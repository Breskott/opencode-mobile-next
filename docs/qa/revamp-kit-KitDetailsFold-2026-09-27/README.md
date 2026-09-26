# revamp-kit-KitDetailsFold: KitDetailsFold, the one technical fold (2026-09-27)

## 1. Scope

- Unit: `kit-KitDetailsFold` (wave 1, tier 2 in this run's brief, tier 1b in the spec; `kit-part`). Finish line: `KitDetailsFold` and `showKitTechnicalDetails` exist in `lib/ui/kit/kit_details_fold.dart` with the frozen API, `KitTechnicalValue` gains `spoken`, and `showKitConfirm(details:)` renders through the public fold with the same `kit-details-toggle` key. Non-goal: no call site outside the kit changes, and `lib/ui/kit/kit.dart` is not edited (the integrator adds the export and doc rows, R06).
- Files changed: `lib/ui/kit/kit_details_fold.dart` (new); `lib/ui/kit/kit_technical_value.dart` (`spoken`, re-export of the fold); `lib/ui/kit/kit_confirm_sheet.dart` (private `_KitDetailsFold` and `_KitConsequences` deleted; details through `KitDetailsFold`, consequences through the public `KitConsequences`); `lib/l10n/app_en.arb` (5 keys); `test/kit/kit_details_fold_test.dart` (new); `test/goldens/kit/kit_details_fold_golden_test.dart` (new) and its 18 PNGs. Generated `lib/l10n/app_localizations*.dart` were regenerated locally and not committed (PROC-13).
- Pages (map ids): none adopted here (kit-part unit; the 25 map elements move in their own units).
- Specs followed: `docs/ux-system/kit-api/KitDetailsFold.md` (frozen API, states, tokens, adaptive, a11y, motion, data safety, tests); kit-v2 §1.8, §4.3, §4.10, §8.2; STANDARDS.md §15, §16.2; owner decision 2026-09-27 (English only, galleries at 412×915 and 1280×800).
- Contract problems (PROC-20):
  1. **KIT-12 states line vs the G4 gate.** The spec asks for the doc line "States: collapsed, open, empty"; gate G4 accepts only {loading, empty, error, disabled, working, answered} and rejects `collapsed`/`open`. Built as `/// States: empty.` with collapsed and open described in prose (the same resolution KitIconButton-v2 recorded). Proposed text: "States: empty (collapsed and open are the disclosure's expanded state)". Blocks nothing.
  2. **G4 "needs disabled" for `onExpansionChanged`.** The gate reads any nullable `on…` callback as an enabling callback; `onExpansionChanged` is a notification (the fold toggles without it). The frozen API cannot rename it. Proposed: the gate exempts `on…Changed` notifications, or the spec adds "no disabled state". Blocks G4 for this part.
  3. **Galleries vs owner decision.** The spec asks for 28 PNGs including `_ar_` shots and five sizes; the owner decision of 2026-09-27 (later, so it wins, R15) drops Arabic and limits sizes to 412×915 and 1280×800. Built: every state at 412×915, `open_values` at 1280×800, and `open_values` at text 2.0 at both sizes, dark and light (18 PNGs). G4's `gallery` check still asks for `kitGallerySizes` and an `_ar_` shot; that gate needs the owner decision.
  4. **"Copy {label}" casing.** The spec shows `kitCopyValue(label)` reading "Copy address" for the label "Address". Built by lower-casing the label's first letter unless its second letter is upper case (so "URL" and "PID" keep their case). A per-language rule in a kit part is fragile; proposed: `KitTechnicalValue` or the ARB message owns the phrase. Blocks nothing.
  5. **G5 contrast heuristic artefact.** The sentence "The server answered from this address." in `KitText` `secondary` fails Flutter's `textContrastGuideline` (1.62) on any light background, although `text2` on `ground` is about 7:1; other sentences in the same role pass. The gallery note uses a different sentence. The investigation is not saved as a file; it reproduces with a bare `KitText(…, role: secondary)` on `0xFFF3F3F1` at DPR 3.
- New kit parts (KIT-3): `KitDetailsFold`, `showKitTechnicalDetails` (this unit's own part).
- Map items (EVID-11): none handled here; the 25 elements are adopted by the units the spec names (kit-KitStateView-v2, kit-KitDialog, shared-team-2, chat-6, …).
- States per page (STATE-20): n/a (kit part). Part states: collapsed → "1."; open → "1.", goldens `open_*`; empty → "10.", golden `empty`; value refused → "5b.".
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitDetailsFold`, base `dcf05c5e`, code head `8a6da2c9`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is wave-checkpoint work.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_details_fold_test.dart` (spec tests 1–14, plus adaptive and keyboard) | all pass | 29 passed (`run-behavior-tests.txt`) | PASS |
| 2 | `test/goldens/kit/kit_details_fold_golden_test.dart` (18 PNGs, DPR 3.0, G5 on every shot) | all pass | 18 passed (`run-golden-tests.txt`) | PASS |
| 3 | `test/kit_ratchet_test.dart`, `test/l10n_coverage_test.dart` | pass; no count rises | 35 passed; `kit_confirm_sheet.dart` "EdgeInsets numeric" 1 → 0 (`run-ratchet-l10n.txt`) | PASS |
| 4 | Confirm regression: `kit_confirm_sheet_test`, `saved_permissions_screen_test`, `e7_session_approvals_layout_test`, `kit_consequences_test`, `kit_sheet_test` | pass unchanged | 74 passed (`run-confirm-regression.txt`) | PASS |
| 5 | `test/goldens/kit/kit_confirm_sheet_golden_test.dart` (shared, owned by KitSheet-v2) | changes: the fold and consequences now draw through the public parts | 24 of 28 differ (`run-shared-confirm-goldens.txt`); PNGs not regenerated (R07/PROC-10) | PASS (expected) |
| 6 | Shared manifest gates: `kit_manifest_test`, `kit_motion_test` | fail only where the integrator or a gate change is needed | G4: states, gallery (contract 1–3), docRow ×2, keyboard; G8x: no motion samples for the two new names; the other 12 motion failures are identical on base (`run-shared-gates.txt`, `run-motion-on-base-dcf05c5e.txt`) | PASS (expected) |
| 7 | `text_scale_overflow_test.dart` "G6 kit overflow matrix" | only the scene registry misses the new part | "every exported kit part has a scene": missing `KitDetailsFold`, `showKitTechnicalDetails`; 65 other cases pass | PASS (expected) |
| 8 | `flutter analyze lib test` | no issues in changed paths | 6 issues, none in changed paths; the 3 errors are in `test/kit/kit_image_test.dart` (`KitIconButton.label`), untouched and present on base (`run-analyze.txt`) | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`test/kit/kit_details_fold_test.dart` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-33 (one of each) | "3. a value shows once, under its first label" | `run-behavior-tests.txt` |
  | KIT-23 (copy) | "4. copy: one value through KitCopy; Copy all copies lines" | `run-behavior-tests.txt` |
  | SEC-2, SEC-4 | "5. redaction…", "5b. a value that is a key trips the debug assert", "6. paths and commit SHAs survive redaction"; golden `open_text` shows `Authorization: •••` | `run-behavior-tests.txt`, `run-golden-tests.txt` |
  | COPY-30, LAY-8 | "9. RTL: the value is LTR, starting where its label starts" | `run-behavior-tests.txt` |
  | A11Y-2, A11Y-8, G6 | "14. no overflow" (320/412 × 1.0/1.3/2.0 × LTR/RTL, a 220-character path) | `run-behavior-tests.txt` |
  | MOT-5, MOT-7, G8 | "11. system reduce motion…", "11. Effects motion Off…" | `run-behavior-tests.txt` |
  | LAY-10 | "keyboard: Enter and Space toggle the focused fold" | `run-behavior-tests.txt` |
  | §8.2 adaptive | "adaptive: a wide window puts the label in its column"; golden `open_values_1280x800` | both |
  | A11Y (semantics) | "8. semantics: expanded state, one node per value, copy label" | `run-behavior-tests.txt` |

- Changed test expectations (TEST-19): none.
- Goldens changed: new `kit_details_fold_*` (18), each opened and looked at. Shared `kit_confirm_*` goldens differ and are left for the integrator: the Details row is now the full-width 48 dp tertiary row (words in `text2`, chevron at the end), values have copy buttons, and the consequences panel is `KitConsequences` (18 dp corners, glyph aligned by the part).
- Before and after: `before-kit-confirm-destructive-dark.png` (base golden), `after-kit-confirm-destructive-dark.png` (render on this branch); `after-kit-details-fold-open-values-dark.png` (no before render: new part).
- Accessibility: toggle is one button node with `expanded` and the tap hint "Hide details" when open; each value is one node "Label: value" (value isolated LTR, `spoken` when given); copy buttons are 48×48 labelled "Copy address"; 200 % text checked in tests and the `text2` goldens; G5 passes on all 18 shots.
- Privacy and security: every value, note and the raw text pass `KitRedact.text` before display and copy; a secret-looking value fails a debug assert naming its label; "Copy all" copies only what the fold shows.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/kit/kit_details_fold_test.dart
$F test -j 1 test/goldens/kit/kit_details_fold_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/l10n_coverage_test.dart
$F test -j 1 test/kit/kit_confirm_sheet_test.dart test/saved_permissions_screen_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- The shared gates that read `kit.dart` (G4 docRow, G8x samples, G6 scene, G14 keyboard list) cannot pass until the integrator adds the kit.dart rows and the manifest-driven scene/sample entries.
- The shared `kit_confirm_*` goldens are not regenerated.
- Hover highlight is built but not asserted by a test.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitDetailsFold` |
| Enabled | Yes: `showKitConfirm(details:)` uses it; reachable from `kit.dart` through the `kit_technical_value.dart` re-export (no direct row yet) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `8a6da2c9` |
| Deployed | No | |
| Released | No | |
