# Second adversarial audit — 2026-09-28

Audited base: `7a99b8f8`, a clean `codex/audit` worktree. Comparison:
`git diff d0a8abcc..7a99b8f8` (674 changed files, including documentation,
generated localization and screenshots). Finding locations below describe that
base unless explicitly identified as fix APIs. This is a prioritized review of
the requested security, storage, native and lifecycle changes, not a claim that
every changed line or platform execution path was exhaustively verified.

Finish line: reproduce actionable risks, fix clear issues outside Claude-owned
files in separate commits, and hand off exact fixes for owned screens. Non-goals:
visual redesign, changing product consent, touching live servers or credentials,
signing, release, pushing, or editing chat, team-page or glass production files.

P1 = high, P2 = medium, P3 = low. Reproductions use synthetic fixtures, fake
transports/platform storage and the real app boundaries described below. No live
credential, production server mutation or device process-death experiment was
used. Raw fixture payloads are not printed by the new regression assertions.

## Ranked findings

| ID | Severity | Finding | Disposition |
| --- | --- | --- | --- |
| A1 | P1 | Protocol adapters promote server error text to trusted product copy | Fixed, `0436b230` |
| A2 | P2 | Task Details timeline renders unredacted server error/activity text | Claude team handoff |
| A3 | P2 | OAuth codes/state survive link Details and Copy | Fixed, `fa9d1eba` |
| A4 | P2 | Worker-message acknowledgement clears a newer composer draft | Claude chat handoff |
| A5 | P2 | Managed profile removal edits an already-paused policy and fails | Fixed, `ffb852ab` |
| A6 | P2 | Late recovery and alias-budget writes can recreate deleted keys | Fixed, `5812c904` |
| A7 | P2 | Late manual-start claim can recreate the deleted built-in owner pointer | Fixed, `7ff34ba6` |
| A8 | P2, latent | New mobile-download consent facade can reopen after deletion | Fixed, `336a3f8a` |

### A1 — Server prose is laundered through ProductException

**Locations:** `lib/api2/gateway_operations.dart:498–502`,
`lib/api/product_repository.dart:474–486,2554–2555`, and the trust boundary in
`lib/domain/product_failure.dart:53`. The new domain mapper treats
`ProductException.message` as app-authored, but these adapters fill it from
`Api2Error.message`, typed worktree payloads, or upgrade-result errors.

**Scenario:** a server rejects an operation with a short explanation containing
an opaque provider credential. Even when that credential is registered with
KitRedact, the adapter places the server string in the visible error body.
Recognizing the exception wrapper as local is not proof its text is local.

**Fix:** preserve each existing authored operation fallback; keep the protocol
exception/result only in `cause`, which the Details mapper redacts. No raw
server text is classified as safe based on prose shape. No SDK generation or
new localization copy was needed.

**Proof:** all four cases in `test/audit2_product_error_mapping_test.dart`
failed before the change and pass afterward: real OC2 background operation,
OC1 worktrees, and upgrade rejection with HTTP 400 and HTTP 200/`success:false`.
Each checks both visible body and retained, redacted Details. The existing
worktree test now expects authored copy and a preserved technical cause.

### A2 — The technical timeline's arbitrary child bypasses redaction

**Locations:** `lib/ui/screens/team/task_details_sheet.dart:768–769,811`.
`_eventText` returns `ActivityAppended.summary` and `RequestResult.errorMessage`
unchanged, and `_EventRow` passes them directly to `KitRow.title`. A
`KitDetailsFold` masks its structured values, not an arbitrary child subtree.

**Scenario:** a task event includes an echoed credential or raw request error.
Expanding technical Details displays that value unchanged. Being under Details
does not waive the redaction requirement.

**Exact owner fix:** sanitize every untrusted timeline text at its presentation
boundary with `KitRedact.text`, including server-derived names in composed
sentences; keep the technical timeline under Details. Do not pass a raw event
body to ordinary status copy or announcements. Add a task-scoped RequestResult
and ActivityAppended fixture with a registered opaque secret and a named-token
marker; expand the fold and assert neither reaches rendered text or copy.

**Proof status:** source-confirmed; no new failing widget probe was committed or
run for these Claude-owned files. The existing four gates do not establish that
arbitrary child content is redacted. No team production file was edited.

### A3 — Authorization parameters are not ordinary prose secrets

**Location:** `lib/ui/widgets/external_link.dart:87`. Applying only
`KitRedact.text` to the URL masks named passwords/tokens, but not opaque OAuth
`code` or `state` parameters.

