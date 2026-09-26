# gate-G5: accessibility guidelines and reading order in every kit gallery shot (2026-09-26)

## 1. Scope

- Gate: `G5` (STANDARDS.md §18.1 row and §18.2 paragraph), built before wave 1 (W1). Finish line: every `kitGalleryShot` fails when a shot breaks `androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline` or the top-to-bottom, start-to-end reading order, in light and dark. Non-goal: fixing a kit part (no `lib/` change) and reading the G4 manifest (G4 builds that).
- Files changed:
  - `test/goldens/kit/kit_gallery.dart`: `kitGalleryShot` turns semantics on, and after the shot settles calls the new `expectKitGalleryAccessible` before the golden compare. New public helpers: `expectKitGalleryAccessible`, `kitReadingOrderProblems`, `kitGalleryG5BaselinePath`.
  - `test/goldens/kit/kit_gallery_g5_baseline.json`: the shrinking baseline (one entry).
  - `docs/qa/gate-G5-2026-09-26/`: this record and its logs.
- Rules enforced: A11Y-1 (semantic label on every control, via `labeledTapTargetGuideline`), A11Y-4 (reading order), A11Y-6 (the three guidelines in dark and light for every kit gallery), LAY-9 (48×48 dp targets, via `androidTapTargetGuideline`; the overlap and destructive-gap parts of LAY-9 stay with G20 and G37).
- Pages (map ids): n/a, gate only.
- Contract problems (PROC-20): the table marks G5 **absolute**, but today's code fails one shot (below). Per the build instructions it ships as a ratchet with one baseline entry; it becomes absolute when the KitConfirmSheet owner fixes that shot and deletes the entry.

### What the gate checks

