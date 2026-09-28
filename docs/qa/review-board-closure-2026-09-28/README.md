# Review board closure audit (2026-09-28)

**Owner's question:** did we finish all review board comments and notes?

**Short answer: not all of them.** Of the 167 pages the owner judged, **110 are done**. Another 45 are partly done; most of what's left is small wording or layout work. 4 pages were not touched, 3 wait on work that is built but not merged yet, and 5 need something from the server first. Of the **27 pages with a written note**, 12 are fully done, 10 partly done, 2 in progress and 3 blocked. Nothing on the board was forgotten outright, but three owner asks are still open at their core:

- **Voice is still capped at 30 seconds.** The fix is P10.3, built on a branch that isn't merged.
- **Claude Code isn't part of phone setup v2 yet.** This is P1.6b, blocked because the ARM64 check hasn't passed.
- **The agent-driven setup assistant and the MCP catalogue don't exist yet.** Both are in P2, which the owner put on "later".

> **Update (slice-close-team, 2026-09-28):** seven more pages are done — start-run-sheet, isolated-task-sheet, team-agent, team-home-needs-you-tab, team-run, team-run-overview-tab and embedded-team-receipt-chip — and the greyed-out Merge on a merged task is gone (embedded-team-merge-section stays blocked on the host merge contract). The counts below include them. Evidence: `docs/qa/slice-close-team-2026-09-28/README.md`.

| Candidate | Value |
|---|---|
| Branch / revision audited | `feat/phone-setup-v2` at `ca043f36` (merge of slice-P10.1-2) |
| Verdict source | 167 records from the screen review board (`docs/ux-system/owner-verdicts-2026-09-26.json`): 111 fix, 56 rethink, 27 with a written note |
| Plan the verdicts became | `docs/ux-system/target-ia.md` (fates), `programmes.json` (slices), `revamp/work-units.json` (168 units), critics' findings in `docs/qa/screen-review/*.json` |
| Method | Read-only. Six parallel auditors each took a set of areas and checked the current `lib/` code (plus goldens and QA records where that was cheap) against each page's planned fate, the owner's note and the critics' high-severity findings. Every row cites a file:line, golden or record. No Flutter build, analyzer or test was run: a release build was using the PC. |
| Not covered | Device proof. "done" means done in code at `ca043f36`, not verified on a phone. |

## Summary counts

| Status | All 167 | 27 with a note | 140 without |
|---|---:|---:|---:|
| done | 117 | 13 | 104 |
| partial | 39 | 9 | 30 |
| not done | 3 | 0 | 3 |
| in progress | 3 | 2 | 1 |
| blocked | 5 | 3 | 2 |
| **total** | **167** | **27** | **140** |

Status meanings:
- **done**: the planned fate is in the code, and both the owner's note and the critics' high findings are addressed (or made moot by removing the page).
- **partial**: the fate landed, but something named is still missing.
- **not done**: nothing meaningful changed for this verdict.
- **in progress**: the remainder is in work that is still in flight: P10.3 voice composer mode and P6.3 team starts at once, both on the unmerged `revamp/slice-P10.3-P6.3` branch (3273d7ef, fb40c24f), plus tap feedback on the next frame and P9.10 kit gate absolute.
- **blocked**: the remainder needs server support that does not exist yet.

By area:

| Area | done | partial | not done | in progress | blocked |
|---|---:|---:|---:|---:|---:|
| a-shell | 10 | 1 | 0 | 0 | 1 |
| b1-chat-screen | 1 | 1 | 0 | 0 | 0 |
| b2-chat-screen | 2 | 1 | 1 | 0 | 1 |
| c-chat-compose | 3 | 5 | 0 | 0 | 0 |
| d-chat-sheets | 9 | 2 | 0 | 2 | 0 |
| e-workspace | 16 | 2 | 0 | 0 | 0 |
| f-files-review-terminal | 9 | 3 | 0 | 0 | 0 |
| g-servers | 16 | 6 | 1 | 0 | 0 |
| h-termux | 11 | 10 | 0 | 0 | 2 |
| i1-team-core | 14 | 1 | 0 | 1 | 0 |
| i2-team-sheets | 9 | 1 | 1 | 0 | 1 |
| j1-settings-more | 9 | 3 | 0 | 0 | 0 |
| j2-library | 4 | 2 | 0 | 0 | 0 |
| k-session-misc | 4 | 1 | 0 | 0 | 0 |

What the pages became: 80 redesigned, 40 merged into another page (mostly phone setup v2, the team conversation, team-home, This phone, the Inbox, the diff view and the file viewer), 18 only restyled on kit parts, 15 removed, 13 fixed and 1 unchanged at this revision (embedded-voice-conversation-controls, waiting on P10.3).


## Pages with an owner note (27)

### embedded-pending-sends-strip — **partial**

> All the queued messages should be merged in one bubble andwith clear ctar message inside the bubble andthe design should follow the themethey feel so different.

- *Page:* [Pending sends strip] (c-chat-compose, verdict **fix**). *Planned fate:* keeps.
- *Became:* redesigned. *Units:* chat-1, P4.3 (kit KitQueuedMessage). *Commits:* 557920e3, 9d5ece6e.
- *Owner note:* yes — all waiting sends are one themed KitQueuedMessage bubble with a 'n waiting' head, per-item states in words and one ⋯ menu each.
- *Critics' findings:* partly — clipping and overflow are fixed (the bubble sits in a height-capped, scrolling ListView), and Edit and a destructive Discard are in ⋯. Still standing: a failed item that was never dispatched (state failed) has no Retry or Send now, only Edit/Discard. Send again is offered only for unconfirmed sends (message_view.dart:1812-1840).
- *Missing:* No Retry action on a failed queued item. It waits for the next automatic flush. *Fix owner:* lib/ui/screens/chat/message_view.dart _draftItem (chat library) (medium impact).
- *Evidence:* `lib/ui/kit/chat/kit_queued_message.dart:1-52`

### profile-editor — **partial**

> Inline with v installa?

- *Page:* Add server \| OpenCode 2 \| Edit server \| Re-enter password \| Re-enter connection token \| OpenCode \| Claude Code or Pi \| Codex (g-servers, verdict **rethink**). *Planned fate:* keeps.
- *Became:* redesigned. *Units:* screen-servers-1, slice-P3.9. *Commits:* 71417a2f, 3d251f37, 24b76eb8.
- *Owner note:* yes — the 'On this phone' row in Add server's step 1 hands off to phone setup v2 (openPhoneSetupStart, servers_screen.dart:263-264, 486-488, 3841). Adding a computer is one stepped flow: kind, Tailscale, pair or address, check, ready (_AddStep, servers_screen.dart:3469), with a staged 'Step n of 4' bar.
- *Critics' findings:* no — all three still stand. (1) A refused connection still says 'Is opencode serve running on that host and port?' next to the 'opencode2 pair' command (app_en.arb:7814, mapped at setup_ui_messages.dart:127). (2) The verdict renders at the head of the form (servers_screen.dart:3244-3251), and the address field sits under the pinned Save & connect (golden add_server_failed). (3) The Codex command is a multi-line block cut at the right edge, and the 'Use wss:// for remote servers. ws:// is limited to this device.' helper remains (arb:1528, servers_screen.dart:2651).
- *Missing:* Plain failure wording with the raw error under Details; the verdict as a KitNotice under the address field, scrolled into view; the Codex command on one scrollable line and field validation instead of the ws/wss helper. *Fix owner:* lib/ui/screens/servers_screen.dart (_status/_manualAddress/_buildCodexFields); lib/l10n/app_en.arb e7SetupRefused, codexAddressHelp; SetupCommands.startFor(codex) (medium impact).
- *Evidence:* `test/goldens/add_server_failed_dark.png`

### provider-quota — **partial**

> Featureitself needs a lot of work

- *Page:* Remaining (g-servers, verdict **rethink**). *Planned fate:* keeps.
- *Became:* redesigned (Codex path); restyled (collector path). *Units:* screen-usage-2, slice-P3.11a, slice-P5.4. *Commits:* 4253a39e, 00cafa13, 43b14616, 8e0c584b, 531bb6ab.
- *Owner note:* partly — P5.4 landed for Codex hosts. It shows sentence rows ('About 40% left in this 5-hour window · resets at 3:00 PM'), with the Codex account as the source (QuotaAnswersController.codex, provider_quota_screen.dart:125), the offline age ('Last known reading, from 40 min ago', :1085-1090) and 'Alert me at 80% used' on by default (quota_answer_preferences.dart:43-60). The collector path still needs a lot of work.
- *Critics' findings:* partly — the setup wall and mechanics moved into Details, and there is a 'Needs the quota collector on {server}' notice with 'How to get it'. Still standing on the collector path: the 'Codex account windows / Reported plan / Snapshot checked <date>' header (arb:1123, 1127, 1136); a 'Secondary window · Not reported' row (arb:1161); the missing-collector page still lists 'Collector server' and 'Stop using this collector', plus a second Refresh beside the top-bar one; the empty monitor notice 'No provider sources are monitored. Read Remaining for a trusted collector…' (quota_monitor_section.dart:108, arb:1484); and 'How to get it' points at 'tool/quota in the app's repository' (arb:24765).
- *Missing:* Collector-path cleanup: provider rows as 'Codex · 74% left · resets in 3 h' without the snapshot/plan/secondary-window header; no collector controls when the collector is missing; plain empty-monitor copy; an external guide link instead of a repository path. Offline value does not survive an app restart, and the ≥80% attention is foreground only (no device notification). *Fix owner:* lib/ui/screens/provider_quota_screen.dart, lib/ui/widgets/quota_monitor_section.dart (follow-up to slice-P5.4) (medium impact).
- *Evidence:* `test/revamp/goldens/slice_p54_collector_missing_dark.png`
- *Update (slice-close-misc, 2026-09-28):* the collector path is closed. Rows are answer sentences under "Codex, from the quota collector on Studio"; the snapshot/plan/secondary-window header is gone (plan, reading time and collector address are in Details; unreported windows are left out); a missing collector shows no collector controls and no second Refresh; the monitoring list shows only while something is monitored (the jargon empty notice is deleted); "How to get it" opens the collector guide through `openExternalLink` instead of naming `tool/quota`. Monitored sources on other servers read as the same answer rows with their state in words. **Still open:** the Codex answer does not survive an app restart, and the 80% alert is foreground only; both need state work (Codex backend owner). Evidence: `docs/qa/slice-close-misc-2026-09-28/README.md`.

### termux-processes — **partial**

> Good screen respec and make proper tool

- *Page:* Running now (h-termux, verdict **rethink**). *Planned fate:* keeps.
- *Became:* redesigned (Running on this phone). *Units:* screen-phone-2, slice-P5.3. *Commits:* 66f6ed58, c0487f2c, 772ea0d9.
- *Owner note:* partly — respecified as a tool grouped by kind (OpenCode server, AI Team, Claude Code, dev services, terminals, helpers), measured Busy/Idle, MB, '18 of 32 background processes' budget, one stop per kind; but it is still Termux-only: the in-app host has no process inventory and This phone shows no row there (this_phone_screen.dart:895-900 inside the Termux-only branch)
- *Critics' findings:* yes — stops are labelled menu items/sheet buttons with the kit stop icon; empty state is a KitStateView (termux_processes_screen.dart:597-606)
- *Missing:* Host-neutral finish line not met: no callable process list for the in-app Linux (P5.3 README 'Blockers kept unavailable'); emulator proof + TalkBack walk not done *Fix owner:* Codex backend (in-app process inventory, codex-p53) then P5.3 follow-up on this_phone_screen.dart (medium impact).
- *Evidence:* `docs/qa/slice-P5.3-2026-09-27/README.md`

### termux-setup-connect-termux — **partial**

> Align with v2

