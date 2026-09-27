# revamp-slice-R6: KitChoiceList current vs selected, KitNotice.offer layout, KitReceipt sending words, KitTaskCard single error glyph (2026-09-27)

## 1. Scope

- Unit: `slice-R6` (wave 3, kit-change, tier 1). Finish line: the four kit parts say each thing once: "Current" only marks the applied value during a pending change, a choice carries its own actions, the offer's close ends its sentence line, a receipt can name its act while sending, and a failed card draws one error glyph. Non-goal: moving callers (the voice model picker, the team board move sheet) onto the new options.
- Files changed: `lib/ui/kit/kit_choice_list.dart`, `lib/ui/kit/kit_notice.dart`, `lib/ui/kit/kit_receipt.dart`, `lib/ui/kit/kit_task_card.dart`; tests `test/kit/kit_r6_choice_current_test.dart` (new), `test/kit/kit_r6_notice_receipt_task_card_test.dart` (new), `test/kit/kit_choice_list_test.dart`, `test/kit/kit_notice_test.dart`; gallery `test/goldens/kit/kit_choice_list_golden_test.dart` (new state `pending_change`) and the goldens listed in §5.
- Pages (map ids): none (kit change; the pages adopt it in their own units).
- Specs followed: STANDARDS.md §1, §15, §16; kit-api `KitChoiceList.md`, `KitNotice.md`, `KitReceipt.md`, `KitTaskCard.md` (additive changes only, R11); owner rules of 2026-09-27 (nothing shown twice, actions on the thing they act on, kit only, English only).
- Contract problems (PROC-20):
  - `KitChoiceList.md` "Current" (line 223): "marks the `selected` row as `current` only when `actsOnTap && !sends`". The unit acceptance (later owner rule) replaces it: "Current" shows only on the applied value (`current:`) while a different value is selected, never beside the radio that marks it. Proposed text: "`KitChoiceList.single(current:)` names the applied value; its row says Current only while `selected != current`; with `sends` it never does." Blocks: nothing (the spec file is outside this write set).
  - `KitNotice.md` Tests required 2 (line 268): "The action and dismiss share the row when the message wraps at 2.0 text." Replaced by the acceptance: the close ends the sentence's first line and the action starts under the sentence at its text inset. Blocks: nothing.
  - STANDARDS EVID-1 names the folder `docs/qa/revamp-<unit id>-<date>`; the task and the existing records (`revamp-chat-1` …) use `docs/qa/revamp-<unit id>`. This record follows the task.
- New kit parts (KIT-3): none. New optional API: `KitChoiceList.single(current:)`, `KitChoice(menu:, menuLabel:)`, `KitChoiceRow(menu:, menuLabel:)`, `KitReceipt(sendingLabel:)`, `KitReceipt.span(sendingLabel:)`.
- Map items (EVID-11): n/a: no pages in this unit.
- States per page (STATE-20): n/a: kit parts; states covered by the part tests and galleries below.
- Deferred states (STATE-21): none.

### What moved or was removed (owner rethink rule)

- "Current" beside the selected radio in pickers and setting lists: removed (the radio already says it). It now appears only on the applied value while another value is selected.
- Per-choice actions ("Download Fast again", "Delete Fast") can now sit on the choice's own row menu instead of an action stack under the list. The voice picker (`lib/voice/voice_ui.dart`) still shows them below the list; moving them is caller work (not in this write set).
- The offer's close moved from beside the action (second line) to the end of the sentence's first line.
- The failed and stopped card's second glyph on the flag line: removed; the leading mark is the one glyph.

## 2. Builds

