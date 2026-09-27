# X52 — Team evidence and immediate dispatch (2026-09-27)

Finish line: expose the existing host's qualified usage, session/heat status and
create-then-sling progress as small Dart APIs for the later UI unit.
Non-goals: UI, native work, task-cost guesses, automatic pool recovery, a
five-second scheduling guarantee, deployment or release.

This is the backend portion of P5.2/P6.3, not completed product acceptance.
Starting revision: `e7762e60`, existing branch `codex/x52`.

## Scope and feasibility

Read: AGENTS.md; STANDARDS sections 2, 3, 13 and 15 only; the
[P5.2](../codex-p52-2026-09-27/README.md) and
[P6.3](../codex-p63-2026-09-27/README.md) handoffs; orchestration/domain/state
and thermal APIs; existing tests; the
[pinned supervisor schema](../../../contracts/gascity-supervisor-openapi-v0-3648ca2d499a.json).
Write ownership was split into usage DTO/model/mapper and its test; a new
dispatch controller and its test; and the overview projection, storage redaction,
tests and this integration record. No excluded single-owner file or UI was edited.
Dependencies: existing gateway, mutation controller, profile-scoped stores and
thermal guard. Acceptance for this backend unit is the behavior specified below;
focused checks are the four new test files and affected existing orchestration tests.

- **Available now:** `GET /v0/city/{cityName}/usage` already reaches the app.
  `UsageBody.today` is since midnight on the host; `recent_by_session` describes
  a trailing window with an optional Gas City session bead ID. The adapter now
  preserves these facts in typed domain models, including partial/unpriced flags.
- **No derivable task cost:** neither window has task attribution or assignment
  intervals. Windows overlap and cannot be accumulated. Current agent output
  uses conversation-format `/session/{id}/stream` and maps text. The schema's
  optional structured transcript format has `SessionStructuredUsage` token and
  context counts, but no dollar price or authoritative task join. A worker's
  current task cannot attribute its earlier spend. No task-cost adapter was built.
- **Available now:** `OrchestrationController.giveTask` already creates a bead,
  then calls `assignWork` immediately. The
  [control adapter](../../../lib/orchestration/adapters/gascity/gascity_control.dart)
  sends `/sling` with `{bead, target, reassign: true}`. This unit adds one-attempt
  state and observed worker evidence, not a second sling or scheduling timer.
- **Still missing:** no supported empty-pool recovery outcome or faster-start
  guarantee. The [older host measurement](../team-hot-2026-09-26/README.md)
  reported about eight seconds; it was not remeasured here. A receipt is not a
  worker start. Automatic recovery remains unavailable.
- Existing authentication/permissions are reused: loopback control with
  `X-GC-Request`, or the configured front's identity/control permission and
  idempotency handling. The front lacks create capability; bare remote hosts
  remain read-only. No credentials, host storage or live server were accessed.

## UI hook-up

### Team status and heat

Import [team_overview.dart](../../../lib/state/team_overview.dart). Recompute
`teamOverview(profileId:, host:, agents:, isStale:, heatHold:)` whenever the
existing orchestration controller or thermal guard notifies. Pass:

- `controller.profileId`, `controller.host` and the successfully loaded
  `controller.snapshot.agents`; use null agents while unsupported/unloaded.
- `isStale: controller.isStale || controller.phase != OrchestrationPhase.ready
  || controller.lastError != null`. Snapshot refresh times cover any scope,
  so do not hide a partial refresh error behind a newer timestamp.
- `heatHold: guard?.holds[controller.profileId]`, resolving the guard through
  the existing `thermalGuardSlotProvider`. Subscribe to the slot as well if
  the shell has not installed its guard yet.

Result: localize `activity` (unknown/idle/working/needsYou/blocked/pausedForHeat/
stoppedForHeat), `hostMode`, `agentCounts`, `isStale` and optional `heatHold`.
Session evidence takes precedence via the existing `teamSessionState`; waiting
and blocked states remain explicit. Inactivity is never treated as intentional
pause. Heat requires matching profile, phone host URL and city; `since`,
`status` and `serviceStopped` come from the actual hold. Counts are last-known
when stale. No projection data is persisted. No wiring in `main.dart` is needed.

### Spend

Import domain models through `domain/orchestration_gateway.dart`; no adapter
imports are needed in UI. Gate on `controller.capabilities.usage` and read
`controller.snapshot.usage?.evidence` on controller notifications.

| Field | Meaning and rendering rule |
|---|---|
| `evidence == null` / `available == false` | Unknown/unavailable, never zero. |
| `today.costUsdEstimate` | City-wide estimate since host midnight; never task cost. |
| `today.unpriced`, `partial`, `partialReasons` | Missing-price/history warning; zero can omit spend. Null unpriced means unknown. Redact reasons before diagnostics/copy. |
| `recording` | Whether new usage is being recorded; false does not erase existing history. |
| `observedFrom`, `updatedAt` | Oldest included fact and aggregate time, not day boundaries. |
| `recent`, `recentWindow`, `recentBySession` | Replacement window snapshots. Never sum refreshes or add session rows to city totals. |
| `recentBySession[].workerName`, `.sessionId`, `.totals` | Worker/window estimates. The optional ID is a Gas City session bead, not an OpenCode session/task ID. |

Each totals value exposes nullable input/output/cache-read/cache-creation tokens,
cost estimate and unpriced count. Negative/nonfinite figures become unknown.
The mapped lists are unmodifiable. Omitted session breakdown is null; a reported
empty list is empty. Preserve controller staleness/errors and `isEstimated`.
Task lifetime cost must continue to say unavailable. No per-task zero placeholder
or price-table calculation has been introduced.