- *Page:* Connect Termux once (h-termux, verdict **rethink**). *Planned fate:* merged->phone-setup-progress.
- *Became:* merged into phone-setup-progress (person-step row). *Units:* slice-P1.2. *Commits:* 935945d6, 2c8d8420.
- *Owner note:* yes — 'Connect Termux once' is a KitChecklist person-step row with 'Copy & open Termux'; returning re-checks; 'App settings' appears only after a denial (phone_setup_termux_job_screen.dart:586-597)
- *Critics' findings:* partly — card-in-card mock UI is gone (one checklist row, 'In Termux, paste the copied line and press Enter.'); but the no-answer text still says 'Open Termux once, run the unlock line, then verify again.' (app_en.arb:6916, used at phone_setup_termux_job_screen.dart:224) and the settings action is still labelled 'App settings'
- *Missing:* No-answer copy still uses 'run the unlock line' jargon; 'App settings' label not renamed to 'Allow the permission in Settings' *Fix owner:* app_en.arb e7SetupTermuxNoAnswer / e7SetupAppSettings (phone setup v2 owner) (low impact).
- *Evidence:* `lib/ui/screens/phone_setup/phone_setup_termux_job_screen.dart:424-446, 576-600`

### termux-setup-failed — **partial**

> Unify all installation into v2

- *Page:* [Setup failed] (h-termux, verdict **rethink**). *Planned fate:* merged->phone-setup-progress.
- *Became:* merged into phone-setup-progress (failed row + Continue setup). *Units:* slice-P1.2, slice-P1.3+P1.5, P8.4. *Commits:* 935945d6, 2045a435.
- *Owner note:* yes — one installer: a Termux failure is a failed checklist row with Continue setup, Report, network mapped to 'No internet', log under Details
- *Critics' findings:* partly — contradictions and 'Retry — resumes' are gone from the UI; but too-old Termux is a failed 'Get Termux' row whose only action is Continue setup (a re-check): personAction is offered only on pending rows (setup_progress_view.dart:296-298), so there is no 'Get the current Termux' link; non-network script errors are shown verbatim as the row text (setup_progress_view.dart:512-518)
- *Missing:* Too-old Termux state has no link to get the current Termux; only network failures are mapped to plain titles *Fix owner:* lib/ui/screens/phone_setup/phone_setup_termux_job_screen.dart (_Gate.outdated) + setup_progress_view.dart _failureText (low impact).
- *Evidence:* `lib/ui/screens/phone_setup/phone_setup_termux_job_screen.dart:476-500`

### termux-setup-update-sheet — **partial**

> Align with v2

- *Page:* Update managed OpenCode? (h-termux, verdict **rethink**). *Planned fate:* merged->phone-setup-progress.
- *Became:* merged into phone-setup-progress (confirm + v2 checklist). *Units:* slice-P1.2, slice-P1.5. *Commits:* 935945d6, 2045a435.
- *Owner note:* yes — Update on the Termux host runs as a v2 checklist job (openPhoneSetupTermux job: update)
- *Critics' findings:* partly — the same-version update is no longer offered (row hidden when up to date, this_phone_screen.dart:819-832); but the confirm keeps engine copy: title 'Update managed OpenCode?' (app_en.arb:6948), body 'restart only the managed local server' (:1611), 'Active generation should be stopped first' (:7468), used at this_phone_screen.dart:382-398
- *Missing:* Update confirm copy still in engine words; up-to-date state is hidden rather than shown as 'Up to date · version' *Fix owner:* lib/ui/screens/this_phone_screen.dart _update + app_en.arb e7SetupConfirmUpdate/setupRuntimeUpdateDetail/e7SetupUpdateInterruption (low impact).
- *Evidence:* `lib/ui/screens/this_phone_screen.dart:376-405`

### start-run-sheet — **done** (slice-close-team)

> Give the user recovery options?

- *Page:* Start a run (i2-team-sheets, verdict **fix**). *Planned fate:* keeps.
- *Became:* redesigned. *Units:* screen-team-2, slice-P3.5. *Commits:* a7bda280 (merge a2ba4379), 3ac501b7 (merge 998915e9).
- *Owner note:* partly — recovery landed for a lost draft (KitDraft per profile, restored on reopen), a refusal (the sheet stays open with the words) and the planner being off where the host creates work (goes straight to the direct-task form). Where neither path exists, the only way on is still 'Host guide'.
- *Critics' findings:* partly — the draft finding is fixed. The planner-off finding still stands: the title stays 'Give the team a task', the body uses engine words ('The planner (Mayor) is off… switch it to the full profile') and there is no Wake/Start the planner action even where controlAgent exists (start_run_sheet.dart:412-416, 676-700; strings app_en.arb:10687-10699).
- *Missing:* Planner-off with no direct path: title it 'This team can't take tasks right now', use plain words, and offer a recovery action (wake/start the planner when the host allows it, else the host guide). *Fix owner:* lib/ui/screens/team/start_run_sheet.dart (_PlannerOff) (medium impact).
- *Evidence:* `lib/ui/screens/team/start_run_sheet.dart:676`
- *Closed by slice-close-team:* with no planner awake and no direct path the sheet opens as "Team can't take tasks" (the glossary's four-word title rule, G28, keeps it shorter than the proposed 'This team can't take tasks right now'), says why in plain words ("The planner is switched off" / "This team has no planner" / "This team has no project yet"), and offers a way on: **Wake the planner** where the host takes agent controls (never for an agent the phone team keeps off), after which the task form opens by itself; elsewhere **Try again** and the Host guide. A refused wake says "Couldn't wake the planner" with the host's words only under Technical details. `TeamStartBlocked` in `lib/ui/screens/team/start_run_sheet.dart`; tests `test/slice_close_team_test.dart`.

### settings — **partial**

> Better layout also? And better search? And can an agent become my opencode configuration assistant help me figure it out, run an agent to research, spec,ckendand frontend also, this can be same as themcpp agent I mentionedeqrlier

- *Page:* Settings (j1-settings-more, verdict **fix**). *Planned fate:* keeps.
- *Became:* redesigned (P3.10 Settings IA). *Units:* screen-settings-1, slice-P3.10, slice-P9.4, slice-aisetup-review. *Commits:* 2bec3ed3, b8cd722b, 1a92d4d2, 01389539, 6962eb0b.
- *Owner note:* partly: the better layout landed (5 groups, at most 5 rows each, about 21 rows: settings_screen.dart:300-445), as did the better search (P9.4: typo tolerance, arrival at the row). The configuration-assistant agent did not: there is no 'Ask the setup assistant' row (P2.2). Only the review-only AI setup page exists, reached from Server settings and search (search_index.dart:989); it runs no agent and cannot change config
- *Critics' findings:* yes: there is one Model row, AI Team stays only in its own row, and there is one Privacy and data row and one About row, with voice licences moved into About's Open source group
- *Missing:* The owner's 'agent as my opencode configuration assistant' (P2.2 Ask the setup assistant, a seeded conversation) was not built. The owner deferred P2 'later'. Apply and Undo for config (P2.3) is blocked on server support. *Fix owner:* slice-P2.2 (owner-deferred) (medium impact).
- *Update 2026-09-28 (slice-P2.4-5):* the note's non-assistant parts, better layout and better search, were already done (P3.10, P9.4). The MCP catalogue this note links to ("same as the mcp agent I mentioned") now exists without the agent: see mcp-setup. Only the assistant itself is still open, and the owner has deferred it.
- *Evidence:* `docs/qa/slice-P3.10-2026-09-27/README.md`

### mcp-setup — **partial** (non-assistant parts done by slice-P2.4-5)

> Can we have two optios one technical users and one driven by ai agents where users can come and say I wantmcp installed or maybe connect with and oss mcp provider and show the mcp from thateposirto or provider in the app as toggles or somethin

- *Page:* Add MCP server (j2-library, verdict **fix**). *Planned fate:* keeps.
- *Became:* redesigned (form); owner's two-path setup not built. *Units:* screen-library-2, P0.1, slice-aisetup-review. *Commits:* aa3c3729, 8c743a97, 6962eb0b.
- *Owner note:* partly: only the technical path exists. There is no Add chooser (P2.4 mcp-add-sheet) and no registry catalogue as toggles (P2.5 mcp-catalog). A registry client exists (lib/domain/setup_registry.dart:161, registry.modelcontextprotocol.io) but no UI uses it. The AI setup page merged 2026-09-28 (6962eb0b) is review-only: it lists MCP servers from Server settings but cannot install one
- *Critics' findings:* yes: headers are key rows with a secret value (mcp_setup_screen.dart:39-41, P0.1), and Headers, OAuth detection and Timeout sit under an Advanced KitExpandRow (:475). Minor: timeout is still entered in milliseconds (:233)
- *Missing:* The owner's 'two options' is missing: the agent-driven path (Ask the setup assistant) and the OSS registry catalogue as toggles. P2 was deferred 'later' by the owner, and agent-driven install also needs P2.3 Apply, which is blocked on server support. *Fix owner:* slice-P2.4 (mcp-add-sheet), slice-P2.5 (mcp-catalog), slice-P2.2 (owner-deferred) (medium impact).
- *Update 2026-09-28 (slice-P2.4-5, owner decision to build P2.4 and P2.5 now):* the technical path and the OSS provider path now both exist. MCP › Add opens the add sheet: **Browse the catalogue** · **Enter manually** (`lib/ui/screens/mcp_catalog_screen.dart` `showMcpAddSheet`). The catalogue lists servers from the public MCP registry (registry.modelcontextprotocol.io, `GET /v0.1/servers`, no credentials; verified live) as switches, each with what it is, where it runs (hosted by / needs Node / needs Python) and what it needs (API key, extra settings), plus one line on price. Turning one on opens the same manual form filled in from the listing, so the same Save and the same gateway call add it. Turning one off runs the MCP page's removal where the server supports it. On a phone host a Node server offers This phone › Add tools › Node. Critic's minor: the timeout is now entered in seconds. Still missing, owner-deferred: the agent-driven path (P2.2 Ask the setup assistant). The add sheet leaves it out rather than showing a row that does nothing. *Evidence:* `docs/qa/slice-P2.4-5-2026-09-28/README.md`, `test/revamp/slice_p2_4_5_test.dart`.
- *Evidence:* `lib/ui/screens/mcp_setup_screen.dart:475`

### voice-composer-sheet — **in progress**

> Why only 30 seconds, this needs rework

- *Page:* [Voice input] (status: Ready for local voice input / Listening …) (d-chat-sheets, verdict **rethink**). *Planned fate:* merged->embedded-composer voice mode.
- *Became:* restyled on HEAD; the merge into composer voice mode is built but not merged. *Units:* screen-voice-1, P10.3. *Commits:* 83af7522, 3273d7ef (revamp/slice-P10.3-P6.3, unmerged).
- *Owner note:* no (in flight): HEAD still caps dictation at 30 s (lib/voice/audio.dart:11 voiceMaximumDuration = 30 s, enforced at lib/voice/controller.dart:156). P10.3's '30 s chunks with no cap' fix is only on the unmerged branch
- *Critics' findings:* no (in flight): the discard warning 'Unsent text is discarded when you leave voice mode...' still shows (voice_ui.dart:986, app_en.arb:706 voiceConversationInstructions)
- *Missing:* Merge P10.3: no cap, the transcript kept in the composer draft, and the sheet removed. *Fix owner:* slice-P10.3 (worktree oc_app-slice-P10.3-P6.3) (high impact).
- *Evidence:* `lib/voice/audio.dart:11`

### team-agent-reassign-sheet — **in progress**

> Why manual it's all about automated dev right

