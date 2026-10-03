#!/usr/bin/env python3
"""Run the recursive Flutter test suite in bounded, resumable chunks.

By default every file runs serially (``--concurrency=1``) in sorted order. With
``--shard-index I --shard-count N`` the manifest is split into N disjoint
shards balanced by the committed per-file timings in ``tool/qa/test_timings.json``
(unknown files weigh the median), so N machines or processes together run
every file exactly once. ``--concurrency C`` is passed to ``flutter test``.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import statistics
import subprocess
import sys
import time
from datetime import datetime, timezone
from typing import Any, Iterable


SCHEMA_VERSION = 1
DEFAULT_CHUNK_SIZE = 25
MAX_CHUNK_SIZE = 1000
DEFAULT_CONCURRENCY = 1
MAX_CONCURRENCY = 64
MAX_SHARD_COUNT = 256
# Seconds per test file measured with the Flutter JSON reporter (load + every
# test). Regenerate with tool/qa/update_test_timings.py from chunk reports.
TIMINGS_FILE = Path("tool/qa/test_timings.json")
# Weight of a file when no timings are available at all.
FALLBACK_WEIGHT_MS = 1000
# Seconds a chunk may run before it is stopped. The local runner promises a
# bounded run, so the default is a deadline generous enough for the slowest
# real chunk (the whole 321-file suite takes 27-40 minutes serially, so a
# 25-file chunk is a few minutes). `--chunk-timeout 0` is the explicit opt out.
DEFAULT_CHUNK_TIMEOUT = 900
TERMINATE_GRACE_SECONDS = 10
# After SIGKILL the leader is reaped by us and its children by init; this is
# only how long we watch the group drain before moving on, never a retry loop.
GROUP_EXIT_SETTLE_SECONDS = 5
WINDOWS = os.name == "nt"
SOURCE_DIRECTORIES = (
    "assets",
    "contracts",
    "lib",
    "packages",
    "test",
    # Tests execute helpers and inspect native/release contracts too.
    "tool",
    "scripts",
    "android/app/src",
    "ios/Runner",
    "ios/Runner.xcodeproj",
    "linux",
    "macos/Runner",
    "windows",
    "packaging",
    ".github",
)
SOURCE_FILES = (
    "analysis_options.yaml",
    "l10n.yaml",
    "pubspec.lock",
    "pubspec.yaml",
    "android/app/build.gradle.kts",
    "android/build.gradle.kts",
    "android/settings.gradle.kts",
    "android/key.properties.example",
    "ios/Podfile",
    "ios/Runner.xcworkspace/contents.xcworkspacedata",
    ".gitignore",
    "README.md",
    "LICENSE",
    "THIRD_PARTY_NOTICES.md",
    "docs/internal/developer-skills.md",
)
TRANSIENT_DIRECTORY_NAMES = {
    ".dart_tool",
    ".git",
    "build",
    "runs",
    "__pycache__",
    ".pytest_cache",
    "ephemeral",
}
# `flutter test` writes golden diffs to `test/**/failures/` when a golden
# comparison fails. Those images are run artifacts, not source: hashing them
# would make every resume after a golden failure refuse with "source changed".
TEST_ARTIFACT_DIRECTORY_NAMES = {"failures"}


class RunnerError(RuntimeError):
    """An expected runner refusal or invalid invocation."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds").replace(
        "+00:00", "Z"
    )


