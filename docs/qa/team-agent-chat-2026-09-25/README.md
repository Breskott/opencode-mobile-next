# The AI Team on the chat page: a worker's own conversation, and the task as a conversation (2026-09-25)

## Scope

The owner, watching his team on his phone: "Why isn't these rendered as regular
conversations in the already built glorious chat page in a way?" Before this change,
an agent's work was only visible on the bare Live output screen, which reads Gas City's
`/session/{id}/stream` text turns.

Two slices, one branch:

1. **A worker's own conversation, watching.**
   - "Open conversation" on the agent screen opens the worker's real OpenCode session
     on the chat page, read-only.
   - A slim status line says "Watching furiosa · Worker · AI Team".
   - The composer is replaced by one action, **Message the worker**. It sends through
     the team's own message control (`OrchestrationController.messageAgent`), so
     nothing is typed into the worker's OpenCode session.
   - Nothing that changes the session is offered.
   - The transcript is read again every 4 s.
   - When the connected server has no such session, Live output opens instead, with a
     line saying why.
2. **The task as a conversation** (coordinator's design,
   `docs/design/team-conversation-2026-09-26.md`, option A, assembled by the app).
   - Your prompt is the task.
   - The lead's reply ("The team") has one line per real team event, each with its time.
   - The steps carry the Overview's marks and fold under one line when there are more
     than three.
   - Each worker or reviewer is a sub-agent card. Its state comes from its **session**,
     not from `/agents`. The card opens that worker's conversation in watching mode.
   - A family strip lists the lead and each agent.
   - The team's questions use its existing request card (`TeamNeedsYouCard`), answered
     in place.
   - Merge uses the existing merge section.
   - One **Now** line says what is happening and since when. After 8 s without an
     answer from the team it says the team isn't answering, with Retry.
   - The composer is "Message the team…" through the same message control.

Code:

| Part | Where |
|---|---|
| Folder → OpenCode session mapping | `lib/domain/team_agent_sessions.dart` (`pickTeamAgentSession`, `findTeamAgentSession`) |
| Lead lines, Now, session-truthful state, short names | `lib/state/team_conversation.dart` |
| Session facts on agents (additive) | `OrchestrationAgent.sessionState` / `sessionRunning`, filled by `mapAgent` / `mapSession` |
| Watching mode (chat library) | `lib/ui/screens/chat/watching.dart` (`ChatWatch`); gates in `chat_screen.dart` |
| Team conversation (chat library) | `lib/ui/screens/chat/team_conversation_view.dart` (`TeamConversationScreen`, `openTeamAgentConversation`, `teamAgentWatch`, `TeamOpenConversationRow`) |
| Frozen entry points for ds/team-discover | `lib/ui/screens/team_conversation/team_conversation.dart`: `TeamConversation.open(context, team, runId:)`, `TeamConversation.start(context, team)`, `TeamTaskConversationRow` |
| Hooks (one row each) | agent screen Output section: `TeamOpenConversationRow`. Task Overview under the objective: `TeamTaskConversationRow`, which opens the task conversation; its workers are one tap further. |
| Live output fallback line | `AgentOutputScreen(note:)` (additive) |
| Copy | 56 keys in `app_en.arb` and `app_ar.arb` (`chatWatch*`, `teamWatch*`, `teamChat*`, `teamOpenConversation*`, `teamOpenTaskConversationHint`) |

## Feasibility (checked before building)

**(a) Team sessions are in the connected OpenCode server's list.**

- **OpenCode 1: yes.**
  - `opencode acp` starts its own in-process server (`packages/opencode/src/cli/cmd/acp.ts`
    calls `Server.listen`) on the same SQLite store as the phone's `opencode serve`.
  - The agents run `/usr/local/bin/opencode`, the server's own binary
    (`AiTeamScripts.agentWrapperScript`).
  - Emulator evidence: `docs/qa/work-tab-team-sessions-2026-09-24` (the polecat session
    in `/root/aiteam/city/.gc/worktrees/my-app/polecats/gastown.furiosa`). That is why
    `lib/domain/team_directories.dart` filters them out of the person's lists.
- **OpenCode 2: not established.** Both dialects implement `listGlobalSessions`
  (all projects, roots only). But the agents run OpenCode 1's binary, and an OpenCode 2
  server under `/opt/oc2` has its own store. There the lookup finds nothing, and Live
  output opens with its line.

**(b) Mapping a Gas City session to the OpenCode session.**

- Gas City does store the OpenCode id: the session bead's `metadata.session_key`
  (for example `ses_f7387e8c…` for `gc-231` furiosa in the spike recording
  `gascity-spike/rec/beads_now.json`).
