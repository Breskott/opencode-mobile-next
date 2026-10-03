# revamp-kit-KitRequestSheet: KitRequestSheet, the one details sheet for a request (2026-09-27)

## 1. Scope

- Unit: `kit-KitRequestSheet` (wave 1, tier 5, kit-part). Finish line: `showKitRequestSheet` opens a request card's details (permission, question/choice, form, gate, reply) with the card's header and pinned answers, answers once through the card's callbacks, and closes itself through `RequestRoutes`. Non-goal: no screen adoption (the four old sheets move with chat-5, shared-chat-3, screen-shell-1 or slice-P3.11a, and slice-P4.1c).
- Files changed:
  - `lib/ui/kit/kit_request_sheet.dart` (new part);
  - `test/kit/kit_request_sheet_test.dart` (new, 35 tests);
  - `test/goldens/kit/kit_request_sheet_golden_test.dart` and 24 `kit_request_sheet_*.png` (new);
  - `lib/l10n/app_en.arb` (+2 keys: `kitRequestChooseOneReason`, `kitRequestSendAnswers`) and the regenerated `lib/l10n/app_localizations*.dart`.
  - Not touched: `lib/ui/kit/kit.dart` (the integrator adds `export 'kit_request_sheet.dart';`, R06), ratchet and l10n baselines.
