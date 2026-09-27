# slice-P3.2 — Saved prompts absorb drafts (2026-09-27)

Finish line: older drafts move once into Saved prompts (MigrationRunner) and
the legacy screens are deleted. Restoring or deleting a saved prompt acts at
once with Undo. A recovered photo joins its own conversation's draft (no
pending-photo sheet). Non-goal: no queued-message bubble (P4.3).

Branch `revamp/slice-P3.2`, base `c024b0dd` (feat/phone-setup-v2 after
P3.7b). Builds on Codex's backend half (`docs/qa/codex-p32-2026-09-27`,
commit `0e89eb11`), which had never been run; its tests run here for the
first time.

## What changed, per page

- **legacy-drafts, legacy-drafts-review-sheet, legacy-drafts-delete-sheet —
  removed** (`lib/ui/screens/legacy_drafts_screen.dart` deleted; the
  "Older drafts" row under composer + › Prompts is gone). Their drafts now
  show in Saved prompts as ordinary saved prompts (merged into
  prompt-stash-sheet, as programmes.json P3 records). Reachability: Saved
  prompts is the route in.
- **prompt-stash-sheet (Saved prompts)**
  - Opening it moves any older drafts that are left
    (`ConnectionController.migrateOlderDrafts`), so they appear in the list
    with their original date.
  - If they cannot move yet, one notice names why with Try again: "Older
    drafts are waiting to move here. Delete saved prompts to make room."
    (Saved prompts is full) or "Some older drafts have not moved here yet.
    They are kept on this device." (storage refused). Nothing is dropped.
  - Delete (row menu) now removes the prompt from the device at once
    (Codex's `SavedPromptsController.delete`); "Saved prompt deleted · Undo"
    puts it back exactly — text, date, attachments (bytes), references.
    Before, the row hid and the delete waited for the bar to close. A prompt
    whose attachment file is already gone can still be deleted (Undo brings
    back what could be read).
- **chat-stash-restore-confirm-sheet ("Restore saved prompt?") and
  chat-stash-attachments-unavailable-sheet — removed.** Tapping a saved
  prompt replaces the draft at once; the bar says "Saved prompt restored" or
  "Restored without a.png; attach them again before sending", with Undo.
  Undo puts back the exact previous draft (text, attachments, staged
  references) only if nothing was typed since. The replaced draft is also
  kept in Saved prompts until then (so closing the app mid-way loses
  nothing); Undo removes that safety copy again. The restored saved prompt
  itself stays saved and reusable (before, it was removed when possible).
- **chat-pending-photo-sheet ("Pending photo") — removed.** At startup,
  `main.dart` calls `recoverPendingPhoto()` (Codex's `DraftPhotoRecovery`):
  a photo the camera handed back after Android stopped the app goes into the
  saved draft of the conversation that asked for it. Picking a new photo
  while one is still waiting attaches that one first — into this composer
  when it is this conversation's, otherwise into its own conversation's
  saved draft — with no question. One that still cannot move keeps waiting
  and the composer says "A photo is still waiting for another conversation.
  Add or discard it there, then try again." The conversation's own pending
  row (chat-pending-photo-row, Add/Discard) stays as the retry affordance.

## Backend changes to Codex's half

- `MigrationRunner` now moves only the *older* drafts — those with no
  recorded server (`profileID` empty), which is what the Older drafts page
  listed — into the Saved prompts of the server in use. Codex's version moved
  every conversation's live draft out of its conversation and refused to move
  the ownerless ones at all (unknownOwner), which would have stranded exactly
  the drafts the deleted page showed; it also collected the running profile's
  live draft attachment files. Ownerless drafts go to the server in use
  because the old page already showed them under every server; with one
  server (the common 1.0.44 case) the owner is unambiguous.
- A missing attachment file no longer blocks the move: the text moves with
  what can still be read (the old page could never restore attachments at
  all). A full Saved prompts (50) is a new `DraftMigrationBlocker.full`;
  the drafts stay in place.
- `SavedPromptsController.delete` tolerates unreadable attachment files.
- Fixed Codex test `native recovery redacts filename metadata` (on io
  `XFile.name` is the path's basename, so the fixture file itself now has the
  sensitive name).

## Migration notes (stored formats)

- `oc.sessionDrafts`: rows without `profileID` are removed after their
  Saved-prompt copies are written and verified; rows that name a server are
  untouched. Format unchanged.
- New Saved prompts rows `oc.promptStash.<profileId>.legacy-draft-<sha256>`
  (existing format; deterministic id so an interrupted run never duplicates).
  Attachment bytes are copied into the Saved prompts vault
  (`prompt-stash-attachments-v1`); the ownerless files in the draft vault are
  collected only after the source rows are gone.
- New `oc.savedPromptMigrationV1.<profileId>` (bool): the migration ran for
  that server.
- New `oc.olderDraftsBackupV1.<profileId>`: JSON list of the migrated rows
  (redacted with KitRedact, text and attachment metadata, not bytes), kept
  for one release as the programme's safety net; nothing reads it. **Remove
  it in the next release.**
- All new keys follow `oc.<what>.<profileId>`, so the profile deletion sweep
  removes them (asserted in `saved_prompts_migration_test.dart`).
  Deleting a server also disposes its Saved prompts controller, so an open
  Undo refuses instead of writing the deleted prompt back.
- Saved-prompt text is redacted by `sanitizeSavedPrompt` on the way in (a
  `password=…` in an older draft is masked in its saved copy).

## Tests

New:
- `test/saved_prompts_wiring_test.dart` (2): controller-level recovery puts a
  returned photo into its own conversation's draft with its text kept;
  removing the server refuses the outstanding delete Undo and leaves no key.
- `test/revamp/saved_prompts_golden_test.dart` (7 goldens).
- `test/saved_prompts_migration_test.dart` rewritten (6): raw 1.0.44
  fixtures; older drafts move once, live drafts on either server stay,
  backup redacted and profile-scoped; copied attachments survive, a live
  draft's files are not collected; refused removal retries without
  duplicates; corrupt index intact; missing file does not hold back text;
  full Saved prompts keeps drafts until room is made.

Changed:
- `test/session_draft_test.dart`: the two Older-drafts tests became
  "older drafts move into Saved prompts once; a refused write keeps them and
  says so" and "an older draft shows up in Saved prompts and restores at once
  with Undo" (no "Restore saved prompt?"; Undo brings back "Current thought").
- `test/prompt_shelf_test.dart`: partial restore acts at once and names the
  missing file; delete is immediate and Undo restores exactly (bytes,
  reference, date); stash-and-restore no longer taps a confirm.
- `test/settings_search_rows_test.dart` (literal 'Older drafts'),
  `test/ui_glossary_baseline.json` and `test/kit_ratchet_baseline.json`
  (entries of the deleted screen removed; the ratchet demanded it).
- Census: shots of the removed pages deleted from
  `tool/capture/census/areas/{b1_chat_screen,c_chat_compose,j1_settings_more}.dart`.

Runs: saved_prompts_{controller,migration,photo_recovery,wiring},
prompt_photos, profile_deletion, prompt_shelf, session_draft,
settings_search_rows, stash_attachments, stash_lifecycle, draft_attachments
and the new goldens — all pass. A wider set (kit_ratchet, ui_glossary,
search_index, architecture_boundaries, analyzer_suppressions,
design_standard, l10n_coverage, chat_states_standard, offline_queue, and every
chat test that opens composer tools or photos: calm_chat_disclosure,
chat_live_events, codex_chat_capabilities, composer_layout,
context_capsule_chat, demo_isolation, desktop/ios gating, kit_composer,
read_aloud, release_blockers, revamp chat_3/4/8 (+goldens), voice_composer,
voice_reply_pipeline, web_search) was run on this branch and on the base in a
temporary worktree: 143 failures on both, the identical set — none new.
`flutter analyze`: no issues.

A check that the Undo refusal fails without the new invalidation passed
anyway: the controller already refuses once the profile row is gone. The
dispose on deletion closes the window while the deletion is still running.

## Images

Before (census, phone): `before-legacy-drafts-phone.png`,
`before-legacy-drafts-review-sheet-phone.png`,
`before-legacy-drafts-delete-sheet-phone.png`,
`before-chat-stash-restore-confirm-sheet-phone.png`,
`before-chat-stash-attachments-unavailable-sheet-phone.png`,
`before-chat-pending-photo-sheet-phone.png`,
`before-prompt-stash-sheet-phone.png`.

After (goldens, phone 412x915 and wide 1280x800, dark):
`after-saved-prompts-older-draft-{phone,wide}.png`,
`after-restored-undo-{phone,wide}.png`,
`after-deleted-undo-{phone,wide}.png`, `after-older-drafts-full-phone.png`.

Seen in the goldens, not changed here: on a phone the kit Undo bar sits over
the composer instead of above it (same for the existing "Draft text cleared"
bar) — a kit/composer inset question.

## Still needs a device

- The programme proof: emulator upgraded from a 1.0.44 build with older
  drafts; they appear in Saved prompts after the first start.
- Camera return after Android kills the app (process death) landing in the
  right conversation's draft.
- Edge case left as is: a pending photo for another conversation is
  written to that conversation's saved draft; if that conversation is also
  open in another pane at the time, its composer does not reload it.

## State

Implemented, enabled (startup wiring in `lib/main.dart`, which is a
single-owner file: 6 lines), verified by focused tests, committed on
`revamp/slice-P3.2`. Not pushed, not released.
