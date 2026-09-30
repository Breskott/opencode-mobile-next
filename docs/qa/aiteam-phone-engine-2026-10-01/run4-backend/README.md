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

Real checker checkpoint: UI plan approval started GLM-5.3 worker session
`ses_f0b833831ffez2Xyl1DFthJdt1`, then separate checker
`ses_f0b82adf9ffeLcd2hvqg5LftdO`; both actual assistant turns finished stop
without API errors. Checker declared four criteria met but emitted successful
observations as findings with status met. Engine correctly refused merge; no
main change occurred. This exposed ambiguous prompt semantics and missing
executed-check evidence for the read-only checker. Fixed with explicit verdict
examples, unresolved-only findings, worker committed check report and open
finding publication. Legacy blocked findings now present in Review with
checkerFindings rather than addressed/Waiting. Validation and permissions were
not relaxed. A fresh project was created and spec-approved through UI; its
GLM-5.3 planner completed before emulator shutdown for the final rebuild.

Final checker source gate: Rust176 passed, zero failed/ignored, with explicit
Storage proof fixture root. One initial gate invocation omitted this required
fixture environment variable and failed before device-boundary controls; the
corrected invocation passed. Nine focused Dart files118 passed. Composed
unchanged run4 UI plus current backend analyzes clean (11.4s). Both ABIs rebuilt
from the gated source. No full repository Flutter suite is claimed.

Final UI restart observation: engine proof/protocol were Ready while the app
retained the expected SSE connection-refused error from the deliberately
stopped old server. The fresh approved task stayed queued with the honest
`chatStatusUnknown` reason. BuiltinPhoneTeamSetupPorts.startServer waits for
server health but does not reconnect the app; PhoneServerHealing's connect
path skips a retained API instance. Fixing the lifecycle attachment callback
to reconnect the same foreground managed-phone profile only after execution-
ready attach; admission remains unknown until a fresh authenticated session-
status observation. The approved queued task is preserved during the rebuild.


Final source checkpoint (supersedes counts above): serial Rust gate **178 passed,
0 failed, 0 ignored**, including normally ignored boundary controls with an
explicit Storage fixture root. Ten focused Dart files **124 passed**; the
composed app using integration `46f546c5` UI analyzes clean (14.8 s). No full
repository Flutter suite, API34, ARM64 device or physical-phone result is claimed.

The Ready-attachment repair passed on OC_API35 after force-stop/reboot: first
activation reached Ready and automatically reconnected the same managed-phone
profile without a second Start or manual Reconnect. Admission stayed UNKNOWN
until fresh authenticated status evidence arrived; the persisted queued task
then ran. A final regression also clears stale task wait reasons from the
existing authoritative job, including a read-only legacy projection that does
not rewrite status, checkpoints or command revisions.

Real-UI acceptance used the unchanged run4 UI, not the instrumentation harness.
All project creation, specification approval, role selection, plan approval,
and promotion dialog actions used Android UI taps. ADB/SQLite access below was
read-only verification of actual sessions, tool exit codes and canonical refs.
The journey survived app updates/reboots while its approved task was queued.

| Step | Result and evidence |
| --- | --- |
| Create and approve specification | PASS; project `project-f260b2df-1a7b-4b5d-ac2e-451c44a634d1`, isolated Final GLM scratch repo |
| Planner | PASS; `ses_f0b790714ffe2tLx8t4Ej9lg5N`, actual `zai-coding-plan/glm-5.3`, finish stop, no API error |
| Approve plan and admit worker | PASS; task `task-1`, worker `ses_f0b5e4a18ffeuaXkC36ePJJUle`, actual glm-5.3 |
| Worker verification | PASS; actual Python tool calls recorded exit0; output bytes exactly `Hello from UI\n`; committed `.aiteam-verification.md` |
| Separate checker | PASS; `ses_f0b5d3e48ffenMBY2blUrxoswn`, actual glm-5.3; read/glob/grep only, four criteria met, no findings |
| Merge to dev | PASS; completed task, scoped engine merge receipt, dev `5682f4228536a68b15e87e1c8621ef581b3dfe3b` |
| Cancel promotion in app | PASS; main stayed `690f0c828a6fc4b26177735ccce6ff4b334a0d4f`, no promotion receipt |

