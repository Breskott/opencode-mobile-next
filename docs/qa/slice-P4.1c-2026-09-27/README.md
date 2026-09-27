# slice-P4.1c: Team gates on the same card (2026-09-27)

## 1. Scope

- Finish line (work-units.json): both TeamReceiptChip wrappers are deleted, gate_sheet's `_Receipt` is deleted, the gate sheet is only the Details variant, and team gates use KitRequestCard and KitReceipt. Non-goal: no supervision changes (no gateway call, controller field or stored format added).
- Owner override for this slice: the chat library (`chat_screen.dart`, `chat/**`, `kit/chat/**`) is owned here. `team_home_screen.dart` and the team home widgets stay untouched, because slice-P3.4 is editing them.
- Leftover also fixed here: the Saved prompts subtitle said "kept on this device for this server". Since P7.2, Saved prompts also holds queued prompts from removed servers, and they show under every server. It now reads "Newest first · kept on this device".
- sliceAdditions (leftover-units.json): team receipts in a moving state name the act through `KitReceipt.sendingLabel` instead of `automatic: true`. This covers the control receipts ("Nudge · Sending…") and the board card's move ("Moving to Review…").

## 2. What changed, per page

- **The gate's card** (`team_needs_you.dart`, `TeamNeedsYouCard`). It shows in the team conversation, on a task's Overview and on the AI Team home. It is now the one `KitRequestCard.ask`, the same card chat-5 uses for permissions and questions. It answers by itself through `OrchestrationController.answerGate`, so any screen that shows it can answer from there, the home included, without editing the home.
  - Decision: its options are in place and one tap sends (a double tap sends once). The chosen option carries the receipt.
  - Approval: Approve and Deny are in place. Deny sends at once, as Reject does on the chat card. A destructive approval is answered in Details, behind its two steps.
  - Free text: the reply field and Send are in the card. Its draft is the Gate sheet's own (`oc.draft.team-gate.<id>.<profileId>`), so words typed in either place survive. The draft is cleared once the answer leaves and is not refused.
  - Gate bead: "Answer" opens Details. Failed task: "Choose what to do" opens Details, with the reason "Stuck: needs you". Review ready: Details only.
  - The receipt is one `KitReceipt`: "Sending…" escalates to "Not confirmed yet" with Try again, and a refusal shows "Not accepted: {reason}" above the answers, which stay. A confirmed answer collapses the card. A phone that only watches says where to answer and keeps Details.
  - The caption is "Needs your decision · {who} · waiting 4 min". `who` is the task on the home and the agent (`teamGateWho`) in the conversation and on the Overview.
- **The Gate sheet** (`gate_sheet.dart`) is now the card's Details.
  - Its title is the ask, and the separate headline in the body is gone, so the ask is said once. A failed task keeps its title ("Sync engine stopped").
  - The subtitle is "{kind} · {task} · {age}".
  - Deny no longer asks a second time.
  - The receipt shows "Sending…" while the host has not answered.
  - Every failure action is kept, including **Report this failure** (P8.4).
  - There was no `_Receipt` class left to delete: screen-team-1 had already moved the sheet to `KitReceipt`.
- **Receipts**:
  - `team_controls.dart`: `TeamReceiptChip` is deleted. `teamControlReceipt(context, record, …)` returns the one `KitReceipt` and is used by `run_screen.dart`, `team_cycle_strip.dart` and the chat's team conversation (`_teamReceipt`).
  - `team_receipt.dart`: `teamGateRowReceipt(context, record, onOpen:)` returns the row's `KitReceipt`, or null once the answer is confirmed. It is used by Activity, the agents list and `TeamGateRow`.
  - `team_board_card.dart`: the move receipt uses `sendingLabel`.
- **Copy** (`app_en.arb`):
  - New: `teamControlReceiptSending`, `teamGateCardRunFailedOpen`, `teamGateCardIfIgnored`, `teamGateCardIfIgnoredFailed`, `teamGateCardIfIgnoredReview`.
  - Changed: `promptStashIntro`.
  - Deleted as unused, from en and ar: `teamUiHomeNeedsYouMore`, `teamUiGateAnswerChipSent`, `teamUiGateAnswerChipUnconfirmed`, `teamUiGateAnswerChipRejected`, `teamUiGateAnswerConfirmDenyTitle`, `teamUiGateAnswerConfirmDenyBody`.
  - gen-l10n was run.

## 3. Not done (blocker, for the coordinator)

