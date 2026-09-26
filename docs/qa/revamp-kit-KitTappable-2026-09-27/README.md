# revamp-kit-KitTappable: KitTappable, the one tap-acting primitive (2026-09-27)

## 1. Scope

- Unit: `kit-KitTappable` (wave 1, tier 2, kit-part, `after: kit-KitMenu`). Finish line: `KitTappable` exists in its own file under `lib/ui/kit/`, has its frozen API, every declared state, its galleries (TEST-9), its contract tests (TEST-15) and its structural asserts. Non-goal: no call site outside the kit changes — `KitRow`, `KitSurface`-based cards, `KitBreadcrumb` and the chat parts adopt it in their own later units.
- Files changed: `lib/ui/kit/kit_tappable.dart` (new), `test/kit/kit_tappable_test.dart` (new), `test/goldens/kit/kit_tappable_golden_test.dart` (new, 16 PNGs), `lib/l10n/app_en.arb` (+`kitTappableShowActions`). Generated `lib/l10n/app_localizations*.dart` are not on the branch (see contract problem 1, PROC-13).
- Pages (map ids): none. `kit-KitTappable` is a kit-part unit with no assigned map pages.
- Specs followed: `docs/ux-system/kit-api/KitTappable.md` (frozen API, states, tokens, adaptive, a11y, RTL, motion, data safety). **Correction (review, 2026-09-27):** the first build (`28acbe89`) did *not* build every section as written — Accessibility (the semantic long-press "Show actions" was a custom action instead), Motion (only `KitMotion.enter`, and the reduced-motion path swapped widgets), A11Y-5 parity (a disabled tappable still published its menu actions), keyboard scoping (keys from focused descendants were handled) and Galleries (no `focused` at 1280×800 with the desktop override; no G5 scan on the interactive shots) were short of the spec. The follow-up fix unit below closes those; the earlier claim is withdrawn; STANDARDS.md rules KIT-9, KIT-10, KIT-12, KIT-28, KIT-43, LOOK-6, LOOK-8, LOOK-19, LOOK-21, STATE-8, A11Y-5, A11Y-6, A11Y-8, MOT-1, MOT-2, MOT-7, MOT-11, plus TEST-9/TEST-15/TEST-20 (galleries and contract tests) and the §1 definition-of-done checklist; `docs/ux-system/kit-v2.md` §7 (G9 contract), §8.2 (adaptive), §8.3 (density, keyboard), §8.4 (gallery sizes), §9.1 (kit-only allowlist).
- Contract problems (PROC-20):
  1. **Arabic/gallery-size scope changed after the spec froze**, same as every wave-1 unit after 2026-09-27: `docs/ux-system/kit-api/KitTappable.md` (wave 0) asks for `app_ar.arb` copy, an Arabic/RTL gallery variant, and a larger size matrix (five LAY-4 sizes for the default state, plus states/menu at 412×915, plus `_text2`/`_ar` at 412×915 and 1280×800). The computed task for this unit states the later, dated owner decision directly: "Galleries: phone 412x915 and one wide size (1280x800) only, light and dark" and "Arabic is DROPPED — no Arabic/RTL galleries, no Arabic ARB entries for new copy". R15 ("owner decisions dated later win") makes this win over the frozen spec. Applied: `kitTappableShowActions` is English-only (no `app_ar.arb` entry; Arabic falls back to the English string); the gallery is `{enabled, disabled} × {412×915, 1280×800} × {dark, light}` (8 PNGs) plus `{hovered, pressed, focused, menu_open} × {412×915} × {dark, light}` (8 PNGs) = 16 PNGs, no Arabic or 2.0-text shots, no RTL review. Reported per PROC-20 rather than silently deviating from the frozen spec's own "Galleries required" section.
  2. **Generated l10n left uncommitted per PROC-13; integrator regenerates.** `flutter gen-l10n` is run locally (via `pub get`, which runs it automatically in this repo) so `kit_tappable.dart` and its tests compile and the checks below run, but its output (`lib/l10n/app_localizations.dart`, `_en.dart`, `_ar.dart`) is not committed (PROC-13, conflict-avoidance across the many parallel tier-1/2 branches). On a fresh checkout of this branch, `flutter analyze`/`flutter test` need `flutter pub get` (which regenerates it) first; the integrator commits the regenerated output after the merge.
  3. **Light theme: pressed looks the same as hovered on a fine pointer (spec problem, reported, not worked around).** In the light theme `surface1` and `surface2` are the same white, so the frozen surface-step rule gives hover = `surface3` and pressed = min(next step, `surface3`) = `surface3`: on a mouse in light, pressed is indistinguishable from hovered, and the menu-open hold looks like hover too (see `kit_tappable_pressed_light.png` / `kit_tappable_menu_open_light.png`). From `surface: surface3` (the chip rule) hover == pressed == `surface2` in both themes. The implementation follows the spec exactly; the spec owner decides between a pressed step that differs from hover (a new fill, e.g. a step below `surface3`) and accepting it explicitly in `KitSurface.md` and `KitTappable.md`.
  4. **`lib/l10n/app_en.arb` edited outside the stated write set.** The first build added `kitTappableShowActions` ("Show actions") to `app_en.arb`, which the spec's Accessibility section names but the unit's write set does not list. The integrator confirms the key (English-only, per the 2026-09-27 owner decision; no `app_ar.arb` entry). The follow-up fix adds no ARB key.
