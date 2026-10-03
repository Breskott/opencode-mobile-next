# slice-team-g17: G17 absolute, discovery on the Plugins row, host guide next step (2026-09-28)

Branch `revamp/slice-team-g17`, from `feat/phone-setup-v2` at `cd3f9a48`.

Finish line: the kit ratchet baseline holds no counts at all, and G17 fails any new colour hit with a message that names what to use. The discovery offer is part of the Plugins AI Team row, and the host guide ends in its next step.
Non-goal: reworking the team page's layout, or regenerating the 122 team goldens that already failed on the base commit (see Tests).

## 1. G17 "attention roles": 19 hits cleared, and the gate is absolute

The rule comes from docs/design/visual-language-2026-09-26.md §1: amber means "needs you" and nothing else, and red is only for destroying or stopping something (LOOK-4, LOOK-24).

A new `TeamMark` type in `lib/ui/widgets/team_vocabulary.dart` decides how a team state leads its row. It returns either the kit's single needs-you mark (`KitNeedsYou.mark()`, the same mark as `KitTaskMark(needsYou)`) or the state's own glyph in its tone. The old functions `teamWorkGlyph`, `teamGateGlyph` and `teamAgentGlyph` are replaced by `teamWorkMark`, `teamGateMark` and `teamAgentMark`.

| Hit | Was | Now |
|---|---|---|
| WorkState.needsInput, AgentState.waiting, GateKind choice / confirmation / freeText / gateBead / unknown (7) | glyph in attention tone | needs-you mark in rows (Needs-you gate rows, merge and work-sheet rows, agent rows); a request card keeps the kind's glyph |
| RunState.blocked, WorkState.blocked, AgentState.blocked (3) | attention | neutral |
| context use ≥ 75 % (`teamContextTone`) (1) | attention (drawn text1) | returns `KitTextTone.primary`, the same look, with no attention role (`teamContextAttentionPercent` renamed to `teamContextHighPercent`) |
| team_states: not answering, plain http refused, unreachable, stale line, refresh-failed line (5) | attention | neutral |
| team_home_screen: heat pause / stop line (1) | attention | neutral |
| team_board_card: needs-you and blocked flags (2) | a tone in `teamBoardFlag`'s tuple that nothing drew (`KitTaskFlag` draws the flag) | tone removed from the tuple; board pixels unchanged |

A side effect of `TeamMark.leading` is that team rows now use the kit's tone map (`KitTokens.toneColor`). Before, merge-section and work-sheet rows drew a failed item's glyph in `danger` red through `AppTheme.statusColor`. They now draw it in text1, as LOOK-5 requires.

**Ratchet (`test/kit_ratchet_test.dart`).**
- Every G17 row is `absolute: true`.
- Two constants hold the failure text: `_g17AttentionFix` and `_g17RoleFix`.
  - For a state that waits on the person, the attention fix names `KitNeedsYou.mark()`, `KitTaskMark(needsYou)`, `KitNeedsYou.span/badge/row`, `KitTaskFlagKind.needsYou` and `KitRequestCard`.
  - For held-up or degraded states it names `AppStatusTone.neutral`, and `AppStatusTone.failure` for failures.
- The other G17 fixes now name the concrete API as well.
- A new test checks three things: every G17 row is absolute, the baseline has no G17 counts, and the fix text names these parts.

**Final `test/kit_ratchet_baseline.json`.** Every gate section is `{}`: G2, G7, G15x, G17, G21 and G48. The only content left is the `allow` section.
- `allow` is structural rather than a count. It is the frozen KIT-5 list of kit files that legitimately own a pattern, for example `kit_copy.dart` owns `Clipboard.setData` and `kit_layout.dart` owns widths.
- It is not a to-do list, and write mode never touches it.
- G17 keeps an empty `"G17": {}` section like G15x, the other rule-table gate with absolute rows. G1, G15 and G16 have no section because they sit outside the `_rules` table.

## 2. embedded-team-discovery-card: folded into the Plugins row

- `PluginsSettingsScreen` no longer shows the card.
- It now runs discovery itself, on open and again when the profile changes.
- When a team answers, the AI Team row reads "Found on {server}" and carries **Turn on** in the same row.
  - Tapping the rest of the row still opens the team page.
  - While saving, the row reads "Turning the AI team on…". A failed save reads "Could not turn the AI team on. Nothing changed. Try again." and keeps Turn on.
- This covers the critic's finding ("one team, two presences"), the owner's fix ("fold the offer into the row ('Found on Laptop · Turn on'), plain words … one consenting tap"), and the critic's engine-words note: no Gas City version or city name shows on the row.
- Kit: `KitRow.action` (additive, KIT-43).
  - It is the row's own single action: a trailing tertiary button at 1.0× text that moves under the supporting line from 1.3× text, the same place `KitRow.unavailable` puts `enable`.
  - Documented in `docs/ux-system/kit-api/KitRow.md`, tested in `test/kit/kit_row_test.dart`.
  - Without it, at 320 dp and 2.5× text the button took half the row, and a tap on the row turned the team on instead of opening it (`team_plugins_layout_test`).
- Removed:
  - the `TeamDiscoveryCard` widget and `teamFoundCopy`;
  - the strings `teamUiDiscoveryTitle`, `teamUiDiscoveryNotNow`, `teamDiscoverTurnOnNamed`, `teamUiVerdictFound` and `teamUiVerdictFoundControls` (English and Arabic);
  - the old `settings_team_discovery_card_offer_*` goldens.
