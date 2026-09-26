# P0.7 backend: removing This phone keeps projects

Finish line: runtime removal preserves `/root/projects` by default, setup reuses those projects, and a small Dart API exposes measured removal choices plus explicit typed-name project deletion.

Non-goals: UI/kit/localization changes, P1.4 component removal, Termux migration, project export, signing, releases or device operation.

## Scope and feasibility

Base: `dcf05c5efbf82781bcfb97b629f5cda86ead2382`, branch `codex/p07n`, plus this worktree's scoped changes. Read: `AGENTS.md`, `STANDARDS.md` sections 2, 3, 13 and 15 only, the earlier [P0.7/P1.4 assessment](../codex-p07-p14-2026-09-27/README.md), built-in Linux/setup/terminal/folder contracts and affected tests. No `HANDOFF.md` exists in this checkout.

The earlier P0.7 blocker is addressed in source: Android can rename `<filesDir>/linux/ubuntu/root/projects` into `<filesDir>/projects` on the same app filesystem and bind it into proot as `/root/projects`. Both normal scripts/services and local terminals use `BuiltinLinux.prootCommand`. Installation preserves projects before resetting even a partial rootfs, then creates the bind mountpoint before marking Ubuntu ready. Removing the runtime preserves the external directory. Android app uninstall/clear-data still deletes all app-private projects.

Migration is an atomic whole-directory rename, with no copy, merge, content rewriting or free-space requirement for a second project copy. Location is the migration state: repeating it after a process dies between rename and mountpoint creation is safe. Empty directories are recreated as needed. If both project locations contain data, or a managed ancestor is a link/non-directory/unreadable, operations fail closed without overwriting projects. No export fallback is needed for the normal layout because preservation is feasible; this slice does not add a ZIP exporter or pretend that a conflicting/unsafe layout was migrated. Such errors need recovery/export by a later UI flow before retrying removal.

Write set:

- `lib/builtin/builtin_linux.dart`: existing channel plus documented removal/measurement API.
- `lib/builtin/builtin_folders.dart`: direct browsing of the external binding, legacy fallback before migration, and retained browsing without Ubuntu.
- `BuiltinLinux.kt`, `BuiltinProjectStorage.kt`, `MainActivity.kt`: storage migration, bind, guarded lifecycle and channel dispatch.
- `SetupRunner.kt`, `LocalTerminal.kt`: synchronize setup/terminal admission with removal using the runtime lock first. No setup protocol or terminal channel change.
- `BuiltinServerService.kt`: notification Stop waits off the main thread, since filesystem measurement/removal can hold the runtime lock.
- Dedicated tests, folder behavior tests, this QA directory and commit-message fallback.

Parent owned channel/lifecycle integration and final verification. Independent workers owned folder browsing/tests, removal API tests/source guards, and native filesystem helper/harness. Reviewers ran no tests. All machine checks were serialized by the parent. No `lib/ui/`, l10n or protected single-owner Dart files were edited.

## UI hook-up

Use `lib/builtin/builtin_linux.dart`; there is no new controller, preference or secret storage to initialize:

```dart
final linux = BuiltinLinux();
final sizes = await linux.projectStorage();
// Default confirmation: Remove OpenCode, keep my projects.
// sizes.keepProjectsFreedBytes; sizes.projectsBytes survives.
await linux.remove(); // Existing linux.uninstall() has this same safe default.

// Separate destructive choice after the person types the displayed literal:
await linux.remove(
  alsoDeleteProjects: true,
  confirmationName: typedName, // Must equal BuiltinLinux.deletionConfirmationName.
);
```

The Dart bridge dispatches the new native `removeRuntime` method, with no fallback to the old `uninstall` method. A Dart update running on an older APK therefore fails with `missing_plugin` instead of invoking its destructive uninstall. New native builds still accept legacy `uninstall` calls, now preserving by default. Ship these native changes in a full APK; a Dart-only patch cannot add the native preservation contract.

The literal typed name is **`OpenCode`** (case-sensitive; no trimming). Display it through `BuiltinLinux.deletionConfirmationName` in either locale. Dart rejects missing/wrong names before invoking native code; native independently verifies it. Do not log, persist or forward the typed value for the keep choice. The two examples are alternatives, not sequential actions.

`BuiltinProjectStorage` exposes `runtimeBytes`, `projectsBytes`, `measuredAtMilliseconds`, `keepProjectsFreedBytes` and `deleteEverythingFreedBytes`. Measurement is fresh, off the Android main thread, not the cached `status.bytesUsed`. These are logical regular-file bytes, not filesystem allocated blocks or a guarantee of exact free-space increase. Links/special files contribute zero and link targets are not traversed. Label the reclamation as an estimate based on the measured files; format bytes with the app's localized formatter. Measurements can change while the server writes, so refresh on entering confirmation and after success or failure. Unknown/inaccessible/malformed storage throws rather than returning zero. Do not enable a size-dependent confirmation with invented values.

Required confirmation copy and wiring for the later UI unit:

