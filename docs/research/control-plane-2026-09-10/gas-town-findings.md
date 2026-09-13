# Gas Town / Gas City / Beads — detailed findings (2026-09-10)

Conventions: **[V]** = verified against a primary source cited inline (repo file, official docs, OpenAPI spec). **[I]** = inference from verified facts. **[U]** = unverified (not found in a primary source; treat as a question). Repo metadata (versions, stars, push dates) was read via the GitHub API on 2026-09-10.

Sources most cited:
- Gas Town repo: https://github.com/gastownhall/gastown (README) and `internal/web/api.go`
- Gas City repo: https://github.com/gastownhall/gascity — docs under `docs/` (rendered at https://docs.gascityhall.com), OpenAPI at https://raw.githubusercontent.com/gastownhall/gascity/main/docs/reference/schema/openapi.json
- Beads repo: https://github.com/gastownhall/beads (README, `docs/core-concepts/issues.md`, `docs/reference/events-journal.md`, `docs/CLI_REFERENCE.md`)
- Yegge essays: https://yegge.ai/gastown, https://yegge.ai/essays/welcome-to-gas-city/ (the Medium originals return 403 to fetchers)

---

## 1. What Gas Town is

| Fact | Status | Source |
|---|---|---|
| Repo `gastownhall/gastown` ("Gas Town - multi-agent workspace manager"), Go, MIT. Latest release v1.2.1 (2026-06-06). ~17,989 stars. Last push 2026-09-09. | [V] | GitHub API `repos/gastownhall/gastown` |
| Open-sourced 2026-01-01; "Gas Town and Beads are MIT-licensed". Built by Julian Knutsen and Chris Sells per the Gas City essay; Yegge "outlined vision". | [V] | https://yegge.ai/gastown, https://yegge.ai/essays/welcome-to-gas-city/ |
| Roles: **Mayor** (AI coordinator, "a Claude Code instance with full context"), **Rigs** (project containers wrapping a git repo), **Crew** (your personal workspace clone), **Polecats** ("worker agents with persistent identity but ephemeral sessions"), **Hooks** ("git worktree-based persistent storage for agent work"), **Convoys** (work tracking units bundling beads), **Molecules** (formula instances with tracked steps; "root-only wisps" vs "poured wisps"), **Witness** (per-rig lifecycle manager: detects stuck agents, triggers nudge/handoff), **Deacon** (cross-rig patrol daemon), **Dogs** (infrastructure workers dispatched by the Deacon), **Refinery** (per-rig merge queue), **Escalation** (`gt escalate`, P0–P2), **Scheduler** (polecat dispatch capacity), **Seance** (predecessor session discovery via `.events.jsonl`), **Wasteland** (federation via DoltHub). | [V] | gastown README "Core Concepts" |
| Sling: `gt sling <bead-id> <rig>` assigns a bead to a worker; `gt convoy create "Feature X" gt-abc12 gt-def34`. | [V] | gastown README "Example: Feature Development" |
| Refinery = "Bors-style merge queue": polecat runs `gt done` → branch pushed, MR bead created → Refinery batches MRs → runs verification gates on merged stack → green: merge all; red: bisect. "Polecats never push directly to main." | [V] | gastown README "Merge Queue (Refinery)" |
| Watchdog chain: "Daemon (Go process) ← heartbeat every 3 min → Boot (AI agent) → Deacon (AI agent) → Witnesses & Refineries". | [V] | gastown README "Monitoring & Health" |
| Host requirements (native): Git 2.20+, Go 1.26.2+ (source builds), `bd` 0.57.0+, sqlite3 ("used by convoy database queries"), ICU4C dev headers, tmux 3.0+ ("Required for `gt up`… Optional only for minimal-mode"), Claude Code CLI ("Default runtime"), Dolt (installed separately on Linux). `brew install gastown` on macOS installs gt+bd+dolt. Docker Compose path exists. | [V] | gastown README "Prerequisites", "Install gt on Linux", "Docker Compose setup" |
| `gt up` "boots Dolt, the daemon, the Deacon, the Mayor, and per-rig Witnesses and Refineries." | [V] | gastown README |
| Runtimes: per-rig `settings/config.json` `runtime.provider`; built-in presets `claude, gemini, codex, kiro, cursor, auggie, amp, opencode, copilot, pi, omp`; `gt sling … --agent cursor` overrides per sling. Claude uses hooks in `.claude/settings.json`; Codex needs `project_doc_fallback_filenames = ["CLAUDE.md"]`; Copilot uses `--yolo`. | [V] | gastown README "Runtime Configuration" |
| Storage: "Beads — git-backed atomic work units stored in Dolt" (third-party summary) and `gt dashboard` sets `GT_DOLT_HOST` / `BEADS_DOLT_SERVER_HOST`. Bead IDs are `prefix-xxxxx` (`gt-abc12`). | [V] | gastown README "Beads Integration"; `internal/cmd/dashboard.go` lines ~179–181; https://ascii.co.uk/news/article/news-20260125-f25263de/ |
| Telemetry: OTEL logs/metrics export (`GT_OTEL_LOGS_URL`, `GT_OTEL_METRICS_URL`); events: session lifecycle, agent state, bd calls, mail, sling/nudge/done, spawn/remove, formula instantiation, convoy creation, daemon restarts. | [V] | gastown README "Observability" |
| `gt feed` = interactive terminal TUI dashboard (beads activity + agent events + merge queue). | [V] | gastown README |

