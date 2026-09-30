# Phone project engine review (2026-09-30)

- **Scope:** branch `crit/aiteam-integration` at `f4786c8b`, compared with `feat/phone-setup-v2`. It covers:
  - `engine/phone/**`;
  - the Kotlin launcher, attestation and lifecycle code under `android/app/src/main/kotlin/**`;
  - the phone-engine Dart adapter and state in `lib/state` and `lib/orchestration/adapters/inapp`.
- **Method:** reading only. No tests, builds or device runs were done. Sub-reviewers first read the Kotlin and Dart slices; every finding kept here was re-read against the source.
- **Confidence tags:** **verified** means I read the whole failure path. **likely** means one step depends on platform behavior that should be checked on a device, and the check is named.

**Summary: 2 critical, 7 major, 22 minor.**

The two critical findings are lifecycle bugs. Either one alone stops the engine from staying up on a real phone. Host tests cannot see them: they run the daemon from a long-lived parent, and host paths have no symlink ancestors. No security finding lets an agent write `main` or read the bearer token or receipt key from disk.

## Top 5

1. **C1 (critical).** The daemon is killed by SIGTERM as soon as the MethodChannel thread that started it exits.
2. **C2 (critical, likely).** On Android the private and worker roots sit under the `/data/user/0` symlink, so `RepositoryAuthority::new` rejects them and the daemon exits.
3. **S1 (major).** The token is sent to, and health is trusted from, anything listening on the fixed loopback port. A proot agent or another app can take the port, collect the bearer token and pose as the engine.
4. **R1 (major).** `interrupted` is a dead end. There is no command that resumes a task, and restarts, pauses and transient HTTP errors all lead to `interrupted`.
5. **R3 (major).** The project revision goes up with every usage tick, so Stop, Pause and Promote regularly fail with `staleRevision` while a task runs.

---

## Critical

### C1. The daemon's parent-death signal is tied to a short-lived thread, so the engine dies right after start (verified)

**Where:**
- `engine/phone/src/main.rs:11-13` sets `PR_SET_PDEATHSIG(SIGTERM)`.
- `MainActivity.kt:397-417`: `inBackground` runs every channel call on a new, short-lived `Thread { … }.start()`.
- `PhoneEngineNative.kt:103-113`: `ProcessBuilder.start()` is called from that thread.

**Failure:**
- Linux sends the parent-death signal when the parent *thread* that forked the child exits, not when the whole process exits (see `prctl(2)`: "the thread that created this process").
- `startPhoneEngine` returns once `awaitHealth` succeeds, and the worker thread then ends. The daemon receives SIGTERM, runs graceful shutdown, and `store.recover()` marks any work `interrupted`.
- The `waitFor` watcher (`BuiltinLinux.kt:455-463`) removes the service.
- The result: the engine never outlives the start call on a device. Dart gets `running=true` once, and every later status call says it is stopped.

**Severity:** critical.

**Fix:** start the daemon from one dedicated thread that lives as long as the process (a `HandlerThread` owned by `PhoneEngineNative`). Alternatively, drop PDEATHSIG and have the daemon exit when its stdin pipe reaches EOF: keep `child.outputStream` open instead of closing it at `PhoneEngineNative.kt:115`. Either way the daemon still cannot outlive the app process.

### C2. Symlinked ancestors make repository authority refuse Android app-data paths (likely; verify on device)

**Where:**
- `repository.rs:85-98`: `new` calls `check_ancestors` and `secure_create_dir`.
- `repository.rs:717-740`: `check_ancestors` and `secure_create_dir` open each component from `/` with `O_NOFOLLOW` and refuse any symlink.
- `PhoneEngineNative.kt:83, 91, 96`: config paths are built with `File(context.filesDir, …).absolutePath`.

**Failure:**
- `getFilesDir()` returns `/data/user/0/<pkg>/files`. On Android, `/data/user/0` is a symlink to `/data/data`. Zygote's `isolateAppData` recreates that symlink inside the app mount namespace, which the daemon inherits.
- `check_ancestors("/data/user/0/…/oc.teamEngine.<p>/repos")` therefore returns `symlink_refused`, `serve` returns `repositoryUnavailable` (`daemon.rs:69-73`), the child exits, and `awaitHealth` throws `engine_start_failed`.
- The Kotlin side already avoids this: `regularNoLinks` stops at `filesDir.parentFile`. The Rust side walks all the way up from `/`.
- The same mismatch also makes the private-root containment comparisons in S3 compare canonical paths with non-canonical ones.

