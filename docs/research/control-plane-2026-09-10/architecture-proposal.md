# Architecture proposal — `OrchestrationGateway` and the Gas City adapter

Status: proposal for owner review. Grounded in [gas-town-findings.md](gas-town-findings.md) and the current codebase (`lib/domain/server_gateway.dart`, `lib/state/connection.dart`, `lib/state/profiles.dart`, `lib/api2/*`). Nothing here is implemented.

## 1. Fit with the existing architecture

The app already separates a protocol-neutral domain interface from two transports:

- `ServerGateway` / `ServerOperationsGateway` (`lib/domain/server_gateway.dart`) are *composed* role interfaces (`HealthGateway, SessionGateway, PromptGateway, PermissionGateway, QuestionGateway, FormGateway, InboxGateway, …`), not sub-gateway getters. Optional roles are extra interfaces the adapter may implement (`SessionRetryGateway`, `CorrelatedPromptGateway`, `SessionImportGateway`).
- Capabilities are a flat, all-`final bool`, const value class (`ServerCapabilities`, ~55 flags; per-backend constants `api2ServerCapabilities`, `codexServerCapabilities`). UI gates with inline `if (controller.capabilities.x)`; AGENTS.md rule: "Gate features on `ServerCapabilities` flags, never on the flavor enum".
- Live updates use `EventGateway.openEventChannel(onEvent, onStatus, onError)` returning a `LiveEventChannel` with `StreamStatus {connecting, connected, reconnecting, disconnected}`; v2 doctrine is "reconcile by refetch, never replay" for the volatile stream.
- Transport selection lives in `ConnectionController._buildTransportPair(ServerProfile)` with injectable factories; protocol detection is `probeServerConnection` (`lib/api/server_probe.dart`).
- Profiles (`ServerProfile`) hold `baseUrl`, Basic-auth `username/password`, backend enum, flavor; secrets go to `FlutterSecureStorage` under `oc.<what>.<profileId>` keys so `removeScopedPreferences` can sweep them.

The orchestration domain mirrors all of that one-for-one, as a *sibling* of the OpenCode gateway (BRD §34/§56), never embedded in `lib/api` or `lib/api2`.

```
lib/
 ├── domain/
 │    ├── server_gateway.dart            (unchanged)
 │    └── orchestration_gateway.dart     NEW — interfaces + models-agnostic capability flags
 ├── orchestration/
 │    ├── models/                        NEW — Project, Run, Work, Agent, Gate, ActivityEvent, Usage (product vocabulary)
 │    ├── events/                        NEW — OrchestrationEvent union + envelope, cursor types
 │    ├── client/                        NEW — HTTP+SSE plumbing shared by adapters (Dio + SSE parser, problem+json errors, request-id correlation)
 │    └── adapters/
 │         ├── gascity/                  NEW — Gas City supervisor API v0 adapter (DTOs generated from the pinned spec)
 │         ├── fixture/                  (test-only) reads tool/qa/gascity_fixture recordings
 │         └── none.dart                 NullOrchestrationGateway (capabilities all false)
 ├── state/
 │    └── orchestration.dart             NEW — OrchestrationController (ChangeNotifier), mirrors ConnectionController's revision guards
 └── ui/  … Workspace / Run detail / Work list / Agents / Activity additions, all capability-gated
contracts/
 └── gascity-supervisor-openapi-v0-<commit>.json   pinned spec snapshot (like contracts/opencode2-openapi-beta-18600.json)
tool/qa/gascity_fixture/                Python-stdlib fixture server (like tool/qa/codex_fixture/)
```

## 2. `OrchestrationGateway` (domain interface)

Composed role interfaces, same style as `ServerGateway`. Sketch (names are proposals; signatures deliberately mirror existing ones like `ServerPage<T>`):