- New kit parts (KIT-3): `KitTappable` (`lib/ui/kit/kit_tappable.dart`).
- Map items (EVID-11): n/a — no map pages assigned to this unit.
- States per page (STATE-20): n/a — not a page. `KitTappable`'s own declared states (its doc comment "States"): `enabled`/`hovered`/`pressed`/`focused` → `test/kit/kit_tappable_test.dart` tests 1, 2, 7, 8, 9 and the matching galleries; `disabled` → test 3 and its gallery; `selected` (semantics only) → test 12; `menu-open` (holds the pressed fill) → the `menu_open` gallery and test group 4/5.
- Deferred states (STATE-21): none — the spec's own "States" section lists no loading/empty/error/answered state for this part ("Loading, empty, error and working belong to the host").

## 2. Builds

- Branch `revamp/kit-KitTappable`, base `dcf05c5efbf82781bcfb97b629f5cda86ead2382` (`feat/phone-setup-v2` at branch time), code head `28acbe89`.
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work at the wave checkpoint.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | New code, no prior fix to prove failing-first (TEST-2: "New code that fixes nothing needs no failing-first run") | n/a | n/a | n/a |
| 2 | `test/kit/kit_tappable_test.dart` | passes | 26 passed (`run-behaviour-tests.txt`) | PASS |
| 3 | `test/goldens/kit/kit_tappable_golden_test.dart` (against the committed PNGs, no `--update-goldens`) | passes | 16 passed (`run-galleries.txt`) | PASS |
| 4 | `test/kit_ratchet_test.dart`, `test/l10n_coverage_test.dart`, `test/design_standard_test.dart`, `test/ui_glossary_test.dart` | pass | 35 + 36 passed, 0 failed (`run-shared-gates.txt`) | PASS |
| 5 | `flutter analyze lib test` (whole worktree) | no errors, no new issues in changed paths | 6 pre-existing issues, all in files this unit did not touch (`kit_since.dart`/`kit_since_golden_test.dart`/`kit_since_test.dart`'s `clock` package `info`, and `kit_image_test.dart`'s `KitIconButton.label` `error` — none in `kit_tappable*` files) (`run-analyze.txt`) | PASS (changed paths clean) |

## 5. Evidence