**Check:** `adb shell run-as <pkg> ls -ld /data/user/0`.

**Severity:** critical.

**Fix:** put `canonicalPath` into `native-config.json` for every root and file. In Rust, canonicalize the roots once at config load, and apply the no-follow walk only below the app data directory.

---

## (1) Security

### S1. Port squatting leaks the bearer token and lets anything pose as the engine (major, verified)

**Where:**
- `PhoneEngineNative.kt:45` uses a fixed port (default 4098).
- `PhoneEngineNative.kt:198-218` (`awaitHealth`) sends `Authorization: Bearer <fresh token>` to `127.0.0.1:<port>` from the moment of `start()`.
- `PhoneEngineNative.kt:126-127` accepts `capabilities.boundary` and `execution` from whatever answers.
- `PhoneEngineNative.kt:136-140` (`credentials()`) later gives Dart the same token and URL.

**Failure:**
- A bash-enabled worker agent can bind 127.0.0.1:4098 while the engine is stopped or restarting (C1 makes that window permanent). Worker bash is allowed at `opencode.rs:702`, and agents share the app UID and network namespace; the Landlock/seccomp policy does not restrict TCP. Any other installed app can do the same.
- The daemon then either fails to bind or loses the race, and Kotlin's very first health poll delivers the new token to the squatter.
- The squatter can answer `{"schemaVersion":1,"profileId":…,"capabilities":{"boundary":true,"execution":true}}`. Kotlin then records `verifiedBoundary=true`, and Dart sends heartbeats and commands to it. The UI shows an attested engine that does not exist.
- The token only authorizes the dead generation, so this is impersonation and token disclosure, not canonical write access.

**Fix:** bind the listener to the child. Options:
- Bind port 0 and report the port plus an HMAC(token, nonce) over the child's stdout pipe.
- Before sending the token, check that the socket inode listening on the port belongs to `/proc/<childPid>/fd`.
- Use a Unix socket in the private root. Agents already cannot use `AF_UNIX`.

### S2. The checker gate trusts an OC1 endpoint that agents can replace (minor, verified)

**Where:**
- `config.rs:94-96` pins the OC1 base URL to `http://127.0.0.1:4097`.
- `opencode.rs:153-179` verifies only the health `version` field and the OpenAPI shape.
- `daemon.rs:942-980` merges into dev when the checker reports "met".

**Failure:**
- The worker agent has `bash:*` and runs as the OC1 server's UID inside the same proot, so it can kill the server and serve a fake one on port 4097.
- The fake passes `verify()`, returns `completed` with a verdict of every criterion met, and receives the daemon's Basic credentials.
- An unchecked commit then lands on **dev**. `main` still needs a confirmed expected-SHA promotion, so this is not a write to main.

**Fix:** treat the checker as advisory in the docs and UI, and show the dev diff at promotion. Optionally, check that the listener on 4097 belongs to the tracked OC1 service pid before each stage.

### S3. Private-root containment checks compare canonical and non-canonical paths (minor, verified)

**Where:**
- `config.rs:178` checks `result.starts_with(&self.private_root)`, where `result` is canonical and `private_root` is raw.
- `repository.rs:127-133` checks `source` (canonical) against the raw `private_root` and `worker_root`.

**Failure:** with an Android `/data/user/0` prefix these checks can never match, so they are no-ops. Escape is currently prevented only by the canonical `host_root` prefix check (`config.rs:177`). A future second source root (for example the rootfs) would silently lose the protection.

**Fix:** canonicalize both roots at config load and compare only canonical paths (same fix as C2).

### S4. Agent-authored trees are checked out inside the private root (minor, defense in depth)

**Where:** `repository.rs:212-243`. `prepare_worker` runs `Repository::init` and `checkout_head` in `private_root/staging/<uuid>`, on a dev tree that previous agents authored (fast-forwarded by `merge_dev`, lines 351-352, with no object validation).

