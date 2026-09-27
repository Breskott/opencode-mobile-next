# Policy executor wiring — 2026-09-27

Finish line: existing automatic actions obey the shared per-server policy and
enter While you were away only after confirmed success.
Non-goal: new automation executors, screen redesign, remote policy mutation,
signing, releases, pushes, or the full integration-candidate test gate.

Worktree: `oc_app-codex-policy`, branch `codex/policy`, base `6ea5e83c`.
Read first: both slice-P6.1/P6.2 and codex-p61/p62 QA READMEs.

## Runtime contract for Claude

Use `AutomationPolicyController.forProfile(prefs, profileId)`; observe its
persisted `value`. Do not instantiate another writable policy. The settings
page can now expose the following supported local controls:

| Choice | Executor and confirmation |
| --- | --- |
| `allowsAutoApproval` | `ConnectionController._maybeAutoApprove`, also requiring the existing session approval choice. High supervision denies it. Only an acknowledged successful permission reply is an act; PermissionNotFound merely removes an obsolete request. |
| `reconnect` | Both event streams and lifecycle transport rebuilding. Cancels retry channels when disabled; checks again after awaited health. First/manual connects are not automatic acts; actual automatic recovery to connected is. |
| `reconcileQueuedSends` | Existing offline queue flush. Rechecks after transport/selection waits and the durable dispatch marker. Records only accepted sends whose queue removal persisted. This does not add transcript reconciliation or automatic resend of uncertain sends. |
| `restartPhoneServer` | Built-in app-exit, launch and foreground-return recovery; managed Termux recovery. Built-in start must confirm readiness. Managed native command completion is insufficient: a ready status with the reserved operation ID confirms it. |
| `pollRestartHealth` | Managed Termux recovery scheduling additionally requires this flag. It does not control manual start readiness checks. |
| `thermalRecovery` | Automatic cool-down resume, including policy checks before native/HTTP changes. Protective heat pause/stop remain enabled for safety. Unreachable or failed session wakes do not produce a resume receipt. |
| `applyCodePush` | Shorebird automatic check/download, gated again before download. A completed download is recorded under the server selected at download start; switching servers mid-download cannot move it. Existing restart-required state is not a new act. |

An action already dispatched cannot be recalled by switching policy off. A
confirmed completion is not an installation claim or a reversible operation.
Manual controls remain manual. Explicit Resend authorizes just that queued entry
even when queue automation is off, and creates no automatic-act receipt.

History uses existing `recordServerAct` / `recordAutomaticAct` and
`AutomaticActivityController.forProfile`. This checkout has no separate
`recordSessionAct` method: conversation acts use `recordAutomaticAct` with captured
project/session identity. No permission patterns, queued content, credentials or
raw exception text are added to history. Existing Inbox localization already
calls update acts “Update downloaded by itself.” No new Undo is supplied.

App-wide update acts deliberately appear in the current server's list, per the
owner decision. No selected server means no unowned automatic download. These
choices do not disable server-side saved permission rules or change host
supervision.

`AppExitNotice.recoveryAllowed` is a new backend hook. The notice UI must not say
“starting again” when false. It is permission, not proof of completion; confirmed
restart is the receipt. Cancelled built-in startup is an unconfirmed failure,
including cancellation during an awaited health probe. The current `AppExitNoticeLine` copy remains a Claude UI
hook-up item, outside this backend-only slice. No UI screen or kit was redesigned.
The existing update golden fixture supplies the new policy callbacks without
changing its visual expectations.

History-save failures remain visible through the existing
`automaticActivity.persistenceFailed` / `corruptHistory` Inbox state. Never repeat
an underlying action to repair its history. Managed restart history retries use
the same durable event ID and confirmation timestamp; other producers retain the
existing history-save error contract and do not automatically replay a lost
receipt. Policy re-enabling does not replay permission requests that arrived while
disabled or force an immediate reconnect; explicit Reconnect remains available.

## Missing executors and honest unsupported state

Do not expose these as working switches:

- Team `routeReadyWork`, `wakeStalledPool`, `restartWorkers`, `recycleWorkers`,
  `holdAtProviderLimit`, `retryUnconfirmedAnswer`, `retryTransientTask`,
  `fallBackToDirectTask`: no app-owned automatic mutation executor. Orchestration
  retry is explicitly a person-tap operation; direct-task fallback is a form and
  Send action. Gas City worker limits and `BuiltinTeam.upkeepOrder/upkeepScript`
  are host-owned routines, without a supported live per-profile policy mutation
  contract. This local policy does not claim to switch them off.
