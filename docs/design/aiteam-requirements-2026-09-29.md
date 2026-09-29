# AI Team: requirements and UI, before the engine (2026-09-29)

The owner:
- "Let's put our requirements and the UI first, and then based on the design and requirements we will find or build the AI Team."
- "It should be able to work with multiple agents across days and projects and servers and branches and all quirks. It's not task by task — it's a full project."

This document is **engine-neutral**. It says what the person experiences and
what any engine has to provide. The engine is chosen afterwards against §6–§7.
The candidates are:
- a native team inside OpenCode servers;
- an OpenCode plugin: Advance, opencode-orchestrator, OpenAgentsControl or opencode-spec;
- Gas City.

**Inputs:**
- [aiteam-native-analysis-2026-09-29](aiteam-native-analysis-2026-09-29.md): Traycer research and phone measurements.
- [team-conversation-2026-09-26](team-conversation-2026-09-26.md): a task is a conversation.
- [aiteam-redesign-2026-09-24](aiteam-redesign-2026-09-24.md): words.
- [team-board-2026-09-26](team-board-2026-09-26.md).
- `docs/ux-system/`: the team-delegator persona, the delegate journey and the target IA.
- [visual-language-2026-09-26](visual-language-2026-09-26.md).
- `docs/ux-system/kit-v2.md`: §4 rules, §8 adaptive, §9 kit only.
- Today's QA records: `docs/qa/crit-team-*`, `crit-roles-*`, `crit-watch-page`, `crit-composer-rail`, all 2026-09-29.

Nothing here was run, and nothing in `lib/` changes.

**Measured on the owner's phone (NX721J):**

| What | Value |
|---|---|
| One extra `opencode acp` agent | ~563 MB, 22 s–4 min cold start under proot |
| Child processes | Android kills the app's children past ~32 (Gas City peaked at 33–37) |
| Chat "Hello" | ~2 min with Gas City on; seconds with it off (Termux 4 s) |
| In-app `opencode serve` | ~410 MB |
| Background time | the `dataSync` service is capped at 6 h per rolling 24 h |

## 1. Goal and non-goals

**Goal.** The unit of work is a **project**: an initiative that lasts days to
weeks, like Traycer's epic.

- It has a goal and a **living spec**, and is broken into **milestones → phases → tasks** with dependencies.
- Many agents with roles work on it in parallel. Each task runs on its own branch or worktree, on whichever server suits it: the phone, a computer over Tailscale, or a VPS. A project may touch several repos.
- Every task is checked against its acceptance criteria, and the findings are ranked. Fixes and re-checks go through a loop.
- Work lands through an integration branch and a local merge queue.
- Progress, decisions and an audit trail survive days away, app restarts and phone reboots. The "quirks" (crashes, rate limits, offline servers, conflicting or manual commits, expired sign-ins, budgets) are handled in plain words, never hidden.
- The phone is always the **remote control**. It is an **engine** only for small, single-agent work, and chat always wins on it.

**Non-goals:**
- Anything public without explicit approval. That covers pushes to a public remote, PRs on GitHub, releases and CI runs. Everything is local by default.
- Drag-only interactions (WCAG 2.5.7).
- A narrating lead agent. State comes from engine events and records.
- Auto-merging into the person's main branch without a durable receipt and undo (off, as decided 2026-09-28).
- Showing cost the engine does not report. Unknown is never shown as zero.
- Choosing the engine (§7 does that).
- Long parallel multi-agent work hosted on the phone.

## 2. Personas and situations

| Who | Situation | What matters |
|---|---|---|
| **Phone-only** (in-app Ubuntu server) | No computer. Memory, heat and the process cap are hard limits | Chat stays fast. One agent at a time. An honest "this needs a computer for parallel or overnight work" |
| **Phone + always-on host** (PC or VPS over Tailscale) | The host runs the agents for days. The phone gives goals, answers, reviews and merges | The phone never has to be open. The work carries on overnight. A "since you were away" digest |
| **Several servers and repos** | The app on one repo, the backend on another host, docs on the phone | One project view across servers. Work can move between servers. Each repo merges on its own |
| **Away for days** | Checks in once a day, one-handed | One digest. Only real decisions are asked. A budget that stops spending |

## 3. Core journeys

**J1: project from goal to done.**

1. **Start a project.** The person uses Work › New › Project (or Team › New project) and fills in:
   - the goal (text and files);
   - the repos (each on a server);
   - a budget (per day and in total);
   - the review level.
