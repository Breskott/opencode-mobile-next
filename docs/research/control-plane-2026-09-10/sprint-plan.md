# Sprint plan — control plane vertical slice (3 sprints)

Written for the ralph-tui + beads workflow (one epic per sprint, 6–15 child beads, each sized to one agent context window, explicit acceptance criteria as checkboxes, quality gates appended, an Impact Table per bead, dependencies wired with `bd dep add <child> <depends-on>`). IDs are planning identifiers, not delivery commitments (docs/backlog/README.md convention). Conventions from AGENTS.md apply to every bead: pinned Shorebird Flutter 3.47.x, `flutter analyze` clean with no new ignores, `flutter test --concurrency=1` for touched suites, UI talks to domain gateways only, gate features on capability flags, `[skip ci]` on commit messages while that instruction stands, `.claude/` never committed.

Universal quality gates (append to every bead):
- [ ] `flutter analyze` reports 0 issues
- [ ] `flutter test --concurrency=1 <touched test files>` passes
- [ ] No UI import of `lib/orchestration/adapters/*` or `lib/api*/` (domain only)
- [ ] New per-profile prefs keys follow `oc.<what>.<profileId>`

UI-only gate: `[ ] Screen renders at 360×640 without overflow (golden or widget test)`.

---

## Sprint 1 — read-only vertical slice on a fixture (Epic CP-1)

Goal: with a fixture server on loopback, a profile with an orchestration endpoint shows a Workspace summary card, Run detail, Work list, Agents list, and orchestration items in Activity. No mutations. No real Gas City required.

Exit criterion: `adb reverse` + `python3 tool/qa/gascity_fixture/fixture_server.py` + the app on a phone shows all five surfaces with live SSE-driven updates; a recorded smoke run in `docs/verification/`.

### CP-101 Pin the Gas City supervisor spec and generate DTOs
As a maintainer I want the supervisor OpenAPI snapshot pinned so adapters never drift silently.
- [ ] `contracts/gascity-supervisor-openapi-v0-<commit>.json` added (raw from `docs/reference/schema/openapi.json` at a named commit) with the commit hash recorded in `docs/opencode2-port-plan.md`-style notes
- [ ] `tool/gen_gascity_dto.dart` (or `.py`) emits Dart DTOs for exactly: Bead, Run, RunStep, RunStatus, RunStepStatus, RunScope, RunLastError, AgentResponse, SessionInfo, SessionResponse, SessionPendingResponse, PendingInteraction, WaitView, WaitListBody, UsageBody, UsageTotals, UsageSessionRecent, ConvoyGetResponse, ConvoyProgress, EventStreamEnvelope, HeartbeatEvent, ErrorModel, HealthOutputBody, city list item
- [ ] Generated files carry a "do not hand-edit" header and round-trip a fixture JSON sample in a unit test
| Path | Change | Purpose |
|---|---|---|
| `contracts/gascity-supervisor-openapi-v0-*.json` | create | pinned spec |
| `tool/gen_gascity_dto.*` | create | generator |
| `lib/orchestration/adapters/gascity/dto/*.dart` | create | DTOs |
| `test/orchestration/gascity_dto_test.dart` | create | round-trip |
Depends on: none.

### CP-102 Domain interface and product models
As an app developer I want `OrchestrationGateway` and product models so UI never sees provider DTOs.
- [ ] `lib/domain/orchestration_gateway.dart` defines the composed read interfaces from architecture-proposal §2 (health, projects, runs, work, agents, gates, activity, usage, events) and `OrchestrationCapabilities` (flat const bools) — no control interface yet
- [ ] `lib/orchestration/models/` defines `Project, RunSummary, RunDetail, RunStep, Work, WorkGraph, Agent, AgentDetail, Gate, ActivityEvent, Usage` with `WorkState` enum exactly {queued, ready, working, waiting, blocked, needsInput, review, failed, completed, cancelled}
- [ ] `NullOrchestrationGateway` with all capabilities false
- [ ] Unit test asserts every `WorkState` has a display label and an icon key (no colour-only meaning)
| Path | Change | Purpose |
|---|---|---|
| `lib/domain/orchestration_gateway.dart` | create | interface |
| `lib/orchestration/models/*.dart` | create | models |
| `lib/orchestration/adapters/none.dart` | create | null gateway |
| `test/orchestration/models_test.dart` | create | labels |
Depends on: none.

