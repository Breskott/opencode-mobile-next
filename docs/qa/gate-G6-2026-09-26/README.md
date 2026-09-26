# gate-G6: text scale overflow matrix for kit parts (2026-09-26)

## 1. Scope

- Unit: gate `G6` (wave W1, gate). Finish line: every part `lib/ui/kit/kit.dart` exports is pumped at every LAY-4 overflow size, at text 1.0, 1.3 and 2.0, LTR and RTL, and any overflow outside a fixed, shrink-only ceiling fails. Non-goal: fixing today's overflows in `lib/ui/kit/` (a `lib/` change, owned by kit-KitAction-v2) and per-declared-state coverage (G4's scene manifest).
- Files changed:
  - `test/text_scale_overflow_test.dart`: the nine critical 2.5x flows are unchanged. The group `G6 kit overflow matrix` holds the manifest check, two self-tests (manifest parser, KIT-24 check), the ceiling check and one matrix test per scene.
  - `test/kit/kit_overflow_scenes.dart` (new): 60 scenes, one or more per part, in English (left to right) and Arabic (right to left).
  - `test/text_scale_overflow_baseline.json` (new): the committed ratchet, 12 entries, each with its error line.
- Pages (map ids): n/a (gate).
- Specs followed: STANDARDS.md §18.1 and §18.2 G6; rules A11Y-2, LAY-4, KIT-24; PROC-13, PROC-20, PROC-31, KIT-4.
- What the gate checks:
  1. **Manifest** (`readKitManifest()`). It reads `lib/ui/kit/kit.dart` and follows every relative or `package:opencode_mobile/` `export`, honouring `show`, following `part` files and re-exports (for example `kit_effects.dart` → `lib/state/effects.dart`). It collects every exported public class whose superclass chain leaves the scanned files at a widget (a name ending in `Widget`, `InheritedNotifier`, `InheritedModel` or `InheritedTheme`), and every top-level `showKit…` function, whatever it returns. Today that is 42 names, and all 42 have scenes. **It fails loudly**: any `export` or `part` directive that is not exactly `export '<file>';`, `export '<file>' show A, B;` or `part '<file>';` (a `hide`, a conditional export, double quotes), any `dart:` or third-party `package:` export, and any exported class whose superclass chain ends outside the kit at a class that is not a widget and is not allowlisted by name (`KitTokens`, `KitPageTransitionsBuilder`) is a manifest problem, and the test fails. A class with no `extends` is an `Object` and is never a widget (`KitAction`, `KitLayout`, `KitMotion` and similar).
  2. **Coverage.** Every manifest name must appear in some scene's `parts`, and every scene must name a part that is still exported. Scene ids must be unique. Once `KitSegmented` is exported, a scene with `labelsOverflow: true` must cover it.
  3. **Matrix.** Each scene is pumped at 9 sizes × 3 text scales × 2 directions, 54 combinations in all:
     - sizes: 320×640, 360×740, 412×915, 600×960, 800×1280, 840×1180, 1280×800, 1600×1000 and 915×412;
     - text: 1.0, 1.3 and 2.0;
     - directions: `en` LTR and `ar` RTL.

     Each combination runs under a fresh `MaterialApp` with the capture theme, the gallery fonts (`loadKitGalleryFonts`) and `disableAnimations`, then gets two 400 ms frames. After that, `tester.takeException()` must be null. Each scene is put in one of three hosts: inside a padded `ListView` (rows, panels), as the whole body (screens, page states), or opened as a modal (`showKitSheet`, `showKitConfirm`).
  4. **KIT-24.** For a `labelsOverflow` scene, at text 2.0 on every phone size (shortest side under 600: 320×640, 360×740, 412×915 and 915×412), `kit24Problem()` requires: a `KitSegmented` is shown; it is as wide as its constraints allow; it contains at least two `KitChoiceRow`s, each as wide as the part and stacked top to bottom without overlap; and it draws no text outside them, so the horizontal segmented track is gone. A self-test proves the check with stand-in widgets: a stack passes; a track kept beside the rows, rows narrower than the part, and no part at all each fail.
  5. **Ratchet.** See Kind below.
