# gate-G8x: kit parts are still under reduced motion (2026-09-26)

## 1. Scope

- Unit: gate `G8x` (§18, W1, test gate). Finish line: `test/kit_motion_test.dart` reads the G4 `kit.dart` manifest and fails when an exported part does not settle after one `pump()` under the system's "remove animations" or Effects › Animations: Off. This covers the first mount and every registered state change, and every drawing must show its finished frame. Non-goal: fixing the kit parts that violate MOT-7 today. That is `lib/` work, which gate builders do not do.
- Files changed: `test/kit_motion_test.dart`, `test/kit/kit_motion_still.dart`, `test/kit_motion_baseline.json`, and this folder. `test/kit/kit_manifest_test.dart`, its allowlist and its QA folder come from the merge of `gate/G4` (see Builds) and are not edited here.
- Pages (map ids): none (a test gate).
- Specs followed: STANDARDS.md MOT-7 (enforced), PROC-13 (manifest-driven per-part list, shrink-only baseline), PROC-20, §0.5 step 3, §16, §18.2 (G4, G8x, G31).
- Contract problems (PROC-20):
  1. **§18.2 "G8x (absolute)".**
     - What it says: G8x is absolute.
     - Why it is wrong: today's code violates MOT-7 in 24 samples of 11 pre-gate parts. The biggest cause is that every indeterminate progress indicator in the kit keeps spinning under reduced motion. An absolute gate therefore cannot pass on today's code. The fix is in `lib/` (`_Spinner` in `lib/ui/kit/kit_buttons.dart`, `KitLoadingBar` and `KitProgressView` in `lib/ui/kit/kit_progress.dart`, `KitRefresh`, `KitRowMenu` and `KitSwitchRow`), and gate builders may not edit `lib/`.
     - Evidence: `test/kit_motion_baseline.json`, `run-pass.txt`, and `lib/ui/kit/kit_buttons.dart:140-176` (`_Spinner` in both slots).
     - Proposed text: "**G8x (ratchet; absolute for parts added after the gate).** `kit_motion_test.dart` iterates the G4 manifest: under `disableAnimations` and under Effects Off each part settles after one `pump()` with no ticker running, on mount and after each registered state change, and each drawing paints its finished frame. Pre-gate samples that still move are listed in `test/kit_motion_baseline.json`, which stays inside the frozen set in the test and only shrinks. A baselined sample that settles fails until it is removed. The kit owners clear it with the `KitStatusMark` still-mark pattern."
     - Blocks: false. The coordinator decides: approve the ratchet and change the wording, or schedule the `lib/` fixes, after which the baseline is emptied.
  2. **§18.2 G31 and PROC-13 "Baselines" do not list `test/kit_motion_baseline.json`.**
     - What they say: G31 watches `kit_ratchet_baseline.json`, `_baseline` and the G2/G7/G17/G21/G24/G26–G29 baselines.
     - Why it is wrong: G8x also has a shrink-only baseline. Inside this test, `_frozenBaseline` stops it from growing, but nothing outside the test does.
     - Evidence: STANDARDS.md §18.2 G31 paragraph, and PROC-13.
     - Proposed text: add "the G8x `test/kit_motion_baseline.json` (`stillMoving`)" to both lists.
     - Blocks: false.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a (no pages).
- States per page (STATE-20): n/a.
- Deferred states (STATE-21): none.

### What the gate checks

| File | Role |
|---|---|
| `test/kit_motion_test.dart` | Imports `readKitManifest` and `KitManifestKind` from `test/kit/kit_manifest_test.dart` (G4) and checks coverage. Holds the samples of the parts that predate the gate, and `_frozenBaseline`. |
| `test/kit/kit_motion_still.dart` | The shared check. `kitMotionStillTests('<Part>', builds:, opens:, changes:)` registers one test per sample for each stillness mode. `KitStill.system` sets `MediaQuery.disableAnimations`; `KitStill.effectsOff` sets `KitEffects(motion: KitMotionLevel.off)`. |
| `test/kit_motion_baseline.json` | The ratchet: 24 pre-gate samples that still move today. It only shrinks. |