### CP-103 Fixture server `tool/qa/gascity_fixture/`
As a QA engineer I want a stdlib-only fake supervisor so the slice is testable without Dolt/tmux.
- [ ] `fixture_server.py` binds `127.0.0.1:8372` (env `OCMN_GASCITY_FIXTURE_PORT`), serves `GET /health`, `/v0/cities`, `/v0/city/demo/{status,usage,runs,runs/census,runs/{id},runs/{id}/steps,beads,beads/ready,bead/{id},bead/{id}/deps,beads/graph/{root},agents,agent/{base}/output,sessions,session/{id},session/{id}/pending,waits,pending,mail,events}` and SSE `/v0/city/demo/events/stream` with `event: event` / `event: heartbeat` frames and `Last-Event-ID` replay from an in-memory log
- [ ] Seeded scenario: 1 project, 2 runs (one active at 12/18 steps with 2 blocked, one completed), 18 beads with `needs` edges, 4 agents (providers opencode/claude/codex/kimi, one with `context_pct` 63, one blocked), 1 pending interaction, 1 open gate bead; a scripted timeline advances every N seconds emitting `bead.closed`, `session.woke`, `request.result.session.submit`
- [ ] Every mutation route returns `403 csrf` without `X-GC-Request` and `problem+json` with `read_only:` detail with it (fixture is read-only in Sprint 1)
- [ ] `README.md` documents `adb reverse tcp:8372 tcp:8372` and the scenario; `smoke_client.py` prints the run census and tails 5 events
| Path | Change | Purpose |
|---|---|---|
| `tool/qa/gascity_fixture/fixture_server.py` | create | fake supervisor |
| `tool/qa/gascity_fixture/smoke_client.py` | create | smoke |
| `tool/qa/gascity_fixture/README.md` | create | usage |
| `tool/qa/README.md` | modify | index entry |
Depends on: CP-101 (shapes).

### CP-104 Gas City read adapter
As an app developer I want a `GasCityGateway` implementing the read interfaces against the supervisor API.
- [ ] `lib/orchestration/client/` provides `OrchestrationHttpClient` (Dio, problem+json → `OrchestrationException{code,status,requestId,detail}`) and `OrchestrationSseParser` (frames, heartbeat, `Last-Event-ID`)
- [ ] `lib/orchestration/adapters/gascity/gascity_gateway.dart` + `gascity_mappers.dart` implement every Sprint-1 read method; state mapping table from architecture-proposal §2 is a pure function with a table-driven test
- [ ] City readiness: per-city calls are skipped and `health().ready=false` when `/v0/cities` shows `running=false`
- [ ] Integration test runs against the fixture (`python3` spawned in test, skipped when unavailable) and asserts run census, 18 works, 4 agents, 1 pending gate, and that the SSE channel reports `connected` then receives ≥1 event
| Path | Change | Purpose |
|---|---|---|
| `lib/orchestration/client/{http_client,sse_parser,errors}.dart` | create | plumbing |
| `lib/orchestration/adapters/gascity/{gascity_gateway,gascity_mappers,gascity_capabilities}.dart` | create | adapter |
| `test/orchestration/gascity_gateway_test.dart` | create | mapping + fixture |
Depends on: CP-101, CP-102, CP-103.

