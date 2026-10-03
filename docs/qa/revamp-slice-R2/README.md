# revamp-slice-R2: Sheets, confirms and input dialogs: one close control, live actions, list body, text scale (2026-09-27)

## 1. Scope

- Unit: `slice-R2` (wave 3, kit-change). Finish line: a sheet has one close control, keeps changing primary and secondary actions pinned, can virtualise a long list, keeps half its room for the body at 250 % text, gives an in-place question its full height, and the input dialog opens in the confirm's frame with honest validation. Non-goal: no screen changes (callers adopt `secondaryDismisses`, `secondaryListenable` and the list body in their own units).
- Files changed: `lib/ui/kit/kit_sheet.dart`, `lib/ui/kit/kit_confirm_sheet.dart`, `lib/ui/kit/kit_consequences.dart`, `lib/ui/kit/kit_dialog.dart`, `test/kit/kit_dialog_test.dart` (2 expectations), new `test/kit/kit_sheet_r2_test.dart`, `test/kit/kit_dialog_r2_test.dart`, `test/kit/kit_confirm_sheet_r2_test.dart`, `test/goldens/kit/kit_sheet_r2_golden_test.dart` and its 16 PNGs.
- Pages (map ids): none (kit part change).
- Specs followed: STANDARDS.md KIT-17, KIT-43 (additive), STATE-8, DATA-1/DATA-3, A11Y-8, LAY-6/7; kit-api KitSheet.md, KitConfirmSheet.md, KitDialog.md; owner rules 2026-09-27 (nothing shown twice, actions name their target, English only).
- Contract problems (PROC-20):
  1. KitDialog.md "Data safety": "Without a draft, a tap outside does nothing once the text differs". The unit moves the input dialog into the confirm's bottom-sheet frame, whose barrier pops through `maybePop`; a tap outside with changed text now asks the discard question in place (the same rule KitSheet already follows). Nothing is lost; the spec text should say "asks the discard question". Blocks nothing.
  2. KitDialog.md "States > Empty": "the primary is disabled with the reason shown as disabledReason under it" before the first edit. The unit's acceptance overrides it: nothing is judged before the first edit (the primary stays enabled; a tap with invalid text shows the reason under the field), and the reason never sits under the button. Spec text to update by the coordinator.
  3. EVID-1 asks for a dated folder; the task text and the existing `docs/qa/revamp-chat-*` folders use `docs/qa/revamp-<unit id>/`. This record follows the task text.
- New kit parts (KIT-3): none. New public API (additive): `showKitSheet(secondaryListenable:, secondaryDismisses:, itemCount:, itemBuilder:)` with `body` now optional (exactly one of `body`/`itemBuilder`); `KitSheet.list(...)`, `KitSheet.showClose`; `KitConsequenceMark.neutral`; `presentKitConfirmFrame` (kit-internal, used by kit_dialog.dart).
- Map items (EVID-11): n/a: no pages.
- States per page (STATE-20): n/a: no pages.
- Deferred states (STATE-21): none.

### What moved or went (owner rule: rethink)

- The header X is left out when the secondary is a plain dismiss (`secondaryDismisses`): one close control, not two.
- The confirm's alternative moved from under Cancel to between the confirm and Cancel (phone: confirm, alternative, Cancel; wide: Cancel, alternative, confirm in one wrapping row).
- The input dialog's reason no longer shows under the button before anything was typed; it shows once, under the field.
- The input dialog left its own centred dialog frame for the confirm's frame (bottom sheet with handle on a phone, the confirm's panel on a PC). The alert keeps the centred blocking dialog.
- The stale `_KitConsequences` doc comment in kit_consequences.dart is corrected.

## 2. Builds

