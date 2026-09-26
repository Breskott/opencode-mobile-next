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
  `lib/l10n/app_localizations*.dart` left unstaged, PROC-13);
  `test/kit/kit_progress_test.dart` (30 tests); `test/goldens/kit/kit_progress_golden_test.dart`
  (30 shots) plus its 30 PNGs (all opened and reviewed). Full list:
  `git diff b67e3276...a16f34cf --stat`.
- Fix round (review findings 1–7, 2026-09-27, same folder per EVID-1). Fix:
  1. waiting under reduced motion read as "30 percent" — the still segment
     is drawn inside `ExcludeSemantics` under one container node with the
     label, `SemanticsRole.loadingSpinner` and no value (the same node a
     moving waiting bar has);
  2. the line was read twice (bar label and the `KitText` under it) — the
     text is excluded from semantics, and a determinate bar is now its own
     container node, so a host such as `KitStateView` no longer folds its
     title and body into the bar's label (found while writing the test for
     this finding: without the container, the bar's label in a
     `KitStateView` read "Downloading the base\n…");
  3. debug asserts — `known(value)` and `staged(stepValue)` within 0..1,
     and within one staged job (same `of`, step and label) the value never
     drops; the check is a private stateful child, so `KitProgressView`
     stays the frozen `StatelessWidget` (the review suggested making it
     stateful; the spec's API block says `extends StatelessWidget`
     UNCHANGED, and the private child keeps that exactly);
  4. the 915×412 staged shots (dark, light) are added;
  5. hours round up (see Contract problems 2);
  6. no test reads `LinearProgressIndicator` fields any more: colour and
     length come from paint matchers, value and role from `getSemantics`;
  7. shared breakage unchanged and still reported below for the
     integrator.
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
     above ships in this unit (`KitProgressView.build`, the `label` join;
     the visible line is excluded from semantics so it is heard once) and
     is covered by the "KitProgressView semantics" group of
     `test/kit/kit_progress_test.dart`; the audible outcome (label then value, together) matches the
     spec's intent even though the sentence lives in a different
     `SemanticsData` field than the spec named.
  2. **"hours with one decimal dropped" (The eta words) is ambiguous.**
     What it says: "Rounding: under 60 s, round up to 10 s; under 1 h,
     whole minutes rounded up; beyond that, hours with one decimal
     dropped." Why it is a problem: "dropped" reads either as truncation
     (2 h 54 min → "about 2 h left", nearly an hour short, which the first
     build shipped) or as a whole-hour figure. Truncation is the only
     reading that under-states time left, while seconds and minutes both
     round up. Resolution in this unit: whole hours rounded up (2 h 54 min
     → "about 3 h left"; exactly 2 h → "about 2 h left"). Evidence:
     `test/kit/kit_progress_test.dart` "an hour or more rounds whole hours
     up, never down" fails on the first build (`failing-first.txt`:
     Expected 'about 3 h left', Actual 'about 2 h left'). Proposed text:
     "beyond that, whole hours rounded up". Blocks: false — the spec owner
     may pick another rounding; only `_etaWords` and that test change.
  3. **"the value never goes backwards within a job … asserted in debug"
     cannot be asserted for `known`.** What it says: "A `staged` step never
     exceeds `of`, and the value never goes backwards within a job unless
     the step goes back. This is asserted in debug." Why it is a problem:
     `known` carries no job identity (no step, label or `of`), and live
     callers start a new job on the same bar with a lower value —
     `SetupProgressView` after "done" and for "Add tools" (its own
     `_jobKey`/`_jump`, `lib/ui/widgets/setup_progress_view.dart:155-172`),
     the phone-setup start meter. Asserting a drop for `known` would throw
     in debug on those callers (R11). Resolution in this unit: asserted for
     `staged` (same `of`, step and label → the value must not drop); `known`
     is left unchecked, pinned by the test "known has no job identity: a
     host may start a new job lower". Proposed text: "Within one `staged`
     job (the same `of`, step and label) the value never goes backwards;
     asserted in debug. A new job, or a stage measured again from zero, is
     a new `KitProgressView` (a new key). For `known` the host keeps the
     bar monotonic within its job (SetupProgressView's furthest-point
     rule)." Blocks: false.
