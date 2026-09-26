# revamp-kit-KitComposerChips: KitComposerChips (2026-09-27)

## 1. Scope

- Unit: `kit-KitComposerChips` (wave 1, tier 2, kit part). Finish line: `KitComposerChips.model`, `.attachments` and `.suggestions` exist in `lib/ui/kit/chat/kit_composer_chips.dart` to the frozen API, with behaviour tests and galleries. Non-goal: no screen migration (chat-3/chat-4/chat-9 own `composer.dart`, `model_shortcuts.dart`, `command_launcher.dart`, `chat_screen.dart`), no `kit.dart` export.
- Files changed: `lib/ui/kit/chat/kit_composer_chips.dart` (new); `lib/l10n/app_en.arb` (+15 keys; the generated `lib/l10n/app_localizations*.dart` are not committed — dropped in `8750bbc4`, the integrator runs gen-l10n after the merge); `test/kit/kit_composer_chips_test.dart` (new); `test/goldens/kit/kit_composer_chips_golden_test.dart` and 26 PNGs (new).
- Pages (map ids): `embedded-composer#embedded-composer-model-chip`, `#embedded-composer-model-cycle-menu`, `#embedded-composer-context-badge`, `#embedded-composer-attachment-chip-preview`, `#embedded-composer-inline-command-row`, `chat#chat-pending-photo-row` (the part only; the pages migrate later).
- Specs followed: `docs/ux-system/kit-api/KitComposerChips.md`; KitChip.md (removable metrics, `KitChipWrap` spacing, `kitChipRemove`); KitMenu.md (`showKitMenu`, keyboard opening); KitImage.md; KitMotionParts.md (`KitSwap`); kit-v2 §8.2, §8.3; STANDARDS STATE-8, STATE-9, COPY-11, KIT-12, LAY-9, LAY-11, LOOK-4, LOOK-21, MOT-7, MOT-11, A11Y-8, TEST-9, TEST-15, TEST-20.
- Owner decision 2026-09-27 applied: no Arabic ARB entries, no Arabic or RTL galleries, galleries at 412x915 and 1280x800 only.
- Contract problems (PROC-20):
  1. **Copy list incomplete.** KitComposerChips.md "Accessibility" says read-only chips read "Image, screenshot.png", but "Kit copy" names no kind words. Added `kitAttachmentImage`, `kitAttachmentFile`, `kitAttachmentFolder`, `kitAttachmentReference` ("{Kind}, {label}"). Proposed: add these four keys to the spec's Kit copy list.
  2. **G4 `states` vs the frozen API.** The frozen fields `onPressed`, `onRemove`, `onShowAll` are nullable (one class, three forms), so `test/kit/kit_manifest_test.dart` requires a `disabled` state, while the spec says "no disabled (STATE-8)". The part declares `States: empty.` and the gate fails on `disabled`. Proposed: allowlist KitComposerChips for `states`, or teach the gate that a named-constructor-required callback is not optional.
  3. **G4 `gallery` vs owner decision 2026-09-27.** The gate asks for `kitGallerySizes`, a `_ar_` shot in `Locale('ar')`; the owner dropped Arabic and limited sizes to 412x915 and 1280x800. Followed the owner. Same for the spec's "Galleries required" (about 30 PNGs with Arabic and five sizes): 26 PNGs rendered instead.
  4. **Task copy rule vs owner.** The task's R04 says "app_en.arb AND app_ar.arb"; the owner decision says en only. Followed the owner. `lib/l10n/app_en.arb` is outside the unit's write set but the spec's Kit copy requires ARB keys; only the ARB is committed, the integrator regenerates `app_localizations*.dart`.
- Blocker (PROC-32, partial): **kit-KitTappable has not merged** (`revamp/kit-KitTappable` = the base commit). The spec builds the model chip, attachment bodies and suggestion rows on `KitTappable`; per STANDARDS §0.4 the nearest existing part is used instead: KitChip's transparent `InkWell` zone that reports hover, press and focus to the pill, and a manual-trigger `Tooltip` (hover only) as KitChip uses. Exact change requested once it merges: replace `_zone(...)` and the model chip's `Tooltip` with `KitTappable(shape: KitShape.pill, surface: KitSurfaceLevel.surface3, menu:, tooltip:)`.
- New kit parts (KIT-3): `KitComposerChips` (with `KitAttachment`, `KitSuggestion`, `KitModelChipState`, `KitAttachmentKind`, `KitSuggestionKind`) — not exported from `kit.dart` (integrator, R06).
- Map items (EVID-11):
  - `embedded-composer-model-chip` statesMissing "no model signed in: chip says 'Choose model' identically to 'server default in use'" → done: test "1. model chip words" (both tests) and goldens `kit_composer_chips_model_sign_in_*`, `kit_composer_chips_model_default_*`.
  - `embedded-composer-inline-command-row` "Inline ListTile suggestions, descriptions truncated mid-word" → done: test "6. suggestions … ellipsizes at a word" and golden `kit_composer_chips_suggestions_*`.
  - `chat-pending-photo-row` couldBeAutomatic "attach the recovered photo to this draft automatically" → the part shows `detail: "Recovered"` with a remove target (golden `kit_composer_chips_attachments_*`); attaching it automatically is deferred to chat-9 (host).
