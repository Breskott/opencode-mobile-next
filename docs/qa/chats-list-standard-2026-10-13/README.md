# Chats list to the screen standard (2026-10-13)

Branch `feat/chats-list-standard`, cut from `preview/fb-usage`, merged with `feat/type-scale`.

Shots (widgetbook web build, 412 x 915): `chats-typical-day.png`, `chats-several-connections.png`,
`chats-many-long-titles.png`, `plans-several.png`.

Row: title line, one meta line ("Needs you / Working / Failed" only when it matters, then project and time;
the agent's name first when it is not OpenCode). No preview, Git mark, context ring or pill.

Standard check (`widgetbook/test/standard_check_test.dart`) gains the `row-lines` rule (at most 2 lines of text
per kit row in the first view), with two self-tests.
