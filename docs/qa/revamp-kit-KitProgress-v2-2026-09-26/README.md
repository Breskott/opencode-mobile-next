# revamp-kit-KitProgress-v2: KitProgress v2 — stages and a time estimate (2026-09-26)

## 1. Scope

- Unit: `kit-KitProgress-v2` (wave 1, tier 1, `kit-change`). Finish line:
  `KitProgress` and `KitProgressView` match `docs/ux-system/kit-api/KitProgress.md`
  exactly (the `staged` constructor, the `known` eta, the eta words, the
  line, the tone map, the tokens, the reduced-motion still frame), the
  galleries are regenerated and reviewed, and the change is additive —
  every existing call site (`setup_progress_view.dart`, the phone-setup
  screens, `saved_server_connection_card.dart`) keeps compiling with no
  edit. Non-goal: no call site migrates to the new `staged`/`eta`
  parameters, and no screen is restyled; `KitLoadingBar` and
  `KitSkeletonRows` are unchanged (the frozen spec's own File section).
- Files changed: `lib/ui/kit/kit_progress.dart`; `lib/l10n/app_en.arb` and
  `lib/l10n/app_ar.arb` (four new keys: `kitProgressStep`,
  `kitProgressEtaSeconds`, `kitProgressEtaMinutes`, `kitProgressEtaHours`;
  `flutter gen-l10n` run locally, the three generated
  `lib/l10n/app_localizations*.dart` restored before committing, PROC-13);
  `test/kit/kit_progress_test.dart` (new, 18 tests); `test/goldens/kit/kit_progress_golden_test.dart`
  (new, 28 shots) plus its 28 PNGs (all opened and reviewed). Full list:
  `git diff feat/phone-setup-v2...8f39e631 --stat`.
- Pages (map ids): none — `KitProgress`/`KitProgressView` are a value
  object and its renderer, not a screen; no `docs/ux-system/map/all.json`
  page record names them.
- Specs followed: `docs/ux-system/kit-api/KitProgress.md` (frozen API, in
  full); `docs/ux-system/revamp/STANDARDS.md` §1, §4, §5 (LOOK-5, LOOK-6,
  LOOK-18), §7 (MOT-5), §8 (COPY-3), §9 (STATE-4, STATE-6, STATE-7), §12,
  §15, §16; `docs/ux-system/kit-v2.md` §2.8, §4.9, §4.10, §4.11, §9.1.
- Contract problems (PROC-20):
  1. **The Accessibility section's "Its value is the line" cannot be
     built as worded against the pinned framework.** What it says: "The
     bar is one semantics node. Its label is `semanticsLabel` or the
     host's title. Its value is the line ('Step 3 of 5, Installing, about
     2 minutes left'), and for `known` it is also given as a percentage
     ('62 percent')." Why it is wrong: on Flutter 3.47.1,
     `LinearProgressIndicator` gives a determinate bar (`value != null`,
     which `staged` also is) `SemanticsRole.progressBar`; the framework's
     own debug-mode role check (`_semanticsProgressBar`) requires
     `SemanticsData.value` to parse as a bare number or an `"NN%"` string,
     and throws a `FlutterError` during `flushSemantics` otherwise — a
     composite sentence is never valid there. It is also framework
     behaviour, not a choice this part makes, that gives a `staged` bar
     the same auto-percentage as `known` once a `value` is set: there is
     no `ProgressIndicator` parameter to opt a determinate bar out of the
     role. Evidence: `~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/packages/flutter/lib/src/semantics/semantics.dart:234-236`
     (`_semanticsProgressBar`, the "must be valid numbers" `FlutterError`)
     and `packages/flutter/lib/src/material/progress_indicator.dart:146-161`
     (`_buildSemanticsWrapper`, `isProgressBar = value != null`, the
     default `'${(_effectiveValue! * 100).round()}'`); reproduced live
     while building this unit — every `_pumpProgress` call in an early
     draft of `test/kit/kit_progress_test.dart` that put the line into
     `semanticsValue` failed with exactly this `FlutterError` (`value:
     "29 of 30 MB · about 50 s left, 62%"`, `value: "Step 3 of 5 ·
     Installing · about 2 min left"`), fixed by moving the line into
     `semanticsLabel` instead. Proposed replacement text: "Its label
     carries `semanticsLabel` and then the line, joined with ', '; a
     screen reader hears both, one after the other. Its value is left to
     the framework's own default (a bare percentage) for any determinate
     bar — `known` and `staged` alike." Blocks: false — the resolution
     above ships in this unit (`kit_progress.dart` lines 252–263) and is
     covered by `test/kit/kit_progress_test.dart`'s three "semantics"
     tests; the audible outcome (label then value, together) matches the
     spec's intent even though the sentence lives in a different
     `SemanticsData` field than the spec named.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a — no page record (see Pages above).
- States per page (STATE-20): n/a — no page; `KitProgress`'s own states
  (waiting, known, staged, stopped, failed) are in the doc comment on both
  classes and in the gallery (`test/goldens/kit/kit_progress_golden_test.dart`).
- Deferred states (STATE-21): none.
- Shared tests broken (PROC-10, TEST-19 case 1, outside this unit's write
  set — reported, not edited):
  - `test/kit_motion_test.dart` (gate G8x): the frozen `_frozenBaseline`
    and `test/kit_motion_baseline.json` list `KitProgressView / waiting /
    system`, `KitProgressView / waiting / effectsOff`, `KitStateView /
    working / system` and `KitStateView / working / effectsOff` as
    "still moving" under reduced motion. MOT-5/G8 (this unit's own
    frozen spec) requires the opposite: an indeterminate bar shows a
    still 30 % track segment under reduced motion instead of continuing
    to animate. Once fixed, both `KitProgressView`'s own "waiting" sample
    and `KitStateView`'s "working" sample (which renders a waiting
    `KitProgressView`) settle after one `pump()`, so all four entries are
    now stale; the test fails on purpose ("G8x ratchet: '…' now settles.
    Remove it from …") and prints the smaller `stillMoving` list to
    commit. Remedy: remove those four lines from
    `test/kit_motion_baseline.json` and from `_frozenBaseline` in
    `test/kit_motion_test.dart` (the failing run already prints the exact
    smaller JSON).
  - `test/phone_setup_progress_screen_test.dart` (three tests, all inside
    `setup_progress_view.dart`, which `KitProgress.md`'s own "Absorbs"
    line names as `kit-KitChecklist`'s future work, not this unit's):
    "failure says the stage and the reason, red bar, Continue setup"
    expects the failed bar's colour to be red (the old
    `AppTheme.statusColor`/danger mapping); LOOK-5 (this unit's frozen
    Tokens section) now paints a failed bar in `text1`, never the danger
    red, so the colour assertion needs the new role. "overall bar eases
    and never goes backwards within a job" and "a re-run after done
    starts over" sample the bar's value at fixed pump timings that assume
    zero animation latency inside `KitProgressView`; K2 §2.8/MOT-5 (this
    unit's frozen Motion section) now has `KitProgressView` itself ease a
    determinate change on `KitMotion.standard`/`enter`, which compounds
    with `SetupProgressView`'s own separate 700 ms easing wrapper and
    shifts the sampled values. Remedy: update the three expectations
    (the new `text1` colour; the new sample timings, or drop
    `SetupProgressView`'s own easing once `kit-KitChecklist` absorbs it).

## 2. Builds

- Branch `revamp/kit-KitProgress-v2`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`
  (`feat/phone-setup-v2` tip at branch time), code head `8f39e631`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is the coordinator's
wave checkpoint work (R19, R20).

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_progress_test.dart` (18 tests, the spec's 7 "Tests required" items plus tone) | passes | 18 passed | PASS |
| 2 | `test/goldens/kit/kit_progress_golden_test.dart` (28 shots, `--update-goldens` then reviewed) | passes; every PNG opened and looked at | 28 passed; images reviewed (waiting's still 30 % frame, known/staged/staged-measured/stopped/failed at 412×915, staged at the other four LAY-4 sizes, staged at text2 and Arabic RTL at two sizes — correct mirrored fill, no overflow, `text1` not red for failed) | PASS |
| 3 | Both files together (`-j 1`) | passes | 46 passed | PASS |
| 4 | `flutter analyze lib test` (whole worktree tree, PROC-2) | no errors, no new warnings or infos | No issues found! | PASS |
| 5 | `dart format --language-version=3.10` on every changed `.dart` file | no diff after formatting | applied (one lint fixed: `use_null_aware_elements`), no further diff | PASS |
| 6 | Existing callers: `test/phone_setup_start_screen_test.dart`, `test/phone_setup_welcome_entry_test.dart`, `test/saved_server_connection_card_test.dart` | pass unchanged | 29 + 12 + 13 = 54 passed | PASS |
| 7 | `test/kit_ratchet_test.dart`, `test/kit/kit_pre_wave_tokens_test.dart` | pass; counts only drop | passed; informational-only print: `kit_progress.dart "Radius.circular(<n>" 1 -> 0`, `"SizedBox numeric" 5 -> 4` (not committed — `test/kit_ratchet_baseline.json` is outside this unit's write set, PROC-13/R05) | PASS |
| 8 | `test/design_standard_test.dart`, `test/l10n_coverage_test.dart` | pass | 15 and 17 passed (l10n's own "these files improved" print is pre-existing, unrelated drift, not from this unit) | PASS |
| 9 | `test/kit/kit_manifest_test.dart` (gate G4) | pass (`KitProgressView`'s pre-existing `name`/`gallery`/`test`/`docRow`/`states` allowlist entries stay valid: NAME-1 still does not match — the class lives in `kit_progress.dart`, not `kit_progress_view.dart`, exactly as this frozen spec's File section requires) | 2 passed, no stale entries | PASS |
| 10 | `test/phone_setup_progress_screen_test.dart` | — | 3 of 22 fail (colour and timing, both tied to this unit's spec-mandated changes); see "Shared tests broken" above | FAIL, reported |
| 11 | `test/kit_motion_test.dart` | — | 4 of 175 fail (stale G8x baseline entries); see "Shared tests broken" above | FAIL, reported |

## 5. Evidence

- No `failing-first.txt`: this is new/additive behaviour on an existing
  part, not a fix to a specific reported bug (TEST-2's "new code that
  fixes nothing needs no failing-first run").
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | Staged line join order and value formula | `test/kit/kit_progress_test.dart` "KitProgress.staged line joins the step, the label and the eta with ' · '" / "value is (step - 1 + stepValue) / of, or (step - 1) / of" | run 1 above, PASS |
  | Staged asserts (K2 §2.8) | `test/kit/kit_progress_test.dart` "asserts step within 1..of and of at least 1" | run 1 above, PASS |
  | Eta rounding (under 60 s → 10 s; under 1 h → whole minutes; beyond → whole hours) | `test/kit/kit_progress_test.dart` "under a minute rounds up to the nearest 10 s" / "under an hour rounds whole minutes up" / "an hour or more drops to whole hours" / "an eta of zero or less is never shown" | run 1 above, PASS |
  | Arabic plural forms in the line | `test/kit/kit_progress_test.dart` "uses the locale plural forms in Arabic" | run 1 above, PASS |
  | Semantics label carries the line; value is the framework's own percentage | `test/kit/kit_progress_test.dart` "carries the line and the percentage for known" / "carries the line for staged; the framework still adds its own percentage to any determinate bar" / "carries the semanticsLabel for waiting" | run 1 above, PASS (also: Contract problems §1 above) |
  | MOT-5/G8: indeterminate settles under reduced motion; determinate change is immediate under reduced motion | `test/kit/kit_progress_test.dart` "an indeterminate bar settles after one pump() under reduced motion" / "a determinate change applies immediately under reduced motion" | run 1 above, PASS |
  | LOOK-5 interim: stopped is `text3`, failed is `text1`, never `danger` | `test/kit/kit_progress_test.dart` "stopped (neutral) and failed use text3 and text1, not the danger role" | run 1 above, PASS |
  | KIT-43: existing `waiting`/`known` calls still compile and render | `test/kit/kit_progress_test.dart` "waiting renders an indeterminate bar with its caption" / "known renders a determinate bar with its caption" | run 1 above, PASS |
  | Galleries at DPR 3, the six declared states, the five LAY-4 sizes, text2 and Arabic (TEST-9) | `test/goldens/kit/kit_progress_golden_test.dart` (28 shots) | run 2 above, PASS |

- Changed test expectations (TEST-19): none in this unit's own files — no
  existing test was touched (the three broken assertions are in a shared
  file outside this unit's write set; see "Shared tests broken" above,
  not "changed" here).
- Goldens changed (all new, each opened and looked at): `kit_progress_waiting_{dark,light}.png`
  (indeterminate, shown at its reduced-motion still 30 % frame because
  the gallery harness always disables animations); `kit_progress_known_{dark,light}.png`
  (62 %, "29 of 30 MB · about 50 s left"); `kit_progress_staged_{dark,light}.png`
  (the default state, also at `_360x800`, `_800x1280`, `_1280x800`,
  `_1600x1000`, `_text2_…` and `_ar_…`/`_ar_1280x800_…`, "Step 3 of 5 ·
  Installing · about 2 min left" / Arabic "الخطوة 3 من 5 · يثبّت · بقيت
  دقيقتان تقريبًا", correctly mirrored fill and right-aligned text, no
  overflow); `kit_progress_staged_measured_{dark,light}.png` ("Step 2 of
  4 · Downloading · 12 of 30 MB"); `kit_progress_stopped_{dark,light}.png`
  and `kit_progress_failed_{dark,light}.png` (both a muted/near-black
  fill, `text3`/`text1`, never red). No approved VL canvas render exists
  for this part (EVID-12: none — KitProgress.md is the frozen spec and
  predates a canvas render for it).
- Before and after: n/a — a `kit-change` on a part with no prior gallery;
  `git show b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4:lib/ui/kit/kit_progress.dart`
  is the "before" source (no PNG existed to diff, EVID-10).
- Accessibility: `semanticsLabel` plus the line are combined into the
  bar's semantics label (see Contract problems §1); the framework's own
  percentage is still the value for any determinate bar; the gallery's
  built-in G5 checks (`androidTapTargetGuideline`, `labeledTapTargetGuideline`,
  `textContrastGuideline`, reading order) ran and passed for all 28 shots
  in both themes — the bar has no tap target, so only the text-contrast
  and reading-order checks apply, and both passed with no new baseline
  entry. 2.0 text wraps the line to two lines with no overflow (`kit_progress_staged_text2_*`).
- Privacy and security: n/a — no credentials, stored data, external links
  or notifications are involved.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_progress_test.dart test/goldens/kit/kit_progress_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/l10n_coverage_test.dart test/design_standard_test.dart test/kit/kit_manifest_test.dart test/kit/kit_pre_wave_tokens_test.dart
$F analyze lib test
# Shared, unedited, expected to show the reported breakage:
$F test -j 1 test/kit_motion_test.dart
$F test -j 1 test/phone_setup_progress_screen_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (R19/R20, coordinator work).
- `test/kit_motion_test.dart` and `test/phone_setup_progress_screen_test.dart`
  do not pass as they stand; see "Shared tests broken" above. Not worked
  around — both files are outside this unit's write set.
- No approved visual-language canvas render exists to diff the goldens
  against.
- The `packages/opencode_sdk`, Android build and live-server checks do not
  apply to this unit (no touched file reaches them).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitProgress-v2` |
| Enabled | Yes: `KitProgressView` already renders on every existing call site (`SetupProgressView`, the phone-setup screens, `saved_server_connection_card.dart`); the new `staged`/`eta` parameters have no call site yet | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `8f39e631` |
| Deployed | No | |
| Released | No | |
