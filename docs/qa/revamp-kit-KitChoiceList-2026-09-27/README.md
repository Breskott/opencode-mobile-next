# revamp-kit-KitChoiceList: KitChoiceList, KitChoiceRow, KitPickerRow (2026-09-27)

## 1. Scope

- Unit: `kit-KitChoiceList` (wave 1, tier 3, kit-part). Finish line: one kit part picks from a list (single acting on tap, multi, "Something else", sent receipts, picker rows and the picker sheet), and `question_options.dart` forwards to it. Non-goal: migrating call sites (wave 2), request-card chrome, anchored dropdowns.
- Files changed: `lib/ui/kit/kit_choice_list.dart` (new), `lib/ui/widgets/question_options.dart` (now @Deprecated forwarding wrappers, R12), `lib/l10n/app_en.arb` + generated `app_localizations*.dart`, `test/kit/kit_choice_list_test.dart`, `test/goldens/kit/kit_choice_list_golden_test.dart` and its 24 PNGs.
- Pages (map ids): none migrated (kit part only).
- Specs followed: `docs/ux-system/kit-api/KitChoiceList.md` (frozen API); STANDARDS KIT-25, KIT-26, STATE-9, STATE-10, AUTO-8, MOT-11, DATA-2; kit-v2 §1.7, §8.2; owner decisions 2026-09-27 (speed; Arabic dropped).
- Contract problems (PROC-20):
  1. `KitTokens.choiceRowMinHeight` (56) is not on the kit tokens yet (pre-wave `_new-tokens.md`). As the spec says, rows use `rowHeightTwoLine` (60) as the floor until it lands.
  2. The spec's `KitChoiceOther` has `onSubmitted` but no visible way to send a multiline answer (Enter adds a line). A `KitField.action` send button was added with one new key `kitChoiceOtherSend` "Send answer" beyond the four listed kit keys. Proposed: list `kitChoiceOtherSend` in the spec's kit copy.
  3. `KitChoiceRow` gained one optional parameter, `focusNode`, beyond the frozen block: `KitChoiceList` needs it to move focus with the arrow keys (§8.2) through `KitTappable`. Additive; proposed for the spec.
  4. The spec's gallery list (40 PNGs, Arabic, 2.0 text, six sizes) is superseded by the owner decision of 2026-09-27: phone 412x915 for every state and 1280x800 for the default, dark and light, no Arabic (24 PNGs). The empty-assert lives in `build` (a `const` constructor cannot assert on `List.isEmpty`).
- New kit parts (KIT-3): `KitChoiceList` (planned part, this unit). Also in the file: `KitChoice`, `KitChoiceOther`, `KitChoiceRow`, `KitChoiceMark`, `KitPickerRow`, `showKitChoiceSheet`. Not exported from `kit.dart` (R06: the integrator adds the export).
- Map items (EVID-11): deferred to wave-2 migration units.
- States (STATE-20): KitChoiceList default, loading, empty, choice-disabled, multi, other, sending, answered, answered-elsewhere; KitPickerRow default, single-option, disabled: each a golden below and covered by a behaviour test.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitChoiceList`, base `024e97b0`, code head: see `git log`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_choice_list_test.dart` + `test/goldens/kit/kit_choice_list_golden_test.dart` (`--update-goldens`, then images inspected) | pass | all passed (26 behaviour + 24 gallery, G5 checks in both themes) | PASS |
| 2 | `dart analyze` on the changed files and the three importers of `question_options.dart` | no issues | no issues | PASS |
| 3 | Other suites (ratchet, design-standard, l10n, `chat_question_card_test.dart`, `activity_requests_test.dart`) | — | not run (owner decision 2026-09-27: own new tests only) | NOT RUN |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test / golden |
  |---|---|
  | G9 one tap, one callback | "single: one tap, one callback (G9)" |
  | STATE-9 Current / shape | "a picker shows Current…", "selection is a shape…" |
  | STATE-10 receipt | "receipt: Sending, Sent, Answered, then Not confirmed yet"; goldens sending, answered, answered_elsewhere |
  | MOT-11 haptics | "haptics" group |
  | DATA-2 draft | "other › a draft survives dispose and remount" |
  | AUTO-8 one option | "KitPickerRow › one choice: no chevron and no sheet"; golden picker_row (Shell) |
  | KIT-25 56 dp | "rows are at least 56 dp tall" |
  | G14 keyboard | "keyboard: Tab enters on the selected row…"; "showKitChoiceSheet pops… Esc with null" |
  | G6 overflow | "no overflow from 320 to 1600 dp at 1.0, 1.3 and 2.0 text" |

- Changed test expectations (TEST-19): none.
- Goldens added (each opened and looked at): `test/goldens/kit/kit_choice_list_*_{dark,light}.png` (24). Fixed after the first look: "Current" no longer trails a separator when a choice has no supporting text; the picker row's value now sits at the row's end instead of mid-row.
- Accessibility: each row is one merged node (button, selected + in-mutually-exclusive-group for single, checked for multi); marks are shapes (ring + dot, box + check), never colour alone; titles wrap; picker value moves under the title at text ≥ 1.3.
- Privacy and security: the "Something else" draft uses `KitDraft` (`oc.draft.<target>.<profileId>`), so profile deletion sweeps it.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_choice_list_test.dart test/goldens/kit/kit_choice_list_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- `chat_question_card_test.dart` and `activity_requests_test.dart` were not run through the new wrappers (owner decision: own tests only); the wrapper keeps the `question-option-<label>` key on the row's gesture and `TextField` inside `KitField`, but a test that reads the old InkWell/row geometry may need the integrator.
- Hover fill and focus ring on a fine pointer are inherited from `KitTappable`, not shown in a golden.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitChoiceList` |
| Enabled | No: no screen uses it yet (wave 2); `question_options.dart` users get it through the wrappers | |
| Verified | Own tests and goldens only | this record |
| Committed | Yes | `revamp/kit-KitChoiceList` |
| Deployed / Released | No | |
