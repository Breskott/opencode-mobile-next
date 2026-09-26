# P3.2 Saved prompts absorb drafts — backend hand-off

Finish line: migrate older drafts once into Saved prompts; expose immediate saved-prompt actions with exact-content Undo and origin-bound recovered-photo attachment.

Non-goals: UI/kit changes, legacy screen removal, queued-message bubbles, release work. Those UI changes are explicitly outside this unit's scope.

## Scope and feasibility

Read: AGENTS.md; STANDARDS.md sections 2, 3, 13, 15 only; existing draft, shelf, photo, attachment and profile-deletion contracts. Worktree: `codex/p32`.

Write: new migration runner, saved-prompts controller, persistence redaction helper, draft-photo recovery service, focused tests, this QA record; narrow redaction at the existing photo store's persistence boundary. No UI, protected single-owner file, native code or generated output changes.

Three bounded responsibilities: migration (runner/test), photo recovery (service/photo persistence/test), controller integration (controller/redactor/test/QA). Parent reviewed the worker results; checks are serialized by the parent. Dependencies: existing `PromptShelfStore`, `SessionDraftStore`, attachment vaults and profile ownership. All are callable locally; no server request or credentials are needed. Feasibility passed for the backend API. App activation requires the coordinator's protected startup/draft-owner wiring described below.

## UI hook-up

Import `lib/state/saved_prompts_controller.dart`. It exports `StashedPrompt`, `PromptAttachment` and review-reference types, so UI needs no protocol-client imports.

1. Create one `PromptShelfStore.withAttachmentFiles(prefs)` for a profile lifetime, shared by migration and `SavedPromptsController(profileID:, shelf:, profileExists:)`. Its vault **must remain separate** from the ordinary draft vault. `profileExists` must reject deletion-in-progress, not just check a stale profile list.
2. Before ConnectionController loads/caches drafts, run `MigrationRunner(prefs:, shelf:, draftVault:, profileExists:).runForProfile(profileID)` for each existing profile. Handle `DraftMigrationResult.complete`, `alreadyComplete`, `migrated` and `blocker`. Unknown-owner/corrupt/unavailable sources remain intact; do not remove their recovery affordance. Repeated runs verify deterministic copies before removing the source. A storage blocker is retryable. No active draft mutation/profile deletion may overlap this startup lane.
3. **After migration**, still before draft-cache initialization, call `DraftPhotoRecovery(photos:, drafts:, vault:, profileExists:).recover()`. This order keeps a newly recovered photo in its originating conversation's draft instead of migrating it immediately into Saved prompts. Handle `nothingPending`, `attached`, `profileRemoved`, `retryRequired`; on retryRequired keep a retry/error affordance, not a pending-photo selection sheet. The service never takes an active-session argument. Supply the ordinary draft vault and the existing photo recovery store, not the stash vault.
4. Listen to `SavedPromptsController` (`ChangeNotifier`); render `prompts` and `busy`. `save(prompt)` persists a sanitized snapshot. `delete(id)` removes immediately after storage acknowledgment, without confirmation, and returns `SavedPromptUndo`. Show the kit Undo notice; invoke `await handle.undo()`. Dismissal releases the handle and its in-memory attachment snapshot. Undo is one-use, retryable after storage failure, and may refuse if the profile was removed, an ID was reused or the shelf is full.
5. `restore(id, composer:, sameLocation:)` replaces the current draft through `SavedPromptComposer.replace` and returns Undo. The source stays saved/reusable. The coordinator must supply a state-owned adapter bound to **one profile, conversation and location**; a restored stash ID/location is source metadata, never permission to switch the adapter’s target conversation. Its `value` includes text, full attachments and review references; `replace` must durably save the whole draft before publishing it, leave value unchanged on failure, reject profile deletion and serialize ordinary composer edits with replacement. Existing single-owner ConnectionController/chat state must implement this bridge; it is deliberately not edited here. Pass location equality from captured directory/workspace, not an always-true flag. Location-bound cross-project and incomplete attachment restores fail without replacing the draft. Undo refuses newer composer edits. Sanitize the existing composer snapshot first: restore rejects a prior value that would require redaction, so Undo never silently changes or persists sensitive prior content.
6. On profile deletion, first block new writes and call `controller.invalidate()` (or dispose); drain the shared shelf's operations, then use the existing deletion coordinator. The generic profile sweep covers the new migration flag and all shelf keys; existing `clearForProfile` clears shelf files and the existing draft/photo sweep clears their roots. Never recreate a controller for a deleted profile to replay Undo.
7. UI owner removes legacy draft screens/routes and replaces their entry points only after successful migration and wiring. This unit leaves them intact as requested. There is no queued-message bubble.

