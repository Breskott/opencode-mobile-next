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

## Fixed F2/F3

Follow-up base: `42d3932d` on `codex/policy`, after the policy work was merged
into `feat/phone-setup-v2`. Findings:
[branch audit F2/F3](../codex-audit-2026-09-27/README.md#f2--p2-an-aborted-profile-removal-already-erased-activity-history-and-undo).
Finish line: an aborted removal retains activity and usable Undo, and unreadable
queued work never loses its server through a missing confirmation snapshot.
Non-goals: queue repair tooling, a destructive unreadable-data override, screen
redesign, native changes, other audit findings, publishing or pushing.

### Deletion and owner contract

`ConnectionController.deleteProfileAndLocalData` remains the only cascade owner.
It closes admission and invalidates old auth/credential/MCP callback scopes
synchronously, then uses the existing profile-deletion and queue write lanes.
Activity `prepareForDeletion()` and policy `pauseForDeletion()` retain their
shared instances, stored data and inverse callbacks. Already admitted writes and
Undo finish before acquiring the queue lane, so an inverse which uses that lane
does not deadlock. New activity mutations pause until commit or cancellation.

Inside the queue lane, the controller independently verifies readability on
**every** removal, including calls with no plan and `keepQueuedPrompts: false`.
Keeping prompts requires a non-null, current plan from
`inspectQueuedPromptsForRemoval`. Preservation finishes before destructive
cleanup. A repaired persisted queue is read afresh instead of trusting an empty
cache from a prior failed decode. New prompts for the removing server cannot
arrive after source cleanup; other servers remain usable.

The first scoped-key sweep excludes `oc.automaticActivity.<profileId>` and
`oc.automation.<profileId>`. These are erased only after the profile-row/Keystore
commit, with refused final cleanup reported as incomplete. Queue/stash failures,
stale plans, and refused profile writes retain history and Undo. `cancelDeletion`
reopens the **same** activity and policy owners; monitor and auth admission also
resume. Monitor callback epochs stay invalid, and quota credential-consent
retirement survives cancellation. Shelf Undo revisions remain separate from
stale external-request revisions. No new durable key or stored-format migration.

This preserves the cascade's existing partial-cleanup semantics after queue
preservation succeeds: a later refusal may leave safely kept drafts and already
cleared local settings. It does not promise to roll back every storage operation.
Phone recovery is disabled only after queue preflight/preservation succeeds; a
later partial cleanup can leave that choice disabled.

### UI hook-up contract for Claude

- Servers must inspect first. An inspection failure shows
  `serversRemoveQueuedUnreadable(name)` using `KitNotice` and redacted
  `productErrorDetails(error)` in `KitDetailsFold`; it opens no confirmation and
  calls no deletion method. The server and source blob remain available.
- Pass the exact plan to `deleteProfileAndLocalData`, with the person's Keep or
  Delete choice. A readable zero-count plan is valid; `null` is not an empty plan.
- `QueuedPromptRemovalException.unreadable` is distinct from `changed` and a
  failed preservation write. An unreadable race after confirmation uses the same
  recoverable notice. Retry means inspect again, then confirm again.
- Respect `DeleteProfileResult.removedProfile` and `partialDeletionMessage`.
  Post-commit cleanup refusal must not be presented as complete erasure.
- No destructive fallback was added. A future unreadable-data discard requires a
  separately explained, explicit decision and a separately reviewed API.

English copy is in `app_en.arb`; `flutter gen-l10n` regenerated the localization
outputs (Arabic currently falls back to English for this new string). Screens
only arrange existing kit parts. To satisfy the requested inherited gates, three
existing team copy strings now use Server / a four-word title. The raw-error
scan's existing transcript-export exception now matches the already-redacted
`put` helper; its allowlist did not grow and no chat screen was edited.

### Follow-up verification

All checks use the pinned SDK above, `dart format --language-version=3.10`, and
serial heavy invocations through `OC_TEST_SLOTS=1 tool/qa/machine_lock.sh`.
Coordinator alone ran Flutter checks; bounded workers owned activity/policy,
Servers copy/tests, and deletion regressions. Connection remained single-owner.

Fail-before evidence: the initial owner/UI run failed on missing reversible
owner methods and the unreadable-queue confirmation being shown. The controller
red run had **32 passed, 14 failed**: nine new F2/F3 regressions plus four activity
preparation cases and one policy pause case. These tests were written and run
before their production fixes.

- `flutter pub get`: passed; no dependency-file changes.
- `flutter analyze --no-pub`: **No issues found** (30.8s).
- Format check: **18 Dart files, zero changes**, language version 3.10.
- The focused 12-file run passed **284 tests in 11 unchanged files**, including
  `automatic_activity`, `automation_policy`, `profile_deletion`, both monitors,
  queue preservation, and all required gates: `kit_ratchet`, `redaction`,
  `kit/kit_redact`, `ui_glossary`, and `no_raw_error_text`.
- The remaining file, `queued_prompt_removal_wiring_test.dart`, passed **all 17
  tests** on its focused rerun. An initial new assertion incorrectly assumed
  insertion order for a timestamp-sorted queue; its corrected assertion checks
  membership. Production behavior did not change for that correction.
- `test/revamp/queued_prompt_removal_test.dart --plain-name behaviour`: **7 passed**.
- Three focused cross-profile queue/count/banner checks: **3 passed**.
- Expanded checking also found **nine unrelated existing failures**. An unchanged
  detached checkout of `42d3932d` reproduced all nine: five older queue widgets,
  two sign-in widgets, and two Saved prompts goldens (obsolete subtitle copy).
  Base run: **61 passed, 9 failed**. No baselines were regenerated or failures
  suppressed. The temporary validation worktree was removed afterward.
- `git diff --check`: passed. No full repository suite, device/emulator run,
  native build, signing, push, release or deployment was performed.

The new regression cases cover stale confirmation, failed preservation, scoped
setting refusal, profile-row refusal, malformed JSON, wrong preference type,
missing Keep snapshot, storage repair/retry, late queue admission, committed
cleanup refusal, admitted activity writes/Undo, and quota consent retirement.

Evidence: [failing-before cases](f23-red-tests.txt),
[base failure comparison](f23-base-failures.txt),
[final source/test hashes](f23-source-sha256.txt).
Commands, using the pinned SDK and the machine lock:

```sh
flutter test --no-pub --concurrency=1 \
  test/queued_prompt_removal_wiring_test.dart test/automatic_activity_test.dart \
  test/automation_policy_test.dart test/profile_deletion_test.dart \
  test/profile_monitor_test.dart test/provider_quota_monitor_test.dart \
  test/queued_prompt_removal_test.dart test/kit_ratchet_test.dart \
  test/redaction_test.dart test/kit/kit_redact_test.dart \
  test/ui_glossary_test.dart test/no_raw_error_text_test.dart
flutter test --no-pub --concurrency=1 test/queued_prompt_removal_wiring_test.dart
flutter test --no-pub --concurrency=1 \
  test/revamp/queued_prompt_removal_test.dart --plain-name behaviour
flutter analyze --no-pub
```

Implemented and verified: F2/F3 controller and Servers behavior, with the required
gates passing. The separate base failures above remain outside these fixes.
Local commit only; no push.

## Audit merge integration — 2026-09-28

Merged `feat/phone-setup-v2` at `98c4c67a`. Kept one Servers queue-read blocker and its recoverable Details flow, the audit credential-registration and product-failure mapping, and the F2 reversible-owner/committed-erasure transaction. English localization keeps both sets of keys without duplicate removal copy. The raw-error allowlist has no additions.

Pinned Flutter verification: 328 focused controller, credential-ingress, persistence and gate tests passed; all 7 Servers removal behavior tests passed; `flutter analyze` found no issues (57.0s). `dart format --language-version=3.10` and the staged diff whitespace check passed. No push or release performed.
