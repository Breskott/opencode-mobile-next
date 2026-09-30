# Phone engine gateway handoff — 2026-09-30

This is the additive backend contract for Claude's UI branch. The agreed engine
is a native Android Rust daemon outside proot, owned by the existing foreground
service. Workers are sessions on the one phone OC1 server. No host service,
extra ACP process, UI edit or `main.dart` change is part of this branch.

## Current availability

The coordinator's app-authority and device-self-check decision supersedes the
old complete-global-idle prerequisite. The backend implements protected store,
queue, session driver, isolated worker clones and canonical Git authority. It
conditionally enables canonical import, lanes and confirmed promotion **on this
phone** after the exact native bundle passes all isolated startup controls and
Rust verifies its native-parent-pinned Keystore receipt. A configuration boolean
cannot confer authority. Failure leaves those capabilities unavailable.

Every new native daemon generation runs native filesystem/process attacks and
real proot/Git positive and negative controls, checks the fixture, signs the
receipt and establishes durable confinement of future server/service/PTY launches.
App updates change packaged hashes and require a fresh proof. An existing
unconfined server/terminal or uncertain process inventory requires an explicit
owner stop/restart; the engine does not kill the person's chat. Unsupported
kernel, Android proc policy or proot compatibility remains a real blocker.

App-authoritative chat admission is separate from supported execution capability:
fresh known idle permits a new team prompt; busy or missing/stale/unknown evidence
pauses admission. No in-process model priority or complete multi-device global
status is claimed. OC2 execution remains unavailable. Live phone acceptance and a
real provider-backed task remain separate from local test/build results.

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
`restartRequired` identifies that prerequisite in native status. After a successful proof, ordinary built-in server and terminal launches
automatically consult the persistent protection marker. A server restart alone
does not clear a failed proof or stale chat admission. Claude owns the presentation and localized copy.

## HTTP and durable commands

Every route requires Bearer auth and binds numeric `127.0.0.1` only:

| Route | Contract |
| --- | --- |
| `GET /v1/health` | schemaVersion=1, profileId, engineVersion, capabilities, exact commandActions, safe protocol/boundary reasons |
| `GET /v1/workspace` | schemaVersion=1, revision, simulated=false, typed TeamWorkspace |
| `POST /v1/commands` | existing TeamProjectCommand JSON → TeamCommandResult |
| `POST /v1/chatBusy` | authenticated app heartbeat; bounded lease, generation and sequence; acknowledged before human dispatch |
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

## Chat authority and native receipt additions

The additive heartbeat body is `{until: unixMillis, sessionIds: string[],
directories: string[], known: bool, appInstance: string, sequence: int}`. Leases
are at most 30 seconds; the adapter renews every 10 seconds while idle **and**
busy and sends changes immediately. Idle also needs renewal: silence is unknown.
The app controller combines its current-directory session-status reconciliation,
connected live event stream and exact dispatch latch. The handwritten OC1
transport invokes an awaited before-dispatch callback for prompt, correlated
prompt, shell and slash-command, so this protection does not depend on a UI edit.
The engine serializes the heartbeat acknowledgment with actual team HTTP prompt
admission. Failure to deliver busy evidence stops only the tracked phone engine
before allowing human dispatch; an uncertain stop does not pretend safety.

While the native app parent is alive, missing/expired/unknown heartbeat cannot
fall back to an idle poll. Whole-app process death normally also terminates its
native daemon through parent-death signaling. In lifetimes where the parent is
positively absent, fallback requires connected `/global/event` observations and
strict `/session/status?directory=...` snapshots for every durable known person
directory. Unknown process presence, directory, response or stream pauses.
SSE busy observations veto admission even during a fresh idle app lease; a
complete idle refetch cannot overwrite a newer busy event. SSE reconnect/silence
never proves idle or turn completion. Known directories persist privately;
heartbeat leases never survive daemon restart as fresh authority.

