# revamp-kit-KitAskLine-look: Kit ask line and skeleton transcript take the look (2026-09-26)

## 1. Scope

- Unit: `kit-KitAskLine-look` (wave 1, tier 1a, kind `kit-change`). Finish line: `KitAskLine`
  and `KitSkeletonTranscript` read every colour, radius, inset and icon size from
  `ThemeRoles`/`KitText`/`KitTokens` instead of `Theme.of(context).colorScheme`/`.textTheme`
  or a numeric literal, with no API or behaviour change. Non-goal: no new ask-line or
  skeleton variant, no edit to either caller.
- Files changed: `lib/ui/kit/kit_ask_line.dart`, `lib/ui/kit/kit_skeleton_transcript.dart`,
  `test/kit/kit_ask_line_test.dart` (new), `test/goldens/kit/kit_ask_line_golden_test.dart` (new).
- Pages (map ids): none assigned (the frozen spec restyles the two parts, not a page; §"Map"
  in `docs/ux-system/kit-api/KitAskLine.md`).
- Specs followed: STANDARDS.md KIT-9, KIT-43, LOOK-1, LOOK-2, LOOK-6, LOOK-12, LOOK-19,
  LOOK-33, LAY-8, A11Y-8; `docs/ux-system/kit-api/KitAskLine.md` in full;
  `docs/design/visual-language-2026-09-26.md` §7.
- Contract problems (PROC-20): the frozen spec's own "Galleries required" section has two
  internal issues, reported here rather than followed literally:
  1. Its second bullet's size list ("360×800, **915×412**, 800×1280, 1280×800, 1600×1000")
     transposes the second entry — every other gallery in the repo, and `kitGallerySizes`
     itself, uses 412×915 (portrait) there, not 915×412 (landscape). Treated as a typo and
     built against the standard `kitGallerySizes`.
  2. Its "That is 30 PNGs" total double-counts: the States bucket's `ask_inline`/`skeleton`
     entries at 412×915 share the exact golden name (`kitGalleryName` drops the size suffix
     at 412×915) with the Default bucket's 412×915 entries for the same states, which are a
     different render (bare vs. above a composer inset) — building both under one name would
     make the second overwrite/compare against the first with mismatched content. Resolved by
     dropping the States bucket's separate bare `ask_inline`/`skeleton` shots (their 412×915
     dark/light coverage already comes from the Default bucket's own 412×915 iteration) and
     keeping `ask_stacked` as the one States-only shot, since it appears nowhere else. Net:
     26 unique PNGs, not 30, with every state still covered at 412×915 in both themes.
  Neither changes the frozen API, tokens or acceptance criteria; both are documented instead
  of worked around per this unit's instructions.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a — no map page is assigned to this unit.