**Which parts need samples.** The rule is G4's definition. Every `KitManifestKind.part`, every `KitManifestKind.scene` and every `showKit…` opener needs samples. `KitManifestKind.scope`, the InheritedWidget scopes such as `KitEffectsScope`, draws nothing and needs none.

**Each sample**, under both modes, runs at 412×915 and is checked after exactly one `pump()`:

- **builds**: the widget is pumped. The test then expects that there is no exception, that a widget whose type is the part is in the tree, and that no ticker is running.
- **opens** (`KitMotionOpen(open, shows:)`): the test expects that a route was pushed and that the `shows` text is found, on screen, and not under opacity 0 or an `Offstage`. No ticker may be running.
- **changes** (`KitMotionChange(build:, act:, shows:/hides:)`): the part is pumped and settled. The `act` then changes its state. It can press a control through `stage.press`, which calls the control's callback; pump a new configuration with `stage.rebuild`; or pop a modal with `kitModalDismiss`. After one `pump()`, the part is still in the tree, the `shows` text is visible or the `hides` text is gone, and no ticker is running.
- **drawings**: a scene is sampled as `KitIllustration(scene: KitSceneProbe(scene))`. The probe records the painted frame, and the test expects `entrance == 1` and `looping == false`. This is MOT-7's "every drawing shows its finished frame".

**Pre-gate `changes:` registered.** Every stateful or animated pre-gate part has one:

- KitAnimatedRows: row inserted, row removed.
- KitButton: working ends, with and without an icon.
- KitConfirmSheet: details open.
- KitEntrance: trigger changes.
- KitExpandRow: opens on press, closes on press.
- KitIllustration: ambient turns on.
- KitLoadingBar: loading ends.
- KitProgressView: progress moves.
- KitRefresh: pulled and released.
- KitReveal: child arrives, child leaves.
- KitRowMenu: menu opens.
- KitScreen: loading ends.
- KitSecretField: revealed.
- KitStateView: details open.
- KitStatusMark: working to done.
- KitSwitchRow: switched on.
- KitTabSwitcher: index changes.
- showKitConfirm and showKitSheet: dismissed.

A new stateful part must register its own `changes:`. The header of `kit_motion_still.dart` says so and shows how.

**Manifest assertions:**

1. The G4 manifest is read. Known parts are present, and known non-parts (including `KitEffectsScope`) are absent.
2. Every part that needs samples has a `kitMotionStillTests('<Part>', …)` in some `test/**/*_test.dart`. `//` and `/* */` comments are stripped first, so a commented-out registration does not count.
3. `kit_motion_test.dart` registers only the frozen `_predatesG8x` parts. A new part registers in its own `test/kit/kit_<snake>_test.dart` (PROC-13).
4. The ratchet only shrinks and names real samples. The JSON must be a subset of `_frozenBaseline` (24 keys), and it must have no duplicates. Each key must be `<part> / <sample> / <still>`, where the part is a pre-gate part and the sample is one that this very part registered (checked through `kitMotionSamples`).
5. Registrations name only parts or openers that `kit.dart` exports.
6. A baselined sample must still fail. When one settles, the test **fails** and prints the lowered JSON.

Sanity tests show that the samples exercise motion. With motion on, `KitStatusMark` working spins and `KitExpandRow` animates its opening. Under each mode, `KitStatusMark` working shows its still dot.

### Baseline (ratchet): 24 entries, each in both modes

| Part | Sample | Cause |
|---|---|---|
| KitActionBlock | working | the `KitButton` spinner |
| KitButton | primary working, secondary working | `_Spinner` (`CircularProgressIndicator`) |
| KitConfirmSheet | working | the `KitButton` spinner |
| KitLoadingBar | loading | indeterminate `LinearProgressIndicator` |
| KitProgressView | waiting | indeterminate `LinearProgressIndicator` |
| KitRefresh | pulled and released | `RefreshIndicator`'s own snap and dismiss animations |
| KitRowMenu | menu opens | the popup-menu route fades in; "Rename" is at opacity 0 after one pump |
| KitScreen | loading | `KitLoadingBar` |
| KitSheet | loading | `KitLoadingBar` |
| KitStateView | working | `KitProgressView` waiting |
| KitSwitchRow | switched on | `Switch.adaptive` thumb animation |

The first review counted 18 entries. The 6 new ones came from the new `changes:` samples on this branch before it merged, so they are still part of the initial baseline, not growth.

