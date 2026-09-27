# slice-P3.3 One model sheet (2026-09-27)

- Unit: `slice-P3.3` (wave 3, programme P3, CHAT lane). Branch `revamp/slice-P3.3`, base `05473fe1` (feat/phone-setup-v2).
- Finish line: Settings › Model and the composer chip open the same model-picker-sheet (default mode from Settings). Agent, thinking and options sit in its footer, and "providers not loaded" is a row in it, so no dialog opens over the sheet.
- Non-goal: no price tiers (P5.4).
- Also in this slice (owner of the chat library now): P3.1's blocked item, the context-capsule page, is removed; and the chat's error rows say plain words, with the server's text only under Details.

## 1. What changed, per page

| Page | Before | After |
|---|---|---|
| `model-picker-sheet` (`lib/ui/widgets/pickers.dart`) | "Your choice" group on top of the list (Thinking and Agent as expanding rows, "No model chosen" row); providers not loaded as a notice; the session note under the group; the primary enabled even with nothing chosen | The list comes first. Thinking and Agent are two chips in the sheet's **pinned footer**, above the apply action: `Thinking: High`, `Agent: Build`. Each opens a `KitMenu` anchored to the chip (checked choice; each agent says what it does, e.g. "Edits files and runs commands"). A model with one level has no Thinking chip; a server without agents has no Agent chip. Providers not loaded are one **row**, "Reload providers", with the reason in words ("Signed in to OpenAI, but the server has not loaded it yet, so its models cannot answer."); tapping it reloads. The session note is the sheet's subtitle ("Applies to this conversation's next turns.") and only shows from a conversation. With nothing chosen the primary is disabled with "Choose a model first."; with no catalog (loading, failed, no models) there is no primary. `focusAgent` opens the agent menu once the catalog has agents. |
| Doors | Composer chip, `/model`, a chat error's Choose model, Settings › Model, search | Unchanged: every door calls `showModelPicker`. Settings (hub → sheet, no catalog page) sets the default for new conversations (`Use Claude Opus 5.5 · Build`, or "Use for new conversations" on a server that owns the choice); the chat sets this conversation ("Use for this conversation"). The catalog screen was already deleted; no route to it remains. |
| `model-picker-sheet-agent-dialog`, `-options-dialog`, `-unloaded-providers-dialog` | Already gone from code (shared-chat-1); still in the UI ledger | Removed from the ledger; their jobs are the footer chips, the details under the chosen row, and the Reload row. |
| `context-capsule` | `lib/ui/screens/context_capsule_screen.dart`, opened from the "+" sheet's More tools › "Notes for this conversation" | Deleted with `lib/domain/context_capsule.dart`, `_addContextCapsule` in `chat_screen.dart`, the `_PromptTool.contextCapsule` tool in `chat/composer.dart`, its tests (`test/context_capsule_test.dart`, `test/context_capsule_chat_test.dart`, `tool/capture/context_capsule_test.dart`), its census shots, its kit-ratchet baseline entries, its ledger page and the search-index exclusion. Its jobs stay reachable in the composer (target-ia §1.4): paste or type text into the message box, attach photos and files from "+". |
| Chat error copy (`chat/message_view.dart`, `chat/chat_states.dart`, `chat/attention_card.dart`) | An error the app did not recognise showed the server's first line as the headline ("Model not found: openai/x. Did you mean: …", "Context window exceeded"); a failed compaction appended the server's reason; a retry notice showed the server's reason | Headlines are words: the recognised cause, else what the error's kind means ("The server doesn't have this model.", "This conversation is too long for the model.", "The model provider needs you to sign in again.", "The reply reached the model's length limit.", "The provider's safety filter stopped this reply."), else "The agent stopped because of an error." The server's text is only under Error details / Details (the prompt-error line now always offers Details when there is text). A compaction failure and a retry notice add a reason only when the app recognises it. `productErrorText` calls in the chat are left to the app-wide sweep (revamp/no-raw-errors), which changes that function itself. |

Kit additions (a missing part goes into the kit):
- `KitSheet` / `showKitSheet`: `footer`, one short line of settings pinned above the actions (it brings its own space below it, so an empty footer takes no room). Documented in `docs/ux-system/kit-api/KitSheet.md`.
- `KitMenuItem.supporting`: one muted line under an item's label that says what choosing it means. Documented in `docs/ux-system/kit-api/KitMenu.md`.

Copy: added `modelPickerThinkingChip`, `modelPickerAgentChip` and six `chatError*` strings; reworded `e7ModelUiUnloadedProviders` (no quoted server error). Deleted 33 unused strings (the 19 `capsule*` strings, `composerToolNotesTitle`, `modelPickerYourChoice`, `modelPickerNoneChosen(Hint)`, `modelPickerThinkingExplain`, `modelPickerThinkingOneLevel`, `modelPickerAgentExplain`, `modelPickerDetailsContext`, `modelPickerModelId`, `modelChoiceProvidersTitle`, `modelChoiceProvidersSummary`, `modelChoiceStagedAgentHint`, `modelChoiceAgentTitle`, `modelDefaultMode`, `e7ModelUiNoAgents`) and their Arabic twins; gen-l10n run.

