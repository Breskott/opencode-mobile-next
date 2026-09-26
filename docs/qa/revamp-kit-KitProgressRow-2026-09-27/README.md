# revamp-kit-KitProgressRow: a measured amount in a row (2026-09-27)

## 1. Scope

- Unit: `kit-KitProgressRow` (wave 1, tier 2, `kit-part`). Finish line:
  `KitProgressRow` (and `KitProgressRow.segments`) exist in
  `lib/ui/kit/kit_progress_row.dart` exactly to
  `docs/ux-system/kit-api/KitProgressRow.md`'s frozen API (both
  constructors, `KitProgressSegment`), every declared state (loading,
  loaded, near limit, at limit, stale, segments, empty), its adaptive
  behaviour, motion, haptics (none), accessibility (one merged semantics
  node), RTL, data safety and its galleries and behaviour tests. Non-goal:
  no screen adopts it (`lib/ui/kit/kit.dart` is untouched, R06; no screen
  file changed) and no chart beyond one stacked bar.
- Files changed (write set, R08/R09):
  - `lib/ui/kit/kit_progress_row.dart` (new: `KitProgressRow`,
    `KitProgressSegment`, and three private helpers —
    `_ScalarBar`, `_SegmentsBar`, `_Legend`, `_CrossFadeLine`).
  - `test/kit/kit_progress_row_test.dart` (new, 14 tests).
  - `test/goldens/kit/kit_progress_row_golden_test.dart` (new, 16 shots)
    plus its 16 PNGs, all opened and reviewed (TEST-6).
  - `lib/l10n/app_en.arb` (six new keys, prefixed `kitProgressRow*`:
    `kitProgressRowLoading`, `kitProgressRowPercent`,
    `kitProgressRowNearLimit`, `kitProgressRowAtLimit`,
    `kitProgressRowAsOf`, `kitProgressRowOther`); `flutter gen-l10n` run
    once at the end. `app_ar.arb` is **not** touched — owner decision
    2026-09-27 drops Arabic for the revamp (see Contract problems below).
  - `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`,
    `app_localizations_ar.dart`: mechanical `gen-l10n` output from the
    `app_en.arb` edit above (no hand edits).
- Pages (map ids): none directly — this is a `kit-part` unit
  (non-goal: no screen adoption). `docs/ux-system/kit-api/KitProgressRow.md`
  "Replaces" names six page elements (`agent-account-limits`,
  `provider-quota-window`, `session-context-hero`, `usage-total`,
  `usage-totals`, `voice-model-setup-sheet-progress`) and
  `session-context-makeup` (C26, `.segments`) as wave-2 adoption work, out
  of scope here.
