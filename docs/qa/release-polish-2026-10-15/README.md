# Release polish, 2026-10-15

Fixes for findings P2-1, P2-3 and P3-1 to P3-4 of `docs/qa/release-device-pass-2026-10-15/`.

| ID | Fix | Check |
|---|---|---|
| P2-1 | Widget timer ticks whenever a reply is running and has a start time (`WidgetV2Policy.timerTicks`), connected or not | Kotlin `WidgetV2PolicyTest` (not run here: no gradle run) |
| P2-3 | Header/list status reads "Shaping the spec · N min", then "Still shaping the spec · N min" after 2 min; the existing top menu gains "Ask again" (plan retry) beside "Stop project" | `test/team_status_words_test.dart` |
| P3-1 | This phone's installed read is ordered: an older, slower read can no longer overwrite the list after Add tools | `test/builtin/tools_agree_after_setup_test.dart` (new test) |
| P3-2 | Picker name "Conversations", real preview layout, 2x2 default, min resize 110dp, action label one line, team rows hidden when there are no conversations unless they need you | Kotlin `WidgetV2PolicyTest` |
| P3-3 | Selected badge sits in the empty middle of the tile, clear of the top pill | golden `kit_live_style_picker_default_*` |
| P3-4 | A running project with every task finished says "All N tasks complete"; "· 0 working" is dropped | `test/team_status_words_test.dart` |

Images: `before-p3-3-look-picker.png` (rel-70) and `after-p3-3-look-picker.png` (golden).
Not shown: widget picker preview (needs a device). Header minutes refresh on the next project update, not on a timer.
