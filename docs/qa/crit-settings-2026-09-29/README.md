# crit/settings, 2026-09-29 (critique section 1, IA)

Not run: no tests, emulator, goldens or images (coordinator gates). `flutter analyze` is clean.

## Done
1. **Plugins page retired as an entry point.** The Tools row and the `settings-category-plugins` search entry are gone. Its words ("plugins", "plugin", "Gas City", ...) now live on the `settings-ai-team` entry (which also carries the ledger page id `plugins-settings`), so search and the launcher land on AI Team. `toolsHubPluginsSubtitle` removed.
2. **One page "Notifications and background"** (`NotificationsSettingsScreen`, key `settings-category-background`, text `settingsHubGroupNotifications` now "Notifications and background"). Order: what notifies, quiet hours, saved servers, background connection, Keep running (steps, heat pause, limits), What runs by itself (Your answers, AI Team level, Always allowed actions). The Settings rows "Keep running" and "What runs by itself" are removed. `openKeepRunningScreen(context)` (app-closed notice, capability flow, This phone) now opens the merged page scrolled to `keep-running` (reads `connProvider`). Search entries `settings-keep-running` and `settings-automation` became inside-settings results of the merged page; `_arrive('keep-running')` opens the merged page. The automation "watch" door is dropped in the merged page (its switch is on the same page).
3. **Settings search field removed.** The hub keeps only the header launcher; it reads the same `searchIndex`, so every entry the field found is still found. Removed l10n: `settingsHubDetailSearching`, `librarySearchResults`, `discoverSearchInsideSettings`, `librarySearchHint`.

## Files
lib: settings_screen.dart, settings/notifications_settings_screen.dart, keep_running_screen.dart, automation_settings_screen.dart (both gained `embedded`), tools_hub_screen.dart, search/search_index.dart, domain/settings_search_catalog.dart, l10n arb + generated.
Ledger: parts/j1-settings-more.json (rebuilt ledger.json, pages.md, navigation.md).
Tests edited: settings_hub, search_index, settings_search_rows, phone_termux_discovery, first_run_settings_doors, v2_feature_gating, desktop_shortcuts, app_exit_recovery, automation_settings, settings_server_updates, tool/capture/force_stop_test.

## Skipped / decisions for the coordinator
- `PluginsSettingsScreen`, `KeepRunningScreen` and `AutomationSettingsScreen` classes still exist (standalone form) because many tests, scenes and ledger pages use them; none is reachable from the product now. Deleting them is a follow-up.
- The Plugins page's "On the server" plugin inventory (`ServerPluginsSection`) has no home now. It needs a decision (AI Team page or About > Details).
- The Conversations hub row that showed the team level as a value is gone with the row.

## Device check
Settings > This app shows one "Notifications and background" row; open it and scroll: sections in the order above, nothing twice. App-closed notice "Keep it running" opens it at the Keep running section. Header launcher: type "keep running", "always allowed", "plugins", "quiet hours", "battery".
