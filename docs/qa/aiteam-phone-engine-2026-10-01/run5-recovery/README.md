# Run 5 restart recovery and limited-budget admission

Finish line: a ready daemon automatically refetches a restart-interrupted recorded
session, or exposes a typed review reason; no duplicate worker/prompt; a fresh
session does not prevent its own first limited-budget prompt.
Non-goal: changing explicit pause/stop, granting unknown usage, or UI changes.

## Contract

- `recover()` still records `restartNeedsReconciliation`. Only a ready daemon calls
  `reconcile_restart_jobs()`. It handles that exact reason, preserves original
  session/directory/dispatch checkpoints, and runs once durably. An unsafe
  checkpoint becomes `recoveryNeedsReview`, not an endless generic wait.
- Refetching a recorded session does not create a lane or incur provider spend and
  bypasses new-work chat/budget admission. New checker creation and integration
  still require admission. Existing `resumeProject` and `resumeTask` commands
  remain available; explicit paused/stopped/review states never auto-resume.
- Session errors/unknown evidence become `sessionFailed`/`sessionUnknown`; no
  replacement prompt, clone, or fabricated completion. Unknown polling remains
  bounded by the existing 30-second initial evidence window.
- Native-only `freshSessionIds` is recorded atomically with a newly created
  session. Only that matching provenance plus no dispatch checkpoint permits
  zero usage before its first prompt. Missing legacy provenance, dispatching,
  dispatched and malformed markers preserve unknown. A fresh checker preserves
  the actual worker's cumulative cost and tokens.
- First dispatch records UTC `sessionDispatchDays`. Same-day first cumulative
  usage is attributed to that day; subsequent cumulative deltas are durable.
  A first observation spanning a day boundary stays unknown rather than assigning
  historic spending to today. Completed jobs from a prior measured day contribute
  zero today. Usage-only updates do not change command revision.
- Dev merge and receipt publication share one daemon queue mutex. Signed private
  merge journals bind repo/task/job and the checked evidence fingerprint. At
  ready attachment, interrupted merge journals are published before later jobs
  can advance dev. Original before/after refs are recovered, never guessed.
  `mergeReady` also receives a restart checkpoint. Main protection is unchanged.

## Verification

Root agent owns serialized Rust/Dart checks and real API35 UI evidence. This
slice adds six Store regressions and four daemon regressions; no heavy tests or
emulator started by this worker. Repository journal crash controls are recorded
in `../run5-merge/README.md`.

Parallel workers now commit verification reports to
`.aiteam-verification/<taskId>.md`, preventing independent tasks from conflicting
on the engine-required common report. Checkers inspect that exact task report;
older engine reports may be read only when they contain actual evidence for the
same task/criteria. One additional regression checks the distinct paths.