- The session API deliberately hides it. `filterMetadata` in
  `gascity-src/internal/api/handler_sessions.go` exposes only `real_world_app_*` keys,
  "to prevent leaking internal bead fields (session_key, command, work_dir …)".
- Reading it from `/bead/{id}` would rely on an internal field, so the app does not.
- The mapping is deterministic by folder:
  - roots only;
  - the session's folder equals the Gas City `work_dir` or is inside it;
  - only sessions updated since the Gas City session's `created_at` − 2 min. The
    polecat worktree is reused across tasks, and an older session there is a previous
    task.
  - newest wins, then by created time, then by id.
  - up to 3 pages of 40;
  - no match → null.

**(c) The chat page can open a session outside the current project.**

- OpenCode 1 reads a session and its messages by id from the SQLite store, not per
  project (`Session.get` is `select … where id`).
- OpenCode 2's `/api/session/{id}/…` reads are by id; location scoping applies to the
  location endpoints (`docs/opencode2-protocol-notes.md`).
- No project switch is needed. `ConnectionController._rememberSessionMembership` only
  adds a session to the project's list when its folder is the project's, so the watched
  session never joins the person's list (test below).
- **What does not work: live events.** The server's `/event` bus is per process. The
  worker's updates happen in the `acp` process and never reach the phone server's
  stream. Watching mode therefore re-reads the transcript every 4 s while the app is in
  front, and at once on resume.

**(d) Watching does not interfere with the agent.** The ACP driver owns the session;
watching mode sends nothing into it:

- no composer, no Send, Stop or voice;
- no conversation menu (share, fork, revert, rename, delete, compact, model);
- no message actions beyond copy;
- no permission, question or form answered;
- no drafts;
- no read receipts: `SessionViewObserver` is skipped, as is the model shortcut.

The person's words go to the Gas City message control. The tests assert that the
OpenCode API received no prompt.

## Builds

- Branch `feat/team-agent-chat` (from `feat/phone-setup-v2` @ `ff5b06c3`, merged
  `c799e2af` for the design doc). No APK built. No emulator or Gradle, as instructed.

## Devices

None. Unit and widget tests, plus renders from the test binding (pinned Shorebird
Flutter `91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`, on the PC).

## Runs

The test data matches the owner's phone on 2026-09-25:

- task given 19:49:03;
- furiosa's session created 19:51:05;
- `/agents` said stopped while `/sessions` said active and running;
- work folder `/root/aiteam/city/.gc/worktrees/my-app/polecats/gastown.furiosa`.

| # | Step | Expected | Actual |
|---|---|---|---|
| 1 | `pickTeamAgentSession`: exact folder, subfolder, `..` and trailing-slash forms, child sessions, the person's session in the rig, newest wins, older-than-start ignored, no match; `findTeamAgentSession` paging and a failing server | as specified | PASS (14 tests) |
| 2 | `mapAgent` / `mapSession` carry the session's `state` and `running` | carried | PASS (3 tests) |
| 3 | Lead lines: a 2-step story in time order with names; untimed lines keep their place; gates; end of task (merged, finished, failed, cancelled); a worker session made for a routed step says a worker started | as specified | PASS |
| 4 | Now: finished, needs you, waiting, starting (including the session running before the cycle knows, and overriding "the host has not started an agent"), working, review, stalled; a queued step behind the step in flight does not speak | as specified | PASS (lead + Now: 23 tests) |
| 5 | Agent screen → Open conversation (with a session for this task, an older one in the same worktree, the refinery's and the person's own) | chat page on `ses_furiosa`, "Watching furiosa · Worker · AI Team", the worker's words; Back → agent screen | PASS |
| 6 | Watching page | no TextField, no conversation menu, no running-work switch, no message actions; Message the worker → sheet → `messageAgent('my-app/gastown.furiosa', …)`; OpenCode prompts: none | PASS |
| 7 | The worker writes a new message to the store (no event) | shown after the next read (≤ 5 s) | PASS |
| 8 | Only the previous task's session in the worktree | Live output with "Its conversation isn't on the server this app is connected to yet …" | PASS |
| 9 | After watching a team session | the project's list (`sortedSessions`) is only the person's; "In other projects" has neither furiosa's nor the refinery's | PASS |
| 10 | Task conversation | prompt = task; lead "Planned 2 steps · 19:49", "Sent … to the workers · 19:51"; card "furiosa · Worker", "Working …" (session truth); Now "furiosa is starting · can take a few minutes on a phone · 3 min"; family strip; steps; composer note "Goes to furiosa · Worker through the AI Team" | PASS |
| 11 | Message the team | `messageAgent` to furiosa, no OpenCode prompt, the words and their receipt in the conversation | PASS |
| 12 | Worker card | watching chat of `ses_furiosa`; Back → conversation | PASS |
| 13 | A choice gate | Now "Needs you · …"; the request card answers in place (receipt), no agent message | PASS |
| 14 | 5 steps | "5 steps · 1 done", unfolds on tap | PASS |
| 15 | `TeamPendingTask` (just given, not yet listed) | Now "Waiting for the team to pick it up · 5 min", lead "Sent to the team"; binds to the run when the team lists the work item | PASS |
| 16 | Task Overview → Open conversation | the task conversation | PASS |
| 17 | Failing first ([failing-first.txt](failing-first.txt)) | fail without the change | FAIL as expected: A, against the base's `lib/` (`c799e2af`), all five new test files fail (the API does not exist); B, with only the three session-truth fixes undone, 4 tests fail (the Now line says "Waiting for a worker · waited 5 min" instead of "furiosa is starting …"; no "Started a worker" line; the stall and the queued step speak) |
| 18 | The new tests plus every test file that imports the chat library or a team screen, the Work tab team-session tests, the mappers, the design standard and l10n: 91 files ([tests-with-change.txt](tests-with-change.txt)) | unchanged behaviour | PASS: 1364 passed, 4 skipped; the 2 failures were the agent screen's controls goldens (`team_agent_controls_{dark,light}.png`), which now show the new Open conversation row. They were regenerated, reviewed and pass. |

