# gate-G6: text scale overflow matrix for kit parts (2026-09-26)

## 1. Scope

- Gate: G6, `test/text_scale_overflow_test.dart` (kit matrix), STANDARDS.md §18.1 and §18.2. When: W1.
- Rules enforced: A11Y-2 (every part reflows at 200 % text with no overflow at the LAY-4 overflow sizes), LAY-4 (the overflow sizes), KIT-24 (KitSegmented stacks full-width `KitChoiceRow`s when its labels do not fit).
- Files changed:
  - `test/text_scale_overflow_test.dart`: the nine critical 2.5x flows are unchanged; the new group `G6 kit overflow matrix` is added.
  - `test/kit/kit_overflow_scenes.dart` (new): 60 scenes, one or more per part, in English (left to right) and Arabic (right to left).
  - `test/text_scale_overflow_baseline.json` (new): the ratchet.
- What the gate checks:
  1. **Manifest.** `kitManifest()` reads `lib/ui/kit/kit.dart`. It follows every relative `export` (it honours `show`, follows `part` files and follows re-exports such as `kit_effects.dart` → `lib/state/effects.dart`). It collects every public class that extends a widget: a superclass ending in `Widget`, `InheritedNotifier`, `InheritedModel`, `InheritedTheme`, or another kit widget. It also collects every top-level `showKit…` function. Today that is 42 names, and all 42 have scenes.
  2. **Coverage.** Every manifest name must appear in some scene's `parts`, and every scene must name a part that is still exported. Scene ids must be unique, and every baseline key must be an existing scene. Once `KitSegmented` is exported, a scene with `labelsOverflow: true` must cover it.
  3. **Matrix.** Each scene is pumped at 9 sizes × 3 text scales × 2 directions, 54 combinations in all:
     - sizes: 320×640, 360×740, 412×915, 600×960, 800×1280, 840×1180, 1280×800, 1600×1000 and 915×412;
     - text: 1.0, 1.3 and 2.0;
     - directions: `en` LTR and `ar` RTL.

     Each combination runs under a fresh `MaterialApp` with the capture theme and the gallery fonts (`loadKitGalleryFonts`) and `disableAnimations`, then gets two 400 ms frames. After that, `tester.takeException()` must be null. Each scene is put in one of three hosts: inside a padded `ListView` (rows, panels), as the whole body (screens, page states), or opened as a modal (`showKitSheet`, `showKitConfirm`).
  4. **KIT-24.** For a `labelsOverflow` scene at text 2.0 on 320 and 360 dp, a widget whose runtime type is `KitChoiceRow` must be present.
- Kind: STANDARDS marks G6 **absolute**, but today's code does not comply, so as the build instructions require, G6 is a **ratchet**:
  - A failing combination that is not in `test/text_scale_overflow_baseline.json` fails the gate.
  - When every scene ran and some baseline entries no longer fail, the test passes and prints the smaller baseline to commit. `G6_OVERFLOW_WRITE=1` writes it instead.
  - The file is only created from observations on the gate's first run. After that, an entry can only leave it.
- Contract problems (PROC-20):
  - The task text listed widths 320/360/412/600/840/1280 and 915×412. STANDARDS §18.2 G6 and LAY-4 also list 800 and 1600. The gate uses the STANDARDS superset.
  - STANDARDS says "every G4 gallery scene", but G4 (`test/kit/kit_manifest_test.dart`) and its scene manifest do not exist yet. Until G4 exposes gallery scenes, the scenes live in `test/kit/kit_overflow_scenes.dart`, which is append-only: one block per new part. So that kit units never edit `text_scale_overflow_test.dart` (PROC-13), this file needs to be added to the PROC-13 registries. Otherwise G4 should hand its gallery scenes to G6.
- New kit parts: none. No `lib/` file changed.

## 2. Builds

- Branch `gate/G6`, base `9220f070` (`feat/phone-setup-v2`), code head `4cc835fd`.
- No APK (gate agents do not build).

## 3. Devices

