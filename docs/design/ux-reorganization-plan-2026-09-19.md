# UX reorganization plan — 2026-09-19

Status: **proposal for the owner to approve.** No code has changed. Evidence is
the UI ledger (`docs/design/ui-ledger/`, 335 pages, 1,720 elements, 820 edges)
and the persona in `docs/product-persona.md`.

## 1. Why the app feels messy

Every feature was added where it was built, not where a person would look for
it. The ledger shows the result:

- The app is organized by **server feature** (MCP, providers, catalog, plugins,
  worktrees) instead of by **what the person is trying to do**.
- There is no rule for where a thing lives, so things live in several places:
  chat has 40 doors on 24 pages, Servers 15 on 9, the model picker 15 on 8,
  Termux setup 11 on 10 under 7 different names.
- "More" and "Settings" are two junk drawers one tap apart. Preferences also
  live in chat, Files, Review, Servers and Plugins. Notifications are split
  three ways and quiet hours exist twice.
- Chat carries about 110 controls, and offers its actions three times (a
  25-row menu, 36 slash commands, a desktop palette) from three separate lists.
- The same action has different names ("Try again" 36× / "Retry" 16×;
  session / chat / conversation / task) and different safety (Disconnect
  confirms in one place and not in another; "Stop sharing" never confirms).
- Dead screens are still in the tree.

None of this is a visual problem. It is a structure problem, so the fix is a
structure with rules, applied in order, and checked against the ledger.

## 2. The person and the loop

From the persona: a developer away from the desk, on a phone, one-handed, in
short interrupted sessions. Their loop is:

> **Open → see what needs me → look just enough → answer or steer → leave → come back to a clear result.**

Everything on a primary screen must serve that loop. Everything else is setup
or a power tool, and belongs one deliberate step away.

## 3. The model in the person's head: four nouns

| Noun | Question it answers | Today's names |
|---|---|---|
| **Server** | Where is the agent running? | server, profile, connection, host |
| **Project** | Which code? | project, workspace, directory, folder, location |
| **Conversation** | Which piece of work? | session, chat, conversation, task |
| **Inbox** | What needs me? | activity, attention, needs you, requests |

One word per noun in the interface, everywhere. Recommendation:
**Server, Project, Conversation, Inbox.** (`/sessions` and similar stay as
typed aliases; the visible label changes.) "Workspace" is retired as a
user-facing word: it currently means the tab, the project, a cloud
environment and a worktree.

## 4. Seven rules (the "logic")

1. **One home.** Every screen and every setting has exactly one canonical
   place. The ledger records it.
2. **Doors are earned.** A shortcut to another place is allowed only where the
   person's job leads there, uses the *same label* as the canonical door, and a
   destination has at most three of them. Everything else is removed.
3. **Primary screens show the loop, nothing else.** Setup, configuration and
   diagnostics never sit on Work, Inbox or Conversation.
4. **Three layers of disclosure.** Always visible: what I need every time.
   One tap: what I need sometimes (one labeled menu, grouped). Typed/search:
   everything, for people who know what they want.
5. **One list of actions.** Menu, slash commands and the desktop palette are
   three views of one action registry (id, label, group, gate, handler, safety
   tier). An action cannot exist in one and be missing or renamed in another.
6. **Safety is a tier, not a habit.**
   - *Undoable* (archive, dismiss, unpin): act now, offer Undo for 5 s.
   - *Interrupts or loses local work* (disconnect, stop server, stop sharing,
     stop process, discard draft): confirm sheet that says what is lost.
   - *Irreversible* (delete conversation, remove server, delete message,
     reset worktree): confirm sheet naming the thing.
7. **Hide, don't disable.** If the connected server cannot do something
   (Codex, Paseo, OpenCode 1 vs 2), the row is absent. No dead rows, no
   backend names in labels unless the person must choose between them.
   ("Ask OpenCode…" in the composer becomes "Ask {agent}…".)

