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
native daemon through retained stdin-pipe EOF and graceful SIGTERM. In lifetimes where the parent is
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

### Review closure: additive contract (2026-09-30)

- Semantic create validation runs before importing Git; rejected commands remain durably replayable. Accepted `deleteProject` may add `cleanupPending: true` if attributable repository/worker cleanup needs retry. Replay of that same request retries cleanup while remaining accepted. Receipt audits are retained; collected repository IDs are retired and must not be reused.
- `chargingOnly: true` is refused with `chargingUnsupported` until power telemetry is available. Health adds `chargingTelemetry: false`; existing charging-only projects pause honestly until edited.
- `/v1/health` adds `eventWindow: {retentionLimit, prunedThroughSeq, earliestAvailableSeq, latestSeq}`. `/v1/events` retains its list shape, adding `type` as an alias of `kind`. The newest 10,000 metadata rows are retained. A cursor before the durable prune watermark returns HTTP 409 `{code: "cursorExpired", resetRequired: true, eventWindow: ...}`. Dart activity propagates safe `PhoneEngineException('cursorExpired')`; consumers must refresh the durable workspace and show an incomplete event-history interval instead of inferring that no work happened. Workspace/spec/promotion histories remain retained.
- Checker findings remain advisory evidence for dev. A same-UID agent can replace the in-rootfs OC1 endpoint; main promotion still requires the person's confirmed expected-SHA request. The UI coordinator should present the dev diff at promotion.
- Native deletion now invokes the verified packaged engine's `--erase-tree` helper for descriptor-anchored mode-000 cleanup after tracked processes stop. This is an internal native CLI, not an authenticated engine command or agent authority.
- Both critical and all seven major paths have focused faulty-behavior controls; see the review-closure QA README. A5's startup global-lock delay remains pending a shared cancellation/admission fence. Completely damaged unscoped legacy receipts remain preserved/fail-closed until an operator quarantine path exists.

### Setup flow additions for b645f086 (2026-09-30)

1. `PhoneProjectEngineController.start()` preserves `BuiltinLinuxException.code` as `PhoneEngineException.code` (including `restart_required`, `boundary_not_packaged`, `boundary_unavailable`). A typed phone-engine failure also preserves its code. Unknown exceptions still map to `engineUnavailable`. Native message, details and exception causes are not retained in the public failure.
2. Native `phoneEngineStatus` and Dart `BuiltinPhoneEngineStatus` add `unconfinedChildren: bool`: an app-wide inventory of live unconfined old servers/terminals/processes, independent of this profile's daemon `running` flag. It is available before start and after stop; older channel maps default the field to false for compatibility. Inventory failure remains an unavailable status, never guessed idle. Existing `restartRequired` and capability gates remain supported.
3. Start now stops the tracked same-profile daemon before running a fresh boundary probe and issuing a new signed generation bound to the packaged binaries. A running daemon/old receipt no longer skips proof. Native start also refuses reusing its own live process and invokes the proof factory again. A different profile's active engine returns `engine_in_use` without being displaced. Unconfined children still block proof (`restart_required`/capabilities false); start never pretends that the skipped proof passed.
4. Controller start drains its old heartbeat producer and gateway clients before native token rotation. Consumers rebind through the existing `onAttached` callback after the fresh credential handoff. Start is an explicit generation refresh: active engine jobs become interrupted checkpoints and resume by existing-session refetch; no prompt is automatically resent. Calling `attach()` remains the operation for reusing a healthy running engine without a restart/probe.

No UI files are changed. On-device running-generation proof instrumentation is separate from host/Dart compile evidence; see the setup-contract QA README.

### Codex device-E2E backend contract, 2026-09-30

Finish line: packaged native executables match the attested hashes, unsupported
Android confinement fails promptly with a typed code, and a failed setup restores
only the OpenCode server stopped by that setup. Non-goal: UI edits, release
delivery, legacy Gas City data migration, or authority from a proot path view.

- Release `assembleRelease` now verifies actual APK bytes and the packaged
  manifest. `libaiteam_*.so` retains its symbols; modifying/stripping any packaged
  executable is a build failure, rather than a device-only failure.
  It also requires `sourceSha256` to match current Cargo inputs and Rust source;
  cherry-picking Rust code without rebuilding/staging the executables fails with
  `stale_engine_sources_rebuild_and_stage`. Rebuild both ABIs with
  `engine/phone/tool/build-android.sh --stage-android` before assembling the APK.
- `--check-kernel` tests query/create/add/restrict in a disposable child with a
  bounded wait. Inherited seccomp SIGSYS produces normal launcher exit 78.
  Native activation reports `boundary_unsupported` before starting a daemon
  when this prerequisite fails. No unsigned/configurable probe result enables
  canonical import, lane admission, or promotion.
