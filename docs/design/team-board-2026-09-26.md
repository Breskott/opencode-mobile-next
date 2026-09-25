# The AI Team's board (2026-09-26)

The owner: "It has beads built in also? It can be treated jira like and have a board for it?" and "This is an example find best UI ux".

Gas City's tasks are beads (the `bd` tracker). The app already reads them (`OrchestrationSnapshot.work`). This spec is the phone board for them: what the best products do, what we take, and what the person may change.

**Finish line:** from the AI Team page, one tap shows a project's tasks as a board of five columns with counts, a card opens its team conversation, and the person can start, reprioritise, move back or cancel what the team has not started, with every change confirmed by the host or said to have failed.

**Non-goals:** dragging cards; editing titles and descriptions; creating epics or dependencies; custom columns; a formula run's internal steps (they are not beads the person gave); swimlanes.

## 1. Research (timebox ~25 min)

| Product | What it does on a phone | Source |
|---|---|---|
| **Jira Cloud (Android/iOS)** | The board is one column at a time; you swipe across columns. Long-press a card to drag it to another column. Moves obey the workflow: a drop onto a column with no transition fails with a warning. A "+ Create" sits in the column. Filters sit behind one icon as a swipeable row of quick filters. | [Manage your board (Android)](https://support.atlassian.com/jira-cloud-android/docs/manage-your-board/), [drag-and-drop KB](https://support.atlassian.com/jira/kb/unable-to-drag-and-drop-issues-between-the-columns-on-the-board/) |
| **Trello (Android)** | Horizontal lists, one per screen width. Drag between lists broke on Samsung (drag opens split screen); Atlassian's answer is the menu: open card › ⋯ › **Move card** › pick the list. | [Community: drag on Android](https://community.atlassian.com/forums/Trello-questions/Drag-and-drop-card-to-other-list-on-Android-app/qaq-p/1899147), [Move cards or lists](https://support.atlassian.com/trello/docs/moving-cards-or-lists/) |
| **Linear (mobile)** | Views default to grouping by status. The inbox is "tap to take action, swipe to delete, snooze to deal with it later"; long-press brings up the action menu. The composer is built for speed. Built for one-handed use. On desktop, dropping a card into another status group changes its status. | [Linear Mobile](https://linear.app/mobile), [Board layout](https://linear.app/docs/board-layout), [Display options](https://linear.app/docs/display-options) |
| **GitHub (iOS, Projects)** | A project's board view renders as a vertical list of collapsible status sections, each with a count pill ("Backlog 1", "Done 2"), with a view switcher under the title. Cards show status, labels, repository and age. | [Mobbin: GitHub iOS project board](https://mobbin.com/screens/7d35dba1-4695-4d82-9d6e-cc648bf9ad73), [Board layout docs](https://docs.github.com/en/issues/planning-and-tracking-with-projects/customizing-views-in-your-project/customizing-the-board-layout) |
| **Notion (iOS)** | A board database shows one column almost full width with the next column peeking at the edge, a status pill with its count on each column. | [Mobbin: Notion iOS board](https://mobbin.com/screens/71f9dba2-130f-406e-b4fe-781f227f51b8) |
| **Things / Todoist / Apple Reminders** | Calm lists: sections with headers, one line per item, gestures for quick changes (swipe to schedule/complete), long-press for more; nothing loud unless it is due. | own knowledge of the shipping apps |
| **ui-ux-pro-max** (`--domain ux`) | "Dragging Movements" (WCAG 2.2 AA, High): drag must never be the only way; give a menu or tap-to-move. "Confirmation Dialogs" (High): confirm destructive or irreversible actions. "Confirmation Messages": no silent success. | `.claude/skills/ui-ux-pro-max` |

### Patterns that fit a one-hand developer watching an AI team

1. **Default view.** Two proven shapes: paged columns with a peek (Jira, Trello, Notion) and a grouped list (GitHub, Linear, Reminders). The owner asked for a board. Paged columns keep the board's spatial model ("it moved right") and put one column's cards at full width, readable one-handed. The grouped list's strength, seeing every count at once, we keep with a **strip of column tabs with counts** above the pages.
2. **Status changes.** Drag is fragile on Android (Trello's Samsung bug), hard one-handed, and cannot be the only way (WCAG 2.5.7). Jira and Trello both fall back to a menu. Swipes hide destructive actions under an accidental gesture. **We use a menu: a card's ⋯ and a long-press open the same "Move" sheet.** No drag.
3. **Who moves what.** Jira refuses moves the workflow does not allow and says so. Here the workflow is the team: Working, Review and Done are the team's to set. The person moves only what the team has not started.
4. **Density.** Linear and Things: one card = title (the person's words, two lines), one muted meta line, at most one flag line. No avatars, no label clouds.
5. **Empty/loading.** Skeleton rows while the first answer comes; a column with nothing says so in one line; a project with nothing shows the team's drawing.
6. **Filters.** Behind one control, only when needed. A board of one project's open work rarely needs more than the project switcher (GitHub puts it under the title).
7. **Dependencies and epics.** Jira and Linear show the parent on the child card and a blocked flag. An epic card carries "2 of 5 done".
8. **Motion.** Linear moves optimistically: the card is in its new place at once, and goes back if the server refuses.

## 2. Decision

**A board of five columns, paged one at a time with the next one peeking, under a strip of column tabs with counts.**

- **Columns:** Backlog · Ready · Working · Review · Done (the owner's example words; no engine words).
- **Opens on Working:** what the team is doing now. If Working is empty, it opens on the first column that has something.
- **Project switcher** under the title ("Board" / "oc_app ▾") when the host has more than one project.
- **Tapping a card opens its team conversation.** Until `TeamConversation.open` lands (docs/design/team-conversation-2026-09-26.md, branch not merged), it opens the task (`RunScreen`) for a card that belongs to one, else the card's Work sheet. One function, `openTeamBoardCard`, is the swap point.

### Why (design standard §1–§10, the personas, the principles)

- **Persona:** a developer delegating to an AI team from a phone, one hand, attention in bursts. The first glance must answer "what is it doing, what is stuck, what needs me". The count strip does that without scrolling. Opening on Working puts the live work under the thumb.
- **Consistency (Jakob's law):** columns are what "a board like Jira" means. The card is a `KitRow` anatomy, the move sheet is the app's row list, and the states are `KitStateView`.
- **Safety:** no gesture moves a card by itself. Every move is named in the sheet in plain words with its consequence. Cancel is error-toned and asks first (§2).
- **Truth over narration:** a moved card shows "Moving to Ready…" until the host confirms. If the host refuses, it goes back and a notice says why. Nothing silent.

### Column mapping (from the bead, its assignee and its session)

| Column | Bead |
|---|---|
| **Backlog** | open, not given to anyone (no `assignee`, no `gc.routed_to`, no session) |
| **Ready** | open, given to the team (`gc.routed_to` or `assignee`), no worker on it yet |
| **Working** | `in_progress`, or a session / an agent on it, or waiting on the person, or stopped with an error |
| **Review** | `needs-review`, or handed to the reviewer (the refinery) |
| **Done** | closed: merged, done or cancelled; the last 7 days |

- **Blocked** is a flag on the card, not a column (Jira's and Linear's model): "Blocked by Sync engine" in the attention tone, in whichever column the card is.
- **Needs you** is a flag too, and the Working tab in the strip carries a dot while any card needs the person.
- **Never shown:** the host's bookkeeping. This covers:
  - session, convoy, message, molecule, gate, agent, role, rig, event, merge-request and slot beads;
  - ephemeral wisps;
  - `order:`/`nudge:` chores and anything labelled `order-run:*`, `gc:session` or `gc:nudge`.

### Card anatomy

1. **Leading mark:** `KitTaskMark` (waiting, working, done, failed, needs you, stopped).
2. **Title:** the person's words, up to two lines.
3. **Meta line** (one line, muted):
   - the priority, only when not normal ("Urgent", "High", "Low");
   - the type, only when not a task ("Bug", "Feature", "Epic · 2 of 5 done");
   - who has it ("Worker", "Reviewer");
   - the age ("3 min").
4. **Flag line** (at most one): "Needs you", "Blocked by …", "Stopped with an error", or "In {epic}" for an epic's child.
5. **Trailing ⋯** for the move sheet, only when the person may change something.

### What the person may change, and what only the team changes

| From | The person may | How it happens | Confirm |
|---|---|---|---|
| Backlog | **Start now** → Ready | give it to the project's workers (`assign`, the proven TEAM-306 sling) | no |
| Ready | **Move back to Backlog** | take it back from the team (`gc.routed_to` cleared) | no |
| Backlog, Ready | **Priority** (Urgent · High · Normal · Low · Someday) | bead update | no |
| Backlog, Ready | **Cancel task** → Done (cancelled) | bead close | **yes**, error-toned |
| Done (cancelled) | **Put back in Backlog** | bead reopen | no |
| Working, Review, Done (finished) | nothing on the board | the team moves them. The sheet says so and offers "Open conversation" to message or stop the team there | — |

- **Quick create:** the top bar's + adds a task to the Backlog (`createWork`, not given to anyone) when the host allows creating work.
- **Read-only:** a host that allows no writes shows the board read-only and says so in one status line: "This team's board is read-only here". There is no ⋯ and no +.

### Motion (§10)

- Cards settle with `KitAnimatedRows` (`KitMotion.standard`).
- A card the person moves animates out of its column. The destination tab's count bumps once (`KitMotion.quick`) and the card arrives in that column.
- Changing column by tab scrolls the pages with `KitMotion.standard` / `emphasized`.
- Reduced motion: every change is instant.
- There is no ambient loop on the board: it is a resting screen.

## 3. Feasibility (what the app can change through the existing gateway)

| Mutation | Route (pinned spec `contracts/gascity-supervisor-openapi-v0-3648ca2d499a.json`) | In the app today | Proven live |
|---|---|---|---|
| Start now | `POST /sling {bead, target: <rig>/gastown.polecat}` | yes: `OrchestrationController.assignWork` (`controlAssign`) | yes (TEAM-306 write proof) |
| Add to backlog | `POST /beads` | yes: `createWork` (`controlCreateWork`: phone host and fixture only; the PC front has no create route of its own) | yes (TEAM-306) |
| Priority | `POST /bead/{id}/update {priority}` | **no** gateway call: added as a separate file (below) | no |
| Back to backlog | `POST /bead/{id}/update {metadata: {gc.routed_to: ""}}` | **no**: added (below) | no. The dispatcher's reading of an empty `gc.routed_to` is inferred from how the app itself reads it. |
| Cancel | `POST /bead/{id}/close` + `{metadata: {close_reason: cancelled}}` | **no**: added (below) | no |
| Reopen | `POST /bead/{id}/reopen` | **no**: added (below) | no |

- The host front forwards any mutation from an allowlisted device (`tool/host/cp_front/README.md`).
- The phone's loopback supervisor takes them directly.
- A bare supervisor read over the network allows no writes, so the board is read-only there.

**Separated additive change.** `perf/team-hot` owns `lib/orchestration/**` and `lib/state/orchestration.dart`, so none of their files is edited. The additions are:
- `lib/domain/orchestration_work_edits.dart`: the `OrchestrationWorkEditGateway` interface.
- `lib/orchestration/adapters/gascity/gascity_work_edits.dart`: a new file that posts through the gateway's public `http` client, with the same idempotency and receipt rules as `GasCityControl`.

The board calls them directly and refreshes the controller afterwards.

**Follow-up for the owner of those files:** fold these three verbs into `OrchestrationControlGateway` + `MutationKind` so they persist as `MutationRecord`s like the other writes, and add a `controlEditWork` capability.
