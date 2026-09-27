# slice-P7.2 — Queued prompts survive server removal (2026-09-27)

Finish line: removing a server with queued prompts says how many there are
and keeps them in Saved prompts unless the person chooses to delete them
too. Nothing is deleted silently. Non-goal: no queue engine changes.

Branch `revamp/slice-P7.2`, base `8e0c584b` (feat/phone-setup-v2 after
P5.4). Builds on Codex's backend half (`docs/qa/codex-p72-2026-09-27`,
`lib/state/queued_prompt_removal.dart`), whose tests had never been run.
They run here for the first time and pass.

## What changed, per page

- **servers-remove-server-sheet ("Remove <server>?")**
  - Before: "2 queued prompts will be deleted" (lost). The only answers were
    Remove and Cancel.
  - After: "2 queued prompts move to Saved prompts" (kept). When a send
    started but was never confirmed: "1 of them may already have been sent".
    The answers are Remove (keeps them), **Remove and delete 2 queued
    prompts** (danger words), and Cancel.
  - The count comes from a snapshot taken when the sheet opens
    (`inspectQueuedPromptsForRemoval`). The removal acts on exactly that
    snapshot. If the queue changed in the meantime (a prompt was sent,
    edited or added), nothing is removed and the page says: "The queued
    prompts for Studio Mac changed, so nothing was removed. Remove it again
    to see the new count." If Saved prompts cannot take them (full, or
    storage refused): "Could not move the queued prompts for Studio Mac to
    Saved prompts, so nothing was removed. Delete some saved prompts or free
    up storage, then try again." No exception text is shown.
- **phone-server-remove-sheet (Remove OpenCode from this phone)**: when
  prompts are queued for this phone's server, the sheet adds "N queued
  prompts move to Saved prompts". After OpenCode is uninstalled, each
  in-app profile is removed with its current queue kept. This path has no
  "delete them too" answer because the sheet already has two answers.
- **prompt-stash-sheet (Saved prompts)**: prompts kept from a removed
  server appear in the Saved prompts of **every** server, newest first,
  among that server's own saved prompts. This is how they reach another
  server. Tapping one restores it into the composer like any saved prompt,
  with Undo, and it stays saved. Embedded (data:) attachments come back.
  A file or link that belonged to the removed server comes back as
  unavailable and is named in the existing "Restored without notes.txt"
  bar. Delete in the row menu removes it at once, and Undo puts it back.
  No chat file was edited. The sheet reads `ConnectionController`, which
  now merges the kept prompts in.
- **Kit** (`KitConfirmSheet`): a destructive `alternative` now keeps its
  danger words. Before this change the kit dropped the flag and drew
  "Delete everything" (this phone) in accent green, like a safe answer.
  Now both destructive alternatives render in `danger`.

### Not built: moving into another server's queue

The finish line also mentions moving them to another server. Keeping them
in Saved prompts, which every server shows, already covers "use them on
another server". Re-queuing them into a live conversation on the other
server would need a conversation picker for each prompt, because session
IDs, models and agents do not carry across servers. Codex's
`moveToSessions` prepares that, but no UI calls it yet.

## Backend changes (on top of Codex's half)

- `ConnectionController.inspectQueuedPromptsForRemoval(profileId)` returns
  the confirmation snapshot. It throws when the queue cannot be read. In
  that case the sheets fall back to the old behaviour, because there is
  nothing readable to keep.
- `deleteProfileAndLocalData(profileId, {queuedPrompts, keepQueuedPrompts})`:
  inside the existing serialized queue step, before source entries are
  filtered, the step now does three things. (1) It compares the live queue
  cache and the durable queue with the confirmed snapshot; any difference
  throws `QueuedPromptRemovalException(changed: true)`. (2) With Keep, it
  awaits `keepAsDrafts`; any failure throws `(changed: false)`. (3) It then
  runs the existing checked queue save. The exception is raised before
  drafts, the stash, scoped keys or the profile row are touched, so the
  server stays. Callers that pass no snapshot behave as before.
- `QueuedPromptRemoval.forgetDraft` now returns the removed record, and a
  new `rememberDraft` puts it back for Undo. `QueuedPromptRemovalException`
  is new. `SavedPromptUndo.kept(...)` gives kept drafts the same one-use
  Undo.
