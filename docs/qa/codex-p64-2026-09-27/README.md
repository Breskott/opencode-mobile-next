# P6.4 — Merge on green, levers in overflow (2026-09-27)

## State

**Blocked at feasibility; no runtime changes.** The requested reversible merge
journey cannot be implemented against the current callable host contract.
The user explicitly required stopping if feasibility fails. No controller,
adapter, storage, UI, or single-owner file was changed. Nothing was enabled,
deployed, pushed, signed, or released.

Inspected candidate: `codex/p64`, base `e60218d5`; working tree initially clean.
Read `AGENTS.md` and only sections 2, 3, 13 and 15 of
`docs/ux-system/revamp/STANDARDS.md` (using heading search and sed ranges).
No `HANDOFF.md` was present in this worktree.

## Scope and finish line

Finish line: expose backend state that automatically merges passing tasks under
Balanced or Autonomous, reports a confirmed receipt, and offers a real reversible
Reopen operation where git permits, while High still requires confirmation.

Non-goals: UI composition, primary/overflow placement, changing High supervision,
host deployment, credential changes, and all user-excluded files.

Read set: orchestration domain interfaces, merge/policy models, Gas City adapters,
orchestration/team-planning/team-board state, host front implementation and its
README, and the read-only KitRedact API. Write set: this QA record and, if Git
metadata is unwritable, root `COMMIT_MSG.txt`.

Dependency: an implemented, authenticated host operation for reversing a specific
merge, with receipts and explicit availability/refusal semantics. Acceptance
would require confirmed automatic merge, reversible git result, unchanged High
behavior, and later UI wiring. Focused behavior tests were conditional on that
contract being feasible; no new runtime behavior was added to test.

## Feasibility evidence

- [Merge gateway](../../../lib/domain/orchestration_gateway.dart#L577) exposes
  readiness, approve and merge only. There is no reverse-merge operation or
  capability. The [front route table](../../../tool/host/cp_front/front.py#L84)
  and [route handler](../../../tool/host/cp_front/front.py#L1258) implement the
  same operations plus read-only policy.
- [Host merge](../../../tool/host/cp_front/front.py#L1045) performs a fast-forward
  or merge commit and pushes to the target branch. It returns the merge commit
  and branch in the response; reopening a work item cannot undo this git change.
- [Work reopening](../../../lib/orchestration/adapters/gascity/gascity_work_edits.dart#L89)
  only posts to `/bead/{id}/reopen`. Its domain interface promises to open a
  closed work item, not reverse a merge. The current board only offers this move
  for cancelled cards ([team_board.dart](../../../lib/state/team_board.dart#L405)).
- Authentication for the existing front is established in source: Tailscale
  identity and an allowlist gate writes; idempotency keys identify stored
  receipts ([host README](../../../tool/host/cp_front/README.md#L14),
  [mutation handler](../../../tool/host/cp_front/front.py#L1296)). No new
  credentials or live host access were used. This is source-contract evidence,
  not proof of any currently deployed host version.
- Balanced/Autonomous alone do not authorize bypassing host approval. The host
  reports supervision without enforcing it, and `require_approval` independently
  defaults to true ([host README](../../../tool/host/cp_front/README.md#L263),
  [boundary evaluation](../../../tool/host/cp_front/front.py#L914)). A caller
  cannot promise unconditional merge-on-green from supervision alone. Also,
  [the current Balanced planner message](../../../lib/state/team_planning.dart#L29)
  explicitly asks before merges; it was left unchanged with the blocked slice.

## Contract problems

Blocking P6.4 acceptance: no callable git reversal contract exists. Do not label a
bead reopen as reversing a merge, invent a remote endpoint, send shell commands to
an agent as an undo workaround, or silently approve a human approval boundary.

Required host follow-up: define and implement reversal availability tied to the
original merge receipt, target branch and expected commit; distinguish
fast-forward from merge-commit reversal; refuse conflicting or changed targets
safely; return an idempotent receipt and refetchable outcome. Expose that contract
and capability through the orchestration domain. Also establish how explicit
Balanced/Autonomous consent interacts with host approval boundaries while keeping
High unchanged. These are prerequisites, not APIs implemented by this change.

## UI hook-up

There is **no new P6.4 Dart API to wire** while feasibility is blocked. Keep
automatic merge and reversible Reopen unavailable. Existing state APIs are:

- `OrchestrationController.mergeReadiness(runId, force: true)` refetches readiness;
  `mergeReadinessFor`, `mergeReadinessError`, and `mergeReadinessLoading` expose
  cached read state. `MergeReadiness.canMerge` includes host boundaries.
- `OrchestrationController.mergeRun(runId)` returns a `MutationRecord` through
  the existing mutation/receipt path. Its current documented contract is a
  confirmed human tap; do not add an automatic caller as part of this handoff.
  A sent or pending receipt is not a confirmed merge. Refetch after reconnect.
- `OrchestrationController.controlAgent(agentId, AgentControlAction.nudge /
  restart / stop / pause)` returns a `MutationRecord` for existing worker levers.
  `refresh()` refetches current state. These existing methods can back a later
  kit overflow; placement is the UI owner's responsibility.
- `TeamBoardEdits`/`OrchestrationWorkEditGateway.reopenWork` concern work-item
  status only. They must not power a promise to undo the git merge.

Future persisted automation receipts must pass through `KitRedact` and follow
profile deletion rules. This change persists no runtime data or credentials.

## Verification

Source inspection confirmed the missing reversal route in both domain and host.
Checked this record's relative links and `git diff --check`. No Dart files
changed, so formatting, Flutter behavior tests and analysis were not run
(docs-only rule PROC-28). No device, screenshot, full-suite, or live behavior
verification is claimed.

Commit attempted but blocked: Git could not create the worktree's `index.lock`
because its metadata filesystem is read-only. The requested commit message is
saved in root `COMMIT_MSG.txt`. Changes remain in the working tree (the initial
README was staged before the commit failure); the integrator must stage the
final README again before committing. No commit was created.
