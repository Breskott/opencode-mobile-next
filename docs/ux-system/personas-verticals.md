# Personas, verticals and automation (2026-09-26)

Built from the Phase 1 map (`map/all.json`, 356 pages), the owner's 167 verdicts, the design principles and standard, and the evidence of real people:
- the issue #87 reporter;
- the owner's real phone (regression rows 1–22, force stop, heat, "Why 4 minutes?");
- the 1.0.44+50 baseline.

The data is in `personas-verticals.json`, which has the same content plus evidence paths for every "worst" item. Ids are from `taxonomy.md`. New vertical ids are marked *proposed*.

## 1. Personas

### phone-only: builds on the phone alone
- **Context.** The phone is both client and server (built-in Ubuntu or Termux). This is the owner's RedMagic (Android 15, 16 GB) and the #87 reporter.
  - The maker's battery manager force-stops the app (`exit-info` reason 10/21, twice in one day).
  - Heat, disk and RAM are real limits: each `opencode acp` uses ~563 MB and the server ~410 MB.
  - Used in bursts, often with one hand.
- **Top jobs.**
  - Set up: phone setup v2.
  - Recover a stopped, killed or heat-paused server: root-connecting, the shell's exit and thermal lines.
  - Chat against the phone's own server.
  - Local files, terminal and processes.
  - Turn on the AI Team on the phone.
- **Needs.**
  - The phone's server comes first everywhere, starts on tap and restarts by itself.
  - Cost is stated before commitment: MB, RAM per worker, battery, and "about 6 min".
  - One resumable setup engine for everything.
  - Effects calm down under battery saver or heat.
- **Pains.**
  - root-connecting offers a retry that cannot work.
  - A server killed by Android or paused for heat looks like offline in chat.
  - termux-setup-failed contradicts itself three times.
  - local-agent-page says Termux while installing into Ubuntu.
  - builtin-server-setup is four manual steps.
  - team-home calls an idle team "Paused" (row 20).
  - Agent output shows "Connecting…" forever (row 22).
  - The Ubuntu image and voice models are missing from storage.
- **Great looks like.**
  1. One tap to a first reply, with an honest estimate, that survives kill and reboot.
  2. One row for the phone's server that says why it stopped and restarts itself.
  3. The cost is shown before every install.
  4. Claude Code and the AI Team come through the same setup.
  5. After Android kills the app, the next open says so in one line and brings everything back.

### remote-lead: steers a computer from the phone
- **Context.** OpenCode 1/2, Codex or Paseo on a computer, over Tailscale. Seconds of attention from the lock screen, on a flaky network.
- **Top jobs.**
  - Observe: Work tab, Inbox.
  - Approve: permission card, question, gate.
  - Review changes.
  - Queue or steer follow-ups.
  - Reconnect and switch servers.
- **Needs.**
  - Open where something waits.
  - The header shows project · server · "Working 2 min / Needs you / Done".
  - The answer before the work.
  - Reconnect with a visible countdown.
  - Queued sends reconciled with the server.
  - Answer on another server without switching.
- **Pains.**
  - "Running tools" spins while the run is blocked on approval.
  - The model chip says "Choose model" while a model answers.
  - Two taps and a sheet per approval.
  - "Delivery unconfirmed" gives no next step; the owner wants one bubble.
  - Unreachable servers look reachable.
  - Status stays green while reconnecting.
  - A tap on an answered request lands on an empty Inbox.
  - Voice input stops at 30 s.
- **Great looks like.**
  1. One "Needs you" list across servers, answered in one tap from the notification.
  2. Run state and elapsed time in every header.
  3. A "finished while you were away" summary.
  4. Narrated retries, and no lost or duplicated sends.
  5. "Always allow this" on the third identical ask.

### team-delegator: hands big jobs to the AI Team
- **Context.** The owner's car-sharing task: "it's all about automated dev". Checks back occasionally, and accepts minutes if they are expected. "Why 4 minutes? Everything should be hot and in seconds."
- **Top jobs.**
  - Give a task.
  - Watch the Now line.
  - Answer gates.
  - Merge and review merged work.
- **Needs.**
  - Project and supervision remembered.
  - One conversation per task.
  - Agents are status, not controls.
  - Engine words (convoy, polecat, city, bead) only under Details.
  - The team heals itself and reports afterwards.
- **Pains.**
  - team-agent says "Working" while the host says stopped (row 21).
  - Six manual levers ("Why manual…").
  - Merge is manual even on Autonomous.
  - The objective is lost on swipe (critical).
  - "Still planning" for 31 min.
  - The AI Team is shown twice with two states (row 18).
  - About 6 min to first output (three worker starts cut off), with nothing on screen explaining it.