2. **Shape the spec.** The planner asks pointed questions (edge cases, constraints), which appear as request cards. It then writes the **living spec**: goal, constraints, decisions, out of scope, and milestones with acceptance criteria.
3. **Review the spec** in the spec editor. The person edits sections, reorders or removes milestones, or uses **Ask to change**. **Approve spec v1** freezes that version.
4. **Plan milestone 1.** It is broken into phases and tasks. Each task has a role, a repo, a server (suggested), dependencies and criteria. The person reviews the plan card and approves it (editing is the same as in step 3).
5. **Work in parallel.** Ready tasks start on their servers, each on its own branch. The overview shows the agents at work across servers, and the board or graph shows progress. Each task is a conversation.
6. **Answer.** Questions, permissions and review gates appear in three places: in the task, in Needs you (Inbox, the Work strip, the project overview) and as a notification. They are answered once.
7. **Check each task** against its criteria. Findings are ranked, with Fix, Re-check and Ignore. Auto mode handles them within caps.
8. **Merge queue.** Checked tasks join the project's local integration branch in order. After each merge, the queue re-checks the combined result. Conflicts become Needs you or a "Resolve with an agent" task.
9. **Milestone review.** When a milestone's criteria are met on the integration branch, the person reviews the milestone diff and findings, and uses **Accept milestone**. Integration into the person's main branch is a confirmed, receipted act. A PR is only created if the person asks.
10. **Days pass.** Opening the app shows **Since you were away**: what merged, what failed, which decisions were made (by whom), what was spent, and what needs the person.
11. **Change the spec mid-way.** An edit shows "Spec v3 · affects 4 tasks". **Replan** revises only the tasks that are not started or are affected. Running tasks keep going until the person stops them.
12. **Done.** When every milestone is accepted, the project reads "Done". The timeline and spec history stay.

**J2: the quirks.**

| Situation | What the person sees and can do |
|---|---|
| **Agent crashes** | The task shows "Stopped unexpectedly · Retry / Reassign". An automatic retry happens once if the engine can, and is recorded |
| **Rate limit or quota** | "Waiting for Anthropic's limit · resumes 14:05". Other tasks carry on. Optionally: "Use {fallback model} meanwhile" (a role setting) |
| **Model error / expired sign-in** | The affected agents pause. Needs you: "Sign in to {provider} again", which opens provider settings. The key is never shown |
| **Stuck or looping agent** | After N minutes with no progress, or when the task's token cap is reached: "Frontend seems stuck on 'X' · Nudge / Restart task / Reassign" |
| **Conflicting edits** | The merge queue stops that item: "Conflicts with 'Theme store' in 2 files · Resolve with an agent / I'll resolve it" |
| **Person's own commits** | The engine sees commits on the target branch that the team did not make. It rebases task branches onto them, or flags a conflict. It never rewrites the person's commits and never force-pushes |
| **Server goes offline mid-work** | The server's tasks read "On pop-os · not reachable since 10:02". Tasks not yet started can be **moved** to another server. Running ones can move only if their branch is on a remote both servers reach; otherwise "Wait for pop-os / Start over elsewhere" |
| **Phone reboot / app killed** | Tasks on a host go on. Tasks on the phone read "Interrupted · Continue". Nothing claims "Working" when nothing runs |
| **Long waits** | Each wait names what it is waiting for and since when ("Waiting for review · 2 h"). Wait escalations are listed in the digest |
| **Budget reached** | New task starts stop. Running tasks finish their current step, then pause. Needs you: "Raise budget / Pause project" |
| **Handing work over** | Reassign a task to another role or server. A hand-off note (summary, branch, open findings) goes with it, and the new agent starts from the branch |

## 4. Requirements

Priority is **M**ust, **S**hould or **C**ould. Every check can be run on a
device (the owner's phone, the emulator, or the owner's PC as host).

### 4.1 What the phone hosts vs what needs an always-on host

| Capability | Phone in-app server | Always-on host (PC/VPS) |
|---|---|---|
| Control plane: view, answer, approve, edit the spec, move work, merge-review | **Yes, always** | — |
| One agent task at a time (chat first) | Yes | Yes |
| Several agents in parallel | **No.** At most 1 running agent turn (2 only as an explicit override with a warning) | Yes (cap set per host) |
| Work that continues overnight or with the app closed | **No.** At most a finishing turn, within 6 h per 24 h | Yes |
| Durable queue, merge queue, audit across days | Records kept, but advanced only while the app runs | Yes |
| Worktrees and local merges | Small repos only (disk and CPU) | Yes |

