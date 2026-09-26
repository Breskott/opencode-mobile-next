# revamp-kit-KitDivider: KitDivider, the one hairline separator (2026-09-26)

## 1. Scope

- Unit: `kit-KitDivider` (wave 1, tier 1, `kit-part`). Finish line: `KitDivider`
  exists in its own file under `lib/ui/kit/`, matches its frozen API, states,
  galleries and contract tests. Non-goal: no call site outside the kit
  changes — `Divider`/`VerticalDivider` at the 70 call sites the spec lists
  are a separate unit's work.
- Files changed: `lib/ui/kit/kit_divider.dart` (new),
  `test/kit/kit_divider_test.dart` (new),
  `test/goldens/kit/kit_divider_golden_test.dart` (new), its 22 PNGs under
  `test/goldens/kit/kit_divider_*.png`, and this QA record with its two
  evidence files.
- Pages (map ids): n/a — a `kit-part` unit has no map pages; nothing in
  `docs/ux-system/map/all.json` is assigned to KitDivider
  (`kit-v2.json assignment: no element is assigned`, per the frozen spec).
- Specs followed: `docs/ux-system/kit-api/KitDivider.md` (the frozen API,
  in full); `docs/ux-system/revamp/STANDARDS.md` §1, §4, §15, §16, §18;
  `docs/ux-system/kit-v2.md` §7, §8.2 (KitDivider needs no per-window
  adaptation: "the same line on compact, medium, expanded and large"), §8.4
  (gallery sizes); `docs/design/visual-language-2026-09-26.md` §4, §7
  (hairline inset to the text start; LOOK-21, a doubled or half-pixel
  hairline is a bug).
