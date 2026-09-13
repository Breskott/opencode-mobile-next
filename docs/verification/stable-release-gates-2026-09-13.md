# Stable release gates — source 5e3b8a4 (1.0.42+47), 2026-09-13

Scope: the recursive local/CI source gate and the factual blocker list for
the current candidate. Non-goals: features, CI execution, signing,
publication, tags, pushes. This note is written by the release-gates worker:
it records only the checks this worker ran (Python only, no Flutter, Dart or
native process). The coordinator runs the machine-heavy checks and has
already recorded `flutter analyze`, the generated-SDK test suite (47 tests)
and the SDK integrity checks as passed on base `5e3b8a4`; those results are
not repeated or re-verified here.

Candidate: commit `5e3b8a4` on `dev` lineage (`master` `ca8bdfc` is an
ancestor, 422 commits behind), `pubspec.yaml` version `1.0.42+47`.

## What the gate is now

| Gate | Local | CI (`android-quality.yml`, `verify` job) |
| --- | --- | --- |
| Test discovery | `tool/qa/run_serial_tests.py`: every `test/**/*_test.dart`, sorted, once | Same runner, `--chunk-size 40 --chunk-timeout 1200` |
| Serial execution | `flutter test --no-pub --concurrency=1` per chunk | Same |
| Hung chunk | Stopped at `--chunk-timeout` (default 900 s, `0` opts out), recorded as `timed_out`; the whole process group is stopped | Same with `--chunk-timeout 1200`; job timeout 45 min still applies |
| Evidence | `build/traycer/serial-<id>/` (`run.json`, `summary.json`, per-chunk log + JSON) | Uploaded as `serial-test-logs-<sha>` on every non-`apk_only` run |
| Resume | `--resume <run dir>` reruns only unfinished chunks; refused when `lib/ test/ packages/ assets/ contracts/` or root config changed | n/a |
| Runner self-check | `python3 -m unittest discover -s tool/qa -p 'test_*.py'` | Step "Check the serial test runner" |

## What changed in this slice

- **CI discovery was top-level only.** `ls test/*_test.dart` listed 320 of the
  321 test files; the one nested file (`test/goldens/theme_gallery_golden_test.dart`)
  was covered only by a hand-written "Test theme goldens on Linux" step. Any
  future nested `test/<dir>/*_test.dart` would have been silently skipped.
  CI now calls the same recursive runner as the local gate, so the golden
  suite runs exactly once and new nested suites are picked up automatically.
- **Runner had no chunk deadline.** A hung `flutter test` blocked forever
  locally and consumed the whole job timeout in CI. `--chunk-timeout <s>`
  stops the chunk (terminate, then kill after 10 s), records it as
  `timed_out`, and `summary.json` mirrors that status (`failed`,
  `timed_out` or `interrupted`) instead of a flat `failed`. The local
  default is now 900 s so the promised bounded run is bounded without
  flags; `--chunk-timeout 0` is the explicit opt out.
- **Stopping a chunk stopped only the launcher.** Review of the first cut
  found that terminate/kill went to the `flutter` launcher pid alone, so
  `dart`/`flutter_tester` children survived a deadline and kept running into
  the next chunk or a retry, which is exactly the concurrency the serial gate
  forbids. On POSIX the launcher now starts in its own session and the
  runner signals that process group id (never a name or pattern): `SIGTERM`
  to the group, bounded grace for the launcher, then `SIGKILL` to the group
  regardless of how the launcher left, so a child that ignores `SIGTERM`
  dies with a launcher that honoured it. The launcher is not reaped until
  the group has been signalled, so the id cannot have been recycled; a
  vanished group (`ProcessLookupError`) is not an error. The same group
  `SIGKILL` runs after a normal exit, so nothing a passed chunk left behind
  survives it. Windows uses `taskkill /T /F /PID <pid>` scoped to the
  captured pid; its limitations (no sweep after a normal exit, orphans of an
  exited parent not found) are documented in `tool/qa/README.md`.
- **Ctrl-C could hang.** Interrupt now uses the same group stop path.
- **Golden failures poisoned resume.** `flutter test` writes diff images to
  `test/goldens/failures/` on a golden mismatch; those were hashed into the
  source snapshot, so every resume after a golden failure was refused as
  "source changed". `test/**/failures/` is now excluded from the snapshot.