**Failure:** any libgit2 checkout path-traversal bug would write into `private_root/repos` or `receipts`, which amounts to a direct ref write without promotion. Examples: a crafted tree with duplicate `a` / `a/` entries, a symlinked directory followed by a child, or a relative symlink like `../../repos/x.git/refs/heads`. I believe current libgit2 removes symlinks in the mkpath step, so this is hardening, not a proven exploit.

**Fix:** stage checkouts in an engine-owned directory outside `private_root`. Alternatively, reject task commits whose trees contain duplicate names, `.git` components, or symlinks with absolute or `..` targets before `merge_dev`.

### Checked and OK

- **Constant-time token comparison:** the only leak is a length check against a fixed 64-character length (`daemon.rs:143`).
- **Secrets in argv, environment and logs:** there are none. Kotlin clears the environment and sends stdout and stderr to `/dev/null`. Error codes are static strings. `OpenCodeClient` is deliberately not `Debug`.
- **Daemon inspection:** `PR_SET_DUMPABLE=0` is set.
- **Private files:** token, credential and receipt files are 0600 under a 0700 root, written with `O_EXCL|O_NOFOLLOW`. The Keystore key is non-exportable P-256 used for SIGN and VERIFY, with no plaintext fallback.
- **Sandbox descriptors and syscalls:** the sandbox closes inherited descriptors and denies `AF_UNIX`, `TIOCSTI`, mount, namespace and handle syscalls. Landlock scopes ptrace, so `/proc/<app>/{fd,environ,root,mem}` are denied.
- **Snapshot copy:** it uses fd-relative `O_NOFOLLOW`, refuses hardlinks, refuses alternates, grafts and replace refs, and rewrites the config.
- **Ref writes:** ref transactions lock `DEV` and `MAIN`. There are no force updates, and promotion is fast-forward only with an intent receipt.
- **Landlock ABI:** the sandbox requires ABI 6 (Linux 6.12+). Many shipping GKI 6.1 and 6.6 phones will fail closed. That is a product reach limit, not a defect.

---

## (2) Correctness

### R1. `interrupted` is terminal, so the recovery code never runs (major, verified)

**Where:**
- `store.rs:1242-1245`: `resumeTask` rejects interrupted jobs with `needsReconciliation`.
- No command performs the `interrupted→resuming` transition that `valid_transition` allows (`store.rs:1325`).
- As a result, `daemon.rs:837-839` and the whole of `resume_job` (`daemon.rs:998-1073`) are unreachable.

**How jobs reach `interrupted`:**
- Every restart: `recover`, `store.rs:528-579`.
- Pausing running work: `pause_job`, `store.rs:1275-1282`.
- Any single failed observe HTTP call: `daemon.rs:1083-1087` maps it to `sessionUnknown`.
- Budget, cap or dependency refusals mid-pipeline, and C1's SIGTERM.

**Consequences:**
- The task is stranded, and its dependents wait forever on `dependencyPending` (`scheduler.rs:116-118`).
- `approveSpec` refuses while any job is interrupted (`store.rs:1108-1123`), so the project is stuck until the user stops or deletes it.

**Fix:**
- Add a reconcile command: `interrupted→resuming` when a session id is recorded, and `interrupted→queued` with a fresh worker when nothing was dispatched.
- Tolerate transient observe errors with bounded retries before interrupting.

### R2. The first poll after `prompt_async` can read as `unknown`, which ends the task (major, likely)

**Where:**
- `opencode.rs:875-964`: `observation` returns `state:"unknown"` when both status snapshots are idle and the last user/assistant pair does not exist yet.
- `daemon.rs:1111`: `await_completion` maps that to `Err("sessionUnknown")`.

**Failure:** `prompt_async` returns 204 before OC1's loop marks the session busy or persists the user message. The first observe, a few milliseconds later, can therefore see idle status and no turn. The task becomes `interrupted` (terminal per R1) at random.

**Fix:** until the dispatched user message id is observed, treat `unknown` as `running` for a bounded grace window (for example 30 s).

### R3. Usage ticks bump the project revision, so user commands go stale while a task runs (major, verified)

