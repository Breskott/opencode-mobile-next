# Run 4 planner projection

Finish line: an approved spec exposes its newest durable planner stage and typed
admission reason in workspace, with durable readable queue/progress timeline rows.

Non-goal: UI changes, scheduler/admission changes, device/server readiness or
changing project command revisions on read.

## Contract

Additive `planningState` is null without a planner, otherwise
`{jobId, stage, reason, updatedAt}` from the newest durable planner job.
Existing project `status` remains unchanged. Domain type is `TeamPlanningState`.
Legacy workspaces without metadata remain readable.

Timeline rows use the existing `TeamTimelineEvent` schema, canned text only,
actor `engine`, kind `planner` or `job`. Rows describe queue, stage or changed
admission reason; unchanged reasons and usage snapshots produce no rows.
The newest 500 project timeline rows are retained. `timelineTruncated` becomes
true after pruning; the separately bounded activity log remains cursor based.

Deletion uses the existing project/profile sweeps. No extra preference keys,
files, credentials, paths or raw model responses are added.

Successful starting/running/checking/merging/completed/resuming transitions clear
only prior queued admission reasons when no explicit new reason is supplied.
Interruption, pause and uncertain-dispatch reasons retain their durable evidence.
Terminal timeline wording takes precedence over an old wait reason.

The run 4 primary dispatch blocker (empty default-role model) is a separate root
fix. This slice exposes checkpoints and removes misleading stale wait copy; it
does not enable an execution driver or claim that planner dispatch succeeds.

## Verification

Four focused Rust regressions and three Dart domain regressions are authored.
They cover persisted queue/reason/stage, read-only projection, no repeated reason
or usage timeline noise, newest planner selection, recovery, bounded history,
project deletion, and legacy domain compatibility.

- Rust and pinned Dart formatting: passed.
- `git diff --check`: passed.
- No heavy tests/analyzer/device check launched by this worker. Root runs the
  focused Rust and Dart regressions under the machine lock after integration.
