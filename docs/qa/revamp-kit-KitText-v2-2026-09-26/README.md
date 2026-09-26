# revamp-kit-KitText-v2: KitText v2 (2026-09-26)

## 1. Scope

- Unit: `kit-KitText-v2` (wave 1, tier 1a, `kit-change`). Finish line: KitText carries the full v2 API from `docs/ux-system/kit-api/KitText.md` — `KitText.selectable`/`.selectableRich`, `KitText.mono` (wrap/end/middle), `KitSelectable` (with `.excluded` and a fine-pointer mode) and `KitLtr` — with every pre-v2 caller and test unchanged, and its own tests and galleries prove every "Tests required" and "Galleries required" item in the spec. Non-goal: no call-site migration (no screen in `lib/ui/` is touched), no new roles, no redaction, no inline bidi isolation (`KitBidi`'s job) — all explicit non-goals in the frozen spec.
- Files changed: `lib/ui/kit/kit_text.dart`, `test/kit/kit_text_test.dart`, `test/goldens/kit/kit_text_golden_test.dart` (new) plus its 32 PNGs, this record.
- Pages (map ids): none — KitText is a foundation kit part, not a screen.
- Specs followed: `docs/ux-system/kit-api/KitText.md` (frozen API, verbatim); `docs/ux-system/revamp/STANDARDS.md` rules TEST-1, TEST-6–TEST-9, TEST-15, TEST-20, EVID-1–EVID-8, R04/R08/R11–R14/R16/R23 from the unit's own instructions; `docs/design/visual-language-2026-09-26.md` §2 (type scale, unchanged).
- Contract problems (PROC-20): see §"Contract problems" below — two items, neither worked around.
- New kit parts (KIT-3): none created as separate files. `KitSelectable` and `KitLtr` are new *classes*, both declared inside `lib/ui/kit/kit_text.dart` because the frozen `KitText.md` spec says so explicitly ("File: `lib/ui/kit/kit_text.dart`... The write set is that file, `test/kit/kit_text_test.dart` and `test/goldens/kit/kit_text_golden_test.dart`", and both classes are listed under KitText's own "Public API" code block). This unit did not invent that placement.
- Map items (EVID-11): n/a — KitText has no map/page record.
- States per page (STATE-20): n/a — a kit part, not a screen. Its own KIT-12 states are declared as `States: none — …` on all three classes (text has no data states; see the frozen spec's "States" section for the fuller reasoning).
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitText-v2`, base `27a3393b` (`feat/phone-setup-v2`, after the `feat/visual-language-v1` and `feat/kit-seams` merges), code head `dd5211d4`.
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator/wave-checkpoint work.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `flutter analyze lib/ui/kit test/kit test/goldens/kit` | no issues | "No issues found!" | PASS |
| 2 | `flutter test -j 1 test/kit/kit_text_test.dart` | all pass | 32 passed, 0 failed | PASS |
| 3 | `flutter test -j 1 test/goldens/kit/kit_text_golden_test.dart` (no `--update-goldens`) | all pass | 32 passed, 0 failed | PASS |
| 4 | `flutter test -j 1 test/kit_motion_test.dart` (G8x, manifest-driven) | all pass, including KitSelectable/KitLtr's new self-registered samples | 179 passed, 0 failed | PASS |
| 5 | `flutter test -j 1 test/kit_ratchet_test.dart` (G1/G2/G7/G15/G15x/G16/G17/G21/G48) | all pass (kit internals are out of scope by directory) | 32 passed, 0 failed | PASS |
| 6 | `flutter test -j 1 test/kit/kit_manifest_test.dart` (G4) | all pass | 1 passed, 1 failed — the completeness check only, for the two new classes (see "Contract problems") | FAIL (expected; not this unit's to fix) |
| 7 | `flutter test -j 1 test/text_scale_overflow_test.dart` (G6) | all pass | 73 passed, 1 failed — the completeness check only, for the same two classes | FAIL (expected; not this unit's to fix) |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + description) | Outcome |
  |---|---|---|
  | LOOK-12/G19 | `test/kit/kit_text_test.dart` "1. styleFor(role) equals LOOK-12 exactly for all ten roles" | PASS |
  | LOOK-11 | `test/kit/kit_text_test.dart` "2. under Arabic every non-mono role has letter spacing 0 and falls back to Noto Sans Arabic" | PASS |
  | LOOK-14 | `test/kit/kit_text_test.dart` "3. every tone colour is opaque in graphiteDark, graphiteLight and a deriveRoles pack" | PASS |
  | LOOK-16/KIT-32 | `test/kit/kit_text_test.dart` group "4. KitText.mono direction under TextDirection.rtl" (3 tests) | PASS |
  | A11Y-8 | `test/kit/kit_text_test.dart` group "5. KitMonoCut" (middle, end) | PASS |
  | SEC-3/data safety | `test/kit/kit_text_test.dart` group "6. KitText.selectable" (toolbar contents, Tab skip) | PASS |
  | KIT-32 (DesktopSelectionArea's job) | `test/kit/kit_text_test.dart` "7. KitSelectable(mode: finePointer)…" | PASS |
  | SelectionContainer.disabled's job | `test/kit/kit_text_test.dart` "8. KitSelectable.excluded…" | PASS |
  | LOOK-18 | `test/kit/kit_text_test.dart` "9. tabular: true sets FontFeature.tabularFigures()" | PASS |
  | TechnicalDirection's job | `test/kit/kit_text_test.dart` "10. KitLtr lays a Row left to right under an RTL ambient" | PASS |
  | A11Y-8 (no clamp) | `test/kit/kit_text_test.dart` "11. at TextScaler.linear(2) the rendered size doubles" | PASS |
  | MOT-7/G8x | `kitMotionStillTests` groups for KitText (incl. new `selectable`/`mono middle cut` samples), KitSelectable, KitLtr | PASS |
  | TEST-9 galleries | `test/goldens/kit/kit_text_golden_test.dart`, 32 shots (`type`, `mono`, `selectable_selected`, their `_text2`/`_ar` variants and the five default-state sizes) | PASS |

- Fixes only (TEST-2): n/a — this unit adds behaviour; it fixes nothing pre-existing, so no failing-first run is required.
- Changed test expectations (TEST-19): none — the three pre-existing tests in `test/kit/kit_text_test.dart` (role/tone/mono-direction) pass unmodified.
- Goldens changed (each opened and looked at, TEST-6):
  - All 32 `test/goldens/kit/kit_text_*.png` are new (first generation for this file), each opened and reviewed: role/tone type scale, the three `KitMonoCut` values (the `end`/`middle` samples are wrapped in a fixed 260 dp box so the cut is visible at every gallery size, otherwise the 720 dp reading column is wide enough to hide it), the Arabic `mono` shot's start-aligned-right technical values, and `selectable_selected`'s highlighted word with drag handles.
  - No approved VL canvas render exists for these new states (EVID-12): n/a.
- Before and after (EVID-10): n/a — no existing screen or golden changed; every KitText.md PNG is newly added, not a modification of a prior render.
- Accessibility: every gallery shot runs G5 (`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`, reading order) with zero new baseline entries needed (`test/goldens/kit/kit_gallery_g5_baseline.json` untouched). The `selectable_selected` shot specifically avoids Android's native text-selection toolbar (44 dp buttons, below the 48 dp guideline) by freezing the "word selected, handles shown" moment instead — cancelling the long-press gesture rather than lifting it, since `RenderEditable.selectWord` runs on press-start and `showToolbar` only on press-end (verified against the pinned Flutter's `text_selection.dart`). `KitText.mono` at `TextScaler.linear(2)` was checked in test 11; 200% text and Arabic are covered by the `_text2`/`_ar` gallery shots.
- Privacy and security: n/a — no credentials, stored data, external links or notifications are touched. `KitText`/`KitText.selectable`/`KitText.mono` still show no secrets (SEC-3): `KitField.secret` is unaffected. The restricted context menu is Copy/Select-all only, never Cut/Paste/Share (data-safety §, verified in test 6).
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F analyze lib/ui/kit test/kit test/goldens/kit
$F test -j 1 test/kit/kit_text_test.dart
$F test -j 1 test/goldens/kit/kit_text_golden_test.dart
$F test -j 1 test/kit_motion_test.dart
$F test -j 1 test/kit_ratchet_test.dart
$F test -j 1 test/kit/kit_manifest_test.dart          # 1 known-expected failure, see below
$F test -j 1 test/text_scale_overflow_test.dart        # 1 known-expected failure, see below
```

## 7. NOT proven

- Not run on a device or emulator (no APK; coordinator/wave-checkpoint work).
- The repository-wide `flutter test --concurrency=1` full suite was not run by this unit (PROC-16/machine sharing; only the files above and their immediate shared gates were run). `test/design_standard_test.dart` was attempted and timed out at 118 s under this unit's per-command budget — it scans `lib/ui/screens/`, which this unit never touches, so a timeout here is a budget artifact, not a signal about this change; the coordinator's wave-checkpoint run covers it.
- `test/l10n_coverage_test.dart` and the glossary/ledger tests were not run: this unit added no new ARB keys, no localizable strings (all copy in the new tests/galleries is internal sample text) and touched no ledger-tracked screen.
- The G4 manifest (`test/kit/kit_manifest_test.dart`) and G6 overflow matrix (`test/text_scale_overflow_test.dart`) each have one known, unfixed failure — see "Contract problems".

## Contract problems (PROC-20)

1. **G4/G6 expect a part-per-file layout that the frozen spec contradicts for this unit.** `docs/ux-system/kit-api/KitText.md` says explicitly: "File: `lib/ui/kit/kit_text.dart` (created on the VL branch). The write set is that file, `test/kit/kit_text_test.dart` and `test/goldens/kit/kit_text_golden_test.dart`," and its "Public API" code block declares `KitSelectable` and `KitLtr` as new classes in that same block, right after `KitText`. Built exactly as specified, `KitSelectable` and `KitLtr` are new public widget classes living in `kit_text.dart`. `test/kit/kit_manifest_test.dart` (G4) and `test/text_scale_overflow_test.dart` (G6), however, expect *every* such class to live in its own `lib/ui/kit/kit_<snake>.dart`, with a matching `test/kit/kit_<snake>_test.dart`, `test/goldens/kit/kit_<snake>_golden_test.dart`, a `[Kit<Name>]` row in `kit.dart`'s doc table, and a scene block in `test/kit_overflow_scenes.dart`. Evidence: `test/kit/kit_manifest_test.dart` fails "name", "gallery", "test" and "docRow" for both classes (exact messages in Run 6 above); `test/text_scale_overflow_test.dart` fails only its "every exported kit part has a scene" check (Run 7). Proposed text: either (a) `KitText.md` gets an explicit carve-out noting `KitSelectable`/`KitLtr` are declared inside `kit_text.dart` and are exempt from the per-file manifest checks, or (b) a future unit splits them into their own files once one exists that can also touch `kit.dart`'s doc table and `test/kit_overflow_scenes.dart` (both outside every wave-1 kit unit's normal write set, since they are the two files most kit units would need to touch to add a "part" this way — a structural tension the coordinator should resolve once for every future multi-class kit file, not per unit). Blocks: `test/kit/kit_manifest_test.dart` and `test/text_scale_overflow_test.dart` from going fully green until resolved; does not block KitText v2's own behaviour or its own tests/galleries, all of which pass.
2. **KitText.md's own "Default state (type)" sizes list disagrees with the shared `kitGallerySizes` constant.** The spec's Galleries section lists "360×800, 915×412, 800×1280, 1280×800 and 1600×1000"; `test/goldens/kit/kit_gallery.dart`'s `kitGallerySizes` (used by every other kit gallery, including the pre-existing `kit_foundation_type` shots) has `412×915` in that slot instead — a landscape phone versus the shared census portrait phone. This file follows the frozen spec's literal sizes (a `915×412` shot exists; a `412×915`-at-that-slot shot does not, since `412×915` is already the "States" bullet's own required size). Evidence: `docs/ux-system/kit-api/KitText.md` "Galleries required" vs. `test/goldens/kit/kit_gallery.dart`'s `kitGallerySizes` constant. Proposed text: the coordinator picks one canonical five-size list for kit-part default-state gallery and either edits `kit_gallery.dart`'s `kitGallerySizes` comment to note the exception, or corrects `KitText.md`. Blocks: nothing today — this file's own goldens are internally consistent and named correctly (TEST-20) either way; it is a documentation-consistency issue for the coordinator, not a test failure.
