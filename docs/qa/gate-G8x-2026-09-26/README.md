# Gate G8x: kit parts are still under reduced motion (2026-09-26)

Branch `gate/G8x`, from `feat/phone-setup-v2` at `9220f070`.

## What the gate checks

This gate enforces **MOT-7**: under the system's remove animations, and
under Settings › Appearance › Animations: Off, every kit part settles after
one `pump()` with no ticker running. It also carries out the §0.5 step 3
direction for G8x: the gate reads the `kit.dart` manifest, so kit units
never edit this test (PROC-13).

| File | Role |
|---|---|
| `test/kit_motion_test.dart` | Reads the manifest and checks coverage. Holds the samples for the parts that predate the gate. |
| `test/kit/kit_motion_still.dart` | The shared check. `kitMotionStillTests('<Part>', builds: {...}, opens: {...})` registers one test per sample for each stillness mode. `KitStill.system` sets `MediaQuery.disableAnimations`. `KitStill.effectsOff` sets `KitEffects(motion: KitMotionLevel.off)`. |
| `test/kit_motion_baseline.json` | The ratchet. It lists the pre-gate samples that still move today, and it may only shrink. |

### How parts are found

1. The test parses `lib/ui/kit/kit.dart` and follows its `export` lines, including nested re-exports, `part` files and `show`/`hide` lists.
2. It collects every public class that is a widget (its superclass chain reaches a `…Widget` or `Inherited*` base, including through other kit classes). It also collects every `KitScene` subclass and every top-level `showKit…` function.
3. Today this gives 43 parts. Data, tokens, controllers and builders are not parts, for example `KitAction`, `KitTokens`, `KitDraft`, `KitEffects` and `KitPageTransitionsBuilder`. Unexported widgets, such as `GatedRow` and `TerminalKeyBar`, are not parts either.

### What each sample test does

Each sample is either a widget or a modal opened with `showKit…`. The test:

1. pumps the sample at 412×915;
2. runs one `pump()`;
3. expects no exception and `hasRunningAnimations == false`;
4. for a modal, also expects that a route was pushed.

### Manifest assertions

These fail loudly:

- **The parser still works.** Known parts are found, and known non-parts are not.
- **Every manifest part has a registration.** Each part needs a `kitMotionStillTests('<Part>', …)` call in some `test/**/_test.dart`. A new part puts that call in its own `test/kit/kit_<snake>_test.dart`.
- **`kit_motion_test.dart` registers only pre-gate parts.** They are listed in the frozen `_predatesG8x` set, so a new part cannot be added here.
- **Registrations name exported parts only.**
- **The ratchet names only pre-gate parts.** Each entry is well-formed and names a sample that exists. A part added after the gate starts at zero.

## Rule ids

MOT-7 (enforced). PROC-13 (the per-part test list is manifest-driven, and the baseline only shrinks).

## Pass on today's code

```
$ tool/qa/machine_lock.sh test -- $F test -j 1 test/kit_motion_test.dart
00:04 +134: All tests passed!
$ tool/qa/machine_lock.sh analyze -- $F analyze test/kit_motion_test.dart test/kit/kit_motion_still.dart
No issues found!
```

The run has 134 tests:

- 5 manifest tests;
- 126 sample tests (the 43 parts, each sample under both stillness modes);
- 3 sanity tests: with motion on, `KitStatusMark` working spins (so the samples do exercise motion), and under each stillness mode it shows its still dot instead.

## Baseline (ratchet)

The table marks G8x as absolute, but today's code does not comply: every indeterminate progress indicator in the kit keeps spinning under reduced motion. Nine samples, each failing in both modes, give **18 baselined entries**:

| Part | Sample | Cause |
|---|---|---|
| KitActionBlock | working | the `KitButton` spinner |
| KitButton | primary working, secondary working | `CircularProgressIndicator` in the spinner slot |
| KitConfirmSheet | working | the `KitButton` spinner |
| KitLoadingBar | loading | indeterminate `LinearProgressIndicator` |
| KitProgressView | waiting | indeterminate `LinearProgressIndicator` |
| KitScreen | loading | `KitLoadingBar` |
| KitSheet | loading | `KitLoadingBar` |
| KitStateView | working | `KitProgressView` waiting |

A baselined sample still has to render without an exception. When one of these samples starts to settle, the test prints the lowered list, for example:

```
G8x ratchet: "KitChevron / default / system" now settles. Lower test/kit_motion_baseline.json to:
{ "stillMoving": [ ... ] }
```

The fix belongs to whoever owns these kit files. The pattern is the one `KitStatusMark` already uses: a still mark under `KitMotion.reduced`.

## Fail on violation (throwaway fixtures, all removed)

**1. A new part is exported but not registered.** A temporary `lib/ui/kit/kit_zzz_spinner.dart` (a bare `CircularProgressIndicator`) was exported from `kit.dart`:

```
manifest every kit.dart part has reduced-motion samples (G8x)
  Expected: empty
    Actual: [KitManifestPart:KitZzzSpinner (widget, lib/ui/kit/kit_zzz_spinner.dart)]
  Each part kit.dart exports needs kitMotionStillTests('<Name>', ...) in its own test/kit/kit_<snake>_test.dart (test/kit/kit_motion_still.dart shows how).
```

**2. The same part registers itself in its own test but still spins.** With a temporary `test/kit/kit_zzz_spinner_test.dart`, the manifest check passes and the behaviour check fails:

```
KitZzzSpinner (MOT-7) default settles at once under system
Expected: false
  Actual: <true>
KitZzzSpinner default under system: 1 frame callback(s) still scheduled: a ticker or animation is running after one pump()
... under effectsOff [E]
```

**3. A pre-gate part regresses, and a new part is slipped into the baseline.** `KitStatusMark` was temporarily changed to ignore `KitMotion.reduced`, and `"KitZzzSpinner / default / system"` was added to the baseline. The run had 7 failures:

```
"KitZzzSpinner / default / system": a part added after G8x starts at zero and is never baselined (PROC-13)
KitStatusMark working under system: 1 frame callback(s) still scheduled ...
KitStatusMark working under effectsOff: 1 frame callback(s) still scheduled ...
KitTaskMark working under system / effectsOff: ... (it draws KitStatusMark)
KitStatusMark working shows its still dot under system / effectsOff: found CircularProgressIndicator
```

**4. A new part is registered inside `kit_motion_test.dart`.** A `kitMotionStillTests('KitNewPart', …)` line was added to this file:

```
manifest this file registers only the parts that predate G8x
    Actual: Set:['KitNewPart']
  A new part registers its samples in its own test file, not in kit_motion_test.dart (PROC-13).
manifest registrations name parts kit.dart exports
    Actual: Set:['KitNewPart']
```

In the same run, adding a settling sample (`KitChevron / default / system`) to the baseline printed the lowered-baseline message shown above.

After each proof the fixtures were removed, and `lib/` was restored with `git checkout`. The final clean run is the pass shown above.

## Notes for the integrator

- G4 (`test/kit/kit_manifest_test.dart`) is being built separately. Until it exists, this gate parses `kit.dart` itself. Once G4 exports a manifest reader, `readKitManifest()` here can be replaced with it.
- G14x and G6 can reuse the same registration pattern.
- No `lib/` change was made. Fixing the 18 baselined samples is kit-owner work, covered by rules MOT-7 and MOT-5.