- `promptStash` merges `keptQueuedDrafts`. An unreadable kept-drafts blob
  is left on disk and left out of the list, so a corrupt blob cannot block
  the server's own Saved prompts. `restorePromptStashAttachments` and
  `deleteSavedPrompt` route `kept-…` ids to the kept store.
- `lib/state/connection.dart` (single owner): about 100 lines, limited to
  the points above.

## Migration notes (stored formats)

- New app-wide key `oc.keptQueuedPrompts` (Codex's
  `QueuedPromptRemoval.draftsKey`). It holds a JSON list of existing
  `QueuedPrompt` records, each string redacted with KitRedact, with at most
  50 records and the queue's byte cap. It is deliberately **not**
  `oc.<what>.<profileId>`. After an explicit Keep the prompts belong to the
  app rather than the removed server, so that server's deletion sweep must
  not take them. The records keep the source profile/session IDs only as
  local provenance. No credentials are copied. A future app-wide erase
  must also remove this key.
- `oc.offlineQueue`, `oc.promptStash.<profileId>.*` and the per-profile
  sweep are unchanged. No existing data is migrated.

## Tests

New:
- `test/queued_prompt_removal_wiring_test.dart` (4), against the real
  controller and storage. It covers these cases:
  - Keep moves both prompts to Saved prompts. They survive a restart and
    the removed server's sweep, and the other server's queued prompt stays
    queued.
  - Restore brings the data: attachment back and names the file one as
    unavailable.
  - Delete with Undo removes the prompt and puts it back. A second Undo is
    refused.
  - "Delete them too" leaves no kept key.
  - A queue that changes after confirmation throws `changed`, and the
    profile and queue stay. Counting again succeeds.
  - Full Saved prompts keeps the server and its queue.
  I checked that the tests catch a regression: with the new block in the
  queue step disabled, 3 of the 4 tests fail.
- `test/revamp/queued_prompt_removal_test.dart` (5 behaviour, 4 goldens).
  The sheet names the count, the unconfirmed count and the other answer.
  Remove keeps the prompts, the other answer deletes them, and Cancel does
  nothing. A changed queue is reported in plain words with no exception
  text. Kept prompts show in another server's Saved prompts.
- Codex's `test/queued_prompt_removal_test.dart` (4): first run, passes.

Changed: the `deleteProfileAndLocalData` overrides in
`test/phone_server_card_test.dart` and
`test/revamp/shared_phone_1_fixtures.dart` now take the new named
parameters (signature only).

Runs (pinned Flutter 3.47.1, `--concurrency=1`):
- All pass: queued_prompt_removal{,_wiring}, revamp/queued_prompt_removal,
  profile_deletion, stash_lifecycle, saved_prompts_wiring, prompt_shelf,
  session_draft, saved_prompts_controller, phone_server_card,
  revamp/shared_phone_1, kit/kit_confirm_sheet, kit/kit_dialog,
  l10n_coverage.
- These fail the same way on the base commit, checked in a temporary
  second worktree, so none of the failures is new:
  - offline_queue: 5
  - revamp/saved_prompts_golden: 6
  - kit_ratchet G17/G21: 2
  - revamp/screen_servers_1 goldens: 14
  - ui_glossary G11 ×2 and G28: 3 (the flagged keys are other slices'; none
    of this slice's keys appear)
- `flutter analyze`: no issues.

## Images

- Before (base, same fixture): `before-remove-sheet-phone.png`,
  `before-remove-sheet-wide.png`.
- After (goldens, phone 412x915 and 1280x800, dark):
  `after-remove-sheet-{phone,wide}.png` and
  `after-kept-in-saved-prompts-{phone,wide}.png`.

Seen in the goldens but not changed here: the Saved prompts subtitle still
says "kept on this device for this server". Kept prompts from a removed
server show under every server. That copy belongs to the chat chain's
sheet.

## Still needs a device

The programme proof on an emulator: queue prompts offline, remove the
server, find the prompts in another server's Saved prompts, and restore one
into a conversation. Also the in-app phone server path: uninstall with
queued prompts, then check that they are kept.

## State

Implemented and enabled on both removal paths. Verified by focused tests
and goldens. Committed on `revamp/slice-P7.2`. Not pushed, not released.