### 1.1 Gas Town's network surface (the important negative result)

| Fact | Status | Source |
|---|---|---|
| `gt dashboard` serves an htmx single-page overview (agents, convoys, hooks, queues, issues, escalations) on port 8080, default bind `127.0.0.1` (`--bind 0.0.0.0` to expose). "Treat it as a trusted local-network surface." | [V] | gastown README "Dashboard"; `internal/cmd/dashboard.go` (`defaultBind := "127.0.0.1"`) |
| Its JSON API is `internal/web/api.go`: routes `/api/run` (POST, executes a **whitelisted** `gt` command, `Confirm` flag enforced server-side), `/api/commands`, `/api/options`, `/api/mail/{inbox,threads,read,send}`, `/api/issues/{show,create,close,update}`, `/api/pr/show`, `/api/rig/add`, `/api/crew`, `/api/ready`, `/api/events` (SSE), `/api/session/preview`. Handlers **shell out** to `gt`, `bd`, `gh`, and `tmux` (`runGtCommand`, `runBdCommand`, `runGhCommand`, `tmux list-sessions`). POST requires header `X-Dashboard-Token` == server CSRF token; "No CORS headers — the dashboard is served from the same origin." Concurrency capped at 12 subprocesses. | [V] | https://github.com/gastownhall/gastown/blob/main/internal/web/api.go (`ServeHTTP`, `handleRun`, `NewAPIHandler`) |
| `/api/events` SSE emits `event: connected` then `event: dashboard-update` with a hash whenever `computeDashboardHash` (run every 2 s) changes, plus a keepalive every 15 s. It is a change *ping*, not an event stream. | [V] | same file, `handleSSE` |
| No OpenAPI document, no bearer/basic auth, no per-user identity, no MCP server in the gastown repo. | [I] | absence in README and `internal/` package list (`acp activity agent … web wisp witness workspace worktree`) |
| `gt` has an `internal/acp` package and `internal/protocol` (witness/refinery handlers) — internal agent protocols, not a client API. | [V] | GitHub contents `internal/` |
| Design docs `docs/design/factory-worker-api.md` and `agent-api-inventory.md` exist. Contents not reviewed. | [U] | GitHub contents `docs/design/` |

**Conclusion [I]:** a mobile client could drive Gas Town only by wrapping its dashboard's command-runner or by shelling `gt`/`bd` itself. That is exactly the "thin host adapter" the BRD anticipates — but it would be a port of the dashboard's shell-out design, with the same trust model.

---

## 2. What Gas City is

| Fact | Status | Source |
|---|---|---|
| Repo `gastownhall/gascity` ("Orchestration-builder SDK for multi-agent coding workflows"), Go, MIT. Latest release v1.4.1 (2026-08-15). 1,237 stars. Last push 2026-09-09. | [V] | GitHub API |
| Announced 2026-04-24 ("v1.0.0 released this week"). "Came with a fully functional 'Gas Town' pack, which runs an exact replica of Gas Town… the default pack that runs on startup. So Gas City starts off as a drop-in replacement for the original Gas Town, and can import all your rigs and beads." MEOW = "Molecular Expression of Work". Dolt is "Gas City's internal powerhouse". "Gas City exposes a rich Factory Worker API. It's a way to make your own agent the driver for Gas City." | [V] | https://yegge.ai/essays/welcome-to-gas-city/ |
| README: "extracts the reusable infrastructure from Gas Town into a configurable toolkit with runtime providers, work routing, formulas, orders, health patrol, and a declarative city configuration." Features: `city.toml`; runtime providers **tmux, subprocess, exec, ACP, Kubernetes, herdr**; "Beads-backed work tracking, formulas, molecules, waits, and mail"; "controller/supervisor loop that reconciles desired state to running state"; packs, overrides, rig-scoped orchestration. Repo map lists **`internal/api/` — HTTP API handlers and resource views**. | [V] | gascity README |
| Prereqs: tmux (always — "the default session backend and the fallback"), git, jq, pgrep, lsof; **dolt ≥ 2.1.0**, **bd ≥ 1.0.0**, flock for the default `bd` beads provider; `gh` optional (GitHub gates); `claude / codex / gemini` per provider. `GC_BEADS=file` or `[beads] provider = "file"` gives a file-based store with "no dolt/bd/flock needed". `brew install gascity`; source needs make, **Go 1.26.4+**, ICU (CGO for Dolt). | [V] | gascity README "Prerequisites" |
| Quickstart: `gc init ~/bright-lights && gc start`, `gc rig add .`, `bd create "…"`, `gc session attach mayor`. | [V] | gascity README |
| "The orchestrator hardcodes zero roles… Every role is configuration supplied through a Pack." Six primitives: Agent (WHO), Bead (WHAT), Formula (HOW), Rig (WHERE), Pack (CONFIGURES), Event (OBSERVE). "tasks, mail, sessions, convoys are all beads differing only by `type`." Bead status `open → in_progress → closed`; dependencies are blocking `needs` edges. Sessions are "disposable; the work they did survives them". Agents can be pools (`min/max_active_sessions`, `scale_check`). | [V] | docs/getting-started/how-gas-city-works.md |
| Formula → run: "Applying it compiles the steps into a graph and materializes them as beads; from that moment a run is independent of the file and of any session." `gc sling` "creates and routes in one motion". Orders = triggers (cooldown, cron, condition, event, manual). | [V] | same |
| Events: "immutable, append-only… Every event carries a monotonically increasing sequence number, so a watcher can replay the stream from any point." Examples `bead.created/closed`, `session.woke/crashed`, `convoy.created/closed`, `order.fired/completed`. Watch with `bd show --watch`, `gc events --follow`, or the dashboard. | [V] | same |

