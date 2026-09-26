# revamp-kit-KitSwatch: Build KitSwatch + KitThemePreview (2026-09-26)

## 1. Scope

- Unit: `kit-KitSwatch` (wave 1, tier 1a, `kit-part`). Finish line: `KitSwatch`, `KitSwatchGrid` and `KitThemePreview` exist in `lib/ui/kit/kit_swatch.dart`, with the frozen §4 API, every declared state (default, selected, disabled with reason, focused), the required galleries and the required behaviour tests. Non-goal: no custom-theme editor, no preview sheet/Apply button/save, no Effects/glass preview, no change to theme packs or `deriveRoles`, no call site outside the kit changes (`kit.dart` export is R06, the integrator's job).
- Files changed: `lib/ui/kit/kit_swatch.dart` (new), `test/kit/kit_swatch_test.dart` (new), `test/goldens/kit/kit_swatch_golden_test.dart` (new) plus 28 golden PNGs, `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb` (9 new `kitSwatch*`/`kitThemePreview*` keys, additive; see contract problem 3), this QA record.
- Review round 1 (13 findings) fixed: the preview's code line is an LTR island (`Directionality` LTR); Arabic preview goldens without tofu (test seam, problem 2); light galleries use each pack's light roles and light accents; the accent scene has the 3 non-default accents; accent swatches are 48 dp targets 8 dp apart in a start-aligned `Wrap`; arrow keys, Home, End and the initial Tab stop skip disabled swatches; the tile's fill (`surface1`, hover one surface step up as KitTappable does) shares the border's rounded decoration; the focus ring is a separate `accent` ring outside the state border, and the accent's selected `text1` ring sits outside the circle; a truncated label gets a tooltip on a fine pointer; the needs-you word renders `KitTaskMark(state: needsYou)`; icon sizes come from `smallIconSize`; the swatch is one semantics node whose label is exactly the name.
- Pages (map ids): none — `kit-KitSwatch`'s `work-units.json` entry has no `pages` (a kit-part unit; the settings grid and the preview sheet adopt this part in wave 2, per the frozen spec's "Depended on by").
- Specs followed: `docs/ux-system/kit-api/KitSwatch.md` (frozen, R16); `docs/ux-system/kit-v2.md` §5, §9.1, §9.2; rules named by the task: LOOK-1, LOOK-6, LOOK-7, LOOK-8, LOOK-14, LOOK-21, LOOK-27, LOOK-39, KIT-9, KIT-12, KIT-25, STATE-8, STATE-9, LAY-2, LAY-9, A11Y-1, A11Y-8; plus KIT-5 (the one allowlisted `Theme` override, inside the kit) and G21 (kit-internal literals, all fixed to read from `KitTokens`).
- **Contract problems (PROC-20):**
  1. **The frozen spec's own "Depends on" section names a gap, not a contradiction, but it blocks one behaviour test as written.** `KitSwatch.accent`'s debug assert is specified as using "the same check `deriveRoles` uses" for LOOK-39 (hue ≥ 30°, ΔE2000 ≥ 20 from `attention` and `danger`), but the spec itself says in the same section: "the LOOK-39 distance check must be a public function in `theme_roles.dart`… This is the §0.5 step 1 theme work, not this unit's." `theme_roles.dart` has no such public function (confirmed: `grep -n accentKeepsMeaning lib/ui/theme_roles.dart` — no match; it is listed under "Not added here" in `docs/ux-system/kit-api/_new-tokens.md`), and `theme_roles.dart` is outside this unit's write set. Rather than skip the assert (which the frozen spec's own Tests §5 requires) or leave the widget non-compliant, I implemented the check as a **self-contained private duplicate** of the exact hue-distance/CIEDE2000 formula `test/theme_roles_test.dart` already uses privately for the same rule (same LAB conversion, same Sharma–Wu–Dalal 2005 CIEDE2000 steps), scoped to `lib/ui/kit/kit_swatch.dart` only, with a code comment pointing at this note. **Recommended fix:** once `theme_roles.dart` gains a public `accentKeepsMeaning(Color, ThemeRoles)` (§0.5 step 1), delete the duplicate block at the bottom of `kit_swatch.dart` (marked "LOOK-39 for KitSwatch.accent's debug assert") and call the real function instead.
  2. **A test-harness gap for the preview's Arabic button labels, not a proven device bug.** `KitThemePreview` wraps its sample in `Theme(data: AppTheme.forLocale(AppTheme.fromRoles(roles), locale))` as frozen (KIT-5). `AppTheme.forLocale` patches `textTheme`/`primaryTextTheme` but not the button themes' baked `textStyle`, so in the test engine (no system fonts) the sample's `KitButton` labels drew as tofu. On a device the platform's system font fallback draws those glyphs, so this is **not** shown to be a device bug; nothing here proves one either way (not run on a device, R19/R20). `test/goldens/kit/kit_gallery.dart` patches the button fallback only for the outer theme, and cannot reach the preview's inner `Theme`. **Resolution in this unit:** a debug-only test seam in `kit_swatch.dart`, the top-level `@visibleForTesting ThemeData Function(ThemeData)? debugKitThemePreviewTheme` (read only inside an `assert`, so it does nothing in release). The Arabic gallery tests set it to give the sample's button styles the same `Noto Sans Arabic` fallback `kit_gallery.dart` gives the outer theme, and reset it in a tear-down. The `_ar` preview goldens now draw "إرسال" and "إرفاق". This seam is an addition beside the frozen API (not a change to it); the coordinator may prefer to move the fallback into `AppTheme.forLocale` (outside this write set), after which the seam can go.
  3. **Copy outside the declared write set (R04 vs the task's write set).** The frozen spec requires the 9 `kitSwatch*`/`kitThemePreview*` keys, so `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb` are edited (additive only), although the task's write set names only `kit_swatch.dart` and the two test files. The generated `lib/l10n/app_localizations*.dart` is not committed (PROC-13), so **this branch does not analyze or compile until the integrator runs `flutter gen-l10n`** after merging.
- New kit parts (KIT-3): `KitSwatch`, `KitSwatchGrid`, `KitThemePreview` — all three are this unit's own frozen part (R13 exempts the builder's own part).
- Map items (EVID-11): n/a — no `pages` entries on this unit.
- States per page (STATE-20): n/a — kit-part unit, no owned pages.
- Deferred states (STATE-21): n/a.

