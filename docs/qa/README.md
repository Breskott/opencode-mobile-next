# QA records

Each change that matters is tested in a real scenario on a device and recorded here,
so what was proven can be audited later (owner's rule, 2026-09-24).

## Record format

One folder per feature and date: `docs/qa/<feature>-<YYYY-MM-DD>/`. Its `README.md` has:

1. **Scope:** the modules and contracts touched, and the spec.
2. **Builds:** branch and commit, and the APK's SHA-256 when one was published.
3. **Devices:** model or AVD, Android version and ABI, and anything notable (for
   example, no Termux installed).
4. **Runs:** numbered steps with expected vs actual, marked PASS or FAIL.
5. **Evidence:** files next to the README: screenshots, logs, `OCTRACE` timing
   excerpts, run marks. Video links go here too; videos are on the Tailscale-only file
   server, not in git.
6. **How to reproduce:** the exact commands.
7. **NOT proven:** what these runs do not show.

Tracing: `adb logcat -s flutter | grep OCTRACE` on any build, or Settings → App
diagnostics → Performance → Copy report.

## Audit-style records

| Record | What it covers |
|---|---|
| [phone-setup-v2-2026-09-24](phone-setup-v2-2026-09-24/README.md) | OpenCode inside the app (no Termux): built-in Linux, the resumable setup engine, setup screens, background survival, the catalog wait |
| [aiteam-builtin-2026-09-24](aiteam-builtin-2026-09-24/README.md) | AI Team inside the app: component, second service, per-project team, a real task to a merged commit on Android 15; process counts vs the 32 limit |
| [work-tab-cleanup-2026-09-24](work-tab-cleanup-2026-09-24/README.md) | The Work tab cleanup (header from the first frame, one loading bar, one status line, other projects once, nothing under New conversation, the 8 s "isn't answering" rule) and the design kit `lib/ui/kit/` with the connection screen and the Work tab migrated (tests, goldens and renders only) |
| [design-standard-aiteam-2026-09-24](design-standard-aiteam-2026-09-24/README.md) | Design standard step 4: the AI Team home, run, agent, sheets and the Work tab's team card on the kit (shared connecting / 8 s not answering / error states, one status line, one pinned primary, one scroll view, `KitPanel`), before/after renders and goldens (tests, goldens and renders only) |
| [design-standard-setup-2026-09-24](design-standard-setup-2026-09-24/README.md) | Design standard step 3: phone setup (start, Customize, progress, ready, the welcome's setup line) and the "This phone" card on the kit, plus the Work tab leftovers (conversation rows, AI Team section, pin tip, other servers, the shell's connection line); kit additions, goldens and before/after renders (tests and renders only) |
| [design-standard-chat-2026-09-24](design-standard-chat-2026-09-24/README.md) | Design standard step 5: the chat's states and banners on the kit (loading bar and placeholder turns, could not load, a message not sent, one status line for the connection and errors, permission/question/form cards and the permission sheet in the one button hierarchy, notify me, empty conversation rails); kit additions `KitRequestCard`, `KitAskLine`, `KitSkeletonTranscript` (tests, goldens and renders only) |
| [design-standard-settings-2026-09-24](design-standard-settings-2026-09-24/README.md) | Design standard step 6: the Settings hub and its screens, the servers list and form, diagnostics, About and the old Termux setup on the kit (`KitNotice` added, `KitRow` options); 24 goldens, before/after renders (tests, goldens and renders only) |
| [aiteam-redesign-2026-09-24](aiteam-redesign-2026-09-24/README.md) | The AI Team in the person's words: "Needs you" first, one Tasks list, agents as one row, a Work tab card of a header and at most three rows, the task Overview with a 4-stage line; engine words (convoy, formula, city, addresses, versions) kept to Technical details by a glossary rule; three product bugs fixed (the task sheet's Send off screen, a refused answer without its receipt, the stage line overflowing at 320 dp) (tests, goldens and renders only) |
| [phone-server-screens-2026-09-24](phone-server-screens-2026-09-24/README.md) | The owner's "Wttf is this shiit" screens on the kit: Servers with the phone's server as one row and a current-server mark, On this phone with one block per state and stacked actions (recovery and Claude Code as rows), Settings › Plugins with plain names and the built-ins folded; kit additions, goldens, before/after renders, behaviour tests that fail on the old code (tests, goldens and renders only) |
| [work-tab-team-sessions-2026-09-24](work-tab-team-sessions-2026-09-24/README.md) | The AI Team's own sessions kept out of the Work tab, projects and All conversations; leaked tool-call markup cut from session titles (tests only) |
| [local-terminal-2026-09-24](local-terminal-2026-09-24/README.md) | A shell in the built-in Ubuntu with no OpenCode server (Termux's Apache 2.0 PTY library, the xterm view, our key bar): the ten device checks of the spec on an Android 14 emulator, the A-vs-B display decision with numbers (A: `seq 1 200000` 2.3 s vs B 28.8 s), process count per shell, three product bugs fixed (CJK/emoji at the last column, select and copy after `clear`, Terminal unreachable while the server starts) |
| [motion-servers-2026-09-25](motion-servers-2026-09-25/README.md) | Add server rebuilt (ledger row 15): the type as three rows, pairing first (Scan code / Paste code), the address folded, Save & connect checks by itself and says what failed (Save anyway), Test connection a tertiary; drawings in the kit's style: this phone and the computer linking up while it checks, a spark when paired, a broken link on failure, and the Servers welcome's hero (tests, goldens and renders only) |

The older folders in this directory are earlier screenshot sets and do not follow
this format.