## 5. Target structure

### 5.1 Bottom navigation: four tabs, each one noun

| Tab | Replaces | Contains |
|---|---|---|
| **Work** | Workspace | Current project (tap to switch), *Needs you* strip, pinned and recent conversations, New conversation, Isolated task. AI Team card when the plugin is on. |
| **Inbox** (badge) | Activity | Waiting on you (permissions, questions, forms, AI Team gates) → Running → Finished (digests). Nothing else. |
| **Project** | Files | Project-scoped tools in one place: Files, Changes (review), Terminal, Health, Worktrees, Search. Rows appear only if the server supports them; the tab hides when none do. |
| **Settings** | More **and** Settings | One searchable hub (5.2). |

The server name in the app bar becomes the **server switcher** (tap → sheet:
saved servers, status, Add, Disconnect). That is the single door to Servers
while connected. The overflow menu's "Disconnect" goes away; "Model / agent"
goes away (it lives on the composer); "Refresh" becomes pull-to-refresh only.

### 5.2 Settings: one hub, eight groups, searchable

| Group | Holds (today scattered across) |
|---|---|
| **Connection** | This server, saved servers, On this phone (Termux: setup, running now, storage, services), Tailscale, accounts (Codex), External agents, server attention rules |
| **Agent setup** | Models & agents, Providers, MCP, Skills, Commands & tools, Plugins (one screen, not two), References, Web sources |
| **Conversation defaults** | Coding defaults, Approvals, Always-allowed actions, Transcript display (thinking, timestamps), Voice |
| **Notifications** | One screen: what notifies, quiet hours (once), background connection, check-ins, saved-server monitoring |
| **Appearance** | Theme, text and reader preferences (today in Files and Review) |
| **Privacy** | Privacy & permissions, telemetry |
| **Usage** | Usage and cost + Remaining usage + quota monitoring (one screen with sections) |
| **Help** | Setup guide, Keyboard shortcuts, Report a bug, Diagnostics, About |

In-context shortcuts survive only as *links into* this hub (for example the
transcript toggles stay reachable from the conversation menu, but they open
the same setting, stored once).

### 5.3 Conversation: three layers

**Always visible (target ≤ 12 controls):** back, title, running-work badge,
Review changes (only when there are changes), menu; transcript; attention card;
composer with attach, mode·model chip, Send/Stop.

**One menu, four groups** (today: 25 flat rows):

| Group | Actions |
|---|---|
| **Look** | Find, Timeline, Changes, Todos, Subagents, Results, Context |
| **Steer** | Note for the agent, Use a skill, Approvals, Retry last prompt, Compact, Run shell command |
| **History** | Revert last prompt, Restore, Fork |
| **Share & move** | Rename, Share / Stop sharing, Export, Continue on computer, Open on another phone |

**Typed layer:** slash commands and the palette list the same registry.
Slash keeps conversation-scoped actions and `@agent` delegation. Pure
navigation commands (`/themes`, `/debug`, `/status`, `/mcps`, `/connect`,
`/tools`) stay as hidden aliases for muscle memory but leave the visible list;
`/status` stops opening Settings under a misleading name.

### 5.4 First run and "not connected"

One welcome: Connect to a server · Set up on this phone · Try the demo.
Tailscale help, external agents and the guide move under Settings → Connection
and Help, reachable *after* connecting too (today they require disconnecting).

### 5.5 AI Team

Stays a plugin with one home (card on Work → AI Team). Its "needs you" items
already flow into Inbox; that is its second, earned door. No tab of its own
until it is daily-use.

## 6. Glossary (enforced by a test)

| Use | Not |
|---|---|
| Try again | Retry, Check again, Check status, Reload (for a failed load) |
| Refresh (pull gesture only) | Reload recent…, Refresh buttons on primary screens |
| Delete = the data is gone | Remove (for data) |
| Remove = forget it on this device | Delete (for a saved server, a pin) |
| Stop = end running work | Cancel, Abort |
| Disconnect = leave this server | Sign out, Close |
| On this phone | Termux setup, On-device setup, Local server, 4 more |
| Conversation / Project / Server / Inbox | session, chat, task / workspace, location / profile, host / activity, attention |

