# AI Team roles: UI slice (2026-09-29)

Branch `crit/roles-ui`, on top of the roles state (`efe0a151`). No tests, emulator
or goldens were run (coordinator gates). `flutter analyze` (whole repo): clean.

## Done
- **Agents page** (`team_agents_screen.dart`, same route/entry point): one list of
  roles by urgency. A role a live worker is working for now comes first ("Frontend"
  / "Working on “task” · 4 min"), then the rest ("Uses <model> · 3 tasks"; on a
  team on a computer "Uses the computer's model"). Live Gas City workers are not
  rows: a worker shows as the role of its current task (`teamRoleIdOfWorker`); an
  unknown role is one "Worker" row that opens its conversation. Pinned "New role".
  Built-in names/purposes come from l10n by id when stored ones are empty
  (`lib/ui/widgets/team_role_copy.dart`).
- **Role page** (`role_screen.dart`, new): Name, What it's for, Instructions
  (multiline), Model row (reuses `team_model_sheet.dart`, now with optional
  title/default copy; "Team's model" default; "The computer's model", not editable,
  on a remote team), the live worker of the role ("Working on ...", "Open its
  conversation" with the model it runs with), recent tasks (open the task
  conversation), "Give <role> a task", Reset (built-in) / Delete (own), each after
  a `showKitConfirm` naming the role. Generated worker name only under Details.
  Save pattern: explicit pinned Save / Create role (enabled when something changed,
  closes the page); nothing writes while typing.
- **New role**: same page, starter template, three example chips (Docs writer,
  Security reviewer, Designer) that fill the fields.
- **Give a task**: start-task sheet direct form gets a "Who" row (suggested role
  from the typed title + details, updates as typing; "Suggested from your words ·
  Change"; picker lists roles). Send goes through `TeamDispatchController.submit`
  with `role`, `roles`, `teamModel` (TeamModelStore) and `applyModel`
  (`BuiltinTeam.applyModel` for the in-app team, null otherwise). `TeamConversation
  .start` / `showStartRunSheet` take an optional `roleId` (the role page's action).
  The planner ("Send to the Mayor") form is a message, not `giveTask`; no Who row.
- **Team conversation**: lead lines "Frontend started" / "Frontend took the task",
  the composer note ("Your message goes to Frontend") and the worker line use the
  role name when known (`roleOfRun`). The role preamble that `describeTaskForRole`
  puts in the description is stripped from the prompt shown in the conversation.
- **Team settings**: agents row is "Agents · N roles" (supporting line: who does the
  work, and how each one works); the Model row is unchanged.
- **Search / ledger**: search entry "Agents" (aliases: roles, personas, ...) opens
  the Agents page; `team-role` excluded in `search_index_test` (opened from Agents),
  `team-agents` exclusion dropped. Ledger parts updated (new `team-role` page,
  rewritten `team-agents`, Who row on the start-run sheet, settings row) and
  `build_ledger.py` rebuilt (0 unresolved targets).
- l10n: 60 new keys in `app_en.arb`; 24 unused keys removed (`teamAgents*` wake/asleep
  /paused/kept-off, `teamUiHomeAgents*`, `teamHomeAgentsRow*`, ...); 8 removed from
  `app_ar.arb`. `gen-l10n` run.

## Not done / decisions
- `agent_screen.dart` (AgentScreen) is kept: other entries still open it (activity,
  gate sheet, watching conversation's top-bar action). The role page folds in its
  useful parts (task, model, conversation) instead of replacing it.
- The old list's "Wake the paused agents" row, "checked ..." freshness kept in the top
  bar, and the standing/asleep/paused/kept-off wording no longer appear on the Agents
  page (helpers `teamAgentStanding`, `teamAgentTitles`, ... stay in the file for other
  callers). The settings row lost its "N agents · 1 working / paused / cooling" counts.
- The watching page hint "Message the worker..." (`teamWatchComposerHintWorker`) is
  not role-aware (top-level function without the task).
- Arabic: new keys not translated (falls back to English).

## Tests edited (not run)
Deleted tests that asserted the removed agents-list/counts copy: `screen_team_3_test`
(7 tests, work-sheet test kept), `slice_p52_test` (5), `team_agent_screen_test` (2),
`team_home_test` (4), `team_redesign_test` (1), `team_motion_test` (1). Trimmed
assertions in `team_page_test`, `team_now_test`, `team_home_layout_test`; pull-to-refresh
test in `team_home_test` still opens the page and needs roles to load. `slice_p3_6_test`
opens the worker conversation through `openTeamAgentConversation`.
`screen_team_3_golden_test`: agents shots removed (4 golden PNGs deleted); the work-sheet
shots now have the new page behind them. New: `test/team_roles_ui_test.dart` (5 tests).
**Goldens to regenerate/check:** `slice_p52_golden_test` (agents, agentsWide, wake),
`team_golden_fixture` TeamShot.agents, `slice_p63_golden_test` and any direct-task sheet
golden (new Who row), work-sheet shots of screen_team_3.

## Device check
Team settings > "Agents · 5 roles": working role first with its task and age; a worker
with no remembered role reads "Worker" (no generated name anywhere but Details on the
role page). Frontend > edit instructions > Save; reset a built-in; create from an
example chip; delete an own role (confirm names it). Start a task: Who row changes as you
type ("tests" -> Tester), Change picks another; the conversation says "Frontend took
the task" and the prompt shows only your words. Remote team: model row reads "The
computer's model" and is not tappable.