### 2.1 Gas Town → Gas City role mapping (official)

From docs/getting-started/coming-from-gastown.md [V]:

| Gas Town | Gas City equivalent (all *configuration*, not platform types) |
|---|---|
| Mayor | Configured agent + coordinating prompt (Gastown pack `mayor`); `gc session attach mayor` |
| Deacon | Orchestrator health patrol + config thresholds |
| Witness | Events + waits, formulas, session scale config ("Modeling a 'witness' on top is optional pack behavior") |
| Refinery | "Configured agent + a formula or order post-processing step. A workflow step, not a standing role." |
| Polecat | Scalable/transient agent pool — "An operating style" |
| Crew | Persistent named agent |
| Dog | Core-pack exec orders; Gastown pack `dog` pool |
| Plugins | Orders (exec or formula) |
| Hooks/worktrees | `work_dir`, `pre_start`, `git worktree`, pack scripts — "not a generic `gc worktree` namespace" |
| `gt mq` (merge queue) | "no direct generic gc command — Gastown-style merge queue behavior lives in the pack and formulas" |
| `gt gate` | `gc wait`; formula `[steps.gate]` (types `gh:run`, `gh:pr`, `timer`, `human`, `mail`) |
| `gt costs` | "no direct equivalent — No matching top-level cost accounting command today" (but see the `/usage` API below) |
| `gt nudge` | `gc session nudge <target> "msg"` |
| `gt feed`/`gt activity` | `gc events` / `gc event emit` |

### 2.2 The Supervisor REST API (the surface a mobile client can rely on)

All [V] from docs/reference/api.md and the OpenAPI document (`info.title` "Gas City Supervisor API", `info.version` **0.1.0**, **164 operations**, **557 schemas**, path prefix `/v0`) unless noted.

- "The `gc` supervisor exposes a single, typed HTTP control plane described by an OpenAPI 3.1 document. Everything the CLI does, any third-party client can do too — there is no hidden surface." Generated Go and TypeScript clients exist ("The generated Go and TypeScript clients set this header automatically").
- Default listener: `gc supervisor start` → "Supervisor API listening on http://127.0.0.1:8372"; the dashboard SPA is served on the same listener; `GC_SUPERVISOR_DASHBOARD=0` disables it. (docs/getting-started/dashboard.md)
- **Headers**: `X-GC-Request` (any non-empty value) required on every POST/PUT/PATCH/DELETE (anti-CSRF; 403 otherwise). `X-GC-Request-Id` on every response. SSE streams add `GC-Agent-Status`, `GC-Session-State`, `GC-Session-Status` before the first frame.
- **Errors**: RFC 9457 `application/problem+json`; stable `type: "urn:gascity:error:<code>"` + `code`; e.g. `bead-not-found`, `validation-failed` (422/400/415). Some legacy paths encode `not_found:` / `conflict:` / `read_only:` / `in_flight:` prefixes in `detail`.
- **Async mutations** return `202 {request_id, event_cursor}`; completion arrives as `request.result.<op>` or `request.failed` on the event stream, matched by `payload.request_id`. "Clients observe completion via the supervisor event stream — there is nothing to poll."
- **Readiness boundary**: per-city routes 404 (`not_found: city not found or not running`) until `GET /v0/cities` reports `running=true`.
- **Versioning**: URL prefix `/v0`; "Breaking changes ship as a new prefix."

Endpoint families (operation list extracted from the spec on 2026-09-10; `{c}` = `{cityName}`):

