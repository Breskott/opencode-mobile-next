# P6.4 reversible merge feasibility — x64, 2026-09-27

## State

**Blocked at the merge contract; documentation only.** OpenCode 2 already has
the necessary general-purpose shell endpoint. The missing pieces are an
authoritative merge baseline and a verified binding to the repository Gas City
pushes. No reversible controller, audit store or undo window was implemented;
automatic merge and undo remain unavailable. No runtime behavior was enabled,
deployed or released.

Inspected `codex/x64` at `1625ac02`, initially clean. Read `AGENTS.md` and only
STANDARDS sections 2, 3, 13 and 15 using heading searches and `sed` ranges. No
`HANDOFF.md` exists in this checkout. This is current source-contract evidence,
not verification of any deployed server.

## Scope and acceptance

Finish line: a controller API that merges with a known reversible Git outcome,
records a redacted audit, and accepts a bounded confirmation token for undo.
Non-goals: UI wiring, changing supervision/approval policy, server implementation
or deployment, and edits to the excluded single-owner files.

Read set: orchestration/domain/state, OpenCode shell adapters and contracts,
`tool/host/cp_front`, prior P6.4 evidence, and the read-only KitRedact API.
Write set: this record and root `COMMIT_MSG.txt`. Three independent read-only
audits covered merge receipts, shell execution, and repository binding; no
reviewer ran tests. Dependency: the contracts below must establish which remote
Git change is being reversed. Acceptance requires refusing stale targets,
preserving unrelated commits, and recovering an uncertain outcome after restart.

## What already works in the client contract

