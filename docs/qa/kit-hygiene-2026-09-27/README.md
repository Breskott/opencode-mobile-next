# kit-hygiene — dead wrappers out, kit.dart complete (2026-09-27)

Unit `kit-hygiene` (docs/ux-system/revamp/work-units.json). Branch
`revamp/kit-hygiene`, rebased on `feat/phone-setup-v2` at d0a8abcc.

Finish line: every retired wrapper with no caller left is deleted, kit.dart
documents every part it exports and no longer re-exports product_states,
and the dead English strings are gone. Non-goal: moving live callers off the
wrappers that still have them (their slices own those files).

## What changed

**kit.dart**
- The `product_states.dart` re-export is gone. team/run_screen.dart, the
  one screen still taking `SectionLabel` through it, imports it directly.
  R13 had already moved project_health and managed_workspaces to
  KitSectionLabel.
- The doc table names every part the G4 manifest finds (58 rows were
  missing, plus the scenes, TerminalKeyBar, LiquidGlassFilter and the motion
  parts). G4 `docRow` is empty; its allowlist key and the `_byR4` docRow
  deferrals are removed.

**Deleted (no callers left)**
- `lib/ui/kit/kit_secret_field.dart` and `KitSecretField` in kit_field.dart,
  with its `_legacySecret` constructor and caller-label plumbing.
- `lib/ui/kit/kit_confirm_retired.dart` (`showConfirmSheet`) and
  `lib/ui/widgets/confirm_sheet.dart` (also held the unused
  `SwipeDeleteBackground`).
- `lib/ui/widgets/agent_color.dart`, `code_highlight.dart`,
  `glass_surface.dart`, `nudge_card.dart`, `team_board_tabs.dart`.
- `product_states.dart`: `LoadingList`, `ProductEmptyState`,
  `ProductErrorState`, `ProductInlineEmpty`, `ProductRefreshBody`, `GatedRow`,
  `GatedRowTile`, `gatedOnV2Explainer`.
- `question_options.dart`: `QuestionOptionRow`, `QuestionCustomAnswerField`.
- `markdown.dart`: `CodeBlock`, `looksLikeFilePath`.
- `terminal_view.dart`: `stripAnsi`.
- `team_board_card.dart`: `TeamBoardPriorityGlyph`. The move sheet draws
  `KitPriorityGlyph(priority: teamBoardKitPriority(p))`.
- `team/work_graph.dart`: `WorkGraphLayout`, `WorkGraphEdge`,
  `WorkGraphPainter` (tests use `KitWorkGraphGeometry.layers`).
- `team_discover.dart`: `@Deprecated TeamNewMode` (the last `@Deprecated`
  wrapper in lib/ui).

**product_states.dart stays.** It holds the shared error words
(`productErrorText`, `productErrorKind`, `productErrorDetails`,
`showProductError`), imported by about 55 files, including the chat
library, main.dart and the phone setup screens, which other slices own. It
also holds `SectionLabel` until its last two callers move: run_screen
(P3.5) and folder_browser. It is no longer a widget file. Renaming it (for example to
`lib/ui/product_errors.dart`) is a mechanical follow-up once those slices
merge.

**Still in use, so they wait for their slice**
| Wrapper | Callers | Cleared by |
|---|---|---|
| `widgets/diff_view.dart` | chat_screen, staged_revert_screen | slice-P3.7a |
| `TerminalView` (terminal_view.dart) | chat/message_view.dart | chat chain (P3.5 owners) |
| `MarkdownText`, `stripPathLineSuffix`, `markdownProseForSpeech` | chat library, agent_blocks | chat chain |
| `questionPrefersSheet` | chat/attention_card.dart | chat chain (a live helper, not a wrapper) |
| `WorkGraph`, `WorkGraphNode` | team/run_screen.dart | slice-P3.5 (retires RunScreen) |
| `TeamBoardCardView` | team/team_board_screen.dart | team board owner (unassigned; the app-to-kit mapping must stay outside the kit) |
| `SectionLabel` | team/run_screen.dart, widgets/folder_browser.dart | P3.5 for run_screen; folder_browser has no owner yet (a one-line move to KitSectionLabel) |
| `TeamReceiptChip` | — | already removed by P5.2 |
| `InfoLabel` | — | already deleted by P3.1 |

These have no callers left but sit outside this unit's write set. Nothing
references them, so their owners can delete them: `EntranceReveal`
(widgets/entrance.dart), `SessionLinkQr` (session_handoff_sheets.dart),
`ProviderMonogram` and `BrandTile` (provider_logo.dart), `TeamComposerField`
(team_controls.dart), `PermissionSheet` (chat/permission_sheet.dart, used
only by tests).

