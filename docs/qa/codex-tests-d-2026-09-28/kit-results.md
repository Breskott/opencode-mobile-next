# Dedicated kit behavior verification

Each complete file ran with the pinned SDK using `flutter test --no-pub -j 1 --reporter expanded <file>`. These contain no golden comparisons. Focused reruns replace earlier failed runs after fixture repairs; no extra settling frames or new baselines were added. Logs remain locally in `.dart_tool/tests-d/`.

| File | Passed | Failed | Final local log |
|---|---:|---:|---|
| `test/kit/kit_agent_strip_test.dart` | 16 | 0 | `kit_agent_strip_test.dedicated.log` |
| `test/kit/kit_board_lane_test.dart` | 24 | 2 | `kit_board_lane_test.final.log` |
| `test/kit/kit_breadcrumb_test.dart` | 13 | 0 | `kit_breadcrumb_test.dedicated.log` |
| `test/kit/kit_capability_explainer_test.dart` | 45 | 0 | `kit_capability_explainer_test.dedicated.log` |
| `test/kit/kit_checklist_test.dart` | 22 | 0 | `kit_checklist_test.dedicated.log` |
| `test/kit/kit_choice_list_test.dart` | 42 | 0 | `kit_choice_list_test.final.log` |
| `test/kit/kit_code_block_test.dart` | 32 | 0 | `kit_code_block_test.dedicated.log` |
| `test/kit/kit_composer_chips_test.dart` | 49 | 0 | `kit_composer_chips_test.dedicated.log` |
| `test/kit/kit_composer_test.dart` | 49 | 1 | `kit_composer_test.dedicated.log` |
| `test/kit/kit_context_region_test.dart` | 4 | 0 | `kit_context_region_test.dedicated.log` |
| `test/kit/kit_date_time_picker_test.dart` | 53 | 2 | `kit_date_time_picker_test.final.log` |
| `test/kit/kit_details_fold_test.dart` | 39 | 0 | `kit_details_fold_test.dedicated.log` |
| `test/kit/kit_dialog_test.dart` | 46 | 0 | `kit_dialog_test.dedicated.log` |
| `test/kit/kit_diff_view_test.dart` | 50 | 0 | `kit_diff_view_test.final.log` |
| `test/kit/kit_group_note_test.dart` | 7 | 0 | `kit_group_note_test.dedicated.log` |
| `test/kit/kit_jump_pill_test.dart` | 27 | 0 | `kit_jump_pill_test.dedicated.log` |
| `test/kit/kit_log_panel_test.dart` | 23 | 0 | `kit_log_panel_test.dedicated.log` |
| `test/kit/kit_manifest_test.dart` | 3 | 0 | `kit_manifest_test.final.log` |
| `test/kit/kit_markdown_test.dart` | 22 | 0 | `kit_markdown_test.dedicated.log` |
| `test/kit/kit_message_test.dart` | 32 | 0 | `kit_message_test.dedicated.log` |
| `test/kit/kit_nav_test.dart` | 25 | 0 | `kit_nav_test.dedicated.log` |
| `test/kit/kit_progress_row_test.dart` | 22 | 0 | `kit_progress_row_test.dedicated.log` |
| `test/kit/kit_queued_message_test.dart` | 22 | 0 | `kit_queued_message_test.dedicated.log` |
| `test/kit/kit_receipt_test.dart` | 45 | 0 | `kit_receipt_test.dedicated.log` |
| `test/kit/kit_request_sheet_test.dart` | 36 | 3 | `kit_request_sheet_test.final.log` |
| `test/kit/kit_scanner_test.dart` | 19 | 0 | `kit_scanner_test.dedicated.log` |
| `test/kit/kit_scrollbar_test.dart` | 10 | 0 | `kit_scrollbar_test.dedicated.log` |
| `test/kit/kit_search_field_test.dart` | 21 | 0 | `kit_search_field_test.dedicated.log` |
| `test/kit/kit_segmented_test.dart` | 66 | 0 | `kit_segmented_test.final.log` |
| `test/kit/kit_status_line_test.dart` | 20 | 0 | `kit_status_line_test.dedicated.log` |
| `test/kit/kit_status_slot_test.dart` | 17 | 0 | `kit_status_slot_test.dedicated.log` |
| `test/kit/kit_tab_switcher_test.dart` | 47 | 0 | `kit_tab_switcher_test.dedicated.log` |
| `test/kit/kit_task_card_test.dart` | 28 | 0 | `kit_task_card_test.dedicated.log` |
| `test/kit/kit_tool_row_test.dart` | 52 | 0 | `kit_tool_row_test.dedicated.log` |
| `test/kit/kit_top_bar_test.dart` | 26 | 0 | `kit_top_bar_test.dedicated.log` |
| `test/kit/kit_turn_test.dart` | 27 | 0 | `kit_turn_test.final.log` |
| `test/kit/kit_viewer_test.dart` | 30 | 0 | `kit_viewer_test.dedicated.log` |
| `test/kit/kit_work_graph_test.dart` | 34 | 0 | `kit_work_graph_test.dedicated.log` |
| `test/kit/kit_work_line_test.dart` | 44 | 0 | `kit_work_line_test.dedicated.log` |
| `test/kit/kit_page_route_test.dart` | 13 | 0 | `kit_page_route_test.dedicated.log` |

Total: **1202 passed / 8 failed**, 40 files.

Remaining strict failures and source locations are explained in [README.md](README.md). KitSegmented production and its dedicated test file were left unchanged; the complete dedicated file was rerun to confirm its original behavior after assessing the separate KIT-24 integration gap.
