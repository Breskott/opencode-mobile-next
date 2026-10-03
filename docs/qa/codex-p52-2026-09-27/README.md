# P5.2 backend feasibility — 2026-09-27

Status: **blocked at feasibility; no implementation added**.

Finish line: expose truthful session-derived team activity, host location, heat
pause reason, and task/day cost through a small backend API for the kit UI.
Non-goals: budget enforcement, UI changes, native changes, releases.

## Scope and decision

Read: AGENTS.md; STANDARDS.md sections 2, 3, 13 and 15; orchestration
gateway/controller, Gas City usage/session DTOs and mapper, OpenCode usage
query and session linking, thermal hold API, and existing team QA evidence.
Write set: this QA record and, if git cannot commit, root COMMIT_MSG.txt.
Dependency: a verified supported source of task-attributed session usage.
Acceptance: ledger rows 18, 20 and 21 plus real task/day cost; none is closed
by this documentation-only unit. Focused checks: diff and local link checks.

The user explicitly requires stopping when a slice fails feasibility. P5.2
fails the cost prerequisite below, so no adapter, controller, persistence or
placeholder cost API was built. There is no new runtime feature to enable.

## Feasibility evidence

- The currently implemented [Gas City gateway](../../../lib/orchestration/adapters/gascity/gascity_gateway.dart)
  `usage()` requests city `/usage` and `/status`. Its
  [DTO](../../../lib/orchestration/adapters/gascity/dto/usage.dart) exposes
  `today` and `recent`; [mapUsage](../../../lib/orchestration/adapters/gascity/gascity_mappers.dart)
  maps the host's `today` totals. These are city-wide estimates, not a task's
  cost and not an individual agent's cost.
- The checked-in [supervisor schema](../../../contracts/gascity-supervisor-openapi-v0-3648ca2d499a.json),
  `GET /v0/city/{cityName}/usage`, additionally describes
  `UsageBody.recent_by_session`. `UsageSessionRecent` attributes estimates
  to a worker name and optional session bead ID, **only for the trailing
  recent window**. It has no task ID, full-session total or historical
  task-assignment intervals. `aggregate_only` only omits this breakdown;
  it is not a date-range or task query. This schema is evidence of the
  limitation, not proof of a callable live deployment.
- Summing overlapping recent windows would double-count, while app downtime
  could lose spend. Assigning all recent session spend to `active_bead`
  could charge a prior task to the current one. Neither meets task cost.
  `partial` and `unpriced` also mean an estimate may omit costs.
- OpenCode has session/message costs, but the existing
  [team session resolver](../../../lib/domain/team_agent_sessions.dart)
  selects the newest matching folder/time session, with bounded pagination.
  It is a navigation heuristic, not an authoritative accounting join.
  [Existing integration evidence](../team-agent-chat-2026-09-25/README.md)
  records that Gas City's public session API hides `metadata.session_key`
  and that the OpenCode 2 shared-store mapping was not established.
  That older live evidence was not reverified in this unit.
- [UsageQuery](../../../lib/domain/usage_statistics.dart) supports time,
  timezone and project scope, not task/session filtering. It does not fill
  the missing attribution contract.
- The existing [HTTP client](../../../lib/orchestration/client/http.dart)
  deliberately strips authorization/cookie credentials. No new credential
  use, internal metadata access or direct server storage access was attempted.
  No live server was contacted and no credentials were read or logged.

Unblock by providing a verified callable contract (with supported authentication)
that supplies task-attributed cost facts or complete session usage with a stable
task/session mapping, including completed/retried workers, time boundaries,
missing pricing and partial-history semantics. Verify it on the target host
before implementing the adapter. A revised requirement explicitly limited to
recent-window estimates would be a different finish line.

## UI hook-up

**No new P5.2 Dart API is available because feasibility failed.** Existing
read-only seams for the subsequent UI unit are:

| Question | Existing Dart API | Constraint |
|---|---|---|
| Is the team working? | `OrchestrationController` is a `ChangeNotifier`; read `snapshot.agents`, `snapshot.work`, `streamStatus`, `isStale`, `lastRefreshedAt`, and `lastError`. | Refetch/reconcile through the controller; do not treat cached state as live. |
| What is the session doing? | `OrchestrationAgent.sessionState`, `sessionRunning`, `sessionId`, `currentWorkId`, and `suspended`. | The mapper currently mixes agent and session states; session precedence still needs a focused backend fix and tests. Do not claim row 21 closed. |
| Where does it run? | `OrchestrationController.host?.hostMode` (`phone` / `computer`) and `host?.city`. | Null means unknown until probing succeeds. Gate on capabilities/host mode, not server flavor. |
| Is this a heat pause? | `ThermalGuard` is a `ChangeNotifier`; `holds[profileId]` returns the actual `ThermalTeamHold` with `since`, `status`, and `serviceStopped`. | Use a matching host/profile hold; absence of running agents alone does not establish a pause or a heat hold. Resolve the guard through the existing `thermalGuardSlotProvider`. |
| What did the team spend today? | `OrchestrationController.snapshot.usage` when `capabilities.usage` is true. | Host-local day, city-wide estimate; not device-local day, not a task or agent total. Preserve unknown/partial/unpriced semantics from the source. |
| What did this task cost? | **Unavailable.** | Do not relabel city totals or recent-window session estimates as task lifetime cost, and do not substitute zero. |

Sources: [controller](../../../lib/state/orchestration.dart),
[agent model](../../../lib/orchestration/models/agent.dart),
[host identity](../../../lib/domain/orchestration_gateway.dart),
[thermal guard](../../../lib/builtin/thermal_guard.dart),
[thermal provider](../../../lib/builtin/thermal_guard_teams.dart).

Later implementation should centralize the state projection in domain/state
so screens only localize and render it. A lack of active workers is idle or
unknown, never evidence of an intentional pause. Heat hold is an explicit,
host-scoped reason. The duplicated team entry in ledger row 18 requires the
separate UI unit; this backend unit cannot close it.

## Verification and shipping state

- Documentation only; no Dart added or changed, so no behavior tests or
  Dart formatting apply. No Flutter tests, analyzer, builds or device checks
  were run. This is not a runtime verification pass.
- No UI, single-owner file, Kotlin, localization, credential, persistence or
  deletion-sweep changes. No new stored data requires KitRedact or migration.
- Implemented: none (feasibility blocked). Enabled: no. Verified: source and
  schema inspection only. Deployed/released: no. Rows 18/20/21 remain open
  for P5.2 acceptance.
- Local link check: all 13 relative links resolve. Whitespace check: passed.
- Commit: blocked by the sandbox. `git add` could not create the worktree's
  `index.lock` in the read-only parent repository git directory. Changes remain
  uncommitted; the requested message and attribution trailers are in
  [COMMIT_MSG.txt](../../../COMMIT_MSG.txt). No push was attempted.
