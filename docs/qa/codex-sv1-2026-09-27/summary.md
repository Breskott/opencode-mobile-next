# Summary-seeded fresh conversation feasibility

Finish line: establish whether a fresh conversation can receive a summary through the permitted domain surface, and leave a precise unavailable-state handoff when it cannot.

Non-goal: automatically run an agent, compact the source conversation, fork its full history, or present an empty newly created conversation as successfully seeded.

Read set: `AGENTS.md`; `STANDARDS.md` sections 2, 3, 13 and 15; the pinned v1 and beta-18600 contracts; v2 wire notes and clients; existing domain gateway and repository methods. Write set: this record only. Dependency: the coordinator owns the capability extension and its tests. Acceptance: distinguish a missing server primitive from a missing client integration, with no partial mutation or unsupported API enabled.

| item | server has it? | what you built | capability flag | UI hook for the builder |
|---|---|---|---|---|
| Fresh conversation seeded with a summary | v2 has generation, creation and durable synthetic-input admission as separate calls; v1 has creation and no-reply input, but its summarize operation compacts the existing session and returns a boolean. Neither exposes an atomic create-with-summary operation. | Feasibility record; no adapter or partial mutation workflow. Protected domain/repository files lack the required generic summary/context methods. | `ServerCapabilities.sessionSummarySeed` extension remains false in the coordinator's capability surface. | Hide/disable the action using that capability. There is no callable summary-seed API in this slice. |

## Current contract evidence

- [v2 wire notes](../../opencode2-protocol-notes.md) §4.2 documents `POST /api/session/{id}/generate` with `{prompt}` returning `{data:{text}}` without touching source history. `POST /api/session` accepts `{id?, title?, agent?, model?, location?, metadata?}` and returns `{data: Session.Info}`. None of its creation fields is a summary seed.
- The same notes §6.1 and §6.3 document `POST /api/session/{id}/synthetic` with `{id?, text, description?, metadata?, delivery?, resume?}` returning `{data: InboxSynthetic}`. `resume:false` admits input without scheduling execution. Admission is durable pending work, **not proof of delivery into model context**. These schemas are present in `contracts/opencode2-openapi-beta-18600.json`.
- `lib/api2/gateway_operations.dart`, `addSessionLocationReminder`, already calls `/synthetic` with `resume:false`, but hardcodes a location-specific reminder. Reusing its directory parameter to insert a summary would violate its contract.
- v1 `contracts/opencode-openapi-f12e14cf.json` exposes `POST /session` and `POST /session/{sessionID}/message` or `/prompt_async` with `noReply` and text parts. The existing v1 `addSessionLocationReminder` uses `noReply:true` plus a synthetic text part. That proves an input primitive, not a generic summary API on the domain surface.
- v1 `POST /session/{sessionID}/summarize` accepts `{providerID, modelID, auto?}` and returns a boolean. It is AI compaction of the existing session; it does not return the summary text or a fresh session.
- `SessionGateway.createSession()` takes no seed. `PromptGateway.promptAsync(...)` exposes no `noReply`/synthetic-input control. `SessionOperationsGateway.compactSession(...)` returns `void`; no domain method returns generated summary text. `Session.summary` is a file-diff aggregate, not prose.

## Why this slice stops

The v2 server primitives can support a deliberately non-atomic client workflow; there is no evidence that an upstream change is mandatory for that design. However, the current gateway cannot call generation or generic synthetic admission, and this task explicitly protects `lib/domain/server_gateway.dart` and `lib/api/product_repository.dart`. A UI-facing service assembled solely from existing gateway methods cannot meet the finish line. No workaround, type/flavour-based enablement, or live request was added.

An authorized later integration should expose protocol-neutral summary generation and context admission through the gateway (for example `generateSessionSummary(sourceID)` and `seedSessionContext(destinationID, redactedSummary)`), plus a controller that records which destination exists if the second write fails. It must distinguish pending admission from delivered context, preserve the source, recover after restart without duplicate creation, and apply `KitRedact.text` before persisting/sending seed text for persistence. The exact API is a proposal, not implemented functionality.

## Missing upstream contract, if atomic creation is required

Proposed **new**, currently absent endpoint: v1 `POST /session/{sourceSessionID}/fresh-summary`; v2 `POST /api/session/{sourceSessionID}/fresh-summary`.

Request: `{requestID: string, expectedSourceMessageID: string, title?: string, location?: {directory: string, workspaceID?: string}, model?: {id: string, providerID: string, variant?: string}}`.

Success: `{data:{session: Session.Info, sourceSessionID: string, sourceMessageID: string, seedMessageID: string, seedState: "stored", resumed: false}}`; v1 would use its own `Session` model/envelope convention. The operation generates from the expected source boundary, creates a distinct root conversation, stores the summary as model-visible synthetic context, leaves the source unchanged, and does not start a destination agent run. `requestID` must provide idempotent retry; 409 must report a changed source boundary; failure must leave no partial destination. A caller cannot claim those guarantees from the existing three-call sequence.

Upstream ownership: session HTTP route/schema module plus the session creation/storage and summary-generation implementation; v2 also the synthetic-message/inbox transaction boundary and `@opencode-ai/schema` / `@opencode-ai/protocol` definitions. Exact upstream implementation file paths are not available in this checkout and have not been asserted. Update the pinned contract and regenerate v1 SDK only after an upstream implementation exists.

## UI hook-up

Import the coordinator's session capability extension and gate on `gateway.capabilities.sessionSummarySeed`, which is false. Do not infer availability from `sessionCompact`, `sessionFork`, `ServerFlavor`, or synthetic message support. No new controller/service/stream or actionable API is exposed by this blocked sub-slice.

## Verification and state

Documentation-only sub-slice. Source/contract inspection completed; no runtime claim. Flutter tests were not run, as instructed. No Dart behavior was added here; capability behavior tests are owned by the coordinator. No UI, protected file, SDK, credentials, live session, or persistent storage was changed. No commit was made by this worker.
