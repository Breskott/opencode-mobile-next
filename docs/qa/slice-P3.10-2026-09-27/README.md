# slice-P3.10 — Settings IA (2026-09-27)

**Finish line (work-units.json):** the Settings hub has the rows of target-ia §1.3. Transcript display becomes two switches. About's Privacy tab merges into Privacy and data. The voice licences go under About › Open source. Plugins and External agents move inside Tools. Import conversation moves to Work.
**Non-goal:** the setup assistant (P2.2) and the search engine (P9.4).

## What changed, per page

| Page | Before | After |
|---|---|---|
| Settings hub (`settings_screen.dart`) | 3 groups: 11 server rows, 7 phone rows, 3 help rows | 5 groups, at most 5 rows each: **server name** (This server, Saved servers, This phone once set up) · **Agent** (Model, Providers and accounts, Tools, AI Team) · **Conversations** (What runs by itself, Show reasoning, Show timestamps and usage, Default shell, Voice) · **This app** (Notifications, Keep running, Appearance, Privacy and data, Usage) · unlabelled **Help** (Setup guide, Report a problem, Available on this server, About). The wide window uses the same five groups as its index. |
| Rows the server hides | absent, with nothing said | still absent, and each group now shows one muted line: "N settings aren't available on this server · **Why**". Why opens Available on this server. Uses the new kit part `KitGroupNote`. The line is not shown while searching. |
| Transcript display sheet | a hub row that opened a sheet with two switches | removed. The two switches are hub rows (`settings-show-reasoning`, `settings-show-timestamps`) and write the same stored values the conversation menu uses. |
| Providers / Accounts | two rows | one row, **Providers and accounts**. It opens Providers, or the Codex account on Codex. `settings-accounts` stays a search entry for a server that has both. |
| MCP, Commands & tools, Plugins, External agents | four hub rows (External agents only in search, under Saved servers) | one hub row, **Tools**, which opens the new `ToolsHubScreen` (`tools_hub_screen.dart`). Its four rows are the same search entries. Rows the server cannot serve are absent and get the same muted line. `CapabilitiesScreen` is unchanged, so chat's `initialTab: 1` still works. |
| Help page (`SettingsHelpScreen`) | a hub row that opened guide, demo, capabilities, shortcuts, tips and voice notices | deleted. Setup guide and Available on this server are hub rows. Try the demo is a row on the Setup guide, shown only when the guide is not embedded in the welcome. Show tips again and Keyboard shortcuts (desktop only) moved to About. The voice licences moved to About › Open source. |
| About | two tabs: Privacy and Open source | no tabs. The order is: identity, notices, **Tips and shortcuts**, then **Open source** (all licences, the voice licences on Android, and the notices). `AboutScreen(controller:)` is optional; the `/about` route keeps working without it. |
| Privacy and data (was "Privacy and local data") | its policy row opened About at the Privacy tab | its **Privacy policy** row opens the policy in the viewer (`showPrivacyPolicy`, which uses the Arabic file when the app is in Arabic). |
| This phone | removed from the hub by R3 | comes back as a hub row only once OpenCode is set up on the phone, where it opens This phone. Before setup, "On this phone" stays a search result under Saved servers (R3: the hub holds no second Add-server door). |
| Import conversation | already in All conversations' menu, which is a Work place | unchanged. It is not on the hub. |

**Search.** Every moved row keeps its stable id. Parents were updated: Tools for `settings-mcp`, `settings-commands-tools`, `settings-category-plugins` and `settings-external-agents`; About for the tips, shortcuts and voice notices; Privacy and data for the policy; Setup guide for the demo. The switches and the shell row open the hub arrived at the row (`KitArrivalScope` + `KitArrival` on every hub row). `SearchEntry.serverGate` marks the rows the server hides, and it drives the count on the muted line. Nothing claims "font size" or "older drafts" any more.

**Ledger.** `about-privacy-tab` and `settings-transcript-display-sheet` are removed. `tools-hub` is added. The `settings`, `about` and `privacy-settings` pages are rewritten, and the ledger is rebuilt. The census shots for the two removed pages are dropped.

