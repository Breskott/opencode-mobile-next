# slice-R18: Review, Terminal, Integrations, Tools and External agents (2026-09-27)

Definition: `docs/ux-system/revamp/leftover-units.json` id `slice-R18`.
Finish line: each of the six pages offers one reload and has no dead rows.
Non-goal: kit changes. R4 `labelTerm`, R7 `KitDiffView.onFileChanged` and
R10 `flag:terminal` are used as they were merged.

## What changed, per page

- **Review** (`review_workspace.dart`)
  - Until a diff shows (the loading, slow or error state), the top bar has no
    Refresh. The body's Try again is then the only reload.
  - The scope hint ("Files this conversation changed.") shows under the view
    picker only when the chosen view is empty.
  - The "N of M viewed" count now uses `KitDiffView.onFileChanged`. Before,
    it relied on a side effect of building the file header's menu.
- **Terminal** (`terminal_screen.dart`)
  - "Remove N ended terminals" is now in the Terminal top-bar menu
    (`terminal-list-menu`). The menu only appears when there are ended
    terminals.
  - Where the list is framed with no bar of its own (the embedded case), the
    action stays under the list, so it still shows once.
  - The empty state reads "No terminals yet" / "Start one in {project}.",
    with the project folder's name. Without a folder it says "Start one in
    this project."
  - The gate uses the terminal-only registry entry `flag:terminal`.
- **Integrations** (`integrations_screen.dart`)
  - The Providers page's bar no longer shows the "1 of 2 connected" count.
  - On the combined page, the Providers, MCP servers and Resources labels now
    explain themselves through `KitRowGroup.labelTerm` (a `KitTerm`). MCP
    servers reuses the glossary text `e7GlossaryMcpExplanation`.
  - When the explained label comes first in its section, the fixed spacer
    above it is dropped. Without this, the label's target added 22 dp to the
    section gap.
- **MCP row** (`integration_tiles.dart`): on a server without runtime removal,
  the row menu leaves out "Remove … until restart" instead of showing it as
  a dead item. The `removalSupported` parameter is gone.
- **Tools** (`tools_screen.dart`)
  - The "Parameter schema" fold and its JSON block are removed.
  - "Copy parameter schema" is in the sheet's menu (`tool-menu`, a
    `KitRowMenu` at the end of the "Takes" label, or beside "Takes nothing").
    The copy is redacted, as the code block's was.
- **External agents** (`external_agents_screen.dart`)
  - On the agent's page, the skills group is left out when the card lists no
    skills. The "It lists no skills" row is gone from Add agent as well.
  - The "Reopening checks…" caption is removed.
  - The "hasn't verified" line shows only on Add agent.
  - The description starts `space5` below the bar's host subtitle.
  - The stop confirm reads: Stop “{task}”? / Ask {agent} to stop / Keep
    running.

Copy: new strings are in `app_en.arb` (`terminalScreenEmpty*`,
`integrations{Providers,Resources}Explanation`, `externalAgentsStopTask*`,
`toolsDetailMenu`). Seven strings are no longer used and were deleted:
`a2aReopenDetail`, `a2aRequestCancel`, `externalAgentsStopTitle`,
`externalAgentsNoSkills`, `e7LibraryParameterSchema`,
`integrationsProvidersSummary` and `integrationsMcpRemoveUnavailable`. The
three of them that were in `app_ar.arb` were removed there too. gen-l10n was
run.

Reachability: every entry point stays. The one control that moved is
Remove-ended, which is now in the bar's menu.

## Tests

New tests. Each one fails on the base commit `0a579ea6` (checked in a
temporary second worktree) and passes here:

- `review_workspace_test`: "R18: no top-bar Refresh while the error or the
  slow wait shows"; "R18: what a view covers is said only when it is empty".
- `screen_terminal_1_test`: "R18: an empty list says No terminals yet and
  names the project". The gate test now also asserts `flag:terminal`.
  "removing the ended terminals" goes through the bar's menu.