**R-01 (M):** when a project asks for more than the phone can host (more than 1
parallel agent, or overnight work), the app says so before starting. It then
offers "Run on {host}" or "Run one at a time on this phone".
*Check:* create a project on a phone-only profile with 3 parallel tasks. The
notice appears, and at most one task runs.

### 4.2 Project, spec and plan

| ID | Pri | Behaviour | Acceptance check |
|---|---|---|---|
| R-10 | M | A project has a goal, repos (each on a server), a review level, budgets and a **living spec**: goal, constraints, decisions, out of scope, milestones with criteria | Create one. Every section is visible in the spec editor after a restart |
| R-11 | M | The planner asks up to 5 clarifying questions before spec v1, as request cards | A vague goal gets a question. The answer shows up in the spec's Decisions |
| R-12 | M | The spec is versioned. Each approved version is kept with who approved it and when. The diff between versions can be read | Edit and approve v2. History shows v1 → v2 with the changes |
| R-13 | M | Milestones → phases → tasks. A task has a title, role, repo, server, depends-on, criteria and a branch. **What runs is what the approved plan says**, including the person's edits | Remove a task and reword a criterion, then approve. The removed task never runs, and the agent's prompt has the new words |
| R-14 | M | A spec change marks the affected tasks. **Replan** changes only those tasks, and running tasks keep going unless the person stops them | Change a constraint. "Affects N tasks" appears, and Replan rewrites only those |
| R-15 | S | Agents may propose spec changes ("Decision needed: SQLite or files?"). They become Needs you and never change the spec by themselves | An agent proposal appears as a request card. Accepting it adds it to Decisions |
| R-16 | M | A planner answer in prose instead of a plan gets plain words, **Use as one task** / **Ask again**, and Details | Force a format failure. No raw parser error is shown |
| R-17 | C | "Save spec to repo" writes the spec as Markdown in a chosen repo (a local commit only) | The file is committed on the integration branch |

### 4.3 Agents, roles, placement and parallelism