- Additive setup call: **`await linux.stopServerForPhoneEngineSetup()`**.
  Only the confirmed phone-team setup stop uses this flag. An ordinary
  `stopServer()` clears the rollback ticket and remains an intentional stop.
  Failed native activation restores the captured same-runtime script/port;
  identical subsequent starts join the live process. The UI should still call
  its existing restore/reconnect path on every failure, including failed server
  start: native rollback cannot promise that the restored server passes HTTP
  health, and it cannot restore a stop ticket lost with app-process death.
- Before restarting OpenCode, the setup controller must gate on
  **`health.boundary`**, rather than `health.canExecute`. Execution includes
  verified OC1 protocol evidence and cannot be required while OC1 is stopped.
  After restarting OC1, wait for `health.canExecute` using fresh health reads.
  These are requests to the coordinator-owned setup controller, not UI edits
  in this backend branch.
- Legacy `BuiltinTeam` recovery is separate from `phoneEngine`. Healthy legacy
  cities skip blocking registration; background store observation expires
  after 60 seconds and is cancelable. This does not accelerate Dolt bootstrap
  or migrate/deactivate legacy profiles.

The proposed Landlock-free alternative is tested with an isolated private
sentinel and actual controls inside proot: worker reads/writes/Git/stat/readlink,
private direct paths and symlink aliases, `/proc` roots/environment/cmdline,
inherited descriptors, and an exact owned tracer-kill escape. The diagnostic
never signs a receipt or grants capabilities. A failed denial or escaped write
means this device remains unsupported. Changing `/proc` binds alone cannot
replace enforcement if a worker can detach from proot. Device results and
artifact hashes are recorded in the E2E-fixes QA README.

### Owner-selected proot tier, 2026-09-30

Landlock remains preferred. Android-seccomp-blocked devices now attempt the
owner-approved proot tier instead of refusing solely on `boundary_unsupported`.
A complete inside-proot private-path/process/FD/environment proof signs a
schema-2 receipt with `tier=proot`, `nativeAttacksDenied=false`, and the actual
proot controls. Before auth handoff the actual daemon is checked again. Failure
remains a typed refusal, without execution authority. Fresh activation requires
all old server/terminal/tool processes stopped, including older proot generations.

`PhoneEngineHealth.boundaryTier` and native status `boundaryTier` are additive
strings (`none`, `landlock`, `proot`). Health reports the tier at both top level
and in `capabilities`; tier tampering invalidates authority. For `proot`, UI may
show the owner-approved plain line: "Protected by this phone Linux sandbox".
PRoot is ptrace-based path translation, not a kernel boundary; the signed tier
does not claim denial of raw native/tracer attacks. The QA README records this.

The setup sequencing contract still applies: after confirmed stop, require
`health.boundary` before restarting OC1 via `startProtectedPhoneServer`, then
wait for fresh `health.canExecute`. Requiring `canExecute` while OC1 is stopped
is circular. Missing real OC1 auth now reports `server_auth_unavailable` before
signing or starting; the durable store is not advertised as runnable without
that execution prerequisite. No fabricated credentials are installed.


## Additive command refusal contract (run 3 repair)

Authenticated HTTP command failures return only `{"code": "<static symbolic reason>"}` (409 for semantic refusals). Dart preserves that code in `TeamCommandResult.code`; it never carries raw exceptions, response bodies, Git paths or credentials into UI errors. HTTP 2xx `accepted:false` keeps the existing typed receipt. Redirects remain `redirectRefused`, missing authentication is `authenticationRequired`, and a write with unknown transport outcome is `transportUncertain` (never automatically resend).

Creation imports committed Git history into the private canonical repo; an unborn repository is refused as `repository_empty`. Commit the intended seed in the source, then retry. Failed imports that published no canonical or worker authority no longer retire the editor's repository ID. Published/deleted canonical repository IDs remain permanently retired. Old retirement markers are not automatically resurrected because their history is ambiguous; use a fresh repo ID/form.

Primary UI mappings:

| Code | Meaning |
| --- | --- |
| `repository_empty` | Source Git repository has no initial commit. |
| `repoPathInvalid` | Folder does not resolve inside the phone's permitted projects root. |
| `repository_retired` | This engine repository ID was retired; create a fresh project/repo ID. |
| `repository_exists` / `import_binding_mismatch` | Existing import belongs to another request; do not overwrite it. |
| `repository_io` / `repository_git` | Repository could not be read or imported; raw OS/Git errors are withheld. |
| `unsafe_repository_metadata` / `unsafe_repository_config` / `shared_repository_objects` / `symlink_refused` / `unsafe_repository_path` | Source metadata fails isolation checks; symlinks/alternates/config includes are never followed into private storage. |
| `divergent_import` | Source dev is not descended from source main. |
| `staleRevision` / `stale_dev` / `stale_main` | Reviewed project/ref changed; refresh and review again. |
| `confirmationRequired` | Promotion requires explicit app confirmation and reviewed SHAs. |
| `boundaryUnavailable` / `executionUnavailable` | Phone protection/execution proof is unavailable. |
| `chooseExecutionMode` / `chooseBudget` / `invalidPlacement` / `invalidSpec` | Correct the corresponding draft field. |

