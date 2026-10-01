# AI Team end-to-end, run 5 (APK 2084, integration f6127309) - 2026-10-01

Tester: Claude, emulator only (AVD OC_API35, `-memory 3072`, `emulator-5554`, lock held, stopped at the end). GLM-5.3 key already stored (nothing typed into any field). Scratch repo `/root/projects/my-app` with one commit (`690f0c8`). The shared emulator also held Codex's earlier projects ("Run4 ..."). Video was captured as screenshot frames (no `screenrecord`); the emulator did not die this run. Not committed.

**Result: the single-lane real journey now works through the UI to Done (create, spec, plan, approve, worker, checker, dev merge, promote cancel then confirm, Done). Chat during a lane works. A Parallel-2 project stopped on its own, and after a force-stop the interrupted work offers no Resume control.**

## Results

| # | Test | Result | Evidence / timing |
|---|---|---|---|
| 1 | Turn on AI Team to Ready | PASS. 18 s and 16 s (reply 0 s, stop, check, protected restart 10 s) | a1_ready.png |
| 1 | Protection line | PASS. "Protected by this phone's Linux sandbox" on the Ready page and at the top of the AI Team home | a1_ready.png |
| 2 | New project (single lane, no limit, committed repo) | PASS. Needs "Where it runs" chosen (button hint says what is missing) | |
| 2 | Spec editor: milestone with title and criteria, Approve spec | PASS | |
| 2 | Planner, plan card | PASS. Approve spec 04:07:33, "Planning is running" at once, "Plan ready to review" within about 1 min (a later project: under 30 s). Plan card shows 2 tasks with criteria, role and repo pickers, "Review gate, risky" | b1_plan.png |
| 2 | Approve and start, worker, checker | PASS. Approved 04:08:17, both tasks done in about 3 min; digest rows read "Work is waiting for a free lane / running / finished" | e1_work_strip.png |
| 2 | Work strip on Work tab | PASS ("AI Team, 1 working") | e1 |
| 2 | Chat while a lane runs | PASS. "Reply with one word: ready" answered in about 15 s with a lane active | e2_chat_while_lane.png |
| 2 | Needs-you from a lane, findings, fix, re-check | NOT REACHED: the checker found nothing, so no findings round happened | |
| 2 | Merge to dev | PASS with a difference: both merges happened by themselves ("Merged into dev, 690f0c8 to 67283be", then "to ea2f56a") with receipt rows; there was no confirm step | g1_merged_receipts.png |
| 2 | Promote dev to main: cancel, then confirm | PASS. The sheet names the commits; "Cancel" left main unchanged; confirm gave "Promoted to main, 690f0c8 to ea2f56a" and the project read Done. Total: create to Done about 12 min including manual form work | g2, g3 |
| 2 | Parallel-2 project with limits | FAIL. Created and spec approved at 04:14:41; planning "stopped and needs review" within a minute ("Planning was interrupted and needs review before resuming"), project "Stopped unexpectedly", no resume control. Re-approving the spec did not restart it | j1_parallel_stopped.png |
| 2 | Force-stop mid-task and reopen | PARTIAL. Honest card on reopen ("OpenCode Mobile was closed at 4:25 AM. Your phone's OpenCode stopped with it and is running again", "AI Team needs to restart OpenCode"). After Turn on (16 s) the project says "Work was interrupted when the app stopped. Resume to check its existing session." but no Resume control exists (project menu has only Pause and Stop; the task page has none). Project sat at "Waiting for dependencies" 10+ min | l2, m1 |
| 3 | Run-4 items | see table | |
| 4 | `ai-team-enable.mp4` | 53 s time-lapse: Turn on, form, spec, plan card, approve, work, chat, end of the first project, second project form. Frames were cut by time, so the final promote and Done moment is short | ai-team-enable.mp4 |

## BUGS

**P0**: none open (the run-4 P0, planner stall, is fixed).

**P1**
- **P1-1 (UI + engine)**: an interrupted task cannot be resumed. The digest tells the person to "Resume", but no control exists anywhere (project menu, board, task page). The project stays "Waiting for dependencies".
- **P1-2 (engine)**: a Parallel-2 project's planner was interrupted within a minute with no outside cause (no app kill, no OpenCode restart seen), then could not be restarted by re-approving the spec. Cause unknown; the single-lane project right before it planned fine.
- **P1-3 (UI)**: after the force-stop the AI Team page showed "Checking AI Team on this phone" with an hourglass for 5+ minutes until the button under it was tapped.

**P2**
- The merge to dev is automatic with no confirm (spec R-61 asks for confirm and receipt; the receipt exists).
- Parallel default "Maximum lanes" is still 1.
- The spec editor hint still says "The demo does not read or upload files" in real mode.
- Work list label "AI Team, Demo" remains for a real team; the Work list shows only some projects.
- The project picker shows the planner worktree as a raw id, `job-5e43...`, as the current project name.
- Inbox lists many "Restarted by itself" rows.
- Settings row reads "AI Team, On, This phone, read-only" ("read-only" is unexplained).
- The Create project sheet can be sent without "Where it runs"; the missing choice is only in a small hint under a disabled button.

## Re-check of run-4 items
| Item | Now |
|---|---|
| P0-1 planner stall, "Not reachable" | Fixed (single lane) |
| P1-1 `boundary_attested` after a kill | Not seen: Turn on after the kill passed (16 s) |
| P1-2 protection line | Fixed |
| P1-3 Servers page reason | Not rechecked |
| Demo hint, Demo row, raw job id, Inbox noise | Still |

## Counts
Open: P0 0, P1 3, P2 8. UI vs engine: P1-1 both, P1-2 engine, P1-3 UI, P2 items UI.

## Files
README.md, contact-sheet-run5.jpg, screenshots, ai-team-enable.mp4 (53 s). The run-3 `onboarding.mp4` is unchanged.
