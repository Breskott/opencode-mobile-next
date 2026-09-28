# slice-tap-feedback — every tap answers on the next frame (2026-09-28)

Branch `revamp/slice-tap-feedback` from `feat/phone-setup-v2` @ `b9fdd22f`.
Owner ask: "make the app feel blazing fast". Hand-off from slice-speed-ui:
kit rows and buttons waited for Flutter's tap-or-scroll timeout
(`kPressTimeout`, 100 ms) before painting a press, and a quick tap (finger
down and up between two frames) never painted one at all.

Finish line: a touch on any kit control paints its pressed state on the
next frame when nothing could turn it into a scroll; inside a scrollable a
quick tap still paints it (on release) and a drag clears it at once.
Non-goal: the glass nav's own press springs and lens (unchanged), chat-library
files (hand-off in the coordinator's lane notes), haptics (unchanged).

## What changed

One shared press layer, `KitPressTracker` (`lib/ui/kit/kit_tappable.dart`),
reads raw pointer events instead of the tap recognizer:

| Situation | Before | After |
| --- | --- | --- |
| Touch on a control with no scrollable that could take the drag (sheets, bars, dialogs, buttons outside lists), or any mouse click | Fill after 100 ms | Fill on the first frame after pointer-down |
| Quick tap anywhere (down and up in one frame) | No fill ever | Fill on the next frame, held `KitMotion.pressHold` (100 ms) |
| Touch held on a row inside a scrollable | Fill after 100 ms, eased in over 150 ms | Fill at 100 ms (platform convention, avoids flashing rows on scroll), instant |
| Drag past the touch slop / scroll starts | Cleared | Cleared at once, no hold |
| Tap won by a control inside the row (trailing icon button) or by a long-press | Row showed a fill only after 100 ms | Row clears at once; the inner control shows its own press |
| Enter / Space / screen-reader activation | No press fill | Unchanged (no press fill) |
| Reduced motion (system or Animations: Off) | Instant | Instant in and out; still settles after one pump (G8x) |

Parts on the tracker:

- **KitTappable** (so KitRow, KitSurface cards, KitBreadcrumb, KitTopBar pill
  and project row, KitTaskCard, KitChoiceList, KitChecklist, KitTabSwitcher,
  KitNav destinations, KitWorkGraph, KitDiffView, KitCodeBlock and the chat
  parts built on it). The pressed fill now appears instantly; hover still
  eases in, clearing still eases out.
- **KitIconButton**: had no pressed state at all (transparent highlight).
  Now surface3 on press (surface2 when it already shows surface3: selected,
  or hovered under a mouse).
- **KitButton** (primary, secondary, tertiary): Material's ink sparkle and
  its delayed pressed highlight are replaced by a flat state layer, the
  button's own foreground at 16 % under the label.
- **KitChip** (body and × zones), **KitSegmented** (per segment),
  **KitJumpPill**, **KitReceipt** tap target, **terminal keys**.
- New token `KitMotion.pressHold` (100 ms). Spec note in
  `docs/ux-system/kit-api/KitTappable.md` (States, Tokens, Motion).

Not converted (still Material ink or no press fill, each already answers the
tap visibly): KitMenu items (the menu closes), KitDetailsFold (it unfolds),
KitProgressRow and legacy KitPanel.onTap (ink ripple), KitDiffView's inline
InkWell. Chat kit `kit_composer_chips.dart` keeps its InkWell highlight
(chat-library file; hand-off in lane notes).

## Evidence

Next frame after a quick tap, same scene before (base `b9fdd22f`) and after,
phone 412×915 and wide 1280×800 (rows inside a scrolling list):

- `contact_before_left_after_right_412x915.png`,
  `contact_before_left_after_right_1280x800.png` (rows: row tap, Connect tap,
  reload icon tap)
- single frames: `before_*` / `after_*` `{row,button,icon}_quick_tap_{412x915,1280x800}.png`

Refreshed goldens (17 files), each `goldens/<name>__before_left_after_right.png`:

| Golden | Why it changed |
| --- | --- |
| `kit_glass_pressed_{dark,light}` | The server pill's pressed fill now shows at 90 ms (it waited 100 ms); glass swell unchanged |
| `kit_glass_lens_stretch_{dark,light}` | The tapped Settings tab shows its pressed fill for 100 ms while the lens travels (a quick tap painted nothing before) |
| `kit_glass_flow_{dark,light}` | "Add a line" (KitButton secondary) shows the flat state layer instead of Material's ink sparkle |
| `kit_date_time_picker_date_{typed,invalid}_{dark,light}` | Text caret blink phase: the press hold adds frames before the shot settles (2 px caret column only) |
| `work_project_folder_open_dialog_missing_{dark,light}{,_1280x800}` | Same caret blink phase |
| `system_run-command-dialog_run-failed_light`, `…_run-failed_1280x800_{dark,light}` | Same caret blink phase |

Also touched by this change but NOT refreshed, because they already fail on
the base commit for unrelated reasons (refreshing would bake those in):
`system_run-command-dialog_run-failed_dark` (412), `team_start_run_1280x800_{dark,light}`,
`work_development_services_editor_sheet_{dark,light}`. 548 other golden
tests in the 88 golden files that tap fail identically on base `b9fdd22f`
(stale goldens on the integration branch; same failing set and pixel counts
with and without this change).

## Tests

- New, `test/kit/kit_tappable_test.dart` group 13 (11 tests): pressed fill
  on the first frame after pointer-down; quick tap (down+up in one frame)
  shows it and one pump leaves no ticker; in a scroll view a quick tap shows
  on release and a held touch at `kPressTimeout`; a scroll drag cancels it
  (no tap, no fill left); a drag off a still row cancels with no hold;
  reduced motion instant both ways; a control inside the row that wins the
  tap leaves the row idle; Enter paints no press; KitIconButton quick tap;
  KitButton first-frame and quick-tap state layer (pixel probes).
  On base `b9fdd22f` 9 of the 11 fail (the two guards pass), after: all pass.
- Existing, all pass: kit_tappable, kit_icon_button, kit_action, kit_chip,
  kit_segmented, kit_jump_pill, kit_receipt, kit_r6_notice_receipt_task_card,
  kit_row, terminal_key_bar; gates kit_ratchet, kit_manifest,
  kit_draft_manifest, kit_motion (G8x one-pump), redaction, ui_glossary,
  no_raw_error_text. All 106 `test/kit/*_test.dart`: 17 failures, the
  identical set on base `b9fdd22f` (G8x one-pump leftovers in board lane,
  date/time picker, request sheet, KitZoom; KitAskLine colours; composer at
  200 %; terminal view "Open all"; top bar r1 sidebar and viewer r1 header
  goldens), none new.
- `flutter analyze`: clean.

## Still needs a device

- Feel on a real phone at 60/120 Hz: the 100 ms hold and the scroll-view
  wait (`kPressTimeout`) are platform conventions, not measured on the
  owner's phone.
- Glass nav: judge whether the tab's pressed fill under the moving lens reads
  well (it is what a held press already showed before; now quick taps show
  it too). If not, KitNav can opt its glass tabs out without touching the
  springs.
