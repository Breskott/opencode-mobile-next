# revamp-slice-P8.1: P8.1 Persisted, redacted diagnostics (2026-09-27)

## 1. Scope

- Unit: `slice-P8.1` (wave 3, programme-slice P8). Finish line: a ReportProblem
  service keeps a persisted ring buffer (errors, OCTRACE timings, Android exit
  reasons, thermal events) that survives a crash and a restart, redacted at
  write time. Non-goal: no UI.
- Builds on the Codex backend half (`docs/qa/codex-p81-2026-09-27/README.md`,
  commit `0fb09740`): `ReportProblem` and `ReportProblemCapture` already existed
  but nothing opened them. This unit is the startup integration.
- Files changed:
  - `lib/diagnostics/report_problem_startup.dart` (new): `ReportProblemStartup`,
    the one per-process holder. `start(diagnostics)` opens the store, attaches
    capture, and on failure records one fixed line (`openFailedMessage`, source
    `report-problem`), never the raw filesystem error. `ready`/`current` let
    later callers reach it; `recordAndroidExit` skips an exit already kept
    (same timestamp); `recordThermal` keeps status changes only, never
    `unknown`. Store failures never throw into callers.
  - `lib/main.dart` (one line + import): `unawaited(ReportProblemStartup.start(diagnostics))`
    right after `installAppErrorCapture`, before `runApp`.
  - `lib/diagnostics/report_problem_capture.dart`: additive
    `typedAndroidExits` option (default false); when true, diagnostics errors
    from `android.exit` are not stored a second time.
  - `lib/builtin/app_exit_recovery.dart`: `runOnce` gains optional
    `problemReport` (default `ReportProblemStartup.ready`) and feeds a notable
    exit's typed `AppExitRecord` to it, without blocking recovery.
  - `lib/builtin/thermal_guard.dart`: optional `onReading` callback, called in
    `observe` (reuses the guard's one native listener; a throwing callback is
    recorded in diagnostics, the guard continues).
  - `lib/builtin/thermal_guard_teams.dart`: `startThermalGuard` passes
    `ReportProblemStartup.current?.recordThermal`.
  - `test/report_problem_startup_test.dart` (new, 7 tests).
- Pages (map ids): none (no UI).
- Specs followed: STANDARDS.md §1, §15, §16; AGENTS.md security invariants
  (credentials never reach logs, diagnostics, notification copy or test output).
- Contract problems (PROC-20): the computed task names the record
  `docs/qa/revamp-<unit id>/README.md`; STANDARDS EVID-1 requires the dated
  folder. The rulebook wins, so this record is at
  `docs/qa/revamp-slice-P8.1-2026-09-27/`. The unit's `after: ["chat-9"]` is
  unrelated to its write set; no chat file was touched.