| Family | Operations |
|---|---|
| Supervisor | `GET /health` → `{city,status,uptime_sec,version}`; `GET /v0/readiness`, `/v0/provider-readiness`; `GET /v0/cities`; `POST /v0/city` (202); `GET/PATCH /v0/city/{c}`, `/status`, `/readiness`, `/health`, `/usage`, `/pending`, `POST …/stop`, `…/unregister` (202) |
| Rigs (Project) | `GET/POST /v0/city/{c}/rigs`; `GET/PATCH/DELETE …/rig/{name}`; `POST …/rig/{name}/{action}` |
| Agents | `GET/POST …/agents`; `GET/PATCH/DELETE …/agent/{base}` and `…/agent/{dir}/{base}`; `POST …/agent/{base}/{action}`; `GET …/agent/{base}/output`; **SSE** `…/agent/{base}/output/stream` |
| Beads (Work) | `GET/POST …/beads`; `GET …/beads/ready`; `GET …/beads/graph/{rootID}`; `GET/PATCH/DELETE …/bead/{id}`; `GET …/bead/{id}/deps`; `POST …/bead/{id}/{assign,close,reopen,update}` |
| Runs | `GET …/runs`, `GET …/runs/census`, `GET …/runs/{run_id}`, `GET …/runs/{run_id}/steps`, `POST …/runs/{run_id}/cancel` |
| Sling (Assign/Start) | `POST …/sling` |
| Sessions | `GET/POST …/sessions`; `GET/PATCH …/session/{id}`; `GET …/session/{id}/{pending,transcript,agents}`; **SSE** `…/session/{id}/stream`; `POST …/session/{id}/{messages,submit,respond,close,kill,stop,suspend,wake,rename,permission-mode}` |
| Convoys | `GET/POST …/convoys`; `GET/DELETE …/convoy/{id}`; `GET …/convoy/{id}/check`; `POST …/convoy/{id}/{add,remove,close}` |
| Workflows | `GET/DELETE …/workflow/{workflow_id}` |
| Waits (Gates) | `GET …/waits`, `GET …/wait/{id}` |
| Formulas | `GET …/formulas`, `…/formulas/feed`, `GET/PUT/DELETE …/formulas/{name}`, `…/{name}/{source,runs}`, `POST …/{name}/{preview,validate}` |
| Orders | `GET …/orders`, `/orders/{check,feed,history}`; `GET …/order/{name}`; `POST …/order/{name}/{enable,disable,run}` |
| Mail | `GET …/mail`, `/mail/count`, `/mail/{id}`, `/mail/thread/{id}`; `POST …/mail`, `…/mail/{id}/{reply,read,mark-unread,archive}`; `DELETE …/mail/{id}` |
| Events | `GET …/events` (+ `X-GC-Index`), **SSE** `…/events/stream` (`event: event` / `heartbeat`), `POST …/events` (emit), `…/events/rotate`; supervisor scope `GET /v0/events`, **SSE** `/v0/events/stream` (`event: tagged_event`, adds `city`) |
| Config/packs/patches/providers/services/maintenance | inspection and admin surfaces (`…/config`, `…/packs`, `…/patches/*`, `…/providers`, `…/services`, `…/maintenance/*`) |
| External messaging | `…/extmsg/*` (adapters, bindings, groups, inbound/outbound, participants, transcript) — for chat-platform relays; `POST /v0/extmsg/clients` registers "an external LLM client and returns a bearer token" (docs/guides/connected-clients.md) |

Key DTO shapes (from `components.schemas`, fields verbatim):

- `Bead`: `id, title, description, status, issue_type, priority, assignee, labels[], dependencies[], needs[], is_blocked, parent, ref, from, metadata{}, ephemeral, no_history, defer_until, created_at, updated_at`.
- `Run` (required `run_id, title, status, scope`): `formula, target, started_at, updated_at, last_error{code,message}`; `run_id` is "the run root bead id". `RunStatus` enum `pending|active|waiting|canceling|completed|failed|canceled|skipped`. `RunStep`: `id, title, status, kind, assignee`; `RunStepStatus` enum `pending|active|blocked|completed|failed|skipped|canceled`. `RunScope{kind: city|rig, ref}`.
- `AgentResponse` (required `name, running, suspended, pack_derived, state, available`): `display_name, description, provider, model, rig, pool, pack, active_bead, activity, last_output, context_pct, context_window, session{name,attached,last_activity}, unavailable_reason`.
- `SessionResponse` (required `id, template, state, title, provider, session_name, created_at, attached, running`): `agent_kind, alias, kind, model, rig, pool, work_dir, active_bead, activity, last_output, last_active, context_pct, context_window, metadata, options, submission_capabilities{supports_follow_up, supports_interrupt_now}, reason`.
- `SessionPendingResponse{pending, supported}`; `PendingInteraction{kind, prompt, options[], request_id, metadata}`; `SessionRespondInputBody{action (e.g. allow, deny), text, request_id, metadata}` → `{id, status}`. Semantics beyond field names are **[U]** (no prose in spec; no `gc session respond` CLI exists — CLI has attach/close/kill/list/logs/new/nudge/peek/pin/prune/rename/reset/submit/suspend/unpin/wait/wake).
- `SlingInputBody`: `bead, target, rig, formula, vars, title, merge ("direct, mr, or local"), owned, reassign, force, no_convoy, no_formula, attached_bead_id, scope_kind, scope_ref` → `SlingResponse{bead, target, formula, mode, status, root_bead_id, workflow_id, run{…}, dashboard_url, warnings}`.
- `ConvoyGetResponse{convoy: Bead, children[], progress{total, closed}}`.
- `UsageBody{available, recording, source, today, last_24h, recent, recent_by_session[], partial, partial_reasons, updated_at}`; `UsageTotals{input_tokens, output_tokens, cache_creation_tokens, cache_read_tokens, cost_usd_estimate, unpriced, invocations, wall_seconds}`; `UsageSessionRecent{session, session_id, …, cost_usd_estimate, unpriced}`.
- `EventStreamEnvelope` (required `seq, type, ts, actor`): `subject, message, payload, session_id, run_id, step_id, depends_on_step_ids[], workflow{…}`. Semantic `type` strings present in the spec (54 typed payloads): `bead.{created,updated,closed,deleted,claim_rejected,claim_released,dead_assignee_reopened,worktree.reaped,worktree.reap_skipped}`, `session.{woke,stopped,crashed,suspended,draining,undrained,idle_killed,max_age_killed,stranded,quarantined,reset_stalled,cold_start_timeout,wake_refused,work_query_failed,updated,unknown_state,…}`, `convoy.{created,closed}`, `mail.{sent,replied,read,marked_read,marked_unread,archived,deleted}`, `order.{fired,completed,failed,suppressed}`, `rig.{create,provision.progress}`, `city.{created,suspended,resumed,unregister_requested}`, `request.result.{city.create,city.unregister,rig.create,session.create,session.message,session.submit}`, `request.failed`.
- SSE resume: `Last-Event-ID` or `after_seq` (city) / `after_cursor` (supervisor, composite like `alpha:4,beta:9`); "When no cursor is supplied, event streams start at the current event head."

