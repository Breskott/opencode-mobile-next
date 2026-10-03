# Reviewed golden refresh — revamp second half (2026-09-28)

Slice `slice-goldens-revamp-b`, branch `revamp/slice-goldens-revamp-b`, base
`138f8216` (feat/phone-setup-v2). Scope: the second half of
`test/revamp/*golden*_test.dart` (37 files, listed below).

## Result

| | Count |
|---|---:|
| Failing goldens on the base | 111 |
| Intended, refreshed (reviewed image by image) | 99 |
| … of which behind a test-fixture regression fixed first | 16 (p66a 6, shell line 4, team page 6) |
| Base failures that match again after the fixture fixes | 4 |
| Product regression, handed off, goldens held back | 1 (8 goldens) |

Four of the 111 base failures disappeared once the fixtures were fixed
(`p66a_review_scope_1280x800_{dark,light}`,
`shell_embedded_connection_status_banner_phone_stopped_{dark,light}` match
their old goldens again).

After the refresh the 37 files run 455 passed, 1 skipped, 8 failed; the
8 failures are exactly the held-back goldens.

## Regressions found

1. **Kit (handed off, not fixed here — lib/ui/kit belongs to the kit lane):**
   `KitCodeBlock._buildHeader` since 98c064bd puts the caption in `Expanded`
   and a labelled copy action in a loose `Flexible` inside a
   `MainAxisAlignment.end` row. Each gets half the row; the copy uses less
   than its half and the rest is pushed to the start, so the caption no longer
   starts at the block's edge ("Terminal command" ~70 px in on the 1280
   Continue on computer sheet, "Link" ~44 px in on Open on another phone).
   Goldens held: `chat_continue_on_computer_sheet_available{,_1280x800}_{dark,light}`,
   `chat_continue_on_phone_sheet_qr{,_1280x800}_{dark,light}`. Hand-off in the
   lane notes with a fix idea. Sheet: [held-kit-code-header.png](held-kit-code-header.png).
2. **Test fixture — slice_p6_6a_defaults_golden_test:** the Work and Review
   shots lost the very notice they exist to show. 7c6d009c made
   `InteractionDefaultsStore` refuse a profile missing from `oc.profiles`; the
   golden's `SeededProfileStore` never writes that row, so `claimDefaultNotice`
   swallowed the refusal. The product is fine (the app's ProfileStore writes
   the row; `slice_p6_6a_defaults_test` passes). Fixed: the shot seeds
   `oc.profiles` and asserts the notice text before the golden.
3. **Test fixture — shared_shell_1_golden_test:** the connection-line shots
   were empty pages: since 3d64653c the line presents the controller's
   connection snapshot, which an isolated controller always hides. Fixed the
   same way `shared_shell_1_test` was (86c9cc16): a `shownStatus` override set
   to not-answering, plus an on-screen text assertion.
4. **Test fixture — slice_p34_golden_test:** the team page's request card
   (P4.1c) reads its age through `package:clock`, which in `testWidgets` is
   today's wall clock, while the scene is pinned to `teamSceneClock`: the
   golden said "waiting 16 d 23 h" and would change every day. Fixed: each
   shot runs under `withClock(Clock.fixed(teamSceneClock))` ("waiting 12 min").

## For the owner to eyeball

- **Team page, Android killed the team** (`team_v2_team_home_killed_light`,
  team-setup sheet): the page is now just the status line and its "Start the
  team again" action; the old contradictory "No AI team on this server" state
  is gone, but the body is empty (no last-known tasks).
- **Run result output** (`review_run_result_output_sheet_one_record_*`):
  terminal output is plain now (the old pass-line green tint is gone); it is
  the same kit code block the chat uses.
- **This phone** (this-phone sheet): "Move from Termux" is the first row of
  the maintenance group, above Update / Switch.