Cancel is a UI confirmation negative control: it does not send a false-confirm
API command. The Rust task-workflow regression separately sends unconfirmed
promotion and proves refusal before confirmed promotion succeeds. The worker
report is model-authored evidence tied to actual observed tool exits, not an
independent execution attestation. An earlier default-model dispatch selected
GLM-5.3-highspeed and hit provider HTTP429; it is not claimed as a completed run.
An earlier checker emitted successful observations as findings; it correctly
blocked merge. Explicit checker JSON examples and open finding projection fixed
that contract without weakening validation or granting shell permissions.


Final packaged candidate: backend bundle `e0b15162`, QA-only composition
`8a50ec09` (no changes under `lib/ui/**` against `46f546c5`). Release compile
passed in40s. Packaged source digest and all six ELF hashes passed the APK
verifier. Emulator QA signing certificate remains
`1DE5BF08146F269BCD9EB5C2FFC94469CE4617D37806285955F978A62494D60C`.
Final QA APK2083 SHA256:
`303923d520aeadae9b6f07b2ecff38770bf785708a0aa203c667a6a8120d01e9`.
Engine x86_64:
`a5ca7759462952d0e3b198af604a656c34327757b83ca2973455a9b92d17fe11`;
arm64-v8a:
`314f851d9bb291bad63707f7c30abd41970208df29d58e35d11cdb7a9d026eba`.
This is local verification, not publication, delivery or physical-phone testing.


Evidence images: [original unreachable server](original-servers.png),
[Ready with automatic reconnection](ready-auto-reconnected.png),
[GLM plan awaiting approval](checker-final-plan-review.png),
[worker](final-worker-running.png), [checker](final-checker-running.png),
[checked dev merge](final-dev-merged.png),
[promotion confirmation](final-promotion-confirm.png),
[live reachable server](final-servers-reachable.png).


Final confirmed promotion: **PASS through UI**. The confirmation showed exact
expected main/dev SHAs; tapping its Promote button produced project **Done**,
“Promoted to main”, and receipt `team-1790811821553214-0` with actor engine.
Actual canonical `refs/heads/main` and `refs/heads/dev` both equal
`5682f4228536a68b15e87e1c8621ef581b3dfe3b`. Initial read-only ref assertion used
the wrong directory nesting and failed; the corrected real canonical path
(`repos/repos/<repoId>.git`) passed. No direct ref write was performed.
The private stored legacy task reason remains unchanged by the read-only
projection, while the real Board shows Done and the task shows Work completed,
all four criteria Met, with no stale wait message.
See [Done and promotion](final-promoted-done.png),
[task verification](final-task-verified.png),
[filtered receipt evidence](final-promotion-evidence.txt) and
[cancel evidence](promotion-cancelled-evidence.txt).

Final packaged binary first-activation self-check after reboot: **PASS**;
stop52s, self-check4s, protected restart15s, no Start again/reconnect tap.
The receipt binds the exact packaged x86 engine hash above and tier **proot**.
Canonical path denial, daemon proc denial, fd hygiene, parent inspection denial,
Git compatibility and unchanged fixture positive/negative controls all pass.
`nativeAttacksDenied=false` is retained honestly: PRoot uses ptrace path
translation and is **not a kernel boundary**. It cannot be advertised as
Landlock protection. See [Ready](final-ready-reproof.png) and
[allowlisted boundary controls](final-boundary-controls.json).


Post-promotion force-stop recovery: **PASS through UI**. First activation passed
(stop21s/proof3s/protected restart8s). Projects and detail both show Done; one
promotion receipt, main=dev and revision23 persisted unchanged. See
[recovered Done](final-done-recovered.png) and
[filtered recovery evidence](recovered-promotion-evidence.txt).


Cleanup: exact supplied APK2083 restored with install-r; installed base APK
SHA256 verified `4cef9ea9d3e4a59ef0d5b2995ac0ac5ba983df944224447eff387dfcb8626e7d`.
App data and scratch acceptance records retained. Owned OC_API35 emulator was
stopped, its PID exited, adb has no devices, and nonblocking acquisition proves
the shared emulator lock is released. No push, CI, release or physical-phone
installation was performed. The final backend branch is ready for coordinator
merge; its additive contracts are in the engine design document.