The full static repository and store reason catalog is in [run 3 backend QA](../qa/aiteam-phone-engine-2026-09-30/run3-backend/README.md). The gateway change is additive; Claude owns plain-language UI mappings and Details.

Committed phone repositories use proot's L2S hardlink emulation. The native snapshot now normalizes only exact loose/allowed pack object aliases through the original dirfd, bounded same-directory chains and explicit decoded object hash checks. This applies to both source import and worker collection. Arbitrary metadata links, config/refs/HEAD aliases and private/proc targets remain refused. Additive codes `invalid_proot_object_link` and `repository_object_hash_mismatch` distinguish an unsafe chain from corrupt object identity; `repository_too_large` also covers decoded-object limits (64 MiB per object, 2 GiB total, 200,000 objects/files).

Planner proposals now require a nonempty task title (`planTaskTitleRequired`). The planner prompt provides the authored JSON schema explicitly; intake normalizes runtime defaults and checks role/repo/server/phase placement and dependency validity transactionally before publishing `needsPlanApproval`. A missing-title proposal rolls back without changing the workspace or job. This fixes the live GLM planner/approval contract mismatch.

Phase intake also rejects malformed types, missing titles and duplicate IDs with `planPhaseInvalid`; it strips model runtime fields and forces `accepted:false`. The planner receives the configured implementation-role catalog and a role enum. Job update failures preserve their static store reason.

Structured-output intake accepts raw JSON or exactly one explicit JSON/untagged fenced block with surrounding prose. Extra fences or object/array delimiters outside the block remain `structuredOutputInvalid`; schema, criterion matching, findings severity and no-waiver checks are unchanged. No prose is interpreted as a verdict.

## Run 4 additive planner and readiness contract (2026-10-01)

An empty role `model` uses the authenticated OC1 server's default model: omit
`model` from `prompt_async`, whose pinned schema requires only `parts`. An
explicit selection remains `provider/model` and is validated before any clone,
session or dispatch checkpoint. Local errors retain typed reasons; only a
transport with an uncertain outcome becomes `promptUncertain`. Existing
uncertain jobs are not resent automatically.

Workspace reads now project each project's nullable `planningState` as
`{jobId, stage, reason, updatedAt}` from the durable planner job. `timeline`
contains bounded durable stage/reason events, with `timelineTruncated` when
older events were omitted. Legacy interrupted planners with no timeline get a
stable read-only checkpoint row. Consumers should show the planner stage and
reason rather than the generic dependencies label while planning is pending.
`TeamServer.reason` is an additive string. The phone server's `online`,
`chatWaiting` and reason are derived live without changing the command revision.

Health adds `readinessReason`: `protocolUnverified`, `transport_unavailable`,
`authentication_failed`, or the static protocol verification code identify the
unavailable protocol prerequisite. Server reasons additionally expose
`chatBusy` and `chatStatusUnknown` for admission waits.
A proven boundary's positive `boundary_attested` is not a readiness failure;
Dart's legacy failure getter returns the protocol reason instead. Failed OC1
verification retries after 2 seconds; healthy revalidation stays at 30 seconds.
Before native snapshots OC1 credentials, production start writes the app-owned
phone profile password through the existing atomic password writer. Missing or
failed preparation returns `server_auth_unavailable` or
`server_credentials_write_failed`.

The authoritative managed-phone chat observation refreshes every 5 seconds,
including idle/unknown states and pending session-page loads. Reads time out
at 4 seconds; an observation older than 15 seconds is unknown. New busy/retry
IDs block admission even without session metadata. Generation, directory,
workspace and later-observation fences reject stale reads. No heartbeat or
reconnect by itself establishes idle, and another client on another device
remains the previously documented residual observation gap.

Real-UI follow-up: the phone adapter presents native `needsPlanApproval` as
`plan`, so the existing domain approval editor can submit the reviewed tasks,
phases and unchanged command revision. Native engine status/checks remain
unchanged. Unapproved active planning is presented as `running`, queued/unknown
planning as `waiting`, interrupted/failed planning as `failed` (restart/pause
reconciliation as `stalled`). Raw `planningState` remains available. A static
current-checkpoint timeline row shows allowlisted failure codes; no provider
error body is rendered. Task `checked` presents as `verified`, `needsFix` as
`findings`, and `merging` as `running`, retaining raw durable engine evidence.
This does not expose unsupported retry/use-as-task commands.
