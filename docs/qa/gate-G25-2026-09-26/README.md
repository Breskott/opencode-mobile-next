# gate-G25: repository hygiene (2026-09-26)

## 1. Scope

- Unit: gate `G25` (wave 1, gate). Finish line: `test/repository_hygiene_test.dart` makes PROC-1, MOT-10, SEC-6, SEC-7, TEST-12 and TEST-18 mechanical, passes on today's tree and fails on each kind of violation. Non-goal: removing today's committed golden-failure files (not in this gate's write set) and the keystore-permission half of SEC-6 (owned by `scripts/release.sh`).
- Files changed: `test/repository_hygiene_test.dart` (extended; its seven existing tests are unchanged), `test/repository_hygiene_baseline.json` (new), this folder.
- Pages (map ids): n/a: repository gate, no UI.
- Specs followed: STANDARDS.md §18 G25 row and paragraph; rules PROC-1, MOT-10, SEC-6, SEC-7, TEST-12, TEST-18.
- Map items (EVID-11): n/a. States (STATE-20/21): n/a.

### Contract problems (PROC-20): two, both need a coordinator decision before merge

1. **TEST-12 is a ratchet, §18 says absolute.** Today's tree tracks 24 golden-failure artefacts under `test/goldens/failures/` (`team_agent*_{isolatedDiff,maskedDiff,masterImage,testImage}.png`). Untracking them and editing the shared `.gitignore` are outside this gate's write set, so TEST-12 is a hardened ratchet (below). **Preferred fix (coordinator, one commit):** `git rm --cached test/goldens/failures/*`, add `failures/` to `.gitignore`, empty `TEST-12` in `test/repository_hygiene_baseline.json` and set `_test12Ceiling = 0`. The test then behaves as absolute. The commit has to do all of these together: untracking the files without emptying the list fails the stale-entry check, by design. Blocks: nothing.
2. **CI cannot run the pinned Shorebird Flutter.** Every workflow that runs the suite (`android-quality.yml` through `tool/qa/run_serial_tests.py`, `desktop-linux.yml`, `ios-quality.yml`, plus `desktop-windows.yml`, `android-release.yml` and `sdk-regenerate.yml`) installs **upstream** Flutter `3.47.2` with `subosito/flutter-action` (`desktop-linux.yml`: "Shorebird's fork is not installable here, so CI uses upstream stable"). Upstream's `frameworkRevision` can never start with `91f8bd75` and can never equal `kit_ratchet_flutter_widgets.json`'s `flutterRevision`, so an unconditional revision check turns every push/PR suite run red. Options: (1) move CI onto the Shorebird Flutter; (2) skip the revision checks on CI and assert the upstream version the workflows pin instead; (3) tag the check local-only and exclude the tag in CI.
   - **Provisionally built: option 2**, because it keeps CI green without touching workflow files (not in this gate's write set) and still checks something on CI. When `GITHUB_ACTIONS=true` or `CI=true`, the "running Flutter is the pinned revision" test is **skipped with a stated reason**. A new test, "every CI workflow pins the same Flutter version, and CI runs it", always checks that all tracked workflows' `flutter-version:` values (with `${{ env.X }}` resolved) are one version, and on CI also checks that the running `frameworkVersion` equals it. **The coordinator should confirm this or pick option 1 or 3.** Option 3 would need a `dart_test.yaml` tag and a workflow edit, both shared files.
   - Found while doing this: the pinned Shorebird SDK's `bin/cache/flutter.version.json` reports `frameworkVersion` **3.47.1** (AGENTS.md agrees), while the workflows pin **3.47.2** and `desktop-linux.yml` claims the local SDK "reports Flutter 3.47.2". CONTRIBUTING.md also says 3.47.2, and an existing test in this file asserts that. So local and CI run different framework versions, not just different forks. This gate does not fix the docs (shared files). It is recorded here for the coordinator.

### What the gate checks (group `G25 repository hygiene`)

| Test | Rule | Kind | Check |
|---|---|---|---|
| MOT-10: flutter_animate is never a dependency or an import | MOT-10 | absolute | every **tracked** `pubspec.yaml`/`pubspec.lock` (root and `packages/opencode_sdk/`) never contains `flutter_animate`; every **tracked** `.dart` file (lib, test, tool, packages, …) never contains `package:flutter_animate/` anywhere. That covers plain, multi-line and conditional (`if (dart.library.io) '…'`) directives. |
| SEC-6, SEC-7: no skill packs, keystores or signing secrets and no screen recordings in docs/qa are tracked | SEC-6, SEC-7, EVID-6 | absolute | `git ls-files` lists nothing under `.claude/skills/`, no `*.jks`/`*.keystore`, no `android/key.properties`, no `docs/qa/**.{mp4,webm,mov}`; `android/.gitignore` still ignores `key.properties`, `**/*.jks`, `**/*.keystore`. The listing must have more than 100 entries so a broken git call cannot pass vacuously |
| TEST-12: golden-failure artefacts are never committed (ratchet) | TEST-12 | ratchet | (a) the baseline lists at most `_test12Ceiling` = 24 paths, a constant in the test that edits may only lower, so adding lines to the JSON cannot widen the allowance; (b) no duplicate entries; (c) every tracked path matching `(^\|/)failures/` is listed; (d) **every listed path is still tracked**, so a stale entry fails, and the failure message prints the smaller list to commit and the ceiling to lower to |
| the pubspec version is name+build with a positive build number | (G25 paragraph) | absolute | `version:` matches `^\d+\.\d+\.\d+\+[1-9]\d*$` |
| PROC-1: the Android build targets compileSdk 37 and Java 17 | PROC-1 | absolute | Comments (`//`, `/* */`) are stripped first. `android/app/build.gradle.kts` has exactly one `compileSdk = 37`, `sourceCompatibility`/`targetCompatibility = JavaVersion.VERSION_17` and `jvmTarget = …JvmTarget.JVM_17`. No tracked `android/**.{kts,gradle}` has a `JavaVersion.VERSION_*`, `JvmTarget.JVM_*`, `jvmTarget = "…"`, `jvmToolchain(N)` or `JavaLanguageVersion.of(N)` other than 17. No tracked `android/**.properties` sets `org.gradle.java.home` to a path without `17` |
| PROC-1, TEST-18: the running Flutter is the pinned revision … | PROC-1, TEST-18 | absolute locally; **skipped on CI** (contract problem 2) | the running SDK (`FLUTTER_ROOT`, else the SDK owning `flutter_tester`) has `bin/cache/flutter.version.json` `frameworkRevision` starting `91f8bd75`, and equal to `test/kit_ratchet_flutter_widgets.json` `flutterRevision` |
| PROC-1: every CI workflow pins the same Flutter version, and CI runs it | PROC-1 | absolute | all tracked `.github/workflows/*.yml` `flutter-version:` values resolve to exactly one version (today `3.47.2` in 6 workflows); on CI the running `frameworkVersion` must equal it |

Baseline counts: `TEST-12`: 24 paths (all in `test/goldens/failures/`), ceiling constant 24. No other baseline.

## 2. Builds

- Branch `gate/G25`, base `9220f070`. First build `c3d06d54`; this record covers the review-fix commit on top of `74845669`.
- No APK (gate units do not build).

## 3. Devices

None: tests only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `flutter analyze test/repository_hygiene_test.dart` | no issues | No issues found | PASS |
| 2 | `flutter test -j 1 test/repository_hygiene_test.dart` on today's tree | 14 pass (7 G25 + 7 existing) | 14 passed (`pass-on-today.txt`) | PASS |
| 3 | Round 1 (first build): staged `android/key.properties`, `android/app/g25-tmp.jks`, `docs/qa/g25-tmp.mp4`, `test/goldens/failures/g25_tmp.png`; `test/g25_violation_tmp.dart` importing flutter_animate; pubspec `1.0.44+0`; `compileSdk = 36`; widget-names revision `00000000…` | each G25 test fails with its rule named | as expected (`fail-on-violation-round-1.txt`) | PASS |
| 4 | Round 2 (first build): staged `.claude/skills/g25-tmp.md`; `# flutter_animate` in `pubspec.yaml` | MOT-10 and SEC-7 fail | as expected (`fail-on-violation-round-2.txt`, `-2b.txt`). The TEST-12 "prints and passes" behaviour shown there has since been **replaced**, see round 3 | PASS |
| 5 | Round 3 (review fixes): tracked `tool/g25_violation_tmp.dart` with a **conditional** import of flutter_animate; `# flutter_animate` in `packages/opencode_sdk/pubspec.yaml`; `git rm --cached` one listed failure file (stale entry); `sourceCompatibility` line **commented out**; `ios-quality.yml` pinned to `3.47.9` | MOT-10, TEST-12, Java and CI-pin tests fail | 4 failed: MOT-10 names both files; TEST-12 `the baseline shrank by 1; a stale entry would let that path be committed again … lower _test12Ceiling to 23`; `lost "sourceCompatibility = JavaVersion.VERSION_17"`; `the workflows install different Flutter versions: {3.47.2: [...], 3.47.9: [.github/workflows/ios-quality.yml]}` (`fail-on-violation-round-3.txt`) | PASS |
| 6 | Round 3b: sourceCompatibility restored; still `val g25Tmp = JavaVersion.VERSION_11` in `android/build.gradle.kts` and `org.gradle.java.home=/usr/lib/jvm/java-21-openjdk` in `android/gradle.properties`; pin regex fixed to resolve `${{ env.FLUTTER_VERSION }}` | Java check names both files; the pin list now includes desktop-linux and desktop-windows | as expected (`fail-on-violation-round-3b.txt`) | PASS |
| 7 | Round 4: a 25th baseline entry, with the file tracked; run with `GITHUB_ACTIONS=true` | TEST-12 fails on the ceiling; the revision test is skipped with its reason; the CI pin test fails because the local SDK is 3.47.1, not 3.47.2 | `lists 25 paths but the ratchet ceiling is 24`; `Skip: PROC-1 revision pin is local-only …`; `this CI run uses Flutter 3.47.1 but the workflows pin 3.47.2` (`fail-on-violation-round-4.txt`) | PASS |
| 8 | All violations removed (unstaged, deleted, files restored); steps 1–2 again | clean, 14 pass | clean, 14 passed | PASS |

## 5. Evidence

- `pass-on-today.txt`: step 8 output.
- `fail-on-violation-round-{1,2,2b}.txt`: the first build's proofs (SEC-6, SEC-7, video, pubspec version, compileSdk, TEST-18 mismatch, TEST-12 new path).
- `fail-on-violation-round-{3,3b,4}.txt`: the review fixes' proofs, quoted in the table above.
- Rule evidence (PROC-31):

  | Rule | Test (`test/repository_hygiene_test.dart` + `--plain-name`) | Output |
  |---|---|---|
  | MOT-10 | "MOT-10" | rounds 1, 2b, 3 |
  | SEC-6 | "SEC-6, SEC-7" | round 1 |
  | SEC-7 | "SEC-6, SEC-7" | round 2 |
  | TEST-12 | "TEST-12" | round 1 (new path), round 3 (stale entry), round 4 (ceiling) |
  | PROC-1 | "PROC-1: the Android build", "PROC-1: every CI workflow" | rounds 1, 3, 3b, 4 |
  | TEST-18 | "PROC-1, TEST-18" | round 1 |

- Changed test expectations (TEST-19): none; the existing tests are untouched.
- Goldens changed: none. Before and after: n/a (no UI).
- Accessibility: n/a.
- Privacy and security: strengthens SEC-6/SEC-7; no credentials read or printed. The test never opens `android/key.properties` or any keystore, only checks git's listing.
- Migration: n/a.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh analyze -- $F analyze test/repository_hygiene_test.dart
tool/qa/machine_lock.sh test -- $F test -j 1 test/repository_hygiene_test.dart
# CI mode (the revision test skips; the pin test fails locally because 3.47.1 != 3.47.2):
GITHUB_ACTIONS=true tool/qa/machine_lock.sh test -- $F test -j 1 test/repository_hygiene_test.dart --plain-name "G25"
# a violation, e.g.:
touch docs/qa/x.mp4 && git add -f docs/qa/x.mp4
tool/qa/machine_lock.sh test -- $F test -j 1 test/repository_hygiene_test.dart --plain-name "SEC-6"
git rm -q --cached docs/qa/x.mp4 && rm docs/qa/x.mp4
```

## 7. NOT proven

- The CI path has not run on a real runner, because CI runs need an explicit request. Round 4 simulated it with `GITHUB_ACTIONS=true` on the local SDK: the skip works and the version check fires. That upstream 3.47.2 passes it is inferred from the workflow pins, not observed.
- The "running Flutter is not the pinned revision" failure was not provoked with a real second SDK (none installed here, and the `flutter` launcher always sets `FLUTTER_ROOT` to itself). The revision-mismatch path was proven through the widget-names file instead, and the prefix check uses the same value.
- The Java check is a pattern scan. It does not evaluate Gradle, so a Java version chosen by an unusual construct (a variable, a convention plugin outside `android/`) is not seen.
- The keystore-location/permission half of SEC-6 belongs to `scripts/release.sh`, not this gate.
- TEST-12 stays a ratchet, not absolute, until the coordinator untracks the 24 files (contract problem 1).
- Only the gate's own test file was run, not the full suite.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes (TEST-12 as a hardened ratchet; revision pin local-only pending coordinator) | `gate/G25` |
| Enabled | Yes | runs with `flutter test` |
| Verified | tests only | this record |
| Committed | Yes | `gate/G25` head |
| Deployed | No | |
| Released | No | |
