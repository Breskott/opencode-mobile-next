# Target information architecture (2026-09-26)

Phase 3 of the UX system programme. It turns the Phase 1 map (`map/all.json`, 356 page records), the Phase 2 synthesis (`journeys`, `capabilities`, `personas-verticals`) and the owner's 167 verdicts into one target app. The owner's notes outrank everything else. Delivery is in [`programmes.json`](programmes.json): eleven programmes, approved one at a time.

**Result:** the same four-tab dock, **356 → 264 pages**. 22 pages are removed, 78 merge into another page and 8 are new. There is one installer, one "Needs you" list, one answer card and one "Report a problem" page. The Settings hub goes from 33 rows to 22.

## 1. The target app map

### 1.1 Top level

| Place | What lives there | Never here |
|---|---|---|
| **Header** (shell, every tab) | Project · server name, plus one status word: *Working*, *Needs you*, *Not answering*. Tapping it opens `server-switcher-sheet`, which gives every server its status word. Under the header sits **one** prioritised `KitStatusLine`, owned by the shell. Priority order: connection → Android stopped the app → heat → update ready. | stacked banners; a second connection indicator |
| **Dock tab 1: Work** (`workspace`) | This project's work: one **New conversation** button, whose chooser offers Solo · Team · In a separate copy · On a cloud machine and remembers the choice per server. Below it, this project's conversations with team tasks marked, each with a state line ("Working · 2 of 5 steps · 3 min"). Then one "N need you" line that opens the Inbox, and the quiet AI Team door until the team is first used. Also here: *All conversations* (search-first, Archived filter) and *Import conversation* (moved from Settings). | a second requests list; a team card; three ways to start |
| **Dock tab 2: Inbox** (`activity`) | **The one "Needs you" list**: every server and every team gate, oldest first, each item naming its server. Below it, *While you were away*: finished work and every automatic act, with Undo where possible. Other servers are grouped rows (`embedded-profile-monitor-inbox`). | settings; the offline send queue (that stays in its conversation) |
| **Dock tab 3: Project** (`project-hub`), on servers with project tools only | Files, Changes (`review-workspace`), Terminal, Dev services, Health, Worktrees, Cloud machines. On Codex or Paseo the tab is absent, and Work's project line says so once: "Files aren't available on Codex · Why". | — |
| **Dock tab 4: Settings** (`settings`) | The Settings hub (§1.3). The Library (providers, MCP, commands, skills, plugins, outside agents) lives here, under *Agent*. | four-layer depth; duplicate rows |
| **Pushed places** | **Conversation**: the chat page for solo chats, team tasks and a worker being watched. **This phone.** **Team page.** **Servers.** **Report a problem.** | a separate "AI Team world" |

The AI Team is not a tab. It is reached from a team conversation's header, from Settings › Agent › AI Team and from the Work door (`docs/design/team-conversation-2026-09-26.md`).

### 1.2 The four "one place" answers

