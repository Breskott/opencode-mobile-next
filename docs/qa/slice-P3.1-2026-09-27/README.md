# slice-P3.1 Delete dead weight (2026-09-27)

- Unit: `slice-P3.1` (wave 3, programme P3). Branch `revamp/slice-P3.1`, base `e1ccfc42` (feat/phone-setup-v2).
- Finish line: the info label and its sheet become a tooltip on the term. context-capsule, the plugin command links (dialog and clear sheet), the session inventory footer, the Work team card and the appearance picker sheet are gone, and each job lands where target-ia §1.4 says.
- Non-goal: no new features.
- Result: done for six of the seven pages; **context-capsule is blocked** (see §2).

## 1. What changed, per page

| Map page | Before | After (target-ia §1.4) |
|---|---|---|
| `embedded-info-label`, `info-label-sheet` | `lib/ui/widgets/info_label.dart`: an `InfoLabel` wrapper over `KitTerm` plus an English-only `Glossary` table | File deleted. Worktrees uses `KitTerm` with `e7GlossaryWorktreeExplanation`; MCP setup's "What is MCP?" calls `showKitTerm` with `libraryMcpTitle` / `e7GlossaryMcpExplanation` (it used to show the hard-coded English "every session" text). The term is a 48 dp button with a label and hint for screen readers (`KitTerm`). |
| `plugins-mapping-dialog`, `plugins-clear-mappings-sheet` | Plugin row menu "Link commands" (AlertDialog of checkboxes), "Review /cmd" items, page menu "Clear personal command links" (confirm sheet), store `lib/state/plugin_command_mappings.dart` | All removed with the store. A plugin row is one tap to its details (chevron, no menu); the details are a kit sheet with status, source and the id in a `KitDetailsFold`. A plugin's commands are run from the command sheet (the per-backend catalog). Old stored links stay under `oc.pluginCommandMappings.<profileId>` and are swept by the existing profile deletion (`profileScopedPreferenceKeys` matches the pattern); nothing reads them. |
| `embedded-session-inventory-footer` | "Load more conversations" / "Refresh" buttons and the raw error text under Work's list and under a command's "Runs in" choices | File deleted. New `lib/ui/widgets/older_sessions_pager.dart` (kit parts only, G16 0): the list pages itself when its end comes within 240 dp of the screen, with two skeleton rows while a page loads. A failed page, a list that changed on the server, a failed refresh or unreadable pins show one `KitNotice.error` in words (raw text only under its Details) with Try again or "Refresh recent conversations". A failed page or a changed list stops the paging until the person acts, so a broken server is not asked again and again. |
| `embedded-team-card` | `lib/ui/widgets/team_card.dart` (already unused in `lib/`: Work lists team tasks as rows since screen-work-1) | File deleted with its goldens (`team_card`, `team_card_phone`, `team_card_idle`, the three "page routes" of the team golden fixture), capture shots and census shots. Its surviving tests (Work has no card and lists the team's tasks; the host disclaimer in Technical details) moved to `test/team_on_work_test.dart`. |
| `appearance-picker-sheet` | `showAppearancePicker` (light-or-dark sheet with preview and Apply) | Removed; light or dark is the inline Auto · Light · Dark control on Appearance (already there). The theme preview sheet (`theme-pack-preview-sheet`) stays. |
| `context-capsule` | `lib/ui/screens/context_capsule_screen.dart` | **Not changed** (blocked, §2). |

Also: 32 English strings made unused are deleted (and their Arabic twins), 3 added (`sessionsOlderLoadFailed`, `sessionsLoadFailed`, `sessionsListChanged`); gen-l10n run. Ledger parts edited and `build_ledger.py` rebuilt: the six pages and their elements are gone, the elements that pointed at them now describe the term, the inline control and the pager. The search index had no entry for any of them. Census areas drop the removed shots.

## 2. Blocked: context-capsule (feasible=false for that page)

Removing `context-capsule` needs `lib/ui/screens/chat_screen.dart` (imports `ContextCapsuleScreen`, `_addContextCapsule`, the `onContextCapsule` wiring at line ~7932) and `lib/ui/screens/chat/composer.dart` (the `_PromptTool.contextCapsule` prompt tool). The brief forbids editing both (chat chain owns them). Blocker: **needs lib/ui/screens/chat_screen.dart and lib/ui/screens/chat/composer.dart**. Once the chat chain drops the prompt tool and `_addContextCapsule`, delete `context_capsule_screen.dart`, `lib/domain/context_capsule.dart` (if unused), `test/context_capsule_test.dart`, `test/context_capsule_chat_test.dart`, `tool/capture/context_capsule_test.dart`, the census shots in `k_session_misc.dart`, the `context-capsule` ledger page and the search exclusion in `test/search_index_test.dart`.

## 3. Tests

New or rewritten behaviour tests (all pass):

| File | Test |
|---|---|
| `test/session_inventory_paging_test.dart` | first request shows no pager; status failures leave older pages reachable (the list pages itself); empty and duplicate pages keep continuation; an end far below the screen waits until scrolled; a failed page says so in words, never the raw error, and Try again asks for that page again; a list that changed offers a refresh from the newest page (16 passed) |
| `test/plugins_screen_test.dart` | a plugin row opens its details; nothing offers command links, and reading the inventory never asks for the commands |
| `test/phone_server_screens_test.dart` | a plugin row opens its details; it has no menu |
| `test/mcp_setup_screen_test.dart` | What is MCP? explains the term in a bubble in the app's copy |
| `test/worktrees_screen_test.dart` | the Worktrees label explains itself: a button with a label and a hint; the bubble says what a worktree is |
| `test/appearance_picker_test.dart` | theme preview only: failed save keeps the theme, 320 dp at 2.5× in both directions |
| `test/team_on_work_test.dart` | (renamed from `team_card_test.dart`) Work has no card and lists the team's tasks; host disclaimer per kind |

Changed expectations (TEST-19): `library_commands_test` (opening "Runs in" loads the older page by itself), `return_brief_widget_test`, `teaching_empty_states_test`, `projects_screen_test` (words instead of the raw error; no Load more tap), `e7_workspace_capture_test`, `settings_server_updates_test` and `chat_live_events_test` (the inline Auto/Light/Dark control instead of the removed sheet), `team_cycle_test`, `team_motion_test`, `team_redesign_test`, `team_home_test`, `team_plugin_off_test` (card tests removed), `kit/kit_term_test` (longest explanation from the ARB), `design_standard_test` and baselines (team_card entries removed), `kit_ratchet_baseline.json` (entries for the deleted files and `server_plugins_section.dart` removed; its G16, G1 and G2 are 0).

Deleted: `test/info_label_test.dart`, `test/team_card_layout_test.dart`, `test/plugin_command_mappings_test.dart`, six `test/goldens/team_card_*.png`.

Runs (pinned Flutter 3.47.1, `-j 2`), compared against the base commit in a second worktree:

| Batch | Files | Slice | Base | New failures |
|---|---|---|---|---|
| 1 | plugins, phone server, plugin names, kit_term, team_on_work (base: team_card), team_plugin_off, team_redesign, appearance_picker, library_commands, return_brief_widget, teaching_empty_states, projects_screen, kit_ratchet, design_standard, golden_harness, ui_glossary, ui_ledger_coverage, gesture_audit, search_index, mcp_setup, worktrees | 44 failed | 45 failed | 0 (after fixing `projects_screen` "zero projects…"); `team_redesign` "Needs you comes first" fails on base too, in its home half |
| 2 | team_cycle, team_motion, team_home, settings_server_updates, appearance_preview_capture, revamp shared_settings_1 (+golden), e7_workspace_capture, accessibility_guidelines, desktop_context_menu, e7_workspace_localized_helpers, goldens team_discover / work_tab / team / work_parts, home_navigation, nudge_moments, project_health, revamp screen_work_1 (+golden), revamp shared_system_1 (+golden), safety_confirms, session_needs_you, session_pins, team_discover, team_phone_onboarding, team_plugins_layout, team_plugins_screen, text_scale_overflow, usage_labels, v2_feature_gating, workspace_hierarchy, workspace_stable_layout, work_tab_cleanup, work_tab_status_line, work_tab_team_sessions | 123 failed | 126 failed | 0; fixed 3 (`team_card_idle` goldens gone, `settings exposes the persisted native appearance choices`) |
| — | `session_inventory_paging_test` | 16 passed | — | — |
| — | `chat_live_events_test --plain-name 'themes command opens Settings'` | passed | failed | — |

The base's own failures (G17/G21 in `kit_ratchet_test`, golden drift, `ui_glossary` G11/G28, `ui_ledger_coverage` screen files, `search_index` Settings search, `phone_server_screens` "On this phone") are pre-existing and untouched. `flutter analyze`: no issues.

## 4. Images

Before = base `e1ccfc42`, after = this slice; dark, 412×915 (phone) and 1280×800 (wide), rendered by a temporary capture test (not committed).

- Work tab, end of a partial list: `before-work-end-more-{phone,wide}.png` (Load more button) → `after-work-end-more-{phone,wide}.png` (skeleton rows; loads by itself).
- Work tab, older page failed: `before-work-end-failed-page-{phone,wide}.png` (raw `ApiException…` in red) → `after-work-end-failed-page-{phone,wide}.png` ("Could not load older conversations." with Try again).
- Plugins: `before-plugins-{phone,wide}.png`, `before-plugins-row-menu-{phone,wide}.png` (Link commands, page menu) → `after-plugins-{phone,wide}.png` (chevron rows, no menus); details `before-plugins-details-*` (Material bottom sheet) → `after-plugins-details-*` (kit sheet, id in Details).
- Team card: `before-work-team-card-golden.png` (base golden `team_card_dark`) → `after-work-team-rows-golden.png` (`work_team_dark`, the team's rows on Work).
- Info label and appearance picker: no visual change to capture (the label already drew `KitTerm`; the sheet had no caller in `lib/`).

## 5. Accessibility, privacy, migration

- Accessibility: terms stay `KitTerm` (button, label, hint, 48 dp; bubble announced once). The pager's skeletons are hidden from screen readers; its error notice is one live region. Plugin rows gain a chevron and lose a menu whose only other item repeated the row's tap.
- Privacy and security: raw paging errors are no longer shown on screen; they sit under the notice's Details, redacted by `KitNotice.error`.
- Migration: none. Old `oc.pluginCommandMappings.<profileId>` values are orphaned, not read, and removed with their profile.

## 6. Needs a device

- Scroll Work to the end on a server with more than one page: the next page arrives before the end is reached, and stops loading when the end is off screen.
- The same in a command's "Runs in" choices (sheet).
- Plugins page on a real OpenCode server: row → details.
- Emulator before/after screenshots of each former host screen (the unit's `proof`) were not taken; images above are test renders.
