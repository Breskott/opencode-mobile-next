# SV1: sessions and messages backend handoff (2026-09-27)

Finish line: provide a gateway-level count for the staged hidden prompt's
following messages, and keep the remaining session actions unavailable wherever
the server contract or permitted integration surface cannot support them.

Non-goals: UI changes, modifying commit/delete behavior, protected-file edits,
new authentication, live-server changes, signing, release or push.

## Scope and ownership

Branch: `codex/sv1`; starting revision: `643a5104`. The supplied worktree was
clean. Read: `AGENTS.md`, standards sections **2, 3, 13, 15 only**, pinned
contracts, relevant generated models (read-only), protocol clients, domain
gateway, existing staged-revert controller and tests. `HANDOFF.md` is absent.
Write: the two new domain libraries, one focused test file, this QA directory,
and root `COMMIT_MSG.txt`. All prohibited single-owner files and `lib/ui/`
remain untouched. No generated code changes.

Execution ownership: the coordinator owns the count, disabled flags, tests and
this README; independent workers own `restore.md`, `summary.md`, and `move.md`.
Their dependency was contract feasibility, their acceptance was a supported
call or an exact blocker, and their focused check was source/document review.
They ran no test processes. The coordinator reviewed all three outcomes and a
worker separately reviewed the new count implementation read-only.

The explicit prohibition on editing `server_gateway.dart` and
`product_repository.dart` takes precedence over the later generic instruction
to add methods there. New APIs use separate-file Dart extensions. This is a
partial backend delivery, not a finished or enabled product journey.

## Feature and server matrix

| item | server has it? | what you built | capability flag | UI hook for the builder |
|---|---|---|---|---|
| Staged revert: hidden prompt plus N subsequent messages | V2 has stage/clear/commit, a staged boundary, and paged raw messages; no numeric count field. V1 has revert/unrevert, not this staged lifecycle. | Read-only `ServerGateway.countStagedRevertMessages`, including bounded paging, overlap deduplication and stale/incomplete rejection | Existing `ServerCapabilities.sessionRevert` plus `canCountStagedRevertMessages(operations)`, which requires `StagedRevertGateway`; no flavor checks | Import count extension, capture existing review, await count, use `messagesAfterPrompt`; invalidate on history/connection changes |
| Restore an archived conversation | No contract-proven clear in either pinned server; numeric zero is not a V1 clear | False capability and [exact upstream request](restore.md); no mutation adapter | `sessionUnarchive == false` | Keep unavailable; existing `restoreSession` means undo revert |
| Fresh conversation seeded with summary | V2 has generation + create + synthetic admission with `resume:false`; V1 has create/noReply input. No atomic fresh-summary operation. Needed generic gateway calls are absent and protected. | False capability and [integration handoff](summary.md); no partial creation workflow | `sessionSummarySeed == false` | Keep unavailable pending authorized gateway integration; do not claim synthetic admission is delivered context |
| Separate conversation copy at destination | Fork and move exist separately, without combined retry/rollback guarantees | False capability and [missing operation contract](move.md) | `sessionCopyToDestination == false` | Do not offer this destination mode |
| Changes conflict at destination | No typed destination-conflict result on either move operation | False capability and [missing conflict schema](move.md) | `sessionMoveConflictDetails == false` | Do not infer conflicts from generic error text |

## UI hook-up

Import `package:opencode_mobile/domain/staged_revert_message_count.dart` for
the count and `package:opencode_mobile/domain/session_slice_capabilities.dart`
for the disabled flags. No UI import of a protocol client is needed.

Every added public API:

| API | Contract |
|---|---|
| `StagedRevertMessageCountGateway` | Extension on the existing `ServerGateway`; no transport construction/auth changes |
| `canCountStagedRevertMessages(Object? operations)` | True only with `capabilities.sessionRevert` and an operations object implementing `StagedRevertGateway`; pass the controller's actual prepared repository |
| `countStagedRevertMessages(String sessionID, {required SessionRevert expected, required Object? operations, required bool Function() isCurrent, int maxPages = 100})` | Returns `Future<StagedRevertMessageCount>`; reads session before/after and newest-to-oldest chronological message pages; stops at the user boundary; never mutates a session |
| `StagedRevertMessageCount.messagesAfterPrompt` | N excludes the prompt and includes all subsequent projected message kinds; zero is returned only for a verified boundary with no later messages |
| `StagedRevertMessageCount.totalMessages` | N + 1, including the hidden prompt |
| `StagedRevertCountException.kind` / `StagedRevertCountFailure` | `unavailable`: missing capability/interface; `stale`: scope or boundary changed; `incomplete`: missing/non-user/partial-message boundary, malformed rows, cursor loop or page budget exhausted; `failed`: transport/read failure. No raw server body retained |
| `SessionSliceCapabilities` | Extension on `ServerCapabilities`, supplying `sessionUnarchive`, `sessionSummarySeed`, `sessionCopyToDestination`, `sessionMoveConflictDetails`; all always false until their owning integrations implement the contract |

Builder sequence (using the existing controller, without editing it here):