### CP-105 Profile field + OrchestrationController
As a user I want to add an orchestration endpoint to an existing server profile and see its connection state.
- [ ] `ServerProfile` gains `orchestrationUrl`, `orchestrationProvider` (`none|gascity|fixture`), `orchestrationCity`; `toJson/fromJson` round-trip; existing profiles load unchanged (`none`)
- [ ] Profile editor shows an "AI orchestration (optional)" section with URL, provider, city; `http://` to a non-loopback host is rejected with the same copy pattern as the OpenCode URL validation
- [ ] `lib/state/orchestration.dart` `OrchestrationController` builds the gateway from the profile via an injectable factory, exposes `health`, `capabilities`, `runs`, `works`, `agents`, `gates`, `activity`, `status`, refetches dirty scopes on events, and disposes the channel when the app backgrounds
- [ ] Connection sheet shows "AI orchestration: Connected · Gas City v<version> · read-only" or "Not configured"
- [ ] Tests mock `flutter_secure_storage` per AGENTS.md; `test/orchestration/orchestration_controller_test.dart` covers connect, event → refetch, background → dispose
| Path | Change | Purpose |
|---|---|---|
| `lib/state/profiles.dart` | modify | fields |
| `lib/state/orchestration.dart` | create | controller |
| `lib/ui/screens/servers_screen.dart` | modify | editor section |
| `lib/ui/widgets/connection_status_banner.dart` | modify | identity line |
| `test/orchestration/orchestration_controller_test.dart` | create | tests |
| `test/profiles_test.dart` | modify | round-trip |
Depends on: CP-102, CP-104.

### CP-106 Workspace "AI development" summary card
As a developer I want the Workspace to show working/idle/blocked agents, active runs and remaining work above my sessions.
- [ ] Card renders only when `capabilities.runs && capabilities.agents`; sessions list below is unchanged when not configured (existing widget tests still pass)
- [ ] Shows "N working · N idle · N blocked", "N active runs", "N work items remaining", stale badge when `fetchedAt` > 60 s and channel not connected
- [ ] Each active run row shows title, state, completion (`closed/total` steps), agents working count, blocked count, elapsed since `started_at`, cost estimate when `usage.available`
- [ ] Tapping a run opens Run detail (CP-107)
| Path | Change | Purpose |
|---|---|---|
| `lib/ui/widgets/orchestration_summary_card.dart` | create | card |
| `lib/ui/screens/workspace_screen.dart` | modify | insert sliver |
| `test/ui/orchestration_summary_card_test.dart` | create | widget test |
Depends on: CP-105.

### CP-107 Run detail screen (Overview + Work tabs)
As a developer I want Run detail to answer: what, how far, what now, what's blocked, do I need to act.
- [ ] Header: title, state chip, elapsed, `closed/total`; a "Needs you" strip listing gates for this run (read-only)
- [ ] Steps grouped by `kind`/stage with state icons and assignee provider label; blocked steps show which step blocks them (from `WorkGraph` edges)
- [ ] Work tab lists the run's beads with `WorkState` filter chips; each row opens Work detail (title, description, status, owner, blocked-by, blocking, worktree/branch if present in metadata, timestamps)
- [ ] Failed run shows `last_error.code/message`
- [ ] Lists are `ListView.builder` (virtualised); 100+ items scroll without jank in a widget test
| Path | Change | Purpose |
|---|---|---|
| `lib/ui/screens/run_detail_screen.dart` | create | screen |
| `lib/ui/screens/work_detail_screen.dart` | create | screen |
| `test/ui/run_detail_screen_test.dart` | create | test |
Depends on: CP-105.

### CP-108 Agents list and Agent detail (read-only)
As a developer I want to see the whole fleet uniformly regardless of provider.
- [ ] Agents list: name, provider/model, state (working/waiting/blocked/idle/stopped), current work title, context % when present; identical row for opencode/claude/codex/kimi
- [ ] Agent detail: identity (name, role/pool, provider, model), runtime (running, session age from `created_at`, context %, `work_dir`, rig), current work (id, title, blocked state), last output (last 80 lines from `/agent/{base}/output`, monospace, read-only)
- [ ] No provider-specific screens; provider only appears as a label
| Path | Change | Purpose |
|---|---|---|
| `lib/ui/screens/agents_screen.dart` | create | list |
| `lib/ui/screens/agent_detail_screen.dart` | create | detail |
| `test/ui/agents_screen_test.dart` | create | test |
Depends on: CP-105.