## 2. Builds

- Branch `gate/G8x`, base `9220f070` (`feat/phone-setup-v2`). It is **stacked on `gate/G4` at `0268e4b2`** (merge `569ba997`), because this gate imports G4's manifest reader. G4 must merge first.
- First build commit `de1787d8`. Code head `b42adb89`.
- No APK (gate agents do not build).

## 3. Devices

None: tests only.

## 4. Runs

Every run used the code head `b42adb89` tree. Each probe was a throwaway change, reverted afterwards with `git checkout` or `rm`, and `git status` was clean afterwards.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit_motion_test.dart test/kit/kit_manifest_test.dart` | pass | 181 passed (179 G8x + 2 G4); G4 prints its 36 `motion` allowlist entries as now passing | PASS |
| 2 | `analyze` on the three test files | no issues | No issues found | PASS |
| 3 | Probe 1: `KitExpandRow`'s `AnimatedRotation` uses plain `KitMotion.standard` (the review's example) | the change samples fail; the mount samples still pass | 4 failed: opens/closes on press × 2 modes (`run-probe1-expand-row.txt`) | PASS |
| 4 | Probe 2: baseline gains `KitChevron / default / system` (also frozen), `KitChevron / working / system` (also frozen) and `KitRow / default / system` (JSON only); `kitMotionStillTests('KitNewPart', builds: {'x': () => const SizedBox()})` is added to this file | fail on growth, on settled entries, on the new registration, on the unexported name and on a sample that renders nothing | 7 failed: "gained keys beyond the frozen G8x baseline", "now settles" × 2, "Set:['KitNewPart']", "does not export", "renders no KitNewPart" × 2 (`run-probe2-ratchet.txt`) | PASS |
| 5 | Probe 3: `KitChevron / working / system` in both the JSON and the frozen set | fail: KitChevron has no such sample | 1 failed: `KitChevron registers no sample "working"` (`run-probe3-foreign-sample.txt`) | PASS |
| 6 | Probe 4: a new exported `KitZzzSpinner`, registered only in `//` and `/* */` comments | fail: missing samples | 1 failed: `['KitZzzSpinner (lib/ui/kit/kit_zzz_spinner.dart)']` (`run-probe4-unregistered-part.txt`) | PASS |
| 7 | Probe 5: `KitZzzSpinner` registered with a `SizedBox` sample and a spinning sample; `showKitSheet` opens registered as a blank dialog and as a dialog whose text is at opacity 0 | all four fail in both modes | 8 failed: "renders no KitZzzSpinner", "frame callback(s) still scheduled", "\"English\" is not shown", "at opacity 0" (`run-probe5-samples-that-lie.txt`) | PASS |
| 8 | Probe 6: `KitIllustration` ignores `KitMotion.reduced` | the drawings fail | 10 failed: "the drawing is not at its finished frame" for KitIllustration, KitPortalScene and KitStateView illustrated (`run-probe6-drawing-frame.txt`) | PASS |

## 5. Evidence

- `run-pass.txt`: step 1. `run-analyze.txt`: step 2. `run-probe1-expand-row.txt` to `run-probe6-drawing-frame.txt`: steps 3 to 8. Absolute paths in these files are rewritten to `<worktree>` and `~`.
- Rule evidence (PROC-31):

  | Rule | Test | Output |
  |---|---|---|
  | MOT-7 (mount) | `test/kit_motion_test.dart` "settles at once under" | `run-pass.txt` |
  | MOT-7 (state change) | `test/kit_motion_test.dart` "changes and settles at once under" | `run-pass.txt`, `run-probe1-expand-row.txt` |
  | MOT-7 (finished frame) | `test/kit_motion_test.dart` KitIllustration, KitPortalScene and KitStateView "illustrated" | `run-pass.txt`, `run-probe6-drawing-frame.txt` |
  | PROC-13 | `test/kit_motion_test.dart` group "manifest" | `run-pass.txt`, `run-probe2-ratchet.txt`, `run-probe3-foreign-sample.txt`, `run-probe4-unregistered-part.txt` |

