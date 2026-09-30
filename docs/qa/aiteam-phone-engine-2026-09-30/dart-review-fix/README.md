# Dart review fixes

Finish line: accepted team commands survive refresh failure, late workspace reads cannot roll back state, ordinary phone-profile edits preserve private engine auth, and closed gateway clients leave controller ownership.

Non-goal: UI changes, native lifecycle/security changes, and changing the fail-closed profile-deletion policy.

## Review dispositions

- **D1:** POST errors retain the existing `saveFailed` result. A successful POST keeps its exact accepted result even if the following workspace read fails; the controller separately reports `unavailable`. A refused command retains its refusal code when the read also fails.
- **D2:** empty `teamEngineAuth` on an ordinary `ProfileStore.upsert` preserves the Keystore entry and restores it on the replacement in-memory profile. The token remains absent from profile JSON. Intentional deletion uses `clearTeamEngineAuth`, including phone-engine deletion; profile removal also retains its existing credential sweep.
- **D6:** stream updates, initial reads, and post-command reads all pass through the workspace revision fence. The engine's workspace revision is global and monotonic; project command-result revisions are separate and are not compared with it.
- **D7:** additive `PhoneEngineGateway.addCloseListener` releases profile ownership on close. Owner shutdown iterates a snapshot so close callbacks cannot invalidate its iteration. No gateway builder signature changes.
- **D8:** a failed native deletion deliberately keeps its durable tombstone. Removing the fence could revive a partly erased profile. Existing retry works, and the focused test now proves retry from a fresh controller after restart, credential erasure on success, and continued admission refusal until the outer profile-deletion sweep completes.

## Checks

Pinned Dart formatter completed for all six changed Dart files. `git diff --check` passed. No Flutter test or analyzer process was launched in this worker, preserving the coordinator's machine lock.

Coordinator focused gate:

```bash
OC_TEST_SLOTS=1 tool/qa/machine_lock.sh test -- flutter test --concurrency=1 \
  test/team_project_controller_test.dart \
  test/phone_project_engine_controller_test.dart \
  test/phone_project_engine_gateway_test.dart \
  test/profile_store_test.dart \
  test/profile_secure_storage_test.dart
```

Use the repository-pinned Flutter executable. The controller test provides the secure-storage method-channel mock; profile-store tests inject their own fake secure storage.