**Where:**
- `store.rs:446`: `update_job` always calls `increment_project`.
- `daemon.rs:1100-1104`: `await_completion` writes `sessionUsage` whenever token totals change, which can be every 2 s.
- Every project command requires `expectedRevision == revision`: `store.rs:1073`, `daemon.rs:342`, `store.rs:500`.

**Failure:** Dart polls every 3 s (`phone_engine_gateway.dart:239`). Stop, Pause, Stop task and Promote, pressed during generation, often return `staleRevision`. Stop is least reliable exactly when the user needs it.

**Fix:** keep usage out of the project revision (use a separate usage counter). Alternatively, exempt stop and pause, which are idempotent, from the revision check.

### R4. The chat directory ledger fills permanently and `unknown` is sticky (major, verified)

**Where:**
- `admission.rs:139-165` and `chat.rs:106-139`: every non-team SSE status teaches the ledger a directory.
- `admission.rs:66-91`: the directories are persisted.
- Nothing ever evicts a directory.
- `chat.rs:149-151`: `observation_unknown()` is never cleared.

**Failure:**
- Each task has its own worker directory (`daemon.rs:853`).
- The new session's first status event can arrive before its id is recorded as a team session (`create_session` at `daemon.rs:863-867`, then `patch` at `873-878`). Worker directories are therefore learned as the person's directories.
- At 256 directories, `observe` fails, the sticky `observation_unknown` flag is set, and admission stays `Unknown` until the daemon restarts. After restart the next new directory trips it again.
- Heartbeats that carry a new directory fail with `directoryLimit`.
- Execution halts permanently after roughly 256 tasks. One malformed SSE directory halts it immediately.

**Fix:** ignore directories under `guest_worker_root`, bound the set with LRU eviction, and clear `observation_unknown` on a fresh complete snapshot or reconnect.

### R5. Engine dispatch holds the chat read lock across up to 30 s of HTTP (minor)

**Where:** `daemon.rs:737-761` holds the read lock across `prompt()`. That call makes three 10-second-timeout requests (`opencode.rs:66-71, 300-328`). `admission.rs:96` needs the write lock to acknowledge the app's busy lease.

**Failure:** the person's own send waits for that acknowledgement and can stall for up to about 30 s.

**Fix:** use short timeouts for the dispatch path. Alternatively, acknowledge immediately with a sequence fence and have the engine re-check after dispatch and abort if it was fenced.

### R6. Stop and delete race against in-flight dispatch (minor)

**Where:** `daemon.rs:453-470` aborts only sessions that are already recorded. The stage check in `stage_admitted_with_ledger` runs before `prompt_async`.

**Failure:**
- A stop that lands between that check and dispatch aborts first, and the prompt then starts and runs to completion, billing the user.
- `delete_profile` (`daemon.rs:474-505`) does not cancel JoinSet tasks, and a session created but not yet patched is never aborted.

**Fix:** after `prompt()` returns, re-read the stage and abort if the job is not active. Abort all pipeline tasks on delete.

### R7. Rejected creates and deleted projects leak canonical storage (minor)

**Where:**
- `daemon.rs:397-452`: imports run before `store.execute`.
- `deleteProject` is store-only (`store.rs:1076-1082`).

**Failure:**
- A create rejected for, say, `chooseBudget` leaves `repos/<id>.git` behind (snapshot up to 2 GB). Dart mints fresh repo ids (`team_project_editors.dart:795-800`), so each retry leaks another copy.
- Deleted projects keep their canonical repos, worker clones, worker records and receipts until the whole profile is deleted.

**Fix:** validate the command with a dry run before importing, and collect unreferenced repos and workers on `deleteProject`.

### R8. `chargingOnly` projects never run (minor)

`daemon.rs:697` hard-codes `charging: None`, so `scheduler.rs:80-85` always returns `Pause("chargingUnknown")`.

**Fix:** carry charging state in the heartbeat, or refuse the setting while it is unsupported.

### R9. Attestation re-hashes about 6.5 MB of ELF on every check (minor)

`attestation.rs:129-138` hashes all three binaries and verifies the P-256 signature on every `boundary_verified()` call. That happens about four times per `/v1/health` (`daemon.rs:268-284`) and repeatedly per queued job every 2 s, which means constant CPU and battery drain.