### 2.3 Security posture of the API (verbatim where it matters)

From docs/runbooks/remote-hardened-city.md, docs/reference/config.md (`[api]`), docs/getting-started/dashboard.md [V]:

- `[api] bind` defaults to `127.0.0.1`. "non-loopback => read-only unless allow_mutations". `allow_mutations = true` re-enables writes on a non-loopback bind.
- "**The read plane is FULLY UNAUTHENTICATED.** Write-auth gates mutations only. Anyone who can reach the port can read every bead payload, all mail, session peeks and transcripts, and the entire event stream… A network/TLS front (reverse proxy, private network, or firewall) is REQUIRED, not optional. In-band read auth is later work."
- Write auth: `write_auth_verify_key = "kid:<base64 ed25519 pubkey>"` — "every mutation requires a signed `X-GC-City-Write` grant"; grants are minted operator-side by `gc-write-mint --kid k1 --key ~/.gc/keys/city.ed25519 --city <name>` (private key never enters `gc`), TTL "≤2 m + 30 s skew", replay-guarded by `jti`, epoch floor `GC_CITY_WRITE_EPOCH_FLOOR` for revocation. `gc context add <name> --url https://… --city … --grant-command "…"` stores the context `0600`.
- "Built-in callers (the bundled gc API client and dashboard SPA) send only the CSRF header and mint no grant, so enabling this gate turns their direct city mutations away with a clear 401" — i.e. **the dashboard becomes read-only on a hardened city**.
- `read_auth_verify_key` exists (read-side twin) but "covers ONLY the typed /v0/city/{cityName} read routes… It does NOT cover… `/v0/events` and `/v0/events/stream`… the dashboard host plane (`/api/*`)… `/v0/cities`, `/health`…". "Gating those feeds is tracked as that follow-up work."
- Boot matrix: non-loopback + mutations + no key ⇒ **refuses to boot** unless `write_auth_allow_unverified = true` (then "an unauthenticated write plane fronted only by the network").
- "`gc` refuses a plain-`http` non-loopback URL at context validation." Private CA via `--ca-file`.
- Supervisor-managed deployments must list the public hostname in `[supervisor] allowed_hosts` or "every request dies 421".
- Command execution trust model (docs/reference/trust-boundaries.md): "Bead titles, descriptions, mail, formula vars, PR text, and API request fields" are **untrusted data**; orchestrator shell helpers strip secret-looking env keys (`TOKEN`, `PASSWORD`, `SECRET`, `API_KEY`, …).
- Residual risks the project itself lists: single controller replica only; unauthenticated read plane; same-user grant trust; repo-content trust; DNS-rebinding TOCTOU.

### 2.4 Coding-agent support ("harness" providers)

From docs/guides/configuring-an-agent.md and `internal/worker/builtin/profiles.go` [V]:

- Three axes: **Harness** (`provider = "claude"` in `agent.toml`), **Transport** (`session = "acp"` vs default tmux), **Runtime** (city `[session] provider`: tmux default, `subprocess`, `acp`, `exec:<script>`, `k8s`, `herdr`).
- Built-in harness presets (name → command; ACP support as declared in `profiles.go`): `claude` (`claude`, **SupportsACP: true**, resume `--resume`), `codex` (`codex`, resume `resume`; no ACP flag seen), `gemini` (`gemini`, `--resume`), `grok`, `kimi` (`kimi`, **ACP**, args `--yolo --no-thinking acp`, resume `--session`), `kiro` (`kiro-cli`, ACP), `cursor` (`cursor-agent`), `copilot`, `amp`, **`opencode`** (`opencode`, **SupportsACP: true**, `ACPArgs: ["acp"]`, resume `--session`), `mimocode`, `zcode`, `cerebras` and `groq` (both run `opencode acp` as a gateway harness), `auggie`, `pi`, `omp`, `antigravity`. Hook installation supported for `claude, codex, gemini, antigravity, kiro, opencode, mimocode, groq, cerebras, copilot, cursor, pi, omp, kimi` (config.md `install_agent_hooks`).
- `DefaultSessionTransport()` in `internal/config/provider.go`: for the `opencode` family with `SupportsACP`, the default transport is **ACP** (`opencode acp` over JSON-RPC stdio) rather than tmux. [V]
- Upstream env binding: claude → `ANTHROPIC_BASE_URL`/`ANTHROPIC_API_KEY`, codex → `OPENAI_*`, gemini → `GOOGLE_GEMINI_BASE_URL`/`GEMINI_API_KEY`; `opencode` is a "gateway" harness fronting many upstreams. [V]
- **Implication for OpenCode Mobile [I]:** a Gas City agent running the `opencode` harness is a *separate* `opencode acp` process per session, **not** a session inside the user's long-running OpenCode server. There is no documented linkage between a Gas City session id and an OpenCode server session id; the BRD's "Run → Agent → Session → raw conversation" hop into the existing chat UI only works if the harness is pointed at the same server or the adapter records a mapping. This is an open question (see open-questions.md).

### 2.5 Worktrees, branches, merge

- Agents get an isolated checkout via `work_dir` (template with `{{.Rig}}`, `{{.RigRoot}}`, `{{.DefaultBranch}}`…), `pre_start`, `session_setup`. Pool worktrees live under `.gc/worktrees/<rig>/`; `auto_prune_worker_dir` (default true) removes a pool session's worktree after its session bead closes if clean/no unpushed commits/no stashes; `auto_reap_closed_bead_worktrees` (default false, with a dry-run mode emitting `bead.worktree.reap_skipped` events) reaps per-bead worktrees once the bead closes. [V] docs/reference/config.md
- `gc sling … merge: direct|mr|local` is the only merge-strategy knob in the API. [V] OpenAPI `SlingInputBody.merge`
- The Gas Town merge queue is not a platform API ("lives in the pack and formulas"). GitHub gates use `gh` (optional). Formula v2 has `[steps.gate]` (types `gh:run`, `gh:pr`, `timer`, `human`, `mail`) which "synthesizes a real gate bead that blocks its step until the gate bead is closed (manually or by an external watcher), but the type values … are doc-comment vocabulary … the parser never validates them and no bundled watcher acts on them. Zero bundled formulas use `gate`." [V] docs/reference/specs/formula-spec-v2.md §4
- Bounded refinement: `[steps.check]` loops ("orchestrator re-runs until the check passes"); v1 `gc converge`. [V] docs/guides/understanding-formulas.md

### 2.6 Dashboard and CLI JSON

- Dashboard: "reads the supervisor's typed API directly (same origin)… agents and their sessions, beads, mail, formula runs, and a health view". [V]
- `gc events` list mode = JSONL of `TypedEventStreamEnvelope`; `--watch`/`--follow` = `EventStreamEnvelope` lines (heartbeats suppressed); `--seq` prints the cursor. Filters `--type`, `--since`, `--payload-match`, `--after`, `--after-cursor`. [V] docs/reference/events.md
- Most `gc` commands accept `--json` (e.g. `gc session list --json --state active|suspended|closed|all`, `gc session peek --json --lines N`). [V] docs/reference/cli.md

---

## 3. Beads (`bd`)

