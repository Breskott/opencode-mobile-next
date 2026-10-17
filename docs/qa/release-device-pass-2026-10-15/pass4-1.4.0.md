# Release device pass 4 on local 1.4.0+54 (emulator-5554), 2026-10-15

Fresh Pixel_6 emulator (-wipe-data, about 2 GB RAM), install of oc-1.4.0-54-local.apk, free model only (Cat Jam Free), no key typed. Physical phone untouched. No code changed, nothing committed.

| step | result | time | image |
|---|---|---|---|
| 1a. Setup, OpenCode 2 default: Linux base | Done (24.04.5) | 17:33:51-17:34:13 (about 25 s) | rel4-02-choose, rel4-03-prog1 |
| 1b. Git and SSH | Done (2.43.0) | about 2 min (17:34-17:36) | rel4-03-prog5 |
| 1c. Python | FAILED first run: "Could not install Python"; Details end with `proot info: vpid 1: terminated with signal 15` / "The setup step could not finish. Try again." during python3-minimal setup. In-app "Continue setup" (no app restart) worked: Python Done 3.12.3 | fail 17:37:05; retry 17:37:37-17:38:15 | rel4-04-python-failed, rel4-05-details |
| 1d. Node.js | Done 24.21.0 (download 58 MB, no curl error) | about 50 s (17:38:15-17:39:05) | rel4 progress (not imaged) |
| 1e. OpenCode 2.0.29, Start OpenCode | Done; "OpenCode is ready, Name your first project" | by 17:39:33 | rel4-06-ready |
| 2. One chat | PASS. Create project my-app, "Reply with the word PONG only" answered "PONG" by Cat Jam Free; reply speed 3.1 s first words, 3.2 s done | 17:43:51-17:44:08 | rel4-07-project, rel4-08-typed, rel4-09-chat-reply, rel4-10-home |
| 3. Settings, About | PASS. "OpenCode Mobile 1.4.0+54" | 17:47 | rel4-11-about |
| 4. Add tools, AI Team | PASS. Add started 17:45:10, step 5 "Getting AI Team ready"; done by 17:54 (screen back on This phone, Storage 970 MB to 1.3 GB); Add tools sheet then lists Python and AI Team Installed. Exact finish time not captured (my poll pattern missed it) | 17:45-before 17:54 | rel4-12-thisphone, rel4-13-addtools, rel4-14-after-add, rel4-15-addtools-after |

## Bugs

- **P2 Setup step killed by SIGTERM (Python)**: the proot process was terminated mid install on a low-memory emulator (about 2 GB, 227 MB free, no lmkd line in logcat; cause not proven). The retry via Continue setup worked without restarting the app, so the old curl P1 is not reproduced: Node.js passed on first attempt. Cause of SIGTERM unknown; check on a real phone.
- **P2 "Installed" line still stale**: after setup and after AI Team was added, This phone still reads "Linux base, Git and SSH, Node.js and OpenCode" (no Python, no AI Team) although Add tools lists both Installed (same as pass 3 P2).
- Note: the first-run chat showed a "Notify you when the agent needs you?" banner (no issue).

No P0/P1.
