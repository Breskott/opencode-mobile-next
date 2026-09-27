# team-home-one-list (2026-09-27)

Owner rules 2026-09-27: (a) one list ordered by urgency, no state sections;
(b) nothing shown twice.

## What changed

- Team home (`lib/ui/screens/team/team_home_screen.dart`):
  - The "Needs you" section label (and its waving agent) is gone; the
    question block (`TeamNeedsYouCard` / `KitRequestCard`) heads the page.
  - One question: the block is also its task's row. It names the task,
    carries its step count ("1 of 5 steps done") and has "Open conversation"
    (key `team-home-gate-<id>-task`), so the task is not listed again.
  - One `Tasks` panel (`team-home-tasks`): needs you, then working, then
    waiting, then done (three shown, "Show N more"). The "Done today" /
    "Done" group (`team-home-completed-group`) is gone; done rows keep their
    check mark and "Done · merged 5h ago".
  - Several questions stay rows on their own panel; their tasks stay in the
    list (a gate row cannot carry a step count).
- `TeamNeedsYouCard` (`team_needs_you.dart`): optional `detail` and
  `onOpenTask`; the task's run screen and the team conversation are
  unchanged.
- Files (`lib/ui/screens/files_screen.dart`): "3 changed files" is the
  list's first row (same inset, hairline and scroll as the file rows) instead
  of a one-row `KitRowGroup` card above the list. In an empty folder it sits
  above the empty state; during the first load and on a load error it is
  not shown.

## Runs

| Step | Result |
|---|---|
| `test/team_home_test.dart` (+1 new test "one list under one heading …") | 9 failures, the same 9 as the base before this change (host phrase key, SwitchListTile, Arabic, stale, search) |
| `test/team_motion_test.dart` | 1 failure, same as base (planning card) |
| `test/team_home_layout_test.dart`, `test/team_home_stable_layout_test.dart` | pass |
| `test/revamp/screen_team_2_golden_test.dart`, `test/revamp/screen_files_1_golden_test.dart` `--update-goldens` | 28 pass, images looked at |
| `test/files_row_actions_button_test.dart`, `test/files_screen_recovery_test.dart`, `test/revamp/screen_files_1_test.dart`, `test/revamp/screen_team_2_test.dart` | pass |
| `test/revamp/shared_team_2_test.dart`, `test/team_gate_answer_test.dart` | 1 failure each, same on base |
| `flutter analyze` on the changed files | clean |

## Images

- `before-team-home-loaded.png` → `after-team-home-loaded.png`
- `before-files-loaded.png` → `after-files-loaded.png`

## NOT proven

- No device run. `test/goldens/team_golden_test.dart` already fails on the
  base (integrator-owned images); not regenerated.
