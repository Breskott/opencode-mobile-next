# revamp-screen-shell-2: Revamp shell (2 files) (2026-09-27)

## 1. Scope

- Unit: `screen-shell-2` (wave 2b, screen-revamp). Finish line: the shell (`home_screen.dart`) and the visible parts of the shortcut layer (`shortcuts.dart`: command launcher, shortcuts help) are built from kit parts only, switch layout at the KitLayout classes through KitNav, and a Project tab gated off on a server without project tools says why and offers the way back. Non-goal: the tabs' own content (Work, Inbox, Project, Settings), the notice widgets the shell hosts, the server switcher sheet, and shortcuts on Android with a hardware keyboard.
- Files changed: `lib/ui/screens/home_screen.dart`, `lib/ui/desktop/shortcuts.dart`, `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`), `test/revamp/screen_shell_2_test.dart` (new), `test/goldens/work_parts_golden_test.dart` and its PNGs, this record.
- Pages (map ids): home-shell, global-shortcuts, command-palette-dialog, shortcuts-help-dialog.
- Specs followed: STANDARDS.md §1, §15, §16; KitNav.md, KitTopBar.md (`KitTopBar.shell`, `KitShellControls`), KitScreen.md, KitSheet.md, KitSearchField.md, KitRow.md; kit-v2 §8.1, §9.1; visual-language §4–§6 (glass only on KitNav and KitShellControls).
- Contract problems (PROC-20):
  - KitUndo.md says the double-back exit hint "becomes a KitStatusLine-free transient handled by screen-shell-1", but no such transient part exists and screen-shell-1 does not own `home_screen.dart`. This unit shows it as a `KitStatus(kind: info)` in the shell's own status slot for 2 s. A higher-priority condition (connection) wins the slot, so the hint can be hidden while reconnecting; the double-back still works. Proposed: name the slot as the transient's home in KitUndo.md, or a coordinator ruling. Blocks nothing.
  - KitShellControls (kit_top_bar.dart) in its `sidebar` layout gives the server name and a `Spacer` equal flex, so a 296 dp sidebar truncates "This phone · Termux" to "This p…" (visible in `after-home-shell-sidebar.png`). Kit fix (not in this write set): drop the Spacer when `expand` or give the name `Expanded`. Blocks nothing.
- New kit parts (KIT-3): none. `AppShortcutScope` gains an optional `perform` callback and `performOf` (additive, R11); `ShortcutHelpEntry` gains an optional `group`; `matchCommands` is a new `@visibleForTesting` function.
- Map items (EVID-11):
  - home-shell statesMissing "Project tab vanishing after switching to Codex/Paseo is unexplained" → done: `test/revamp/screen_shell_2_test.dart` "the tab going away after a server switch is explained", golden `shell_home_shell_project_unavailable_{dark,light}`.
  - home-shell statesMissing "several notices at once stack with no priority" → deferred to the owners of `connection_status_banner.dart` (shared unit with `confirm_sheet.dart`) and `app_exit_notice.dart`/`thermal_notice.dart` (listed as notUi, no owner): they must produce `KitStatus` objects before the shell can put them in its one slot. The shell's slot already takes the tabs' own status lines (they now contribute to it).
  - home-shell infoMissing "a state word beside the dot while not Connected" → done: KitShellControls shows the word always ("Connected", "Reconnecting", "Offline"); test "a phone gets the dock and the glass top controls".
  - home-shell infoMissing "which project is open (the subtitle repeats the tab)" → the shell no longer repeats the tab on compact/medium (the dock names it); the project name is Work's own header. Sidebar project switcher (`KitShellControls.project`) deferred to the Work unit (no project switch callback lives in the shell).
  - home-shell actionsMissing "one place for 'what needs me'" → deferred to the Work/Inbox units (content, not shell).
  - home-shell couldBeAutomatic (banner, app-exit, thermal lines) → unchanged; owned by those widgets.
  - global-shortcuts statesMissing/actionsMissing "Android with a hardware keyboard gets no shortcuts" → deferred, no owner: enabling bindings on Android changes a tested product decision (`desktop_shortcuts_test` "no shortcut layer is installed") and needs the owner.
  - command-palette-dialog statesMissing "no match shows nothing designed" → done: `KitSearchNoMatch` with Clear search; test "no match says so and clears".
  - command-palette-dialog a11y "active row by colour alone" → done: the Enter target is a filled `KitRow(selected: true)`; test "filters as you type; Enter runs the filled first match".
  - shortcuts-help-dialog proposal fix (key column, section labels, scroll, "Find on this screen") → done: grouped Anywhere / In a conversation, mono key column at the row end, descriptions wrap to 4 lines, the sheet frame scrolls; `e7LocaleUiFindSurface` now reads "Find on this screen"; test "groups rows by where they work".