### CP-109 Activity aggregation of orchestration items
As a developer I want orchestration attention items and the run timeline inside Activity, not a fifth tab.
- [ ] `unifiedAttentionCount` includes pending orchestration gates; dock badge updates in a widget test
- [ ] Activity "Needs attention" shows gate rows (kind, prompt, run/agent, age) ordered per BRD §47 (decision → failed run → permission → review → blocked agent → merge → completion); tapping opens Run detail (read-only in this sprint)
- [ ] A "Run timeline" section lists `ActivityEvent`s newest-first with filter chips (agents, work, decisions, system, failures); silent event types (`session.updated`, `mail.read`) are hidden by default
- [ ] Empty/unconfigured state unchanged for profiles without orchestration
| Path | Change | Purpose |
|---|---|---|
| `lib/ui/screens/activity_screen.dart` | modify | sections |
| `lib/state/connection.dart` | modify | badge sum (minimal touch; single-owner file) |
| `lib/domain/attention_item.dart` | modify | gate item kind |
| `test/activity_orchestration_test.dart` | create | test |
Depends on: CP-105, CP-107.

### CP-110 Feature-gating regression and phone smoke record
- [ ] `test/v2_feature_gating_test.dart` (or a new sibling) proves that with `NullOrchestrationGateway` no orchestration widget is in the tree on Workspace, Activity, More
- [ ] Manual phone smoke against the fixture recorded in `docs/verification/control-plane-slice-<date>.md` with screenshots list and the fixture commit
Depends on: CP-106, CP-107, CP-108, CP-109.

---

## Sprint 2 — gates and decisions, live output, changes (Epic CP-2)

Goal: the user can *see* everything they will later act on, live, and open the underlying detail; the fixture grows a scripted decision flow; a first read-only run against a real Gas City is attempted.

### CP-201 Live agent output and session stream
- [ ] Agent detail "Live" toggle opens SSE `/agent/{base}/output/stream`; `GC-Agent-Status: stopped` shows "replaying transcript"; stream disposed on leave
- [ ] Reconnect with backoff; status chip mirrors `StreamStatus`

### CP-202 Gate detail sheet (read-only rendering of all gate kinds)
- [ ] Renders pending interaction (`kind`, `prompt`, `options[]`), open gate bead (title, blocking steps), wait (`kind`, `dep_ids`, `expires_at`), human-addressed mail (subject, body)
- [ ] Copy uses product words ("Approval", "Decision", "Waiting on…"), with a "technical details" expander showing raw type and ids
- [ ] Fixture scenario adds a choice-style interaction with 3 options and a `session.stopped` after answer

### CP-203 Changes view via existing VCS gateway (no sidecar)
- [ ] When a Work item's metadata carries a `work_dir` under the OpenCode server's project and `ServerCapabilities.worktreeCreate/projectManagement` exist, Work detail offers "Open changes" which routes into the existing worktree/diff screens with that path pre-selected (reuse, not rebuild)
- [ ] When the path is unknown or the OpenCode server is a different host, the action is hidden (no dead buttons)

### CP-204 Agent → OpenCode session link (best effort)
- [ ] If the agent's `SessionResponse.metadata` (or a front-provided field) contains an OpenCode session id, Agent detail shows "Open session" into the existing chat screen; otherwise hidden
- [ ] Owner question logged if no linkage exists in a real deployment

### CP-205 Multi-project aggregation on Workspace
- [ ] When `/v0/cities` returns multiple running cities or a city has multiple rigs, the summary card shows a per-project line ("OpenCode Mobile · 5 agents · 1 run", "SDK · 1 blocked") and Activity aggregates gates across them

### CP-206 Usage and cost surfaces (labelled estimated)
- [ ] Run header shows `cost_usd_estimate` with "estimated" label; agent detail shows tokens and context; `unpriced=true` shows "not priced"

### CP-207 Real Gas City read-only proof
- [ ] On a dev host: `brew install gascity` or source build, `gc init`, one rig, Gas Town pack default; supervisor exposed via `tailscale serve --bg 8372` (TLS by Tailscale); app connects read-only; record differences between fixture and reality in `docs/verification/` and open beads for each mismatch
- [ ] Explicitly record: does `/agent/{base}/output` work for tmux vs ACP sessions; what `PendingInteraction.kind` values appear; whether `SessionResponse.metadata` links to anything