```dart
abstract class OrchestrationGateway
    implements OrchestrationHealthGateway, ProjectGateway, RunGateway, WorkGateway,
        AgentGateway, GateGateway, OrchestrationActivityGateway, UsageGateway,
        OrchestrationEventGateway {
  OrchestrationCapabilities get capabilities;
  OrchestrationEndpointIdentity get identity;   // host, provider, version, city/project scope
  bool get isClosed;
  void close();
}

abstract class OrchestrationHealthGateway {
  Future<OrchestrationHealth> health();        // {provider, version, uptime, ready, readOnly}
}
abstract class ProjectGateway {
  Future<List<Project>> listProjects();        // Gas City: cities × rigs
}
abstract class RunGateway {
  Future<ServerPage<RunSummary>> runPage({String? projectId, RunStatusFilter? status, String? cursor, int limit = 50});
  Future<RunDetail> run(String runId);          // includes steps
}
abstract class WorkGateway {
  Future<ServerPage<Work>> workPage({String? projectId, String? runId, WorkStatusFilter? status, String? cursor, int limit = 100});
  Future<Work> work(String id);
  Future<WorkGraph> workGraph(String rootId);   // nodes + blocks/needs edges
}
abstract class AgentGateway {
  Future<List<Agent>> listAgents({String? projectId});
  Future<AgentDetail> agent(String agentId);   // identity, runtime, current work, last output
  Future<List<String>> agentOutput(String agentId, {int lines = 80});
}
abstract class GateGateway {
  Future<List<Gate>> pendingGates({String? projectId}); // union of pending interactions, open gate beads, waits, human-addressed mail
}
abstract class OrchestrationActivityGateway {
  Future<ServerPage<ActivityEvent>> activityPage({String? projectId, String? runId, ActivityFilter? filter, String? cursor, int limit = 100});
}
abstract class UsageGateway {
  Future<Usage?> usage({String? projectId});   // null when provider has no cost data
}
abstract class OrchestrationEventGateway {
  LiveEventChannel openActivityChannel({
    required void Function(OrchestrationEvent) onEvent,
    required void Function(StreamStatus) onStatus,
    void Function(Object)? onError,
    String? afterCursor,
  });
}

// Mutations are a separate composed interface, only implemented when the adapter has write authority.
abstract class OrchestrationControlGateway {
  Future<MutationReceipt> assignWork({required String workId, required String agentId, String? formula, Map<String, String>? vars, required String idempotencyKey});
  Future<MutationReceipt> closeWork(String workId, {String? reason, required String idempotencyKey});
  Future<MutationReceipt> reopenWork(String workId, {required String idempotencyKey});
  Future<MutationReceipt> respondToGate(String gateId, GateResponse response, {required String idempotencyKey});
  Future<MutationReceipt> messageAgent(String agentId, String text, {required String idempotencyKey});
  Future<MutationReceipt> agentAction(String agentId, AgentAction action /* stop, kill, wake, suspend, reset */, {required String idempotencyKey});
  Future<MutationReceipt> cancelRun(String runId, {required String idempotencyKey});
}
```

