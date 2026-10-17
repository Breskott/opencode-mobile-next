# Chat header declutter (2026-10-14)

Owner ask: "Declutter?", micro animations where applicable, premium feel.
Built on the one-bar header (project line under the title).

## What changed
| Rule | Where |
|---|---|
| Title on one line with an ellipsis on a phone; a tap shows the full title (kit tooltip); two lines at text scale 1.3 or more | `lib/ui/kit/kit_top_bar.dart` (`_titleText`) |
| Context ring hidden under 50 % used, shown from 50 % | `chat_top_bar.dart` (`_contextRingFrom`, `accessoryShown`) |
| Collapse-all-steps only while a step is open (`_transcriptExpansion.anyOpen`) | `chat_top_bar.dart`, `KitAction.visible` |
| Parts fade in and out with their slot (150 ms, easeOutCubic, no bounce) | new `lib/ui/kit/kit_presence.dart` |
| Project line chevron turns 180 degrees while its menu is open; the server name joins the line with a fade and slide; a new title cross-fades | `kit_top_bar.dart` |
| All of the above instant under `KitMotion.reduced` | same |

Deviation from the brief: no 0.85 to 1 scale on the ring and button. Gate G21 (MOT-2)
forbids `Transform.scale` in the kit ("slide or cross-fade"), so they fade while their
slot opens along the row. The ring's percent already counts up inside `KitContextRing`.

## Images (412 dp phone, real fonts, one screen each)
- `before-4-percent.png`: header as the owner saw it (2-line title, server line, 4 % ring, collapse).
- `after-4-percent.png`: one-line title, project line, collapse button, no ring.
- `after-4-percent-no-open-steps.png`: no step open, so no collapse button either.
- `after-62-percent.png`: ring and percent back from 50 %.
- `after-ring-1-40ms.png` .. `after-ring-4-250ms.png`: the ring arriving, frame strip.

Reproduce: `SHOT_OUT=dir SHOT_AFTER=1 flutter test test/chat_header_declutter_shots_test.dart`.

## Tests
- `test/kit_top_bar_declutter_test.dart` (title lines, tap shows full title, collapse absent/fade, ring not built until shown, reduced motion, chevron, server join, title cross-fade).
- `test/chat_context_ring_test.dart` (no ring at 4 %, ring at 60 %), `test/chat_live_events/composer_errors_tests.dart` (25 % has no ring).
- `test/kit/kit_presence_test.dart` (G8x reduced-motion samples), scene in `kit_overflow_scenes.dart` (G6).
- Updated for the fade timing: `chat_shell_rows_test.dart`; for the split line text: `chat_project_chip_test.dart`.
- Goldens regenerated and looked at: `chat_one_bar_title_text2_dark` (server drops under the project at 2.0 text), `chat_project_menu_dark/light` (chevron up while the menu is open).
- Not mine: `revamp/slice_team_g17_golden_test.dart` differs only in a time-dependent sentence.
