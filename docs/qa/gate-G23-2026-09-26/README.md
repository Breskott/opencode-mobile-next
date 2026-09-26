# gate-G23: golden harness (2026-09-26)

## 1. Scope

- Gate: G23, `test/golden_harness_test.dart` (STANDARDS.md §18.1 row and §18
  detail paragraph "G23 (absolute)"). Finish line: the golden harness rules are
  a test that passes on today's tree and fails on any new violation. Non-goal:
  fixing today's violations (that needs edits to other units' golden files and
  to `kit_gallery.dart`, which G4 owns).
- Files: `test/golden_harness_test.dart`, `test/golden_harness_baseline.json`,
  this folder. No `lib/` change.
- Rules enforced: TEST-7, TEST-8, TEST-9, TEST-20, ARCH-11. Also ratchets the
  tracked `**/failures/` set (TEST-12 belongs to G25; see NOT proven).
- Contract problems (PROC-20): see "Decisions and open points" below.

### What the gate checks

"Golden test files" are `test/goldens/**/*_golden_test.dart` plus every other
`test/**/*_test.dart` that calls `matchesGoldenFile`. "Harness" means any file
under `test/` that calls `matchesGoldenFile` (today 15 files in
`test/goldens/`, `kit_gallery.dart` and 4 scene tests in `test/`).

| Check (baseline key) | Rule | What fails |
|---|---|---|
| `kitGalleryDpr3` | TEST-9 | `kit_gallery.dart` does not set `devicePixelRatio = 3.0` (or sets anything else); any other file in `test/goldens/kit/` sets a ratio other than 3 |
| `androidPlatform` | ARCH-11 | a harness (and `kit_gallery.dart`) lacks `debugDefaultTargetPlatformOverride = TargetPlatform.android` (or `TargetPlatformVariant.only(TargetPlatform.android)`) |
| `regenerateHeader` | TEST-7 | the leading comment block lacks "Regenerate deliberately" and "look at every changed image before committing it" |
| `captureFonts` | TEST-8 | a golden test file never uses `loadCaptureFonts` or `loadKitGalleryFonts` |
| `arabicFont` | TEST-8 | a file rendering `Locale('ar')` loads neither `loadKitGalleryFonts` nor a `NotoSansArabic` font |
| `goldenNames` | TEST-20 | a PNG under `test/` (outside `failures/`) does not match `<module>_<page>_<state>[_ar][_text2][_<W>x<H>]_<dark\|light>.png` / `kit_<part>_<state>…`; a size segment must be a LAY-4 gallery size other than 412x915 |
| `trackedFailures` | TEST-12 (ratchet only) | `git ls-files test` lists a new path under a `failures/` directory |
| absolute test | TEST-8 | `loadCaptureFonts` (`tool/capture/fixtures.dart`, comments stripped) does not register every `*Family` constant of `AppTheme` and every `family:` in `pubspec.yaml` |

Every check except the last is a ratchet against
`test/golden_harness_baseline.json`: a violation not in the baseline fails;
fewer violations pass and print the smaller baseline to commit;
`GOLDEN_HARNESS_WRITE=1` rewrites the baseline but refuses to add entries once
the file exists. The name rule also has self-tests with good and bad names.

### Baseline counts (candidate 9220f070)

| Check | Entries |
|---|---|
| androidPlatform | 21 (every harness: none sets the Android override today) |
| arabicFont | 1 (`folder_browser_golden_test.dart`) |
| captureFonts | 7 (`team_discover_scenes`, `team_scenes`, `theme_gallery` golden tests; `kit_illustration_test`, `kit_states_scenes_test`, `servers_scenes_test`, `setup_scenes_test`) |
| goldenNames | 120 PNGs |
| kitGalleryDpr3 | 1 (`kit_gallery.dart` sets DPR 1) |
| regenerateHeader | 3 (`theme_gallery_golden_test`, `kit_illustration_test`, `servers_scenes_test`) |
| trackedFailures | 24 (`test/goldens/failures/team_agent_*`) |

### Decisions and open points

1. TEST-20 "with the size left out only for 412×915" is read strictly: a
   `_412x915` segment is itself a violation (the size is always left out for
   the default). Today's kit gallery writes `_412x915` for its scaled and
   default shots, so 14 kit PNGs are in the baseline for it (4 more, the
   `kit_sheet_{ar,text2}_1280x800_*` shots, lack a state segment). If the coordinator reads
   the rule as "may be left out", drop the `412x915` branch in
   `goldenNameProblem` and regenerate the baseline.
2. The rulebook paragraph limits the header and font checks to
   `test/goldens/**/*_golden_test.dart`; the gate also applies them to the four
   golden-comparing tests outside `test/goldens/`, since TEST-7/TEST-8 say
   "every golden test file".
3. The module segment is not checked against a module list (none is machine
   readable in the rulebook); only the shape and segment count are.