- States per page (STATE-20): n/a (kit parts, not a page). Per-part doc states (KIT-12), as
  the frozen spec's exact wording: `KitAskLine` "States: inline, stacked."; `KitSkeletonTranscript`
  "States: loading (decorative)." Neither word is in gate G4's fixed vocabulary
  (`{loading, empty, error, disabled, working, answered}`), so `test/kit/kit_manifest_test.dart`
  still reports a `states` problem for both — unchanged from before this unit (both were
  already allowlisted there for lacking any `States:` line at all). See §7 and "Shared tests".
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitAskLine-look`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`
  (`feat/phone-setup-v2`), code head `078a57c7` ("feat(kit): KitAskLine and
  KitSkeletonTranscript take the look").
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator/checkpoint work.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `flutter analyze lib/ui/kit/kit_ask_line.dart lib/ui/kit/kit_skeleton_transcript.dart test/kit/kit_ask_line_test.dart test/goldens/kit/kit_ask_line_golden_test.dart` | no issues | no issues | PASS |
| 2 | `flutter analyze` (whole project) | no issues | no issues | PASS |
| 3 | `flutter test -j 1 test/kit/kit_ask_line_test.dart` | all pass | 14 passed | PASS |
| 4 | `flutter test -j 1 --update-goldens test/goldens/kit/kit_ask_line_golden_test.dart` (first run: no PNGs existed) | 26 shots render and pass G5 | 26 passed | PASS |
| 5 | `flutter test -j 1 test/kit_ratchet_test.dart` | passes; per-file G21/G15x counts for the two files at or below baseline | 33 passed; both files' counts dropped to 0 (advisory "Shell:" lines only, not failures) | PASS |
| 6 | `flutter test -j 1 test/design_standard_test.dart` | passes | 15 passed | PASS |
| 7 | `flutter test -j 1 test/l10n_coverage_test.dart` | passes (no copy changed) | 3 passed | PASS |
| 8 | `flutter test -j 1 test/first_reply_notify_card_test.dart` (shared caller, KitAskLine) | passes unchanged | 17 passed | PASS |
| 9 | `flutter test -j 1 test/chat_states_standard_test.dart` (shared caller, KitSkeletonTranscript) | passes unchanged | 6 passed | PASS |
| 10 | `flutter test -j 1 --plain-name "KitSkeletonTranscript" test/kit_motion_test.dart` | passes | 2 passed | PASS |
| 11 | `flutter test -j 1 --plain-name "KitSkeletonTranscript" test/text_scale_overflow_test.dart` | passes | 1 passed | PASS |
| 12 | `flutter test -j 1 test/kit/kit_manifest_test.dart` (shared, gate G4) | 1 known "now passes" entry for `test · KitAskLine` (see §7); nothing else | exactly that one stale entry | FAIL (expected; see §7) |
| 13 | `flutter test -j 1 test/goldens/chat_states_golden_test.dart --plain-name "loading"` (shared, integrator-owned golden) | pixel mismatch: the loading skeleton's look changed on purpose | mismatch, ~19% diff, visually confirmed as the intended surface3/pill restyle | FAIL (expected; see §7) |
| 14 | `flutter test -j 1 test/goldens/chat_states_golden_test.dart --plain-name "notify me"` (shared, integrator-owned golden) | pixel mismatch: the ask line's accent → text2 change | mismatch, visually confirmed (button/glyph now text2, was accent) | FAIL (expected; see §7) |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | LOOK-2, LOOK-6 | `test/kit/kit_ask_line_test.dart` "reads no colorScheme, textTheme, accent or partial-alpha text" | run 3 above |
  | LOOK-33 | `test/kit/kit_ask_line_test.dart` "renders the question, a 20 dp text2 glyph and both answers…" | run 3 above |
  | A11Y-8 / stacking | `test/kit/kit_ask_line_test.dart` "sits beside the question when it fits; moves under it…" and "a long question at 320 dp stacks with no overflow" | run 3 above |
  | LAY-8 / G6 overflow | `test/kit/kit_ask_line_test.dart` "no overflow from 320 to 1600 dp" | run 3 above |
  | KIT-43 | `test/kit/kit_ask_line_test.dart` "first_reply_notify_card and chat_states callers compile against the unchanged constructor" (×2) | run 3 above |
  | LOOK-19, LAY-5 | `test/kit/kit_ask_line_test.dart` "at most 700 dp wide at 1280 dp" | run 3 above |
  | decorative/a11y | `test/kit/kit_ask_line_test.dart` "excluded from semantics; keeps its key" | run 3 above |
  | G21/G15x ratchet | `test/kit_ratchet_test.dart` | run 5 above (both files' EdgeInsets/SizedBox/BorderRadius.circular/maxWidth literal counts to 0) |

- Changed test expectations (TEST-19): none — no existing test file in this unit's write set
  was edited; both `test/kit/kit_ask_line_test.dart` and
  `test/goldens/kit/kit_ask_line_golden_test.dart` are new.
- Goldens changed (each opened and looked at): all 26 are new (`kit_ask_line_*.png`), no
  approved VL canvas render exists to compare against for these two parts (EVID-12: none).
  Representative shots inspected: `kit_ask_line_ask_inline_dark.png`/`_light.png` (inline,
  two-line question, buttons vertically centred against it, no accent),
  `kit_ask_line_ask_stacked_dark.png` (long question, answers reversed under it start-aligned,
  as the unchanged behaviour requires), `kit_ask_line_skeleton_dark.png` (surface3 blocks,
  pill-shaped reply bars), `kit_ask_line_ask_inline_ar_dark.png` (RTL: glyph at the visual
  start/right, answers at the end/left), `kit_ask_line_ask_inline_text2_dark.png` (2.0 text
  forces stacked).
- Before and after (EVID-10, shared/integrator-owned goldens this unit's look reaches but does
  not own): `test/goldens/chat_states_golden_test.dart` "chat · loading" and "chat · notify me"
  were run (not `--update-goldens`) to see the real before/after; both mismatch as expected
  (run 13–14). Diff images were inspected under `test/goldens/failures/` and then discarded —
  that directory's tracked pre-existing contents (from another unit's committed failure
  artifacts) were restored with `git checkout -- test/goldens/failures/` after an accidental
  `rm -rf` touched them; `git status` now shows no diff there (R07: render, look, then
  `git checkout` — never stage `test/**/failures/`).
- Accessibility: `KitAskLine`'s glyph and question keep their existing semantics
  (`Semantics(container: true, label: semanticsLabel)`, unchanged); the answers are still
  48 dp `KitButton`s carrying their own labels. `KitSkeletonTranscript` stays wrapped in
  `ExcludeSemantics` (verified: adds zero semantics nodes over a bare screen, run 3). 200 %
  text (`test/kit/kit_ask_line_test.dart` "sits beside…at 2.0x text") and a long question at
  320 dp, LTR and RTL (`"a long question at 320 dp stacks with no overflow"` ×2), both checked;
  every gallery shot ran the G5 accessibility guidelines (tap targets, contrast, reading order)
  in both themes as part of `kitGalleryPart` (run 4).
- Privacy and security: n/a — no credentials, stored data, links or notifications changed.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_ask_line_test.dart
$F test -j 1 test/goldens/kit/kit_ask_line_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart test/l10n_coverage_test.dart
$F test -j 1 test/first_reply_notify_card_test.dart test/chat_states_standard_test.dart
$F analyze
```

## 7. NOT proven

- Not run on a device or emulator (out of scope for this unit, R19/R20).
- `test/kit/kit_manifest_test.dart`'s gate G4 "allowlist only shrinks" test fails with exactly
  one entry: `test · KitAskLine` now passes (because `test/kit/kit_ask_line_test.dart` exists
  for the first time), so its `kit_manifest_allowlist.json` "test" entry is stale. That file
  is shared/integrator-owned (same "only shrinks, `KIT_MANIFEST_WRITE=1`" pattern as the kit
  ratchet baseline) and outside this unit's write set; recorded in `sharedTestsBroken` for the
  integrator to drop that one line (or rerun with `KIT_MANIFEST_WRITE=1`) after merge. No
  other check in that file changed status for either class: both remain on the `states`
  allowlist (their new `States:` lines use words outside gate G4's fixed vocabulary, by the
  frozen spec's own design — see §1) and on the `gallery` allowlist (that check's scanner only
  recognises `kitGalleryShot`/`matchesGoldenFile` call literals, not `kitGalleryPart`, the
  helper this gallery and the pre-existing `kit_foundation_golden_test.dart` both use, so it
  still reports the gallery as unscanned either way).
- `test/goldens/chat_states_golden_test.dart`'s "chat · loading" and "chat · notify me"
  scenarios (shared, integrator-owned goldens under R07) now mismatch on purpose: the visible
  look changed exactly as this unit's spec asks (surface3/pill skeleton, text2 glyph and
  answers instead of accent). Recorded in `sharedTestsBroken`; the integrator regenerates
  those two PNGs (`--update-goldens`, look at the images, commit) once every unit touching the
  chat screen for this wave has landed.
- The "beside vs. under" behaviour test does not use the literal 412 dp from item 2 of the
  frozen spec's Tests section: this bare widget test loads no real font, and the headless
  test-font substitute is wide enough that even a short label pair wraps at 412 dp regardless
  of the part's own logic. The mechanism (fits beside when there is room; text scale 2.0 or a
  long question at 320 dp forces it under, start-aligned) is proven at a width chosen to fit
  under that substitute font; the literal 412 dp/1.0×, with the real Geist face, is proven by
  the golden gallery (`kit_ask_line_ask_inline_412x915_dark/light.png`, visually inspected,
  §5).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitAskLine-look` |
| Enabled | Yes (no flag; both parts are used unconditionally by their existing callers) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `078a57c7` |
| Deployed | No | |
