# slice-P3.7b — One "Undo from here" flow (2026-09-27)

Finish line: both OpenCode 1 and OpenCode 2 go through `stage-revert-sheet`.
The flow quotes the prompt and lists the files; it is staged when the server
allows it and otherwise an honest one-step confirm. `chat-revert-confirm-sheet`
is gone. Non-goal: no new revert capabilities on the server.

Branch `revamp/slice-P3.7b`, base `8a6f232e` (feat/phone-setup-v2 after chat-9).

## What changed, per page

- **chat-revert-confirm-sheet — removed.** `_revertLast` (conversation menu
  "Undo last prompt", `/undo`) no longer opens its own `showKitConfirm`
  ("Revert from this prompt?" / "Revert"); it picks the newest saved prompt and
  enters the same `_undoFrom` flow as the prompt's own menu. This folds in
  chat-8's open note ("_revertLast's one-step confirm should fold into the
  stage-revert sheet"). Strings `chatUiRevertFromThisPrompt`,
  `chatUiMessagesAndFileChangesAfterTheMost`, `chatUiRevert`,
  `chatUiRollBackMessagesAndFileChangesAfter` deleted (en + ar).
- **stage-revert-sheet — now the one flow on every server**
  (`lib/ui/screens/staged_revert_screen.dart`, `showStageRevertSheet`). The
  shape follows what the server can do (`supportsStagedRevert`, i.e. the
  repository implements `StagedRevertGateway`), never the flavor enum:
  - *Staged* (OC2): unchanged — "hidden while you review", "Put files back
    too", "Undo and review" stages inside the sheet and opens the review page.
  - *One step* (OC1, new `undo:` callback): the honest confirm. It quotes the
    prompt, says "This prompt and the N messages after it are removed, and
    files go back to how they were before it. You can put them back until you
    send another prompt." (N from the loaded transcript; "everything after it"
    if the prompt is not loaded), lists "Files the agent edited after it"
    (completed edit/write/patch tool evidence via the new
    `RunResult.editedPaths`), and a destructive "Undo now" that runs inside the
    sheet — a failure keeps the sheet open with "That didn't finish…". Busy or
    stale turns the primary off with the reason, as on OC2.
- **Prompt menu (long-press / right-click)**: "Undo from here" (was "Revert from
  this prompt", OC2-only) now shows on every server with `sessionRevert`,
  including while the conversation is busy (the sheet then says why it is off),
  so both doors give the same model.
- **Conversation menu / `/undo`**: "Undo last prompt" (was "Revert last
  prompt"); one description on every server.
- **Chat after a one-step undo**: the transcript now applies the server's undo
  boundary on every server (`_visibleHistory`, history paging), so the undone
  turns actually disappear on OC1 (before, OC1 kept showing them). The session
  is re-read right after the undo and after "Put back" so the boundary applies
  at once instead of waiting for the event. A status line "Undone from a
  prompt · Put back" (`_undoneStatus`, chat_states.dart) is the way back, in
  the same place OC2's "Revert staged · Review" sits.
- **staged-revert (Review the undo)**: uses the SV1 count
  (`countStagedRevertMessages`, docs/qa/codex-sv1-2026-09-27) for the exact
  reviewed boundary: "This prompt and the 3 messages after it are hidden…", and
  the delete question's lost line "The hidden prompt and the 3 messages after it
  are deleted". Loading, stale, failed or incomplete counts keep the
  "everything after it" copy (never zero). The count is dropped with the review
  (identity + `isRevertReviewCurrent`) and re-read on "Review latest state".
  DiffView is untouched (P3.7a).

## Tests

New:
- `test/undo_from_here_flow_test.dart` (7): `RunResult.editedPaths`; OC1 — both
  doors open the same one-step sheet with prompt, count and files; "Undo now"
  reverts, hides the undone turns, shows "Undone from a prompt", and "Put back"
  brings them back; a failed undo keeps the sheet open; busy keeps the door but
  disables the undo. OC2 — both doors open the same staged sheet; staging opens
  the review page with the exact count in the intro and the delete question.
  The "hides the undone turns" test failed before the session re-read fix
  (verified), then passed.
- `test/revamp/undo_from_here_golden_test.dart` (10 goldens).

Changed: `test/staged_revert_workflow_test.dart` (fixture gets a local
`messagePage` so the review page never reaches the network),
`test/chat_menu_hierarchy_test.dart` and `test/codex_chat_capabilities_test.dart`
("Undo last prompt").

Runs: new + changed revert files and `run_result_test.dart` — 47 passed.
Affected existing files (kit_ratchet, ui_glossary, design_standard,
chat_states_standard, run_result, chat_menu_hierarchy, codex_chat_capabilities,
desktop_context_menu, staged_revert_message_count, screen_review_2 goldens,
architecture_boundaries, offline_queue) were run on this branch and on the base
commit in a temporary worktree: the same 37 failures on both, none new (base
drift: kit_ratchet G17/G21, glossary G11/G28, ARCH-1 tools_screen,
TextFormField casts, screen_review_2 golden pixel drift at identical
percentages). `flutter analyze`: no issues.

## Images (dark phone 412x915 unless named wide; wide is 1280x800)

| before | after |
|---|---|
| `before-chat-revert-confirm-sheet-phone.png`, `-wide.png` (OC1 menu door) | `after-stage-revert-sheet-one-step-phone.png`, `after-stage-revert-sheet-one-step-wide.png` (light) |
| (OC2 sheet unchanged) | `after-stage-revert-sheet-staged-phone.png` |
| `before-staged-revert-phone.png` | `after-staged-revert-counted-phone.png`, `after-staged-revert-counted-wide.png` |
| `before-staged-revert-delete-question-phone.png` | `after-staged-revert-delete-question-counted-phone.png` |

## Still needs a device

The proof in the unit ("Emulator against OC1 and OC2: undo from a prompt on
each") was not run here. On OC1 check: the revert hides the turns straight
away, "Put back" restores them, and sending a new prompt after an undo leaves
the removed turns gone (server cleanup emits `message.removed`). On OC2 check
the review page's count against the transcript. The OC1 message count and file
list come from the loaded transcript (tool evidence), not a server preview —
OC1 has no pre-revert file preview.