| One… | Lives at | Every other door |
|---|---|---|
| **Installer** | Phone setup v2: `phone-setup-start` (pre-flight: CPU, free space, RAM) → `phone-setup-customize-sheet` (first setup, or *Add tools*; the host, in-app or Termux, is chosen here) → `phone-setup-progress` (KitChecklist; person-step rows; resume) → `phone-setup-ready`. Afterwards everything is managed on **This phone** (`termux-setup-installed` reshaped, host-neutral). | These all hand off to v2 and land on the same ready page: Welcome › On this phone, Servers › This phone, Settings › This phone, root-connecting (phone stopped), team page › On this phone, Solo · Team (team missing on the phone), the Terminal's phone source, and search › Claude Code. All 10 `/termux-setup` call sites and `builtin-server-setup` (`main.dart:1636`) go. |
| **"Needs you" list** | Inbox (`activity`). Each row opens **the conversation, scrolled to the card**. For another server, it switches server first (`profile-monitor-switch-server-dialog`). | Work shows one line; the header and server rows show a status word; the tab badge counts each request once; a notification lands where an Inbox row does. `attention-overview` is deleted and `profile-monitor` folds into the server rows. |
| **Answer card** | A `KitRequestCard` in its conversation (chat or team) answers the common case in place: Allow once / Reject, an option sent with Undo, or "Something else". *Details* opens one `KitRequestSheet`, with permission, question, form and gate as its variants. A `KitReceipt` follows every answer, and the work line says "Waiting for you". | Inbox, notifications and team rows point to the card; they never answer it themselves. |
| **Report a problem** | `app-diagnostics`, redesigned as *Report a problem*. It opens prefilled with the error that brought the person there plus the recent diagnostics (persisted and redacted). The person can preview what is sent, then send it as a GitHub issue (through `openExternalLink`) or copy or share it. | Settings › Help, About, and **every** error state: the `KitStateView`/`KitNotice` error tone offers "Report this" through `openReportProblem(context, error:)`. Network errors offer a fix instead of a report. |

### 1.3 Settings IA (22 rows, at most 5 per group, at most hub → page → sheet)

At the top are one `KitSearchField` covering every setting (including rows inside pages, with typo tolerance, arriving on the row with a highlight), the row **Ask the setup assistant**, and one status line.

| Group | Rows (target page) |
|---|---|
| — | 1 **Ask the setup assistant**: a conversation with a configuration agent. It is also offered when a search finds nothing. |
| Server | 2 This server (`server-settings`: status, restart, update, Disconnect) · 3 Servers (`servers`: saved servers, pairing, Tailscale) · 4 This phone (Android only; opens `phone-setup-start` until the phone is set up) |
| Agent | 5 Model (`model-picker-sheet`, default mode; the catalog is inside) · 6 Providers and accounts (`integrations` › Providers; the Codex account on Codex) · 7 Tools (`capabilities` renamed: MCP, Commands, Skills, Plugins, Outside agents, Tools and references) · 8 AI Team (`team-home`; the intro state when off) |
| Conversations | 9 What runs by itself (new `automation-settings`: supervision, auto-approve, housekeeping consents, background monitoring; *Always allowed actions* is inside it) · 10 Show reasoning (switch) · 11 Show timestamps and usage (switch) · 12 Default shell (hidden when there is only one shell) · 13 Voice (packs, voices) |
| This app | 14 Notifications (only "what notifies me"; a denied state; a test notification) · 15 Keep running (background, Android's daily limit, battery, heat) · 16 Appearance (inline Auto/Light/Dark, Effects, Language) · 17 Privacy and data (sizes of local data, policy; About's Privacy tab merges here) · 18 Usage (Spent · Remaining) |
| Help | 19 Setup guide · 20 Report a problem · 21 Available on this server (missing features first, each with "How to get it") · 22 About (version, Open source including the voice licences, Show tips again, keyboard shortcuts on desktop) |

Removed from the hub:
- the separate Plugins, MCP, Commands and External agents rows (now inside Tools);
- Report a bug and App diagnostics as two rows (now one);
- the second privacy row and the second notices row;
- Transcript display (now two switches);
- Import conversation (moved to Work).

Rows a server cannot serve still stay off the hub. Instead, the group shows one muted line: "N settings need a newer server · Why".

### 1.4 Page list after merges and removals

