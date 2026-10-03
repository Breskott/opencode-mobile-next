# Journeys and jobs (2026-09-26)

This summary is built from the Phase 1 map, `map/all.json`. The map has 356 page records with 410 `sameJobElsewhere` entries. Every entry is clustered into exactly one job. `journeys.json` holds the full data:

- every entry point and where it lands,
- the source entries (`<pageId>#<n>`),
- the intersections, patterns and priorities.

The owner's verdicts outrank the critics. Surprising claims were checked in the code; `file:line` references are in the JSON.

**Result:** 52 canonical jobs. Following the targets, **21 pages disappear and 68 merge into another page**, which covers every remove or merge proposal in the map.

## The five worst inconsistencies

1. **Answering the agent lands in two places, in three shapes.**
   - A request opened from Work lands in the chat (`workspace_screen.dart:1184`). The same request opened from the Inbox, other-server rows or a notification opens a sheet over a list (`activity_screen.dart:766,809`; `profile_monitor_screen.dart:65,75`).
   - OC1 question cards, OC2 form cards, ```` ```choices ```` and team gates are four builds of one idea. Only team gates show a receipt.
   - The work line still says "Running tools" while the agent waits.
2. **A team task has two pages.**
   - Work rows and board cards open the task conversation.
   - Team-home rows open `RunScreen`, because `onOpenRun` is never passed (`team_home_screen.dart:132-143`). Notifications also open `RunScreen` (`main.dart:967`).
   - "Give the team a task" ends on the conversation from Work (`TeamConversation.start`), but stays on the home from the team page (`team_home_screen.dart:177`).
   - The conversation, the task's decided home, cannot stop its task.
3. **There are three installers for one "set up this phone".** The installers are phone setup v2, the legacy in-app steps and the Termux wizard.
   - The ledger has 17 edges into `termux-setup` against 3 into `phone-setup-start`. Nine call sites still push `/termux-setup`.
   - Claude Code installs only over Termux. The phone AI Team has two installers.
   - There are four progress surfaces and two success moments.
4. **"What needs me" has four answers for other servers.** Inbox, Work's panel, `attention-overview` (a stale cache) and `profile-monitor` each answer it, with three landings. Work and Inbox also duplicate each other.
5. **Turning the AI Team on: five doors, three flows.**
   - Settings › AI Team opens *Plugins* when the team is on (`search_index.dart:548`).
   - There is a third management sheet under an engine name (`team-plugin-sheet`).
   - The phone path goes through the old Termux wizard (`team_intro_screen.dart:190`).

Close behind:
- **Revert** differs by protocol and by door (`chat_screen.dart:4689/4712`).
- **Archive** undoes on swipe but confirms from the menu (`workspace_screen.dart:1497-1503`).
- **Report a bug** sends only the version to GitHub, while diagnostics go to the person's own server log.
- There are two classes named `TeamReceiptChip` (`team_controls.dart:52`, `team_receipt.dart:101`).

## Jobs: today → target

"Doors" is the number of `sameJobElsewhere` entries for the job. "Target" is the canonical landing.

| Job | Journey | Doors | Today: where the doors land | Target |
|---|---|---|---|---|
| Set up this phone | install | 19 | phone-setup-progress · builtin-server-setup · termux-setup-installing | phone-setup-start → progress → ready (host is a Customize choice) |
| Add a tool to this phone | install | 10 | Termux wizard (Claude Code) · v2 or team checklist (AI Team) | Customize (add mode) → progress → ready |
| Manage the phone's agent | configure | 17 | card · wizard page · list row · legacy page | one host-neutral "This phone" page; v2 jobs |
| Turn the AI Team on | install | 14 | team-intro · plugins · team-plugin-sheet · termux-setup · v2 | team-home (off = intro + discovery) |
| Add a computer | connect | 13 | agent-choice → editor · editor · Servers list (link) | profile-editor, v2-style steps, inline check |
| Switch server | connect | 5 | switcher sheet (via Servers) · Servers page | server-switcher-sheet |
| Disconnect or forget a server | connect | 3 | three doors, a detour through Servers | KitConfirmSheet in place |
| Sign in to a provider | connect | 7 | hub top · two code dialogs · two forget sheets | the provider's row in Providers |
| Start a conversation | converse | 5 | chat (three ways to start work on Work) | New conversation chooser → chat |
| Write a prompt | converse | 5 | composer · editor · context-capsule | composer + "+" sheet |
| Speak and hear | converse | 6 | sheet each turn · Advanced · setup first | composer voice mode, automatic model setup |
| Reuse or recover text | converse | 13 | three stores, two restore flows | Saved prompts, act + Undo |
| Queued messages | converse | 3 | chips · two withdraw sheets · Inbox | one "Waiting to send" bubble |
| Run a command | converse | 12 | dialog + new message (Library) vs inserted (chat) | redesigned command sheet, per-backend catalogs |
| Conversation actions | converse | 6 | session menu ≡ launcher; fork lands two ways | one Go to / Do menu |
| Share or export | converse | 6 | two share confirms, three unshare doors | one confirm; Copy link visible |
| Rename, archive, find | converse | 10 | swipe with Undo vs menu confirm; two archived lists | Undo always; search-first All conversations |
| Change the model | configure | 10 | sheet vs Settings screen (same view); two agent dialogs | model-picker-sheet (also for the default) |
| Sub-agents | converse | 5 | banner + relations vs family strip | family strip in chat and team |
| Continue on computer | converse | 2 | two flows, two commands | continue-on-computer-sheet |
| Find in a conversation | inspect | 5 | find bar · timeline search · history search | docked find bar |
| Where work runs | configure | 15 | chat in the copy vs a bare worktrees list; three create dialogs | New conversation chooser / "Move…" → chat |
| Open or switch project | connect | 12 | in place vs projects list; three choosers | workspace-context-sheet |
| Give the team a task | delegate | 8 | conversation · stays on home · board backlog | TeamConversation.start → team-conversation |
| Open a team task | delegate | 12 | conversation (Work, board) vs RunScreen (home, notification) | team-conversation; Task details sheet |
| Watch a worker | observe | 7 | chat watching vs raw output, chosen by door | chat (watching) renders both |
| Message the team or a worker | delegate | 4 | three places, three receipts | team-conversation composer |
| Stop a task or worker | delegate | 13 | 4 task confirms, 2 worker confirms; none in the conversation | conversation menu "Stop task"; one confirm |
| Reassign work | delegate | 5 | manual sheet · board · gate retry | automatic; manual fallbacks only |
| Outside agents | delegate | 5 | Servers + Settings; task typed twice | Library › Integrations › Outside agents |
| **Answer the agent** | approve | 19 | chat card · sheet over Inbox · gate-sheet | request card in its conversation |
| Stop being asked | approve | 6 | rules made in chat, managed in Settings | approvals sheet + Allowed actions |
| Merge a team task | approve | 2 | approve sheet + merge confirm; no diff | approve with receipt; one merge confirm |
| Review changes | review | 13 | review-workspace · diff-view · files-changes detour | review-workspace (one KitDiffView) |
| Undo from a prompt | review | 5 | immediate (OC1) vs staged (OC2), by door | stage-revert-sheet for every server |
| Tell the agent what to fix | review | 3 | comment can be lost; two discard guards | drafts into the composer |
| **See what needs me** | observe | 13 | Inbox (sheet) · Work (chat) · attention-overview · profile-monitor | Inbox → conversation at the card |
| See and stop what runs | observe | 8 | three conversation lists; two process lists | Work (conversations) · "Running on this phone" tool |
| Follow progress | observe | 5 | menu-only todos; three step looks | KitChecklist + one Now line |
| Read a file | inspect | 10 | two viewers, three row-action forms | file-preview-sheet (KitFileViewer) |
| Read a log | inspect | 7 | four looks, two sheets for one log | KitLogPanel |
| Technical details | inspect | 11 | five team folds; uncopyable errors | KitDetailsFold |
| Open a terminal | inspect | 3 | two new buttons, two key bars | Project › Terminal |
| Add an MCP, skill or plugin | configure | 6 | manual form only; two skill sheets | Add chooser: catalog / ask an agent / manual |
| Keep working in background | configure | 5 | two battery doors; team tips separate | keep-running |
| Appearance and display | configure | 4 | picker sheet; toggles three ways | inline controls in Settings |
| Find a setting | configure | 1 | consistent | same (plus a configuration assistant later) |
| Privacy and licences | learn | 6 | two privacy pages, two licence pages | Privacy and data · About › Open source |
| Usage and quota | account | 8 | hub vs agent-account; two threshold systems | usage-hub Spent / Remaining |
| **Server stops answering** | recover | 9 | 2 implementations, 3 wordings, raw-error sheet, 3 restart confirms | one status source → root-connecting |
| **Report a problem** | recover | 5 | GitHub (version only) vs own server log | app-diagnostics "Report a problem", prefilled |
| Learn, try, stay current | learn | 4 | guide names differ; notices cover actions | demo · guide · one update line |

## Journey graph (main flow per journey type)

- **install:** Welcome or Servers › This phone → `phone-setup-start` → (Customize) → `phone-setup-progress` → `phone-setup-ready` → first conversation. Add tools: This phone → Customize (add) → progress → ready.
- **connect:** Welcome › On my computer → `profile-editor` (kind → address or pairing → check) → Work. Switch: header → `server-switcher-sheet`. Sign in: Providers row (also from a chat error).
- **converse:** Work › New conversation (Solo) → `chat` → composer ("+", "/", mic) → turn → needs you (approve) → finished → Changes (review).
- **delegate:** Work › New conversation (Team) → give-a-task sheet → `team-conversation` (pending → Now line → steps → workers in the family strip → gate cards → merge). The board is the backlog and planning view; the team page is overview and configuration.
- **approve:** request card in its conversation → answer in place, or Details → one sheet → receipt. From the Inbox or a notification → the conversation at the card.
- **review:** Changes (chat, Project, run result, request, merge) → `review-workspace` → Comment → composer; or Undo from here → `stage-revert-sheet` → `staged-revert`.
- **observe:**
  - Inbox covers what needs me and what finished, on every server.
  - Work covers what I am working on.
  - Server rows carry a status word.
  - Notifications → Inbox → conversation.
- **inspect:** Project tab → Files → `file-preview-sheet` · Terminal · Details folds · KitLogPanel.
- **configure:**
  - Settings (search) → page.
  - In a conversation: the model sheet, approvals and commands, which set values for that conversation only.
  - Library: Providers · MCP · plugins · commands.
- **recover:**
  - Status line → after 8 s, `root-connecting`'s diagnosed card → Try again / Restart / Switch server.
  - Error state → Try again / Report a problem.
  - Failed install row → resume.
- **account:** Settings › Usage → Spent | Remaining; a quota alert → Remaining.
- **learn:** Welcome → demo; guide; team intro; `server-capabilities` ("why is X missing" → how to get it).

## Where journeys intersect, and who owns the moment

| Intersection | Where | Rule |
|---|---|---|
| install ↔ connect | servers, servers-welcome, profile-editor, root-connecting, phone-setup-ready | Servers is grouped by where the agent runs. Connect owns listing, switching and adding a computer. The This phone row hands off to phone setup v2, whose ready page hands back ("Switch to this phone"). Adding a computer never installs. |
| converse ↔ delegate | workspace, chat, team-conversation, team-home | New conversation owns the start; Team is a mode of it. A team task is a chat-page conversation. The team page never starts or follows work. |
| approve ↔ converse | chat and its cards, permission, question and form sheets | The card in the conversation owns the answer. Sheets open only from Details and return to the card with a receipt. |
| approve ↔ observe | activity, workspace, profile-monitor, notifications | Observe points, it does not answer. Every list row deep-links to the card, switching server first. |
| approve ↔ delegate | team-conversation, team-home, gate-sheet, merge section | Gates are the same KitRequestCard and KitReceipt. The team home lists and links. The supervision level decides which gates reach the person. |
| observe ↔ observe | Work, Inbox, attention-overview, profile-monitor, switcher, running-work-sheet | Inbox owns "needs me / finished" and Work owns "working on". attention-overview is deleted; profile-monitor folds into server rows. |
| install ↔ delegate | team-intro, phone-setup-customize-sheet, team-home, team-host-sheet | Delegate owns discovery. Install owns the phone team (a v2 component). Connect owns a computer's team. All paths hand back to "Give the team a first task". |
| review ↔ approve | permission sheet, merge section, merge changes, staged-revert | Approve owns the decision; review supplies a read-only KitDiffView. |
| review ↔ recover | revert sheets, staged-revert | Undo is one review flow; recover surfaces link to it. |
| converse ↔ recover | queued strip, draft sheets, chat, activity | The conversation owns its queue and drafts (undo-first). The Inbox does not list the offline queue. |
| observe ↔ inspect | termux-processes, development-services, running-work-sheet, terminal | Work owns running conversations. The "Running on this phone" tool owns processes. The Project tab owns dev commands. |
| configure ↔ converse | model picker, catalog, approvals, display toggles, launcher | Changes inside a conversation apply to that conversation; Settings sets defaults. Both open the same component. |
| account ↔ connect | integrations, command-auth, agent-account, usage-hub | Connect owns sign-in; account owns the numbers. agent-account becomes the Codex quota source. |
| recover ↔ learn | error states, app-diagnostics, about, settings | The error state owns the moment. Its "Report a problem" is prefilled with that error. |
| configure ↔ install | termux-setup-installed, server-settings, host-management | The phone's own server is configured on This phone; changes that need software run as v2 jobs. |
| delegate ↔ inspect | team-agent, team-agent-output, cycle strip, gate-sheet | The worker's conversation owns "what is it doing"; raw output is only its fallback rendering. |

## Patterns that must be one component everywhere

| Pattern | Target |
|---|---|
| Answering the agent | **KitRequestCard family.** Answer in place for the common case (Allow once / Reject; an option sends with Undo). Details opens one KitRequestSheet. The answer shows a KitReceipt, and the work line says "Waiting for you". |
| Confirmations | **KitConfirmSheet** (78 elements ask for it). Its title is a question naming the thing. Error tone only when destructive; typed-name guard for heavy deletes. "Keep running" is the cancel word for stops. |
| Undo vs confirm | Reversible or restorable acts happen at once with a KitUndoSnackbar. Irreversible or server-destructive acts are confirmed. The same act gets the same model from every door. |
| Technical details | **KitDetailsFold**, collapsed, with mono values, copy per value and values deduplicated. Engine words only live here. |
| Logs | **KitLogPanel**: follows the newest line, copies, and sits folded under Details. |
| "Needs you" markers | One attention source per request, shown as a mark plus the word "Needs you" and counted once. The tab badge, rows, server rows, the header and the notification all use the same words. |
| Receipts | **KitReceipt** for every write the phone sends. It replaces both `TeamReceiptChip` classes and the gate sheet's `_Receipt`. |
| Status and waiting | **KitStatusLine** from one connection source, with fixed stages and an 8 s escape. **KitNowLine** for team work. |
| Install progress | The v2 **KitChecklist** (staged marks, bar, time left, Stop, resume, person-step rows). |
| Viewers | **KitFileViewer** and **KitDiffView** (scoped or read-only). |
| Choices, discards, errors, short input | KitChoiceRow · KitDiscardGuard (drafts survive) · KitStateView with Report a problem · KitInputDialog. |

## Top 15 journey fixes

| # | Fix | Personas | Effort | Main pages |
|---|---|---|---|---|
| 1 | Answer the agent in one place with one card | remote-lead, team-delegator, phone-only, newcomer | L | chat cards, permission, question, form and gate sheets, activity, workspace, team-conversation |
| 2 | A team task is one page: every door opens the conversation, which can stop the task | team-delegator, remote-lead | M (routing is S) | team-home, team-run (+ its tabs), team-conversation, team-board, start-run-sheet |
| 3 | Unify all installation into phone setup v2 | phone-only, newcomer, tinkerer | L | phone-setup-*, termux-setup-*, builtin-server-setup, local-agent-page, team-phone-onboarding-* |
| 4 | The Inbox is the only "needs me" list; delete attention-overview | remote-lead, tinkerer, team-delegator | M | activity, workspace, attention-overview, profile-monitor, server-switcher-sheet |
| 5 | One connection status and a diagnosed failure view | phone-only, remote-lead, newcomer | M | home-shell, connection banner and details sheet, root-connecting, bootstrap-gate |
| 6 | Report a problem from any error, with diagnostics attached | all | M | app-diagnostics, embedded-product-states, chat, settings, about |
| 7 | Turn the team on from one team page with automatic discovery | team-delegator, newcomer | M | team-intro, team-home, team-plugin-sheet, plugins-settings, discovery and reoffer cards |
| 8 | Add a computer in one path | remote-lead, newcomer | M | servers, servers-welcome, agent-choice, profile-editor, connection-help, session-link banner |
| 9 | Queued messages as one bubble; drafts and saved prompts undo-first | phone-only, remote-lead | M | pending-sends strip, queued-draft sheets, prompt-stash, legacy-drafts |
| 10 | One "Undo from here" flow and one diff component | remote-lead, tinkerer | L | revert sheets, staged-revert, review-workspace, diff-view, files-changes-sheet |
| 11 | KitConfirmSheet and the undo-vs-confirm rule, app-wide | all | M | confirm-sheet and its ~10 off-pattern dialogs and sheets |
| 12 | Watching a worker means its conversation; message it there | team-delegator | M | team-agent, team-agent-output, team-agent-message-sheet, cycle strip |
| 13 | Command sheet redesign with per-backend catalogs; session menu becomes Go to / Do | tinkerer, remote-lead | M | command-launcher-sheet, session-menu-sheet, commands, plugins-mapping-dialog |
| 14 | Voice as a composer mode, with automatic model setup and no 30 s cap | phone-only, remote-lead | L | voice controls, voice-composer-sheet, voice-model-setup-sheet |
| 15 | Start all work from New conversation, always ending in a conversation | newcomer, team-delegator, tinkerer | M | workspace, isolated-task-sheet, worktrees, managed-workspaces, session-destination-sheet |

**Quick wins inside the list.** Each is a small routing change, not a redesign.

- **#2:** pass `TeamConversation.open` as `onOpenRun`, route the team notification link to the conversation, and make team-home's start call `TeamConversation.start`.
- **#7:** make Settings › AI Team open the team page.
- **#4:** delete `attention-overview`.