- Changed test expectations (TEST-19): `test/kit_motion_test.dart` is this gate's own file. The old hand-listed G8 tests are replaced by the manifest-driven samples. The old modal tests asserted "Delete fox?" and "English". The same texts are now each `KitMotionOpen`'s `shows`, which also checks visibility.
- Goldens changed: none.
- Accessibility: n/a (no UI change).
- Privacy and security: n/a (no credentials, stored data, links or notifications).
- Migration: n/a.

### Notes for the integrator

- Merge `gate/G4` before `gate/G8x`. If G4's fix round renames `readKitManifest`, `KitManifest.parts` or `.openers`, or `KitManifestKind`, adjust the import in `test/kit_motion_test.dart`.
- After both merge, G4 prints its 36 `motion` allowlist entries as passing, because this file imports `kit_manifest_test.dart`. Lower `test/kit/kit_manifest_allowlist.json` with `KIT_MANIFEST_WRITE=1` (it is G4's file, so this gate does not edit it).
- A kit unit that clears a baselined sample removes the key from both `test/kit_motion_baseline.json` and `_frozenBaseline`. The test fails until it does.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
git switch gate/G8x && $F pub get
tool/qa/machine_lock.sh test -- $F test -j 1 test/kit_motion_test.dart test/kit/kit_manifest_test.dart
tool/qa/machine_lock.sh analyze -- $F analyze test/kit_motion_test.dart test/kit/kit_motion_still.dart test/kit/kit_manifest_test.dart
# Probe 1 (then: git checkout -- lib/ui/kit/kit_row_parts.dart)
python3 - <<'EOF'
p='lib/ui/kit/kit_row_parts.dart'; s=open(p).read()
s=s.replace("duration: KitMotion.reduced(context)\n                    ? Duration.zero\n                    : KitMotion.standard,", "duration: KitMotion.standard,")
open(p,'w').write(s)
EOF
tool/qa/machine_lock.sh test -- $F test -j 1 test/kit_motion_test.dart -r expanded
# Probe 6: in lib/ui/kit/kit_illustration.dart, change
#   `if (KitMotion.reduced(context) || _skipCelebration) {` to `if (_skipCelebration) {`, run as above, restore.
```

Probes 2 to 5 are the edits described in Runs rows 4 to 7. The exact fixture of probe 5 is `test/kit/kit_zzz_spinner_test.dart`, which registers `builds: {'renders something else': () => const SizedBox(), 'spins': () => const KitZzzSpinner()}` and two `showKitSheet` `KitMotionOpen` entries built with `showDialog`. It needs `lib/ui/kit/kit_zzz_spinner.dart`, a bare `CircularProgressIndicator`, exported from `kit.dart`.

## 7. NOT proven

- Not run on a device or emulator. The full suite was not run, only the three files above.
- **24 samples still violate MOT-7** and are baselined, not fixed (table above). Until the kit owners fix them, no indeterminate progress indicator in the kit is still under reduced motion. The same holds for the pull-to-refresh motion, the row menu's opening and the switch thumb.
- **A real tap's Material ink** (splash and highlight) is not covered. `stage.press` calls the control's callback, because framework ink ignores `disableAnimations` and would keep a ticker running in every tapped sample. Whether ink feedback falls under MOT-7 is for the coordinator.
- **Only the registered state changes are covered.** Not covered: KitButton idle → working (it ends on the baselined spinner); KitConfirmSheet's `action`-driven working; the KitSheet pull-down dismiss (`_PullDown`); KitIllustration celebrations; page transitions (`KitPageTransitionsBuilder` is not a manifest part); and any change a registration does not name.
- **The finished frame is asserted only for drawings sampled through `KitSceneProbe`.** A KitIllustration inside another part is checked only when that sample passes a probe, as KitStateView "illustrated" does. KitRefresh's disc painter is not checked.
- **"Visible" means found, overlapping the 412×915 screen, and not under opacity 0 or an `Offstage`.** A clip, a colour equal to the background, or a scale of 0 would pass.
- **The registration check is static.** A registration inside a skipped group, or in a test file that is never run, still counts.
- Only the dark theme, 412×915 and English were used.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `gate/G8x` |
| Enabled | Yes (runs with `flutter test`) | `test/kit_motion_test.dart` |
| Verified | tests only | this record |
| Committed | Yes | code head `b42adb89` |
| Deployed | No | |
| Released | No | |