**Removed (22).** Their jobs go to:
- `attention-overview` → Inbox.
- `embedded-return-brief-panel` and its status dialog → Inbox › While you were away.
- `embedded-info-label` and `info-label-sheet` → a tooltip on the term (owner: "Kill … or show tool tip").
- `context-capsule` → the composer (owner: "users can dump all this into the input box").
- `plugins-mapping-dialog` and `plugins-clear-mappings-sheet` → the command sheet's per-backend catalogs.
- `embedded-session-inventory-footer` → lists that page themselves.
- `embedded-team-card` → team rows on Work.
- `embedded-team-phone-reoffer-card` → the team page's off state.
- `embedded-managed-server-health` → This phone.
- `team-agent-reassign-sheet` → automatic dispatch (owner: "Why manual").
- `team-merge-approve-sheet` → approve with a receipt.
- `appearance-picker-sheet` → inline segmented control.
- `workspace-archive-session-sheet` → archive with Undo.
- `chat-pending-photo-sheet` → recovered photos attach to their own draft (owner: "you decide").
- `chat-stash-restore-confirm-sheet` and `prompt-stash-delete-sheet` → act, then Undo.
- `termux-setup-start-installed-sheet` and `termux-setup-unchecked-install-sheet` → v2 check scripts.
- `builtin-server-remove-confirm-sheet` → the new host-neutral `remove-from-phone-sheet`.

**Merged (78), grouped by the page that takes the job:**

| Target | Merged in |
|---|---|
| `phone-setup-start` | builtin-server-setup, termux-setup-unsupported (pre-flight state) |
| `phone-setup-customize-sheet` | termux-setup-choose, team-phone-onboarding-offer |
| `phone-setup-progress` | termux-setup-installing, -checking, -get-termux, -connect-termux, -failed, -update-sheet, embedded-local-agent-onboarding-block, team-phone-onboarding-steps, team-phone-onboarding-failed |
| `phone-setup-ready` | termux-setup-connected, team-phone-onboarding-success |
| This phone (`termux-setup-installed`) | termux-setup |
| `phone-component-sheet` (new) | local-agent-page |
| `keep-running` | team-phone-tips-sheet |
| `workspace-folder-chooser` · `project-folder-open-dialog` | team-phone-onboarding-project-sheet · local-agent-project-sheet |
| `team-home` | team-home-runs-tab, -agents-tab, -needs-you-tab, team-plugin-sheet, embedded-team-phone-section, team-phone-onboarding-killed, team-intro (off state) |
| `team-conversation` | team-run, team-run-overview-tab, -work-tab, -agents-tab, -timeline-tab, embedded-team-planning-card, team-agent-message-sheet, team-cycle-how-sheet, embedded-team-cycle-strip (Now line) |
| `chat` (watching) · `team-agent` · `team-agent-stop-confirm-sheet` · `start-run-sheet` | team-agent-output · team-agent-details-sheet · team-cycle-stop-confirm-sheet · team-board-add-sheet |
| `review-workspace` · `stage-revert-sheet` · `file-preview-sheet` · `files` | diff-view, files-changes-sheet · chat-revert-confirm-sheet · files-file-viewer-sheet · files-row-actions-sheet |
| `profile-editor` · `servers` · `root-connecting` · `activity` | agent-choice, connection-help · profile-monitor · connection-status-details-sheet · embedded-completion-digest-card |
| `model-picker-sheet` | catalog (default mode), model-picker-sheet-agent-dialog, -options-dialog, -unloaded-providers-dialog |
| `prompt-stash-sheet` | legacy-drafts, legacy-drafts-review-sheet, legacy-drafts-delete-sheet (one-shot migration) |
| `embedded-composer` (voice mode) · `embedded-message-view` | voice-composer-sheet, embedded-voice-conversation-controls · todos-sheet |
| `capabilities` (Tools) | plugins-settings, external-agents |
| `settings` · `privacy-settings` · `about-open-source-tab` | settings-transcript-display-sheet · about-privacy-tab · voice-notices |
| `global-sessions` · `project-hub` · `session-context` · `workspace-context-sheet` | workspace-archived-sheet · manage-project · workspace-session-details-sheet · workspace-directory-details-dialog |
| `confirm-sheet` (→ KitConfirmSheet) | question-sheet-dismiss-dialog, shell-output-stop-dialog |
| small pairs | session-handoff-dialog → continue-on-computer-sheet; chat-message-error-details-dialog → chat-prompt-error-details-dialog; integrations-oauth-code-dialog → integrations-mcp-oauth-code-dialog; integrations-forget-uncertain-auth-sheet → integrations-forget-pending-auth-sheet; command-auth-sheet-confirm-sheet → command-auth-sheet; skills-preview-sheet → skill-activation-sheet; provider-quota-enroll-dialog → provider-quota |