### CP-208 Fixture: event replay and stale-data behaviour
- [ ] Fixture supports `?after_seq` and `Last-Event-ID`; app test proves a dropped stream followed by reconnect refetches dirty scopes and shows no duplicate timeline rows

---

## Sprint 3 — controls through the front (Epic CP-3)

Goal: safe mutations. Requires the owner's decisions in open-questions.md (host, provider, sidecar language).

### CP-301 Control-plane front (sidecar) MVP
- [ ] `tool/host/cp_front/` (language per owner decision) serves `/.well-known/opencode-mobile-orchestration`, `POST /respond`, `POST /sling`, `POST /work/{id}/close|reopen`, `POST /agent/{id}/{stop,wake}`, `POST /runs/{id}/cancel`, `GET /changes?bead=`; refuses to start unless bound to loopback; verifies `Tailscale-User-Login` against `tailscale whois`; allowlist of logins in config
- [ ] Mints `X-GC-City-Write` grants with a host-held ed25519 key and forwards to the supervisor with `X-GC-Request`; maps `Idempotency-Key` → `request_id`; returns `202 {request_id, event_cursor}` unchanged
- [ ] Unit tests with a recorded supervisor stub; documented in `docs/ubuntu-host.md` sibling `docs/control-plane-host.md`

### CP-302 `OrchestrationControlGateway` + Gas City front adapter
- [ ] Domain control interface (architecture-proposal §2) implemented only by `GasCityFrontGateway`; `capabilities.control*` true only when the front's well-known document says so
- [ ] Every mutation takes an `idempotencyKey`, persists a `PendingMutation{key, kind, target, dispatchedAt}` before sending (offline-queue `dispatchedAt` pattern), resolves on `request.result.*`, and never auto-retries

### CP-303 Answer a gate from Activity
- [ ] Choice/confirm/free-text/allow-deny sheets post `respond {action, text, request_id}`; the sheet stays "sending…" until the receipt resolves; the answer routes to the exact session (`request_id`) and the gate disappears only after the server confirms
- [ ] Notification deep-link opens the same sheet (reuse existing notification plumbing)

### CP-304 Assign / start work
- [ ] Work detail "Assign to…" lists agents/pools; posts `sling {bead, target, rig}`; optional formula from `/formulas`; result shows `dashboard_url`-free product confirmation

### CP-305 Agent lifecycle controls with confirmation
- [ ] Nudge (message), stop, wake, suspend; kill and cancel run behind a two-step destructive sheet with the agent/run name typed or held; hidden when capability false

### CP-306 Merge readiness card (read-only)
- [ ] Front computes readiness (all steps completed, no open gates, `gh pr view` mergeable when configured); app shows the checklist; `Merge` button is **not** built this sprint

### CP-307 Autonomy/supervision policy display
- [ ] Read the city's Gastown-pack config (`/config`) and show the effective policy summary ("asks before merge: yes/no") — read-only; editing policies stays on the host

---

## Do not build (explicitly)

- A fifth navigation tab, a Gas City admin console, or a generic "run any gc/bd command" control (BRD §9, §55).
- Provider-specific worker screens (BRD §17).
- A phone-side ed25519 write key or grant minting; a phone-side shell into tmux.
- A planning UI that turns objectives into work graphs (that is the Mayor pack's job; the app slings text and shows beads).
- A Dart port of Beads (`.beads/` or Dolt access from the app); `.beads/issues.jsonl` parsing.
- Offline queueing of orchestration mutations (disabled offline instead).
- Support for Gas Town's `gt dashboard` `/api/run` endpoint.
- Termux-hosted Gas City until the owner confirms Dolt/tmux viability there.
- Full proxying of the 164 supervisor operations through the sidecar.
- Auto-merge, force merge, branch reset, worktree deletion from the phone in these three sprints.

## Open questions for the owner (blocking Sprint 2/3)

See [open-questions.md](open-questions.md). The ones that gate sprint boundaries: which orchestrator (Gas City vs ralph-tui vs both), host + Tailscale exposure, sidecar language/ownership, whether agents' `opencode` harness should point at the user's OpenCode server, and the review/merge strategy.
