# revamp-kit-KitMotionParts: KitSwap, KitSpin, KitAnimatedBox, KitDim, KitAnimatedValue (2026-09-26)

## 1. Scope

- Unit: `kit-KitMotionParts` (wave 1, tier 1a, `kit-part`; cut review C11).
  Finish line: the five motion parts exist in
  `lib/ui/kit/motion/kit_motion_parts.dart`, match the frozen API, states,
  galleries and contract tests. Non-goal: no call site outside the kit
  changes and `lib/ui/kit/kit.dart` is not touched — the G16-baseline
  screens the spec's "Replaces" table lists (`chat/message_view.dart`,
  `chat/empty_chat.dart`, `phone_setup_start_screen.dart`,
  `setup_progress_view.dart`, `chat/composer.dart`, `chat_screen.dart`,
  `review_workspace.dart`, `entrance.dart`, …) are a separate unit's work.
- Files changed (review fix `8bff010c` touches the part, its behaviour
  test, the two `kit_motion_box_outlined_*` goldens and this record):
  `lib/ui/kit/motion/kit_motion_parts.dart` (new),
  `test/kit/kit_motion_parts_test.dart` (new),
  `test/goldens/kit/kit_motion_parts_golden_test.dart` (new), its 54 PNGs
  under `test/goldens/kit/kit_motion_*.png`, and this QA record.
- Pages (map ids): n/a — a `kit-part` unit has no map pages; the spec's own
  "kit-v2.json `assignment`: no element is assigned" line confirms it.