*Refinement over `journeys.json`:* `external-agents` goes to Tools, not `integrations`. `integrations` keeps only Providers, so each Settings row opens one thing. `legacy-drafts-delete-sheet` goes to `prompt-stash-sheet`, where deleting now means Undo, because `prompt-stash-delete-sheet` itself is removed.

**New (8):**
- `new-conversation-sheet`: Solo · Team · separate copy · cloud.
- `phone-component-sheet`: status, sign-in, version, update and remove for Claude Code, AI Team, Python, and so on.
- `remove-from-phone-sheet`: "Keep my projects" is the default.
- `mcp-add-sheet`: Browse · Ask the setup assistant · Enter manually.
- `mcp-catalog`: registry servers as toggles.
- `embedded-config-change-card`: the assistant's proposed change, shown as a diff, with Apply and a receipt.
- `report-problem-preview-sheet`.
- `automation-settings`: "What runs by itself".

**Surviving (256 + 8 new = 264), by where they live:**
- *Shell and system:* home-shell, root-connecting, bootstrap-gate, server-switcher-sheet, embedded-connection-status-banner (becomes the shell status line), share-session-failed-banner, session-link-server-missing-banner (redesigned as a prefilled "Add this server?" sheet), desktop-release-notice, shorebird-update-notice, system, global-shortcuts, command-palette-dialog, shortcuts-help-dialog, embedded-context-menu-region, embedded-desktop-file-drop-target, file-drop-failed-dialog, confirm-sheet, external-link-dialog, embedded-product-states, demo.
- *Work:* workspace, workspace-folder-chooser, workspace-context-sheet, workspace-rename-session-dialog, workspace-share-session-sheet, workspace-delete-session-sheet, global-sessions, global-sessions-continue-here-sheet, isolated-task-sheet, projects, projects-rename-dialog, project-folder-new-dialog, project-folder-open-dialog, project-folder-browser, running-work-sheet, session-import, session-import-destination-sheet, embedded-team-discover, embedded-mobile-task-list, new-conversation-sheet.
- *Inbox:* activity, embedded-profile-monitor-inbox, profile-monitor-switch-server-dialog, question-sheet.
- *Project:* project-hub, files, file-preview-sheet, embedded-file-preview-body, review-workspace, review-comment-sheet, stage-revert-sheet, staged-revert, staged-revert-confirm-sheet, terminal, terminal-surface, terminal-rename-dialog, terminal-remove-sheet, development-services and its confirm, logs and editor sheets, project-health, project-health-git-init-dialog, worktrees and its reset, create and remove dialogs, managed-workspaces and its create and remove dialogs, shell-output, shell-output-timeout-sheet, run-command-dialog.
- *Conversation:*
  - chat, embedded-composer, prompt-tools-sheet, prompt-editor, prompt-editor-discard-sheet, prompt-history-sheet, prompt-stash-sheet;
  - the chat draft, stash and queue sheets (draft-attachment-recovery, stash-attachments-unavailable, discard/resend-queued-draft, cancel-inbox-send, share-confirm, leave-unsaved-draft);
  - embedded-pending-sends-strip (becomes the "Waiting to send" bubble), embedded-prompt-error-banner, chat-prompt-error-details-dialog, embedded-message-view, embedded-markdown-text, markdown-code-reader, embedded-tool-card, embedded-subagent-context-banner, embedded-shared-session-banner, embedded-chat-nudge-slot, embedded-transcript-find-bar, embedded-model-shortcuts, embedded-transcript-display-toggles;
  - session-menu-sheet, command-launcher-sheet, chat-message-actions-sheet, chat-delete-message-sheet, chat-run-shell-dialog, chat-rename-session-dialog, timeline-sheet;
  - request pages: embedded-permission-attention-card, embedded-question-attention-card, embedded-question-options, permission-sheet, permission-sheet-always-dialog, form-sheet, form-sheet-dismiss-confirm-sheet, form-sheet-date-picker, session-approvals-sheet, embedded-auto-approval-indicator, embedded-config-change-card;
  - chat-read-aloud-consent-sheet, chat-read-aloud-voice-sheet, model-picker-sheet, web-sources;
  - session pages: session-context, active-context, active-context-message, session-relations, session-export, session-note, session-note-discard-dialog, run-result, run-result-output-sheet, continue-on-computer-sheet, continue-on-phone-sheet, session-destination-sheet, session-destination-confirm-dialog.
