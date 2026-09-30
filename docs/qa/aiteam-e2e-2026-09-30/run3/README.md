# AI Team end-to-end, run 3 (APK 2081, then 2082 retest) - 2026-09-30

Tester: Claude, emulator only (AVD OC_API35, x86_64, API 35, `emulator-5554`, lock held, stopped at the end). Model GLM-5.3 (zai-coding-plan). Scratch repos only (`/root/projects/my-app`, `/root/projects/scratch1`, created through chat). Not committed.

**Result: the engine now turns on (2082) but no project can be created, so plan, lanes, findings, merge, promote, budget, kill-and-reopen and stop are BLOCKED by one P0.**

## 2082 retest note
The coordinator's 2082 (check passes on the proven boundary, reply wait re-checks every 2 s) was installed with `install -r` after the first two failures below. On 2082: Turn on AI Team reached **Ready in 54 s** (reply 0 s, stop 13 s, check 6 s, protected restart 35 s), and again in 48 s after an emulator reboot (honest "AI Team needs to restart OpenCode" card on Work first). The reply wait passed in 0 s on the one 2082 try (the 7-minute stall was not retried with a fresh reply, so "fixed" is one run).

## Results

| # | Test | Result | Evidence / timing |
|---|---|---|---|
| 1 | Setup on this phone (fresh `pm clear`) | PASS. Linux base, Git, Python, Node, OpenCode, start: about 5 min (21:11:28 to 21:16:11 first take, 21:54:06 to 21:59:31 second) | onboarding.mp4 |
| 1 | GLM-5.3 key (Z.AI Coding Plan Global), model picker filter by provider | PASS, key never shown (dots only) | contact-sheet-A |
| 1 | Plain chat "Hello" on GLM-5.3 | PASS. First reply visible: about 9 s (warm), 7 s after app restart, 11 s for a second message. Cold first reply took 2 to 3 min the first time (the send was late, not measured exactly) | c1_hello.png, onboarding.mp4 |
| 2 | Turn on AI Team, 2081 | **FAIL**: reply wait stalled at "Finishing your current reply" for 7+ min although the chat was idle; after app restart the check failed, Details `boundary_attested` (engine started, `canExecute` false) | d1, d2, e1, e2 |
| 2 | Turn on AI Team, 2082 | **PASS**, Ready 54 s and 48 s | n1_ready.png |
| 2 | Protection line "protected by the phone's Linux sandbox" | **FAIL**: not shown anywhere on AI Team home, Ready page or More menu; no such string in `app_en.arb` | n1, n2 |
| 3 | New project, Single lane, no limit | **FAIL (P0)**: Start planning answers "Changes could not be saved. Your edits are still here; try saving again." | r1_save_failed.png |
| 3 | Same with Parallel 2 lanes plus per-day/total limit | **FAIL**, same message | t2_parallel.png, t3_final_fail.png |
| 3 | Plan card, lanes, living edge, needs-you from lanes, findings, merge, promote, chat-first while lane runs, kill app mid-task, budget reached, stop task | BLOCKED by the P0 | |
| 3 | Needs-you in chat (permission card) | PASS (chat agent asked twice for a directory, then "Always allow" confirm worked) | s1 (deleted), shown during scratch repo |
| 3 | Honest recovery after the emulator died | PASS: Work list showed "Needs you: AI Team needs to restart OpenCode", Stop-and-continue sheet, Ready again | p1_needs.png |
| 4 | Roles and agents: Model picker (real catalog, sorted), Checker/Planner read-only, add a new role | PASS | f1_roles, u1_roles_new |
| 4 | New project defaults / Team settings sheet | PASS (single/parallel, charging, review level, budget) | g1_defaults.png |
| 4 | Spec editor, board, timeline, servers, digest | BLOCKED (need a project) | |
| 4 | Notifications permission prompt | PASS (asked after first reply) | |
| 4 | Light theme | PASS on Appearance and AI Team | j1, j2 |
| 4 | 2.0x font | PASS on Settings, Work, AI Team demo page (no overflow); New project sheet not checked at 2.0x | k1, k2, k3 |
| 4 | Dark | PASS (default) | |
| 5 | Baseline bug re-check | see table | |
| 6 | Videos | `onboarding.mp4` made (partly 2081, see below); `ai-team-enable.mp4` covers enable to Ready to New project to failure only | |

## BUGS (open on 2082)