**Scenario:** a server-provided authorization URL reaches the shared confirmation
sheet. The person expands Details or selects Copy link, exposing an authorization
code that does not have a known secret prefix. This requires the explicit copy
action; it is not automatic clipboard exfiltration.

**Fix:** redact decoded query/fragment parameters, including OAuth code/state and
SPA callback fragments, for display and copy. Preserve ordinary links and the
original URI solely for the explicitly approved launcher. Malformed encoded
values are masked rather than trusted.

**Proof:** the real `external_link_test.dart` dialog failed on `?code=` before
the change. Query code, fragment state, SPA callback code, Details, clipboard and
unchanged approved launch now pass. The proposed `%74oken` case already passed
because Dart normalizes that parameter; it remains coverage and is **not**
claimed as a reproduced defect.

### A4 — Sending to a worker can erase the person's next words

**Locations:** `lib/ui/screens/chat/watching.dart:247–257` and
`lib/ui/kit/chat/kit_composer.dart:515`. `_send` awaits `onSend`, then clears the
whole controller and persisted draft. The field remains editable while sending.
The removed team message sheet had explicitly disabled its field during send.

**Scenario:** submit message A, type message B while the host acknowledges A,
then receive success. The acknowledgement clears B and deletes its saved draft.

**Exact owner fix:** capture the submitted full text, draft owner and edit
revision. Clear only if that same submitted revision is still current after the
acknowledgement; retain and persist subsequent edits. Compare revisions, not
only trimmed strings (editing away and back is still an edit). Preserve rejection,
route/session switching and disposal behavior. Alternatively explicitly disable
editing with the kit's supported control, if the owner chooses that interaction.

**Proof status:** source-confirmed, not a newly executed widget reproduction.
Owner test: delay the real watch `onSend` future, edit while pending, acknowledge
success and verify the new text and restart-restored draft; also cover unchanged
successful submission, rejection, edits away/back and disposal. No chat or
chat-kit production file was edited.

### A5 — Deletion calls a public policy setter after closing policy admission

**Locations:** `lib/state/connection.dart:6221,6359` and
`lib/termux/managed_server_recovery.dart:196,396,462`.

**Scenario:** the profile has a loaded or persisted Termux recovery record.
Removal pauses its automation policy, then recovery cleanup calls
`setBehavior(restartPhoneServer, false)` on that same paused owner. The setter
rejects the write, so removal fails and retains the row/sign-in.

**Fix:** `ManagedServerRecovery.prepareForProfileDeletion(prefs, id)` closes and
revokes recovery without editing the person's policy. The controller uses that
deletion boundary; public opt-out retains its separate semantics. Deleting an
alias does not revoke a different surviving installation owner's permit.

**Proof:** both real-controller cases in
`test/audit2_managed_recovery_deletion_test.dart` failed before the fix with the
paused-policy error and passed in the intermediate policy-only implementation.
Loaded/stored alias cases preserve the surviving owner's record and send no
native revocation commands. Abort coverage preserves the saved policy.

### A6 — Recovery cleanup drains checks, but not all preference writers

**Locations:** `lib/termux/managed_server_recovery.dart:354,396,414,511`.
Manual resume/suspend, policy revocation and installation-budget mirroring can
write independently of `_inFlightCheck`.

**Scenario:** a platform preference write is admitted, removal drains only the
health check and sweeps the key, then the earlier write completes. The deleted
profile's recovery record returns. An alias can also write its mirrored budget.

**Fix:** serialize all installation recovery preference writes, close admission
synchronously and drain the whole lane before deletion sweeps. Keep deletion
admission closed through facade disposal, reject late manual adoption and alias
writes, and reopen only when controller synchronization confirms a retained
profile after abort. Native revocation begins immediately, before waiting for a
slow storage write; serialization must not prolong a dispatched recovery permit.

**Proof:** after A5, held-write and abort regressions still failed: deletion
finished before the held write, and the retained owner did not reopen. Final
tests cover own and alias writes, stale manual calls after sweep, abort recovery
and stop while a reservation write is blocked. The first integration attempt
exposed an old test's await-before-release deadlock and delayed revocation;
the final fix revokes immediately, and the revised test proves that before
releasing disk. The interrupted run is not counted as a pass.

### A7 — The shared built-in owner pointer has a separate untracked writer

**Locations:** `lib/builtin/phone_server_healing.dart:63–75` and
`lib/state/connection.dart:6365–6369`.

**Scenario:** manual Start is waiting for its owner-pointer platform write.
Deletion clears `oc.builtinServerOwner` and removes the profile first; the old
claim then completes and writes the deleted ID back. The post-write readability
guard rejects Start, so this audit does not claim a wrong-profile start or a
credential leak. It is stale deleted-profile metadata and can prevent reliable
owner selection on the next start.

