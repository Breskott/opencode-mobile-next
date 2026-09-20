# Working in several projects at once

Date: 2026-09-21. Status: slice 1 built; slices 2 and 3 planned.

## What is true today

- `ConnectionController` holds one project (`directory` + `workspace`). A
  switch rebuilds the transport, reopens the event stream and wipes
  conversations, approvals, questions, forms, the inbox and notifications
  (`_selectLocation`, `_clearLocationData`). `locationRevision` is read in
  about 270 places as "what I captured is stale".
- The server does not work that way. Runs in every project keep going.
- What already points the other way: every `Session` carries its own
  `directory`; `sessionsById` is a global map and only `_sessionInventoryIDs`
  says which ones belong to the current project; OpenCode 2 sends one
  server-wide event stream and the app filters the other projects out
  client-side (`Api2Gateway.openEventChannel(directoryFilter:)`); OpenCode 2's
  `/session/active` reports running conversations server-wide;
  `listGlobalSessions` lists across projects on OpenCode 1 and 2. Codex and
  Paseo bind their gateway object to one folder (`_checkLocation`), and the
  wire takes `cwd` per request.

## Slice 1 (built): the other projects are in reach

Recent projects per server (`oc.recentLocations.<profile>`), a chip strip on
Work with running counts, and "In other projects" under the current
project's conversations. Opening one switches project, as the all-projects
finder always did.

## Slice 2: what needs you, from every project

Goal: a permission or a question in project B reaches you while you look at
project A, in the Inbox tab and as a notification.

- OpenCode 2: stop dropping foreign events. Route them to a second, summary
  consumer that keeps per-project counts of running / waiting-permission /
  waiting-question / finished, keyed by the event's `location`. No second
  connection.
- OpenCode 1: `/event` is per directory. Open a light stream per recent
  project (cap 3, least recently used dropped), summary only.
- Inbox rows and notifications gain the project's name; a tap opens the
  conversation through slice 1's path. `_dismissAllCodingAlerts` on switch
  must stop withdrawing other projects' alerts.
- `ProfileMonitor` polls `recentLocations`, not one saved location.

## Slice 3: a chat carries its own project

Goal: open a conversation in project B without the rest of the app leaving
project A; two chats in two projects side by side on a tablet.

- Gateways take a location per call (`sessionPage`, `session`, prompt,
  abort, permission replies); the controller's field is the default.
  OpenCode 2 already addresses per-conversation routes without a location.
- Caches keyed by project instead of wiped: `_sessionInventoryIDs` becomes a
  map; permissions, questions, forms and the inbox derive their project from
  `sessionsById[id].directory`.
- `ChatScreen` reads its project from its conversation. `locationRevision`
  splits into "transport rebuilt" (`connectionRevision`) and a project value
  each screen holds. This is the risky part: half-done it silently turns off
  staleness protection, so it lands behind the existing guards' tests.
- Codex and Paseo stay one-project behind a capability until their gateways
  key caches by `cwd`.
