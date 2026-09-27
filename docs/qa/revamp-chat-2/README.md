# revamp-chat-2: Chat parts: tool rows and the task view (2026-09-27)

## 1. Scope

- Unit: `chat-2` (wave 2c, tier 2, screen revamp). Finish line: every file in the write set is kit-only (G1, G2, G7, G16, G17, G21 all 0), the two pages are handled by their map proposal ("fix") in the visual language, and ToolCard's public API stays (run_result_view.dart and tool/capture still compile). Non-goal: no gateway call, controller field or persistence; the host wiring of the two new optional ToolCard hooks is left to the chat library's owner.
- Files changed: `lib/ui/widgets/tool_card.dart`, `lib/ui/widgets/mobile_task_view.dart`, `lib/ui/widgets/transcript_highlight.dart`, new `lib/ui/kit/chat/kit_find_mark.dart`, `lib/l10n/app_en.arb` (+ generated), `test/tool_card_test.dart`, `test/mobile_task_view_test.dart`, new `test/revamp/chat_2_test.dart`, new `test/revamp/chat_2_golden_test.dart` and 20 PNGs under `test/revamp/goldens/chat_{tool,task,find}_*`. `lib/ui/kit/chat/kit_tool_row.dart` is in the write set but needed no change.
- Pages (map ids): `embedded-tool-card`, `embedded-mobile-task-list`.
- Specs followed: STANDARDS.md MAP-1, KIT-1, KIT-3, KIT-23, KIT-32, KIT-41, KIT-43, LOOK-1, LOOK-5, LOOK-12, LOOK-14, STATE-9, STATE-16, AUTO-15, PERF-2; kit-api KitToolRow.md (host adapter, cap at 12, one indent level); visual-language §5 (transcript: a code block with a file header, `+n −n` and copy).
- Contract problems (PROC-20):
  - Record folder: STANDARDS EVID-1 names `docs/qa/revamp-<unit id>-<date>/`, the unit's task text names `docs/qa/revamp-<unit id>/`. Followed the task text (as chat-1 did). Blocks nothing.
  - Copy: the task's hard rules still say "app_en.arb AND app_ar.arb"; the owner decision of 2026-09-27 (later, wins) drops Arabic. New keys are in app_en.arb only.
  - KitToolRow.md says "`mobile_task_view.dart` moves to KitChecklist". KitChecklist has no stopped/cancelled mark (a cancelled task would read "Waiting"), it announces a job live region ("Step 3 of 7") and carries job actions (Stop, Resume, cost). The plan is built from KitRow + KitTaskMark instead — the team's step mark, which is what the map's `sameJobElsewhere` asks to match. Proposed text: "moves to KitRow rows with KitTaskMark (or KitChecklist once it has a stopped state and a non-live mode)".
