# Phone engine gateway handoff — 2026-09-30

This is the additive backend contract for Claude's UI branch. The agreed engine
is a native Android Rust daemon outside proot, owned by the existing foreground
service. Workers are sessions on the one phone OC1 server. No host service,
extra ACP process, UI edit or `main.dart` change is part of this branch.

## Current availability

The store, scheduler, authenticated API, session pipeline, canonical Git
authority, native lifecycle, Dart adapter and deferred proof harnesses are
implemented. **Protected project execution is unavailable.** This is backend
groundwork, not a completed live task journey.

Two prerequisites remain:

1. OC1 1.18.32 does not expose a complete active-directory execution/status
   checkpoint. Session inventory and volatile global SSE cannot prove all
   non-team sessions idle. `global_status_unavailable` pauses admission.
2. The exact Android kernel/proot/Git boundary proof has not run. Landlock ABI 6
   and seccomp compatibility remain unverified. A caller-supplied persisted
   `verified=true` is rejected, even after a probe reports success. A future
   native attestation/generation contract must bind the proof to every proot
   execution entry point and preserve enforcement across restart.

Both gates must be resolved before enabling a real lane or promotion. Canonical
repo import is also refused until boundary verification; otherwise an existing
unconfined chat server could reach raw canonical refs despite scheduling being
disabled. Current health therefore omits `createProject`, `createQuickTask` and
`promote`. Readiness must never be inferred from a running process or a passing
compile check. OC2 execution is unavailable.

## UI connection calls

Use `ConnectionController.phoneProjectEngine`, which is profile-owned:

```dart
final health = await connection.phoneProjectEngine.start(profileId);
// Or attach to the native process already running:
final attached = await connection.phoneProjectEngine.attach(profileId);
final current = await connection.phoneProjectEngine.probe(profileId);
```

These return `PhoneEngineHealth`. `canExecute` requires execution, boundary,
verified OC1 and no OC2 flag. Start requires the existing built-in Linux/OC1
setup and its native-owned server authentication file; it does not install Linux
or create another OpenCode server. Native start tracks a single daemon. A
different active profile or port is refused. Attach saves the nonsecret
`OrchestrationProvider.phoneEngine` configuration and Keystore credential, then
refreshes active orchestration even when only the bearer token changed.

The existing orchestration gateway provides `OrchestrationProjectGateway`:
`teamWorkspace()`, `watchTeamWorkspace()`, `executeProject(TeamProjectCommand)`,
`close()` and `deleteLocalData()`. No UI imports of `api`, `api2`, HTTP clients,
native credentials, or concrete adapter internals are needed.

Gate controls on `OrchestrationCapabilities`. Workspace reading can be available
while execution is unavailable. `projectLifecycle` additionally requires all
creation/deletion verbs; it is false in the current unverified boundary state.
Lane, verification, placement, merge-queue and promotion capabilities require
actual advertised verbs and execution readiness. Unsupported commands return a
safe refusal; no command is simulated. Advanced verification/fix/recheck,
conflict resolution, manual merge queue, undo, placement and migration commands
are outside this first backend slice and remain unadvertised.

The UI should explain unavailable readiness and allow retry/probe. A legacy
server or terminal cannot silently be killed to change protection mode.
`restartRequired` identifies that prerequisite in native status. Protected
server restart is a separate explicit setup operation; it never clears the
proof/admission gates by itself. Claude owns the presentation and localized copy.

## HTTP and durable commands

Every route requires Bearer auth and binds numeric `127.0.0.1` only:

| Route | Contract |
| --- | --- |
| `GET /v1/health` | schemaVersion=1, profileId, engineVersion, capabilities, exact commandActions, safe protocol/boundary reasons |
| `GET /v1/workspace` | schemaVersion=1, revision, simulated=false, typed TeamWorkspace |
| `POST /v1/commands` | existing TeamProjectCommand JSON → TeamCommandResult |
| `GET /v1/events?after=0&limit=100` | durable ordered metadata events, not raw prompts/tool output |
| `DELETE /v1/profile` | durable tombstone → deleted=true; native owner subsequently stops/sweeps |

Commands need a unique requestId and expectedRevision for project changes.
Identical successful retries return the original result; changed payloads using
the same requestId are rejected. Canonical import intents bind repository,
source and request so a crash between import and the SQLite commit can be
reconciled. The client never automatically retries a mutating transport failure.
The existing typed command shape is unchanged.

Planner output proposes spec/phases/tasks JSON for approval. Approved tasks use
private independent clones, one recorded worker session and a separate read-only
checker session. Role instructions/models are snapshotted when queued, including
the checker role. Each criterion must be reported; any finding blocks automatic
merge in this slice. The exact checked commit is revalidated before a serialized
canonical `dev` merge. No native project test-command runner is implemented;
checker judgments are not evidence that repository tests executed.

Promotion requires confirmed=true, project revision, targetId=repository id,
expectedDevCommit, expectedMainCommit and requestId. Only the native authority
updates canonical main and persists an expected-SHA receipt. Hooks in worker
clones are defense in depth. A hook override cannot establish access to the
canonical repository. No generic shell/ref-write API exists.

## Recovery, budgets and deletion

SQLite WAL/FULL transactions retain queue stages, recorded session IDs,
idempotency, actual Git receipts, unknown usage and digest events per profile.
App/OS interruption marks active jobs `interrupted`. It never automatically
creates a replacement session or resends an uncertain prompt. Existing sessions
can be refetched by the driver; interrupted commands still require explicit
reconciliation/review. Recovery after an uncertain Git mutation must reconcile
physical refs/receipts before permitting further work. Automatic completion of
all interrupted checkpoints is not claimed.

Single/parallel admission checks dependencies, fresh chat idleness, configured
lane limits and known usage. Per-session cumulative usage is summed once;
missing cost or explicit token total remains unknown. Daily-cost attribution and
charging telemetry are not established by this slice; finite daily/charging-only
requirements pause when their evidence is unknown. No per-session process
priority or memory estimate is presented as measured truth.

`close()` releases the adapter and leaves the native daemon running. Profile
deletion uses the existing `deleteProfileAndLocalData` flow, including inactive
phone-engine profiles. Deletion first latches client admission, drains in-flight
writes, durably tombstones the store, stops tracked processes and removes private
state/worker clones without following links. Failed/uncertain deletion retains
its intent and blocks reactivation; credentials are not silently discarded while
the daemon could still be writing. Native lifetime remains bounded by service
and OS policy; timeout/stop does not promise an unbounded background worker.

## Local packaging and evidence

`engine/phone/tool/build-android.sh --stage-android` builds the three ARM64 native
executables with the pinned NDK, stages them in jniLibs, adds an Android asset
manifest with SHA-256 hashes/source digest and bundles exact dependency notices.
Native launch/proof verifies the packaged hashes. Android's existing legacy JNI
packaging extracts the executables into nativeLibraryDir outside app-writable
data. Other ABIs have no engine artifact and fail unavailable.

See [slice QA](../qa/aiteam-phone-engine-2026-09-30/README.md) and the linked
per-slice READMEs for commands and deferred acceptance. Compiling/staging these
artifacts is not device verification, APK signing, installation or release.
