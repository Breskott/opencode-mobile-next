# revamp-kit-KitStatusMark-v2: KitStatusMark v2 (2026-09-27)

## 1. Scope

- Unit: `kit-KitStatusMark-v2` (wave 1, kit-change). Finish line: `KitStatusMark`
  and `KitTaskMark` gain a `paused` modifier and an optional visible word
  (`label`/`showLabel`), so no state is shown by colour alone, with every
  existing caller compiling unchanged. Non-goal: no caller outside the kit
  changes, and no new enum value is added.
- Files changed: `lib/ui/kit/kit_status_mark.dart`, `lib/ui/kit/kit_task_mark.dart`,
  `test/kit/kit_status_mark_test.dart` (new), `test/goldens/kit/kit_status_mark_golden_test.dart`
  (new, plus its 20 PNGs), `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`,
  `test/kit/kit_manifest_allowlist.json` (one stale entry removed, see below).
- Pages (map ids): none — this is a kit-part change, not a screen.
- Specs followed: `docs/ux-system/kit-api/KitStatusMark.md` (frozen API);
  STANDARDS.md rules KIT-12, KIT-43, LOOK-4, LOOK-5, LOOK-6, STATE-9, STATE-11,
  MOT-7, MOT-8, G37, TEST-9, TEST-15; kit-v2.md §2.9.