**Fix contract:** one preference owner serializes manual claims and deletion
clearing, closes admission before drain, and preserves the empty-string tombstone
so another local profile is not silently selected. Only a completed abort may
reopen claims for a retained profile. Failed writes reconcile the optimistic
SharedPreferences cache with disk; if that read fails, later operations must
reconcile before trusting the pointer. A refused claim must not hide another
profile’s durable owner pointer from its deletion.

**Proof:** `test/audit2_builtin_owner_deletion_test.dart` uses the real healing
callback, ProfileStore and ConnectionController, with a delayed platform write.
It failed before the fix because deletion completed before the claim settled.
Five final regressions pass: the delayed real-controller claim, refused-clear
abort/retry, refused and thrown claims preserving another durable owner, and
failed reload blocking subsequent claims/clears until disk reconciliation. The
first focused attempt found a missing test-only type import; it was corrected
before the successful run.

### A8 — Mobile consent can obtain a new writer after deletion closes the old one

**Locations:** `lib/state/consent_owners.dart:119–130` and
`lib/state/mobile_download_consent.dart:57–85,235–253`.

**Scenario:** close the cached consent owner, sweep the profile key, then request
the facade again. Removing the cached future permits a fresh writable owner,
and no saved-profile membership check prevents recreating
`oc.mobileDownloadConsent.<id>`.

**Fix:** stop facade admission synchronously, close loaded owners before awaiting
their queues, reject absent/unreadable membership on load and use, and let the
controller's completed abort reopen a fresh owner while stale objects remain
closed. Settings/consent semantics and the on-disk format are unchanged.

**Proof:** the fresh-facade resurrection test failed before the fix. Five focused
regressions now cover late facades, close during probe, absent/direct owners,
explicit abort reopening and a real refused controller removal. Existing mobile
consent tests now seed actual saved profiles. **Latent scope:** this consent
facade has no current production download caller, so this is not a demonstrated
live download-policy bypass.

## Reviewed invariants and limitations

- **Credentials:** trusted profile/provider/probe ingress registers values before
  capture; `/config/providers` remains raw only at transport/model boundaries.
  AI setup production adapters remain read-only; transaction tests use fakes.
  Setup snapshots are structurally redacted and audit history is bounded metadata,
  never snapshots, credential maps or restore handles. Existing live diagnostics
  keep synchronous durability; historical timing import preserves redaction.
- **Links and architecture:** reviewed launch sites retain the shared gate,
  including the integration OAuth launcher callback. No new direct-launch bypass
  was established. The domain mapper boundary remains intact after A1. Existing
  flavor/runtime-selection and UI dependency debt is not counted as a new
  regression without a changed, reachable feature gate.
- **Removal/migrations:** queue preflight re-reads durable state inside its lane,
  corrupt or changed input fails closed, and rejected preflight retains activity
  history/Undo. `oc.keptQueuedPrompts` intentionally changes to app ownership on
  explicit Keep and survives source-profile deletion; erasing it in the generic
  sweep would be data loss. No changed stored prompt/draft migration was found
  beyond bootstrap ordering; migration/photo prerequisites still precede shell.
  Start fresh verifies owned secure-key deletion and retains profile/prompt data.
- **Native network:** the new monitor has no argument-bearing network operation,
  exposes no SSID/address/credential, invalidates queued callbacks by owner and
  reports VPN transport as unknown. Dart rejects stale asynchronous readings;
  Internet validation is not used as proof of LAN or Tailscale reachability.
- **Scripts/voice/setup:** reviewed changed recovery scripts retain token, PID,
  process-start-time and fixed-port validation. No new script injection was
  demonstrated. Voice automatic selection keeps unknown-memory failure closed,
  explicit download consent and verification. Native setup keeps the single
  atomic persistence owner, typed failure and terminal-writer drain.
- **Background:** foreground healing has policy/generation checks, finite durable
  retry budgets and explicit-stop precedence. Builtin/setup services declare
  `specialUse`; the separate `dataSync` service retains timeout handling. Battery
  exemptions are not treated as permission for unbounded `dataSync`. No hardware
  thermal, OS six-hour timeout or process-death run was performed here.
- **Native hardening observation, not an exploit claim:** recovery generation
  decoding in `MainActivity.kt:444,459` accepts `Number.toLong()`, including
  fractional doubles. Current Dart producers send integers; no external attacker
  input route was found. Strict integer/range decoding plus malformed-channel
  JVM cases is a future native hardening task, not a verified credential or
  recovery-admission vulnerability in this audit.
