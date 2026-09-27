# revamp-screen-terminal-1: Revamp terminal (3 files) (2026-09-27)

## 1. Scope

- Unit: `screen-terminal-1` (wave 2b, screen-revamp). Finish line: the three files are built only from kit parts (G1, G2, G7, G16, G17 and G21 at zero), each of the five pages follows its map proposal with the wave-2 missing states and actions, and the look is the visual language. Non-goal: no gateway call, controller field or persistence added (so no terminal age, no font size, no restart-the-same-command).
- Files changed: `lib/ui/screens/terminal_screen.dart`, `lib/ui/screens/local_terminal_screen.dart`, `lib/ui/screens/settings/default_shell_row.dart`, `lib/l10n/app_en.arb` (42 new keys, English only per the owner decision of 2026-09-27), `test/local_terminal_screen_test.dart`, `test/terminal_accessibility_test.dart`, new `test/revamp/screen_terminal_1_test.dart`, `test/revamp/screen_terminal_1_golden_test.dart`, `test/revamp/screen_terminal_1_fixtures.dart`, 26 goldens in `test/revamp/goldens/terminal_*`.
- Pages (map ids): `terminal`, `terminal-surface`, `terminal-remove-sheet`, `terminal-rename-dialog`, `coding-settings-shell-sheet`.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-8, KIT-11, KIT-15, KIT-22, KIT-23, KIT-25, KIT-26, KIT-27, KIT-28, KIT-33, KIT-34, KIT-35, KIT-36, STATE-5, STATE-12, DATA-11, MAP-1, COPY-8; kit-v2 §9.1; visual-language §5 (rows, one list, menus), §6 (no glass here).
- Contract problems (PROC-20): none blocking. One note: the unit brief says write `app_ar.arb` too (R04), the owner decision of 2026-09-27 drops Arabic; the later owner decision was followed (§0.2).
- New kit parts (KIT-3): none.
- Moved or removed (owner rule "rethink, not just restyle"):
  - Terminal page: accessible mode, reconnect, rename, stop moved from three unlabeled bar icons into the overflow menu, each named ("Rename build-server", "Stop build-server"); Copy stays in the bar as "Copy output". The always-on "Connected - PID 4821" line was removed; the PID moved to "Terminal details" with the command and folder.
  - Terminal page: the hand-built `Ctrl-C … →` strip was replaced by the kit key bar (the one phone terminals already use), led by ^C and ^D.
  - Terminal list: the per-row ⋮ button was removed (KIT-28); its items live in the row's long-press/right-click menu. The FAB became the KitScreen bottom primary "New terminal", shown only when the list has rows (the empty state carries its own). The Running/Exited chip moved into the row's supporting line as words.
  - Terminal list: the "Report a bug" tertiary stays only on the load-failure state.
  - Default shell: the header ListTile that looked like a first option is gone (the sheet title and subtitle say it); the "Default shell updated" snackbar was removed (the row names the new shell).
  - This phone's terminal: "Set up" became "Set up Linux on this phone"; "Paste" became "Paste into Shell 1"; the stop question names the shell.
