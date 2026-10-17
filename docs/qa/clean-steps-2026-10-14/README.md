# Clean work steps and flat inline diff (2026-10-14)

Catalog use-cases (Chats > Work steps, Chats > KitDiffView), headless 412 x 915, widgetbook web build served on 127.0.0.1:8767 (server stopped by PID).

| Shot | What it shows |
| --- | --- |
| `0-closed.png` | the group line, closed |
| `1-open-one-running.png` | "Ran 2 commands" open; one line per step on one rail, the running step's node is the small spinner |
| `2-open-command.png` | an open command: one box at the text x, `$` and the whole command wrapped, first 6 output lines, outcome, "Show all 14 lines", copy icon top-right |
| `3-inline-edit-diff.png` | an edit step opened: the step line says "Edit checkout_test.dart +3 -1"; no file header, fold row and lines sit on the page |
| `4-full-diff-header.png` | the full diff view: the pinned header is the page ground with a hairline |

Wrap lines for the inline diff is on the step line's long-press (right-click) menu.

Checks run: kit_clean_steps_test, kit_clean_steps_open_test, timeline, tool row, work line, diff view, tool card, diff page, transcript placement, review workspace, permission sheet, team conversation, G16 ratchet, plus the 8 affected golden files regenerated, widgetbook standard check (baseline gained only the two new use-cases' by-design findings), flutter analyze clean.
Not mine and failing on the base: kit_manifest_test (KitProjectFileList, KitTaskChip, KitWindowRow) and kit_ratchet G17 (about_you_screen amber).
