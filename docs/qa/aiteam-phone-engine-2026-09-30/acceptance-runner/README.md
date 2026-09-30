# Live backend acceptance runner

Finish line: the test-only instrumentation runner starts the packaged native
engine and its real on-device boundary self-check, uses the pinned in-app OC1
server for a real one-task planner/worker/checker journey, verifies canonical
dev/main refs and durable promotion receipts, and emits six ordered PASS steps.

Non-goal: screen automation, installing or signing an APK, initializing Ubuntu,
adding provider credentials, weakening the boundary policy on emulator kernels,
or exercising OC2. This is backend acceptance; UI activation remains separately
owned and must be exercised separately.

## Preparation

Use a disposable `io.github.eslamasabry.opencode_mobile.preview` installation
with built-in Ubuntu initialized, OC1 1.18.32 installed, Git available, a stored
in-app server password, and an explicitly selected authenticated model. Both
the preview app and its release androidTest APK must already be installed from
the same candidate. The runner refuses every other target package. Android
instrumentation restarts the target process; do not use a preview installation
that contains a live conversation or work you need to retain.

Gradle uses the release variant because this Shorebird embedding has release
engine jars. `:app:compileReleaseAndroidTestKotlin -PocPreview=true` is a compile
check; assembling/signing/installing the app and test APK requires the normal
maintainer authorization. This slice does not change signing configuration.

Invoke `tool/qa/phone_engine_acceptance.sh` after those prerequisites. Its runner
component is:

```
io.github.eslamasabry.opencode_mobile.preview.test/io.github.eslamasabry.opencode_mobile.PhoneEngineAcceptance
```

Arguments are `server=http://127.0.0.1:4097`, `model=provider/model`,
`timeoutSeconds=900` (30–3600), `isolatedQa=true`, and `allowModelSpend=true`.
The runner uses an unrestricted budget only with that explicit model-spend
acknowledgment. It admits exactly one proposed task and disables fix rounds.
A real planner turn, worker turn and checker turn consume provider usage; the
timeout is an execution deadline, not a claim of a dollar spending cap.

## Actual checks

The runner launches the real app activity for foreground-service eligibility.
It refuses to stop a known busy person session, stops only the preview server
and preview terminal objects through existing native controls, and refuses any
other running service. It starts a fresh random-profile engine through
`BuiltinLinux.startPhoneEngine`; no host credential or attestation injection
is accepted. It requires signed boundary capability, then restarts OC1 through
the same command/auth contract as `BuiltinLinux.serverScript` and waits for
pinned OpenAPI execution capability.

A unique scratch repository is seeded on main inside `/root/projects` and
imported through the normal authenticated create-project command. Both private
canonical main and dev must equal its seed. A real planner session must propose
one phase and one task with the exact scratch criterion; the runner approves
that proposal without manufacturing a substitute plan. The worker must commit
the exact file on its task branch and the checker must mark its criterion met
with no findings. The runner verifies the merged canonical dev SHA, unchanged
main SHA, committed file bytes, tracked-file diff and merge receipt.

Promotion without confirmation must return `confirmationRequired` and leave
canonical main and the workspace unchanged. Confirmed promotion must update
the real private ref, persist an applied authority JSON receipt and SQLite
workspace receipt, and replay idempotently with the identical request.

While running, this test-only app process is the chat authority for its isolated
profile. Every ten seconds it authenticates pinned server health and polls
strict session-status maps for `/root`, `/root/projects`, and known project
directories, with a ten-second maximum collection age and exact pinned status
shapes. Busy non-team sessions deny admission; failed or unknown status
sends `known=false`, and missed leases expire as unknown. Team IDs are read
from the engine's real private SQLite jobs. No host-forged idle heartbeat is
used. Chats from another client in an unobserved directory remain a scoped
authority gap, as in the product contract. This runner is not a universal
cross-client scheduling proof.

## Output and retained data

Only `phoneEngineStep=PASS <step>` or `FAIL <step> <safeCode>` and a final
`phoneEngineResult=PASS|FAIL` are emitted by instrumentation. Exception text,
provider output, passwords and bearer tokens never enter instrumentation
output. Required steps, in order:

1. `engine_start_proof`
2. `scratch_repo`
3. `approved_plan`
4. `checked_dev_merge`
5. `unconfirmed_promotion_refused`
6. `confirmed_promotion_receipt`

The runner stops only its own server and engine in cleanup and closes the
foreground activity. It retains its uniquely named scratch repository,
isolated worker clones, SQLite state, attestation and receipts in disposable
preview storage for inspection. It does not clear app data or delete projects.
Use the preview app's normal storage controls after evidence review. A failing
device boundary probe is a FAIL; no host-only result enables device lanes.

## Verification

Compile checks and any live run are recorded by the integrating agent. The
runner's implementation alone is not evidence of device acceptance or model
completion. Its initial parser checks use valid AArch64/x86_64 ELF64 PIE headers
and reject truncated, malformed, unsupported-machine, ELF32, big-endian and
non-PIE fixtures. These parser fixtures never substitute for installed bundle
hash verification, signed native proof or live workflow execution.
