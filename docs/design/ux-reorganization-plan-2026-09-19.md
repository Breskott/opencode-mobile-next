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

### 5.6 Sequence: the order a person meets things

Structure says where things live. Sequence says **when** a person meets them.
The rule: *nothing is asked or shown before the moment it is needed.*

**First run, today (from the ledger):** the welcome screen offers eight
choices at once (Connect to a server, Try demo, Connect OpenCode 2, Termux
setup, and behind "More setup options": Tailscale, Setup guide, External
agents; plus About and guide icons). The person must already know what
OpenCode 1 vs 2, Termux, Tailscale and an "external agent" are before they
have seen the product do anything. After connecting they land on Workspace
with no next step; the empty conversation offers three suggestion chips and
one tip line. There is no other teaching anywhere in the app.

**First run, target: one question at a time, ending in a success.**

| Step | Screen asks | Why here |
|---|---|---|
| 1 | "Where does your coding agent run?" → **On my computer** · **On this phone** · **Just show me** (demo) | The only real fork. Three plain choices, no product names. |
| 2a | Computer: "Which agent?" → OpenCode · Claude Code / Pi (Paseo) · Codex. Then *one* screen: the command to run on the computer, and Scan / Paste / Type address | Backend choice appears only to people who said "computer", and picks the right form for them. Tailscale help is a link on this screen ("Not on the same network?"), where the problem actually occurs. |
| 2b | Phone: the existing Termux wizard (already sequential: get → connect → choose → install → running) | Keep; rename to "On this phone". |
| 3 | Test runs automatically on entry; failure shows the diagnosed cause and one fix | Today "Test connection" is a separate optional button. |
| 4 | "Pick a project" (folder chooser), skipped when the server reports one | Today the person lands on Work with "Choose a project" as one card among many. |
| 5 | Lands **inside a new conversation** with the keyboard up and three starter prompts | First success is a reply, not a dashboard. |
| 6 | After the first reply finishes: one card, "Get told when it's done?" → notification permission + background connection | Permission asked at the moment its value is obvious, not at install. |

External agents, Codex account, quota monitoring, MCP, skills: none of these
appear during first run. They are found later (5.8).

**Returning, target:** cold start goes to **Inbox if something is waiting on
the person, otherwise Work**. A notification always opens the exact
conversation or request. A failed reconnect shows the cause and keeps cached
conversations readable instead of blocking on a connecting screen.

**Interrupted:** drafts, attachments and scroll position survive leaving and
coming back (already a persona requirement; listed here because it is part of
sequence, not structure).

### 5.7 Order inside a screen

One ordering rule for every list and screen, top to bottom:

1. **What needs me** (blocked, failed, asking)
2. **What is happening now** (running)
3. **What I was doing** (pinned, then recent by last activity)
4. **What I could start** (New, Isolated task)
5. **Everything else** (archived, tools, plugins)

Applied:

- **Work:** Needs you → Running → Pinned → Recent → (New is a fixed button,
  always in thumb reach) → AI Team card → Archived. Project switcher stays in
  the header, not in the scroll.
- **Inbox:** Waiting on you → Running → Finished. Within a group, oldest
  waiting first (the thing blocked longest is first).
- **Settings hub:** groups ordered by how often a person needs them:
  Connection, Conversation defaults, Notifications, Appearance, Agent setup,
  Usage, Privacy, Help. Inside a group, most-changed first; destructive rows
  (Disconnect, Remove) always last and visually separated.
- **Menus and sheets:** the conversation menu's groups are ordered
  Look → Steer → History → Share & move (frequency, then risk). Destructive
  items are last in their group.
- **Buttons:** one primary action per screen, bottom, full width. The safe
  choice is never the visually loudest when the other choice is destructive.
- **Forms:** required before optional, optional collapsed; the field order
  matches the order the person obtains the values (address → folder →
  password is right; it is the order Paseo/Codex print them).

### 5.8 Discoverability: how hidden things get found

Moving things one step away (rule 4) only works if people can find them. Five
mechanisms, all cheap, none of them a tutorial:

1. **Search that covers everything.** The "Find settings, tools, and help"
   field in More already exists. It moves to the top of Settings and is fed by
   the action registry and the ledger, so it finds *settings, screens and
   actions* ("quiet hours", "fork", "MCP", "terminal") and jumps straight
   there. The same index backs slash commands and the desktop palette.
2. **Signposts on the primary surface.** A hidden layer always has a visible,
   labeled handle: the conversation menu button, the "/" hint in the empty
   composer, the mode·model chip. No feature is reachable *only* by a gesture
   (long-press, swipe); gestures are accelerators for something a menu also
   offers. The ledger lists every gesture-only element so this is checkable.
