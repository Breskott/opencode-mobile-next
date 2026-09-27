# slice-kit24: KitSegmented stacks instead of truncating (KIT-24)

Finish line: when a segment's label does not fit on one line in its share of
the width, or text is at 2.0 or more, `KitSegmented` becomes a vertical stack of
full-width `KitChoiceRow`s. Nothing is truncated. Non-goal: no call sites
migrate, and the fine-pointer tooltip (which needs `KitTappable.tooltip`) is
out of scope.

## What changed

Only `lib/ui/kit/kit_segmented.dart` plus kit tests and goldens.

- **Fit measurement** (`_stacks`, measured the way `KitAskLine` measures): a
  `LayoutBuilder` checks, for each segment, whether the insets, check, icon,
  label and count fit in `(width - 2 hairlines) / n`. It uses the same styles
  and `TextScaler` the row draws with. If any segment misses, or the label
  scale is 2.0 or more, the part stacks. The ellipsis is gone, so the row
  form never truncates.
- **Stacked form**: one `KitChoiceRow` (radio mark) per segment, in the same
  `surface1` panel with hairline dividers that `KitChoiceList` draws. Each
  row keeps its segment's order, value and key. A count joins the title
  ("Needs you · 2"), and an icon is the row's leading glyph. A disabled
  segment shows its reason on its own row. When the whole control is
  disabled, its single reason stays under the stack.
- **Keyboard**: in both forms the group is still one Tab stop, and Tab
  enters on the selected segment. The row form uses Left and Right, which
  follow the reading direction. The stack uses Up and Down, plus Home and
  End. Arrows move focus only, skip disabled segments and never select.
  Space and Enter select. The one Tab stop is now enforced by a
  `FocusTraversalGroup` policy (`_OneStopPolicy`) instead of toggling
  `skipTraversal` on each build. Toggling left a `LayoutBuilder` frame
  callback behind after a selection change: a node-property change is
  announced after the frame, which broke the one-pump rule (G8).
- **Semantics**: the group keeps its `semanticsLabel`. Stacked rows are
  `selected` + `inMutuallyExclusiveGroup` + `enabled` with a tap action,
  through `KitChoiceRow`/`KitTappable`. The row form's semantics are
  unchanged.
- **Motion**: switching between forms is a layout change with no animation.
  Under reduced motion, one `pump()` settles after a tap in either form and
  after the host changes the value.
- Stacked keyboard also accepts Left and Right in reading order, so a
  person (or a caller's test) who learned the row form is not stranded.
- `test/kit/kit_manifest_test.dart`: removed the `_text2Pending` entry for
  KitSegmented, because the text-2.0 galleries now exist.

## Tests

Pinned Flutter 3.47.1, `flutter test --no-pub -j 1 <file>`, via
`tool/qa/machine_lock.sh`.

| File | Result |
|---|---|
| `test/text_scale_overflow_test.dart` (whole file) | **268/268 pass**, including G6 `KitSegmented/stacked-long-labels`, which fails on `feat/phone-setup-v2` |
| `test/kit/kit_segmented_test.dart` | **81/81 pass**. Run against the base part, 8 of the new stacking tests fail, as expected |
| `test/goldens/kit/kit_segmented_golden_test.dart` | 26 pass, 6 of them new baselines. `segment_disabled_dark` and `disabled_dark` fail with label anti-aliasing diffs under 1%, and fail identically on the untouched base commit. They are pre-existing, so they were not refreshed |
| gates: `kit_ratchet` 34, `redaction` 16, `ui_glossary` 21, `no_raw_error_text` 5, `kit/kit_manifest` 3, `kit/kit_draft_manifest` 25 | all pass |
| `flutter analyze lib test/kit test/goldens/kit` | clean |
| callers: `global_sessions_screen`, `appearance_picker`, `provider_quota_screen`, `review_workspace`, `common_file_preview`, `local_terminal_screen` | pass. `provider_quota_screen` at text 2.5 uses Arrow Right, so the stack also accepts Left/Right |
| caller `kit/kit_date_time_picker_test` | 2 time-picker MOT-7 failures, identical on base (pre-existing, codex-tests-d) |
| caller `kit/kit_composer_test` "200 % text at 320 dp" | **new failure: 40 px bottom overflow.** The composer's delivery choice now stacks at text 2.0 instead of cutting its labels. The fix belongs in chat-owned `lib/ui/kit/chat/kit_composer.dart` (its accessory area needs to scroll or give up room), which this slice may not edit |
| caller `mcp_setup_screen_test` "compact large-text phone" | **new failure (test only).** At 320×640 and text 2.0, the stacked "Local command" row sits under the bottom bar, and the test taps it without scrolling. The fix is to reveal the row before the tap (`await tester.ensureVisible(find.text('Local command'))`). This file is outside the slice's write set |

New tests (group `stacking (KIT-24)` in `test/kit/kit_segmented_test.dart`):
- text 2.0 stacks full-width rows with the same values;
- 320 dp long labels stack uncut, and 412 dp short labels stay one row;
- the part switches both ways as the width changes;
- a row tap calls `onChanged` once (not for the selected or a disabled row);
- row semantics;
- a disabled reason appears on its row once, and the whole-control reason
  appears once under the stack;
- a count joins the title;
- keyboard: one Tab stop, Down/Up skip a disabled row without selecting,
  Space selects, and Down works the same in RTL;
- reduced motion settles in one pump after a row tap.

Also added: the motion-still sample "the host moves the selection".

Changed expectation (TEST-19): the G6 sizing matrix now finds each label with
`find.textContaining`, because in the stacked form a count joins the row
title ("Bravo · 2").

## Images

Before and after contact sheets, dark, rendered with the gallery fonts. BEFORE
is `feat/phone-setup-v2` at `90db3565`:

- `phone_long_labels_360.png`: long labels at 360 dp. Before, "Every
  conversation o…" was cut; after, two radio rows.
- `phone_text2_360.png`: the default scene at text 2.0 on a phone.
- `phone_four_icon_count_412.png`: 4 segments with icons and counts at 412
  dp. Before, "Ne…" was cut and the "Working" label disappeared; after, a
  stack.
- `wide_long_labels_1280.png`: the same long labels on a wide window. They
  fit, so the part stays one row (unchanged).
- `wide_text2_1280.png`: text 2.0 on a wide window stacks (KitSegmented.md:
  at 2.0 the form is stacked in every window).
- `wide_four_icon_count_1280.png`: 4 segments fit on one row on a wide
  window (unchanged).

New goldens: `test/goldens/kit/kit_segmented_stacked_{dark,light}.png` and
`kit_segmented_default_text2[_1280x800]_{dark,light}.png`.

## Still needs a device

- A TalkBack pass on the stacked form (a radio row announcement inside the
  named group).
- A hardware keyboard pass (Tab, arrows, Home/End) on a tablet or ChromeOS.
- Callers that already use KitSegmented stack wherever their labels miss.
  Chat-owned callers (composer delivery, command launcher) were not edited.
  Their screens should be looked at on a narrow phone at large text.