**Copy.** English only in `app_en.arb`. New keys: the group labels, Providers and accounts, Tools, the two switches, the unavailable line and Why, the Tools lines, Privacy policy, and Tips and shortcuts. `settingsHubPrivacyRow` is now "Privacy and data". Six keys that are no longer used were deleted.

## Deviations, stated

- **Wording of the muted line.** It says "N settings aren't available on this server" rather than "need a newer server". On Codex or Paseo no newer version adds these rows, so "newer" would be false. The Why link leads to the page with the same name.
- **Row count.** The hub has 20 rows on Android with OpenCode 1 and nothing set up on the phone, and 21 with the phone set up. The setup assistant (row 1) is P2.2's.
- **Row 9, What runs by itself.** Since the merge of feat/phone-setup-v2 (P6.1) this is P6.1's `settings-automation` row; Always allowed actions (`saved-permissions-entry`) is found inside it.
- **Default shell.** It is not yet hidden when the server offers only one shell. That needs a load before the row can decide, so it is left as it was.

## Tests

- **New:** `test/settings_hub_test.dart`, group "slice-P3.10: the Settings IA" (10 tests). They check:
  - at most 5 rows per group, none twice, 20 in total;
  - no dead aliases;
  - This phone joins once the phone is set up;
  - the switches act in place and are stored;
  - the Paseo line and Why, and no line on OpenCode 1;
  - the Tools page on OpenCode 1 and on Codex;
  - the privacy policy from Privacy and data;
  - the voice licences on About.
- **Also new:** `test/kit/kit_group_note_test.dart` (3 tests) and the kit gallery `test/goldens/kit/kit_group_note_golden_test.dart` (16 shots). `KitGroupNote` passes the G4 manifest.
- **Updated for the new IA:** settings_hub, search_index, about_alpha_notice, ios_remote_platform_gating, codex_navigation, first_run_settings_doors, settings_server_updates, team_plugin_off, usage_hub_screen and screen_system_1_golden.
- **Goldens re-recorded** because the hub or About changed:
  - `test/goldens/settings_hub_*` and `settings_about_*`;
  - `test/revamp/goldens/settings_hub_*`;
  - `test/revamp/goldens/system_about_*`.
- **Runs:** every test file that references a changed id or screen (54 files) was run. Each failure was compared with the base `441012f8` in a temporary worktree. After the fixes, **no failure is new**. The base itself fails about 270 tests in those files, mostly golden drift, chat and provider-quota tests, plus the kit_ratchet G17/G21, the design_standard golden count, G4 and the G23 harness gates. None of them names a file from this slice.
- Two cases in settings_hub_test that failed on base were corrected:
  - "battery" now expects the Keep running battery row;
  - "font" was removed, because it is a dead alias.
- **Analyzer:** `flutter analyze` is clean.

## Images (before = base `441012f8`, after = this slice)

| Shot | Before | After |
|---|---|---|
| Hub, every group, dark | `before-settings_hub_full_dark.png` | `after-settings_hub_full_dark.png` |
| Hub, every group, light | `before-settings_hub_full_light.png` | `after-settings_hub_full_light.png` |
| Hub at 200 % text | `before-settings_hub_text200_dark.png` | `after-settings_hub_text200_dark.png` |
| Hub, two panes, 1280x800 | `before-settings_hub_1280x800_dark.png` | `after-settings_hub_1280x800_dark.png` |
| Hub on Paseo (hidden rows) | `before-settings_hub_paseo_dark.png` | `after-settings_hub_paseo_dark.png` |
| About | `before-about_dark.png` | `after-about_dark.png` |
| Privacy and data | `before-privacy_dark.png` | `after-privacy_dark.png` |
| Tools (new) | — | `after-tools_dark.png`, `after-tools_light.png`, `after-tools_codex_dark.png` |

Source: `test/revamp/slice_p310_settings_ia_golden_test.dart`. The same scenes were run on the base worktree for the "before" images.

## Still needs a device

- An emulator screenshot of the hub, as the proof requires. No device was used in this slice.
- The KitArrival scroll to the switches when they are opened from the command palette.
- The privacy policy viewer on a phone in Arabic.
