# Servers, On this phone and Plugins cleanup (2026-09-24)

## Scope

The owner, on build 2051 on his phone: "Wttf is this shiit" (screenshots
`../design-regressions-2026-09-24/phone-{1,2,3}-*.jpg`, ledger rows 10–12, and row 3).
Spec: [`docs/design/phone-server-screens-cleanup-2026-09-24.md`](../../design/phone-server-screens-cleanup-2026-09-24.md),
on [`docs/design/design-standard.md`](../../design/design-standard.md) and `lib/ui/kit/`.
Behaviour stays; structure, hierarchy and words change.

### What changed, screen by screen

| Screen | Before (owner's phone, `before-*`) | After |
|---|---|---|
| **Servers** | The phone's server three times: a "Server found on this phone" card with Connect, Restart and Stop as big buttons over two rows; the saved "This device (Termux)" row with `http://127.0.0.1:4096`; an "On-device server" block with the Android caveat, the crash-recovery toggle, "Attempts used: 0 of 3", Refresh and "On this phone". The connected server not marked (ledger row 3). | **One row per server.** The phone's server is one "This phone" row: "OpenCode 2 · Running" (or Stopped, Starting, Restarting, Stopping, Checking, Not running, not answering / no Termux access). Tapping connects (starts a stopped server; opens Details for the one in use). Restart, Stop (error colour, confirmed), Details, Disconnect and Forget saved sign-in are in its menu; no buttons in rows. The saved sign-in it stands for (and Claude Code's) is not listed a second time. **Current mark**: the connected server's icon is a filled accent circle and its line starts "Connected ·" (also `selected` for screen readers). Addresses read as host[:port], no scheme. The recovery toggle, attempts and caveat moved to On this phone. Connect OpenCode 2, On this phone and More setup options stay as rows, under a hairline; Add server stays the pinned primary, Try demo under it. |
| **On this phone** (Termux) | A big "OpenCode 2" headline and "OpenCode is running on this phone. / Version 2.0.10"; big Continue to app; "Other OpenCode versions"; big Restart local server; then Update OpenCode and a red-square "Stop local server" crammed on one line; storage and running now; a large Claude Code card in the middle. | **One block in every state** (`KitStateView`, inline): "OpenCode on this phone", one line "Running · OpenCode 2 · version 2.0.10"; one primary Continue to app, one secondary Restart, then Update OpenCode and Stop **each on a line of its own** (`KitActionStack`; Stop in the error colour with the kit's stop icon, confirmed). Stopped: "OpenCode is stopped", "OpenCode 2 · version 2.0.10", Start installed OpenCode, then Reinstall & start. Failed or a half-done version switch: "OpenCode needs attention" with the same order; installing is a `KitStateView` over the live log. **Options** rows: Other OpenCode versions (unfolds), Restart after a crash (switch; the attempts and the Android caveat under it once on), Storage on this phone, Running now, and "Claude Code on this phone · Optional", which opens its own page. When the state changes the list returns to its top, so the new state and its actions are in view. |
| **Settings › Plugins** | Every server plugin a row of its internal id (`opencode.tool.input.repair`…) with "Active", "Built in" and a "Link commands" button; "Clear personal links" above the list; a two-line explanation; "AI Team · Gas City" / "Off · Add manually". | **Plain names** ("Input repair", "Worktree", "Browser", "MCP", "Wakatime"): a readable form of the id's last part (the server gives no title); the raw id only under the plugin's Details, in mono. **Built-in plugins fold into one row** "Built in · 7 active" (opens by itself when one failed to load); only plugins the person added are listed openly. State in the row: a status mark and one line ("Active", "Failed to load"). "Link commands" and the linked commands are in each row's menu, "Link commands" only when the server has commands to link; "Clear personal links" is in the section's menu, confirmed. One-line explanation. The AI Team row reads "AI Team · Off" or "On · This phone"; Gas City, its version and Add manually are on the AI Team page. |

### Kit additions (new files, exported from `kit.dart`)

| Part | File | What |
|---|---|---|
| `KitRowIcon` + `kitCurrentSpan` | `lib/ui/kit/kit_row_parts.dart` | A row's leading icon; `current: true` draws the current mark (filled accent circle). The supporting line starts with the word. |
| `KitRowMenu`, `KitMenuItem` | same | A row's trailing overflow menu; destructive items error-coloured. |
| `KitChevron`, `KitSwitchRow`, `KitExpandRow` | same | The trailing chevron; an on/off setting as a row; a row that unfolds a group or a rare choice in place. |
| `KitActionStack` | `lib/ui/kit/kit_action_stack.dart` | The §2 hierarchy with each tertiary action on its own line (Update above Stop, never side by side). |

Documented in the standard §2 and §6. `test/design_standard_test.dart` now also scans
`local_server_row.dart`, `termux_running_server_entry.dart`,
`managed_server_recovery_option.dart`, `termux_phone_tools.dart`,
`server_plugins_section.dart`, and the Plugins page classes of `plugins_screen.dart`
(the AI Team sheet in that file belongs to the AI Team redesign).

### Other files

- `lib/ui/widgets/local_server_card.dart` → `local_server_row.dart` (`LocalServerRow`): the
  shared look of the phone's OpenCode server and Claude Code, now a row. The server
  switcher shows the same rows.
- `lib/ui/widgets/managed_server_health.dart` removed (and its test and capture): the
  block it drew is gone from Servers. Its recovery part is
  `lib/ui/widgets/managed_server_recovery_option.dart`; its health readout is what On this
  phone itself shows (status, version, storage).
- `lib/ui/screens/local_agent_screen.dart`: Claude Code's own page (in the UI ledger as
  `local-agent-page`).
- Strings: 27 new keys in `app_en.arb` and `app_ar.arb`; the recovery clean-up message no
  longer sends the person to Servers.

## Builds

- Branch `ds/phone-server-screens` from `df81ce51` (feat/phone-setup-v2). Code commit
  `4ddf307e`.
- No APK built. No emulator or phone.

## Devices

None. Widget tests and rendered images only (pinned Shorebird Flutter
`91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`, on the PC).

## Runs

| # | Step | Expected | Actual |
|---|---|---|---|
| 1 | `test/phone_server_screens_test.dart` (10 behaviour tests: the phone server once on Servers; the current mark; no recovery on the list; On this phone's status line, stacked Update/Stop and Stop confirming; recovery and Claude Code as rows there; stopped offers Start first; plain plugin names with the raw id under Details; built-ins fold; actions in menus with a confirmed Clear; the AI Team row) | pass | PASS (10) |
| 2 | The same file on `df81ce51` (old code, same scenes) | every test fails | FAIL 10/10, each on the behaviour, not on compilation: `behaviour-tests-on-df81ce51.txt` |
| 3 | `test/plugin_display_name_test.dart` (id → name) | pass | PASS (2) |
| 4 | Goldens `test/goldens/phone_server_screens_golden_test.dart`: servers_phone, phone_running, phone_stopped, plugins_server × dark/light at 412×915 | match | PASS (8); `settings_golden_test.dart` servers_list updated (current mark, host addresses), termux_setup unchanged |
| 5 | `design_standard_test`, `l10n_coverage_test`, `ui_glossary_test` | pass | PASS |
| 6 | Whole suite, 398 files, `-j 3` in 8 chunks of 60–121 s each | pass | 4,820 passed, 13 skipped, 2 failed. Both failures fail the same way on `df81ce51` (not this change): `launch_shortcut_native_contract_test` (manifest shortcuts resource) and `ui_ledger_coverage_test` (screen files without a ledger entry; this branch adds `local_agent_screen.dart` to the ledger, the rest predate it) |
| 7 | `flutter analyze` | clean for the changed files | 1 info left, pre-existing (`team_finished_runs_test.dart` unnecessary import) |

### Test expectations changed because the UI changed

| Test file | Change |
|---|---|
| `termux_running_server_test.dart` | Restart, Stop and Try again are opened from the row's menu; the row says "OpenCode 1 · Stopped/Running" instead of "Server on this phone is stopped" / "Server found…"; the connected row shows "Connected · …" and the current mark; a row with nothing to put in its menu shows no menu (no empty menu). |
| `local_agent_onboarding_test.dart` | Same for Claude Code's row ("Stopped", "Running"; Restart and Stop in the menu; the menu of an installed daemon no longer has Refresh). |
| `server_switcher_test.dart` | Restart and Stop are checked in the phone row's menu. |
| `termux_setup_screen_test.dart` | "OpenCode is running on this phone." → the status line "Running · OpenCode …"; Stop and Restart found by key (labels are now "Stop", "Restart"); the restart confirm by its new key `confirm-restart-managed-opencode` (two "Restart" buttons are on screen now); the stopped state's "OpenCode 1 · version …". The recovery clean-up test now turns Restart after a crash on from this page (where it lives) instead of writing a half record into preferences behind the page's back. |
| `team_phone_onboarding_test.dart` | The running line instead of "OpenCode is running on this phone." |
| `plugins_screen_test.dart` | Link commands / Review /x from the row menu, Clear personal links from the section menu; plain name "Reviewer"; source, terminal UI and the "Your command links" note under Details. |
| `team_plugins_screen_test.dart` | Row line "Off" (not "Off · Add manually"), "Found on {server}"; see the coordinator note below. |
| `oc2_server_discovery_test.dart` | A saved phone server is reached through the "This phone" row (runtime choice and direct connect unchanged). |
| `agent_account_widget_test.dart`, `first_run_auto_test_test.dart`, `first_run_welcome_test.dart`, `server_codex_connect_flow_test.dart`, `server_profile_editor_test.dart`, `server_profile_reentry_test.dart` | A saved server's row menu is the kit's `KitRowMenu`, not `PopupMenuButton<String>`. |

### Product bugs found by the tests, fixed

- **Claude Code's own page stayed empty** in the first cut: a lazy `ListView` dropped the
  block while it was still checking (zero height), and its check never came back. The
  page is a plain scroll view now (`phone_server_screens_test` › Claude Code row).
- **A failed version switch hid its own way out**: the state block at the top said
  "needs attention" with Try again / Return, but the list kept the scroll offset from
  the versions row further down (`termux_setup_screen_test` › failed beta switch). The
  list now returns to its top when the state changes.
- **The coordinator's note** (`team_plugins_screen_test.dart:581`,
  "persists into the config"): the tap on `plugins-ai-team-row` hit nothing. The AI Team
  sheet the form was opened from was still up over the row, so the test was reading
  that sheet, not one the row opened. The test now closes it, taps the row with
  `hitTestable()`, and checks the sheet opened; no layout bug covers the row.

## Evidence

- `before-N-*.png` / `after-N-*.png`: the same state rendered by
  `tool/capture/phone_server_screens_test.dart` (scenes in
  `test/support/phone_server_scenes.dart`) on `df81ce51` and on `4ddf307e`, 412×915,
  dark, real fonts: 1 Servers (OpenCode 2 running in Termux, connected to a remote
  server), 2 On this phone running, 3 On this phone stopped, 4 Plugins (seven built in,
  one added, AI Team off); `-scrolled` is the page under the fold, `after-4-…-open` the
  built-ins unfolded. `before-1` and `before-2` match the owner's screenshots.
- `behaviour-tests-on-df81ce51.txt`: run 2.
- `test/goldens/{servers_phone,phone_running,phone_stopped,plugins_server}_{dark,light}.png`
  and the updated `servers_list_*`.

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test -j 3 test/phone_server_screens_test.dart test/plugin_display_name_test.dart \
  test/goldens/phone_server_screens_golden_test.dart test/goldens/settings_golden_test.dart \
  test/design_standard_test.dart test/termux_running_server_test.dart \
  test/termux_setup_screen_test.dart test/plugins_screen_test.dart \
  test/team_plugins_screen_test.dart test/local_agent_onboarding_test.dart \
  test/server_switcher_test.dart test/l10n_coverage_test.dart test/ui_glossary_test.dart
# Renders (after):
$F test --concurrency=1 tool/capture/phone_server_screens_test.dart
# Renders and the behaviour tests on the old code:
mkdir /tmp/old && git archive df81ce51 | tar -x -C /tmp/old
cp test/support/phone_server_scenes.dart /tmp/old/test/support/
cp tool/capture/phone_server_screens_test.dart /tmp/old/tool/capture/
cp test/phone_server_screens_test.dart /tmp/old/test/
(cd /tmp/old && $F pub get && $F test --concurrency=1 \
  --dart-define=PHONE_SERVER_CAPTURE=before tool/capture/phone_server_screens_test.dart \
  && $F test test/phone_server_screens_test.dart)
# Goldens, deliberately:
$F test --update-goldens test/goldens/phone_server_screens_golden_test.dart
```

## NOT proven

- Not viewed on a device: no emulator or phone run, no APK. The owner's build 2051 has
  not seen this.
- Renders and goldens are English at 1× text; large text (320 dp, 2.5×) and RTL are
  covered by the existing layout tests of the rows (no overflow), not by new images.
- The Termux answers in the scenes are synthetic (status, storage, processes); the
  Claude Code block and the AI Team on-phone block are not in the scenes.
- Not changed: the in-app server's "This phone" card (`PhoneServerCard`, phone setup
  v2 screen D) is still a card on Servers when that server exists; the server switcher
  still lists the saved phone sign-in under "Saved servers" beside the phone row; the
  UI ledger's older entries for the removed "On-device server" block are not rewritten.
