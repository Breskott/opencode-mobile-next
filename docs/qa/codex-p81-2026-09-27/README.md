# P8.1 — persisted, redacted diagnostics (backend half)

Date: 2026-09-27. Worktree: `oc_app-codex-p81`, branch `codex/p81`.

Finish line: a `ReportProblem` service retains a bounded, write-time-redacted
history of errors, OCTRACE timings, Android exits and thermal readings across
process death and restart. Non-goal: UI, native changes or automatic upload.

## Scope and feasibility

Read: `AGENTS.md`, STANDARDS sections 2, 3, 13 and 15, diagnostics services,
`KitRedact`, typed exit/thermal bridges, existing diagnostics Clear action and
existing diagnostics/timing tests. No `HANDOFF.md` exists in this checkout.

Write: `lib/diagnostics/{report_problem,report_problem_capture,app_diagnostics,
perf_trace}.dart`, the two new `test/report_problem*_test.dart` files and this QA
directory. No UI, main, connection, gateway, repository or Kotlin edits.

Dependencies: existing `path_provider`, `KitRedact`, `AppDiagnosticsController`,
`PerfTrace`, `AppExitRecord` and `ThermalReading`; all are callable locally.
No remote endpoint, authentication or credential access is needed. The backend
feasibility check passed. Startup/UI integration is intentionally left to its
owner, as requested. Three independent owned slices covered storage, capture and
behavior tests; only the coordinator attempted verification commands.

## Behavior and storage

- Default app-private location: application-support directory `/diagnostics/`.
  `report_problem.json` is a version-1 snapshot; `report_problem.pending` is its
  temporary replacement. No preferences or per-profile keys are added.
- Each synchronous record redacts every string with `KitRedact` before field
  truncation or disk IO, flushes the temporary snapshot, then renames it over
  the committed snapshot. Successful return does not require a later flush.
- Defaults: 128 entries and 262,144 encoded UTF-8 bytes per snapshot. Both
  committed and temporary files can coexist (at most 524,288 bytes total).
  Oldest entries are evicted first. A record too large for a custom byte budget
  is dropped. Source/message/stack fields are capped at 128/2048/8192 runes.
- Recovery reads only the committed file, discards orphan temporary files and
  invalid/unknown-version/oversized snapshots, and reapplies current redaction
  and limits before exposing or rewriting entries. No existing format migrates.
- `clear()` removes both files and memory. Failures throw fixed, sanitized
  `StateError` messages and set `storageFailed`; failed writes do not publish
  uncommitted records. No diagnostic operation prints a filesystem exception.
- Persistence is synchronous to cover fatal-error handling and same-turn trace
  completion. Device IO latency and actual Android kill/relaunch are unmeasured;
  this is process-crash durability, not a promise about power or disk loss.
- Existing Flutter/platform error callbacks now receive redacted exception,
  stack and metadata strings. Diagnostic trace names, parents, attributes and
  log output also pass through `KitRedact`. Arbitrary loaded secrets still need
  the kit's existing exact-value registration before capture.

## UI hook-up

Public APIs are documented in
[`report_problem.dart`](../../../lib/diagnostics/report_problem.dart) and
[`report_problem_capture.dart`](../../../lib/diagnostics/report_problem_capture.dart).

The startup owner should open one service per app process, after bindings and
credential redactor registration, and retain it with its capture adapter:

```dart
final report = await ReportProblem.open();
final capture = ReportProblemCapture(
  report: report,
  diagnostics: appDiagnostics, // the same instance given to error capture
  thermalReadings: thermalBridge.readings(), // optional existing bridge
);
```

Handle an open failure using fixed local copy, never the raw error. No service
is opened automatically by this change, because `lib/main.dart` is out of scope.
Use the existing thermal subscription's stream when available; do not add a
second native listener just for this service. No new notification path is added.

`ReportProblem` is a `ChangeNotifier`: listen to `entries` and `storageFailed`.
Entries are immutable and oldest-first, with `kind`, `timestamp`, `source`,
`message` and `stack`. `recordError(error, stack, source: ..., at: ...)`,
`recordTiming(span)`, `recordAndroidExit(record)` and
`recordThermal(reading, at: ...)` are synchronous write boundaries. The adapter
already captures existing/live errors and completed timings; do not double-feed
those methods. It imports at most the report capacity of preexisting timings.
Repeated errors produce another event when the process controller coalesces one.