- Branch `revamp/slice-R6`, base `643a5104`, code head `24840cc8`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 3 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_r6_choice_current_test.dart` + `test/kit/kit_r6_notice_receipt_task_card_test.dart` | pass | 16 passed | PASS |
| 2 | `test/kit/kit_choice_list_test.dart` + `test/kit/kit_notice_test.dart` (edited expectations) | pass | 61 passed | PASS |
| 3 | `test/goldens/kit/kit_choice_list_golden_test.dart --update-goldens` | renders; changed images looked at | 26 passed | PASS |
| 4 | `test/goldens/kit/kit_task_card_golden_test.dart --update-goldens` | renders; changed images looked at | 20 passed | PASS |
| 5 | `test/goldens/kit/kit_notice_golden_test.dart --update-goldens` | renders; only offer images change | 52 passed; 4 offer images changed | PASS |
| 6 | `flutter analyze` on the 4 parts, the 5 test files and the callers `voice_ui.dart`, `question_options.dart`, `team_board_card.dart` | no issues | no issues | PASS |

Not run (owner decision 2026-09-27, run only own tests): `kit_receipt_test.dart`, `kit_task_card_test.dart`, the ratchet, design-standard and l10n gates.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | Current vs selected | `test/kit/kit_r6_choice_current_test.dart` "a pending change: Current moves to the applied value only" | run 1 |
  | Never beside its radio | same file, "KitChoiceRow: current on the selected row stays silent", "a picker that acts on tap never repeats its radio" | run 1 |
  | Row menu on the choice | same file, "a choice carries its own row menu; the tap still selects", "the row menu opens on long-press too" | run 1 |
  | Offer layout | `test/kit/kit_r6_notice_receipt_task_card_test.dart` "wrapped: the close ends the first line…"; `test/kit/kit_notice_test.dart` "at 2.0 text the close ends the first line…" | runs 1, 2 |
  | Sending words escalate | `test/kit/kit_r6_notice_receipt_task_card_test.dart` "still turns into Not confirmed yet with Try again" | run 1 |
  | One error glyph | same file, "a failed card shows the error glyph once", "a stopped card shows the stop glyph once" | run 1 |

- Changed test expectations (TEST-19):
  - `kit_choice_list_test.dart` "a picker shows Current on the selected row" → "the selected radio never says Current": expects no "Current" (owner rule, nothing shown twice).
  - `kit_notice_test.dart` "at 2.0 text the action and the close share the row" → "the close ends the first line and the action starts under the sentence at its text inset" (unit acceptance).
- Goldens changed (each opened and looked at):
  - `kit_choice_list_default{,_1280x800}_{dark,light}.png`: "Current ·" gone from the selected Production row.
  - `kit_choice_list_choice_disabled_{dark,light}.png`: "Current" gone from the selected Staging row.
  - `kit_choice_list_pending_change_{dark,light}.png` (new): Fast says "Current · On this phone" with its "More" menu; Balanced is selected with no "Current".
  - `kit_notice_offer_wrapped_{dark,light}.png`, `kit_notice_offer_text2_{dark,light}.png`: the close sits at the end of the sentence's first line; the action starts at the text inset under it.
  - `kit_task_card_failed_{dark,light}.png`, `kit_task_card_stopped_{dark,light}.png`: the flag line lost its duplicate glyph.
  - Approved VL canvas renders: none for these states (EVID-12).
- Before and after (EVID-10): `before-kit_choice_list-default.png` / `after-kit_choice_list-default.png`, `after-kit_choice_list-pending_change.png` (no before: new state), `before-kit_notice-offer_wrapped.png` / `after-kit_notice-offer_wrapped.png`, `before-kit_task_card-failed.png` / `after-kit_task_card-failed.png` (base `643a5104` goldens).
- Accessibility: the choice row stays one merged selection node; its menu button is a separate `KitIconButton` ("More", 48 dp target) and the menu is also a custom action on the row (KitTappable). The offer's close keeps its 48 dp target and label; at 2.0 text it stays on the first line (golden `kit_notice_offer_text2`). The receipt's live region announces the sending words, then "Not confirmed yet" once.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.
- Copy: no new ARB keys (the sending words are the caller's; "Current" is the existing `kitChoiceCurrent`), so gen-l10n was not needed.
- Unrelated, found and left: `kit_choice_list_empty_*` and `kit_choice_list_picker_row_*` goldens already differ from the base render (KitStateView and KitPickerRow drift from other units); they were rendered, not staged, and are left for the integrator.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_r6_choice_current_test.dart test/kit/kit_r6_notice_receipt_task_card_test.dart
$F test -j 1 test/kit/kit_choice_list_test.dart test/kit/kit_notice_test.dart
$F test -j 1 test/goldens/kit/kit_choice_list_golden_test.dart test/goldens/kit/kit_task_card_golden_test.dart test/goldens/kit/kit_notice_golden_test.dart
$F analyze lib/ui/kit/kit_choice_list.dart lib/ui/kit/kit_notice.dart lib/ui/kit/kit_receipt.dart lib/ui/kit/kit_task_card.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- No caller uses `current:`, the choice row menu or `sendingLabel` yet (voice picker, team board move receipt); their pages are unchanged.
- The full suite, the ratchet, design-standard and l10n gates were not run (owner decision 2026-09-27).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/slice-R6` |
| Enabled | Yes (kit parts; opt-in options unused by callers) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `24840cc8` |
| Deployed | No | |
| Released | No | |
