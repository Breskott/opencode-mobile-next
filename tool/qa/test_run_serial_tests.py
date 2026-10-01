#!/usr/bin/env python3
"""Tests for the recursive serial test runner.

Run with ``python3 -m unittest discover -s tool/qa -p 'test_*.py'``.
Every test builds a throwaway repository and a fake ``flutter`` shell script,
so no Flutter or Dart process is involved and the module finishes in seconds.
"""

from __future__ import annotations

import contextlib
import io
import json
import os
import signal
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

import run_serial_tests as runner

# The fake launcher can ignore SIGTERM (FAKE_FLUTTER_IGNORE_TERM), start a
# background child that would outlive it (FAKE_FLUTTER_CHILD, a shell snippet)
# and hang (FAKE_FLUTTER_SLEEP). It records its own pid and the pid of every
# process it starts, one per line, so tests can prove all of them were stopped.
FAKE_FLUTTER = """#!/bin/sh
printf '%s\\n' "$@" >> "$FAKE_FLUTTER_ARGS"
printf -- '--\\n' >> "$FAKE_FLUTTER_ARGS"
printf '%s\\n' "$$" >> "$FAKE_FLUTTER_PIDS"
if [ -n "${FAKE_FLUTTER_IGNORE_TERM:-}" ]; then trap '' TERM; fi
if [ -n "${FAKE_FLUTTER_CHILD:-}" ]; then
  sh -c "$FAKE_FLUTTER_CHILD" &
  printf '%s\\n' "$!" >> "$FAKE_FLUTTER_PIDS"
fi
if [ -n "${FAKE_FLUTTER_SLEEP:-}" ]; then
  sleep "$FAKE_FLUTTER_SLEEP" &
  printf '%s\\n' "$!" >> "$FAKE_FLUTTER_PIDS"
  wait "$!"
fi
exit "${FAKE_FLUTTER_EXIT:-0}"
"""

POSIX = os.name != "nt"


def process_alive(pid: int) -> bool:
    """True while the pid exists and is not a zombie awaiting its reaper."""
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    stat_path = Path("/proc") / str(pid) / "stat"
    if stat_path.exists():
        try:
            state = stat_path.read_text(encoding="utf-8").rsplit(")", 1)[1].split()[0]
        except (OSError, IndexError):
            return True
        return state != "Z"
    return True


def wait_dead(pid: int, timeout: float = 5.0) -> bool:
    deadline = time.monotonic() + timeout
    while process_alive(pid):
        if time.monotonic() >= deadline:
            return False
        time.sleep(0.02)
    return True


