# revamp-slice-R8: R8 Fields, progress row, avatar and status slot: l10n fallback, 200 % text, badge overlap, docs (2026-09-27)

## 1. Scope

- Unit: `slice-R8` (wave 3, kit-change). Finish line: KitField and KitSearchField (and KitProgressRow, KitImage) render English kit words with no localization delegates, the segments legend stacks cleanly at 2.0 text, the 4th / "Other" fills stand apart from the unfilled track, KitAvatar's error badge clears the initials, and KitStatusLineSlot documents its child, contribution lookup and priority order. Non-goal: new copy, new public API, or restyling any other state of these parts.
- Files changed: `lib/ui/kit/kit_field.dart`, `lib/ui/kit/kit_search_field.dart`, `lib/ui/kit/kit_progress_row.dart`, `lib/ui/kit/kit_image.dart`, `lib/ui/kit/kit_status_slot.dart`, `test/kit/r08_kit_fields_progress_avatar_test.dart`; goldens `test/goldens/kit/kit_image_avatar_error_{light,dark}.png`, `test/goldens/kit/kit_progress_row_segments_{light,dark}.png`, new `test/goldens/kit/kit_progress_row_segments_text2{,_1280x800}_{light,dark}.png`.
- Pages (map ids): none (kit parts only).
- Specs followed: kit-api KitField.md, KitSearchField.md, KitProgressRow.md, KitImage.md, KitStatusLine.md; LOOK-5 / STATE-9 (error is a shape and words); hairlines 1 physical px; text scale to 2.0.
- Contract problems (PROC-20): none. Token choice for the track (acceptance asks the coordinator to confirm): the segments track is now `surface1` (the panel's colour, used by no fill) inside a 1 physical px `hairline` outline; plain bars keep `surface3`. Coordinator to confirm.
- New kit parts (KIT-3): none. No public API change; every existing caller compiles unchanged (R11).
- Map items (EVID-11): n/a: no pages.
- States per part (STATE-20): fields without delegates → `r08` "English fallback without localization delegates"; segments at 2.0 text → `r08` "2.0 text: one legend entry per line, no overflow" + `kit_progress_row_segments_text2_*` goldens; segments at 1.0 wide → "1.0 text at width keeps two legend columns"; avatar error → "KitAvatar error badge does not cover the initials" + `kit_image_avatar_error_*`.
- Deferred states (STATE-21): none.
- Moved or removed items (owner rethink rule): nothing moved or removed; these are kit parts with no page items. English copy only; no new ARB keys (the fallback reuses existing `kit*` keys via `AppLocalizationsEn`).

## 2. Builds

- Branch `revamp/slice-R8`, base `b2ff0935` (revamp/leftovers), code head `c2a2a320`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 3 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/r08_kit_fields_progress_avatar_test.dart` after rebasing on `b2ff0935` | pass | 2 dark gallery goldens differed 0.07 % (R9 moved dark `text3`); looked at, regenerated; then 11 passed | PASS |
| 2 | `test/goldens/kit/kit_progress_row_golden_test.dart` + `kit_image_golden_test.dart` | R8 goldens pass | `avatar error` passes; `segments · 412x915 · dark` differed only by R9's `text3`, looked at, regenerated; unrelated failures listed below | PASS (R8 scope) |
| 3 | `test/kit/kit_progress_row_test.dart` + `test/kit/kit_image_test.dart` | pass | 58 passed, 1 failed: "KitZoom under reduced motion the reset settles after one pump", which also fails with the base `kit_image.dart` (checked) | PASS (R8 scope) |
| 4 | `flutter analyze` on the six changed Dart files | no issues | one unused test parameter fixed; no issues | PASS |

Ratchet, design-standard, l10n, kit_field/kit_search_field/kit_status_line suites were not run (owner decision 2026-09-27: own files only).

Unrelated failures seen (not caused by R8, not regenerated): `kit_image_zoom_rest_*` (light and dark, 230 px: the disabled zoom-out/reset icon colour, from another unit's KitIconButton/theme change); `kit_progress_row_stale_dark` (R9's dark `text3`); `kit_image_test.dart` "KitZoom under reduced motion the reset settles after one pump" (fails on base too).

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | l10n fallback | `test/kit/r08_kit_fields_progress_avatar_test.dart` "KitField shows its counter words", "KitField.secret shows Saved and Replace", "KitSearchField shows its result count and clear" | run 1 |
  | 200 % text | same file "2.0 text: one legend entry per line, no overflow"; goldens `kit_progress_row_segments_text2{,_1280x800}_{light,dark}.png` | run 1 |
  | distinct track | same file "the 4th and Other fills differ from the unfilled track" | run 1 |
  | badge overlap | same file "KitAvatar error badge does not cover the initials" (both sizes); golden `kit_image_avatar_error_*` | runs 1, 2 |
  | status slot docs | `lib/ui/kit/kit_status_slot.dart` KitStatusLineSlot dartdoc | n/a (docs) |

- Changed test expectations (TEST-19): none in existing test files.
- Goldens changed (each opened and looked at):
  - `kit_image_avatar_error_{light,dark}.png`: the failure badge moved from over the second initial to the circle's bottom-end diagonal, outside the initials. Approved render: none (EVID-12).
  - `kit_progress_row_segments_{light,dark}.png`: the unfilled track is the panel colour inside a hairline outline; the dim 4th/Other fills now read as filled, so the bar ends at 76 %. Approved render: none.
  - new `kit_progress_row_segments_text2_*`: 2.0 text, one legend entry per line, value labels right-aligned, no overflow, phone and 1280x800, light and dark.
- Before and after: `before-kit_image-avatar_error_dark.png` / `after-kit_image-avatar_error_dark.png`; `before-kit_progress_row-segments_light.png` / `after-kit_progress_row-segments_light.png`; `before-kit_progress_row-segments_dark.png` / `after-kit_progress_row-segments_dark.png`; `after-kit_progress_row-segments_text2_dark.png` (no before: new state).
- Accessibility: segments legend readable at 2.0 text (wraps, never clips); avatar error keeps its words "Can't show this image" and a glyph, now not covering the initials. No label or target changes.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/r08_kit_fields_progress_avatar_test.dart
$F test -j 1 test/goldens/kit/kit_progress_row_golden_test.dart --plain-name segments
$F test -j 1 test/goldens/kit/kit_image_golden_test.dart --plain-name "avatar error"
$F analyze lib/ui/kit/kit_field.dart lib/ui/kit/kit_search_field.dart lib/ui/kit/kit_progress_row.dart lib/ui/kit/kit_image.dart lib/ui/kit/kit_status_slot.dart test/kit/r08_kit_fields_progress_avatar_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- The coordinator has not yet confirmed the segments track token (`surface1` + hairline outline).
- Full suite, ratchet, design-standard and l10n gates not run (owner decision: own files only).
- Existing `kit_field_test.dart`, `kit_search_field_test.dart` and `kit_status_line_test.dart` not re-run.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/slice-R8` |
| Enabled | Yes: kit parts, no flag | |
| Verified | Tests and goldens only | runs 1-4 |
| Committed | Yes | `revamp/slice-R8` |
| Deployed | No | |
| Released | No | |
