# gate-G25: repository hygiene (2026-09-26)

## 1. Scope

- Unit: gate `G25` (wave 1, gate). Finish line: `test/repository_hygiene_test.dart` makes PROC-1, MOT-10, SEC-6, SEC-7, TEST-12 and TEST-18 mechanical, passes on today's tree and fails on each kind of violation. Non-goal: removing today's committed golden-failure files (not in this gate's write set) and the keystore-permission half of SEC-6 (owned by `scripts/release.sh`).
- Files changed: `test/repository_hygiene_test.dart` (extended; its seven existing tests are unchanged), `test/repository_hygiene_baseline.json` (new), this folder.
- Pages (map ids): n/a: repository gate, no UI.
- Specs followed: STANDARDS.md §18 G25 row and paragraph; rules PROC-1, MOT-10, SEC-6, SEC-7, TEST-12, TEST-18.
- Contract problems (PROC-20): one. §18 marks G25 **absolute**, but today's tree tracks 24 golden-failure artefacts under `test/goldens/failures/` (`team_agent*_{isolatedDiff,maskedDiff,masterImage,testImage}.png`). Following the gate brief, TEST-12 is a **ratchet** until they are untracked; every other G25 check is absolute. Proposed fix (needs an owner outside this gate): `git rm --cached test/goldens/failures/*`, add `failures/` to `.gitignore`, and empty the `TEST-12` list in the baseline; the test then acts as absolute. Blocks: nothing.
- Map items (EVID-11): n/a. States (STATE-20/21): n/a.

### What the gate checks (group `G25 repository hygiene`)

| Test | Rule | Kind | Check |
|---|---|---|---|
| MOT-10: flutter_animate is never a dependency or an import | MOT-10 | absolute | `pubspec.yaml` and `pubspec.lock` never contain `flutter_animate`; no `.dart` file under `lib/` or `test/` has an `import`/`export` of `package:flutter_animate/` |
| SEC-6, SEC-7: no skill packs, keystores or signing secrets and no screen recordings in docs/qa are tracked | SEC-6, SEC-7, EVID-6 | absolute | `git ls-files` lists nothing under `.claude/skills/`, no `*.jks`/`*.keystore`, no `android/key.properties`, no `docs/qa/**.{mp4,webm,mov}`; `android/.gitignore` still ignores `key.properties`, `**/*.jks`, `**/*.keystore`. The listing must have more than 100 entries so a broken git call cannot pass vacuously |
| TEST-12: golden-failure artefacts are never committed (ratchet) | TEST-12 | ratchet | every tracked path matching `(^\|/)failures/` must be in `test/repository_hygiene_baseline.json` `TEST-12`; when entries are no longer tracked the test prints the smaller list to commit |
| the pubspec version is name+build with a positive build number | (G25 paragraph) | absolute | `version:` matches `^\d+\.\d+\.\d+\+[1-9]\d*$` |
| PROC-1: the Android build targets compileSdk 37 and Java 17 | PROC-1 | absolute | `android/app/build.gradle.kts` has exactly one `compileSdk = 37`, `JavaVersion.VERSION_17` for source and target, and `JvmTarget.JVM_17` |
| PROC-1, TEST-18: the running Flutter is the pinned revision … | PROC-1, TEST-18 | absolute | the running SDK (`FLUTTER_ROOT`, else the SDK owning `flutter_tester`) has `bin/cache/flutter.version.json` `frameworkRevision` starting `91f8bd75`, and equal to `test/kit_ratchet_flutter_widgets.json` `flutterRevision` |

Baseline counts: `TEST-12`: 24 paths (all in `test/goldens/failures/`). No other baseline.

## 2. Builds

- Branch `gate/G25`, base `9220f070`, code head `c3d06d54`.
- No APK (gate units do not build).

## 3. Devices

None: tests only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `flutter analyze test/repository_hygiene_test.dart` | no issues | No issues found | PASS |
| 2 | `flutter test -j 1 test/repository_hygiene_test.dart` on today's tree | 13 pass (6 G25 + 7 existing) | 13 passed (`pass-on-today.txt`) | PASS |
| 3 | Violation round 1: staged `android/key.properties`, `android/app/g25-tmp.jks`, `docs/qa/g25-tmp.mp4`, `test/goldens/failures/g25_tmp.png`; added `test/g25_violation_tmp.dart` importing flutter_animate; pubspec `1.0.44+0`; `compileSdk = 36`; widget-names revision `00000000…`; a baseline entry that is not tracked | all 6 G25 tests fail with the rule named | 6 failed, 7 existing passed (`fail-on-violation-round-1.txt`) | PASS |
| 4 | Violation round 2: staged `.claude/skills/g25-tmp.md`; `# flutter_animate` line in `pubspec.yaml`; baseline has one untracked entry | MOT-10 and SEC-7 fail; TEST-12 passes and prints the smaller baseline | as expected (`fail-on-violation-round-2.txt`, `fail-on-violation-round-2b.txt` after the MOT-10 message was shortened) | PASS |
| 5 | Violations removed (unstaged, deleted, files restored, baseline regenerated), step 2 again | 13 pass | 13 passed | PASS |

## 5. Evidence

- `pass-on-today.txt`: step 2/5 output.
- `fail-on-violation-round-1.txt`: step 3 output. Key lines: `these files import flutter_animate (MOT-10): [test/g25_violation_tmp.dart]`; `SEC-6 no keystore (*.jks): android/app/g25-tmp.jks is tracked`; `SEC-6 no android/key.properties: android/key.properties is tracked`; `no video files under docs/qa/: docs/qa/g25-tmp.mp4 is tracked`; `TEST-12: golden-failure artefacts are committed … test/goldens/failures/g25_tmp.png`; `pubspec version "1.0.44+0" is not X.Y.Z+N with N ≥ 1`; `Expected: ['37'] Actual: ['36']`; `TEST-18: test/kit_ratchet_flutter_widgets.json was generated from Flutter 00000000… but tests run on 91f8bd75…`.
- `fail-on-violation-round-2.txt` / `-2b.txt`: `SEC-7 .claude/skills/ is never committed: .claude/skills/g25-tmp.md is tracked`; `pubspec.yaml names flutter_animate; it is banned …`; `--- G25 TEST-12 baseline shrank by 1; commit this list …` followed by the 24-path list.
- Rule evidence (PROC-31):

  | Rule | Test (`test/repository_hygiene_test.dart` + `--plain-name`) | Output |
  |---|---|---|
  | MOT-10 | "MOT-10" | round 1, round 2b |
  | SEC-6 | "SEC-6, SEC-7" | round 1 |
  | SEC-7 | "SEC-6, SEC-7" | round 2 |
  | TEST-12 | "TEST-12" | round 1 (new path fails), round 2 (shrink prints) |
  | PROC-1 | "PROC-1: the Android build" | round 1 |
  | TEST-18 | "PROC-1, TEST-18" | round 1 |

- Changed test expectations (TEST-19): none; existing tests untouched.
- Goldens changed: none. Before and after: n/a (no UI).
- Accessibility: n/a.
- Privacy and security: strengthens SEC-6/SEC-7; no credentials read or printed. The test never opens `android/key.properties` or any keystore, only checks git's listing.
- Migration: n/a.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh analyze -- $F analyze test/repository_hygiene_test.dart
tool/qa/machine_lock.sh test -- $F test -j 1 test/repository_hygiene_test.dart
# a violation, e.g.:
touch docs/qa/x.mp4 && git add -f docs/qa/x.mp4
tool/qa/machine_lock.sh test -- $F test -j 1 test/repository_hygiene_test.dart --plain-name "SEC-6"
git rm -q --cached docs/qa/x.mp4 && rm docs/qa/x.mp4
```

## 7. NOT proven

- Not run on a device or emulator (none needed).
- The "running Flutter is not the pinned revision" failure was not provoked with a real second SDK (none installed here, and the `flutter` launcher always sets `FLUTTER_ROOT` to itself); the revision-mismatch path was proven through the widget-names file instead, and the prefix check uses the same value.
- The keystore-location/permission half of SEC-6 is `scripts/release.sh`'s, not this gate's.
- TEST-12 is a ratchet, not absolute, until the 24 tracked failure files are untracked (see Contract problems).
- Only the gate's own test file was run, not the full suite.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes (TEST-12 as ratchet) | `gate/G25` |
| Enabled | Yes | runs with `flutter test` |
| Verified | tests only | this record |
| Committed | Yes | code head `c3d06d54` |
| Deployed | No | |
| Released | No | |
