# gate-G23: golden harness (2026-09-26)

## 1. Scope

- Gate: G23, `test/golden_harness_test.dart` (STANDARDS.md §18.1 row and §18
  detail paragraph "G23 (absolute)"). Finish line: the golden harness rules are
  a test that passes on today's tree, is absolute for the kit galleries, and
  fails on any new violation anywhere. Non-goal: fixing today's screen-golden
  violations outside `test/goldens/kit/` (those files and their goldens belong
  to other units, PROC-10).
- Files:
  - gate: `test/golden_harness_test.dart`, `test/golden_harness_baseline.json`,
    this folder;
  - kit gallery prerequisite (review finding 1 and 3, commits `8f3fdcee` and
    `7dd5efa3`): `test/goldens/kit/kit_gallery.dart`,
    `test/goldens/kit/kit_sheet_golden_test.dart`,
    `test/goldens/kit/kit_confirm_sheet_golden_test.dart`, 18 kit PNGs renamed.
    `kit_gallery.dart` is the **G5** file (§18.1 row G5), not G4's as the first
    record said. See "Merging with G5" below.
  - No `lib/` change.
- Rules enforced: TEST-7, TEST-8, TEST-9, TEST-20, ARCH-11. Also ratchets the
  tracked `**/failures/` set (TEST-12 belongs to G25; see NOT proven).

### What the gate checks

"Golden test files" are `test/goldens/**/*_golden_test.dart` plus every other
`test/**/*_test.dart` that calls `matchesGoldenFile`. "Harness" means any file
under `test/` that calls `matchesGoldenFile` (today 15 files in
`test/goldens/`, `kit_gallery.dart` and 4 scene tests in `test/`). Every scan
reads the source with comments removed by a string-aware scanner (`//` lines
and nested `/* */` blocks, not inside plain, raw, triple-quoted or
interpolated strings), so a commented-out override or font load does not count.

