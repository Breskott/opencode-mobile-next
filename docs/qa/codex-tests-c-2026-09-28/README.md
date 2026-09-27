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
| `text_scale_overflow_test.dart` | interrupted; rerun pending |
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
