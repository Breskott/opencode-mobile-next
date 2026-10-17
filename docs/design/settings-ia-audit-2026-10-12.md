# Settings IA and UX audit, 2026-10-12

Read-only audit of Settings on `master` (a07fe4ed9). No code was changed.

## Summary

1. Settings is five groups and 21 rows built on mixed schemes (place, topic, "leftovers"). The groups do not match what people come to do: switching server, signing in to a model, checking quota and fixing notifications each take a different, non-obvious path.
2. Four "agent" things live in four homes: the row Agents (Server group), the group Agent, AI Team, and External agents (inside Tools). Four "server" things too: This server, Saved servers, In-app Ubuntu and Available on this server (Help).
3. Notifications and background is one page of six concerns (what notifies, quiet hours, watched servers, background link, battery, "what runs by itself"), and Keep running is reachable from three places. Quota alerts are set in Notifications but their threshold lives in Usage.
4. Rows look the same but behave three ways: a page, a bottom sheet (Model, Voice), or an inline switch/picker. Labels leak internals ("In-app Ubuntu", "Default shell", "Spent", "Providers and accounts" that opens two different pages).
5. Proposal: five groups of at most six rows, each answering one question: **Connections** (Servers, This phone), **AI** (Model, Providers, Usage, Tools, Agents), **Chat** (two switches, phrases, shell, voice, permissions and automation), **This app** (Notifications, Background, Appearance, Language, Privacy and data) and **Help** (Setup guide, Report a problem, About). Everything is at most two levels from Settings, except one server's own page (list, then detail). The new Usage widget page is a third section of Usage (Spent / Remaining / Widget), Android only.
6. Nothing new is needed in the kit: KitRowGroup, KitRow, KitRowValue, KitSwitchRow, KitPickerRow, KitSegmented, KitGroupNote and KitDetailsFold already cover every proposed screen.

Method: lenses applied explicitly are the IA audit (scheme/task fit, breadth and depth, label scent, consistency, findability across seeking modes, every page a front door, choices and disclosure), navigation (layering, wayfinding, utility nav), Nielsen heuristics, microcopy audit, and information density. The `ui-ux-pro-max` skill contributes only its mobile navigation rule (predictable back, overloaded nav is HIGH priority). Mobbin was available (iOS and web only, no Android); I looked at Telegram and GitHub settings. ChatGPT and Slack searches returned nothing usable, so they are not cited.

Evidence notation: `hub:N` is `lib/ui/search/search_index/hub_rows.dart`, `scr:N` is `lib/ui/screens/settings_screen.dart`, `srv:N` is `lib/ui/screens/settings/server_settings_screen.dart`, `notif:N` is `lib/ui/screens/settings/notifications_settings_screen.dart`.

---

## 1. The current tree

Settings is the third tab of the shell (Chats, Files, Settings; `home_screen.dart`). Search is the header launcher and reads the same index. From expanded widths the groups become a list pane and the chosen group's rows the detail pane. Rows the server cannot serve are removed and counted per group in a line ("N settings aren't available on this server" + Why).

Depth: 0 = Settings hub, 1 = a page the hub row opens, 2 = a page or tab inside it, 3 = deeper. Labels are the English strings from `app_en.arb`.

### Group "<server name>" (`SettingsGroup.server`)

| Row (key) | Label / value | Opens (depth 1) | Inside it |
|---|---|---|---|
| settings-category-server (scr:278, hub:9) | **This server**; subtitle is health and version, retry icon on failure | ServerSettingsScreen titled with the server name (srv:344) | d1 sections: Health, Change sign-in for {server}, Edit {server}, Check for agents again; AI setup (d2 page, review only), Run as a Linux service, Server updates / Update OpenCode; Address (details fold); Plugins on server (server_plugins_section); Disconnect from {server}; Remove {server} |
| settings-saved-servers (hub:23) | **Saved servers** | `/servers` screen | server list, per-server Connect / Edit / Details / Remove, Add server, scanner, Connect with Tailscale (d2), "On this phone" setup start |
| settings-this-phone (hub:40) | **In-app Ubuntu** (key says "this phone"; shown only once set up, Android) | ThisPhoneScreen | Start/Stop the server, Update OpenCode, Switch to OpenCode 1/2, Add tools, Claude Code on this phone, Storage, Export projects, Open a terminal, Keep running in the background, Remove OpenCode; d2: Running on this phone, Storage on this phone, Crash recovery, Reply speed diagnostics |
| settings-agents (hub:54) | **Agents** (subtitle "Agents run on the built-in server" off-phone) | AgentsScreen | the agents the phone can run (Claude Code and others), sign-in terminal, model sheet |