**Setup commands.** The placeholders in `lib/ui/setup_commands.dart` are
`OPENCODE_SERVER_PASSWORD=<your password>` and
`PASEO_PASSWORD=<a long password>`. The old bare-word and quoted samples
read as real secrets, so KitCodeBlock's secret guard threw at 320 dp/2.5x
(see `setup_commands_before_320.png`, Flutter's error screen). The docs
that print the same commands (docs/paseo-connection.md,
docs/technical-overview.md) match the new text.

**ARB sweep.** 1,001 English keys that nothing on the integration branch
uses were deleted from `lib/l10n/app_en.arb` (English only; app_ar.arb is
untouched), then gen-l10n was run. Kept: 9 unused keys that open slices'
diffs use (P3.5: defaultModelNotice, defaultModelChange, teamUiPhoneRemoved,
teamBoardAddFailed; P0.7: phoneServerCardRemoveBody,
phoneServerCardRemoveBodyUnmeasured, builtinServerRemoveBody; shared-chat-2:
formRendererUseTime, formRendererFinishLater). Also kept: 69 keys that only
tests or tools read.

**Gates**
- G4 (`test/kit/kit_manifest_test.dart`): passes. The allowlist lost its
  stale entries for the deleted parts and every docRow entry.
  `_deferredAtKitMerge` lost its 58 docRow lines and `_byR4`. kit-gates had
  already merged and its worktree was clean, so this edit collides with no
  open work.
- G16 ratchet (`test/kit_ratchet_test.dart`): passes. Counts only dropped.
- design_standard: the deleted nudge_card.dart left its migrated list and
  baseline.

## Tests

- New and changed behaviour tests re-point retired wrappers to the kit or
  to the real product path. Markdown code tests render fenced
  `MarkdownText`. Graph geometry tests use `KitWorkGraphGeometry`. The
  nudge layout test uses `KitNotice.offer` as the chat's nudge slot does.
  The error-state test uses `KitStateView.error`. Tests that only covered a
  deleted wrapper were deleted with it.
- 65 files were run, and the failures were compared with the base
  (6ea5e83c) in a second worktree. No failure is new. 16 base failures pass
  now (markdown_reading ×6, markdown_agent_blocks, markdown_streaming,
  chat_live_events, kit_motion G8x, nudge_moments load, and others). The
  remaining failures fail identically on the base: home_navigation,
  first_run_*, reader_preferences, chat_live_events, team goldens, and
  others.
- `flutter analyze`: no issues.

## Images

- `before_retired_product_states_rows_412.png`,
  `before_retired_product_states_rows_1280_dark.png`: the retired
  product-state wrappers' own goldens, deleted with them.
- `after_kit_state_view_error_412.png`,
  `after_kit_state_view_empty_1280_dark.png`: the kit part every screen
  already uses in their place.
- `setup_commands_before_{320,1280}.png` and
  `setup_commands_after_{320,1280}.png`: the setup commands in KitCodeBlock
  at 320 dp and 2.5x text, and at 1280. Before, it throws at 320 dp; after,
  it renders.

## Needs a device

Nothing. Every deleted part was unused in the app. No screen's look
changed except the setup commands' placeholder text.

## Merge notes

- The branch was rebased on d0a8abcc (after R4, R13, kit-gates and P5.2).
  The kit.dart doc table and kit/kit_overflow_scenes.dart, which R4 also
  changed, merged cleanly. gen-l10n was rerun on the rebased tree.

## Merge with the integration tip (2026-09-28)

`feat/phone-setup-v2` (dbac9c48: P3.5, P3.6, the Codex audit F1, kit-polish,
R13–R15, P10.4) was merged in, and the conflicts were resolved:
- `team/run_screen.dart` stays deleted (P3.5).
- `product_states.dart` keeps the audit's domain-owned error mapping
  (`ProductFailure`) and loses every widget. `SectionLabel`'s last caller,
  folder_browser.dart, now uses
  `KitSectionLabel(margin: EdgeInsets.zero, gapBefore: 0)`, so the file holds
  error words and the failed-act alert only.
- `team/work_graph.dart` keeps only `WorkGraphNode` (Task details maps its
  steps through it). The `WorkGraph` widget had no app caller left and is
  deleted. `test/team_work_graph_test.dart` draws `KitWorkGraph` (layers)
  through a local helper, and `test/team_work_tab_test.dart` keeps both
  sides: P3.5's Task details and this unit's geometry helper.
- More wrappers had no callers on the new tip and are deleted:
  `EntranceReveal` (entrance.dart), `TechnicalDirection`
  (technical_direction.dart), `SessionLinkQr`, `ProviderMonogram`,
  `BrandTile`, `TeamComposerField`, `workOwnerInitial`. Their tests now use
  `KitEntrance` and `KitLtr`; the wrapper-only tests were dropped.
- ARB sweep redone: 3 more keys deleted (teamControlsFieldUnavailable,
  productErrorRejectedBecause, teamUiPhoneRemoved). 5 unused keys are kept
  for open slices (P0.7, shared-chat-2).

Still in use after the merge: `diff_view.dart` (P3.7a); `TerminalView`,
`MarkdownText`, `stripPathLineSuffix`, `markdownProseForSpeech`,
`questionPrefersSheet` (chat library); `TeamBoardCardView`
(team_board_screen, no owner); `PermissionSheet` (only tests use it: 5 test
files and the census; left for the chat library owner).

Gates on the merge: kit_ratchet, kit_manifest (G4), redaction, ui_glossary,
no_raw_error_text and kit_draft_manifest pass, and `flutter analyze` is
clean. Four failures remain, the same on the tip: design_standard
"412x915 goldens" and three workspace_hierarchy tests.
