# Phone engine durable recovery and usage revisions

Finish line: an explicit resume reconciles the recorded worker or checker turn after pause/restart, without submitting that turn twice; usage snapshots refresh the workspace without invalidating the user's project command revision.

Non-goal: automatic restart admission, retrying an uncertain prompt, device boundary verification, or substituting unknown provider cost with zero.

## Changes

- Interruption records `resumeStage`. Repeated death while reconciling preserves that original stage. Neither opening the database nor recovery resumes a job automatically.
- `resumeTask` and explicitly requested `resumeProject` route a complete recorded session/directory/dispatch checkpoint to `resuming`. The daemon must observe the existing session and must never submit its original prompt again. Checker checkpoints additionally require the recorded task commit.
- `promptDispatch` records `dispatching` before network submission and `dispatched` after acknowledgment. An acknowledged checkpoint cannot regress to dispatching. Existing ambiguous jobs without this new checkpoint remain unavailable with `needsReconciliation`; there is no fabricated migration evidence.
- An interrupted job with no sessions can return to the fresh queue only at a known pre-dispatch stage. Uncertain session creation, an uncertain prompt without its session, corrupt checkpoints, and missing checkpoint stages fail closed.
- Usage-only updates retain the project revision used by Stop, Pause and Promote. They advance workspace revision, a separate `usageRevision`, durable usage state, and metadata-only usage events. Stage and other state changes still advance project revision. Unknown cumulative cost remains unknown.

## Validation ownership

Added store durability tests cover repeated restart/resume, uncertain acknowledgment retention, checker reconciliation, pristine pre-dispatch requeue, uncertain session creation refusal, missing checkpoint refusal, monotonic acknowledgment, and usage update/reopen/user-command behavior. The coordinator runs the focused Rust test suite under the shared machine lock; no test or build process was launched by this worker.

Formatting: `rustfmt --edition 2021 engine/phone/src/store.rs engine/phone/tests/store_durability.rs`.

Diff check: `git diff --check`.

Daemon integration dependency: persist `promptDispatch` before/after submission; continue from an observed completed worker into a newly admitted checker; reconcile merging receipts; safely prepare a fresh worker if pre-dispatch recovery finds a clone already created before the crash.