### Group "Agent"

| Row | Label / value | Opens | Inside it |
|---|---|---|---|
| settings-model-and-mode (hub:83) | **Model**, value the model name, subtitle "Server default" | bottom sheet (model picker), not a page | model, variant, agent |
| settings-providers (hub:96) | **Providers and accounts** | IntegrationsScreen (providers) if the server has a catalog, otherwise AgentAccountScreen (**Codex account**) | provider cards, credentials sheet, pending sign-in recovery; MCP lives in the same screen family |
| settings-tools (hub:119) | **Tools** | CapabilitiesScreen, six tabs | MCP, Commands, Tools, Skills, References, External agents (a2aTitle); MCP add/catalog/setup d3 |
| settings-ai-team (hub:138) | **AI Team**, value "On · This phone" / "Off" / "Turning on…" | openTeamSetup: Team settings when on, turn-on flow when off | team settings page |

### Group "Conversations"

| Row | Label / value | Behaviour |
|---|---|---|
| settings-show-reasoning (scr:408 area) | **Show reasoning**, "When on, the model's reasoning opens under each answer." | inline switch |
| settings-show-timestamps | **Show timestamps and usage**, "When on, each message shows its time, tokens and cost." | inline switch |
| default-shell-settings-entry | **Default shell** (hidden if the server has no shell setting) | inline choice |
| settings-phrase-chips | **Phrase suggestions**, "Your common short phrases, above the message box. Learned on this phone from what you send." | inline row with show-hidden |
| settings-voice (hub:249) | **Voice** (Android) | bottom sheet to download speech models |

### Group "This app"

| Row | Label / value | Opens | Inside it |
|---|---|---|---|
| settings-category-background (hub:262) | **Notifications and background**, value "Background: On/Off/Running now/Stopped by Android" | NotificationsSettingsScreen (notif:523) | sections: **What notifies me** (Finished runs, Approvals and questions, Check in on long runs + minutes, Quota thresholds, Send a test notification); **Quiet hours** (+ start, end); **Background** (Stay connected in the background, battery exemption); **Saved servers** (Monitor this server, Notify when attention is needed, Wi-Fi only); then embedded Keep running section, then embedded What runs by itself (team level, rules, **Always allowed actions** door), then a details fold "How watching servers works" |
| settings-category-appearance (hub:291) | **Appearance**, value Light/Dark/System | AppearanceSettingsScreen | Display: **Light or dark** (segmented), **Language** picker, **Theme**; Effects: Motion Full/Calm/Off, Glowing border while replying (+ style, colours, speed) |
| settings-category-privacy (hub:303) | **Privacy and data** | PrivacySettingsScreen | Shared with your server: Sync read state; On this device: Storage used, Clear queued prompts, Clear drafts; Privacy policy (sheet) |
| settings-category-usage (hub:317) | **Usage**, value "Spent · Remaining" | UsageHubScreen, two sections | **Spent** (UsageScreen: spend, Budgets), **Remaining** (ProviderQuotaScreen: provider quota, **Quota monitoring**); refresh action |

### Group (unlabelled) Help

| Row | Label | Opens |
|---|---|---|
| settings-setup-guide (hub:331) | **Setup guide** | GuideScreen; Try the demo is inside |
| library-report-bug (hub:345) | **Report a problem**, error-count badge | AppDiagnosticsScreen (crash reports, exit history, performance trace) |
| settings-server-capabilities (hub:359) | **Available on this server** | ServerCapabilitiesScreen (every gated feature and why) |
| settings-about-notices (hub:371) | **About** | AboutScreen: version, Copy version, Check for updates, signing certificate, Tips and shortcuts (Show tips again, Keyboard shortcuts), Open source licences (All package licenses, Bundled components), voice model licences |

### Reachable only through search or deep links (insideSettings entries)

