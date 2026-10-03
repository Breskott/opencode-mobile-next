# slice-P3.5: Retire RunScreen, plus the owner's team conversation reports (2026-09-27)

Branch `revamp/slice-P3.5`, from `feat/phone-setup-v2` (merged up to `5636d02f`: P5.2, R4, R12, P6.7, coord-main, the kit gates).

**Finish line.** team-run and its four tabs are deleted. A task is its
conversation. Task details is a sheet in the conversation's menu. Steps are
tappable in the transcript. The board's add sheet is the one "Give the team
a task" sheet, with Keep in backlog. The reassign and merge-approve sheets
are gone (earlier slices removed them; this slice checked).
**Non-goal.** No automatic merge (P6.4).

The chat library was owned here, so this slice also fixes the owner's four
reports from build 2055 on the phone, and wires the chat call sites that
P6.6a left.

## What changed, per page

### team-run: removed (merged into team-conversation)

- `lib/ui/screens/team/run_screen.dart` is gone (git mv to
  `task_details_sheet.dart`). No route pushes a run page.
- **Task details** (`showTeamTaskDetails`, sheet key `team-task-details`) is
  the conversation's menu entry. It holds what the conversation does not
  say:
  - the status line: state word · "0 of 2 steps done" · elapsed (or since
    the hand-off to merge, TEAM-117);
  - the stage line: Waiting · Working · Reviewing · Done;
  - the steps as `KitWorkGraph` rows, with their dependencies. Each step
    opens its Work sheet (owner, age, what it waits on, why). A formula run
    that tracks no work lists its own stages;
  - where the host reports usage, that a task's cost is not reported
    (P5.2's rule: the team page has the day's estimate), and the host's
    policy;
  - one Technical details fold: the host's term, the times, the ids, every
    raw field, and **What the host reported** (the task's event log, which
    was the Timeline tab).
- Not repeated there: the agents (the conversation's strip and worker
  lines; each agent's page is on the team page), the counts (the status line
  and the graph say them), the gates, the merge section and the Stop receipt.