- States per page (STATE-20): home-shell: connected-work (goldens `work_*`), reconnecting (`shell_reconnecting_*`), wide sidebar (`shell_home_shell_work_1280x800_*`), project unavailable (`shell_home_shell_project_unavailable_*`), back-exit hint (test). command-palette-dialog: open (`shell_command_palette_open*`), filtered and no match (tests). shortcuts-help-dialog: open (`shell_shortcuts_help_open*`).
- Deferred states (STATE-21): shell notice priority → needs KitStatus producers, owner: notice widgets' units.

## 2. Builds

- Branch `revamp/screen-shell-2`, base `8dc27c66`, code head `f4b7a51f`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/screen_shell_2_test.dart` | passes | 12 passed (`run-behaviour.txt`) | PASS |
| 2 | `--update-goldens test/goldens/work_parts_golden_test.dart` | 20 renders, no exception | 20 passed; every PNG opened | PASS |
| 3 | `test/kit_ratchet_test.dart` (source scan) | this unit's counts drop to 0 | G1, G15, G16 for both files 0 (`-> 0` lines); the file fails G17/G21 only on base files (`quota_monitor_section.dart`, `kit_choice_list.dart`, `kit_task_card.dart`, `kit_markdown.dart`, `kit_board_lane.dart`, `kit_dialog.dart`) | PASS for this unit |
| 4 | `flutter analyze --no-pub lib test` | no issues in changed paths | 1 info in `test/goldens/kit/kit_tappable_golden_test.dart` (base, not changed here) | PASS |
| 5 | Other suites | not run (owner decision 2026-09-27) | — | n/a |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | LAY-1/LAY-5 (layout by window class) | `screen_shell_2_test.dart` "a medium window gets the rail; 760 is no longer a break", "a PC window gets the sidebar and names the tab" | `run-behaviour.txt` |
  | STATE-12 (explain a missing capability, offer enable) | "a search result for Files explains and offers the switch", "Ctrl+3 explains instead of silently landing on Work", "the tab going away after a server switch is explained" | `run-behaviour.txt` |
  | STATE-9 (state in words) | "a phone gets the dock and the glass top controls" | `run-behaviour.txt` |

- Failing-first (TEST-2): not produced (owner decision 2026-09-27: no extra test time). On the base the explanation sheet and row do not exist, so the three STATE-12 tests cannot pass there.
- Changed test expectations (TEST-19): none in shared tests (not edited; see sharedTestsBroken in the build record).
- Goldens changed (each opened and looked at):
  - `work_team_*`, `work_nudge_*`, `work_other_servers_*`: the old app bar with server name and tab subtitle is replaced by the glass server pill with its status word and a glass search button; the dock is KitNavBar. Approved render `docs/design/visual-language-2026-09-26/Main.png` and `WorkLight.png`: same top controls and dock; differences: the pill carries " · Connected" (STATE-9), Work's content is not this unit's.
  - `shell_reconnecting_*`: same change on Inbox with "Offline".
  - `shell_home_shell_work_1280x800_*` (new): sidebar with the server pill, Search field, destinations; content pane titled "Work". Approved `Desktop.png`: differences: no project switcher or pane list in the sidebar (Work unit), no pinned "New conversation" in the sidebar (Work keeps its own), the server name truncates (kit issue above).
  - `shell_home_shell_project_unavailable_*` (new): after a switch to a server without project tools, the row "Project isn't available · <server> has no project tools." with Switch server. No approved render.
  - `shell_command_palette_open{,_1280x800}_*`, `shell_shortcuts_help_open{,_1280x800}_*` (new): kit sheet (bottom on phone, centred panel on wide). No approved render.
- Before and after: `before-home-shell-work.png` / `after-home-shell-work.png`, `before-home-shell-reconnecting.png` / `after-home-shell-reconnecting.png`; after only: `after-home-shell-sidebar.png`, `after-home-shell-project-unavailable.png`, `after-command-palette-dialog-open.png`, `after-shortcuts-help-dialog-open.png` (no before render for these pages in this golden file).
- Accessibility: destinations are KitNav buttons with selected state and labels always visible; the Inbox count is KitNeedsYou's words; the server pill's label is "name, status, Switch server"; the launcher's Enter target is filled, not tinted, and rows are focusable (Arrow Down from the field); shortcut descriptions wrap instead of being cut. 200 % text not rendered in this unit.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/screen_shell_2_test.dart
$F test -j 1 test/goldens/work_parts_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart
$F analyze --no-pub lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared tests that pump the shell or the old dialogs were not run; several assert the old Material widgets and keys (listed in the build record).
- Tabs that still call `ScaffoldMessenger.showSnackBar` (Work, Settings, Files) have no `Scaffold` in the shell any more, so their snackbars do not show until those units move them to KitUndo.
- The KitScreen one-status-line debug check across the shell (banner + a tab's own line) was not exercised in every state.
- 200 % text, Arabic (dropped) and the 800x1280 medium golden were not rendered.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-shell-2` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `f4b7a51f` |
| Deployed | No | |
| Released | No | |