- **Runner is covered.** `tool/qa/test_run_serial_tests.py` exercises
  discovery, chunking, failure, deadline, resume and process-group
  ownership with a fake `flutter` shell script (no Flutter involved), and CI
  runs it before the suite. The fake launcher can ignore `SIGTERM`, hang,
  and start a child that would outlive it; it records every pid it starts
  and the tests assert each one is gone (launcher ignoring `SIGTERM`, child
  ignoring `SIGTERM` under a launcher that honoured it, child left behind by
  a passed chunk, Ctrl-C). With the group handling reverted, four of those
  tests fail with "outlived the chunk"; with it, they pass and no test
  process is left behind after the module (checked with `pgrep` after three
  consecutive runs).

## Checks performed by this worker (Python only)

| Check | Result |
| --- | --- |
| `python3 -m py_compile` on runner and tests | ok |
| `python3 -m unittest discover -s tool/qa -p 'test_*.py'` | 20 tests, all pass in about 5 s (`fixture_server` tests are not discovered: no package `__init__`) |
| Same suite with the process-group fix reverted | 4 failures, each a recorded child still alive; leftover `sleep` children observed and cleaned |
| Workflow YAML parses; changed steps inspected | ok, 23 steps |
| Discovery dry run of the real runner against this checkout with a fake `flutter` (scratch dir, deleted) | 321 files, 0 duplicates, 1 nested (goldens), 9 chunks of 40/40/40/40/40/40/40/40/1, 2637 source files hashed |
| Old vs new discovery on this checkout | `ls test/*_test.dart` = 320; recursive = 321 |

Not run by this worker: `flutter analyze`, `flutter test`, generated-SDK
verification, `lintRelease`, `flutter build apk`, any GitHub Actions run,
anything on Windows. The coordinator has recorded analyzer, SDK tests (47)
and integrity checks as passed on the base commit.

## Release blockers for 5e3b8a4 / 1.0.42+47

1. **No serial full-suite evidence for this source.** The last recorded
   runner artifact is `docs/verification/backlog-serial-gate-2026-09-07.json`
   at `cb10259` (197 files, 1942 passed, 309 commits ago). `HANDOVER.md`
   reports "full suite 3590 green" at 1.0.42+43 with `--concurrency=4`, which
   is neither this revision nor the repo's serial gate, and has no run
   artifact. Required: one runner pass on `5e3b8a4` (321 files) with the
   `build/traycer/serial-<id>/summary.json` status `passed`, run under the
   pinned Flutter 3.47.2.
2. **`flutter analyze`**: passed on base `5e3b8a4` per the coordinator. Not a
   blocker for the base; must be re-run on the final integrated candidate.
3. **Generated SDK gate** (`tool/sdk/verify_*` integrity checks and the
   `packages/opencode_sdk/` test suite, 47 tests): passed on base `5e3b8a4`
   per the coordinator. Same re-run requirement on the final candidate.
4. **Platform CI has not run this workflow.** All recent commits carry
   `[skip ci]`; the workflow change in this slice is unverified on GitHub
   until the maintainer requests a run. Expect one job of roughly the old
   duration plus per-chunk startup for 9 chunks instead of 4 invocations.
5. **Android release lint, test-signed APK compile and signer check** are
   CI-only and pending that run (stable CI signer
   `2D010C2103CB2F78ABAACA690EAD4D45F8003A6C0A02082CD2A2AE62FD18D0EC`).
6. **Resolved during integration:** `scripts/release.sh` invokes the recursive serial runner; its safety fixture verifies a nested test and prevents Shorebird after a failed gate.
7. **Branch/tree preconditions for `release.sh`**: master-only, clean tree.
   Candidate is on `dev` lineage; a fast-forward of `master` is a maintainer
   decision.
8. **Resolved during integration:** `HANDOVER.md` marks the old parallel command as historical and directs current work to the serial gate.
9. **No release notes for 1.0.42** (`docs/releases/` ends at v1.0.33+34) and
   the readiness row "Final source and artifacts pass release gates" is still
   "Pending final candidate".

## How to close blocker 1 (coordinator)

```sh
python3 tool/qa/run_serial_tests.py \
  --flutter ~/.shorebird/bin/cache/flutter/<rev>/bin/flutter \
  --chunk-size 25        # --chunk-timeout defaults to 900 s; 0 opts out
# on interruption or a killed shell:
python3 tool/qa/run_serial_tests.py --resume build/traycer/serial-<run-id>
```

A chunk stopped at the deadline or by Ctrl-C leaves no `dart` or
`flutter_tester` behind: the runner stops the launcher's whole process group,
so a resume never runs concurrently with a leftover from the stopped chunk.

Copy `summary.json` next to this note when it reads `"status":"passed"`
with the final candidate source fingerprint; `5e3b8a4` was only the starting baseline.

Coordinator runner regression checks: 21 passed, including scoped process-group cleanup and source snapshot invalidation. SDK/contracts were unchanged during UI integration.