| Fact | Status | Source |
|---|---|---|
| Repo `gastownhall/beads` ("A memory upgrade for your coding agent"), Go, MIT, v1.2.2 (2026-08-15), ~27k stars, npm `@beads/bd`, PyPI `beads-mcp`. Docs https://beads.gascity.com/ | [V] | GitHub API; README |
| "Distributed graph issue tracker for AI agents, powered by Dolt." Two storage modes: **Embedded (default)** — "Dolt runs in-process, data lives in `.beads/embeddeddolt/`, single writer"; **Server** — `bd init --server`, external `dolt sql-server`, "multiple concurrent writers". "`.beads/issues.jsonl` is an export for viewers and interchange, **not the source of truth or a backup**." Cross-machine sync: `bd dolt push/pull` against `refs/dolt/data` on the git remote. | [V] | README "Storage Modes" |
| Git-free usage: `BEADS_DIR=… bd init --stealth`; all core commands work with zero git calls. | [V] | README |
| Issue model: `id, title, description, type (bug|feature|task|epic|chore), status (open|in_progress|closed|deferred), priority 0–4, labels, created_at, updated_at`; `is_blocked` computed. Hierarchical IDs `bd-a3f8.1`. Hash IDs `bd-a1b2` "prevent merge collisions". | [V] | docs/core-concepts/issues.md; docs/reference/json-schema.md |
| Dependencies: `blocks` (affects ready queue), `parent-child`, `discovered-from`, `related` (no ready impact); `bd dep add <child> <parent>`, `bd dep tree`, `bd blocked`, `bd ready`. Graph links `relates-to, duplicates, supersedes, replies-to`. | [V] | docs/core-concepts/issues.md; README |
| Core CLI: `bd create "T" -t task -p 1 --json`, `bd update <id> --claim` ("Atomically claim a task (sets assignee + in_progress)"), `bd close <id> --reason …`, `bd show <id> --json`, `bd list --status … --json`, `bd prime`, `bd remember`. Global flags: `--json`, `--readonly` ("block write operations (for worker sandboxes)"), `--actor` (audit trail), `-C <dir>`, `--db`, `--sandbox` (disables auto-push), `--dolt-auto-commit off|on|batch`. | [V] | README; docs/CLI_REFERENCE.md global flags |
| Molecules: `bd mol show|pour|wisp|bond|squash|burn|distill`; protos are template epics; `pour` = persistent, `wisp` = ephemeral; `bd formula list|show|convert`. | [V] | docs/CLI_REFERENCE.md `bd mol` |
| Worktrees: `bd worktree create|list|remove|info` — "Worktrees automatically share the same beads database as the main repository via git common directory discovery". | [V] | docs/CLI_REFERENCE.md |
| **Events journal** (off by default): `bd config set events-journal true`; `bd events tail --since <seq> [--follow] [--limit N]`, `bd events export`; JSONL records `{seq, ts, op: create|update|delete, issue_id, actor, issue{…}}` written "in the same transaction as the mutation"; retention 7 days / 100k rows, auto-prune. Distinct from script hooks (`.beads/hooks/on_create|on_update|on_close`, fire-and-forget) and audit history (`bd history <id> --events`). | [V] | docs/reference/events-journal.md |
| MCP server: `beads-mcp` (Python, `uv tool install beads-mcp`) "for MCP-only environments like Claude Desktop where the bd CLI is unavailable… Prefer CLI + hooks when shell is available". | [V] | docs/integrations/mcp-server.md |
| No `bd` HTTP daemon found in README or CLI reference (grep for "daemon" in `docs/CLI_REFERENCE.md` returned nothing). | [I] | absence |
| Schema version guard: an older binary refuses a DB migrated by a newer one (`BD_IGNORE_SCHEMA_SKEW=1` escape hatch). Upgrades across schema migrations need one designated clone to `bd migrate` + `bd dolt push`. | [V] | README |

**Safe remote read/write [I]:** a remote client should never touch `.beads/` files or Dolt directly. Options in order of safety: (1) Gas City API (`/beads`, `/bead/{id}/...`) — preferred, Gas City owns the store; (2) `bd --json --readonly -C <rig>` for reads and `bd … --actor <phone-user>` for writes executed by a host-side sidecar; (3) `bd events tail --follow` as a change feed when Gas City is not running. `.beads/issues.jsonl` must be treated as a stale export.

Discrepancy to flag: ralph-tui's docs say it reads `.beads/beads.jsonl` and syncs with `bd sync --flush-only` (https://ralph-tui.com/docs/plugins/trackers/beads), while current Beads calls the export `.beads/issues.jsonl` and Dolt the source of truth. **[U]** whether ralph-tui's tracker works against Beads ≥ 1.x without changes.

---

## 4. Alternatives for the "orchestration endpoint" role

| Candidate | Runs / Work / Agents / Gates / Review primitives | Remote API | Notes |
|---|---|---|---|
| **Gas City supervisor** | Runs (`/runs`, steps, cancel), Work (beads + deps + graph + ready), Agents (`/agents`, sessions, output SSE, context %), Gates (gate beads, `/waits`, session pending/respond), Review: **none** (no diff API), Cost (`/usage`), Events (SSE, seq, resume) | Typed OpenAPI 3.1 + SSE [V] | Best fit. Unauth'd reads; grant-signed writes on hardened binds. |
| **Gas Town `gt`** | All of the above as CLI/TUI; merge queue (Refinery); escalation | Dashboard `/api/*` shell-out with CSRF token; hash-poll SSE [V] | Legacy; Gas City ships a Gas Town pack. Do not target. |
| **Beads alone (`bd`)** | Work + deps + ready + molecules; events journal; no agents/sessions | CLI `--json`; MCP server (stdio) [V] | Durable-work layer only. |
| **ralph-tui** | Sequential loop over one epic: picks `bd ready`, `bd update --status in_progress`, runs one agent, `--status closed`; `ralph-tui resume`; agents: Claude, OpenCode, Droid, Antigravity, Codex, Cursor, Gemini, Copilot, Grok, Kimi, Kiro, Pi | "No HTTP API, server, or daemon is mentioned" [V] https://ralph-tui.com/docs/plugins/trackers/beads | One agent at a time; no fleet, no gates beyond the loop. Already the team's execution tool; a Run = one epic. Could be observed via the Beads events journal, not driven remotely. |
| **OpenCode 2 server (already integrated)** | Sessions with `parentID` (subagent/fork children), `POST /api/session/{id}/background` (move backgroundable tools to background), agents list (`mode: subagent|primary`), permissions/forms, worktrees, VCS diff | Existing `ServerGateway` + SSE [V] docs/opencode2-protocol-notes.md; `BackgroundWorkSupport` in `lib/domain/server_gateway.dart` | Provides Agents/Sessions/Review/Changes but **no durable Work graph, Runs, or dependency gating**. Right source for "Changes" and "raw session" views. |
| **Claude Agent SDK** | "A library that runs the agent loop in your own process, in Python or TypeScript"; hooks, subagents, permissions ("Control which tools run automatically, which need approval"), sessions ("resume or fork later"), MCP | None — library; other languages "run the CLI as a subprocess" [V] https://code.claude.com/docs/en/agent-sdk/overview | Not an orchestration endpoint; would be *inside* a sidecar. |
| **Managed Agents (Anthropic)** | Hosted REST API, per-session sandbox, SSE events | Hosted [V] (per claude-api skill) | Cloud-hosted execution contradicts BRD §36 (host-local worktrees). Out of scope. |
| **herdr** (`herdr.dev`) | Alternative Gas City session backend | [U] | Referenced only as a runtime provider; not researched. |

