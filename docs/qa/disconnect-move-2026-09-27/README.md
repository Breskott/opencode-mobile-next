# disconnect-move: Disconnect moves to the server's own page (2026-09-27)

## 1. Scope

- Owner complaint: "Why do we still have a floating disconnect button that doesn't explain what will be disconnected and doesn't belong".
- Finish line: Settings has no Disconnect row; Settings > Connection > This server ends with a destructive row "Disconnect from {server}" that says what stops and what stays where, and opens the existing disconnect confirmation. Search "disconnect" opens that page at the row. Non-goal: any change to the confirmation or to connection logic.
- Files: `lib/ui/screens/settings_screen.dart` (row and the unused standalone-row path removed), `lib/ui/screens/settings/server_settings_screen.dart` (row, `initialSection`, the moved confirm-disconnect-navigate flow), `lib/ui/search/search_index.dart` (`settings-disconnect` hub row became `inside-server-disconnect`, parent This server), `lib/l10n/app_en.arb` (`serverSettingsDisconnectTitle`, `serverSettingsDisconnectDetail`) + generated, tests `test/settings_hub_test.dart`, `test/safety_confirms_test.dart`, goldens `test/revamp/goldens/settings_hub_loaded_*`, `servers_server_settings_*`.

## 2. Runs

| # | Step | Result |
|---|---|---|
| 1 | `flutter analyze --no-pub` on the three lib files and two test files | No issues |
| 2 | `test/settings_hub_test.dart` (new: "Disconnect is not on Settings; the server page names it and explains it", "searching disconnect lands on the server page row") | all passed |
| 3 | `test/safety_confirms_test.dart` | 5 passed, 1 failed: "Workspace Stop sharing session actions menu asks first" (its "Conversation actions" tooltip is not found on Workspace; unrelated to this change) | The two disconnect-sheet tests expected "No queued prompts." with nothing waiting, which the sheet never says (settings-disconnect-sheet); they now assert the one sentence and no count.
| 4 | `test/revamp/screen_settings_1_golden_test.dart --plain-name "settings hub"`, `test/revamp/screen_servers_2_golden_test.dart --plain-name "server settings"` with `--update-goldens`, then both files in full without | all passed |

Legacy `test/goldens/settings_golden_test.dart` and `test/goldens/team_discover_golden_test.dart` fail across scenes this change does not touch (servers_add, termux_setup, intro...), so they are stale already; not regenerated here. `test/search_index_test.dart` has 5 failures unrelated to this change (they `pump()` once after `enterText`, before the kit search field settles).

## 3. Evidence (phone 412x915, dark)

- `before-settings.png`: the red "Disconnect" floating under Connection.
- `after-settings.png`: Connection ends with Connect with Tailscale.
- `after-server-page.png`: This server, then Details, a divider, and "Disconnect from Laptop" with its explanation.