- `run-behaviour-tests.txt`: output of step 2 (26 tests: the frozen spec's 12 numbered behaviour tests, the two debug-assert tests, and the `kitMotionStillTests` registration's 6 samples).
- `run-galleries.txt`: output of step 3.
- `run-shared-gates.txt`: output of step 4 (ratchet, l10n coverage, design-standard, glossary — none of them touched or newly failing; the ratchet's printed per-file counts are all pre-existing and unrelated to this unit, since it added no file under `lib/ui/` outside the kit).
- `run-analyze.txt`: output of step 5, showing the 6 pre-existing issues are all outside this unit's changed paths.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | LAY-9 / KIT-9 (48×48 minimum, small child centred, large child keeps size) | `test/kit/kit_tappable_test.dart` "1. a 20×20 child..." | `run-behaviour-tests.txt` |
  | A11Y-... (Enter/Space fire once, key repeat does not refire) | `test/kit/kit_tappable_test.dart` "2. Enter and Space..." | `run-behaviour-tests.txt` |
  | STATE-8 (disabled: no Tab stop, no hover, basic cursor, hint = reason) | `test/kit/kit_tappable_test.dart` "3. disabled..." | `run-behaviour-tests.txt` |
  | KitMenu.md "Right-click and long-press" / keyboard (Shift+F10, Menu key, onLongPress hook, onLongPress+menu assert) | `test/kit/kit_tappable_test.dart` group "4. menu:..." | `run-behaviour-tests.txt` |
  | KIT-28 (menu items as CustomSemanticsAction, "Show actions") | `test/kit/kit_tappable_test.dart` "5. menu items..." | `run-behaviour-tests.txt` |
  | "with an empty menu, long-press shows the tooltip" | `test/kit/kit_tappable_test.dart` "6. empty menu..." | `run-behaviour-tests.txt` |
  | KitSurface.md surface-step hover/pressed algorithm (dark, light, the surface3 "chip rule", touch = no hover) | `test/kit/kit_tappable_test.dart` group "7. hover and pressed..." (pixel probe) | `run-behaviour-tests.txt` |
  | LAY-10 / LOOK-21 (focus ring only via keyboard, not via tap) | `test/kit/kit_tappable_test.dart` "8. keyboard focus..." | `run-behaviour-tests.txt` |
  | Tooltip on hover and on keyboard focus, with the shortcut | `test/kit/kit_tappable_test.dart` "9. the tooltip..." | `run-behaviour-tests.txt` |
  | MOT-11 (no HapticFeedback ever) | `test/kit/kit_tappable_test.dart` "10. no HapticFeedback..." | `run-behaviour-tests.txt` |
  | MOT-7 / G8x (settles after one pump, system and Effects Off, enabled/disabled/pressed-then-released) | `kitMotionStillTests('KitTappable', ...)` in `test/kit/kit_tappable_test.dart` | `run-behaviour-tests.txt` |
  | A11Y (selected exposes `isSelected`) | `test/kit/kit_tappable_test.dart` "12. selected..." | `run-behaviour-tests.txt` |
  | TEST-9 / G4 (galleries at DPR 3, declared states, both themes, reduced sizes per the 2026-09-27 decision) | `test/goldens/kit/kit_tappable_golden_test.dart` | `run-galleries.txt` |
  | G16/G21 (kit-only ratchet: `kit_tappable.dart` adds zero new hits outside the kit; no literal colour/size/radius/duration inside it either) | `test/kit_ratchet_test.dart` | `run-shared-gates.txt` |
  | COPY (glossary, label rules) | `test/ui_glossary_test.dart` | `run-shared-gates.txt` |

- Changed test expectations (TEST-19): none — no shared test was touched or broke.
- Goldens changed (all new, each opened and looked at):
  - `kit_tappable_enabled_{dark,light}.png`, `_1280x800_{dark,light}.png`: a single row ("Archive \"Fix the login bug\"") on a `KitPanel` sheet, plain surface1 fill, no ring, no hover tint.
  - `kit_tappable_disabled_{dark,light}.png`, `_1280x800_{dark,light}.png`: the same row with a dimmed (`text3`/`text2`) icon and title and a visible "Needs a connection" second line (the host's own STATE-8 treatment — `KitTappable` itself draws no disabled look).
  - `kit_tappable_hovered_{dark,light}.png`: a barely-there lighter fill in dark (surface1→surface2, both close in value by design) and a clearer one in light (surface1→surface3).
  - `kit_tappable_pressed_{dark,light}.png`: a visibly stronger fill (surface3) in both themes.
  - `kit_tappable_focused_{dark,light}.png`: a 2-physical-px `accent` ring following the panel's rounded corners, drawn inside the bounds.
  - `kit_tappable_menu_open_{dark,light}.png`: the row (pressed fill) with `KitMenuPanel` open below it, "Rename" then "Archive" (destructive, red, last, after the divider) — matches KitMenu's own ordering rule.
  - No approved visual-language canvas render exists for KitTappable to diff the goldens against (EVID-12: none available).
- Before and after: n/a — new part, no prior render of this page/element exists (EVID-10: "no before render", no page id — KitTappable is not a screen).
- Accessibility: `button`/`link` role, `enabled`, `selected`, `hint` = disabled reason, label merges from the child's own text when `label` is null (tests 3, 5, 12); 48×48 minimum target proven at the corner of a 20×20 child (test 1); focus ring only for keyboard-originated focus (test 8); every menu action reachable as a `CustomSemanticsAction` in addition to the visible menu (test 5, KIT-28); tooltip text never the only carrier of information (semantics carry the same via `label`/`hint`).
- Privacy and security: no credentials, stored data, external links or notifications touched (n/a).
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get   # also regenerates lib/l10n/app_localizations*.dart (PROC-13)
$F test -j 1 test/kit/kit_tappable_test.dart test/goldens/kit/kit_tappable_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/l10n_coverage_test.dart test/design_standard_test.dart test/ui_glossary_test.dart
$F analyze lib test
```

## 5b. Follow-up fix unit (review of 2026-09-27)

The code commit `28acbe89` was fast-path merged into `feat/phone-setup-v2` (`097c9079`) before review, so these fixes land on `revamp/kit-KitTappable` as a follow-up for the integrator to merge. Each fix has a behaviour test that fails on `28acbe89` and passes now (`run-fix-failing-first.txt`: 5 failures on the old implementation; `run-fix-behaviour-tests.txt`: 30 passed).

| # | Finding | Fix | Test |
|---|---|---|---|
| 1 | `_handleKeyEvent` acted on keys bubbling up from a focused descendant (Enter/Space on a nested button fired the row; Shift+F10 in a child opened the row menu) | returns `ignored` unless `node.hasPrimaryFocus` | "keys from a focused child belong to the child, not the row" (nested `TextButton`: Enter and Space run the child, row `onTap` never fires, Shift+F10 opens no menu) |
| 2 | "Show actions" was a custom action; `Semantics.onLongPress` was null with a menu | `Semantics(onLongPress: _openMenu(null), onLongPressHint: kitTappableShowActions)` when the menu is non-empty; the extra custom action is gone | "the long-press action is \"Show actions\" and opens the menu" (performs `SemanticsAction.longPress` through the semantics owner; `KitMenuPanel` opens anchored) and "each enabled item is a custom action that runs it" (exactly the items, invoked through the owner) |
| 3 | A disabled tappable with a menu still published custom actions | no menu actions or long-press hint when disabled | "disabled with a menu: no custom actions, no long-press" |
| 4 | Tree changed shape with state (DecoratedBox vs AnimatedContainer; Tooltip added/removed) and only `KitMotion.enter` | always `AnimatedContainer` (`Duration.zero` under reduced motion), curve `enter` when a fill appears or deepens and `exit` when it clears; the Focus/gesture/child subtree is under a `GlobalKey` `KeyedSubtree`, so the Tooltip wrapper coming or going reparents instead of remounting. The ring's `Positioned.fill` is now `PositionedDirectional` (R23) | "the child keeps its state across Effects Off and tooltip" (a stateful child's `initState` runs once across four toggles); the `kitMotionStillTests` samples still settle in one pump |
| 5 | Tests asserted implementation details | test 3 asserts the active cursor is `basic` via `mouseTracker.debugDeviceActiveCursor` and pixel-probes no hover fill; test 7 asserts `click`; test 8 pixel-probes a 2-px `accent` ring on both edges and the surface in the third column; Shift+F10, Menu key and the semantic long-press assert the panel sits below the widget, end-aligned (`position: null`); test 5 goes through the semantics tree | `run-fix-behaviour-tests.txt` |
| 6 | Missing `focused` at 1280×800 desktop; no G5 on interactive shots | `kit_tappable_focused_1280x800_{dark,light}` with `debugPlatformCapabilities = linuxDesktop()`; `_interactiveShot` (now also used by `menu_open`) runs `expectKitGalleryAccessible` (tap target, labelled tap target, text contrast, reading order) | `run-fix-galleries-ratchet.txt` (18 gallery tests + ratchet, all pass) |
| 7 | Light pressed == hovered | reported as contract problem 3, implementation unchanged | — |
| 8 | ARB edit outside the write set; README over-claim | contract problem 4; the "built as written" claim is corrected in §1 | — |

- New goldens (opened and looked at): `kit_tappable_focused_1280x800_{dark,light}.png` — the demo row across the full 1280 width (the interactive harness has no 720 max-width), with the 2-physical-px accent ring following the panel's rounded corners. The 16 existing PNGs re-rendered byte-identical (no change in pixels from the widget-shape fix).
- Checks: `flutter analyze` on the three changed files: no issues (`run-fix-analyze.txt`); `test/kit_ratchet_test.dart` (`run-fix-galleries-ratchet.txt`), `test/design_standard_test.dart` and `test/l10n_coverage_test.dart` (`run-fix-shared-gates.txt`) pass.
- Generated `lib/l10n/app_localizations*.dart` regenerated locally only (PROC-13), not committed.

## 7. NOT proven

- Not run on a device or emulator (coordinator work, R19/R20).
- Not exported from `lib/ui/kit/kit.dart` (integrator's job, R06) — so `test/kit_manifest_test.dart`/`test/kit_motion_test.dart`'s manifest checks do not see `KitTappable` yet, and its `kitMotionStillTests` registration is not yet cross-checked by `test/kit_motion_baseline.json`.
- No call site adopts `KitTappable` in this unit (by design, R13/R14): `KitRow`, `KitSurface`-based cards, `KitBreadcrumb` and the chat parts still build their own tap handling until their own later units migrate to it.
- No approved visual-language canvas render exists for KitTappable to diff the goldens against (EVID-12: none available).
- Contract problem 1 above (the reduced gallery/Arabic scope) is applied per the owner decision text quoted in the task; problem 2 is settled by PROC-13 convention already used by prior tier-1 units.
- The `hovered` shot's dark-theme fill is visually very close to the unhovered fill (surface1 and surface2 are close in value in the app's dark theme by design, not a rendering bug) — confirmed by the pixel-probe test, not just by eye.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitTappable` |
| Enabled | No: not exported from `kit.dart`, not adopted by any screen yet (by design, R14/R13) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `28acbe89` (merged into `feat/phone-setup-v2` as `097c9079`); review fixes `b4a57ab4` on `revamp/kit-KitTappable`, not yet merged |
| Deployed | No | |
| Released | No | |
