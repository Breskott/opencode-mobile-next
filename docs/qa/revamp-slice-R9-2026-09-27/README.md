# revamp-slice-R9: R9 Theme: disabled buttons pass AA in dark, one accent-meaning check (2026-09-27)

## 1. Scope

- Unit: `slice-R9` (wave 3, kit-change). Finish line: a disabled primary or secondary button (`text3` on `surface3`) reads at 4.5:1 or more in every theme pack and a custom theme, and LOOK-39 is one public check (`accentKeepsMeaning`) that the swatch assert and the tests share. Non-goal: moving any other role, changing `KitButton`, or making `deriveRoles` move an accent away from attention/danger.
- Files changed: `lib/ui/theme_roles.dart`, `lib/ui/kit/kit_swatch.dart`, `test/theme_roles_test.dart`, `test/kit/kit_swatch_test.dart`, 14 dark goldens `test/goldens/kit/kit_swatch_*_dark.png`.
- Pages (map ids): none (theme roles and one kit part).
- Specs followed: visual-language §3 (roles, text3 floor), LOOK-8, LOOK-39; kit-api/KitSwatch.md "Only guarded accents" and "Pre-wave" (the public `accentKeepsMeaning(Color accent, ThemeRoles roles)` it names).
- Contract problems (PROC-20):
  - visual-language-2026-09-26.md §3 lists `text3` as `#8A8D94` "≥ 4.5:1 on ground"; the dark value is now `#8C8F96` because the spec value measures 4.44:1 on `surface3`, where `KitButton` paints disabled words. The docs and `.dc.html` canvases are outside this unit's write set; proposed text for §3: "`text3` `#8C8F96`, ≥ 4.5:1 on ground and every surface (a disabled button is text3 on surface3)". Does not block.
  - KitSwatch.md says the accent assert "uses the same check `deriveRoles` uses". `deriveRoles` has no LOOK-39 check (it only guards contrast), so the shared check is `accentKeepsMeaning`, used by the swatch and the tests. Proposed text: "uses `accentKeepsMeaning` from `theme_roles.dart`". Does not block.
- New kit parts (KIT-3): none. New public API in `theme_roles.dart` (additive): `accentKeepsMeaning`, `accentMinHueDistance`, `accentMinDeltaE`, `hueDistance`, `deltaE2000`, and `@visibleForTesting deltaE2000Lab`.
- Map items (EVID-11): n/a: no pages.
- States per page (STATE-20): n/a: no pages. Part states unchanged (KitSwatch disabled golden regenerated).
- Deferred states (STATE-21): none.
- Moved or removed items (owner rethink rule): removed the private CIEDE2000/hue/Lab duplicate from `kit_swatch.dart` and from `test/theme_roles_test.dart`; nothing on a page moved.

## 2. Builds

- Branch `revamp/slice-R9`, base `643a5104`, code head `0c3f5718`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 3 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Probe on base: `contrastRatio(text3, surface3)` for every pack | shows the defect | opencode/dark 4.438; every derived pack 3.96–4.45 in both brightnesses | PASS (defect confirmed) |
| 2 | `test/theme_roles_test.dart` + `test/kit/kit_swatch_test.dart` | pass | 80 passed | PASS |
| 3 | `test/goldens/kit/kit_swatch_golden_test.dart` before regenerating | only text3 pixels differ | 14 dark goldens failed; diffs only on the disabled glyph/label and a disabled-reason icon | PASS |
| 4 | same, `--update-goldens`, then looked at | pass | 30 passed | PASS |
| 5 | `flutter analyze` on the four changed Dart files | no issues | No issues found | PASS |

Ratchet, design-standard, l10n and other suites were not run (owner decision 2026-09-27: own files only).

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | text3 floor (visual-language §3) | `test/theme_roles_test.dart` "a disabled button reads in every pack: text3 on surface3 (R9)"; `_floors` now also checks text3 on surface3 for every pack and custom theme | run 2 |
  | LOOK-39 | `test/theme_roles_test.dart` "accentKeepsMeaning is the one LOOK-39 check (R9)" | run 2 |
  | LOOK-39 (swatch) | `test/kit/kit_swatch_test.dart` "the debug assert is accentKeepsMeaning: it asserts exactly when the shared check fails (R9)" | run 2 |

- Changed test expectations (TEST-19): `_floors` in `test/theme_roles_test.dart` no longer skips `text3 on surface3` (old: skipped; new: ≥ 4.5), visual-language §3.
- Goldens changed (each opened and looked at): `test/goldens/kit/kit_swatch_{disabled,grid*,grid_ar*,grid_focused,grid_text2*,preview_graphite_text2*}_dark.png`: Graphite dark `text3` one step lighter (#8A8D94 → #8C8F96) on the disabled swatch's glyph and label and the preview's meta icon; nothing else. Approved render: none for these goldens (EVID-12).
- Before and after: `before-kit_swatch-disabled-dark.png` (from base `test/goldens/kit/kit_swatch_disabled_dark.png`), `after-kit_swatch-disabled-dark.png`.
- Accessibility: disabled button words now reach WCAG AA (4.5:1) on `surface3` in all 38 static pack/brightness pairs and derived custom themes.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/theme_roles_test.dart test/kit/kit_swatch_test.dart
$F test -j 1 test/goldens/kit/kit_swatch_golden_test.dart
$F analyze lib/ui/theme_roles.dart lib/ui/kit/kit_swatch.dart test/theme_roles_test.dart test/kit/kit_swatch_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Other goldens not re-rendered: every dark golden that paints Graphite `text3`, and every golden of a derived pack that paints `text3`, will show a one-step text3 change and need regeneration by the integrator.
- Ratchet, design-standard and l10n gates not run.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/slice-R9` |
| Enabled | Yes | theme roles in force for all packs |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `0c3f5718` |
| Deployed | No | |
| Released | No | |