- *Page:* Reassign work to {agent} (i1-team-core, verdict **rethink**). *Planned fate:* removed.
- *Became:* removed. *Units:* screen-team-1. *Commits:* 346ca55c (merge 30dbf42c).
- *Owner note:* partly — manual reassign is gone (agent_screen.dart:39-41: 'the dispatcher routes ready work'). The automatic side the owner asked for ('team starts at once', P6.3) is still on revamp/slice-P10.3-P6.3 (fb40c24f, not merged into HEAD).
- *Critics' findings:* moot — the sheet no longer exists (no Reassign sheet or strings in lib/; only the assign receipt label remains).
- *Missing:* P6.3 immediate dispatch (team starts at once) is not merged yet. *Fix owner:* revamp/slice-P10.3-P6.3 (P6.3) (medium impact).
- *Evidence:* `lib/ui/screens/team/agent_screen.dart:39`

### session-link-server-missing-banner — **blocked**

> Screen sucks

- *Page:* This server is not saved on this phone. Add it under Servers, then scan the code again. (a-shell, verdict **fix**). *Planned fate:* keeps.
- *Became:* redesigned. *Units:* slice-P3.9, coord-main, slice-sessionlink-ui. *Commits:* 3d251f37, d7d70913.
- *Owner note:* partly — the banner is now an 'Add this server?' sheet whose primary opens Add server. But Add server opens empty and the body still says 'then scan the code again', because a local link carries no address.
- *Critics' findings:* partly — one round trip removed. Filling Add server from the link and continuing to the conversation are built (session_address_sheets.dart) but gated off.
- *Missing:* Address-carrying session links are built but gated off (ServerCapabilities.sessionAddressHandoff false on every adapter) until host verification exists. Until then there is no prefill and no automatic continue. *Fix owner:* backend gate (docs/qa/codex-sessionlink-2026-09-28), then lib/main.dart _showSessionLinkServerMissing (medium impact).
- *Evidence:* `lib/main.dart:1306-1330`

### command-launcher-sheet — **blocked**

> We need a better UI and there should be at.sheet ina sense right? Also run an agent to think how tovisually represent these in ai, at the end of the day we are out of the terminal rightand what about using Claude or codex will this support their commands?

- *Page:* Commands (b2-chat-screen, verdict **rethink**). *Planned fate:* keeps.
- *Became:* redesigned. *Units:* chat-4, slice-P10.1-2. *Commits:* 34353c2f, ca043f36.
- *Owner note:* partly — one sheet now serves '/', '+ Commands', Ctrl+K and the Library tab, with plain-word titles and the slash form as a trailing hint. Claude Code and Codex commands are not supported: the sheet names them as missing and does not send a typed /cmd or !cmd. No visual-representation study is recorded.
- *Critics' findings:* yes — no 'mobile' tag; the action leads and /slash is a trailing mono hint (command_sheet.dart:640-660); /warp shows only with the workspaceWarp capability. The title is 'Commands and agents' because the sheet also has a Delegate tab.
- *Missing:* Claude Code (Paseo) and Codex command catalogues. No callable, live-tested list, run and output contract exists (ServerCapabilities.slashCommands is false on both gateways). *Fix owner:* Codex backend queue (docs/qa/codex-p101-2026-09-27) then lib/ui/widgets/command_sheet.dart (medium impact).
- *Evidence:* `docs/qa/slice-P10.1-2-2026-09-28/README.md`

### local-agent-page — **blocked**

> I will assume you are going to make this inline with installationv2 that we have already.his needs be specced in and alsohinkf users who started with opencode and now wants to mix both.

- *Page:* Claude Code (h-termux, verdict **rethink**). *Planned fate:* merged->phone-component-sheet.
- *Became:* restyled (kit shell only; merge into phone-component-sheet not built). *Units:* screen-phone-1, slice-P1.6b (not started). *Commits:* 5088cc85; gate 01c3e7a2, fd8ab222, 6ff049d9.
- *Owner note:* partly — specced (programmes.json P1.6b: 'claude' component in Customize/Add tools on either host, 'Sign in to Claude' person-step, 'This phone · Claude Code' next to 'This phone · OpenCode') but not built; the Claude Code row on This phone appears only on the Termux host (this_phone_screen.dart:872 'if (!inApp)'), so in-app OpenCode users cannot mix in Claude Code
- *Critics' findings:* no — LocalAgentScreen is a KitScreen shell (local_agent_screen.dart:22 '// revamp: redesign (slice-P1.6b)') wrapping the same bordered card (local_agent_onboarding.dart:657-676) with the name twice, right-aligned button clusters (:744-755, :928-948), and engine copy ('Paseo daemon' step, app_en.arb:12317, :12357)
- *Missing:* P1.6b not built: blocked by gate-P1.6a NO-GO/incomplete on ARM64 (Claude native optional dependency absent; Paseo/auth unverified); ClaudeScripts prepared but not registered. Note: a Termux-host-only v2 component would not depend on the in-app ARM64 gate, but the coordinator kept P1.6b unavailable as a whole *Fix owner:* slice-P1.6b (Codex backend + Claude UI) after gate-P1.6a (high impact).
- *Evidence:* `docs/qa/gate-P1.6a-2026-09-28/README.md; lib/ui/screens/local_agent_screen.dart:12-22`

### attention-overview — **done**

> Rethink and spec, deletingis an option if it's not required.

- *Page:* Server attention (a-shell, verdict **rethink**). *Planned fate:* removed.
- *Became:* removed. *Units:* reachability pass (retired), slice-P4.2b (job moved to Inbox). *Commits:* 666fae3b, 2c1c783f.
- *Owner note:* yes — the page is deleted (owner allowed deletion). 'Which server needs me' is now the one Inbox list across saved servers.
- *Critics' findings:* moot — page removed; lib/ui/screens/attention_overview_screen.dart is gone and nothing in lib/ references it.
- *Evidence:* `git show --stat 666fae3b (Retired: AttentionOverviewScreen); lib/ui/screens/activity_screen.dart:891-893`

### chat-pending-photo-sheet — **done**

> I don't understand you decide

- *Page:* Pending photo (b1-chat-screen, verdict **rethink**). *Planned fate:* removed.
- *Became:* removed. *Units:* slice-P3.2. *Commits:* 331179d0.
- *Owner note:* yes — the owner said 'you decide': the blocking sheet is gone. A waiting photo now joins its own conversation's draft with no question; the one that belongs here is a row with add, discard and preview.
- *Critics' findings:* moot — sheet removed; a photo that cannot move yet gives one line (photoPendingOther) and no destructive choice.
- *Evidence:* `lib/ui/screens/chat_screen.dart:3295-3310`

### termux-setup-choose — **done**

> Align with v2

- *Page:* Choose how to continue (h-termux, verdict **rethink**). *Planned fate:* merged->phone-setup-customize-sheet.
- *Became:* removed (merged into phone-setup-start / customize). *Units:* slice-P1.2, slice-P1.3+P1.5. *Commits:* 935945d6, 2045a435.
- *Owner note:* yes — the Termux path is phone setup v2: start screen › Other ways › Use Termux opens the same checklist (PhoneSetupTermuxJobScreen) with Customize/Add tools; no separate runtime-choice screen, no competing in-app block, Claude Code not mixed into the choice
- *Critics' findings:* moot — screen deleted; leftover wizard strings (e7SetupChooseContinue, e7SetupNoUbuntu) survive only as native-message translations in setup_ui_messages.dart:276, :336
- *Evidence:* `lib/ui/screens/phone_setup/phone_setup_termux_job_screen.dart:25-36`

### termux-setup-connected — **done**

> Align with v2

- *Page:* [OpenCode is running on this phone] (h-termux, verdict **rethink**). *Planned fate:* merged->phone-setup-ready.
- *Became:* merged into phone-setup-ready. *Units:* slice-P1.2. *Commits:* 935945d6.
- *Owner note:* yes — a first Termux setup ends on PhoneSetupReadyScreen (host: termux) like the in-app one; updates/switches end back on This phone
- *Critics' findings:* moot — the wizard's success state with seven actions is deleted; server controls live on This phone
- *Evidence:* `lib/ui/screens/phone_setup/phone_setup_termux_job_screen.dart:321-324`

### termux-setup-get-termux — **done**

> Incorporate in installav2

- *Page:* Get Termux (h-termux, verdict **rethink**). *Planned fate:* merged->phone-setup-progress.
- *Became:* merged into phone-setup-progress (person-step row). *Units:* slice-P1.2. *Commits:* 935945d6, 2c8d8420.
- *Owner note:* yes — 'Get Termux' is the first person-step row of the v2 checklist with one action through openExternalLink (phone_setup_termux_job_screen.dart:339, :581-585); Termux is reached only from phone setup's Other ways
- *Critics' findings:* yes — the four competing paths are gone; row detail 'Install the current F-Droid build of Termux, then return here.'
- *Evidence:* `lib/ui/screens/phone_setup/phone_setup_termux_job_screen.dart:443-446`

### termux-setup-installing — **done**

> Align with v2

- *Page:* [Setup progress: Preparing setup / Setting up Ubuntu / Installing OpenCode / Getting models ready / Starting local server / Restarting local server / Switching to {runtime}] (h-termux, verdict **rethink**). *Planned fate:* merged->phone-setup-progress.
- *Became:* merged into phone-setup-progress. *Units:* slice-P1.2. *Commits:* 935945d6, 2c8d8420.
- *Owner note:* yes — Termux install/update/switch run in the same SetupProgressView (KitChecklist with marks, determinate bar, ETA, log under Details)
- *Critics' findings:* yes — rows are named by runtime (OpenCode 1/2), not the beta build string; the raw log is folded
- *Evidence:* `lib/ui/screens/phone_setup/phone_setup_termux_screen.dart:23-31, 406`

### team-home — **done**

> You decide and rethink

