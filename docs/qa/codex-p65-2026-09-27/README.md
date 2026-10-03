# P6.5 — phone-server lifecycle report (2026-09-27)

## Scope and finish line

Backend finish line: expose an observable `LifecycleReport` whose recovery
success requires health evidence from the phone server and any previously running
AI Team, using the existing Android exit and server-start contracts.

Non-goal: background budget changes, a new restart loop, native changes, UI
implementation, or a claim that interrupted agent tasks have resumed.

Base: `codex/p65`, `d97420b8`. This is the supplied isolated worktree; no other
checkout was edited. One coupled service/test slice was implemented locally.

- Read set: `AGENTS.md`; revamp `STANDARDS.md` sections 2, 3, 13 and 15 only;
  lifecycle bridge, built-in server/team services, existing recovery tests,
  `lib/main.dart` lifecycle callers, `KitRedact`, and prior force-stop QA.
- Write set: [service](../../../lib/state/lifecycle_report.dart),
  [behavior tests](../../../test/lifecycle_report_test.dart), this QA directory,
  and root `COMMIT_MSG.txt` if Git metadata cannot be written.
- Dependencies: existing `AppLifecycleBridge`, `BuiltinLinux`,
  `BuiltinServerStarter`, `AppExitRecovery`, `BuiltinTeam`, and saved phone profile.
  The programme ledger lists chat-9, programme-P4/P5 and slice-P4.4 as integration
  predecessors; this scoped service does not certify those units complete.
- Acceptance for this backend addition: no success from a PID alone; failed or
  missing health stays unconfirmed; team/unknown-service recovery cannot be
  silently omitted; stale async results cannot restore invalidated success;
  no new persistence, restart policy, background work, or secret output.
- Focused checks: pinned format, `test/lifecycle_report_test.dart`, then analyzer.

## Feasibility and current behavior

The callable contract exists: `AppLifecycleBridge.launchReport()` uses
`oc/lifecycle` and returns `AppLaunchReport` (exit classification/time and previous
service names). `AppLifecycle.kt` implements it. The pre-existing server starter
uses the saved profile credentials and waits for authenticated health; the team
has supervisor and city health methods. No new credential source is needed.

Existing startup/resume paths in `lib/main.dart` invoke
`AppExitRecovery.runOnce`, `BuiltinServerStarter.autoStartIfStopped` and
`allowAutoStart`. Explicit tap-start uses `BuiltinServerStarter.start`. These
paths were inspected, not changed. A force-stopped app executes no Dart code:
recovery here is on the next open/resume, not a promise to run while force-stopped.

Previously there was no Dart type named `LifecycleReport`. `AppExitNotice` records
the interruption before recovery completes, so it is insufficient evidence for
“everything is back”. The new read-only report supplies this missing distinction.
It neither replaces the existing recovery owner nor adds another starter.

Device feasibility is not established in this task. The existing
[force-stop record](../force-stop-2026-09-26/README.md) explicitly says its Kotlin
lifecycle path was not exercised on a device. A fixture copied from an earlier
phone exit record does not prove recovery for this candidate. Standards PROC-7
prohibits this builder from running adb/emulators or touching the phone; the
verifier must perform the recipes below. No workaround for that proof is added.

## UI hook-up

Public API: `LifecycleReportController` in
[`lib/state/lifecycle_report.dart`](../../../lib/state/lifecycle_report.dart).
It is a `ChangeNotifier` with `value`, `refresh(ServerProfile?)`, `invalidate()`,
`dismiss()` and `dispose()`. Construct one per app process with the shared
`BuiltinLinux` instance. Its default dependencies use the existing lifecycle
bridge, authenticated server probe, and built-in team health methods.

1. Keep the existing `AppExitRecovery` and `BuiltinServerStarter` owners. On a
   start/retry tap, call `report.invalidate()`, await the shared
   `starter.start(phoneProfile)`, then await `report.refresh(phoneProfile)`.
   Do not create a second starter or call start from the report listener.
2. After the existing cold-open/resume start and reconnect sequence, refresh
   using the **saved built-in phone profile**, even when a remote server is
   selected. For the non-selected phone server, await the existing
   `AppExitRecovery.runOnce` operation before refreshing. A remote/Termux/null
   profile returns `unavailable` without native or HTTP calls.
3. Listen to `value`. `exitKind` and `stoppedAt` are facts to localize; a crash
   must be attributed to the app, not described as a battery-setting problem.
   Preserve the date for exits on an earlier day. Show the one-line notice only
   when `showNotice` is true. Use “everything is back” only when
   `everythingBack` is true. It means services answer health checks, not that
   interrupted jobs or remote model requests have resumed.
