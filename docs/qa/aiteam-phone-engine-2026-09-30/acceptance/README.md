# Live phone-engine acceptance

Finish line: one host command invokes an installed, isolated preview test runner
which starts the real native engine/proof and exercises an approved scratch task,
checked dev merge, unconfirmed promotion refusal and confirmed promotion receipt,
with one safe PASS/FAIL line per step.

Non-goal: signing or installing APKs, starting an emulator, modifying the stable
app's existing profiles/projects/provider settings, exposing engine credentials
to adb, simulating the proof or model responses,
or verifying the separate UI journey. The host command is a test driver; the
engine, canonical repositories, authentication and proof remain inside the app.

## Prepare the isolated preview once

Use the coordinator's matching **release preview app** and **release androidTest
APK**, built from the same integrated source. The target package is
`io.github.eslamasabry.opencode_mobile.preview`; its test package is the target
plus `.test`. The test runner is
`io.github.eslamasabry.opencode_mobile.PhoneEngineAcceptance`. APK signing and
installation remain separate maintainer-authorized steps. Debug Flutter APKs do
not work with this project's pinned Shorebird engine.

The preview must already have its own installed Ubuntu, git and authenticated
OC1 **1.18.32** runtime, with the selected provider/model available. Finish the
preview's reply and stop its server/terminals before running: the runtime proof
must not start alongside an existing unconfined preview process. The runner uses
the existing native controls and private credentials; no password, bearer token
or provider configuration needs to be copied to the host. Use disposable preview
data because Android instrumentation restarts its target process. The stable
app's server and data are outside this test's ownership.

The bundle must contain the device's ABI (`x86_64` for emulator-5554 or
`arm64-v8a` for a phone). An emulator without the required kernel confinement
features reports a proof failure; the harness cannot weaken the boundary.

## Run

From the integrated checkout, with Python 3 and adb available:

```bash
tool/qa/phone_engine_acceptance.sh \
  --serial emulator-5554 \
  --server http://127.0.0.1:4097 \
  --model '<provider>/<model>' \
  --isolated-qa --allow-model-spend
```

Replace `<provider>/<model>` with the already-authenticated model's literal ID.
`--server` is the **phone's** loopback OC1 URL, not a host forwarded port. The
explicit flags acknowledge use of isolated preview data and real provider-backed
planner/worker/checker calls. They do not approve any APK signing/install step.
This is a real model test: unknown usage is not reported as zero and the harness
does not promise a dollar ceiling. `--timeout-seconds` defaults to 900 and accepts
30–3600; `--adb /absolute/path/to/adb` overrides PATH/SDK discovery. `--package`
may select another matching test build but must end in `.preview`.

## Explicit stable-app QA

The owner subsequently authorized one live task with the stable app's existing
authenticated `zai-coding-plan/glm-5.3` setup. The default remains the preview.
The exact stable target requires **both** `--stable-app-qa` and
`--package io.github.eslamasabry.opencode_mobile`; it cannot be combined with
`--isolated-qa`. Prepare matching stable/test APKs separately under the owner's
installation authorization, preserving app data and comparing the installed
certificate before delivery. Never uninstall, clear data, reset provider auth or
replace the certificate to make the test work.

The stable QA target must be built with `-PocStableEngineQa=true` (or Flutter's
`--android-project-arg=ocStableEngineQa=true`) to retain its Kotlin/native
instrumentation ABI through R8. Normal stable builds retain their usual rules.
For a compile-only check, the coordinator uses JDK 17 and the machine lock with
Gradle `:app:compileReleaseAndroidTestKotlin -PocStableEngineQa=true`.

```bash
tool/qa/phone_engine_acceptance.sh \
  --serial '<authorized-adb-serial>' \
  --server http://127.0.0.1:4097 \
  --model zai-coding-plan/glm-5.3 \
  --package io.github.eslamasabry.opencode_mobile \
  --stable-app-qa --allow-model-spend
```

Instrumentation restarts the stable app process. Start its existing authenticated
in-app OC1 server, finish the person's chat reply, and close terminals first. The
runner refuses a missing/untracked server, known busy chat, unknown scoped status,
live terminal or another service. It uses existing native stop/start controls
only after that check, creates a new random `qa_*` engine profile and one scratch
repository, and drives the actual approved planner/worker/checker sessions. It
never edits the person's projects, existing engine profiles or provider settings.
Native first activation still performs its normal durable confinement setup;
the runner never bypasses proof or deletes protection state.

Ordered durable job events prove planner completion and the task's
`running → checking → mergeReady → merging → completed` transitions. The task
must also have distinct worker/checker sessions and durable dispatched prompts.
Additional fixed PASS lines report `planner_completed`, `worker_completed`,
`checker_completed` and `dev_merged`; they reflect persisted evidence, so a fast
stage cannot be missed by polling. Stable success additionally requires
`PASS stable_server_restored` from cleanup. The QA engine stops; the person's OC1
server availability is restored using the same installed OC1/authentication
contract. Restore failure makes the final result fail even if task steps passed.
The new scratch/profile and receipts remain available for inspection. This
procedure does not restore an interrupted live reply: busy or unknown chat is a
refusal, not permission to interrupt it.

Expected success:

```text
PASS preflight x86_64
PASS engine_start_proof
PASS scratch_repo
PASS approved_plan
PASS checked_dev_merge
PASS unconfirmed_promotion_refused
PASS confirmed_promotion_receipt
PASS acceptance
```

The shell wrapper checks the selected device, supported ABI, installed target/test
packages and exact instrumentation target before invocation. It passes the native
runner `server`, `model`, `timeoutSeconds`, `isolatedQa=true` and
`allowModelSpend=true`. The runner's app-private API calls and repository checks
are described in its source; this command does not perform host HTTP requests to
the engine or export its credentials.

The wrapper accepts each fixed step exactly once, in order, followed by
`phoneEngineResult=PASS` and `INSTRUMENTATION_CODE: -1`, and also requires adb to
exit successfully. Failure status, missing/duplicate/conflicting/out-of-order
steps, instrumentation errors, unsupported ABI, malformed output and timeout all
exit nonzero. Raw adb output, exceptions, private paths, model text and optional
runner codes are discarded. On interruption it terminates only its own host adb
client; the native runner owns cleanup under its bounded deadline. Interrupted
commands are not a pass, and native cleanup may finish after the client exits.

## Focused host verification

```bash
python3 -m unittest discover -s tool/qa/tests \
  -p 'test_phone_engine_acceptance.py' -v
bash -n tool/qa/phone_engine_acceptance.sh
git diff --check
```

Executed for the stable extension: **14 host tests passed**, shell syntax passed,
and whitespace check passed. Tests use a local fake adb transcript and cover the
six-step success protocol, ARM64/x86_64 preflight, failure/result conflicts,
duplicate/order/missing/malformed steps, error redaction, absent app/runner,
device/ABI failure, consent, shell-injection rejection, exact stable target,
mutually exclusive opt-in, required stage/cleanup evidence and cleanup failure.
They do not establish
Android proof, a live provider task, a UI pass or a full-suite result. At slice
creation no adb device was attached; live acceptance is pending on an authorized
prepared preview installation. No APK was signed/installed and nothing was pushed.
