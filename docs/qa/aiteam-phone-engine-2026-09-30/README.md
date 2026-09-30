# Phone project engine — first slice

Finish line: a phone-resident native Rust daemon persists project commands and task stages, drives planner → worker → checker sessions on one pinned OC1 server using isolated worker clones, merges checked changes into private canonical dev, and permits confirmed expected-SHA promotion only through the authenticated API and a proven filesystem boundary.

Non-goal: UI changes, OC2 execution, multi-host migration, signing, publishing, unbounded Android lifetime, or per-session CPU/IO priority claims.

Owner has deferred tests. Tests and proof harnesses are implemented for later execution; no test or device pass is claimed. Compile, analyzer and format results are recorded below. All artifacts use Storage, not /tmp.

## Ownership and frozen contracts

- Store slice owns `engine/phone/src/store.rs`, `scheduler.rs`, store tests and its QA README.
- Git slice owns `engine/phone/src/repository.rs`, git proof tests and its QA README.
- Native slice owns both halves of the builtin MethodChannel, Kotlin lifecycle/launcher, `engine/phone/src/bin/oc-engine-sandbox.rs`, boundary proof and its QA README.
- Protocol slice owns `opencode.rs`, protocol evidence/tests and its README.
- Gateway slice owns the additive domain/Dart adapter/profile wiring, deletion and its tests/README.
- Coordinator owns Cargo/package/build integration, config/HTTP/reconcile pipeline, cross-slice integration fixes and the integration README. No UI is edited. Each execution slice has its own Storage worktree and local `[skip ci]` commits.

Store interface: `Store::open(root: &Path, profile: &str) -> Result<Store, StoreError>`; `workspace() -> Result<Value, StoreError>`; `execute(&Value) -> Result<Value, StoreError>` matching `TeamProjectCommand` and `TeamCommandResult`; `events(after: i64, limit: usize) -> Result<Vec<Value>, StoreError>`; `delete_profile() -> Result<(), StoreError>`; `jobs() -> Result<Vec<Value>, StoreError>`; `update_job(id: &str, expected_stage: &str, patch: &Value) -> Result<Value, StoreError>`; `recover() -> Result<(), StoreError>`. StoreError has public `code() -> &str`, no raw SQL/path/payload exposure. State uses `oc.teamEngine.<profile>` subdirectory and transactionally persists idempotent commands, project revisions, job stages, usage, receipts and event metadata. Running stages recover as `interrupted`, never automatically resubmitted. Jobs hold task/project/repo ids, role/model, criteria, dependency ids, stage, directory, session ids and expected commits.

Repository interface: `RepositoryAuthority::new(private_root: PathBuf, worker_root: PathBuf) -> Result<Self, RepoError>`; `import_repo(repo_id: &str, source: &Path) -> Result<Value, RepoError>`; `prepare_worker(repo_id: &str, task_id: &str) -> Result<Value, RepoError>`; `collect_worker(repo_id: &str, task_id: &str, expected_dev: &str) -> Result<Value, RepoError>`; `merge_dev(repo_id: &str, task_id: &str, expected_dev: &str, expected_task: &str) -> Result<Value, RepoError>`; `promote(repo_id: &str, expected_dev: &str, expected_main: &str, confirmed: bool, request_id: &str) -> Result<Value, RepoError>`; `refs(repo_id: &str) -> Result<Value, RepoError>`. RepoError exposes only `code() -> &str`. Canonical roots must never overlap worker roots; untrusted paths/symlinks/local origins cannot reach protected state. libgit2 only, no shell git in daemon. Mutations return before/after refs; promotion is idempotent, binds exact dev/main and is crash-reconcilable. No force refs or force pushes. Worker hooks are defense in depth, not authority.

HTTP contract v1: every endpoint requires Bearer auth; loopback bind only; `GET /v1/health`, `GET /v1/workspace`, `POST /v1/commands` (TeamProjectCommand JSON), `GET /v1/events?after=<seq>&limit=<n>` (metadata array), `DELETE /v1/profile`. Health contains schemaVersion=1, engineVersion, profileId, capabilities (execution/boundary/oc1Verified/oc2) and commandActions array. Responses never contain tokens, provider credentials, SQL/native errors or raw server output. Missing proof => execution unavailable. `close()` releases app resources without stopping daemon; `deleteLocalData()` drains client writes and calls durable engine deletion. No command auto-retry after ambiguous transport failure.


## Integrated outcome and blockers

This branch contains backend groundwork and deferred acceptance harnesses. The
finish line above has **not** been demonstrated on the phone. No UI or main.dart
file changed. The additive UI contract is
[the engine handoff](../../design/aiteam-inapp-engine-2026-09-30.md).

- Native Rust/SQLite store, command replay, queue checkpoints and digest metadata
  are wired to the authenticated loopback API and profile-owned Dart adapter.
- Planner/worker/checker protocol source, isolated-clone canonical Git authority,
  serialized dev integration and confirmed expected-SHA promotion receipts are
  implemented behind unavailable execution capabilities.