- **One TeamReceiptChip remains**, in `lib/ui/widgets/team_receipt.dart`, now a three-line forward to `teamGateRowReceipt`. Its only caller is `team_home_screen.dart`, which slice-P3.4 is rewriting (its worktree still calls `TeamReceiptChip(key:, record:, onOpen:)`).
  - When P3.4 merges, replace that call with `teamGateRowReceipt(context, record, key: …, onOpen: …)` (it returns `Widget?`, null for confirmed), then delete the class.
  - After that, `teamUiGateAnswerChipUnconfirmedSemantics` is still used by `teamGateRowReceipt`, so keep it.
  - Until then the acceptance item "one receipt class in the codebase" holds everywhere except that one forwarding wrapper.
- The gate sheet keeps the plain sheet tone. `KitSheetTone.attention` outside the kit trips G17 (LOOK-24), so the attention header stays the card's own.
- The Gate sheet still answers and shows its own receipt before it closes on confirmation, as before. Moving a failed task's "Ask the team to fix it" receipt onto the card would need `teamGateMutation` to count agent messages as answers, which is a supervision semantics change (non-goal).

## 4. Tests

New:

- `test/revamp/slice_p4_1c_test.dart` (10 tests). It covers:
  - a decision is the card and one tap sends once, with "Sending…" on the chosen option;
  - Approve and Deny in place, with no second step;
  - a destructive approval in Details, behind two steps;
  - a free-text reply in the card that shares the sheet's draft and is cleared once sent;
  - a refusal that shows its reason and keeps the answers;
  - a failed task whose Details keep Report this failure;
  - watch-only;
  - the sheet titled with the ask;
  - row receipts;
  - the Saved prompts copy.
- `test/revamp/slice_p4_1c_golden_test.dart` renders 24 goldens (6 scenes × 412x915 / 1280x800 × dark / light). Its harness is in `slice_p4_1c_support.dart`.

Updated expectations (changed behaviour): `shared_team_1_test` and `kit/kit_receipt_test` (the wrappers' groups now test `teamControlReceipt` and `teamGateRowReceipt`), `team_gate_answer_test` (Deny is one step, "Sending…", the card's refusal), `team_conversation_screen_test` (one tap sends, no Send), `team_home_test` and `team_run_screen_test` (the caption words, the watch-only line as the card's detail), `team_controls_test` and `team_one_page_test` ("{control} · Sending…", "Not accepted"), and `kit_ratchet_baseline.json` (team_receipt.dart's G17 entry goes to 0). The gate goldens in `test/goldens/team_agent_golden_test.dart` (gate · …) and `team_sheets_golden_test.dart` (gate sheet) were re-rendered.

Runs, with the pinned Flutter 3.47.1 and `--concurrency=5`, on the same 23 files at the base `c90ff900` (in a temporary second worktree) and on this branch:

| Run | Passed | Failed |
|---|---|---|
| base | 329 | 72 |
| this branch (+ the 2 new files) | 372 | 63 |

- Every failure on this branch also fails on the base, except `team_controls_test` "nudge the host refuses: Not accepted with the reason". That is the renamed "…Refused with the reason", and it fails on both at `scrollToControls` (pre-existing).
- This branch fixes 10 of the base's failures: 6 stale gate goldens, "two-step Cancel run", and both P0.4 Stop task tests.
- The pre-existing failures are in these areas: the team_controls layout and scroll tests, the team_activity sheet-closing tests, team_home, the shared_team_1 and team_agent (agent top) stale goldens, the team work sheet goldens, the G17/G21 ratchet (other files), and design_standard goldens.
- `flutter analyze`: no issues.

## 5. Evidence (this folder)

| Before (base) | After |
|---|---|
| `before-card_choice_dark.png` | `after-card_choice_dark.png`, and `after-card_choice_sending_dark.png` (after a tap) |
| `before-card_approval_dark.png` | `after-card_approval_dark.png` |
| `before-card_approval_1280x800_light.png` | `after-card_approval_1280x800_light.png` |
| `before-card_choice_1280x800_light.png` | `after-card_choice_1280x800_light.png` |
| `before-card_free_text_dark.png` | `after-card_free_text_dark.png` |
| `before-card_run_failed_dark.png` | `after-card_run_failed_dark.png` |
| `before-details_choice_dark.png` | `after-details_choice_dark.png` |
| `before-details_choice_1280x800_dark.png` | `after-details_choice_1280x800_dark.png` |
| `before-gate_sheet_run_failed_dark.png` | `after-gate_sheet_run_failed_dark.png` |

## 6. Still needs a device

The unit's proof: on the emulator with the spike city, answer a gate in the conversation (a decision by tap, an approval in place, a reply) and watch the receipt go Sending → collapsed once the host confirms. Also open a failed task's Details and use Report this failure. No device was used here.