- States (KIT-12): model chosen, serverDefault, signInNeeded, chooseNeeded, context warning, context almost full, narrow; attachments editable, read-only, thumbnail, detail, empty; suggestions list, capped with Show all, empty → tests 1–6 and the 13 state goldens.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitComposerChips`, base `dcf05c5e`, code head `ebf665e1` (first build `c6bfe871`).
- Review round 1 (2026-09-27):
  1. PROC-5/PROC-13: generated l10n output restored to the base and dropped (`8750bbc4`); only the `app_en.arb` additions stay.
  2. Attachment label cut with room to spare: the label and detail were `Flexible(flex: 3)`/`Flexible(flex: 2)`, which capped the name at 3/5 of the line. Now `_LabelAndDetail` measures both as painted; the detail keeps its width (capped at 2/5 only when the pair does not fit) and the name takes the rest, middle-cut only when the pair truly does not fit.
  3. KIT-3: the private `_ChipWrap` copy is deleted; the strip is `KitChipWrap(key: stripKey)` from `kit_chip.dart`.
  4. Behaviour, not implementation: "empty renders nothing" now asserts no "Suggestions" semantics node, no "Show all" and zero size; the "almost full" colour test reads every painted paragraph's colour under the chip key (words and glyphs) and the context words' painted colour under the context key.
  Also removed an unused `super.key` on `_ModelChip` (analyzer warning).
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only (TEST-2) | n/a: new code, no fix | n/a | PASS |
| 2 | `test/kit/kit_composer_chips_test.dart` | passes | 43 passed (at `ebf665e1`, l10n generated locally, not committed) | PASS |
| 2a | Fix check (TEST-2): the three new "5. attachments a name …" tests against the old layout (`git stash` of the part) | the two "show whole while the chip has room" tests fail | both failed (name painted cut); pass after the fix | PASS |
| 3 | `test/goldens/kit/kit_composer_chips_golden_test.dart` (includes G5 accessibility per shot) | passes | 26 passed (at `ebf665e1`) | PASS |
| 3a | `test/kit_ratchet_test.dart` after the review fixes | passes | 33 passed | PASS |
| 3b | `flutter analyze` on the three changed Dart files | no issues | no issues | PASS |
| 4 | `test/kit_ratchet_test.dart`, `test/l10n_coverage_test.dart` | pass | 35 passed | PASS |
| 5 | `test/design_standard_test.dart`, `test/ui_glossary_test.dart` | pass | passed | PASS |
| 6 | `test/kit/kit_manifest_test.dart` (G4) | KitComposerChips entries only from integrator-owned wiring | fails on KitComposerChips: exported, docRow (integrator, R06), states `disabled` (problem 2), gallery `kitGallerySizes`/`_ar_` (problem 3) | FAIL (expected, reported) |
| 7 | `test/golden_harness_test.dart` (G23) | no new violation from this unit | one violation, `arabicFont: test/goldens/kit/kit_page_route_golden_test.dart`, not this unit's file | PASS for this unit |
| 8 | `test/kit_motion_test.dart` | no failure from this unit | 13 failures in KitButton, KitActionBlock, KitConfirmSheet, KitProgressView, KitStateView and `showKitMenu` sampling; none reference this part (not exported, so not sampled there; its own samples run in step 2) | PASS for this unit |
| 9 | `flutter analyze --no-pub lib test` | no issues in changed paths | 7 issues, all outside changed paths (`kit_since.dart` clock import, `kit_image_test.dart` KitIconButton.label) | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | P7.5, P7.7, P6.6 | `test/kit/kit_composer_chips_test.dart` "1. model chip words" | step 2 |
  | STATE-9, LOOK-4 | same file, "3. context" group | step 2 |
  | LAY-11, A11Y-8 | same file, "4. narrow slot" | step 2 |
  | DATA-11 | same file, "5. attachments" group | step 2 |
| AUTO-4, A11Y-8 (name and "Recovered" not cut while there is room) | same file, "a name and its detail both show whole while the chip has room" (text x1, x2) and "a name too long for the slot is middle-cut" | steps 2, 2a |
  | map "truncated mid-word" | same file, "a long description wraps to two lines and ellipsizes at a word" | step 2 |
  | G14 keyboard | same file, "7. keyboard" group | step 2 |
  | LAY-9, A11Y-1 | same file, "8. semantics and targets" group | step 2 |
  | MOT-7 (G8x) | same file, "9. reduced motion" and `kitMotionStillTests('KitComposerChips')` | step 2 |
  | G6 | same file, "10. 200 % text at 320 dp" (LTR and RTL Directionality) | step 2 |
  | G5 | every shot in `kit_composer_chips_golden_test.dart` | step 3 |

- Changed test expectations (TEST-19): review round 1 — "0.96 says 'Context almost full', never attention or danger" now reads painted paragraph colours instead of walking `Text`/`Icon` widgets (and adds: the context words paint in `text1`); "no 'Show all' without onShowAll; empty renders nothing" now asserts no "Suggestions" node and zero size instead of no `InkWell`. Three tests added (above).
- Goldens added (each opened and looked at): `test/goldens/kit/kit_composer_chips_{model,model_default,model_sign_in,model_context,model_narrow,attachments,attachments_read_only,suggestions,empty}_{dark,light}.png`, `kit_composer_chips_default_{dark,light}.png`, `kit_composer_chips_default_1280x800_{dark,light}.png`, `kit_composer_chips_default_text2_{dark,light}.png`, `kit_composer_chips_default_text2_1280x800_{dark,light}.png` (26, 608 KB). Review round 1 regenerated, after looking at each: `attachments`, `attachments_read_only`, `default`, `default_1280x800`, `default_text2`, `default_text2_1280x800` (dark and light). At 412 dp the image chip now fills its line (`screenshot-…6-09-27.png Recovered`), the file chip at text 2.0 shows `buil…g.txt 2.1 MB` whole-detail, and at 1280 dp every name shows whole. The thumbnail is the shared 1x1 red PNG fixture, so it renders as a solid red tile. Approved VL canvas render: none exists for this part (EVID-12).
- Before and after: no before render (new part, no page migrated) (EVID-10).
- Accessibility: model chip is one button "{words}[, Context N % full]" with hint "Change model" and the menu items as custom actions; attachment body "Preview {label}" (or "{Kind}, {label}" as plain text) with the detail as value, remove target "Remove {label}"; suggestions list "Suggestions", rows "{label}, {description}"; all targets ≥ 48 dp, body and remove targets 8 dp apart; 200 % text checked at 320 dp.
- Privacy and security: n/a — no credentials, stored data, links or notifications. Raw model/provider ids are the host's to keep out of `label` (COPY-11).
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_composer_chips_test.dart test/goldens/kit/kit_composer_chips_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/l10n_coverage_test.dart
$F test -j 1 test/design_standard_test.dart test/ui_glossary_test.dart
$F test -j 1 test/kit/kit_manifest_test.dart
$F analyze --no-pub lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- KitTappable behaviour (its hover cross-fade, pressed step, shared focus ring and `tooltip:`) is not used; the zones follow KitChip's pattern until kit-KitTappable merges.
- The model chip's tooltip shows on mouse hover only (manual trigger); not exercised by a hover test.
- At text 2.0 on a phone the image chip's pair does not fit, so "Recovered" is end-cut to its 2/5 share (`Recov…`); the full detail stays in the chip's semantics value.
- Right-click opening the menu at the pointer position and Shift+F10 / context-menu key opening are implemented; only right-click and long-press are tested.
- Suggestions "description on the same line from expanded" is implemented but has no dedicated test or wide suggestions golden.
- The model chip's and the attachment label-and-detail LayoutBuilders answer no intrinsic-size query; a host that puts it under `IntrinsicWidth`/`IntrinsicHeight` will fail (not tested).
- Esc returning focus to the composer field is KitComposer's routing (not this part).
- No Arabic/RTL galleries or Arabic copy (owner decision 2026-09-27).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Partial (PROC-32: tap zones await kit-KitTappable; everything else in the frozen spec is implemented) | `revamp/kit-KitComposerChips` |
| Enabled | No: not exported from `kit.dart`, no screen uses it yet | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `ebf665e1` |
| Deployed | No | |
| Released | No | |