def canonical_json(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> tuple[str, int]:
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
            size += len(chunk)
    return digest.hexdigest(), size


def relative_path(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def is_transient(root: Path, path: Path) -> bool:
    relative_parts = path.relative_to(root).parts
    if any(part in TRANSIENT_DIRECTORY_NAMES for part in relative_parts):
        return True
    return relative_parts[:1] == ("test",) and any(
        part in TEST_ARTIFACT_DIRECTORY_NAMES for part in relative_parts[1:-1]
    )


def iter_directory_files(root: Path, directory: Path) -> Iterable[Path]:
    if not directory.is_dir():
        return
    for path in directory.rglob("*"):
        if not path.is_file():
            continue
        if is_transient(root, path):
            continue
        yield path


def collect_test_manifest(root: Path) -> list[dict[str, Any]]:
    test_root = root / "test"
    paths = sorted(
        (
            path
            for path in test_root.rglob("*_test.dart")
            if path.is_file() and not is_transient(root, path)
        ),
        key=lambda path: relative_path(root, path),
    ) if test_root.is_dir() else []
    return [file_entry(root, path) for path in paths]


def collect_source_manifest(root: Path) -> list[dict[str, Any]]:
    paths: dict[str, Path] = {}
    for directory_name in SOURCE_DIRECTORIES:
        directory = root / directory_name
        for path in iter_directory_files(root, directory):
            paths[relative_path(root, path)] = path
    for file_name in SOURCE_FILES:
        path = root / file_name
        if path.is_file():
            paths[relative_path(root, path)] = path

    return [file_entry(root, paths[name]) for name in sorted(paths)]


def file_entry(root: Path, path: Path) -> dict[str, Any]:
    digest, size = sha256_file(path)
    return {"path": relative_path(root, path), "sha256": digest, "size": size}


def manifest_fingerprint(entries: list[dict[str, Any]]) -> str:
    return sha256_bytes(canonical_json(entries))


def source_snapshot(root: Path) -> dict[str, Any]:
    tests = collect_test_manifest(root)
    source = collect_source_manifest(root)
    return {
        "test_manifest": tests,
        "test_manifest_fingerprint": manifest_fingerprint(tests),
        "source_manifest": source,
        "source_fingerprint": manifest_fingerprint(source),
    }


def atomic_json_write(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    temporary.write_bytes(canonical_json(value) + b"\n")
    temporary.replace(path)


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RunnerError(f"Could not read JSON metadata: {path}: {exc}") from exc


def resolve_flutter(value: str) -> str:
    candidate = Path(value).expanduser()
    if candidate.is_file():
        return str(candidate.resolve())
    located = shutil.which(value)
    if located:
        return str(Path(located).resolve())
    raise RunnerError(
        f"Flutter executable was not found: {value!r}. Pass the explicit flutter "
        "executable path (including flutter.bat on Windows)."
    )


def chunks(items: list[str], size: int) -> list[list[str]]:
    return [items[index : index + size] for index in range(0, len(items), size)]


def load_timings(root: Path) -> dict[str, int]:
    """Committed per-file timings in integer milliseconds; empty when absent."""
    path = root / TIMINGS_FILE
    if not path.is_file():
        return {}
    data = read_json(path)
    files = data.get("files") if isinstance(data, dict) else None
    if not isinstance(files, dict):
        raise RunnerError(f"Timing file has no 'files' object: {path}")
    timings: dict[str, int] = {}
    for name, seconds in files.items():
        if not isinstance(name, str) or not isinstance(seconds, (int, float)) or seconds < 0:
            raise RunnerError(f"Invalid timing entry in {path}: {name!r}: {seconds!r}")
        timings[name] = int(round(seconds * 1000))
    return timings


def file_weights(test_paths: list[str], timings: dict[str, int]) -> dict[str, int]:
    """Weight of every file; files without a measurement weigh the median."""
    default = int(statistics.median(timings.values())) if timings else FALLBACK_WEIGHT_MS
    return {path: timings.get(path, default) for path in test_paths}


def longest_first(test_paths: list[str], weights: dict[str, int]) -> list[str]:
    return sorted(test_paths, key=lambda path: (-weights[path], path))


def partition_shards(
    test_paths: list[str], weights: dict[str, int], shard_count: int
) -> list[list[str]]:
    """Deterministic longest-processing-time partition into shard_count shards.

    Files are placed heaviest first, each on the currently lightest shard (ties
    go to the lowest shard number). Integer weights keep the result identical
    on every machine. Each shard lists its files heaviest first, so a parallel
    ``flutter test`` starts the long files early instead of ending on them.
    Every input file lands in exactly one shard.
    """
    loads = [0] * shard_count
    shards: list[list[str]] = [[] for _ in range(shard_count)]
    for path in longest_first(test_paths, weights):
        target = min(range(shard_count), key=lambda index: (loads[index], index))
        shards[target].append(path)
        loads[target] += weights[path]
    return shards


def plan_tests(
    test_paths: list[str],
    timings: dict[str, int],
    shard_index: int,
    shard_count: int,
    concurrency: int,
) -> list[str]:
    """The ordered files this invocation runs.

    The default (one shard, serial) keeps the sorted manifest order. A sharded
    or parallel run schedules the heaviest files first.
    """
    if shard_count == 1 and concurrency == 1:
        return list(test_paths)
    weights = file_weights(test_paths, timings)
    return partition_shards(test_paths, weights, shard_count)[shard_index - 1]


def command_for_flutter(
    flutter: str,
    test_paths: list[str],
    concurrency: int = DEFAULT_CONCURRENCY,
    json_report: Path | None = None,
) -> list[str]:
    arguments = [flutter, "test", "--no-pub", f"--concurrency={concurrency}"]
    if json_report is not None:
        arguments.append(f"--file-reporter=json:{json_report}")
    arguments += test_paths
    if Path(flutter).suffix.lower() not in {".bat", ".cmd"}:
        return arguments

    # CreateProcess cannot reliably execute a Windows batch file directly from
    # every Python/runtime combination. Use the user's command processor while
    # retaining an argv-safe command line for paths containing spaces.
    command_line = subprocess.list2cmdline(arguments)
    command_processor = os.environ.get("COMSPEC", "cmd.exe")
    return [command_processor, "/d", "/s", "/c", command_line]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run recursive *_test.dart files in bounded serial Flutter chunks "
            "with retained logs and safe resume."
        )
    )
    parser.add_argument(
        "--root",
        type=Path,
        help="Repository root (defaults to the checkout containing this script).",
    )
    parser.add_argument(
        "--flutter",
        help=(
            "Explicit Flutter executable. Required for a new run; pass the full "
            "flutter.bat path on Windows."
        ),
    )
    parser.add_argument(
        "--chunk-size",
        type=int,
        default=DEFAULT_CHUNK_SIZE,
        help=f"Maximum test files per serial chunk (default: {DEFAULT_CHUNK_SIZE}).",
    )
    parser.add_argument(
        "--chunk-timeout",
        type=int,
        default=None,
        help=(
            "Seconds a single chunk may run before it and every process it "
            f"started are stopped and the chunk is recorded as timed_out (default: "
            f"{DEFAULT_CHUNK_TIMEOUT}). Pass 0 to opt out of the deadline explicitly. "
            "On resume, an explicit value overrides the one stored in run.json."
        ),
    )
    parser.add_argument(
        "--shard-index",
        type=int,
        default=None,
        help="1-based shard to run out of --shard-count (default: 1).",
    )
    parser.add_argument(
        "--shard-count",
        type=int,
        default=None,
        help=(
            "Split the manifest into this many timing-balanced shards; together "
            "they run every file exactly once (default: 1, the whole suite)."
        ),
    )
    parser.add_argument(
        "--concurrency",
        type=int,
        default=None,
        help=(
            f"Test files flutter test runs at once (default: {DEFAULT_CONCURRENCY}, "
            "serial). On resume, an explicit value overrides the stored one."
        ),
    )
    parser.add_argument(
        "--json-report",
        action="store_true",
        help=(
            "Also write each chunk's Flutter JSON report next to its log, so "
            "summary.json names the failing files and tool/qa/update_test_timings.py "
            "can refresh the shard timings. Kept on resume."
        ),
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        help="Directory for new run folders (default: build/traycer).",
    )
    parser.add_argument(
        "--resume",
        type=Path,
        help="Existing run directory to resume after validating its source snapshot.",
    )
    return parser.parse_args()


def validate_chunk_size(size: int) -> None:
    if size < 1 or size > MAX_CHUNK_SIZE:
        raise RunnerError(
            f"--chunk-size must be between 1 and {MAX_CHUNK_SIZE}, got {size}"
        )


def validate_shard(shard_index: int | None, shard_count: int | None) -> tuple[int, int]:
    count = 1 if shard_count is None else shard_count
    index = 1 if shard_index is None else shard_index
    if count < 1 or count > MAX_SHARD_COUNT:
        raise RunnerError(f"--shard-count must be between 1 and {MAX_SHARD_COUNT}, got {count}")
    if index < 1 or index > count:
        raise RunnerError(
            f"--shard-index must be between 1 and --shard-count ({count}), got {index}"
        )
    return index, count


def validate_concurrency(concurrency: int | None) -> int:
    if concurrency is None:
        return DEFAULT_CONCURRENCY
    if concurrency < 1 or concurrency > MAX_CONCURRENCY:
        raise RunnerError(
            f"--concurrency must be between 1 and {MAX_CONCURRENCY}, got {concurrency}"
        )
    return concurrency


def validate_chunk_timeout(timeout: int | None) -> int:
    if timeout is None:
        return DEFAULT_CHUNK_TIMEOUT
    if timeout < 0:
        raise RunnerError(f"--chunk-timeout must be 0 or a positive number of seconds, got {timeout}")
    return timeout


def run_directory_for(root: Path, output_root: Path, prefix: str = "serial") -> Path:
    run_id = f"{prefix}-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}-{secrets.token_hex(4)}"
    run_directory = output_root / run_id
    run_directory.mkdir(parents=True, exist_ok=False)
    return run_directory


def create_run(root: Path, args: argparse.Namespace, snapshot: dict[str, Any]) -> tuple[Path, dict[str, Any]]:
    if not args.flutter:
        raise RunnerError("--flutter is required when starting a new run")
    validate_chunk_size(args.chunk_size)
    chunk_timeout = validate_chunk_timeout(args.chunk_timeout)
    shard_index, shard_count = validate_shard(args.shard_index, args.shard_count)
    concurrency = validate_concurrency(args.concurrency)
    flutter = resolve_flutter(args.flutter)
    output_root = (args.output_root or root / "build" / "traycer").resolve()
    prefix = "serial" if shard_count == 1 else f"shard{shard_index}of{shard_count}"
    run_directory = run_directory_for(root, output_root, prefix)
    manifest_paths = [entry["path"] for entry in snapshot["test_manifest"]]
    test_paths = plan_tests(
        manifest_paths, load_timings(root), shard_index, shard_count, concurrency
    )
    chunk_list = chunks(test_paths, args.chunk_size)
    metadata = {
        "schema_version": SCHEMA_VERSION,
        "run_id": run_directory.name,
        "root": str(root),
        "created_at": utc_now(),
        "flutter": flutter,
        "chunk_size": args.chunk_size,
        "chunk_timeout": chunk_timeout,
        "concurrency": concurrency,
        "json_report": bool(args.json_report),
        "shard_index": shard_index,
        "shard_count": shard_count,
        "manifest_count": len(manifest_paths),
        "test_count": len(test_paths),
        "chunk_count": len(chunk_list),
        "chunks": [
            {"index": index, "tests": test_paths}
            for index, test_paths in enumerate(chunk_list, start=1)
        ],
        "test_manifest_fingerprint": snapshot["test_manifest_fingerprint"],
        "source_fingerprint": snapshot["source_fingerprint"],
    }
    atomic_json_write(run_directory / "run.json", metadata)
    atomic_json_write(run_directory / "test-manifest.json", snapshot["test_manifest"])
    atomic_json_write(run_directory / "source-manifest.json", snapshot["source_manifest"])
    atomic_json_write(
        run_directory / "summary.json",
        summary_for(metadata, [], "pending", None),
    )
    return run_directory, metadata


def load_resume(root: Path, args: argparse.Namespace, snapshot: dict[str, Any]) -> tuple[Path, dict[str, Any]]:
    if args.flutter:
        supplied_flutter = resolve_flutter(args.flutter)
    else:
        supplied_flutter = None
    run_directory = args.resume.expanduser().resolve()
    metadata = read_json(run_directory / "run.json")
    if metadata.get("schema_version") != SCHEMA_VERSION:
        raise RunnerError("Unsupported or missing run metadata schema version")
    if Path(metadata.get("root", "")).resolve() != root:
        raise RunnerError(
            f"Refusing to resume: run root is {metadata.get('root')!r}, current root is {str(root)!r}"
        )
    if metadata.get("source_fingerprint") != snapshot["source_fingerprint"]:
        raise RunnerError(
            "Refusing to resume: relevant source changed since the run snapshot "
            f"({metadata.get('source_fingerprint')} != {snapshot['source_fingerprint']})"
        )
    if metadata.get("test_manifest_fingerprint") != snapshot["test_manifest_fingerprint"]:
        raise RunnerError(
            "Refusing to resume: recursive test manifest changed since the run snapshot"
        )
    shard_index, shard_count = validate_shard(
        metadata.get("shard_index", 1), metadata.get("shard_count", 1)
    )
    if (args.shard_index is not None and args.shard_index != shard_index) or (
        args.shard_count is not None and args.shard_count != shard_count
    ):
        raise RunnerError(
            "Refusing to resume: --shard-index/--shard-count differ from the immutable run metadata"
        )
    stored_concurrency = validate_concurrency(metadata.get("concurrency", DEFAULT_CONCURRENCY))
    expected_tests = plan_tests(
        [entry["path"] for entry in snapshot["test_manifest"]],
        load_timings(root),
        shard_index,
        shard_count,
        stored_concurrency,
    )
    actual_tests = [
        test_path
        for chunk in metadata.get("chunks", [])
        for test_path in chunk.get("tests", [])
    ]
    if actual_tests != expected_tests:
        raise RunnerError(
            "Refusing to resume: stored chunk manifest does not match the current test manifest"
        )
    if supplied_flutter and supplied_flutter != metadata.get("flutter"):
        raise RunnerError(
            "Refusing to resume: --flutter differs from the executable stored in run.json"
        )
    if args.chunk_size != DEFAULT_CHUNK_SIZE and args.chunk_size != metadata.get("chunk_size"):
        raise RunnerError(
            "Refusing to resume: --chunk-size differs from the immutable run metadata"
        )
    # The deadline is execution policy, not part of the snapshot: an explicit
    # value on resume wins; otherwise the stored one (or none) applies.
    if args.chunk_timeout is not None:
        metadata["chunk_timeout"] = validate_chunk_timeout(args.chunk_timeout)
    else:
        metadata["chunk_timeout"] = validate_chunk_timeout(metadata.get("chunk_timeout"))
    # Concurrency is execution policy too; the stored file order stays fixed.
    if args.concurrency is not None:
        metadata["concurrency"] = validate_concurrency(args.concurrency)
    else:
        metadata["concurrency"] = stored_concurrency
    return run_directory, metadata


def summary_for(
    metadata: dict[str, Any], chunks_summary: list[dict[str, Any]], status: str, error: str | None
) -> dict[str, Any]:
    value: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "run_id": metadata["run_id"],
        "status": status,
        "updated_at": utc_now(),
        "source_fingerprint": metadata["source_fingerprint"],
        "test_manifest_fingerprint": metadata["test_manifest_fingerprint"],
        "shard_index": metadata.get("shard_index", 1),
        "shard_count": metadata.get("shard_count", 1),
        "chunks": chunks_summary,
        "failed_files": sorted(
            {
                path
                for chunk in chunks_summary
                if chunk.get("status") != "passed"
                for path in chunk.get("failed_files", [])
            }
        ),
    }
    if error:
        value["error"] = error
    return value


