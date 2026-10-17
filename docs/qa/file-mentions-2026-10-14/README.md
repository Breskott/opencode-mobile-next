# @file mentions and a project file sheet (2026-10-14)

Emulator proof (emulator-5554, release APK build 2302, OpenCode 1.0.193 on
port 4170 reached at `http://10.0.2.2:4170`, scratch git project, own XDG dirs,
no model auth).

| File | What it shows |
| --- | --- |
| `11-at-suggestions.png` | typing `read @ser`: matching project files (name, folder) in the existing suggestion strip |
| `12-picked.png` | after a pick: text is `read @lib/server.dart `, one file chip staged |
| `13-plus-menu.png` | the + menu: "File from the project" beside Attach file |
| `14-project-sheet.png` | the project file sheet: search field and the top-level files |
| `15-sent.png` | the sent prompt with its file chip |
| `wire-user-parts.txt` | the user message as the server stored it: text part, then the file part with `source` (path and `@lib/server.dart` range 5..21); the synthetic Read output shows the server read the file |

The "agent stopped because of an error" line in the last screenshot is the
server having no model sign-in; the request itself is what is verified.