- *Team:* team-home, team-conversation, team-board, team-board-move-sheet, team-board-priority-sheet, team-board-cancel-confirm-sheet, start-run-sheet, team-run-details-sheet (becomes Task details), team-run-cancel-confirm-sheet (becomes "Stop this task?"), team-agents, team-agent, team-agent-stop-confirm-sheet, team-agent-restart-confirm-sheet, embedded-team-receipt-chip (becomes KitReceipt), gate-sheet, gate-sheet-confirm-sheet, embedded-team-merge-section, team-merge-confirm-sheet, team-merge-changes-sheet, work-sheet, embedded-work-graph, team-host-sheet, team-host-guide-sheet, team-host-details-sheet, team-turn-off-sheet, embedded-team-discovery-card, embedded-team-technical-value, team-phone-stop-sheet, team-phone-remove-sheet.
- *Servers and This phone:*
  - servers, servers-welcome, servers-remove-server-sheet, profile-editor, profile-editor-discard-sheet, pairing-scanner, tailscale-setup, host-management, server-settings, server-settings-restart-dialog, server-settings-upgrade-sheet;
  - phone-setup-start, phone-setup-customize-sheet, phone-setup-progress, phone-setup-progress-stop-sheet, phone-setup-ready;
  - termux-setup-installed (This phone), termux-setup-switch-runtime-sheet, termux-setup-restart-sheet, termux-setup-replace-installed-sheet, phone-component-sheet, remove-from-phone-sheet, builtin-server-log-sheet, termux-storage, termux-storage-clean-sheet;
  - termux-processes (becomes *Running on this phone*) and its stop-one, stop-group and details sheets;
  - embedded-setup-terminal, embedded-termux-attention-line, embedded-termux-running-server-entry, embedded-local-agent-server-entry, stop-local-agents-confirm-sheet, restart-local-agents-sheet, remove-local-agents-confirm-sheet.
- *Settings and Library:*
  - settings, settings-disconnect-sheet, automation-settings, saved-permissions, saved-permissions-revoke-dialog, coding-settings-shell-sheet, voice-model-setup-sheet, voice-model-setup-sheet-delete-dialog;
  - notifications-settings, notifications-settings-quiet-time-dialog, keep-running, appearance-settings, theme-pack-preview-sheet, language-sheet, privacy-settings, privacy-settings-clear-queued-sheet, privacy-settings-clear-drafts-sheet;
  - usage-hub, usage, usage-budget-dialog, usage-budget-clear-dialog, provider-quota, provider-quota-clear-dialog, agent-account;
  - guide, app-diagnostics (becomes *Report a problem*), app-diagnostics-clear-sheet, report-problem-preview-sheet, server-capabilities, about, about-open-source-tab, console-organization-sheet, console-organization-switch-dialog;
  - capabilities (Tools), integrations and its provider and MCP sheets and dialogs (remove-mcp, authorization-launch, disconnect-provider, connect-method, connect-key, forget-pending-auth, oauth-inputs, mcp-oauth-code), command-auth-sheet, credential-management-sheet and its remove and rename, mcp-setup, mcp-add-sheet, mcp-catalog, commands, skills, skill-activation-sheet, tools, tools-detail-sheet, references;
  - add-agent, external-agent-detail, external-agent-detail-input-dialog, external-agent-detail-delete-sheet, external-agents-delete-sheet, external-task, external-task-cancel-sheet, external-task-forget-sheet.