None: tests only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/text_scale_overflow_test.dart` on today's code (baseline committed) | passes | 71 passed: 9 critical flows, 2 checks and 60 scenes (`pass-on-today.txt`) | PASS |
| 2 | Throwaway violations, then removed: (a) the KitGlass scene deleted; (b) a `KitPanel/violation` scene whose child is a `Row` of two unwrapped texts; (c) a `KitButton/segmented-violation` scene marked `labelsOverflow` | gate fails on all three | 3 failed: `Actual: ['KitGlass']` "Kit parts with no scene…"; `KitPanel/violation overflowed or threw in 26 of 54 combinations beyond test/text_scale_overflow_baseline.json` ("A RenderFlex overflowed by 164 pixels on the right" at 320x640 text 1.0 …); `KitButton/segmented-violation … 4 of 54` "labels do not fit, but no KitChoiceRow (KIT-24 …)" (`fail-on-violation.txt`) | PASS |
| 3 | Ratchet shrink: a stale entry `KitRow/default: 320x640 text 1.0 ltr` added to the baseline for the run, then restored | passes and prints the smaller baseline | 62 passed; printed "G6 overflow baseline shrank" without the stale entry (`ratchet-shrinks.txt`) | PASS |
| 4 | `flutter analyze test/text_scale_overflow_test.dart test/kit/kit_overflow_scenes.dart` | no issues | No issues found | PASS |

## 5. Evidence

- `pass-on-today.txt`: run 1.
- `fail-on-violation.txt`: run 2.
- `ratchet-shrinks.txt`: run 3.
- Baseline counts at creation: 5 scenes, 12 combinations, all at text 2.0.

  | Scene | Failing combinations |
  |---|---|
  | `KitActionBlock/default` | 800x1280 ltr and rtl, 840x1180 ltr, 915x412 ltr (overflow of 14–264 px on the right) |
  | `KitSheet/default` | 800x1280 ltr, 915x412 ltr (15 px) |
  | `KitSheet/full` | 800x1280 ltr, 915x412 ltr (15 px) |
  | `KitSheet/loading` | 800x1280 ltr, 915x412 ltr (15 px) |
  | `KitSheet/disabled` | 800x1280 ltr, 915x412 ltr (15 px) |

  Cause, for the kit owner: at `maxWidth >= 600`, `KitActionBlock` (`lib/ui/kit/kit_buttons.dart`) lays tertiary, secondary and primary out in one `Row` and never falls back to its stacked layout when they do not fit at text 2.0. The sheet's pinned actions show the same overflow on medium windows. Fixing this is a `lib/` change and outside this gate. The fix should lower the baseline.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) | Output |
  |---|---|---|
  | A11Y-2, LAY-4 | `test/text_scale_overflow_test.dart` "G6 kit overflow matrix" | `pass-on-today.txt`, `fail-on-violation.txt` |
  | KIT-24 | same, "every exported kit part has a scene" + `labelsOverflow` scenes | `fail-on-violation.txt` (segmented-violation) |

- Changed test expectations (TEST-19): none. The nine existing 2.5x cases are untouched.
- Goldens changed: none.
- Accessibility: this gate is itself the text-scale check. It covers 1.0, 1.3 and 2.0 at every LAY-4 size and in Arabic RTL.
- Privacy and security: n/a. The secret field scene uses a fake `sk-test-not-a-real-key`.
- Migration: n/a.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 1 test/text_scale_overflow_test.dart
tool/qa/machine_lock.sh test -- $F test -j 1 test/text_scale_overflow_test.dart --plain-name 'G6'
# after a kit fix, write the smaller baseline:
G6_OVERFLOW_WRITE=1 tool/qa/machine_lock.sh test -- $F test -j 1 test/text_scale_overflow_test.dart --plain-name 'G6'
tool/qa/machine_lock.sh analyze -- $F analyze test/text_scale_overflow_test.dart test/kit/kit_overflow_scenes.dart
```

The matrix takes about 40 s (60 scenes × 54 combinations).

## 7. NOT proven

- Not run on a device or emulator.
- Only states that have a scene are checked. Declared states (KIT-12) are not parsed, so a part's undeclared or missing states are G4's to enforce.
- The KIT-24 stacked-layout check is proven only against a stand-in scene, because `KitSegmented` and `KitChoiceRow` do not exist yet. The check matches by runtime type name.
- Vertical clipping inside a scrolling host is not an overflow and is not detected. Only thrown layout errors count.
- The heights for width-only LAY-4 sizes (640, 740, 960, 1180 and so on) are this gate's choice. STANDARDS gives widths only.
- The full repository suite was not run. Only this file and the analyzer were run.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes (ratchet; absolute once the baseline is empty) | `gate/G6` |
| Enabled | Yes | runs with `flutter test` |
| Verified | tests only | this record |
| Committed | Yes | code head `4cc835fd` |
| Deployed | No | |