- New kit parts (KIT-3): none.
- Moved or removed items (owner rethink rule): none, no page changed.
- Map items (EVID-11): n/a, the unit has no pages.
- States per page (STATE-20): n/a, no pages.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/slice-P8.1`, base `5177502d` (revamp/wave3), code head
  `737899a5`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work (see
section 6, emulator steps).

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/report_problem_startup_test.dart` with `typedAndroidExits: false` and the guard's `onReading` call removed | the exit and thermal tests fail on assertions | 2 failed (duplicate `android.exit` entry; 0 thermal entries): `failing-first.txt` | PASS |
| 2 | `test/report_problem_startup_test.dart` | passes | 7 passed | PASS |
| 3 | `test/report_problem_test.dart`, `test/report_problem_capture_test.dart` (Codex's backend tests, never executed before) | pass | 32 passed | PASS |
| 4 | `flutter analyze` on the six changed lib files and the new test | no issues | No issues found | PASS |

Not run (owner speed rule): the rest of the suite, including
`test/app_exit_recovery_test.dart` and `test/thermal_guard_test.dart`, whose
call sites only gained optional parameters.

## 5. Evidence

- `failing-first.txt`: output of step 1.
- Acceptance evidence:

  | Acceptance | Test (`test/report_problem_startup_test.dart` `--plain-name`) |
  |---|---|
  | Survives a crash and restart, all four kinds | "start opens once, imports what came before, and keeps every kind redacted on disk across a crash and reopen" (reads the file with no dispose/flush, then reopens) |
  | Redaction with fake keys: diagnostics, report | same test: registered key, `Bearer` token and password through a diagnostics error, its stack, an OCTRACE attribute and a typed exit description; the raw file, `reportText()` and `reportJson()` carry none |
  | Redaction: notifications and logs | "notification and log copy made from the report stays redacted" |
  | Size-bounded | "the report stays within its entry and byte bounds" (5 entries, 4096 bytes) |
  | Clear-data erases it | "the diagnostics Clear action erases the saved report, also after a restart" (the app's clear action is the diagnostics screen's Clear, `AppDiagnosticsController.clear`) |
  | Typed Android exit, once | "exit recovery keeps the typed exit once, without an error copy, and not again after a restart" |
  | Thermal events | "the thermal guard hands its readings to the report: changes only, no unknowns" |
  | Open failure is quiet and fixed | "a store that cannot open leaves one fixed diagnostics line" |

- Changed test expectations (TEST-19): none.
- Goldens changed: none.
- Accessibility: n/a, no UI.
- Privacy and security: the report stays app-private
  (`<app support>/diagnostics/report_problem.json`), is never uploaded, logged
  or notified by this unit, and every string passes `KitRedact` before disk.
  Limitation carried from the backend: a secret is masked by exact value only
  after it is registered with `KitRedact.registerKnownSecret`; pattern-shaped
  values (Bearer, `password=`, `sk-…`) are masked always. A profile's deletion
  does not clear this global report (no per-profile data is stored in it).
- Migration: new stored file (version 1 snapshot); no existing format changes.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/report_problem_startup_test.dart test/report_problem_test.dart test/report_problem_capture_test.dart
$F analyze lib/diagnostics lib/builtin/app_exit_recovery.dart lib/builtin/thermal_guard.dart lib/builtin/thermal_guard_teams.dart lib/main.dart test/report_problem_startup_test.dart
```

Emulator proof (coordinator; release APK from this branch, API 34 x86_64 AVD):

1. Install and open the app; connect to any server so some errors/timings exist.
2. `adb shell run-as io.github.eslamasabry.opencode_mobile cat files/diagnostics/report_problem.json`
   (`getApplicationSupportDirectory()/diagnostics`, on Android
   `/data/data/io.github.eslamasabry.opencode_mobile/files/diagnostics/`).
   Expect `"version":1` and `timing` entries (`OCTRACE`).
3. Crash the process: `adb shell am crash io.github.eslamasabry.opencode_mobile`
   (or `adb shell kill -9 <pid>` for a low-memory-like kill).
4. Reopen the app; wait for the shell. Read the file again: the earlier
   entries are still there, plus one `androidExit` entry (`crash reason=4 …`)
   and no `android.exit` error copy of it.
5. `grep` the file for any provider key or server password in use: no match.
6. Open Settings > Diagnostics, tap Clear and confirm: the file is gone
   (`ls files/diagnostics/` shows neither `report_problem.json` nor `.pending`).
7. Paste a redacted excerpt of steps 2 and 4 into the wave checkpoint record.

## 7. NOT proven

- Not run on a device or emulator; the crash-and-reopen log excerpt is the
  coordinator's (section 6).
- Synchronous write latency on a real phone is unmeasured.
- Thermal readings that arrive before the store finished opening are not kept
  (the guard starts after bootstrap, normally later than the open).
- Errors recorded before `KitRedact` knows a loaded secret are masked only by
  pattern, not by exact value.
- The other suites (`app_exit_recovery_test`, `thermal_guard_test`, the full
  suite) were not re-run under the owner's speed rule.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/slice-P8.1` |
| Enabled | Yes: opened at every start from `main()` | `lib/main.dart` |
| Verified | Unit tests and analyzer only | this record |
| Committed | Yes | `revamp/slice-P8.1` |
| Deployed | No | |
| Released | No | |