## 2. Canonical path for each job

"→" means the person lands there. Every other door listed in `journeys.json` either is removed or is re-pointed to the same landing.

| # | Job | Entry points | Lands on |
|---|---|---|---|
| 1 | Set up this phone | Welcome › On this phone; Servers/Settings › This phone; root-connecting › Start | phone-setup-start → progress → ready → first conversation |
| 2 | Add a tool to this phone | This phone › Add tools; team page › On this phone; Solo · Team (missing); Terminal › This phone | customize (add mode) → progress → ready ("Give the team a first task" / "Start Claude Code") |
| 3 | Manage the phone's agent | Servers › This phone; switcher › phone row menu | This phone; every change runs as a v2 job |
| 4 | Turn the AI Team on | Settings › AI Team; team header; Work door; Solo · Team | team-home (off state = intro + automatic discovery) |
| 5 | Add a computer | Servers › Add a computer; Welcome › On my computer; switcher › Add; pairing link | profile-editor steps (kind → address or pairing → check → ready) |
| 6 | Switch server | header; root-connecting › Switch server | server-switcher-sheet |
| 7 | Disconnect or forget a server | Servers row menu; switcher row menu | KitConfirmSheet in place; it names what is lost |
| 8 | Sign in to a provider | Settings › Providers; chat auth error; model picker row; composer "Sign in to a model" | integrations › the provider's row |
| 9 | Start a conversation | Work › New conversation; launcher; `/new` | new-conversation-sheet → chat (or team-conversation) |
| 10 | Write a prompt | composer; "+"; expand | chat |
| 11 | Speak and hear | composer mic | composer voice mode (automatic pack setup) |
| 12 | Reuse or recover text | "+" › Saved prompts; history | composer; act, then Undo |
| 13 | Queued messages | "Waiting to send" bubble | chat |
| 14 | Run a command | composer "/"; Settings › Tools › Commands | command-launcher-sheet (per-backend catalog) |
| 15 | Conversation actions | title menu; long-press | session-menu-sheet (Go to / Do) |
| 16 | Share or export | menu › Share; Work row menu | one KitConfirmSheet → link copied |
| 17 | Rename, archive, find | row menu = title menu; search | global-sessions; archive with Undo |
| 18 | Change the model | model chip; chat error; Settings › Model | model-picker-sheet |
| 19 | Sub-agents | sub-agent card; family strip | chat (the child conversation) |
| 20 | Continue on the computer | menu › Continue on computer | continue-on-computer-sheet |
| 21 | Find in a conversation | menu › Find; timeline search | find bar docked above the composer |
| 22 | Where work runs | new-conversation-sheet; menu › Move… | chat in the new place |
| 23 | Open or switch project | header project name | workspace-context-sheet |
| 24 | Give the team a task | New conversation › Team; team-home › Give a task; board "+" (Keep in backlog) | `TeamConversation.start` → team-conversation (or the backlog, with a receipt) |
| 25 | Open a team task | Work row; board card; team-home row; notification | team-conversation (Task details in its menu) |
| 26 | Watch a worker | family strip; team-agents row | chat, watching mode |
| 27 | Message the team or a worker | team-conversation composer | team-conversation, with a receipt |
| 28 | Stop a task or worker | conversation menu › Stop task; strip › worker menu | KitConfirmSheet ("Keep running" as the cancel) → receipt |
| 29 | Reassign work | *automatic*; board › Start now; gate › Retry | team-conversation, with a receipt |
| 30 | Outside agents | Settings › Tools › Outside agents | external-task |
| 31 | Answer the agent | card; Inbox row; Work line; notification; other-server row | the conversation, scrolled to the KitRequestCard |
| 32 | Stop being asked | request › Always allow; auto-approval line; Settings › What runs by itself | session-approvals-sheet (this conversation) or saved-permissions (everywhere) |
| 33 | Merge a team task | the conversation's merge section | team-conversation, with a receipt (automatic on green under Balanced or Autonomous) |
| 34 | Review changes | chat › Changes; Project › Changes; run-result; request › See the change; merge › Review | review-workspace (KitDiffView) |
| 35 | Undo from a prompt | long-press › Undo from here; menu | stage-revert-sheet (every server) |
| 36 | Tell the agent what to fix | review › Comment | composer draft |
| 37 | See what needs me | Inbox tab; notification; Work line; header word | Inbox → the conversation at the card |
| 38 | See and stop what runs | Work › Running; This phone › Running now; attention line | chat (conversations) or Running on this phone (processes) |
| 39 | Follow progress | transcript | KitChecklist + one Now line |
| 40 | Read a file | Files row; path link; tool card | file-preview-sheet |
| 41 | Read a log | any Details fold; This phone › Server log | KitLogPanel |
| 42 | Technical details | end of the page › Details | KitDetailsFold in place |
| 43 | Open a terminal | Project › Terminal | terminal-surface |
| 44 | Add an MCP, skill or plugin | Settings › Tools › MCP › Add; the assistant | mcp-add-sheet → catalog / assistant / mcp-setup |
| 45 | Keep working in the background | every background hint; Settings › Keep running | keep-running |
| 46 | Appearance and display | Settings › Appearance; Conversations switches | inline controls |
| 47 | Find a setting | Settings search; command palette; no result → assistant | the page, scrolled to the row |
| 48 | Privacy and licences | Settings › Privacy and data; About | privacy-settings · about › Open source |
| 49 | Usage and quota | Settings › Usage; quota alert | usage-hub, Spent · Remaining |
| 50 | Server stops answering | every status line; root-connecting | the status line, then after 8 s root-connecting's diagnosed card |
| 51 | Report a problem | every error state; Settings › Help; About | Report a problem, prefilled |
| 52 | Learn, try, stay current | Welcome › Try it offline; Settings › Setup guide; update line | demo · guide · one "Update ready · Restart" line |

