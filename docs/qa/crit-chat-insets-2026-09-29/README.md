# Chat insets: one gutter (2026-09-29)

Owner: "you keep another padding inside, a box inside the chat canvas again,
multiple paddings, so we're left with less space for the text." Fix: the
transcript has ONE horizontal gutter, `KitTokens.gutter` (16 dp on a phone),
applied once by the transcript list (`chat_screen.dart` `ScrollablePositionedList`
padding, already the single owner). No transcript piece adds its own outer
horizontal padding. Measured by reading the source; no device run.

## Before (dp from the screen edge to the text start, phone)

| Piece | Layers, start side | Text start | Text width (412 dp) |
|---|---|---|---|
| Reply (markdown) | list gutter 16 | 16 | 380 |
| Prompt bubble | list gutter 16 + bubble inner 16 | 32 | bubble max 380, text 348 (end gutter 16 + inner 16) |
| Step row (tool / thought) in work line | gutter 16 + hairline 1 + indent 12 | 29 | 367 |
| Reply text inside opened work group (owner shot "Step 2") | gutter 16 + hairline 1 + indent 12 | 29 | 367 |
| Opened tool detail / opened notice fold ("Instructions from the team") | gutter 16 (+ work stroke/indent 13 if in a group) + own stroke 1 + indent 12 | 29 (42 nested) | 367 (354) |
| Quote in markdown | gutter 16 + stroke 1 + indent 12 | 29 | 367 |
| Code block / table | box flush on 16, text inside box 16 (code) / 12 (cells) | 32 / 28 | box 380 |
| Team conversation rows | list gutter 16, then the same kit parts | as above | as above |
| In-transcript empty state / notices | page gutter 16 only | 16 | 380 |

## After

| Piece | Layers | Text start | Text width (412 dp) |
|---|---|---|---|
| Reply | gutter 16 | 16 | 380 (unchanged) |
| Prompt bubble | gutter 16 (end edge) + inner 12; bubble max = width - 48 | 28 from the bubble start | bubble max 332, text 308 |
| Step row in work line | gutter 16 | 16 | 380 (+13) |
| Reply text inside opened work group | gutter 16 | 16 | 380 (+13) |
| Opened tool detail / notice fold body | gutter 16 | 16 | 380 (+13, +26 nested) |
| Quote | gutter 16 + stroke 1 + gap 8 | 25 | 371 (+4) |
| Code block / table | unchanged: flush box on the gutter | box 380 | unchanged |
| Empty state / notices | gutter 16 | 16 | 380 |

Prompt note: the bubble now hugs its words up to the fixed 48 dp start inset
(before: full width, inner 16 x 12). Vertical inner is 10 dp
(`KitLayout.bubblePaddingVertical`), horizontal `space3` (12): a 4 dp gain per
side for text, at the price of the fixed 48 dp start margin the owner asked for.

## Changes

- `lib/ui/kit/kit_layout.dart`: `bubbleStartInset` (48), `bubblePaddingVertical` (10).
- `lib/ui/kit/chat/kit_message.dart`: auto bubble max = width - 48; inner padding 12/10;
  hug math follows; notice/fold opened body has no stroke and no indent.
- `lib/ui/kit/chat/kit_queued_message.dart`: same max width rule as the prompt.
- `lib/ui/kit/chat/kit_work_line.dart`: steps list has no stroke/indent (rows on the gutter).
- `lib/ui/kit/chat/kit_tool_row.dart`: opened row body has no stroke/indent.
- `lib/ui/kit/chat/kit_markdown.dart`: quote gap 12 -> 8.
- Screen level: audited `chat_screen.dart` and `chat/*.dart`; the only horizontal
  padding around transcript items is the single list gutter, so nothing to remove.
  Page-level bars (notices above the composer, empty state, team list) each apply
  the gutter once and do not nest inside the transcript list.
- Tests edited (not run): `test/kit/kit_message_test.dart` (bubble max width),
  `test/kit/kit_queued_message_test.dart` (bubble max width).

## Not done

- Code block inner padding (16) and table cell padding (12) kept: they are the box's
  own fill padding, and the box edge is flush with the text column.
- Grouping stroke of the work line removed, so steps no longer show a vertical rule;
  a device check should confirm the group still reads as one unit (the fold header).

## Device check

Reviewer watch page with a long team-instructions prompt; a worker page with many
steps and an opened step; a quote and a code block inside a reply; RTL.
