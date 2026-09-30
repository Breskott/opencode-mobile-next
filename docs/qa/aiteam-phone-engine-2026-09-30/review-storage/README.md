# Phone engine storage review follow-up

Finish line: reject semantically invalid creates before canonical import, reject
unsupported charging-only admission settings, and bound durable activity history
with an explicit cursor-gap response.

Non-goal: power-state telemetry, repository collection (daemon/repository owners),
changing command idempotency, or pruning authored project/spec/promotion history.

## R7: preflight before repository side effects

`Store::validate_command(&Value) -> Result<(), StoreError>` validates headers and
applies the command to cloned workspace/jobs under the store lock. It writes no
SQLite rows, events or replay results. The daemon must first check
`command_result` for replay, preflight before importing, then use ordinary
`execute` to persist a semantic rejection. Final execution rechecks the current
state; preflight does not reserve a revision or claim imported refs.

Regressions verify invalid budget rejection, unchanged workspace/jobs/events and
request reuse after preflight, plus valid planner preflight creating no durable
job and a subsequent stale-revision refusal. Removing semantic validation causes
the rejection assertions to fail; persisting the clones fails the unchanged-state
assertions.

## R8: unsupported charging-only setting

Until Android power state is carried in authenticated admission telemetry,
`chargingOnly: true` returns `chargingUnsupported` on creation, defaults and
project settings updates. Existing charging-only projects need their setting
changed to false; the engine still pauses them when charging is unknown.

The regression covers all three command paths and unchanged durable state after
rejection. Removing the refusal makes these commands accepted and fails the test.

## R10: durable event retention and honest cursor gaps

The latest 10,000 activity rows are retained. A transactional, durable
`event_retention.pruned_through` watermark records the highest removed sequence.
Retention runs on every event append and on database open, including migration of
previously unbounded logs. SQLite sequence numbers keep increasing; project data,
command replay results, spec versions and receipts are unaffected.

`events(after, limit)` returns `cursorExpired` when `after < prunedThroughSeq`.
The exact cutoff cursor remains valid. `event_window()` provides additive
`retentionLimit`, `prunedThroughSeq`, `earliestAvailableSeq` (nullable), and
`latestSeq` metadata. The daemon supplies this metadata with a cursor-expired
error and `resetRequired: true`; clients must refetch workspace and disclose that
older activity is unavailable instead of presenting an incomplete since-away
digest as complete. Successful event responses retain their list format.

Regressions seed realistic SQLite rows without thousands of unrelated project
mutations, then exercise normal command append, reopening, old-schema migration,
the cutoff boundary, retained row count and unchanged replay state. Removing
pruning or cursor detection fails the retention/gap assertions.

## Verification

- `cargo fmt --manifest-path engine/phone/Cargo.toml`: passed.
- `git diff --check`: passed.
- Tests authored, not executed in this worker. Root runs the serialized focused
  Rust gate after integrating the daemon and repository changes.
- No Flutter/native build, Android/device proof, signing or publication performed.