### Intersection rules (who owns the moment)

1. **install ↔ connect.** Servers is grouped by where the agent runs. Adding a computer never installs anything. The This phone row hands off to v2, and v2's ready page hands back ("Switch to this phone").
2. **converse ↔ delegate.** New conversation owns the start, and Team is a mode of it. A team task is a conversation. The team page never starts or follows work.
3. **approve ↔ converse.** The card in the conversation owns the answer. A sheet opens only from Details and returns to the card with a receipt.
4. **approve ↔ observe.** Observe surfaces point; they never answer. Every row deep-links to the card, switching server first.
5. **approve ↔ delegate.** Team gates use the same KitRequestCard and KitReceipt. Supervision decides which gates reach the person.
6. **observe ↔ observe.** The Inbox owns "needs me" and "finished". Work owns "working on". Server rows carry a word.
7. **install ↔ delegate.** Delegate owns discovery. Install owns the phone team, which is a v2 component. Connect owns a computer's team. Every path ends on "Give the team a first task".
8. **review ↔ approve.** Approve owns the decision. Review supplies a read-only KitDiffView.
9. **review ↔ recover.** Undo is one review flow, and recover surfaces link to it.
10. **converse ↔ recover.** The conversation owns its queue and drafts (Undo first). The Inbox never lists the offline queue.
11. **observe ↔ inspect.** Work owns running conversations, *Running on this phone* owns processes, and Project owns dev commands.
12. **configure ↔ converse.** A change made inside a conversation applies to that conversation, while Settings sets the defaults. Both open the same component.
13. **account ↔ connect.** Connect owns sign-in, and account owns the numbers.
14. **recover ↔ learn.** The error state owns the moment. Its Report is prefilled with that error.
15. **configure ↔ install.** Anything that needs software runs as a v2 job from This phone.
16. **delegate ↔ inspect.** The worker's conversation owns "what is it doing". Raw output is only the fallback rendering.
17. **configure ↔ automate** (new). A setting the assistant changes shows as a change card in its conversation, is applied only on approval, and afterwards shows in the Settings row's supporting line.