- OC1's complete global chat-status prerequisite is missing. The pinned-source
  evidence is in [protocol QA](../aiteam-phone-protocol-2026-09-30/README.md).
  `global_status_unavailable` never becomes a fabricated idle observation.
- Native boundary, proot/Git compatibility and attested restart enforcement are
  unverified. Mutable config proof flags are refused. Canonical import and
  promotion remain unavailable as well as lane execution. See
  [native QA](native/README.md).
- Interrupted execution remains durable and uncertain; no replacement prompt is
  automatically sent. Full resume of every interrupted checkpoint, daily-cost
  attribution, charging telemetry and a native project test-command runner are
  not established. Unknown finite-budget/charging prerequisites pause honestly.
  OC2, manual verification/fix/conflict/merge-queue/migration verbs are not exposed.

## Executed checks (compile/analysis, no tests)

Candidate: Phase A 5191d4c5 plus the seven local decision/slice integration commits
through ca5e682f and the coordinator implementation committed with this README.
The binary manifest records its exact Rust source digest rather than claiming
that the pre-commit sourceRevision alone describes the candidate.

| Check | Result |
| --- | --- |
| Pinned Flutter 3.47.1 `pub get` | Passed; existing Arabic untranslated-message report, no dependency lock changes |
| Pinned `flutter analyze --no-pub` | Passed, no issues; initial new style diagnostics fixed without ignores |
| `cargo check --locked --all-targets` | Passed; test targets compiled, never executed |
| Rust/Dart format, `bash -n` build script | Passed |
| ARM64 Android release cross-build, NDK 28.2.13676358/API 26 | Passed for daemon, launcher and isolated probe; first bionic constant omissions fixed |
| Gradle `:app:compileReleaseKotlin`, JDK 17 | Passed; missing Java O_DIRECTORY replaced with nofollow open/fstat/fsync; existing Gradle/Kotlin warnings remain |
| ELF/hash/source-digest inspection | Three stripped ARM64 PIE executables with Android linker, staged in jniLibs and pinned manifest; does not run them |
| Git whitespace/ownership check | Recorded at commit boundary; no UI/main.dart edits |
| Rust/Flutter tests, full suite, live model task, Android boundary/lifecycle proof | **Not run: owner deferred tests** |
| APK signing/install/release, push/PR/CI | **Not performed** |

Checks used machine locks and Storage TMPDIR/CARGO_TARGET_DIR. Earlier Phase A
suite failures are not engine coverage. Cross-compilation is not a kernel denial,
a proot positive control, a provider invocation or a live end-to-end task pass.

The build script stages three ARM64 executables, SHA-256/source/toolchain manifest
and dependency notices. SourceDirty=true is intentional for this pre-commit build;
verify sourceSha256 against committed Cargo.toml/Cargo.lock/src and each executable
against the manifest. No x86/emulator artifact is provided. Generated JNI files
are part of this local backend commit; no APK was delivered.

## Deferred acceptance (when the owner resumes tests)

Use pinned Flutter and machine locks. Keep test scratch/build outputs on Storage;
run commands sequentially. Start with these focused tests, then the complete
unchanged-candidate integration gates at the agreed stable boundary:

```bash
OC_TEST_SLOTS=1 \
TMPDIR=/home/eslam/Storage/tmp/aiteam-phone-engine-build/tmp \
CARGO_TARGET_DIR=/home/eslam/Storage/tmp/aiteam-phone-engine-build/target \
OC_ENGINE_TEST_ROOT=/home/eslam/Storage/tmp/aiteam-phone-engine-tests \
tool/qa/machine_lock.sh test -- \
  cargo test --manifest-path engine/phone/Cargo.toml --locked

OC_TEST_SLOTS=1 \
TMPDIR=/home/eslam/Storage/tmp/aiteam-phone-engine-build/tmp \
tool/qa/machine_lock.sh test -- \
  /home/eslam/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter \
  test --concurrency=1 test/phone_project_engine_gateway_test.dart \
  test/phone_project_engine_controller_test.dart test/builtin_phone_engine_test.dart
```

The task_workflow Rust test is a **component fixture**: scripted session IDs/JSON,
real independent Git clone/commit/check binding/dev merge/promotion receipt,
reopen and deletion. It makes no OpenCode/model request and is not a live-session
proof. HTTP tests separately cover authentication, capability refusals and durable
deletion. Store/scheduler and Git attack tests are described in
[store QA](../aiteam-phone-store-2026-09-30/README.md) and
[Git QA](../aiteam-phone-git-2026-09-30/README.md); Dart lifecycle/deletion tests in
[gateway QA](../aiteam-phone-gateway-2026-09-30/README.md).

The ignored Linux boundary test and native runPhoneEngineBoundaryProbe() require
isolated fixtures and real kernel positive/negative controls. Follow native QA;
a successful ABI query or harness summary alone does not enable production.
Later device acceptance must also prove exact packaged hashes, cold first start,
UI closure, bounded foreground lifetime, interrupted session reconciliation,
profile deletion and confirmed expected-SHA promotion without an accessible
canonical path through legacy server/PTY/process entry points. Only after both
admission and native prerequisites are resolved can a real approved one-task
plan/session/check/dev journey establish the finish line.
