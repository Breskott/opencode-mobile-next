# Phone engine Dart gateway

> Historical worker-slice record. The runtime authority/heartbeat follow-up and
> executed integration checks supersede the unavailable/deferred conclusions
> below; see [current integrated QA](../aiteam-phone-engine-2026-09-30/README.md).


Finish line: a saved phone engine profile reconnects through authenticated loopback health to the existing TeamProjectController, polls durable workspace snapshots, and profile deletion drains app writes before native durable deletion including inactive profiles.

Non-goal: UI edits, native implementation, execution proof, provider configuration, signing, publication or test execution.

Read set: frozen engine README, decision thread, orchestration/domain/profile/deletion contracts and native BuiltinLinux bridge.
Write set: lib/orchestration/adapters/inapp/**, lib/domain/phone_project_engine.dart, lib/state/phone_project_engine.dart, lib/state/orchestration.dart, lib/state/profiles.dart, lib/state/connection.dart, focused phone_project_engine tests and this README.
Dependency: native BuiltinLinux start/status/credentials/stop/deletePhoneEngine methods. The gateway requires schema 1/profile identity health and exact advertised command actions; execution controls require proven execution, boundary and OC1 capability.
Acceptance: credentials only in Keystore; no redirected auth; malformed payloads expose stable codes; no mutation retries; closing Flutter leaves the daemon alive; deletion tombstones before drain and native cleanup.
Checks: owner deferred all test processes. Dart formatting and diff checks only; integration analyzer belongs to coordinator. Artifacts remain on Storage.

## UI hook-up contract

`connection.phoneProjectEngine.start(profileId, port: 4098, notice: localizedNotice)` starts native lifetime then attaches; `attach(profileId)` attaches an existing daemon; `probe(profileId)` refetches authenticated health. All return `PhoneEngineHealth`; `canExecute` requires execution, boundary, verified OC1 and no OC2. Never show execution enabled from native start alone. Attach persists config/auth and recreates the active existing orchestration/TeamProjectController automatically. Closing app controllers closes only HTTP clients. The real profile deletion cascade invokes durable phone-engine deletion for active and inactive profiles.

Native dependency: `BuiltinLinux.startPhoneEngine({required String profileId, int port=4098, String? notice})`, `phoneEngineCredentials(String profileId)` typed fields `baseUrl`/`bearerToken`, and `deletePhoneEngine(String profileId)`. Native deletion remains authoritative when daemon HTTP is unavailable; it must erase canonical/worker data and prevent restart resurrection.

## Verification record

Pinned Dart formatter parsed/formatted all eight changed/new Dart files. Formatting emitted missing flutter_lints package-resolution warnings because this fresh worktree has no .dart_tool package resolution; this is not analyzer evidence. `git diff --check` passed. Two focused test files were written without running tests or launching servers. No analyzer, emulator, signing, push, publish or release action was performed. Native bridge references require the native slice to be merged for the integration checkpoint.