1. Prepare the normal action transport/repository. Capture `api`,
   `review = controller.reviewSessionRevert(sessionID)`, and `review.revert`.
   Require a non-null boundary and `api.canCountStagedRevertMessages(repository)`.
2. Capture a UI-owned load/history generation and call
   `api.countStagedRevertMessages(sessionID, expected: review.revert!,
   operations: repository, isCurrent: () => mounted && generationIsCurrent &&
   controller.isRevertReviewCurrent(review))`. `generationIsCurrent` is the
   builder's own comparison, not a new controller property.
3. Increment that generation and discard the displayed count on any transcript
   mutation, staged-history reset, profile/location change, reconnect or widget
   disposal. Refetch after reconnect. Recheck currentness before displaying a
   completed future; overlapping requests must not overwrite a newer review.
4. On success, N is `result.messagesAfterPrompt`. Localize plural/zero handling.
   Loading/failure/stale means **count unknown**, never zero. Offer reload when
   incomplete. `maxPages` bounds requests (100 pages at the gateway's default
   100 rows); it must be positive or the API throws `ArgumentError`.
5. Continue to use `controller.commitSessionRevert(review)` and its existing
   confirmation, busy guard and preflight. This read helper never commits.

The count is a reviewed point-in-time observation, not an atomic server promise
of a deletion count. The current server has no transcript revision/count bound
to commit. A change racing reads or commit cannot be transactionally prevented
here; the builder must invalidate observed history changes and must not label
the count as server-guaranteed. A future atomic guarantee needs the upstream
`Session.Revert` schema to include `messagesAfterPrompt` and a history revision,
with commit accepting that expected revision and rejecting changes with 409.
That is a proposed server enhancement, not a callable endpoint added here.

## Count feasibility evidence

- `contracts/opencode2-openapi-beta-18600.json`: `Session.Revert` contains
  `messageID`, snapshot/files, but no count; paths
  `/api/session/{sessionID}/revert/{stage,clear,commit}` and
  `/api/session/{sessionID}/message` provide the required existing primitives.
- `docs/opencode2-protocol-notes.md` sections 4.2, 5, 6.3: paginated messages,
  message variants and explicit stage lifecycle.
- `lib/api2/gateway.dart`, `messagePage` / `_messagePage`: newest raw page is
  mapped to chronological order; the opaque continuation requests older rows.
- `lib/api2/gateway_mappers.dart`, `mapApi2Messages`: maps every raw message
  one-to-one, including synthetic/system rows, so the count does not omit them.
  Some non-user kinds project as role `user`; the helper additionally calls
  `StagedRevertGateway.sessionRevertPrompt` to verify the raw user kind (null
  rejects, empty text is a valid attachment-only prompt). Review caught this
  distinction and a focused regression case covers it.
- `lib/domain/session_history.dart`: existing reader explicitly retains
  staged-away raw pages; hiding occurs in the consumer, not in gateway reads.
- `lib/api/models.dart`, `SessionRevert.fingerprint`: identifies message,
  part, snapshot and reviewed file content; count checks it before and after.
- `lib/state/connection.dart`, `isRevertReviewCurrent` and
  `commitSessionRevert`: existing profile/location/revision and mutation guards
  stay in place. `SessionRevertReview` is unchanged.

## Security and persistence

No local or remote persistence, credential reads, logging, transcript storage,
or migration was added. Only numeric counts escape the read helper; transient
IDs are discarded when it completes. Read failures become a typed safe error.
Therefore no persistence call needs `KitRedact` in the implemented slice.
The blocked summary workflow must apply `KitRedact.text` before seed text is
persisted, including server persistence, when it is later implemented.

## Verification

- Added `test/staged_revert_message_count_test.dart`: paged/all-kind counts,
  overlap deduplication, zero, unknown coverage, non-user/foreign boundaries,
  cursor loops, page budget, part boundaries, scope changes, remote boundary
  changes, unsupported/closed transports, safe failures and disabled flags.
- Pinned `dart format --language-version=3.10` completed for all three Dart
  files. It warned that the worktree cannot resolve
  `package:flutter_lints/flutter.yaml`; formatting itself exited 0.
- Flutter tests, analyzer and full suite **not run**, per the explicit task
  instruction. No compilation or test-pass claim is made. No runtime, emulator,
  screenshots or live-server verification was attempted.
- Static review, QA relative-link existence and staged `git diff --check` are
  the available checks. Protected-file and generated-file diffs must be empty.

Verifier command (not executed here):

```bash
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter test --concurrency=1 test/staged_revert_message_count_test.dart
```

## State and blockers

Implemented: count backend and explicit unavailable flags; remaining slices
have feasibility records. Enabled: no UI integration. Verified: source review
and formatting only; runtime tests pending. Committed: see this branch's SV1
commit and root `COMMIT_MSG.txt`. Deployed/released/pushed: no.

Contract problems: the task requests protected gateway edits and also forbids
them; the explicit write prohibition is honored. Summary seeding requires the
gateway owner to expose generation and generic synthetic admission with scope,
retry and partial-failure handling. Restore and combined copy/conflict require
the upstream changes described in their records. These are blockers to the
corresponding full product journeys, not successful implementation claims.
