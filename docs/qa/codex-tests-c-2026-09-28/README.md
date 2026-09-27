# Codex tests-c — 2026-09-28

Finish line: repair the assigned non-golden tests against the intentional September 27 UI changes; preserve meaningful failures for product-owner handoff. Non-goals: production edits, golden refresh, gate or baseline changes, publication.

## Prerequisite integration

Merged `feat/phone-setup-v2` at `dbac9c48` into `codex/tests-b` (previous head `93aab671`). The two conflicts were test-only resolutions:

- `team_controls_test.dart`: P3.6's worker conversation composer replaces the removed message sheet; the agent page offers one Open conversation action. Kept tests-b receipt, capability, manual-reassignment removal, and 320dp/2.5x layout checks. Dismiss the overflow menu before replacing its screen in the layout fixture.
- `builtin_server_autostart_test.dart`: kept both fake setup engines and the voice-device probe mock alongside incoming autostart checks.

Serial pinned-Flutter merge verification (`flutter test --no-pub --concurrency=1 <file>`): team_controls **31/31**, builtin_server_autostart **6/6**, kit_ratchet **34/34**, redaction **16/16**, ui_glossary **21/21**, no_raw_error_text **5/5**. Initial team-controls run was 29/31 because the fixture retained its open menu across screen replacement; corrected fixture rerun is 31/31. Logs: `/tmp/codex-tests-c/merge-*.jsonl`, `merge-final-team_controls.jsonl`.

The merge includes upstream product, baseline and image changes. This lane did not author those changes or regenerate images; subsequent tests-c edits are restricted to tests and this evidence record.

## Chat batch

Pending baseline and repairs. Four disjoint test groups; the lead owns serial execution and integration. Workers do not run Flutter or edit production files.

### Recovery checkpoint

The host crashed during the original serial baseline run. `8f94659e` and 13 uncommitted test edits survived; `/tmp/codex-tests-c` logs did not. The completed before counts below were captured before that crash (pass / fail / existing skip). The overflow matrix was in flight and is rerun in full. Current logs are stored on the persistent volume at `/home/eslam/Storage/tmp/codex-tests-c-20260928/`; `recovered-before-*` reruns untouched tests whose failure details were needed, and `after-*` validates repairs. No interrupted run is counted as a pass.

| File (`test/`) | Before pass / fail / skip |
|---|---:|
| `chat_live_events_test.dart` | 72 / 33 / 0 |
| `product_ui_regression_test.dart` | 5 / 22 / 0 |
| `stable_chat_layout_test.dart` | 3 / 7 / 0 |
| `chat_reference_send_test.dart` | 2 / 4 / 0 |
| `offline_queue_test.dart` | 52 / 5 / 0 |
| `chat_transcript_placement_test.dart` | 13 / 4 / 0 |
| `read_aloud_test.dart` | 7 / 1 / 0 |
| `desktop_context_menu_test.dart` | 4 / 1 / 0 |
| `context_capsule_chat_test.dart` | absent (deleted by P3.3) |
| `desktop_selection_test.dart` | 1 / 1 / 0 |
| `release_blockers_test.dart` | 19 / 4 / 0 |
| `codex_chat_capabilities_test.dart` | 6 / 3 / 0 |
| `chat_menu_hierarchy_test.dart` | 1 / 1 / 0 |
| `chat_server_state_ui_test.dart` | 8 / 1 / 0 |
| `chat_states_standard_test.dart` | 4 / 2 / 0 |
| `nudge_moments_test.dart` | 12 / 8 / 0 |
| `text_scale_overflow_test.dart` | 101 / 2 / 0 (recovered full run) |
| `voice_composer_test.dart` | 3 / 3 / 0 |
| `voice_model_localization_test.dart` | 7 / 2 / 0 |
| `voice_reply_pipeline_test.dart` | 0 / 20 / 3 |
| `pending_sends_strip_test.dart` | 11 / 5 / 0 |
| `model_picker_test.dart` | 3 / 23 / 0 |
| `transcript_search_test.dart` | 7 / 2 / 0 |
| `team_agent_chat_test.dart` | 5 / 0 / 0 |

### Product-owner handoff (confirmed, tests remain enabled)

- **Provider authentication recovery:** `lib/ui/screens/library/integrations_screen.dart:784`, `:1350`, `:1417` each build an inline error state with a primary retry action when providers, MCP and resources all fail to load. Opening Providers from the chat auth error (`chat_server_state_ui_test.dart`, provider-auth recovery scenario) trips the three-primary assertion at `lib/ui/kit/kit_screen.dart:652`. P3.3's QA record already identifies this pre-existing issue. Fix the page's action hierarchy; the gate is unchanged.
- **Permission plus approval tip:** `lib/ui/screens/chat_screen.dart:7006` (`_aboveComposer` Column) overflows its bottom by 43 pixels on the default 800×600 test viewport when the third same-kind permission request surfaces the approval tip. `nudge_moments_test.dart` scenarios “the third request of one kind points at Approvals” and “closing it removes it for good” both reproduce it. The no-overflow checks remain active; chat owner must fit the combined content.

### Verified repair checkpoint 1

Pinned serial per-file after runs: reference sends **6/6**, conversation menu hierarchy **2/2**, voice/model localization **9/9**. Reference sends now inspect the kit field's editor and combined visible draft warning; menu toggles use KitSwitchRow; localized model close waits for scrolling to finish. Payload, unsaved-reference, toggle and Arabic reachability assertions are retained. Other files are still under validation at this checkpoint.