- Specs followed: `docs/ux-system/kit-api/KitProgressRow.md` (frozen API,
  in full); `docs/ux-system/kit-v2.md` §1.13 (the part's origin — its
  "attention from 80 %, failure at 100 %" line is superseded by the
  frozen spec's own LOOK-4 discussion, no conflict), §8.2, §8.4, §9.1;
  `docs/ux-system/revamp/STANDARDS.md` §1, §4 (kit idioms), §7
  (motion/haptics), §8.2 (English words), §9 (STATE-4, STATE-9, STATE-18),
  §12, §15 (TEST-9, TEST-15, TEST-20), §16, §18 (G16, G21).
- Contract problems (PROC-20):
  1. **Gallery scope narrowed by a later owner decision, not a spec
     defect.** `KitProgressRow.md`'s own "Galleries required" (and
     STANDARDS TEST-9) ask for the full LAY-4 size matrix plus Arabic and
     2.0-text shots. The computed task for this run states: "Owner
     decision 2026-09-27: Arabic is DROPPED — no Arabic/RTL galleries, no
     Arabic ARB entries for new copy (app_en.arb only), no RTL review.
     Galleries: phone 412x915 and one wide size (1280x800) only, light and
     dark." `STANDARDS.md`'s own header carries the same dated decision
     ("Owner decision 2026-09-27: Arabic is dropped from the revamp …").
     Per R15 (later owner decisions win), this unit's gallery renders the
     seven declared states at 412×915 and the default (loaded) state at
     1280×800, light and dark only (16 PNGs) — no `_ar_`, no `_text2_`,
     no 360×800/915×412/800×1280/1600×1000. Not worked around: this is
     the newer, explicit instruction, not a gap I am filling in. Blocks:
     false — flagged for the record, not a stop.
  2. **`KitProgressRow.segments`'s "Other" value label has no defined
     format.** The frozen spec's States table says the legend "always has
     the words" and Tests item 6 says "the legend lists every label with
     its value label. A fifth segment folds into 'Other'", but nowhere
     defines what the folded "Other" entry's *value label* should say
     (its swatch and name are unambiguous; a summed byte/token count would
     need a format and a unit the spec never gives, and inventing one
     risks an honest-state violation — STATE-18 — for a computed number
     the caller never supplied). Resolution in this unit: "Other"'s
     `valueLabel` is left `null` (the legend row shows the swatch and the
     name only), same as any segment the caller does not give one for.
     Evidence: `test/kit/kit_progress_row_test.dart` "the legend lists
     every label with its value label, and a fifth segment folds into
     Other" pins this. Proposed text: add one sentence to the Purpose or
     Tests section, e.g. "The folded 'Other' segment carries no value
     label; only its swatch and name show." Blocks: false — a spec owner
     wanting a summed number can add the wording and this unit's fold
     logic (`_slices`) changes in one place.
  3. **Which color slot "Other" takes is implicit.** `_new-tokens.md`
     freezes `segmentFills` as `[accent, text2, text3, surface3]` and says
     "'Other' uses surface3", which only resolves cleanly if "Other" is
     always the bar's 4th/last slice and the "hairline edge" note on the
     4th fill exists specifically so two adjacent `surface3` slices (a 4th
     *named* segment and a following "Other") stay legible next to each
     other. Resolution in this unit: at most 4 real segments keep their
     own name and colour (`segmentFills[0..3]`); segment 5 onward always
     folds into one trailing "Other" using `surface3`, with a 1 physical
     px hairline start-edge (`KitTokens.hairlineWidth`) exactly where two
     `surface3` slices could sit side by side. Evidence: the "segments"
     gallery shot and the "fifth segment folds into Other" test. Blocks:
     false.
- New kit parts (KIT-3): `KitProgressRow`, `KitProgressSegment` (this
  unit, per the frozen freeze — not a new, unplanned part).