Product bugs found by the tests and fixed before the tests were changed:

- The Now line said "The host has not started an agent yet" while furiosa's session was
  running. This is the owner's phone case: the dispatch cycle stalls on
  `hostNotStarted` because no wake event arrived. A running session now overrides that
  stall.
- The lead had no "Started a worker" line for the same reason. The session's creation
  now counts as that event.
- The Now line spoke for a step still queued behind the one in flight ("Waiting for a
  worker"). It now follows the step that was sent to a worker.
- The watching action's spinner ran while its sheet was open, which is a silent
  spinner. The action now only disables itself.

## Renders (412 × 915, dark)

| File | What |
|---|---|
| [agent-screen-open-conversation.png](agent-screen-open-conversation.png) | The agent screen's Output section: Open conversation above Live output |
| [watching-chat.png](watching-chat.png) | furiosa's conversation in watching mode: the banner, the worker's words, the note and Message the worker in place of the composer |
| [live-output-fallback.png](live-output-fallback.png) | Live output opened as the fallback, with its line |
| [team-conversation-en.png](team-conversation-en.png) | The task as a conversation |
| [team-conversation-needs-you.png](team-conversation-needs-you.png) | The same with a question from the team (scrolled) |
| [team-conversation-ar.png](team-conversation-ar.png) | Arabic, RTL (layout only: the capture fonts have no Arabic glyphs, so its text shows as boxes) |

Visible in the renders and not changed here, because other branches own them:

- The subtitle says "On this phone · Paused" while furiosa's session runs.
  `teamHostCondition` counts live agents from `/agents` (ledger row 20,
  `ds/team-discover`).
- The agent screen's header says "Stopped" (row 21, the same agent).

The conversation's own parts use the session.

## Evidence

- `failing-first.txt`: the new tests run with the product changes reverted.
- `tests-with-change.txt`: the new tests plus every chat and team screen test file.

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test -j 2 test/team_agent_sessions_test.dart test/team_session_state_test.dart \
  test/team_conversation_lead_test.dart test/team_agent_chat_test.dart \
  test/team_conversation_screen_test.dart
# Renders:
TEAM_CHAT_CAPTURE_DIR=$PWD/docs/qa/team-agent-chat-2026-09-25 \
  $F test test/team_agent_chat_render_test.dart
```

## NOT proven

- **On a device.** Nothing here ran on the phone or an emulator. In particular:
  - that the phone's store has furiosa's session under exactly the Gas City `work_dir`;
  - that `created_at` and the store's times agree closely enough for the 2-minute
    window;
  - the 4 s re-read's cost on the phone's battery and server.
- **OpenCode 2** as the connected server. Expected: no match, so Live output with its
  line.
- A team on a computer while the app is connected to that computer's OpenCode server.
  The mapping is folder-based and should match; not run.
- More than 120 newer sessions on the server: the lookup stops at 3 pages of 40.
- `TeamConversation.start` through the planner. The conversation binds by the planning
  request's title match (`teamPlanningRunMatches`); only the direct-task binding by work
  id is tested.
- Merge from the conversation. It is the existing merge section, not exercised here
  with a real merge.
- The watching session's title is the worker's own session title (for example
  "Polecat startup: claim work and execute"). It is not rewritten.
