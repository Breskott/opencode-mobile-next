# UX system taxonomy (frozen vocabulary, 2026-09-26)

The owner, after reviewing 167 screens:

> You need to review all screens and map their UI elements into kit system and create new kit as needed, also map to modules and journey types … once you map these, look at journeys and ways they intersect … if a user doesn't have this and wants to enable this, what is the flow and discoverability and expectations and limitations … then map user personas and what UI/UX should be for them … add any other verticals.

Every mapping in `docs/ux-system/` uses only the ids below, so the parts join up. Add a new id only in `proposals`, never ad hoc.

## Journey types (`journey`) — what the person is doing

| id | The person is… | Examples |
|---|---|---|
| `install` | getting something onto this phone or a host | phone setup v2, Termux path, AI Team turn-on, Claude Code, voice model |
| `connect` | reaching a server or account | Add server, pairing, Servers list, connecting/not answering, sign in to providers |
| `converse` | talking to an agent | chat, composer, voice, commands, queued messages |
| `delegate` | handing a bigger job to the AI Team | Solo · Team, team conversation, board, planning |
| `approve` | answering the agent: permissions, questions, forms, gates, merges | permission sheet, question card, gate sheet, merge section |
| `review` | checking what changed | diffs, review workspace, revert, run result |
| `observe` | watching status and what needs them | Work tab, Inbox/Activity, notifications, running now, profile monitor |
| `inspect` | reading details | files, viewers, terminal, logs, technical details |
| `configure` | changing how things work | settings, providers/models, MCP, plugins, appearance, notifications |
| `recover` | getting back from a failure | errors, offline, force stop, heat pause, restart, re-enter credentials |
| `account` | cost, usage, quota, identity | usage, provider quota, agent account |
| `learn` | understanding or being onboarded | welcome, demo, guides, help, about |

A page may carry up to 2 journey types (a primary one first).

## Modules (`module`) — the product area

`shell` (navigation, header, dock) · `work` (Work tab, projects, conversations list) · `chat` · `team` (AI Team) · `servers` · `phone` (built-in Ubuntu, Termux, on this phone) · `files` · `review` · `terminal` · `settings` · `library` (commands, integrations, MCP, plugins) · `voice` · `usage` · `system` (diagnostics, about, updates, lifecycle).

## Capabilities (`needs`) — what must exist for the page to be useful

| id | Meaning |
|---|---|
| `server.any` | connected to some server |
| `server.oc1` / `server.oc2` | an OpenCode 1 / 2 server |
| `server.codex` / `server.paseo` | Codex / Paseo (Claude Code, Pi) |
| `phone.builtin` | the built-in Ubuntu installed |
| `phone.termux` | Termux installed and allowed |
| `model.auth` | at least one model signed in |
| `team.on` | AI Team on for this server/project |
| `team.phone` | AI Team hosted on this phone |
| `claude.local` | Claude Code on this phone |
| `voice.model` | a voice model downloaded |
| `mcp.any` | MCP servers configured |
| `project.open` | a project folder chosen |
| `perm.notifications` / `perm.battery` / `perm.camera` / `perm.mic` | Android permissions |
| `network.tailscale` | the host is reached over Tailscale |

## Element kinds (`elements[].kind`)

`screen-frame` · `header` · `status-line` · `loading` · `state` (empty/error/stopped/offline) · `row` · `section-label` · `primary-action` · `secondary-action` · `tertiary-action` · `menu` · `chip` · `segmented` · `switch` · `field` · `picker` · `sheet` · `dialog` · `request-card` (permission/question/gate) · `notice` · `progress` · `card-panel` · `list` · `transcript` · `code-or-log` · `viewer` (file/diff/markdown/image) · `illustration` · `tabbar` · `badge` · `toast` · `other`.

## Kit components (`elements[].kit`) — today's kit (`lib/ui/kit/`)

KitScreen, KitButton, KitAction, KitActionBlock, KitActionStack, KitStateView, KitLoadingBar, KitSkeletonRows, KitSkeletonTranscript, KitProgress/KitProgressView, KitStatusLine, KitAskLine, KitRequestCard, KitRow (+ KitRowIcon, KitRowMenu, KitChevron, KitSwitchRow, KitExpandRow), SectionLabel, KitPanel, KitNotice, KitStatusMark, KitTaskMark, KitIllustration (+ scenes), KitGlass, KitRefresh, KitReveal, KitAnimatedRows, KitTabSwitcher, KitInset, KitMenuItem, KitHaptics, KitMotion, KitEffects.

Use `kit: "none"` for a hand-built widget, and `kitGap` with a proposed component name when no kit part fits.

## Personas (`personas`) — the people, from evidence

| id | Who | Evidence |
|---|---|---|
| `phone-only` | builds on the phone alone: built-in Ubuntu or Termux, no computer | the owner's Termux phone; issue #87's reporter ("built-in terminal instead of Termux") |
| `remote-lead` | has a computer; uses the phone to steer and approve work while away | Tailscale servers, OpenCode 2 on a computer, notifications |
| `team-delegator` | hands bigger jobs to the AI Team and watches the results | the owner's car-sharing task; "it's all about automated dev" |
| `tinkerer` | power user: several servers, MCP, commands, processes, logs | Running now, MCP, Termux processes |
| `newcomer` | first run or the demo; doesn't know the vocabulary | the welcome, demo and setup |
| cross-cutting | large text, screen reader, Arabic RTL, one hand, a slow or metered network | design standard §9, `docs/design/principles.md` |

## Verticals (`verticals`) — qualities every page is checked for

`a11y` · `rtl-l10n` · `perf` · `battery-heat` · `reliability` (offline, background limits, force stop) · `security-privacy` (credentials, links, local only) · `honest-state` · `automation-first` (the owner, 2026-09-26: manual controls are the fallback, not the way) · `help-feedback` (bug reporting, diagnostics) · `notifications` · `upgrade-migration` · `consistency-kit`.
