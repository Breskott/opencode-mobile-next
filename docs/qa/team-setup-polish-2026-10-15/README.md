# AI Team setup polish (2026-10-15)

Source: `docs/qa/aiteam-oc2-emulator-2026-10-14/run4-2318.md`. Branch `fix/team-setup-polish`, with `codex/aiteam-oc2-interrupted` merged. Nothing run on a device or emulator; images are phone-size goldens (412x915, dark; light twins are in `test/goldens/team/`).

| # | Finding | Fix | Test |
|---|---|---|---|
| 1 | First-commit error off-screen | The sheet scrolls the progress line / problem into view (150-250 ms, instant under reduced motion). A folder picked on the phone is probed first: an empty repo says so at the folder row with "Make the first commit for me". | `team_setup_polish_test` (refusal in view, empty folder inline) |
| 2 | New folder had no commit | `createFolderScript` now makes an empty first commit after `git init` | `builtin_linux_test` (real sh) |
| 3 | No defaults, one missing field at a time | Team defaults, else Single lane + $5/day, $20 total; mode+budget missing together are one message | `team_setup_polish_test`, updated editor tests |
| 4 | "Not available · host unreachable" on first open | Row says "Checking…" for 30 s after a first unreachable answer, until the team has answered once | `team_plugins_screen_test` |
| 5 | "Leave demo" on a real server | Only when the workspace is simulated | `team_setup_polish_test` |
| 6 | "0 milestones" with a drafted one | Header counts the milestone drafted from the goal; plural forms | `team_setup_polish_test` |
| 7 | Roles reorder | Planner, Worker, Checker, then others | `team_setup_polish_test` |
| 8 | Model/Fallback layout differed | Same y for Model and Fallback in every role; read-only note last; Fallback under "Optional" with "not switched to automatically yet" | `team_setup_polish_test` |
| 9 | Interrupted task had no way forward | See below | gateway + UI tests |

## Interrupted task (root-cause-4.md contract)
- `phone_engine_gateway.dart`: a task interrupted with `structuredOutputInvalid` is resumable (only when the engine advertises `resumeTask`/`resumeProject`): task `paused`, project `paused`, an unanswered `interrupted` request, timeline code `checkerAnswerUnreadable` (plain words in `teamRefusalCheckerUnreadable*`).
- Task page and the project's needs-you card show what happened and one primary **Resume** (`resumeTask`, target task, reviewed revision), saying it re-reads the answer without asking the model, may merge into dev and let waiting tasks start. No recheck/accept/discard.
- Not exercised against a real engine; needs the rebuilt engine and an emulator pass.

## Images
Before: `before-refusal-offscreen.png` (r4-33), `before-task-no-way-forward.png` (r4-43; the task sat in Review).
After: `after-refusal-in-view.png`, `after-empty-folder-inline.png`, `after-interrupted-task.png`, `after-interrupted-project.png`, `after-role-worker.png`, `after-role-checker.png`.

## Checks
Non-golden files on the build server: all pass (see commit). Goldens: `team_projects_golden_test` "new" scenes regenerated (defaults changed the sheet) and `team_setup_polish_golden_test` added, both viewed.