3. **Empty states that teach.** Every empty list says what belongs there and
   offers the one action that fills it (Inbox: "Nothing needs you. Approvals
   and questions from running work appear here."; Project → Changes: "No
   changes yet. Edits the agent makes show up here to review."). Today only
   the conversation and Activity have real empty states.
4. **Contextual, one-time nudges tied to a real moment.** Not a tour. Each
   fires once, at the moment the feature would have helped, and is dismissible:
   - third permission card for the same kind of action → "Always allow edits in
     this conversation?" (points at Approvals)
   - first finished run with file changes → "Review what changed"
   - first long wait → "Leave; you'll be notified" (if notifications are on)
   - context above ~80% → "Compact to keep going"
   - second project used → "Pin conversations you return to"
   A small registry records which nudges were shown; Settings → Help has
   "Show tips again".
5. **Capability awareness.** When a row is hidden because the connected
   server cannot do it (rule 7), Settings → Connection → This server lists
   "Available here" and "Not available on this server", so an absent feature
   has an explanation instead of looking like a bug. This matters more now
   that Codex and Paseo connections hide most of the Project tab.

### 5.9 Onboarding as stages, not a screen

| Stage | Goal | Measure |
|---|---|---|
| **0. Understand** | Know what this is before committing: welcome sentence + demo | demo reachable in 1 tap, no account, no network |
| **1. Connect** | A working connection | decisions on screen at once ≤ 3; taps from install to connected |
| **2. First success** | One reply from their own agent in their own project | time from connected to first reply; no dead-end screen between |
| **3. Stay in the loop** | Notifications + background on | asked once, after first success; accepted rate |
| **4. Grow** | Find review, approvals, models, skills, projects when needed | each nudge fires at its trigger; search finds every ledger page by its title |

The setup guide stops being a separate document-like screen: its three steps
*are* stage 1, and its "Advanced" commands live behind "Show the commands" on
the connect screen. It stays in Settings → Help for later reference.

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
| **3. Navigation and order** | Tabs → Work / Inbox / Project / Settings; server switcher in the app bar; Project tab gathers Files, Changes, Terminal, Health, Worktrees; the ordering rule (5.7) applied to Work, Inbox, Settings and menus; Connection group reachable while connected | 3–4 days | medium |
| **3b. First run** | Sequenced onboarding (5.6): one-question welcome, agent choice only on the computer path, automatic test, project pick, land in a conversation, notification ask after first success; cold start routes to Inbox when something waits | 3–4 days | medium |
| **3c. Discoverability** | Global search over settings, screens and actions; teaching empty states for every list; nudge registry with the five nudges; "Available here" capability list; remove gesture-only features | 3–4 days | low |
| **4. Conversation** | Action registry feeding menu, slash and palette; grouped menu; slash list pruned to conversation scope; always-visible set cut to ≤ 12; start splitting `chat_screen.dart` (7,486 lines) along the registry's seams | 5–7 days | high (largest file, most tests) |
| **5. Prove it** | Walk the five journeys below on a phone: large text, RTL, keyboard up, flaky network; record taps and screenshots next to the ledger | 1–2 days | none |

Phases 1–3c can run as parallel worktrees per area once phase 0 lands, because
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
| Choices on the first screen a new person sees | 8 (+2 icons) | 3 |
| Screens between "connected" and a first reply | Work → New → conversation, no guidance | lands in a conversation |
| Lists with a teaching empty state | 2 | all |
| Features reachable only by a gesture | listed by the ledger | 0 |
| Ledger pages found by search from their title | not searchable | 100% |
| Moment notification permission is asked | out of context | after first success |

And six journeys, each timed in taps from a cold start: install to first
reply (new person); resume the last
conversation; answer a pending permission; review a change and send a
follow-up; switch project; switch server.

## 10. Decisions (owner delegated them on 2026-09-19: "you decide")

1. **Vocabulary: adopted.** Server, Project, Conversation, Inbox. The visible
   word "session" becomes "conversation"; typed aliases (`/sessions`, `/new`)
   and code identifiers keep their names. Done as its own pass right after the
   phase 1 wording merge, because both rewrite the same string files.
2. **Tabs: adopted.** Work / Inbox / Project / Settings.
3. **Slash commands: adopted.** Navigation-only commands leave the visible
   list and keep working when typed.
4. **First run: adopted.** One opening question, the agent choice only on the
   "computer" path, automatic test, land in a conversation, notification ask
   after the first reply.
5. **Nudges: adopted, all five, each shown once,** with "Show tips again" in
   Settings → Help. A nudge that cannot name a concrete benefit at its trigger
   moment is dropped rather than reworded.
6. **Order: 0 → 1 → 2 → 3 → 3b → 3c → 4 → 5.** Phase 2 starts when phase 1 is
   merged, since both edit the Settings screen.

Reversible by design: every phase ships alone, and the ledger numbers in
section 9 show whether it helped.
