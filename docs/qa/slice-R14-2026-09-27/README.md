# slice-R14 — Shell and shared widgets (2026-09-27)

Definition: `docs/ux-system/revamp/leftover-units.json`, id `slice-R14`.

## What changed

| Where | Change |
|---|---|
| `lib/ui/screens/home_screen.dart` | PC sidebar layouts pass no top bar: the `KitTopBar(title: <tab>)` that repeated the highlighted sidebar destination is gone. The pane starts with the destination's own header (the project on Work), as in `docs/design/visual-language-2026-09-26/Desktop.png`. Compact and medium keep the glass shell controls. |
| `lib/ui/screens/home_screen.dart` | `OpenTerminalIntent` (Ctrl+`) always opens the Terminal page. On a server without terminals the page explains why (`terminal-unavailable`), where the shortcut used to do nothing. |
| `lib/ui/kit/kit_screen.dart` (+ `docs/ux-system/kit-api/KitScreen.md`) | New `KitScreen(page: true)`: the page frame (ground, top safe area, keyboard lift, snack bar host) with no bar. The PC content pane uses it, so leaving out the bar loses none of the frame. It is additive, and every other caller is unchanged. |
| `lib/ui/screens/session_export_screen.dart` | The private `_SectionLabel` is replaced by `KitSectionLabel` (margin zero inside the padded list; the section gap now comes from the label). |
| `lib/ui/widgets/safety_confirms.dart` | The unused `confirmStopProcess` is deleted. |
| `lib/ui/widgets/work_status_line.dart` | `WorkRunawayNotice` has one action, "Stop {helper}" (e.g. "Stop node"). `stopRunawayHelper` asks with `showKitConfirm` (stop kind, "can't be started again" consequence), stops exactly that pid with `TermuxProcesses.stopPid`, and announces the result once ("Stopped node" / "Couldn't stop node. Try again, or stop it from Termux."). "See what's running" is removed; Running on this phone is still reachable from This phone. |
| `lib/ui/widgets/termux_phone_tools.dart` | The watcher passes the process name and pid. It hides the line at once after a stop that worked, and keeps it in the failure tone, with the same Stop, after one that failed. Has a `stop` test seam. |
| `lib/ui/widgets/phone_server_card.dart` | New `PhoneServerCard.row(...)`: a `KitRow` for a caller's `KitRowGroup`. Its line reads "Connected · OpenCode 1.18.29 · Running", Start or Set up is the trailing button (under the line at large text), Continue setup and Show progress sit under the line, and everything else stays in the row menu. The card itself is unchanged; R15 moves Servers onto the row. |
| `lib/l10n/app_en.arb` | + `workRunawayStopped`, `workRunawayStopFailed`. The now-unused `workRunawaySee`, `termuxProcsStop` and `termuxProcsKeep` are deleted, from `app_ar.arb` too. gen-l10n was rerun. |

Not done here (the file is owned by another agent right now):
- `lib/ui/widgets/product_states.dart` `SectionLabel` → forward to `KitSectionLabel` with `/// Retired: use KitSectionLabel`. The file belongs to kit-hygiene; this is left for them or the coordinator.
- `lib/ui/screens/terminal_screen.dart:85` still uses `'flag:fileBrowsing+terminal'` for its unavailable state. The registry now has the terminal-only `'flag:terminal'` (R10), and swapping it is a one-line change in R18's file.

## Images

- `pc-work-before-dark.png` / `pc-work-after-dark.png` show the 1280×800 PC shell on Work. The repeated "Work" bar is gone, and the pane starts with the project header.
- `phone-runaway-before-dark.png` / `phone-runaway-after-dark.png` show the Work status line: "See what's running" becomes "Stop node".
- `servers-phone-row-{stopped,notsetup,running}-{phone,wide}.png` show the new row variant inside a list group, at 400 dp and 1280 dp. This variant is new, so it has no "before" image.

## Tests

New:
- `test/work_tab_status_line_test.dart`: Stop asks first and Keep changes nothing. Confirming stops exactly pid 4242, hides the line and announces "Stopped node" once. A failed stop keeps the line with plain words (no raw bridge text), the same Stop, and one announcement.
- `test/revamp/screen_shell_2_test.dart`:
  - The PC pane has no top bar, "Work" is said once, and the project header is the pane's first thing.
  - Ctrl+` on a server without terminals opens the Terminal page with its explanation. Checked to fail with the old `when capabilities.terminal` guard.
  - The existing PC test now reads the selected sidebar destination instead of `current-tab-title`.
- `test/phone_server_card_test.dart`, row variant: Start is trailing on the row's line and starts the server; Set up is trailing and the rest is in the menu; running and connected has no button and Stop is in the menu; at 320 dp and 2.5× text Start moves under the line with no overflow.

Run once: the slice's listed tests, `kit_ratchet_test`, `ui_glossary_test`, `termux_processes_test`, the shell test files (home_navigation, codex_navigation, first_run_landing, project_hub, desktop_shortcuts, screen_shell_2), `work_tab_cleanup_test`, `shared_phone_1_test`, `kit/kit_screen_test` and the affected golden files. Every failure that remains also fails on the base commit 0a579ea6, checked in a temporary base worktree: stale `current-tab-title` and phone-size expectations in home/codex/first-run/project-hub/desktop-shortcut tests; safety_confirms (3); servers_scenes goldens (5); kit_ratchet G17/G21; ui_glossary (4); work_tab_cleanup (6). `flutter analyze` is clean.

Goldens: both worktrees were regenerated and compared. Only images that differ from the base's own regeneration were kept:
- `shell_home_shell_work_1280x800`
- `shell_command_palette_open_1280x800`
- `shell_shortcuts_help_open_1280x800`
- `work_runaway`
- `p66a_work_project_1280x800`
- `work_workspace_loaded_1280x800`

All are dark and light, and all come from the PC pane without its bar or the Stop label. The stale goldens from earlier merges were left alone, and the time-dependent team_home images were reverted.

## Still needs a device

- A real Termux leftover process: Stop ends it via `procs-stop` and TalkBack reads the one announcement.
- A tablet in landscape (expanded) confirms the bar-less pane still clears the status bar (SafeArea through `KitScreen(page: true)`).