- Kind: STANDARDS marks G6 **absolute**, but today's code does not comply, so, as the build instructions require, G6 is a **ratchet that cannot grow**:
  - `_overflowCeiling` in `test/text_scale_overflow_test.dart` is a `const` holding the 12 combinations that failed when the gate was built (code head `4cc835fd`), each with its first error line. Kit units never edit this file (PROC-13), so nothing can be added to it.
  - `test/text_scale_overflow_baseline.json` must exist. A missing file fails the gate and is never recreated from observations, not even with `G6_OVERFLOW_WRITE=1`. Every entry must be in the ceiling, with the same error and an overflow no larger (for example 15 px, not 40 px).
  - Each scene's observed failures must equal its baseline entries exactly. A new combination, a different error or a larger overflow fails as a regression. A combination that is fixed, or overflows less, also fails ("improved. Tighten … in the same change"), so a stale entry cannot mask a later regression at the same combination.
  - `G6_OVERFLOW_WRITE=1` writes the tightened baseline: only baselined entries that still fail, and fail no worse, are kept. Without the flag the tightened baseline is printed.
- Contract problems (PROC-20):
  1. {§18.2 G6 and LAY-4; the task text listed widths 320/360/412/600/840/1280 and 915×412, while STANDARDS also lists 800 and 1600; settled by §0.2 (STANDARDS wins); the gate uses the STANDARDS superset; no text change; blocks: false}
  2. {§18.2 G6 "every G4 gallery scene"; G4 (`test/kit/kit_manifest_test.dart`) and its scene manifest do not exist yet; evidence: `test/kit/` has no `kit_manifest_test.dart`; the scenes live in `test/kit/kit_overflow_scenes.dart`, append-only, one block per new part; proposed text for PROC-13's registries list: "`kitOverflowScenes` in `test/kit/kit_overflow_scenes.dart` (until G4 hands its gallery scenes to G6)"; blocks: false}
  3. {§18.2 G6 says "(absolute)", and PROC-13's baseline list and G31's list name the G2/G7/G17/G21/G24/G26–G29 baselines only; today 12 combinations overflow (`test/text_scale_overflow_baseline.json`), so G6 ships as a ratchet whose baseline neither PROC-13 nor G31 protects; this gate fixes the ceiling inside the test instead (`_overflowCeiling`, `test/text_scale_overflow_test.dart`); proposed text: add "`test/text_scale_overflow_baseline.json` (G6)" to PROC-13's Baselines list and to G31's list, and amend §18.2 G6 to "(absolute once `test/text_scale_overflow_baseline.json` is empty; until then a ratchet under `_overflowCeiling`)"; blocks: false}
  4. {work-units.json kit-KitSheet-v2 and kit-KitAction-v2 are both tier 1 with no `after`; the KitSheet overflow comes from `KitActionBlock`'s row in the sheet's pinned actions (`lib/ui/kit/kit_sheet.dart:337`, `lib/ui/kit/kit_buttons.dart:301`); a KitSheet-v2 scene for a new state overflows at 800×1280 and 915×412 text 2.0 and cannot be baselined under the fixed ceiling, and the fix is outside KitSheet-v2's write set; proposed: kit-KitSheet-v2 `after: ["kit-KitAction-v2"]`, and kit-KitAction-v2's acceptance gains "G6 baseline `test/text_scale_overflow_baseline.json` is `{}`"; evidence: `stale-entry-fails.txt` shows that stacking `KitActionBlock` below 900 dp removes all 12 entries; blocks: false for G6}
- New kit parts (KIT-3): none. No `lib/` file changed in any commit; `lib/ui/kit/kit_buttons.dart` was changed only by the throwaway patches of runs 2 and 3, and reverted.
- Map items (EVID-11): n/a (gate).
- States per page (STATE-20): n/a (gate).
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `gate/G6`, base `9220f070` (`feat/phone-setup-v2`), code head `3d4b0d3f`.
- No APK (gate agents do not build).

## 3. Devices

None: tests only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/text_scale_overflow_test.dart` on today's code at code head | passes | 73 passed: 9 critical flows, the manifest check, the manifest-parser self-test, the KIT-24 self-test, the ceiling check and 60 scenes (`pass-on-today.txt`) | PASS |
| 2 | `fail-on-violation.patch` applied: (a) **a real part broken**: `KitActionBlock` (`lib/ui/kit/kit_buttons.dart`) loses its stacked fallback (`maxWidth >= 600` → `>= 0`); (b) the KitGlass scene deleted; (c) a `KitPanel/violation` scene whose child is a `Row` of two unwrapped texts; (d) the baseline hand-raised: a `KitRow/default` entry added and `KitSheet/default` 800x1280 raised from 15 to 40 px. Reverted with `git apply -R` | gate fails on all four | 15 failed (`fail-on-violation.txt`): manifest `Actual: ['KitGlass']`; ceiling check lists both hand-added entries "may only shrink"; the real break fails `KitActionBlock/default`, `KitActionBlock/disabled`, `KitRequestCard/*`, `KitScreen/default`, all five `KitSheet/*` scenes and `KitStateView/error` (for example "360x740 text 2.0 ltr: A RenderFlex overflowed by 704 pixels"); `KitRow/default` fails "improved. Tighten" for the stale hand-added entry; `KitPanel/violation` fails in 16 of 54 combinations | PASS |
| 3 | `stale-entry.patch` applied: `KitActionBlock` stacks below 900 dp instead of 600 (a fix), baseline not updated. Reverted with `git apply -R` | gate fails until the baseline is tightened | 5 failed: `KitActionBlock/default` and the four `KitSheet/*` scenes, "improved. Tighten test/text_scale_overflow_baseline.json in the same change" with every entry "fixed"; the printed tightened baseline is `{}` (`stale-entry-fails.txt`) | PASS |
| 4 | Baseline moved away, run with `G6_OVERFLOW_WRITE=1`, then restored | fails, and does not recreate the file | 6 failed: "test/text_scale_overflow_baseline.json is missing. It is never recreated…", and the 5 overflowing scenes; `ls` afterwards: "No such file or directory" (`missing-baseline-fails.txt`) | PASS |
| 5 | `flutter analyze test/text_scale_overflow_test.dart test/kit/kit_overflow_scenes.dart` | no issues | No issues found | PASS |

## 5. Evidence

- `pass-on-today.txt`: run 1.
- `fail-on-violation.patch` and `fail-on-violation.txt`: run 2.
- `stale-entry.patch` and `stale-entry-fails.txt`: run 3.
- `missing-baseline-fails.txt`: run 4.
- Baseline counts (= the ceiling, at creation): 5 scenes, 12 combinations, all at text 2.0.

  | Scene | Failing combinations |
  |---|---|
  | `KitActionBlock/default` | 800x1280 ltr (264 px) and rtl (14 px), 840x1180 ltr (224 px), 915x412 ltr (149 px) |
  | `KitSheet/default` | 800x1280 ltr, 915x412 ltr (15 px) |
  | `KitSheet/full` | 800x1280 ltr, 915x412 ltr (15 px) |
  | `KitSheet/loading` | 800x1280 ltr, 915x412 ltr (15 px) |
  | `KitSheet/disabled` | 800x1280 ltr, 915x412 ltr (15 px) |

  Cause, for the kit owner: at `maxWidth >= 600`, `KitActionBlock` (`lib/ui/kit/kit_buttons.dart:301`) lays tertiary, secondary and primary out in one `Row` and never falls back to its stacked layout when they do not fit at text 2.0. The sheet's pinned actions use `KitActionBlock` (`lib/ui/kit/kit_sheet.dart:337`). Run 3 shows that stacking below 900 dp empties the baseline; a fix that measures the row instead is the owner's choice.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) | Output |
  |---|---|---|
  | A11Y-2, LAY-4 | `test/text_scale_overflow_test.dart` `--plain-name 'G6 kit overflow matrix'` (one test per scene) | `pass-on-today.txt`, `fail-on-violation.txt` |
  | A11Y-2 (manifest completeness) | same file, `--plain-name 'every exported kit part has a scene, and every scene a part'` and `'the manifest fails loudly on what it cannot read'` | `pass-on-today.txt`, `fail-on-violation.txt` |
  | KIT-4 style ratchet (shrink only) | same file, `--plain-name 'the overflow baseline exists and stays under the ceiling'` | `fail-on-violation.txt`, `stale-entry-fails.txt`, `missing-baseline-fails.txt` |
  | KIT-24 | same file, `--plain-name 'the KIT-24 check passes a stack and fails a track, narrow rows or no part'` | `pass-on-today.txt` |

- Changed test expectations (TEST-19): none. The nine existing 2.5x cases are untouched.
- Goldens changed: none.
- Accessibility: this gate is itself the text-scale check. It covers 1.0, 1.3 and 2.0 at every LAY-4 size and in Arabic RTL.
- Privacy and security: n/a. The secret field scene uses a fake `sk-test-not-a-real-key`.
- Migration: n/a.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
Q=docs/qa/gate-G6-2026-09-26
# 1. pass on today
tool/qa/machine_lock.sh test -- $F test -j 1 test/text_scale_overflow_test.dart
# 2. fail on violation (a real kit part, a missing scene, a new overflow, a raised baseline)
git apply $Q/fail-on-violation.patch
tool/qa/machine_lock.sh test -- $F test -j 1 test/text_scale_overflow_test.dart --plain-name G6
git apply -R $Q/fail-on-violation.patch
# 3. a fixed overflow fails until the baseline is tightened
git apply $Q/stale-entry.patch
tool/qa/machine_lock.sh test -- $F test -j 1 test/text_scale_overflow_test.dart --plain-name G6
git apply -R $Q/stale-entry.patch
# 4. a missing baseline fails and is not recreated
mv test/text_scale_overflow_baseline.json /tmp/g6-baseline.json
G6_OVERFLOW_WRITE=1 tool/qa/machine_lock.sh test -- $F test -j 1 test/text_scale_overflow_test.dart --plain-name G6
ls test/text_scale_overflow_baseline.json   # No such file or directory
mv /tmp/g6-baseline.json test/text_scale_overflow_baseline.json
# after a real kit fix: write the tightened baseline, then commit it with the fix
G6_OVERFLOW_WRITE=1 tool/qa/machine_lock.sh test -- $F test -j 1 test/text_scale_overflow_test.dart --plain-name G6
# 5. analyze
tool/qa/machine_lock.sh analyze -- $F analyze test/text_scale_overflow_test.dart test/kit/kit_overflow_scenes.dart
```

The matrix takes about 40 s (60 scenes × 54 combinations).

## 7. NOT proven

- Not run on a device or emulator.
- G6 is not yet absolute: 12 combinations stay baselined until kit-KitAction-v2 fixes `KitActionBlock`.
- Only states that have a scene are checked. Declared states (KIT-12) are not parsed, so a part's undeclared or missing states are G4's to enforce; per-declared-state coverage waits for G4's scene manifest.
- KIT-24: `KitSegmented` and `KitChoiceRow` do not exist yet, so the check is proven only against stand-in widgets, and it matches the real parts by runtime type name. Whether labels overflow is declared by the scene author (`labelsOverflow`), not measured from the labels' intrinsic width against the track, and the stack is checked at text 2.0 on phone sizes only, not at 1.3 or on wider windows.
- A kit part that extends an unknown non-widget base, or adds a non-widget class extending one, must be allowlisted in this file (`_nonWidgetClasses`), which kit units do not edit; such a unit reports it (PROC-32).
- Vertical clipping inside a scrolling host is not an overflow and is not detected. Only thrown layout errors count.
- The heights for width-only LAY-4 sizes (640, 740, 960, 1180 and so on) are this gate's choice. STANDARDS gives widths only.
- The full repository suite was not run. Only this file and the analyzer were run.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | partial (ratchet with 12 baselined combinations; per-state coverage waits for G4) | `gate/G6` |
| Enabled | Yes | runs with `flutter test` |
| Verified | tests only | this record |
| Committed | Yes | code head `3d4b0d3f` |
| Deployed | No | |
| Released | No | |

Blockers to absolute: {kind: outside-write-set; file: `lib/ui/kit/kit_buttons.dart` (`KitActionBlock`), which also fixes the four `KitSheet/*` scenes; owner: kit-KitAction-v2; needed: `KitActionBlock` falls back to its stacked layout when its row does not fit at text 2.0; change requested: that fix plus `test/text_scale_overflow_baseline.json` written with `G6_OVERFLOW_WRITE=1` to `{}` in the same commit}.
