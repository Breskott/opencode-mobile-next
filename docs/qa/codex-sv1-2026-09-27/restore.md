# Restore an archived conversation

Finish line: establish a supported server operation that returns an archived
conversation to ordinary session listings, or keep restoration unavailable and
document the exact missing contract.

Non-goal: clearing a staged revert, cloning a conversation, changing local
archive display state, or writing any UI/protected integration file.

Read set: the pinned OpenCode 1 and OpenCode 2 contracts; generated session
update models; `lib/api/product_repository.dart`; `lib/api/models.dart`;
`lib/api2/gateway_operations.dart`; `lib/api2/gateway_mappers.dart`;
`lib/domain/server_gateway.dart`; protocol notes and the existing unarchive
verification record. Write set: this document only. Dependencies: a supported
server contract before a client adapter, followed by the gateway owner's
integration. Acceptance: no claim that reverting or writing zero unarchives a
conversation; exact blocked request and response documented.

## Feasibility result

**Blocked by the pinned server contracts. No restoration adapter was built.**

| Item | Server has it? | What you built | Capability flag | UI hook for the builder |
|---|---|---|---|---|
| Restore an archived conversation | No supported clear operation in either pinned protocol | Contract audit and upstream request below; no speculative writes | `sessionUnarchive` must remain false; existing `sessionArchive` only means archive | Keep Restore unavailable; do not call existing `restoreSession` |

OpenCode 1 exposes `PATCH /session/{sessionID}` with optional directory/workspace
query scope and request `{"time":{"archived": number}}`. Its response is HTTP
200 containing `Session`. The schema rejects JSON null. The generated
`SessionUpdateRequestTime` has `includeIfNull: false`, so passing Dart null omits
the field rather than clearing it.

The [existing pinned-upstream investigation](../../verification/session-pins-and-unarchive.md#why-unarchive-remains-pending)
records that the handler only updates when supplied, storage preserves zero,
and ordinary listings exclude every non-null archive timestamp. That historical
implementation inspection is consistent with the current checked-in schema and
the app's `Session.archived` test (`time?.archived != null`). It was not repeated
against a live server in this task. Neither zero nor omission is an unarchive
operation.

OpenCode 2 beta-18600 has an archive timestamp on its session projection but no
archive/unarchive write endpoint. `api2ServerCapabilities.sessionArchive` is
already false. A stored field alone does not establish a callable mutation.

`SessionOperationsGateway.restoreSession` already has a different meaning:
OpenCode 1 calls `/session/{id}/unrevert`; OpenCode 2 clears staged revert.
Neither restores an archived conversation. Do not reuse this method name for
unarchive.

Evidence:

- `contracts/opencode-openapi-f12e14cf.json`, JSON pointer
  `/paths/~1session~1{sessionID}/patch/requestBody/content/application~1json/schema/properties/time/properties/archived`:
  numeric only; the same operation's 200 response references `Session`.
- `packages/opencode_sdk/lib/src/model/session_update_request_time.dart` and
  `.g.dart`: null is omitted; generated code is unchanged.
- `lib/api/product_repository.dart`: `archiveSession` writes epoch milliseconds;
  `restoreSession` calls `sessionUnrevert`.
- `lib/api/models.dart`: `Session.archived` checks non-null, including zero.
- `contracts/opencode2-openapi-beta-18600.json` and
  `docs/opencode2-protocol-notes.md` section 4.2: session route inventory.
- `lib/api2/gateway_operations.dart`: archive rejects as unavailable;
  `restoreSession` delegates to `clearSessionRevert`.
- `lib/api2/gateway_mappers.dart`: archive capability false.

## Exact missing server contract

The following is a **proposed upstream change**, not an existing endpoint:

1. OpenCode 1: extend the existing scoped `PATCH /session/{sessionID}` request
   to accept `{"time":{"archived":null}}`. Null must clear the archive database
   column, omission must remain a no-op, and numeric values must keep existing
   archive behavior. Return HTTP 200 `Session` with `time.archived` absent;
   the next ordinary session listing must include the same session ID.
   Implement the nullable input in the session HTTP API schema and clear handling
   in `packages/opencode/src/server/routes/instance/httpapi/handlers/session.ts`,
   delegating to storage's existing clear behavior in
   `packages/opencode/src/session/session.ts`. These paths are recorded by the
   pinned-upstream investigation linked above. Publish the updated OpenAPI
   snapshot and regenerate the SDK through `tool/sdk/generate.sh` only after
   the contract changes. The generated request must distinguish explicit null
   from omitted fields.
2. OpenCode 2: add an authenticated `POST /api/session/{sessionID}/unarchive`
   with empty object body `{}` and HTTP 204 response. A following
   `GET /api/session/{sessionID}` must return the same ID and `time.archived: 0`
   (or no archive timestamp), and ordinary session listings must include it.
   Put this in the upstream session HTTP command group, backed by the durable
   session archive mutation/projection; publish its typed client/schema and
   refetch/event behavior. The beta upstream implementation source is not in
   this checkout, so an exact source filename is not asserted. Preserve the
   server's existing Basic authentication and tagged 404/error conventions.

Both operations must be idempotent for an already-active conversation and retain
the original session, messages, project/location, and identity. Do not advertise
support until these semantics are verified for the connected implementation.

## UI hook-up

No callable restoration API is added for this blocked slice. Gate the future
action on a dedicated `ServerCapabilities.sessionUnarchive` flag, default false;
never infer unarchive support from `sessionArchive`, server flavor, or the
presence of the archive timestamp. The parent unit may supply this disabled
capability as a separate-file extension because `server_gateway.dart` is
explicitly outside this job's write set.

After the prerequisite lands, the proposed gateway API is
`Future<void> unarchiveSession(String sessionID)`. Wire it through the existing
authenticated transport and gateway owner, preserve captured location/profile
scope, await success, then refetch session details and the current listing.
Do not optimistically clear archive state. No credential handling, persistence,
or migration is introduced by this audit.

## Verification and state

The local contract request/response and route inventory were inspected with
bounded source reads and JSON parsing. Flutter tests and analyzer were not run,
as instructed. This slice adds documentation only, so no new executable behavior
or behavior test is claimed. No live server was contacted and no restoration
was performed. Implemented: audit only. Enabled: no. Runtime verified: no.
Committed: parent unit records the final commit. Deployed/released: no.
