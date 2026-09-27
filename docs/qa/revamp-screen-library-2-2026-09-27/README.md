# revamp-screen-library-2: Revamp library (3 files) (2026-09-27)

## 1. Scope

- Unit: `screen-library-2` (wave 2b, screen-revamp). Finish line: Commands & tools, Add MCP server and the External agents pages (list, Add agent, agent page, task, and their questions) construct only kit parts, with G1, G16, G7 and the look gates at 0 for the three files, follow their map proposals in the visual language, and explain their gates instead of hiding them. Non-goal: no gateway call, controller field, store method or stored format added; the external agents list does not move into Integrations (map `merge-into:integrations`, integrations_screen.dart belongs to screen-library-1 and its redesign slice).
- Files changed: `lib/ui/screens/capabilities_screen.dart`, `lib/ui/screens/external_agents_screen.dart`, `lib/ui/screens/mcp_setup_screen.dart`, `lib/l10n/app_en.arb` (71 new keys, prefixed `capabilities*`, `mcpSetup*` and `externalAgents*`; no key renamed or deleted), generated `lib/l10n/app_localizations*.dart`, tests `test/external_agent_widget_test.dart`, `test/mcp_setup_screen_test.dart`, `test/library_integrations_test.dart` (one expectation), new `test/revamp/screen_library_2_test.dart`, `test/revamp/screen_library_2_golden_test.dart`, `test/revamp/goldens/library2_*.png` (34).
- Pages (map ids): add-agent, capabilities, external-agent-detail, external-agent-detail-delete-sheet, external-agent-detail-input-dialog, external-agents, external-agents-delete-sheet, external-task, external-task-cancel-sheet, external-task-forget-sheet, mcp-setup.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-8, KIT-11, KIT-20, KIT-21, KIT-23, KIT-28, KIT-34, LOOK-1, LOOK-2, LOOK-4, LOOK-5, LOOK-12, LOOK-15, LOOK-21, STATE-8, STATE-9, STATE-12, DATA-11, SEC-1, SEC-3, MAP-1; kit-v2 §9.1; visual-language §4 and §5 (rows in surface1 panels, sentence-case section labels, one pinned primary, sheets with an icon tile and a start-aligned title).
- Contract problems (PROC-20):
  - {Task text R04 "lib/l10n/app_en.arb AND app_ar.arb (real Arabic)" versus the owner decision 2026-09-27 "Arabic is DROPPED ... app_en.arb only"; the later owner decision wins (R15), so no Arabic entries were added; blocks: false}.
  - {`KitCapabilities` registry, `mcp.any` words: its title and why ("Extra tools", "No extra tools are added on this server yet.") are written for the offer, not for a server that cannot add one; this page uses its own words (`mcpSetupUnavailableTitle`, `mcpSetupUnavailableBody`) with `KitStateView.missing(capability: 'mcp.any')`; proposed: a `kitCapMcpAnyWhy` that explains the gate; blocks: false}.
  - {The Tools tab gate is `ServerCapabilities.toolInventory`, which has no capabilities.json id; the nearest registry entry is `server.oc1` (no enable flow), whose why is used under this page's own title; proposed: a `flag:toolInventory` matrix row; blocks: false}.
- New kit parts (KIT-3): none.
- Moved or removed items (owner rule 2026-09-27, rethink):
  - External agents: the headline "Bring an agent you trust." and the boundary paragraph above the list → one caption under the list (`externalAgentsBoundary`); the full-width "Add agent" button → the top bar action, and the empty state's primary when there is none.
  - External agents: "Try removing again" button under a half-removed agent → the row itself (tap asks the one removal question); added "Remove {name} from this phone" to every row's menu (map actionsMissing).
  - Add agent: the separate "Inspect Agent Card" and "Save agent" buttons → one pinned primary that turns from "Check agent" into "Save {name}"; the card's version and protocol lines → the Details fold; the card claim paragraph → a caption under the card rows; added "Stop checking" while a check runs.
  - Agent page: "Update credential" outlined button and "Remove agent" text button at the bottom → the top bar menu ("Replace key for {name}", "Remove {name} from this phone", last and destructive); the agent card at the top → its description line, a skills group and the Details fold.
  - New task: the "New task" dialog (write, then "Review task") → removed; "New task for {name}" opens the task page as a draft directly; a new task left empty is dropped on Back, so no empty row stays.
  - Task page: "Refresh task" button → pull down to check; "Stop task" and "Forget saved task" text buttons → the top bar menu, destructive and confirmed ("Ask {name} to stop this task", "Forget this task on this phone"); the state card → the screen's status line with the last check; "Send to agent" / "Reply to this task" → one pinned primary naming the agent; "Review external link" outlined button → a link row that opens through `openExternalLink`; the "saved" SnackBar on a failed forget → the page's issue notice.
  - Add MCP server: the "Persisted configuration" heading and paragraph → the "Where it goes" choice with its one-line consequence; working folder, environment variables, OAuth detection and timeout → Advanced (map proposal); the bottom bar's saved and error lines → the status line (save failed, location changed) or a saved state that replaces the form.
  - Commands & tools: nothing removed; the Tools tab no longer disappears.
- Map items (EVID-11):
  - capabilities: fix "KitStateView empty ... say where a command runs" → partial: tabs from KitTabSwitcher with 16 dp rails; the empty states and "where a command runs" live in commands/skills/references screens (screen-library-4). whenMissing server.oc1 "Tools tab hidden" → done, explains: `screen_library_2_test.dart` "keeps the Tools tab and says why on a server without it", golden `library2_capabilities_tools_unavailable_*`. statesMissing "server with no commands (Codex/Paseo) still reachable" → done: `flag:serverCatalog` explainer for the page, test "a server without a catalog explains the whole page", golden `library2_capabilities_unavailable_*`; "search with no match" → screen-library-4 (the catalog screens own search). actionsMissing "add or edit a command", "choose where it runs" → no owner (no gateway call).
  - mcp-setup: fix (name and address first, headers as key + obscured value, the rest under Advanced) → done, goldens `library2_mcp_setup_form_*`, `library2_mcp_setup_runtime_*`. actionsMissing "discard guard" → done: test "Back with typed input asks before discarding it"; "Test connection", "ask an agent", "browse a catalog" → no owner (no gateway call; integrations redesign). whenMissing server.any "disabled (form detached)" → done, explains: test "a server that cannot add one explains instead of a form", golden `library2_mcp_setup_unavailable_*`. statesMissing "name taken" → done as the server's reason on the status line (`mcp_setup_screen_test.dart` "keeps validation and server errors inline without saving"); "unreachable URL", "OAuth needed after save" → no owner (no signal from the add call).
  - external-agents: proposal merge-into:integrations → deferred: Integrations is screen-library-1's file and its redesign slice has no owner yet; this unit keeps the page and fixes it. infoMissing "tasks needing a reply" → done: "Needs you · host" on the row and first in the list, test "an agent waiting for a reply comes first and says so", golden `library2_external_agents_list_*`. actionsMissing "remove from the row" → done: test "removal is on the row, names the agent and confirms". statesMissing "agent unreachable / card changed" → no owner (no probe call).
  - external-agents-delete-sheet / external-agent-detail-delete-sheet: fix (trash icon, "Remove Palette agent?", one sheet for both) → done: `_confirmRemove` shared, golden `library2_external_agents_remove_sheet_*`; infoMissing "remote tasks continue" → done in the body.
  - add-agent: redesign → done (see moved items), golden `library2_add_agent_checked_*`, test `external_agent_widget_test.dart` journey. statesMissing "inspect failed" → done (notice titled "Couldn't check this agent"; address errors under the field); "unsupported card explained" → done (notice with the reason, Save disabled with it). actionsMissing "cancel inspection" → done ("Stop checking"). infoMissing "example address" → done (hint and helper).
  - external-agent-detail: fix → done, golden `library2_external_agent_detail_*`. infoMissing "one-line description" → done. statesMissing "unreachable" → no owner.
  - external-agent-detail-input-dialog: fix → done: New task needs no dialog (test "a new task left empty leaves no row behind"); the key dialog is `showKitInputDialog(kind: secret)` titled "Replace the key for {name}" with "Save key" / Cancel and the key's destination in its helper (infoMissing "where the key goes").
  - external-task: fix → done, goldens `library2_external_task_reply_*`, `library2_external_task_draft_*`. infoMissing "relative last check" → done ("Checked with the agent less than a minute ago"). statesMissing "polling stopped in background" → not shown (the page is not visible then); actionsMissing "notification when a reply is needed" → no owner (no background poll for A2A).
  - external-task-cancel-sheet: fix ("Stop this task?", stop icon, error tone) → done, test "cancel keeps active state when agent does not confirm", golden `library2_external_task_stop_sheet_*`; statesMissing "refused" → done (the existing "Cancellation is not confirmed" notice stays).
  - external-task-forget-sheet: fix (plain words, trash icon, question title) → done ("Forget this task?"), journey test.
- States per page (STATE-20): capabilities: loaded (tabs), tools not listed (test + golden), catalog not shared (test + golden). mcp-setup: form (golden), until restart (golden), errors after Save (test + golden), save failed (test), location changed (test), saved but not reconnected (test), not available (test + golden), discard question (test). external-agents: empty (golden), loaded by urgency (test + golden), removal unfinished (row words; no test), storage error (notice; no test). add-agent: address, checking (Stop checking), checked (golden), unsupported, check failed. external-agent-detail: tasks by urgency (golden), no tasks (test). external-task: draft (golden), needs a reply (golden), sent, uncertain (test), draft save failed (test), cancel unconfirmed (test).
- Deferred states (STATE-21): agent unreachable / card changed → needs a probe call, no owner; MCP "OAuth needed after save" → needs a status read after the add, no owner.

## 2. Builds

- Branch `revamp/screen-library-2`, base `7011dc46` (feat/phone-setup-v2), code head `93f915ac`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only | n/a: a revamp, not a fix | | n/a |
| 2 | `test/revamp/screen_library_2_test.dart`, `test/external_agent_widget_test.dart`, `test/mcp_setup_screen_test.dart`, `test/revamp/screen_library_2_golden_test.dart` | pass | 74 passed (`tests.txt`) | PASS |
| 3 | `test/library_integrations_test.dart` "empty MCP state opens persistent native setup" | passes | passed; the other 23 tests of that file fail on Integrations words and flows changed by screen-library-1 (not re-run on the base here) | PASS |
| 4 | `test/kit_ratchet_test.dart` in `KIT_RATCHET_WRITE=1` dry run (baseline restored) | the three files absent from every gate | absent from G1, G15, G16, G2, G7, G17, G21 | PASS |
| 5 | `flutter analyze` on the changed files | no issues | no issues (`analyze.txt`) | PASS |

Other suites were not run (owner decision 2026-09-27).

## 5. Evidence

- `tests.txt`: step 2. `analyze.txt`: step 5.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | STATE-12 (explain, never vanish) | `test/revamp/screen_library_2_test.dart` "keeps the Tools tab and says why on a server without it", "a server without a catalog explains the whole page", "a server that cannot add one explains instead of a form" | `tests.txt` |
  | DATA-11 (confirm before a destructive act) | same file "removal is on the row, names the agent and confirms"; `test/external_agent_widget_test.dart` "cancel keeps active state when agent does not confirm" | `tests.txt` |
  | Discard guard | same file "Back with typed input asks before discarding it" | `tests.txt` |
  | Owner rule: one list by urgency | same file "an agent waiting for a reply comes first and says so" | `tests.txt` |
  | Never resend, draft safety | `test/external_agent_widget_test.dart` journey, "uncertain delivery ...", "failed draft save ...", "Back and Send wait ..." | `tests.txt` |
  | SEC-3 (header values secret, never prefilled) | `test/mcp_setup_screen_test.dart` "masks the value, key stays visible, reveal on press, never prefilled" | `tests.txt` |

- Changed test expectations (TEST-19):
  - `test/external_agent_widget_test.dart`: journey → New task opens the draft directly (no "Review task" dialog), buttons named for the agent ("Send to Color agent", "Reply to Color agent", "Save Color agent"), Stop/Forget/Remove through the top bar menu with keyed confirmations, `KitButton` instead of `FilledButton`; added "a new task left empty leaves no row behind". Rules: map fixes, KIT-28, COPY-8.
  - `test/mcp_setup_screen_test.dart`: `KitButton` instead of `FilledButton`/`OutlinedButton`; Advanced opened before its fields; the save error read from the status line; the saved state replaces the form (the name field is gone rather than disabled); the kit's reveal tooltip replaces "Hide header value"; `_reveal` moves the list's position and unfocuses first (a focused multiline field kept scrolling its caret back). Rules: KIT-20, map fix.
  - `test/library_integrations_test.dart`: "Persisted configuration" heading → the `mcp-scope` choice (the heading was removed as a stray item).
- Goldens added (each opened and looked at), `test/revamp/goldens/`: `library2_capabilities_tools_unavailable` (phone and 1280x800), `library2_capabilities_unavailable`, `library2_mcp_setup_form` (phone and 1280x800), `library2_mcp_setup_runtime`, `library2_mcp_setup_errors`, `library2_mcp_setup_unavailable`, `library2_external_agents_list` (phone and 1280x800), `library2_external_agents_empty`, `library2_external_agents_remove_sheet`, `library2_add_agent_checked`, `library2_external_agent_detail`, `library2_external_task_reply`, `library2_external_task_draft`, `library2_external_task_stop_sheet`, each dark and light. Approved render: `docs/design/visual-language-2026-09-26/Settings.png` (grouped rows in surface1 panels, sentence-case labels, pinned primary) and `Confirm.png` (sheets). Differences: the pages are forms and lists without the Settings page's large title (KitTopBar is the kit's page bar); the capabilities "catalog not shared" title reads the registry's "Server settings".
- Before and after (EVID-10): `before-external-agents.png` / `after-external-agents.png`, `before-add-agent.png` / `after-add-agent.png`, `before-external-agent-detail.png` / `after-external-agent-detail.png`, `before-external-task.png` / `after-external-task.png`, `before-external-task-cancel-sheet.png` / `after-external-task-stop-sheet.png`, `before-mcp-setup.png` / `after-mcp-setup.png`, `before-capabilities.png` / `after-capabilities-tools-gate.png` (before images from `docs/qa/screen-census/`).
- Accessibility: every row action is also in the row's menu (semantic custom actions through KitRow); disabled primaries show their reason as visible text under the button ("Write your reply first", "Enter the agent key first", "Type the agent address first"); state is worded, never colour-only (task marks plus the state word); all fields have visible labels; the header value and agent key use KitField.secret with a labelled reveal; no text-scale golden was made (the compact 2.0 text MCP test passes).
- Privacy and security: the agent key and header values are `KitField.secret` / `showKitInputDialog(kind: secret)` (never prefilled, never kept in a draft); a failed key save shows the fixed issue words, never a server reply; agent output links open only through `openExternalLink` after `safeExternalLinkUri`; the A2A never-resend rule is unchanged (claimSend before send; a sent task's title is written with `saveTask(existingOnly: true)` before the claim, which compares draft and task only).
- Migration: n/a: no stored format changed (a new task may now be stored with an empty title until it is sent; the field already allowed any string and rows fall back to the draft's first line).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/revamp/screen_library_2_test.dart test/external_agent_widget_test.dart test/mcp_setup_screen_test.dart test/revamp/screen_library_2_golden_test.dart
$F analyze lib/ui/screens/capabilities_screen.dart lib/ui/screens/external_agents_screen.dart lib/ui/screens/mcp_setup_screen.dart
```

## 7. NOT proven

- Not run on a device or emulator; no live OpenCode server or A2A agent.
- Shared tests not run; expected to need the integrator: `test/v2_feature_gating_test.dart` (the Tools tab now stays on OpenCode 2; `Tab`/`DefaultTabController` replaced by KitTabSwitcher), `test/e7_library_layout_test.dart` (mcp-setup layout expectations), census capture areas `tool/capture/census/areas/{a_shell,g_servers,j2_library,j1_settings_more}.dart` (old words and dialogs).
- `test/library_integrations_test.dart`: 23 tests fail on Integrations expectations that screen-library-1 changed (its QA record lists the file for the integrator); only this unit's expectation was updated.
- The ratchet baseline and the l10n coverage baseline were not edited (integrator-owned; both files' counts dropped).
- The external agents list is not merged into Integrations (map proposal); the MCP "ask an agent" and "catalog" paths, "Test connection" and command "where it runs" are not built.
- No text-scale 200 % golden or keyboard-only run.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-library-2` |
| Enabled | Yes (no flag) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `93f915ac` |
| Deployed | No | |
| Released | No | |