Ledger: `docs/design/ui-ledger/parts` edited (context-capsule page and its two entry elements gone; the three model-picker dialog pages gone; the sheet's purpose, Reload row, apply, and new Thinking and Agent footer elements) and `build_ledger.py` rebuilt (unresolved inbound 2, as on the base).

## 2. Tests

New: `test/revamp/slice_p3_3_model_sheet_test.dart` (8, all pass):
- Settings › Model opens the sheet for new conversations (real `SettingsScreen`, hub row → sheet): footer chips, pinned and hit-testable, "Use Claude Opus 5.5 · Build", no subtitle, no dialog.
- The composer chip opens the same sheet for this conversation (real `ChatScreen`): same footer, "Use for this conversation", the subtitle.
- Thinking opens as a menu and is staged until applied; each agent says what it does and subagents are not offered; a model with one level drops only the Thinking chip; with no model chosen the primary says why it waits; a 1280×800 window pins the same footer in the side sheet; providers not loaded are a row that reloads them (no "Model not found" text).

Changed expectations: `test/revamp/shared_chat_1_test.dart` (footer chips instead of "Your choice"; the Reload row; no thinking chip for a one-level model), `test/v2_transcript_rows_test.dart` (scope note is the sheet subtitle; a failed compaction no longer shows the server's reason), `test/session_selection_sync_test.dart` (comment), `test/chat_server_state_ui_test.dart` (error cards say words; the server's text is under Details), `test/model_picker_test.dart` (unloaded wording), `test/search_index_test.dart` (context-capsule exclusion gone), `test/support/e7_voice_model_arabic_fixture.dart` (deleted getter), `test/kit_ratchet_baseline.json` (capsule entries gone). Goldens regenerated: the ten `test/revamp/goldens/chat_model_picker_sheet_*` (model sheet only, `--plain-name "model sheet"`).

Runs (pinned Flutter 3.47.1), compared with the base in a second worktree (`oc_app-p33-base`):

| Batch | Files | New failures |
|---|---|---|
| A | shared_chat_1 (+golden), session_selection_sync, v2_transcript_rows, voice_model_localization, product_ui_regression, model_picker, search_index, kit_ratchet, kit menu and sheet tests and goldens, ui_glossary, chat_states_standard, chat_server_state_ui, chat_transcript_placement, revamp chat_1, kit_log_panel golden, ui_ledger_coverage, design_standard | 0 after the fixes above. Pre-existing on base and untouched: 24 of `model_picker_test` (it still drives the retired options dialog), 23 of `product_ui_regression_test`, `v2_transcript_rows` classic scope label, two `voice_model_localization` model-picker cases, `search_index` ledger coverage, `kit_ratchet` G17/G21, `chat_server_state_ui` "provider auth opens the providers screen" (KitScreen two-primaries assert), golden drift in other files. |
| B | chat_live_events, codex_chat_capabilities, prompt_shelf, ios_remote_platform_gating, web_search, calm_chat_disclosure, desktop_platform_gating, session_draft, settings_hub, plus a recheck of the new test, shared_chat_1 (+golden), session_selection_sync, kit sheet and menu tests and goldens, kit_ratchet, search_index | 0 after updating `chat_live_events` "a model-not-found session error shows one line and Choose model" (words on the line, the server's text under Details). Everything else failing in these files fails the same way on base. |

`flutter analyze`: no issues.

## 3. Images

Before = base goldens, after = this slice (dark):
- Phone 412×915: `before-model-sheet-loaded_dark.png` ("Your choice" on top) → `after-model-sheet-loaded_dark.png` (list first; Thinking and Agent chips pinned above "Use Claude Opus 5.5 · Build").
- Wide 1280×800 (side sheet): `before-model-sheet-loaded_1280x800_dark.png` → `after-model-sheet-loaded_1280x800_dark.png`.
- Agent choice: `before-model-sheet-details_dark.png` (agent row unfolded in the list) → `after-model-sheet-details_dark.png` (agent menu over the footer, each agent with its line).

## 4. Accessibility, privacy, migration

- Accessibility: the footer chips are 48 dp targets with a chevron and collapsed semantics; the menus are `KitMenu` (focus moves in from the keyboard, returns to the chip on close, checked semantics, the agent's line is read with its name). The Reload row is one button with the reason as its supporting text; while reloading it is disabled with "Loading model catalog". The disabled primary reads its reason.
- Privacy and security: server error text (which can carry paths and stack frames) is no longer the headline anywhere in the chat's error rows; it sits under Details.
- Migration: none. The context capsule stored nothing of its own (it wrote into the ordinary session draft).

## 5. Needs a device

- Proof asked by the unit: emulator screenshots of both doors (Settings › Model and the composer chip) showing the same sheet. Not taken here; the two widget tests above open it from the real Settings hub and the real chat screen.
- On a phone with the keyboard open over the search field: the footer and apply stay pinned above the keyboard.
- On an OpenCode 2 server: Settings says "Use for new conversations"; the chat says "Use for this conversation".
