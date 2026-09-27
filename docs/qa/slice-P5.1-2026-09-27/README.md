# slice-P5.1: the team's Now line (2026-09-27/28)

**Finish line.** The team conversation has one Now line. It says what is happening, since when, what comes next and how long that usually takes. After 8 s without the next stage it says why in one sentence and unfolds the Why in place. It replaces the dispatch cycle strip.

**Non-goal.** No dispatch speed change (P6.3).

Branch `revamp/slice-P5.1`, merged up to `feat/phone-setup-v2` `c9504b56` (kit-hygiene, one connection status, removal safeguards, tests-a). The state half is Codex's `lib/state/team_now_line.dart` ([codex-p51](../codex-p51-2026-09-27/README.md)).

## What changed, page by page

### Team conversation (`chat/team_conversation_view.dart`)

- The header's status line is now `TeamNowLineView`, fed by `TeamNowInput.forRun` / `forPlanning`. It shows the stage in the person's words ("Starting a worker · 3 min"), the next stage ("Next: the worker begins the task · usually within 5 min") and, from 8 s on, the factual reason.
- **Why?** unfolds in place (no sheet). It explains how the stage works and offers the ways out the page has: watch the planner or worker, Refresh, Stop following this request (local dismiss, which does not cancel host work), and Stop the task where the capability allows.
- 31 minutes without a plan says "Waiting for a plan · 31 min" with "No plan has been reported yet. The reason is unknown." and its ways out. It never shows "Still planning" alone.
- A team that has not answered for 8 s says so and offers Try again.
- The usual time is said only while it holds, never as a deadline. It comes from the host's documented 1–5 min worker start, not a measured figure. The "under a minute" example stays unclaimed (codex-p51).
- New: sending a message scrolls the transcript to it, because the taller header could leave it under the fold.

### Team page (`team_home_screen.dart`, `widgets/team_now.dart`)

- The Now line is one sentence about the team as a whole, and only when the rows below cannot say it: paused (with Resume) or "The team isn't starting a worker" (with Start a worker / Why?). It never repeats a task's title or wait, which the task row already says. Before: "'Add subtract function…' has waited 16 d and no worker has started" above the same row.
- The home planning card is gone (P3.5 leftover). A task being planned is a row of the one task list ("Waiting for a plan · 31 min") and opens its conversation, whose Now line carries the planning state.
- Fixed: "No tasks match" no longer shows above a planning row when nothing is filtered.

### Work sheet (`team/work_sheet.dart`)

- The step's Now line replaces the seven-step cycle strip (Routed / Claimed / Pushed …), so no engine words appear above Details.
- The sheet still reads the agent's transcript so a usage limit is seen ("The AI service reported a usage limit.").

### Removed

- `TeamCycleStrip`, its "How the host dispatches" sheet, `TeamPlanningCard`, the unused `teamAgentsOnRun`, and their strings.

## Tests

- New: `test/revamp/slice_p5_1_test.dart` (8 behaviour cases: the 8 s reason with no event, the Why folding in place, the usual time never used as a deadline, 31 min planning with ways out and no engine words, an unconfirmed request, a moving task, and the planning row on the team page). Also new: `test/revamp/slice_p5_1_golden_test.dart` (6 goldens).
- Updated: `team_cycle_test`, `team_controls_test`, `team_motion_test`, `team_now_test`, `team_conversation_screen_test`, `slice_p3_5_test`, `shared_team_1_golden_test`. Goldens refreshed for the team conversation (chat_4, p35), the work sheet and the p52 team page.
- Gates pass: kit_ratchet, redaction, ui_glossary, no_raw_error_text, kit_manifest, kit_draft_manifest, team_now_line. `flutter analyze`: clean.
- Pre-existing failures, identical on the base `c9504b56` (checked in a second worktree), not touched:
  - `team_controls_test`: 17, because the start sheet's Send sits off-screen at 400×900, plus the Mayor/gating cases.
  - `team_home_test`: 10.
  - `team_now_test`: 3.
  - `team_agent_screen_test` layouts.
  - `team_gate_answer_test` layouts.
  - `team_home_layout_test` 320dp.
  - `team_plugins_screen_test`: 6.
  - `team_redesign_test`: 3.
  - `team_task_details_test`: 1.
  - `team_phone_onboarding_test` layouts.
  - Golden drift in screen_chat_1, screen_team_2/3 (home, agents), slice_p34, team_phone_v2, shared_team_1 board sheets.

## Images

`before/` and `after/` show the same scenes:

- The conversation, working and needs-you.
- The work sheet.
- The p52 team page, phone and 1280×800.
- New in `after/`:
  - `p51_team_conversation_planning_why*` (31 min, Why open).
  - `p51_team_home_planning_row*`, which replaces `before/embedded-team-planning-card--planning.png`.
- `before/team_cycle_how_sheet_dark.png` and `before/embedded-team-cycle-strip--host-not-started.png` show what was retired.

## Still needs a device

- The proof: a task from pending to the first worker output on the owner's phone (read-only adb) or an emulator, recorded here.
- The census areas `i1_team_core`/`i2_team_sheets` were updated for the new keys but not re-run.