1. The three `flutter_test` guidelines, each evaluated directly (`guideline.evaluate(tester)`) so all failures of a shot are reported together.
2. Reading order (A11Y-4): `tester.semantics.simulatedAccessibilityTraversal()`, keeping visible nodes (not hidden, non-empty, on screen) with their global rects. For each node and the one read just before it, when their rects do not overlap, it fails if the node lies wholly above the previous one ("goes back up"), or it starts on the same line and lies wholly on its start side ("goes back towards the start of the line"; start is left in LTR and right in RTL, taken from `Directionality` under the gallery's locale). Overlapping nodes (a row and its trailing button) have no order and are skipped.
3. Modal barriers are left out of the reading order: `ModalRoute` itself gives a dismissible barrier `OrdinalSortKey(1.0)` so "Scrim / close" is read after the sheet (flutter `widgets/routes.dart`, "To be sorted after the _modalScope"). Without that exclusion every sheet shot failed with `"Scrim" … is read after "More languages" …: goes back up`.
4. Both themes: every gallery already renders each shot in light and dark, and every shot goes through `kitGalleryShot`, so no shot can skip the check. There is no opt-out parameter.

### Ratchet

- Baseline `test/goldens/kit/kit_gallery_g5_baseline.json`, keyed by golden name, listing the check names (`androidTapTarget`, `labeledTapTarget`, `textContrast`, `readingOrder`) that shot may still fail.
- A check not listed for a shot fails the test with every reason. A listed check that now passes prints `G5 ratchet: <shot> now passes <check>. Commit the smaller baseline …: remove "<shot>"` (or the shorter list) and the test still passes, matching `kit_ratchet_test.dart`.
- Baseline counts on 2026-09-26: **1 shot, 1 check** out of 58 shots.

| Shot | Check | Why | Owner |
|---|---|---|---|
| `kit_confirm_destructive_text2_1280x800_light` | `textContrast` | At 2.0 text on a 1280×800 window the KitConfirmSheet dialog scrolls and its **Cancel** button is cut by the dialog's bottom edge (see `test/goldens/kit/kit_confirm_destructive_text2_1280x800_light.png`); the contrast check samples the grey scrim under the clipped half (3.79:1). The dark shot passes. A fix needs a `lib/ui/kit/` change (keep the actions visible, as KIT-17 asks of KitSheet), so it is outside this gate. | KitConfirmSheet unit |

## 2. Builds

- Branch `gate/G5`, base `9220f070`, code head `e353426b`.
- No APK (gate agents do not build).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Both kit galleries with an empty baseline | real failures of today's code are shown | 1 of 58 failed: `kit_confirm_destructive_text2_1280x800_light` [textContrast]; see `today-without-baseline.txt` | PASS |
| 2 | Both kit galleries with the committed baseline (pass on today) | all pass, goldens unchanged | `00:13 +58: All tests passed!`, no ratchet message; see `pass-today.txt` | PASS |
| 3 | Throwaway `test/goldens/kit/zz_g5_violation_test.dart` (deleted after): an unlabelled tap target, 3.36:1 text, reversed sort keys | each fails at G5, before the golden compare | `[labeledTapTarget] … expected tappable node to have semantic label`, `[textContrast] … found 3.36`, `[readingOrder] #9 "Top line" at (181, 426, 231, 446) is read after #10 "Bottom line" at (169, 470, 243, 490): goes back up`; see `fail-on-violation.txt` | PASS |
| 4 | Same fixture: a 20 dp tall labelled button | fails at G5 | `[androidTapTarget] … expected tap target size of at least Size(48.0, 48.0), but found Size(232.0, 20.0)`; see `fail-on-violation-tap-target.txt` | PASS |
| 5 | Temporary stale baseline entry `kit_sheet_half_dark: [readingOrder]` (reverted) | passes and prints the smaller baseline | `G5 ratchet: kit_sheet_half_dark now passes readingOrder. Commit the smaller baseline in test/goldens/kit/kit_gallery_g5_baseline.json: remove "kit_sheet_half_dark"`; see `ratchet-shrink.txt` | PASS |
| 6 | `flutter analyze test/goldens/kit` | no issues | `No issues found!` | PASS |

Before the exclusion in "What the gate checks" 3, the first run failed 40 shots, all on the framework's scrim node; before the handle was disposed in the shot itself, every shot failed with "A SemanticsHandle was active at the end of the test" (tear-downs run after that check). Both were fixed in the helper.

## 5. Evidence

- `pass-today.txt`, `today-without-baseline.txt`, `fail-on-violation.txt`, `fail-on-violation-tap-target.txt`, `ratchet-shrink.txt`: the outputs of runs 2, 1, 3, 4 and 5.
- Rule evidence (PROC-31):

  | Rule | Test | Output |
  |---|---|---|
  | A11Y-1 | every `kitGalleryShot` (`labeledTapTarget`) | `pass-today.txt`, `fail-on-violation.txt` |
  | A11Y-4 | every `kitGalleryShot` (`readingOrder`) | `pass-today.txt`, `fail-on-violation.txt` |
  | A11Y-6 | every `kitGalleryShot`, both themes | `pass-today.txt` |
  | LAY-9 (size) | every `kitGalleryShot` (`androidTapTarget`) | `pass-today.txt`, `fail-on-violation-tap-target.txt` |

- Changed test expectations (TEST-19): none; no golden changed (turning semantics on does not change the paint).
- Accessibility: this is the accessibility gate; see the baseline table for the one open finding.
- Privacy and security: n/a, no credentials, stored data, links or notifications changed.
- Migration: n/a, no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 1 \
  test/goldens/kit/kit_sheet_golden_test.dart \
  test/goldens/kit/kit_confirm_sheet_golden_test.dart
tool/qa/machine_lock.sh analyze -- $F analyze test/goldens/kit
# Pass-on-today without the baseline (run 1): set "shots" to {} in
# test/goldens/kit/kit_gallery_g5_baseline.json and rerun the first command.
```

## 7. NOT proven

- Not run on a device or emulator; TalkBack's real order was not listened to. The reading-order check compares consecutive nodes only, and treats overlapping nodes as unordered, so an order that is wrong only between non-neighbours, or between overlapping nodes, passes.
- Only the two galleries that exist today (KitSheet, KitConfirmSheet) are covered; later parts are covered when their galleries call `kitGalleryShot`. G4's manifest wiring is not part of this gate.
- A baseline entry whose shot is renamed or deleted is not reported as stale (each shot only sees its own entry).
- The LAY-9 overlap and destructive-gap clauses are not checked here (G20, G37).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `gate/G5` |
| Enabled | Yes: runs in every kit gallery shot | `test/goldens/kit/kit_gallery.dart` |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `e353426b` |
| Deployed | No | |
