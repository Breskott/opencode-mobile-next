# AI Team without Gas City? Native team analysis (2026-09-29)

Owner: "But why do we need the AI team [Gas City]? Don't we have enough to
build this in the native itself or in the Ubuntu? Why can't we redo the same?
It's just a matter of beads and beads thinking process and sub-agent
orchestration that is already happening in OpenCode."

Scope: read-only analysis at `bc53f456` (`feat/phone-setup-v2`). Nothing was
run on a device. Numbers marked *measured* come from `docs/qa/team-hot-2026-09-26`,
`docs/qa/aiteam-builtin-2026-09-24`, `docs/qa/crit-team-*-2026-09-29` and today's
owner report. Numbers marked *estimate* are unmeasured.

## Short answer

Yes. On the phone the app uses only a small part of Gas City. The rest is
switched off: mayor, deacon, boot and witness are suspended, the worker pool is
capped at 1, and most orders are manual. Gas City's core value is
coordinating many independent agent processes through a shared store (beads in
Dolt). An app that drives sessions inside **one** OpenCode server does not have
that coordination problem. OpenCode already provides sessions with an agent and
a model per session, child sessions, todos, permission and question asks, diffs,
revert, live events and (in v2) a durable log. The app already renders all of
these in its chat.

The app's team UI already sits behind a provider-neutral seam
(`lib/domain/orchestration_gateway.dart`: `OrchestrationGateway` with a
`GasCityGateway`, a `FixtureOrchestrationGateway` and a `NullOrchestrationGateway`).
So a native team is **one new adapter**, not a rewrite of the ~19k lines of
team UI.

Recommendation: **Option C, with a Traycer-style flow (§6).** Build the native
team (B) for the phone and for any single OpenCode server. Its flow is: plan and
spec card, then the person approves, then each phase runs as a role session,
then a verifier checks each phase against its acceptance criteria. Keep Gas City
only as an opt-in "connect a Gas City on your computer". Stop installing it on
the phone once the native slice passes on the device. Traycer shows that this
flow needs no task-graph engine: it is a thin client-side loop over existing
coding agents.

## 1. What Gas City + beads + Dolt provide, and what the app really uses

The endpoints were found by searching `lib/orchestration/adapters/gascity/*`.
The callers were found by searching `lib/ui`, `lib/state` and `lib/builtin` for
the `OrchestrationController` methods.