class RunnerCase(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "repo"
        self.write("pubspec.yaml", "name: fixture\n")
        self.write("lib/main.dart", "void main() {}\n")
        self.write("test/zeta_test.dart", "void main() {}\n")
        self.write("test/alpha_test.dart", "void main() {}\n")
        self.write("test/goldens/theme_gallery_golden_test.dart", "void main() {}\n")
        self.write("test/goldens/gallery_dark.png", "png\n")
        self.write("test/support/fakes.dart", "class Fake {}\n")
        self.write("test/preview/running_work.dart", "void main() {}\n")
        self.flutter = Path(self.temporary.name) / "flutter"
        self.flutter.write_text(FAKE_FLUTTER, encoding="utf-8")
        self.flutter.chmod(self.flutter.stat().st_mode | stat.S_IXUSR)
        self.args_log = Path(self.temporary.name) / "flutter-args.txt"
        self.pids_log = Path(self.temporary.name) / "flutter-pids.txt"
        self.output_root = Path(self.temporary.name) / "runs"
        environment = mock.patch.dict(
            os.environ,
            {
                "FAKE_FLUTTER_ARGS": str(self.args_log),
                "FAKE_FLUTTER_PIDS": str(self.pids_log),
                "FAKE_FLUTTER_EXIT": "0",
            },
        )
        environment.start()
        self.addCleanup(environment.stop)
        for name in ("FAKE_FLUTTER_SLEEP", "FAKE_FLUTTER_CHILD", "FAKE_FLUTTER_IGNORE_TERM"):
            os.environ.pop(name, None)
        # Never leave a fake launcher or its child behind, even when an
        # assertion fails: cleanup runs before the temporary directory goes.
        self.addCleanup(self.kill_recorded_processes)

    def recorded_pids(self) -> list[int]:
        """Every pid the fake launcher(s) recorded: launcher, child, hang."""
        if not self.pids_log.exists():
            return []
        return [int(line) for line in self.pids_log.read_text(encoding="utf-8").split() if line]

    def kill_recorded_processes(self) -> None:
        if not POSIX:
            return
        for pid in self.recorded_pids():
            for target in (lambda: os.killpg(pid, signal.SIGKILL), lambda: os.kill(pid, signal.SIGKILL)):
                try:
                    target()
                except (ProcessLookupError, PermissionError):
                    pass

    def assert_recorded_processes_dead(self, expected_count: int) -> None:
        pids = self.recorded_pids()
        self.assertEqual(len(pids), expected_count, pids)
        for pid in pids:
            self.assertTrue(wait_dead(pid), f"process {pid} outlived the chunk")

    def write(self, relative: str, text: str) -> None:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

    def run_runner(self, *extra: str, new_run: bool = True) -> tuple[int, str]:
        argv = ["run_serial_tests.py", "--root", str(self.root)]
        if new_run:
            argv += ["--flutter", str(self.flutter), "--output-root", str(self.output_root)]
        argv += list(extra)
        buffer = io.StringIO()
        with mock.patch.object(sys, "argv", argv), contextlib.redirect_stdout(buffer), contextlib.redirect_stderr(buffer):
            code = runner.main()
        return code, buffer.getvalue()

    def only_run_directory(self) -> Path:
        directories = [path for path in self.output_root.iterdir() if path.is_dir()]
        self.assertEqual(len(directories), 1, directories)
        return directories[0]

    def invocations(self) -> list[list[str]]:
        if not self.args_log.exists():
            return []
        calls: list[list[str]] = []
        current: list[str] = []
        for line in self.args_log.read_text(encoding="utf-8").splitlines():
            if line == "--":
                calls.append(current)
                current = []
            else:
                current.append(line)
        return calls

    @staticmethod
    def summary(run_directory: Path) -> dict:
        return json.loads((run_directory / "summary.json").read_text(encoding="utf-8"))


class ManifestTests(RunnerCase):
    def test_manifest_is_recursive_sorted_and_only_test_files(self) -> None:
        manifest = [entry["path"] for entry in runner.collect_test_manifest(self.root)]
        self.assertEqual(
            manifest,
            [
                "test/alpha_test.dart",
                "test/goldens/theme_gallery_golden_test.dart",
                "test/zeta_test.dart",
            ],
        )

    def test_golden_failure_artifacts_do_not_change_the_snapshot(self) -> None:
        before = runner.source_snapshot(self.root)
        self.write("test/goldens/failures/theme_masterImage.png", "png\n")
        self.write("test/goldens/failures/stray_test.dart", "void main() {}\n")
        after = runner.source_snapshot(self.root)
        self.assertEqual(before["source_fingerprint"], after["source_fingerprint"])
        self.assertEqual(before["test_manifest_fingerprint"], after["test_manifest_fingerprint"])

    def test_a_new_nested_test_changes_the_manifest(self) -> None:
        before = runner.source_snapshot(self.root)
        self.write("test/state/new_nested_test.dart", "void main() {}\n")
        after = runner.source_snapshot(self.root)
        self.assertNotEqual(before["test_manifest_fingerprint"], after["test_manifest_fingerprint"])
        self.assertIn("test/state/new_nested_test.dart", [e["path"] for e in after["test_manifest"]])


class ExecutionTests(RunnerCase):
    def test_full_run_invokes_serial_chunks_once_each(self) -> None:
        code, output = self.run_runner("--chunk-size", "2")
        self.assertEqual(code, 0, output)
        calls = self.invocations()
        self.assertEqual(len(calls), 2)
        run_directory = self.only_run_directory()
        # The default command is the serial one scripts/release.sh relies on.
        self.assertEqual(
            calls[0],
            [
                "test",
                "--no-pub",
                "--concurrency=1",
                "test/alpha_test.dart",
                "test/goldens/theme_gallery_golden_test.dart",
            ],
        )
        self.assertEqual(calls[1], ["test", "--no-pub", "--concurrency=1", "test/zeta_test.dart"])
        summary = self.summary(run_directory)
        self.assertEqual(summary["status"], "passed")
        self.assertEqual([chunk["status"] for chunk in summary["chunks"]], ["passed", "passed"])
        run_json = json.loads((run_directory / "run.json").read_text(encoding="utf-8"))
        self.assertEqual(run_json["test_count"], 3)
        # The local runner is bounded by default; 0 is the explicit opt out.
        self.assertEqual(run_json["chunk_timeout"], runner.DEFAULT_CHUNK_TIMEOUT)
        self.assertGreater(runner.DEFAULT_CHUNK_TIMEOUT, 0)

    def test_zero_deadline_is_an_explicit_opt_out(self) -> None:
        code, output = self.run_runner("--chunk-timeout", "0")
        self.assertEqual(code, 0, output)
        run_json = json.loads((self.only_run_directory() / "run.json").read_text(encoding="utf-8"))
        self.assertEqual(run_json["chunk_timeout"], 0)

    def test_failed_chunk_stops_the_run_and_is_recorded(self) -> None:
        os.environ["FAKE_FLUTTER_EXIT"] = "3"
        code, output = self.run_runner("--chunk-size", "1")
        self.assertEqual(code, 1, output)
        self.assertEqual(len(self.invocations()), 1)
        summary = self.summary(self.only_run_directory())
        self.assertEqual(summary["status"], "failed")
        self.assertEqual(summary["chunks"][0]["exit_code"], 3)
        self.assertIn("Failed: chunk 1", output)

    def test_chunk_deadline_stops_a_hung_chunk(self) -> None:
        os.environ["FAKE_FLUTTER_SLEEP"] = "20"
        code, output = self.run_runner("--chunk-size", "1", "--chunk-timeout", "1")
        self.assertEqual(code, 1, output)
        run_directory = self.only_run_directory()
        summary = self.summary(run_directory)
        self.assertEqual(summary["status"], "timed_out")
        result = summary["chunks"][0]
        self.assertEqual(result["status"], "timed_out")
        self.assertEqual(result["chunk_timeout"], 1)
        self.assertLess(result["duration_seconds"], 15)
        log = (run_directory / result["log"]).read_text(encoding="utf-8")
        self.assertIn("exceeded 1s", log)
        self.assertIn("Timed out: chunk 1", output)

    def test_negative_deadline_is_rejected(self) -> None:
        code, output = self.run_runner("--chunk-timeout", "-5")
        self.assertEqual(code, 2)
        self.assertIn("--chunk-timeout", output)


@unittest.skipUnless(POSIX, "process-group ownership is the POSIX path")
class ProcessGroupTests(RunnerCase):
    """The runner owns the launcher's process group, not just the launcher pid.

    Regression for: stop_process only terminated the launcher, so a child
    such as flutter_tester survived a deadline and kept running into the
    next chunk or a retry.
    """

    def run_one_chunk_with_deadline(self, *extra: str) -> tuple[dict, str]:
        code, output = self.run_runner("--chunk-size", "1", "--chunk-timeout", "1", *extra)
        self.assertEqual(code, 1, output)
        summary = self.summary(self.only_run_directory())
        self.assertEqual(summary["status"], "timed_out", output)
        return summary["chunks"][0], output

    def test_deadline_kills_the_group_when_the_launcher_ignores_sigterm(self) -> None:
        os.environ["FAKE_FLUTTER_IGNORE_TERM"] = "1"
        os.environ["FAKE_FLUTTER_SLEEP"] = "20"
        os.environ["FAKE_FLUTTER_CHILD"] = "sleep 60"
        with mock.patch.object(runner, "TERMINATE_GRACE_SECONDS", 1):
            result, _ = self.run_one_chunk_with_deadline()
        # Both the launcher and its child inherited the ignored SIGTERM: only
        # SIGKILL to the group, after the bounded grace, can have stopped them.
        self.assertEqual(result["status"], "timed_out")
        self.assertLess(result["duration_seconds"], 8)
        self.assert_recorded_processes_dead(expected_count=3)

    def test_child_ignoring_sigterm_dies_with_a_launcher_that_honoured_it(self) -> None:
        os.environ["FAKE_FLUTTER_SLEEP"] = "20"
        os.environ["FAKE_FLUTTER_CHILD"] = "trap '' TERM; sleep 60"
        result, _ = self.run_one_chunk_with_deadline()
        # The launcher left on SIGTERM at once; the runner must not spend the
        # 10 s grace on it and must still SIGKILL the group for the child.
        self.assertLess(result["duration_seconds"], 6)
        self.assert_recorded_processes_dead(expected_count=3)

    def test_children_left_behind_by_a_passed_chunk_are_swept(self) -> None:
        os.environ["FAKE_FLUTTER_CHILD"] = "sleep 60"
        code, output = self.run_runner("--chunk-size", "1")
        self.assertEqual(code, 0, output)
        self.assertEqual(self.summary(self.only_run_directory())["status"], "passed")
        # Three chunks, each a launcher plus the child it left behind.
        self.assert_recorded_processes_dead(expected_count=6)

    def test_interrupt_stops_the_group(self) -> None:
        os.environ["FAKE_FLUTTER_SLEEP"] = "20"
        os.environ["FAKE_FLUTTER_CHILD"] = "trap '' TERM; sleep 60"
        real_wait_leader = runner.wait_leader

        def interrupt_once(process, timeout):
            if timeout is None or timeout > runner.TERMINATE_GRACE_SECONDS:
                # Ctrl-C arrives once the launcher has started everything.
                deadline = time.monotonic() + 5
                while len(self.recorded_pids()) < 3 and time.monotonic() < deadline:
                    time.sleep(0.02)
                raise KeyboardInterrupt
            return real_wait_leader(process, timeout)

        with mock.patch.object(runner, "wait_leader", interrupt_once):
            code, output = self.run_runner("--chunk-size", "1", "--chunk-timeout", "0")
        self.assertEqual(code, 1, output)
        summary = self.summary(self.only_run_directory())
        self.assertEqual(summary["status"], "interrupted")
        self.assert_recorded_processes_dead(expected_count=3)

    def test_signalling_a_vanished_group_is_not_an_error(self) -> None:
        process = subprocess.Popen(["sh", "-c", "true"], start_new_session=True)
        process.wait()
        self.assertFalse(runner.signal_group(process.pid, 0))
        self.assertEqual(runner.stop_process(process), 0)


class WindowsStopTests(unittest.TestCase):
    def test_windows_stop_targets_the_captured_pid_tree_only(self) -> None:
        process = mock.Mock()
        process.pid = 4242
        process.poll.return_value = None
        process.wait.return_value = 1
        with mock.patch.object(runner, "WINDOWS", True), mock.patch.object(
            runner.subprocess, "run"
        ) as run:
            self.assertEqual(runner.stop_process(process), 1)
        self.assertEqual(run.call_args.args[0], ["taskkill", "/T", "/F", "/PID", "4242"])
        self.assertEqual(run.call_args.kwargs["timeout"], runner.TERMINATE_GRACE_SECONDS)
        process.kill.assert_not_called()

    def test_windows_stop_falls_back_to_kill_when_taskkill_is_missing(self) -> None:
        process = mock.Mock()
        process.pid = 4242
        process.poll.return_value = None
        process.wait.side_effect = [subprocess.TimeoutExpired("x", 1), -1]
        with mock.patch.object(runner, "WINDOWS", True), mock.patch.object(
            runner.subprocess, "run", side_effect=FileNotFoundError
        ):
            self.assertEqual(runner.stop_process(process), -1)
        process.kill.assert_called_once()


def test_paths(calls: list[list[str]]) -> list[str]:
    return [arg for call in calls for arg in call if arg.startswith("test/")]


class ShardingTests(RunnerCase):
    WEIGHTS = {
        "test/huge_test.dart": 230.0,
        "test/big_test.dart": 200.0,
        "test/large_test.dart": 180.0,
        "test/medium_test.dart": 60.0,
    }

    def synthetic_manifest(self) -> tuple[list[str], dict[str, int]]:
        paths = sorted(
            list(self.WEIGHTS) + [f"test/small_{index:03d}_test.dart" for index in range(200)]
        )
        timings = {name: int(value * 1000) for name, value in self.WEIGHTS.items()}
        # Most small files are measured; a few are new and get the median.
        for index in range(190):
            timings[f"test/small_{index:03d}_test.dart"] = 1000 + (index % 7) * 500
        return paths, timings

    def write_timings(self, files: dict[str, float]) -> None:
        self.write(
            "tool/qa/test_timings.json",
            json.dumps({"schema_version": 1, "unit": "seconds", "files": files}),
        )

    def test_every_file_lands_in_exactly_one_shard(self) -> None:
        paths, timings = self.synthetic_manifest()
        weights = runner.file_weights(paths, timings)
        for count in (1, 2, 3, 4, 6, 7, 250):
            shards = runner.partition_shards(paths, weights, count)
            self.assertEqual(len(shards), count)
            flat = [path for shard in shards for path in shard]
            self.assertEqual(sorted(flat), paths, count)
            self.assertEqual(len(flat), len(set(flat)), count)

    def test_shards_are_balanced_by_timing(self) -> None:
        paths, timings = self.synthetic_manifest()
        weights = runner.file_weights(paths, timings)
        total = sum(weights.values())
        heaviest = max(weights.values())
        for count in (2, 4, 6):
            loads = [sum(weights[p] for p in shard) for shard in runner.partition_shards(paths, weights, count)]
            # Greedy LPT guarantee: no shard exceeds the ideal share by more
            # than its single heaviest file.
            self.assertLessEqual(max(loads), total / count + heaviest, (count, loads))
        for count in (2, 4):
            loads = [sum(weights[p] for p in shard) for shard in runner.partition_shards(paths, weights, count)]
            # With small files to fill the gaps, the spread stays tiny.
            self.assertLessEqual(max(loads) - min(loads), 2000, (count, loads))
        loads = [sum(weights[p] for p in shard) for shard in runner.partition_shards(paths, weights, 6)]
        # When one file outweighs the ideal share, it alone sets the longest shard.
        self.assertEqual(max(loads), heaviest, loads)
        # The four slow files never share a shard when there is room.
        shards = runner.partition_shards(paths, weights, 4)
        for name in self.WEIGHTS:
            self.assertEqual(sum(name in shard for shard in shards), 1)
        self.assertEqual(sorted(shard[0] for shard in shards), sorted(self.WEIGHTS))

    def test_partition_is_deterministic_and_heaviest_first(self) -> None:
        paths, timings = self.synthetic_manifest()
        weights = runner.file_weights(paths, timings)
        first = runner.partition_shards(paths, weights, 6)
        second = runner.partition_shards(list(reversed(paths)), dict(reversed(list(weights.items()))), 6)
        self.assertEqual(first, second)
        for shard in first:
            self.assertEqual(shard, sorted(shard, key=lambda path: (-weights[path], path)))

    def test_unknown_files_weigh_the_median(self) -> None:
        weights = runner.file_weights(
            ["test/a_test.dart", "test/new_test.dart"],
            {"test/a_test.dart": 9000, "test/b_test.dart": 1000, "test/c_test.dart": 2000},
        )
        self.assertEqual(weights, {"test/a_test.dart": 9000, "test/new_test.dart": 2000})
        self.assertEqual(
            runner.file_weights(["test/x_test.dart"], {}),
            {"test/x_test.dart": runner.FALLBACK_WEIGHT_MS},
        )

    def test_default_run_keeps_sorted_serial_order(self) -> None:
        self.write_timings({"test/zeta_test.dart": 100.0})
        manifest = [entry["path"] for entry in runner.collect_test_manifest(self.root)]
        self.assertEqual(runner.plan_tests(manifest, runner.load_timings(self.root), 1, 1, 1), manifest)

    def test_shard_runs_together_cover_the_suite_once(self) -> None:
        self.write_timings({
            "test/alpha_test.dart": 1.0,
            "test/goldens/theme_gallery_golden_test.dart": 5.0,
            "test/zeta_test.dart": 3.0,
        })
        for index in (1, 2):
            code, output = self.run_runner(
                "--shard-index", str(index), "--shard-count", "2", "--concurrency", "4"
            )
            self.assertEqual(code, 0, output)
        calls = self.invocations()
        self.assertEqual(
            test_paths(calls),
            [
                "test/goldens/theme_gallery_golden_test.dart",
                "test/zeta_test.dart",
                "test/alpha_test.dart",
            ],
        )
        self.assertTrue(all("--concurrency=4" in call for call in calls))
        runs = sorted(path.name for path in self.output_root.iterdir())
        self.assertTrue(runs[0].startswith("shard1of2-"), runs)
        self.assertTrue(runs[1].startswith("shard2of2-"), runs)
        run_json = json.loads((self.output_root / runs[1] / "run.json").read_text(encoding="utf-8"))
        self.assertEqual(
            (run_json["shard_index"], run_json["shard_count"], run_json["concurrency"]),
            (2, 2, 4),
        )
        self.assertEqual(run_json["manifest_count"], 3)
        self.assertEqual(run_json["test_count"], 2)

    def test_an_empty_shard_passes_without_running_flutter(self) -> None:
        code, output = self.run_runner("--shard-index", "5", "--shard-count", "5")
        self.assertEqual(code, 0, output)
        self.assertEqual(self.invocations(), [])
        self.assertEqual(self.summary(self.only_run_directory())["status"], "passed")

    def test_invalid_shard_arguments_are_rejected(self) -> None:
        for extra in (
            ("--shard-index", "0", "--shard-count", "6"),
            ("--shard-index", "7", "--shard-count", "6"),
            ("--shard-index", "2"),
            ("--shard-count", "0"),
            ("--concurrency", "0"),
        ):
            code, output = self.run_runner(*extra)
            self.assertEqual(code, 2, extra)
            self.assertIn("must be between", output)
        self.assertFalse(self.output_root.exists() and any(self.output_root.iterdir()))

    def test_resume_keeps_the_shard_and_refuses_another(self) -> None:
        os.environ["FAKE_FLUTTER_EXIT"] = "1"
        self.run_runner("--shard-index", "1", "--shard-count", "2", "--chunk-size", "1", "--concurrency", "3")
        run_directory = self.only_run_directory()
        code, output = self.run_runner(
            "--resume", str(run_directory), "--shard-index", "2", "--shard-count", "2", new_run=False
        )
        self.assertEqual(code, 2)
        self.assertIn("--shard-index/--shard-count differ", output)

        os.environ["FAKE_FLUTTER_EXIT"] = "0"
        code, output = self.run_runner("--resume", str(run_directory), new_run=False)
        self.assertEqual(code, 0, output)
        calls = self.invocations()
        # The failed first chunk reran with the stored concurrency, then the rest.
        self.assertEqual(test_paths(calls[:1]), test_paths(calls[1:2]))
        self.assertTrue(all("--concurrency=3" in call for call in calls))
        run_json = json.loads((run_directory / "run.json").read_text(encoding="utf-8"))
        self.assertEqual(
            sorted(test_paths(calls[1:])),
            sorted(path for chunk in run_json["chunks"] for path in chunk["tests"]),
        )


class ReportTests(RunnerCase):
    def write_report(self, name: str, root_prefix: str) -> Path:
        events = [
            {"type": "suite", "suite": {"id": 0, "path": f"{root_prefix}/test/alpha_test.dart"}},
            {"type": "testStart", "test": {"id": 1, "suiteID": 0, "name": "loading"}, "time": 0},
            {"type": "testDone", "testID": 1, "result": "success", "hidden": True, "time": 1500},
            {"type": "testStart", "test": {"id": 2, "suiteID": 0, "name": "a"}, "time": 1500},
            {"type": "testDone", "testID": 2, "result": "success", "time": 4000},
            {"type": "suite", "suite": {"id": 3, "path": f"{root_prefix}/test/goldens/theme_gallery_golden_test.dart"}},
            {"type": "testStart", "test": {"id": 4, "suiteID": 3, "name": "g"}, "time": 4000},
            {"type": "error", "testID": 4, "error": "boom", "time": 4100},
            {"type": "testDone", "testID": 4, "result": "failure", "time": 4200},
        ]
        path = Path(self.temporary.name) / name
        path.write_text(
            "Resolving dependencies...\n" + "\n".join(json.dumps(event) for event in events) + "\n",
            encoding="utf-8",
        )
        return path

    def test_report_gives_per_file_time_and_failures(self) -> None:
        report = self.write_report("report.jsonl", "/elsewhere/other_checkout")
        results = {
            runner.relative_test_path(self.root, path): value
            for path, value in runner.report_suite_results(report).items()
        }
        self.assertEqual(
            results,
            {
                "test/alpha_test.dart": {"ms": 4000, "failed": False},
                "test/goldens/theme_gallery_golden_test.dart": {"ms": 200, "failed": True},
            },
        )
        tests = [entry["path"] for entry in runner.collect_test_manifest(self.root)]
        self.assertEqual(
            runner.failed_files_for(self.root, report, tests, "failed"),
            ["test/goldens/theme_gallery_golden_test.dart"],
        )
        self.assertEqual(runner.failed_files_for(self.root, report, tests, "passed"), [])
        # A timed-out chunk without failing events names the files that never reported.
        missing = Path(self.temporary.name) / "missing.jsonl"
        self.assertEqual(runner.failed_files_for(self.root, missing, tests, "timed_out"), tests)

    def test_json_report_is_opt_in_and_kept_on_resume(self) -> None:
        os.environ["FAKE_FLUTTER_EXIT"] = "1"
        self.run_runner("--chunk-size", "2", "--json-report")
        run_directory = self.only_run_directory()
        report = run_directory / "chunks" / "001-attempt-001.report.jsonl"
        self.assertEqual(
            self.invocations()[0][:4],
            ["test", "--no-pub", "--concurrency=1", f"--file-reporter=json:{report}"],
        )
        os.environ["FAKE_FLUTTER_EXIT"] = "0"
        code, output = self.run_runner("--resume", str(run_directory), new_run=False)
        self.assertEqual(code, 0, output)
        retry = run_directory / "chunks" / "001-attempt-002.report.jsonl"
        self.assertIn(f"--file-reporter=json:{retry}", self.invocations()[1])

    def test_failed_run_summary_names_the_files(self) -> None:
        os.environ["FAKE_FLUTTER_EXIT"] = "1"
        code, output = self.run_runner("--chunk-size", "2")
        self.assertEqual(code, 1)
        summary = self.summary(self.only_run_directory())
        self.assertEqual(
            summary["failed_files"],
            ["test/alpha_test.dart", "test/goldens/theme_gallery_golden_test.dart"],
        )
        self.assertIn("failed: test/alpha_test.dart", output)

    def test_timings_generator_writes_per_file_seconds(self) -> None:
        import update_test_timings

        report = self.write_report("report.jsonl", str(self.root))
        argv = ["update_test_timings.py", "--root", str(self.root), str(report)]
        with mock.patch.object(sys, "argv", argv), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(update_test_timings.main(), 0)
        data = json.loads((self.root / runner.TIMINGS_FILE).read_text(encoding="utf-8"))
        self.assertEqual(
            data["files"],
            {"test/alpha_test.dart": 4.0, "test/goldens/theme_gallery_golden_test.dart": 0.2},
        )
        self.assertEqual(
            runner.load_timings(self.root),
            {"test/alpha_test.dart": 4000, "test/goldens/theme_gallery_golden_test.dart": 200},
        )


class ResumeTests(RunnerCase):
    def test_resume_is_refused_when_a_test_dependency_changes(self) -> None:
        self.write("scripts/release.sh", "#!/bin/sh\nexit 0\n")
        os.environ["FAKE_FLUTTER_EXIT"] = "1"
        self.run_runner("--chunk-size", "1")
        run_directory = self.only_run_directory()
        self.write("scripts/release.sh", "#!/bin/sh\nexit 1\n")
        code, output = self.run_runner("--resume", str(run_directory), new_run=False)
        self.assertEqual(code, 2)
        self.assertIn("relevant source changed", output)
        self.assertEqual(len(self.invocations()), 1)

    def test_resume_reruns_only_unfinished_chunks(self) -> None:
        os.environ["FAKE_FLUTTER_EXIT"] = "1"
        code, _ = self.run_runner("--chunk-size", "1")
        self.assertEqual(code, 1)
        run_directory = self.only_run_directory()

        os.environ["FAKE_FLUTTER_EXIT"] = "0"
        code, output = self.run_runner("--resume", str(run_directory), new_run=False)
        self.assertEqual(code, 0, output)
        calls = self.invocations()
        self.assertEqual([call[-1] for call in calls], [
            "test/alpha_test.dart",
            "test/alpha_test.dart",
            "test/goldens/theme_gallery_golden_test.dart",
            "test/zeta_test.dart",
        ])
        self.assertTrue((run_directory / "chunks" / "001-attempt-002.json").exists())
        self.assertEqual(self.summary(run_directory)["status"], "passed")

        # A second resume of a passed run reruns nothing.
        code, _ = self.run_runner("--resume", str(run_directory), new_run=False)
        self.assertEqual(code, 0)
        self.assertEqual(len(self.invocations()), 4)

    def test_resume_is_refused_when_source_changed(self) -> None:
        os.environ["FAKE_FLUTTER_EXIT"] = "1"
        self.run_runner("--chunk-size", "1")
        run_directory = self.only_run_directory()
        self.write("lib/main.dart", "void main() { print('changed'); }\n")
        code, output = self.run_runner("--resume", str(run_directory), new_run=False)
        self.assertEqual(code, 2)
        self.assertIn("relevant source changed", output)
        self.assertEqual(len(self.invocations()), 1)

    def test_resume_is_refused_when_a_test_is_added(self) -> None:
        os.environ["FAKE_FLUTTER_EXIT"] = "1"
        self.run_runner("--chunk-size", "1")
        run_directory = self.only_run_directory()
        self.write("test/goldens/second_golden_test.dart", "void main() {}\n")
        code, output = self.run_runner("--resume", str(run_directory), new_run=False)
        self.assertEqual(code, 2)
        # test/ is part of the source snapshot, so the source check trips first.
        self.assertIn("Refusing to resume", output)
        self.assertEqual(len(self.invocations()), 1)

    def test_resume_keeps_or_overrides_the_stored_deadline(self) -> None:
        os.environ["FAKE_FLUTTER_EXIT"] = "1"
        self.run_runner("--chunk-size", "1", "--chunk-timeout", "30")
        run_directory = self.only_run_directory()
        run_json = json.loads((run_directory / "run.json").read_text(encoding="utf-8"))
        self.assertEqual(run_json["chunk_timeout"], 30)

        os.environ["FAKE_FLUTTER_EXIT"] = "0"
        code, _ = self.run_runner("--resume", str(run_directory), new_run=False)
        self.assertEqual(code, 0)
        results = sorted((run_directory / "chunks").glob("*.json"))
        timeouts = {json.loads(p.read_text(encoding="utf-8"))["chunk_timeout"] for p in results}
        self.assertEqual(timeouts, {30})

    def test_resume_is_refused_for_a_different_flutter(self) -> None:
        os.environ["FAKE_FLUTTER_EXIT"] = "1"
        self.run_runner("--chunk-size", "1")
        run_directory = self.only_run_directory()
        other = Path(self.temporary.name) / "flutter-other"
        other.write_text(FAKE_FLUTTER, encoding="utf-8")
        other.chmod(other.stat().st_mode | stat.S_IXUSR)
        code, output = self.run_runner("--resume", str(run_directory), "--flutter", str(other), new_run=False)
        self.assertEqual(code, 2)
        self.assertIn("--flutter differs", output)


if __name__ == "__main__":
    unittest.main()