## 3. What each persona sees first (no modes)

There is no simple/expert switch and no persona picker. The same screens serve everyone. Context comes from `ServerCapabilities` and the host kind. Detail unfolds in three steps: summary → Details fold → technical page.

| Persona | First screen and defaults | Unfolds when needed |
|---|---|---|
| **newcomer** | Welcome with one question: *On this phone* · *On my computer* · *Try it offline*. Setup ends in a project that already exists ("my-app") and a preselected model. Before the first send, the model chip reads "Sign in to a model". Work shows one button and one empty state. | The AI Team door appears only after a first finished conversation. Terms explain themselves in tooltips. Settings opens with search and the assistant at the top. |
| **phone-only** | This phone is first in Servers and the switcher. The header word says why the phone server stopped, and it restarts by itself. Every install shows its cost first (MB, time, heat, processes). After Android kills the app, the next open explains it in one line. | *Running on this phone* (processes, a budget of 32), Storage, the server log under Details, Add tools. |
| **remote-lead** | Opens where something waits: a notification or an Inbox row goes to the card, which is answered in one tap. The header shows project · server · *Working 2 min / Needs you / Done*. The switcher gives every server its word. | While you were away; the reconnect countdown; diagnosed failures; "Always allow" after the third identical ask. |
| **team-delegator** | New conversation remembers *Team* for this server. Work lists team tasks with a Now line. The person is asked only at the gates their supervision level reserves. | Task details, workers in the family strip, the team page (where it runs, cost, speed), engine words only under Details. |
| **tinkerer** | The same defaults as everyone. | Row menus hold the manual levers next to what automation already did; values are copyable mono values under Details; the command palette and shortcuts; Tools; Available on this server; Report a problem with diagnostics. |
| **cross-cutting** | Every state has a word and a mark. The primary action sits at the bottom. Large downloads name their size and ask before using mobile data. Arabic is offered honestly ("partly translated, N %"). | — |

## 4. Deliberately not changing

- **The dock stays** Work · Inbox · Project · Settings. Project stays capability-gated. Glass stays on the dock and the composer only.
- **The chat page is the one conversation surface** for solo chats, team tasks (option A, assembled from the team's data) and watched workers. A real lead agent (option B) is out of scope.
- **The setup v2 engine** (component ids, check scripts, the `::oc` progress protocol, resume) is kept. It gains components and a host choice; nothing is rewritten.
- **Architecture:** UI → `ServerGateway` / `ServerCapabilities` only. Features are gated on flags, never on the flavour. OC1, OC2, Codex and Paseo are all still supported.
- **Termux remains a supported host**, now through v2. Both phone hosts can coexist on ports 4097 and 4096.
- **The board stays** as the backlog and planning view. The team page becomes an overview, not a workspace.
- **Kept pages:** Demo, Welcome, Keyboard shortcuts on desktop, `continue-on-phone-sheet`, the confirm sheets for irreversible acts (delete a message, delete a session, reset or remove a worktree), and the form date picker.
- **Security invariants:** `openExternalLink`, `oc.<what>.<profileId>` keys plus the deletion sweep, and credentials never echoed. They are extended with `KitSecretField`, never relaxed.
- **Tokens, theme, iconography, KitMotion timings, the Effects controls and the design standard's rules.** Kit v2 adds parts; it does not restyle.
- **Search:** one search index serves the Settings hub and the command palette.
- **Manual controls stay** for everything irreversible, public or credential-related (see the automation contract). They move into overflow; they are never deleted.
