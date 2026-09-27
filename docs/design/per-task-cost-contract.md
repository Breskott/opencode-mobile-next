# Per-task cost: host accounting contract

Date: 2026-09-28. Source baseline: `98c4c67a` (`feat/phone-setup-v2`
integration, inspected from `codex/audit`). Status: **proposal; host support
unverified and task cost remains unavailable**.

Finish line: agree on an authoritative usage-to-task join, lifetime totals and
worker assignment history that the app can render without inventing spend.
Non-goals: an app-side accounting ledger, billing or budget enforcement,
provider credential access, and implementing or enabling task cost now.

## Current evidence and blocker

The [P5.2 backend feasibility record](../qa/codex-p52-2026-09-27/README.md),
[P5.2 UI record](../qa/slice-P5.2-2026-09-27/README.md), and
[X52 contract sketch](../qa/codex-x52-2026-09-27/README.md) agree on the missing
join. Current source confirms that it is still missing:

| Evidence at the baseline | Consequence |
|---|---|
| [Gas City gateway `usage()`](../../lib/orchestration/adapters/gascity/gascity_gateway.dart#L519) reads city `/usage` and `/status`. | No task selector or lifetime session read is implemented. |
| [Usage DTO](../../lib/orchestration/adapters/gascity/dto/usage.dart#L43) now preserves `recent_by_session`, unlike the earlier feasibility snapshot. [Mapper](../../lib/orchestration/adapters/gascity/gascity_mappers.dart#L935) retains its qualification. | Each row covers a trailing window, worker name and optional **Gas City session bead ID**. It is not a task or OpenCode session ID. |
| The [pinned supervisor OpenAPI](../../contracts/gascity-supervisor-openapi-v0-3648ca2d499a.json#L1), JSON pointers `/components/schemas/UsageBody`, `/components/schemas/UsageSessionRecent`, `/components/schemas/UsageTotals` and `/paths/~1v0~1city~1{cityName}~1usage`, defines host-local `today`, trailing `recent`, `partial`, `unpriced`, and only the `aggregate_only` query option. | No task join, assignment history or full-session totals. Unpriced facts are omitted from cost; a zero estimate can omit real spend. The schema is a checked-in contract, not a live-host verification. |
| [`currentWorkId`](../../lib/orchestration/adapters/gascity/gascity_mappers.dart#L643) comes from current `active_bead`. | It cannot explain the task on which a worker incurred earlier usage. |
| [Team session resolver](../../lib/domain/team_agent_sessions.dart#L26) picks by folder and activity time, with [bounded pagination](../../lib/domain/team_agent_sessions.dart#L50). | Useful navigation heuristic, insufficient accounting evidence. Do not reconstruct the private `metadata.session_key` join. |
| [OpenCode usage query](../../lib/domain/usage_statistics.dart#L3) filters time/timezone/project; the supervisor's `SessionStructuredUsage` schema contains tokens/context but no task join or dollar price. | Neither supplies the missing contract. |
| [Task Details](../../lib/ui/screens/team/task_details_sheet.dart#L235) renders `teamRunCostUnreported`; [tests](../../test/team_usage_test.dart#L417) reject city and arbitrary raw-payload figures as task cost. | Keep that behavior. The former `run_screen.dart` mentioned in P5.2 is no longer the current surface. |

Only app source, fixtures and the pinned schema were inspected; no Gas City
supervisor accounting implementation is vendored here, and no target host was
queried. Current app [domain evidence](../../lib/orchestration/models/usage.dart#L60)
explicitly prohibits summing overlapping windows. Taking successive window
samples loses usage during app downtime and double-counts overlapping periods.
Full-session totals alone still cannot assign a session that worked on two tasks.

## Required host facts

The host must own a durable ledger and expose read projections. The app must
never collect provider credentials or recover this ledger from transcript text.

1. **Stable identity.** Every fact carries opaque `city_id`, `session_id`,
   `session_attempt_id`, `invocation_id` and `fact_id`. A worker display name is
   not an identity. IDs survive host restart and do not collide when a worker
   name is reused. A provider request ID may be used internally for deduplication
   but is not returned. A task is `(city_id, task_scope, bead_id)`; rig-scoped bead
   names must not collide with another rig's bead.
2. **Usage attribution.** Capture `assignment_id` and task identity when each
   invocation is admitted. A response arriving after reassignment retains its
   original task. Retries and child sessions have their own attempts/facts plus
   an explicit parent/task join. If one invocation genuinely spans tasks, either
   emit documented, disjoint allocations whose totals equal its usage, or mark
   it `unattributed`; never divide costs by elapsed assignment time. Existing
   historical facts without an authoritative join remain unassigned.
3. **Assignment history.** Persist each assignment before dispatch, then record
   host-observed start/end as separate fields. Reassignment closes the previous
   interval and opens another with a new ID. Preserve intervals for completed,
   crashed, retried and removed workers and repeated assignments to the same
   task. A missing boundary is unknown, not a guessed timestamp. Thermal holds,
   user suspension and waiting can occur inside an assignment: time assigned
   is not active work, model latency, CPU time or a billable duration.
4. **Session lifetime.** Retain totals from session creation across host/app
   restarts, midnight, rotations and archive. Distinguish the complete source
   lifetime from the oldest retained fact. Archived/evicted history is explicit
   missing coverage, never an empty session. Report finalization separately:
   a closed session can still receive delayed usage or pricing corrections.
5. **Idempotent accounting.** Deduplicate by stable fact/invocation identity.
   Cumulative provider updates replace a fact revision; they are not additional
   invocations. Repricing changes a revision. Aggregation uses one immutable
   ledger snapshot and each fact contributes once, including after replay.
   Task retries are included once in task lifetime spend; parent/child rollups
   have an explicit scope and must not double-count nested facts.
6. **Price and completeness.** Preserve model/provider identifiers, price-table
   version, effective date, rate units, currency and source class internally;
   return safe price provenance. Token categories have documented inclusion
   rules (especially cache and reasoning tokens) so the client never sums
   overlapping categories. A list-price estimate is never a provider invoice.
   Missing attribution, history, price or recorder coverage are independent
   reasons for incompleteness. Wall-clock facts alone do not imply a charge.

## Proposed version 1 read API (not callable today)

Extend the existing `/v0` supervisor namespace without changing existing `/usage`
semantics. Each response carries `schema_version: 1`. The deployment's supported
capability discovery must advertise the contract version and retention policy;
absence means unsupported, even if an endpoint happens to return JSON.

| Proposed endpoint | Purpose |
|---|---|
| `GET /v0/city/{cityName}/bead/{id}/usage?scope_kind=rig&scope_ref={rig}` | Authoritative task lifetime aggregate, including retries. Default `include_descendants=false`; a supported `true` explicitly changes scope and includes each fact once. |
| `GET /v0/city/{cityName}/session/{sessionId}/usage` | Full-session aggregate plus attributed task and unattributed subtotals. Includes every attempt unless an explicit `attempt_id` narrows scope. |
| `GET /v0/city/{cityName}/bead/{id}/assignments?scope_kind=rig&scope_ref={rig}` | Durable worker/task intervals, not just current workers. |

The scope pair is mandatory for bead endpoints; accept only `city` with the
host-defined city reference or `rig` with a verified rig reference. IDs are
encoded as path segments. All three reads support opaque `snapshot_id` and
`cursor`; initial reads return a snapshot token and subsequent pages must use
it. Optional `from`/`to` RFC3339 UTC bounds select a half-open `[from,to)` range;
supply both or neither. Omitted bounds mean lifetime, never a recent
window. Assignment reads clip the displayed interval to the query but retain
original start/end and IDs. A usage fact belongs to a time range by its
host-recorded invocation admission time; this rule also handles responses
arriving later. The response states `time_basis: invocation_admitted_at`.

`GET .../usage` returns the following **proposed** shape; values below are
synthetic and are not evidence of a working endpoint:

```json
{
  "schema_version": 1,
  "city_id": "city-example",
  "subject": {"kind": "task", "scope_kind": "rig", "scope_ref": "demo", "bead_id": "task-7", "include_descendants": false},
  "snapshot_id": "snapshot-42",
  "revision": "42",
  "as_of": "2026-09-28T09:10:00Z",
  "range": {"kind": "lifetime", "from": "2026-09-28T09:00:00Z", "to": "2026-09-28T09:10:00Z", "time_basis": "invocation_admitted_at"},
  "recording": true,
  "finalized": false,
  "coverage": {"history_complete": true, "attribution_complete": true, "pricing_complete": true, "complete": true, "reasons": [], "unpriced_facts": 0, "unattributed_facts": 0},
  "totals": {"invocations": 2, "input_tokens": 1000, "output_tokens": 200, "cache_read_tokens": 0, "cache_creation_tokens": 0, "known_cost_usd_estimate": "0.012000", "cost_usd_estimate": "0.012000"},
  "pricing": {"source": "list_price_estimate", "currency": "USD", "versions": ["example-price-table-v1"]},
  "sessions": [{"session_id": "session-3", "session_attempt_id": "attempt-2", "assignment_ids": ["assignment-9"], "invocations": 2, "known_cost_usd_estimate": "0.012000"}],
  "next_cursor": null
}
```

Normative rules for this shape:

- Money uses nonnegative finite decimal strings in USD, not binary floating
  point and not an implicit currency conversion. `cost_usd_estimate` is null
  unless history, attribution and pricing are all complete **through `as_of`**.
  `known_cost_usd_estimate` is the subtotal of known, attributed, priced facts;
  it does not claim a final task total. Zero is valid only when complete coverage
  explicitly establishes zero. Unknown token categories are null, not zero.
- `complete` is the conjunction of the three coverage flags and recorder
  coverage through the range. Reasons are allowlisted codes such as
  `history_pruned`, `recorder_gap`, `attribution_missing`, `pricing_missing` or
  `ingestion_pending`, with optional time bounds; never paths or raw errors.
  Task attribution completeness requires the host to establish that relevant
  session/assignment facts are covered. Unresolved facts that could belong to
  this task make it incomplete; do not hide them because no join was found.
- `recording: false` concerns current collection, not historical validity. It
  must create a coverage gap for an active task when usage might be omitted.
  `finalized: true` requires task/session closure and all expected usage ingested;
  corrections may still advance revision, so the UI never calls estimates a bill.
- A session response has `subject.kind: session` plus `session_id`; it returns
  `tasks[]` with scoped identities and an `unattributed` subtotal instead of
  `sessions[]`. At one snapshot, attributed task subtotals plus unattributed
  usage must equal session totals under the same filters. A task's `sessions[]`
  breaks down exactly that task's totals, not each session's other tasks.
- Aggregate totals cover the **entire result**, even if `sessions[]`/`tasks[]`
  paginate; repeating them on later pages does not add spend. Pages at one
  snapshot cannot change. Expired snapshots return typed `snapshot_expired`
  and the app refetches from page one. ETag/revision permits replacement reads,
  never accumulating snapshots. No SSE replay is required for correctness.

Each assignment row contains `assignment_id`, scoped task identity,
`session_id`, `session_attempt_id`, safe `worker_label`, `assigned_at`, nullable
`worker_observed_at`, nullable `ended_at`, `end_reason` (reassigned/completed/
failed/cancelled/unknown), and `boundary_complete`. Times are host UTC facts.
The envelope includes `history_complete`, safe missing-history reasons and the
same snapshot semantics. A still-open interval has `ended_at: null`; a missing
historical end must carry incomplete boundary evidence. The app may calculate
elapsed assignment time through `as_of`, labeling it as assignment time.
Summed worker intervals can overlap and exceed task wall time: expose the
intervals or label a sum as total worker assignment time, never “time billed.”

HTTP semantics: `200` may contain partial evidence; no silent truncation.
`400/422` rejects malformed ranges/scope. `401/403` uses the existing supported
host/front read authorization. `404` is unknown task/session, not zero usage;
`410` is unavailable retained history/snapshot. `503` is temporary inability to
read accounting. Errors expose safe codes and an opaque request ID only.
The front must explicitly route and authorize these reads before remote use;
Tailscale reachability alone is not permission. Reuse supported identity policy,
never forward OpenCode/provider credentials: the current
[HTTP client credential header block](../../lib/orchestration/client/http.dart#L71)
remains in force.

## App and UI hook-up contract for Claude

Until the host contract is implemented and verified on a target host, **add
nothing to task cost**: no adapter, speculative calls, polling ledger, new cost
number or zero placeholder. Keep existing Task Details “not reported” behavior
and the separate, qualified city-day estimate on the team page.

When support exists, add a domain-owned `TaskUsageGateway` and typed immutable
`TaskUsageEvidence`/`TaskAssignments` projections. Add explicit capability flags
for task usage, session lifetime usage and assignment history plus the negotiated
contract version; existing `capabilities.usage` means city usage only. Gate on
capabilities, never server flavor. Protocol adapters own HTTP parsing; state
owns fetch/replacement, cancellation on profile/task switch and stale state;
kit-based UI reads domain values only.

| Domain result | Truthful UI behavior |
|---|---|
| Unsupported | Existing no-task-cost explanation; no number. |
| Fetching or no evidence | Loading/unknown, never zero. |
| Complete, active task | “Estimated cost so far” with as-of time and exact scope. |
| Complete, finalized task | “Estimated cost” with pricing provenance in Details; never “charged” or “bill.” |
| Missing history, attribution or pricing | Do not show `cost_usd_estimate` as a total. A future supported partial view may explicitly show “Known estimate; some use is missing,” with distinct reasons. No partial cost UI is authorized by this document. |
| Last successful evidence followed by disconnect/error | Mark stale with last as-of time; do not claim the total is current. |
| Assignment history | Show worker, assigned/start-observed/end times separately; missing boundaries stay unknown. Do not infer billable or continuously active time. |

Use localized plain error wording with redacted Details; no raw host reasons.
Any future display copy goes in `app_en.arb`, then localization generation.
Refresh replaces evidence after reconnect; do not sum windows or mix snapshots.
No persistence is needed for an initial implementation. If later cached, use
`oc.<what>.<profileId>`, register a shared owner with the deletion transaction,
stop/drain writes before deletion, and persist only minimized redacted evidence.
No titles, prompts, transcript content, working-directory paths, provider keys,
auth headers or internal session metadata belong in accounting responses,
notifications, reports or clipboard. Task/session IDs and cost patterns remain
private operational data: authenticated scope checks, no public share link and
no analytics payload containing the raw response.

## Acceptance and unblock evidence

These are required future behavior tests, **not tests run by this docs job**:

1. Worker runs task A, is reassigned to B, then A's delayed model response
   arrives: cost remains on A; B never inherits the old window.
2. Duplicate fact delivery, cumulative usage revisions, app reconnect and host
   restart produce the same totals. A price correction replaces one revision.
3. A task crosses midnight, includes a failed/retried session, then closes while
   the app is offline: lifetime totals include every attempt exactly once.
4. A task with complete zero usage is distinguishable from missing price,
   recorder gaps, pruned history and missing attribution. The latter never
   display a zero or complete total. Unknown task returns 404.
5. Reused worker names and bead IDs in two rigs remain distinct. Nested task
   rollups include each fact once. Session reconciliation equals task allocations
   plus unattributed usage at a single snapshot.
6. Concurrent ingestion during pagination cannot alter the pinned snapshot;
   expired cursor restarts the read, and repeated aggregate totals are not added.
7. A thermal pause within an assignment does not create fake billed seconds.
   A missing end boundary stays unknown; simultaneous workers' elapsed time is
   never presented as task wall time.
8. Unsupported capability causes zero proposed-endpoint requests; existing city
   usage remains qualified. Malformed/version-mismatched data fails closed.
   Profile switch/deletion cannot deliver another profile's late response.
9. Credential-shaped payloads never reach visible error bodies, logs or copies;
   authorization isolates city/rig data and unsupported front routes stay off.

Existing [usage evidence tests](../../test/team_usage_evidence_test.dart#L7)
and [Task Details tests](../../test/team_usage_test.dart#L417) encode current
window/unknown/no-task-cost behavior; their source was inspected, not rerun.
The host owner must supply the ledger/assignment implementation, pinned schema,
supported permission/front routing contract and a target-host fixture proving
the examples above before the app owner adds an adapter. Historical data that
cannot be authoritatively joined must remain explicitly incomplete. No backend
piece is safe to add before that prerequisite.

Verification for this unit: source/schema review and documentation link/diff
checks only. No server, credential store, Flutter/native tests or builds were
accessed. Nothing is implemented, enabled, deployed or released by this design.

Documentation validation: all 73 relative links/line anchors across the four
contracts resolve, both JSON examples parse, and the staged whitespace check
passes. No application source changed; no runtime test pass is claimed.
