# Phone chat admission heartbeat

Finish line: the current phone connection renews authenticated, sequenced idle/busy/unknown observations every ten seconds; actual person prompt dispatch latches the exact session before the engine can admit another team lane, and stale connection/deletion/lifecycle state cannot revive idle admission.

Non-goal: UI changes, native bridges, unverified global status claims, execution boundary proof, provider credentials or test execution.

Read set: pinned engine/API contracts, ConnectionController reconciliation/lifecycle, OpenCodeApi direct dispatch and existing phone gateway tests.
Write set: lib/state/connection.dart, lib/state/phone_project_engine.dart, lib/orchestration/adapters/inapp/phone_engine_gateway.dart, their two tests, this README; actual handwritten OC1 dispatch seam subject to coordinator ownership extension.
Dependency: coordinator implements authenticated POST /v1/chatBusy and ledger admission. Tests/analyzer belong to coordinator; this slice performs formatting/diff checks only.
Frozen body: {until: unixMs <= now+30000, sessionIds: [string], directories: [string], known: bool, appInstance: string, sequence: int}. Expiry is UNKNOWN. Renewal occurs while idle and busy. Daemon owns filtering its team sessions.

## Implemented integration

- `ConnectionController` owns the source for the configured builtin OC1 phone profile. A real successful current-directory status reconciliation plus connected stream establishes `known`; disconnect/reconnect, transport retirement, rescope, read failure or malformed status invalidates it. Empty retained caches never establish idle. Busy sessions and exact dispatch latches contribute IDs/directories; daemon owns excluding team sessions.
- The coordinator approved ownership of handwritten `lib/api/opencode_api.dart` because `lib/domain/oc1_gateway.dart` does not exist. Optional dispatch callbacks run inside actual prompt_async, correlated prompt, shell and slash-command methods, preserving normal injected API factories and the existing UI. Every person dispatch latches its session before required heartbeat ACK.
- ACK requires HTTP success and `{accepted:true}`. Monotonic wire sequence and one app-instance UUID span producer replacements; older unsent observations coalesce, required pre-dispatch observations do not. Idle and busy leases both renew every ten seconds and expire within thirty seconds. Shutdown sends unknown then drains/closes app resources; it does not stop the daemon.
- A failed pre-dispatch heartbeat stops only the exact native engine before the person request can enter OpenCode. Stop must report `running=false`; failure stays retryable and never fabricates suspension. Restart remains explicit. Profile switching and every builtin alias dispatch fence settle previous profile engine stops, including a restarted app with an older saved engine alias. Foreground preparation covers OC2 aliases while OC2 execution stays unavailable.
- A post-ACK idle poll alone never clears a dispatch latch. The app must observe busy/retry for that turn, then a fresh same-directory idle read begun after transport settlement. Pending requests, stale reads, directory changes and later unsent failures retain earlier uncertain latches. No claim that OC1 busy precedes the async HTTP acknowledgment is made.
- Deletion latches gateway admission synchronously, cancels heartbeat renewal, drains in-flight observation writes, then performs durable engine deletion. Deleted profiles cannot create another producer.

## Limits and verification

The source proves this app's observed directory/turn activity, not a complete global OC1 idle inventory. The daemon must respect the advertised directory scope and its independent busy SSE veto; this heartbeat does not turn a missing global endpoint into proof. A fast turn for which no busy/retry was observed stays latched rather than releasing on an uncorrelated completion or empty poll. Recovery needs subsequent affirmative turn observation; no invented completion evidence is used.

Focused tests added for idle/busy/unknown change and timer renewal, lease expiry under queued sends, required-delivery ordering, current-turn latch epochs/start proof, unsent overlap, native-stop failure/retry, alias fences, actual OC1 dispatch callbacks, strict ACK, malformed status, and heartbeat/deletion drain. Tests and analyzer were not run, as instructed. Pinned Dart formatting and `git diff --check` passed; formatter package-resolution warnings reflect this fresh worktree without package resolution. Native/device/global admission proof remains separate. No UI/main/generated SDK/native bridge edits, publication, signing or push.