- Map items (EVID-11):
  - terminal: statesMissing "server not answering >8 s" → done: `terminal-loading` KitStateView with `since` + Try again (code), list-failed state (golden `terminal_list_*`, test "one list, running first"); "exited with code in words" → done: row line "Ended · code 1 · flutter" (test "one list, running first, each state in words"); "phone chosen but Ubuntu missing -> install" → done: golden `terminal_phone_not_set_up_*`, test "a server with no terminals says why and offers this phone". actionsMissing "restart an exited command" → deferred: no owner (the gateway's `createTerminal` takes only a title, so the original command cannot be re-run without a gateway change, which wave 2 forbids); "remove all exited" → done: test "removing the ended terminals asks once, keeps running ones". couldBeAutomatic "pick the only available source silently" → done (off Android there is no choice: existing test "off Android there is no choice, only the server"). infoMissing "state and age" → state done, age deferred: no owner (no start time in `TerminalProcess`); "folder" → done in Terminal details (test "details hold the command, folder and process id").
  - terminal-surface: statesMissing "process exited (restart/remove here)" → done: closed line with Reconnect and Stop/Remove in the page menu (golden `terminal_surface_closed_*`, test "a closed connection says so with Reconnect"); "reconnecting status line instead of PID" → done (test "connected: no status line; the menu names the terminal"). actionsMissing "rename / stop from here" → done (tests "a rename here renames the page at once", golden `terminal_surface_menu_*`); "paste" → done (menu "Paste into build-server"); "font size" → deferred: no owner (needs a stored preference; the kit terminal already scales with the system text size up to 2x). couldBeAutomatic "hide when connected; reconnect automatically on resume" → done (no line when connected; resume reconnects: test "terminal lifecycle closes once and resumes with one replacement channel").
  - terminal-remove-sheet: statesMissing "stop failed" → done: test "a stop that fails keeps the question open with the reason" (kit `kit-confirm-failed` notice + Try again). infoMissing "terminal name", "whether output is kept" → done: "Stop build-server?" + "Its output can't be brought back." (golden `terminal_remove_sheet_*`). actionsMissing "undo remove: impossible, say so" → done (same body line).
  - terminal-rename-dialog (keep): KitInputDialog, label "Name" (golden `terminal_rename_dialog_*`); statesMissing "rename failed" → done: test "a rename that fails stays in the dialog with the name kept". couldBeAutomatic: already automatic (the name comes from the numbering).
  - coding-settings-shell-sheet: statesMissing "save failure inline" → done: test "choosing a shell saves it; a failed save shows in the row". couldBeAutomatic "with one shell, show the row read-only" → done: test "one shell: the row says so and opens nothing". infoMissing "what Automatic resolves to" → deferred: no owner (the server does not report it).
- States per page (STATE-20): terminal: loading (code, `since`), empty (golden `terminal_empty_*`), error (list-failed state, code), refresh-failed notice (`test/library_refresh_test.dart`), loaded (golden `terminal_list_*`), unavailable (golden `terminal_unavailable_*`); terminal-surface: connected (golden `terminal_surface_*`), connecting (loading bar; line after 8 s), paused, closed (golden `terminal_surface_closed_*`), failed, readable text (`test/terminal_accessibility_test.dart`); local terminal: not set up, starting, failed, ended (`test/local_terminal_screen_test.dart`).
- Deferred states (STATE-21): terminal age → needs a start time from the server, no owner.

## 2. Builds

- Branch `revamp/screen-terminal-1`, base `9007257d` (feat/phone-setup-v2 when the branch was cut), code head `6b2903df`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/screen_terminal_1_test.dart` (13 behaviour tests) | passes | 13 passed | PASS |
| 2 | `test/revamp/screen_terminal_1_golden_test.dart` (26 goldens, regenerated and looked at) | passes | 26 passed | PASS |
| 3 | Owned tests: `test/local_terminal_screen_test.dart`, `test/terminal_accessibility_test.dart`, `test/terminal_input_queue_test.dart`, `test/library_refresh_test.dart` | pass | 38 passed | PASS |
| 4 | `test/kit_ratchet_test.dart` with `KIT_RATCHET_WRITE=1`, baseline inspected then restored (never staged) | no entry left for the three files | none left in G1, G2, G7, G16, G17, G21 | PASS |
| 5 | `flutter analyze --no-pub lib test` | no errors; no issues in changed paths | 5 infos, all pre-existing in other units' files (`test/revamp/screen_shell_1_test.dart`, …) | PASS |

Steps 1–3 in one run: `tests.txt` (77 passed). Step 5: `analyze.txt`.

## 5. Evidence

- `tests.txt`: the run of steps 1–3; `analyze.txt`: step 5.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-28, COPY-8 | `test/revamp/screen_terminal_1_test.dart` "the row menu names the terminal it acts on" | `tests.txt` |
  | DATA-11 (confirm; failure stays) | "a stop that fails keeps the question open with the reason" | `tests.txt` |
  | KIT-11 (input dialog; failure under field) | "a rename that fails stays in the dialog with the name kept" | `tests.txt` |
  | STATE-12 (explain + offer) | "a server with no terminals says why and offers this phone" | `tests.txt` |
  | KIT-35 (one line, only when not connected) | "connected: no status line; the menu names the terminal"; `test/terminal_accessibility_test.dart` "closed terminal disables writes and announces why" | `tests.txt` |
  | KIT-33 (details fold) | "details hold the command, folder and process id" | `tests.txt` |
  | KIT-25 (choice sheet, single shell read-only) | "one shell: the row says so and opens nothing" | `tests.txt` |
  | LAY-9 (48 dp keys) | `test/terminal_accessibility_test.dart` "terminal keys keep 48dp targets on phones" | `tests.txt` |

- Changed test expectations (TEST-19):
  - `test/terminal_accessibility_test.dart`: accessible mode and reconnect are opened from the page menu (were bar icons); the `Ctrl-C` OutlinedButton strip checks became kit key bar checks (`TerminalKeyBar.enabled`, `terminal-key-interrupt`); "Connected - PID 42" became "no status line" (PID moved to details); "Unavailable" became the reason text; the accessible input is found as the TextField inside KitField; the paused line is asserted on the next drawn frame (`scheduleForcedFrame`, frames are off while the app is away); the transcript assertions pump one more frame. KIT-35, map terminal-surface proposal.
  - `test/local_terminal_screen_test.dart`: the cost line's key is now the status slot's `kit-status-local-terminal-cost` (KIT-35).
- Goldens changed (each opened and looked at; all new): `test/revamp/goldens/terminal_{list,list_1280x800,empty,row_menu,remove_sheet,rename_dialog,unavailable,phone_not_set_up,surface,surface_1280x800,surface_closed,surface_menu,shell_sheet}_{dark,light}.png`. Approved renders: `docs/design/visual-language-2026-09-26/Main.png` (lists: grouped surface1 panel, icon tiles, muted second line — matches), `Confirm.png` (the stop sheet: danger icon tile, question title, danger-filled confirm, "Keep running" — matches), `Settings.png` (the shell sheet rows — matches, except the choice mark is the kit's radio, which is KitChoiceList's own choice).
- Before and after (EVID-10): `before-terminal-populated.png` → `after-terminal-populated.png`, `before-terminal-empty.png` → `after-terminal-empty.png`, `before-terminal-remove-sheet-stop.png` → `after-terminal-remove-sheet-stop.png`, `before-terminal-rename-dialog.png` → `after-terminal-rename-dialog.png`, `before-terminal-surface-connected.png` → `after-terminal-surface-connected.png`, `before-coding-settings-shell-sheet.png` → `after-coding-settings-shell-sheet.png`; `after-terminal-unavailable.png` (no before render: the page was hidden).
- Accessibility: every icon-only control is a KitIconButton with a label (Copy output, the overflow); the readable-text mode keeps its labelled command field (KitField mono, left to right) and send button whose name says why it is disabled; every key of the kit key bar is 48 dp with its full name as its semantics; row menus are semantic custom actions (KitRow); the readable mode is now named "Show as readable text" instead of an accessibility figure. 200 % text was not checked in this unit.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed. Copy goes through KitCopy (redacts known secrets).
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/revamp/screen_terminal_1_test.dart test/revamp/screen_terminal_1_golden_test.dart
$F test -j 1 test/local_terminal_screen_test.dart test/terminal_accessibility_test.dart test/terminal_input_queue_test.dart test/library_refresh_test.dart
$F analyze --no-pub lib test
```

## 7. NOT proven

- Not run on a device or emulator; no live OpenCode server terminal was opened.
- Shared tests not run (owner decision 2026-09-27); likely broken and left to the integrator: `test/product_ui_regression_test.dart` (terminal cases use the old bar icons, `Ctrl-C` text and the FAB), `test/motion_adopt_test.dart` (finds the refresh MaterialBanner, now a KitNotice), `test/settings_server_updates_test.dart` (expects the "Default shell updated" snackbar and a `BottomSheet`), possibly `test/motion_states_test.dart` (Terminal group's drawn scenes).
- `test/design_standard_test.dart` `_migrated` entries for the three files and `docs/design/ui-ledger` parts were not written (shared files the unit never stages).
- The openers that hide the terminal when a server lacks it (`home_screen.dart`, `project_hub_screen.dart`, `chat_screen.dart`) are outside the write set; the page explains the gate when reached, but those entry points still hide it. `chat_screen.dart:5702` pushes `TerminalScreen` bare; the screen now draws its own top bar there, but the chat should push `TerminalPage`.
- 200 % text and the landscape-with-keyboard layout of the server terminal page were not rendered.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-terminal-1` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `6b2903df` |
| Deployed | No | |
| Released | No | |