Existing Android exit diagnostics already enter via `source: android.exit` as
error events. For the typed `androidExit` category, the startup owner should feed
the existing `AppExitRecord` to `recordAndroidExit` once when fetched; avoid
duplicating the same exit through both paths. The service does not poll Android
or invent an exit reason. Thermal events use the provided stream; unavailable
platform data remains unavailable.

Take one `final preview = report.reportText()` for the exact Copy/Share preview
and reuse that same value for the user's explicit action. `reportJson()` is the
structured equivalent. Neither API uploads anything or selects a destination.
Use `ReportProblem.notificationText(raw)` and `ReportProblem.logText(raw)` for
diagnostic copy before passing it to the app's existing notification/log owner;
these helpers only sanitize and bound strings, never post or print. Copy of
technical report text must still use the kit's redacting Copy API.

**Clear data:** the existing diagnostics screen calls
`AppDiagnosticsController.clear()`. Once this adapter is attached, that action
also synchronously clears the persisted report, even with an empty process
error buffer after restart. Old timing history is not replayed after clear.
Observe `report.storageFailed` before showing success and offer retry if set.
A future general clear-data action can call `report.clear()` directly; Android's
system Clear storage removes the app-private directory too. If a profile-delete
flow is intended to erase this global report, its connection owner must call
`report.clear()` there; no profile-specific persistence is introduced here.

For shutdown, `await capture.close()` before disposing the source controllers
and `report`. Closing does not delete history. Retain the adapter for the process
lifetime rather than recreating it whenever a screen opens.

## Validation

Pinned SDK:
`~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`.

The requested Flutter test command was attempted and failed before test startup:
the wrapper writes `bin/cache/engine.stamp.tmp.*` and `engine.realm`, outside this
sandbox's writable roots. [Saved output](flutter-test.txt). The requested Flutter
analyzer wrapper has the same block: [saved output](flutter-analyze.txt).

Offline resolution using the pinned SDK's Dart binary produced a local package
configuration from cached dependencies. Its final pub-cache active-root write
was denied; no package source or lockfile was changed.
[Saved output](pub-get.txt).

The same pinned SDK's direct `bin/cache/dart-sdk/bin/dart --suppress-analytics`
can format/analyze without modifying the read-only Flutter cache. Formatting
uses `format --language-version=3.10` on all six changed Dart files.
[Formatting output](format.txt). Whole `lib test` analysis uses
`analyze lib test`; [analysis output](dart-analyze.txt).

Verifier commands, to run serially in a writable pinned Flutter environment:

```bash
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter test --concurrency=1 test/report_problem_test.dart
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter test --concurrency=1 test/report_problem_capture_test.dart
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter test --concurrency=1 test/app_diagnostics_test.dart
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter test --concurrency=1 test/perf_trace_test.dart
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter analyze lib test
```

New behavior coverage includes all four event kinds across reopen without
dispose, disk/report/notification/log redaction using fake keys, real trace-log
and forwarded-error redaction, count/UTF-8 limits, malformed snapshot recovery,
interrupted writes, clear/restart, deletion/write failures, subscription cleanup,
out-of-order timing completion and synchronous same-turn persistence.
Tests have **not executed**, so neither passing runtime evidence nor a
failing-before/fixed-after regression record is claimed. No goldens/UI changes,
full suite, APK, device, network, signing or release checks were attempted.

## State

Implemented: backend service and adapters. Enabled: startup integration pending.
Verified: formatting passed (six files, zero final changes); whole `lib test`
analysis passed with **No issues found**; diff/QA-link checks passed. Behavior
verification remains blocked by the environment.

Committed: **no**. `git add` failed because the worktree's Git metadata is on the
read-only parent checkout; [saved error](commit.txt). All changes remain in the
working tree. The exact requested commit message and both attribution trailers
are in [`COMMIT_MSG.txt`](../../../COMMIT_MSG.txt). Deployed/released/pushed: no.