- The census shot `embedded-team-discovery-card` now captures the row's Turn on.
- Dismissal memory is kept: `OrchestrationStore.dismissDiscovery`, which Turn off sets, still stops the asking for that server.

## 3. team-host-guide-sheet: the next step, and the 8373 hint

- `showTeamHostGuideSheet(context, {enterAddress})`. With `enterAddress`, the sheet's pinned primary is **Enter the address**: it closes the guide, then opens the next step.
  - Team intro: "Set it up" and "On a computer" open the address form (`editTeamAddress`).
  - Server editor: "Learn how" goes to its "Add manually" form.
  - `KitEnableFlows.teamHostGuide`: `editTeamAddress`.
  - The address form's own "How" note: back to the address field, which gets focus.
- Where the team is already added (gate sheet, agent page, Start-a-task), the guide explains only the host side. It has no primary there.
- Step 2 says "Save the team file…" instead of "city file". This is the critic's C3 note: engine words stay inside the commands.
- **Port.** `tool/host/cp_front/front.py` has `DEFAULT_PORT = 8373`, and the guide's step 4 command runs `--port 8373`. The address hint `teamUiAddAddressHint` now reads `http://100.x.x.x:8373` (it was `:8372`, the bare supervisor).
  - The stale untranslated Arabic copy was dropped.
  - The glossary baseline entry moved from `:8372` to `:8373`; the count is unchanged.
  - A test reads `front.py` and checks that the hint, `teamHostFrontPort` and the guide command all agree.

## Images (before left, after right; dark 412×915 and light 1280×800)

The gallery is `test/revamp/slice_team_g17_golden_test.dart` (goldens `test/revamp/goldens/team_g17_*`). The "before" shots are the same gallery run at `cd3f9a48`, before any edit.

- `home_*`: in team home's Needs-you group, the question row's amber edit-note tile becomes the needs-you mark. Both needs-you rows now lead with the same mark.
- `agents_*`: an agent waiting on you gets the amber needs-you mark (it was a white "?" tile); a blocked agent is neutral text2.
- `heat_*`, `notAnswering_*`: the heat line and the "Can't reach the team host" page are neutral. The kit already drew attention there in text1, so the only visible change is the glyph going from text1 to text2.
- `plugins_*`: the separate card ("Laptop also runs an AI team. Turn it on?" with Turn on AI Team / Not now) is gone. The row now reads "AI Team · Found on Laptop" with Turn on.
- `guide_*`: the pinned primary **Enter the address** is new, and step 2 says "team file".
- Board card: nothing visual changes, because `KitTaskFlag` already drew the flags. `test/goldens/team_board_golden_test.dart` fails the same 30 scenes at base and after.
- Updated goldens:
  - `team_work_sheet_*`: the "Needs input" dependency takes the needs-you mark.
  - `team_host_sheet_*`: the 8373 hint.
  - `team_host_guide_sheet_*`: the primary and step 2.
  - `settings_team_found_row_*`: new; replaces the card goldens.

## Tests (run once each, via tool/qa/machine_lock.sh)

**Shown failing first on the base commit** (new test files copied into a base worktree at `cd3f9a48`):
- `kit_ratchet_test` "G17 colour": 4 absolute problems, with the new fix text.
- `slice_team_g17_test`, `team_host_guide_sheet_test` and `kit_row_test`: do not compile on base (the new API is missing).
- `shared_settings_1_test` "team found on the server" ×2.
- `team_discover_test` "the host guide ends in its next step".
- `team_page_test`, heat line tone.
- `team_plugins_screen_test`: 3 found-row tests.

**After, in this worktree.** All pass except failures that were already there, identical on base:
- New or changed test files: `test/slice_team_g17_test.dart` (new), `kit_ratchet_test`, `kit/kit_row_test`, `team_host_guide_sheet_test`, `team_discover_test`, `team_plugins_screen_test`, `team_plugins_layout_test`, `revamp/shared_settings_1_test`, `team_page_test`, `team_agent_screen_test`, `capability_flows_test`.
- Gates: `redaction`, `ui_glossary`, `no_raw_error_text`, `kit/kit_manifest`, `kit/kit_draft_manifest`, `architecture_boundaries`.
- Tests for the other changed files: team board, merge, work sheet, gate answer, home, redesign, one page, task details, work graph, the layout tests, `slice_close_team`, `screen_team_1/2/3`, `shared_team_1/2`, `kit_needs_you`, `kit_task_card`, `team_phone_onboarding`, `aiteam_component`, `l10n_coverage`, `design_standard`.

**Pre-existing failures, the same at base:**
- `team_plugins_screen_test` "manual add host kind" ×6.
- `shared_settings_1_test`: Arabic share, theme preview Undo.
- `team_gate_answer_test` "layout 320dp 2.5x" ×4.
- `shared_team_2_test` host-details ×2.
- 122 team goldens in `test/goldens/team_*` and `test/revamp/*` that no longer match on base (board, home, agents, discover, scenes, phone v2 …). Some of these screens also show this slice's tone change, but they need regenerating by their owner against a known-good base, not here.

`flutter analyze` on the whole project (lib, test, tool): no issues.

## Still needs a device

- A real Gas City host found on a Tailscale address, to check the row's Turn on end to end.
- The guide's Enter the address on a phone, with the keyboard opening on the address field.