| Capability | Gas City mechanism | App calls (endpoint → caller) | Used by today's phone UX? |
|---|---|---|---|
| Task store | beads in Dolt (`bd`, `dolt sql-server`) | `GET /beads`, `/bead/{id}`, `POST /beads` → `createWork` (start_run_sheet, team_conversation, team_controls) | **Yes**: one task per "Give the team a task" |
| Task graph / dependencies | bead deps, `ready=true`, convoys | `GET /beads?ready`, `/convoys`, `/convoy/{id}` → `work_graph.dart`, board | Shown when present. Phone tasks are single beads with no dependencies |
| Claim / assign | `POST /sling` (routes to a pool, pokes the reconciler) | `assign` → `giveTaskAsRole`, gate_sheet, team_board | **Yes**: every task is create then sling |
| Board edits | `POST /bead/{id}/update|close|reopen` | `setWorkPriority`, `unassignWork`, `cancelWork`, `reopenWork` → `team_board.dart` | Yes (board page) |
| Patrol / reconcile | supervisor tick, `patrol_interval=60s`, orders | not called. Its effects are observed through events | Implicitly. It starts and restarts the worker. It also costs 5–8 s per tick under proot (*measured*) |
| Agent pools and processes | one `opencode acp` per session; polecat `wake_mode=fresh`, exits after every task | `GET /agents`, `/sessions`; `POST /agent/{n}/suspend|resume`, `/session/{id}/stop|wake` → agent_screen, team_controls | **Yes**. This is the cost centre: 563 MB and 22 s to 4 min of cold start per worker (*measured*) |
| Git worktree per task | `.gc/worktrees/<rig>/<agent>`, branch per bead | only read (`gc.work_dir`, `metadata.branch` in `dispatch.dart`) | Yes, for isolation. The phone adds a stand-in bare `origin` plus a hook (`BuiltinTeam.originsDir`, `pull.log`) |
| Merge / refinery | refinery agent merges to origin; front routes `/front/merge-readiness`, `/front/mr/{id}/approve`, `/front/merge/{run}` | `mergeReadiness`, `approveMergeRequest`, `mergeRun` → `merge_section.dart` | **Front routes: no.** The phone config has `front: false`, so these return 404/null there. The phone merges through the refinery agent and the origin hook, not through app-confirmed merge |
| Gates / approvals | pending interactions of the agent's ACP session | `GET /pending`, `/waits`; `POST /session/{id}/respond` → gate_sheet, team_needs_you | **Yes**. These are OpenCode permission and question asks relayed through Gas City |
| Mail / nudges | `POST /session/{id}/messages` | `messageAgent`, `controlAgent(nudge)` → team conversation composer, gate_sheet | Yes (composer "Your message goes to Worker") |
| Planner (mayor) | message to mayor, which then creates beads | `team_planning.dart` sends the objective to the mayor | **No on the phone**: the mayor is suspended (`keptOffKinds`) |
| Formulas / molecules / runs | `--formula` slings, `/runs` | `GET /runs`, `POST /runs/{id}/cancel` | Rarely. Direct slings never appear in `/runs` (06-decisions §F.3) |
| Cost / usage | `GET /usage` | `usage` → team settings "spend today", task details | Yes (one row) |
| Events stream | `/events/stream` SSE plus `/events` replay | `events()` → controller timeline, `DispatchCycle` derivation | **Yes**: the whole conversation and the Now line are built from it |
| Live agent output | `/session/{id}/stream` | `watchAgentOutput` → `team_watch_live.dart` | Only as a fallback. When the worker's OpenCode session is readable, the real chat page is used |
| Recovery | beads survive in Dolt; the reconciler restarts dead sessions | none | Partly. After an APK update nothing restarted the supervisor (`crit-team-revive`) |
| Policy | `/front/policy` | `policy` → policy_block | No on the phone (no front) |
| Auth | none on the phone supervisor (`BuiltinTeam` doc: "no password of its own yet") | loopback only | A gap: any app on the phone can reach 127.0.0.1:8472. The in-app OpenCode server has `OPENCODE_SERVER_PASSWORD` |

What the phone really exercises is create task, route it to one worker, watch
events and output, answer asks, message the worker, cancel, and merge through
the refinery. Parallel pools, formulas, the planner, patrols, the witness, the
front merge routes and policy are either off or unreachable on the phone.

## 2. What OpenCode already provides natively