---

## 5. Glossary: internal term → BRD product term → Gas City API object

| Gas Town term | BRD UI term | Gas City reality (what the client actually reads) |
|---|---|---|
| Bead | **Work** | `Bead` DTO (`/beads`, `/bead/{id}`, `/beads/graph/{root}`, `/beads/ready`), `issue_type` distinguishes task/epic/gate/message/session/convoy |
| Molecule / wisp | **Run** (also "Workflow" when a template) | `Run` (`/runs`, `/runs/{run_id}/steps`; `run_id` = root bead) for v2 formula runs; `Convoy` (`/convoys`, `progress{total,closed}`) for grouped ad-hoc work; `Workflow` (`/workflow/{id}`) |
| Polecat / Crew | **Agent** | `AgentResponse` (`/agents`), plus its live `SessionResponse` (`/sessions`) |
| Sling | **Assign / Start work** | `POST /sling {bead, target, rig, formula, vars, merge}` |
| Hook | **Current work** | `AgentResponse.active_bead` / `SessionResponse.active_bead` (+ `work_dir`) |
| Refinery | **Merge** | not an API object; `sling.merge` strategy + pack formulas; MR state via `gh` |
| Witness / Deacon | **Supervisor** | orchestrator health patrol; visible only as `session.*` events (`stranded`, `reset_stalled`, `idle_killed`, …) |
| Formula | **Workflow (template)** | `/formulas`, `/formulas/{name}/{source,preview,runs}` |
| Rig | **Project** | `RigResponse` (`/rigs`); bead-ID prefix scope |
| Convoy | **Run (batch)** | `ConvoyGetResponse` |
| Mail / nudge | **Message agent** | `/mail`, `POST /session/{id}/messages|submit` |
| Gate / wait | **Gate / Decision** | gate bead (`issue_type: gate`, closed to release), `WaitView` (`/waits`), `PendingInteraction` (`/session/{id}/pending` → `/respond`) |
| Order | (system automation; not user-facing) | `/orders` |
| City | (host / orchestration endpoint) | `/v0/cities`, `/v0/city/{c}` |

---

## 6. Data/event surface a mobile client can rely on (summary)

Read-only, no credential, over Tailscale to the supervisor listener:

1. `GET /health`, `GET /v0/cities` — discovery + readiness boundary.
2. `GET /v0/city/{c}/status`, `/health`, `/usage?aggregate_only=…` — Workspace summary and cost.
3. `GET /v0/city/{c}/runs`, `/runs/census`, `/runs/{id}`, `/runs/{id}/steps` — Run list/detail.
4. `GET /v0/city/{c}/beads?…`, `/beads/ready`, `/bead/{id}`, `/bead/{id}/deps`, `/beads/graph/{root}` — Work list + dependency graph.
5. `GET /v0/city/{c}/agents`, `/sessions`, `/session/{id}`, `/session/{id}/pending`, `/agent/{base}/output` — Agent fleet + detail + last output.
6. `GET /v0/city/{c}/waits`, `/pending`, `/mail?…` — Gates / needs-attention.
7. `GET /v0/city/{c}/events?after_seq=` + SSE `/events/stream` (`Last-Event-ID`) — Activity timeline and live updates.
8. SSE `/session/{id}/stream`, `/agent/{base}/output/stream` — live agent output (replays transcript when stopped).

Mutations (need `X-GC-Request` + network trust or a signed grant): `POST /sling`, `/bead/{id}/{close,reopen,assign,update}`, `/beads`, `/session/{id}/{respond,messages,submit,stop,kill,wake,suspend}`, `/runs/{id}/cancel`, `/convoy/{id}/*`, `/mail`.

Gaps a sidecar must fill: diffs/changes per bead or worktree; verification results; structured decisions with routed answers; merge readiness; cross-project aggregation when cities live on different hosts.
