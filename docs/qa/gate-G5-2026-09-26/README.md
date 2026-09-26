# gate-G5: accessibility guidelines and reading order in every kit gallery shot (2026-09-26)

## 1. Scope

- Gate: `G5` (STANDARDS.md §18.1 row and §18.2 paragraph), built before wave 1 (W1). Finish line: every `kitGalleryShot` fails when the shot breaks `androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline` or the top-to-bottom, start-to-end reading order, in light **and** dark, whichever theme its gallery asked for. Non-goal: fixing a kit part (no `lib/` change), reading the G4 manifest (G4 builds that), and screen goldens outside `test/goldens/kit/` (see Contract problems 3).
- Files changed:
  - `test/goldens/kit/kit_gallery.dart`: `kitGalleryShot` turns semantics on, pumps the shot in the other theme and checks it (no golden), then pumps it in its own theme, checks it and compares the golden. New public API: `expectKitGalleryAccessible`, `kitReadingOrderProblems`, `kitGalleryG5Ceiling`, `kitGalleryG5BaselinePath`, `readKitGalleryG5Baseline`, `kitGalleryG5OverCeiling`, typedef `KitGalleryG5Baseline`.
  - `test/goldens/kit/kit_gallery_g5_baseline.json`: the baseline, one (shot, check, node) entry.
  - `test/goldens/kit/kit_gallery_g5_test.dart`: the gate's own tests (new). Each check fails on a small tree that breaks it; the baseline cannot pass its ceiling, cannot keep a stale entry, and excuses only its named node; a shot is checked in the theme its gallery did not render; plus one test that pins a known limit (§7). No golden is compared.
  - `docs/qa/gate-G5-2026-09-26/`: this record and its logs.