A unit test scans `app_en.arb` for the banned terms on action labels, the same
way `repository_hygiene_test` pins the non-affiliation sentence.

## 7. What gets deleted

`SessionsTab` and its two dialogs, `_DiffSheet`, `RunningAgentsStrip`,
`CatalogScreen`'s legacy bodies, the unreachable "Open session" button on the
AI Team work sheet, routes `/activity` and `/requests`, the duplicate
"Plugins" screen, and the two hard-coded English strings
(`files_screen.dart:1180`, `review_workspace.dart:2313`).

## 8. Order of work

Each phase ships on its own, keeps every feature reachable, and ends by
regenerating the ledger and comparing the numbers in section 9.

| Phase | What | Size | Risk |
|---|---|---|---|
| **0. Guardrails** | Glossary test; ledger check in the test suite (every screen in `lib/ui/screens` must be in the ledger; entry points per destination ≤ 3 reported); safety-tier helper (`confirmThen`, `undoable`) | 1–2 days | none |
| **1. Clean and make safe** | Delete dead UI; rename to the glossary; apply safety tiers to the 8 unconfirmed actions; fix the two unlocalized strings | 2–3 days | low |
| **2. One Settings** | Merge More + Settings into the hub with search; single Notifications screen (quiet hours once); single Usage screen; single Plugins; move reader prefs to Appearance with in-context links | 3–4 days | medium (many tests reference keys) |
| **3. Navigation** | Tabs → Work / Inbox / Project / Settings; server switcher in the app bar; Project tab gathers Files, Changes, Terminal, Health, Worktrees; first-run welcome trimmed; Connection group reachable while connected | 3–4 days | medium |
| **4. Conversation** | Action registry feeding menu, slash and palette; grouped menu; slash list pruned to conversation scope; always-visible set cut to ≤ 12; start splitting `chat_screen.dart` (7,486 lines) along the registry's seams | 5–7 days | high (largest file, most tests) |
| **5. Prove it** | Walk the five journeys below on a phone: large text, RTL, keyboard up, flaky network; record taps and screenshots next to the ledger | 1–2 days | none |

Phases 1–3 can run as parallel worktrees per area once phase 0 lands, because
the ledger already splits the app into 13 disjoint areas.

## 9. How we know it worked

Measured from the regenerated ledger, before → target:

| Measure | Now | Target |
|---|---|---|
| Doors to the busiest destinations (chat / Servers / model picker / Termux) | 40 / 15 / 15 / 11 | job-led only; ≤ 3 for everything except opening a conversation |
| Names for "On this phone" | 7 | 1 |
| Always-visible controls on a conversation | ~110 incl. embedded | ≤ 12 |
| Flat rows in the conversation menu | 25 | 4 groups |
| Action lists for a conversation | 3, hand-maintained | 1 registry |
| Places holding persisted preferences | 6 | 1 hub (+ links) |
| Interrupting actions without confirm or undo | 8 | 0 |
| Orphan or dead surfaces | 8 | 0 |
| Screens reachable only by disconnecting | 5 | 0 |

And five journeys, each timed in taps from a cold start: resume the last
conversation; answer a pending permission; review a change and send a
follow-up; switch project; switch server.

## 10. Decisions needed from the owner

1. **Vocabulary:** Conversation / Project / Server / Inbox as proposed?
   (Largest string churn is "session" → "conversation".)
2. **Tabs:** Work / Inbox / Project / Settings as proposed, replacing
   Workspace / Files / Activity / More?
3. **Slash commands:** hide the navigation-only commands from the visible list
   (aliases keep working)?
4. **Order:** start with phases 0–1 (safe, no layout change), then 2?