## 2. Builds

- Branch `revamp/kit-KitSwatch`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4` (`feat/phone-setup-v2` tip when this worktree started; the shared branch has since moved further on the coordinator's machine — expected, per PROC-9/PROC-32 this unit does not rebase mid-flight), code head: this record's commit.
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work (R19, R20).

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `flutter pub get` | resolves | "Got dependencies!" | PASS |
| 2 | `flutter analyze lib/ui/kit/kit_swatch.dart` | no issues | "No issues found!" | PASS |
| 3 | `flutter test -j 1 test/kit/kit_swatch_test.dart` (the 9 required behaviour scenarios plus the review-round tests: semantics label, disabled skipping, focus ring, hover, tooltip, accent layout, preview parts) | all pass | 58 passed; the disabled-skipping and semantics-label tests were run against the previous commit's `kit_swatch.dart` and failed there (focus stayed put; label read "Graphite\n…") | PASS |
| 4 | `flutter test -j 1 --update-goldens test/goldens/kit/kit_swatch_golden_test.dart`, each PNG opened and looked at | 28 PNGs, all correct | 28 passed, all reviewed (see §5) | PASS |
| 5 | `flutter analyze lib test` (whole tree, with gen-l10n output present locally) | no errors, no new issues | "No issues found!" | PASS |
| 6 | `flutter test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart`, then `test/l10n_coverage_test.dart test/golden_harness_test.dart` | pass (ratchet baselines only shrink or hold) | 47 passed; 10 passed | PASS |
| 7 | `flutter test -j 1 test/design_standard_test.dart test/ui_glossary_test.dart test/ui_ledger_coverage_test.dart` | pass | 38 passed | PASS |
| 8 | `flutter gen-l10n` (local only, output not committed) | new `kitSwatch*`/`kitThemePreview*` getters generated | generated; `lib/l10n/app_localizations*.dart` restored with `git checkout --` before committing (PROC-13) | PASS |

## 5. Evidence

- `failing-first.txt`: n/a — this is new behaviour, not a fix (TEST-2 exempts new code that fixes nothing from a failing-first run).
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-25 (accent selects at once) | `test/kit/kit_swatch_test.dart` "the check paints in onColor(color)" | 49/49 passed in the file run |
  | STATE-9 (never colour alone) | `test/kit/kit_swatch_test.dart` "selected gives \"In use\" semantics…" | same run |
  | STATE-8 / LOOK-14 (unavailable said, not faded) | `test/kit/kit_swatch_test.dart` "with a reason: the reason is visible text… no Opacity wraps any text" | same run |
  | LOOK-39 | `test/kit/kit_swatch_test.dart` "a colour inside the attention band asserts in debug (LOOK-39)" | same run |
  | LAY-9 / A11Y-8 (columns, one fewer at 1.3×) | `test/kit/kit_swatch_test.dart` grid columns group (4 tests) | same run |
  | LAY-10-style group rule | `test/kit/kit_swatch_test.dart` keyboard group (4 tests) | same run |
  | G6 overflow | `test/kit/kit_swatch_test.dart` "no overflow …" (30 parameterised cases) | same run |
  | G21 (kit-internal literals) | `test/kit_ratchet_test.dart` "G21 look and motion: numbers and effects come from the kit" | 16/16 passed |

- Changed test expectations (TEST-19): none — both test files are new.
- Goldens changed (all new; each opened and looked at before committing):
  - `kit_swatch_grid_dark.png` / `_light.png`: the 8-pack grid in the gallery's brightness (light packs in the light shot, dark in the dark) — Graphite selected (accent border, check), Material You unavailable (sparkle glyph, visible reason), the rest each in their own theme's ground/panel/accent/success; tiles on `surface1`. Correct.
  - `kit_swatch_grid_focused_dark.png` / `_light.png`: as above, with the accent focus ring outside the selected swatch's border. Correct.
  - `kit_swatch_accent_dark.png` / `_light.png`: the 3 guarded Graphite accents other than the default green (blue, teal, violet) in that brightness's accent values, 48 dp targets 8 dp apart from the start edge, blue selected with its check in `onColor`. Correct.
  - `kit_swatch_preview_graphite_dark.png` / `_light.png`, `kit_swatch_preview_catppuccin_dark.png` / `_light.png`: the sample panel (icon tile, title, working mark, code line, needs-you task mark, segment check, Send/Attach) painted in the candidate theme's roles of that brightness. Correct.
  - `kit_swatch_grid_{360x800,915x412,800x1280,1280x800,1600x1000}_{dark,light}.png`: the default grid across the LAY-4 sizes; columns grow from 2/3 up to 6, no overflow. Correct.
  - `kit_swatch_{grid,preview_graphite}_text2_{,1280x800}_dark.png`: 2.0 text; the grid drops a column, labels wrap to two lines, no overflow; the preview grows taller. Correct.
  - `kit_swatch_{grid,preview_graphite}_ar_{,1280x800}_dark.png`: right-to-left mirrored layout; the preview's code line `final ready = true;` is an LTR island aligned left; every Arabic word draws, the buttons "إرسال"/"إرفاق" included (contract problem 2), and the segment reads "مفعّل". Correct.
  - The segment pill in the preview is a stand-in (a `DecoratedBox` pill with a check and `KitText`) until the planned `KitSegmented` part merges; the preview then renders that part.
- Before and after: n/a — no page this unit owns; `KitSwatch`/`KitThemePreview` are new, so there is no prior render (EVID-10 "no before render", no page id, since no map page is being replaced by this unit).
- Accessibility: each swatch is a button in an `inMutuallyExclusiveGroup`, labelled by its name, selected semantics carry the value "In use" (never colour alone); a disabled swatch keeps its reason as the semantics hint and is skipped by Tab (verified: `Focus.skipTraversal == true`, `canRequestFocus == false`); targets are ≥48×48 dp (`tokens.minTarget`); 200% text wraps (label to 2 lines, reason unbounded) with no overflow at 320–1600 dp, LTR and RTL (30-case sweep, all pass); the preview is one semantics node (`excludeSemantics: true`, `image: true`) with no descendant button nodes (verified: `find.bySemanticsLabel('Send')` finds nothing).
- Privacy and security: n/a — no credentials, stored data, external links or notifications are touched. `KitSwatch` never applies or saves a theme; `onPressed` is entirely the host's.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F analyze lib/ui/kit/kit_swatch.dart
$F test -j 1 test/kit/kit_swatch_test.dart
$F test -j 1 test/goldens/kit/kit_swatch_golden_test.dart
$F analyze lib test
$F test -j 1 test/kit_ratchet_test.dart test/l10n_coverage_test.dart test/design_standard_test.dart test/ui_glossary_test.dart test/ui_ledger_coverage_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (coordinator work, R19/R20).
- `KitSwatch`/`KitSwatchGrid`/`KitThemePreview` are not yet exported from `kit.dart` (R06: the integrator adds the export and doc-table row) and are not yet adopted by `personal_settings_screens.dart`'s pack grid or `appearance_picker.dart`'s preview sheet — that is explicitly wave-2 work per the frozen spec's "Depended on by", not this unit's.
- `test/kit/kit_overflow_scenes.dart` and the other kit.dart-manifest-driven registries (`kit_keyboard_test.dart`, `text_scale_overflow_test.dart`, `accessibility_guidelines_test.dart`) have no `KitSwatch` entry yet: they discover parts from `kit.dart`'s exports, which do not include this part until R06 happens, so they do not need one from this unit yet either.
- The two contract problems above (§1) are reported, not resolved, per R16/PROC-20 — resolving them needs `theme_roles.dart` and `app_theme.dart` respectively, both outside this unit's write set.
- Hover fill, cursor and the truncated-label tooltip are proven by widget tests with a simulated mouse only, not on a PC build.
- `flutter build apk` was not run (out of scope for a kit-part unit; R19).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitSwatch`, `lib/ui/kit/kit_swatch.dart` |
| Enabled | No: not yet exported from `kit.dart` or adopted by any screen (wave-2 work) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head: this record's commit |
| Deployed | No | |
| Released | No | |