Notes
- `OrchestrationCapabilities` is a flat const value class like `ServerCapabilities`: `runs, runSteps, workGraph, workReady, agents, agentOutputStream, sessionsLinked, gatesInteractions, gatesBeads, waits, mail, usage, eventStream, eventReplay, controlAssign, controlCloseWork, controlRespond, controlMessage, controlAgentLifecycle, controlCancelRun, changes, verification, mergeReadiness`. Per-adapter constants (`gasCityReadOnlyCapabilities`, `gasCityWithFrontCapabilities`, `fixtureCapabilities`, `noneCapabilities`).
- Product models carry both the product word and the raw provider object (`Work.raw: Map<String, dynamic>`), so an "advanced terminology" toggle (BRD §50) can show `gc` names without a second model.
- State mapping is explicit and total, never inferred from chat activity (BRD §14): Gas City `Bead.status open + is_blocked=true → Blocked`, `open + !is_blocked → Ready`, `in_progress → Working`, `closed → Completed`, `deferred → Queued`; `issue_type=gate && status=open → Gate`; `RunStepStatus` maps 1:1 (`blocked → Blocked`, `pending → Queued`, `active → Working`); `RunStatus.waiting → Waiting`, `canceling|canceled → Cancelled`, `failed → Failed`. "Needs input" = a pending interaction on the agent's session, or an open gate bead blocking the step. "Review" = label/`metadata` convention to be agreed with the owner (Gas City has no review state).
- Events: `OrchestrationEvent` is a sealed union with an `UnknownOrchestrationEvent` fallback (same approach as `Api2Event`'s `UnknownApi2Event`), keyed by the provider's semantic `type` (`bead.closed`, `session.crashed`, `request.result.*`…). The controller applies the v2 doctrine: an event marks scopes dirty; state is refetched, not patched from payloads, except for append-only timeline entries.

## 3. Gas City adapter (`lib/orchestration/adapters/gascity/`)

- Base URL = supervisor listener (default `http://127.0.0.1:8372` on the host → exposed on the Tailscale address). City discovery: `GET /v0/cities` → pick the single running city or let the profile pin `cityName`. Readiness rule: per-city calls only after `running=true`; otherwise show "starting".
- Headers: none for reads. Every mutation sets `X-GC-Request: ocmn` and, when the profile carries a grant source, `X-GC-City-Write: <grant>` obtained from the sidecar (never minted on the phone; the ed25519 key stays on the host — Gas City's own model).
- Errors: parse `application/problem+json`, switch on `code` (`bead-not-found`, `validation-failed`, `read_only`, `in_flight`, `conflict`), surface `X-GC-Request-Id` in the error sheet for bug reports.
- Async mutations: `202 {request_id, event_cursor}` → the adapter subscribes `/events/stream?after_cursor=…` and resolves the `MutationReceipt` on `request.result.*` / `request.failed` with matching `payload.request_id`. Timebox it; if the stream drops, the receipt becomes `pending` and the UI shows "submitted, awaiting confirmation" — never re-POSTs automatically.
- SSE: reuse the parser design from `lib/api2/sse2.dart` (`Sse2Parser`) but as `lib/orchestration/client/sse.dart`; honour `event: heartbeat`, send `Last-Event-ID`, reconnect with backoff, and treat a gap as "refetch dirty scopes".
- Mapping to product models is one file (`gascity_mappers.dart`), like `lib/api2/gateway_mappers.dart`, so the DTO layer can be regenerated from the pinned spec without touching UI.
- DTO generation: the spec is huge (557 schemas). Generate only the ~25 DTOs the adapter uses (Bead, Run, RunStep, AgentResponse, SessionResponse, SessionPendingResponse, PendingInteraction, SlingInputBody/Response, ConvoyGetResponse, WaitView, UsageBody, EventStreamEnvelope + used payloads, ErrorModel, HealthOutputBody, city list items) into `packages/` or `lib/orchestration/adapters/gascity/dto/`, with a `tool/` script that re-derives them from `contracts/gascity-supervisor-openapi-v0-<commit>.json`. Do not hand-edit generated files (same rule as `packages/opencode_sdk/`).

## 4. The host-side "control-plane front" (thin sidecar)

Gas City already provides the durable model and the typed read API, so the sidecar is deliberately small. It exists for four reasons the supervisor does not cover:

| Responsibility | Why the supervisor cannot do it | Sidecar behaviour |
|---|---|---|
| **Authenticated mutations for a phone** | Writes need a signed `X-GC-City-Write` grant minted with an operator-held ed25519 key; the dashboard/gc client cannot mint one; Basic auth is not a Gas City concept | Listens only on loopback behind `tailscale serve`; checks `Tailscale-User-Login` and confirms it with `tailscale whois <x-forwarded-for>`; if the login is on an allowlist, mints a grant with `gc-write-mint` (or the same signing code) and forwards the mutation to the supervisor. Adds the app's idempotency key → `request_id` mapping so a retried POST returns the earlier receipt. |
| **Changes per Work/worktree** | No diff API in Gas City | `GET /changes?bead=<id>` / `?worktree=<path>` → files changed, `+/-`, unified diff, computed with `git -C <work_dir> diff <default_branch>...HEAD` using `SessionResponse.work_dir` / bead `metadata.gc.work_dir`. Read-only git; never writes. |
| **Verification results** | Formula `check` steps and CI are not queryable as "tests passed 182/182" | `GET /verification?run=<id>` aggregating: check-step bead outcomes (`RunStep.status` + `last_error`), optional `gh run list` for the branch, and a project-configured command allowlist (`flutter analyze`, `flutter test`) executed by an *order*, never on demand from the phone. |
| **Merge readiness** | Merge is pack-level | `GET /merge-readiness?run=<id>` = all steps completed + MR bead / `gh pr view --json mergeable,statusCheckRollup` + no open gates. `POST /merge` is out of scope until the owner picks a merge strategy. |

Everything else (runs, work, agents, sessions, events, usage) the phone reads **directly from the supervisor**; the sidecar is not a proxy for the 164 operations. If the owner prefers a single endpoint, the sidecar can reverse-proxy `/v0/*` read routes unchanged (pass-through, no re-shaping), which keeps the adapter identical.

Suggested implementation: one Go binary (shares Gas City's generated Go client and the grant-minting code) or a Python-stdlib service in the same spirit as `tool/qa/codex_fixture/fixture_server.py`; ~6 routes; JSON; SSE pass-through for `/events/stream`. It should refuse to start if it is not behind loopback + `tailscale serve`, mirroring Gas City's fail-closed boot matrix.

Discovery: the sidecar serves `GET /.well-known/opencode-mobile-orchestration` → `{provider:"gascity", supervisorUrl, cityName, front:true, version, capabilities:{…}}`. Alternative when no sidecar: the app probes `GET /health` on the supervisor URL and recognises Gas City by the `{city,status,uptime_sec,version}` shape plus `GET /v0/cities`. The OpenCode server itself has no way to advertise a foreign endpoint (v2's discovery is `~/.local/state/opencode/service.json`, local-only), so "OpenCode server config" discovery is **not** available; manual entry remains the fallback (BRD §38).

## 5. Connection model

- `ServerProfile` gains optional fields: `orchestrationUrl` (String?), `orchestrationProvider` (enum `none|gascity|fixture`), `orchestrationCity` (String?), `orchestrationFront` (bool: reads go to `orchestrationUrl`, writes to `<front>/…`). Secrets, if any (a front bearer token as a fallback where Tailscale identity headers are unavailable), go to secure storage under `oc.orchestrationToken.<profileId>`.
- `ConnectionController` gets an `OrchestrationController` sibling (not another 1,000 lines in the same file — the 2026-08-29 audit already flags `ConnectionController` size). It owns: gateway construction from the profile, `connectionRevision`-style guards, dirty-scope refetch, attention count contribution (`unifiedAttentionCount += orchestration.pendingGates.length`), and the activity channel lifecycle (start on foreground, dispose on background — battery, BRD §51).
- Cleartext rule: refuse `http://` to non-loopback orchestration hosts exactly as `gc` does; the Android `network_security_config.xml` loopback allowlist already exists. Tailscale MagicDNS hosts count as non-loopback; the owner must front them with TLS (`tailscale serve` provides it).
- Identity display: connection sheet shows provider, version (`/health.version`), city name, `readOnly` (derived from a 403 `read_only:` probe or the front's capability document), and whether writes are grant-backed.

## 6. Offline and idempotency rules

- Reads: last snapshot cached per profile+city (Hive/prefs like existing stores); shown with the existing `ConnectionStatusBanner` "stale" treatment; every list carries `fetchedAt`.
- Live: SSE `seq` cursor persisted per profile; on reconnect send `Last-Event-ID`; if the server replays nothing (head-only), mark all scopes dirty and refetch.
- Mutations: all `OrchestrationControlGateway` methods require a client-generated `idempotencyKey` (UUID) persisted *before* the request leaves the device — the `dispatchedAt` pattern from `lib/state/offline_queue.dart`. A dispatched mutation with no receipt is shown as "sent, unconfirmed" and is **never** auto-retried; the user can re-send explicitly. The front maps `idempotencyKey → request_id` so an explicit re-send is safe; against a bare supervisor (no front) re-sends are refused for non-idempotent operations (`sling`, `close`) and allowed for naturally idempotent ones (`respond` with the same `request_id`).
- Offline queueing of orchestration mutations is **not** in scope (BRD §33 allows "disabled or explicitly queued"; choose disabled).
- Destructive actions (kill session, cancel run, delete work, reap worktree) require the two-step confirmation sheet and are hidden entirely unless `capabilities.control*` is true.

## 7. Capability matrix per provider

| Capability | Gas City direct (read-only) | Gas City + front | Fixture | ralph-tui (via Beads journal, future) | OpenCode 2 alone |
|---|---|---|---|---|---|
| Projects | yes (`/rigs`) | yes | yes | one repo | projects (existing) |
| Runs + steps | yes (`/runs`) | yes | yes | epic = run [I] | no |
| Work list / ready / graph | yes | yes | yes | yes (`bd --json`) | no |
| Agents (provider, model, context %) | yes | yes | yes | one agent | subagent sessions (existing) |
| Agent live output | yes (SSE) | yes | yes (scripted) | no | session stream (existing) |
| Gates: pending interactions | yes (read) | respond | yes | no | permissions/forms (existing) |
| Gates: gate beads / waits | yes (read) | close | yes | no | no |
| Activity stream (seq, resume) | yes | yes | yes | journal (`bd events tail`) [V] | SSE (existing) |
| Usage / cost | yes (`/usage`) | yes | yes | no | provider quota (existing) |
| Assign / start work (sling) | no | yes | simulated | no | no |
| Message / nudge agent | no | yes | simulated | no | prompt (existing) |
| Stop / wake / cancel run | no | yes | simulated | no | abort (existing) |
| Changes / diffs | no | yes (git) | canned | no | VCS diff (existing) |
| Verification | no | partial | canned | no | no |
| Merge readiness / merge | no | readiness only | canned | no | no |
| Link Agent → OpenCode session | [U] | [U] | canned | n/a | n/a |

## 8. What this proposal does not do

- No Dart code that shells out to `gt`, `gc`, or `bd` from the phone; no Termux-hosted supervisor assumptions.
- No re-implementation of Gas City's dashboard; no generic "run any gc command" control.
- No planning UI ("objective → plan"): v1 lets the user sling text to the configured planner agent (Mayor) and watch beads appear; plan editing is bead editing.
- No embedding of orchestration into `lib/api`/`lib/api2` or `ServerGateway`.