def result_files(run_directory: Path, chunk_index: int) -> list[Path]:
    prefix = f"{chunk_index:03d}-attempt-"
    return sorted(
        (path for path in (run_directory / "chunks").glob(f"{prefix}*.json") if path.is_file()),
        key=lambda path: path.name,
    )


def latest_results(run_directory: Path) -> list[dict[str, Any]]:
    metadata = read_json(run_directory / "run.json")
    results: list[dict[str, Any]] = []
    for chunk in metadata["chunks"]:
        files = result_files(run_directory, int(chunk["index"]))
        if files:
            results.append(read_json(files[-1]))
    return results


def next_attempt(run_directory: Path, chunk_index: int) -> int:
    attempts = []
    for path in result_files(run_directory, chunk_index):
        try:
            attempts.append(int(path.stem.rsplit("-", 1)[-1]))
        except ValueError:
            continue
    return max(attempts, default=0) + 1


def launch_chunk(command: list[str], root: Path, log: Any) -> subprocess.Popen[Any]:
    """Start the Flutter launcher as the sole owner of a fresh process group.

    On POSIX ``start_new_session`` makes the launcher the leader of a new
    session and process group whose id equals the launcher pid captured here.
    Everything Flutter spawns (dart, flutter_tester, ...) inherits that group,
    so the runner can stop the whole chunk by signalling one id it owns. It
    never looks processes up by name or pattern.
    """
    return subprocess.Popen(
        command,
        cwd=root,
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=not WINDOWS,
    )