- Retired as views: the tab strip, the Timeline filters and jump pill, the
  List/Graph toggle (the graph's rows are the list) and the run page's own
  loading, error and missing states (the conversation has them).
- Actions of the run page and where they live now:

  | Run page | Now |
  |---|---|
  | Refresh | conversation menu › Refresh |
  | Technical details | Task details › Technical details |
  | Stop task / Close batch | conversation menu › Stop task (P0.4), with its receipt |
  | Answer a gate | the gate card in the conversation; Details is the Gate sheet, which keeps **Report this failure** (P8.4) |
  | Open a step | tap the step in the transcript, or in Task details |
  | Open an agent | the strip or worker line opens its conversation; its page (nudge, restart, stop) is on the team page |
  | Merge | the merge section at the end of the conversation |
  | Merged celebration | at the end of the conversation, once per task |

### team-conversation (`lib/ui/screens/chat/team_conversation_view.dart`)

- **Owner report 1: no progress for 45 h.**
  - `teamNow` (`lib/state/team_conversation.dart`) now marks a step
    stalled when it has shown no progress for `teamNoProgressAfter` (1 h).
    "No progress" means the newest of the step's cycle times, the item's
    update and its worker session's last activity. Before, a worker
    "starting" for 45 h read "can take a few minutes on a phone · 1 d".
  - The Now line says **"No progress for 1 d 21 h"**.
  - A notice under the worker line says who has not moved the task since
    when (with the date when it is another day). It offers:
    - **Nudge furiosa** (`controlAgent` nudge);
    - **Restart furiosa** (asks first);
    - **Report the problem** (Report a problem, with the stall's ids under
      its details).

    Without agent controls, it offers the report only.
  - The nudge's or restart's receipt follows.
  - Long durations now read in hours and days everywhere in the kit:
    `KitSince.durationWords` ("45 min", "3 h 20 min", "1 d 21 h"). The
    worker line said "Running for 2,715 min"; it now says "Running for
    1 d 21 h". KitSince's waiting and age labels also switch at an hour.
- **Owner report 2: the task's text five times.** After the prompt, the
  lead refers to it: "Sent it to the workers", "Started a worker on it",
  "furiosa took it", "Its changes are on a branch", "furiosa is working on
  it · …". A task whose only step is the task itself shows no steps fold,
  and its worker line carries no task line. Its Work sheet is a row of Task
  details. A step with its own words keeps them.
- **Owner report 3: the strip over the transcript.** The agent strip is
  the header's last row, with room below it and the header's divider. The
  transcript starts under it (test: the strip ends above the list and the
  prompt).
- **Owner report 4: text under the composer.** `KitComposer.layer` now
  draws the composer's band as solid ground. It runs from the composer's
  top edge to the window's bottom edge, across the full width, so nothing
  shows beside or beneath the composer. This is a kit change, so the main
  chat gets it too.
- **Steps are tappable.** `KitToolRow` gains `onOpen` and `openLabel` for a
  step. A step with `onOpen` opens elsewhere, with a forward chevron and
  the hint "Open its details". It cannot also fold.
- The menu gains **Refresh**.

### Chat call sites left by P6.6a (`chat_screen.dart`, `chat/nudge_slot.dart`)

- The model the app picked by itself is said once per server, in the one
  nudge slot above the composer: "Using Claude Sonnet 4, this server's
  default model." It comes with **Choose another model** (the model sheet)
  when there is another model, and the close otherwise. This goes through
  `claimDefaultNotice(kind: DefaultKind.model, …)` after the catalog loads.
- `ReviewWorkspace(profileId: _conn.profile?.id)`: the review view's notice
  is said once per server, and comment drafts persist per server.

### Security: Copy transcript and share links (G12, SEC-13)

- **Copy transcript** (`/copy`) no longer copies tool output verbatim.
  `_transcriptMarkdown` masks everything that is not the person's own
  through `KitRedact`: replies, reasoning, tool output, attachment names,
  error text and the title. The person's own prompts stay as typed.
- The share-link copies (`chat_screen.dart` `_copyShareLink` and the
  shared status line in `chat/chat_states.dart`) now use the redacted
  default. A plain share address comes out unchanged, and a credential in
  one is masked.
- `test/redaction_test.dart`:
  - `chat_screen.dart` moves from the findings list (4) to the
    own-content list (3: message Copy, the composer draft, and the already
    masked transcript);
  - `chat_states.dart` leaves both lists (0 verbatim copies).
- Test: `slice_p3_5_test` "Copy transcript masks what is not the person's
  own". A tool that printed `ANTHROPIC_API_KEY=sk-ant-…` and a reply
  quoting a bearer token reach the clipboard masked, while the prompt stays
  verbatim.

### team-board-add-sheet: removed (merged into start-run-sheet)

- The board's + (and its empty state's action) opens the one **Give the team
  a task** sheet through `TeamConversation.start(offerBacklog: true,
  projectId: <the board's project>)`.