- Contract problems (PROC-20): one, for the integrator.
  - The shared gallery sizes lack the landscape phone. `kitGallerySizes`
    (`test/goldens/kit/kit_gallery.dart:105`) lists 360×800, 412×915,
    800×1280, 1280×800 and 1600×1000, following kit-v2.md §8.4 (line 1236),
    which also has only those five. STANDARDS.md LAY-4 ("Gallery sizes
    (TEST-9): 360×800, 412×915, 915×412, 800×1280, 1280×800 and 1600×1000")
    and TEST-9, and the frozen `KitDivider.md` ("Default state (`insets`): at
    360×800, 915×412, 800×1280, 1280×800 and 1600×1000"), require 915×412.
    The G23 name gate already allows it (`test/golden_harness_test.dart:87`).
  - What this unit did: it rendered the shot in its own gallery file
    (`[...kitGallerySizes, const Size(915, 412)]`), which is the spec, not a
    workaround; `kit_gallery.dart` is shared and outside this write set, so
    it is not edited. Every other part built on `kitGallerySizes` is missing
    the 915×412 shot until the integrator adds it there and to kit-v2.md
    §8.4.
  - An earlier revision of this record said "none" and that the galleries
    were "at the §8.4 sizes"; that was wrong: the first build had no
    915×412 shot.
- New kit parts (KIT-3): `KitDivider` — this unit's own part.
- Map items (EVID-11): n/a — no pages, no `actionsMissing`/`statesMissing`/
  `couldBeAutomatic` items apply.
- States per page (STATE-20): n/a. Per the frozen spec's own "States"
  section: "None. A separator has no loading, empty, error, disabled,
  working or answered state." Verified by the absence of any state
  parameter in the public API and by the contract tests below.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitDivider`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`
  (`feat/phone-setup-v2`). First build `a0d20201d4a36ad4819ad9137f45a8ab59b88931`;
  review fixes (code head) `74f7cfa6`.
- No APK (unit agents do not build; R19/R20 reserve device and build proof
  for the coordinator).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Sanity check: the fractional-offset pixel-probe test with `_snap` disabled (`return logical;`) | fails with an assertion, not a compile error | failed: `device row 28 should be the one painted row` — see `pixel-snap-sanity-failing.txt` | PASS |
| 2 | `test/kit/kit_divider_test.dart` restored to the committed `_snap`, full file | passes | 17 passed | PASS |
| 3 | `test/goldens/kit/kit_divider_golden_test.dart --update-goldens` | generates 20 PNGs, each looked at | 20 passed, each opened and reviewed (§5) | PASS |
| 4 | `test/goldens/kit/kit_divider_golden_test.dart`, no `--update-goldens` (deterministic re-run) | passes with the just-reviewed goldens, including the G5 accessibility check on every shot | 20 passed | PASS |
| 5 | `flutter analyze lib test` | no errors; no new issues in changed paths | `No issues found!` (21.9s) | PASS |
| 6 | `test/kit_ratchet_test.dart` + `test/design_standard_test.dart` | pass | 47 passed | PASS |
| 7 | `test/l10n_coverage_test.dart` + `test/ui_glossary_test.dart` + `test/ui_ledger_coverage_test.dart` | pass | 25 passed | PASS |

Review fixes (code head `74f7cfa6`; runs 1–7 above are for `a0d20201`):

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 8 | Sanity check A: semantics test with `ExcludeSemantics` swapped for `KeyedSubtree` (the wrapper removed, nothing else) | passes: the leaf `_RenderKitHairline` has no semantics configuration, so the tree does not change | passed | PASS (as expected; see note) |
| 9 | Sanity check B: `ExcludeSemantics` swapped for `Semantics(label: 'Divider')` | fails with an assertion | failed: `a horizontal KitDivider must add nothing to the semantics tree`, the tree gains `label: "Divider"` — `semantics-sanity-failing.txt` | PASS |
| 10 | Sanity check C: `ExcludeSemantics` swapped for `Semantics(container: true)` (an unlabelled node) | fails with an assertion | failed with the same reason — `semantics-sanity-failing.txt` | PASS |
| 11 | `test/kit/kit_divider_test.dart` with the committed part | passes | 18 passed | PASS |
| 12 | `test/goldens/kit/kit_divider_golden_test.dart --update-goldens` | 22 shots, each looked at | 22 passed; all 22 opened (§5) | PASS |
| 13 | Goldens + unit tests, no `--update-goldens` | pass | 40 passed (22 golden, 18 unit) | PASS |
| 14 | `flutter analyze` on the three changed Dart files | clean | `No issues found!` | PASS |
| 15 | `test/kit_ratchet_test.dart` + `test/golden_harness_test.dart` (G16, G23 names incl. `_915x412_`) | pass | 40 passed | PASS |
| 16 | `test/design_standard_test.dart` | pass | 15 passed | PASS |

Runs 8–10 note (TEST-2): removing `ExcludeSemantics` alone cannot fail any
behaviour test, because the painted leaf never describes semantics; the
wrapper is the spec's guarantee that nothing below it ever will. So the
discriminating check is a divider that does reach the tree (a label, or an
empty container node), and the test catches both. The earlier test checked
`debugSemantics == null` on the wrapper's own render object, which can never
form a node, so it said nothing about what a screen reader meets between two
rows; it was replaced.

Run 1 is not a "fix" in TEST-2's sense (there is no prior broken behaviour to
revert to) — it is the same discipline applied to new code, to prove the
hardest test (the pixel-grid-snap probe) actually discriminates a correct
implementation from an incorrect one before trusting it. The KitDivider.md
example offset (y = 10.3 at DPR 2.625) turned out to leave only a 3.75 %
sub-pixel bleed into the next row, too small for this probe's tolerance to
catch, so the test uses y = 27.5 device pixels instead (an exact half-pixel
straddle), which fails clearly without the fix and passes with it.

## 5. Evidence

- `pixel-snap-sanity-failing.txt`: output of Run 1.
- `semantics-sanity-failing.txt`: outputs of Runs 8–10.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | Acceptance: hairline 1 physical px | `test/kit/kit_divider_test.dart` "layout extent is exactly one physical pixel" (dpr 1.0, 2.625, 3.0, both axes) | Run 2, Run 11 |
  | Tokens: the thickness is `KitTokens.hairlineWidth(context)` (KitDivider.md §Tokens) | `test/kit/kit_divider_test.dart` "both axes are exactly KitTokens.hairlineWidth thick" | Run 11 |
  | LOOK-21 (never smeared over two device-pixel rows) | `test/kit/kit_divider_test.dart` "a fractional offset snaps to exactly one device-pixel row (DPR 2.625)" | Run 1 (fails without the fix) + Run 2 (passes with it) |
  | Insets none/gutter/text = 0/16/58, RTL from the right | `test/kit/kit_divider_test.dart` "insets: none 0, gutter 16, text 58 from the start edge" | Run 2 |
  | Colour = `ThemeRoles.hairline` exactly, alpha unchanged, light and dark | `test/kit/kit_divider_test.dart` "colour is exactly ThemeRoles.hairline, alpha unchanged" | Run 2 |
  | No semantics node | `test/kit/kit_divider_test.dart` "has no semantics node (decorative, never announced)": the whole semantics tree with the divider (horizontal, `text` inset, vertical) equals the tree with an empty box of the same size in its place | Runs 8–11 |
  | 200 % text unaffected | `test/kit/kit_divider_test.dart` "thickness is unaffected by 2.0 text" | Run 2 |
  | Reduced motion, no ticker (MOT-7) | `test/kit/kit_divider_test.dart` `kitMotionStillTests('KitDivider', …)`, 6 samples (horizontal, horizontal gutter inset, vertical × system/effectsOff) | Run 2 |
  | G4/TEST-9 galleries: both states at 412×915; `insets` at 360×800, 915×412, 800×1280, 1280×800, 1600×1000; 2.0 text and Arabic at 412×915 and 1280×800; dark and light; DPR 3 | `test/goldens/kit/kit_divider_golden_test.dart` | Runs 12–13 |
  | G5 accessibility (tap targets, contrast, reading order) on every gallery shot, including the toolbar's four `KitIconButton`s | `test/goldens/kit/kit_divider_golden_test.dart` (built into `kitGalleryPart`) | Runs 12–13, no baseline entry needed |

- Changed test expectations (TEST-19): none against the base — every file
  here is new. Within this branch, the review fixes replaced the semantics
  test's assertion (the old one could not fail, Runs 8–10 note) and added
  the `KitTokens.hairlineWidth` test; no expectation was loosened.
- Goldens changed (all new to the repo; each opened and looked at before
  committing). The review fixes regenerated all 20 first-build shots,
  because the fixtures are now the kit's own `KitRow` (with `KitRow.icon`,
  the 30 dp `surface3` tile with 9 dp corners) and `KitIconButton`, and
  added two:
  - `kit_divider_insets_{dark,light}.png` (412×915) and the other gallery
    sizes (360×800, 915×412, 800×1280, 1280×800, 1600×1000), both themes:
    four `KitRow`s on one `surface1` panel, hairlines of `none` (edge to
    edge), `gutter` (16 dp) and `text` (58 dp) between them. Measured on
    the PNGs: the three lines start at x = 0, 16 and 58 at 412×915, and at
    the panel's start + 0, 16 and 58 at 915×412 (panel 97–817); the `text`
    line starts exactly where `KitRow`'s title starts, past the tile.
  - `kit_divider_insets_915x412_{dark,light}.png` (new in the review fix):
    the landscape phone; the panel is centred and capped, the insets hold.
  - `kit_divider_insets_ar_{dark,light}.png` (412×915, 1280×800): Arabic,
    right-to-left. Measured: `gutter` and `text` end 16 and 58 px from the
    right edge (x ≤ 395 and ≤ 353 of 412), `none` spans edge to edge.
  - `kit_divider_insets_text2_{dark,light}.png` (412×915, 1280×800): 2.0
    text; the rows grow with the type, the hairlines stay one line and the
    `text` inset still meets the title's start.
  - `kit_divider_vertical_{dark,light}.png` (412×915): a toolbar one
    `minTarget` tall with two groups of two `KitIconButton`s, split by one
    vertical hairline that keeps `space3` clear above and below, so it is
    as tall as the glyphs.
  - Crispness (KitDivider.md "Galleries required"), corrected: the gallery
    PNGs are captured by `matchesGoldenFile` at one image pixel per logical
    pixel (a 412×915 shot is a 412×915 PNG), so the DPR-3 device rows are
    not in the image and cannot be judged there. In the PNGs each hairline
    is exactly one image row of blended colour (light: (248, 248, 248) on
    white at y = 70, 124, 178), never two. The one-device-row claim itself
    is proven at device resolution by the pixel probe (Runs 1–2, 11). The
    first revision of this record claimed a 4× device-pixel view of the
    golden; that was not possible from a 1× capture.
  - No approved VL canvas render exists yet for this part (EVID-12): none.
