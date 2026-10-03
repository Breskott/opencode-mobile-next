# The AI Team's board (2026-09-26)

## Scope

- **Spec and research:** [`docs/design/team-board-2026-09-26.md`](../../design/team-board-2026-09-26.md). It covers what Jira, Trello, Linear, GitHub, Notion, Things/Reminders and ui-ux-pro-max do on a phone, the decision, and the feasibility of each mutation.
- **The owner's ask:** "It has beads built in also? It can be treated jira like and have a board for it?"
- **What this adds:** a board of a project's tasks (Gas City beads) in five columns — Backlog · Ready · Working · Review · Done — paged one at a time with the next column peeking, under a strip of column tabs with counts. It opens on Working.

### What the person can do

- **Tap a card** to open its task (the swap point for the team conversation; see NOT proven).
- **"⋯" or long-press a card** to open the move sheet:
  - **Backlog:** Start now, Priority, Cancel task (confirmed).
  - **Ready:** Move back to Backlog, Priority, Cancel task (confirmed).
  - **Done, cancelled only:** Put back in Backlog.
  - **Working and Review:** the sheet says the team moves them and offers Open conversation.
- **+** adds a task to the Backlog when the host allows creating work.
- **Pull to refresh** any column.

How moves behave:
- A move shows at once in its new column ("Moving to Ready…") and stays there until the host shows it.
- If the host refuses, the card goes back and a notice gives the host's words.
- A host that allows no writes shows the board read-only, with a status line that says so.

### Files

| File | What |
|---|---|
| `lib/state/team_board.dart` (new) | Column mapping (status × assignee × `gc.routed_to` × session × agent on it). Bookkeeping filter. Card model (priority, type, epic progress, blockers, needs you, moving). Ordering. The allowed moves per column. `TeamBoardEdits`, which sends a move and refreshes. |
| `lib/domain/orchestration_work_edits.dart` (new) | **Additive** `OrchestrationWorkEditGateway` (set priority, unassign, cancel, reopen) and `WorkPriority`. |
| `lib/orchestration/adapters/gascity/gascity_work_edits.dart` (new) | **Additive** Gas City implementation over the gateway's public `http`, using `receiptFromFront`. `POST /bead/{id}/update`, `/close`, `/reopen` per the pinned supervisor spec. No existing file under `lib/orchestration/**` was edited. |
| `lib/ui/screens/team/team_board_screen.dart` (new) | The screen, `openTeamBoard`, and `openTeamBoardCard` (the one swap point for `TeamConversation.open`). |
| `lib/ui/widgets/team_board_card.dart`, `team_board_tabs.dart`, `team_board_move_sheet.dart` (new) | The card (with a priority glyph drawn as signal bars), the column strip (its count bumps when it changes), and the sheets (moves, priority, cancel confirmation, add). |
| `lib/ui/screens/team/team_home_screen.dart` | Two hooks, a few lines each: a Board action in the top bar, and a "View board" row after the agents row. |
| `lib/ui/app_iconography.dart` | One icon, `kanban` (Phosphor, already in the bundled font). |
| `lib/l10n/app_en.arb`, `app_ar.arb` (+ gen-l10n output) | 74 `teamBoard*` strings in en and ar. |
| `test/ui_glossary_test.dart` | The `teamBoard` strings join the engine-word rule (no bead, convoy, rig, …). |

## Builds

- **Branch:** `feat/team-board`, from `feat/phone-setup-v2` at `c799e2af`.
- **APK:** none built. The machine is shared; no Gradle or emulator was used, per the task's rules.

## Devices

None. This record covers tests, goldens and renders only.

## Runs

| # | Check | Expected | Actual |
|---|---|---|---|
| 1 | `test/team_board_test.dart`, the bookkeeping rule removed (`tests-without-fix.txt`) | Fails: the order wisp and the order-run chore reach the board | FAIL, 3 tests (`order:phone-upkeep` shown, Backlog 5 not 4) |
| 2 | `test/team_board_test.dart` | These all hold:<ul><li>bookkeeping never shown (session, order wisp, order-run chore, convoy, molecule, gate, 10-day-old done);</li><li>grouping from status, assignee and session;</li><li>counts;</li><li>Needs you dot;</li><li>epic 2 of 5;</li><li>blocked-by;</li><li>another project's task only on its board;</li><li>tap opens the conversation;</li><li>team-owned cards have no ⋯ and a long press says why;</li><li>Start now sends `assign` to `oc_app/gastown.polecat` and shows the card in Ready as "Moving…";</li><li>Cancel asks first and "Keep it" sends nothing;</li><li>priority is sent as `bd`'s number;</li><li>a refused move goes back with the host's words;</li><li>a read-only host shows no ⋯, no +, and a status line;</li><li>empty, loading (skeleton, then the 8 s state) and error;</li><li>Add to backlog creates an unassigned task;</li><li>the AI Team page opens the board from its header and from its row.</li></ul> | PASS, 17 tests |
| 3 | `test/goldens/team_board_golden_test.dart`: 14 shots × dark/light at 412×915 | Renders reviewed, below | PASS, 28 |
| 4 | Existing AI Team home, design and glossary tests, plus `team_golden_test` (the hooks change the home) | Pass; the home goldens are regenerated for the two hooks | See "Suite result" |

