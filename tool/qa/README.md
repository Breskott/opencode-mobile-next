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