- **Send** starts the task and opens its conversation. **Keep in backlog**
  (the sheet's secondary action, where the host creates work) makes the
  task, given to no one. The board then shows its Backlog.
- A refusal keeps the sheet open with what was typed.
- `showStartRunSheet` now returns `StartRunResult` (the record plus
  `backlog`).
- Deleted: `showTeamBoardAddSheet` and `TeamBoardEdits.addToBacklog`.
- The send labels stay "Send to the Mayor" / "Send to an agent": they name
  their target (owner rule). Keep in backlog is offered only from the board,
  where the backlog is visible.

### Copy

- New (English only): the kit durations (`kitDuration*`, `kitToolFor`,
  `kitSinceWaitingForLong`, `kitToolOpenDetails`), the lead's "it" lines
  (`teamChatLead*It`), `teamChatNowWorkingIt`, `teamChatNowNoProgress`,
  `teamChatNoProgress*`, `teamTaskDetailsReported` and
  `teamStartRunKeepInBacklog`.
- Deleted, from en and ar, 37 keys that became unused:
  - the run page's tabs, filters, empty states and work-list words;
  - the cancel-run and close-batch confirmations;
  - `teamOpenTaskConversationHint`;
  - `teamUiRunDetails*`;
  - `kitToolForMinutes`;
  - the board add sheet's five keys.

  gen-l10n was run.

### Ledger

- `docs/design/ui-ledger/parts`:
  - team-run, its four tabs, its details sheet, its cancel sheet and
    team-board-add-sheet are removed;
  - team-task-details is added;
  - the team-conversation elements are updated (Refresh, Task details
    sheet, step rows, no-progress actions);
  - the board's + now targets start-run-sheet, which gains Keep in backlog;
  - `_assignments` points to `task_details_sheet.dart`.
- `ledger.json` was rebuilt. `check_ui_ledger.py` reports 189 errors, which
  were all there before (192 at base).

## For the coordinator

- **Planning card as a lead line: not done here.** `TeamPlanningCard` is
  rendered by `team_home_screen.dart` (P5.2 is editing it). Its code marker
  says slice-P6.3. The conversation already shows a pending task as its
  lead line ("Sent to the team…"). What remains is to drop the card from
  the home.
- No team-home door opens a run page. The conversation's "AI Team" action
  still pushes `TeamHomeScreen` directly (as P3.4 noted), not `TeamPage`.
- `teamAgentsOnRun` in `team_vocabulary.dart` (P5.2's file) no longer has
  a caller.
- The work-row age in `lib/domain/work_row_status.dart` still words long
  ages as minutes (it calls `kitSinceAge` directly). This is a follow-up
  for its owner.
- `tool/capture`: the screen census (`areas/i1_team_core.dart`,
  `areas/i2_team_sheets.dart`) now renders team-task-details (batch,
  formula, reported, missing) and hosts its sheets on the conversation.
  `motion_team_test` and `aiteam_redesign_test` render the conversation.
  The census was not re-run here: it rewrites `docs/qa/screen-census`.
- `test/design_standard_test.dart`: the run page's `_migrated` and
  `_grandfathered` entries are removed (the file is deleted, TEST-10), so
  the grandfathered count is now 58.

## Tests

New:

- **`test/revamp/slice_p3_5_test.dart`**: 15 tests.
  - No progress:
    - the Now line;
    - the worker line in days and hours;
    - the notice and Nudge (sends once, with a receipt);
    - Restart asks first, and backing out sends nothing;
    - a host without controls offers the report only;
    - a task that moves says nothing.
  - Said once: the lead's "it", no steps fold, no task line; a real step
    keeps its words.
  - Nothing covers the transcript: the strip ends above the list, and the
    composer band is solid to the bottom edge.
  - Task details has every former fact, and a step opens the Work sheet.
  - A transcript step opens the Work sheet.
  - Refresh.
  - The board's + with Keep in backlog.
  - P6.6a's model notice, once per server, with Choose another model.
- `test/kit/kit_since_test.dart`: durations in hours and days. The old
  "Waiting 1,234 min" expectation now reads "Waiting 20 h 34 min".
- `test/kit/kit_tool_row_test.dart`: a step with `onOpen`, and an agent
  running for 1 d 21 h.
- **`test/revamp/slice_p3_5_golden_test.dart`**: 14 goldens.

Migrated off RunScreen (two parallel sub-agents on disjoint test files):

- `team_run_screen_test` became `team_task_details_test`;
- `team_work_tab`, `team_work_layout`, `team_run_layout`, `team_usage`,
  `team_policy`;
- `team_controls` (cancel run became the conversation's Stop task);
- `team_cycle`, `team_motion`, `team_agent_screen` (Agents tab → the
  conversation's strip), `team_merge`, `team_redesign`,
  `team_design_standard`;
- `support/team_golden_fixture` (the `team_run_*` shots now render the
  conversation and Task details, under a pinned clock) and
  `goldens/team_golden_test`;
- `team_conversation_screen` (the Overview → conversation test is gone),
  `team_one_page`, `team_gate_answer`, `team_board`, `search_index`,
  `shared_team_1` (+golden; the add sheet's test and goldens are deleted),
  `screen_team_2`, and the ratchet and design-standard baselines.

Regenerated goldens:

- `chat_4_team_conversation_*` (the strip band);
- `team_run_{overview,work,merged}_{dark,light}` (now the conversation and
  Task details).

Runs, with the pinned Flutter 3.47.1 and `--no-pub`:

- **The files.** Every test file this branch changes or adds, plus the gates
  (`kit_ratchet`, `ui_glossary`, `l10n_coverage`, `architecture_boundaries`,
  `redaction`, `design_standard`), the chat goldens and tests
  (`chat_3/4/5`, `chat_states`, `saved_prompts`, `kit_composer*`,
  `kit_jump_pill`, `kit_ask_line`), `team_board`, `team_discover`,
  `team_agent_chat_render`, `slice_p4_1c`, `slice_p6_6a_defaults` and
  `slice_p52_golden`. That is 44 files.
- **The base.** The same files at the base `5636d02f`, in a temporary second
  worktree. The base runs the old `team_run_screen_test` in place of
  `team_task_details_test`.
- **Result.**
  - Base: 168 failing tests.
  - This branch: 174 before the last fix.
  - Every failure on this branch fails on the base too, except these:
    - my own goldens, which the merged R4 row-group change and P5.2's
      cost line invalidated (regenerated and looked at);
    - `slice_p52_task_details_cost` (P5.2's golden, now of Task details;
      regenerated);
    - one G17 finding: Task details used the attention tone twice
      (removed).
  - After those fixes nothing new fails. 8 base failures are fixed, among
    them `team_design_standard` §1 and the four `team_work_layout` Work
    sheet tests.
- **Pre-existing on base.** The kit ratchet G21 and KIT-5 (kit scenes),
  `design_standard` goldens (`team_agent_controls`), `ui_glossary`
  G11/G28, `architecture_boundaries`, and many team and chat goldens that
  are stale on base. Also `redaction_test`: `lib/main.dart` has a new
  `redact: false`; it is not a chat file and is for the coordinator.
- `flutter analyze` (whole repo, including tool/): no issues.

## What still needs a device

The unit's proof was not run: on the emulator, give a task and follow it to
merge without leaving the conversation. The owner's reports also need a
check on a real phone:

1. A worker left quiet for over an hour shows "No progress for …", and
   Nudge and Restart reach it.
2. The composer band at the bottom with gesture navigation.
3. The strip above the transcript while scrolling.

## Images

| | Before | After |
|---|---|---|
| Stalled task (owner report: "Running for 2,700 min", the task five times) | `before/team_conversation_no_progress_dark.png` | `after/team_conversation_no_progress_dark.png` |
| Stalled task, 1280x800 | `before/team_conversation_no_progress_1280x800_light.png` | `after/team_conversation_no_progress_1280x800_light.png` |
| A moving task (strip band, composer band) | `before/team_conversation_working_dark.png` | `after/team_conversation_working_dark.png` |
| A moving task, 1280x800 | `before/team_conversation_working_1280x800_light.png` | `after/team_conversation_working_1280x800_light.png` |
| The run page → Task details | `before/team_run_overview_dark.png`, `before/team_run_work_dark.png` | `after/team_task_details_dark.png`, `after/team_task_details_1280x800_light.png` |
| The board's add sheet → Give the team a task | `before/board_add_sheet_dark.png` | `after/board_give_task_dark.png`, `after/board_give_task_1280x800_light.png` |

## Shipping states

- Implemented: yes.
- Committed: locally on `revamp/slice-P3.5`.
- Verified: by the tests and goldens above, not on a device.
- Enabled, deployed, released: no.