- `restartDevServices`, `stopIdleHelpers`, `cleanCaches`, `updateWhenIdle`: no
  app automatic executor. Code-push download uses `applyCodePush`, not the
  separate consent for idle housekeeping updates.
- `resumeSetup`: `ChannelSetupEngine.resume()` has no app caller. Existing restore
  observes an already running native job; Continue is an explicit person action.
- Team-specific auto-approval and merge-on-green executors remain absent; the
  approval gate here controls the existing session permission executor only.
  The Balanced/planner merge wording conflict from P6.1 remains unresolved.

Other preferences are not claimed as newly integrated: `retryIntake`,
`retryProviderErrors`, `recheckEnvironment`, `reduceEffects`, `chooseDefaults`,
`detectInstallations`, `preserveDrafts`, `followOutput`, `pollOpenPages`,
`boundedPaging`. Their UI/native/other-owner paths require separate scoped work;
this is not evidence they have no executor. `monitorOtherServers` and
`monitorQuota` retain the existing monitor/notification stores described by P6.1;
no second monitoring switch or consent migration is introduced.

## Ownership and storage

Coordinator: connection, app composition, SSE cancellation guards and their tests.
Recovery worker: app-exit/built-in/Termux recovery and tests. Update worker: update
notice and tests. Team worker: thermal recovery and tests. Contracts frozen before
parallel edits; coordinator reviews integration and serializes heavy checks.

No new preference key. Existing policy/history keys remain
`oc.automation.<profileId>` and `oc.automaticActivity.<profileId>`, with existing
profile deletion barriers. Managed state at `oc.managedServerRecovery.<profileId>`
adds optional `unreportedOperation` and `confirmedAtMs`; old records remain
readable. These retain only owned operation identity/time and are swept with the
profile. Recorder registration survives a later UI-created recovery owner and is
removed when its connection scope or managed profiles disappear.

## Verification

Pinned Flutter/Dart path:
`~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin`.

- `flutter pub get`: passed without tracked dependency changes.
- `dart format --language-version=3.10` on all changed Dart files: passed.
- Final focused serial run: **209 passed, 7 failed**, across the ten files below.
  Every new behavior test passed. The unchanged base `6ea5e83c`, in an isolated
  detached validation worktree, reproduces **the same seven failures** with the
  same selected names: five older queue-composer widget tests and two older
  phone-guidance copy tests. This is not an all-green suite claim. See
  [focused-tests.txt](focused-tests.txt) and [base-failures.txt](base-failures.txt).
- `flutter analyze --no-pub`: **No issues found** (22.3s). See [analyze.txt](analyze.txt).
- `git diff --check`: passed. Final source/test hashes are in
  [source-sha256.txt](source-sha256.txt).

Final focused command (SDK prefix as above):

```sh
flutter test --no-pub --concurrency=1 \
  test/session_auto_approval_controller_test.dart \
  test/connection_sse_test.dart test/api2_sse_test.dart \
  test/offline_queue_test.dart test/app_exit_recovery_test.dart \
  test/builtin_server_test.dart test/managed_server_recovery_test.dart \
  test/shorebird_update_notice_test.dart test/thermal_guard_test.dart \
  test/no_raw_error_text_test.dart
```

Base comparison used the same SDK/configuration and these exact name selectors:

```sh
flutter test --no-pub --concurrency=1 \
  test/offline_queue_test.dart test/app_exit_recovery_test.dart \
  --name 'sending while disconnected queues a visible draft|selection failure restores an undispatched draft without queuing|editing an unconfirmed send|discarding an unconfirmed send honors a refused deletion|on a RedMagic:|without the channel'
```

No full repository suite, emulator/device, native build, signing, deployment or
release performed. No screenshots apply to the backend/composition changes.
The adapted golden fixture was not regenerated. The final test run covers the
final implementation; earlier diagnostic runs are not combined into its count.

Implemented/enabled: the local executor gates and confirmed-act producers above.
Verified: focused behavior, with the seven reproduced base failures explicitly
retained. UI switch exposure and the app-exit notice copy are Claude's hook-up
work. Committed locally only; no push, PR, CI run, deployment or release.
