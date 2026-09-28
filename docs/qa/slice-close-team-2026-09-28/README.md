# slice-close-team (2026-09-28)

Closes the team-area gaps left open by the review-board closure audit
(`docs/qa/review-board-closure-2026-09-28/README.md`), plus the
isolated-task-sheet ("only its entry point moved"). Branch
`revamp/slice-close-team`, from `feat/phone-setup-v2` at `ee0fdb7a`.

## What changed, per page

| Page | Before | After |
|---|---|---|
| start-run-sheet (owner note: "Give the user recovery options?") | Planner off with no direct path: title "Give the team a task", engine words ("The planner (Mayor) is off… switch it to the full profile"), only "Host guide". | Opens as **"Team can't take tasks"** with the reason in plain words: "The planner is switched off" / "This team has no planner" / "This team has no project yet". Way on: **Wake the planner** where the host takes agent controls (`controlAgent`, never for an agent the phone team keeps off). Once the host lists the planner awake, the sheet closes and the task form opens. Everywhere else: **Try again**, which reads the host again and moves on when it can, plus the Host guide. A refused wake says "Couldn't wake the planner"; the host's words appear only under Technical details. If the planner goes off while the form is open, the same state shows in place. |
| isolated-task-sheet | "New task in a fresh worktree"; asks only for a worktree name; path at the top; "Stopping now cannot undo…"; a failed setup ends in raw text and a lone Close. | **"Start in a separate copy"**, one plain line, and **"What should it work on?"**. The field keeps a per-server draft and is sent once the copy is ready; left empty, it opens a blank conversation. The name is folded under Options, and the path and branch are under Details. The wait shows three stages, "Usually 1–3 minutes" and the elapsed time, with a full-width Stop waiting. If the send fails, the task is kept as the conversation's draft. **Setup failed in {name}** offers Start anyway, Remove the copy (confirmed in place) and Close; the setup output is only under Details. **Couldn't make the copy** offers Try again. |
| team-run-overview-tab / embedded-team-merge-section | A merged task kept the whole readiness checklist, the request id, "Already on main" and a greyed-out **Merge** button. | Merged: only "Merged into main · 4f9c2a1" and **Review changes**. Merge on green, Undo and real diffs are still blocked on the host merge contract. |
| team-run (Task details) | Stage words Waiting · Working · Reviewing · Done. "Done" showed even while a step was still in review. | **Planned · Working · In review · Merged**. Merged shows only once every step is closed. A completed task with a step still open is "In review", on its stage line, its status word and its home row mark. |
| team-agent | "Working" beside "waiting on one other step" when that step had finished. | A dependency counts only while the host lists it as open (`teamOpenDependencies`, the board's rule). |
| embedded-team-receipt-chip, team-home-needs-you-tab | A trailing "⚠ Not confirmed yet" chip in the row, in place of the chevron. | The receipt is a mark and a word in the row's supporting line: "Needs you · ⚠ Not confirmed yet · …" (home) and "Decision · ⚠ Not confirmed yet · …" (team rows, Activity). The row itself opens the Gate sheet, where Try again lives. Team and Activity rows keep their chevron. The home's question rows have no chevron because none of its task rows do, so they match the list they sit in. |

Kit: `KitReceipt.span(mark: true)` puts the state's glyph before the word and draws a still dot, never a spinner, inside text. Existing callers are unchanged.

Team helpers: `teamGateReceiptSpan` and `teamGateRowLine` replace `teamGateRowReceipt`. The string `teamUiGateAnswerChipUnconfirmedSemantics` is deleted along with the four old planner-off strings.

## Tests

- **New:** `test/slice_close_team_test.dart` (11 tests). On the base commit, 9 of the 10 widget tests fail. The one that passes is the control case: an open dependency still reads "waiting on one other step". The pure `teamOpenDependencies` test does not compile on base.
- **New:** `test/isolated_task_sheet_test.dart` (28 tests pass). 8 new behaviour tests fail on base: task sent after ready, blank open when empty, draft kept when the send fails, Start anyway after a failed setup, Remove the copy, setup output only under Details, Try again after a failed create, and the new form. `test/isolated_task_launch_test.dart` has 2 new tests.
- **Updated to the new behaviour:** `team_controls_test`, `team_merge_test`, `team_task_details_test`, `team_cycle_test`, `team_gate_answer_test` (Activity rows), `kit/kit_receipt_test` (the `teamGateRowLine` group replaces the retired wrapper's), `revamp/slice_p4_1c_test`, and `revamp/screen_work_4_test`.
- **Regenerated goldens:** `p35_team_task_details_*` (4) and `slice_p52_task_details_cost_light` (stage words), plus `work_isolated_task_sheet_*`.
- **Gates:** `kit_ratchet`, `redaction`, `ui_glossary` (G28 included), `no_raw_error_text`, `kit/kit_manifest`, `kit/kit_draft_manifest` and `architecture_boundaries` pass. `flutter analyze` is clean on the whole project.
- **Failures that also fail on the base commit** (not touched):
  - `team_controls_test` "sends objective + supervision…": `team-conversation-now-why` is missing, in the chat library.
  - `team_gate_answer_test`: the four "320dp 2.5x … every variant with actions fits".
  - `revamp/shared_team_2_test`: team-host-details-sheet clipboard and golden.
  - Many team goldens in `goldens/team_golden_test`, `team_agent_golden_test`, `team_scenes_golden_test`, `revamp/screen_team_1/2/3_golden_test` and `shared_team_1_golden_test`. The set of failures matched base exactly, except the five stage-word goldens regenerated above.
  - `revamp/screen_work_4_golden_test`: 14 non-isolated-task shots.

## Images

Rendered by `test/revamp/slice_close_team_golden_test.dart`, which runs the same file on the base commit for "before". Each is at 412×915 dark and 1280×800 light.

| Page | Before | After |
|---|---|---|
| start-run-sheet, planner off | `before_plannerOff_dark.png`, `before_plannerOff_1280x800_light.png` | `after_plannerOff_dark.png`, `after_plannerOff_1280x800_light.png` |
| merged task | `before_merged_dark.png`, `before_merged_1280x800_light.png` | `after_merged_dark.png`, `after_merged_1280x800_light.png` |
| Task details stage line | `before_stage_dark.png`, `before_stage_1280x800_light.png` | `after_stage_dark.png`, `after_stage_1280x800_light.png` |
| question rows with an unconfirmed answer | `before_receipt_dark.png`, `before_receipt_1280x800_light.png` | `after_receipt_dark.png`, `after_receipt_1280x800_light.png` |
| worker page, closed dependency | `before_agent_dark.png`, `before_agent_1280x800_light.png` | `after_agent_dark.png`, `after_agent_1280x800_light.png` |
| isolated-task-sheet | `isolated-task-before-form_dark.png`, `isolated-task-before-form_1280x800_dark.png`, `isolated-task-before-creating_dark.png`, `isolated-task-before-failed_dark.png` | `isolated-task-after-form_dark.png`, `isolated-task-after-form_1280x800_dark.png`, `isolated-task-after-creating_dark.png`, `isolated-task-after-failed_dark.png`, `isolated-task-after-setup_failed_dark.png`, `isolated-task-after-setup_failed_1280x800_dark.png` |

## Not done here, and why

- **team-host-guide-sheet:** the copyable commands are the security slice's, since it also touches the host script. Its layout was not edited, so as not to collide with that change. If the security change leaves the layout as it is (prose steps, the repository path at the end), the layout part still needs a follow-up.
- **team-agent-output** ("This session has ended" state): the fix lives in `lib/ui/screens/chat/team_watch_live.dart`, which belongs to the chat library.
- **embedded-team-discovery-card** (fold the offer into the Plugins AI Team row): the fix lives in `lib/ui/screens/settings/plugins_screen.dart`, which belongs to the Plugins page. The row already says "Found on {server}", so only removing the card and adding Turn on to the row remain.
- **isolated-task "Run setup again":** there is no proven contract for it. `resetWorktree` resets the files, and nothing shows that it reruns setup. Per the feasibility rule it is left out.

## Needs a device

- Waking a suspended planner on a real Gas City front: how long the host takes to list the planner awake after `resume`.
- The isolated task on a real OpenCode 1 server: whether the first send lands after `worktree.ready`, and what happens with a slow setup.