4. Map `readiness` once in the presentation owner: `unchecked`/`checking`,
   `unavailable`, `stopped`, `unreachable`, `partial`, `ready`. These are typed
   facts, not raw error strings. During `partial`, the server may answer while
   the team is still recovering. The existing starter starts the team
   asynchronously, so refresh again after team readiness changes or an explicit
   foreground retry. There is deliberately no timer in this service.
5. On starter activity, backgrounding, transport loss, profile mutation/switch
   or deletion, call `invalidate()` immediately. Refresh when the relevant
   foreground operation finishes. A health result is a snapshot, not continuous
   monitoring. Invalidated/disposed or superseded refreshes cannot publish late
   success. Deletion must not schedule another refresh with the deleted profile.
6. Dismiss calls `dismiss()`; this survives refresh within the process. Dispose
   with the app owner. Replace the existing interruption notice when wiring the
   new presentation so the person does not see two notices.

The coordinator owns lifecycle wiring in `lib/main.dart`/`connection.dart`; the UI
unit owns the kit notice and English/Arabic copy. Those files are untouched.
No new Riverpod registration or generated localization changes are included.

## Security and storage

The report contains enums, a timestamp and booleans. It exposes no native
description, health response text, exception text, profile or credentials.
Credentials are used only by the existing authenticated loopback probe. Unknown
historical service names cannot yield full recovery. No new data is persisted,
so there is no preference migration, deletion sweep change or stored text needing
`KitRedact`. A future persistence/export addition must use `KitRedact`; do not
serialize the native report or profile to implement it.

The service creates no timers, services or notifications, and never changes the
six-hour dataSync budget or battery exemptions. All calls are foreground checks.

## Verification

- **Format:** completed via the Dart binary inside the pinned Flutter SDK with
  `--suppress-analytics format --language-version=3.10`. The requested wrapper
  cannot update its read-only SDK cache. Package-resolution warnings remain
  because this worktree has no resolved Flutter package configuration.
- **Behavior tests:** 15 tests added; execution blocked before test discovery by
  the pinned Flutter wrapper's read-only cache. No passing-test claim.
- **Analyzer:** attempted, blocked by the same SDK cache write. No clean-analysis
  claim. No ignores or exclusions added.
- **Diff/link checks:** whitespace and local Markdown targets checked. No edits
  to `lib/ui/`, single-owner files, native code, background policy or credentials.
- **Device/UI:** not run. No screenshots, release build, signing, push or deploy.

See [verification.txt](verification.txt) for command/error evidence. Verifier:

```bash
F="$HOME/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter"
"$F" pub get
"$F" test --concurrency=1 test/lifecycle_report_test.dart
"$F" analyze
```

After UI integration, also run the existing `test/app_exit_recovery_test.dart`
and `test/builtin_server_test.dart` serially. This is not a completed integration
gate, and old test results have not been reused.

## Device recipes for the verifier — NOT RUN

Use the final integrated candidate and synthetic tasks. Record revision, device,
Android version, exact steps, observed exit time, service health and screenshot.

| Recipe | Required observation |
|---|---|
| Start on tap | Stop the managed phone server through its existing control; tap start; notice remains unconfirmed until authenticated health succeeds. |
| Force-stop then reopen | Start server (and enabled team), force-stop from Android Settings, reopen; one correctly timed notice; success only after server and team health. |
| Crash then reopen | Use a verifier-owned controlled crash; reopen; crash attribution and health-gated recovery, with no battery-setting blame. |
| Reboot then reopen | Reboot with services running; reopen; check actual native report and recovery. Do not invent an Android-stop time if the platform supplied none. |
| Airplane mode | Toggle while running, background/reopen, restore connectivity; distinguish local loopback health from remote provider/network availability. Do not claim interrupted tasks resumed. |
| Failure and dismissal | Refuse health or leave the team unavailable; never show full recovery. Dismiss; refresh does not resurrect the notice in that process. |

## State and blockers

Implemented: **partial P6.5** — report service and behavior tests; existing startup
behavior retained. Enabled: **no new UI wiring**. Verified: formatting and static
review only; Flutter execution and device proof blocked. Committed: implementation,
tests and initial QA record in **`e38b4344`**, with the requested `[skip ci]` subject
and both attribution trailers. The subsequent QA correction could not be staged
(`index.lock`: read-only filesystem); those documentation updates remain in the
working tree, with their message in root `COMMIT_MSG.txt`. Deployed/released: **no**.

Blockers: environment (read-only Flutter cache; QA follow-up Git metadata write);
integration
(coordinator lifecycle hooks and UI notice); device proof (force-stop/crash,
reboot and airplane recipes). P6.5 is not complete or merge-ready until the
verifier clears these. No failed backend contract or unsupported-auth adapter was
introduced. Contract problems: the original device-proven finish line remains
unmet under builder PROC-7; assign that proof to the verifier rather than treat
unit fixtures as device evidence.