- Default **Remove OpenCode, keep my projects**: show `keepProjectsFreedBytes` estimated freed and `projectsBytes` retained. Runtime, installed tools, runtime logs/settings, sessions/team data outside projects, and the Ubuntu download archive are removed. All contents under `/root/projects`, including hidden files and Git data, remain. Files/link targets outside that subtree are not promised to survive.
- **Delete everything**: show `deleteEverythingFreedBytes`, explicitly include project loss, require the typed literal above, then pass `alsoDeleteProjects: true`.
- Replace the default use of `phoneServerCardRemoveBody`: its existing everything-is-deleted wording remains untouched in this backend-only unit. Localize the two choices and their survival copy in the UI unit.
- Keep local UI busy state while awaiting either action and disable competing setup/start/removal actions. Native serializes lifecycle admission, rejects removal during active setup/installation, stops services, tracked script processes and terminals, and refuses deletion if tracked processes have not stopped. Errors may follow partial runtime deletion: refresh rather than report success or assume rollback. A failed delete clears the ready marker before deleting runtime contents so damaged Ubuntu cannot stay marked installed.
- `BuiltinLinuxException.code`: `confirmation_required`, `storage_unavailable`, `removal_failed`, `missing_plugin`, `unsupported_platform`. Show localized actionable errors; messages contain no native filesystem diagnostics. Setup/migration/deletion errors are intentionally collapsed into `removal_failed`; re-read setup status and storage to choose guidance. No exception is a successful removal.
- Continue the existing built-in profile/server selection cleanup in the connection/UI owner; this unit does not edit `connection.dart`. After keep removal, setup through the existing flow mounts the retained directory before starting OpenCode. `BuiltinFolders.list('/root/projects')` and nested browsing use the same logical paths; direct browsing also works while Ubuntu is absent.

Security: no new diagnostic/state payload is persisted, so no new payload needs `KitRedact`. Project files are renamed verbatim, including user-owned source and `.env` files; redacting them would corrupt the data being preserved. No project names, contents, credentials or raw filesystem errors are added to logs. The native helper uses injected `lstat`, rejects unsafe storage roots, never follows links while measuring/deleting, and emits a fixed error without an underlying cause.

## Behavior and regression coverage

- `test/builtin_project_removal_test.dart`: preserving defaults and legacy call compatibility, old-APK fail-closed dispatch, exact confirmation, both size choices, absent/malformed/negative measurements, native failure sanitization and missing plugin failure.
- `test/builtin_linux_test.dart`: the existing bridge test now expects `removeRuntime` for `uninstall()` because the old method cannot safely accept the preservation contract on older APKs.
- `test/builtin_folders_test.dart`: existing browser behavior plus migration, retained/reinstalled browsing, virtual parents, nested Git markers, mount precedence/prefix boundaries, no stale cached rootfs, symlinks, traversal and deleted storage.
- `test/builtin_project_storage_native_test.dart`: Flutter wrapper compiling/running the production Kotlin filesystem helper using the host adapter in `test/native/builtin_project_storage_harness.kt`. Requires `kotlinc` and `java` on PATH (or `KOTLINC`/`JAVA` environment overrides); no skipped cases or Gradle invocation. Thirteen scenarios cover new setup, hidden/Git migration, empty destination, interrupted-rename recovery, keep/reinstall/delete, partial-rootfs reset, collisions, ancestor/content links, measured totals, read failures, checked deletion failures/ready-marker invalidation and invalid sizes.
- `test/builtin_project_lifecycle_guard_test.dart`: source guards against losing the bind, installer preservation, native confirmation/default, setup/terminal lock order, process stopping, regenerated proc stand-ins and background channel/notification dispatch. These guards do not replace Android runtime tests.

No failing-first Flutter baseline was obtained because Flutter cannot start in this sandbox. No Flutter behavior pass or whole-app analyzer pass is claimed.

## Verification

- **Passed:** Kotlin helper compiled with `kotlinc`; all 13 host filesystem scenarios passed with `java -jar /tmp/codex-p07n-storage-tests.jar`. [Saved output](native-tests.txt). This exercises the actual production helper, with a Java NIO no-follow inspection adapter; it does not execute Android `Os.lstat`, lifecycle dispatch or proot.
- **Passed:** seven changed Dart files formatted using the same pinned SDK's direct `bin/cache/dart-sdk/bin/dart --suppress-analytics format --language-version=3.10`. [Saved output](format-direct.txt). The unresolved `flutter_lints` include reflects missing package resolution, not a lint pass.
- **Blocked:** requested pinned `bin/dart` wrapper fails before formatting because SDK `engine.stamp`/`engine.realm` writes are read-only. [Saved output](format.txt).
- **Blocked:** final affected Flutter test selection fails before loading any test for that same sandbox SDK-cache reason. [Saved output](tests.txt).
- **Blocked:** pinned `flutter analyze` fails at the same bootstrap step. [Saved output](analyze.txt).
- **Passed:** `git diff --check`. No full suite, Gradle, APK, emulator, adb, phone or UI screenshot checks were run.

Verifier commands with a writable pinned SDK cache and resolved dependencies:

```sh
F="$HOME/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter"
"$F" pub get
"$F" test --concurrency=1 test/builtin_project_removal_test.dart test/builtin_project_storage_native_test.dart test/builtin_project_lifecycle_guard_test.dart test/builtin_folders_test.dart test/builtin_linux_test.dart
"$F" analyze
```

Coordinator acceptance still required: release APK compile check for all native integration; on-device legacy projects → keep removal → setup → old project listing/content; same with hidden/Git data and app restart; destructive wrong/correct typed name; measured choice copy; active setup rejection and terminal shutdown. The UI unit supplies localized copy, typed input, accessibility checks and screenshots. There is no device proof of the proot binding in this record.

## State

Implemented: scoped backend contract and native project preservation. Enabled: existing uninstall callers now preserve; new confirmation UI/size copy is not wired. Verified: native filesystem helper and formatting/diff only; Flutter/analyzer and Android integration remain unverified. Committed: no. `git add` could not create the worktree `index.lock` on the read-only filesystem ([output](commit-attempt.txt)); changes remain in this worktree and the requested message/trailers are in root `COMMIT_MSG.txt`. Deployed/released: no. No push attempted.