- Map items (EVID-11): n/a — no page record (see Pages above; wave-2
  adoption is not this unit's non-goal-crossing work).
- States per page (STATE-20): n/a — no page; the part's own seven states
  are in its doc comment and in every gallery/test.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitProgressRow`, base `dcf05c5efbf82781bcfb97b629f5cda86ead2382`
  (`feat/phone-setup-v2` tip at branch time), code head: this branch's
  first (and only) commit.
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fix-round test, `_SegmentsBar`'s `Row` reverted to no `crossAxisAlignment` (the state before the fix) | fails with an assertion, not a crash | failed: `Expected: contains <4.0> Actual: [78.0, 0.0, 12.0]` — `failing-first.txt` | PASS |
| 2 | `test/kit/kit_progress_row_test.dart` (14 tests) | passes | 14 passed — `run-kit-progress-row-test.txt` | PASS |
| 3 | `test/goldens/kit/kit_progress_row_golden_test.dart` (16 shots, `--update-goldens`; every PNG opened and looked at) | passes; G5 accessibility checks (androidTapTarget, labeledTapTarget, textContrast, reading order) pass in both themes for every shot with no new baseline entry | 16 passed — `run-kit-progress-row-golden-test.txt` | PASS |
| 4 | `test/kit_ratchet_test.dart`, `test/design_standard_test.dart`, `test/l10n_coverage_test.dart` | pass; ratchet counts for the new file are 0 (no baseline needed) | 50 passed — `run-ratchet-design-l10n.txt` | PASS |
| 5 | `flutter analyze lib/ui/kit/kit_progress_row.dart test/kit/kit_progress_row_test.dart test/goldens/kit/kit_progress_row_golden_test.dart` | no issues | No issues found! — `run-analyze.txt` | PASS |
| 6 | `flutter analyze` (whole worktree) | no *new* errors/warnings/infos in this unit's changed paths | 6 pre-existing issues, all in `lib/ui/kit/kit_since.dart`, `test/kit/kit_image_test.dart`, `test/kit/kit_since_test.dart` — none in this unit's files | PASS |
| 7 | `dart format --language-version=3.10` on every changed `.dart` file | no diff after formatting | no further diff | PASS |

## 5. Evidence

- `failing-first.txt`: run 1 — the segments-bar cross-axis-collapse fix's
  test, failing on the pre-fix code with an assertion (not a compile
  error), found first by looking at the "segments" golden image (a blank
  gap where the bar should be) before any test caught it.
- `run-kit-progress-row-test.txt`: run 2.
- `run-kit-progress-row-golden-test.txt`: run 3.
- `run-ratchet-design-l10n.txt`: run 4.
- `run-analyze.txt`: run 5.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + name) or golden | Output |
  |---|---|---|
  | `value: null` → skeleton, no percentage, "loading" semantics | "a null value shows no percentage and says loading" | `run-kit-progress-row-test.txt` |
  | Value label shown, "62 percent" in the merged semantics | "renders the value label and carries it in semantics" | `run-kit-progress-row-test.txt` |
  | Automatic near/at limit at 80 %/100 %, neither at 79 % | "80 % shows Near limit, 100 % shows Limit reached, 79 % shows neither" | `run-kit-progress-row-test.txt` |
  | An explicit tone never adds the automatic words | "an explicit tone never adds the automatic words" | `run-kit-progress-row-test.txt` |
  | LOOK-4: `tone: attention` throws | "attention throws an AssertionError" | `run-kit-progress-row-test.txt` |
  | `asOf` renders "as of HH:mm" (`intl`, `DateFormat.Hm`) | "renders \"as of HH:mm\" in the locale format" | `run-kit-progress-row-test.txt` |
  | Segments legend lists every label + value label; a 5th folds into "Other" | "the legend lists every label with its value label, and a fifth segment folds into Other" | `run-kit-progress-row-test.txt` |
  | Data safety: segments summing over 1 assert in debug | "segments summing over 1 assert in debug" | `run-kit-progress-row-test.txt` |
  | `onTap`: the whole row is one ≥48 dp target, called once; no button semantics without it | "the whole row is one target and tapping calls it once" / "without onTap there is no button semantics" | `run-kit-progress-row-test.txt` |
  | MOT-5/G8: a value change settles after one `pump()` under reduced motion; keeps animating briefly otherwise | "a value change settles after one pump() under reduced motion" / "without reduced motion a value change keeps animating briefly" | `run-kit-progress-row-test.txt` |
  | Regression: a childless `DecoratedBox` in a `Row` needs `CrossAxisAlignment.stretch` | "the stacked bar actually paints at its full height, …" | `run-kit-progress-row-test.txt`; fails on the pre-fix code: `failing-first.txt` |
  | Galleries: seven declared states × dark/light at 412×915; default (loaded) at 1280×800 (owner-narrowed scope, Contract problem 1) | `test/goldens/kit/kit_progress_row_golden_test.dart` (16 shots) | `run-kit-progress-row-golden-test.txt` |

- Changed test expectations (TEST-19): none — every test in this unit's
  write set is new.
- Goldens changed (all new; every PNG opened and looked at before
  committing, TEST-6):
  - `kit_progress_row_loading_{dark,light}.png`: title only, skeleton bar
    (surface3, static, no motion).
  - `kit_progress_row_loaded_{dark,light}.png`, and
    `kit_progress_row_loaded_1280x800_{dark,light}.png`: 62 % accent bar;
    at 1280 the title and value label sit on one line (the adaptive
    "trailing fits" layout, `KitProgressRow.md` "Adaptive", expanded/large)
    instead of stacking as they do at 412×915.
  - `kit_progress_row_near_limit_{dark,light}.png`: 85 %, "Near limit" in
    `text1`/label weight after the value label, bar still `accent`.
  - `kit_progress_row_at_limit_{dark,light}.png`: 100 %, bar filled in
    `text1` (never the danger role), "Limit reached".
  - `kit_progress_row_stale_{dark,light}.png`: "40 % used · as of 10:42"
    in `text3` after the value label.
  - `kit_progress_row_segments_{dark,light}.png`: a 4-segment stacked bar
    (`accent`/`text2`/`text3`/`surface3`+hairline) and its legend, one row
    per segment with a colour swatch, name and value label. **Caught by
    looking at this exact image** (TEST-6): the first render had no
    visible bar at all — see "Regression" in Contract-adjacent evidence
    above and `failing-first.txt`.
  - `kit_progress_row_empty_{dark,light}.png`: `value: 0`, "Nothing used
    yet" (title and the caller's own words for the empty state fit on one
    line at 412 too — a short value label plus a short title both clear
    the trailing-fit measurement).
  - No approved visual-language canvas render exists for this part
    (EVID-12: none — `KitProgressRow.md` is the frozen spec and predates
    a canvas render for it).
- Before and after (EVID-10): no before render — this is a brand-new kit
  part with no prior golden or census page (`git log --all -- lib/ui/kit/kit_progress_row.dart`
  is empty before this branch). After: the 16 PNGs above are the "after"
  state.
- Accessibility: every state is one merged `Semantics` node
  (`container: true`), built from a plain-word `Semantics(label: …)` while
  everything visible underneath is `ExcludeSemantics`-d, so a screen
  reader hears the row once: "{title}, {percent} percent, {valueLabel}[,
  near limit][, as of 10:42]" for the scalar row, "{title}, {valueLabel};
  {label} {valueLabel}; …" for segments. With `onTap` the node also carries
  `button: true` and a `tap` action (checked by
  `flagsCollection.isButton`/`hasAction`); without it, neither. The row's
  minimum height is `KitTokens.rowHeightTwoLine` (60), above the 48 dp
  target floor. G5 (`androidTapTargetGuideline`, `labeledTapTargetGuideline`,
  `textContrastGuideline`, reading-order) ran on every gallery shot in
  both themes and passed with zero new baseline entries — the single
  merged node design leaves nothing else for the traversal check to
  order. 200 % text and RTL review are out of scope this wave (Contract
  problem 1, owner decision 2026-09-27).
- Privacy and security: n/a — no credentials, stored data, external links
  or notifications are involved; the part renders only what its caller
  passes in.
- Migration: n/a — no stored format changed; `KitProgressRow` holds no
  state of its own.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n   # regenerates lib/l10n/app_localizations*.dart from app_en.arb
$F test -j 1 test/kit/kit_progress_row_test.dart
$F test -j 1 test/goldens/kit/kit_progress_row_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart test/l10n_coverage_test.dart
$F analyze lib/ui/kit/kit_progress_row.dart test/kit/kit_progress_row_test.dart test/goldens/kit/kit_progress_row_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (R19/R20, coordinator work).
- No Arabic or RTL review, and no 2.0-text or non-412/1280 gallery sizes
  this wave (Contract problem 1, owner decision 2026-09-27); the frozen
  spec's own fuller gallery/RTL requirements are deferred to whenever that
  decision is revisited.
- No approved visual-language canvas render exists to diff the goldens
  against (the frozen spec predates one).
- TalkBack itself was not run: the merged-node label and the button
  semantics are proven on the semantics tree in widget tests, not by
  listening on a device.
- No screen adopts `KitProgressRow` yet (non-goal); the six page elements
  and `session-context-makeup` (C26, `.segments`) `KitProgressRow.md`
  names as replacing are wave-2 work for another unit.
- The "Other" legend entry's value label is left blank by design
  (Contract problem 2); a caller wanting a summed number must format it
  itself until the spec says otherwise.
- `packages/opencode_sdk`, the Android build and live-server checks do
  not apply to this unit (no touched file reaches them).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitProgressRow` |
| Enabled | Yes, but unused: the part exists and is fully tested; no screen imports it yet (non-goal) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | this branch's commit (see `git log -1`) |
| Deployed | No | |
| Released | No | |
