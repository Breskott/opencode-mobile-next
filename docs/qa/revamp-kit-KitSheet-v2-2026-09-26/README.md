# revamp-kit-KitSheet-v2: KitSheet v2 (2026-09-26, review fixes 2026-09-27)

## 1. Scope

- Unit: `kit-KitSheet-v2` (wave 1, tier 1a, `kit-change`). Finish line: `showKitSheet`/`KitSheet` draw the visual-language sheet header (grabber, icon tile, left-aligned title, Close) with no call-shape change, and callers get `KitConsequences` for a sheet body's facts panel. It is done when every existing call site still compiles and renders, the new header states (icon, tone) and `KitConsequences` are tested and in the gallery, and KitDraft is untouched. Non-goal: moving any of the 78 `showModalBottomSheet`/5 `DraggableScrollableSheet` call sites to `showKitSheet` (wave 2), and the confirmation's own look (`kit_confirm_sheet.dart`, kit-KitDetailsFold's file).
- Files changed (base `b67e3276`):
  - `lib/ui/kit/kit_sheet.dart`: the library. `kit_confirm_sheet.dart`, its part file, is untouched; it belongs to kit-KitDetailsFold.
  - `lib/ui/kit/kit_consequences.dart` (new): a `part of 'kit_sheet.dart'` file. See "Contract problems" below.
  - `test/kit/kit_sheet_test.dart`: extended in place. Every existing assertion is unchanged.
  - `test/kit/kit_sheet_wrap_test.dart` (new): the one test that needs the app's real face loaded.
  - `test/kit/kit_consequences_test.dart` (new).
  - `test/goldens/kit/kit_sheet_golden_test.dart`: restructured for the new states; see §5.
  - `test/goldens/kit/kit_consequences_golden_test.dart` (new).
  - `test/goldens/kit/kit_sheet_*.png` (28) and `test/goldens/kit/kit_consequences_default*.png` (8). §5 says which are new, regenerated or removed.
  - Not changed any more: `test/kit/kit_overflow_scenes.dart`. The first pass appended a `KitConsequences` scene to it. That shared file is outside this unit's tests write set (R08), so the review-fix pass reverted the append. See "Shared tests broken" in §7.
- Pages (map ids): none. This is a kit-only change; kit-v2.json's 41 `KitSheet` pages move to it in wave 2, when their screens adopt `showKitSheet`.
- Specs followed: docs/ux-system/kit-api/KitSheet.md (frozen API); kit-v2.md §1.1, §4.6, §4.7, §8.2, §8.3; visual-language §5 "Sheets", §6, §7; STANDARDS.md rules KIT-11, KIT-15, KIT-16, KIT-17, KIT-18, KIT-19, KIT-39, KIT-43, LOOK-19, LOOK-21, LOOK-22, LOOK-25, LAY-3, LAY-4, LAY-10, LAY-13, DATA-1..4, MOT-2, MOT-11, A11Y-8, TEST-20, NAME-1, KIT-3, KIT-12, KIT-14. The owner decision of 2026-09-27 (STANDARDS.md header) is applied: no Arabic/RTL galleries, and galleries at 412×915 and 1280×800 only.
- Contract problems (PROC-20):
  1. **NAME-1/G4 one-file-per-part against KitSheet.md's "same library".**
     - What the docs say: KitSheet.md's Public API block puts `KitConsequenceMark`, `KitConsequence` and `KitConsequences` in the `kit_sheet.dart` library. KitConfirmSheet.md:234 says kit-KitDetailsFold uses "the same library: … KitConsequences" from its `part of` file. G4 (NAME-1, KIT-3) wants every exported class in its own `lib/ui/kit/kit_<snake>.dart`, with its own test and gallery.
     - Why it matters: these conflict whenever a frozen spec adds a public class to an existing part's library. The first pass moved the classes to a separate library and re-exported it (`export 'kit_consequences.dart';`). An export does not put names into `kit_sheet.dart`'s own scope, so the confirm part could not name `KitConsequences` without an import edit to `kit_sheet.dart`, a file outside kit-KitDetailsFold's write set.
     - Resolution in this branch: `kit_consequences.dart` is now a `part of 'kit_sheet.dart'`, and `kit_sheet.dart` says `part 'kit_consequences.dart';` in place of the export. The three declarations are in the `kit_sheet.dart` library, as both specs say. They are also in their own NAME-1 file, and G4's `name` and `exported` checks pass (the gate follows `part` files).
     - Evidence: a probe line referencing `KitConsequences`/`KitConsequence`/`KitConsequenceMark` was temporarily appended to `kit_confirm_sheet.dart`. `flutter analyze` resolved every name, and the probe was then removed; `kit_confirm_sheet.dart` is byte-identical to base.
     - Proposed text for the coordinator: "A frozen spec that adds a public class to an existing part's library names its NAME-1 file and says `part of`."
     - Blocks: nothing.
     - A side note from the same probe: `KitConsequences` cannot be `const`-constructed, because the frozen `assert(items.length > 0)` is not a constant expression. Callers write `KitConsequences(items: const [...])`.
  2. **G4 `docRow` against R06.** STANDARDS G4/KIT-14 wants a `kit.dart` doc-table row for every exported part in the commit that adds it. The harness makes `lib/ui/kit/kit.dart` a file this unit never stages (R06). `test/kit/kit_manifest_test.dart` therefore reports `docRow · KitConsequences: no [KitConsequences] row in the kit.dart table` (`run-10.txt`).
     - Integrator fix at merge: add `| [KitConsequences] | the counted-facts panel a sheet body places wherever the facts belong |` to `kit.dart`'s doc table. No export-list change is needed, because the class is part of `kit_sheet.dart`, which `kit.dart` already exports.
  3. **G4 `gallery` against the owner decision of 2026-09-27.** G4 still requires every part's gallery to use `kitGallerySizes` (all five LAY-4 sizes) and to have an `…_ar_…` golden in `Locale('ar')`. The owner decision (STANDARDS.md header, harness RULES) suspends Arabic/RTL galleries and limits galleries to 412×915 and 1280×800. `run-10.txt` shows `gallery · KitConsequences` and `gallery · KitSheet: … lacks kitGallerySizes, an …_ar_… golden in Locale('ar')`.
     - Proposed fix (coordinator/integrator): drop the `hasArabic` requirement and accept `kitGalleryScaledSizes` in place of `kitGallerySizes` in `test/kit/kit_manifest_test.dart`'s gallery check. It is a shared gate file (R10), so this unit does not edit it.
  4. **Subtitle and consequence-row type roles against the approved Confirm render.** The approved render is `docs/design/visual-language-2026-09-26/Confirm.png`, with source `Confirm.dc.html`. KitSheet.md's Tokens list gives the subtitle `secondary` (14/20, w400 per LOOK-12) and a consequence's text `rowTitle` (16/22, w500). The render's source draws the subtitle at 15/22 w400 in `text2`, and the consequence rows at 14.5 w400.
     - This branch keeps the frozen spec's roles, because the frozen spec is the build contract (R16).
     - Proposed text, for the coordinator to rule on: the subtitle becomes `body` (16/24, closest to the render's 15/22), and a consequence's text becomes `body` or `secondary` at w400, not `rowTitle` w500.
     - Blocks: nothing. It is a one-token change in `KitTokens.sheetSubtitle`/`KitConsequences` once ruled, then a re-render of the `kit_sheet_*` and `kit_consequences_*` galleries.
- New kit parts (KIT-3): `KitConsequences`, with `KitConsequenceMark` and `KitConsequence`.
  - The class lives in `lib/ui/kit/kit_consequences.dart`, a part of the `kit_sheet.dart` library. Its tests are in `test/kit/kit_consequences_test.dart` (including the `kitMotionStillTests` registration) and its gallery in `test/goldens/kit/kit_consequences_golden_test.dart`.
  - Its class shapes and doc comments are exactly the frozen spec's.
  - It still needs its G6 overflow scene, a `kit.dart` doc row and the G4 gallery rule change, all integrator-owned (see §7).
  - The private seam `_KitIconTile` and the `KitSheetTone` enum stay in `kit_sheet.dart` itself. The confirm part can use `_KitIconTile` because it is in the same library.
- Map items (EVID-11): n/a, because this unit owns no map page.
- States per page (STATE-20): n/a (kit-only). The part's own declared states (default, with-icon, consequences, loading, disabled, discard, half, not-dismissible, keyboard-open, attention, full) are covered by the gallery (§5) and the behaviour tests (§4).
- Deferred states (STATE-21): the disabled primary's `disabledReason` line (STATE-8) and the "row on PC" acceptance both need kit-KitAction-v2's `KitActionBlock`/`KitAction`. See §7 and README.md decision D4, which is the frozen spec's own scheduling call.

## 2. Builds

- Branch `revamp/kit-KitSheet-v2`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`. Code heads: `bea04d0d` (first pass), then this record's commit (review fixes).
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

Review-fix pass, 2026-09-27. Each command ran through `tool/qa/machine_lock.sh`, with `-j 1`.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_sheet_test.dart` + `test/kit/kit_consequences_test.dart` | pass | 34 passed (`run-9.txt`) | PASS |
| 2 | `test/kit/kit_manifest_test.dart` (G4) + `test/text_scale_overflow_test.dart` (G6) | known integrator-owned failures only | G4 fails on exactly 3 lines: `gallery · KitConsequences`, `gallery · KitSheet` (owner decision against the gate, contract problem 3) and `docRow · KitConsequences` (contract problem 2). Every `name`, `exported`, `states`, `stateScenes`, `test` and `motion` check passes. G6 fails on exactly `every exported kit part has a scene` → `['KitConsequences']`, because the shared-file append was reverted (R08). Every other G6 scene passes (`run-10.txt`). | **FAIL: documented, integrator-owned (§7)** |
| 3 | `test/goldens/kit/kit_sheet_golden_test.dart` + `kit_consequences_golden_test.dart` | 28 + 8 shots match | 36 passed (`run-11.txt`) after the 4 `kit_sheet_with_icon_text2*` PNGs were regenerated and looked at | PASS |
| 4 | `test/kit_motion_test.dart` + `test/kit/kit_confirm_sheet_test.dart` | pass | 203 passed | PASS |
| 5 | `test/kit/kit_keyboard_test.dart` + `kit_draft_test.dart` + `kit_sheet_wrap_test.dart` | pass | 18 passed | PASS |
| 6 | `test/kit_ratchet_test.dart` + `test/design_standard_test.dart` | pass, no baseline raised | 47 passed | PASS |
| 7 | `test/golden_harness_test.dart` (G23 names) | pass | passed | PASS |
| 8 | `flutter analyze lib/ui/kit/` + every changed test file | no issues | "No issues found!" | PASS |

The first pass's logs (`run-1.txt`, `run-7.txt`, `run-8.txt`) are kept for history and are superseded by runs 9–11.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-43 (additive only) | `test/kit/kit_sheet_test.dart` "the frame: title, subtitle, close, body and pinned actions" and the whole `unsaved input without a draft` group, unchanged | run-9.txt |
  | A11Y-8 (no truncation), spec test 2 | `test/kit/kit_sheet_wrap_test.dart` "title and subtitle wrap fully at 2.0 text" | run 5 |
  | KIT-17, spec test 3 | `test/kit/kit_sheet_test.dart` "pinned actions stay visible with the keyboard open (KIT-17)": at 2.0 text with `viewInsets.bottom` 300, the primary's rect bottom ≤ window height − 300 (the visible rect, not the window). "Row 19" starts below the primary's top. A drag on the body brings it fully above the primary, and the primary's rect is unchanged afterwards. | run-9.txt |
  | Spec test 1, STATE-9 | `test/kit/kit_sheet_test.dart` "with icon, the tile sits above the title, at the start, and is excluded from semantics", "without icon, no tile is drawn", "tone: attention paints the glyph in attention, neutral in text1" | run-9.txt |
  | Spec test 4, KIT-18 | `test/kit/kit_sheet_test.dart` "the close button is a 48 dp KitIconButton" (Close), "the grabber exposes the "Dismiss" action when dismissible". Also "not dismissible while an irreversible step runs": no Close and no `KitIconButton`, `kit-sheet-handle` has no `SemanticsAction.dismiss`, and `sendKeyEvent(escape)`, back and a barrier tap all leave the sheet open. | run-9.txt |
  | Spec test 5, §8.2 | `test/kit/kit_sheet_test.dart` group "adapts to the window (§8.2)": 360×800, **412×915** and 915×412 bottom; 800×1280 bottom capped at 640; 1280×800 and 1600×1000 panel ≤ 560 and centred; **1280×800 `full`** and 1600×1000 `full` end sheet 400–480 at the end edge. The existing "the side sheet opens from the start edge in Arabic" test is kept unchanged (behaviour, not a gallery). | run-9.txt |
  | Spec test 7, LOOK-5/DATA-8 | `test/kit/kit_consequences_test.dart` "lost is danger, kept is a text2 check, info is a text2 info glyph" | run-9.txt |
  | Spec test 7, LOOK-21 | `test/kit/kit_consequences_test.dart` "the separator is one physical pixel, inset to the text start". It pumps at DPR 3 and expects `Divider.thickness` == 1/3. In LTR, every separator's drawn line (its `DecoratedBox`) starts at the same x as each fact's text (`getRect(find.text(...)).left`). | run-9.txt |
  | Spec test 7 (icon override) | `test/kit/kit_consequences_test.dart` "an icon override replaces the mark's own glyph": it pumps `icon: AppIconography.terminal` and finds that glyph on screen, and no info glyph | run-9.txt |
  | Spec test 8 (`routes`) | `test/kit/kit_sheet_test.dart` group "routes: closes itself when its request is answered elsewhere" (both tests) | run-9.txt |

- Changed test expectations (TEST-19): none. Every existing assertion is unchanged; only new assertions and tests were added.
- Icon tile (review finding 7): the tile now stays at `tokens.markSize` (44 dp) at every text scale, so its edge always falls on whole physical pixels. Only the glyph grows, through `tokens.iconSize(context, markIconSize)`, clamped at `maxIconScale` (22 → 33 dp at most, inside the 44 dp tile). The first pass grew the tile to 44 + (glyph − 22), which is 50.6 dp at 1.3 text: 151.8 px at DPR 3, a soft edge.
- Goldens (each opened and looked at):
  - Regenerated in this pass: `kit_sheet_with_icon_text2_{dark,light}.png` and `kit_sheet_with_icon_text2_1280x800_{dark,light}.png`. The tile is 44 dp again, and the 33 dp glyph sits inside it. Nothing else moved.
  - Removed in this pass, per the owner decision of 2026-09-27 (no Arabic/RTL galleries; galleries at 412×915 and 1280×800 only). This is why the gallery differs from the frozen spec's 40-PNG list:
    - `kit_sheet_with_icon_ar_{dark,light}.png` and `kit_sheet_with_icon_ar_1280x800_{dark,light}.png`;
    - `kit_sheet_with_icon_{360x800,915x412,800x1280,1600x1000}_{dark,light}.png`;
    - `kit_consequences_default_ar_*` (4);
    - `kit_consequences_default_{360x800,800x1280,1600x1000}_*` (6).
  - The window-class behaviour at those sizes stays proven by spec test 5 above.
  - Kept from the first pass (unchanged bytes):
    - `kit_sheet_{default,disabled,loading,half}_{dark,light}.png`: re-rendered for the Text → KitText and IconButton → KitIconButton look pass;
    - `kit_sheet_with_icon_{dark,light}.png` and `kit_sheet_with_icon_1280x800_{dark,light}.png`;
    - `kit_sheet_{attention,consequences,not_dismissible,keyboard_open,discard}_{dark,light}.png`;
    - `kit_sheet_full_1280x800_{dark,light}.png`;
    - `kit_consequences_default{,_1280x800,_text2,_text2_1280x800}_{dark,light}.png`.
  - The first pass removed `kit_sheet_default_{360x800,800x1280,1280x800,1600x1000,ar,text2,ar_1280x800,text2_1280x800}_*` and `kit_sheet_full_{dark,light}.png`, which no shot produces any more.
  - Gallery total: 28 `kit_sheet_*` + 8 `kit_consequences_*` = 36 PNGs.
- **Approved render comparison (EVID-12, LOOK-25).** The first pass wrongly said that no approved render exists. `docs/design/visual-language-2026-09-26/Confirm.png` (390×844 dp at 2×, source `Confirm.dc.html`) is the approved render that KitSheet.md cites ("as in the approved Confirm render"). Every new or changed `kit_sheet_*` and `kit_consequences_*` golden was compared with it side by side.
  - Same as the render:
    - the grabber is 36×5, centred;
    - the header order is tile, title, subtitle, all start-aligned;
    - the tile is 44 dp;
    - the title is `title` w650 at 23–24;
    - the side rail is 20;
    - the consequences sit on a `surface1` panel with one-line rows, glyph then text;
    - the separators are inset to the text start and are one hairline;
    - lost uses the danger glyph and kept a `text2` check;
    - the buttons are stacked full width on the phone.
  - Different, each either raised or explained:
    1. Subtitle size: render 15/22 w400 `text2`; golden `secondary` 14/20. This is contract problem 4, and the spec role is kept.
    2. Consequence text: render 14.5 w400; golden `rowTitle` 16/22 w500. This is contract problem 4, and the spec role is kept.
    3. Space from title to subtitle: render 10 dp (the header column's `gap: 10`); golden 2 dp (`space1 / 2`). Space from tile to title: render 10 dp; golden 24 dp (a `space3` gap plus the title's `space3` top padding, which centres the title line against the 48 dp Close).
       - Not changed here. The render is a confirmation with no Close, and KitSheet's spec puts Close at the end of the title line.
       - Raised for the coordinator, alongside contract problem 4: should the KitSheet header match the render's 10/10 rhythm, with Close aligned to the first title line instead?
    4. Close: the golden has a 48 dp `KitIconButton` at the end of the title line; the render has none. The spec requires Close on KitSheet (spec test 4), and the render is a confirmation, which is kit-KitDetailsFold's look.
    5. Tile: render radius 14 and glyph 18; golden `markRadius` 12 and `markIconSize` 22. Both are the spec's named tokens (Tokens list). VL §4 allows icon-tile radii of 9–14.
    6. Consequence glyph size: render 18; golden `smallIconSize` 20, which the spec names.
    7. Consequence row geometry: render padding 13 vertical and 14 horizontal, gap 12, so the text starts at 44. Golden: 12 vertical (`space3`) and 16 horizontal (`space4`), gap 12, so the text starts at 48. VL §4 "panel inner padding: 16" is followed.
    8. Panel radius: render 16; golden `panelCornerRadius` 18. The spec (LOOK-19 "panel 18") and VL §4 "panels: 18" both say 18.
    9. Buttons: render 52 tall, radius 16, gap 10 (the destructive fill is the confirmation's). The golden has today's `KitActionBlock` (50 tall, radius 14), which belongs to kit-KitAction-v2.
- **NOT proven, spec-acknowledged (README.md decision D4, STANDARDS §0.4):** `kit_sheet_with_icon_1280x800_{dark,light}.png` and `kit_sheet_full_1280x800_{dark,light}.png` show today's `KitActionBlock` stacking the actions. It rows only at `maxWidth >= 600`, which the 560 dp panel never reaches. The integrator re-renders these once kit-KitAction-v2 merges (R07).
- Before and after: n/a. No screen page changed.
- Accessibility:
  - the icon tile and the consequence glyphs are `ExcludeSemantics` (tested);
  - the grabber's "Dismiss" action is tested both when present (dismissible) and when absent (not dismissible);
  - Close is a 48×48 `KitIconButton` labelled "Close";
  - the title and subtitle wrap fully at 200 % text (tested with the real Geist face);
  - every gallery shot ran G5 (tap-target, labelled-target, text-contrast guidelines, reading order) in both themes.
- Privacy and security: n/a. No credentials, stored data, external links or notifications changed.
- Migration: n/a. No stored format changed; `KitDraft`'s key `oc.draft.<target>.<profileId>` is untouched (C17).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_sheet_test.dart test/kit/kit_consequences_test.dart
$F test -j 1 test/kit/kit_manifest_test.dart test/text_scale_overflow_test.dart   # 2 known integrator-owned failures
$F test -j 1 test/goldens/kit/kit_sheet_golden_test.dart test/goldens/kit/kit_consequences_golden_test.dart
$F test -j 1 test/kit_motion_test.dart test/kit/kit_confirm_sheet_test.dart
$F test -j 1 test/kit/kit_keyboard_test.dart test/kit/kit_draft_test.dart test/kit/kit_sheet_wrap_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart test/golden_harness_test.dart
$F analyze lib/ui/kit/ test/kit/kit_sheet_test.dart test/kit/kit_consequences_test.dart \
  test/kit/kit_sheet_wrap_test.dart test/goldens/kit/kit_sheet_golden_test.dart \
  test/goldens/kit/kit_consequences_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (R19/R20: coordinator work).
- **Shared tests broken, for the integrator after the merge:**
  - `test/kit/kit_manifest_test.dart` (G4):
    - `docRow · KitConsequences`: add the `kit.dart` doc row (contract problem 2);
    - `gallery · KitConsequences` and `gallery · KitSheet`: the gate still requires `kitGallerySizes` and an `_ar_` golden, which the owner decision of 2026-09-27 removed (contract problem 3).
  - `test/text_scale_overflow_test.dart` (G6), "every exported kit part has a scene": `['KitConsequences']`. The integrator appends the `KitConsequences` scene to `test/kit/kit_overflow_scenes.dart` (PROC-13 allows it; R08 forbids this unit). The scene, English only per the owner decision:

    ```dart
    // kit_sheet.dart: KitConsequences, the visual language's consequences
    // panel (a sheet body places it where the facts belong).
    KitOverflowScene(
      const ['KitConsequences'],
      'default',
      build: (_, c) => KitConsequences(
        items: const [
          KitConsequence('3 queued prompts will be deleted', mark: KitConsequenceMark.lost),
          KitConsequence('The exported transcript is kept', mark: KitConsequenceMark.kept),
          KitConsequence('This runs in the background', mark: KitConsequenceMark.info),
        ],
      ),
    ),
    ```

    The first pass's run of that scene passed at 1.0, 1.3 and 2.0 text, LTR and RTL (`run-7.txt`).
- The "row on PC" half of the acceptance ("buttons stacked on phones and right-aligned in a row on PC") is not proven. Today's `KitActionBlock` rows only at `maxWidth >= 600`. The frozen spec assigns this to kit-KitAction-v2 and the integrator (decision D4). "Stacked on phones" is proven ("actions stack full width on a phone"). Spec test 6 stays under NOT proven until then.
- The disabled primary's `disabledReason` line (STATE-8) belongs to `KitAction`/`KitActionBlock` (kit-KitAction-v2), not this unit.
- The subtitle and consequence-row type roles, and the header spacing, differ from the approved Confirm render. They are raised as contract problem 4 and difference 3 above and await a coordinator ruling.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitSheet-v2` |
| Enabled | Yes: additive only, no flag; every existing call site keeps working (KIT-43) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | this branch's commits |
| Deployed | No | |