- Before and after (EVID-10): n/a — new kit part, no existing page or golden
  changes look; nothing was migrated onto it in this unit.
- Accessibility: decorative and excluded from semantics (verified: the
  whole semantics tree is identical with and without the divider, Runs
  8–11); not focusable or interactive (`hitTestSelf` is `false`);
  unaffected by 200 % text (its
  layout extent is DPR-derived, not type-derived); every gallery shot passed
  `androidTapTargetGuideline`, `labeledTapTargetGuideline`,
  `textContrastGuideline` and the reading-order check with no new baseline
  entries.
- Privacy and security: n/a — no credentials, stored data, links or
  notifications are touched by a hairline.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_divider_test.dart
$F test -j 1 test/goldens/kit/kit_divider_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/golden_harness_test.dart
$F test -j 1 test/design_standard_test.dart
$F test -j 1 test/l10n_coverage_test.dart test/ui_glossary_test.dart test/ui_ledger_coverage_test.dart
$F analyze lib/ui/kit/kit_divider.dart test/kit/kit_divider_test.dart test/goldens/kit/kit_divider_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (R19/R20: coordinator work).
- Not exported from `kit.dart` (R06: the integrator's row) — so it is not
  yet reachable from any real screen, and the G8x reduced-motion ratchet
  (`test/kit_motion_test.dart`) will not check it until that export lands;
  this unit's own registration is already in place for that moment.
- No call site migrated (R14 non-goal, and this unit's non-goal): the 70
  `Divider`/`VerticalDivider` uses the spec lists still stand.
- No live-server or Paseo checks apply to a pure UI kit part; none run.
- Copy (COPY-1): no new user-facing strings were added (KitDivider carries
  no text), so nothing changed in `app_en.arb`/`app_ar.arb` and `gen-l10n`
  was not re-run. The gallery test's placeholder row labels are test-only
  fixture text, not app copy, matching the existing pattern in
  `test/goldens/kit/kit_sheet_golden_test.dart`.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitDivider` |
| Enabled | No: not exported from `kit.dart` yet (R06) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `74f7cfa6` (review fixes on `a0d20201`) |
| Deployed | No | |
| Released | No | |