### Suite result

`-j 2` over the files below: **+156 −8**.
- **Files:** `team_board_test`, `team_home_test`, `team_home_layout_test`, `team_home_stable_layout_test`, `team_redesign_test`, `team_design_standard_test`, `design_standard_test`, `team_motion_test`, `app_iconography_test`, `ui_glossary_test`, `goldens/team_golden_test` and `goldens/team_board_golden_test`.
- **The 8 failures:** all goldens in `team_golden_test`. `team_home_loaded`, `team_home_empty` and `team_home_loaded_phone` changed by 0.45 % because of the new Board icon in the top bar. `team_start_run` changed by 0.05 % because that icon shows behind the sheet.
- **After regeneration:** each was reviewed (`team_home_loaded_light.png` shows the icon and the "View board" row after the agents row), and the file passes, +30.
- **Analyzer:** `flutter analyze` finds no issues.

## Evidence (renders, dark and light, `*_dark.png` / `*_light.png`)

| Render | Shows |
|---|---|
| `team_board_working_*` | The opening column. Needs you first, then stopped with an error, then urgent. The strip counts every column, and Working has a dot. |
| `team_board_backlog_*` | Priorities as bars ("High", "Low"), types (Bug, Feature, Epic · 2 of 5 done), a card blocked by another, ⋯ on each. |
| `team_board_ready_*`, `team_board_review_*`, `team_board_done_*` | The other columns. Done is muted, and the cancelled task has its ⋯ (Put back in Backlog). |
| `team_board_move_sheet_*` | Start now, Priority, Open details, then Cancel task apart and error-toned. |
| `team_board_team_moves_*` | A Working card's long press: "The team moves this task…" and Open conversation. |
| `team_board_cancel_confirm_*` | Keep it / Cancel task. |
| `team_board_moving_*` | After Start now: the card in Ready, "Moving to Ready…", and Ready 3 / Backlog 3. |
| `team_board_refused_*` | The notice with the host's words; the card is still in Ready. |
| `team_board_read_only_*` | The read-only status line; no ⋯ and no +. |
| `team_board_empty_*` | The team at an empty board, with Add to backlog. |
| `team_board_loading_*` | The columns without counts, and skeleton cards. |
| `team_board_error_*` | Can't reach the team host, with Try again and Details. |

## How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 2 test/team_board_test.dart test/ui_glossary_test.dart
$F test -j 2 test/goldens/team_board_golden_test.dart
# renders: the goldens, copied here
```

## NOT proven

- **On a device.** No APK was built and nothing ran on the phone or an emulator: layout on a real screen, gestures, the page swipe's feel, and frame times (`gfxinfo`).
- **The new bead edits against a live Gas City.** Priority, Move back to Backlog, Cancel and Put back in Backlog use routes from the pinned supervisor spec (`POST /bead/{id}/update|close|reopen`) that the app never called before:
  - Clearing `gc.routed_to` to take work back is inferred from how the app reads routing. That the dispatcher then leaves the bead alone is **not verified**.
  - Start now and Add to backlog reuse the proven TEAM-306 `sling` / `POST /beads`.
- **Persisted records.** The edits are not persisted `MutationRecord`s. `lib/orchestration/**` and `lib/state/orchestration.dart` belong to `perf/team-hot`, so the verbs sit in a separate interface. Folding them into `OrchestrationControlGateway`/`MutationKind` with a `controlEditWork` capability is the follow-up.
- **The team conversation.** Tapping a card opens the task (`RunScreen`) or, for a card with no task, its Work sheet. `TeamConversation.open` is not on this branch, and `openTeamBoardCard` is the one line to swap.
- **Formula runs.** A formula run's internal steps are wisps, so they are not on the board.
- **The AI Team page's top bar.** It now has up to three icons (search when more than 8 tasks, Board, info). §1 asks for one icon action plus overflow; moving info into an overflow is for `ds/team-discover`, which owns that screen.
