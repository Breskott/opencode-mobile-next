# Run 4 backend repair and real UI acceptance

Finish line: default app roles plan with the phone server's authorized model, planner progress/waiting reasons and live server reachability are visible, first protected restart reaches Ready, and create → plan → approve → worker → checker → dev merge → confirmed promotion passes through app UI. Non-goal: editing Claude-owned UI, publishing, or physical-device claims.

Exact APK 2083 / integration 46f546c5 was installed preserving data on OC_API35 under the shared emulator lock, port5554, memory3072. Certificate matches the known local release signer. The real UI reproduced the existing planning project's “Waiting for dependencies” and empty timeline. Private metadata confirms planner stage `interrupted`, reason `promptUncertain`, empty model; all default role models are empty. No provider key or bearer token was exported. The acceptance harness's explicit model setup hid this path.

The pinned OC1 prompt schema requires `parts` only; model is optional. Empty role selection will omit that wire field, leaving model choice with the phone's OpenCode server. Explicit model identities remain validated. Local validation errors must occur before dispatch checkpoints or clone/session creation and retain a static typed reason.

Additional defects: server.online was a persisted false default, planner reasons stayed in private job data, idle chat UNKNOWN could stay sticky, and initial failed protocol verification retried after30s while setup waited28s. The positive attestation string was incorrectly used as a readiness failure. Verification and final UI results are recorded below at the slice boundary.

Host checkpoint: Rust crate serial tests including normally ignored boundary
controls: 166 passed, 0 failed/ignored. Six affected Dart files: 96 passed.
Pinned Flutter analysis clean; Dart formatting, Rust formatting and diff check
clean. The new timer regression file is still being checked separately, so
this is focused evidence, not a full Flutter suite result. Both Android ABIs
rebuilt/staged from the changed Rust source; package checks follow the real-UI
QA build.

Root causes and fixes:

- Empty default role model was locally rejected after dispatch checkpoint;
  omit optional wire model and validate explicit choices before side effects.
- `server.online=false` was an untouched seed, not a live authentication result;
  workspace reads now derive protocol reachability and typed admission reasons.
- Planner stage/reason stayed in private job records and timeline was empty;
  additive planningState and bounded durable timeline expose the wait. Legacy
  ambiguous dispatch gets a read-only checkpoint, never automatic resend.
- A failed startup protocol check waited 30 seconds to retry, exceeding setup's
  28-second wait; unavailable protocol now retries after 2 seconds. A healthy
  boundary no longer supplies `boundary_attested` as a readiness error.
- Idle/unknown app chat observations lacked a refresh path; managed-phone polls
  now run with scope/freshness fences even without existing busy IDs.
- Native snapshots credentials before protected restart. Production preparation
  atomically matches the app-owned password first, eliminating stale rootfs
  credentials without logging or persisting credentials in diagnostics.

Final host checkpoint: new chat-admission timer regressions 9 passed, bringing
focused Dart total to 105 (six earlier files 96 plus new file 9). Initial
attempts exposed harness fake-clock/Dio and pre-invariant timer disposal issues;
those were corrected without weakening assertions. Final pinned analysis clean.
The QA-only composition of integration 46f546c5 plus the backend (UI unchanged)
also analyzes clean. Release compile completed in 3m43s. All six packaged native
hashes and Rust source digest pass `verify_phone_engine_apk.py`; certificate is
`1DE5BF08146F269BCD9EB5C2FFC94469CE4617D37806285955F978A62494D60C`.
QA APK version2083 SHA256
`9df5dccf899879ea6c360e0e43afaa726d11f4ae0c269c5421c042f17e8de6ec`.
This is an emulator QA build using the existing debug signing configuration,
not a published or delivered release. The exact original2083 remains available
for restoration after the run.

Real-UI device checkpoint (patched2083): after force-stop, first activation
passed without Start again: stop42s, boundary3s, protected restart15s. Servers
now says Reachable. A default-role project dispatched its planner to the
server-selected `zai-coding-plan/glm-5.3-highspeed`; the provider returned APIError
HTTP429. This is not a default-model dispatch pass-to-completion claim. The
engine recorded `sessionFailed`; raw provider error text/credentials were not
exported. Via Roles and agents UI, all three roles were then explicitly set to
`zai-coding-plan/glm-5.3`. A fresh GLM project was created/spec-approved through
UI. Its actual assistant record reports glm-5.3, finish=stop, no error; the
engine published one task and `needsPlanApproval`. This revealed the next real
UI contract mismatch: UI expects domain `plan` to offer approval. The adapter
now translates the presentation while preserving native checks/revisions.
Also found: UI requires authoritative merged queue items to offer Promote,
while native durable merge receipts existed without queue projection. That
projection is being completed before the final device run. Emulator stopped
while rebuilding; lock remains owned until final cleanup.

Second host checkpoint: Rust170 passed including normally ignored device-
boundary host controls, new merge projection regressions and 14 negative
mutations. Domain status/approval and completion projection tests pass (39
focused gateway tests, including 6 new completion tests with more than25
negative cases). Analysis clean. The queue proof derives from exact scoped
receipts and matching checker criteria; no stage alone grants passed checks.