| Need | OpenCode 1 (phone pin 1.18.29) | OpenCode 2 (`lib/api2`) | App support today | Missing |
|---|---|---|---|---|
| A worker per task | `POST /session` with `title`, `parentID`, `permission` (SDK `SessionCreateRequest`). Runs **inside the one `opencode serve`** | `POST /api/session` with `title`, `agent`, `model`, `metadata`, `location` | `SessionGateway.createSession()` exists but takes no arguments yet | Pass title, parent, agent and model through the gateway (small) |
| Role = prompt + model | the prompt takes `agent`, `model`, `system`, `tools` | agent and model are session state set at create or `POST …/agent`; no `system` field | `PromptGateway.promptAsync(agent:, model:)`; `TeamRole` (instructions + model) built today | none. The role's instructions go in `system` (v1) or as a prompt prefix (v2, today's approach) |
| Sub-agents inside a worker | `task` tool: child session with `parentID` in the same process, own agent, model and permission, `subagent_depth`, `task_id` resume, background mode behind `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS` (`packages/opencode/src/tool/task.ts`) | agents with `mode: subagent`; `parentID` on sessions | chat renders sub-agent cards; `listSessionChildren`; `BackgroundWorkSupport` | none |
| Custom agents | `opencode.json` `agent{}`, `.opencode/agent/*.md`, `PATCH /config` | agents from config and files; **no config-write endpoint** | provider and agent pickers | optional. Not needed for slice 1 (use `build` plus the role's prompt) |
| Task list / plan | `todowrite`, `GET /session/{id}/todo` | todos | `SessionGateway.todos` | none |
| Gates / approvals | permission and question asks, per-session `permission` rules | permissions, forms (`/api/session/{id}/form`) | Inbox and chat cards already answer them | none |
| Progress | `/event` and `/global/event` SSE | 91-event union plus durable session log | the chat's live events, stall detection (`7ddac797`) | map session status to task state (small) |
| Steer / message a worker | prompt into the session | `PromptDelivery.steer/queue` | the composer | none |
| Stop / cancel | `abort` | abort | `PromptGateway.abort` | none |
| Changes / review | `GET /session/{id}/diff`, revert | diff and revert | `SessionGateway.diff`, review screens | none |
| Worktree | `POST /experimental/worktree` (`worktreeCreate: true`) | create not usable (`worktreeCreate: false`) | worktree list and inspect | v2 create, and merge in both → git through the session's shell, or the Ubuntu shell on the phone |
| Cost / usage | `cost` and `tokens` per assistant message | same | usage screens | sum per task session (small) |
| Durable queue | sessions persist; the turn dies with the server | prompts admitted to a durable inbox; `POST …/wait` | reconnect then refetch | **a task list and handoff loop outside the model. The app must own this** |

**What is really missing is small.** It is a task record (title, role, state,
session id, `blockedBy`) and a loop that starts the next step when a session
goes idle. The loop means: worker done → reviewer; reviewer done → "Ready to
merge". Beads solves this for many processes that share nothing. Here there is
one app and one server.

## 3. Option B, native team

### Shape

| Part | Native design |
|---|---|
| Orchestrator | The **app** (deterministic, "truth over narration" as in team-conversation §Why A). New `NativeTeamGateway implements OrchestrationGateway` (plus `OrchestrationMergeGateway` from slice 3). New `OrchestrationProvider.native`. |
| Task record | Per profile, key `oc.team.tasks.<profileId>` (JSON; follows the deletion-sweep naming rule): `{id, title, text, roleId, state, sessionId, reviewerSessionId?, worktree?, blockedBy[], createdAt, events[]}`. The session carries the link back: v2 `metadata {teamTask, role}`; v1 a per-project "Team" root session as `parentID`, so `listSessionChildren` finds every task from any device. |
| Worker | `createSession(title, parent, agent, model)` then `promptAsync(text, agent: role agent, model: role.model, system: role.instructions)`. It runs in the **same** `opencode serve` as chat. The worker may use the `task` tool for its own sub-agents. |
| Planner | A read-only session (OpenCode's `plan` agent, Product role) writes the spec and phases (§6). The app turns them into a reviewable card and then into phase records. |
| Isolation | Phone slice 1: none. The worker edits the project like a chat does and review uses the session diff and revert. Slice 3: one git worktree per task (v1 `POST /experimental/worktree`; v2 and merges through git in the session's shell or the Ubuntu shell). |
| Review | Per phase, a verifier session (Tester role) checks the phase's diff against its acceptance criteria (§6). The final roll-up becomes the "Ready to merge" gate. |
| Merge | App-confirmed. With no worktree: "Keep changes" (nothing to do) or "Undo" (session revert). With a worktree: `git merge --no-ff` run for the person. A conflict becomes a gate: "Resolve with a worker". |
| Approvals | The worker's own OpenCode permission and question asks. They already appear in Inbox and chat. `gates()` lists them for task sessions only. |
| Progress | `events()` maps the server's session events (busy, idle, error, tool calls, permission asked) to `ActivityEvent`s for task sessions. The lead lines and the Now line keep working. |
| Watching a worker | Always the real chat page on the worker's session. The `team_watch_live` fallback is not needed. |
| Capacity | App-side queue. Phone: 1 running task (setting 1–3). Computer: 3. The person's chat turn pauses new task starts (the "chat wins" slice that `crit-team-nice` could not build on Gas City). |
| Recovery | On launch, reconcile each unfinished record with its session status. Idle with no finish means an "Interrupted · Continue" gate, or auto-continue (v2's durable inbox resumes by itself). |

### Processes, memory, time

| | Gas City on the phone (today) | Native |
|---|---|---|
| Long-lived processes added | supervisor, `dolt sql-server`, Dolt watchdog, tmux, plus 1 `opencode acp` per active agent. Peak 33–37 processes against Android's ~32 cap (*measured*: aiteam-builtin, `phoneTuning` note) | **0**. Tool children (bash, LSP) are the same as in a chat |
| Resident memory | 79 + 96 + 28 MB idle; plus **563 MB per worker** and 563 MB per refinery (*measured*) | per-session state inside the existing 410 MB server, *estimated* tens of MB; to be measured |
| Worker start | 5–8 s tick, then 22 s to 4 min `acp` cold start, cut-off retries; ~6 min before tuning, 40–70 s expected after (*measured / expected*) | **none**: the server is already warm. First output = one model call, like a chat reply (the Termux "Hello" took 4 s, *measured*) |
| Chat while the team works | "Hello" took ~2 min with the team on (*measured*) | same server and event loop, but no extra processes or Dolt I/O. The app can hold new tasks back while a chat turn runs. *Expected* close to the team-off speed; must be measured |
| Disk / download | AI Team component: 3 tarballs (gc 1.4.1, bd 1.2.2, Dolt), 44 MB download, ~125 MB installed (*measured*) plus the city and Dolt data | 0 |
| Security | loopback supervisor with **no password** runs agents with shell access | only the in-app server, which has a password |
| Works on OpenCode 1 and 2 | Gas City drives `opencode acp` (v1-shaped) | yes, through `ServerGateway` (v1 `system`/`permission`; v2 `metadata`, durable inbox) |
| Works on a computer | yes (the primary PRD persona) | yes, same model: the host's `opencode serve` runs the task sessions. The app must be open for handoffs; a single task turn runs without it |

### What we would delete (phone path), and what we keep

| Delete / stop shipping (phone) | Lines | Keep unchanged |
|---|---|---|
| `lib/builtin/team/*` (supervisor service, city tuning, origin hook, start progress) | 1,594 | Team conversation, board, home, settings, glance strip, Now line, notifications (`lib/ui/screens/team/**`, `chat/team_*`, `widgets/team_*`: ~19.4k lines) |
| `lib/builtin/setup/aiteam_scripts.dart` (downloads, wrapper, nice) | 414 | `lib/state/orchestration.dart` controller, mutation store, receipts |
| `lib/termux/team_runtime.dart`, `team_scripts.dart` (Termux team) | 1,863 | `TeamRole`s and `giveTaskAsRole` (its `applyModel` hook becomes the prompt's `model`) |
| AI Team setup component (gc, bd, Dolt tarballs; tmux, jq, lsof, procps for the team) | — | the domain models (`WorkItem`, `OrchestrationRun`, `OrchestrationGate`, `DispatchCycle`) |
| Phone-only copy: "starting a worker, about 30 s", upkeep, host address | — | `GasCityGateway` + mappers (~5k lines) **for Option C** |

About 3.9k lines leave the phone path. The ~5k-line Gas City adapter stays only
if Option C keeps computer Gas City. `DispatchCycle` needs a native evidence
branch: routed → claimed → working → review → ready → merged, with no
"agent starting" step.

## 4. Option C, hybrid

| Host | Team engine | Why |
|---|---|---|
| In-app Ubuntu (phone) | **Native** | processes, memory, cold start, the chat slowdown, no-auth supervisor |
| Termux OpenCode (phone) | **Native** | same reasons. The Termux Gas City install is retired |
| Computer / VPS OpenCode | **Native by default** | nothing to install; the same UX |
| A person who already runs Gas City on a computer | **Gas City adapter** (opt-in: "Connect a Gas City") | keeps the PRD's primary persona: many parallel agents, formulas, a durable queue that runs with the app closed, the refinery merge queue |

The UI does not change between the two, because both implement
`OrchestrationGateway`. Features are gated on `OrchestrationCapabilities`
flags, never on the provider (AGENTS.md rule). Native sets `controlCreateWork`,
`controlAssign`, `controlMessage`, `controlRespond`, `controlCancelRun`,
`controlAgent` (stop only), `eventStream`, `usage` and `changes`;
`mergeReadiness` from slice 3; `agentOutput`, `policy` and `runs` false.

## 5. Costs and risks

### Effort

| Slice | Content | Days (*estimate*) |
|---|---|---|
| S1a | Engine: `NativeTeamGateway` (records, create+prompt, session→task state, events, gates, stop, message); `createSession` args in both gateways; provider `native`; in-app profile uses it; native `DispatchCycle` branch; tests with a fake `ServerGateway` | 3–4 |
| S1b | Spec flow (§6): planner session produces the spec JSON; kit plan card (approve, edit, ask to change); phases run in order as role sessions; verifier per phase; findings card with Fix and Re-check | 3–4 |
| S2 | "Ready · Keep / Undo" (diff and revert), launch reconcile ("Interrupted · Continue"), cost per task, queue with a phone cap of 1 plus "chat first", auto mode (auto-fix Critical and Major, at most 2 rounds) | 2–3 |
| S3 | Worktree per task (v1 API; git shell for v2), app-confirmed merge, conflict gate, parallel cap > 1 for phases that do not depend on each other | 3–4 |
| S4 | Retire the phone Gas City: stop offering the component, removal flow for existing installs, copy and ledger updates | 1–2 |
| **Total** | | **~12–17 days**. The first usable slice is S1a+S1b (~6–8 days) |

### What the app loses (native vs Gas City)

| Loss | Matters on the phone? | Mitigation |
|---|---|---|
| Work advancing with the app closed (supervisor loop) | Low. A single task's turn still runs on the server with the app closed; only handoffs wait | handoffs happen on the next launch or event; the Android dataSync 6 h cap already bounds background time |
| Many isolated agent processes in parallel | No: the phone pool is capped at 1 | app queue with cap N; `task` tool sub-agents inside a worker |
| Durable queue in Dolt, cross-device truth | Low | session `metadata` / root-session children let any device rebuild the list; the app records are per profile |
| Formulas / molecules / convoys | No (not used on the phone) | Option C for people who want them |
| Refinery merge queue, witness / deacon health patrols | No (witness suspended, front absent) | app-confirmed merge; stall detection from the session's own events |
| Agent identity per process (`GC_ALIAS`, gascity.js plugin, `bd` in the agent's shell) | No | role = agent + model + instructions |
| Interop with Gas City's dashboard and CLI | Only for computer users | Option C |

### Risks

| Risk | Likelihood | Handling |
|---|---|---|
| A long worker turn in the shared server still slows chat (event loop, LSP, bash) | medium | cap of 1, "chat first" hold, `nice` for tool children; measure on the device in S1 |
| v1 1.18.29 ignores `permission` or `parentID` on create | low to medium | verify on the device in S1. The fallback is a title tag plus app records |
| v2 has no `system` and no config write | known | role text as a prompt prefix (today's approach); optional `.opencode/agent/*.md` later |
| Planner or verifier answers in prose instead of JSON; a weak model writes vague acceptance criteria | medium | lenient parser, plus one "answer in the format" retry, plus a fallback to a single-phase plan; the person edits criteria on the card; the planner and verifier model is a role setting |
| Worker edits the project directly in S1 (no isolation) | known and accepted for S1 | review gate plus Undo (revert). Worktrees in S3 |
| Existing phones have Gas City tasks and beads in Dolt | low volume | S4: "Finish or cancel the team's old tasks" read through the old adapter once, then the removal flow. Beads data is deleted with the component. Nothing is migrated into native records (they are not the same shape, and phone tasks are short-lived) |
| Sunk work in Gas City phone tuning (hot start, warm worker, nice, revive) | certain | the UI, state, roles and conversation work carries over. Only the engine changes |

## 6. Traycer-style spec-driven flow

### How Traycer works (public docs only; the source is not public)

Sources: [docs.traycer.ai](https://docs.traycer.ai) pages
[Plan](https://docs.traycer.ai/extension/tasks/plan.md),
[Phases](https://docs.traycer.ai/extension/tasks/phases),
[Verification](https://docs.traycer.ai/extension/tasks/verification.md),
[Epic](https://docs.traycer.ai/extension/tasks/epic.md),
[YOLO](https://docs.traycer.ai/extension/tasks/yolo-mode.md),
[Agents](https://docs.traycer.ai/agents-and-models/coding-agents.md); and
[Augment's comparison](https://www.augmentcode.com/tools/traycer-vs-intent).

| Step | What Traycer does |
|---|---|
| Task | The person states the goal and attaches context: files, folders, images, or a git diff against uncommitted work, a branch or a commit. Four modes: **Plan** (one PR), **Phases** (multi-step feature), **Review**, **Epic** (specs and tickets). |
| Spec (Epic) | Elicitation: it "actively asks pointed questions to surface constraints, edge cases, and the 'invisible rules'". It writes **focused mini-specs** (PRD, tech, design, API) and **tickets with acceptance criteria and status**. Every spec and ticket in an epic stays in the model's context. |
| Phases | It breaks the goal into ordered phases with milestones and scope. The person can **add, reorder (drag), select and merge** phases. Context carries forward ("decisions and mappings"), but each phase runs in isolation. |
| Plan per phase | A file-level plan: file analysis, symbol references, implementation steps, "file changes with exact edits", architecture and approach. The person refines it by chatting until it fits. |
| Hand-off | Traycer **does not write the code itself**. It hands the plan to one of ~16 coding agents (Claude Code, Cursor, OpenCode, Codex, …) or copies a prompt. |
| Verification | It compares the implementation with the plan. Findings are ranked **Critical / Major / Minor / Outdated**. Actions: fix one, fix a selection, "Fix all in <agent>". Then **Re-verify** (checks only earlier findings) or **Fresh verification**. |
| Automation | **YOLO**: plan → code → verify → next phase with no hand-off clicks. You choose which severities are auto-fixed (for example Critical+Major) and which agent runs each stage. It "requires an active IDE": it stops when the computer sleeps. It also pauses on failure or when it runs out of artifact slots. |
| Storage | Tasks, and artifacts (specs, tickets, stories, reviews) on epic boards that can be shared with teammates. The artifact-slot quota suggests Traycer's cloud holds them (*inferred*). |

**Why it feels good.** The plan can be reviewed before any code exists. A
file-level plan with acceptance criteria can be checked, not just believed.
Small phases limit the damage when a step goes wrong. The check is against the
stated intent, not "looks done". Severity ranking tells the person what to look
at. The person steps in at a few cheap points (approve the plan, triage
findings) instead of at every tool call.

### Traycer on the phone, with option B

| Traycer step | Native team (all inside the phone's one `opencode serve`) | App part |
|---|---|---|
| Task + context | "Give the team a task", with optional files or the current diff | existing composer |
| Elicitation + spec | A planner session (OpenCode `plan` agent, which is read-only; Product role) may ask 1–3 questions (OpenCode question asks, already rendered). It then returns one fenced JSON spec: `{goal, constraints[], phases:[{title, roleId, why, files[], steps[], acceptance[]}]}` | a question card, then a new **kit plan card** (Kit-only rule: new `lib/ui/kit` part) |
| Review the plan | The card in the team conversation shows the goal, the phases (role, files, acceptance). Actions: **Approve**, **Edit** (phase text, reorder, remove), **Ask to change** (a message to the planner session, which revises the spec) | plan card + edit sheet |
| Phase run | Each phase is a child session (`parentID` = the task's root) with the phase's role (agent, model, instructions). The prompt holds the spec, this phase, its acceptance criteria and a short summary of the earlier phases. Phases run in order on the phone; phases with no dependencies may run in parallel in S3 | existing worker row → real chat |
| Verification | A verifier session (Tester role, read-only permission) gets the phase's acceptance criteria and the phase session's `diff`. It returns `{findings:[{severity, file, text}], passed}` | a new **kit findings card**: "Checked · 1 major, 2 minor" |
| Fix / re-check | **Fix** sends the chosen findings back into the **same** phase session (its context is kept, and v2 `steer` works). **Re-check** re-runs the verifier on the earlier findings only | findings card actions |
| Auto mode | Team setting: "Fix serious problems by themselves" (Critical+Major, at most 2 rounds). The next phase then starts. Anything left over becomes "Needs you" | settings row |
| Roll-up | Phase rows: Planned → Working → Checking → Passed / Needs you. The task is Done when every phase passed. Then the whole diff goes to "Keep / Undo" (S2) or merge (S3). Cost is the sum of the task's sessions | lead lines + Now line |
| Storage | The spec and phase records sit in the task record (`oc.team.tasks.<profileId>`). Optional later: "Save plan to project" as `.opencode/plans/<task>.md` so that a computer or other devices see it | — |

### Does this make Gas City and beads even less necessary?

Yes. Traycer is a working example of the good version of this product, and it
has no task-graph database, no agent pool and no supervisor. It is a
client-side loop: spec → phase → hand-off → verify → next. It even stops when
the IDE sleeps. That is exactly option B's shape, with the app in the role of
the IDE extension and the phone's OpenCode in the role of the coding agent.
Beads' dependency graph maps to an ordered phase list with an optional
`dependsOn`. Gas City's real strengths are many isolated workers at once, a
merge queue and running with no client. Those are orthogonal to the
spec-driven flow and do not apply on a phone capped at one worker. They remain
the reason for Option C's opt-in computer adapter.

Note: team-conversation §Why A preferred facts over narration. The spec card
keeps that rule: the plan is an artifact the person approves, and every
progress line still comes from session events. The planner only authors the
plan; it does not report progress.

## 7. Recommendation and slice plan

**Build the native team with the Traycer-style flow (Option C: native
everywhere by default, Gas City only as an opt-in computer connection).**

Finish line for the first slice (S1a+S1b): *on the owner's phone, "Give the
team a task" produces a plan card with phases and acceptance criteria. After
Approve, each phase runs as its role's session in the in-app OpenCode, and a
verifier checks it. Findings show with Fix and Re-check. The task ends Done in
the existing team conversation, and no Gas City process runs.*

Non-goals for S1: worktrees, merge, parallel phases, auto mode, epics and
multiple specs, removing Gas City. A "Skip the plan" path (one phase, the task
as written) comes for free with the engine.

| Slice | Owner | Read set | Write set | Acceptance |
|---|---|---|---|---|
| S1a engine | one state/adapter agent | `lib/domain/orchestration_gateway.dart`, `server_gateway.dart`, `lib/state/orchestration.dart`, `team_roles.dart`, `dispatch.dart` | new `lib/orchestration/adapters/native/*`; `OrchestrationProvider.native`; `createSession` args (single-owner `server_gateway.dart` and `product_repository.dart`: freeze the signature first); in-app profile config | fake-`ServerGateway` test: create → session → busy → idle → Done; a permission ask becomes a gate; stop aborts |
| S1b spec flow | the same agent (state), plus one UI agent for the kit plan and findings cards | S1a, `lib/ui/kit/`, `team_conversation_view.dart` | spec and findings parsers (lenient JSON with a "planner answered in prose" fallback), phase loop, 2 kit parts, l10n | a test: spec → approve → 2 phases → verifier fails one → Fix → Re-check passes → Done; an edited or reordered phase is what runs |
| S2–S4 | per §5 | | | |

**Device proof for S1** (record in `docs/qa/aiteam-native-<date>/README.md`):

1. With the native team on, `adb shell ps -A -o PID,RSS,ARGS | grep -cE 'gc|dolt|opencode acp'` shows **0**. The app's process count matches the team-off count.
2. Give a task. The plan card appears within one planner turn (record the time). Edit one phase, then Approve. Phase 1's session appears in about 1 s, with no cold start.
3. While a phase runs, send "Hello" in a normal chat on the same server. Time the first word against the team-off baseline (target: within 2x; today it is ~2 min).
4. A permission ask in a phase appears as "Needs you" in the team conversation and in Inbox. Answering it continues the phase.
5. The verifier's findings card appears with severities. Fix, then Re-check, turns it to Passed. The task ends Done with its diff and cost.
6. Record the RSS of `opencode serve` before, during and after, for the memory row in §3.
