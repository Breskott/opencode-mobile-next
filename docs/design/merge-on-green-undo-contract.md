# P6.4: merge on green and undo host contract

Status: **proposal, blocked; no runtime implementation or enablement**. Reviewed
2026-09-28 against integration revision `98c4c67a`. This supersedes no existing
API: the routes, fields, capabilities and domain types below are proposed.

Finish line: an authorized merge has a durable, queryable receipt identifying
the actual target before and after the atomic update, and a bounded undo can
append a restoring commit without removing unrelated work. Non-goals: changing
supervision, approving a host boundary automatically, deploying a front, or
implementing shell-based Git mutation in the phone.

## Current evidence and remaining blocker

The [x64 feasibility record](../qa/codex-x64-2026-09-27/README.md) remains valid
after the integration merge:

| Current source | What it proves, and what it does not |
|---|---|
| [Host candidate build](../../tool/host/cp_front/front.py#L820) and [readiness](../../tool/host/cp_front/front.py#L871) | The host fetches origin and can construct fast-forward or sequential multi-branch results. It computes a target/source fingerprint internally. The public document omits the old target and exact source revisions. A later candidate fetch can also observe newer refs. |
| [Host merge](../../tool/host/cp_front/front.py#L1045) and [route](../../tool/host/cp_front/front.py#L1289) | Merge recomputes readiness, checks lines and boundaries, then performs an ordinary push. The request carries no expected target/source revisions. The response has `mergeCommit`, `branch`, `branches`, `fastForward`; these do not identify the baseline for the whole operation. |
| [Receipt store](../../tool/host/cp_front/front.py#L293) and [receipt write](../../tool/host/cp_front/front.py#L1476) | Completed responses are persisted and replayed by idempotency key. Persistence follows the Git mutation; a crash between push and receipt leaves ambiguity. Per-key serialization is not serialization of competing writes to one branch. |
| [Rig mapping](../../lib/orchestration/adapters/gascity/gascity_mappers.dart#L1040) and [profile configuration](../../lib/state/profiles.dart#L102) | The app has a rig directory and a separately configured orchestration URL. These do not prove that an OpenCode shell sees or pushes the same repository as the front. |
| [Merge domain interface](../../lib/domain/orchestration_gateway.dart#L583), [adapter](../../lib/orchestration/adapters/gascity/gascity_control.dart#L246), [readiness model](../../lib/orchestration/models/merge.dart#L155) | Current operations are readiness, approval and merge. No undo, baseline binding or reversible receipt contract exists. |
| [Manual controller action](../../lib/state/orchestration.dart#L1160) and [automation preference](../../lib/domain/automation_policy.dart#L81) | `mergeRun` is documented as a person's confirmed action. `allowsAutoMerge` is a local permission predicate; current `lib/` contains no execution consumer of that getter. A stored preference is not implemented automatic merging. |

The generic [managed shell interface](../../lib/domain/managed_shell.dart#L53)
and [OpenCode 2 adapter](../../lib/api2/gateway_operations.dart#L322) already
provide command execution with an explicit directory and polling. A missing
generic shell endpoint is therefore not the blocker. The missing facts are
authoritative repository identity, an atomic baseline and recoverable outcome.

Concrete race: the app observes target A; another writer advances it to X; the
host builds and pushes C containing X. Restoring A's tree would remove X's
changes. A final first parent does not bound an entire fast-forward or
multi-branch operation. Checking that the remote still equals C only guards
changes after this merge; it cannot establish what preceded it.

## Host identity and immutable merge plan

Advertise a new versioned `reversibleMergeV1` capability only when **all** of
these contracts are available for the selected rig. Existing `merge` or
`mergeReadiness` support is insufficient. Unsupported hosts return unavailable;
the phone must not infer support from server flavor or hostname.

`GET /v0/city/{city}/front/merge-plan/{run}` returns an authenticated plan:

| Field | Required meaning |
|---|---|
| `planId`, `planVersion`, `expiresAt` | Opaque durable plan identity, schema version and host-clock expiry. A plan identifies immutable inputs; refresh creates a new plan. |
| `binding` | `{hostInstanceId, repositoryId, bindingVersion, rigId, targetRef}`. `repositoryId` identifies the authoritative push destination, not a worktree, URL string or commit shared with a mirror. Configuration changes invalidate the binding version. |
| `beforeCommit`, `beforeTree` | Full object IDs for the observed target. State the Git object format; do not assume 40-character SHA-1. |
| `sources` | Ordered `{workId, ref, commit}` entries and run membership revision. No floating branch names are permitted during execution. |
| `candidateCommit`, `candidateTree` | Exact planned result built from those inputs, retained by the host through receipt retention. The result must descend from `beforeCommit`. |
| `checks` | Required check IDs, check/config version, result, completion time, and exact candidate commit/tree plus input fingerprint. Missing, skipped, running, expired or mismatched evidence is not green. |
| `policyVersion`, `boundaries`, `authorization` | Host rules and satisfied approvals bound to this plan's revisions. Local supervision cannot satisfy `require_approval`. Re-evaluate authorization at mutation time. |
| `reversal` | Whether this exact plan is reversible, supported strategy, host retention deadline and proposed undo deadline. No reversible promise for an already-merged/no-change result. |

Keep repository credentials, credential-bearing origin URLs and shell output
off this wire. An opaque repository ID comes from trusted host configuration
and authenticated discovery, not an arbitrary value supplied by a repository
file or UI form. A host rename is not a new repository; a changed remote is not
silently the old binding.

## Atomic merge and durable outcome

`POST /v0/city/{city}/front/merge/{run}` gains a negotiated v1 body containing
`planId`, `bindingVersion`, `expectedTargetCommit`, ordered expected source
commits, and a scoped authorization reference. It requires an `Idempotency-Key`.
Old unversioned manual requests keep their existing semantics and do not acquire
a reversible claim. Automatic requests require the new capability explicitly.

The host must perform this sequence:

1. Authenticate and authorize the caller for this repository, target, run and
   operation. Check the scoped authorization's expiry/revocation, current host
   policy and any independent human approval. Validate every identifier and
   ref; never interpolate request text into a shell command.
2. Durably record the request identity and canonical body digest before any
   external mutation. Reusing a key with different inputs, path, operation or
   principal is a conflict; an exact retry returns the same operation.
3. Validate the binding, run membership, exact target/source inputs, pinned
   candidate and required check evidence. Changed inputs require a fresh plan
   and fresh checks. Do not silently recompute a different candidate under the
   approved plan. Serialize host operations per authoritative repository/ref.
4. Atomically compare the **authoritative destination ref** to the expected old
   object ID and advance it to the pinned descendant. That successful compare
   establishes the receipt's actual `beforeCommit`. A local process lock or
   preflight fetch is insufficient against another Git writer. If the push
   destination cannot enforce this condition, refuse reversible automation.
5. Persist a terminal receipt with actual before/after commit and tree IDs,
   binding, source revisions, plan/check evidence references, actor, timestamps,
   undo deadline and result. Return success only after durable confirmation.

Git's local `update-ref <ref> <new> <old>` provides a checked ref update;
ordinary push's fast-forward rule alone does not express the plan's expected
old value. The host implementer must supply an equivalent checked transaction
at the actual destination and separately enforce ancestry. Updating a local
tracking ref is not sufficient. This is a contract requirement, not permission
to force-push. See the official [checked ref update documentation](https://git-scm.com/docs/git-update-ref)
and [push fast-forward rules](https://git-scm.com/docs/git-push).

`GET /v0/city/{city}/front/merge-operations/{operationId}` and
`GET /v0/city/{city}/front/merge-operations/by-request/{requestId}` return the
same durable operation, authorized to its owner/authorized repository readers.
States are `prepared`, `applying`, `merged`, `rejected`, `reversing`, `reversed`,
or `unknown`. `202` means pending, not merged. Typed rejection codes include
`stale_target`, `stale_sources`, `checks_not_green`, `binding_changed`,
`approval_required`, `expired`, `forbidden`, and `storage_unavailable`.

Host restart recovery must reconcile a durable pre-intent against the
destination's transaction evidence, including a push whose response was lost.
A retained transaction ID/ref log tied to the operation must disambiguate an
already-applied operation even if later commits advanced the target. Merely
finding the candidate object or seeing a matching tree is not proof that this
request applied it. Unknown stays unknown, blocks a fresh mutation for that
operation, and offers query/manual reconciliation; it must never become an
automatic retry with a new key. Corrupt or unavailable receipt storage fails
closed. Retain receipts/tombstones long enough for the advertised retry and
undo windows; expiry must not allow a replay to perform a second mutation.

## Preferred undo: host-owned restoring commit

`POST /v0/city/{city}/front/merge-operations/{operationId}/reverse` requires a
new idempotency key, the merge receipt ID, `expectedCurrentCommit` equal to its
`afterCommit`, and a short-lived confirmation reference bound to the actor,
repository, branch, merge operation and deadline. Confirmation is not Git
authorization; recheck both. The host is the authority for expiry, including
after an app restart. Do not place confirmation references in links or logs.

For a confirmed merge A → C, construct restoring commit R with **parent C and
tree A**. Atomically advance the destination C → R, preserving the history and
any unrelated commits already included in A. This reverses the whole recorded
operation for fast-forward and multi-branch merges alike. Never reset the
remote, rewrite history, force-push, or delete branches/worktrees. If target
has advanced to D, refuse; do not restore A's tree on D, which could remove
unrelated later changes. Manual conflict-aware recovery is a separate action.

The reversal uses the same durable intent, outcome querying and idempotency
rules as merge. A lost response does not justify a second restoring commit.
One merge permits at most one successful automatic reversal. Expired,
already-merged/no-change, unknown, missing-object or unverifiable receipts
cannot offer undo. Undo changes repository contents only: it cannot reverse
deployments, published packages, data migrations or work performed elsewhere.
Do not promise those effects. Reopening a bead is a distinct work-status action.

## Alternative: verified shell binding

A future app-side implementation can use the existing managed shell only after
the host provides the same authoritative merge receipt and verifiable binding.
It needs authenticated evidence joining front `repositoryId`/binding version
to a specific shell server instance, allowed directory and actual push target.
The evidence must be fresh, scoped and invalidated by remote, directory or host
changes. A path string, Tailscale node address, matching commit or caller's
claim is not that evidence. Git push permission must be separately established.

Shell execution would create R in an isolated checkout, verify it has parent C
and tree A, and request a checked non-rewriting update of the bound target.
The same durable operation/recovery ownership is still required; shell exit
status alone cannot recover a lost successful push. Ordinary push from R
rejects a divergent concurrent advance, but a host-verified expected-ref
condition remains the contract. Do not build shell strings or run an AI prompt
to approximate the missing contract. Prefer host reversal to avoid giving the
phone a second Git execution and credentials boundary.

## App and Claude UI hook-up contract

Until the negotiated contract exists, refuse automatic merge, reversible merge,
an undo timer/button, guessed-baseline restoration and shell fallback. Preserve
the existing separately confirmed manual merge/readiness flow with no undo
promise. [Work reopen](../../lib/domain/orchestration_work_edits.dart#L71) must
never be labelled Git undo. Stored automation consent must not make a legacy
merge eligible for unattended execution.

Proposed domain interface: `ReversibleMergeGateway.loadPlan(runId)`,
`commitPlan(planId, requestId, authorization)`, `getOperation(operationId)`,
`findOperation(requestId)` and
`reverseOperation(operationId, requestId, confirmation)`. These are design
names, **not callable Dart APIs**. Adapters own transport, domain models own
typed failures and sanitized presentation facts, and one controller owns
admission, durable pending operations, expiry, reconnection and policy checks.
Require both protocol-neutral capability support and explicit current local
automation permission plus host authorization. No flavor checks in UI.

| Controller state | UI truth and permitted action |
|---|---|
| Unsupported or unbound | Existing manual workflow only; explain unavailable reversible support when relevant. |
| Checking / waiting for green | Show outstanding checks for the actual planned revisions. No success indication. |
| Ready / authorized | Show target and scope; manual confirmation or previously scoped automatic permission applies. |
| Submitting / applying | Show merge in progress and suppress duplicate admission. |
| Unknown / reconnecting | Say the result has not been confirmed; offer Check status. No retry with a new key and no Undo. |
| Merged with valid reversible receipt | Show confirmed completion and host-derived undo deadline. Enable Undo only while eligible. |
| Reversing / reversed | Show progress, then confirmed repository restoration. Do not imply bead reopening or deployment rollback. |
| Refused / expired / target advanced | Give a plain explanation and safe next action; preserve the known operation history. |

All components come from the kit. Visible copy is authored plain language,
localized through `app_en.arb`; redacted technical context goes only in Details.
No server exception text, shell output, raw remote URL or credential belongs in
notifications, clipboard or audit rows. If local operation metadata is added,
use `oc.<what>.<profileId>` and include its admission/drain owner in profile
deletion. Deleting local state must not imply cancellation of a host merge.

## Acceptance before enablement

These are required future host/domain behavior tests, not tests run or passing
for this proposal:

1. Target changes A → X between plan and commit, including X already contained
   in a source: reject stale target; no mutation, no fabricated A baseline.
2. A source branch/run membership changes or check evidence refers to another
   tree/config: reject; never merge refreshed unchecked content.
3. Two different keys target one branch concurrently: at most one applies the
   same baseline; all other callers must replan. Include an external Git writer.
4. A host crash before push, after push before receipt, or during reversal is
   recoverable by the same request ID without another merge/restoring commit.
5. Receipt I/O failure, corruption or missing retained evidence leaves mutation
   disabled/unknown; it does not discard history and replay the operation.
6. Changed repository binding, same path in another namespace, or same commits
   in a mirror cannot authorize a mutation of the wrong repository.
7. For fast-forward and sequential multi-branch merges, R's parent is exactly C
   and R's tree exactly A; prior unrelated changes survive. A later D refuses
   undo and remains untouched. No test executes force-push/reset/delete.
8. Expired/revoked/cross-principal authorization and host approval boundaries
   reject even with local low-supervision/merge-on-green preferences enabled.
9. App death, profile deletion or lost network never produces a false success,
   a duplicate operation, an extended undo window or an assumed cancellation.
10. UI tests distinguish unsupported, checking, unknown, refused, merged and
    reversed; security tests prove raw Git errors/remote credentials stay out
    of body copy, Details after redaction, logs and notification text.

This document changes no code and establishes no deployed host capability.
Validation for this change is source tracing and documentation link/diff checks;
no live Git mutation, server access, Flutter tests or host test run is claimed.

Documentation validation: all 73 relative links/line anchors across the four
contracts resolve, both JSON examples parse, and the staged whitespace check
passes. No application source changed; no runtime test pass is claimed.