**Fix:** cache the result keyed by `(dev, ino, size, mtime)`, or hash once at startup, since the APK library directory is immutable.

### R10. The events table grows without bound (minor)

`store.rs:644-654` writes one row per job update, which is roughly every 2 s per active job, and nothing prunes it.

**Fix:** cap or compact old events, since clients use cursors.

### R11. One bad receipt blocks every promotion (minor)

`repository.rs:480-529`: `reconcile_earlier_promotions` parses every `receipts/*.json` before it filters by repository. It propagates `invalid_receipt` or `promotion_recovery_required`, so a single unreadable or odd receipt blocks all future promotions for all repositories, and no operator path clears it.

**Fix:** filter by repository before propagating errors, and surface the blocked receipt for review.

### Panics, SQLite and libgit2 checked and OK

**Unwraps:** I reviewed the 33 `unwrap`/`expect` calls outside tests. All of them are guarded or static:
- `daemon.rs:1175-1179` follows validation.
- `store.rs:858-861` follows the membership loop.
- The `projects`, `tasks` and `specVersions` array unwraps rely on invariants only the engine writes.
- The `signal handler` and `"no-store".parse()` calls are static.

I found no panic reachable from input. A panic under `store` would poison the mutex and permanently return `storeUnavailable`, so keep these invariants.

**SQLite:** every write is an `IMMEDIATE` transaction. The request-id fingerprint replay is correct, promotion replay across a crash is correct, and deletion is a tombstone plus `VACUUM`.

**libgit2:** ref transactions lock `DEV` and `MAIN`, there is no force, and promotion is fast-forward only.

---

## (3) Android lifecycle

Kotlin paths are relative to `android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile/`.

- **C1 and C2 above.**

- **A1 (minor): the PDF process blocks attestation.**
  - The `:local_pdf` process (`AndroidManifest.xml:186`) runs under the app UID but is not in the `known` set of `hasUnconfinedChildren()` (`BuiltinLinux.kt:77-117`).
  - While it is alive, every start reports `restart_required` and the boundary is never attested.
  - Fix: allow the app's own process names by checking `/proc/<pid>/cmdline` against `<pkg>:*`.

- **A2 (minor): a profile can become undeletable.**
  - `eraseNoLinks` (`PhoneEngineNative.kt:283-289`) fails on a directory without write permission.
  - Agents cannot `chmod` (seccomp), but they can create read-only directories directly with `mkdir(path, 0555)`.
  - Deletion then throws, and the persisted tombstone makes every later `start()` (line 52) fail.
  - Fix: `Os.chmod(dir, 0700)` each directory, which the unconfined app is allowed to do, before listing or deleting it; skip entries that are already gone.

- **A3 (minor): the protection marker is written before signing.**
  - `BuiltinLinux.kt:441` writes the marker and sets `protectedProot` before `issue()`.
  - If signing fails, every later proot launch is forced through the sandbox, with no receipt and no way to clear the marker.
  - Fix: write the marker after a successful `issue()`, or provide a verified clear path.

- **A4 (minor): one failed stop aborts Stop all.**
  - In `removeService` (`BuiltinLinux.kt:744-749`), `phoneEngine.stopTracked()` can throw `engine_stop_failed`.
  - That aborts the `stopAllServices` loop (`753-761`), so the OC1 server keeps running after the user pressed Stop in the notification.
  - Fix: use try/finally for each service.

- **A5 (minor): engine start holds the global lock for a long time.**
  - `startPhoneEngine` (`BuiltinLinux.kt:425`) is `@Synchronized` and runs the boundary probe (several `waitFor(30s)` calls) plus up to 10 s of health polling.
  - The notification Stop, `status`, `startService` and `phoneEngineStatus` all block on that monitor.
  - Fix: use a separate engine lock and run the probe outside it.

- **A6 (minor): a plaintext password copy outlives the engine.**
  - `oc1-credentials.json` (`PhoneEngineNative.kt:70-81`) keeps a plaintext copy of the OC1 password (private, 0600).
  - It survives engine stop and Ubuntu uninstall.
  - Fix: delete it in `stop()` and in uninstall.

