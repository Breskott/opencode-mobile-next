# crit-connect (2026-09-29)

Analyze clean; no tests, emulator or goldens run (coordinator gates).

## Done
1. First connect lands on Work: `home_screen.dart` no longer auto-opens an empty New conversation (first run is marked landed, notify-ask stays armed). The project chooser / newest usable project logic in Work is unchanged (it already skips home folders); with no project Work shows its chooser empty state. `test/first_run_landing_test.dart` rewritten to match.
2. Work "active folder" row shows only while a conversation is running (`busySessions` not empty); copy is now "A conversation is running in this folder · {directory}" (en + ar, same key). Ledger part updated.
3. Spacing: lone status-line text action ends on the 16 dp gutter (Reset demo); diff toolbar end padding raised so the wrap button clears the edge; Work New conversation button gets an extra 8 dp above and below; KitNotice puts 8 dp between its message and its actions (Add server error).
4. Dock: labels at large text grow the dock by one step (unchanged at 1.0, stays 60 dp).
5. KitField semantics: placeholder example is now the hint when there is no helper/error (label was already the semantic label).

## Skipped
- Demo permission card at ~8 dp: it is drawn by chat files (`lib/ui/screens/chat*`), off-limits.
- "Try the demo" 48 dp target: on the Setup guide it is already a KitRow (min 48 dp); the 23 dp in the dump was the text node.
- "Home folder project eslam": no code change beyond removing the auto-created conversation (which used the server's default folder); could not reproduce the project choice without a server.

## Device check
Fresh connect lands on Work; demo Reset demo alignment; diff wrap button; Work bottom button spacing with 2.0x font; dock at 2.0x; Add server error with Save anyway button; TalkBack on a KitField.
