# crit team-page (2026-09-29)

Base b92cf1e7, branch crit/team-page. No tests were run (the coordinator gates); analyze is clean.

## Done
1. Team home is the work only. One status line, then one task list by urgency. A task that needs the person shows its question in its own row ("Needs you · question · age"), and the row opens the Gate sheet. The separate needs-you card is gone, and every question is a row (a question whose task is not listed is a loose row at the top). Working tasks keep their live "n of m steps done" line, and done and failed tasks come last. Give the team a task stays pinned, and the board stays in the top bar.
2. Setup left the home. The new `lib/ui/screens/team/team_settings_screen.dart` (`TeamSettingsScreen`, `openTeamSettings`) holds the agents row, spend today, host upkeep, phone controls, Change address, the Details row (speed, then the address and engine sheet) and "Turn off the AI Team". The home top bar has a "Team settings" action (`team-home-settings`); its menu is Refresh only. The row keys are unchanged.
3. Settings > AI Team is setup-only. The search entry `settings-ai-team` now uses `openTeamSetup`: Team settings while on, the intro and turn-on flow while off. The state line is unchanged ("On · This phone"). The `ai-team` search destination still opens the work page.
4. "Gas City" is not in the team screens' copy except `teamDiscoverComputerBody` (the intro's install instruction), which is left because it names the thing to install.

## Copy
Added `teamSettingsTitle`, `teamSettingsOpenTooltip` and `teamSettingsTurnOff` (en and ar). Removed the unused `teamUiTurnOff` (en and ar). Ran gen-l10n.

## Files
lib/ui/screens/team/{team_home_screen,team_page,team_settings_screen}.dart, lib/ui/search/search_index.dart, lib/l10n/*, and the tests below.

## Tests edited (not run)
team_home_test, team_page_test, team_plugins_screen_test, team_plugins_layout_test, team_phone_onboarding_test, team_home_layout_test, team_home_stable_layout_test, team_redesign_test, team_agent_screen_test, team_discover_test, revamp/slice_p52_test.
- Tests that read the agents, spend, upkeep, host, Change address, Turn off or phone rows now open Team settings first (or pump `TeamSettingsScreen`).
- The single-question tests now assert the question is the task row and that it opens the Gate sheet.

## Skipped or open
- `TeamNeedsYouCard` is no longer used on the home (test/revamp/slice_p4_1c* still build it directly). It is still used by the conversation view.
- The UI ledger parts (docs/design/ui-ledger/parts/*.json: team-home reachedFrom entries, and the new team-settings page) were not updated or rebuilt.
- slice_p34_golden_test's "menu" shot now shows only Refresh, so that golden needs a re-record.
- No "current step name" beyond the existing "n of m steps done" line.
- team_home_layout_test still has a 320 px "needs you" section that assumes multi-question rows. It should still hold.

## Device check
- The home shows only the status line and the tasks.
- A question sits inline in its task row and opens the Gate sheet.
- Team settings opens from the top bar and from Settings > AI Team when on, and Turn off returns to a sensible page.
- Settings > AI Team when off still opens the intro.
- Details still names Gas City.