---

## (4) Dart adapter and state

- **D1 (major, verified): a refresh failure after an accepted command reads as failure.**
  - In `team_project_controller.dart:57-73` (`execute`), the POST and the `teamWorkspace()` refresh share one `try`.
  - An accepted command whose refresh then fails returns `saveFailed`. `newRequestId()` mints a new id on retry, so the retry can create a second project or quick task.
  - Fix: catch only the POST. Refresh separately and keep the accepted result.

- **D2 (major, verified construction; save path not fully traced): editing a phone-engine server erases its token.**
  - The server editor builds a new `ServerProfile` without `teamEngineAuth` (`lib/ui/screens/servers_screen.dart:2640-2657`).
  - `ProfileStore.upsert` deletes `oc.teamEngineAuth.<id>` whenever the field is empty (`profiles.dart:937-938`).
  - Editing or renaming a phone-engine profile therefore drops the engine token. Gateway, probe and chat-lease heartbeat all fail until the user re-attaches.
  - Fix: carry `teamEngineAuth` from the existing profile in the editor, or have `upsert` leave the secure key alone when the field is empty.

- **D3 (minor): a deletion during first start or attach can be undone.**
  - `connection.dart:7293-7297` calls `phoneProjectEngine.deleteProfile` only when the profile is already `phoneEngine`, already has a token, or already has a tombstone.
  - A first `start()` or `attach()` that is still in flight (`phone_project_engine.dart:399-449`) is not blocked, and can `upsert` the deleted profile back into existence.
  - Fix: also call `deleteProfile` for managed built-in URLs or when an attach is in flight.

- **D4 (minor): raw exception text reaches the queued-prompt error.**
  - `PhoneEngineException` (`engineStopFailed`, `chatTransportRetired`) is thrown from `beforeSessionDispatch` outside the error-mapping `try`.
  - The queue flush stores `error.toString()` as the queued prompt's error (`connection.dart:7700-7702`), which reads `PhoneEngineException(engineStopFailed)` (`domain/phone_project_engine.dart:8`).
  - That breaks the no-raw-errors rule.
  - Fix: map these codes to `ApiException` with plain wording.

- **D5 (minor): phone-engine profiles never raise AI Team attention in the monitor.**
  - `monitor_attention_reader.dart:26-30, 141-158` builds the phone-engine probe and gateway with an empty `profileId` and token.
  - The result is always `endpointInvalid`, silently, and a gateway is built and thrown away on every poll.
  - Fix: pass `profile.id` and `teamEngineAuth` in, or route these profiles through `phoneProjectEngine`.

- **D6 (minor): an old snapshot can overwrite a newer one.**
  - The poll stream and `execute()` both assign `snapshot` without comparing `revision` (`team_project_controller.dart:34-38, 63-66`).
  - An older poll that finishes late overwrites the newer state.
  - Fix: drop snapshots whose revision is lower than the current one.

- **D7 (minor): closed gateway clients pile up.**
  - `_gateways[id]` (`phone_project_engine.dart:377, 574-599`) is only pruned on delete or close.
  - Probe and heartbeat clients accumulate for the life of the `ConnectionController`.
  - Fix: remove each client when it closes.

- **D8 (minor): a failed deletion locks the profile out for the session.**
  - `deleteProfile` adds the id to `_deleted` before the tombstone write and native deletion (`phone_project_engine.dart:616-630`).
  - If either step fails, the profile still exists but is blocked for the rest of the session.
  - Fix: remove the id from `_deleted` on failure.

---

## Claims checked and dropped

- **"The daemon is orphaned when the app crashes":** today PDEATHSIG kills it. The claim becomes real if C1 is fixed by simply removing PDEATHSIG, which is why the C1 fix keeps a death signal via stdin EOF or a long-lived thread.
- **"`stop()` leaves agent children running":** the daemon starts no processes (`grep Command::new` finds none). Agents belong to the separately tracked OC1 service.
- **"The `oc.teamEngineDeleted.<id>` preference survives deletion":** `ProfileStore.remove` finishes with `removeScopedPreferences(id)` (`profiles.dart:1112`), which sweeps it.
