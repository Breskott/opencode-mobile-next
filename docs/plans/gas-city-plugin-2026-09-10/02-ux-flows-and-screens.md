# UX — flows, screens, states, copy

**Revised 2026-09-10 after the Mobbin pass** (see
[02a-design-references.md](02a-design-references.md)). The governing rule
is now *one number, one sentence, one action per surface*. Where a section
below lists more, the mockups win: the extra material moves behind a tap
(Details, Timeline, Technical details).

Design principles carried from the BRD (§52) and the app's existing rules:
human-first, exception-driven, progressive detail, durable state over chat
state, mobile-native. Everything below must also hold at 320dp × 2.5x text,
in Arabic/RTL, and with reduced motion. Product term first with the Gas City
term in small secondary text ("Work · bead", "Run · convoy", "Agent ·
polecat"); the provider is named openly in headers ("AI Team · Gas City").

Legend for states: **L** loading · **E** empty · **S** stale (cached, host
unreachable) · **X** error · **N** not available (capability off).

---

## 1. Discovery and enablement

### 1.1 Where it lives

- **More › Plugins** (new group under the existing "Library" entry, not a
  tab). Row: **AI Team** · subtitle by state:
  - "Off" (default)
  - "Found on Development PC · Gas City 1.4" (advertised, not enabled)
  - "On · Development PC" (enabled, healthy)
  - "On · reconnecting…" / "On · host unreachable since 3 min"
  - "Not available on this server" (probe says nothing; explains why)
- Also reachable from the Workspace card's overflow ("Team settings") and
  from the server editor as a section ("AI Team (optional)").

### 1.2 Discovery flow

```
Saved server connects
   └─ probe /.well-known/opencode-mobile-orchestration on the server host
        ├─ 200 → offer: "Development PC also runs an AI team. Turn it on?"  [Turn on] [Not now]
        ├─ no route → try the profile's saved orchestration URL, if any
        └─ nothing → row shows "Off · Add manually"
```

- The offer is a one-time quiet card on Workspace (dismissable, remembered
  per server). Never a modal on connect.
- Manual add: sheet with **Address** (https:// required except loopback),
  **City** (optional; auto-picked if one), **Test** → verdict chip:
  "Gas City 1.4.1 · city bright-lights · read-only" or a specific failure
  (plain HTTP refused, unreachable, not a Gas City, city not running).
- Writes: the verdict states "Decisions and controls: available via
  front" or "read-only (no front on host)". Copy explains what the front is
  in one line with a link to the host guide.

### 1.3 Turning it off

Sheet: "Turn off AI Team for Development PC? Removes its card, attention
items and cached team data from this phone. Nothing changes on the host."
[Keep] [Turn off]. Secrets under `oc.orchestrationToken.<profile>` are
deleted; the probe offer is not re-shown for 30 days.

---

## 2. Workspace — the AI Team card

Placement: below the project context, above Sessions (BRD §10). Present
only when enabled for the active server.

### 2.1 Card anatomy

```
[team] AI Team · Gas City                    ● 1 needs you
Offline-first sessions is 72% done.
5 agents working. Wolf is waiting for your decision on storage.
▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░
[ Decide ]                              1 more run  ›
```

- Headline is a sentence about the run that most needs you (or the most
  recent active run); the second line is one plain sentence, generated from
  state, never a list of numbers.
- One progress bar, one colour. One primary action: the top "needs you"
  item, else "Open".
- Other runs collapse to "N more runs ›". Cost, agents, stages and hosts
  live behind the tap.

### 2.2 What makes it feel alive (kept deliberately small)

- The bar animates only when progress changes; the card never breathes.
- The sentence updates in place when the state changes ("Wolf finished
  Database tests." for a few seconds, then back to the summary).

### 2.3 States

- **L**: skeleton with the header only. **E** (enabled, no runs): "No runs
  yet. Send an objective to start one." [Start a run] (Sprint B) or
  "Start runs from the host for now" (Sprint A). **S**: banner line "Showing
  data from 09:41 · host unreachable" and dimmed numbers; nothing
  interactive except Refresh. **X**: one line with the cause and Retry.
  **N**: card absent.

---

## 3. AI Team home (tap the card header)

A screen with three segments: **Runs** · **Agents** · **Needs you**. Top
shows host identity chip ("Development PC · Gas City 1.4.1 · city
bright-lights · read-only"), tap for Technical details.

- **Runs** list: active first, then waiting/blocked, then completed
  (collapsed group "Completed today (4)"). Filter chips: Active, Blocked,
  Completed, All. Search by title.
- **Agents** list: the fleet (§5).
- **Needs you**: the same items Activity shows, scoped to this server.
- FAB **Start a run** (Sprint B): opens the objective sheet (§7).

---

## 4. Run detail

Answers, in order, the five BRD questions. Tabs: **Overview · Work ·
Agents · Timeline** (+ **Changes** and **Verification** appear when those
capabilities exist — Sprint 3+ of research plan).

### 4.1 Overview

```
Offline-first sessions · Run · convoy
● Working                                         34 min
12 of 18 done
▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░
[ Working 5 ]  [ Blocked 2 ]
┌ Wolf needs a decision ─────────────────────┐
│ Which persistence strategy for the tests?   │
│ [ Decide ]                                  │
└─────────────────────────────────────────────┘
Stages
✓ Requirements, Architecture, Data model
◐ Implementation                          4 of 6 ›
○ Testing
○ Review and merge
Work · Agents · Timeline                        Details
```

- Answers the five questions top to bottom with one element each.
- Only the single most urgent "needs you" item is shown inline; the rest
  are in Activity.
- Merge readiness (02 §8a) appears as the last stage row once every
  earlier stage is done, opening the merge sheet.

### 4.2 Work tab

**List** on phones (default and only view at phone widths); **Graph** is
an opt-in view for tablets and desktop.

- **List** groups by state (Needs input, Blocked, Working, Ready, Queued,
  Review, Completed, Failed, Cancelled) — the BRD §14 vocabulary — each row:
  title, owner glyph, blocked-by count, age. Tap → Work sheet.
- **Graph**: a top-down dependency graph rendered with a custom painter
  (no new dependency): nodes are rounded chips coloured by state (plus a
  glyph for non-colour readers), edges are `needs` links, the critical
  path is drawn thicker, and the currently blocked chain is highlighted.
  Pinch-zoom, drag-pan, "Fit" button, node tap → Work sheet. On 320dp it
  defaults to List; Graph is one tap away.
- **Work sheet**: title, description (markdown), state, owner, dependencies
  as chips (tap to jump), blocking (what waits on this), branch/worktree,
  linked session ("Open session" when the link exists), output excerpt,
  timestamps, validation result if any. Actions (Sprint B): Assign to…,
  Close, Reopen, Nudge owner.

### 4.3 Agents tab

Same rows as the fleet (§5), scoped to this run.

### 4.4 Timeline tab

Reverse-chronological event list with filter chips **Agents · Work ·
Decisions · Code · Tests · System · Failures**. Rows are one line
("10:46 Test suite passed 182/182") with a leading glyph per category;
tapping an event opens the related Work/Agent/Gate. Live: new events slide
in at the top with the same "jump to latest" pill the chat uses when the
user has scrolled away.

### 4.5 States

**L** skeleton per tab; **S** stale banner + last-updated; **X** inline
retry per tab; a run that disappeared server-side → "This run is no longer
on the host" with Back.

---

## 5. Agents (fleet) and Agent detail

### 5.1 Fleet row

```
[glyph] Fox · OpenCode / GPT-X            ● Working
        Sync engine · ctx 63% · 12m
```

Status vocabulary: Working, Idle, Waiting (needs input), Blocked, Stopped,
Crashed. Sort: needs-you first, then working, idle, stopped.

### 5.2 Agent detail

Sections: **Identity** (name, role, provider, model, harness), **Runtime**
(state, session age, context meter with the same ring the composer uses,
working directory, worktree/branch — LTR mono), **Current work** (work chip,
dependency state), **Activity** (recent files read/changed, commands, tests,
tool calls, collapsed like the chat's tool groups), **Output** (live tail,
monospace, LTR, "Follow" toggle; the same follow-latest behaviour as chat).

Controls (Sprint B, capability-gated): **Message** (composer sheet with the
chat's composer widget in "message an agent" mode, no attachments),
**Nudge** (one-tap "please continue"), **Pause / Resume**, **Stop**
(two-step), **Restart** (two-step), **Reassign work…**, **Open session**
(when linked), **Open worktree** (Files with the worktree filter).

### 5.3 Restraint

Agent detail is a step log (what it read, ran, asked) ending in the one
thing you can do: answer (with an optional note that travels with the
answer), nudge, or stop. Context use is a number in the
header, not a ring. Live output is one tap away, not inline.

## 6. Needs you — Activity integration

Activity already aggregates permissions, questions and forms. AI Team items
join the same list with the BRD §47 priority order:

1. Decision requested (pending interaction) · 2. Run failed · 3. Permission
(existing) · 4. Review ready (label `needs-review`) · 5. Agent blocked ·
6. Merge ready (Sprint 3+) · 7. Significant completion (run completed).

Row: kind glyph, one-line title, run/agent/server subtitle, age. Tap opens
the **Gate sheet**:

- **Choice**: radio list from the interaction's options, [Send].
- **Confirmation**: the prompt, [Cancel] [Approve] (destructive prompts are
  red and two-step).
- **Free text**: the composer widget, [Send].
- **Gate bead**: description, what it unblocks (chips), [Mark done] (Sprint B)
  or "Close this on the host" (Sprint A).
- **Run failed**: classified failure (Agent, Execution, Test, Merge conflict,
  Infrastructure, Dependency, Authentication, Context), affected work,
  recoverable yes/no, recommended action, and buttons Retry / Restart agent
  / Reassign / View logs / Cancel work (Sprint B).

Every answer routes with the interaction's `request_id`; the sheet shows
"Sent · waiting for the host to confirm" until the matching `request.result`
event arrives, then "Answered" and the row leaves the list. A lost stream
leaves it at "Sent, unconfirmed — check on the host before re-sending"; it is
never re-sent automatically.

Notifications (Sprint B): kinds 1, 2, 4, 7 push, deep-linking to the exact
gate sheet with route ids only. Everything else stays silent.

---

## 7. Start a run (Sprint B)

Sheet: **Objective** (multi-line, the app's prompt editor in "objective"
mode), **Project** (rig picker), **Supervision** (High / Balanced /
Autonomous with the BRD descriptions), **Planner** (the configured planner
agent, e.g. Mayor, shown not chosen), **Boundaries** (read-only list from
host policy: "Never merge without approval", "Require tests before merge").
[Send to planner]. The result is a run once the planner materialises beads;
until then the card shows "Planning… (Mayor)" with the planner's live output
one tap away.

---

## 8. Technical details expander and side-by-side terms

Every title carries its Gas City term as small secondary text
("Sync engine · bead gc-abc12", "Offline-first sessions · convoy"). The
Technical details expander on Run, Work, Agent and the host chip lists raw
provider objects (ids, rig, formula, session id, request ids) with copy
buttons. There is no terminology toggle.

## 8a. Merge (Sprint B)

Run overview gains a **Merge** section once every step is complete:

```
READY TO MERGE · merge request gc-mr-14
✓ 18/18 work items   ✓ Tests   ✓ Build   ✓ Review   ✓ No conflicts
✓ Acceptance criteria
14 files · +841 / −203
[ Review changes ]   [ Approve request ]   [ Merge ]
```

- Readiness lines come from the front's `/merge-readiness`; any missing
  line disables Merge and says why.
- **Approve request** approves the MR bead (one confirmation).
- **Merge** is two-step ("Merge into main? This cannot be undone from the
  phone") and honours host boundaries ("Never merge without approval",
  "Require tests before merge"); a boundary that blocks it is shown, not
  silently applied.
- Force-merge, branch reset and worktree deletion do not exist on the phone.

---

## 9. Settings › Plugins › AI Team

- Host chip and identity (provider, version, city, read-only/controls).
- Live updates: "Event stream connected · seq 41 823" / reconnecting.
- Notifications: per-kind switches (Sprint B).
- Host performance disclaimer (per host mode).
- Data on this phone: "Team cache 1.2 MB" [Clear]; token (if any) [Forget].
- **On this phone** section (Sprint C): status of the phone-hosted
  supervisor (Stopped / Starting / Running 3h · 2 agents), [Start] [Stop],
  battery truth line ("Android may stop this at any time; nothing is lost,
  work resumes when you start it again"), [Remove from this phone].
- Turn off (§1.3).

---

## 10. Offline and stale behaviour (BRD §33)

- Every list carries "Updated 09:41" in its header when older than 60 s.
- Stale + unreachable: read-only, controls disabled with the reason
  ("Host unreachable"), no queued mutations.
- Reconnect: `Last-Event-ID` resume; if the host replays nothing, all
  scopes refetch and a brief "Caught up" toast appears.

---

## 11. Accessibility and layout rules

- Status never colour-only: glyph + text + optional texture.
- Every row ≥ 48dp target; graph nodes ≥ 44dp at 1x and never smaller than
  the text they hold.
- 320dp × 2.5x: cards stack, the stage strip wraps to two lines, the graph
  defaults to List, all sheets scroll.
- RTL: layout mirrors; ids, paths, branches, commands and output stay LTR.
- Live regions announce new needs-you items; the timeline does not announce
  every event.

---

## 12. Copy inventory (English; Arabic goes to `docs/qa/ai-team/messages_ar.json`)

Keys are prefixed `teamUi`. First batch (Sprint A) ≈ 90 keys: the states in
§1–§6, run/work/agent state names, the gate kinds, stale/offline lines, the
plugin toggle sheet, technical-details labels. Server content (titles,
descriptions, output, error text) is never translated.
