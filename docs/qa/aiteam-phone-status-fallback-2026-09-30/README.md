# Known-person-directory status fallback — 2026-09-30

Finish line: native protocol code can refetch complete fresh status maps for positively known person directories and consume global busy observations, while the coordinator remains the admission authority.

Non-goal: discovering every other client's directory, treating SSE silence as idle, app/background lifecycle decisions, daemon heartbeat endpoints, UI, native lifecycle edits, or a global priority guarantee.

Ownership: only engine/phone/src/opencode.rs, engine/phone/tests/status_fallback.rs and this README. Branch build/aiteam-phone-status-fallback, based on ddf3a6fe. No existing checkout or another owner's files were edited.

## Supported contract

The pinned source remains OC1 1.18.32, revision 545f51d26cc39a907d2867492d498d9607ea5fa4. Existing session driver source evidence is in ../aiteam-phone-protocol-2026-09-30/README.md. No live server, model, or provider call was made in this slice.

- [Pinned status implementation](https://github.com/anomalyco/opencode/blob/545f51d26cc39a907d2867492d498d9607ea5fa4/packages/opencode/src/session/status.ts#L25-L46) keeps a complete directory InstanceState map, deletes idle entries and defaults absent entries to idle. [The status handler](https://github.com/anomalyco/opencode/blob/545f51d26cc39a907d2867492d498d9607ea5fa4/packages/opencode/src/server/routes/instance/httpapi/handlers/session.ts#L84-L86) returns that whole map, with no pagination.
- [Global event route](https://github.com/anomalyco/opencode/blob/545f51d26cc39a907d2867492d498d9607ea5fa4/packages/opencode/src/server/routes/instance/httpapi/groups/global.ts#L88-L96) supports authenticated GET /global/event with operation ID global.event. Current /doc validation now also checks that operation.
- [Global SSE handler](https://github.com/anomalyco/opencode/blob/545f51d26cc39a907d2867492d498d9607ea5fa4/packages/opencode/src/server/routes/instance/httpapi/handlers/global.ts#L24-L55) emits server.connected, future global bus events and ten-second heartbeats. It emits no initial complete busy-state snapshot.
- [Global envelope](https://github.com/anomalyco/opencode/blob/545f51d26cc39a907d2867492d498d9607ea5fa4/packages/opencode/src/bus/global.ts#L4-L9) carries optional directory/project/workspace plus payload. [EventV2 bridge](https://github.com/anomalyco/opencode/blob/545f51d26cc39a907d2867492d498d9607ea5fa4/packages/opencode/src/event-v2-bridge.ts#L38-L43) produces directory and payload {id,type,properties}. Status parsing uses exactly directory, payload.type and payload.properties.sessionID/status; retry messages and raw payloads never leave the observer.

The original global-authority blocker remains valid. Global inventory is not active-instance enumeration; its stored creation directories and tied timestamp pagination cannot prove coverage of all executing instances. The new fallback has explicitly limited scope to supplied, positively known person directories.

## API and admission ownership

person_directory_status(directories: &[String], team_session_ids: &[String]) -> Result<bool, ProtocolError> checks exact pinned health and refetches GET /session/status?directory=... for every supplied distinct directory. It accepts at most 64 directory inputs and requires the whole multi-directory observation to finish within ten seconds. Empty/relative/NUL/oversized/unknown input, malformed status IDs/entries, unsuccessful reads, and stale aggregate observations return static safe errors. Every map is fully validated before returning; busy/retry for any non-team session returns false. Exact supplied team IDs are excluded. An empty valid complete map is idle only for that supplied known directory. No unknown directory is invented or inferred from session inventory.

The coordinator may select this positive fallback only after establishing **app-process absence**. A stale heartbeat while the app process is alive remains UNKNOWN. App UI background, screen closure, and process absence are different states. Native Android parent-death normally stops the daemon with the app process; consequently this absence fallback mainly supports non-Android or independently surviving client lifetimes. It must never imply Android background execution outlives that native boundary.

OpenCodeClient::global_status_observer() returns GlobalStatusObserver. Its API is:

- async next() -> Result<GlobalStatusObservation, ProtocolError>, where Status {directory,session_id,busy} contains metadata only and Other represents ignored non-session events.
- observed_non_team_busy(&[String]) -> Result<bool, ProtocolError> checks the volatile set. True blocks even when the busy session belongs to a previously unknown directory and the app reports idle. False means only no observed busy session; **it is never positive admission**.
- connected() -> bool describes fresh stream connectivity, never idle state.

Busy/retry events add an exact (directory,session) pair. Idle or legacy session.idle removes only that exact pair; it does not clear a different directory or establish global idle/task completion. Global disposal, malformed status frames, EOF, transport errors, timeout and observer capacity exhaustion disconnect with safe errors. Existing busy evidence stays volatile in memory, but disconnected evidence queries return UNKNOWN errors. A new connection starts incomplete history and requires independent authoritative admission/refetch. SSE disconnect or reconnect never marks a task complete.

SSE headers/read waits are bounded independently; there is no overall lifetime request timeout. A thirty-second quiet/stale connection becomes disconnected UNKNOWN, not idle. Frames and retained unparsed bytes are capped at 256 KiB and busy observations at 4096. CRLF, comments, multiline data and fragmented frames are supported; unterminated EOF frames do not dispatch. There is no auto-reconnect or replay claim.

verify() continues reporting capabilities.execution=false, chatAdmission=false and oc2=false. It additionally exposes executionDriver=true, knownPersonDirectoryStatus=true, globalStatusObserver=true and globalAdmissionAuthority=false. These flags distinguish implemented protocol mechanisms from the coordinator's app-authoritative admission, boundary proof, budgets and runtime readiness. The older chat_admission() method remains a global-authority refusal for compatibility; the coordinator replaces its usage with the app-authoritative gate and this explicitly scoped fallback.

Other clients/devices using directories that were never supplied or observed remain an explicit residual coverage limit. This slice does not claim complete cross-device priority.

## Verification state

Embedded parser/status tests and local Axum HTTP/SSE fixtures were written for root to execute under the machine lock. Cases cover all supplied directories, team exclusions, retries, malformed/missing maps, empty/unknown inputs, exact-directory busy clearing, unknown-directory busy evidence, stream EOF/reconnect, multiline/split frames and oversized frames.

rustfmt --edition 2021 engine/phone/src/opencode.rs engine/phone/tests/status_fallback.rs completed, and git diff --check was clean. No tests, Cargo checks, live servers, or test processes were run by this worker. No daemon/config/Cargo/app/native files were edited. No push, publication, signing, or release occurred.
