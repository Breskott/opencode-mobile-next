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
