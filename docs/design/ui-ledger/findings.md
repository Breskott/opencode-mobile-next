# UI ledger: findings

Facts from the ledger that matter for a later reorganization. These are
observations with evidence, not proposals. Numbers come from
`python3 docs/design/ui-ledger/build_ledger.py --stats` at the revision in
`ledger.json`; page ids in `code` are ledger page ids (see `pages.md`).
Element counts exclude `hostWiring` duplicates (see README).

## 0. Size

- 335 pages: 79 screens, 14 tabs, 129 sheets, 51 dialogs, 48 overlays
  (embedded widgets, banners, the `system` pseudo page), 14 wizard steps.
- 1,720 interactive elements, 156 of them destructive.
- By area: chat 78 pages, settings/More 61, AI Team 50, workspace 38, servers
  32, Termux 30, shell 19, files 17, misc 6, onboarding 4.
- Tap depth from the connected shell: 16 pages at depth 0, 82 at 1, 130 at 2,
  59 at 3, 29 at 4, 2 at 5.

## 1. Duplicate entry points to the same destination

Counted as distinct UI elements whose `target` is the page (system triggers and
keyboard shortcuts listed separately).

| Destination | Entry points | Where (file:line) |
|---|---|---|
| `chat` | 40 elements on 24 pages | Workspace rows and "New session" (`workspace_screen.dart:2115`), Activity rows, global sessions, `/new` (`chat_screen.dart:4616`), command palette (`main.dart:1094`), fork actions, subagent banners, tool cards, return brief, completion digest, demo, import, plus 7 system triggers in `main.dart` (share 349, launcher 548/605, link 748, alert 1044) |
| `servers` | 15 elements on 9 pages | shell overflow "Disconnect" (`home_screen.dart:212`), settings disconnect sheet (`settings_screen.dart:134`), "Manage server profiles" (`settings/server_settings_screen.dart:271`), "Change server" x3 and "Update password/token" x4 (`saved_server_connection_card.dart:369-412`, `connection_status_banner.dart:44,72,211`), "Open Servers" (`main.dart:936`), "Connect existing server" (`termux_setup_screen.dart:2555`) |
| `model-picker-sheet` | 15 elements on 8 pages | shell overflow "Model / agent" (`home_screen.dart:195`), composer model chip, `/models` `/agents` `/variants` (`chat_screen.dart:4696-4712`), prompt-error banner, model error card (`message_view.dart:1845`), coding settings, tools screen (`tools_screen.dart:110`) |
| `termux-setup` | 11 elements on 10 pages | More (`library_screen.dart:78`), Servers (`servers_screen.dart:710`, welcome 819), connecting card "Check Termux"/"Termux setup" (`saved_server_connection_card.dart:380,446`), Server settings "Update managed OpenCode" (`server_settings_screen.dart:301`), managed health "Open setup controls" (`managed_server_health.dart:270`), team phone "Open phone setup"/"Set up" (`team_phone_section.dart:402,641`), processes (`termux_processes_screen.dart:252,522`) |
| `file-preview-sheet` | 11 elements on 7 pages | composer chips, message attachments, markdown file links, tool cards (`tool_card.dart:1821,2022,2139,2287`), context capsule, prompt editor |
| `permission-sheet` | 8 elements on 7 pages | Activity, chat attention card, completion digest, return brief, profile monitor and its inbox |
| `guide` | 6 UI elements + route `/guide` | Servers x2 (`servers_screen.dart:422,944`), profile editor (2345), More (`library_screen.dart:189`), About settings (`personal_settings_screens.dart:403`) |
| `review-workspace` | 6 elements on 5 pages | session menu "Changes" (`attention_card.dart:604`), `/diff` (`chat_screen.dart:4806`), Files "Open in Review" (`files_screen.dart:1133,1200`), changes sheet (`files_screen.dart:1667,1696`) |
| `integrations` | 6 elements on 4 pages | More "Providers" and "MCP" as two rows to the same screen in two modes (`library_screen.dart:103,117`), `/mcps` and `/connect` (`chat_screen.dart:4721,4731`), "Open providers" error action, catalog provider row |
| `terminal` | 3 UI elements + shortcut | Workspace "Terminal" (`workspace_screen.dart:1837`), More "Terminal" (`library_screen.dart:154`), `/terminal` (`chat_screen.dart:4689`), Ctrl/Cmd+` (`home_screen.dart:67`) |
| `global-sessions` | 5 elements | Workspace has three separate openers on one page (`workspace_screen.dart:496,523,1795`), folder chooser (2326), `/sessions` (`chat_screen.dart:4624`) |
| `background-settings` | 3 elements | Activity "Background updates" (`activity_screen.dart:1330`), Workspace status row (`workspace_screen.dart:1849`), Settings (`settings_screen.dart:228`) |
| `app-diagnostics` | 3 elements + route `/debug` | command palette (`main.dart:1146`), `/debug` (`chat_screen.dart:4789`), Settings > Diagnostics (`personal_settings_screens.dart:366`) |

## 2. The same action offered in several places

- **Session actions exist twice inside chat.** The session menu sheet
  (`SessionMenuSheet`, `attention_card.dart:499`, 25 rows) and the slash-command
  launcher (`chat_screen.dart:4616-4965`, 36 built-in commands) both lead to
  timeline, changes/review, context usage, skills, share, revert, fork and each
  other: 8 shared targets. The launcher additionally duplicates 3 rows of the
  More tab (`integrations`, `settings`, `terminal`). The desktop command palette
  (`main.dart:1094-1146`, 9 commands) is a third list of destinations.
- **Reasoning/timestamp display toggles** are in the session menu
  (`transcript_display_toggles.dart:75,89`) and again as `/thinking` and
  `/timestamps` (`chat_screen.dart:4884,4896`).
- **Disconnect** is in the shell overflow with no confirmation
  (`home_screen.dart:197-200`) and in Settings behind a confirm sheet that counts
  queued prompts and drafts (`settings_screen.dart:299`, sheet at 134).
- **Stop sharing** is on the chat shared-session banner
  (`message_view.dart:2385`), in the session menu (`attention_card.dart:695`), as
  `/unshare` (`chat_screen.dart:4838`) and in the Workspace row menu
  (`workspace_screen.dart:1542`); none confirms, while Share does.
- **Refresh sessions** is in the shell overflow (`home_screen.dart:208`), the
  command palette (`main.dart:1141`) and pull-to-refresh on Workspace; 28 pages
  in total carry a pull-to-refresh gesture next to 14 "Refresh" buttons.
- **Wrap lines / Scroll lines** is one persisted reader preference exposed by 6
  controls (`markdown.dart:1302,1320`, `files_screen.dart:2098`,
  `review_workspace.dart:280`, `reader_preferences.dart:66`).
- **Pin session** appears twice on the same Workspace row (menu and context
  menu, `workspace_screen.dart:1533,1579`).
- **Model selection** can be changed from 8 pages (see section 1) and the model
  list itself is rendered twice: `ModelCatalogView` (`pickers.dart:113`) is the
  body of both `model-picker-sheet` and `catalog` (More > Models & agents).

## 3. Pages reachable only through deep paths

Depth from the connected shell (tabs = 0).

- Depth 5: `external-task-cancel-sheet`, `external-task-forget-sheet`.
- Depth 4 screens: `external-task` (Servers > External agents > agent > task),
  `active-context-message` (chat > session menu > Context usage > Active context
  > message).
- Depth 3 screens: `worktrees`, `managed-workspaces`, `development-services`
  (all: Workspace > project context sheet > Manage project > row,
  `manage_project_screen.dart`), `team-run` (Workspace > AI Team card > Team home
  > run row; also by deep link `main.dart:900`), `saved-permissions` (More >
  Settings > Privacy & permissions > row, `personal_settings_screens.dart`),
  `host-management` (More > Settings > Server > row), `quota-monitor` (More >
  Settings > Remaining usage > Quota monitoring, `provider_quota_screen.dart:212`;
  otherwise only by notification `main.dart:982`), `active-context`,
  `pairing-scanner`, `add-agent`, `external-agent-detail`.
- **Reachable only through the Servers screen**: `external-agents`
  (`servers_screen.dart`, also on the welcome body), `agent-account` (server
  row menu), `attention-overview` and through it `profile-monitor`,
  `tailscale-setup`, `demo`. From the connected shell, Servers itself is reached
  by "Disconnect" (`home_screen.dart:197`) or More > Settings > Server > Manage
  server profiles (`server_settings_screen.dart:271`). `profile-monitor` has one
  more entry: the saved-servers summary embedded in Activity
  (`profile_monitor_screen.dart:147`).
- The AI Team area has a single UI entry point: the team card on Workspace
  (`workspace_screen.dart:619`, push at 856). `team-agent` and `gate-sheet` are
  additionally reachable from Activity rows (`activity_screen.dart:919`).
- `termux-storage` and `termux-processes` are reached from the "installed" state
  of Termux setup only (`termux_setup_screen.dart`, rows in
  `termux_phone_tools.dart`), plus the Workspace attention line for processes.

## 4. Orphans and dead surfaces

- `sessions-tab` (`SessionsTab`, `chat/sessions_tab.dart:7`) with its rename
  dialog and delete sheet: instantiated only in tests, 12 elements.
- `diff-sheet` (`_DiffSheet`, `chat/session_sheets.dart:111`): never constructed.
- `embedded-running-agents-strip` (`RunningAgentsStrip`,
  `widgets/running_agents_strip.dart:114`): not instantiated under `lib/`.
- `CatalogScreen._models/_providers/_agents/_modelDetails`
  (`library/catalog_screen.dart:113-439`) and `catalog-model-details-sheet`: never
  called; the live body is `ModelCatalogView`.
- Work sheet "Open session" button (`team/work_sheet.dart:399`): needs
  `onOpenSession`, which no caller of `showWorkSheet` passes.
- Termux setup "Start installed OpenCode" and "Reinstall & start" in
  `_setupChoices`: build switches to the installed view whenever an installed
  version is known, so they do not appear.
- Process details sheet "protected" branch (`termux_processes_screen.dart:252`)
  is not reachable from the list.
- Named routes `/activity` and `/requests` (`main.dart:1235-1236`) and
  `HomeScreen.initialTab` have no in-app caller.
- `ManageProjectScreen.isAvailable` always returns true, so the "Manage project"
  entry is effectively ungated.
- System-only surfaces (no UI opener, by design): `bootstrap-gate`,
  `global-shortcuts`, `command-palette-dialog`, `desktop-release-notice`,
  `shorebird-update-notice`, `share-session-failed-banner`,
  `session-link-server-missing-banner`, `chat-draft-attachment-recovery-sheet`,
  `model-picker-sheet-agent-dialog` (opened post-frame when `focusAgent`).

## 5. Settings are spread over many pages

The Settings hub (`settings_screen.dart:200-299`) has 11 category rows, but only
a minority of persisted preferences live under it. Controls that write a
persisted preference, by page:

- Under Settings: `background-settings` (`background_settings_screen.dart:78`),
  `privacy-settings` "Sync read state" (`personal_settings_screens.dart:208`),
  appearance / theme pack / language sheets (`appearance_picker.dart:207`,
  `language_picker.dart:109`), coding defaults, `provider-quota` (5 controls,
  `provider_quota_screen.dart:302-645`), `quota-monitor` (5,
  `quota_monitor_screen.dart:178-225`), usage budgets (`usage_screen.dart:268`).
- Reachable only from the Servers screen: `profile-monitor` notification rules,
  6 controls (`profile_monitor_screen.dart:371-480`).
- Inside chat: per-session approvals (`approvals_sheet.dart:84-312`), transcript
  reasoning/timestamps (`transcript_display_toggles.dart:75,89`), "Speak
  replies" (`voice_conversation.dart:442`), voice transcription language
  (`voice/voice_ui.dart:143`), model favorites and default model
  (`pickers.dart:927,1042`).
- Inside Files/Review: reader order and wrap (`files_screen.dart:838,843,2098`,
  `review_workspace.dart:280`).
- On the Servers screen: "Recover a crashed managed server"
  (`managed_server_health.dart:193`).
- In More > Plugins: command links per plugin (`plugins_screen.dart:361`).
- AI Team offers are dismissed in three places (`team_discovery_card.dart:255`,
  `team_phone_onboarding.dart:674`, `team_phone_section.dart:636`) and AI Team is
  configured under Settings > Plugins (`settings/plugins_screen.dart`).
- Notification policy is split three ways: background service (Settings),
  per-server monitor rules (Servers > attention > monitoring), quota alerts
  (Settings > Remaining usage > Quota monitoring); quiet hours are defined
  independently in `profile_monitor_screen.dart:419` and
  `quota_monitor_screen.dart:208`.
- There are two screens titled "Plugins": `PluginsScreen`
  (`plugins_screen.dart:14`, server plugin inventory, More tab, gate
  `capabilities.pluginInventory`) and `PluginsSettingsScreen`
  (`settings/plugins_screen.dart:47`, AI Team, Settings hub, gate
  `profile != null`).

### Update after UX phase 2, steps 1-3 (one Settings hub)

- More and Settings are one page, `settings` (`SettingsScreen`, the fourth
  tab): search plus eight groups. `coding-settings`, `diagnostics-settings`
  and `about-settings` are gone; their rows are hub rows.
- One Plugins page: `plugins-settings`, with sections "In this app" (AI Team)
  and "On the server" (`ServerPluginsSection`, the former `PluginsScreen`).
  The per-plugin command links therefore sit under Settings now, so the
  places holding persisted preferences drop from 6 to 5.
- "Always allowed actions" and the transcript display toggles have a hub home
  (Conversation defaults); the conversation menu flips the same stored values.
- Still open from this section: quiet hours are still defined twice
  (`profile_monitor_screen.dart`, `quota_monitor_screen.dart`) and
  `usage`, `provider-quota` and `quota-monitor` are still three pages
  (phase 2 steps 4-5).
- Pages 335 -> 325: five settings pages merged away, one sheet added, and six
  stale pages removed whose code phase 1A had deleted (`sessions-tab` and its
  two dialogs, `diff-sheet`, `embedded-running-agents-strip`,
  `catalog-model-details-sheet`).

## 6. Inconsistent labels for the same action

- Retry family: "Try again" 36 elements, "Retry" 16, "Check again" 5, "Check
  status" 4, "Refresh" 14, "Reload messages" 1 (examples:
  `run_result_screen.dart:183` "Retry", `product_states.dart` "Try again",
  `termux_setup_screen.dart:1716` "Check again",
  `managed_server_health.dart:262` "Check status").
- New conversation: "New session" (`workspace_screen.dart:2115`,
  `main.dart:1094`, `/new`), "New chat" (`sessions_tab.dart:214`,
  `run_command_dialog.dart:160`), "New task" (launcher shortcut `main.dart:548`;
  also used for external agent tasks, `external_agents_screen.dart:501`), "Start
  one" (`sessions_tab.dart:55`).
- The conversation noun varies: "session" (menus, Workspace), "chat"
  (run-command dialog), "conversation" ("Open conversation" x4, "Import
  conversation" `library_screen.dart:170`, "Find in conversation"), "task"
  (launcher, app bar "Tasks · N running" `chat_screen.dart:6474`).
- Delete family: "Delete" 14 elements and "Remove" 14 for comparable
  destructive actions (servers and worktrees are removed, sessions and messages
  deleted).
- Settings is opened by a row labelled "Settings" and by `/status — Server
  status` (`chat_screen.dart:4780`).
- The More tab is `LibraryScreen` in code, "More" in the dock
  (`home_screen.dart:165`), and its collapsed group is "Tools & help"
  (`library_screen.dart:342`); "Commands & tools" opens `CapabilitiesScreen`.
- Termux setup is labelled "Termux setup", "Check Termux", "Open phone setup",
  "Open setup controls", "Set up", "Update managed OpenCode" and "Protected ·
  open the server controls" depending on the opener (lines in section 1).
- "Cancel" is used for three different outcomes (79 elements): dismiss, abort a
  server-side operation (`integration_tiles.dart:185,598`), and return a queued
  message to the composer (`message_view.dart:2742`).
- Two hard-coded English strings bypass l10n: "Open" (`files_screen.dart:1180`)
  and "Expand" (`review_workspace.dart:2313`).

## 7. Very dense pages

Elements per page (hostWiring excluded):

| Page | Elements | File |
|---|---|---|
| `command-launcher-sheet` | 48 (36 built-in commands) | `chat/command_launcher.dart`, catalog in `chat_screen.dart:4616-4965` |
| `workspace` | 40 | `workspace_screen.dart` |
| `chat` | 35 own + 22 composer + 18 message view + 15 prompt tools + attention cards | `chat_screen.dart`, `chat/composer.dart`, `chat/message_view.dart` |
| `integrations` | 31 | `library/integrations_screen.dart`, `integration_tiles.dart` |
| `review-workspace` | 30 | `review_workspace.dart` |
| `files` | 27 | `files_screen.dart` |
| `session-menu-sheet` | 25 | `chat/attention_card.dart:499` |
| `profile-editor` | 23 | `servers_screen.dart:961` |
| `global-sessions` | 20 | `global_sessions_screen.dart` |
| `activity`, `team-agent` | 19 each | `activity_screen.dart`, `team/agent_screen.dart` |
| `servers` | 18 | `servers_screen.dart` |
| `gate-sheet` | 17 | `team/gate_sheet.dart` |

A chat session screen with its embedded composer, message view, banners and
cards exposes about 110 distinct controls, and two further lists (session menu
25, command launcher 48) are one tap away. `chat_screen.dart` is a single
7,486-line state class that opens 25 surfaces.

## 8. Gates that hide whole areas

- **Files tab**: `conn.capabilities.fileBrowsing` removes the destination
  (`home_screen.dart:119,140`); the shell then has three tabs.
- **AI Team**: everything depends on `ConnectionController.orchestration !=
  null` (`state/connection.dart:712`; built only when the profile has an
  orchestration config and is not isolated). The Workspace card is under
  `if (widget.controller.orchestration case final team?)`
  (`workspace_screen.dart:619`). 50 pages sit behind this one gate.
- **Termux / on-device**: `platformCapabilities.supportsTermux` gates the route
  (`main.dart:1242`), the More row (`library_screen.dart:78`) and the connecting
  card actions (`main.dart:1400-1416`). 30 pages.
- **More tab rows**: `capabilities.serverCatalog` hides Models & agents,
  Providers, MCP and Commands & tools together (`library_screen.dart:90-131`);
  `capabilities.pluginInventory` hides Plugins (142); `capabilities.terminal`
  hides Terminal (154, also checked by every other opener);
  `capabilities.sessionImportExport && repository is SessionImportGateway`
  hides Import conversation (170); `desktopInteractions` gates Keyboard
  shortcuts (216).
- **Workspace/project management**: `capabilities.projectManagement` gates the
  folder chooser, the interactive Projects list, worktrees, project health and
  session relations; `capabilities.managedWorkspaces` gates managed workspaces;
  `capabilities.globalSessionSearch` gates "Search all sessions".
- **Settings rows**: `platformCapabilities.supportsBackgroundService`
  (Notifications & background, `settings_screen.dart:228`),
  `controller.supportsUsageStatistics` (Usage and cost, 252), `profile != null`
  (Remaining usage 261, Plugins 288).
- **Chat**: `capabilities.sessionDiff && !isIsolated` selects Review workspace
  versus plain `DiffView`; many authoring features are off while
  `_conn.isIsolated`; `platformCapabilities.supportsVoice` gates voice.
- **Backend kind**: the profile editor shows different fields per backend
  (OpenCode, Codex, Tailscale mode; `servers_screen.dart:961` onward) and
  `agent-account` requires `capabilities.agentAccount && api is
  AgentAccountGateway`.
- **Desktop only**: global shortcuts, command palette, context-menu regions,
  file drop, desktop release notice (`desktopInteractions`).

## 9. Destructive actions without confirmation

`destructive: true` with `mutate` on a non-confirmation page:

- Shell overflow "Disconnect" (`home_screen.dart:197-200`).
- "Stop sharing" in four places (section 2).
- "Stop local server" (`termux_setup_screen.dart:1999,2235`); orphan process
  "Stop" (`termux_processes_screen.dart:513`, confirms only for non-orphans).
- MCP server "Disconnect" (`integrations_screen.dart:193`, tile at
  `integration_tiles.dart:44`).
- "Remove saved note" (`session_note_screen.dart:303`), "Discard pending photo"
  (`chat_screen.dart:7046`).
- Composer "Stop" aborts the running turn (`composer.dart:1188` ->
  `chat_screen.dart:3383`); swipe-to-archive on Workspace uses a 5 s Undo
  snackbar instead of a confirmation (`workspace_screen.dart:1448`).
