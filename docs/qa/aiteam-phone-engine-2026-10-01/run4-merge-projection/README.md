# Durable checked-merge projection

Finish line: the existing phone project promotion flow recognizes a completed
dev merge using durable checker evidence and scoped canonical merge receipts,
including completed projects created before this projection existed.

Non-goal: UI/domain changes, a process-merge command, changing promotion authority,
or inferring a successful check merely from a completed stage.

Workspace reads project completed task jobs into stable `merge-<jobId>` rows.
Only a validated check and matching private job/project merge receipt grant
`status: merged`, `checksPassed: true`. Missing/invalid evidence is blocked, never
an unimplemented queued action. Reads do not persist or change revisions.

New checker snapshots are stored on the job as well as the project task. Legacy
jobs may use matched task snapshots only with exact criteria/task/repo scope.

The original criteria must still match the current task for both new and legacy
jobs. Both the selected checker snapshot and current task must pass the engine's
actual `validate_check` (all criteria met and no findings). The task must already
be `merged`. Receipt scope binds repository/task, checked task commit and merged
commit, unchanged main, and exact before/after refs to an engine-authored project
receipt whose id is the job id and kind is `merge`. Refs must be full commit IDs.
New project receipts additionally store taskId; old receipt rows are accepted
only through their job-id and private job-receipt task binding. Historical valid
merges need not equal the latest dev SHA, which may have advanced with later jobs.

Projection preserves the current workflow and server data. Project deletion
removes the existing jobs and project receipts, so no extra deletion state exists.

Four focused regressions cover accepted receipt, completed without receipt,
14 failing verdict/scope/ref/current-task mutations, legacy task-only snapshots,
partial-evidence refusal, repeated GET stability and reopening. Fixtures exercise
the authenticated store transition contract; they are not a device Git proof.

- `cargo fmt`: passed.
- `git diff --check`: passed.
- Focused Rust tests: authored, not run in this worker.
- No UI/domain edits, heavy checks, device run, signing or push.

No heavy checks are run by this worker; root runs the focused Rust gate.