**P0**
- **P0-1 (engine, with UI copy)**: New project "Start planning" is refused on the real phone engine. Tried: empty repo with no commit, repo with one commit on `main`, a second scratch repo (`scratch1`), repo name `my-app`, `greetapp`, `scratch`, Single lane and Parallel 2 lanes, No limit and limits. Always the generic save-failed line. The engine returns an opaque `commandRefused`/`importFailed` class (see `engine/phone/src/daemon.rs` `import_requested_repositories`); I could not read the code because the engine token is private. Needs the engine owner to reproduce with guest path `/root/projects/<dir>` from the New project sheet and to return a typed reason.

**P1**
- **P1-1 (UI)**: the failure line names nothing ("Changes could not be saved") and there is no Details with the code. The person cannot tell a bad repo from an engine refusal. (Breaks "no raw errors" and "actions name their cause".)
- **P1-2 (UI)**: no protection line for the proot tier (R-xx). `boundaryTier` exists in the Dart layer; nothing renders it.
- **P1-3 (UI, 2081 only, fixed in 2082?)**: reply wait stalled 7+ min on an idle chat (d1, d2). Not reproduced once on 2082; keep an eye on it.
- **P1-4 (UI, 2081 only)**: demo opened after a failed turn-on showed "Give your team a goal" with no New project button, a dead end (h2_demo, deleted). Not rechecked on 2082.
- **P1-5 (engine, 2081, fixed in 2082)**: check failed with `boundary_attested` although the boundary was attested.

**P2**
- Work list keeps a row "AI Team, Demo" after the real team is Ready.
- The optional "Files to read first" hint in the real New project sheet ends with "The demo does not re(ad)...".
- Parallel default "Maximum lanes" is 1 (B-16 default not applied in the sheet).
- Chat model tip still says "Using Big Pickle, this server's default model" after GLM-5.3 was picked.
- Role model picker shows the raw provider id `zai-coding-plan`.
- After a "Not now" on the stop sheet, step 2 reads Failed while the headline says "Nothing changed" (2081).
- Two emulator deaths (host memory, all agents share the box): not app bugs.

## Counts
Open on 2082: P0 1, P1 4 (P1-1, P1-2, P1-3 watch, P1-4 unchecked), P2 6. Fixed by 2082 during this run: P0 (boundary check) and the stalled reply wait (one run). UI vs engine: P0-1 engine (plus UI copy P1-1), P1-2 UI, P1-3 UI, P1-4 UI, P1-5 engine.

## Baseline table (run 2 B-x)
| Bug | Now |
|---|---|
| P0-1 hash check, P0-2 Landlock crash | Fixed in 2081/2082 (proot tier started; the Landlock probe still dies on SIGSYS syscall 444 in logcat, which is now expected and handled) |
| B-1 slow first word | Improved: 7 to 11 s warm; cold case not cleanly measured |
| B-3 OpenCode restarted after a failed turn-on | Fixed (chat answered right after the failure, "OpenCode is back on") |
| B-4 failure copy | Fixed (sentence plus Details), but see P1-1 for the new sheet |
| B-5 roles use model picker, Checker read-only | Fixed |
| B-6 reply wait | Worse on 2081 (stall), Fixed on 2082 (one run) |
| B-7 host cost line | Fixed ("Not measured on this phone yet. Your chat stays first.") |
| B-8 typed repo counts | Fixed (Start planning enabled with typed name and folder) |
| B-9 budget hints | Fixed (limits form says above zero) |
| B-10 to B-12, B-14 to B-17 | Not retestable (no project) |
| B-13 model list sorting | Fixed (GLM-5.3, Flash, Highspeed, 5.2, 5-Turbo, 4.7) |
| B-18 Settings "AI Team" row | Fixed (reads Off until ready) |
| B-19 stale transcript | Not reproduced |
| B-20 Inbox "Restarted by itself" | Still (appears after the app restarted OpenCode; wording is arguably right) |
| B-2 migration | Not tested (fresh install) |

## Videos
- `onboarding.mp4`: 102 s. Setup, "OpenCode is ready", provider Z.AI Coding Plan connected (key entry frame omitted because the first take typed into the wrong field and exposed it), model picker, Hello, reply. Setup frames were recorded on 2081, the rest on 2082. The second fresh take on 2082 was lost when the emulator died mid-recording.
- `ai-team-enable.mp4`: 140 s. Turn on, Stop and continue, Ready, New project sheet, form filling, failure. NOT the intended full journey (blocked by P0-1).

## Key exposure (owner should know)
During the first onboarding take the helper typed the zai-coding-plan key into the chat composer instead of the provider field. It was on screen for about one minute and its first characters appeared once in this tester's tool output. The affected recording segment was discarded and the composer was cleared without sending; no screenshot or video in this folder contains it. Rotate that key if the transcript is stored.

## Files
README.md, contact-sheet-A/B/C jpg, single pngs, onboarding.mp4, ai-team-enable.mp4.