- Rules enforced: A11Y-1 (every control has a semantic label, via `labeledTapTargetGuideline`), A11Y-4 (reading order, kit galleries only; see Contract problems 3), A11Y-6 (the three guidelines in dark and light for every kit gallery), LAY-9 (48×48 dp targets, via `androidTapTargetGuideline`; the overlap and destructive-gap parts of LAY-9 stay with G20 and G37).
- Pages (map ids): n/a, gate only.
- Contract problems (PROC-20):
  1. {G5 §18.2, "G5 (absolute)", today's code fails one shot so it cannot ship absolute, evidence `today-without-baseline.txt` and `test/goldens/kit/kit_confirm_destructive_text2_1280x800_light.png`, proposed: none needed once the KitConfirmSheet unit fixes the shot and deletes the entry; until then the harness holds a hard ceiling of one entry (`kitGalleryG5Ceiling`, `test/goldens/kit/kit_gallery.dart:207`), blocks: false}.
  2. {PROC-13 "Baselines" and G31 §18.2, list `kit_ratchet_baseline.json`, the l10n `_baseline` and the G2/G7/G17/G21/G24/G26–G29 files, they do not name `test/goldens/kit/kit_gallery_g5_baseline.json`, so neither the merge rule nor G31 guards it, evidence `docs/ux-system/revamp/STANDARDS.md:187` and `:1148`, proposed: add "the G5 baseline `test/goldens/kit/kit_gallery_g5_baseline.json`" to both lists, blocks: false (the harness ceiling fails any raise meanwhile, and kit units may not edit the harness, §0.5 step 3)}.
  3. {A11Y-4, "In each gallery and golden fixture … Gate: missing: G5", G5 only reaches `kitGalleryShot`; 20 other golden test files (16 under `test/goldens/`, plus `test/setup_scenes_test.dart`, `test/servers_scenes_test.dart`, `test/kit_states_scenes_test.dart`, `test/kit_illustration_test.dart`) call `matchesGoldenFile` directly with no shared helper, so the golden-fixture half has no gate, and wiring it would edit other owners' files, evidence `docs/ux-system/revamp/STANDARDS.md:536` and `grep -rl matchesGoldenFile test | grep -v test/goldens/kit/`, proposed: A11Y-4's gate column becomes "G5 (kit galleries); missing: G3x (screen golden fixtures: a shared screen-golden helper that calls `kitReadingOrderProblems`, with its own shrinking baseline)", and G3x's paragraph gains that clause, blocks: false}.

### What the gate checks

1. The three `flutter_test` guidelines, each evaluated directly (`guideline.evaluate(tester)`) so every failure of a shot is reported together. A guideline's reason joins one paragraph per failing node; the harness splits it on `SemanticsNode#…(` and keys each failure by that node's label (tooltip when it has no label, empty when it has neither).
2. Reading order (A11Y-4): `tester.semantics.simulatedAccessibilityTraversal()`, keeping visible nodes (not hidden, non-empty, on screen) with their global rects. For each node and the one read just before it, when their rects do not overlap, it fails if the node lies wholly above the previous one ("goes back up"), or starts on the same line and lies wholly on its start side ("goes back towards the start of the line"; start is left in LTR and right in RTL, from `Directionality` under the gallery's locale). Overlapping nodes (a row and its trailing button) have no order and are skipped.
3. Modal barriers are left out of the reading order: `ModalRoute` gives a dismissible barrier `OrdinalSortKey(1.0)` so "Scrim / close" is read after the sheet (flutter `widgets/routes.dart`). Without that exclusion every sheet shot failed with `"Scrim" … is read after "More languages" …: goes back up`.
4. Both themes, enforced by the harness (A11Y-6): a shot name must end in `_light` or `_dark` matching `light` (otherwise `ArgumentError`); the shot is first pumped in the other theme and checked under the partner name (`…_dark` → `…_light`), then pumped in its own theme, checked and compared with its golden. A gallery that renders only dark, or only some scenes in light, still gets every shot checked in both. The other-theme pass compares no golden, so no golden changed.
5. There is no opt-out parameter.

### Baseline and ceiling

- `test/goldens/kit/kit_gallery_g5_baseline.json`: `{"shots": {shot: {check: [node label]}}}`. A failure is excused only when its shot, check **and** node label are listed; another node failing the same check in the same shot fails.
- Hard ceiling: `kitGalleryG5Ceiling` in the harness holds only `kit_confirm_destructive_text2_1280x800_light` → `textContrast` → `"Cancel"`. Any JSON entry outside it fails every shot (`… entries are outside kitGalleryG5Ceiling …`). Kit units may not edit the harness (§0.5 step 3, PROC-13), so the JSON can only shrink.
- Stale entries fail: when a listed (check, node) no longer fails, the shot fails with `Stale baseline: <shot> now passes [<check>] "<node>". Delete that entry …`, so a stale entry cannot hide a later regression. (This replaces the earlier behaviour, which only printed a message; its log `ratchet-shrink.txt` is removed.)
- Counts on 2026-09-26: **1 shot, 1 check, 1 node** out of 58 shots. The same frame is also checked from the dark shot's light pass, under the same name, so one entry covers both.

| Shot | Check | Node | Why | Owner |
|---|---|---|---|---|
| `kit_confirm_destructive_text2_1280x800_light` | `textContrast` | `Cancel` | At 2.0 text on a 1280×800 window the KitConfirmSheet dialog scrolls and its **Cancel** button is cut by the dialog's bottom edge (see the PNG); the contrast check samples the grey scrim under the clipped half (3.79:1). The dark theme passes. A fix needs a `lib/ui/kit/` change (keep the actions visible, as KIT-17 asks of KitSheet), outside this gate. | KitConfirmSheet unit |

## 2. Builds

- Branch `gate/G5`, base `9220f070`. First build `e353426b` + record `d30aec9d`; review fixes in the commit that carries this record.
- No APK (gate agents do not build).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

All with `F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter` through `tool/qa/machine_lock.sh`.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Both kit galleries with `"shots": {}` | today's real failures shown | 2 of 58 failed, both `failed for kit_confirm_destructive_text2_1280x800_light: [textContrast] node "Cancel"`: the light shot, and the dark shot through its light pass; see `today-without-baseline.txt` | PASS |
| 2 | Both kit galleries and `kit_gallery_g5_test.dart` with the committed baseline (pass on today) | all pass, goldens unchanged | `00:15 +73: All tests passed!` (58 shots + 15 gate tests), no PNG changed; see `pass-today.txt` | PASS |
| 3 | `kit_gallery_g5_test.dart` with a temporary `print` of each caught G5 message (removed after) | each violation fails at G5 on the intended node | `[androidTapTarget] node "Tiny" … found Size(120.0, 20.0)`, `[labeledTapTarget] node "" … flags: [isButton …]`, `[textContrast] node "Faint" … found 2.32`, `[readingOrder] node "Top line" … goes back up`, `[readingOrder] node "Start" … goes back towards the start of the line` (RTL), `outside kitGalleryG5Ceiling: zz_g5_fixture_light [textContrast] "Faint"`, `[textContrast] node "Other"` excused-shot, `Stale baseline: … now passes [textContrast] "Cancel"`, `failed for zz_g5_theme_light: [textContrast] node "Pale" … found 1.11` from a dark-only shot; see `fail-on-violation-self-test.txt` | PASS |
| 4 | Real gallery `kit_sheet half` with an entry outside the ceiling added to the JSON (`kit_sheet_half_dark` / `readingOrder` / `Scrim`; reverted) | both shots fail | `these entries are outside kitGalleryG5Ceiling … kit_sheet_half_dark [readingOrder] "Scrim"`, `+0 -2: Some tests failed.`; see `baseline-over-ceiling.txt` | PASS |
| 5 | Gate tests against a weakened harness (ceiling check off, stale check off, own theme only, whole-check exemption; restored after, `cmp` clean) | the gate's tests catch each | 4 failed: `an entry outside the ceiling fails`, `a listed node that now passes fails as stale`, `another node failing the listed check still fails`, `a dark-only gallery is still checked in light` (it reached the golden compare instead); see `self-test-mutations.txt` | PASS |
| 6 | `flutter analyze --no-pub test/goldens/kit` | no issues | `No issues found!` | PASS |
| h1 | (first build, historical) throwaway `zz_g5_violation_test.dart`: "small tap target", unlabelled target, 3.36:1 text, reversed sort keys | each fails at G5 | **the small-tap-target fixture passed every G5 check** and failed only at the golden compare (`Could not be compared against non-existent file: "zz_small.png"`); the other three failed at G5, but the unlabelled and contrast failures were reported on `SemanticsNode#8 (0, 0, 412, 915) role: dialog`, not on the intended control; see `fail-on-violation.txt` | see below |
| h2 | (historical) same file, a 20 dp tall labelled `TextButton` | fails at G5 | `[androidTapTarget] … found Size(232.0, 20.0)`; see `fail-on-violation-tap-target.txt` | PASS |

About h1. The throwaway fixture was deleted and its source was not kept, so h1 and h2 cannot be rerun exactly; run 3 replaces them with permanent fixtures in `kit_gallery_g5_test.dart`. What the log shows: the tap action and the label `"Faint"` sat on the full-window dialog node (#8, 412×915), so the fixture's controls had no semantics node of their own and their semantics merged into the dialog's. The guidelines judge semantics nodes, not gesture areas: the small tap zone was measured as the dialog node, which is 412×915 and touches the view edge, and `androidTapTargetGuideline` skips nodes at the view edge (`_isAtBoundary(paintBounds, viewRect)`, flutter_test `accessibility.dart:173`). The label and contrast checks still fired, on the dialog node. The gate test `known gap: a bare 20 dp GestureDetector inside a larger labelled node is not measured` reproduces the mechanism (a 20 dp `GestureDetector` inside a 200×100 labelled node passes G5) and is listed under NOT proven. Run 3's fixtures give each control its own node, and each failure names that node.

## 5. Evidence

- `today-without-baseline.txt`, `pass-today.txt`, `fail-on-violation-self-test.txt`, `baseline-over-ceiling.txt`, `self-test-mutations.txt`: runs 1–5. `fail-on-violation.txt`, `fail-on-violation-tap-target.txt`: historical runs h1, h2.
- Rule evidence (PROC-31):

  | Rule | Test | Output |
  |---|---|---|
  | A11Y-1 | every `kitGalleryShot` (`labeledTapTarget`); `labeledTapTarget: an icon button with no label fails` | `pass-today.txt`, `fail-on-violation-self-test.txt` |
  | A11Y-4 | every `kitGalleryShot` (`readingOrder`); `readingOrder: …` (LTR and RTL) | `pass-today.txt`, `fail-on-violation-self-test.txt` |
  | A11Y-6 | every `kitGalleryShot` in both themes; `a dark-only gallery is still checked in light` | `pass-today.txt`, `today-without-baseline.txt`, `fail-on-violation-self-test.txt` |
  | LAY-9 (size) | every `kitGalleryShot` (`androidTapTarget`); `androidTapTarget: a 20 dp tall button fails` | `pass-today.txt`, `fail-on-violation-self-test.txt` |

- Changed test expectations (TEST-19): none; no golden changed.
- Accessibility: this is the accessibility gate; see the baseline table for the one open finding.
- Privacy and security: n/a, no credentials, stored data, links or notifications changed.
- Migration: n/a, no stored format changed. The baseline JSON format changed from `{shot: [check]}` to `{shot: {check: [node]}}`; it has no other reader.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 1 \
  test/goldens/kit/kit_sheet_golden_test.dart \
  test/goldens/kit/kit_confirm_sheet_golden_test.dart \
  test/goldens/kit/kit_gallery_g5_test.dart
tool/qa/machine_lock.sh analyze -- $F analyze test/goldens/kit
# Run 1: set "shots" to {} in test/goldens/kit/kit_gallery_g5_baseline.json
# and rerun the two gallery files; restore the file afterwards.
```

## 7. NOT proven

- Not run on a device or emulator; TalkBack's real order was not listened to. The reading-order check compares consecutive nodes only and treats overlapping nodes as unordered, so an order that is wrong only between non-neighbours, or between overlapping nodes, passes.
- Tap-target size is judged per semantics node, not per gesture area: a small tap zone with no semantics node of its own (a bare `GestureDetector`) is measured as the enclosing node, and a node touching the view edge or the edge of a scrollable is skipped by `androidTapTargetGuideline`. Pinned by the `known gap` gate test; this is how the first small-target fixture (h1) passed G5.
- A11Y-4 for the 20 golden fixtures outside `test/goldens/kit/` is not enforced (Contract problems 3); proposed owner G3x.
- The baseline file is not in PROC-13's or G31's baseline lists (Contract problems 2); the harness ceiling is the only guard until the contract names it.
- Only the two galleries that exist today (KitSheet, KitConfirmSheet) are covered; later parts are covered when their galleries call `kitGalleryShot`, which G4's manifest is to require. G4's manifest wiring is not part of this gate.
- A baseline entry whose shot is renamed or deleted is not reported as stale (each shot sees only its own entry). The ceiling limits the harm to that one named frame. After the KitConfirmSheet unit deletes the JSON entry, the ceiling entry stays in the harness and would accept the same entry back; only a reviewer (or G31, once it names the file) sees that raise.
- A node is identified by its label, so two failing nodes with the same label in the listed shot share one entry.
- The LAY-9 overlap and destructive-gap clauses are not checked here (G20, G37).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `gate/G5` |
| Enabled | Yes: runs in every kit gallery shot, in both themes | `test/goldens/kit/kit_gallery.dart` |
| Verified | tests and goldens only | this record |
| Committed | Yes | `gate/G5` (review-fix commit) |
| Deployed | No | |