- Branch `revamp/slice-R2`, base `643a5104` (revamp/leftovers), code head: the commit before this record's commit (see `git log`).
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 3 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_sheet_r2_test.dart` | passes | 10 passed | PASS |
| 2 | `test/kit/kit_dialog_r2_test.dart` | passes | 6 passed | PASS |
| 3 | `test/kit/kit_dialog_test.dart` | passes | 38 passed | PASS |
| 3b | `test/kit/kit_confirm_sheet_r2_test.dart` (after the wide-row Wrap) | passes | 5 passed | PASS |
| 4 | `--update-goldens test/goldens/kit/kit_sheet_r2_golden_test.dart` | 16 shots render, G5 checks pass | 16 passed, every image opened | PASS |
| 5 | `test/kit_ratchet_test.dart` | no violation in the write set | failures only in files outside the write set (kit_choice_list, kit_task_card, kit_board_lane, kit_log_panel, kit_checklist, kit_viewer, kit_nav, kit_top_bar, integration_tiles, quota_monitor_section); kit_sheet.dart "EdgeInsets numeric" 1 -> 0 | PASS (write set) |
| 6 | `test/golden_harness_test.dart` | new goldens named per TEST-20 | only pre-existing `test/revamp/goldens/system_run-command-dialog_*` names fail | PASS (write set) |
| 7 | `flutter analyze lib/ui/kit` + the changed tests | no issues | no issues | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden |
  |---|---|
  | one close control | `test/kit/kit_sheet_r2_test.dart` "a dismissing secondary replaces the header X" |
  | KIT-17 live secondary | `test/kit/kit_sheet_r2_test.dart` "a live secondary changes in place and stays pinned" |
  | virtualised list | `test/kit/kit_sheet_r2_test.dart` "a list body builds only the rows in view" (5000 rows, < 60 built) |
  | 250 % text, 320x640 | `test/kit/kit_sheet_r2_test.dart` "at 2.5 the header scrolls away and the body keeps half" / "at 1.0 the header stays pinned"; golden `kit_sheet_text250_*` |
  | question at full height | `test/kit/kit_sheet_r2_test.dart` "a question in place over a sheet gets the full sheet height" |
  | 800x600 reach | `test/kit/kit_sheet_r2_test.dart` "at 800x600 ..." and "at 1024x600 ..." (side sheet) |
  | alternative placement | `test/kit/kit_confirm_sheet_r2_test.dart` group "the alternative sits between the confirm and Cancel" |
  | neutral mark | `test/kit/kit_confirm_sheet_r2_test.dart` group "the neutral mark" |
  | `_lastText` first edit | `test/kit/kit_dialog_r2_test.dart` "the first edit already counts" |
  | same frame as confirm | `test/kit/kit_dialog_r2_test.dart` "on a phone it is a bottom sheet with a handle, like a confirm" |

- Changed test expectations (TEST-19): `test/kit/kit_dialog_test.dart` #2: "reason under the primary before the first edit" -> "nothing judged before the first edit; a tap shows it under the field" (unit acceptance). #6: "a tap outside does nothing" -> "a tap outside asks the discard question" (confirm frame, DATA-3).
- Frame rule: the header stays fixed only while it takes at most half of the room the pinned actions leave; otherwise it scrolls with the body. At 320x640 and 2.5x the body keeps 346 of 576 dp (60 %).
- Goldens added (each opened): `kit_sheet_text250`, `kit_sheet_oneclose`, `kit_confirm_sheet_alternative`, `kit_dialog_inputframe`, each at 412x915 and 1280x800, dark and light. No approved VL canvas render exists for these states (EVID-12: n/a).
- Integrator-owned goldens now stale (not re-rendered, R07): `kit_confirm_destructive_*` (the alternative moved), `kit_dialog_input_*` (input dialog frame). kit_sheet_* goldens are expected unchanged at scroll offset 0.
- Before and after: `before-kit-confirm-destructive.png` (base golden) vs `after-kit-confirm-alternative.png`; `before-kit-dialog-input.png` vs `after-kit-dialog-inputframe.png`; `after-kit-sheet-text250.png`, `after-kit-sheet-oneclose.png` (no before render: new states).
- Accessibility: the close button stays a 48 dp labelled target when shown; without it the handle keeps its "Dismiss" action and back/Esc close. The neutral dot is excluded from semantics. At 250 % text the header scrolls with the body, the actions stay pinned and reachable.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_sheet_r2_test.dart test/kit/kit_dialog_r2_test.dart
$F test -j 1 test/kit/kit_confirm_sheet_r2_test.dart test/kit/kit_dialog_test.dart
$F test -j 1 test/goldens/kit/kit_sheet_r2_golden_test.dart
$F analyze lib/ui/kit
```

## 7. NOT proven

- Not run on a device or emulator.
- `test/kit/kit_sheet_test.dart`, `kit_sheet_live_actions_test.dart`, `kit_sheet_wrap_test.dart`, `kit_confirm_sheet_test.dart`, `kit_confirm_sheet_look_test.dart`, `kit_consequences_test.dart` and the kit_sheet/kit_confirm/kit_dialog galleries were not re-run (owner decision 2026-09-27: own tests only).
- No caller uses `secondaryDismisses`, `secondaryListenable` or the list body yet.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/slice-R2` |
| Enabled | Yes (opt-in flags for the new sheet features) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | `revamp/slice-R2` |
| Deployed | No | |
| Released | No | |
