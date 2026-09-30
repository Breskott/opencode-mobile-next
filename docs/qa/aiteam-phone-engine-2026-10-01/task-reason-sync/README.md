# Authoritative task reasons after admission

Finish line: an admitted task clears the stale waiting reason in both its job
and task, and older durable task snapshots display the current scoped job reason.
Non-goal: changing admission, stages, dispatch, checker evidence or usage revisions.

The existing job admission-clear decision now updates task.reason too. Explicit
nested task reasons retain their meaning and also become the job reason. A
read-only workspace projection copies the existing string reason from the latest
row-ordered task job matching both projectId and taskId; it changes no status,
checkpoint, event, or revision.

Two regressions cover queued/starting admission, continued blocked updates,
usage-only updates preserving command revision, interrupted and explicit nested
reasons, unchanged session/dispatch/check evidence, and legacy scoped projection
with multiple job rows and unchanged raw storage.

Worker validation: cargo fmt and git diff --check passed. No tests/builds launched.
Coordinator focused gate: cargo test --lib store::checker_publication_tests.