| Check (baseline key) | Rule | What fails |
|---|---|---|
| `kitGalleryDpr3` | TEST-9 | `kit_gallery.dart` does not set `devicePixelRatio = 3.0` (or sets anything else); another file in `test/goldens/kit/` that calls `matchesGoldenFile` itself sets a ratio other than 3 (a file that only calls `kitGalleryShot` gets 3 from it; G5's pure widget self-test may pump at any ratio) |
| `androidPlatform` | ARCH-11 | a harness (and `kit_gallery.dart`) lacks `debugDefaultTargetPlatformOverride = TargetPlatform.android` (or `TargetPlatformVariant.only(TargetPlatform.android)`) |
| `regenerateHeader` | TEST-7 | the leading comment block lacks "Regenerate deliberately" and "look at every changed image before committing it" |
| `captureFonts` | TEST-8 | a golden test file never calls `loadCaptureFonts` or `loadKitGalleryFonts` |
| `arabicFont` | TEST-8 | a file rendering `Locale('ar')` does not load the Arabic families (`loadKitGalleryFonts`, or a `FontLoader('Noto Sans Arabic')`), **or** does not render through a theme that falls back to them (`AppTheme.forLocale(` or `kitGalleryShot(`) |
| `goldenNames` | TEST-20 | a PNG under `test/` (outside `failures/`) does not match `<module>_<page>_<state>[_ar][_text2][_<W>x<H>]_<dark\|light>.png` / `kit_<part>_<state>…`; a size segment must be a LAY-4 gallery size other than 412x915 |
| `trackedFailures` | TEST-12 (ratchet only) | `git ls-files test` lists a new path under a `failures/` directory |
| font test (absolute) | TEST-8 | `loadCaptureFonts` does not register every `*Family` constant of `AppTheme` and every pubspec `family:`; or `loadKitGalleryFonts` (with `loadCaptureFonts`) does not register every `fontFamily:` / `fontFamilyFallback:` literal in `lib/ui/app_theme.dart` (today `sans-serif`, `Noto Sans Arabic`), less `arabicFallbackAllowlist` (`Noto Naskh Arabic`, `Arial`, each with its reason); a stale allowlist entry fails too |
| baseline test (absolute) | PROC-13, KIT-4, KIT-44 | the baseline holds any `test/goldens/kit/` entry or an unknown key; any commit that touched it added an entry or key against a parent (unless its body has `ratchet-tighten: G23 <check>`, and then only for that check); the file on disk has an entry HEAD lacks; the file was added more than once |

**Absolute:** everything under `test/goldens/kit/` (the kit gallery frame,
every kit part gallery, every kit PNG), the font test and the baseline test.
A kit entry in the baseline is ignored by the ratchet and fails the baseline
test, so a new kit part gallery at DPR 1, without the Android override or with
a `_412x915` name fails however the baseline is edited.

**Ratchet (outside `test/goldens/kit/`):** a violation not in
`test/golden_harness_baseline.json` fails; fewer violations pass and print the
smaller baseline to commit; `GOLDEN_HARNESS_WRITE=1` rewrites the baseline but
refuses to add entries once the file exists. The baseline guards itself
through git history (above). The name rule and the scanner have self-tests.

### Baseline counts (candidate 7dd5efa3)

| Check | Entries | Before the review fixes |
|---|---|---|
| androidPlatform | 20 (every screen harness; none sets the Android override today) | 21 |
| arabicFont | 1 (`folder_browser_golden_test.dart`) | 1 |
| captureFonts | 7 (`team_discover_scenes`, `team_scenes`, `theme_gallery` golden tests; `kit_illustration_test`, `kit_states_scenes_test`, `servers_scenes_test`, `setup_scenes_test`) | 7 |
| goldenNames | 102 PNGs (screen goldens only) | 120 |
| kitGalleryDpr3 | 0 | 1 |
| regenerateHeader | 3 (`theme_gallery_golden_test`, `kit_illustration_test`, `servers_scenes_test`) | 3 |
| trackedFailures | 24 (`test/goldens/failures/team_agent_*`) | 24 |

## 2. Review findings (2026-09-26) and what was done

1. **Kit gallery exempt from DPR and platform: accepted, fixed here.**
   `kitGalleryShot` sets `physicalSize = size * 3.0`, `devicePixelRatio = 3.0`
   and `debugDefaultTargetPlatformOverride = TargetPlatform.android`, cleared in
   a `finally` (flutter_test checks foundation debug variables before
   tear-downs run, so `addTearDown` is too late; the `finally` also covers a
   caller that catches a failed shot, which G5's self-tests do). The kit
   entries left the baseline and `test/goldens/kit/` is now absolute. The
   first record's "kit_gallery.dart, which G4 owns" was wrong: §18.1 gives it
   to G5.
   Found while fixing: all 58 kit PNGs are **byte-identical** at DPR 3 and as
   Android. `matchesGoldenFile` captures the layer at pixel ratio 1.0, so the
   PNG is always logical size, and `captureTheme` already set `platform:
   TargetPlatform.android`. DPR 3 only changes pixel snapping during layout,
   which these parts do not show. If TEST-9 means 3x images (VL §7), the
   gallery needs its own capture at `pixelRatio: 3` (as `tool/capture` does);
   that is a coordinator decision, not something this gate can assert.
2. **Baseline could grow by hand: accepted, fixed.** See the baseline test
   row above; run B in `fail-on-violation.txt` shows a committed growth
   failing and the same commit with `ratchet-tighten: G23 androidPlatform`
   passing. Adding the file to the PROC-13 and G31 lists in STANDARDS.md is
   a rulebook edit left to the integrator (text in §8).
3. **Name check vs the kit helper: accepted, fixed.** `kitGalleryName(shot,
   size, {light, ar, text2})` in `kit_gallery.dart` builds
   `kit_<part>_<state>[_ar][_text2][_<W>x<H>]_<mode>` and leaves out 412x915;
   it rejects a `shot` that is not `kit_<part>_<state>`. Both kit golden tests
   use it. 18 PNGs were renamed (14 lost `_412x915`, the 4
   `kit_sheet_{ar,text2}_1280x800_*` gained the `default` state; the 412x915
   ar/text2 sheet shots did both); their bytes did not change.
4. **Font check a weaker proxy: accepted, fixed.** The font test now reads
   the `fontFamily:` and `fontFamilyFallback:` literals of `app_theme.dart`.
   `loadKitGalleryFonts` registers Noto Sans Arabic also as
   `'Noto Sans Arabic'` and Roboto as `'sans-serif'` (what Android maps it
   to); `Noto Naskh Arabic` and `Arial` are on a reasoned allowlist. The
   Arabic check also requires `AppTheme.forLocale(` or `kitGalleryShot(`.
   What stays a proxy is in NOT proven.
5. **Minor items: accepted.** Block comments are stripped (string-aware);
   the scan asserts all 7 keys; the ownership sentence is corrected; the
   §18.1 status and rule rows are left to the integrator with exact text
   (§8), because no gate branch edits the shared rulebook.

Rejected: none.

## 3. Merging with G5

`gate/G5` (`c4e4f1ae`) rewrote `kitGalleryShot` (two-theme loop, semantics
handle, name check). `git merge` of `gate/G23` and `gate/G5` conflicts in one
hunk of `kit_gallery.dart`. Resolution: take G5's side, then

- replace `tester.view.physicalSize = size;` / `devicePixelRatio = 1;` with
  the DPR 3 pair and its comment;
- set `debugDefaultTargetPlatformOverride = TargetPlatform.android;` just
  before G5's `try {`;
- add `debugDefaultTargetPlatformOverride = null;` first in G5's `finally`.

`kit-gallery-on-G5.diff` is exactly that resolution against `gate/G5`. On a
scratch merge with it, `flutter test test/golden_harness_test.dart
test/goldens/kit/` passed: `00:20 +81: All tests passed!` (G23, G5's
self-tests and baseline, both kit galleries). G4 (uncommitted in its worktree)
merges cleanly textually, but see §8 for its `_ar_` needle.

## 4. Builds

- Branch `gate/G23`, base `9220f070` (feat/phone-setup-v2). Commits:
  `67c99f05` (gate), `8f3fdcee` (kit gallery prerequisite), `1de99fcb` (review
  fixes), `7dd5efa3` (override in `finally`, DPR check scope), then this
  record. No APK.

## 5. Devices

None: tests only.

## 6. Runs

| # | Expected | Actual | Result |
|---|---|---|---|
| 1 | Kit galleries regenerate at DPR 3 as Android (`--update-goldens`) | `00:12 +58: All tests passed!`; 58 PNGs byte-identical to the old ones (18 renamed) | PASS |
| 2 | Gate passes on the candidate (8 tests) | `00:00 +8: All tests passed!` | PASS |
| 3 | Gate plus both kit galleries (compare mode) | `00:18 +66: All tests passed!` | PASS |
| 4 | `flutter analyze test/golden_harness_test.dart test/goldens/kit` | `No issues found!` | PASS |
| 5 | Run A: planted violations fail all three rule tests | 3 tests failed, every planted violation named | PASS |
| 6 | Run B1: a commit growing the baseline fails | `2ed47bfa added androidPlatform: …` | PASS |
| 7 | Run B2: the same commit with `ratchet-tighten: G23 androidPlatform` | `All tests passed!` | PASS |
| 8 | Scratch merge with `gate/G5`, resolution as in §3 | `00:20 +81: All tests passed!` | PASS |
| 9 | Probes removed | `git status --short`: clean | PASS |

## 7. Evidence

- `fail-on-violation.txt`: runs A and B in full. Key lines of run A:

```
  loadKitGalleryFonts (test/goldens/kit/kit_gallery.dart) does not register the AppTheme literal families [Noto Sans Arabic]
  'absolute, never baselined: androidPlatform: test/goldens/kit/kit_gallery.dart',
  'uncommitted edit added androidPlatform: test/goldens/zz_probe_golden_test.dart',
  New golden-harness violations (STANDARDS.md §18 G23). Fix them; the baseline only shrinks, and nothing under test/goldens/kit/ is ever baselined:
    kitGalleryDpr3: test/goldens/kit/kit_gallery.dart
    androidPlatform: test/goldens/kit/kit_gallery.dart
    regenerateHeader: test/goldens/zz_probe_golden_test.dart
    arabicFont: test/goldens/zz_probe_golden_test.dart
    goldenNames: test/goldens/kit/kit_probe_state_412x915_dark.png (412x915 is the default: leave it out)
00:00 +5 -3: Some tests failed.
```

  The `androidPlatform: kit_gallery.dart` line is the override commented out
  as `/* … */`, which the first gate version accepted.

- Pass on the candidate:

```
00:00 +0: G23 golden-name rule (TEST-20) accepts the documented shapes
00:00 +1: G23 golden-name rule (TEST-20) rejects the rest
00:00 +2: G23 golden-name rule (TEST-20) reads the regenerate header only at the top of the file
00:00 +3: G23 scanner strips line and block comments, not strings
00:00 +4: G23 scanner baseline growth honours ratchet-tighten only for its check
00:00 +5: G23 font loaders register every family AppTheme and pubspec name (TEST-8)
00:00 +6: G23 baseline only shrinks and never holds kit gallery entries
00:00 +7: G23 golden harness ratchet (TEST-7, TEST-8, TEST-9, TEST-20, ARCH-11)
00:00 +8: All tests passed!
```

- `kit-gallery-on-G5.diff`: the tested merge resolution with G5.

## 8. For the integrator and the coordinator

1. **Coordinator, in writing:** §18 calls G23 absolute. It is absolute for
   `test/goldens/kit/` and for fonts; for screen goldens it is a ratchet,
   because 20 screen harnesses lack the Android override, 102 screen PNGs
   break TEST-20, and so on, and fixing them means editing other units' golden
   tests and regenerating their goldens (PROC-10). Accept the ratchet here,
   or schedule those fixes as a W1 prerequisite.
2. **Coordinator:** TEST-9's DPR 3 does not change `matchesGoldenFile`
   output (§2 item 1). Decide whether gallery PNGs must be 3x images.
3. **G4:** its gallery check looks for the text `_ar_` in
   `<snake>_golden_test.dart`. Galleries that use `kitGalleryName(…, ar:
   true)` no longer contain it, so G4 should also accept `ar: true` (both kit
   golden tests use it now).
4. **Merge G5 and G23** with the §3 resolution.
5. **STANDARDS.md edits** (a shared rulebook; this branch does not touch it):
   - §18.1 row G23: status `missing` → `exists`.
   - Rule rows: ARCH-11, TEST-7 and TEST-8 `missing: G23` →
     `` `test/golden_harness_test.dart` (G23) ``; TEST-9 `missing: G4, G23` →
     `` `test/golden_harness_test.dart` (G23); missing: G4 ``; TEST-20
     `missing: G23, G32` → `` `test/golden_harness_test.dart` (G23); missing:
     G32 ``.
   - PROC-13 **Baselines** list: add `test/golden_harness_baseline.json`
     ("lower only the entries for files you changed …" applies unchanged).
   - G31 detail: add "`test/golden_harness_baseline.json` gains no entry or
     key" next to the G2/G7/… list.
6. **Failures folder:** `git rm -r --cached test/goldens/failures` and a
   `test/**/failures/` line in `.gitignore` (G25), then rerun this gate with
   `GOLDEN_HARNESS_WRITE=1` to drop the 24 `trackedFailures` entries.

## 9. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 1 test/golden_harness_test.dart test/goldens/kit/
tool/qa/machine_lock.sh analyze -- $F analyze test/golden_harness_test.dart test/goldens/kit
# after fixing violations:
GOLDEN_HARNESS_WRITE=1 tool/qa/machine_lock.sh test -- $F test -j 1 test/golden_harness_test.dart
```

## 10. NOT proven

- The checks are text scans. A harness that sets the Android override or DPR
  through a helper in another file is not seen (only `kit_gallery.dart`'s own
  source counts for kit galleries). The gate does not render anything.
- The Arabic check proves that the file loads the Arabic families and names a
  theme that falls back to them (`AppTheme.forLocale` or `kitGalleryShot`),
  not that every Arabic `Text` in the render uses that theme; a widget with its
  own `TextStyle(fontFamily: …)` outside the fallback is not seen.
- `loadCaptureFonts` alone still does not register the Arabic families; a
  screen rendering Arabic must call `loadKitGalleryFonts` (the check enforces
  it). `tool/capture/fixtures.dart` was not changed.
- `'sans-serif'` is registered as Roboto because that is Android's mapping;
  another device mapping is not modelled. `Noto Naskh Arabic` and `Arial` are
  never registered (allowlist).
- DPR 3 is asserted in the source; the golden PNGs are captured at pixel
  ratio 1 (§2 item 1).
- A golden rendered at a non-default size without a size segment cannot be
  detected from its name.
- The baseline history check trusts git: a rewritten history (the adding
  commit amended) or an exported tree without `.git` is not checked (the test
  prints that it skipped). `ratchet-tighten:` is trusted as written; who wrote
  it (KIT-44: coordinator or the named unit) is a review item.
- TEST-12 is not enforced absolutely; 24 tracked failure images remain until
  G25's untracking.
- TEST-20's per-unit PNG/MB budget is not checked (G32).
- The full suite was not run; only the gate and the two kit gallery files
  (plus G5's tests on the scratch merge).

## State table

| Item | State |
|---|---|
| Gate test and baseline | implemented, verified locally, committed on `gate/G23` |
| Kit gallery DPR 3, Android override, `kitGalleryName`, Arabic families | implemented, verified locally (58 goldens pass), committed on `gate/G23` |
| Merge with G5 | resolution tested on a scratch merge, not committed anywhere |
| STANDARDS.md status and lists | not changed; text for the integrator in §8 |
| Screen-golden violations (baseline) | recorded, not fixed |
| Pushed / merged | no |
