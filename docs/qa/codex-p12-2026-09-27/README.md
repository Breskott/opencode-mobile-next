# P1.2 — Termux as a v2 setup host

## Scope

Finish line: the same v2 setup job runs with `host=termux`, presents person
steps and component failures as resumable rows, recognises an existing healthy
installation, and reaches phone-setup-ready only after connection succeeds.

Non-goals: removing the old wizard (P1.3), rebuilding UI, changing native code,
or introducing a second job runner to substitute for the existing v2 contract.

Candidate inspected: `024e97b0d1ef270c83927b438a0843c048adc773`, branch
`codex/p12`; the worktree was clean before this record.

Read set: `AGENTS.md`; STANDARDS sections 2, 3, 13 and 15 only;
`lib/builtin/setup/`, `lib/builtin/builtin_linux.dart`, `lib/termux/bridge.dart`,
`lib/ui/kit/kit_redact.dart`, the phone setup start screen, and the native setup
and Termux dispatch implementations cited below. UI and native files were
read-only. No credentials or live device state were inspected.

Write set: this QA record and, if Git metadata is not writable, root
`COMMIT_MSG.txt`. No Dart behaviour was added after the feasibility failure.

Dependency (`after`): a callable, durable Termux host for the shared v2 job
runner. This dependency is absent in the inspected candidate.

## Feasibility — blocked

The existing v2 job cannot select Termux as its execution host. This is a
missing runner contract, not a missing permission prompt:

| Evidence | Current callable behaviour |
|---|---|
| [Dart setup transport](../../../lib/builtin/builtin_linux.dart), lines 219–251 | `startSetup`, `setupStatus`, `cancelSetup` and `completeSetupStep` target the built-in Linux channel; there is no host selector. |
| [Native dispatch](../../../android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/MainActivity.kt), lines 462–503 | All four operations dispatch to the same `SetupRunner`; passing a host in opaque job params does not change execution. |
| [Durable runner](../../../android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/SetupRunner.kt), lines 51–53, 75–84, 250–274 | Persistence is under built-in Linux, interruption recovery belongs to this runner, native install calls `linux.install`, and component scripts call `linux.start`. |
| [Termux dispatch](../../../android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/MainActivity.kt), lines 931–985; [callback registry](../../../android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/TermuxResultService.kt), lines 9–21 | `runInTermux` is a single command/result call, with a maximum callback wait of 120 seconds and callbacks held in memory. It does not provide durable v2 component-job status or cancellation. Timeout is not proof that the command stopped. |
| [Termux manager](../../../lib/termux/bridge.dart), lines 1628–1680 and 2140–2152 | The existing detached manager has its own setup phases and verbs; it does not accept the v2 component manifest or expose its job record. Wrapping this legacy setup as one row would not satisfy the requested per-component job. |
| [Component checks](../../../lib/builtin/setup/setup_engine.dart), lines 323–350 | Checks first ask whether built-in Linux is installed, then run inside it. A healthy Termux container cannot satisfy this check path. |
| [Finish step](../../../lib/builtin/setup/setup_finish.dart), lines 36–75 | Completion ensures a built-in profile and starts its server. Termux needs host-specific completion before success can mean connected. |

Termux's current permission contract is available: `capabilities()`,
`requestPermission()`, `openTermux()`, `openAppSettings()` and `verifyBridge()`
in `lib/termux/bridge.dart`. Android checks RUN_COMMAND permission and service
availability before dispatch. These primitives do not supply the missing
durable job contract. No provider credentials are needed for component checks;
managed-server authentication must stay in the existing secure profile flow.

Per the task's explicit stop-on-failed-feasibility instruction and PROC-17,
implementation stops here. A separately designed durable shell runner could
be explored in another scoped task; this record does not claim that Termux
execution is fundamentally impossible from Dart.

## UI hook-up

**No new callable Dart API is delivered. Do not wire `host=termux` to the
current engine:** it would still execute against built-in Linux. The public
API today is `SetupEngine.run/progress/restore/cancel/installedOptional` in
`lib/builtin/setup/setup_contract.dart`; it has no supported Termux host.

The coordinator/native owner needs to supply host-aware start/status/cancel/
complete-step operations and durable host identity. Then the backend unit can
expose host selection through the shared engine, person-step state/actions,
and host-specific checks and completion. Reuse `SetupProgress` for component
rows, `canContinue` for retry, and require a successful connection before
publishing `SetupState.done`. Preserve host and selection across restart.
Redact persisted/displayed diagnostic strings with `KitRedact` before writing;
do not persist credentials in job params or logs.

Once that API is implemented and verified, the UI owner replaces `_useTermux`
at `lib/ui/screens/phone_setup/phone_setup_start_screen.dart:347–350` (the
referenced route has moved from line 314) with shared job startup and progress
navigation, followed by phone-setup-ready on success. This task leaves that
file untouched as explicitly requested.

## Acceptance and follow-up checks

All product acceptance remains unverified and unimplemented in this unit:

- Route selection uses the shared job with Termux host: UI-owner dependency.
- Existing healthy Termux components pass checks without reinstalling:
  host-aware check dependency. Preserve pinned-version checks; merely finding
  the Termux app is insufficient.
- Fresh installation, a failed component and retry, and a kill mid-install
  followed by restore/resume: durable host-runner dependency.
- Ready is emitted only after the Termux server is authenticated and connected:
  host-specific finish dependency.

After that dependency lands, focused `flutter_test` cases should cover an
existing installation, failure/resume and restored host/selection, plus
redaction and permission/person-step transitions. Native kill/resume behaviour
also requires coordinator-run device evidence; a fake bridge cannot prove it.

## Verification and state

Docs-only change: no behaviour tests, Dart formatting, Flutter analyzer, full
suite, APK build, emulator or device run was warranted or performed. This is
not a claim that the Flutter toolchain is blocked. Source references and local
Markdown links were checked; `git diff --check` passed.

Implemented: partial (feasibility record only). Enabled: no. Verified: source
contract inspection and documentation checks only. Deployed/released: no.
Commit: sandbox denied the Git index lock outside this worktree; the requested
message is saved in root `COMMIT_MSG.txt` for the coordinator.

Blocker: `outside-write-set` / `single-owner`, native `SetupRunner.kt` and
`MainActivity.kt`: add durable Termux host dispatch for the existing component
job, with host-scoped status, cancellation and interruption recovery. Shell
and Dart host adapters can follow that contract. App-shell finish wiring in
`lib/main.dart` is a separate coordinator-owned integration change.

Contract problems: the requested `host=termux` capability is not present in the
current callable v2 job contract (evidence above); blocks: true. Proposed
replacement prerequisite: integrate durable host-aware runner operations
before enabling or wiring the Termux v2 path.
