# Run 4 phone chat admission recovery

Finish line: after a transient unavailable or malformed person-session status read, a managed phone connection recovers admission through a bounded fresh scoped status poll, while every observed busy/retry person session and every pending chat dispatch keeps the engine paused.

Non-goal: changing UI, native engine startup, planner model defaults, daemon admission policy, or background lifetime guarantees. Those remain coordinator-owned slices.

## Contract

No public method was renamed. `ConnectionController` uses its existing five-second fallback timer to read only the connected phone directory/workspace status, including when there are no previously tracked busy sessions or a full session page is pending. Each managed-phone status read has a four-second timeout. A successful status snapshot expires after fifteen seconds of monotonic elapsed time; the heartbeat becomes UNKNOWN after expiration.

Busy/retry IDs from the fresh map enter `busySessions` before a known heartbeat can be published, even when session metadata has not arrived. Newer SSE status evidence wins over an older poll. Unknown SSE values, malformed IDs/statuses, status errors and timeouts fail closed. A late response from a retired connection or changed directory/workspace/location revision cannot publish admission truth. A delayed full session page also cannot replace a newer status-only poll with an older idle map.

The dispatch tracker retains pending chat turns independently of an empty server status map. The existing heartbeat publisher continues its periodic renewal while a prompt request is waiting on the wire. Integration must retain Claude's additive `replyInFlight`/open-turn tracking when merging this connection change.

This scoped phone observation does not prove that another client on another device is idle. A missing directory or disconnected/suspended app remains UNKNOWN; this patch does not override that boundary.

## Focused regressions

`test/phone_chat_admission_recovery_test.dart` covers:

- Idle UNKNOWN recovery on the existing periodic lane, including recovery after a failed read.
- Fresh busy/retry IDs whose metadata has not arrived.
- Recovery while a full session page is still loading.
- Rejection of late directory and connection-generation responses.
- A newer unknown or busy SSE event while a poll is pending.
- A delayed full page following a newer busy poll.
- Four-second timeout and malformed status fail-closed behavior.
- Real `OpenCodeApi.promptAsync` dispatch fencing and renewed busy heartbeat while its request is pending.

Without the idle-poll change, the first three regressions stop at the old empty-tracked/loading guards. Without inclusion of all busy/retry IDs, the second regression advertises idle. Without the read revision fence, the delayed-page regression clears newer busy evidence. These are intended regression assertions; a mutation run has not been performed by this worker.

## Verification handoff

Changed Dart files formatted with the pinned SDK; `git diff --check` passed. No Flutter test, analyzer, native build or device process was launched by this worker. The coordinator owns the serialized machine gate and must record its results on the integration candidate.

Suggested focused serial set: `test/phone_chat_admission_recovery_test.dart`, `test/phone_engine_connection_review_test.dart`, `test/phone_project_engine_controller_test.dart`, `test/phone_project_engine_gateway_test.dart`, and `test/connection_v2_test.dart` (existing missed-idle reconciliation regressions).

Implemented and locally committed; execution verification, integration and phone deployment are separate pending gates. No push.