## Storage and safety

- New preference marker: `oc.savedPromptMigrationV1.<profileId>`. Existing shelf keys remain `oc.promptStash.<profileId>.<id>` and `oc.stashAttachmentVault.<profileId>`; the existing profile sweep supports interior profile segments. No new shared preference blob or vault root is introduced.
- Migration reads old `oc.sessionDrafts` fixtures, copies attachments to the independent shelf vault, verifies the copy, removes attributable source drafts, collects old payloads and then marks completion. Interrupted runs resume without duplicate prompts. Corrupt/ownerless data is never assigned to the active profile. Capacity/storage failures preserve the source; partial verified shelf copies can remain visible and are reused on retry.
- Recovery copies bytes into the ordinary draft vault before discarding photo recovery data, preserves the conversation's text/attachments, and deduplicates restart retries. It uses the existing `oc.draftAttachmentVault` deletion breadcrumb before publishing files.
- New persisted prompt copy, reference metadata and text attachment payloads use `KitRedact`; identity/location/URL fields that would change under redaction are rejected, not silently rebound. Binary photo payloads stay opaque and unchanged. Credentials/raw exceptions are not logged. Undo snapshots live only in memory.
- No authentication adapter, live server, signing key, publication or analytics added.

## Verification

Acceptance tests added:

- `test/saved_prompts_controller_test.dart`: immediate durable deletion + exact metadata/attachment Undo, restore + exact previous composer Undo, stale-edit refusal, profile sweep/no resurrection, redaction, failed-write retry.
- `test/saved_prompts_migration_test.dart`: raw old preferences, once-only migration, independent attachment ownership, interrupted migration retry, corrupt/ownerless/missing sources.
- `test/saved_prompts_photo_recovery_test.dart`: origin ownership, restart idempotence, storage failure preservation, profile deletion during recovery and redaction.

Pinned toolchain: `~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/`.

The requested Flutter launcher is blocked before analysis/test execution: its startup script attempts to update `bin/cache/engine.stamp.tmp.*` and `engine.realm` in the read-only SDK. This worktree also lacks `.dart_tool/package_config.json`. See `analyze.txt` and `tests.txt`. **No tests or analyzer pass is claimed**, including the existing deletion-sweep test. A verifier must run the commands below after restoring the normal toolchain environment:

```bash
flutter pub get
flutter test --concurrency=1 test/saved_prompts_controller_test.dart test/saved_prompts_migration_test.dart test/saved_prompts_photo_recovery_test.dart test/prompt_photos_test.dart test/profile_deletion_test.dart
flutter analyze lib test
```

Formatting uses the same pinned installation's actual `bin/cache/dart-sdk/bin/dart` binary with `CI=true` and `format --language-version=3.10`, bypassing only the read-only launcher cache refresh; `CI=true` suppresses its telemetry write. See `format.txt`. No alternate SDK is used.

## State

Implemented: backend APIs and focused tests. Enabled: not yet; startup/composer/UI hook-up belongs to the coordinator. Verified: source review and formatting/diff checks only; execution blocked as above. Committed: no. `git add` failed because the parent repository worktree metadata is read-only (`index.lock` could not be created). The requested commit message and attribution trailers are saved in root `COMMIT_MSG.txt`; all edits remain in this worktree. Deployed/released: no.

Contract problems: none requiring an alternative server contract. Full product finish line remains pending the explicitly excluded legacy-screen removal and protected startup/composer wiring. A separate composer adapter is necessary because current draft persistence lives in the single-owner connection/chat libraries; this unit does not claim a working UI journey without it.

Final checks: pinned bundled formatter exited 0; `git diff --check` passed; no UI/protected/native files changed. `candidate.txt` records the base revision and SHA-256 of implementation/test files. Focused execution and full analyzer still require the verifier; no release/build or full-suite run was attempted.