- Contract problems (PROC-20):
  - **`KitStatusMark.md`'s acceptance line vs. its own API block.** The
    acceptance criterion this unit was given says "`KitMarkState.paused`"
    (a fifth enum value). The same frozen spec file explicitly rules this
    out in its own "Why `paused` is a flag and not a new enum value"
    section: adding a value would break two exhaustive `switch`es in
    `lib/ui/screens/chat/team_conversation_view.dart` (a single-owner file
    no wave-1 unit may edit), so K2 §2.9 is amended and `paused` ships as a
    boolean flag on `waiting`/`working` instead. I built the flag design the
    frozen spec's own API block gives (higher authority, and it already
    reasons through the contradiction with evidence), not the literal
    enum wording of the acceptance line. Blocks nothing; flagged so the
    coordinator can update the acceptance-line text to match K2's amendment.
  - **`toneFor`/`toneColor(AppStatusTone)` listed as an available pre-wave
    token.** The spec's Tokens section lists `KitTokens.toneFor` /
    `toneColor(AppStatusTone)` under "New tokens (pre-wave)", but
    `docs/ux-system/kit-api/_new-tokens.md`'s own "Not added here" section
    says that helper was *not* added (it needs the README.md D12 table,
    which isn't written yet). `lib/ui/kit/kit_tokens.dart` is outside this
    unit's write set, so I did not add it either. I used the same Tokens
    section's explicit per-state `ThemeRoles` mapping directly (`text3`,
    `accent`, `AppTheme.successOf`, `text1`, `text2`, `attention`) instead,
    which the spec gives as the concrete instruction either way. Blocks
    nothing for this unit; flagged so `toneFor`/`toneColor` isn't
    double-claimed as already-merged when a later unit needs it.
  - **Waiting ring legibility (LOOK-21 vs. the review's LOOK-8 finding).**
    The spec fixes the ring at "a hollow ring, 1 physical px stroke" and
    `markRingSize` 10. The review found it barely visible in
    `kit_status_mark_labelled_dark.png`. A sweep of every pack (dark and
    light) measured `text3` at 3.96:1 to 6.06:1 on ground and surface1-3,
    so the implemented `text2` fallback never fires in a shipped pack: the
    faintness comes from the 1 px stroke on a 10 dp ring, not the colour.
    Only a spec change fixes that (for example `focusRingWidth`, a larger
    `markRingSize` or a filled ring). Needs a coordinator or owner decision.
    I did not work around the frozen spec.
  - **No spinner stroke token.** `KitTokens` has no stroke for the working
    ring, and `kit_tokens.dart` is outside this write set. The spinner now
    uses `KitTokens.focusRingWidth(context)` (2 physical px, 0.67 dp at DPR
    3, the kit's heavier stroke) in place of the literal 2 dp. This is
    thinner than before. The goldens do not show it, because the gallery
    always runs under reduced motion (still dot). Proposed
    `_new-tokens.md` entry: `KitTokens.spinnerStroke` (2 dp, shared with
    `kit_buttons.dart`'s `_Spinner`, which has the same literal).
  - **Gallery harness: no landscape phone, and G5 textContrast on a lone
    word.** `kitGallerySizes` has no 915x412, although this spec's gallery
    list asks for it, so the golden test adds 915x412 itself
    (`kit_status_mark_all_915x412_{dark,light}.png`). Flutter's
    `textContrastGuideline` samples a lone `Text` at 1x device pixels. At
    that size a 14 sp `text2` word is mostly anti-aliased grey, so
    unmerged showLabel words failed by luck of their letter shapes ("Working"
    and "Stopped" at 1.16-2.89:1), although the same role measures at least
    4.5:1 in every pack (LOOK-8). The labelled scene therefore shows each
    mark as a card header (the title at the start, the mark and its word at
    the end, one `MergeSemantics`), which is how a real header reads.
    Proposal for the harness owner: sample textContrast at the view's DPR.
- New kit parts (KIT-3): none — this changes the two existing parts named in
  the spec's own "File" section.
- Map items (EVID-11): n/a — no map page.
- States per page (STATE-20): n/a — no screen; the part's own states are
  waiting, working, done, failed, paused (modifier), plus KitTaskMark's
  needsYou and stopped — all covered by golden scenes and
  `test/kit/kit_status_mark_test.dart`.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitStatusMark-v2`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`, first code head `76b3ed81`, review-fix commit on top (see `git log`).
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator/checkpoint work.

## 4. Runs

### Review fixes (round 2)

| # | Finding | Fix | Check | Result |
|---|---|---|---|---|
| R1 | No cross-fade on a state change | `KitStatusMark` wraps the glyph in an `AnimatedSwitcher` keyed by `(state, paused)`: `KitMotion.quick`, or `Duration.zero` under `KitMotion.reduced`. `KitTaskMark` puts all six states through one switcher, so working to needsYou also fades | `kit_status_mark_test.dart` "with motion on, a state change cross-fades on KitMotion.quick", "a state change swaps at once under …", "a task turning to needsYou swaps at once under …" | PASS |
| R2 | Required test 4 (G8) missing from this file | Working, paused working, working with showLabel, task working and task paused+showLabel: still dot or pause glyph, no `CircularProgressIndicator`, `hasRunningAnimations == false`, each under `system` and `effectsOff` (`kitStillApp`) | group "reduced motion (G8, MOT-7)", 16 cases | PASS |
| R3 | Waiting ring: 3:1 fallback not implemented | The ring uses `text3` when it reaches 3:1 on ground and surface1-3, and `text2` otherwise (`contrastRatio`) | group "waiting ring contrast (LOOK-8)": a sweep of every pack in dark and light, plus a built pack whose `text3` misses 3:1 | PASS (legibility itself: contract problem above) |
| R4 | Spinner literals `16` and `2` | Size is the pixel-snapped 20 dp glyph (`smallIconSize`, grows with text). Stroke is `KitTokens.focusRingWidth` (token gap reported) | "the working ring is the glyph size and grows with text" (26 dp at 1.3 text) | PASS |
| R5 | Glyph size not snapped to physical pixels | `(size * dpr).roundToDouble() / dpr` in both parts | "snaps to whole physical pixels at DPR 2.625/3.0/1.75" (done, paused, needsYou, stopped) | PASS |
| R6 | No 915x412 shot, and showLabel in KitRow's leading slot | 915x412 added. Labelled marks now sit outside KitRow as card headers, in English and Arabic | golden test: 24 shots, each looked at | PASS |
| R7 | Edits outside the write set | Flagged for the integrator (see "Integrator notes") | n/a | flagged |

With showLabel, the word's semantics node now covers the visible word only, and the glyph is excluded. The screen reader still hears the word once. Semantics tests pass unchanged.

### First build

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: fix's test on the base without the fix | n/a — not a fix, new behaviour only | n/a | n/a |
| 2 | `test/kit/kit_status_mark_test.dart` | passes | 37 passed | PASS |
| 3 | `test/goldens/kit/kit_status_mark_golden_test.dart` (`--update-goldens`, then re-run) | passes, 20 PNGs, each looked at | 20 passed | PASS |
| 4 | `test/kit_ratchet_test.dart` (G1/G2/G7/G15/G15x/G17/G21/G48) | passes | 32 passed (notes the `kit_status_mark.dart` "stroke width not KitTokens" count dropped 1 → 0; baseline file is integrator-owned, R05, left untouched) | PASS |
| 5 | `test/kit/kit_manifest_test.dart` (G4) | passes, allowlist only shrinks | 1 stale entry (`test · KitStatusMark`) found and removed with `KIT_MANIFEST_WRITE=1`; re-run passes | PASS |
| 6 | `test/kit_motion_test.dart` (shared, unedited — G8x) | passes | 179 passed, including `KitStatusMark`/`KitTaskMark` reduced-motion samples and the still-dot checks under both `system` and `effectsOff` | PASS |
| 7 | `test/ui_glossary_test.dart` | passes | 21 passed | PASS |
| 8 | `test/design_standard_test.dart` | passes | 15 passed | PASS |
| 9 | `test/text_scale_overflow_test.dart` (G6) | passes | 75 passed, including `KitStatusMark/default` and `KitTaskMark/default` | PASS |
| 10 | `test/l10n_coverage_test.dart` | passes | 2 passed | PASS |
| 11 | `test/builtin_team_section_test.dart` (this unit's tests write set) | passes unmodified | 4 passed, no edit needed | PASS |
| 12 | `flutter analyze lib test` | no errors; no new issues | "No issues found!" | PASS |

### Round 2 runs

| # | Step | Result |
|---|---|---|
| a | `test/kit/kit_status_mark_test.dart` | 58 passed |
| b | `test/goldens/kit/kit_status_mark_golden_test.dart` (`--update-goldens`, looked at, re-run) | 24 passed |
| c | `test/kit_motion_test.dart` + `test/builtin_team_section_test.dart` | 183 passed |
| d | `test/kit/kit_manifest_test.dart` + `test/ui_glossary_test.dart` | 23 passed |
| e | `test/design_standard_test.dart` + `test/kit_ratchet_test.dart` | 47 passed |
| f | `test/golden_harness_test.dart` + `test/text_scale_overflow_test.dart` | 83 passed |
| g | `test/l10n_coverage_test.dart` | 2 passed |
| h | `flutter analyze` (whole tree) | No issues found |

## Integrator notes (R7)

- **l10n regeneration dependency.** The unit adds 7 ARB keys, each in both
  `app_en.arb` and `app_ar.arb`: `kitMarkWaiting`, `kitMarkWorking`,
  `kitMarkDone`, `kitMarkFailed`, `kitMarkPaused`, `kitTaskNeedsYou` and
  `kitTaskStopped`. Under PROC-13, the regenerated
  `lib/l10n/app_localizations*.dart` are **not committed**. The branch's
  kit code calls those getters, so it compiles only after the integrator
  runs `flutter gen-l10n` on the merge.
- **`kitTaskNeedsYou` collision check.** `KitNeedsYou.md` names only
  `kitNeedsYouWaiting` as its own key. It gets its mark word from
  `KitTaskMark(state: needsYou)` / `KitTaskMark.wordFor`, and
  `KitStatusMark.md` says "the same key KitNeedsYou uses". So the
  KitNeedsYou unit should reuse this key and not add it. If its branch
  adds `kitTaskNeedsYou` as well, the ARB union produces a duplicate JSON
  key. Keep one copy (the values should be "Needs you" / "يحتاجك").
- **Ratchet change.** `test/kit/kit_manifest_allowlist.json` (shared) lost
  its stale `test · KitStatusMark` entry, because G4 forces removal once
  `test/kit/kit_status_mark_test.dart` exists. The allowlist only shrinks.
  Merge it deliberately. `test/kit_ratchet_baseline.json` is untouched: its
  `kit_status_mark.dart` "stroke width not KitTokens in kit" entry (1) can
  drop to 0.

## 5. Evidence

- `failing-first.txt`: n/a — not a fix.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | G37 / STATE-11 (paused refused on a finished step) | `test/kit/kit_status_mark_test.dart` "paused with done throws an AssertionError" / "paused with failed throws an AssertionError" | run 2 above |
  | G37 / STATE-11 (KitTaskMark) | `test/kit/kit_status_mark_test.dart` "KitTaskMark paused with needsYou throws an AssertionError" / "...with stopped..." | run 2 above |
  | KIT-12 (semantics word, English and Arabic) | `test/kit/kit_status_mark_test.dart` "default word in semantics (English and Arabic)" group (20 cases) | run 2 above |
  | LOOK-5 (failed paints `text1`, never `danger`) / LOOK-6 (done paints `success`, never `accent`; working paints `accent`) | `test/kit/kit_status_mark_test.dart` "colour roles (LOOK-5, LOOK-6, STATE-9)" group, against a theme whose accent is deliberately far from success/danger so a role mix-up would fail | run 2 above |
  | P9.5 (a word beside every mark; `label`/`showLabel`) | `test/kit/kit_status_mark_test.dart` "label overrides the word; showLabel shows it" group | run 2 above |
  | TEST-9 (galleries: declared states, 5 LAY-4 sizes, 2.0 text, Arabic RTL) | `test/goldens/kit/kit_status_mark_golden_test.dart` | run 3 above |
  | G8 (reduced motion, no ticker after one pump, every new configuration and a state change) | `test/kit/kit_status_mark_test.dart` group "reduced motion (G8, MOT-7)"; the shared `test/kit_motion_test.dart` default samples too | round 2 runs a, c |
  | Motion (cross-fade on `KitMotion.quick`) | `test/kit/kit_status_mark_test.dart` "with motion on, a state change cross-fades on KitMotion.quick" | round 2 run a |
  | LOOK-8 (ring ≥ 3:1, `text2` fallback) | `test/kit/kit_status_mark_test.dart` group "waiting ring contrast (LOOK-8)" | round 2 run a |
  | LOOK-33 (glyph snapped to physical pixels, ≤ 1.5x) | `test/kit/kit_status_mark_test.dart` group "glyph size (LOOK-33)" | round 2 run a |

- Changed test expectations (TEST-19): none — no existing test asserted on the
  old look/behaviour of these two parts.
- Goldens changed (all new; each opened and looked at before being kept):
  - `kit_status_mark_all_{dark,light}.png` and its 5-LAY-4-size, 2.0-text and
    Arabic variants (18 files): the 7 declared states in a `KitRow`, each
    with its supporting word — waiting (hollow ring), working (still dot;
    the harness always sets `disableAnimations: true`), done (green check),
    failed (neutral circled-X, not red), paused-working (pause glyph),
    task needsYou (amber question mark), task stopped (muted stop glyph).
    No approved VL canvas render exists for this part yet (EVID-12: no
    approved render).
  - `kit_status_mark_labelled_{dark,light}.png` and `_labelled_ar_…`
    (4 files, round 2): the 7 marks with `showLabel: true` outside a
    `KitRow`, as card headers: the title at the start, the mark with its word
    at the end, mirrored in Arabic. This replaces the round-1 scene in the
    KitRow leading slot, which the review rejected. No approved render
    (EVID-12).
  - `kit_status_mark_all_915x412_{dark,light}.png` (2 files, round 2): the
    default sheet on a landscape phone. The `all` shots did not change
    (the ring stays `text3` in the gallery pack, and the glyph sizes were
    already whole pixels at DPR 3).
  - A first attempt at this scene (marks stacked in a bare `Column`, not a
    `KitRow`) tripped `textContrastGuideline` on "Working"/"Paused"/"Needs you"
    (found ratios 1.16–3.56 against a 4.5 floor) once real fonts + DPR 3 were
    loaded, even though the underlying `ThemeRoles.text2` vs `ground` contrast
    is well over 4.5:1 on paper; isolating the exact same word+colour inside a
    `KitRow` (this unit's final composition) passes cleanly in both themes.
    This reads as a rendered-pixel sampling artefact of thin, small real-font
    glyphs at specific screen positions, not a real colour defect — recorded
    here rather than worked around silently, per "fix the part, not the shot":
    the fix taken was a different (and arguably more representative) gallery
    layout, not a suppressed check.
- Before and after: no before render exists for these two parts (first
  gallery built for them); EVID-10 "no before render" applies to every shot.
- Accessibility: every mark carries its word in semantics
  (`Semantics(label:, excludeSemantics: true)`), verified in English and
  Arabic (test/kit/kit_status_mark_test.dart). `showLabel` renders the word
  as visible `KitText(role: .secondary)` text, checked at 2.0 text scale and
  in Arabic RTL in the gallery (`kitGalleryPart`'s G5 checks: tap targets,
  text contrast, reading order — all passed for every one of the 20 shots).
- Privacy and security: n/a — no credentials, stored data, external links or
  notifications changed.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_status_mark_test.dart
$F test -j 1 test/goldens/kit/kit_status_mark_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/kit/kit_manifest_test.dart test/kit_motion_test.dart
$F test -j 1 test/ui_glossary_test.dart test/design_standard_test.dart test/l10n_coverage_test.dart
$F test -j 1 test/text_scale_overflow_test.dart test/builtin_team_section_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator (coordinator/checkpoint work, R19/R20).
- The full serial suite (`flutter test --concurrency=1`) was not run; this
  is unit-level work, not the wave's stable-batch boundary (AGENTS.md
  productivity rule 6). The files this change plausibly touches were run
  individually instead (§4).
- The spinner (motion on) is not in any golden. The gallery runs under
  reduced motion, so its thinner `focusRingWidth` stroke has not been seen
  rendered.
- The waiting ring's legibility at 1 physical px is still open (see the
  contract problems).
- `KitNeedsYou.mark()` producing the same configuration as
  `KitTaskMark(state: needsYou)` (spec test #6) is explicitly that unit's
  test, not this one's — `KitNeedsYou` does not exist yet.
- No caller outside the kit was changed to use `showLabel` or `paused`
  (out of scope: R14, and `team_conversation_view.dart`'s word switches are
  explicitly deferred to the chat chain per the frozen spec).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitStatusMark-v2` |
| Enabled | Yes — both parts are already exported from `lib/ui/kit/kit.dart` and used by existing callers | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | `76b3ed81` + the round-2 review-fix commit |
| Deployed | No | |
| Released | No | |