4. The TEST-20 budget (60 PNGs / 8 MB per unit) needs a base revision and is
   left to G32.
5. Untracking `test/goldens/failures/` and adding `test/**/failures/` to
   `.gitignore` (PLAN §pre-wave checklist, G25) touches shared files; this gate
   only stops the tracked set from growing. Integrator: `git rm -r --cached
   test/goldens/failures` and the `.gitignore` line, then regenerate this
   baseline.

## 2. Builds

- Branch `gate/G23`, base `9220f070` (feat/phone-setup-v2), code head: the
  gate commit. No APK.

## 3. Devices

None: tests only.

## 4. Runs

| # | Expected | Actual | Result |
|---|---|---|---|
| 1 | Gate passes on today's tree (5 tests) | `00:00 +5: All tests passed!` | PASS |
| 2 | `flutter analyze test/golden_harness_test.dart` clean | `No issues found!` | PASS |
| 3 | Planted violations fail both tests (see below) | 2 tests failed, every planted violation named | PASS |
| 4 | A stale baseline entry passes and prints the smaller baseline | `G23: violations dropped. Commit the smaller baseline …`, `All tests passed!` | PASS |
| 5 | Probes removed, tree back to the gate files only | `git status --short`: only the two gate files | PASS |

Planted for run 3 (all removed afterwards): `test/goldens/zz_g23_probe_golden_test.dart`
(no header, no fonts, no Android override, renders `Locale('ar')`),
`test/goldens/kit/zz_g23_probe_golden_test.dart` (sets DPR 1),
`test/goldens/zz_probe_dark.png`, `test/goldens/kit/kit_probe_state_412x915_dark.png`,
`test/goldens/failures/zz_probe_testImage.png` (`git add -N`), and the
`AppPhosphorDuotone` load commented out in `tool/capture/fixtures.dart`.

The first run 3 did not fail the font test: a commented-out `load(...)` still
matched. The gate now strips comments before reading `loadCaptureFonts`, and the
rerun fails as shown.

## 5. Evidence

- `fail-on-violation.txt`: the full failing output of run 3. Key lines:

```
  Actual: ['AppPhosphorDuotone']
  loadCaptureFonts (tool/capture/fixtures.dart) must register every family AppTheme or pubspec.yaml declares (TEST-8); missing: [AppPhosphorDuotone]
  New golden-harness violations (STANDARDS.md §18 G23). Fix them; the baseline only shrinks:
    kitGalleryDpr3: test/goldens/kit/zz_g23_probe_golden_test.dart
    androidPlatform: test/goldens/zz_g23_probe_golden_test.dart
    regenerateHeader: test/goldens/zz_g23_probe_golden_test.dart
    captureFonts: test/goldens/zz_g23_probe_golden_test.dart
    arabicFont: test/goldens/zz_g23_probe_golden_test.dart
    goldenNames: test/goldens/kit/kit_probe_state_412x915_dark.png (412x915 is the default: leave it out)
    goldenNames: test/goldens/zz_probe_dark.png (needs <module>_<page>_<state>)
    trackedFailures: test/goldens/failures/zz_probe_testImage.png
00:00 +3 -2: Some tests failed.
```

- Pass on today's tree:

```
00:00 +0: G23 golden-name rule (TEST-20) accepts the documented shapes
00:00 +1: G23 golden-name rule (TEST-20) rejects the rest
00:00 +2: G23 golden-name rule (TEST-20) reads the regenerate header only at the top of the file
00:00 +3: G23 loadCaptureFonts registers every AppTheme and pubspec family
00:00 +4: G23 golden harness ratchet (TEST-7, TEST-8, TEST-9, TEST-20, ARCH-11)
00:00 +5: All tests passed!
```

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 1 test/golden_harness_test.dart
tool/qa/machine_lock.sh analyze -- $F analyze test/golden_harness_test.dart
# after fixing violations:
GOLDEN_HARNESS_WRITE=1 tool/qa/machine_lock.sh test -- $F test -j 1 test/golden_harness_test.dart
```

## 7. NOT proven

- The checks are text scans: a harness that sets the Android override or DPR
  through a helper in another file is not seen (only `kit_gallery.dart`'s own
  source counts for kit galleries). The gate does not render anything.
- A golden rendered at a non-default size without a size segment
  (for example `folder_browser_compact_ar_*` at 320x640) cannot be detected
  from its name.
- TEST-12 (failures never committed) is not enforced absolutely; 24 tracked
  failure images remain until the integrator untracks them (G25).
- TEST-20's per-unit PNG/MB budget is not checked (G32).
- The full suite was not run; only this test file.

## State table

| Item | State |
|---|---|
| Gate test and baseline | implemented, verified locally, committed on `gate/G23` |
| Today's violations (baseline) | recorded, not fixed |
| Pushed / merged | no |