| ID | Pri | Behaviour | Acceptance check |
|---|---|---|---|
| R-20 | M | A role is a name, instructions and a model, with a fallback model optional. The planner and the checker are roles, and the checker is read-only | Set the checker's model. The findings show it. A checker attempt to write is refused |
| R-21 | M | Each task has a server. The planner suggests one (the repo's server, then capacity). The person can change it before the task starts | Change a task's server to the phone. It runs there |
| R-22 | M | A parallel cap per server (phone 1; host default 3). Tasks whose dependencies are done start as capacity frees | 4 ready tasks on a host with cap 3: 3 run and 1 queues, then it starts |
| R-23 | M | **Move work:** a task not started moves to another server in one step. A running task moves only when its branch is reachable from the target; otherwise the choice is named: wait, or start over | Move a queued task from the PC to the phone. It runs on the phone |
| R-24 | S | Reassign a task to another role or server with a hand-off note (summary, branch, open findings) | The new agent's first message contains the note |
| R-25 | M | A project can span repos. Each task targets one repo, merges happen per repo, and a milestone is done when all its repos' merges land | A 2-repo milestone shows 2 merge queues, and is done only when both have merged |

### 4.4 Execution visibility and conversation

| ID | Pri | Behaviour | Acceptance check |
|---|---|---|---|
| R-30 | M | Every task is a conversation on the chat page: the task, its steps folded (newest 3 while running), findings, a merge-queue entry, and "Open {role}'s conversation" for the real session | Open a task. The watching page shows the task title and role name, with no generated names |
| R-31 | M | **One live status per page.** In a task, the composer's living edge carries "Frontend · 3:10". On the overview, the status slot carries the project's one line. There are no duplicate clocks | Only one elapsed clock is visible per page |
| R-32 | M | State words come only from engine events or reads. 20 s or more without news says so, with a way on. After a reconnect, the app refetches (no replay) | Stop a host's server. Within 30 s its tasks read "not reachable", never "Working" |
| R-33 | M | The overview shows agents at work across every server: role, task, server, elapsed | Tasks on the phone and the PC: both listed under their server |

### 4.5 Needs you, review gates, notifications

| ID | Pri | Behaviour | Acceptance check |
|---|---|---|---|
| R-40 | M | Needs you covers spec and plan approval, questions, permissions, findings that block, conflicts, sign-in expiry, budget reached, stuck agents and milestone review. It shows in the task, Inbox, the Work strip and the project overview, with one notification. Answering it once clears it everywhere | A permission ask on the PC host: all four places show it; answering from Inbox clears all within 2 s |
| R-41 | M | The **review level** per project decides which gates reach the person. **Every step** means each plan, each task's findings and each merge. **Milestones** means the spec, plans and milestone review; task findings are auto-fixed within caps. The spec and milestone review are always the person's | With "Milestones", task findings never reach Needs you unless unresolved after the caps |
| R-42 | M | Notifications: Needs you (alerting); Milestone ready / Project done (alerting, on by default); Problem (a crash, offline, budget: alerting, one per cause); Working (silent, ongoing, one per app). Quiet hours are respected, and a notification never answers anything itself | Background during work: one ongoing notification. A budget stop posts one alert |
| R-43 | M | **Since you were away:** after 4 h or more away, the project opens on a digest: merged, failed, decisions (made by the person, an agent or auto mode), cost, and what needs you. Once read, it folds into the timeline | Leave the app for 4 h during host work. The digest lists every merge and decision in that window |

### 4.6 Verification

| ID | Pri | Behaviour | Acceptance check |
|---|---|---|---|
| R-50 | M | After each task, a read-only check compares its diff with its criteria. It returns findings {severity: Critical/Major/Minor/No longer applies, criterion, file:line, text} and met/unmet per criterion | A planted miss gives a Major finding that names the criterion |
| R-51 | M | Fix selected (in the same task context), Re-check (earlier findings only), Check again from scratch, Ignore (recorded with who) | Fix, then Re-check: "Passed · resolved 1"; no new session |
| R-52 | M | **Auto mode** fixes chosen severities (default Critical+Major), at most N rounds (default 2, max 3). Anything left over becomes Needs you. Every automatic act is in the timeline | A planted Major is fixed without taps. After the caps, Needs you |
| R-53 | S | A milestone check runs on the integration branch against the milestone's criteria after the merge queue drains | The milestone review shows the milestone check's findings |
| R-54 | S | Local checks run with no CI: the repo's own test/analyze commands, set per repo, run by the checker or the merge queue | The merge queue log shows the repo command passing before a merge |

### 4.7 Branches, merge queue, integration

| ID | Pri | Behaviour | Acceptance check |
|---|---|---|---|
| R-60 | M | A branch (worktree) per task, created from the project's integration branch per repo. Names are readable (`team/<project>/<task>`), and they appear only under Details | `git worktree list` on the host shows one per running task |
| R-61 | M | A local **merge queue** per repo: checked tasks merge into the integration branch in dependency order, and the repo checks re-run after each merge. Each merge has a receipt (commit before and after) | 3 tasks merge in order, and each receipt names its commits |
| R-62 | M | A conflict stops only that item. It becomes Needs you with **Resolve with an agent** / **I'll resolve it** | A planted conflict: the other items continue |
| R-63 | M | Manual commits by the person on the integration or main branch are detected. Task branches are rebased onto them, and anything that cannot be rebased becomes a conflict. There is no force-push and no rewrite of the person's commits | Commit by hand mid-project. The queue rebases, and the person's commit stays unchanged |
| R-64 | M | Integration into the person's target branch (main) is per milestone. It is confirmed, names the repo and branch, and gets a receipt | Accept a milestone. The receipt shows the target branch before and after |
| R-65 | S | Undo a merge from the queue or a milestone by adding a reverting commit (never a history rewrite), where the engine provides durable receipts | Undo: a revert commit appears, and unrelated commits are untouched |
| R-66 | S | "Open a pull request" is available only when the person asks. It is confirmed each time and names the remote and repo. Nothing is pushed to a public remote otherwise | No push happens without the confirm, as the remote log shows |

### 4.8 Durability, recovery, audit

| ID | Pri | Behaviour | Acceptance check |
|---|---|---|---|
| R-70 | M | Project, spec, plan, task state, findings, merge receipts and timeline survive app death, phone reboot and days away. On a host they live on the host, readable from any device | Reboot the phone. Every project reappears with the same state. Open it from the PC as well: the same view |
| R-71 | M | On launch or reconnect, every unfinished task is reconciled with its server before being drawn as live. Interrupted phone tasks read "Interrupted · Continue" | Kill the app mid-task. Within 5 s: Interrupted, never Working |
| R-72 | M | **Continue** resumes in the task's own context and branch (or restarts the task from its branch, and says which) | Continue: "Continued" or "Restarted from branch" on the card |
| R-73 | M | **Timeline / audit trail:** every spec version, approval, answer, automatic act, merge, move, retry and budget event, with the time and who did it (the person, a role, auto mode or the engine). It is grouped by day and can be filtered | Filter to Decisions over 3 days. Each entry has its actor and time |
| R-74 | S | Automatic recovery: one retry for a crashed agent, back-off for rate limits, and stall detection. Each one is recorded, and the second failure goes to Needs you | Kill an agent process on the host. One retry is recorded, then Needs you |

### 4.9 Budgets and cost

| ID | Pri | Behaviour | Acceptance check |
|---|---|---|---|
| R-80 | M | Budgets per project, per day and in total (money or tokens), plus a token cap per task. At 80 % there is a notice. At 100 % no new starts, running steps finish, then everything pauses with Needs you | Set $1/day. At the cap, new starts stop and one alert posts |
| R-81 | S | The overview shows cost today and in total, per role and per server, only as reported by the engine. "Unknown" is never shown as $0 | An engine with no cost data shows "Not reported" |

### 4.10 Performance on the phone (chat first)

| ID | Pri | Behaviour | Acceptance check (owner's phone, in-app server) |
|---|---|---|---|
| R-90 | M | A chat's first word while a team task runs on the same server takes ≤ 2× the team-off baseline and ≤ 10 s. No new team turn starts while a chat turn waits for its first word | Five "Hello"s with and without a task running: median ratio ≤ 2, and none over 10 s |
| R-91 | M | Controlling remote projects (the host does the work) adds nothing to chat latency. The phone polls no faster than every 30 s when events stream | The same test with the work on the PC: ratio ≤ 1.1 |
| R-92 | M | A task on the phone adds ≤ 150 MB resident and ≤ 1 long-lived process. The app tree stays ≤ 24 processes. Team on and idle adds ≤ 20 MB and makes no model calls | `ps` RSS and count: off, idle and running |
| R-93 | M | Opening a project overview takes ≤ 1 s from cache. The digest shows ≤ 2 s after the host answers. Task start → first agent output takes ≤ 20 s on a warm server | Stopwatch |
| R-94 | S | The heat guard pauses new phone tasks ("Cooling down · carries on by itself"). A slow chat word shows "AI Team is also working on this phone" | Emulated thermal state |

### 4.11 Privacy, security, accessibility, localization

| ID | Pri | Behaviour | Acceptance check |
|---|---|---|---|
| R-100 | M | Hosts are reached over the tailnet only, under the server's own authentication. There is no unauthenticated listener on the phone | `ss -ltn` in the proot: no new listener without auth |
| R-101 | M | Provider keys and server passwords never appear in the spec, findings, the timeline, notifications, diagnostics or Details. The engine never needs keys from the app | Grep an export and screenshots: 0 hits |
| R-102 | M | Server-authored links go through `openExternalLink`. Local records use `oc.team*.<profileId>` keys and are swept on profile deletion | After deleting the profile, no `oc.team*` keys remain |
| R-103 | M | 48 dp targets. Reorder and move work with buttons or a menu (no drag-only). PC keyboard: A and D, 1–9, Esc. Reduced motion stills the edge light. Text scale 2.0 and RTL work | G4, G6 and G14 galleries at 360 and 1280. A TalkBack pass over the overview, the spec and each card |
| R-104 | M | All copy is in `app_en.arb`/`app_ar.arb`. No engine words (bead, polecat, convoy, city, ACP, plugin names) outside Details. Branch names, paths and ids are LTR and copyable. No raw errors: plain words, a way on, then Details | The glossary test covers the new parts. Arabic renders of each part |

## 5. UI specification

The kit-only rule applies. Screens only arrange `lib/ui/kit/` parts.

- **Reused:** `KitBoardLane`, `KitTaskCard`, `KitWorkGraph`, `KitRequestCard`, `KitComposer.rail`, `KitWorkLine`, `KitDiffView`, `KitReceipt` and `KitNeedsYou`.
- **New parts** go in `lib/ui/kit/team/`, each with its §8.4 gallery:
  - `KitPlanCard`: a spec or plan proposal;
  - `KitMilestoneRow`: progress, criteria met and state;
  - `KitFindingsCard`;
  - `KitMergeQueue`: the queue list plus a receipt per item;
  - `KitDigest`: since you were away;
  - `KitTimelineDay`;
  - `KitServerLane`: agents at work on one server.

**Words.**
- Project: the initiative.
- Repo: a codebase (see Q1).
- Milestone, phase and task.
- Agent roles by name: Frontend, Tester, Planner, Checker.

### 5.1 Screens

| Screen / part | Shows, in order | States | Parts |
|---|---|---|---|
| **Work strip** (Work tab) | "AI Team · 3 working · 1 needs you", then up to 3 rows (needs-you first): a project or a task that needs the person | idle: "AI Team · nothing running"; off: hidden; offline host: last-known with its age | `KitRow`, `KitTaskMark`, `KitNeedsYou` |
| **Projects** (Team home) | Top bar "AI Team" plus Settings. Then Needs you (as rows). Then **projects by urgency**: title, "Milestone 2 of 4 · 3 working · on 2 servers", and the budget only when near it. Then Done projects (3, then Show all). Pinned: **New project** · Give a quick task | empty: one sentence plus the two actions; loading: skeleton; host down: last-known rows with age | `KitScaffold`, `KitRow`, `KitStateView`, `KitStatusLine` |
| **Project overview** | The digest if away ≥ 4 h. Then the status line ("On track · milestone 2 of 4"), Needs you, **Milestones** (progress rows), **Agents at work** (grouped by server), **Merge queue** (per repo, when not empty), **Recent decisions** (3), **Cost** (today and total vs budget). Top bar: Spec · Board · Timeline, and a menu (Pause project, Settings, Details) | planning (the spec card in progress); running; paused (why, and Resume); blocked (the one reason first); done (summary plus timeline) | `KitMilestoneRow`, `KitServerLane`, `KitMergeQueue`, `KitDigest` |
| **Spec editor** | Version chip ("v3 · approved 2 d ago"). Sections: Goal, Constraints, Decisions, Out of scope, Milestones (each with criteria, and up/down). Pending agent proposals at the top. **Approve v4** (primary) · Ask to change · History | draft (unsaved changes kept as a draft); proposed (by an agent: amber); approved; replan-needed ("Affects 4 tasks · Replan") | `KitField`, `KitRow`, `KitPlanCard`, `KitDiffView` (version diff) |
| **Board / graph** | The existing board (Backlog · Ready · Working · Review · Done), with filters for milestone, repo and server. The toggle shows the dependency graph | the board as in team-board-2026-09-26 | `KitBoardLane`, `KitTaskCard`, `KitWorkGraph` |
| **Timeline** | Days (newest first), each a `KitTimelineDay` of events with actor and time. Filters: Decisions · Merges · Problems · Everything | empty day hidden; long day folded after 10 | `KitTimelineDay`, `KitSegmented` |
| **Servers** (cross-server) | One lane per server: reachable or since when, cap and use ("2 of 3 agents"), its tasks. Per task: Move to…; per server: Pause | offline: last-known with its age, "Move tasks not started" | `KitServerLane`, `KitRowMenu` |
| **Task conversation** (drill-down) | Top bar: task title, "Frontend · on pop-os · team/dark/settings". Transcript: the task (from the plan), folded steps, request cards, the findings card, then the merge-queue entry ("3rd in queue" → receipt). Composer: "Message Frontend…". Its living edge is the one live status | running; waiting (rate limit or dependency, with the time); needs-you; stuck; interrupted (Continue); moved; done | `KitTurn`, `KitWorkLine`, `KitToolRow.agent`, `KitFindingsCard`, `KitComposer.rail` |
| **New project sheet** | Goal (multi-line, a kept draft) plus files. Repos (add: repo + server). Review level (`KitSegmented`: Every step · Milestones). Budget per day and in total. **Start planning** | host missing: "Parallel work needs a computer · Add a server / Run one at a time here" | `showKitSheet`, `KitField`, `KitPickerRow`, `KitSegmented` |
| **Quick task sheet** | A task with no project: Who (role), Where (server), Plan first · Just do it. It becomes a one-task project in the list | as above | same |
| **Roles / Agents** | Roles by urgency (working first, "Working on 'X' · on pop-os · 4 min"). A role page: instructions, model, fallback model, live tasks, recent tasks | remote host: "The computer's model" (read-only) | `KitRow`, `KitField`, `KitPickerRow` |
| **Team settings** | Servers and caps (phone 1); defaults (review level, auto mode severities and rounds, budgets); chat first (always on for the phone); roles; Details (engine, versions, addresses); Turn off | a capability the engine lacks: the row is absent or explained | `KitRow`, `KitSwitchRow`, `KitDetailsFold` |
| **Notifications** | "oc_app redesign: {question}" · "Milestone 2 ready to review" · "pop-os not reachable · 3 tasks waiting" · "Budget reached · paused". Silent ongoing: "AI Team: 3 agents working". The lock screen gets a public version without text | one ongoing notification per app; problems collapse per cause | existing channels |

**Adaptive layout (kit-v2 §8).**

| Window | Layout |
|---|---|
| Phone | Single column. The overview's sections stack, and the spec, board, timeline and servers are pushed pages |
| Tablet | Two panes: the projects list and the overview |
| PC | Three panes: the projects list (296), the overview or task conversation (700 max), and a side pane (340) for the spec, the diff or the servers |

Keyboard and motion:
- On PC, the board and graph take arrow keys.
- Motion uses `KitMotion`. The edge light follows the crit-composer-rail caps.
- Resting pages have no ambient loop, and nothing moves under reduced motion.

### 5.2 Wireframes (phone, 360 dp)

**Project overview:**
```
 oc_app redesign                 Spec Board ⋮
 On track · milestone 2 of 4 · 3 working
╭────────────────────────────────────────╮ amber
│ ● Needs you · Keep drafts in SQLite?   │
│   Decision from Backend · 20 min    ›  │
╰────────────────────────────────────────╯
 Milestones
 ✓ 1 Kit parts            Accepted Mon  ›
 ◐ 2 Team screens     5 of 8 tasks ▰▰▰▱ ›
 ○ 3 Phone proof          waits on 2    ›
 Agents at work
 pop-os   Frontend · Settings list · 12m ›
          Tester · Board checks · 3m    ›
 phone    Docs · Arabic copy · 1m       ›
 Merge queue · app repo · 2 waiting     ›
 Cost  $1.84 today · $9.10 of $25       ›
```

**Plan card** (a milestone plan proposal):
```
╭────────────────────────────────────────╮ amber
│ Plan for milestone 2 · waiting for you │
│ 3 phases · 8 tasks · 2 repos           │
│ ── Phase 1 · Data ──────────────────── │
│ 1 Team store      Backend · pop-os   › │
│   app repo · 3 criteria                │
│ 2 Sync endpoint   Backend · pop-os   › │
│   api repo · after 1                   │
│ ── Phase 2 · Screens ───────────────── │
│ 3 Overview page   Frontend · pop-os  › │
│ 4 Arabic copy     Docs · phone       › │
│   … 4 more                             │
│ [        Approve and start        ]    │
│   Edit plan          Ask to change     │
╰────────────────────────────────────────╯
```

**Findings card** (in a task):
```
╭────────────────────────────────────────╮ amber
│ Checked · 1 major, 2 minor             │
│ ☑ Major  Choice lost on restart        │
│          settings_store.dart:88        │
│          Criterion 2 · survives restart│
│ ☐ Minor  No Arabic label on switch     │
│ ☐ Minor  Unused import                 │
│ [          Fix 1 selected          ]   │
│   Re-check       Ignore and continue   │
╰────────────────────────────────────────╯
```

**Merge queue** (per repo, on the overview):
```
 Merge queue · app repo → team/redesign
 ✓ Team store      merged 10:02 · a1b2→c3d4
 ◐ Overview page   checking after merge 0:40
 ⚠ Settings list   Conflicts in 2 files     amber
     Resolve with an agent · I'll resolve it
 ○ Arabic copy     waiting on Overview page
 Milestone 2 → main: after the queue drains
```

**Since you were away** (top of the overview after ≥ 4 h):
```
╭────────────────────────────────────────╮
│ Since Tue 22:10 · 11 h                 │
│ ✓ 4 tasks merged · milestone 1 accepted│
│ ↻ Auto-fixed 3 findings (2 rounds)     │
│ ⚠ pop-os was offline 02:14–03:40       │
│ ✎ Backend decided: drafts in SQLite  › │
│ $3.20 spent · 1 needs you              │
│   Open timeline              Got it    │
╰────────────────────────────────────────╯
```

## 6. Engine contract

The UI reaches these capabilities through the domain gateway and gates on the
capability flags, never on the engine's name. **Fill** means the app could
build the capability itself over plain OpenCode sessions.

| ID | Capability | Pri | Fill? |
|---|---|---|---|
| E-01 | Create a project (goal, repos with servers, budgets, review level) and a quick task. Ids return at once | M | yes |
| E-02 | Elicit questions, produce and **version** a structured spec; accept an edited spec as the one in force | M | yes |
| E-03 | Plan milestones → phases → tasks with role, repo, server, depends-on and criteria; replan only affected tasks | M | yes |
| E-04 | Run a task with a role (instructions + model + fallback) on a chosen server and branch | M | yes |
| E-05 | **Parallel execution** with a per-server cap and dependency-ordered starts | M | partly: only while the app runs |
| E-06 | **Durability across days:** queued, running and finished state and the audit trail persist without the app, readable from any device | M | **no** (needs a host-side store) |
| E-07 | **Advances with no client connected**: starts, hand-offs, checks and the merge queue | M for hosts · n/a phone | **no** |
| E-08 | **Multi-server placement**: run on any registered server; move a task that has not started; move a running one via a shared remote | M | partly |
| E-09 | Stream progress per task (events, idle, error); state refetchable after a reconnect | M | OpenCode events |
| E-10 | Asks (permission, question, decision) per task; answer, message or steer | M | OpenCode |
| E-11 | Read-only check against criteria with ranked findings; fix in context; re-check; fresh check | M | yes |
| E-12 | Auto mode with severity and round caps | S | yes |
| E-13 | **Branch management**: a worktree per task from the integration branch; rebase onto new commits; detect manual commits; never force-push | M | partly (git in the shell) |
| E-14 | **Merge queue** per repo, with local checks after each merge, conflict stop per item, and **durable receipts** (before and after) | M | partly |
| E-15 | Integration to main per milestone (confirmed); revert-commit undo; PR only on request | S | partly |
| E-16 | **Recovery**: crash retry, rate-limit back-off, stall and loop detection, reconcile after restart, continue from the branch | M | partly |
| E-17 | **Budgets**: per project/day/total and a per-task token cap; stop starts at the cap; report usage per task, role and server | M | partly (sums while the app runs) |
| E-18 | Timeline events with actor and time for every decision and automatic act | M | partly |
| E-19 | **Chat-first hold** on a shared server: no new team turn while a chat turn waits for its first word | M (phone) | yes |
| E-20 | Runs under the server's own auth; no new unauthenticated listener; never needs provider keys from the app; tailnet-only | M | — |
| E-21 | Works with the phone's in-app OpenCode (OC1 today); OC2 as well | M / S | — |

**Neutral note on the engine picture.** Project scope moves weight onto E-05
to E-07, E-13, E-14 and E-16. The app cannot supply these while it is closed.
That means:
- an engine with a durable host-side queue, parallel workers and a merge queue (Gas City's strengths, or a host-resident plugin or service) matters again **on a computer host**;
- on the phone, the app may be the **control plane only**, plus at most one light local agent.

§7 decides this with measurements, not preference.

## 7. Engine evaluation rubric

Measure phone cost and chat impact on the NX721J (R-90 to R-92). Measure host
behaviour on the owner's PC over Tailscale. **Disqualifiers for a role:**
- **Phone engine:** more than 1 added long-lived process, a chat ratio over 2×, or an unauthenticated listener.
- **Host engine:** E-06, E-07 or E-14 missing and not fillable on the host.

| Candidate | Contract (M x/19 · S x/2; filled by app) | Phone cost (processes / MB / cold start) | Chat-first impact | Durable across days (E-06) | Runs with app closed (E-07) | Parallel + multi-server (E-05, E-08) | Branches + merge queue (E-13, E-14) | Recovery + budgets (E-16, E-17) | OC1 + OC2 | API-drivable (not only slash commands) | License | Maturity | Fits as |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Native team (app-driven loop over OpenCode servers) | | | | | | | | | | | | | |
| Native + small host service (same records, host-resident loop) | | | | | | | | | | | | | |
| Advance (OpenCode plugin) | | | | | | | | | | | | | |
| opencode-orchestrator (plugin) | | | | | | | | | | | | | |
| OpenAgentsControl (plugin) | | | | | | | | | | | | | |
| opencode-spec (plugin) | | | | | | | | | | | | | |
| Gas City on a computer/VPS | | | | | | | | | | | | | |
| Gas City on the phone (today's baseline) | | | | | | | | | | | | | |

"Fits as" is one of: phone engine · host engine · control plane only · not suitable.

## 8. Open questions for the owner

| # | Question | Recommended default |
|---|---|---|
| 1 | The word "project" already means a codebase in the app. What do we call the initiative? | **"Project"** for the initiative (the owner's word). In team screens a codebase is a **"repo"**. Chat keeps its folder wording |
| 2 | Must a phone-only person be able to run a whole project on the phone? | **Yes, one task at a time**, with a clear "parallel and overnight need a computer". A computer host is recommended, not required |
| 3 | Default review level? | **Milestones**: the person approves the spec, plans and each milestone. Task findings are auto-fixed (Critical+Major, 2 rounds), and leftovers come to the person |
| 4 | Integration into main: per milestone or at the end? | **Per milestone**, confirmed with a receipt. Never automatic until durable merge receipts and undo exist |
| 5 | Default budget for a new project? | **$5 per day, no total**, with a notice at 80 %. Tokens are shown when the engine reports no money |
