# AI Team end-to-end, run 4 (APK 2083, integration 46f546c5) - 2026-10-01

Tester: Claude, emulator only (AVD OC_API35, `emulator-5554`, lock held, stopped at the end). GLM-5.3 key was already stored from run 3 (not retyped, nothing typed into any field this run). Scratch repo: `/root/projects/my-app` with one commit (`690f0c8`, made through chat). Not committed.

**Result: Turn on AI Team works, New project works, spec approval works. The planner never starts, so plan card, lanes, findings, merge, promote, parallel project and chat-first-while-a-lane-runs were NOT reached.** One P0 blocks everything after "Approve spec".

## Results

| # | Test | Result | Evidence / timing |
|---|---|---|---|
| 1 | Turn on AI Team to Ready | PASS. 46 s, 49 s, 44 s, 43 s in four runs (reply 0 s, stop 13-36 s, check 5-6 s, protected restart 33 s) | a1_ready.png |
| 1 | Protection line "Protected by this phone's Linux sandbox" | FAIL. String exists (`phoneTeamProtectedProot`, used only in `team_execution_gate.dart`) but is not on the Ready page, AI Team home, project page or project Servers page | a1_ready.png |
| 2 | New project with a repo that has no commit | PASS (new): "This repository has no commits yet. Make a first commit in it, then start planning again." with Retry and Details | c1_nocommits.png |
| 2 | New project with a missing folder | Refused with "The team couldn't start planning... open Details", Details shows `Code: repoPathInvalid` (accepted copy, code not translated) | b3_error.png |
| 2 | New project, Single lane, No limit, repo with one commit | PASS. Project created, status "Shaping the spec" | d1 (deleted), e1 |
| 2 | Spec editor: needs a milestone with title and criteria; Approve spec | PASS (validation line says what is missing) | d2_spec_editor.png |
| 2 | Plan card (edit, ask to change, approve) | **BLOCKED**: after Approve spec the project reads "Waiting for dependencies" for 26+ minutes; no plan, no task, no timeline row | e1_project_waiting.png |
| 2 | Lanes, living edge, step folding, needs-you from lanes, findings, merge to dev, promote (refused, then confirmed), done | BLOCKED | |
| 2 | Parallel 2 lanes project, chat-first while a lane runs | BLOCKED | |
| 2 | Kill app mid-task and reopen | Partly tested with the stuck project: honest card "OpenCode Mobile was closed at 1:06 AM. Your phone's OpenCode stopped with it and is running again." and "AI Team needs to restart OpenCode". First re-check failed (see P1-1), second passed | f1, g1_notready.png |
| 3 | Open P1/P2 from run 3 | see table below | |
| 4 | `ai-team-enable.mp4` | Made as a time-lapse (74 s, waits cut): Ready, New project, form, spec, approve, stall, restart. It is NOT the full happy path because of the P0 | ai-team-enable.mp4 |

## BUGS

**P0**
- **P0-1 (engine or host link)**: After "Approve spec" the planner never runs. The project page stays "Waiting for dependencies", Board "No tasks yet", Timeline empty, for 26+ minutes (also after killing and reopening the app and turning the team on again). The project's Servers page says "This phone, Not reachable, last known tasks" while the same phone shows Ready and OpenCode is running and healthy (`opencode serve` and `libaiteam_engine.so` processes alive, system idle). The engine looks unable to reach the OpenCode host it was just proven with; likely a stale or rotated OC1 credential/host link after restarts, or the planner job never reaching the scheduler. Needs the engine owner; Codex's scripted acceptance run does not go through the app's approve-spec path. (Waiting label is wrong wording for "planning".)

**P1**
- **P1-1 (engine)**: After the app was force-stopped with an approved-spec project, the first Turn on check failed: "Not ready yet", Details "The team's engine answered but said it cannot run work yet. boundary_attested". "Start again" passed. Same code string as the run-3 bug: a healthy state is reported as a failure.
- **P1-2 (UI)**: protection line not shown anywhere (see row 1).
- **P1-3 (UI)**: project Servers page shows only the name and "Not reachable" with no way forward (no retry, no reason).

**P2**
- The spec editor's "Files to read first" hint still ends "The demo does not read or upload files" in the real engine.
- Work list still shows a row "AI Team, Demo" after the real team is Ready.
- The project picker shows the planner's worktree as a raw id, `job-5e43127a-...`, as the current project name after the app restarts.
- Inbox lists about ten "Restarted by itself" rows for the same cause (noisy).
- `repoPathInvalid` has no plain-words line (the no-commit case has one).
- My own harness: the emulator process died three times during this run (last sessions while `screenrecord` was running; frames were captured as screenshots instead). Each death reverted some of `/data`, which removed the earlier scratch commits.

## Re-check of run-3 open items
| Item | Now |
|---|---|
| Start planning save-failed, generic copy (P0, P1-1) | Fixed: plain words and Details with a code for no-commit and missing folder |
| Turn on check `boundary_attested` (run 3 P1-5) | Fixed on clean start; returns after a kill (P1-1 above) |
| Stalled reply wait (run 3 P1-3) | Not seen in four turn-ons |
| Protection line (run 3 P1-2) | Still missing |
| Demo New project ungated (run 3 P1-4) | Not retested (team is on) |
| Work "AI Team, Demo" row, "demo does not read" hint | Still |
| Parallel default lanes 1, chat model tip, raw provider id in role picker | Not checked this run |

## Counts
Open: P0 1, P1 3, P2 5. UI vs engine: P0-1 engine/host link, P1-1 engine, P1-2 UI, P1-3 UI, P2 items UI.

## Videos
`ai-team-enable.mp4` 74 s (time-lapse, blocked journey, no key anywhere). `onboarding.mp4` from run 3 is unchanged and was not redone.

## Files
README.md, contact-sheet-run4.jpg, single screenshots, ai-team-enable.mp4.
