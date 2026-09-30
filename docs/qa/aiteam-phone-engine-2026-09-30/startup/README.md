# B-1: legacy team startup after app restart

Finish line: reuse a live healthy legacy city without invoking a blocking registration command, and bound/cancel background startup observation without reporting an unready task store as ready.

Non-goal: migrate or delete the old Gas City profile/project data, change the UI, or claim that shortening observation accelerates Dolt/database startup. Phone-engine startup and legacy Gas City startup are separate runtimes.

## Root cause and limits

The integrated APK 2079 report describes the old Gas City team on the emulator, not the new Rust engine. `main.dart` wires app-exit recovery to `BuiltinTeam.ensureRunning(observe: true)`. `AppExitRecovery._reviveTeam` selects only `BuiltinTeam.isBuiltinConfig(profile.orchestration)`; `phoneEngine` configurations already cannot enter that callback.

`BuiltinTeam._observe` entered the “Opening the task store” step, then polled `/v0/city/phone/health` for up to **six minutes**. That signal means the legacy city and its Dolt/bead store have loaded. Recovery does not run `gc init`, reinstall tools, or execute the new engine's per-binary proof. Previous API 35 evidence in `docs/qa/aiteam-builtin-2026-09-24/README.md` measured 2.9 minutes waiting for city health on first start and about four minutes to restart an existing team. Thus the reported 3.5 minutes matches the existing legacy database startup behavior. No trace from APK 2079 identifies an individual database operation, and this change does not invent one.

The legacy supervisor can also compete with ordinary chat for CPU/processes. These changes do **not** establish that GLM's 115-second first response was caused by that competition. The fresh model's 13-second response and upstream/provider timing differ. A coordinator migration decision is still needed to retire legacy recovery for old Gas City profiles; old configuration/data is preserved here.

## Changes

- Explicit legacy start checks live city health before registration. A healthy existing city skips `gc register`, whose CLI can wait for up to 60 seconds under proot, and keeps its existing service. There is no cached ready flag: readiness comes from the current HTTP health response.
- Background recovery observes the store for 60 seconds, configurable as `recoveryStoreTimeout`. A timeout is a real `BuiltinTeamException(timedOut: true)` on the store step. It leaves the still-running legacy service alone and does not mark the store step complete. An explicit cold start retains its existing longer health budget.
- Probe deadlines now bound each awaited health/status request, including a request that never completes. Stop, turn-off and remove invalidate the shared progress generation and cancel observation immediately. A late health response cannot complete a canceled or timed-out step.
- No native/API changes, tool installation changes, profile migration, data deletion, or UI edits.

## Regression coverage

`test/builtin_team_startup_test.dart` checks healthy start reuse, healthy app-recovery reuse without install/register, registration of an unhealthy city, a hanging city health request timing out without false readiness, and Stop/Off/Remove canceling a hanging observer while ignoring a late success.

Affected checks: `test/builtin_team_startup_test.dart`, `test/builtin_team_test.dart`, `test/builtin_team_removal_test.dart`, and `test/builtin_team_hot_test.dart`; repository analyzer at the integration checkpoint.

Validation at this slice commit: Dart formatter completed for the two backend files and the new focused test. Flutter tests/analyzer are deferred to the coordinator's machine-locked run; no emulator timing or device runtime pass is claimed here.