- **Inherited partial-deletion limitation:** InteractionDefaultsStore and
  SetupAuditStore stay closed if a later scoped-key deletion fails and retains
  the profile (`profiles.dart:989–994`). Reopening them safely needs fresh durable
  snapshots and an explicit post-transaction abort hook, not reopening during
  the sweep. This availability limitation, already anticipated in the first
  audit's F2/F8 handoff, remains; it is not represented as repaired by A8.

## Verification and commit ledger

Pinned Flutter/Dart:
`~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin`.
Root alone runs checks with `OC_TEST_SLOTS=1 tool/qa/machine_lock.sh`,
`flutter test --no-pub --concurrency=1 … --reporter expanded` and
`dart format --language-version=3.10`. No test worker starts a second process.

Before-fix evidence (local, ephemeral logs):

- A1: four failures, `/tmp/oc-audit2-product-red.log`.
- A3: one OAuth-code failure and one already-safe encoded-token pass,
  `/tmp/oc-audit2-link-red.log`.
- A5: two removal failures, `/tmp/oc-audit2-managed-red.log`.
- A6: policy-only candidate passes A5 but fails held-write/abort cases,
  `/tmp/oc-audit2-managed-drain-red.log`.
- A7: deletion-drain failure, `/tmp/oc-audit2-builtin-owner-red.log`.
- A8: resurrection failure, `/tmp/oc-audit2-mobile-red.log`.

Intermediate successful checks: 112 product/link/mobile tests; 71 final managed
recovery/deletion tests; 31 final mobile/removal tests. These overlap and are not
summed into a distinct-test total. The five builtin-owner regressions also pass
(`/tmp/oc-audit2-builtin-owner-focused.log`). Production/test candidate:
`7ff34ba6`; the final report-only commit does not change that candidate. Pinned
format check: 17 changed Dart files, zero formatting changes.

Final focused run: **443 passed, zero skipped**, all 29 manifest files loaded,
exit 0 (`/tmp/oc-audit2-final-tests.log`). All four requested gates passed:
`kit_ratchet`, `redaction`, `ui_glossary`, `no_raw_error_text`. The native setup
harness compiled and ran all three scenarios (ordered terminal persistence,
typed write failure and failed-start status); this was not an Android device
or APK build. `flutter analyze --no-pub`: **No issues found**, exit 0
(`/tmp/oc-audit2-final-analyze.log`, 18.6 seconds). `git diff --check` passed.

All six fixes are implemented, locally verified and committed individually as
listed above. A2 and A4 remain owner handoffs. This audit did not run the full
repository suite, a device smoke test, Android timeout simulation or release
build; nothing was pushed, deployed, signed or released.

Final focused/gate manifest (29 files):

```text
test/audit2_product_error_mapping_test.dart
test/audit2_managed_recovery_deletion_test.dart
test/audit2_mobile_consent_deletion_test.dart
test/audit2_builtin_owner_deletion_test.dart
test/product_repository_test.dart
test/product_error_text_test.dart
test/external_link_test.dart
test/managed_server_recovery_test.dart
test/profile_deletion_test.dart
test/queued_prompt_removal_wiring_test.dart
test/mobile_download_consent_test.dart
test/phone_server_healing_test.dart
test/builtin_server_recovery_test.dart
test/credential_ingress_redaction_test.dart
test/default_notice_deletion_test.dart
test/setup_transaction_test.dart
test/setup_audit_store_test.dart
test/setup_controller_test.dart
test/network_test.dart
test/voice_automatic_setup_test.dart
test/builtin_recovery_bridge_test.dart
test/setup_runner_native_test.dart
test/termux_recovery_scripts_test.dart
test/termux_healing_arm_test.dart
test/thermal_guard_test.dart
test/kit_ratchet_test.dart
test/redaction_test.dart
test/ui_glossary_test.dart
test/no_raw_error_text_test.dart
```

## UI hook-up contract for Claude

No new screen wiring or English copy is needed for the fixes. Keep authored
`productErrorText` in the body and redacted `productErrorDetails` under Details.
Copy link gets the masked representation; only explicit approval launches the
original URI. Obtain mobile consent via its shared owner; missing/deleting
profiles are unavailable, and an aborted deletion creates a fresh owner.

The two required owner changes are A2 (redact timeline child text) and A4
(acknowledgement clears only the submitted composer revision). Their exact
behavior tests are specified above. No chat, team-page or glass production file
was edited. No push, signing, release or full-repository test claim is made.