Quiet hours, Stay connected in the background, Saved servers (monitoring), What notifies me, What runs by itself, Always allowed actions, Keep running, Light or dark, Language, Theme, Motion, Glow, Budgets, Quota monitoring, Commands / Tools / Skills / References, MCP, External agents, Plugins on this server, Disconnect, AI setup, Connect with Tailscale, Models & agents (the model picker again), Accounts (Codex), Running on this phone, Storage on this phone, Claude Code (phone page), Add server, Privacy policy, Try the demo, Show tips again, Keyboard shortcuts, voice licences, Import a session (a destination).

### Other entry points to the same things (outside Settings)

Server switcher sheet from the Chats header (`home_screen.dart:493`); connection status banner opens `/servers` (`connection_status_banner.dart:51,240`); the model picker opens from the composer, status line and nudge; chat slash commands open ServerSettingsScreen and AppearanceSettingsScreen (`chat_command_actions.dart:312,331`); Provider quota opens Notifications (`provider_quota_screen.dart:368`).

### Duplicate and near-duplicate map

| Concept | Where it appears (names differ) |
|---|---|
| Server identity and sign-in | hub "This server"; page Edit {server}, Change sign-in; Servers screen Edit; Codex account row |
| Server list | "Saved servers" row; the Chats-header switcher; "On your other servers" on Work; connection banner |
| This phone | row "In-app Ubuntu" (key this-phone); "On this phone" (Add server's way, search); "Claude Code on this phone"; Agents row; Storage on this phone; Keep running link |
| Keep running / background | hub value "Background: …"; Notifications page "Background" section; embedded Keep running section; This phone page row; Quiet hours; battery exemption |
| Quota | Usage › Remaining › Quota monitoring; Notifications › Quota thresholds ("the threshold you set in Usage") |
| Agents | hub Agents; group "Agent"; AI Team; Tools › External agents; Codex account; "Claude Code or Pi" server type; "Models & agents" screen title |
| Model | hub Model row; Models & agents; composer chip; status line |
| Privacy/data | Privacy and data (queue, drafts); Storage on this phone; Report a problem (kept errors); About › Open source |
| Per-server capability | group notes ("N settings aren't available"), Available on this server, AI setup, server Plugins |

---

## 2. Findings

Severity: critical = blocks or misleads a frequent task; major = costs most people time or trust; minor = polish.

### Critical

**C1. Frequent tasks have no single, predictable door** (IA: findability across seeking modes, single-path findability; Navigation: utility navigation must be obvious).
- Switch server: Settings › "This server" opens the *current* server's page (scr:355); the list is the second row, "Saved servers" (scr:358). The real switcher is in the Chats header (`home_screen.dart:493`), not in Settings. Four different surfaces list servers (table above).
- Model sign-in: "Providers and accounts" (hub:96) goes to either the provider list or the Codex account depending on server capability, so the same label leads to two different pages (Heuristic 4, consistency; IA: label scent). The sign-in state (connected or not) is not on the row.
- Quota: Usage is filed under "This app" (scr:466) although it is about the server's providers; its alert threshold is on a different page (notif:260, "Quota thresholds ... the threshold you set in Usage").
- Fix: Group by task (proposal section 3). Put Servers first with its value (server name and status) as the one door; make Providers show a value ("2 connected" or "Sign in needed"); keep Usage next to Providers; keep quota alerts on one page (Usage), with a one-line link from Notifications.

**C2. Notifications and background is a dumping ground** (IA: categories mutually exclusive; Density: cognitive load, progressive disclosure).
- One page holds six concerns across four stacked groups plus two embedded sub-screens (notif:535-600): What notifies me, Quiet hours, Background (live connection and battery), Saved servers (per-server monitoring), Keep running, What runs by itself, plus a details fold. A person who wants "stop the pings at night" scrolls past battery policy; a person who wants "keep working when the app is closed" must find the Background section on the same page as notification toggles.
- Keep running exists as an embedded section, as a standalone route (`keep_running_screen.dart:26` redirects into this page), as a row on This phone (`this_phone_screen.dart:1049,1181`), and as a hub value. Three routes, one concept (IA: consistency).
- "What runs by itself" (agent autonomy) is not a notification or a battery topic at all; "Always allowed actions" hides inside it and is reachable only through search (hub:158, `insideSettings`) — a dead-end for anyone browsing.
- Fix: split into **Notifications** (what notifies, quiet hours, watched servers, test) and **Background** (stay connected, battery, thermal, Keep running), and move **Permissions and automation** (What runs by itself, Always allowed actions) to the Chat group. Retire the hub's merged label and the duplicate This phone row (keep one link).

**C3. Rows look identical but behave three ways** (Heuristic 4 consistency and standards; Heuristic 6 recognition; IA: dead ends).
- Model (hub:83, `showModelPicker`) and Voice (hub:249, `_openVoice`) have a value or chevron like a door but open a bottom sheet; two rows are inline switches; Default shell and Phrase suggestions are inline controls; Providers opens one of two pages; AI Team opens settings or a turn-on flow depending on state. The user cannot predict from the row whether a tap navigates, edits or starts a setup.
- Fix: one rule per control type, visible in the row (KitRowValue for pickers and sheets, chevron only for pages, KitSwitchRow for switches). Voice: make it a page ("Voice typing": model state, download, remove) — it currently has no place to see the state, and its licences are in About.

### Major

**M1. Group scheme mixes places, topics and leftovers** (IA: organization scheme matches the task; hybrid schemes only at shallow depth).
- Group 1 is named after the server ("Laptop") yet holds Saved servers, This phone, and Agents (scr:359-364); group 2 "Agent" mixes the model, who pays, tools and the team; group 3 "Conversations" holds voice, shell and two transcript switches; group 4 "This app" holds Usage (a server/provider fact) and Notifications. Group labels are mostly nouns of different kinds (a server name, "Agent", "Conversations", "This app", none).
- Fix: five task groups, each one question: Connections / AI / Chat / This app / Help.

**M2. Four "agent" homes and four "server" homes** (IA: label scent and consistency, one term per concept; Microcopy: consistency).
- Agent: group "Agent", row "Agents" (phone-hosted agents), "AI Team", "External agents" (a tab inside Tools), "Codex account" (inside Providers), "Models & agents" (the model picker's search title, hub:`settings-models`), server type "Claude Code or Pi". A user looking for "where do I add Claude Code" has five plausible rows.
- Server: "This server", "Saved servers", "In-app Ubuntu", "OpenCode server" (srv:366), "Server" (e7SettingsUi1), "Available on this server" (Help), and the group label that is the server's own name.
- Fix: one term each. "Servers" (list) and "This phone" (the on-device server); "Agents" (page with sections AI Team, On this phone, External); "Providers" for sign-ins. Move "Available on this server" onto each server's own page.

**M3. "In-app Ubuntu" is a build detail used as a label** (Microcopy: plain language; Heuristic 2 match with the real world).
- hub:40 uses `phoneServerCardTitle` ("In-app Ubuntu") while the key, search aliases and sibling labels say "this phone". On first install the row is absent entirely (gated by `_phoneSetUp`, hub:44) and appears only under Add server › "On this phone" (hub:62): the on-phone server is discoverable from two different words in two places.
- Fix: label **This phone**, value Running / Stopped / Set up; always visible on Android (value "Not set up" opens setup), so there is one word and one door.

**M4. Settings ignores depth and wayfinding for server detail** (Navigation: always answer "where am I"; IA: breadth over depth).
- Server work spreads over 3 levels: Settings › Saved servers › server details (Edit/Details) and Settings › This server › (AI setup, Plugins, Disconnect). The same server's Edit and Change sign-in exist on both (srv:403,435 and servers screen `e7SetupEdit`). Tools adds a 6-tab strip (MCP, Commands, Tools, Skills, References, External agents) and MCP then goes to d3 setup and catalog.
- Fix: Servers (list, switch, add) › one server (everything about it). Tools shrinks to five tabs by moving External agents to Agents. Keep titles as breadcrumbs: the server page title is already the server name (srv:344), good.

**M5. The "Why" notes make the hub depend on the server's mood** (Density; Heuristic 1 visibility vs 8 minimalist).
- Each group can show "N settings aren't available on this server" (scr:530-ish `_unavailableNote`), and a separate Help row "Available on this server" duplicates it. Four notes can appear on one scroll; a hub that changes per server also changes row positions, so muscle memory fails (Heuristic 7 flexibility).
- Fix: keep rows in place and show missing ones as one muted line at the bottom of the hub ("3 settings aren't available on this server. Why"), linking to the server page's "What this server supports". Remove the Help row.

**M6. Appearance hides Language** (IA: label scent).
- Language is inside Appearance (`appearance-language`), with only Light/Dark/System as the row value (scr:462). People who need the app in Arabic (RTL) must guess "Appearance". Telegram and iOS Settings both keep Language as its own row with its value ("English", [Telegram, mobbin.com/screens/d1dbed8c-9d7f-410e-943f-91d0268bb2de]).
- Fix: separate **Language** row (value: current language, "System default"), RTL users see it at the same spot.

**M7. Privacy and data does not hold the data** (IA: categories match user mental model).
- Storage and removal are split across Privacy and data (queued prompts, drafts), This phone › Storage, About (licences, certificate), Report a problem (kept errors, crash reports), and Remove {server}/Disconnect. "Clear queued prompts" and "Clear drafts" are destructive rows on a page whose title promises policy.
- Fix: keep Privacy and data as the one place for what this phone keeps (queued prompts, drafts, read-state sync, errors kept, policy); link to This phone › Storage with one row.

**M8. Information density of the hub itself** (Density: cognitive load; Hick's law).
- 21 rows plus up to 5 notes, with 12 live values, across a single scroll; the first screen shows only server, saved servers, this phone, agents and part of Agent. The three highest-frequency actions (model, notifications, appearance) sit rows 5, 15 and 16 (scr:374, 454, 460). Two switches and two inline controls (reasoning, timestamps, shell, phrases) occupy the first-screen real estate of the Conversations group yet are set once.
- Fix: order by frequency within groups (Connections and AI first), keep switches (owner rule: visible first-page actions, not in a menu) but put them in Chat, below AI. Show value at row end for everything that has a state (Telegram: "Off", "English", [mobbin.com/screens/d1dbed8c-9d7f-410e-943f-91d0268bb2de]).

### Minor

- **m1. "Show timestamps and usage"** (scr hub row): "usage" collides with the Usage page (it means tokens and cost). Rewrite: "Show time, tokens and cost".
- **m2. "Spent" / "Remaining"** are bare nouns as section names (usageSectionSpent/Remaining). Better: "Spending" and "Left this period"; values on the hub row repeat "Spent · Remaining" which is not information. Show a real value: "$4.20 today" or "62% left" if cached, else "Not connected".
- **m3. "Default shell"** is jargon without context (Heuristic 2). Rewrite: "Terminal in new chats" or "Shell for commands"; subtitle says what it affects.
- **m4. "Providers and accounts"** double-barrelled; "Accounts" is the Codex account only. Use "Providers" and put "Codex account" as a row inside it, or "Model sign-in".
- **m5. "Run as a Linux service"** (srv:497) and "Restart OpenCode on its host" assume sysadmin vocabulary; they are conditional so low impact but belong in a Details fold (the kit has KitDetailsFold).
- **m6. Error suffix**: `e7SettingsRetryError` is "{error} Tap to retry." (srv:308,316). Check that `{error}` is always plain words (owner rule: no raw errors); if it ever carries server text it must go under Details.
- **m7. Help has no label** (scr "Help" panel `label: null`), so Report a problem and About float without a heading; consider labelling it "Help and about" to give wayfinding in the two-pane index (the index row is titled "Help").
- **m8. Setup guide and Try the demo** live in Help, while Report a problem lives next to "Available on this server": a first-run person who lands in Settings meets "Available on this server" before Setup guide.
- **m9. Search is only a header launcher.** The hub has no visible "Search settings" row; with ~60 insideSettings entries search is a primary path (IA: findability), and Telegram and iOS both put a search field at the top of Settings. A single visible row "Search settings" at the top (kit launcher) would make it discoverable (Obvious options first).
- **m10. Two-pane detail empty state** says "Choose a group of settings" (`settingsHubDetailEmpty`): fine, but at expanded width the first group should be preselected; it already falls back to the first group (scr:`allGroups.firstOrNull`), so low priority.

### What is missing

- A visible value on every state-bearing row (Providers, Notifications, Language, Privacy, Servers, Tools count).
- Provider/account sign-in status at a glance (Heuristic 1).
- One place for "Background" status that is not a subtitle of a merged page.
- Usage widget page (requested): there is no home for configuring a home-screen usage widget.
- A "what's new / version" footer on the hub (About holds it, one level down; Heuristic 6).
- Language row (above) and quick access to Add server from the Servers list top.

### What works and should stay

- Values at the row's end (scr:355-400), the section keys and KitArrival so search results land on the exact row.
- Per-server gating with a reason; Disconnect/Remove named after the target (Actions name their target); the AI Team state words.
- GitHub's Notifications page is a good model for the Notifications split: it puts the type switches inline and Working Hours (our Quiet hours) as one value row opening a small page ([mobbin.com/screens/e4cad526-3b71-49b6-b0bf-ff5e24a47d7f] and [mobbin.com/screens/e665bf8d-756a-46f9-bb10-33a8924211e0]).

### Reference patterns (Mobbin, iOS)

- Telegram Settings: one flat panel of about six rows (Notifications and Sounds, Privacy and Security, Data and Storage, Appearance, Power Saving "Off", Language "English"), then a second panel for account extras, a third for help; each row has an icon and value at the end, tab bar stays visible. [Mobbin: Telegram settings](https://mobbin.com/screens/d144a634-c6ef-4980-b641-ecac4889651d), [scrolled](https://mobbin.com/screens/d1dbed8c-9d7f-410e-943f-91d0268bb2de).
- GitHub Settings: short list (plan, feedback, legal, accounts, App Lock) with an inline "Clear cache 20 KB" action; Notifications is a separate page with inline switches and one "Working Hours" row. [Mobbin: GitHub settings](https://mobbin.com/screens/f081dfde-0b25-48fb-ad9f-846670b0c5af), [notifications](https://mobbin.com/screens/e665bf8d-756a-46f9-bb10-33a8924211e0), [working hours](https://mobbin.com/screens/e4cad526-3b71-49b6-b0bf-ff5e24a47d7f).
- Platform convention (Material 3 settings, iOS Settings): single-level list of topic rows with search at the top, a summary under each title, system language and appearance as separate rows, no more than about six rows per panel. Android's own Settings puts Notifications and Battery as siblings, not one page.

---

## 3. Proposed structure

Principles: one question per group (IA: scheme matches task), every state shown as a value (visibility of status), at most two levels from the hub except a single server's own page, one term per concept, no actions in overflow menus, every destination listed once (duplicates become links, not copies).

### New tree

Hub (Settings), top row: **Search settings** (kit launcher row).

**Group: Connections** (most frequent)
- **Servers** (value: server name · "Connected" / "Offline") – list of saved servers with switch/connect, Add server, Connect with Tailscale; tap a server for its page: Health and version, Sign-in, Edit, Check for agents again, AI setup, Plugins, Updates, What this server supports (the old "Available on this server"), Address (fold), Disconnect, Remove.
- **This phone** (Android; value Running / Stopped / Not set up) – the on-device server: Start/Stop, Update, Add tools, Storage, Export, Terminal, Remove; keep a single "Keep running" link to Background.

**Group: AI**
- **Model** (value: model name) – opens the picker sheet; row shows "Server default" as value when unset.
- **Providers** (value: "2 connected" / "Sign in") – providers and keys; Codex account appears as a row inside when the server has one.
- **Usage** (value: "62% left" or "Not connected") – sections: Spending, Left this period (Remaining + Quota monitoring), **Widget** (new, Android).
- **Tools** (value: count) – MCP, Commands, Tools, Skills, References (five tabs).
- **Agents** – sections: AI Team (state), On this phone (Claude Code and others), External agents.

**Group: Chat**
- **Show reasoning** (switch)
- **Show time, tokens and cost** (switch)
- **Phrase suggestions** (inline row)
- **Shell for commands** (value; hidden if the server has no setting)
- **Voice typing** (value: model state; page, Android)
- **Permissions and automation** – What runs by itself, Always allowed actions

**Group: This app**
- **Notifications** (value: On/Off) – What notifies me, Quiet hours, Watched servers, Test
- **Background** (value: Running / Off / Stopped by Android) – Stay connected, battery, thermal, Keep running guidance
- **Appearance** (value: Light/Dark/System) – Light or dark, Theme, Effects
- **Language** (value: English / العربية / System)
- **Privacy and data** – read-state sync, queued prompts, drafts, errors kept, policy, link to This phone › Storage

**Group: Help** (label "Help and about")
- **Setup guide** (Try the demo inside)
- **Report a problem** (badge: errors kept)
- **About** (version, updates, tips, shortcuts, licences)

Footer note (one muted line, only when something is hidden): "3 settings aren't available on this server. Why" linking to Servers › server › What this server supports.

Most frequent top-level rows (put these first in each group; given the audit evidence of how often they are reopened): Servers, Model, Providers, Usage, Notifications, Appearance, Language.

### Where the Usage widget page goes

Usage › third section **Widget** (KitSegmented already switches Spent/Remaining; add a third segment, hidden unless the Android platform capability for home-screen widgets is on). Contents: which provider and window the widget shows, refresh interval, preview, and Add to home screen. It sits with Usage because it reads the same Spending and Left-this-period data, so a person who set a budget finds the widget beside it; quota alerts stay in Usage (Quota monitoring), with Notifications keeping only a one-line link. No new top-level row.

### Old to new mapping (every current row)

| Old row / entry | New home |
|---|---|
| This server (hub:9) | Servers › the connected server |
| Saved servers | Servers (list) |
| In-app Ubuntu | This phone |
| Agents (on this phone) | Agents › On this phone |
| Model | Model |
| Providers and accounts | Providers (Codex account row inside) |
| Tools | Tools (five tabs) |
| External agents (Tools tab) | Agents › External agents |
| AI Team | Agents › AI Team |
| Show reasoning | Chat (switch) |
| Show timestamps and usage | Chat, renamed "Show time, tokens and cost" |
| Default shell | Chat, renamed "Shell for commands" |
| Phrase suggestions | Chat |
| Voice | Chat › Voice typing (page) |
| Notifications and background | split: Notifications and Background |
| Keep running (3 routes) | Background (one route; This phone keeps a link) |
| What runs by itself | Chat › Permissions and automation |
| Always allowed actions | Chat › Permissions and automation |
| Quota thresholds toggle (Notifications) | Usage › Left this period (Notifications keeps a link) |
| Appearance | Appearance (Light or dark, Theme, Effects) |
| Language (inside Appearance) | Language (own row) |
| Privacy and data | Privacy and data (+ link to Storage on this phone) |
| Privacy policy | Privacy and data |
| Usage | Usage (adds Widget section) |
| Setup guide, Try the demo | Help › Setup guide |
| Report a problem | Help › Report a problem |
| Available on this server | Servers › server › What this server supports (hub footer links to it) |
| About, Show tips again, Keyboard shortcuts, licences | Help › About |
| Disconnect / Remove {server} | Servers › server (unchanged, named by target) |
| AI setup, Plugins on this server, Linux service, Server updates | Servers › server |
| Connect with Tailscale, Add server | Servers (top actions, visible rows) |
| Models & agents (search entry) | removed as a duplicate of Model |

### Buildability (kit-only)

Every new or moved screen is composed of existing kit parts: KitScreen/KitTopBar, KitRowGroup, KitRow with KitRowValue and KitChevron, KitSwitchRow, KitPickerRow, KitSegmented for the Usage sections, KitGroupNote for the hub footer, KitDetailsFold for technical copy, KitNotice for states. New work is pages and routing only, not components; the Usage Widget preview needs one kit part if the preview is drawn (kit_chart / kit_level_meter exist to reuse). The G16 ratchet should go down because the merged Notifications page's sections shrink. Search index entries change `parent` and `group` only; hub keys (`settings-category-*`) can be kept for tests and deep links.

### Risks and open questions

- Splitting Notifications and Background changes the deep-link targets used by `keep_running_screen.dart:26` and `provider_quota_screen.dart:368`; both need to be re-pointed, and `SettingsSearchTarget.pageId` values change.
- Moving External agents into Agents touches the Tools tab enum (ToolsSection) and the capability flows (`capability_flows.dart`).
- A card sort of the 21 labels with five to eight users (or a first-click test on "where do I switch server / sign in to a model / stop night pings") would settle the contested calls: whether Usage belongs with Providers or This app, and whether Voice reads better under Chat or This app.
- The home-screen widget capability and its data source were not found in the code (no widget code was inspected); the Widget section's gating and contents are a proposal.
