# Plugin architecture — how AI Team fits without touching the OpenCode gateway

This refines the research proposal
(`docs/research/control-plane-2026-09-10/architecture-proposal.md`) into a
plugin shape. Nothing here is code; every name is a proposal to be used
verbatim by the beads.

## 1. What "plugin" means in this app

The app has no runtime plugin loader and should not grow one. "Plugin" means:

1. **Off by default, per server.** A `ServerProfile` field
   `orchestration: OrchestrationConfig?` (null = off). Fields:
   `provider` (`gascity` | `fixture`), `url`, `city`, `hostMode`
   (`computer` | `phone`), `front` (bool), `enabledAt`.
2. **Its own domain and state.** `lib/domain/orchestration_gateway.dart`
   (composed role interfaces + `OrchestrationCapabilities` const class),
   `lib/orchestration/{models,events,client,adapters}`, and
   `lib/state/orchestration.dart` (`OrchestrationController`). It is a
   sibling of `ConnectionController`, constructed and disposed by it, never
   another thousand lines inside it.
3. **Capability-gated UI.** Every widget checks
   `orchestration?.capabilities.x` the way the app checks
   `ServerCapabilities`. With the config null, the widgets do not exist in
   the tree — not hidden, absent — so the "plugin off" regression test is a
   tree assertion.
4. **Its own copy, tests, fixture and docs.** `teamUi*` keys, `test/team_*`,
   `tool/qa/gascity_fixture/`, `docs/qa/ai-team/`, `docs/ai-team-host.md`.
5. **Removable without a trace.** Turning it off drains its stores, deletes
   `oc.orchestration*.<profileId>` keys and secrets, and participates in the
   existing profile-deletion sweep.

## 2. Module map

```
lib/
 ├── domain/orchestration_gateway.dart          interfaces, capabilities, MutationReceipt
 ├── orchestration/
 │    ├── models/   project.dart run.dart work.dart agent.dart gate.dart activity_event.dart usage.dart
 │    ├── events/   orchestration_event.dart (sealed union + Unknown), cursor.dart
 │    ├── client/   http.dart (Dio + problem+json), sse.dart (Last-Event-ID, heartbeat, backoff)
 │    └── adapters/
 │         ├── gascity/  dto/ (generated subset), gascity_gateway.dart, gascity_mappers.dart, gascity_probe.dart
 │         ├── fixture/  fixture_gateway.dart (reads tool/qa/gascity_fixture recordings; tests only)
 │         └── none.dart NullOrchestrationGateway
 ├── state/
 │    ├── orchestration.dart                    OrchestrationController
 │    └── orchestration_store.dart              cache + cursor persistence per profile
 ├── termux/team_runtime.dart                   (Sprint C) manager.sh verbs for gc
 └── ui/
      ├── screens/team/  team_home_screen.dart run_screen.dart agent_screen.dart work_sheet.dart gate_sheet.dart work_graph.dart
      ├── widgets/team_card.dart                 Workspace card
      └── screens/settings/plugins_screen.dart   More › Plugins
contracts/gascity-supervisor-openapi-v0-<sha>.json
tool/qa/gascity_fixture/                         Python stdlib server + recordings
tool/host/cp_front/                              (Sprint B) Python stdlib front
```

## 3. Capabilities (flat const class, like `ServerCapabilities`)

`OrchestrationCapabilities { projects, runs, runSteps, workGraph, workReady,
agents, agentOutput, sessionLink, gatesInteractions, gatesBeads, usage,
eventStream, eventReplay, controlRespond, controlMessage, controlAgent,
controlCancelRun, controlAssign, changes, verification, mergeReadiness,
phoneHost }`. Per adapter constants: `gascityReadCapabilities`,
`gascityFrontCapabilities` (adds control*), `fixtureCapabilities` (all
true), `noneCapabilities` (all false).

## 4. State model (total, explicit)

| Product state | Gas City source |
|---|---|
| Work: Queued / Ready / Working / Waiting / Blocked / Needs input / Review / Failed / Completed / Cancelled | bead `status` × `is_blocked` × session `waiting` × label `needs-review` × run-step `last_error` × `closed_reason=cancelled` |
| Run: Planning / Working / Waiting / Blocked / Failed / Completed / Cancelled | formula run status; convoy = Batch with derived status |
| Agent: Working / Idle / Waiting / Blocked / Stopped / Crashed | agent + session state |
| Gate: Choice / Confirmation / Free text / Gate bead / Run failed / Review ready | pending interaction `kind`; gate bead; run `failed`; label |

Unknown values map to `unknown` with the raw string kept for Technical
details; they never crash a list.

## 5. Events and refresh doctrine

Same as OpenCode 2: an event marks scopes dirty (`runs`, `run:<id>`,
`agents`, `agent:<id>`, `gates`, `activity`), the controller refetches on a
short debounce, the timeline is append-only from events. Cursor (`seq`)
persisted per profile; resume with `Last-Event-ID`; head-only replay →
refetch all. Stream status feeds the same `ConnectionStatusBanner` states.

## 6. Writes

Only via `OrchestrationControlGateway`, only when `capabilities.control*`.
Every mutation: client UUID idempotency key persisted before send; receipt
resolved by the matching `request.result` event or a timeout to `pending`;
never auto-retried; destructive ones behind the existing two-step sheet.
Transport: computer host → the front on the host, plain HTTP on the tailnet
address (identity header, grant minted host-side); phone host → loopback per
the spike's finding (TEAM-002).

## 7. Security rules carried into beads

- Allow `http://` only to loopback and tailnet addresses (100.64.0.0/10,
  `*.ts.net`); refuse it anywhere else. Owner decision 2026-09-10: no
  Tailscale Serve, no HTTPS certificates, never Funnel — WireGuard already
  encrypts and authenticates the hop, and a public certificate would put the
  hostname in Certificate Transparency logs.
- Host identity (provider, version, city, TLS host) visible on the card
  and in Settings.
- No secret in logs, notes, fixtures or bug reports; request ids are fine.
- PRIVACY.md paragraph: what the plugin reads from the host and what it
  stores on the phone.

## 8. Testing strategy

- Unit: mappers (state table is exhaustive), SSE parser, idempotency store.
- Widget: every screen at 1x and 320dp/2.5x LTR+RTL, every state L/E/S/X/N.
- Fixture: `tool/qa/gascity_fixture/` serves recorded responses from a real
  Gas City (CP-001) plus scripted event logs (normal run, blocked, failed,
  stream drop + resume).
- Regression: plugin-off tree assertion; plugin-on adds no new calls to
  `ServerGateway`.
- Real: read proof against Gas City on the PC (Sprint A), write proof via
  the front (Sprint B), phone-host proof on the emulator rootfs and then the
  phone (Sprint C).

## 9. What stays out of the code base

No shelling to `gc`/`bd` from Dart on the computer path; no dashboard
re-implementation; no generic command runner; no embedding in
`ServerGateway`; no `ConnectionController` growth beyond constructing and
disposing the sibling controller and contributing the attention count.