def signal_group(pgid: int, signum: int) -> bool:
    """Signal the captured group; False when it no longer exists."""
    try:
        os.killpg(pgid, signum)
    except ProcessLookupError:
        return False
    return True


def leader_has_exited(process: subprocess.Popen[Any]) -> bool:
    """Non-reaping check so the leader pid (and thus the group id) stays reserved.

    ``os.waitid`` with ``WNOWAIT`` reports the exit without collecting the
    zombie. While the zombie exists its pid cannot be recycled, so a later
    ``killpg`` on the same id can only ever reach our own group. CPython does
    not expose ``waitid`` on macOS; there the check reaps, which leaves a
    theoretical pid-reuse window between the reap and the group SIGKILL.
    """
    if not hasattr(os, "waitid"):
        return process.poll() is not None
    try:
        return (
            os.waitid(os.P_PID, process.pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
            is not None
        )
    except ChildProcessError:
        # Already reaped elsewhere; nothing is left to wait for.
        return True


def wait_leader(process: subprocess.Popen[Any], timeout: float | None) -> bool:
    """Poll the unreaped leader; True if it exited before the deadline."""
    deadline = None if timeout is None else time.monotonic() + timeout
    delay = 0.005
    while not leader_has_exited(process):
        if deadline is not None and time.monotonic() >= deadline:
            return False
        time.sleep(delay)
        delay = min(delay * 2, 0.25)
    return True


def wait_group_drained(pgid: int, timeout: float) -> None:
    """Bounded courtesy wait for the group to disappear after SIGKILL."""
    deadline = time.monotonic() + timeout
    while signal_group(pgid, 0) and time.monotonic() < deadline:
        time.sleep(0.02)


def reap_group(process: subprocess.Popen[Any]) -> int:
    """Kill any survivor in the group, then reap the leader. POSIX only.

    Called whether the leader exited on its own or was stopped: a process that
    is still alive in the group after the launcher is gone is a leak (a stray
    flutter_tester would otherwise keep running into the next chunk or a
    retry). SIGKILL is sent while the leader is still a zombie, so the group
    id is guaranteed to be ours.
    """
    signal_group(process.pid, signal.SIGKILL)
    exit_code = process.wait()
    wait_group_drained(process.pid, GROUP_EXIT_SETTLE_SECONDS)
    return exit_code


def wait_chunk(process: subprocess.Popen[Any], timeout: float | None) -> int:
    """Wait for the chunk; raises TimeoutExpired without reaping anything."""
    if WINDOWS:
        return process.wait(timeout=timeout)
    if not wait_leader(process, timeout):
        raise subprocess.TimeoutExpired(process.args, timeout or 0)
    return reap_group(process)


def stop_process(process: subprocess.Popen[Any]) -> int:
    """Stop the chunk and everything it started; always returns an exit code.

    POSIX: SIGTERM to the group, a bounded grace for the leader, then SIGKILL
    to the group regardless of how the leader left (a child that ignores
    SIGTERM must not survive a parent that honoured it).

    Windows: the launcher (``cmd.exe`` for a ``flutter.bat``) is stopped with
    ``taskkill /T /F /PID <pid>``, scoped to the captured pid and its
    descendants, never a process name. Descendants whose parent has already
    exited cannot be found by that tree walk; binding the tree with a job
    object would need extra dependencies, so that limitation is documented in
    tool/qa/README.md and the fallback is a plain kill of the launcher.
    """
    if WINDOWS:
        return stop_process_tree_windows(process)
    signal_group(process.pid, signal.SIGTERM)
    wait_leader(process, TERMINATE_GRACE_SECONDS)
    return reap_group(process)


def stop_process_tree_windows(process: subprocess.Popen[Any]) -> int:
    if process.poll() is None:
        try:
            subprocess.run(
                ["taskkill", "/T", "/F", "/PID", str(process.pid)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=TERMINATE_GRACE_SECONDS,
                check=False,
            )
        except (OSError, subprocess.TimeoutExpired):
            pass
    try:
        return process.wait(timeout=TERMINATE_GRACE_SECONDS)
    except subprocess.TimeoutExpired:
        process.kill()
        return process.wait()


def report_lines(report: Path) -> Iterable[dict[str, Any]]:
    """Events of a Flutter JSON reporter file; skips non-JSON noise lines."""
    try:
        text = report.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return
    for line in text.splitlines():
        if not line.startswith("{"):
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(event, dict):
            yield event


def report_suite_results(report: Path) -> dict[str, dict[str, Any]]:
    """Per suite path: summed test time in ms (load included) and failure."""
    suites: dict[int, str] = {}
    starts: dict[int, tuple[int, int]] = {}
    results: dict[str, dict[str, Any]] = {}
    for event in report_lines(report):
        kind = event.get("type")
        if kind == "suite":
            suite = event.get("suite") or {}
            if isinstance(suite.get("id"), int) and isinstance(suite.get("path"), str):
                suites[suite["id"]] = suite["path"]
                results.setdefault(suite["path"], {"ms": 0, "failed": False})
        elif kind == "testStart":
            test = event.get("test") or {}
            if isinstance(test.get("id"), int) and isinstance(test.get("suiteID"), int):
                starts[test["id"]] = (int(event.get("time", 0)), test["suiteID"])
        elif kind == "testDone":
            start = starts.get(event.get("testID"))
            if start is None or start[1] not in suites:
                continue
            entry = results[suites[start[1]]]
            entry["ms"] += max(0, int(event.get("time", 0)) - start[0])
            if event.get("result") not in (None, "success"):
                entry["failed"] = True
        elif kind == "error":
            start = starts.get(event.get("testID"))
            if start is not None and start[1] in suites:
                results[suites[start[1]]]["failed"] = True
    return results


def relative_test_path(root: Path, path: str) -> str:
    """Map an absolute suite path from any checkout onto this repo's test/."""
    candidate = Path(path)
    if not candidate.is_absolute():
        return candidate.as_posix()
    try:
        return candidate.resolve().relative_to(root).as_posix()
    except ValueError:
        pass
    parts = candidate.parts
    options = [index for index, part in enumerate(parts) if part == "test"]
    for index in options:
        relative = Path(*parts[index:]).as_posix()
        if (root / relative).is_file():
            return relative
    return Path(*parts[options[0]:]).as_posix() if options else candidate.as_posix()


def failed_files_for(root: Path, report: Path, tests: list[str], status: str) -> list[str]:
    """Files that failed in a chunk; every unfinished file when none is named."""
    if status == "passed":
        return []
    results = report_suite_results(report)
    failed = sorted(
        {relative_test_path(root, path) for path, entry in results.items() if entry["failed"]}
    )
    if failed:
        return failed
    finished = {relative_test_path(root, path) for path in results}
    # A timeout or crash may leave no failing test event; name what did not
    # report rather than claiming the chunk had no culprit.
    return [path for path in tests if path not in finished] or list(tests)


def run_chunk(
    root: Path,
    run_directory: Path,
    chunk: dict[str, Any],
    flutter: str,
    chunk_timeout: int = DEFAULT_CHUNK_TIMEOUT,
    concurrency: int = DEFAULT_CONCURRENCY,
    json_report: bool = False,
) -> dict[str, Any]:
    index = int(chunk["index"])
    attempt = next_attempt(run_directory, index)
    chunk_directory = run_directory / "chunks"
    chunk_directory.mkdir(parents=True, exist_ok=True)
    stem = f"{index:03d}-attempt-{attempt:03d}"
    log_path = chunk_directory / f"{stem}.log"
    result_path = chunk_directory / f"{stem}.json"
    report_path = chunk_directory / f"{stem}.report.jsonl"
    command = command_for_flutter(
        flutter, chunk["tests"], concurrency, report_path if json_report else None
    )
    started_at = utc_now()
    started = datetime.now(timezone.utc)
    print(f"[{index}/{len(read_json(run_directory / 'run.json')['chunks'])}] {len(chunk['tests'])} tests")
    print("  " + subprocess.list2cmdline(command))
    exit_code: int | None = None
    status = "failed"
    try:
        with log_path.open("w", encoding="utf-8", errors="replace") as log:
            process = launch_chunk(command, root, log)
            try:
                exit_code = wait_chunk(process, chunk_timeout or None)
            except subprocess.TimeoutExpired:
                status = "timed_out"
                exit_code = stop_process(process)
                log.write(f"\nrun_serial_tests: chunk exceeded {chunk_timeout}s and was stopped\n")
            except KeyboardInterrupt:
                status = "interrupted"
                exit_code = stop_process(process)
                log.write("\nrun_serial_tests: interrupted by the user\n")
    except OSError as exc:
        log_path.write_text(f"Could not start Flutter: {exc}\n", encoding="utf-8")
        exit_code = 127
    if status == "failed" and exit_code == 0:
        status = "passed"
    ended = datetime.now(timezone.utc)
    result = {
        "schema_version": SCHEMA_VERSION,
        "run_id": read_json(run_directory / "run.json")["run_id"],
        "chunk": index,
        "attempt": attempt,
        "tests": chunk["tests"],
        "command": command,
        "started_at": started_at,
        "ended_at": utc_now(),
        "duration_seconds": round((ended - started).total_seconds(), 3),
        "exit_code": exit_code,
        "status": status,
        "chunk_timeout": chunk_timeout,
        "concurrency": concurrency,
        "log": log_path.relative_to(run_directory).as_posix(),
        "report": report_path.relative_to(run_directory).as_posix() if json_report else None,
        "failed_files": failed_files_for(root, report_path, chunk["tests"], status),
    }
    atomic_json_write(result_path, result)
    return result


def result_path_name(result: dict[str, Any]) -> str:
    return f"chunks/{int(result['chunk']):03d}-attempt-{int(result['attempt']):03d}.json"


def write_summary(run_directory: Path, metadata: dict[str, Any], status: str, error: str | None = None) -> None:
    atomic_json_write(
        run_directory / "summary.json",
        summary_for(metadata, latest_results(run_directory), status, error),
    )


def execute(root: Path, args: argparse.Namespace) -> int:
    snapshot = source_snapshot(root)
    if not snapshot["test_manifest"]:
        raise RunnerError("No recursive test/*_test.dart files were found")
    # Validate shard/concurrency arguments before anything is written.
    validate_shard(args.shard_index, args.shard_count)
    validate_concurrency(args.concurrency)

    if args.resume:
        run_directory, metadata = load_resume(root, args, snapshot)
    else:
        run_directory, metadata = create_run(root, args, snapshot)

    write_summary(run_directory, metadata, "running")
    passed = {
        result["chunk"]
        for result in latest_results(run_directory)
        if result.get("status") == "passed"
    }
    for chunk in metadata["chunks"]:
        index = int(chunk["index"])
        if index in passed:
            continue
        current = source_snapshot(root)
        if (
            current["source_fingerprint"] != metadata["source_fingerprint"]
            or current["test_manifest_fingerprint"] != metadata["test_manifest_fingerprint"]
        ):
            message = "Relevant source or the recursive test manifest changed during the run"
            write_summary(run_directory, metadata, "refused_source_changed", message)
            raise RunnerError(message)
        result = run_chunk(
            root,
            run_directory,
            chunk,
            metadata["flutter"],
            metadata.get("chunk_timeout", DEFAULT_CHUNK_TIMEOUT),
            metadata.get("concurrency", DEFAULT_CONCURRENCY),
            bool(metadata.get("json_report", False)),
        )
        if result["status"] != "passed":
            # Mirror the chunk outcome (failed / timed_out / interrupted) so a
            # reader of summary.json knows whether to fix, split, or resume.
            write_summary(run_directory, metadata, result["status"])
            print(f"{result['status'].replace('_', ' ').capitalize()}: chunk {chunk['index']} ({result['log']})")
            for path in result["failed_files"][:20]:
                print(f"  failed: {path}")
            if len(result["failed_files"]) > 20:
                print(f"  ... and {len(result['failed_files']) - 20} more in {result_path_name(result)}")
            return 1
        write_summary(run_directory, metadata, "running")

    current = source_snapshot(root)
    if (
        current["source_fingerprint"] != metadata["source_fingerprint"]
        or current["test_manifest_fingerprint"] != metadata["test_manifest_fingerprint"]
    ):
        message = "Relevant source or the recursive test manifest changed before completion"
        write_summary(run_directory, metadata, "refused_source_changed", message)
        raise RunnerError(message)
    write_summary(run_directory, metadata, "passed")
    print(f"Passed: {run_directory}")
    return 0


def main() -> int:
    args = parse_args()
    script_root = Path(__file__).resolve().parents[2]
    root = (args.root or script_root).expanduser().resolve()
    if not root.is_dir():
        print(f"error: repository root does not exist: {root}", file=sys.stderr)
        return 2
    try:
        return execute(root, args)
    except RunnerError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
