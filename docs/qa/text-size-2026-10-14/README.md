# Text size and top bar over the live background (2026-10-14)

## What changed
- **Text size** (Settings > Appearance > Display): Smallest 0.85, Small 0.92,
  Default 1.0, Large 1.15. It multiplies the phone's own font scale, is applied
  once at the app root (`KitText.appScale` in `lib/main.dart`), is capped by the
  existing `AppTheme.maxTextScale`, is stored per device as `oc.textSize`, and
  eases in over 250 ms (instant when the phone's "remove animations" is on).
  Touch targets are unchanged: the segments stay at least 48 dp tall.
- **Top bar**: `KitTopBar` no longer paints a ground colour, so the page's live
  background runs up behind the title instead of ending in a flat band.

## Tests (fail without the change)
- `test/text_size_test.dart`: default and restart persistence, the scale
  multiplies the phone's 1.2 to 1.02 and eases to 1.38, the runaway cap still
  wins, Settings picker saves and keeps 48 dp targets, and Chats home,
  Settings and This phone pump at Smallest with no overflow.
- `test/kit/kit_top_bar_transparent_test.dart`: no opaque ground inside the bar
  (fails with the old bar).
- Goldens regenerated and looked at: `settings_appearance_*` (new Text size row).

## Images (phone size, one screen each; `tool/capture/text_size_capture_test.dart`)
Default, then Smallest: `chats-*`, `settings-*`, `appearance-*`, `this-phone-*`.
Top bar: `top-bar-before.png` (flat band) and `top-bar-after.png` (light rays
run behind the title, bold intensity).

## Known unrelated golden failures at this base
`team_run_merged_*` and `library2_external_task_draft_*` fail with identical
pixel counts with and without this change.
