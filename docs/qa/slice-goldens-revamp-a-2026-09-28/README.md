# slice-goldens-revamp-a: reviewed golden refresh (2026-09-28)

Branch `revamp/slice-goldens-revamp-a`, worktree `oc_app-slice-goldens-revamp-a`, base `138f8216`
(feat/phone-setup-v2 after slice-glass-ambient). Scope: the first half of
`test/revamp/*golden*_test.dart` (37 files, list in the coordinator's `rv-a.txt`).

- **Finish line:** every failing golden in the 37 files is judged, regressions are fixed at their source, intended changes are refreshed, and the 37 files pass.
- **Non-goals:** the other half of `test/revamp`, `lib/ui/kit/**` (kit agent), G23 naming rules.

## Result

| | Count |
|---|---|
| Failing goldens found (Skia, `flutter test`) | 323 (182 scenes x light/dark) |
| Intended, refreshed | 319 (180 scenes) |
| Regression fixed, then refreshed | 4 (`team_intro_phone` x phone/1280 x light/dark): test fixture, see below |
| Handed off | 0 |
| Goldens changed that were not failing | 0 (the changed set equals the failing set) |

After the refresh all 37 files pass: 751 tests, two serial chunks, `-j 2`, through `tool/qa/machine_lock.sh`.

## The one regression: `team_intro_phone` captured a loading page

The AI Team intro on a phone now runs the phone's pre-flight first (P1.7, `320269a2`). It asks the
device (`oc/voice getDeviceInfo`) and shows two skeleton rows and no set-up button until the answer
arrives. The golden test never answered, so the new render was the loading state, not the intro.
The product is right. The gallery was wrong.

Fix (`test/revamp/screen_team_1_golden_test.dart`): the phone scenes pass a capable device
(`deviceProbe`), and every intro scene asserts `KitSkeletonRows` is absent before it matches. That
assertion fails without the probe (checked: `Found 1 widget with type "KitSkeletonRows"`) and passes
with it. See `team-intro-phone-fixture.png` (committed | unfixed render | after).

## What changed on purpose (grouped)

| Cause | Commit | What the images show |
|---|---|---|
| Moderate ambient fields + crisp glass | 6ae40ca8, 2f96633b | Work shell goldens: soft green/blue fields on the ground (the 50-91 % diffs), pill and dock rims |
| R1 KitTopBar flat on the gutter | 9413f93d | 1280 toolbars are flat with a hairline instead of a glass pill; phone titles start on the gutter (a few px shift) |
| R4 row groups on one inset | ba9d7088 | section labels move to the group edge; section gaps a few px taller, so rows below shift |
| R9 dark text3 | 0c3f5718 | `8A8D94` -> `8C8F96`, 2/255, dark only, invisible (chat_2 and three sub-threshold diffs) |
| R5 accent tertiary | 4e49ccde | Undo, Try again, Refresh usage, Open a project you used before in the accent |
| R6 current vs selected | 24840cc8 | the selected radio no longer also says Current (default shell, stop-after, import into) |
| R2 / P3.11a sheets | 24be364a, 00cafa13 | question sheet: Send pinned at the bottom; project sheet lost Manage project |
| R16 say things once | 253a6919 | note page: Save appears only after an edit; active context: no count line, '{Role} message' titles; capabilities intro |
| R18 no dead rows | c0efb78c | Providers count subtitle gone; MCP menu has no disabled Remove; agent pages drop 'It lists no skills'; tool schema under a menu |
| P10.1 / P10.2 | 34353c2f | conversation menu is the ... overflow (was vertical dots / 'Conversation menu' text); Server commands page rebuilt with search |
| Composer | 23f2d0ce, 74412bb5 | one trailing control; expand in the field corner; stop moves to the start |
| P3.7a one diff component | d4f01730 | Review changes shows KitDiffView |
| Team | 4cfbf10a, 781933fb, d42ba768, 47d9d881, 4334ce0c | one request card, status line in the slot, header says Off, Wake row, Technical details row, Plugins row |
| R3 code block | e55a23f9 | no empty header band / wrap toggle on a one-line command |
| Copy | 5f5d957f and slice commits | actions name their target (Stop service, Remove environment, Ask Color agent to stop), Move to the cloud, Privacy and data, No terminals yet |

## Look at these (owner)

1. **Team task default supervision is now High, not Balanced** (`team_start_run`). The start sheet reads
   the per-server automation policy (P6.1, `929be112`), whose default is `AutomationSupervision.high`
   (`dff34356`). Earlier notes say Balanced = asks before merges. If new tasks should start on Balanced,
   change the policy default, not the golden.
2. **Provider sign-in states lost amber** (`library_integrations_pending_auth`): 'Sign-in waiting' and
   'Sign-in may not have started' are now text colour (G17 kit-polish, `1dc1dae8`). Right if a pending
   browser sign-in doesn't count as needs-you.
3. **Agents list** (`team_agents_list`): the per-row 'Wake slit' button became one 'Wake the paused agent' row at the top.
4. Unchanged by this refresh but visible in these galleries (not regressions of the merged work):
   at 2.0 text, file names break mid-word in Review (`review_*_text2`: 'checkout_page.da / rt');
   at 1280 the 'Saved prompt restored · Undo' snack bar sits over the composer (`saved_prompts_restored_undo_1280x800`);
   the 100 % rate-limit bar is drawn in text colour, not danger (`agent_account_limit_reached`).

## Contact sheets

Before (committed golden) | after (refreshed), dark variant of each scene (light where only light failed).

- `chat_phone-1.png`
- `chat_phone-2.png`
- `chat_phone-3.png`
- `chat_phone-4.png`
- `chat_wide-1.png`
- `chat_wide-2.png`
- `chat_wide-3.png`
- `library_phone-1.png`
- `library_phone-2.png`
- `library_phone-3.png`
- `library_wide-1.png`
- `phone-system-settings_phone-1.png`
- `phone-system-settings_phone-2.png`
- `phone-system-settings_phone-3.png`
- `phone-system-settings_wide-1.png`
- `phone-system-settings_wide-2.png`
- `review_phone-1.png`
- `review_wide-1.png`
- `team-intro-phone-fixture.png`
- `team_phone-1.png`
- `team_wide-1.png`
- `work_phone-1.png`
- `work_phone-2.png`
- `work_wide-1.png`

## Per-golden verdicts

One row per scene (light and dark share the verdict). Diff = pixel share that failed, per theme.

| File | Golden (scene) | Diff | Verdict | Reason / commit |
|---|---|---|---|---|
| chat_2 | `chat_task_list_1280x800` | D 0.00 | Intended | R9 dark text3 8A8D94->8C8F96, invisible (0c3f5718) |
| chat_2 | `chat_task_list` | D 0.01 | Intended | R9 dark text3 8A8D94->8C8F96, invisible (0c3f5718) |
| chat_2 | `chat_tool_edit_open` | D 0.26 | Intended | R9 dark text3 8A8D94->8C8F96, invisible (0c3f5718) |
| chat_2 | `chat_tool_steps_1280x800` | D 0.10 | Intended | R9 dark text3 8A8D94->8C8F96, invisible (0c3f5718) |
| chat_2 | `chat_tool_steps` | D 0.28 | Intended | R9 dark text3 8A8D94->8C8F96, invisible (0c3f5718) |
| chat_2 | `chat_tool_subagent_step` | D 0.07 | Intended | R9 dark text3 8A8D94->8C8F96, invisible (0c3f5718) |
| chat_3 | `chat_3_composer_busy_1280x800` | D 5.04 L 5.04 | Intended | composer: one trailing control, editor in field corner (23f2d0ce); P4.4 accessories (74412bb5); P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_3 | `chat_3_composer_busy` | D 12.62 L 12.63 | Intended | composer: one trailing control, editor in field corner (23f2d0ce); P4.4 accessories (74412bb5); P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_3 | `chat_3_composer_sign_in_1280x800` | D 0.26 L 0.26 | Intended | composer: one trailing control, editor in field corner (23f2d0ce); P4.4 accessories (74412bb5); P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_3 | `chat_3_composer_sign_in` | D 4.19 L 4.20 | Intended | composer: one trailing control, editor in field corner (23f2d0ce); P4.4 accessories (74412bb5); P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_3 | `chat_3_composer_text_1280x800` | D 4.28 L 4.28 | Intended | composer: one trailing control, editor in field corner (23f2d0ce); P4.4 accessories (74412bb5); P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_3 | `chat_3_composer_text` | D 10.74 L 10.74 | Intended | composer: one trailing control, editor in field corner (23f2d0ce); P4.4 accessories (74412bb5); P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_3 | `chat_3_history_sheet_1280x800` | D 0.26 L 0.26 | Intended | P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_3 | `chat_3_history_sheet` | D 0.63 L 0.30 | Intended | P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_3 | `chat_3_prompt_editor` | D 0.24 L 0.24 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| chat_3 | `chat_3_tools_sheet_1280x800` | D 0.26 L 0.26 | Intended | P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_3 | `chat_3_tools_sheet` | D 0.36 L 0.30 | Intended | P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_5 | `chat_5_approvals_sheet_1280x800` | D 9.00 L 6.36 | Intended | approvals say the new-conversation rule once (23f2d0ce); P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_5 | `chat_5_approvals_sheet` | D 0.71 L 0.65 | Intended | approvals say the new-conversation rule once (23f2d0ce); P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_5 | `chat_5_permission_card_1280x800` | D 0.26 L 0.26 | Intended | P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_5 | `chat_5_permission_card` | D 0.29 L 0.29 | Intended | P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_5 | `chat_5_question_card_1280x800` | D 0.26 L 0.26 | Intended | P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| chat_5 | `chat_5_question_card` | D 0.29 L 0.29 | Intended | P10.1/P10.2 conversation menu + one command sheet (34353c2f); R1 flat toolbar, title on the gutter (9413f93d) |
| p67_consent | `p67_consent_answers_1280x800` | D 0.14 | Intended | R4 row groups on one inset / section label spacing (ba9d7088) |
| p67_consent | `p67_consent_answers` | D 0.37 L 0.37 | Intended | R4 row groups on one inset / section label spacing (ba9d7088) |
| p67_consent | `p67_first_start_battery_1280x800` | D 0.08 | Intended | R4 row groups on one inset / section label spacing (ba9d7088) |
| p67_consent | `p67_first_start_battery` | L 0.23 | Intended | R4 row groups on one inset / section label spacing (ba9d7088) |
| saved_prompts | `saved_prompts_deleted_undo_1280x800` | D 0.30 | Intended | R5 accent tertiary text buttons (4e49ccde); copy change (actions name their target / plainer words) (Saved prompts subtitle); P10.1/P10.2 conversation menu + one command sheet (34353c2f) |
| saved_prompts | `saved_prompts_deleted_undo` | D 0.21 | Intended | R5 accent tertiary text buttons (4e49ccde); copy change (actions name their target / plainer words) (Saved prompts subtitle); P10.1/P10.2 conversation menu + one command sheet (34353c2f) |
| saved_prompts | `saved_prompts_older_draft_1280x800` | D 0.30 | Intended | R5 accent tertiary text buttons (4e49ccde); copy change (actions name their target / plainer words) (Saved prompts subtitle); P10.1/P10.2 conversation menu + one command sheet (34353c2f) |
| saved_prompts | `saved_prompts_older_draft` | D 0.14 | Intended | R5 accent tertiary text buttons (4e49ccde); copy change (actions name their target / plainer words) (Saved prompts subtitle); P10.1/P10.2 conversation menu + one command sheet (34353c2f) |
| saved_prompts | `saved_prompts_older_drafts_full` | D 0.26 | Intended | R5 accent tertiary text buttons (4e49ccde); copy change (actions name their target / plainer words) (Saved prompts subtitle); P10.1/P10.2 conversation menu + one command sheet (34353c2f) |
| saved_prompts | `saved_prompts_restored_undo_1280x800` | D 3.58 | Intended | composer: one trailing control, editor in field corner (23f2d0ce); P4.4 accessories (74412bb5); R5 accent tertiary text buttons (4e49ccde); P10.1/P10.2 conversation menu + one command sheet (34353c2f) |
| saved_prompts | `saved_prompts_restored_undo` | D 7.09 | Intended | composer: one trailing control, editor in field corner (23f2d0ce); P4.4 accessories (74412bb5); R5 accent tertiary text buttons (4e49ccde); P10.1/P10.2 conversation menu + one command sheet (34353c2f) |
| screen_chat_1 | `chat_demo_ready` | D 5.88 L 5.88 | Intended | composer: one trailing control, editor in field corner (23f2d0ce); P4.4 accessories (74412bb5); R16 pages say things once (253a6919) |
| screen_chat_1 | `chat_running_work_sheet_empty` | D 0.06 | Intended | R2/P3.11a pinned sheet actions (24be364a, 00cafa13) |
| screen_chat_1 | `chat_session_context_loaded` | D 8.63 L 8.63 | Intended | R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_chat_1 | `chat_session_destination_sheet_move_1280x800` | D 0.03 | Intended | R2/P3.11a pinned sheet actions (24be364a, 00cafa13) |
| screen_chat_1 | `chat_session_destination_sheet_move` | D 0.13 | Intended | R2/P3.11a pinned sheet actions (24be364a, 00cafa13) |
| screen_chat_1 | `chat_session_destination_sheet_warp` | D 0.82 | Intended | copy change (actions name their target / plainer words) 'Move to the cloud' (5f5d957f) |
| screen_chat_1 | `settings_console_organization_sheet_loaded` | D 10.11 | Intended | R2/P3.11a pinned sheet actions (24be364a, 00cafa13); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_chat_1 | `settings_console_organization_switch_dialog_confirming` | D  | Intended | R2/P3.11a pinned sheet actions (24be364a, 00cafa13); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_chat_1 | `terminal_shell_output_running` | D 4.70 L 4.70 | Intended | R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_chat_1 | `terminal_shell_output_timeout_sheet` | D 5.28 L 4.93 | Intended | R6 Current only on a current-but-unselected choice (24840cc8); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_chat_2 | `chat2_active_context` | D 14.01 L 13.72 | Intended | R16 pages say things once (253a6919) |
| screen_chat_2 | `chat2_active_context_message` | D 1.60 L 1.60 | Intended | R16 pages say things once (253a6919) |
| screen_chat_2 | `chat2_session_note_1280x800` | D 16.13 L 16.13 | Intended | R16 pages say things once (253a6919); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_chat_2 | `chat2_session_note` | D 5.24 L 5.24 | Intended | R16 pages say things once (253a6919); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_chat_2 | `chat2_session_note_discard` | D 0.06 | Intended | R16 pages say things once (253a6919); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_chat_2 | `chat2_session_relations` | D 16.44 | Intended | R4 row groups on one inset / section label spacing (ba9d7088); copy change (actions name their target / plainer words) (Continue ... on computer, P3.11a) |
| screen_chat_2 | `chat2_session_relations_menu` | D 15.89 L 15.89 | Intended | R4 row groups on one inset / section label spacing (ba9d7088); copy change (actions name their target / plainer words) (Continue ... on computer, P3.11a) |
| screen_chat_2 | `chat2_web_sources_1280x800` | D 18.49 L 18.49 | Intended | R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_chat_2 | `chat2_web_sources` | D 11.12 | Intended | R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_chat_3 | `chat_session_export_choice_1280x800` | D 14.62 L 14.58 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_chat_3 | `chat_session_export_choice` | D 0.53 L 0.53 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_chat_3 | `chat_session_export_downloading` | D 0.08 L 0.08 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_chat_3 | `chat_session_export_saved` | D 0.53 L 0.53 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_chat_3 | `chat_session_export_save_failed` | D 0.53 L 0.53 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_chat_3 | `chat_session_export_unredacted` | D 0.53 L 0.53 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_chat_3 | `chat_session_export_unsupported` | D 0.82 L 0.44 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_library_1 | `library_integrations_connect_method_sheet` | D 0.73 L 0.41 | Intended | R18 one reload, no dead rows (c0efb78c): provider count subtitle gone; R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_1 | `library_integrations_disconnect_sheet` | D 0.73 L 0.41 | Intended | R18 one reload, no dead rows (c0efb78c): provider count subtitle gone; R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_1 | `library_integrations_loaded_1280x800` | D 7.52 L 7.53 | Intended | R18 one reload, no dead rows (c0efb78c): provider count subtitle gone; R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_1 | `library_integrations_loaded` | D 17.85 L 17.85 | Intended | R18 one reload, no dead rows (c0efb78c): provider count subtitle gone; R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_1 | `library_integrations_mcp` | D 2.48 L 2.48 | Intended | R18 one reload, no dead rows (c0efb78c): provider count subtitle gone; R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_1 | `library_integrations_mcp_menu` | D 10.86 L 7.17 | Intended | R18 one reload, no dead rows (c0efb78c); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_library_1 | `library_integrations_oauth_inputs_sheet` | D 0.79 L 0.41 | Intended | R18 one reload, no dead rows (c0efb78c): provider count subtitle gone; R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_1 | `library_integrations_sign_in_sheet` | D 2.48 L 2.46 | Intended | R18 one reload, no dead rows (c0efb78c): provider count subtitle gone; R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_1 | `library_integrations_unavailable` | D 0.36 L 0.36 | Intended | R18 one reload, no dead rows (c0efb78c): provider count subtitle gone; R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_2 | `library2_add_agent_checked` | D 18.41 | Intended | R18 one reload, no dead rows (c0efb78c) |
| screen_library_2 | `library2_capabilities_tools_unavailable_1280x800` | D  L  | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_2 | `library2_capabilities_tools_unavailable` | D 0.45 L 0.45 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_2 | `library2_capabilities_unavailable` | D 0.45 L 0.45 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_2 | `library2_external_agent_detail` | D 13.86 L 13.86 | Intended | R18 one reload, no dead rows (c0efb78c); R16 pages say things once (253a6919) |
| screen_library_2 | `library2_external_agents_empty` | D 0.29 L 0.29 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_2 | `library2_external_agents_list` | D 0.31 L 0.29 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_2 | `library2_external_agents_remove_sheet` | D 0.36 L 0.29 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_2 | `library2_external_task_draft` | D 1.26 L 1.26 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_2 | `library2_external_task_reply` | D 1.13 L 0.86 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_2 | `library2_external_task_stop_sheet` | D 6.57 L 6.57 | Intended | copy change (actions name their target / plainer words) (stop names the task); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_2 | `library2_mcp_setup_unavailable` | D 5.44 L 5.44 | Intended | copy change (actions name their target / plainer words); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_3 | `library_credential_management_remove_sheet` | D 0.70 L 0.70 | Intended | copy change (actions name their target / plainer words) ('Remove Anthropic account') |
| screen_library_3 | `library_integrations_pending_auth` | D 1.15 L 0.83 | Intended | G17 attention roles: amber only for needs-you (1dc1dae8); R18 one reload, no dead rows (c0efb78c) |
| screen_library_3 | `library_tools_detail_sheet` | D 10.28 L 3.29 | Intended | R18 one reload, no dead rows (c0efb78c); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_library_3 | `library_tools_loaded` | D 0.43 L 0.40 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_3 | `settings_plugins_loaded_1280x800` | D 3.06 L 3.06 | Intended | team-g17: discovery on the Plugins row (4334ce0c); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_library_3 | `settings_plugins_loaded` | D 4.87 L 4.86 | Intended | team-g17: discovery on the Plugins row (4334ce0c); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_library_4 | `library_commands_failed` | D 11.29 L 11.29 | Intended | P10.1/P10.2 conversation menu + one command sheet (34353c2f) |
| screen_library_4 | `library_commands_loaded_1280x800` | D 26.53 L 26.54 | Intended | P10.1/P10.2 conversation menu + one command sheet (34353c2f) |
| screen_library_4 | `library_commands_loaded` | D 27.71 L 27.71 | Intended | P10.1/P10.2 conversation menu + one command sheet (34353c2f) |
| screen_library_4 | `library_references_empty` | D 0.21 L 0.22 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_4 | `library_references_loaded` | D 0.24 L 0.22 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_4 | `library_references_sheet` | D 0.29 L 0.21 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_4 | `library_skill_sheet_add_failed` | D 8.89 L 8.83 | Intended | R3 code block without empty header band (e55a23f9) |
| screen_library_4 | `library_skills_loaded_1280x800` | D 11.20 L 10.85 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_library_4 | `library_skills_loaded` | D 0.14 L 0.12 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_phone_1 | `phone_setup_start_ready_other_ways` | D 0.28 L 0.26 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R9 dark text3 8A8D94->8C8F96, invisible (0c3f5718) |
| screen_phone_1 | `phone_setup_start_stopped` | D 1.17 L 0.26 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R9 dark text3 8A8D94->8C8F96, invisible (0c3f5718) |
| screen_phone_1 | `phone_setup_welcome_stopped` | D 0.19 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R9 dark text3 8A8D94->8C8F96, invisible (0c3f5718) |
| screen_phone_1 | `phone_this_phone_details_log` | D 10.26 L 9.46 | Intended | R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_phone_1 | `phone_this_phone_not_set_up` | D 0.21 L 0.21 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R9 dark text3 8A8D94->8C8F96, invisible (0c3f5718) |
| screen_phone_2 | `phone_setup_progress_running_1280x800` | D 10.88 L 10.88 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_phone_2 | `phone_setup_progress_stop_sheet` | D 0.11 | Intended | R9 dark text3 8A8D94->8C8F96, invisible (0c3f5718) |
| screen_review_1 | `review_workspace_comment_sheet` | D 12.74 L 10.36 | Intended | P3.7a one diff component (d4f01730); R2/P3.11a pinned sheet actions (24be364a, 00cafa13) |
| screen_review_1 | `review_workspace_empty` | D 0.30 L 0.30 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_review_1 | `review_workspace_error` | D 5.84 L 5.84 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_review_1 | `review_workspace_loaded` | D 55.37 L 53.09 | Intended | P3.7a one diff component (d4f01730) |
| screen_review_2 | `review_run_result_finished_1280x800` | D 15.75 L 15.75 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_review_2 | `review_run_result_finished` | D 0.85 L 0.70 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_review_2 | `review_run_result_finished_text2` | D 3.00 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_review_2 | `review_run_result_running` | D 0.84 L 0.70 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_review_2 | `review_staged_revert_confirm_sheet_keep` | D 1.82 L 1.76 | Intended | copy change (actions name their target / plainer words) ('Delete hidden messages forever?'); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_review_2 | `review_staged_revert_done` | D 0.30 L 0.30 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_review_2 | `review_staged_revert_staged_1280x800` | D 13.07 L 13.07 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_review_2 | `review_staged_revert_staged` | D 0.70 L 0.69 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_review_2 | `review_staged_revert_staged_text2` | D 2.60 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_review_2 | `review_stage_revert_sheet_ready` | D 3.77 | Intended | R2/P3.11a pinned sheet actions (24be364a, 00cafa13); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_servers_2 | `servers_pairing_scanner_blocked` | D 0.34 L 0.34 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_servers_2 | `servers_pairing_scanner_denied_1280x800` | D 9.47 L 9.47 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_servers_2 | `servers_pairing_scanner_denied` | D 0.34 L 0.34 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_servers_2 | `servers_pairing_scanner_no_camera` | D 0.34 L 0.34 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_servers_2 | `servers_pairing_scanner_starting` | D 0.34 L 0.34 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_servers_2 | `servers_profile_monitor_switch_server_dialog_confirm` | D  | Intended | R9 dark text3 8A8D94->8C8F96, invisible (0c3f5718) |
| screen_settings_1 | `settings_appearance_loaded_1280x800` | D 19.77 | Intended | R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_settings_1 | `settings_appearance_loaded` | D 25.67 L 24.81 | Intended | R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_settings_1 | `settings_hub_loaded` | D 0.65 L 0.65 | Intended | Model row names the server default (P3.10 Settings IA); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_settings_1 | `settings_privacy_clear_drafts_sheet_confirming` | D 16.67 L  | Intended | copy change (actions name their target / plainer words) ('Privacy and data', 'Privacy policy'); R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_settings_1 | `settings_privacy_loaded_1280x800` | D 12.43 | Intended | copy change (actions name their target / plainer words) ('Privacy and data', 'Privacy policy'); R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_settings_1 | `settings_privacy_loaded` | D 16.63 L 16.63 | Intended | copy change (actions name their target / plainer words) ('Privacy and data', 'Privacy policy'); R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_shell_1 | `shell_activity_empty` | D 0.11 L 0.11 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_shell_1 | `shell_activity_waiting` | D 0.13 L 0.11 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_shell_1 | `shell_question_sheet_unanswered` | D 16.67 L 0.25 | Intended | R2/P3.11a pinned sheet actions (24be364a, 00cafa13): Send pinned at the bottom |
| screen_system_1 | `system_keep_running_1280x800` | L 15.62 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_system_1 | `system_keep_running` | D 0.69 L 0.58 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_system_1 | `system_keep_running_set` | D 0.58 L 0.58 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_system_1 | `system_server_capabilities_1280x800` | D 16.76 | Intended | R16 pages say things once (253a6919) |
| screen_system_1 | `system_server_capabilities` | D 19.26 L 19.26 | Intended | R16 pages say things once (253a6919) |
| screen_system_2 | `system_shorebird_update_notice_ready_1280x800` | D 9.48 L 9.48 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_system_2 | `system_shorebird_update_notice_ready` | D 0.11 L 0.11 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_team_1 | `team_intro_computer_1280x800` | D 14.92 L 14.92 | Intended | header says Off (P3.4 d42ba768); R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_team_1 | `team_intro_computer` | D 15.00 L 14.98 | Intended | header says Off (P3.4 d42ba768); R4 row groups on one inset / section label spacing (ba9d7088); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_team_1 | `team_intro_phone_1280x800` | D 17.25 L 16.15 | Fixed (fixture) + refreshed | FIXTURE: golden caught the P1.7 pre-flight loading rows; test now passes a capable device (fixed here); header says Off (P3.4 d42ba768); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_team_1 | `team_intro_phone` | D 25.81 L 24.68 | Fixed (fixture) + refreshed | FIXTURE: golden caught the P1.7 pre-flight loading rows; test now passes a capable device (fixed here); header says Off (P3.4 d42ba768); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_team_2 | `team_home_empty` | D 8.70 L 8.54 | Intended | P4.1c one request card (4cfbf10a); slice-close-team / P3.4 rows (47d9d881, d42ba768); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_team_2 | `team_home_loaded_1280x800` | D 17.11 L 17.11 | Intended | P4.1c one request card (4cfbf10a); slice-close-team / P3.4 rows (47d9d881, d42ba768); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_team_2 | `team_home_loaded` | D 28.32 L 28.32 | Intended | P4.1c one request card (4cfbf10a); slice-close-team / P3.4 rows (47d9d881, d42ba768); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_team_2 | `team_home_search` | D 42.01 L 42.01 | Intended | P4.4 one status line in the slot (781933fb); P4.1c one request card (4cfbf10a) |
| screen_team_2 | `team_start_run_1280x800` | D 9.56 L 9.55 | Intended | P6.1 default supervision comes from the automation policy: High (dff34356, 929be112); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_team_2 | `team_start_run` | D 1.34 L 0.71 | Intended | P6.1 default supervision comes from the automation policy: High (dff34356, 929be112); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_team_3 | `team_agents_list_1280x800` | D 14.74 L 14.74 | Intended | wake-all row replaces per-row Wake (P3.4 d42ba768); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_team_3 | `team_agents_list` | D 15.01 L 15.01 | Intended | wake-all row replaces per-row Wake (P3.4 d42ba768); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_terminal_1 | `terminal_list_empty` | D 0.99 L 0.88 | Intended | copy change (actions name their target / plainer words) 'No terminals yet' (c0efb78c); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_terminal_1 | `terminal_list_unavailable` | D 0.16 L 0.16 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_terminal_1 | `terminal_phone_not_set_up` | D 0.27 L 0.16 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_terminal_1 | `terminal_shell_sheet` | D 0.24 L 0.17 | Intended | R6 Current only on a current-but-unselected choice (24840cc8) |
| screen_terminal_1 | `terminal_surface_menu` | D 0.21 L 0.21 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_terminal_1 | `terminal_surface_open` | D 0.21 L 0.21 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_usage_1 | `agent_account_limit_reached` | D 0.53 | Intended | R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_usage_1 | `agent_account_signed_in` | D 0.53 | Intended | R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_usage_1 | `usage_stats_loaded_1280x800` | D 0.13 L 0.13 | Intended | R5 accent tertiary text buttons (4e49ccde); R1 flat toolbar, title on the gutter (9413f93d) |
| screen_voice_1 | `voice_notices_loaded_1280x800` | D 12.93 L 12.93 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_voice_1 | `voice_notices_loaded` | D 0.30 L 0.27 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_work_1 | `work_workspace_context_sheet` | D 75.63 L 64.29 | Intended | Moderate ambient fields (6ae40ca8) + crisp glass (2f96633b); Manage project + separate-copy rows left the project sheet (00cafa13, 47d9d881) |
| screen_work_1 | `work_workspace_delete_confirm` | D 50.90 | Intended | Moderate ambient fields (6ae40ca8) + crisp glass (2f96633b) |
| screen_work_1 | `work_workspace_empty` | D 91.07 | Intended | Moderate ambient fields (6ae40ca8) + crisp glass (2f96633b) |
| screen_work_1 | `work_workspace_folder_chooser` | D 85.68 L 86.25 | Intended | Moderate ambient fields (6ae40ca8) + crisp glass (2f96633b); R5 accent tertiary text buttons (4e49ccde) |
| screen_work_1 | `work_workspace_folder_chooser_error` | D 86.19 L 86.75 | Intended | Moderate ambient fields (6ae40ca8) + crisp glass (2f96633b); R5 accent tertiary text buttons (4e49ccde) |
| screen_work_1 | `work_workspace_loaded` | D 79.29 | Intended | Moderate ambient fields (6ae40ca8) + crisp glass (2f96633b) |
| screen_work_2 | `work_session_import_destination_sheet` | D 7.34 L 5.40 | Intended | R6 Current only on a current-but-unselected choice (24840cc8); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_work_2 | `work_session_import_empty` | D 0.89 L 0.53 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_work_2 | `work_session_import_error` | D 0.89 L 0.53 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_work_2 | `work_session_import_review_1280x800` | D 16.70 L 16.70 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_work_2 | `work_session_import_review` | D 0.77 L 0.69 | Intended | R1 flat toolbar, title on the gutter (9413f93d); R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_work_3 | `work_managed_workspaces_remove_sheet_typing_1280x800` | D  L  | Intended | copy change (actions name their target / plainer words) ('Remove environment') |
| screen_work_3 | `work_managed_workspaces_remove_sheet_typing` | D 0.31 L 0.31 | Intended | copy change (actions name their target / plainer words) ('Remove environment') |
| screen_work_4 | `work_development_services_confirm_sheet_stop` | D 0.66 L 0.61 | Intended | copy change (actions name their target / plainer words) ('Stop service') |
| screen_work_4 | `work_development_services_editor_sheet` | D 0.47 L 0.41 | Intended | R1 flat toolbar, title on the gutter (9413f93d); text cursor visible |
| screen_work_4 | `work_development_services_empty` | D 0.41 L 0.41 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_work_4 | `work_development_services_logs_sheet` | D 3.04 L 2.98 | Intended | R4 row groups on one inset / section label spacing (ba9d7088) |
| screen_work_4 | `work_development_services_running` | D 0.41 L 0.41 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_work_4 | `work_development_services_unsupported` | D 0.41 L 0.41 | Intended | R1 flat toolbar, title on the gutter (9413f93d) |
| screen_work_4 | `work_projects_one_folder` | D 0.51 L 0.51 | Intended | copy change (actions name their target / plainer words) ('Server uses one folder') |

## Commands

```bash
# find the failures (two chunks of the 37 files, in parallel slots)
tool/qa/machine_lock.sh test -- flutter test -j 2 <files>
# refresh after review, then confirm
tool/qa/machine_lock.sh test -- flutter test -j 2 --update-goldens <files>
tool/qa/machine_lock.sh test -- flutter test -j 2 <files>   # 350 + 401 passed
tool/qa/machine_lock.sh analyze -- flutter analyze test/revamp/screen_team_1_golden_test.dart   # clean
tool/qa/machine_lock.sh test -- flutter test test/golden_harness_test.dart test/kit_ratchet_test.dart   # G23, G16 pass
```