Residual scope: another client/device may start a reply in an unobserved directory
or race after a snapshot. OC1 supplies no atomic global inventory/admission lock.
This implementation protects this app's own turns and conservatively observes
known directories; it cannot promise global priority across unrelated clients.
Additive `PhoneEngineHealth` fields expose `boundaryReason`, `restartRequired`,
`admission`, `chatAuthority` and `globalAdmissionAuthority`; older payloads default
to unknown admission. The health response therefore reports `chatAuthority=phoneAppAndKnownDirectories`,
`globalAdmissionAuthority=false`, and separate `admission` state.

Native config adds `boundary.receiptFile`, `publicKeyFile`, `generation`; `verified`
remains false. The parent separately supplies public key/policy hashes and the
launch generation in actual daemon argv. Exact signed receipt bytes bind profile,
parent PID, boot/kernel, policy, all three packaged binary hashes, complete controls
and monotonic issuance. Rust verifies freshness on startup, then revalidates the
accepted receipt digest and current invariants before every authority step.
A replaced receipt or binary closes capabilities immediately. See
[runtime receipt contract](../qa/aiteam-phone-engine-2026-09-30/native/runtime-attestation.md).

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

`engine/phone/tool/build-android.sh --stage-android` builds all three native
executables for ARM64 and x86_64 with the pinned NDK. Manifest schema 2 contains
an `abis` object with each target, API and exact binary hashes, plus the shared
source digest and dependency notices. Native verification selects the actual
installed ELF architecture, checks all three files and rejects mixed bundles.
Android's existing JNI packaging extracts them into nativeLibraryDir outside
app-writable data. Other ABIs remain unavailable. An x86_64 build does not waive
the real emulator kernel/proot boundary proof.

See [slice QA](../qa/aiteam-phone-engine-2026-09-30/README.md) and the linked
per-slice READMEs for commands and remaining device acceptance. Compiling/staging these
artifacts is not device verification, APK signing, installation or release.

## Startup and recovery follow-up

The native `port` argument is now a compatibility hint. The child binds port 0
and reports its actual port over its private stdout pipe, authenticated with
HMAC-SHA256 over `oc-phone-engine-ready-v1\n<profile>\n<port>\n<nonce>`.
Native sends no bearer token to TCP before verifying that child message.
Always use `phoneEngineCredentials.baseUrl`; the app must not assume port 4098.
The app holds child stdin open; EOF on stop or whole-process death triggers
graceful engine shutdown. A short-lived channel thread exiting no longer stops
the daemon. Trusted Android app-data aliases normalize to canonical paths;
symlinks below app storage still refuse launch/import.

Explicit `resumeTask`/`resumeProject` now refetch recorded dispatched or uncertain
sessions. A completed worker continues to a new checker without resending its
worker prompt. A provably undispatched abandoned clone can be recreated from
current dev. Missing dispatch evidence or uncertain session creation remains
blocked for review. This does not claim automatic recovery of every interrupted
merge/fix/permission checkpoint. Usage-only updates advance workspace revision
and a usage revision, while keeping the project command revision stable.

The person-directory ledger excludes the entire team worker namespace before
session-birth events can pollute it. Its bounded LRU protects busy/current scopes;
unknown observations recover only through complete fresh scoped status evidence
at the same observation revision with a continuously connected observer.

Accepted commands retain their result when a later refresh fails. Older workspace
snapshots are ignored. Ordinary profile edits preserve the existing engine
Keystore token; explicit clearing/deletion has a separate operation. Closed
gateway clients leave controller ownership, and failed deletion stays durably
fenced and retryable.

The checker is advisory model evidence. An agent capable of replacing its OC1
server can falsify that server's responses; confirmation must still review the
actual dev diff and expected refs. Canonical main is protected independently.
The live acceptance wrapper and test-only preview runner are documented in
[acceptance QA](../qa/aiteam-phone-engine-2026-09-30/acceptance/README.md).
