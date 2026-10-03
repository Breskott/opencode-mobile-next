# Device boundary regressions

Finish line: a no-model preview instrumentation run verifies bounded, SIGSYS-safe packaged-kernel detection, records real proot-view controls, and proves that unsupported activation restores the stopped service without rotating it on an identical restart.

Non-goal: a successful diagnostic does not issue an attestation, enable execution, or substitute for the production boundary proof. This slice does not provision models, read provider credentials, or test UI.

Ownership: `PhoneEngineDeviceBoundaryRegressions.kt` and this README. Production native changes and instrumentation runner dispatch belong to the coordinator.

## Callable contract

`PhoneEngineDeviceBoundaryRegressions.run(context, bootstrap = true): Map<String, Any?>` requires the disposable `.preview` app in the foreground, no services or terminal sessions, and no active engine. It installs the pinned Ubuntu image if necessary and quietly ensures `git` is installed when `bootstrap` is true. With `bootstrap = false`, the runtime and git must already exist.

The helper validates the packaged sandbox before launching `--check-kernel` with an empty environment and closed stdin. Exit 0 means the production boundary may be supported; exit 78 means unsupported. A signal exit, timeout, or other code fails the regression. A kernel-unsupported activation must throw exactly `boundary_unsupported`, leave all engine authority unavailable, and restore the synthetic service that the test deliberately stopped. The subsequent identical start must preserve the tracked service uptime. A supported kernel instead requires a genuine successful production proof; pure proot diagnostic failures cannot invalidate a valid Landlock proof.

The returned map contains only fixed labels, Boolean controls, and the numeric kernel exit code. It never exports paths, process output, server authentication, or error text. The synthetic service does not listen on a port, use a model, or access existing projects. It is cleaned up by exact native controls in `finally`.

## Validation

Authored for API 34/API 35 execution by the coordinator under the emulator lock. No device or build checks were run in this worker slice. Runtime results must be recorded separately by the coordinator.
