# Android release quality cleanup — 2026-10-15

Base: `53eea9f8e`, branch `codex/kotlin-ci-clean`.

Finish line: the requested detekt, gate integration, Android release unit-test,
and release lint commands pass with no baseline growth. This is a behavior-neutral
cleanup; no signing, deployment, publishing, push, or release was performed.

## Changes

- Named numeric bounds and colors, wrapped long expressions, and replaced wildcard imports.
- Extracted widget rendering, parsing, action settlement, overlay state, notification
  rendering, and Activity channel/permission helpers. Preserved channel names,
  intent identities, validation ordering, callbacks, defaults, and error tokens.
- Set the hidden widget todo row's orientation to `horizontal`, its existing default.
- Updated existing native source-contract tests to follow extracted owners and
  verify their Activity/service wiring.

## Counts

The untouched base reproduced 286 new weighted detekt issues. The completed
cleanup reports zero; no detekt configuration or suppression was added.

| Rule | Before | After |
| --- | ---: | ---: |
| MagicNumber | 131 | 0 |
| MaxLineLength | 87 | 0 |
| ReturnCount | 19 | 0 |
| CyclomaticComplexMethod | 14 | 0 |
| TooManyFunctions | 8 | 0 |
| LongMethod | 7 | 0 |
| LongParameterList | 5 | 0 |
| LoopWithTooManyJumpStatements | 5 | 0 |
| WildcardImport | 3 | 0 |
| ComplexCondition | 2 | 0 |
| NestedBlockDepth | 2 | 0 |
| ThrowsCount | 2 | 0 |
| LargeClass | 1 | 0 |
| **Total** | **286** | **0** |

The reviewed baseline remains byte-for-byte unchanged: **538 entries**,
SHA-256 `fbc22dc9a7eaf29a8c810cf98a4609c6d25b35741fb2ffcd6cda116ff4d9f332`.
Lint errors: **1 reported before → 0 after**. The fixed error was `Orientation`
in `widget_session_v2_list_row.xml`. Final lint also reports 195 warnings and
one hint; those are not a claim of a warning-free build.

## Verification environment

- Pinned Flutter: `~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter`.
- Temurin `17.0.20.1+1`; detekt `1.23.8`; Gradle wrapper `9.5.0`.
- Gradle runs on `the build server`, isolated directory
  `~/wt/oc_app-codex-ktclean-quality-20261015`, under `tool/qa/machine_lock.sh build --`.
- Rsync excluded `build/`, `.dart_tool/`, `.git`, `.gradle/`, `key.properties`,
  keystores, `.claude/`, `.env`, and host-specific `local.properties`.
- Temurin was downloaded into that verification directory and checked against
  its published SHA-256. No home-level package files were edited.
- Native source manifest matched locally and remotely: 219 Kotlin/Gradle/XML files.
  Manifest SHA-256 (sorted compact Python JSON mapping paths to file hashes):
  `ae0f84f53844e128480be3fc670799eab2bacb6e5feba7cfc4e78bbb9b1a816c`.

## Commands and results

Run from the worktree root, with Temurin's `JAVA_HOME` and `bin` in `PATH`:

| Command | Result |
| --- | --- |
| `tool/qa/kotlin_static_analysis.sh` | PASS; zero findings |
| `OC_DETEKT_INTEGRATION=1 python3 -m unittest tool.qa.test_kotlin_static_analysis` | PASS; 7 tests |
| `tool/qa/machine_lock.sh build -- "$FLUTTER" build apk --release --config-only` | PASS; pinned Flutter, server copy |
| `tool/qa/machine_lock.sh build -- ./android/gradlew -p android :app:testReleaseUnitTest --no-daemon` | PASS; 456 tests in 29 suites, zero failures/errors/skips, 8m 22s |
| `tool/qa/machine_lock.sh build -- ./android/gradlew -p android :app:lintRelease --no-daemon` | PASS; zero errors, 4m 19s |
| Pinned Dart `format --output=none --set-exit-if-changed --language-version=3.10` on all 9 changed Dart files | PASS |
| `tool/qa/check_commits.sh --message-file build/ktclean-evidence/commit-message.txt --staged-format` | PASS |
| `git diff --cached --check` | PASS |

`FLUTTER` above denotes the pinned absolute executable, not another SDK on PATH.
Gradle completed release Kotlin and Java compilation; no signing or APK delivery
was needed for these commands.

Additional affected Dart checks (serial, pinned Flutter, same server build lock):

```bash
flutter test --no-pub --concurrency=1 \
  test/shared_storage_path_test.dart \
  test/session_link_native_contract_test.dart \
  test/session_address_link_native_test.dart \
  test/launch_shortcut_native_contract_test.dart \
  test/builtin_project_lifecycle_guard_test.dart \
  test/launch_surfaces_native_contract_test.dart \
  test/share_intent_native_contract_test.dart \
  test/voice_model_manifest_test.dart \
  test/release_blockers_test.dart \
  test/native_notification_copy_test.dart \
  test/background_live_test.dart
```

Initial result: 108 passed; the standalone Kotlin harness failed because
`kotlinc` was absent from the server PATH. Kotlin 2.3.20 was copied into the
isolated verification directory (no package installation or home package edit).
The unchanged `session_address_link_native_test.dart` then passed both tests
with that compiler and Temurin on PATH (11 seconds). Across the original batch
and this focused rerun, all **109 distinct tests** passed on the same source
candidate. No source edits were needed after the environment-only failure.

Local untracked raw logs and source manifest: `build/ktclean-evidence/`.
The full Flutter suite and device/runtime qualification are outside this job.

Source/test patch SHA-256 against the base (excluding this note):
`a18805920b50830645d24e401ebcad403e5be77270a8851f8ac0568cde268555`.

Raw log SHA-256 identifiers:

```text
868d5ce48922e366f91e984fa40445cec66f5385d2b1ef83f59f0fafb5d4631d  final-detekt.log
c0397e5a1c519691ffa6a03cfd5da485d5cfeb9f8e6a46d16b76d2e291a2772a  detekt-integration.log
c4ca43da68f061c55f8ede766316c42ea26f1f90f947643474451fc46ead3ca8  config-only.log
e136780015a269beaad9d67aafa5002c6743c6c6a1ff39d4af878fcb283a0ec9  android-unit.log
dc58868cdcf51196d67c7b8fcd2548b172801623a7227ee987de535923e16c37  android-lint.log
3550db5ad6a0f6c0d98f00e8324b81cca25bbb0c6815a52bd689b0602a651234  dart-guards.log
4d484d166b0d7cdbde43dc7dc0acd57d72baa564680e0f6b57080cd346da9686  dart-harness-rerun.log
```
