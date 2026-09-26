# revamp-kit-KitSegmented: KitSegmented, the row-form single choice (2026-09-26)

## 1. Scope

- Unit: `kit-KitSegmented` (wave 1, tier 1d, `kit-part`). Finish line: `KitSegmented` in `lib/ui/kit/kit_segmented.dart` matches its frozen API and renders every scene the spec names, with its galleries and behaviour tests. Non-goal: no local `KitChoiceRow` substitute, and no screen migrates to it (wave 2).
- Fix: review round 1 (11 findings). Fixed here: 3 (keyboard-only ring, no focus on tap, ring as a foreground decoration), 4 (no InkWell: no splash or theme overlays, token fills only, real taps settle under reduced motion), 5 (const `StatelessWidget` as declared; the selected check is a build-time assert), 7 (Tab re-enters on the selected segment), 8 (behaviour-based tests), 9 (G6 matrix for the row form), 11 (record path in the comments), and the first half of 2 (the text-2.0 baselines are dropped). Settled by a higher rule instead of the finding: 6 (see Contract problems). Held on dependencies (PROC-32): 1, the second half of 2, the stacking half of 9, and 10.
- Files changed: `lib/ui/kit/kit_segmented.dart`, `test/kit/kit_segmented_test.dart`, `test/goldens/kit/kit_segmented_golden_test.dart`; PNGs: `kit_segmented_default_text2_{dark,light}.png` and `kit_segmented_default_text2_1280x800_{dark,light}.png` deleted, `kit_segmented_counts_{dark,light}.png` renamed to `kit_segmented_with_counts_{dark,light}.png`; this record and `failing-first.txt`.
- Pages (map ids): none. This unit builds the part only (non-goal: "No migration of call sites (wave 2)").
- Specs followed: docs/ux-system/kit-api/KitSegmented.md (frozen API); kit-v2.md §1.6, §8.2; KitTappable.md's hover, pressed and focus-ring rules (README.md decision D11), which KitSegmented.md's "Fine pointer" points to; STANDARDS.md KIT-12, KIT-24, LOOK-6, LOOK-15, LOOK-21, STATE-8, STATE-9, MOT-2, MOT-5, MOT-7, MOT-11, A11Y-1, A11Y-2, A11Y-3, LAY-4, LAY-9, LAY-10, LAY-11, DATA-11, G6, G8, G21, G37, PROC-20, PROC-32; Appendix A #78.
- Contract problems (PROC-20):
  - {rule: KitSegmented.md "States" ("The doc comment declares: `default`, `with-counts`, `segment-disabled`, `disabled`, `stacked`") vs STANDARDS.md KIT-12 (a part declares its states "from {loading, empty, error, disabled, working, answered}") and G4. Why wrong: G4 rejects any other name, so the spec's line would fail the gate with "unknown states default, with-counts, segment-disabled, stacked". Evidence: `test/kit/kit_manifest_test.dart:77` (`kitManifestStates`) and `:1095`–`:1097` (the "unknown states" failure). §0.2 settles it (STANDARDS ranks above the kit-api page), so the `States:` line stays `States: disabled.` and the doc comment names the five scenes in a separate sentence. The galleries render each scene except stacked (held, below), under names that match the scenes (`kit_segmented_with_counts_*`, `kit_segmented_segment_disabled_*`). Proposed text for KitSegmented.md "States": "The doc comment declares `States: disabled.` (KIT-12). The gallery also renders the scenes default, with-counts, segment-disabled and stacked." blocks: false.}
  - {rule: KitSegmented.md "Public API" (`const KitSegmented({...}) : assert(segments.length >= 2 && segments.length <= 4), ...`). Why wrong (minor): `List.length` is not a constant expression, so with the spec's own assert a `const KitSegmented(...)` call can never compile ("The property 'length' can't be accessed on the type 'List<…>' in a constant expression", `const_eval_property_access`). The `const` keyword can be declared but not used, just as with Flutter's `SegmentedButton`. The build keeps `const` as declared, and callers write `KitSegmented(...)`. Evidence: a pure-Dart reproduction with the pinned SDK (`dart analyze` on a class with the same initializer, invoked as `const`). Proposed text: add "(`const` is declared for subclasses and lints; the length assert means call sites are never `const`)". blocks: false.}
  - {rule: kit.dart export/doc row, STANDARDS.md PROC-13 ("kit.dart: add exactly one export line and one doc-table row per new part") vs this unit's dispatch, R06 ("Shared files you never stage: lib/ui/kit/kit.dart … the integrator adds exports"). Evidence: `docs/ux-system/revamp/STANDARDS.md` PROC-13 vs the dispatch's hard-rules list. Followed R06 and left `kit.dart` untouched; tests import the part by path. Proposed text: PROC-13's kit.dart line should say "the integrator adds it", matching R06. blocks: false.}
  - {rule: G4 gallery/stateScenes scan, `test/kit/kit_manifest_test.dart`'s `_Gallery`. What it does: it recognises a shot only from a literal `kitGalleryShot(name: …)` or a `matchesGoldenFile('literal')` in the part's own gallery file. `kitGalleryPart`, the helper `test/goldens/kit/kit_gallery.dart` recommends for a non-modal part, calls `matchesGoldenFile` inside kit_gallery.dart, so the scan cannot see this gallery. Evidence: §4 Runs #6: `stateScenes · KitSegmented: no 412x915 golden kit_segmented_disabled_…` although `kit_segmented_disabled_{dark,light}.png` exist and pass. Proposed text: `_Gallery` should also recognise `kitGalleryPart(name: kitGalleryName(...), …)` the same way it recognises `kitGalleryShot`. blocks: false.}
- Blockers (PROC-32), both kind `dependency`:
  - **kit-KitChoiceList (`KitChoiceRow`), not merged.** Needed for: the stacked form (KIT-24, Appendix A #78), the fit measurement that chooses it (KitAskLine's approach), removing the ellipsis, test item 5, the stacked gallery (2 PNGs), and the text-2.0 galleries (4 PNGs, which the spec says show the stacked form). Exact change requested: once KitChoiceList merges into the integration branch, rebase this branch and add `_fits(context, share)` (a `TextPainter` measure of check + icon + label + count + insets per segment against `width / n`, plus text scale ≥ 2.0), a `KitChoiceRow` stack for the not-fitting case (same values and keys, disabled reason on the row), Up/Down keys in that form, and delete the `maxLines: 1, overflow: TextOverflow.ellipsis` path.
  - **kit-KitTappable (`KitTappable.tooltip`), not merged.** Needed for the fine-pointer tooltip that repeats the full label when a count or icon shortens it (R23 allows a tooltip only through KitIconButton, KitTerm or `KitTappable.tooltip`; KitIconButton is icon-only and KitTerm is also unmerged). Exact change requested: once KitTappable merges, render each segment through it (which also replaces the GestureDetector/FocusableActionDetector pair built here) with `tooltip:` set when a count or icon is present, and add a hover/keyboard-focus tooltip test.
- New kit parts (KIT-3): `KitSegmented` and its data class `KitSegment<T>`, `lib/ui/kit/kit_segmented.dart`.
- Map items (EVID-11): none. The 25 map elements across 22 pages ("Replaces") migrate in wave 2; no page's map record is owned here.
- States per page (STATE-20): n/a: no page changed.
- Deferred states (STATE-21): the part's own "stacked" scene → needs kit-KitChoiceList's `KitChoiceRow`, owner: this unit once that dependency merges.

## 2. Builds

- Branch `revamp/kit-KitSegmented`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`, code head `832208c553f336167e0f762decc54e955774d084` (first build `bcd1b315`).
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work (R19/R20).

## 4. Runs

All with `F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter`, one file per command through `tool/qa/machine_lock.sh`.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fix: the new `test/kit/kit_segmented_test.dart` against the previous part (`bcd1b315`'s `kit_segmented.dart`) | the review-fix tests fail with assertions | 7 failed, 59 passed: "a tap moves the selection" ×2 (MOT-7, splash ticker), "a selected value not among the segments asserts", "a tap leaves no keyboard focus or ring behind", "leaving the group and coming back lands on the selected segment again" (Expected: Bravo, Actual: Charlie), "hover and press fill with surface steps, never overlays" (a non-token overlay colour), "after a real tap one pump() settles and no ticker runs" (Actual: <true>); see `failing-first.txt` | PASS |
| 2 | `$F test -j 1 test/kit/kit_segmented_test.dart` at code head | all pass | 66 passed | PASS |
| 3 | `$F test -j 1 test/goldens/kit/kit_segmented_golden_test.dart` (no `--update-goldens`) | all pass | 22 passed; the 20 kept baselines are unchanged, and the renamed with-counts pair is byte-identical to the old counts pair (`cmp`) | PASS |
| 4 | `$F test -j 1 test/kit_ratchet_test.dart` (shared, read-only) | passes, 0 counts for this file | 32 passed. On the previous part the same gate failed for this file: G21 "EdgeInsets numeric" ×1 and "stroke width not KitTokens in kit" ×2 | PASS |
| 5 | `$F analyze lib/ui/kit/kit_segmented.dart test/kit/kit_segmented_test.dart test/goldens/kit/kit_segmented_golden_test.dart` | no issues | "No issues found!" | PASS |
| 6 | `$F test -j 1 test/kit/kit_manifest_test.dart` (G4, shared, read-only) | fails only on the recorded causes | fails on `exported` and `docRow` (R06, integrator), `stateScenes` (scanner gap) and `gallery` (the scanner gap for `_ar_`, and a text-2.0 golden that is now absent until the stacked form lands). `states` passes with `States: disabled.` | FAIL (all causes recorded above) |
| 7 | Throwaway probe (not committed): 4 segments with icon and count, 320 and 412 dp, text 1.0/1.3/2.0 | shows whether the row form needs the stack | RenderFlex overflow at every point, including 412 dp at text 1.0 (10 px) | FAIL (expected without the stacked form; see NOT proven) |

Not run: design-standard, l10n, glossary and ledger tests (nothing in this write set touches what they check, and no ARB keys were added); `test/kit_motion_test.dart` and `test/text_scale_overflow_test.dart`, which only discover parts exported from `kit.dart`; a whole-tree `flutter analyze`.

## 5. Evidence

- `failing-first.txt`: output of Runs #1.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | G37 (structural asserts) | `test/kit/kit_segmented_test.dart` "construction (G37)" (5 cases) | Runs #2 PASS |
  | STATE-9 (selection not colour only) | `test/kit/kit_segmented_test.dart` "only the selected segment shows the check glyph", "the check moves with the selection" | Runs #2 PASS |
  | A11Y-1 (group and segment semantics) | `test/kit/kit_segmented_test.dart` "each segment carries button, selected and group semantics", "a disabled segment is announced as not enabled", "the count is included in the segment semantic label" | Runs #2 PASS |
  | STATE-8 (honest disabled reason) | `test/kit/kit_segmented_test.dart` "disabled reasons (STATE-8)" (3 cases) | Runs #2 PASS |
  | LAY-10, LAY-11, G14 (keyboard) | `test/kit/kit_segmented_test.dart` "Tab lands on the selected segment", "the group is one Tab stop", "Arrow Right moves focus without calling onChanged", "arrows skip a disabled segment", "Space calls onChanged…", "Enter calls onChanged…", "in RTL, Arrow Left moves to the next segment", "leaving the group and coming back lands on the selected segment again" | Runs #2 PASS; Runs #1 FAIL on the old part |
  | LOOK-21, LOOK-6 (keyboard-only 2 px accent ring, no layout shift) | `test/kit/kit_segmented_test.dart` "keyboard focus shows the accent ring", "the ring does not move the content", "a tap leaves no keyboard focus or ring behind" | Runs #2 PASS; Runs #1 FAIL on the old part |
  | MOT-2, D11 (surface-step fills, no overlays) | `test/kit/kit_segmented_test.dart` "hover and press fill with surface steps, never overlays", "a hovered unselected segment fills surface2 in dark" | Runs #2 PASS; Runs #1 FAIL on the old part |
  | G8, MOT-7 (reduced motion) | `test/kit/kit_segmented_test.dart` "after a real tap one pump() settles and no ticker runs" plus `kitMotionStillTests('KitSegmented', …)` (4 builds and 2 changes, each under both kinds of stillness) | Runs #2 PASS; Runs #1 FAIL on the old part |
  | LAY-9, G6, A11Y-2 (48 dp, no overflow, row form) | `test/kit/kit_segmented_test.dart` "sizing and overflow (LAY-9, G6)" (24 cases: 4 scenes × text 1.0/1.3/2.0 × LTR/RTL, each at 320, 360, 412, 600, 800, 840, 1280, 1600 dp and 915×412) | Runs #2 PASS |
  | G21 (numbers and strokes from the kit) | `test/kit_ratchet_test.dart` | Runs #4 PASS |
  | TEST-9 (galleries, DPR 3) | `test/goldens/kit/kit_segmented_golden_test.dart`, 22 shots | Runs #3 PASS |

- Changed test expectations (TEST-19), all in this unit's own test files:
  - "the selected segment shows a check glyph": was a private `ValueKey('kit-segmented-check')` plus `AnimatedOpacity.opacity == [0,1,0]`; now the check glyphs painted at an opacity above zero, exactly one, in the selected segment's third of the control (review finding 8; STATE-9, AGENTS.md "Tests assert behavior").
  - "one pump() settles…": was the `InkWell`'s `onTap` called directly to avoid the splash; now a real `tester.tap` on a host that keeps the selection (finding 8; G8).
  - "every segment and the control are at least 48 dp": was `find.byType(InkWell)` at 412×915 only; now semantics rects across the G6 matrix (findings 8 and 9; LAY-9, G6).
  - Keyboard tests: focus was entered by a pointer tap and read by `FocusNode.debugLabel`; now it is entered by Tab and read as the label inside the focused segment, because a tap no longer takes focus (finding 3; LAY-10).
  - "a selected value not among the segments asserts": was an `AssertionError` at construction; now at build (`tester.takeException()`), because the constructor is `const` again (finding 5; G37).
- Goldens changed (each opened and looked at):
  - `test/goldens/kit/kit_segmented_default_text2_dark.png`, `…_text2_light.png`, `…_text2_1280x800_dark.png`, `…_text2_1280x800_light.png`: deleted. They showed the one-row form, but the spec says the text-2.0 scenes show the stacked form (finding 2). Approved render: no approved render.
  - `test/goldens/kit/kit_segmented_with_counts_dark.png`, `…_light.png`: renamed from `kit_segmented_counts_*` to match the with-counts scene name. The bytes are identical and both were opened: "All · ✓ Needs you 2 · Done", check in accent before the label, count after it, selected segment on surface3. Approved render: no approved render (there is no `docs/design/visual-language-2026-09-26` render for this part).
  - The branch now carries 22 PNGs (TEST-20: ≤ 60). The spec asks for 28; the 6 missing are the held stacked and text-2.0 scenes.
- Before and after (EVID-10): n/a: no page changed. This is a kit part, not a screen revamp.
- Accessibility: group semantics (`semanticsLabel`) and, per segment, `button`, `selected`, `inMutuallyExclusiveGroup` and `enabled`, with a label that includes the count ("Bravo, 2"). Checked by `matchesSemantics`. 48 dp targets and no overflow are checked at every LAY-4 overflow size, at text 1.0, 1.3 and 2.0, LTR and RTL, for the four row-form scenes. Keyboard: one Tab stop that enters on the selected segment, arrows that follow the reading direction, and Space/Enter to choose. The focus ring shows only for keyboard focus. Arabic RTL is in the galleries (`kit_segmented_default_ar_*`). Text 2.0 with long or many labels needs the stacked form (NOT proven).
- Privacy and security: n/a: no credentials, stored data, external links or notifications. The part is local UI only.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F analyze lib/ui/kit/kit_segmented.dart test/kit/kit_segmented_test.dart test/goldens/kit/kit_segmented_golden_test.dart
$F test -j 1 test/kit/kit_segmented_test.dart
$F test -j 1 test/goldens/kit/kit_segmented_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart
# failing-first: put the previous part back, run the new tests, restore
git show bcd1b315:lib/ui/kit/kit_segmented.dart > lib/ui/kit/kit_segmented.dart
$F test -j 1 test/kit/kit_segmented_test.dart   # 7 fail
git checkout -- lib/ui/kit/kit_segmented.dart
```

## 7. NOT proven

- Not run on a device or emulator (coordinator work, R19/R20).
- **The stacked form does not exist (blocked on kit-KitChoiceList, PROC-32).** The part always renders one row, and a label that does not fit is cut with an ellipsis, which the spec forbids ("Nothing truncates"). Missing because of it: the fit measurement, test item 5, Up/Down keys in the stacked form, the stacked gallery and the four text-2.0 galleries. Worse than truncation: a row of **4 segments with icons and counts overflows (a RenderFlex error) at 320 dp and even at 412 dp, text 1.0** (Runs #7). The G6 matrix here covers only the four spec scenes (3 short segments), which fit. No host should use 4 icon-and-count segments until the stack lands.
- **The fine-pointer tooltip is not implemented (blocked on kit-KitTappable, PROC-32).**
- Hover is tracked with a `MouseRegion`, which fires only for pointers that can hover. It is not gated on `KitLayout.finePointer` as KitTappable.md words it; the result is the same for mouse and trackpad. A stylus that hovers would also show the fill (not tested).
- The hover and pressed fills change at once. KitTappable.md cross-fades them on `quick`, but KitSegmented.md does not ask for that. They are instant under reduced motion either way.
- `test/kit/kit_manifest_test.dart` (G4) still fails for this part: two causes belong to the integrator (R06), one is the recorded scanner gap, and the missing text-2.0 golden is held. `test/kit_motion_test.dart` and `test/text_scale_overflow_test.dart` will not see the part until `kit.dart` exports it.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Partial (PROC-32: blocked on kit-KitChoiceList for the stacked form and on kit-KitTappable for the tooltip; everything else in the frozen spec is implemented) | `revamp/kit-KitSegmented` |
| Enabled | No: not exported from `kit.dart` yet (R06, integrator step) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `832208c553f336167e0f762decc54e955774d084` |
| Deployed | No | |
| Released | No | |