- New kit parts (KIT-3): `KitFindMark` (`lib/ui/kit/chat/kit_find_mark.dart`) — the find-in-conversation mark: a span style that paints only an accent wash (passive .18, active .38, the same wash KitCodeBlock.fill uses) and never a text colour. Needed because TextStyle construction is G21-counted outside the kit; the coordinator owns its contract and the kit.dart export.
- Map items (EVID-11):
  - embedded-tool-card, statesMissing "long shell output capped like edits" → done: `test/tool_card_test.dart` "long output is capped at 12 lines with Open full output"; golden `chat_tool_shell_open_*`.
  - embedded-tool-card, statesMissing "waiting for permission (shows running)" → done in the adapter: `ToolCard.waitingForYou` and running `question` tools read "Waiting for you" with no spinner (`test/tool_card_test.dart` "a call blocked on the person says Waiting for you, no spinner"; golden `chat_tool_steps_*`, row 4). Host wiring (pass `waitingForYou` when a pending permission's `tool.callID` matches the part) → deferred to the chat library owner (chat_screen.dart + chat/*.dart, single-owner; not in this write set).
  - embedded-tool-card, actionsMissing "copy output" → done: every output is a KitCodeBlock with the kit copy of the whole text (`test/tool_card_test.dart` "copying output uses the kit copy of the whole text"); the command has its own "Copy command".
  - embedded-tool-card, actionsMissing "rerun command" → done in the adapter: `ToolCard.onRerunCommand` shows "Run this command again" (`test/tool_card_test.dart` "Run this command again appears only when the host offers it"). Host wiring (what a rerun sends) → deferred to the chat library owner; hidden until then, never a dead button.
  - embedded-tool-card, infoMissing "Passed/Failed in words" → done: caption "Passed · exit code 0" / "Failed · exit code 1", and a non-zero exit is a Failed step. "+n −m summary" → done: `+6 −2` on the line (KitToolRow counts), and in the diff header.
  - embedded-tool-card, owner fix "plain subagent card ('Delegated to explore · Done') that matches the team worker card" → done: `KitToolRow.agent` when the host can open the child session (`test/tool_card_test.dart` "a sub-agent the host can open is the plain agent line"). Without a session to open it stays a foldable step with the prompt folded and the result capped.
  - embedded-tool-card, verticals "off-palette orange; spinner not KitStatusMark" → done (no agent colour chip; KitStatusMark marks). "exit 0, diff headers" → done (words; KitDiffView reads hunks as "Lines 40–45").
  - embedded-mobile-task-list, statesMissing "long list (20+) inside a chat card" → done: a window of 8 around the first unfinished task and "Show all N tasks" (`test/mobile_task_view_test.dart` "a long plan shows a window around the work and unfolds"; golden `chat_task_list_long_*`).
  - embedded-mobile-task-list, owner fix "one readout ('2 of 4 done' + bar), no engine label, filter as a chip and Copy in the card's overflow, a small 'High' badge" → done: one KitProgressView readout, the same count on the Work line (was "1/2 completed", counting cancelled tasks), label removed, KitChip filter, Copy as a kit copy icon at the end of the filter line (no overflow menu: one action does not need a menu), "High priority" as a KitChip. Verticals "three disagreeing counts" and "priority by colour weight" → done.
- States per page (STATE-20): embedded-tool-card: notRun, pending, running, waitingForYou, done, failed, stopped, background, folded/open; image loading / failed with "Load <name> again" / loaded; file opening → `test/tool_card_test.dart`, golden `chat_tool_steps_*`. embedded-mobile-task-list: in progress, filtered, filtered-empty, nothing tracked, long → `test/mobile_task_view_test.dart`, goldens `chat_task_list*`.
- Deferred states (STATE-21): none beyond the two host wirings above.
- Moved or removed (owner rule 2026-09-27, rethink):
  - Removed the "Server-reported tasks · mobile view" engine label from the plan.
  - Removed the running 2 px left accent on a tool row (the status mark says it).
  - Removed the "Subagent working…" spinner row under a running delegation's line (the line's mark says Running; the words stay in the body when opened with no result yet).
  - Removed the coloured agent chip and the "Background" badge (the line's status word says "Started in the background").
  - Moved "Open subagent conversation" from a small button inside the opened body to the whole agent line (the line opens the conversation, like the team worker card).
  - Moved "Copy all tasks" from a text button to a copy icon on the filter line; the "All tasks copied" snackbar is gone (KIT-23: the kit announces "Copied").
  - Pruned output ("Output pruned") moved from under the folded line into the opened step, where the output would be.

## 2. Builds

- Branch `revamp/chat-2`, base `d91b85b3`, code head `db11d2d9`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2c checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/tool_card_test.dart` | passes | 20 passed | PASS |
| 2 | `test/mobile_task_view_test.dart` | passes | 13 passed | PASS |
| 3 | `test/calm_chat_disclosure_test.dart` | passes | 4 passed | PASS |
| 4 | `test/revamp/chat_2_test.dart` | passes | 3 passed | PASS |
| 5 | `test/revamp/chat_2_golden_test.dart --update-goldens`, then every PNG opened | renders without exceptions | 19 passed; 20 PNGs looked at | PASS |
| 6 | `KIT_RATCHET_WRITE=1 test/kit_ratchet_test.dart` (baseline restored afterwards) | the three write-set files leave every gate map | all three gone from G1, G2, G16, G17, G21; kit_find_mark.dart absent | PASS |
| 7 | `flutter analyze` on lib/ui/widgets, lib/ui/kit/chat, lib/ui/screens/chat*, tool/capture and the changed tests | no issues | no issues | PASS |

Not run (owner decision 2026-09-27: only the unit's own test files): the rest of the suite, the design-standard and l10n tests.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | AUTO-15 | `test/tool_card_test.dart` "a call blocked on the person says Waiting for you, no spinner" | run 1 |
  | PERF-2 | `test/tool_card_test.dart` "long output is capped at 12 lines with Open full output" | run 1 |
  | STATE-9 | `test/tool_card_test.dart` "a non-zero exit is a failed step with its code in words" | run 1 |
  | KIT-23 | `test/mobile_task_view_test.dart` "copy sends the full parsed list even while filtered" | run 2 |
  | LOOK-14 | `test/revamp/chat_2_test.dart` "KitFindMark is only an accent wash; active is stronger" | run 4 |

- Changed test expectations (TEST-19): `test/tool_card_test.dart` rewritten (old: agent chip, running accent, "exit 0", "+1 · −1", `tool-duration`/`tool-not-run` keys, prompt preview toggle → new: KitToolRow words and states, exit words, capped output, the agent line); `test/mobile_task_view_test.dart` widget tests rewritten (old: filter button wrapping, "In progress · High priority" caption, snackbar copy feedback → new: KitChip filter, "High priority" chip, KitTaskMark states, long-plan window, kit copy).
- Goldens (new, each opened and looked at; approved canvas `docs/design/visual-language-2026-09-26/Chat.png`):
  - `chat_tool_steps_{dark,light}.png`, `_1280x800_*`: seven folded steps (read, edit `+6 −2`, running, waiting for you, failed, not run, the agent line). Canvas shows these folded under the work chip; differences: none in the row style (no frame, glyph + title + mono path + mark).
  - `chat_tool_shell_open_*`: failing command, command block, output capped at 12 lines with "Failed · exit code 1" and Open full output, Run this command again. Canvas has no opened shell step.
  - `chat_tool_edit_open_*`: KitDiffView with file header `+3 −1`. Canvas shows the edit as a code block with header `+6 −2` and copy; difference: the diff view's header carries the path under the name and change navigation (KitDiffView's own look).
  - `chat_tool_subagent_step_*`: a delegation without a conversation to open, prompt folded, result as Markdown.
  - `chat_task_list*`, `chat_task_list_long_*`: the plan and the long-plan window.
  - `chat_find_excerpt_*`: the pinned find excerpt with the active mark.
- Before and after (EVID-10): `before-embedded-tool-card-{shell,long-output,edit,subagent}.png` and `before-embedded-mobile-task-list-in-progress.png` (from the screen census at base), `after-…` beside them (copies of the dark goldens).
- Accessibility: tool rows keep ≥ 48 dp targets and KitToolRow's labels ("Shell, npm run lint, Failed"); the agent line is one button with the hint "Open subagent conversation"; task rows read their words and state (the mark is excluded); "High priority" is a word, not a colour; at 2.0 text and 320 dp the priority chip moves under the task's words (no overflow; `test/mobile_task_view_test.dart` "plain text remains inert with RTL, large type and narrow width").
- Privacy and security: output is shown only through KitCodeBlock (redacted by the kit, SEC-4); copying goes through KitCopy. No credentials, stored data or external links changed.
- Migration: n/a: no stored format changed (the expansion store keys are unchanged).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/tool_card_test.dart test/mobile_task_view_test.dart
$F test -j 1 test/calm_chat_disclosure_test.dart test/revamp/chat_2_test.dart
$F test -j 1 test/revamp/chat_2_golden_test.dart
KIT_RATCHET_WRITE=1 $F test -j 1 test/kit_ratchet_test.dart && git diff test/kit_ratchet_baseline.json; git checkout test/kit_ratchet_baseline.json
$F analyze lib/ui/widgets lib/ui/kit/chat lib/ui/screens tool/capture test/tool_card_test.dart test/mobile_task_view_test.dart test/revamp
```

## 7. NOT proven

- Not run on a device or emulator.
- The full suite was not run. Shared tests expected to break (they assert the old implementation): `test/release_blockers_test.dart` "tool expansion has 48dp target and reduced-motion semantics" (InkWell, "Shell, Running" label order, `$ flutter test` as one text); `test/chat_live_events_test.dart` grouped-tool tests that cast `embedded-tool-row` and `embedded-tool-error-output` to `Container` and read their decorations; `tool/capture/v2_subagent_test.dart` taps `find.text('explore')` (the line now reads "Delegated to explore").
- `waitingForYou` and `onRerunCommand` are not wired by the chat screen yet, so in the app a tool blocked on a permission still reads Running (question tools already read Waiting for you) and "Run this command again" does not show.
- The screen is not yet in design_standard_test's `_migrated` list and the ratchet and l10n baselines are not regenerated (integrator files, R05/R10).
- UI ledger parts (`d-chat-sheets.json`, `e-workspace.json`) still name the old keys `tool-body-see-all` for output/diff "See all" (now the kit's `kit-code-open-full` / KitDiffView's open-all) and the old line numbers.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/chat-2` |
| Enabled | Yes (the two host hooks are off until wired) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `db11d2d9` |
| Deployed | No | |
| Released | No | |
