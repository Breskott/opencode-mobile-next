# Separate destination copy and destination conflicts

Finish line: establish whether the captured server contracts can create a separate
conversation at the destination and report real destination change conflicts.
Non-goal: composing fork plus move into an unproven transaction, changing the
existing move workflow, or inventing a conflict from an error message.

Read set: `AGENTS.md`, standards sections 2, 3, 13 and 15, captured OpenCode 1/2
contracts, OpenCode 2 protocol notes, domain gateway and protocol operations.
Write set: this document only. Dependency: no upstream copy/move contract is
available. Acceptance: identify exact missing operation and conflict data, leave
both features unavailable. Check: document/source review; no Flutter commands.

## Feasibility: unavailable on both captured contracts

| Item | Server has it? | What you built | Capability flag | UI hook for the builder |
|---|---|---|---|---|
| Create a separate conversation copy at a destination | No combined, retry-safe operation | Contract gap documented; no adapter | Proposed `sessionCopyToDestination == false` | Do not offer this destination mode |
| Changes conflict at the destination | No typed destination-conflict result for session movement | Required error schema documented; no inferred status | Proposed `sessionMoveConflictDetails == false` | Do not display a destination-conflict state from generic failure text |

Flag names above are proposed integration names; the main README records the
actual additive API chosen by the coordinating unit.

### Existing evidence

- OpenCode 1: `contracts/opencode-openapi-f12e14cf.json`, path
  `/experimental/control-plane/move-session` (line 215), operation
  `experimental.controlPlane.moveSession`. Request is
  `{sessionID, destination:{directory}, moveChanges?}`. Success is **204**, with
  no new session identifier. `MoveSessionError` (line 15676) contains only
  `{name:"MoveSessionError", data:{message}}`; it has no conflict discriminator,
  affected paths, transaction outcome, or destination state.
- OpenCode 1: `/session/{sessionID}/fork` (line 6565) accepts `{messageID?}` and
  returns a session. It has no destination-copy operation or atomic coupling to
  movement. `lib/api/product_repository.dart:959` already maps move, and line
  975 maps workspace warp; those existing methods are outside this write set.
- OpenCode 1: `/experimental/workspace/warp` (line 9683) accepts
  `{id:workspaceID|null, sessionID, copyChanges?}` and returns **204**. It moves
  the same session's sync history. `VcsApplyError` (line 22460) has only reasons
  `non-git` and `not-clean`. Neither proves that changes conflict at a destination.
- OpenCode 2: `contracts/opencode2-openapi-beta-18600.json`, JSON path
  `paths["/api/session/{sessionID}/fork"].post`: fork accepts `{boundary}` and
  returns `data:Session.Info`; it creates a child with projected history.
- OpenCode 2: JSON path
  `paths["/api/session/{sessionID}/move"].post`: move accepts
  `{directory, workspaceID?, delivery?}`; declared responses are **204**, **400**
  `InvalidRequestError`, **401** `UnauthorizedError`, and **404**
  `SessionNotFoundError`. No conflict response or created-copy ID is present.
  The description mentions optional change transfer, but the actual request
  schema has no change-transfer field. `lib/api2/gateway_operations.dart:903`
  documents that `moveChanges` cannot be represented and sends only directory.
- `docs/opencode2-protocol-notes.md:86` documents `session.moved` as
  `{sessionID, location, projectID, subpath?}`. It has no conflict or copy result.
  The generic `ConflictErrorEncoded` schema exists elsewhere in the spec, but
  session move does not declare it; its existence is not evidence of this feature.
- `lib/domain/server_gateway.dart:1275` exposes existing `moveSession` returning
  `Future<void>` and line 1280 exposes `warpSession`. Neither returns a separate
  destination session or typed conflict. Fork followed by move can leave an
  orphaned fork after failure and has no agreed retry/rollback semantics.

These findings are from the checked-in contract snapshots and current adapters;
no live-server probe was performed and no capability is inferred from a version.

## Missing upstream contract (proposal, not a callable API)

Add an operation owned by the upstream session-copy/movement service and its
transaction boundary, exposed beside the existing HTTP session operations:

- OpenCode 1: proposed `POST /experimental/control-plane/copy-session`, beside
  `experimental.controlPlane.moveSession`.
- OpenCode 2: proposed `POST /api/session/{sessionID}/copy`, beside
  `v2.session.fork` and `v2.session.move`.

Request (OpenCode 1 additionally carries `sessionID` in the body):

```json
{
  "operationID": "client-generated-idempotency-id",
  "destination": {"directory": "/destination", "workspaceID": "wrk_example"},
  "copyChanges": true,
  "sourceRevision": "opaque-session-revision",
  "destinationRevision": "opaque-workspace-revision"
}
```

Success **201** must return
`{data:{operationID, sourceSessionID, destinationSessionID, destination,
sourcePreserved:true, changesCopied:boolean}}`. Repeating `operationID` must
return the same completed result without a second copy. Source preservation,
session-history snapshot boundaries, file-change application, concurrent-update
handling and failure cleanup must be specified and enforced by the server.

Conflict **409** must return a dedicated discriminated payload, for example:

```json
{
  "_tag": "SessionDestinationConflictError",
  "operationID": "client-generated-idempotency-id",
  "sourceSessionID": "ses_source",
  "destination": {"directory": "/destination"},
  "conflicts": [{"path": "example.txt", "kind": "content"}],
  "sourcePreserved": true,
  "destinationUnchanged": true
}
```

The server must define conflict kinds (e.g. content, destination-dirty,
source-changed), safe relative-path handling, and whether this is all-or-nothing.
An asynchronous implementation also needs an operation-status read endpoint
and a durable terminal result so the app can recover truth after disconnect.
It must never report a completed destination copy just because work was queued.

Upstream ownership is identifiable by the existing operation IDs above; the
upstream implementation source tree is not included in this app checkout, so
no unverified TypeScript filename is asserted. OpenCode 1 provenance is
`anomalyco/opencode` commit `f12e14cf1640cbf0dfb6b1ff425b2daaef459eec`
(`contracts/README.md`); the API contract belongs in that upstream repository's
`packages/sdk/openapi.json` after the service and HTTP route exist. OpenCode 2
must update its HTTP session operation plus shared schema/protocol definitions
and captured OpenAPI contract. Only then regenerate the OpenCode 1 Dart SDK via
`tool/sdk/generate.sh` and add protocol-neutral gateway/result APIs.

## UI hook-up

Keep these two actions unavailable behind false capability getters. Existing
move/fork/warp APIs keep their existing meanings; neither their presence nor a
generic error enables these features. There is no new movement controller,
storage, credential access or UI change in this slice. There are no behavioral
tests for an invented operation; the coordinating unit may test the false
capability getters it adds. Implemented: documentation only. Enabled: no.
Verified: static contract review only. Deployed/released: no.