- Harness note (not a spec problem): `kitGallerySizes` in
  `test/goldens/kit/kit_gallery.dart` has no 915×412, though gate G23
  (`namedGallerySizes`) and `kitGalleryName` both accept it. This gallery
  now lists the spec's five sizes itself (`_defaultSizes`); other kit
  galleries that loop over `kitGallerySizes` miss the landscape phone the
  same way. `kit_gallery.dart` is shared and outside this unit's write set.
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
    (the new `text1` colour; the new sample timings). Recommended instead
    of new timings: drop `SetupProgressView`'s own 700 ms
    `TweenAnimationBuilder` (`setup_progress_view.dart:305-331`) so the
    two eases do not stack — `KitProgressView` already eases, and
    `_furthest` alone keeps the bar from going backwards. That file is
    outside this unit's write set.
  - Merge note: this branch cannot merge alone. The integrator lands, in
    the same integration, the four `test/kit_motion_baseline.json` and
    `_frozenBaseline` removals and the three
    `test/phone_setup_progress_screen_test.dart` updates above. Re-run
    after the fix round: the same 4 and 3 tests fail with the same
    messages (runs 12 and 13), nothing else.

## 2. Builds

- Branch `revamp/kit-KitProgress-v2`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`
  (`feat/phone-setup-v2` tip at branch time), code head `a16f34cf`
  (the fix round; the first build was `8f39e631`).
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is the coordinator's
wave checkpoint work (R19, R20).

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: the new tests on the pre-fix part (`git show 85c86a1a:lib/ui/kit/kit_progress.dart`) | the fix tests fail with an assertion | 7 failed with `Expected:`/`Actual:` (stepValue and value asserts, no-backwards, hours, line read once, KitStateView host node, waiting reduced-motion semantics); see `failing-first.txt` | PASS |
| 2 | `test/kit/kit_progress_test.dart` (30 tests) | passes | 30 passed; see `run-kit-progress-test.txt` | PASS |
| 3 | `test/goldens/kit/kit_progress_golden_test.dart` (30 shots; `--update-goldens` only for the two new 915×412 shots) | passes; new PNGs opened and looked at; the 28 existing PNGs unchanged | 30 passed; `git status` shows only the two new PNGs | PASS |
| 4 | `flutter analyze lib test` | no issues | No issues found! | PASS |
| 5 | `dart format --language-version=3.10` on every changed `.dart` file | no diff after formatting | no further diff | PASS |
| 6 | Callers: `phone_setup_start_screen`, `phone_setup_welcome_entry`, `saved_server_connection_card`, `kit_illustration`, `local_terminal_screen`, `kit_motion_app` tests | pass unchanged | 41 + 25 + 36 passed | PASS |
| 7 | Hosts: `design_standard_setup`, `e7_setup_layout`, `first_run_welcome`, `motion_setup`, `phone_server_card`, `phone_setup_ready_screen`, `phone_setup_notification_route`, `local_agent_onboarding`, `work_tab_cleanup`, `goldens/work_tab_golden`, `oc2_server_discovery`, `phone_termux_discovery`, `team_discover`, `launch_shortcut_routing` tests | pass unchanged | 20 + 28 + 44 + 31 + 38 + 17 + 33 passed | PASS |
| 8 | `test/text_scale_overflow_test.dart`, `test/goldens/kit/kit_gallery_g5_test.dart` | pass | 75 passed; G5 31 passed (with `local_terminal_screen`) | PASS |
| 9 | `test/kit_ratchet_test.dart`, `test/kit/kit_pre_wave_tokens_test.dart` | pass; counts only drop | 38 passed; informational print `kit_progress.dart "Radius.circular(<n>" 1 -> 0`, `"SizedBox numeric" 5 -> 4` (baseline is integrator-owned, R05) | PASS |
| 10 | `test/design_standard_test.dart`, `test/l10n_coverage_test.dart` | pass | 17 passed (l10n's "these files improved" print is pre-existing drift) | PASS |
| 11 | `test/kit/kit_manifest_test.dart`, `test/golden_harness_test.dart` (G4, G23) | pass | 10 passed; the `_915x412` names are accepted | PASS |
| 12 | `test/kit_motion_test.dart` | — | 4 of 179 fail (the same stale G8x baseline entries); see "Shared tests broken" | FAIL, reported |
| 13 | `test/phone_setup_progress_screen_test.dart` | — | 3 of 25 fail (the same colour and timing expectations); see "Shared tests broken" | FAIL, reported |

## 5. Evidence

- `failing-first.txt`: run 1 — the fix round's tests on the pre-fix part,
  seven assertion failures (`Expected:`/`Actual:`), none a compile error.
- `run-kit-progress-test.txt`: run 2.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | Staged line join order and value formula | `test/kit/kit_progress_test.dart` "joins the step, the label and the eta with ' · '" / "value is (step - 1 + stepValue) / of, or (step - 1) / of" | `run-kit-progress-test.txt` |
  | Staged asserts (K2 §2.8): step within 1..of, of ≥ 1, stepValue within 0..1 | "asserts step within 1..of and of at least 1" / "asserts stepValue within 0..1" | `run-kit-progress-test.txt`; fails on base: `failing-first.txt` |
  | Known value within 0..1 | "asserts value within 0..1" | `run-kit-progress-test.txt`; fails on base: `failing-first.txt` |
  | Never backwards within a staged job, in debug (Data safety and honest state) | "the same step and label dropping its value asserts" / "moving forward, or holding, is fine" / "the step going back may lower the bar" / "a different job (another \"of\") starts over" / "known has no job identity: …" | `run-kit-progress-test.txt`; fails on base: `failing-first.txt` |
  | Eta rounding (under 60 s → 10 s up; under 1 h → minutes up; beyond → hours up) | "under a minute rounds up to the nearest 10 s" / "under an hour rounds whole minutes up" / "an hour or more rounds whole hours up, never down" / "an eta of zero or less is never shown" | `run-kit-progress-test.txt`; hours fails on base: `failing-first.txt` |
  | Arabic plural forms in the line (COPY-3) | "uses the locale plural forms in Arabic" | `run-kit-progress-test.txt` |
  | A11Y: one node; the line read once; the percentage for determinate bars | "carries the line and the percentage for known" / "the line is read once: the bar and its words are one node" / "inside a KitStateView the bar stays its own node: …" / "carries the line for staged; …" | `run-kit-progress-test.txt`; the two "once"/"own node" tests fail on base: `failing-first.txt` |
  | STATE-7: waiting is indeterminate for every reader, reduced motion included | "carries the semanticsLabel for waiting" / "waiting under reduced motion is still indeterminate: no value and no percentage, the same as with motion" | `run-kit-progress-test.txt`; fails on base (value '30'): `failing-first.txt` |
  | MOT-5/G8: waiting still under reduced motion, a 30 % segment at the start; moving otherwise; determinate jumps under reduced motion and eases otherwise | "an indeterminate bar settles after one pump() under reduced motion, as a still 30 % segment at the start" / "without reduced motion the waiting bar keeps moving" / "a determinate change applies immediately under reduced motion" / "a determinate change eases there with motion" (paint matchers) | `run-kit-progress-test.txt` |
  | LOOK-5 interim, LOOK-6: running accent, stopped `text3`, failed `text1`, never `danger` | "running is the accent; stopped (neutral) and failed paint text3 and text1, not the danger role" (paint matcher) | `run-kit-progress-test.txt` |
  | KIT-43: existing `waiting`/`known` calls still compile and render | "waiting renders an indeterminate bar with its caption" / "known renders a determinate bar with its caption" | `run-kit-progress-test.txt` |
  | Galleries at DPR 3: six declared states; staged at 360×800, 915×412, 800×1280, 1280×800, 1600×1000; text2 and Arabic (TEST-9) | `test/goldens/kit/kit_progress_golden_test.dart` (30 shots) | run 3 |

- Changed test expectations (TEST-19), all in this unit's own
  `test/kit/kit_progress_test.dart`:
  - "an hour or more drops to whole hours" → "an hour or more rounds whole
    hours up, never down": 2 h 20 min was "about 2 h left", now "about 3 h
    left" (review finding 5; Contract problems 2).
  - The motion, KIT-43 and tone tests read `LinearProgressIndicator.value`
    and `.color`; they now assert the painted segment (`paints..rrect`) and
    the semantics value and role (review finding 6). The asserted
    behaviour is the same, apart from waiting under reduced motion, whose
    old expectation (`bar.value` not null) is replaced by "no semantics
    value, a still 30 % segment painted at the start" (review finding 1).
- Goldens changed, fix round: `kit_progress_staged_915x412_{dark,light}.png`
  (new, opened and looked at: the bar at 40 % in the accent, capped at the
  state width and centred, "Step 3 of 5 · Installing · about 2 min left"
  under it, no overflow; no approved render, EVID-12). The other 28 are
  byte-identical after the fix round (semantics changes paint nothing).
- Goldens from the first build (all new, each opened and looked at): `kit_progress_waiting_{dark,light}.png`
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
- Before and after: no before render — a `kit-change` on a part with no
  prior gallery (`git show b67e3276:lib/ui/kit/kit_progress.dart` is the
  "before" source, EVID-10). After: `after-kit_progress-staged_915x412_dark.png`
  (new landscape shot) and `after-kit_progress-waiting_dark.png` (the
  reduced-motion still frame, pixels unchanged by the semantics fix).
- Accessibility: the bar is one semantics node in every state. Its label
  is `semanticsLabel` then the line, joined with ", "; the line's visible
  `KitText` is excluded, so it is heard once. A determinate bar has
  `SemanticsRole.progressBar` and the framework's percentage as its value;
  a waiting bar has `SemanticsRole.loadingSpinner` and no value, with or
  without reduced motion. The bar is a container node, so inside a
  `KitStateView` live region the title and body stay in the host's node
  and the bar is read after them as its own item. Not focusable, no tap
  target. The gallery's G5 checks ran for all 30 shots in both themes
  with no new baseline entry; 2.0 text wraps the line with no overflow
  (`kit_progress_staged_text2_*`).
- Privacy and security: n/a — no credentials, stored data, external links
  or notifications are involved.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n   # the generated l10n files are not committed on this branch
$F test -j 1 test/kit/kit_progress_test.dart
$F test -j 1 test/goldens/kit/kit_progress_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/kit/kit_pre_wave_tokens_test.dart
$F test -j 1 test/design_standard_test.dart test/l10n_coverage_test.dart
$F test -j 1 test/kit/kit_manifest_test.dart test/golden_harness_test.dart
$F analyze lib test
# Failing-first: the fix round's tests on the pre-fix part
git show 85c86a1a:lib/ui/kit/kit_progress.dart > lib/ui/kit/kit_progress.dart
$F test -j 1 test/kit/kit_progress_test.dart   # 7 fail, see failing-first.txt
git checkout lib/ui/kit/kit_progress.dart
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
- TalkBack itself was not run: "read once", "no percentage while
  waiting" and "the bar is its own node in a KitStateView" are proven on
  the semantics tree in widget tests, not by listening on a device.
- The no-backwards assert covers `staged` only; `known` hosts are not
  checked by the part (Contract problems 3).
- The `packages/opencode_sdk`, Android build and live-server checks do not
  apply to this unit (no touched file reaches them).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitProgress-v2` |
| Enabled | Yes: `KitProgressView` already renders on every existing call site (`SetupProgressView`, the phone-setup screens, `saved_server_connection_card.dart`); the new `staged`/`eta` parameters have no call site yet | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `a16f34cf` (fix round; first build `8f39e631`) |
| Deployed | No | |
| Released | No | |