- *Page:* AI Team (i1-team-core, verdict **rethink**). *Planned fate:* keeps.
- *Became:* redesigned (one page). *Units:* screen-team-2, slice-P3.4, slice-P5.2, slice-P5.1. *Commits:* d42ba768 (merge aa40d789), 10cf32d9 (merge 9ea6cf2f), e5148e4a.
- *Owner note:* yes — rethought as one page: the team's Now line only when the rows can't say it, what needs you with no heading, one task list by urgency, the team panel (agents, how it runs, today's estimate) and Turn off in the menu. Off state on the same page.
- *Critics' findings:* yes — the task whose question is carded is left out of the task list (team_home_screen.dart:704-707 'run.id != carded?.id'). Several questions become their task rows. Not answering has its own words (P3.4).
- *Evidence:* `docs/qa/slice-P3.4-2026-09-27/README.md`

### team-phone-onboarding-steps — **done**

> Align with v2

- *Page:* Setting up the AI team (i2-team-sheets, verdict **rethink**). *Planned fate:* merged->phone-setup-progress.
- *Became:* merged into phone-setup-progress (phone setup v2). *Units:* slice-P1.7. *Commits:* 802e46f9 (merge 56887008).
- *Owner note:* yes — 'Align with v2': openTeamOnThisPhone runs AI Team as a v2 Add-tools job on the host's progress screen. The old five-step Termux block is gone, and TeamPhoneReadyScreen uses the phone-setup hero (team_phone_onboarding.dart:1-22).
- *Critics' findings:* moot — progress, cancel and log folding now belong to phone setup v2's progress screen.
- *Evidence:* `docs/qa/slice-P1.7-2026-09-27/README.md`

### app-diagnostics — **done**

> We need a first grade page that users willingly willuse toaise bugs and also this page should be accessibleen errors happen across app

- *Page:* App diagnostics (j1-settings-more, verdict **fix**). *Planned fate:* keeps.
- *Became:* redesigned (Report a problem page). *Units:* screen-system-1, slice-P8.1, slice-P8.2, P8.3, slice-P8.4. *Commits:* 1505b849, 10699f50, a4b3369d, 46380182, c274356e.
- *Owner note:* yes: it is now a first-grade Report a problem page (describe the problem, the attached error, optional redacted diagnostics, then Review report with a preview of exactly what is sent, then a GitHub form, Copy or Share). It is reachable from errors across the app: main.dart:161 sets KitReportHook.handler = openReportProblem, so every non-network KitStateView.error or KitNotice error offers 'Report a problem' (kit_state_view.dart:408-416, kit_notice.dart:366-372), which covers 74 call sites in 41 files, plus the team gate sheet and failed jobs with their log (P8.4)
- *Critics' findings:* yes: one primary 'Review report' leads the page and the errors list follows. Clear errors sits on the list header with a confirm that states the count. Clear timings is a destructive item in the Performance overflow menu (perf_trace_section.dart:57-63), and no red monospace step names remain
- *Evidence:* `lib/ui/screens/app_diagnostics_screen.dart:25 (+ lib/main.dart:161)`

### legacy-drafts-review-sheet — **done**

> Do we even need this?

- *Page:* Older drafts (j1-settings-more, verdict **fix**). *Planned fate:* merged->prompt-stash-sheet.
- *Became:* removed (migrated into Saved prompts). *Units:* slice-P3.2. *Commits:* 331179d0, 05473fe1.
- *Owner note:* yes: the answer to 'do we even need this?' was no. Older drafts migrate once into Saved prompts (lib/state/migration_runner.dart:41) and lib/ui/screens/legacy_drafts_screen.dart is deleted
- *Critics' findings:* moot: the page is deleted
- *Evidence:* `docs/qa/slice-P3.2-2026-09-27/README.md`

### context-capsule — **done**

> It's a glorifiednputoxi would kill itif not needed, users candump all this into the input box anyway

- *Page:* Context capsule (k-session-misc, verdict **fix**). *Planned fate:* removed.
- *Became:* removed. *Units:* slice-P3.3 (P3.1 deferred it). *Commits:* 3fcace2c, c90ff900.
- *Owner note:* yes — the owner said kill it. context_capsule_screen.dart is deleted and nothing in lib/ references it.
- *Critics' findings:* moot — page removed.
- *Evidence:* `git show --stat 3fcace2c ('context capsule gone'); only a stale reference remains in test/calm_chat_disclosure_test.dart`

### embedded-info-label — **done**

> Wtf is this page? Kill if not neededor show tool tip?

- *Page:* [Info label: term with info glyph] (k-session-misc, verdict **fix**). *Planned fate:* removed.
- *Became:* removed. *Units:* kit-KitTerm, slice-P3.1. *Commits:* b98b1933, 496a4583.
- *Owner note:* yes — the owner said 'kill or tooltip'. info_label.dart and its Glossary are deleted; terms are now KitTerm tooltips.
- *Critics' findings:* moot — KitTerm has a 48 dp minimum target (kit_term.dart:29, 691).
- *Evidence:* `lib/ui/kit/kit_term.dart:1-30`

## The other 140 pages

Gaps are shortened here; every non-done row is listed in full under **Gaps** below.

| Page | Area | Verdict | Became | Status | Units · commits | Gap | Evidence |
|---|---|---|---|---|---|---|---|
| activity | a-shell | fix | redesigned | done | screen-shell-1, slice-P4.2a, slice-P4.2b (inbox-work), slice-P6.2 · 24adc02d, 2c1c783f, … |  | lib/ui/screens/activity_screen.dart:930-948 |
| bootstrap-gate | a-shell | fix | redesigned | done | coord-main · c274356e, 2c8efba4 |  | lib/main.dart:328-375 |
| connection-status-details-sheet | a-shell | rethink | merged into root-connecting / shell status line | partial | shared-shell-1, slice-P4.4 · 781933fb, 3fe463f8 | The raw error fold starts open instead of collapsed. | lib/ui/widgets/connection_status_banner.dart:198-276 |
| embedded-connection-status-banner | a-shell | fix | redesigned | done | shared-shell-1, slice-P4.4 · 781933fb, fe34c91f |  | docs/qa/slice-P4.4-2026-09-28/README.md |
| embedded-product-states | a-shell | fix | removed | done | shared-system-1, kit-hygiene, no-raw-errors · bbb3577f, 4316dc8c, 6cdfca4e |  | lib/ui/widgets/product_states.dart:13-21 |
| home-shell | a-shell | rethink | redesigned | done | screen-shell-2, slice-P1.3, slice-P4.4 · f4b7a51f, 2045a435 |  | lib/ui/screens/home_screen.dart:471-490 |
| question-sheet | a-shell | fix | redesigned | done | screen-shell-1 · 24adc02d |  | lib/ui/screens/activity_screen.dart:1902-2025 |
| root-connecting | a-shell | fix | redesigned | done | coord-main, slice-P1.3, slice-P4.4 · 2c8efba4, 781933fb |  | lib/ui/widgets/saved_server_connection_card.dart:310-390 |
| share-session-failed-banner | a-shell | fix | redesigned | done | coord-main · c274356e, 2c8efba4 |  | lib/main.dart:678-726 |
| shorebird-update-notice | a-shell | fix | redesigned | done | screen-system-2 · 5a42b94d, ff9a4446 |  | lib/update/shorebird_update_notice.dart:273-287 |
| chat | b1-chat-screen | fix | redesigned | partial | chat-7, chat-8, chat-9, slice-P3.6, slice-P3.7b, slice-P4.4, P7.5 · 01634614, 064d7211, … | Assistant text before the last tool step still folds into the work line in finished turns, so the answer's explanation can be hidden. This conflicts … | lib/ui/screens/chat/message_view.dart:529-570 |
| chat-leave-unsaved-draft-sheet | b2-chat-screen | fix | restyled | not done | chat-7, chat-8, chat-9 · 01634614 | No 'Copy draft and leave' primary and no 'Try saving again'; the copy still points to actions the sheet does not offer. | lib/ui/screens/chat_screen.dart:6751-6760 |
| chat-revert-confirm-sheet | b2-chat-screen | rethink | merged into stage-revert-sheet | done | slice-P3.7b · 2b858465, 0b6fd5b3 |  | docs/qa/slice-P3.7b-2026-09-27/README.md |
| chat-run-shell-dialog | b2-chat-screen | fix | restyled | partial | chat-7, chat-8, chat-9, slice-P10.1 · 01634614, 34353c2f | The command field is still one line. It needs to show 1–4 mono lines so the whole command is readable. | lib/ui/screens/chat_screen.dart:4985-5010 |
| session-menu-sheet | b2-chat-screen | rethink | redesigned | done | chat-5, slice-P10.2 · 34353c2f, ca043f36 |  | lib/ui/widgets/session_menu.dart:11-31 |
| chat-read-aloud-consent-sheet | c-chat-compose | fix | fixed | partial | chat-6 · e52f11c4, edd086b4 | Consent is not remembered across conversations or app restarts. It resets on every scope change. | lib/ui/screens/chat/read_aloud.dart:82-120 |
| embedded-composer | c-chat-compose | fix | redesigned | partial | chat-3, slice-P4.4 (KIT-24), P7.5/P7.7 · e28442b0, 74412bb5 | In the working state with text, show one trailing control (Send), not Stop+Send, and move expand into the field corner. | lib/ui/kit/chat/kit_composer.dart:385-403 |
| embedded-message-view | c-chat-compose | fix | redesigned | done | chat-1 · 557920e3, fcf193c8 |  | lib/ui/kit/chat/kit_work_line.dart:380-420 |
| embedded-prompt-error-banner | c-chat-compose | fix | fixed | partial | chat-6, slice-P4.4 · e52f11c4, 781933fb | Add a one-tap 'Use <suggestion> and resend' and mark the failed prompt Not sent with Retry. | lib/ui/screens/chat/chat_states.dart:176-221 |
| embedded-transcript-find-bar | c-chat-compose | fix | restyled | partial | chat-6 · e52f11c4 | The match excerpt card still repeats the count. Keep the count in the bar only and highlight in place. | lib/ui/widgets/transcript_highlight.dart:111-150 |
| prompt-history-sheet | c-chat-compose | fix | fixed | done | chat-3 · e28442b0 |  | lib/ui/screens/chat_screen.dart:982-991 |
| prompt-stash-sheet | c-chat-compose | fix | redesigned | done | chat-3, slice-P3.2 · e28442b0, 331179d0 |  | lib/ui/screens/chat/prompt_stash.dart:275-310 |
| embedded-completion-digest-card | d-chat-sheets | rethink | merged into activity (Inbox 'Finished' KitExpandRow), but … | partial | slice-P4.2b · 2c1c783f, 53c2bf2a | The row landed, but its body was not rebuilt. It should say only what is known ('Finished · 9 files changed · nothing waiting on you'), put … | lib/ui/widgets/completion_digest.dart:54 |
| embedded-markdown-text | d-chat-sheets | fix | restyled (KitMarkdown) | done | kit-KitMarkdown, kit-hygiene · 79d941e4, 0e57c30f, 4316dc8c |  | lib/ui/kit/chat/kit_markdown.dart:754 |
| embedded-permission-attention-card | d-chat-sheets | fix | redesigned (one KitRequestCard) | done | chat-5 · ec709a5d, c79b4494 |  | lib/ui/screens/chat/attention_card.dart:52 |
| embedded-tool-card | d-chat-sheets | fix | redesigned (kit tool rows) | done | chat-2 · db11d2d9, c7443538 |  | lib/ui/widgets/tool_card.dart:696 |
| embedded-voice-conversation-controls | d-chat-sheets | rethink | unchanged on HEAD (the merge into composer voice mode is … | in progress | chat-5, P10.3 · 3273d7ef (revamp/slice-P10.3-P6.3, unmerged) | P10.3 (voice as a composer mode) is not merged, so the separate voice-conversation controls still exist in … | lib/ui/screens/chat/voice_conversation.dart:420 |
| form-sheet | d-chat-sheets | fix | restyled (KitSheet) | done | shared-chat-2 · da07313f |  | lib/ui/widgets/form_renderer.dart:79 |
| markdown-code-reader | d-chat-sheets | fix | redesigned | done | kit-KitMarkdown, kit-KitCodeBlock · 79d941e4, 0e57c30f |  | lib/ui/widgets/markdown.dart:241 |
| permission-sheet | d-chat-sheets | fix | redesigned (KitRequestSheet) | done | chat-5 · ec709a5d, c79b4494 |  | lib/ui/screens/chat/permission_sheet.dart:277 |
| session-approvals-sheet | d-chat-sheets | fix | redesigned | partial | chat-5, P6 · ec709a5d, 0b171ac3 | Say the new-conversation rule once and remove the contradicting footer sentence from approvalsUiServerRulesNote. | lib/ui/screens/chat/approvals_sheet.dart:186 |
| todos-sheet | d-chat-sheets | rethink | merged into embedded-message-view (Tasks step checklist) | done | chat-6 · e52f11c4, edd086b4 |  | lib/ui/screens/chat/session_sheets.dart:3 |
| voice-model-setup-sheet | d-chat-sheets | rethink | redesigned | done | screen-voice-1, slice-P10.4 · 83af7522, 5c36473d |  | lib/voice/voice_ui.dart:290 |
| voice-notices | d-chat-sheets | fix | redesigned; moved under About > Open source | done | screen-voice-1, slice-P3.10 · 83af7522, 2bec3ed3 |  | lib/voice/notices.dart:155 |
| console-organization-sheet | e-workspace | rethink | redesigned | done | screen-chat-1 · 63b5410f, 251e50c8 |  | lib/ui/screens/session_destination_sheet.dart:697-727 |
| embedded-mobile-task-list | e-workspace | fix | redesigned | done | chat-2 · db11d2d9, c7443538 |  | lib/ui/widgets/mobile_task_view.dart:78-85 |
| embedded-session-inventory-footer | e-workspace | rethink | removed | done | slice-P3.1 · 496a4583 |  | lib/ui/widgets/older_sessions_pager.dart:1-15,103-108 |
| global-sessions | e-workspace | rethink | redesigned | done | screen-work-2, slice-R13 · 93e42ef3, 80e9b414 |  | lib/ui/screens/global_sessions_screen.dart:150-206,936-941 |
| global-sessions-continue-here-sheet | e-workspace | fix | fixed | partial | screen-work-2 · 93e42ef3 | Engine wording 'through the server's sync system' still in globalSessionsMoveBody | lib/ui/screens/global_sessions_screen.dart:658-667 |
| isolated-task-sheet | e-workspace | fix | redesigned (slice-close-team: 'Start in a separate copy', asks 'What should it work on?' and sends it after setup; Start anyway / Remove the copy on a failed setup; setup output under Details; 'Run setup again' left out, no proven contract) | done | screen-work-4, slice-P4.5 · 3599f22f, a2605a09, 8a5113ef | Ask 'What should it work on?' and send it after setup; title 'Start in a separate copy' + plain body with path/branch under Details; rewrite the … | docs/qa/revamp-slice-P4.5-2026-09-27/README.md (map items: 'write the first prompt' … no … |
| managed-workspaces | e-workspace | fix | redesigned | done | screen-work-3 · 9e901d21, acbfc9a7 |  | lib/ui/screens/managed_workspaces_screen.dart:341-372,597-627 |
| managed-workspaces-create-dialog | e-workspace | fix | redesigned | done | screen-work-3 · 9e901d21 |  | lib/ui/screens/managed_workspaces_screen.dart:684-720 |
| project-health | e-workspace | fix | redesigned | partial | screen-work-3 · 9e901d21 | Split 'Couldn't read Git status' + Try again from 'This server doesn't report Git status' with no retry | docs/qa/revamp-screen-work-3-2026-09-27/README.md (line 19, 29) |
| projects | e-workspace | fix | redesigned | done | screen-work-4 · 3599f22f, fd451271 |  | lib/ui/screens/projects_screen.dart:375-395 |
| running-work-sheet | e-workspace | fix | redesigned | done | screen-chat-1, slice-P5.3 · 63b5410f, 251e50c8 |  | lib/ui/screens/running_work_sheet.dart:536-573 |
| session-destination-sheet | e-workspace | fix | redesigned | done | screen-chat-1 · 63b5410f |  | lib/ui/screens/session_destination_sheet.dart:390-399,570-577 |
| shell-output | e-workspace | fix | redesigned | done | screen-chat-1 · 63b5410f |  | lib/ui/screens/running_work_sheet.dart:955-975 |
| workspace | e-workspace | rethink | redesigned | done | screen-work-1, slice-P4.5, slice-P3.12, slice-inbox-work (P5.5) · 23b2efb5, a2605a09, … |  | lib/ui/screens/workspace_screen.dart:1134-1143,2342-2364 |
| workspace-folder-chooser | e-workspace | fix | fixed | done | screen-work-1, slice-P3.11a · 23b2efb5, 00cafa13 |  | lib/ui/screens/workspace_screen.dart:2445-2493 |
| workspace-session-details-sheet | e-workspace | rethink | merged into session-context | done | screen-work-1, slice-P3.11a · 00cafa13, 674f8182 |  | lib/ui/screens/session_context_screen.dart:767-788 |
| worktrees | e-workspace | fix | redesigned | done | screen-work-2 · 93e42ef3, d764b1a0 |  | lib/ui/screens/worktrees_screen.dart:456-540 |
| worktrees-create-dialog | e-workspace | fix | fixed | done | screen-work-2 · 93e42ef3 |  | lib/ui/screens/worktrees_screen.dart:223-230 |
| diff-view | f-files-review-terminal | rethink | merged into review-workspace's KitDiffView (DiffPage) | partial | kit-KitDiffView, slice-P3.7a, slice-R7 · d4f01730, f8337516, 0047e87e | Multi-file title still 'Review' (reviewTitle) instead of 'Changes · N files' | lib/ui/screens/review_workspace.dart:975-1036 |
| file-preview-sheet | f-files-review-terminal | rethink | redesigned | done | shared-files-1, screen-files-1 · 036e14a3, d79038aa |  | lib/ui/widgets/file_preview.dart:383-440 |
| files | f-files-review-terminal | fix | redesigned | done | screen-files-1, slice-P3.7a · 6f21d378, 4e0f79f9, d4f01730 |  | lib/ui/screens/files_screen.dart:1218-1232 |
| files-file-viewer-sheet | f-files-review-terminal | rethink | merged into file-preview-sheet (KitViewer) | done | screen-files-1, shared-files-1 · 6f21d378, 036e14a3 |  | lib/ui/kit/kit_viewer.dart:691-699,854-859 |
| files-row-actions-sheet | f-files-review-terminal | fix | merged into files (row menu) | done | screen-files-1 · 6f21d378 |  | lib/ui/screens/files_screen.dart:1397-1460 |
| project-hub | f-files-review-terminal | fix | redesigned | done | screen-files-1, slice-P3.11a, slice-close-misc · 6f21d378, 00cafa13 | Closed by slice-close-misc: Changes says "3 files changed" / "No changes", Terminal "1 running"; read on open, project change, tool close and when the last conversation finishes (no poller). Changes first already held. | lib/ui/screens/project_hub_screen.dart (_readStatus) |
| review-comment-sheet | f-files-review-terminal | fix | redesigned | done | screen-review-1 · 8a424e7c, e83b720c |  | lib/ui/screens/review_workspace.dart:636-695 |
| review-workspace | f-files-review-terminal | fix | redesigned | done | screen-review-1, slice-P3.7a, slice-R7 · 8a424e7c, 2cbeebe9, d4f01730 |  | test/revamp/goldens/review_loaded_light.png |
| stage-revert-sheet | f-files-review-terminal | fix | redesigned | done | screen-review-2, slice-P3.7b · af410fb8, 2b858465, 0b6fd5b3 |  | lib/ui/screens/staged_revert_screen.dart:136-215 |
| staged-revert | f-files-review-terminal | fix | redesigned | partial | screen-review-2 · af410fb8, 0a4020b2 | State 'Files were put back' / 'Files were left as they are' (SessionRevert has no applyFiles flag; the app could remember the choice it sent) | docs/qa/revamp-screen-review-2-2026-09-27/README.md (line 25) |
| terminal | f-files-review-terminal | fix | redesigned | done | screen-terminal-1, slice-R18 · 6b2903df, 443f4b47, c0efb78c |  | lib/ui/screens/terminal_screen.dart:639-650 |
| terminal-surface | f-files-review-terminal | fix | redesigned | done | screen-terminal-1 · 6b2903df |  | lib/ui/screens/terminal_screen.dart:1380-1420 |
| add-agent | g-servers | rethink | redesigned | done | screen-library-2 · 93f915ac, 8c743a97 |  | lib/ui/screens/external_agents_screen.dart:395 |
| agent-account | g-servers | fix | restyled | partial | screen-usage-1, slice-P5.4 · 82eb38cc, 64437e87 | Plain sign-in copy ('Sign in with your ChatGPT account. You finish in the browser; this app never sees your password.') was never applied. The kit … | test/revamp/goldens/agent_account_signed_out_dark.png |
| agent-choice | g-servers | rethink | merged into profile-editor (Add server step 1) | done | slice-P3.9 · 3d251f37, 24b76eb8 |  | test/revamp/goldens/servers_addserver_kind_dark.png |
| connection-help | g-servers | rethink | merged into profile-editor (inline advice) | done | slice-P3.9 · 3d251f37, 24b76eb8 |  | docs/qa/slice-P3.9-2026-09-27/README.md |
| embedded-profile-monitor-inbox | g-servers | fix | redesigned | done | screen-servers-2, slice-P4.2b (slice-inbox-work) · 337b478d, 53c2bf2a |  | lib/ui/screens/profile_monitor_screen.dart:339 |
| external-agent-detail | g-servers | fix | redesigned | done | screen-library-2 · 93f915ac, 8c743a97 |  | lib/ui/screens/external_agents_screen.dart:744 |
| external-agent-detail-input-dialog | g-servers | fix | fixed | done | screen-library-2 · 93f915ac |  | lib/ui/screens/external_agents_screen.dart:680 |
| external-agents | g-servers | rethink | merged into Tools hub (capabilities), list redesigned | done | screen-library-2, slice-P3.10 · 93f915ac, 2bec3ed3, b8cd722b |  | lib/ui/screens/external_agents_screen.dart:237 |
| external-task | g-servers | fix | redesigned | done | screen-library-2 · 93f915ac |  | lib/ui/screens/external_agents_screen.dart:1118 |
| host-management | g-servers | rethink | restyled | not done | screen-servers-2, slice-R15 · 337b478d, 0bc6651e | Pin the script to a release tag, show a checksum, add a 'What this does' fold, say it is Linux only, and add a way to check it is running. | lib/ui/screens/host_management_screen.dart:33 |
| profile-editor-discard-sheet | g-servers | fix | fixed | done | screen-servers-1 · 71417a2f, 62592cfc |  | lib/ui/screens/servers_screen.dart:2327 |
| profile-monitor | g-servers | rethink | removed (merged into the Inbox and Notifications) | done | screen-servers-2, slice-P4.2b (slice-inbox-work), slice-P3.9, slice-close-misc · 337b478d, 2c1c783f, … | Closed by slice-close-misc: ProfileMonitorScreen deleted; the Servers row is gone; search "Background checks" and the Inbox "Not checking …" row open Notifications at the saved servers' checks. The green dot and engine words went with the page. | lib/ui/screens/profile_monitor_screen.dart (ProfileMonitorInbox only) |
| provider-quota-clear-dialog | g-servers | fix | removed | done | screen-usage-2, 531bb6ab (owner rules R1-R6) · 531bb6ab |  | git show 531bb6ab -- lib/ui/screens/provider_quota_screen.dart |
| provider-quota-enroll-dialog | g-servers | rethink | merged into provider-quota | done | slice-P3.11a, slice-P5.4 · 00cafa13, 674f8182, 43b14616 |  | docs/qa/slice-P3.11a-2026-09-27/README.md |
| server-settings | g-servers | fix | redesigned | done | screen-servers-2, slice-P1.3, slice-R15 · 337b478d, 2045a435, 0bc6651e |  | lib/ui/screens/settings/server_settings_screen.dart:78 |
| server-settings-restart-dialog | g-servers | fix | redesigned (kit sheet) | done | screen-servers-2 · 337b478d |  | lib/ui/screens/settings/server_settings_screen.dart:105 |
| server-settings-upgrade-sheet | g-servers | fix | fixed | done | screen-servers-2 · 337b478d |  | lib/ui/screens/settings/server_settings_screen.dart:182 |
| servers | g-servers | fix | redesigned | partial | screen-servers-1, slice-P3.9, slice-R15, slice-P4.2b, slice-P4.4, slice-P7.2, … | The supporting line should carry kind and state only, with the address and folder moved to the row menu's Details. | test/revamp/goldens/slice_r15_servers_phone_row_dark.png |
| tailscale-setup | g-servers | fix | redesigned | partial | screen-servers-3, slice-R15, slice-P3.9 · b738e8e7, 0bc6651e | Rename the primary to 'Continue' and drop 'VPN connection is unverified' from the installed line. | lib/ui/screens/tailscale_setup_screen.dart:91 |
| usage | g-servers | rethink | redesigned | done | screen-usage-1, slice-P5.4, slice-P5.2 · 82eb38cc, 64437e87, 43b14616, 8e0c584b |  | docs/qa/slice-P5.4-2026-09-27/after-usage_loaded_dark.png |
| usage-budget-clear-dialog | g-servers | fix | fixed | done | screen-usage-1 · 82eb38cc |  | test/revamp/goldens/usage_budget_clear_dialog_dark.png |
| builtin-server-log-sheet | h-termux | fix | merged into this-phone (Details fold) | done | screen-phone-1, slice-P1.3+P1.5 · 5088cc85, 2045a435 |  | lib/ui/screens/this_phone_screen.dart:1004-1027 (KitDetailsFold > KitLogPanel live: … |
| builtin-server-setup | h-termux | fix | removed (merged into phone-setup-start) | done | screen-phone-1, slice-P1.3 · bf19c3e2, 7617d6fc |  | docs/qa/slice-P1.3-P1.5-2026-09-27/README.md (entry-point table) + lib/main.dart:2074 |
| development-services | h-termux | fix | redesigned | done | screen-work-4 · 3599f22f, fd451271 |  | lib/ui/screens/development_services_screen.dart:562-720; … |
| development-services-confirm-sheet | h-termux | fix | redesigned | done | screen-work-4 · 3599f22f |  | lib/ui/screens/development_services_screen.dart:305-335 |
| development-services-logs-sheet | h-termux | fix | restyled | partial | screen-work-4 · 3599f22f | Log does not follow new output: readLogs is called once at development_services_screen.dart:362 and otherwise only via the panel's onRefresh (:457); … | lib/ui/screens/development_services_screen.dart:353-470 |
| embedded-local-agent-onboarding-block | h-termux | rethink | restyled (merge into phone-setup-progress not built) | blocked | slice-P1.6b (not started), P1.6a gate · 01c3e7a2, fd8ab222, 6ff049d9 (gate only) | The planned merge into the v2 checklist (P1.6b: a 'claude' component + 'Sign in to Claude' person-step) is not built: P1.6a gate is NO-GO/incomplete … | docs/qa/gate-P1.6a-2026-09-28/README.md; lib/ui/widgets/local_agent_onboarding.dart:65-70 |
| embedded-setup-terminal | h-termux | fix | redesigned | done | shared-phone-1, slice-P1.2, slice-P1.3+P1.5 · a840e233, 935945d6, 2045a435 |  | lib/ui/widgets/setup_progress_view.dart:281-345 (KitChecklist log: KitLogPanel) |
| embedded-termux-attention-line | h-termux | fix | fixed (action only) | partial | shared-servers-1, R14 · 58c17ec3, 635f69ac | Copy still says OpenCode is busy when the culprit is a leftover helper; no 'See what's running' link to Running on this phone | lib/ui/widgets/work_status_line.dart:96-110 |
| phone-setup-customize-sheet | h-termux | fix | redesigned | done | screen-phone-1, slice-P1.5 · 5088cc85, 2045a435 |  | lib/ui/screens/phone_setup/phone_setup_customize_sheet.dart:448-470; … |
| termux-setup | h-termux | fix | merged into This phone (termux-setup-installed) | partial | slice-P1.2, slice-P1.3+P1.5 · 935945d6, 2045a435, 7617d6fc | Switch-stopped state has no explanation sentence ('OpenCode 2 didn't start... your conversations are kept'): only the runtime name, 'Needs you' and … | lib/ui/screens/this_phone_screen.dart:686-710 |
| termux-setup-installed | h-termux | fix | redesigned (This phone, host-neutral) | partial | slice-P1.5, slice-P1.4, slice-P0.7-port · 2045a435, 94ec2afa, 1207aa74 | Needs-you state does not distinguish failed install (Reinstall) from failed start ('OpenCode didn't start' / Start again); Termux failure text is not … | lib/ui/screens/this_phone_screen.dart:710-790 |
| termux-setup-replace-installed-sheet | h-termux | fix | removed | done | slice-P1.3+P1.5 · bf19c3e2, 2045a435 |  | lib/ui/screens/this_phone_screen.dart:819-832 |
| termux-setup-unsupported | h-termux | fix | merged into phone setup (Termux job unsupported state) | partial | slice-P1.3 · 2045a435 | Title still 'Setup on this phone is Android only' instead of 'Connect a server'; body keeps backticks and the untrue 'requires Termux'; no copyable … | lib/ui/screens/phone_setup/phone_setup_termux_job_screen.dart:549-555 |
| termux-storage | h-termux | fix | restyled | partial | screen-phone-1 · 5088cc85 | Scan view should show the category rows filling in with the log under Details; intro paragraph still long | docs/qa/revamp-screen-phone-1-2026-09-27/after-termux-storage-scanning.png |
| embedded-team-cycle-strip | i1-team-core | rethink | merged into team-conversation (Now line) | done | shared-team-1, slice-P5.1 · 19640c8b, e5148e4a (merge dd18fdee) |  | lib/ui/screens/chat/team_conversation_view.dart (TeamNowLineView); … |
| embedded-team-receipt-chip | i1-team-core | fix | restyled (slice-close-team: the receipt is a mark and word in the row's supporting line, `teamGateRowLine`; the chevron stays) | done | kit-KitReceipt, slice-P4.1c, slice-P5.2 · 513310c0, 4cfbf10a (merge 078cffed), 10cf32d9 | Receipt as a word + icon in the row's supporting line ('Question · Not confirmed yet'), chevron trailing; the retry stays in the Gate sheet. | lib/ui/widgets/team_receipt.dart:99 |
| team-agent | i1-team-core | fix | redesigned (short status page; slice-close-team: only open dependencies count, `teamOpenDependencies`) | done | screen-team-1, slice-P3.6 · 346ca55c (merge 30dbf42c), af07cc7a (merge dbac9c48) | Say the dependency only while it is open (check the dependency's state), so 'Working' and 'waiting on…' never show together. | lib/ui/screens/team/agent_screen.dart:246 |
| team-agent-message-sheet | i1-team-core | fix | merged into team-conversation (watching composer) | done | screen-team-1, slice-P3.6 · af07cc7a (merge dbac9c48) |  | docs/qa/slice-P3.6-2026-09-27/README.md |
| team-agent-output | i1-team-core | rethink | merged into chat (watching mode; TeamWatchLiveScreen … | partial | slice-P3.6 · af07cc7a (merge dbac9c48) | Ended + empty: an inline state 'This session has ended' with a way on (Back to the task / About the worker) instead of the 'fills in as the agent … | lib/ui/screens/chat/team_watch_live.dart:289 |
| team-agents | i1-team-core | fix | redesigned | done | screen-team-3, slice-P3.6 · ac649a70 (merge f6f2e4ec), af07cc7a (merge dbac9c48) |  | lib/ui/screens/team/team_agents_screen.dart:149 |
| team-cycle-how-sheet | i1-team-core | fix | merged into team-conversation (Now line 'Why?' in place) | done | shared-team-1, slice-P5.1 · 19640c8b, e5148e4a (merge dd18fdee) |  | docs/qa/slice-P5.1-2026-09-27/README.md |
| team-cycle-stop-confirm-sheet | i1-team-core | fix | merged into team-agent-stop-confirm-sheet | done | shared-team-1, screen-team-1 · 19640c8b, 346ca55c |  | lib/ui/screens/team/agent_screen.dart:322 |
| team-home-needs-you-tab | i1-team-core | fix | merged into team-home (slice-close-team: 'Needs you · Not confirmed yet · …' in the supporting line; no trailing chip — the home's task rows carry no chevron, so its question rows match them) | done | screen-team-2, slice-P3.4, slice-P5.2 · a7bda280, d42ba768 (merge aa40d789), 10cf32d9 | Receipt as a word in the supporting line ('Needs you · … · Not confirmed yet'), chevron trailing. | lib/ui/screens/team/team_home_screen.dart:788 |
| team-home-runs-tab | i1-team-core | fix | merged into team-home | done | screen-team-2, slice-P3.4 · a7bda280, d42ba768 (merge aa40d789) |  | lib/ui/screens/team/team_home_screen.dart:697 |
| team-run | i1-team-core | fix | merged into team-conversation (+ Task details sheet; slice-close-team: Planned · Working · In review · Merged, Merged only once every step is closed) | done | slice-P3.5 · 3ac501b7 (merge 998915e9) | Stage words as outcomes ('Planned · Working · In review · Merged'), with Done/Merged only when every step is merged. | lib/ui/screens/team/task_details_sheet.dart:375 |
| team-run-agents-tab | i1-team-core | fix | merged into team-conversation (strip + worker lines) | done | slice-P3.5 · 3ac501b7 (merge 998915e9) |  | lib/ui/screens/chat/team_conversation_view.dart:1417 |
| team-run-cancel-confirm-sheet | i1-team-core | fix | merged into the team conversation's Stop task confirm | done | slice-P3.5 · 3ac501b7 (merge 998915e9) |  | lib/ui/screens/chat/team_conversation_view.dart:304 |
| team-run-overview-tab | i1-team-core | fix | merged into team-conversation (slice-close-team: merged = 'Merged into main · <sha>' + Review changes, no Merge) | done | slice-P3.5, slice-P5.1 · 3ac501b7 (merge 998915e9), e5148e4a | The merged state shows only 'Merged into main · <sha>' with Review changes, and no disabled Merge button. | lib/ui/screens/team/merge_section.dart:350 |
| embedded-team-discovery-card | i2-team-sheets | fix | fixed | partial | shared-settings-1 · 063f4741 (merge 550cbfbf) | Fold the offer into the Plugins AI Team row ('AI Team · Found on Laptop' + Turn on); shared-settings-1 deferred it to the Plugins row owner and no … | lib/ui/screens/settings/plugins_screen.dart:175 |
| embedded-team-merge-section | i2-team-sheets | fix | redesigned (the greyed-out Merge on a merged task is gone, slice-close-team) | blocked | screen-team-2, slice-P3.5 · a7bda280 (merge a2ba4379), 3ac501b7; blocker docs … | P6.4 merge on green / undo and real merge diffs ('Review changes' lists steps, not diffs) need a host merge contract that does not exist … | docs/qa/codex-x64-2026-09-27/README.md |
| embedded-team-phone-reoffer-card | i2-team-sheets | fix | removed | done | shared-phone-1, slice-P1.7, slice-R12 · 802e46f9 (merge 56887008), 7acd226c (merge … |  | docs/qa/slice-R12-2026-09-27/README.md |
| embedded-team-phone-section | i2-team-sheets | rethink | merged into team-home (menu › On this phone sheet) | done | shared-phone-1, slice-P3.4 · a840e233 (merge d4e437c6), d42ba768 (merge aa40d789) |  | lib/ui/screens/team/team_home_screen.dart:328 |
| embedded-team-planning-card | i2-team-sheets | fix | merged into team-conversation (lead line + Now line; … | done | screen-team-2, slice-P3.5, slice-P5.1 · 3ac501b7, e5148e4a (merge dd18fdee) |  | docs/qa/slice-P5.1-2026-09-27/README.md |
| embedded-work-graph | i2-team-sheets | fix | redesigned (KitWorkGraph rows) | done | kit-KitWorkGraph, kit-hygiene · 73d5f37d, c232e63a (merge cafc5732) |  | lib/ui/screens/team/work_graph.dart:1 |
| gate-sheet | i2-team-sheets | fix | redesigned | done | screen-team-1, slice-P4.1c · 346ca55c (merge 30dbf42c), 4cfbf10a (merge 078cffed) |  | lib/ui/screens/team/gate_sheet.dart:119 |
| team-host-guide-sheet | i2-team-sheets | rethink | restyled (kit-only) | not done | shared-team-1 · 19640c8b (merge 6fbdb27a) | Each step as a sentence plus a KitCodeBlock command with Copy; 'Open the full guide' through openExternalLink; primary 'Enter the address' opening … | lib/ui/widgets/team_host_form.dart:477 |
| team-host-sheet | i2-team-sheets | fix | redesigned | done | shared-team-1, slice-R12 · 19640c8b (merge 6fbdb27a), 7acd226c (merge c3a2493f) |  | docs/qa/slice-R12-2026-09-27/README.md |
| work-sheet | i2-team-sheets | rethink | redesigned | done | screen-team-3, slice-P5.1 · ac649a70 (merge f6f2e4ec), e5148e4a (merge dd18fdee) |  | lib/ui/screens/team/work_sheet.dart:81 |
| about | j1-settings-more | fix | redesigned | done | screen-system-1, slice-P3.10 · c2889432, 0ed5d941, 2bec3ed3 |  | lib/ui/screens/about_screen.dart:210 |
| about-open-source-tab | j1-settings-more | fix | redesigned | done | screen-system-1, slice-P3.10 · c2889432, 2bec3ed3 |  | lib/ui/screens/about_screen.dart:287 |
| about-privacy-tab | j1-settings-more | fix | merged into privacy-settings (Settings > Privacy and data > … | partial | screen-system-1, slice-P3.10 · c2889432, 2bec3ed3 | The policy text was not rewritten in the person's words, and there is no folded Technical details section for the CIDRs and key names … | PRIVACY.md:27 |
| appearance-picker-sheet | j1-settings-more | rethink | removed (inline KitSegmented on the Appearance page) | done | shared-settings-1, slice-P3.1 · 496a4583, 477e2075 |  | lib/ui/screens/settings/personal_settings_screens.dart:107 |
| model-picker-sheet | j1-settings-more | fix | redesigned (one model sheet) | done | shared-chat-1, slice-P3.3 · 3fcace2c, c90ff900, fa9fc679 |  | lib/ui/widgets/pickers.dart:574 |
| model-picker-sheet-agent-dialog | j1-settings-more | rethink | merged into model-picker-sheet (footer Agent chip + menu) | done | shared-chat-1, slice-P3.3 · 3fcace2c |  | lib/ui/widgets/pickers.dart:673 |
| notifications-settings | j1-settings-more | fix | redesigned | done | screen-settings-1, slice-close-misc · 477e2075, a528c5cf | Closed by slice-close-misc: the background line reads "Android stops this after 6 hours a day. The app will tell you when it does." and monitorDisclosure names the switch ("Stay connected in the background"). | lib/l10n/app_en.arb e7SettingsUi34, monitorDisclosure |
| plugins-mapping-dialog | j1-settings-more | rethink | removed | done | slice-P3.1 · 496a4583, 441012f8 |  | lib/ui/screens/settings/server_plugins_section.dart:39 |
| team-plugin-sheet | j1-settings-more | rethink | merged into team-home | done | screen-library-3, slice-P3.4 · d42ba768, aa40d789 |  | docs/qa/slice-P3.4-2026-09-27/README.md |
| command-auth-sheet | j2-library | rethink | restyled | partial | screen-library-3, slice-P3.11a · 0d4d1e71, 2d238870, 00cafa13 | The three plain states the critic asked for ('Signing in on the server...', 'Signed in', 'Sign-in didn't finish - Try again') are not written. The … | lib/ui/screens/library/command_auth_sheet.dart:189 |
| credential-management-sheet | j2-library | fix | redesigned | done | screen-library-3, slice-P3.11a · 0d4d1e71, 00cafa13 |  | lib/ui/screens/library/credential_sheet.dart:363 |
| integrations | j2-library | rethink | redesigned | done | screen-library-1, slice-P3.10 · 3e19c94a, 2bec3ed3 |  | lib/ui/screens/library/integration_tiles.dart:247 |
| integrations-forget-uncertain-auth-sheet | j2-library | rethink | merged into integrations-forget-pending-auth-sheet | done | screen-library-3, slice-P3.11a · 00cafa13, 674f8182 |  | lib/ui/screens/library/integrations_screen.dart:1272 |
| integrations-mcp-oauth-code-dialog | j2-library | fix | restyled (one KitInputDialog for providers and MCP) | done | screen-library-1, slice-P3.11 · 3e19c94a |  | lib/ui/screens/library/integration_tiles.dart:522 |
| run-result | k-session-misc | fix | redesigned | partial | screen-review-2, slice-P3.7a · 21e501a3, d4f01730 | Pass the model through the catalog name or presentedModelLabel. When the outcome is notReported, lead with the known facts. | lib/ui/widgets/run_result_view.dart:166-210 |
| session-handoff-dialog | k-session-misc | rethink | merged into continue-on-computer-sheet | done | slice-P3.11a · 00cafa13, 674f8182 |  | lib/ui/widgets/session_handoff.dart:35-84 |
| session-note | k-session-misc | fix | fixed | done | screen-chat-2, R16 · e2543231, 253a6919 |  | lib/ui/screens/session_note_screen.dart:170-210 |

## Gaps, ranked by user impact

The ranking weighs four things: how many people hit the gap, whether the owner wrote a note about it, whether it is a trust or security problem, and whether a fix is ready. Each item names the file or unit that should close it.

### A. Built, waiting to merge (in progress)

1. **Voice stops after 30 seconds.** Affects voice-composer-sheet ("Why only 30 seconds, this needs rework") and embedded-voice-conversation-controls. At this revision, `lib/voice/audio.dart:11` still sets `voiceMaximumDuration = 30 s`, and `lib/voice/controller.dart:156` enforces it. The sheet still warns "Unsent text is discarded…" (`lib/voice/voice_ui.dart:986`). **Fix:** merge slice-P10.3 from `revamp/slice-P10.3-P6.3` (3273d7ef: composer voice mode, 30 s chunks with no cap, transcript kept in the draft, sheet deleted) after its focused checks. *High.*
2. **The team does not start work at once.** Affects team-agent-reassign-sheet ("Why manual it's all about automated dev right"). The manual sheet is gone (346ca55c). Dispatch within 5 s and waking a stalled pool (P6.3) are on the same unmerged branch (fb40c24f, 11cd0808). **Fix:** merge slice-P6.3 with P10.3. *Medium.*

### B. Owner notes still open at their core

3. **Claude Code is not part of phone setup v2.** Affects local-agent-page ("make this inline with installation v2 … users who started with opencode and now wants to mix both") and embedded-local-agent-onboarding-block. **Blocked:** gate-P1.6a is NO-GO or incomplete on ARM64 (`docs/qa/gate-P1.6a-2026-09-28/README.md`), and `lib/builtin/setup/claude_scripts.dart:1-2` is not registered.
   - Someone who set up OpenCode inside the app cannot add Claude Code: the row is Termux-only (`lib/ui/screens/this_phone_screen.dart:872`, `if (!inApp)`).
   - The page is still the old card with engine words ("Paseo daemon").
   - **Fix:** slice-P1.6b. Once the ARM64 proof passes, add the `claude` component to Customize and Add tools with a "Sign in to Claude" person-step. A Termux-host version could ship first, because it does not depend on the in-app ARM64 check. That split is an owner or coordinator decision. *High.*
4. **No setup assistant, and MCP has one path only.** Affects settings ("can an agent become my opencode configuration assistant…") and mcp-setup ("two options: one for technical users and one driven by AI agents … an OSS MCP provider … as toggles").
   - Settings layout (P3.10) and search (P9.4) landed.
   - Missing: the "Ask the setup assistant" row (P2.2). **Update 2026-09-28:** the MCP Add chooser (P2.4) and the registry catalogue as toggles (P2.5) are built in slice-P2.4-5 (`docs/qa/slice-P2.4-5-2026-09-28/README.md`).
   - A registry client already exists (`lib/domain/setup_registry.dart:161`) but nothing uses it. The AI setup page merged on 2026-09-28 (2b79b0ee) is review-only.
   - **Fix:** the owner marked P2 "later" on 2026-09-26, but two notes ask for it. Ask the owner to schedule P2.4 and P2.5 (neither needs server Apply) before P2.2. P2.3 Apply/Undo stays blocked on server support. *Medium; owner decision.*
5. **Quota on the collector path is still mostly the old page.** Affects provider-quota ("Feature itself needs a lot of work"). P5.4 landed for Codex hosts. On the collector path, these remain:
   - the "Snapshot checked / Reported plan / Secondary window · Not reported" header;
   - collector controls on the missing-collector state;
   - the jargon empty notice;
   - "How to get it" pointing at `tool/quota` in the app's repository;
   - an offline value that is lost on restart;
   - an 80 % alert that shows only in the foreground.

   **Fix:** a P5.4 follow-up in `lib/ui/screens/provider_quota_screen.dart` and `lib/ui/widgets/quota_monitor_section.dart`. *Medium.*
   *Update: slice-close-misc closed the first four (collector path). The offline value across a restart and a device alert remain; both are state work for the Codex backend.*
6. **Closed by slice-close-team.** ~~A planner-off team gives no way forward.~~ Affects start-run-sheet ("Give the user recovery options?"). Drafts, a refusal and the direct-task path are recovered. When the planner is off and no direct path exists, the sheet still:
   - keeps the title "Give the team a task";
   - explains in engine words: "The planner (Mayor) is off… switch it to the full profile";
   - offers only Host guide (`lib/ui/screens/team/start_run_sheet.dart:412`, `:676-700`).

   **Fix:** `_PlannerOff`. Use a plain title, and offer Wake the planner where `controlAgent` exists. *Medium.*
7. **Add server still fails in engine words.** Affects profile-editor ("Inline with v installa?"). The owner's point is met: This phone hands off to v2, and adding a computer is one stepped path. All three critic findings stand:
   - "Is opencode serve running…" appears next to an OC2 pair command (`app_en.arb:7814` `e7SetupRefused`).
   - The failure shows at the top of the form, away from the field (golden `test/goldens/add_server_failed_*.png`).
   - The Codex command is clipped, and the ws/wss helper is still there (`app_en.arb:1528` `codexAddressHelp`).

   **Fix:** `lib/ui/screens/servers_screen.dart` (`_status`, `_manualAddress`, `_buildCodexFields`). *Medium.*
8. **Running on this phone covers Termux only.** Affects termux-processes ("Good screen respec and make proper tool"). The tool is respecified, but there is no process inventory for the in-app Linux, and the row sits inside the Termux-only branch (`this_phone_screen.dart:895-900`). **Fix:** the Codex backend adds the in-app inventory (codex-p53), then a P5.3 follow-up. *Medium.*
9. **A failed queued message has no Retry.** Affects embedded-pending-sends-strip. The owner's "one bubble, themed" is done. A failed queued item offers only Edit and Discard (`lib/ui/screens/chat/message_view.dart:1812-1840`). **Fix:** `_draftItem` in the chat library. *Medium.*
10. **The session-link sheet cannot prefill the server.** Affects session-link-server-missing-banner ("Screen sucks"). It is now an "Add this server?" sheet, but Add server opens empty and the text still says "scan the code again". **Blocked:** links that carry the address are built but gated off (`ServerCapabilities.sessionAddressHandoff` is false on every adapter until the host can be verified; `docs/qa/codex-sessionlink-2026-09-28`). *Medium.*
11. **Commands for Claude Code and Codex don't exist.** Affects command-launcher-sheet ("… what about using Claude or codex will this support their commands?"). There is one sheet with plain words and an honest "not available" for those backends. **Blocked:** there is no callable command contract (`slashCommands` is false on both gateways). The visual study the owner asked for ("run an agent to think how to visually represent these") is not recorded anywhere. **Fix:** the Codex backend queue (`docs/qa/codex-p101-2026-09-27`), then `lib/ui/widgets/command_sheet.dart`. *Medium.*
12. **Termux-host words that could still be plainer** (all *low*, under the "Align with v2" notes):
    - termux-setup-connect-termux still says "run the unlock line" and "App settings" (`app_en.arb:6916`).
    - termux-setup-failed: a too-old Termux has no "Get the current Termux" link, because actions only appear on pending rows (`setup_progress_view.dart:296`).
    - termux-setup-update-sheet: the confirm says "Update managed OpenCode?" and "Active generation…" (`this_phone_screen.dart:382-398`).

### C. Pages with no note: not done, or high or medium gaps

13. **host-management (not done).** The page tells people to pipe a script from the `master` branch straight into bash: unpinned, no checksum, no "What this does" (`lib/ui/screens/host_management_screen.dart:33-35`). This is a trust problem. **Fix:** pin a release tag, show a checksum and add a Details fold. No unit owns this; it needs one. *High.*
14. **chat-leave-unsaved-draft-sheet (not done).** The body tells the person to copy or retry, but the only choices are Leave and Cancel (`lib/ui/screens/chat_screen.dart:6751-6760`). **Fix:** `_leaveChat`: make "Copy draft and leave" the main button and add "Try saving again". *Medium.*
15. **Closed by slice-close-team.** ~~isolated-task-sheet (not done).~~ P4.5 only moved the entry point. The sheet still:
    - uses the title "New task in a fresh worktree";
    - never asks what the copy should work on;
    - shows a stop line that cannot undo anything (`lib/ui/screens/isolated_task_sheet.dart:311`);
    - ends a failed setup in a lone Close (`:444-446`).

    *Medium; no owner.*
16. **team-host-guide-sheet (not done).** Commands are prose you cannot copy, and it ends by pointing at `docs/ai-team-host.md` in the repository (`lib/ui/widgets/team_host_form.dart:477`). **Fix:** use `KitCodeBlock` commands, "Open the full guide" through `openExternalLink`, and "Enter the address". *Medium.*
17. **chat (partial; owner decision).** In a finished turn, text written before the last tool step folds under the work line, so the explanation can be hidden (`lib/ui/screens/chat/message_view.dart:529-570`). The critic says keep the prose visible; the turn model says fold the work. *Medium.*
18. **embedded-prompt-error-banner.** There is no one-tap "Use ⟨suggested model⟩ and resend", and the failed prompt is not marked "Not sent" with Retry (`lib/ui/screens/chat/chat_states.dart:176-221`). *Medium.*
19. ~~**profile-monitor.**~~ *Closed by slice-close-misc: the page is removed; every door lands in Notifications.* P4.2b's acceptance ("route removed") is not met. It is still reachable as Servers › Background checks (`servers_screen.dart:1029-1040`) and from search (`search_index.dart:1377`). The dot stays green while a request waits, and the engine words remain. *Medium.*
20. **embedded-completion-digest-card.** The Inbox row landed, but the expanded body is still the old raw card with its disclaimers and five text buttons (`lib/ui/widgets/completion_digest.dart:54-104`). **Fix:** a P4.2b follow-up. *Medium.*
21. **command-auth-sheet.** Recovery mechanics are still shown as copy (`lib/ui/screens/library/command_auth_sheet.dart:185-213`). *Medium.*
22. **termux-setup-installed and embedded-termux-attention-line.**
    - "Needs you" does not tell a failed install from a failed start, and Termux errors are shown exactly as the scripts send them (`lib/state/phone_host.dart:384` → `this_phone_screen.dart:778`).
    - The line blames OpenCode when a leftover helper is the real cause, and has no "See what's running" (`lib/ui/widgets/work_status_line.dart:101-103`).

    *Medium.*
23. ~~**project-hub.**~~ *Closed by slice-close-misc: live lines on Changes and Terminal.* Rows are titles only, with no live lines such as "3 files changed" or "1 running" (`lib/ui/screens/project_hub_screen.dart:446`). *Medium; no owner.*
24. **chat-run-shell-dialog.** The command field is a single line (`chat_screen.dart:4995`). **Fix:** a multi-line mono `KitField`. *Medium.*
25. **embedded-team-merge-section (blocked).** Merge on green, Undo and real diffs need the host merge contract (939a0554, bae398c0). The greyed-out Merge button on a merged task is gone (slice-close-team). *Medium.*

### D. Low-impact leftovers (wording and polish; one line each)

- **connection-status-details-sheet** (partial): The raw error fold starts open instead of collapsed. Fix: lib/ui/widgets/connection_status_banner.dart.
- **chat-read-aloud-consent-sheet** (partial): Consent is not remembered across conversations or app restarts. It resets on every scope change. Fix: lib/ui/screens/chat/read_aloud.dart (chat library).
- **embedded-composer** (partial): In the working state with text, show one trailing control (Send), not Stop+Send, and move expand into the field corner. Fix: lib/ui/kit/chat/kit_composer.dart (kit owner).
- **embedded-transcript-find-bar** (partial): The match excerpt card still repeats the count. Keep the count in the bar only and highlight in place. Fix: lib/ui/screens/chat/message_view.dart _frame + lib/ui/widgets/transcript_highlight.dart.
- **session-approvals-sheet** (partial): Say the new-conversation rule once and remove the contradicting footer sentence from approvalsUiServerRulesNote. Fix: lib/ui/screens/chat/approvals_sheet.dart:186 + app_en.arb approvalsUiServerRulesNote.
- **global-sessions-continue-here-sheet** (partial): Engine wording 'through the server's sync system' still in globalSessionsMoveBody Fix: lib/l10n/app_en.arb globalSessionsMoveBody (screen-work-2 follow-up).
- **project-health** (partial): Split 'Couldn't read Git status' + Try again from 'This server doesn't report Git status' with no retry Fix: gateway typed unsupported error (Codex backend) + lib/ui/screens/project_health_screen.dart _readFailed.
- **diff-view** (partial): Multi-file title still 'Review' (reviewTitle) instead of 'Changes · N files' Fix: lib/ui/screens/review_workspace.dart DiffPage (P3.7a follow-up).
- **staged-revert** (partial): State 'Files were put back' / 'Files were left as they are' (SessionRevert has no applyFiles flag; the app could remember the choice it sent) Fix: lib/state/connection.dart stageSessionRevert (remember applyFiles) + lib/ui/screens/staged_revert_screen.dart.
- **agent-account** (partial): Plain sign-in copy ('Sign in with your ChatGPT account. You finish in the browser; this app never sees your password.') was never applied. The kit rebuild and the 'Sign in with ChatGPT' primary did land. Fix: lib/l10n/app_en.arb agentAccountSignInNote/agentAccountHostNote; lib/ui/screens/agent_account_screen.dart.
- **servers** (partial): The supporting line should carry kind and state only, with the address and folder moved to the row menu's Details. Fix: lib/ui/screens/servers_screen.dart _ServerRow (:1193-1246).
- **tailscale-setup** (partial): Rename the primary to 'Continue' and drop 'VPN connection is unverified' from the installed line. Fix: lib/l10n/app_en.arb tailscaleContinue, tailscaleInstalled.
- **development-services-logs-sheet** (partial): Log does not follow new output: readLogs is called once at development_services_screen.dart:362 and otherwise only via the panel's onRefresh (:457); no poll while the sheet is open Fix: lib/ui/screens/development_services_screen.dart (_logs) — screen-work-4 follow-up.
- **termux-setup** (partial): Switch-stopped state has no explanation sentence ('OpenCode 2 didn't start... your conversations are kept'): only the runtime name, 'Needs you' and two buttons Fix: lib/ui/screens/this_phone_screen.dart _status (switchTarget branch) — P1.5 follow-up.
- **termux-setup-unsupported** (partial): Title still 'Setup on this phone is Android only' instead of 'Connect a server'; body keeps backticks and the untrue 'requires Termux'; no copyable mono command box Fix: lib/ui/screens/phone_setup/phone_setup_termux_job_screen.dart:546-563 + app_en.arb e7SetupUnsupportedSetup.
- **termux-storage** (partial): Scan view should show the category rows filling in with the log under Details; intro paragraph still long Fix: lib/ui/screens/termux_storage_screen.dart _buildScanning (screen-phone-1 follow-up).
- **embedded-team-receipt-chip** (done, slice-close-team): Receipt as a word + icon in the row's supporting line ('Question · Not confirmed yet'), chevron trailing; the retry stays in the Gate sheet. Fix: lib/ui/widgets/team_receipt.dart (teamGateRowReceipt) + its row callers.
- **team-agent** (done, slice-close-team): Say the dependency only while it is open (check the dependency's state), so 'Working' and 'waiting on…' never show together. Fix: lib/ui/screens/team/agent_screen.dart (_workHold).
- **team-agent-output** (partial): Ended + empty: an inline state 'This session has ended' with a way on (Back to the task / About the worker) instead of the 'fills in as the agent works' line. Fix: lib/ui/screens/chat/team_watch_live.dart.
- **team-home-needs-you-tab** (done, slice-close-team): Receipt as a word in the supporting line ('Needs you · … · Not confirmed yet'), chevron trailing. Fix: lib/ui/widgets/team_receipt.dart / lib/ui/screens/team/team_home_screen.dart.
- **team-run** (done, slice-close-team): Stage words as outcomes ('Planned · Working · In review · Merged'), with Done/Merged only when every step is merged. Fix: lib/ui/widgets/team_vocabulary.dart (teamRunStage) + lib/ui/screens/team/task_details_sheet.dart (_StageLine).
- **embedded-team-discovery-card** (partial): Fold the offer into the Plugins AI Team row ('AI Team · Found on Laptop' + Turn on); shared-settings-1 deferred it to the Plugins row owner and no later slice did it. Fix: lib/ui/screens/settings/plugins_screen.dart (slice-P3.1 / Plugins owner).
- **about-privacy-tab** (partial): The policy text was not rewritten in the person's words, and there is no folded Technical details section for the CIDRs and key names (screen-system-1 deferred this as document content with no owner). Fix: PRIVACY.md + assets/l10n/PRIVACY.ar.md (docs content; no unit owns it).
- ~~**notifications-settings**~~ (closed by slice-close-misc): Shorten the background row to 'Android stops this after 6 hours a day. The app will tell you when it does.' (or let it wrap), and replace 'Keep live' with the switch's name in monitorDisclosure. Fix: lib/ui/screens/settings/notifications_settings_screen.dart:606 + app_en.arb e7SettingsUi34/monitorDisclosure.
- **run-result** (partial): Pass the model through the catalog name or presentedModelLabel. When the outcome is notReported, lead with the known facts. Fix: lib/ui/widgets/run_result_view.dart _facts/_outcome.

### E. Loose ends found on the way (not board pages)

- `test/calm_chat_disclosure_test.dart` still mentions the removed Context capsule.
- The Arabic `sessionCopyHandoff` still means "copy handoff reference", not "Continue on computer".
- `lib/ui/screens/server_settings_screen.dart:33`: the restart sheet hard-codes `bash ubuntu-opencode.sh restart`, which is wrong for servers not installed with that helper.
- All conversations still ends in a "Load more" button (`global_sessions_screen.dart:1005`), although target-ia says lists load their next page by themselves.
- In Files, the change-marks line still shows when the folder listing has failed (`files_screen.dart:1080`).
- Old wizard strings (`e7SetupChooseContinue`, `e7SetupNoUbuntu`, `e7SetupResumeSetup`) survive only to translate script messages (`setup_ui_messages.dart`). They are not dead code, but they could move to that file's own keys.
- A few QA folders do not follow the `<unit>-<date>` naming (e.g. `docs/qa/revamp-screen-system-1/`), and P8.3 has no commit of its own (the report hook came in with c274356e, coord-main).

### Suggested next moves

1. Merge P10.3 and P6.3. This closes gaps 1-2 and moves 3 pages to done.
2. Put the owner decisions to the owner: schedule P2.4 and P2.5 (gap 4), ship a Termux-only P1.6b (gap 3), and decide the chat fold (gap 17).
3. Run one "leftovers" chat-library unit for gaps 9, 14, 18 and 24 plus the chat lows.
4. Run one servers/phone wording unit for gaps 7, 12, 22 and the servers and termux lows.
5. Run one team unit for gaps 6, 16, 25 plus the team lows. *(slice-close-team closed gap 6, gap 15, the merged-state part of gap 25 and the team lows it owns; gap 16's commands are with the security slice, team-agent-output is in the chat library, and the discovery-card fold is in the Plugins page.)*
6. Give host-management (gap 13) an owner now; it is the only security-shaped gap.