Additional product issues exposed after restoring the interactions:

- **Missing load diagnostics:** `lib/ui/screens/chat/chat_states.dart:57` passes `productErrorText` to the error state's Details. In `chat_states_standard_test.dart`, “a conversation that could not load…” expects the original safe technical diagnostic under Details; it gets the friendly headline again. `productErrorDetails` is the documented diagnostic path. Final state-file check is **5 pass / 1 fail**.
- **Model sheet does not close with a search:** `lib/ui/widgets/pickers.dart:137` uses `maybePop` after applying. `lib/ui/kit/kit_search_field.dart:463` intercepts that pop while a query exists, clears it and leaves the sheet open. Both “model selector searches and persists…” and session-selection reopening retain their failed dismissal assertions.
- **Thinking-menu race:** `lib/ui/widgets/pickers.dart:395` resyncs an untouched draft after an external model change, but the open thinking menu still describes the previous model. Its callback at `:783` applies that previous model's variant to the new model. “the thinking menu keeps edits bound to the displayed model” retains its identity assertion.
- **Dismiss while model apply is pending:** `lib/ui/widgets/pickers.dart:142` disposes the apply notifiers when the sheet closes, while the exiting body can still finish `_applySelection`; its finally block at `:1331` calls `_setApplying` (`:412`) on the disposed notifier. The existing authorized-agent-choice/dismissal test remains enabled.

- **Home large-text toolbar:** `lib/ui/kit/kit_top_bar.dart:946` lays out the home context in a horizontal Row that overflows by 127 pixels on the 360×740, 2.5× home-shell scenario in `text_scale_overflow_test.dart`. The test now includes the original Flutter diagnostic as its failure reason, preserving the no-exception assertion.
- **MCP command destination:** the live-events `/mcps` command reaches IntegrationsScreen, where simultaneous MCP/resource load failures independently create retry primaries (`lib/ui/screens/library/integrations_screen.dart:1350`, `:1417`). This is the same page-action hierarchy defect as provider-auth recovery, with two sections instead of three; its navigation test remains enabled.

### Verified repair checkpoint 2

Transcript search **9/9**, Codex chat capabilities **9/9**, transcript placement **17/17**, read-aloud **8/8**. States **5/6** and nudges **18/20** now fail only on the technical-details loss and approval overflow listed above. Search still verifies highlighting without reparsing, capability tests require disabled attachment actions and no unsupported transports, placement preserves alignment and nonoverlap, and read-aloud preserves consent and background draft disposal.

### Verified repair checkpoint 3

Offline queue **57/57**, pending sends **16/16**, stable chat layout **10/10**, desktop context menus **5/5**, desktop selection **2/2**. These retain queue refusal/durable deletion/payload assertions, explicit default delivery and remembered choice, keyboard/draft/focus bounds, actual file opening and clipboard behavior, and desktop-wide versus phone reply-local selection. Fixtures now wait for the documented Undo window and finish menu/scroll animations before interacting; no warnings or timers are suppressed.

- **Completed context with unknown limit is treated as loading:** `lib/ui/screens/session_context_screen.dart:604` supplies null usage with a known 1,000-token value label. `lib/ui/kit/kit_progress_row.dart:156`, `:171` and `:423` classify null as loading and omit that known value. The live-events native context-destination assertion is retained.
- **Voice permission arrival creates two primary actions:** `lib/ui/screens/chat_screen.dart:7070` renders permission attention (`chat/permission_sheet.dart:168` → `kit_request_card.dart:1019` Allow), alongside voice controls at `chat_screen.dart:7203` (`chat/voice_conversation.dart:483` Listen). A permission while waiting for a spoken reply trips `kit_screen.dart:652`; `voice_reply_pipeline_test.dart` “late reply stays silent after approval” remains enabled.

### Verified repair checkpoint 4

Voice composer **6/6**, read-aloud **8/8**, nudges **18 pass / 2 product failures**. The compact voice fixtures now set the actual logical view size, check radio semantics at the merged accessible label, follow primary-first action layout, and open each bundled license viewer with localization delegates. Nudges still assert both reachable actions at 2.5× and preserve no-overflow checks. No consent, speech dispatch or background-revocation expectation was removed.

### Product UI handoff (final 23 pass / 4 fail)

- `lib/ui/kit/kit_undo.dart:229` inserts the Undo bar in the root overlay. `lib/ui/screens/files_screen.dart:1034` shows it after staging a file; reopening the changed-files sheet leaves that bar above the row. The actual hit-test path for `changed-file-lib/main.dart` reaches `files-staged-notice` / `_KitUndoBar` instead. “changes card opens the changed set…” retains its hit-testable assertion; waiting out Undo would conceal the obstruction.
- `lib/ui/kit/kit_search_field.dart:174` schedules the debounce; `:292` forwards IME submission without cancelling it. Both call `FilesScreen._onSearchChanged` at `lib/ui/screens/files_screen.dart:1209`, so typing `ProjectHealth` then submitting immediately issues the same query twice. “symbol search opens the exact source line…” keeps the single-request expectation.
- `lib/ui/screens/terminal_screen.dart:546` and `:555` reload after rename/remove completes without checking the captured location. The two stale-callback tests change workspace/repository while the operation is pending and observe an unwanted extra reload of the new location. Both original call-count guards remain.