- **File preview on a wide window** (`file_preview_sheet_markdown_1280x800_*`):
  Attach to prompt sits on its own row under the name (R1's rule), even at
  1280 px.

## Contact sheets (before | after)

- [held-kit-code-header.png](held-kit-code-header.png)
- [p66a-defaults.png](p66a-defaults.png)
- [shell-connection-line.png](shell-connection-line.png)
- [team-page.png](team-page.png)
- [this-phone.png](this-phone.png)
- [files-review.png](files-review.png)
- [team-setup.png](team-setup.png)
- [kit-polish-and-copy.png](kit-polish-and-copy.png)

## Golden → verdict

| Golden | Diff | Verdict | Sheet |
|---|---:|---|---|
| `chat_continue_on_computer_sheet_available_1280x800_dark` | 0.47 % | REGRESSION (held, handed off) | [held-kit-code-header](held-kit-code-header.png) |
| `chat_continue_on_computer_sheet_available_1280x800_light` | 0.47 % | REGRESSION (held, handed off) | [held-kit-code-header](held-kit-code-header.png) |
| `chat_continue_on_computer_sheet_available_dark` | 8.57 % | REGRESSION (held, handed off) | [held-kit-code-header](held-kit-code-header.png) |
| `chat_continue_on_computer_sheet_available_light` | 8.58 % | REGRESSION (held, handed off) | [held-kit-code-header](held-kit-code-header.png) |
| `chat_continue_on_phone_sheet_qr_1280x800_dark` | 0.03 % | REGRESSION (held, handed off) | [held-kit-code-header](held-kit-code-header.png) |
| `chat_continue_on_phone_sheet_qr_1280x800_light` | 0.03 % | REGRESSION (held, handed off) | [held-kit-code-header](held-kit-code-header.png) |
| `chat_continue_on_phone_sheet_qr_dark` | 0.07 % | REGRESSION (held, handed off) | [held-kit-code-header](held-kit-code-header.png) |
| `chat_continue_on_phone_sheet_qr_light` | 0.07 % | REGRESSION (held, handed off) | [held-kit-code-header](held-kit-code-header.png) |
| `p66a_review_scope_dark` | 39.39 % | INTENDED after fixture fix | [p66a-defaults](p66a-defaults.png) |
| `p66a_review_scope_light` | 44.68 % | INTENDED after fixture fix | [p66a-defaults](p66a-defaults.png) |
| `p66a_work_project_1280x800_dark` | 78.85 % | INTENDED after fixture fix | [p66a-defaults](p66a-defaults.png) |
| `p66a_work_project_1280x800_light` | 77.82 % | INTENDED after fixture fix | [p66a-defaults](p66a-defaults.png) |
| `p66a_work_project_dark` | 91.24 % | INTENDED after fixture fix | [p66a-defaults](p66a-defaults.png) |
| `p66a_work_project_light` | 91.66 % | INTENDED after fixture fix | [p66a-defaults](p66a-defaults.png) |
| `shell_embedded_connection_status_banner_lost_1280x800_dark` | 0.13 % | INTENDED after fixture fix | [shell-connection-line](shell-connection-line.png) |
| `shell_embedded_connection_status_banner_lost_1280x800_light` | 0.13 % | INTENDED after fixture fix | [shell-connection-line](shell-connection-line.png) |
| `shell_embedded_connection_status_banner_lost_dark` | 0.36 % | INTENDED after fixture fix | [shell-connection-line](shell-connection-line.png) |
| `shell_embedded_connection_status_banner_lost_light` | 0.36 % | INTENDED after fixture fix | [shell-connection-line](shell-connection-line.png) |
| `slice_p34_team_page_heat_paused_1280x800_light` | 15.70 % | INTENDED after fixture fix | [team-page](team-page.png) |
| `slice_p34_team_page_heat_paused_light` | 28.60 % | INTENDED after fixture fix | [team-page](team-page.png) |
| `slice_p34_team_page_heat_stopped_light` | 28.66 % | INTENDED after fixture fix | [team-page](team-page.png) |
| `slice_p34_team_page_menu_light` | 27.41 % | INTENDED after fixture fix | [team-page](team-page.png) |
| `slice_p34_team_page_on_phone_1280x800_light` | 17.23 % | INTENDED after fixture fix | [team-page](team-page.png) |
| `slice_p34_team_page_on_phone_light` | 28.45 % | INTENDED after fixture fix | [team-page](team-page.png) |
| `close_servers_termux_script_failed_light` | 1.06 % | INTENDED | [this-phone](this-phone.png) |
| `close_servers_this_phone_install_failed_light` | 11.82 % | INTENDED | [this-phone](this-phone.png) |
| `close_servers_this_phone_start_failed_1280x800_light` | 4.02 % | INTENDED | [this-phone](this-phone.png) |
| `close_servers_this_phone_start_failed_light` | 13.04 % | INTENDED | [this-phone](this-phone.png) |
| `close_servers_this_phone_switch_stopped_light` | 14.32 % | INTENDED | [this-phone](this-phone.png) |
| `close_servers_this_phone_update_confirm_light` | 4.08 % | INTENDED | [this-phone](this-phone.png) |
| `close_servers_this_phone_up_to_date_1280x800_light` | 4.52 % | INTENDED | [this-phone](this-phone.png) |
| `close_servers_this_phone_up_to_date_light` | 12.97 % | INTENDED | [this-phone](this-phone.png) |
| `team_v2_this_phone_installed_light` | 18.21 % | INTENDED | [this-phone](this-phone.png) |
| `termux_v2_this_phone_light` | 28.29 % | INTENDED | [this-phone](this-phone.png) |
| `embedded_file_preview_body_json_dark` | 0.97 % | INTENDED | [files-review](files-review.png) |
| `embedded_file_preview_body_json_light` | 0.97 % | INTENDED | [files-review](files-review.png) |
| `embedded_file_preview_body_malformed_dark` | 0.12 % | INTENDED | [files-review](files-review.png) |
| `embedded_file_preview_body_malformed_light` | 0.12 % | INTENDED | [files-review](files-review.png) |
| `file_preview_sheet_binary_dark` | 1.61 % | INTENDED | [files-review](files-review.png) |
| `file_preview_sheet_binary_light` | 1.56 % | INTENDED | [files-review](files-review.png) |
| `file_preview_sheet_markdown_1280x800_dark` | 8.80 % | INTENDED | [files-review](files-review.png) |
| `file_preview_sheet_markdown_1280x800_light` | 3.36 % | INTENDED | [files-review](files-review.png) |
| `file_preview_sheet_unavailable_dark` | 1.51 % | INTENDED | [files-review](files-review.png) |
| `file_preview_sheet_unavailable_light` | 1.46 % | INTENDED | [files-review](files-review.png) |
| `review_run_result_loaded_1280x800_dark` | 0.16 % | INTENDED | [files-review](files-review.png) |
| `review_run_result_loaded_dark` | 0.44 % | INTENDED | [files-review](files-review.png) |
| `review_run_result_output_sheet_one_record_1280x800_dark` | 11.49 % | INTENDED | [files-review](files-review.png) |
| `review_run_result_output_sheet_one_record_1280x800_light` | 11.45 % | INTENDED | [files-review](files-review.png) |
| `review_run_result_output_sheet_one_record_dark` | 24.22 % | INTENDED | [files-review](files-review.png) |
| `review_run_result_output_sheet_one_record_light` | 24.12 % | INTENDED | [files-review](files-review.png) |
| `slice_p63_sheet_sending_light` | 1.25 % | INTENDED | [team-setup](team-setup.png) |
| `team_board_priority_sheet_dark` | 0.27 % | INTENDED | [team-setup](team-setup.png) |
| `team_board_priority_sheet_light` | 0.21 % | INTENDED | [team-setup](team-setup.png) |
| `team_phone_section_states_1280x800_dark` | 1.86 % | INTENDED | [team-setup](team-setup.png) |
| `team_phone_section_states_dark` | 4.92 % | INTENDED | [team-setup](team-setup.png) |
| `team_v2_intro_preflight_light` | 11.72 % | INTENDED | [team-setup](team-setup.png) |
| `team_v2_ready_done_1280x800_light` | 0.35 % | INTENDED | [team-setup](team-setup.png) |
| `team_v2_ready_done_light` | 0.95 % | INTENDED | [team-setup](team-setup.png) |
| `team_v2_ready_failed_light` | 0.25 % | INTENDED | [team-setup](team-setup.png) |
| `team_v2_setup_failed_report_light` | 0.25 % | INTENDED | [team-setup](team-setup.png) |
| `team_v2_team_home_killed_light` | 8.79 % | INTENDED | [team-setup](team-setup.png) |
| `chat_continue_on_computer_sheet_unavailable_dark` | 0.33 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `chat_continue_on_computer_sheet_unavailable_light` | 0.33 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `chat_model_picker_sheet_failed_dark` | 0.22 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `chat_model_picker_sheet_failed_light` | 0.22 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `chat_model_picker_sheet_loaded_1280x800_dark` | 0.03 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `chat_model_picker_sheet_loaded_1280x800_light` | 0.03 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `chat_model_picker_sheet_no_models_dark` | 0.42 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `chat_model_picker_sheet_no_models_light` | 0.42 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `chat_transcript_display_toggles_default_dark` | 0.06 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `other_servers_panel_1280x800_dark` | 0.10 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `other_servers_panel_dark` | 0.26 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `phone_remove_local_agents_confirm_sheet_confirming_dark` | 0.06 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `phone_restart_local_agents_sheet_busy_dark` | 0.06 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `phone_stop_local_agents_confirm_sheet_confirming_dark` | 0.06 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `servers_settings_disconnect_sheet_waiting_dark` | 0.06 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `server_switcher_sheet_1280x800_dark` | 0.13 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `server_switcher_sheet_dark` | 0.41 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `settings_language_sheet_loaded_1280x800_dark` | 0.27 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `settings_language_sheet_loaded_1280x800_light` | 0.27 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `settings_language_sheet_loaded_dark` | 0.78 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `settings_language_sheet_loaded_light` | 0.72 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `settings_theme_pack_preview_sheet_in_use_dark` | 0.06 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `settings_theme_pack_preview_sheet_other_dark` | 0.06 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `settings_theme_pack_preview_sheet_unavailable_dark` | 0.06 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `slice_p54_codex_answer_1280x800_dark` | 6.15 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `slice_p54_codex_answer_1280x800_light` | 6.14 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `slice_p54_spent_partial_1280x800_dark` | 0.13 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `slice_p54_spent_partial_1280x800_light` | 0.13 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `system_run_command_dialog_idle_dark` | 0.06 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `system_run_command_dialog_run_failed_dark` | 0.07 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `team_board_cancel_confirm_sheet_dark` | 0.06 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `team_board_move_sheet_1280x800_dark` | 0.01 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `team_board_move_sheet_dark` | 0.07 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `team_board_move_sheet_read_only_dark` | 0.06 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `team_phone_remove_sheet_1280x800_dark` | 0.06 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `team_phone_remove_sheet_1280x800_light` | 0.06 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `team_phone_remove_sheet_dark` | 0.17 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `team_phone_remove_sheet_light` | 0.17 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `team_phone_stop_sheet_1280x800_dark` | 0.06 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `team_phone_stop_sheet_dark` | 0.23 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `undo_delete_question_counted_dark` | 1.07 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `undo_delete_question_counted_light` | 1.07 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `work_new_conversation_sheet_all_1280x800_dark` | 0.18 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `work_new_conversation_sheet_all_1280x800_light` | 0.18 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `work_new_conversation_sheet_all_dark` | 10.93 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |
| `work_new_conversation_sheet_all_light` | 10.94 % | INTENDED | [kit-polish-and-copy](kit-polish-and-copy.png) |

- **held-kit-code-header** — REGRESSION (held, handed off): KitCodeBlock header caption pushed off the start edge by 98c064bd (Expanded name + loose Flexible labelled copy + MainAxisAlignment.end); kit lane. The `$` prompt with hanging wrap on the command is intended (KitCodeKind.command, R3).
- **p66a-defaults** — INTENDED after fixture fix: Test fixture regression fixed: the golden prefs lacked the saved profile row, so InteractionDefaultsStore admission (7c6d009c) refused and the "Opened FinanceHub3…" / "Showing Uncommitted…" notices vanished; test now seeds `oc.profiles` and asserts the notice. Remaining diffs: ambient fields (6ae40ca8), KIT-24 stacked scope choice (bd0ea2c9).
- **shell-connection-line** — INTENDED after fixture fix: Test fixture regression fixed: since 3d64653c an isolated controller's connection snapshot is hidden, so the shot rendered an empty page; the test now sets the not-answering snapshot (as shared_shell_1_test does) and asserts the line. Diff: P4.4 copy "Studio box isn't answering" (3d64653c). Phone-stopped shots now match the old goldens unchanged.
- **team-page** — INTENDED after fixture fix: Team gates on the one request card (P4.1c, 4cfbf10a): reason/age header, Details + Open conversation; ambient light fields (6ae40ca8). Test fixture regression fixed: the card's age read the real date ("waiting 16 d 23 h", a different image every day); the test now pins package:clock to teamSceneClock ("waiting 12 min").
- **this-phone** — INTENDED: "Move from Termux" row (slice-migration-ui 072f27f8 / a5cc3e80); Restart after a crash on by default with its limits (heal, 6ed0ec26); "Running now" row replaced by P5.3 (c0487f2c); setup log one line per line on a phone, Wrap toggle off (532494cf, ledger row 16).
- **files-review** — INTENDED: KitViewer body and header on the gutter, primary action on its own row (R1 9413f93d / 67059d74); code blocks without the empty header band (R3 e55a23f9); one text node per block changes glyph AA (G5, KitCodeBlock); run output: command and output as two kit code blocks with the outcome as the caption (chat-2 db11d2d9); 1-2 px pixel snapping (glass-crisp e74d28e9).
- **team-setup** — INTENDED: R5 accent tertiary actions (Report this failure, Run it on a computer; 4e49ccde); "AI Team" capitalised; header says Off/Stopped (P3.4 d42ba768, P6.3 fdcb99e8); R6 "Current" only when it differs from the selection (24840cc8); spinner token; row/section snapping.
- **kit-polish-and-copy** — INTENDED: Kit polish: R5 accent tertiary (Copy details, Filter), sheet handle/rim tone and pixel snapping (glass-crisp e74d28e9, sub-1 % colour on several dark sheets), 8 px top inset on usage; copy: "Try again" (no-raw-errors 6cdfca4e), "Provider sign-in needed" (5f5d957f G11/G28), "Can't read the saved password" (cred-status 76c934c6), "Delete hidden messages forever?" (5f5d957f), "Separate copy of shopfront" (close-team 47d9d881), R6 language "Current" + Arabic 62 % (24840cc8, 86c9cc16); caret shown in the focused run-command field.

## Commands

```bash
tool/qa/machine_lock.sh test -- flutter test -j 2 $(cat rv-b.txt)          # base: 352 passed, 111 failed (all pixel)
tool/qa/machine_lock.sh test -- flutter test test/revamp/slice_p6_6a_defaults_test.dart   # product behaviour: 12 passed
tool/qa/machine_lock.sh test -- flutter test -j 2 $(cat rv-b.txt)          # with fixture fixes: 107 failed (all pixel, reviewed)
tool/qa/machine_lock.sh test -- flutter test -j 2 --update-goldens $(cat rv-b.txt)
git checkout -- <the 8 held goldens>
tool/qa/machine_lock.sh test -- flutter test -j 2 $(cat rv-b.txt)          # 455 passed, 1 skipped, 8 failed (held)
```

Files (rv-b.txt): sessionlink_ui, shared_chat_1, shared_files_1,
shared_phone_1, shared_review_1, shared_servers_1, shared_settings_1,
shared_shell_1, shared_system_1, shared_team_1, slice_aisetup_review,
slice_close_chat, slice_close_servers_phone, slice_close_servers_termux,
slice_close_team, slice_inbox_work, slice_p10_3, slice_p2_4_5,
slice_p310_settings_ia, slice_p34, slice_p3_5, slice_p37a, slice_p4_1c,
slice_p4_5, slice_p5_1, slice_p52, slice_p54, slice_p63,
slice_p6_6a_defaults, slice_r12, slice_r15, slice_r17, slice_team_g17,
team_phone_v2, termux_v2_host, undo_from_here, voice_auto_setup
(`test/revamp/<name>_golden_test.dart`).