- [ManagedShellGateway](../../../lib/domain/managed_shell.dart#L53) accepts a
  command and explicit directory, then exposes shell-ID polling, exit status
  and paged output. The [OpenCode 2 adapter](../../../lib/api2/gateway_operations.dart#L321)
  uses `POST /api/shell` with `command`, `cwd` and ownership metadata, followed
  by `GET /api/shell/{id}` and `GET /api/shell/{id}/output`
  ([polling/output](../../../lib/api2/gateway_operations.dart#L379)). This can
  run Git directly; an AI prompt is unnecessary. Gate it on
  `ServerCapabilities.developmentServices`
  ([v2 capabilities](../../../lib/api2/gateway_mappers.dart#L34)); v1's managed
  shell implementation is [unsupported](../../../lib/api/product_repository.dart#L33).
- OpenCode 2 uses its existing [Basic-auth transport](../../../lib/api2/transport.dart#L8).
  Gas City front writes separately use Tailscale identity and an allowlist
  ([host documentation](../../../tool/host/cp_front/README.md#L14)). Neither
  HTTP credential establishes Git push permission or a shared filesystem. No
  credentials, live server access or Git mutations were used for this audit.
- [Team merge](../../../tool/host/cp_front/front.py#L1045) supports fast-forward
  and merge-commit results. It builds in a
  [fresh clone](../../../tool/host/cp_front/front.py#L820), pushes to the rig's
  origin target branch, and returns `mergeCommit`, `branch`, `branches` and
  `fastForward` in the receipt. A local checkout reset does not undo that push.
- [Rig mapping](../../../lib/orchestration/adapters/gascity/gascity_mappers.dart#L994)
  exposes the host's rig path. Readiness identifies the rig and target branch.
  Those are useful inputs, but do not prove that the OpenCode shell sees the
  same repository: [OrchestrationConfig](../../../lib/state/profiles.dart#L115)
  has its own URL, and its host mode describes placement rather than proving
  shared repository identity.

## Why app-side undo is not yet safe

1. **No atomic pre-merge baseline.** The host knows `heads[target]` internally
   ([readiness calculation](../../../tool/host/cp_front/front.py#L898)), but
   does not return it in the [readiness document](../../../tool/host/cp_front/front.py#L925)
   or successful receipt. Readiness's `mergeCommit` is the candidate result,
   not the old target. The [merge handler](../../../tool/host/cp_front/front.py#L1290)
   does not accept an expected target SHA: it recomputes readiness and fetches
   again. A confirmation token in Dart cannot make that server operation
   conditional on the app's earlier snapshot.
2. **A concrete race loses unrelated work.** The app observes target A; another
   writer advances it to X; the host then fast-forwards to C, which includes X.
   A reversal restoring A's tree also reverses X. Checking that the current
   remote still equals C prevents a later-write race, but cannot establish
   that A was the actual baseline of this merge. An audit or undo timer does
   not repair that missing fact.
3. **Commit shape is not a general substitute.** A single non-fast-forward
   merge can expose its baseline through its first parent. The host also
   supports fast-forward and sequential multi-branch merges
   ([candidate construction](../../../tool/host/cp_front/front.py#L820)); the
   final first parent does not necessarily bound the entire run. Restricting
   undo to some post-merge shapes would not guarantee reversibility before
   performing the merge, and repository binding would still be missing.
4. **No authoritative shell-to-target binding.** The rig path has no remote
   repository identity to compare against the shell's Git origin. Matching
   path strings, hostnames or commit SHAs is insufficient across namespaces,
   clones and mirrors. Supplying an unverified directory would move this
   safety prerequisite to the caller rather than implement it.

This refines the [prior P6.4 blocker](../codex-p64-2026-09-27/README.md): the
absence of a dedicated reversal route alone is not proof of infeasibility.
The existing shell is sufficient once these merge facts are guaranteed.

## Required server contract

Preferred missing operation: an authenticated, idempotent
`POST /front/merge/{run}/reverse` **(proposed; not implemented)**, bound to the
original merge receipt, expected current target SHA, and confirmation expiry.
The host must capture the actual pre-merge target during merge execution,
serialize/guard competing target mutations, retain the before/after SHAs and
repository/branch identity, and offer a refetchable reversal receipt. Reversal
should append a restoring commit and reject an advanced target; it must not
force-push or rewrite unrelated history. Repeated requests must resolve to the
same outcome; an ambiguous transport failure must remain unknown until refetched.

An app-side shell implementation is an alternative if the existing merge API is
extended to atomically validate `expectedTargetCommit`, pin the source revisions,
return authoritative before/after commits, and expose a verifiable repository
binding to the shell. It could create a restoring commit parented by the exact
merge result and use an ordinary push; a concurrent advance then rejects that
push. No additional generic shell endpoint is needed. These are proposed
contracts, not callable APIs today.

The existing human-approval boundary also remains in force: supervision alone
must not silently approve the host's independent `require_approval` condition
([boundary evaluation](../../../tool/host/cp_front/front.py#L914)).

## UI hook-up

**No new Dart API is available to wire.** Keep reversible Merge/Reopen and
automatic merge unavailable until the contract above is implemented. Existing
`OrchestrationController.mergeReadiness(runId, force: true)`,
`mergeReadinessFor`, `mergeReadinessLoading`, and `mergeReadinessError` support
readiness display. `mergeRun(runId)` remains a confirmed human action; a pending
receipt is not confirmed success. `controlAgent` supports the existing overflow
actions. Refetch after reconnect.

`reopenWork` changes work-item status only. Do not present it as Git undo.
A later controller should own merge/undo confirmation, expiry, refusal and
uncertain-outcome states, not leave shell strings or commit attribution to UI
code. Its audit strings must pass through `KitRedact`, exclude raw shell output
and remote URLs, and use `oc.<what>.<profileId>` storage so profile deletion
removes them. This change persists no runtime data.

## Verification and commit

No Dart behavior was added, so there are no new behavior tests or Dart files to
format. Flutter tests/analyzer were not run, as explicitly instructed. No full
suite, live host, device or UI verification is claimed. All 17 local documentation
links and line anchors passed validation; `git diff --check` passed. Local Git
staging and commit succeeded; no push was attempted. The requested conventional
commit text remains in root `COMMIT_MSG.txt` (ignored by Git).