- Pages (map ids): permission-sheet, question-sheet, gate-sheet, form-sheet (their merge target; adoption is not this unit).
- Specs followed: `docs/ux-system/kit-api/KitRequestSheet.md` (frozen API, built as written); STANDARDS.md KIT-11, KIT-16, KIT-17, KIT-30, KIT-33, SEC-9, DATA-1, DATA-2, DATA-3, AUTO-12, AUTO-17, STATE-8, STATE-10, LAY-10, A11Y-3, MOT-11, TEST-9, TEST-20; kit-v2 §2.1, §8.2.
- Owner decisions applied (2026-09-27): Arabic dropped (no ar ARB entries, no RTL test 14, no `_ar` galleries); galleries at 412×915 and 1280×800 only, light and dark (24 PNGs instead of the spec's 40); tests written once, only this unit's files run.
- Contract problems (PROC-20):
  1. **Form `submit` is a snapshot.** KitRequestSheet.md gives `KitAction? submit` and test 8 says "submit is disabled with its reason until valid". `showKitSheet` takes its pinned actions once at call time, so a host cannot enable `submit` when its fields become valid. Built: the disabled submit with its reason (test 8 "submit disabled shows its reason"), and an enabled submit answers once. Proposed: `ValueListenable<KitAction>? submit` here, or listenable actions on `showKitSheet` (kit-KitSheet). Blocks: form adoption (shared-chat-3), not this part.
  2. **`showKitSheet` has no live pinned actions.** The kit's own live answers (ChooseMany's Send, reply's Send) need to enable themselves. Built inside this file only: a private `KitAction` subclass whose `onPressed`/`disabledReason` read the sheet's session, rebuilt through the frame's `dirty` listenable, whose value stays the host's own unsaved flag (false when none). Side effect: a ChooseMany sheet (no draft) lets the frame own the swipe (handle and header pull-down close it; `canPop` stays true, nothing is asked). Proposed: `showKitSheet(actionsChanged: Listenable)` in kit-KitSheet. `blocks: false`.
  3. **`KitRequestChooseMany<T>` loses `T`.** It reaches the kit through the sealed `KitRequestAnswers`, so the kit cannot build a `Set<T>` for `onSend`. Built: the set is reified for `String` and `int` values (question ids and indexes); any other `T` must be `Object?`/`dynamic`. Proposed: a public `KitRequestChooseMany.sendChosen(Set<Object?>)` in kit_request_card.dart (kit-KitRequestCard owner). `blocks: false` for OC question options (strings).
  4. **gate-confirm from Approve.** "Answering here" closes the sheet right after the card's callback, so a `showKitConfirm` raised by the host's `onAllow` is dropped with the route. The in-place confirmation works when raised from inside the sheet (test 9 "an in-place showKitConfirm adds no route"; gallery `gate_confirm`). Proposed: `KitRequestDecide(confirmAllow: Future<bool> Function())` or a sheet parameter that confirms before answering. Blocks: slice-P4.1c's merge confirmation.
  5. **KitSheet frame overflow at 2.0 text with the keyboard.** Spec test 13 (412×915, text 2.0, `viewInsets.bottom` 300): `kit_sheet.dart:349` Column overflows by 43 px because its header and pinned block do not shrink; only the body scrolls. Not this part's code. Test 13 is split into "2.0 text" and "the keyboard open (300 dp)", each passing. Proposed (kit-KitSheet): at 2.0 text the header scrolls with the body. `blocks: false`.
  6. **Disabled primary contrast in dark** (known, docs/qa/revamp-kit-KitAction-v2-2026-09-26 contract problem 3): `text3` on `surface3` is 4.44:1 and G5 fails it. The `question_many`, `form` and `reply` galleries therefore show the enabled Send; the disabled Send/submit with its reason is covered by tests 7, 8 and "reply".
  7. **Permission `fullText` kind.** The spec says the command block holds "the full command, path or pattern list". A `command` block draws a `$` prompt, wrong for a path, so the block is `command` without `change` and `output` (no prompt) when a `change` is shown (an edit's path). Both are mono, left to right, copyable and never capped.
- New kit parts (KIT-3): `KitRequestSheet` (`showKitRequestSheet`, `KitRequestSheetOutcome`, `KitRequestAlwaysAllow`, `KitRequestMessage`).
- Map items (EVID-11): every `actionsMissing`/`statesMissing` item of permission-sheet, question-sheet, gate-sheet and form-sheet belongs to the adopting units: deferred to chat-5 (permission, form flow), screen-shell-1 or slice-P3.11a (question), slice-P4.1c (gate), shared-chat-3 (form frame).
- States (KIT-12, from the doc comment): permission, permission-always, permission-change, question, question-many, form, form-discard, gate, gate-confirm, reply → goldens; closed-elsewhere → test 3.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitRequestSheet`, base `4c871866`, code head `2c762c46`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only | n/a: new part, fixes nothing | n/a | PASS |
| 2 | `test/kit/kit_request_sheet_test.dart` | passes | 35 passed (`run-tests.txt`) | PASS |
| 3 | `test/goldens/kit/kit_request_sheet_golden_test.dart` (G5 in both themes per shot) | passes | 24 passed (`run-tests.txt`) | PASS |
| 4 | `flutter analyze` on the three new Dart files | no issues | no issues (`run-analyze.txt`) | PASS |
| 5 | Ratchet, design-standard, l10n, glossary, ledger tests | pass | not run: owner decision 2026-09-27 (own files only) | n/a |

## 5. Evidence

- Rule evidence (PROC-31), all in `test/kit/kit_request_sheet_test.dart`, output `run-tests.txt`:

  | Rule | Test (`--plain-name`) |
  |---|---|
  | header is the card's | "1. the header is the card's" |
  | AUTO-17, G9, one send haptic | "2. answered here" |
  | AUTO-12 | "3. answered elsewhere the route goes a frame after isPending turns false"; "already not pending: nothing opens" |
  | DATA-1, DATA-3 | "4. dismissed back / Esc / Close / tap outside / swipe down returns dismissed"; "the typed reject note is restored on reopen" |
  | KIT-30, SEC-9 | "5. Always allow …" (both) |
  | KitChoiceList sends | "6. question …" (both) |
  | STATE-8 | "7. ChooseMany …"; "8. form submit disabled shows its reason"; "reply: Send is disabled …" |
  | DATA-2, KIT-16 | "8. form with draft …"; "with dirty only, back asks the discard question in place and adds no route"; "9. gate an in-place showKitConfirm adds no route" |
  | §8.2 adaptive | "10. permission with change … end-side sheet of 400–480 with the diff unified" |
  | KIT-33 | "11. details render last and collapsed in one fold" |
  | LAY-10, G14 | "12. keyboard …" (four tests: A, D and Enter, typing in the note, Tab order) |
  | KIT-17, G6 | "13. large text and sizes …" (2.0 text; keyboard; no overflow at 320/412/600/840/1280) |
  | G8 | "15. reduced motion …" |

- Changed test expectations (TEST-19): none (no existing test edited).
- Goldens (all new, each opened and looked at): `test/goldens/kit/kit_request_sheet_{permission,permission_always,permission_change,question,question_many,form,form_discard,gate,gate_confirm,reply}_{dark,light}.png` and `kit_request_sheet_{permission,permission_change}_1280x800_{dark,light}.png` (24 PNGs, 944 KB). Approved VL canvas render: none for this new part (EVID-12).
- Before and after: no before render (new part, pages permission-sheet, question-sheet, gate-sheet, form-sheet unchanged); after: `after-kit-request-sheet-permission.png`, `after-kit-request-sheet-permission-change-1280x800.png` (EVID-10).
- Accessibility: the route is named by the card's title (KitSheet `namesRoute`); the sheet announces nothing on close (the card's receipt does, A11Y-3); pinned answers are 48 dp buttons 8 dp apart (KitActionBlock); the risk switch moves focus to its scope sentence (KitSwitchRow.risk); Tab reaches Close, the switch, the options and the pinned answers (test 12); 2.0 text keeps the answers pinned (test 13, see contract problem 5); G5 (tap targets, labels, contrast, reading order) passed for every gallery shot in both themes.
- Privacy and security: no credentials, links or notifications. Drafts stay per profile under `oc.draft.<target>.<profileId>` (KitDraft, swept by `ProfileStore.profileScopedPreferenceKeys`); the sheet never clears them (the host does). Command, path and details go through KitCodeBlock/KitDetailsFold redaction.
- Migration: n/a, no stored format changed.
- Other findings (not this unit): the base commit tracks 24 files under `test/goldens/failures/` (TEST-12); they were left untouched (not deleted, not staged).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get --offline
$F test -j 1 test/kit/kit_request_sheet_test.dart test/goldens/kit/kit_request_sheet_golden_test.dart
$F analyze lib/ui/kit/kit_request_sheet.dart test/kit/kit_request_sheet_test.dart test/goldens/kit/kit_request_sheet_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- The shared gates (kit ratchet, design standard, l10n coverage, G6 matrix, full suite) were not run (owner decision 2026-09-27).
- Arabic/RTL (spec test 14) and the 2.0-text, 360×800, 915×412, 800×1280 and 1600×1000 galleries were not made (owner decision 2026-09-27).
- The combined 2.0 text + 300 dp keyboard case overflows in KitSheet (contract problem 5).
- A form's submit becoming enabled, and Approve raising the merge confirmation in place, are not possible with the frozen API (contract problems 1 and 4).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitRequestSheet` |
| Enabled | No: no screen calls it yet (adopters listed in §1) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `2c762c46` |
| Deployed | No | |
| Released | No | |