- Specs followed: `docs/ux-system/kit-api/KitMotionParts.md` (the frozen
  API, in full); `docs/ux-system/revamp/STANDARDS.md` §1, §4, §15, §16, §18;
  `docs/ux-system/kit-v2.md` §7, §8.2 (no per-window adaptation: "the same
  on compact, medium, expanded and large"), §8.4 (gallery sizes);
  `docs/design/visual-language-2026-09-26.md` §7 (no fade-scale, MOT-2).
- Contract problems (PROC-20): one, not blocking:
  {rule: `KitMotionParts.md` "Public API" (KitDim doc: "A debug assert fails
  when the child's render subtree contains a paragraph") read with the
  "Replaces" table (`Opacity` → "`KitDim` for images, drawings and marks");
  what it says: KitDim dims marks, and asserts on any `RenderParagraph`
  below it; why wrong: every `Icon`/glyph mark paints through a
  `RenderParagraph` (Icon builds a `RichText` whose one span uses the icon
  font), so KitDim cannot dim an icon mark without failing its own assert
  — the two sentences contradict each other for the commonest "mark";
  evidence: `lib/ui/kit/motion/kit_motion_parts.dart:334` and `:342` (the guard,
  `_paintsNoParagraph`), `test/kit/kit_motion_parts_test.dart:22-33` (the
  test mark avoids `Icon` for this reason) and the gallery's `_imageMark` /
  `_drawingMark` (no glyphs); proposed replacement text (recommended, keeps
  the guard strict): in the Replaces table, "`KitDim` for images and
  drawings. A glyph mark (an `Icon` or `AppGlyph`) is dimmed by
  kit-KitIcon's own dimmed state, never by `KitDim`", and in the KitDim
  doc, "Dims an image or a drawing (Opacity's job) … A debug assert fails
  when the child's render subtree contains a paragraph, including an icon
  glyph"; alternative if the owner wants KitDim to take glyphs: "A debug
  assert fails when the child's render subtree contains a text paragraph;
  a paragraph whose only span is an icon-font glyph (`Icon`) is exempt";
  blocks: false}. The item is left at the frozen behaviour (the guard
  asserts on every paragraph, glyphs included) until the coordinator
  settles it. `KitSwap` now matches the frozen `extends StatelessWidget`
  exactly (the first build shipped `StatefulWidget` without reporting it;
  fixed in `8bff010c`, see §5), so no other contract problem remains.
  Earlier note, still true: The spec's own "Open
  questions" section names one conditional risk — `KitDim` would be a
  PROC-20 contract problem if the pre-wave `KitTokens.staleAlpha` and
  `disabledAlpha` were missing — but both already exist in
  `lib/ui/kit/kit_tokens.dart` (merged by `feat/kit-seams` before this unit
  started), so `KitDim` proceeded with no blocker, per the spec's own
  fallback ("`KitSwap`, `KitSpin`, `KitAnimatedBox` and `KitAnimatedValue`
  go ahead" — `KitDim` too, once checked). One non-blocking process note:
  the workflow task's own text names the QA path as
  `docs/qa/revamp-<unit id>/README.md`, but STANDARDS.md EVID-1 (and every
  sibling unit already on this branch, e.g. `kit-KitDivider`,
  `kit-KitAskLine-look`) uses a dated folder,
  `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/README.md`. Followed STANDARDS
  (the dated form, matching siblings) rather than the shorter form the task
  text gives, since STANDARDS is named the one rulebook and the dated form
  is what the rest of the branch already does.
- New kit parts (KIT-3): `KitSwap`, `KitSpin` (with `.fixed` and `.chevron`),
  `KitAnimatedBox`, `KitDim`, `KitAnimatedValue` — all named by this unit's
  own frozen spec, none of the reserved planned-part names (R13).
- Map items (EVID-11): n/a — no pages, no `actionsMissing`/`statesMissing`/
  `couldBeAutomatic` items apply.
- States per page (STATE-20): n/a. Per the frozen spec's own "States"
  section, the only states are per-part ("at rest and changing", `KitDim`
  dimmed × stale/disabled, `KitSpin.chevron` expanded/folded,
  `KitAnimatedValue` settled/easing/jumped); "Loading, empty, error, working
  and answered belong to the hosts." Covered by the contract tests below,
  not a page's STATE-20 table.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitMotionParts`, base
  `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4` (`feat/phone-setup-v2`), code
  head `8bff010c` (review fix on top of the first build `e14769a6`).
- No APK (unit agents do not build; R19/R20 reserve device and build proof
  for the coordinator).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only (TEST-2): n/a — every file here is new, nothing here reverts a prior regression. Two implementation bugs were caught and fixed by these same tests while writing them (see §5): `KitSwap`'s `_key` was a lazily-`late` field read for the first time inside `didUpdateWidget`, where `widget` already is the new child, so the very first swap compared a key against itself and never animated; and the "KitSpin animates" test's own assumption (`AnimatedRotation.turns` is the target, not the interpolated value) was wrong, not the part. Both were caught by "a keyed change cross-fades …" and "KitSpin(turns: .5) animates" failing before the fix and passing after. | n/a | n/a | N/A |
| 2 | `test/kit/kit_motion_parts_test.dart` | passes | 36 passed | PASS |
| 3 | `test/goldens/kit/kit_motion_parts_golden_test.dart --update-goldens` | generates 54 PNGs plus 22 non-golden G6 checks, each PNG looked at | 76 passed, each PNG opened and reviewed (§5) | PASS |
| 4 | `test/goldens/kit/kit_motion_parts_golden_test.dart`, no `--update-goldens` (deterministic re-run) | passes with the just-reviewed goldens, including the G5 accessibility check on every shot | 76 passed | PASS |
| 5 | `flutter analyze lib test` | no errors; no new issues in changed paths | `No issues found!` (22.6 s) | PASS |
| 6 | `test/kit_ratchet_test.dart` + `test/design_standard_test.dart` | pass | 47 passed (one round-trip: G21's kit stroke-width check first failed on `BorderSide(width: width)` — a parameter, not `KitTokens.hairlineWidth(context)` written at the call site — fixed by inlining the token call; see §5) | PASS |
| 7 | `test/l10n_coverage_test.dart` + `test/ui_glossary_test.dart` + `test/ui_ledger_coverage_test.dart` | pass | 25 passed | PASS |
| 8 | Review fix, fails first (TEST-2): the new behaviour tests run against the part at `e14769a6` | the three new tests fail | "leaving child keeps its state" got `['init', 'init', 'dispose']` (the leaving child re-initialised), "a change mid-swap" found no `box-a` (the first leaving child vanished at once), "turning outlined on and off" got `Size(96.3, 56.3)` mid-change (layout lerped through fractional pixels); `failing-first.txt` | FAIL as expected |
| 9 | Review fix: `test/kit/kit_motion_parts_test.dart` at `8bff010c` | passes | 40 passed | PASS |
| 10 | Review fix: `test/goldens/kit/kit_motion_parts_golden_test.dart` without `--update-goldens` | only the outlined box changes | `box_outlined` dark and light failed (the box no longer grows by 2/dpr); both re-rendered with `--plain-name "box_outlined ("`, opened and compared, then the whole file re-run: 76 passed | PASS |
| 11 | Review fix: `test/kit_ratchet_test.dart` + `test/design_standard_test.dart`; `flutter analyze lib test` | pass, clean | 47 passed; `No issues found!` | PASS |

## 5. Evidence

- `failing-first.txt` (review fix): the three new behaviour tests run
  against the first build's part (`e14769a6`), showing each defect the
  review found (Run 8). The first build's own development bugs (Run 1)
  predate any commit and have no captured "before".
- Review fix (`8bff010c`), what changed and why:
  - `KitSwap` rebuilt the leaving child from scratch: its unkeyed `Stack`
    went from `[FadeTransition(A)]` to `[IgnorePointer(…(A)),
    FadeTransition(B)]`, so the framework matched B onto A's element and
    inflated a new element and `State` for A (initState ran again, timers
    and fetches restarted, text fields went blank while fading). It is now
    the frozen `StatelessWidget` over `AnimatedSwitcher` (which keys each
    entry), with one private `_KitSwapLayer` per child whose
    `IgnorePointer`/`ExcludeSemantics` are always in the tree and only
    flip on when the child's animation turns to reverse. A change during a
    swap reverses each leaving entry from where it is. Curves:
    `KitMotion.enter` in, `KitMotion.exit.flipped` out (the switcher runs
    a leaving entry in reverse; same pairing as `KitReveal`).
  - `KitAnimatedBox` put the edge on the background `ShapeDecoration`, and
    `Container` pads its child by that decoration's insets, so turning
    `outlined` on grew a hugging box by 2/dpr and lerped it over `pace`
    (layout animation, and fractional pixels mid-change). The fill is now
    a side-less shape and the edge a `foregroundDecoration` (never padded)
    with a constant `KitTokens.hairlineWidth(context)` side whose colour
    fades between transparent and `hairline`.
  - Tests now read what is painted, not widget fields: `_paintedOpacity`
    multiplies the render tree's opacity objects above a child;
    `_paintedTurns` reads the child's paint transform to the screen;
    semantics are read from the live semantics tree. Added: a
    `KitPace.standard` swap settling at exactly `KitMotion.standard`; the
    chevron's painted turn in LTR and RTL sampled every 50 ms against
    `KitMotion.emphasized` and settling at `KitMotion.standard`;
    initState/dispose counts across a swap; an interrupted swap; a
    constant size and child offset while `outlined` toggles; the outline
    measured from the painted ring (`drawDRRect`, 0.5 logical px at
    DPR 2).
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | First build is final (no mount animation), all 5 parts | `test/kit/kit_motion_parts_test.dart` group "first build is final (no mount animation)" | Run 2 |
  | Instant under system reduced motion and Effects › Animations: Off (MOT-7, G8) | `test/kit/kit_motion_parts_test.dart` group "reduced motion settles after one pump() (G8, MOT-7)", 6 parts × 2 switches | Run 2 |
  | `KitSwap`: cross-fade over exactly `KitMotion.quick` or `standard`, both children painted part-way, constant size, no scale/size widget inside its own subtree, outgoing ignores taps and is absent from the live semantics tree | `test/kit/kit_motion_parts_test.dart` "a keyed change cross-fades over exactly quick (150 ms)…" and "…standard (250 ms)…" | Run 9 |
  | `KitSwap`: the leaving child keeps its element and State; a change mid-swap fades each leaving child on from its current opacity | `test/kit/kit_motion_parts_test.dart` "the leaving child keeps its state until it has faded out", "a change mid-swap fades each leaving child on from its current opacity" | Run 8 (fails before), Run 9 |
  | `KitSpin(turns: .5)` paints part-way round then half a turn, layout unchanged; `.fixed` swaps width/height; `.chevron` paints upright folded and half a turn open under LTR and RTL, following `emphasized` over `KitMotion.standard` | `test/kit/kit_motion_parts_test.dart` group "KitSpin" | Run 9 |
  | `KitAnimatedBox`: level change and `outlined` toggle animate paint only (constant `RenderBox` size and child offset), child size change snaps in one frame, the painted edge is `1/dpr` | `test/kit/kit_motion_parts_test.dart` group "KitAnimatedBox" | Run 8 (outline toggle fails before), Run 9 |
  | `KitDim`: debug assert fails over a `KitText` child; the settled painted opacity is `disabledAlpha`/`staleAlpha`/1 | `test/kit/kit_motion_parts_test.dart` group "KitDim" | Run 9 |
  | `KitAnimatedValue`: first value at once, 0.2→0.8 eases over `standard`, `jump: true` resets at once | `test/kit/kit_motion_parts_test.dart` group "KitAnimatedValue" | Run 2 |
  | `pumpAndSettle` completes for every part (nothing loops) | one "pumpAndSettle completes (nothing loops)" test per part group | Run 2 |
  | No `Duration(` literal, no `Curves.` in the source (MOT-1) | `test/kit/kit_motion_parts_test.dart` "no Duration( literal and no Curves. in kit_motion_parts.dart (MOT-1)" | Run 2 |
  | G4 galleries at the §8.4 sizes, dark and light, plus 2.0 text and Arabic for swap/spin at two sizes | `test/goldens/kit/kit_motion_parts_golden_test.dart` | Run 3/4 |
  | G5 accessibility (tap targets, contrast, reading order) on every gallery shot | `test/goldens/kit/kit_motion_parts_golden_test.dart` (built into `kitGalleryPart`) | Run 3/4, no baseline entry needed |
  | G6 overflow matrix (no images): every part at 320 dp width, 2.0 text, both directions | `test/goldens/kit/kit_motion_parts_golden_test.dart` group "G6 overflow matrix (no images)" | Run 3/4 |
  | G21 (LOOK-21): `KitAnimatedBox`'s outline reads `KitTokens.hairlineWidth(context)` at the `BorderSide` call site, not through a variable | `test/kit_ratchet_test.dart` "G21 look and motion: numbers and effects come from the kit" | Run 6 |

- Changed test expectations (TEST-19): none — every file here is new.
- Bugs the tests caught and their fixes, before this commit (development
  history, not a shipped regression):
  - `KitSwap`'s outgoing-child key was stored in a `late Key _key =
    _keyOf(widget.child);` field initializer, never read from `build()`.
    Since nothing forced it to evaluate at mount, its first read happened
    inside the very first `didUpdateWidget`, where `widget` already refers
    to the *new* child — so the field's own lazy initializer computed the
    new key too, comparing it to itself and always finding "no change".
    Fixed by setting `_key` explicitly in `initState()`. Caught by "a keyed
    change cross-fades …" going from `hasRunningAnimations: false` (bug) to
    `true` (fixed) right after the first swap.
  - The "KitSpin(turns: .5) animates" test asserted a mid-flight
    `AnimatedRotation.turns` value was not yet `.5`; that field is the
    *target* `AnimatedRotation` is animating to, not the interpolated
    value (which lives in its own private state), so the assertion was
    checking the wrong thing and always failed. Replaced with a check on
    `hasRunningAnimations` mid-flight plus the settled value, which is what
    "animates" actually means here.
  - The first "no Scale/Size/Transform" check in the `KitSwap` test looked
    at the *whole* widget tree and found a `ScaleTransition` that belongs
    to `MaterialApp`'s own Android zoom route transition (paused, unrelated
    to `KitSwap`). Scoped the finders to `find.descendant(of:
    find.byType(KitSwap), …)`.
  - The same test's semantics check ("b" findsOneWidget) ran at t = 0 right
    after the swap started, where the incoming `FadeTransition`'s opacity
    is exactly 0 and `FadeTransition` excludes a fully transparent subtree
    from semantics by default — looking like KitSwap's own exclusion logic
    but actually just the normal one-frame gap. Advanced a small amount of
    real time (30 ms) before checking.
- Goldens changed in the review fix: `kit_motion_box_outlined_{dark,light}.png`
  only. Old and new were cropped and compared at 4×: the hairline ring is
  unchanged in weight and colour, and the box is now exactly 96×56 (it was
  96⅔×56⅔, the child padded by the edge). Every other motion golden
  matched unchanged, including all `swap` shots (settled frames look the
  same over `AnimatedSwitcher`).
- Goldens in the first build (all new; each opened and looked at before committing):
  - `kit_motion_swap_{before,after}_{dark,light}.png` (412×915): a status
    pill ("Sending…" / "Sent") on `surface2`. First render used
    `KitTextRole.secondary` and failed G5's contrast check on
    `swap_before` in one theme pass (1.66:1); switched to
    `KitTextRole.rowTitle` (text1), which reads clearly in both themes.
  - `kit_motion_spin_chevron_{closed,open}_{dark,light}.png`,
    `kit_motion_spin_fixed_{dark,light}.png` (412×915): a labelled row with
    the chevron closed/open, and a terminal glyph rotated a quarter turn.
    Confirmed the chevron points down when closed and up when open, and the
    fixed glyph is genuinely sideways, not just rotated in place.
  - `kit_motion_box_{default,surface1,surface2,surface3,outlined}_{dark,light}.png`
    (412×915), plus `box_default` at the four other §8.4 sizes: a rounded
    panel at each fill level, and the outlined variant with a hairline
    border and no fill. Confirmed the outline reads as a genuine hairline,
    not a doubled or blurred edge, at DPR 3.
  - `kit_motion_dim_{stale,disabled}_{dark,light}.png` (412×915): a filled
    tile ("an image") and a painted circle ("a drawing") side by side,
    dimmed at each level. Confirmed the disabled example is visibly dimmer
    than the stale one (`disabledAlpha` .38 vs `staleAlpha` .6).
  - `kit_motion_value_{030,080}_{dark,light}.png` (412×915): a track and a
    fill bar. First render was blank — both `DecoratedBox`es were bare
    inside a `Stack`, which gives non-positioned children with no
    intrinsic size a size of zero, so nothing painted. Fixed by wrapping
    each in `Positioned.fill`. Confirmed the fill now reads as roughly 30 %
    and 80 % of the track.
  - `kit_motion_swap_after_{ar,text2}_*.png`,
    `kit_motion_spin_chevron_open_{ar,text2}_*.png` at 412×915 and
    1280×800: Arabic (right to left, Arabic label) and 2.0 text. Confirmed
    the chevron still points the same way under RTL (it is direction-free,
    as the spec requires) and the pill/row grow with the larger text
    without clipping.
  - No approved VL canvas render exists yet for this part (EVID-12): none.
- Before and after (EVID-10): n/a — new kit part, no existing page or
  golden changes; nothing was migrated onto it in this unit.
- Accessibility: `KitSwap`'s outgoing child is excluded from semantics
  (verified on the live semantics tree: the leaving label is absent while
  it fades, the arriving one present) and ignores pointer events (verified: a tap over its
  bounds, away from the incoming child's, calls back nothing); `KitDim`
  changes no semantics of its own; `KitSpin.chevron` is decorative (the
  host owns the `expanded` semantics state, not tested here — it is the
  host's job per the spec); every gallery shot passed
  `androidTapTargetGuideline`, `labeledTapTargetGuideline`,
  `textContrastGuideline` and the reading-order check with no new baseline
  entries (`test/goldens/kit/kit_gallery_g5_baseline.json` unchanged).
- Privacy and security: n/a — no credentials, stored data, links or
  notifications are touched by motion primitives.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_motion_parts_test.dart
$F test -j 1 test/goldens/kit/kit_motion_parts_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart
$F test -j 1 test/l10n_coverage_test.dart test/ui_glossary_test.dart test/ui_ledger_coverage_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator (R19/R20: coordinator work).
- Not exported from `kit.dart` (R06: the integrator's row) — so none of the
  five parts is reachable from any real screen yet, and the G8x
  reduced-motion ratchet (`test/kit_motion_test.dart`) and the G6 overflow
  matrix's own registry (`test/kit/kit_overflow_scenes.dart`) will not pick
  them up until that export lands; this unit's write set does not include
  either shared file, so its own `test/kit/kit_motion_parts_test.dart` and
  golden file carry the equivalent checks (reduced motion, overflow at
  narrow width/2.0 text/RTL) directly instead.
- No call site migrated (R14 non-goal, and this unit's own non-goal): the
  59-site G16 baseline the spec's "Replaces" table lists still stands;
  `KitEntrance`'s own class (`EntranceReveal` in `lib/ui/widgets/entrance.dart`)
  is untouched, as the spec requires (its file is outside this write set).
- No live-server or Paseo checks apply to a pure UI kit part; none run.
- Copy (COPY-1): no new user-facing strings were added — every part in
  this unit carries no text of its own (the host supplies and is
  responsible for any words, per the spec's Accessibility section), so
  nothing changed in `app_en.arb`/`app_ar.arb` and `gen-l10n` was not
  re-run. The gallery and overflow tests' demo copy ("Sending…", "Sent",
  "Show details", the Arabic equivalents) is test-only fixture text, not
  app copy, matching the existing pattern in
  `test/goldens/kit/kit_foundation_golden_test.dart`.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitMotionParts` |
| Enabled | No: not exported from `kit.dart` yet (R06) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `8bff010c` (review fix; first build `e14769a6`) |
| Deployed | No | |
| Released | No | |
