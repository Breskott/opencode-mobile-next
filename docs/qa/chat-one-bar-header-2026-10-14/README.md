# Chat header as one bar (2026-10-14)

Branch `feat/chat-one-bar-header` (proposal, not merged).

Change: the project chip and the server line under the chat title become one
quiet, tappable line: folder glyph, project name, ` · <server>` only when 2+
connections are live, and a small chevron. It opens the same menu the chip did
(Files, Terminal, Changes). The line is at least 48dp tall, wraps instead of
pushing the title above the back arrow, and reads "Project X on Y. Opens a menu
..." to a screen reader. Back arrow, top-bar actions and the ⋯ are unchanged.
Without a project line (temporary folder, watching a worker) the server name
still shows as the old subtitle, so no state loses it.

Images (one phone screen each; goldens, so the font is the test font where noted):
- `before-normal.png` / `after-normal.png`: real-font golden, one server. The chip pill becomes the quiet line.
- `before-menu.png` / `after-menu.png`: the menu opened from it.
- `after-two-servers.png`: two servers (test font blocks); one line carries project and server.
- `after-text-2x.png`: text size 2.0 with a back arrow (test font blocks); the title sits beside the arrow, wrapping to two lines, with the line below.

Tests: `test/chat_project_chip_test.dart` (project alone with one server, server
added with two, same menu opens, 48dp, text 2.0 back-arrow placement),
`test/kit/kit_top_bar_large_text_test.dart`. 46 chat goldens regenerated; each
differs only in the header.