- **Great looks like.**
  1. A task always lands in its conversation, with "Starting a worker, about 30 s".
  2. A Now line says what, since when, and what's next.
  3. Asked only at the gates the person reserved.
  4. Auto-merge when checks pass, with Reopen.
  5. Cost per task.

### tinkerer: power user
- **Context.** Several servers, MCP, commands, worktrees, terminals, logs; sometimes a tablet or keyboard. High attention.
- **Top jobs.**
  - Configure providers, MCP, models and shell.
  - Inspect logs, processes, diagnostics and capabilities.
  - Switch servers and projects.
  - Commands and shortcuts.
- **Needs.**
  - The same defaults as everyone, and no expert mode.
  - Raw values in mono under Details, one tap to copy.
  - Dense tool pages are fine.
  - Automation with an audit trail; manual levers in overflow.
- **Pains.**
  - termux-processes: unlabelled colour squares, and "CPU 108%" unexplained.
  - The diagnostics log lives in memory only.
  - Error details cannot be copied.
  - MCP bearer tokens are shown in clear.
  - Five hand-built log views.
  - Settings search is a raw field.
  - Capabilities have no enable path.
  - No Claude or Codex commands.
- **Great looks like.**
  1. Copy anything.
  2. One log viewer.
  3. Diagnostics survive a crash and export in one tap.
  4. Search finds any setting.
  5. Capabilities say why a feature is off and how to turn it on.

### newcomer: first run or demo
- **Context.** Doesn't know the vocabulary, judges the app in minutes, may read Arabic.
- **Top jobs.**
  - Welcome and demo.
  - Phone setup or pairing by code.
  - Sign in to a provider.
  - First conversation.
- **Needs.**
  - One question, one button.
  - A preselected model and a created project.
  - No engine words (glossary test).
  - Terms explained in place.
- **Pains.**
  - Settings has 33 rows in engine words.
  - The OpenCode-vs-Paseo choice.
  - A raw "Secure storage is locked" or "Cannot reach http://…".
  - "Whisper INT8, MiB".
  - No path from "no models" to signing in.
  - The info-label page ("Wtf is this page?").
  - Arabic is offered while most strings are English.
- **Great looks like.**
  1. From install to first reply with no word to look up.
  2. The demo shows one full loop.
  3. Every error has one next step.
  4. Tooltips instead of pages.
  5. Nothing optional looks required.

### Cross-cutting needs (every persona)

