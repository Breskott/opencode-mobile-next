# slice-queue-move — move waiting prompts to the connected server (2026-09-28)

Finish line: when prompts wait for a server the app cannot reach, a person can
pick them on Servers, move them into a new or recent conversation on the
server the app is connected to, see what moves, confirm, and undo.
Non-goal: moving to a server that is not connected (its conversations cannot be
checked); changing the queue engine or the removal flow.

Branch `revamp/slice-queue-move`, base `b9fdd22f` (feat/phone-setup-v2). It
builds on Codex's `moveToSessions` (docs/qa/codex-p72-2026-09-27), which had
no caller until now.

## What changed, per page

- **Servers › a server row** (`lib/ui/screens/servers_screen.dart`)
  - Before: nothing on a server's row said that prompts were waiting for it.
    Its menu offered Connect, Edit, Remove.
  - After: a row that is not the connected one says "4 prompts waiting to
    send" in the strong label weight. When another server is connected and
    keeps a queue, the menu adds **"Move 4 waiting prompts to Laptop"**. It
    names the target. With no connected server the line stays and the action
    is not offered, because there is nowhere to move them to. An isolated view
    shows neither.
- **Move queued prompts sheet** (new, `lib/ui/widgets/queued_prompt_move_sheet.dart`,
  `showQueuedPromptMoveSheet`). It is built only from kit parts: `showKitSheet`,
  `KitChoiceList.multi` and `.single`, `KitSectionLabel`, `KitConsequences`,
  `KitNotice`, `KitDetailsFold`, `KitStateView`, `KitReveal`, `showKitUndo`.
  Any surface can open it.
  - It shows the subtitle "From Studio Mac" and that server's queued prompts
    only. The prompt text is masked by KitRedact, kept to one paragraph and
    cut at 140 characters. Each row says "Queued 3h ago · 1 file".
  - Every prompt that can move starts picked. The others are shown dimmed with
    the reason:
    - "May already have been sent. Check it on Studio Mac first." (its send
      started and was never confirmed)
    - "Has a file only Studio Mac can open" (a file: or content: attachment)
    - "Hiding a password in it would break its agent mentions"
  - Conversation: "New conversation" (the default), then the 8 most recent
    conversations on the connected server.
  - Facts, shown only when true:
    - "Passwords and keys in 1 prompt stay hidden". Moved prompts are stored
      redacted, like every kept queued prompt.
    - "1 prompt uses the model chosen on Laptop". The destination does not
      offer that model or agent, so the prompt's choice is dropped rather than
      sent to fail.
  - Primary: **"Move 2 prompts to Laptop"**. With none picked it is disabled
    with "Choose at least one prompt". Secondary: Cancel.
  - Failure: the sheet stays open and says, in plain words, what failed and
    that nothing moved. Examples: "Could not start a new conversation on
    Laptop, so nothing moved. Try again or choose an existing conversation."
    The same applies when the server disconnected, the conversation is gone,
    the prompts no longer wait, or the move could not be saved. Technical text
    appears only in the Details fold.
  - Done: the one Undo bar says "2 prompts moved to Laptop". When some picked
    prompts stopped waiting in the meantime it says "Moved 1 of 2 prompts to
    Laptop. The rest no longer waited." Undo puts back each prompt that has not
    started sending. If some had started: "1 prompt already started sending on
    Laptop and stays there. The rest wait for Studio Mac again." If all had:
    "…so they stay there." The moved prompts are sent (`flushOfflineQueue`)
    only when the Undo window closes, so Undo has something to undo.
- **Remove server sheet**: not changed. Its goldens were refreshed only because
  the row behind the sheet now says "2 prompts waiting to send".

## Backend

- `lib/state/queued_prompt_move.dart` (new, pure):
  - `QueuedPromptMove.blockFor` gives the reason a prompt cannot move,
    mirroring `moveToSessions`.
  - `hidesSecrets` and `keepsSelection` report whether a model or agent is
    offered. An unknown catalog counts as offered.
  - `apply` builds the queue after the move. It uses `moveToSessions` with the
    person's pick, and refuses when the live queue and storage differ (order
    does not matter).
  - `undo` puts moved prompts back only while they are still unsent on the
    destination.
  - The problem enum `QueuedPromptMoveException` carries the problem, with the
    cause kept only for Details.
- `lib/state/queued_prompt_removal.dart`: `moveToSessions` takes an optional
  `only` set, so a picked subset moves and the rest of the plan stays. This is
  4 lines, and its existing tests are unchanged and pass.