### Submit and observe work

Import [team_dispatch.dart](../../../lib/state/team_dispatch.dart). Keep one
`TeamDispatchController(controller)` per task attempt, listen to it, then invoke:

```dart
await dispatch.submit(
  title: title,
  description: description,
  projectId: projectId,
  agentId: poolId,
);
```

Use `canSubmit` to gate the action. Both create and assign capabilities and a
ready, fresh source are required before any create. Empty required values are
rejected locally. Duplicate taps share the same future, including after an
uncertain result. A fresh instance is only for a deliberately new task; never
recreate one on every build or use it to retry an uncertain task.

Localize `phase`: idle, unavailable, invalidInput, submitting, rejected,
unconfirmed, awaitingWorker, workerObserved. Read `workId`, `createMutationKey`,
`assignMutationKey`, `createStatus`, `assignStatus`, `assignmentReceipt` for
receipt detail. `workerSessionId` requires a fresh snapshot naming an explicitly
running session on the exact work ID. An unrelated pool member or generic
agent state is insufficient. It is current observation, not proof of model
progress or a stored start timestamp; it becomes unknown on disconnect.

Dispose this notifier before its source and on profile switch/deletion. It adds
no persisted state, timers, retries or automatic recovery. After restart use
the existing controller mutation records/cycles to reconcile; do not resubmit.
Continue using `cycleFor(workId)` and `teamNow(...)` for the existing Now line.

## Exact missing server contracts (proposed, not implemented)

1. `GET /v0/city/{cityName}/bead/{id}/usage?from=<RFC3339>&to=<RFC3339>`:
   omit dates for task lifetime. Return `bead_id`, `currency: USD`, `as_of`,
   `from`, `to`, `source`, `complete`, `partial_reasons`, `unpriced`, nullable
   `cost_usd_estimate`, input/output/cache token totals and `sessions[]` with
   stable session/attempt IDs. The server must attribute immutable usage facts
   to task assignment intervals, deduplicate updates and include closed/retried
   workers across app downtime. It must distinguish no usage from missing
   history/pricing and publish price provenance. Use supported read access;
   no provider API keys or internal session metadata in responses.
2. For safe recovery, `POST /v0/city/{cityName}/dispatch` with an idempotency key
   and `{bead, target, recover_if_stalled: true, expected_generation}`. Require
   an explicit supported control permission. Return `202` with `operation_id`
   for acceptance only; expose `GET /v0/city/{cityName}/dispatch/{operation_id}`
   returning `bead`, `target`, `state`, `worker_session_id`, `accepted_at`,
   `started_at`, `recovery_action`, `recovered_at` and a safe reason code.
   Atomically check the expected generation and respect intentional suspension,
   thermal holds and stopped services; never wake them as stalled pools.
   Repeated keys return the same operation; changed bodies conflict. Terminal
   states distinguish running, refused/paused, failed and no recovery needed.
   A recovery success requires the matching worker and an attributable action.

The host may extend sling with equivalent semantics instead of adding endpoint
2. Its scheduler must still meet the measured latency target; a mobile wrapper
cannot guarantee it. Verify deployment support and permissions before adding
either adapter. These missing sub-slices stopped at feasibility.

## Privacy, persistence and verification

`MutationStore.save` and `OrchestrationStore.saveSnapshot` now pass stored
structures through `KitRedact`, preserving JSON structure and numeric facts.
The original task sent to the server is unchanged. A manual retry after restart
uses saved redacted text, so credential-like content may require re-entry.
Existing saved data is not retroactively scrubbed until rewritten. No new keys
or format migration; the existing profile/plugin deletion sweep still applies.
No raw transport exception is exposed by the new dispatch API.

Authored focused behavior tests:

- [team_overview_test.dart](../../../test/team_overview_test.dart): session
  precedence, stale/unknown/idle truth and profile/host-scoped heat reasons.
- [team_usage_evidence_test.dart](../../../test/team_usage_evidence_test.dart):
  partial/unpriced, unavailable, window/session and invalid-value semantics.
- [team_dispatch_test.dart](../../../test/team_dispatch_test.dart): capability
  gates, duplicate taps, receipt versus matching session, refusal/uncertainty
  and disposal.
- [team_storage_redaction_test.dart](../../../test/team_storage_redaction_test.dart):
  stored redaction/roundtrip, unchanged send data, numeric facts and profile keys.

Pinned `dart format --language-version=3.10` succeeded. It warned that
`package:flutter_lints/flutter.yaml` could not resolve; this worktree has no
package configuration. Flutter tests, analyzer and builds were **not run**,
as explicitly instructed. No failing-first or runtime pass is claimed.
Final formatting check covered all 12 changed Dart files with zero changes;
whitespace checks and all 12 relative documentation links passed.
Verifier: run pinned `flutter pub get`, the four files above serially, plus
`test/team_control_test.dart`, `test/team_controller_test.dart`,
`test/team_usage_test.dart`, `test/team_gascity_mappers_test.dart`, then analyze.

Implemented: backend APIs and storage safeguards. Enabled: usage mapping on the
existing read path; new overview/dispatch API requires UI hook-up. Verified:
source/schema review and formatting only; behavior tests await verifier.
Committed: see commit outcome below. Deployed/released: no. Original P5.2/P6.3
task-cost, pool-recovery, UI and timing acceptance remain open.

## Commit outcome

Included in the local X52 commit with subject
`feat(team): expose usage evidence and dispatch progress [skip ci]` and both
requested attribution trailers. The reusable message is in
[COMMIT_MSG.txt](../../../COMMIT_MSG.txt). No push requested or attempted.
