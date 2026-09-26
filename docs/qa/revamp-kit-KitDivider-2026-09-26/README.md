# revamp-kit-KitDivider: KitDivider, the one hairline separator (2026-09-26)

## 1. Scope

- Unit: `kit-KitDivider` (wave 1, tier 1, `kit-part`). Finish line: `KitDivider`
  exists in its own file under `lib/ui/kit/`, matches its frozen API, states,
  galleries and contract tests. Non-goal: no call site outside the kit
  changes — `Divider`/`VerticalDivider` at the 70 call sites the spec lists
  are a separate unit's work.
- Files changed: `lib/ui/kit/kit_divider.dart` (new),
  `test/kit/kit_divider_test.dart` (new),
  `test/goldens/kit/kit_divider_golden_test.dart` (new), its 20 PNGs under
  `test/goldens/kit/kit_divider_*.png`, and this QA record.
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
- Contract problems (PROC-20): none. The frozen spec, kit-v2.md §8.2/§8.4 and
  STANDARDS.md §15 all agree; no rule or contract needed to be reported.
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
  (`feat/phone-setup-v2`), code head `a0d20201d4a36ad4819ad9137f45a8ab59b88931`.
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
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | Acceptance: hairline 1 physical px | `test/kit/kit_divider_test.dart` "layout extent is exactly one physical pixel" (dpr 1.0, 2.625, 3.0, both axes) | Run 2 |
  | LOOK-21 (never smeared over two device-pixel rows) | `test/kit/kit_divider_test.dart` "a fractional offset snaps to exactly one device-pixel row (DPR 2.625)" | Run 1 (fails without the fix) + Run 2 (passes with it) |
  | Insets none/gutter/text = 0/16/58, RTL from the right | `test/kit/kit_divider_test.dart` "insets: none 0, gutter 16, text 58 from the start edge" | Run 2 |
  | Colour = `ThemeRoles.hairline` exactly, alpha unchanged, light and dark | `test/kit/kit_divider_test.dart` "colour is exactly ThemeRoles.hairline, alpha unchanged" | Run 2 |
  | No semantics node | `test/kit/kit_divider_test.dart` "has no semantics node (decorative, never announced)" | Run 2 |
  | 200 % text unaffected | `test/kit/kit_divider_test.dart` "thickness is unaffected by 2.0 text" | Run 2 |
  | Reduced motion, no ticker (MOT-7) | `test/kit/kit_divider_test.dart` `kitMotionStillTests('KitDivider', …)`, 6 samples (horizontal, horizontal gutter inset, vertical × system/effectsOff) | Run 2 |
  | G4 galleries at the §8.4 sizes, dark and light, plus 2.0 text and Arabic at 412×915/1280×800 | `test/goldens/kit/kit_divider_golden_test.dart` | Run 3/4 |
  | G5 accessibility (tap targets, contrast, reading order) on every gallery shot | `test/goldens/kit/kit_divider_golden_test.dart` (built into `kitGalleryPart`) | Run 3/4, no baseline entry needed |

- Changed test expectations (TEST-19): none — every file here is new.
- Goldens changed (all new; each opened and looked at before committing):
  - `kit_divider_insets_{dark,light}.png` (412×915) and the four other §8.4
    sizes, both themes: four placeholder rows on one panel, hairlines of
    `none` (edge to edge), `gutter` (16 dp) and `text` (58 dp, past the icon
    tile) between them. Confirmed the `text` inset lines up with where the
    row's title starts, not the icon tile's edge.
  - `kit_divider_insets_ar_{dark,light}.png` (412×915, 1280×800): Arabic,
    right-to-left. Confirmed the gap moves to the right for `gutter` and
    `text`, and `none` still spans edge to edge.
  - `kit_divider_insets_text2_{dark,light}.png` (412×915, 1280×800): 2.0
    text; row height and hairline position hold, only the type grows.
  - `kit_divider_vertical_{dark,light}.png` (412×915): two icon groups in a
    toolbar strip, split by one vertical hairline. Crispness (KitDivider.md
    "Galleries required"): at 412×915 DPR 3, cropped and viewed at 4× —
    one clean line, no doubling and no soft/blurred edge, in both themes.
  - No approved VL canvas render exists yet for this part (EVID-12): none.
- Before and after (EVID-10): n/a — new kit part, no existing page or golden
  changes look; nothing was migrated onto it in this unit.
- Accessibility: decorative and excluded from semantics (verified: the
  painted line's `RenderObject.debugSemantics` is `null`); not focusable or
  interactive (`hitTestSelf` is `false`); unaffected by 200 % text (its
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
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart
$F test -j 1 test/l10n_coverage_test.dart test/ui_glossary_test.dart test/ui_ledger_coverage_test.dart
$F analyze lib test
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
| Committed | Yes | code head `a0d20201d4a36ad4819ad9137f45a8ab59b88931` |
| Deployed | No | |
| Released | No | |
