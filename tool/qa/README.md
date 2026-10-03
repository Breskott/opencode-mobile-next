# Verification runner

`run_serial_tests.py` discovers every `test/**/*_test.dart` file recursively,
sorts the manifest, and runs bounded chunks one at a time with
`flutter test --no-pub --concurrency=1`. It retains stdout/stderr logs and one
JSON result per chunk attempt under `build/traycer/serial-<run-id>/` by default.

Start a run with an explicit Flutter executable (use the full `.bat` path on
Windows):

```powershell
python tool/qa/run_serial_tests.py `
  --flutter 'C:\path\to\flutter.bat' `
  --chunk-size 25
```

Resume an interrupted or failed run:

```powershell
python tool/qa/run_serial_tests.py --resume build/traycer/serial-<run-id>
```

The default output location is `build/traycer/serial-<run-id>`.

## Deadline and process ownership

Every chunk is bounded: `--chunk-timeout` defaults to 900 seconds and a chunk
that exceeds it is stopped and recorded as `timed_out`. `--chunk-timeout 0`
opts out explicitly (the run is then only bounded by the outer shell or CI
job). On resume the stored value applies unless a new one is passed.

Stopping a chunk stops everything the chunk started, not just the `flutter`
launcher:

- **POSIX** (Linux, Termux, macOS): the launcher is started in a new session,
  so its pid is the id of a process group the runner owns. Deadline and Ctrl-C
  send `SIGTERM` to that group, wait up to 10 s for the launcher, then send
  `SIGKILL` to the group whether or not the launcher left (a `flutter_tester`
  that ignores `SIGTERM` must not survive a launcher that honoured it). The
  same group `SIGKILL` runs after a normal exit, so a process left behind by a
  passed chunk never runs into the next chunk or a retry. Signals go only to
  the captured group id, never to a process name or pattern; the launcher is
  not reaped until the group has been signalled, so the id cannot have been
  recycled. Because the launcher is in its own session, a terminal Ctrl-C
  reaches the runner only; the runner then stops the group.
- **Windows**: the launcher (`cmd.exe` running `flutter.bat`) and its
  descendants are stopped with `taskkill /T /F /PID <pid>`, scoped to the
  captured pid. Limitation: the tree walk cannot find descendants whose parent
  already exited, and nothing is swept after a normal exit; binding the tree
  to a job object would need extra dependencies. If `taskkill` is unavailable
  the launcher alone is killed. This path is exercised only with mocks in
  `test_run_serial_tests.py`; it has not been run on a Windows machine.

`run.json`, `test-manifest.json`, and `source-manifest.json` record the run
snapshot. Resume is refused when application code, tests, assets, contracts,
SDK packages, Flutter configuration, or the helper scripts and native/release
contracts inspected by tests change. The exact paths are listed in
`SOURCE_DIRECTORIES` and `SOURCE_FILES` in the runner. Local signing credentials
are not included. Generated golden-failure images and tool caches are excluded.
Old chunk logs/results are retained; retries receive a new attempt number.

## Shards, concurrency and the fast local run

`--shard-index I --shard-count N` (1-based) runs one of N disjoint shards. The
split is a deterministic longest-first partition weighted by
`test_timings.json` (seconds per file, load included); a file missing from it
weighs the median. Every file lands in exactly one shard, so the N shards
together are the full suite. A sharded or `--concurrency C` run schedules the
heaviest files first; the default (one shard, `--concurrency 1`) keeps the
sorted serial order and command line `scripts/release.sh` uses. Shard
arguments are part of the run snapshot (resume refuses different ones);
concurrency, like the deadline, can be overridden on resume.

`--json-report` also writes each chunk's Flutter JSON report
(`chunks/*.report.jsonl`) so `summary.json` lists `failed_files`. Refresh the
weights from reports, preferably of a serial run:

```bash
python3 tool/qa/update_test_timings.py build/traycer/*/chunks/*.report.jsonl
```

`run_tests_fast.sh` is the fast full local run: 4 shards side by side, each
`--concurrency 2` and holding one `machine_lock.sh` test slot, then
`summary.txt`/`summary.json` with each shard's status, the failing files and
an every-file-exactly-once coverage check. CI (`android-quality.yml`) runs the
same runner as a 6-shard matrix with `--concurrency 4`.

# Commit rules check (opt-in)

`check_commits.sh` (STANDARDS.md G33, PROC-14) checks a branch's commits
before a merge: every message carries `[skip ci]`, a non-merge commit has a
body and ends with a `Co-Authored-By:` trailer block, and every Dart file the
range changed passes `dart format --language-version=3.10`.

```bash
tool/qa/check_commits.sh feat/phone-setup-v2      # <base> [<head>]
```

It is opt-in: the repository installs no git hook, because a hook in a
shared `.git` (or `core.hooksPath`) would run on every agent's commits in
every worktree. Its `--message-file` mode can back a personal commit-msg hook
in a checkout only you use.