- `lib/state/connection.dart` (single owner, +116 lines, additions only, next
  to `queuedPromptCountForProfile`):
  - `queuedPromptsForProfile`.
  - `queuedPromptMoveDestination`: the connected, non-isolated, queue-keeping
    server that is not an agent socket.
  - `moveQueuedPrompts(sourceProfileID, promptIDs, sessionID?)`:
    1. Checks the destination and the conversation first.
    2. Creates the new conversation, if one was asked for, before taking the
       queue lock.
    3. Inside `_serializeQueueChange`, rechecks the destination, applies the
       move, saves once, and installs the queue in the cache.
    4. If the save is refused, it throws and nothing changes.
  - `undoQueuedPromptMove(result)` reverses the move under the same lock and
    skips the prompt currently in flight.

Profile isolation:
- Only the source's prompts are listed or moved; another server's prompts are
  never touched (tested).
- The only destination is the connected server the person picks by pressing
  the primary.
- A move to the source itself, to a server that is not connected, or to a
  conversation that is not on the destination is refused (tested).

## Migration and privacy

- No stored format changes. Moved entries stay ordinary `oc.offlineQueue`
  records, with a new profileID and sessionID and the old error cleared.
- No new keys.
- Text in moved entries is redacted by `moveToSessions`, as before, and the
  sheet discloses this.
- No provider credentials are read. Nothing is logged.

## Tests

New: `test/revamp/queued_prompt_move_test.dart`, 11 behaviour tests and 4
goldens.

- Row line and a menu action that names its target.
- Choose a conversation and confirm: the picked prompts move, uncertain and
  file prompts stay, another server's prompt is untouched, secrets are masked
  in the sheet and in storage, and nothing is sent before the Undo window
  closes.
- New conversation is the default. An unpicked prompt stays.
- Undo restores the queue byte for byte.
- Cancel moves nothing and starts no conversation.
- A failure keeps the sheet open in plain words, with Details. Raw server text
  is not shown and nothing is saved.
- No connected server: no action.
- Controller partial: a picked prompt that is gone or uncertain is counted as
  skipped and not moved.
- Partial Undo leaves a prompt that already started sending.
- Isolation refusals: the source itself, another server's prompt, a
  conversation not on the destination, a disconnected destination.
- Model/agent check.

Regression check: I made two mutations. Listing every server's prompts in the
sheet, and Undo ignoring the sending marker, each made 5 tests fail. Both were
then reverted.

Runs (pinned Flutter 3.47.1, `--concurrency=1`, via tool/qa/machine_lock.sh):

- Pass: revamp/queued_prompt_move (15), queued_prompt_removal,
  queued_prompt_removal_wiring, revamp/queued_prompt_removal (remove-sheet
  goldens refreshed on purpose), kit_ratchet, ui_glossary, l10n_coverage,
  design_standard.
- These fail identically on the base commit, checked in a temporary second
  worktree. None is new:
  - revamp/queued_prompt_removal "kept prompts in Saved prompts" goldens (2)
  - architecture_boundaries ARCH-1 and ARCH-2 (identical output)
  - revamp/screen_servers_1 (14)
  - e7_setup_layout (2)
  - offline_queue (1)
- `flutter analyze`: no issues.

## Images

Phone 412x915 and wide 1280x800, dark:

- Before (base, same fixture): `before-row-menu-phone.png`,
  `before-row-menu-wide.png`. The menu has no move action and the rows say
  nothing about waiting prompts.
- After: `after-row-menu-{phone,wide}.png` and
  `after-move-sheet-{phone,wide}.png`. The wide sheet image also shows the rows
  saying "4 prompts waiting to send" and "1 prompt waiting to send".

## Not done here, hand-offs

The details are in the coordinator's lane notes.

- Chat: the "drafts waiting for other servers" note should open this sheet. No
  chat file was edited.
- This phone card (owned by phone setup): the same row line and menu action.
- Removing a server could offer "Move to Laptop" beside Keep and Delete. That
  needs `deleteProfileAndLocalData` to take a move choice inside its lock.

## Still needs a device

With two real servers:
1. Queue prompts while Studio is offline.
2. Connect to Laptop.
3. Move them into a new conversation and check they send after the Undo
   window.
4. Undo a second move before it sends.

Real model catalogs are also needed for the "uses the model chosen on" line.

## State

Implemented and enabled on Servers. Verified by the focused tests and goldens.
Committed on `revamp/slice-queue-move`. Not pushed, not released.
