# Phase 2 spec — one Settings hub

Implements section 5.2 of `ux-reorganization-plan-2026-09-19.md`. Source of
truth for what exists today: `ui-ledger/ledger.json` (pages `more`, `settings`
and the settings-area pages). Nothing is removed from the product in this
phase; rows move so that each has **one home**.

## Outcome

- The fourth tab is **Settings**. `MoreScreen` and `SettingsScreen` become one
  screen: search field on top, then eight groups in this order. A group is a
  header plus rows; a row opens its existing screen. Rows the connected server
  cannot serve are absent (rule 7), and a group with no rows is absent.
- The search field ("Find settings, tools, and help", already on More) stays
  and covers every row below, including rows inside second-level screens, by
  title and by the keywords listed here.
- Tab order, tab names and the server switcher are phase 3. In this phase the
  tab keeps its position and is only renamed **Settings**.

## Groups and rows

`from` is where the row lives today (ledger page id → element label).

### 1. Connection
| Row | Opens | From | Gate |
|---|---|---|---|
| This server (name, status, "Try again" on failure) | `server-settings` | settings → connection summary + Server | — |
| Saved servers | `servers` | server-settings → Manage server profiles | — |
| On this phone | `termux-setup` | more → Termux setup | `supportsTermux` |
| Accounts | `agent-account` | servers → profile menu → Codex account | agent-socket backend with an account |
| External agents | `external-agents` | servers → More setup options | — |
| Connect over Tailscale | `tailscale-setup` | servers → More setup options | `supportsTailscaleHandoff` |
| Disconnect (last, separated) | shared confirm sheet | settings → Disconnect | connected |

Inside `server-settings`, keep: health check, Run as a Linux service, server
update rows. "Manage server profiles" leaves that screen (it is now a sibling).

### 2. Conversation defaults
| Row | Opens | From |
|---|---|---|
| Model and mode | model picker | coding-settings → Selected model / Selected agent (two rows become one) |
| Default shell | shell sheet | coding-settings |
| Approvals | approvals sheet | chat session menu → Approvals (menu keeps a link to this same setting) |
| Always allowed actions | `saved-permissions` | privacy-settings |
| Transcript display (thinking, timestamps) | toggles | chat session menu → Display and context (menu keeps the toggles; same stored values) |
| Voice | voice settings | chat composer / prompt tools |

`coding-settings` as a separate screen goes away; its rows are this group.

### 3. Notifications (one screen: `notifications-settings`)
Sections, top to bottom:
1. **What notifies me** — finished runs, approvals and questions, check-ins on
   long runs (+ "Check in after"), quota thresholds.
2. **Quiet hours** — one start/end pair. Replaces the two separate
   definitions in `profile-monitor` and `quota-monitor`
   (`Quiet hours: 22:00–08:00` becomes this shared pair; migrate stored values:
   if the profile-monitor pair exists use it, else the fixed 22:00–08:00 when
   the quota toggle was on).
3. **Background** — Stay connected in the background, battery access, service
   state (today `background-settings`).
4. **Other saved servers** — Monitor this server, Notify, Wi-Fi only (today
   `profile-monitor`; its live attention list stays reachable from Inbox).

Wi-Fi-only exists twice today (profile monitor, quota monitor): one toggle,
"Check in the background on Wi-Fi only".

### 4. Appearance
Light or dark, Theme, Language (today `appearance-settings`) **plus** reader
preferences that today live in Files and Review (text size, wrap, line
numbers…). Files and Review keep a "Reading options" link that opens this
section; values are stored once.

### 5. Agent setup
| Row | Opens | From | Gate |
|---|---|---|---|
| Models | `catalog` (models body) | more → Models & agents | `serverCatalog` |
| Providers | `integrations` (Providers) | more → Providers | `serverCatalog` |
| MCP servers | `integrations` (MCP) | more → MCP | `serverCatalog` |
| Commands, tools, skills, references | `capabilities` | more → Commands & tools | `serverCatalog` |
| Plugins | **one** screen | more → Plugins (`plugins`) + settings → Plugins (`plugins-settings`) | either gate |
| Import conversation | `session-import` | more → Import conversation | `sessionImportExport` |

**Plugins merge:** one screen titled Plugins with two sections: "In this app"
(AI Team · Gas City, from `plugins-settings`) and "On the server" (server
plugin inventory, from `plugins`, shown only with `pluginInventory`).

### 6. Usage (one screen with two sections)
"Spent" (today `usage`) and "Remaining" (today `provider-quota`). Quota
monitoring's alert threshold stays here; its notification toggles move to
Notifications. `quota-monitor` as a separate screen goes away.

### 7. Privacy
Sync read state, Clear queued prompts, Clear drafts (today
`privacy-settings`), telemetry choice if present. "Always allowed actions"
moves to Conversation defaults (it is about how the agent works, not privacy).

### 8. Help
Setup guide, Keyboard shortcuts (desktop), Report a bug, App diagnostics,
"Available on this server" (new in phase 3c; placeholder omitted until then),
About (privacy and data use, voice licenses, open source notices).
`diagnostics-settings` and `about-settings` as one-row pass-through screens go
away.

### Leaves the tab
- **Terminal** (more → Terminal): belongs to the Project tab (phase 3). Until
  then it stays as the last row of Agent setup so nothing is lost.

## Search keywords (beyond row titles)
server: host, url, password, profile · phone: termux, local, on-device ·
notifications: alerts, quiet, battery, background, check-in · appearance:
theme, dark, language, arabic, font · models: provider, api key, mcp, tools,
skills · usage: cost, tokens, budget, quota, limit · privacy: drafts, queue,
read state · help: guide, bug, diagnostics, version, licenses

## Compatibility
- Keep existing `ValueKey`s on rows that survive, so tests and any deep links
  keep working; add keys `settings-group-<name>` for groups.
- Routes that opened `MoreScreen` or `SettingsScreen` open the hub; a route
  argument may name a group to scroll to.
- Slash commands that navigate (`/themes`, `/debug`, `/status`, `/mcps`,
  `/connect`, `/tools`) point at the new rows.

## Done when
- Ledger regenerated: pages `more` and `settings` are one page; places holding
  persisted preferences = 1 hub (+ links); one Plugins page; one quiet-hours
  definition; no one-row pass-through screens.
- Every row reachable by search from its title and keywords (test).
- Stored quiet-hours values migrate (test with both legacy shapes).
- Large text (2.5×), RTL and 320 dp captures of the hub.
- Full suite green.