| Need | Worst today | Great looks like |
|---|---|---|
| **Large text** (200 %) | Notifications explanation and MCP OAuth instruction truncated even at 100 % (critical); code cut in the file viewer; receipt chip cuts titles to a few letters | a 200 % golden for every migrated screen; nothing clipped |
| **Screen reader** | state by colour only (profile-monitor, home-shell dots, command palette); unlabelled stop squares; icon-only pending-send actions | a word plus a mark for every state; labels by construction; a TalkBack walk per release |
| **Arabic RTL** | Arabic offered while most strings are hardcoded; 13 non-directional paddings in review; Arabic copy of force-stop/thermal never viewed; `l10n_coverage_test` failing on `team_now.dart` | coverage gate green; RTL goldens; the kit isolates LTR values; an honest "partly translated" |
| **One hand** | Stop and Send 8 dp apart; prompt-editor primary out of reach; find bar at the top | primary pinned at the bottom; destructive actions away from frequent ones; every gesture has a menu twin |
| **Slow or metered network** | a 150–360 MB voice download with no Wi-Fi note; usage has no last-known value offline; setup on slow networks unproven (#87) | size shown and resume for every download; last-known values with their age; consent before large downloads on mobile data |

### Serving several personas in one app
1. **No modes.** No simple/expert switch and no persona picker. Use progressive disclosure: summary → Details fold → technical page.
2. **Defaults for the newcomer, reach for the tinkerer.** Primary surfaces use the person's words. Ids, paths and addresses go under Details, copyable.
3. **Context chooses.** Actions follow what the server is and can do (`ServerCapabilities`): a phone server gets Restart and cost lines; a remote server gets network help.
4. **Automatic by default, manual in overflow.** Every automatic act is announced afterwards in one line, with Undo where possible.
5. **Remember, don't re-ask.** Supervision, project, model, and Queue vs Steer are remembered per server.
6. **Ask for consent once, in flow,** at the moment it matters. Never make the person hunt in Settings.
7. **Where tinkerer detail lives:**
   - the Details fold (bottom of a state or sheet);
   - `KitRowMenu`;
   - technical pages reached from Diagnostics or the server's details, never inside a primary flow;
   - shortcuts and the command palette.
8. **Explain, don't vanish.**
   - Today 285 capability gates are *hidden*, only 18 offer to enable, 82 explain and 13 are disabled.
   - Wherever the feature can be enabled, show "Not on this server · why · Turn it on".
9. **One job, one landing place.** Give the team a task vs Solo · Team; Add server vs Connect OpenCode 2.
10. **Density follows the page's role.** Glance pages get one line per item. Work pages put content first. Tool pages may be dense.

## 2. Verticals

The counts below say how many pages the map flagged for each vertical. Two figures per row:
- **Flagged** is the number of pages the map tagged for that vertical.
- **Issue** is how many of those tags are not "ok". The split was made by a heuristic over free text, so treat it as approximate.

| Vertical | Standard (what "good" means) | Flagged / issue | Worst 5 (evidence in JSON) | Mechanisms that keep it true |
|---|---|---|---|---|
| **a11y** | 48 dp targets with 8 dp gaps; 4.5:1 contrast; never colour alone; 200 % reflow; every control labelled; one live announcement | 97 / 82 | info-label ~24 dp target (critical); MCP OAuth dialog truncated (critical); notifications explanation truncated (critical); process stop squares unlabelled; chat Stop and Send 8 dp apart | `KitIconButton` (48 dp minimum, required label); `KitStatusMark` word+mark; tooltip replaces info-label; accessibility guidelines on every golden; 1.0 and 2.0 text-scale goldens for migrated screens; TalkBack walk in each release record |
| **rtl-l10n** | all strings in arb; directional paddings; LTR isolation for code, paths and ids; honest language offer | 60 / 49 | language sheet offers Arabic over hardcoded English; chat hardcoded strings; review has 13 non-directional paddings; permission sheet shows raw tool ids; update notices hard-coded | `KitTechnicalValue` and `KitCodeBlock` isolate LTR; fix and ratchet `l10n_coverage_test`; lint against `EdgeInsets.only(left/right)`; ar/RTL goldens; "partly translated (N %)" |
| **perf** | against the 1.0.44+50 baseline (see the note below this table); a real phone's p90 ≤ 17 ms | 23 / 11 | chat is an 8189-line library with AnimatedSize on the list; message view layout animation; uncapped tool output; the glass dock budget (gfxinfo sees 0 Flutter frames); unbounded paging | `measure.sh` + `timestats.py` per candidate on the same emulator (replaces gfxinfo in standard §10 and the glass gate); OCTRACE budgets in App diagnostics › Performance; lint against AnimatedSize and literal Durations in list items; capped output; an arm64 phone run |
| **battery-heat** | cost stated before running; nothing runs unannounced; heat guard pauses and resumes the team; Effects follow battery saver and heat | 24 / 20 | Effects ignore battery saver and heat; team offer hides ~550 MB/worker; thermal pause not shown on the team sheet; local shells run unannounced; background budget not shown | `DeviceBudget` service (thermal, saver, storage, RAM) → `KitEffects`; `KitCostLine` required on install screens; one "Running on this phone" surface (running-work + processes merged); battery-saver widget test; thermal override device recipe |
| **reliability** | survives force stop, low-memory kill, the 6 h dataSync cap, reboot and a locked keystore; recovers by itself and explains once; resumable jobs; last-known offline | 68 / 47 | 6 h cap never shown; diagnostics log in memory only; PTYs vanish on restart; Termux install can't resume; queued prompts deleted silently on server remove; bootstrap-gate has no way out | `LifecycleReport` (the force-stop recovery, built but not device-proven); every long job on the v2 engine; background-budget tracker ("resumes at 14:10"); last-known cache; force-stop, reboot and airplane recipes per release |
| **security-privacy** | AGENTS.md invariants; secrets never displayed or prefilled; risky switches scoped and reversible; remote scripts pinned | 74 / 20 (strongest) | MCP bearer tokens in clear (critical); host-management pipes an unpinned script into bash; server-wide auto-approve has no scope or expiry; shell dialog hides that it skips approvals; public link without Stop sharing | `KitSecretField`; `KitRiskSwitch` (scope, expiry, indicator); a redaction test with fake keys through diagnostics, reports, notifications and logs; `launchUrl` allowed only in `external_link.dart`; SHA-256 pins |
| **honest-state** | words never contradict the screen or host; state from the source of truth; > 8 s says so with a way out; jobs > 30 s show stages and an estimate; no disabled button as progress | **188 / 153** | agent "Working" while stopped (row 21, real phone); output "Connecting…" forever (row 22); idle team "Paused", 8–9 min turn-on with no expectation (rows 19–20); "Running tools" while blocked on approval; Termux failure contradicts itself 3×, and unreachable servers look reachable | `KitStateView` and `KitStatusLine` escalate by themselves after 8 s (`since`); one status source per entity, mapped to words once; `KitProgressView` requires stages and an estimate; lint against a disabled button with a spinner; `KitCapabilityRow`; glossary test with contradiction pairs on goldens |
| **automation-first** | the app decides what it safely can (197 elements); manual controls are the fallback; every automatic act reported with Undo; interrupt only under the contract | 89 / 70 | six manual agent levers; merge manual on Autonomous; two taps and a sheet per approval; builtin setup is four steps; every setting manual (owner wants a config and MCP agent) | `AutomationPolicy` per server plus a "What runs by itself" page; `KitAutoLine` and a "While you were away" log; an agent assistant as the fallback for search and MCP; reverted-automation tests |
| **help-feedback** | "Report a problem" within 2 taps of any error; persisted, redacted diagnostics; preview; copy for every raw error; network errors get a fix, not a report | **18 / 16** | App diagnostics ("a first grade page … accessible when errors happen across app") is memory-only; the bug report carries only version and platform; chat errors can't be copied; failed setup and team jobs have no report path; Report offered for timeouts | `ReportProblem` service (persisted ring buffer: errors, OCTRACE, android.exit, thermal); `KitStateView` error variant gets Copy and Report automatically, with a classifier choosing Report or Fix; a preview sheet; redaction and "every error has Copy" gates |
| **notifications** | Needs-you arrives while the app is closed; a tap lands on the request or explains why it's gone; denied state, test notification, preset | 17 / 10 | no denied state and no test notification; external tasks never alert; no alert when the Claude daemon dies; answered request → empty Inbox; Termux install has no progress notification | `NotificationRouter` as the only sender (dedupe, per server, cancel when answered); a preset; landing-contract test |
| **upgrade-migration** | no data loss or reinstall; existing installs adopted; one-shot migrations leave no screens; server updates offered; code push predictable | 19 / 16 | legacy-drafts is a permanent migration screen; builtin installs must land on the v2 card; server update routes to the old wizard; capabilities never offer "update server"; code-push "Got it" doesn't apply it | `MigrationRunner` with old-prefs fixtures; v2 check scripts treat existing installs as done; one `UpdateService` line |
| **consistency-kit** | everything from `lib/ui/kit`; one confirm, sheet, log and row; destructive always error-coloured; KitMotion only | 277 / 248 (widest, least severe) | ≥ 8 AlertDialogs bypass the confirm sheet; chat mostly hand-built; termux-setup has 4 Scaffolds in 3265 lines; destructive shown in green ×4; three notice-line implementations stacked | parts ranked by map demand: `KitConfirmSheet` 78, `KitSheet` 33, `KitSegmented` 15, `KitLogPanel` 13, `KitChoiceRow` 11, `KitSearchField` 10, `KitCommandBlock` 8, `KitInputDialog` 7, `KitDetailsFold` 7, `KitDiscardGuard`; `design_standard_test` bans AlertDialog, ListTile, ExpansionTile, SwitchListTile and raw progress; goldens |

**The perf baseline.** 1.0.44+50 was measured on the same emulator and fixture:

| Measure | Baseline |
|---|---|
| Cold start to a usable Work tab | 3.4 s |
| Open a project | 1.6 s |
| Open Settings | 0.2 s |
| App's share of send → first token | 0.5 s |
| Streaming (TimeStats) | p90 40 ms, 76.8 % of frame intervals over 17 ms |

No candidate build and no real phone has been measured yet.

### Missing verticals the evidence shows (proposed ids)

| Proposed | Standard | Evidence | Mechanisms |
|---|---|---|---|
| **data-safety** (never lose typed work) | nothing typed, dictated, queued or attached is lost on back, swipe, crash or a lost server; sheets keep a draft instead of asking | 24 pages. Lost on swipe (critical): team objective, review comment, agent message, context capsule, dev-service editor. Also lost: form answers on back, unsent voice transcript, queued prompts deleted on server remove | `KitDiscardGuard` (keeps the draft silently); `DraftStore` keyed `oc.draft.<target>.<profileId>` so the deletion sweep finds it; a harness test that types, swipes and reopens every input sheet |
| **cost-awareness** | tokens and money per turn and per task, quota headroom, default 80 % alert | 19 pages. usage shows "30 days" vs "Sep 2–6"; team cost shown as one agent's; no price tier in the model picker; no cloud-sandbox cost | `CostService` → `KitCostLine` and the conversation header; default budget alert; price tier on model rows |
| **multi-server** | see and answer what needs you on every server without switching; every item names its server | only 4 pages record it, although remote-lead and tinkerer run several. The switcher lacks other servers' state; answering needs a switch; the Inbox doesn't name the server | a gateway per profile; one cross-server Inbox; server chip on rows and notifications |
| **discoverability** ("don't have X, want X") | a gated feature explains why and offers the enable flow | whenMissing: 285 hidden vs 18 offers-enable. Settings rows vanish; chat menus shrink silently on Codex/Paseo; "no models" has no sign-in path | capability-explainer registry → `KitCapabilityRow`; a map audit gate |

## 3. Automation first

197 elements are mapped `couldBeAutomatic: yes`. About 40 of them already happen and only need their manual control demoted.

**The app does it by default. It says so afterwards and doesn't ask:**
- **Reconnecting.** Reconnect with a countdown, re-probe on a network change, retry share and link intake.
- **Queued sends.** Reconcile them with the server transcript; retry transient provider errors with backoff.
- **The phone's server.**
  - Start it on tap; restart it after a force stop or crash.
  - Resume setup after a kill, reboot or network return.
  - Re-check Termux, Tailscale and sign-in on resume.
  - Poll health after a restart.
- **Heat.** Pause the team and resume it after cooling; drop Effects under battery saver or heat.
- **Defaults instead of questions.**
  - The only or last-used project; "my-app" on first run.
  - The server's default model by name; the voice pack by RAM and the voice by locale.
  - Queue rather than Steer; the review scope that has changes.
  - Names and titles generated; skip any picker with one option.
- **Detection.** The server kind after pairing, the team host, existing installs.
- **Keeping work.** Keep drafts per target; recovered photos go back to their own draft; restore with Undo.
- **Live pages.** Follow output at the bottom, poll while open, bounded paging, no refresh buttons.
- **Team housekeeping.**
  - Route ready work to free workers.
  - Wake a stalled pool, then say so.
  - Restart crashed workers; recycle them at the context threshold.
  - Hold a worker at a provider limit until it resets.
  - Retry an unconfirmed answer once; re-sling a transient failure once.
  - Fall back to a direct task when the planner is off.
- **App updates.** Download the code push silently and apply it on the next cold start.

**Consent once, in flow, when it first matters:**
- Battery exemption and the maker's auto-start.
- Notifications, with the preset "Tell me when the agent needs me".
- "Always allow this" after 3 identical asks.
- AI Team supervision level per server: Balanced or Autonomous is the consent to auto-approve and auto-merge on green.
- Housekeeping with side effects: restart dev services, stop idle helpers after 10 min, clean caches when space is low, update when idle.
- Background monitoring of other servers and quota.
- Downloads over 50 MB on mobile data.
- The agent assistant running commands on a server (MCP, config, AI Team).
- Including diagnostics in a report.
- A warm team worker (~550 MB), after a device experiment.

**Manual, always:**
- Anything irreversible or public: deletes, reverts, worktree reset or remove, public share, credential removal, org switch.
- Decisions the agent asks for outside saved rules.
- What to build.
- Signing in.
- Ad-hoc shell commands and stops.
- Tinkerer levers (nudge, reassign, restart, stop, pause, refresh). These stay in overflow as fallbacks, next to what automation already did.

### The "Needs you" contract: the only reasons to interrupt
1. **A decision only the person can make.** A permission outside their saved rules, a question or form, a gate their supervision reserves, a merge under High supervision.
2. **Work that cannot continue without them.** Credentials expired or rejected; a provider limit or budget reached with no fallback; storage full; a step still failing after the automatic retries, saying what was tried.
3. **A first-time consent** from the list above, at the moment it becomes relevant.

**What every Needs-you item must do:**
- Say why it is asking.
- Say what happens if the person ignores it ("the team waits; nothing is lost").
- Be answerable in one tap from the notification.
- Be deduplicated, listed oldest first, and name its server.
- Disappear everywhere once answered.

**What is never a Needs-you:** reconnecting, restarts, heat pauses, updates, progress and finished work.
- These go on quiet status lines, and on the quiet channel when the app is in the background.
- They are collected in "While you were away".
- "Done" alerts are opt-in per kind (on by default for team tasks and long runs).