- `screen_library_1_test`: "R18: Providers, MCP servers and Resources explain
  themselves; the Providers page has no connected count". "MCP rows … no
  dead Remove" is updated.
- `tools_screen_test`: "the tool sheet copies the schema the server returned"
  (the clipboard is checked); "long server descriptions keep Copy parameter
  schema reachable".
- `external_agent_widget_test`: "R18 agent page: no empty skills group, no
  reopen caption, the unverified line only on Add agent, a section gap under
  the bar". The stop question's words are updated.
- `slice_p6_6a_defaults_test`, `screen_library_3_test`: updated for the hint
  and the schema menu.

Run once: the files above plus `terminal_accessibility_test`,
`library_integrations_test`, `integration_auth_recovery_test`,
`screen_library_2_test`, `screen_review_2_test` and `kit_ratchet_test`.
Result: 154 passed, 27 failed.

All 27 failures also fail on the base commit and are not R18's:

- `library_integrations_test` (19) and `integration_auth_recovery_test` (2).
- `tools_screen_test` "Settings exposes one native tools destination": the
  Settings hub moved in P3.10.
- `kit_ratchet_test` G17 and G21. The G17 hit in `integration_tiles.dart` is
  `KitTextTone.attention`, which the "attention roles" pattern flags wrongly;
  the gate belongs to kit-gates.

Three tools tests failed on the base commit and pass now: search with 2
tools, the fold overflow, and "the detail sheet says what the tool takes".

`flutter analyze`: clean.

## Goldens

I ran the eight golden files that draw these pages
(`screen_library_1-4`, `screen_review_1`, `screen_terminal_1`,
`slice_p6_6a_defaults`, `slice_p310_settings_ia`) on the base commit and on
R18:

- 79 tests were already stale on the base commit. They were **not**
  regenerated.
- 41 tests failed only with R18. I looked at each diff and regenerated only
  those 41 (41 PNGs):
  - `library_integrations_*`: labels are now terms, no count in the bar, no
    dead Remove.
  - `library_credential_management_*` and `library_command_auth_sheet_*`:
    the bar behind the sheet has no count.
  - `library2_add_agent_checked_light`.
  - `review_*` and `p66a_review_scope_*`: no hint, no Refresh while slow.
  - `terminal_list*`, `terminal_row_menu`, `terminal_rename_dialog` and
    `terminal_remove_sheet`: the bar menu replaces the action under the
    list.

These goldens were already stale and also change with R18. They were left
for their owners: `terminal_empty`, `terminal_unavailable`,
`library_tools_detail_sheet`, `library2_external_agent_detail`,
`library2_external_task_stop_sheet`, `review_empty`, `review_error`,
`review_loaded`, `library2_add_agent_checked_dark`, and others.

## Images (this folder)

Before and after, each from a regenerated golden:

- `review_all_viewed_light_before_after.png` (phone)
- `review_loaded_1280x800_dark_before_after.png` (wide)
- `review_slow_light_before_after.png`
- `p66a_review_scope_light_before_after.png`
- `terminal_list_light_before_after.png`
- `terminal_list_1280x800_dark_before_after.png`
- `library_integrations_loaded_light_before_after.png`
- `library_integrations_loaded_1280x800_dark_before_after.png`
- `library_integrations_mcp_menu_light_before_after.png`
- `library_credential_management_sheet_light_before_after.png`
- `library2_add_agent_checked_light_before_after.png`

`*_stale_golden_vs_after.png` compares the old, already stale golden with
R18's render. These are for the states whose goldens were not regenerated:
the terminal empty state, the tool sheet with its menu, the agent page, and
the stop question.

## Known kit behaviour (not changed here)

An explained label (`labelTerm`) still sits about 7 dp further from its
panel than a plain label does. The `KitTerm` 48 dp target reaches past the
6 dp label gap. This belongs to `kit_section_label.dart` (R4), which is
outside this unit.

## Still needs a device

- Tapping the explained labels with TalkBack and a finger.
- The Terminal bar menu with a hardware keyboard.
- Copy parameter schema pasting into another app.
- The stop question on a real A2A agent.
