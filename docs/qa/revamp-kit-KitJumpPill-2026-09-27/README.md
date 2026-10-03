# revamp-kit-KitJumpPill: KitJumpPill (2026-09-27)

## 1. Scope

- Unit: `kit-KitJumpPill` (wave 1, tier 2, `kit-part`). Finish line: `KitJumpPill` exists in
  its own file under `lib/ui/kit/`, with its frozen §4 API (`KitJumpPill`, `KitJumpPill.older`,
  `KitJumpPillLayer`, `KitJumpEdge`, `latestLabel`), every declared state (visible, hidden),
  its galleries (TEST-9), its contract tests (TEST-15) and its structural asserts (behaviour
  tests 1-9 of the frozen spec). Non-goal: no call site outside the kit changes (no screen
  migrates onto it in this unit).
- Files changed:
  - `lib/ui/kit/kit_jump_pill.dart` (new)
  - `test/kit/kit_jump_pill_test.dart` (new)
  - `test/goldens/kit/kit_jump_pill_golden_test.dart` (new)
  - `test/goldens/kit/kit_jump_pill_{default,older,focused}[_1280x800]_{dark,light}.png` (new, 12 files)
  - `lib/l10n/app_en.arb` (two new keys: `kitJumpLatest`, `kitJumpNewLatest`)
  - Not changed by this branch: the generated `lib/l10n/app_localizations*.dart` output is
    integrator-owned (PROC-11/13). A first commit (`1f27fe32`) included it by mistake; review
    fix `0dd7f6aa` restored those three files to `feat/phone-setup-v2`'s versions, so the
    branch no longer carries its own regeneration.
- Pages (map ids): none — this unit builds the part only; the map's five assignment sites
  (`chat#chat-earlier-messages-pill`, `chat#chat-jump-to-latest`,
  `embedded-message-view#embedded-message-view-jump-to-latest`,
  `team-agent-output#team-agent-output-jump`, `team-run-timeline-tab#team-run-timeline-jump`)
  are migrated by whichever screen units later adopt this part (non-goal, per the kit-part
  default finish line).
- Specs followed: `docs/ux-system/kit-api/KitJumpPill.md` (frozen API, states, tokens,
  adaptive, motion, a11y, RTL, data safety, tests and galleries required); `kit-v2.md` §1.19,
  §8.2, §8.4; STANDARDS.md Appendix A #24 (solid, not glass), KIT-31, LOOK-20, LOOK-27, MOT-2;
  §4 (kit-only idioms), §7 (motion/haptics), §12 (accessibility), §15 (tests/goldens), §18 (G5
  gate); `docs/design/visual-language-2026-09-26.md` §4 (pill shape), §7 (hairline rounding).
- Contract problems (PROC-20): one, recorded and resolved by a later, higher-authority
  decision (R15), not worked around silently:
  - KitJumpPill.md's "Galleries required" section asks for goldens at 360x800, 915x412,
    800x1280, 1280x800 and 1600x1000, plus text-2.0 and Arabic RTL sweeps at 412x915 and
    1280x800. The owner decision dated 2026-09-27 (this task's brief, later than the spec's
    2026-09-26 date) drops Arabic/RTL entirely and narrows galleries to phone 412x915 and one
    wide size 1280x800 only, light and dark. R15 (owner decisions dated later win) applies:
    this unit built to the narrower, later instruction and did not build the wider matrix.
    Also affects the spec's test 6 ("Arabic plural forms resolve" is not exercised) and the
    Copy rule R04 ("app_en.arb AND app_ar.arb") — only `app_en.arb` carries new copy; after
    the integrator regenerates, Arabic falls back to the English string for the two new keys
    (untranslated, not an error).
- New kit parts (KIT-3): `KitJumpPill` (`KitJumpEdge`, `KitJumpPillLayer` alongside it in the
  same file, per the frozen API).
- Map items (EVID-11): n/a — no page in this unit's `pages` (see Scope: none migrated).
- States per page (STATE-20): n/a — a kit-part unit, not a screen; the part's own two states
  (visible, hidden) are covered by `test/kit/kit_jump_pill_test.dart` groups 1-2 and by the
  galleries.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitJumpPill`, base `dcf05c5e` (tip of `feat/phone-setup-v2` at branch
  creation). First build `1f27fe32`; review fixes `0dd7f6aa` (generated l10n dropped) and the
  review-fix commit that carries this record (focus ring, hidden-while-animating, label line
  bound, 700 dp pane galleries).
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work (R19/R20).

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_jump_pill_test.dart` (`$F test -j 1`) | all pass | 17 passed | PASS |
| 2 | `test/goldens/kit/kit_jump_pill_golden_test.dart` (`$F test -j 1`) | all pass, G5 clean, no baseline addition | 12 passed | PASS |
| 3 | `test/kit_ratchet_test.dart` | passes, no new pattern for the new file | see run 3 note | PASS |
| 4 | `test/design_standard_test.dart` | passes | see run 3 note | PASS |
| 5 | `flutter analyze` on the three changed Dart files | no issues | see run 3 note | PASS |
| 6 | Failing-first (TEST-2): the new tests against the pre-fix `kit_jump_pill.dart` (`git show 1f27fe32:lib/ui/kit/kit_jump_pill.dart`) | the four new tests fail | 4 failed: "2. hidden … 50 ms into the exit fade …", "8. … focus ring painted outside the pill …", "9. … 100% text: one line …", "9. … a long count is bounded to 2 lines" | PASS |

Runs 1-2 are from the review-fix revision; the earlier first-build counts (14 behaviour
tests) are superseded.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-12 (states) | `test/kit/kit_jump_pill_test.dart` "1. visible" / "2. hidden" groups | run 1 above |
  | MOT-2 (never scales) | `test/kit/kit_jump_pill_test.dart` "3. motion toggling visible animates over KitMotion.standard, no scale" | run 1 above |
  | MOT-7/G8x (reduced motion) | `test/kit/kit_jump_pill_test.dart` "3. motion under reduced motion (system)" and "(Animations: Off)" | run 1 above |
  | LAY-6 (KitBottomInset clearance) | `test/kit/kit_jump_pill_test.dart` "4. KitJumpPillLayer" group | run 1 above |
  | A11Y-1/4/6, G5 | `test/goldens/kit/kit_jump_pill_golden_test.dart` (`expectKitGalleryAccessible` on every shot, both themes) | run 2 above |
  | LOOK-6 (accent focus ring, 2 physical px, outside the pill) | `test/kit/kit_jump_pill_test.dart` "8. desktop capabilities focus ring painted outside the pill in accent when focused; Enter activates" | run 1 above |
  | Hidden = not hittable/read/focused at once, fade only | `test/kit/kit_jump_pill_test.dart` "2. hidden hidden takes effect at once: 50 ms into the exit fade …" | run 1 above |
  | `button` label one line, two from 2.0 text | `test/kit/kit_jump_pill_test.dart` "9. text scale and line count" group | run 1 above |
  | KIT-31/LOOK-20 (solid, no glass/shadow/blur) | visual review of the 12 golden PNGs (§ below) | goldens |
- Changed test expectations (TEST-19), all in this unit's own test file, at review:
  - Test 8 used to check only that a foreground `DecoratedBox` with an accent side existed in
    the widget tree — it passed while the ring was clipped away. It now reads back the painted
    pixels (`RenderRepaintBoundary.toImage`) and asserts accent just outside the pill's left
    edge and just above its top, none there while unfocused, and no accent inside the fill.
  - Test 9 used to accept `maxLines` null (no bound) and never measured lines. It now loads
    the gallery's real fonts, counts the rendered lines of the label's `RenderParagraph`
    (≤ 2 at 2.0 at 320 dp, not truncated for the real label; ≤ 2 for a long count; exactly 1
    at 1.0, even a long label at 240 dp, where the pill is exactly area − 2 × gutter wide).
  - Test 2 gained a mid-exit check (50 ms after hiding): still painting, yet tap, Enter,
    semantics tree and Tab all miss it, and focus has left it.
- Goldens (each opened and looked at before committing). First build: all 12 new. Review
  fixes regenerated 8 of them; `kit_jump_pill_{default,older}_{dark,light}.png` (412x915)
  came out byte-identical and are unchanged:
  - `kit_jump_pill_default_{dark,light}[_1280x800].png`: the bottom pill, "3 new · Jump to
    latest", down arrow, over a 6-line transcript stand-in, above a composer-height bar.
    Looked at: solid `surface3` stadium, hairline border, clears the composer. At 1280x800 the
    scene now sits in a 700 dp conversation pane at the window's end (a `surface1` side region
    with a hairline edge fills the rest), and the pill is centred in that pane (x ≈ 930), not
    the window (x = 640).
  - `kit_jump_pill_older_{dark,light}[_1280x800].png`: the top pill, "Earlier messages", up
    chevron, at the transcript's top edge; at 1280x800 likewise centred in the 700 dp pane.
  - `kit_jump_pill_focused_{dark,light}[_1280x800].png`: same as default, tabbed to focus.
    Looked at, zoomed: a continuous accent (green) outline now runs all the way round the
    stadium, outside its hairline border, in both themes. The earlier focused shots showed no
    ring at all (only anti-aliased edge differences), because the ring was drawn inside the
    Material's shape clip. The goldens are stored one image pixel per logical pixel, so a
    2-physical-px ring (0.67 dp) shows as a thin line in the PNG; its colour and position
    outside the pill are asserted by test 8, its width comes from
    `KitTokens.focusRingWidth(context)` (not measured by any test).
  - No approved VL canvas render exists for this part yet (EVID-12: n/a, none published for
    KitJumpPill).
- Before and after: n/a — no existing page or golden changes; this is a new part with no
  prior render to diff against (EVID-10, "no before render", part id `kit-jump-pill`).
- Accessibility: button semantics with the words as the label, icon excluded from semantics
  (test 7); not a live region (test 7); 48×48 minimum hit area (test 7, and the pill's
  `minTarget` height token); keyboard Tab reaches it only while visible, Enter activates (test
  2, test 8); an accent focus ring paints outside the pill (test 8, pixel read-back); 200% text
  at 320 dp wraps to at most two rendered lines without overflow or truncation, 100% text stays
  on one (test 9); hidden is out of hit-testing, semantics and focus from the moment `visible`
  turns false — only the fade keeps painting — and stays mounted once settled (test 2). G5 (tap targets, labelled
  targets, text contrast, reading order) passes on every gallery shot in both themes with no
  new entry added to the shared G5 baseline.
- Privacy and security: n/a — no credentials, stored data, external links or notifications are
  touched by this part.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test -j 1 test/kit/kit_jump_pill_test.dart
$F test -j 1 test/goldens/kit/kit_jump_pill_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart test/l10n_coverage_test.dart test/ui_glossary_test.dart
$F analyze lib/ui/kit/kit_jump_pill.dart test/kit/kit_jump_pill_test.dart test/goldens/kit/kit_jump_pill_golden_test.dart
$F analyze lib
```

## 7. NOT proven

- Not run on a device or emulator (R19/R20: coordinator work).
- No screen adopts `KitJumpPill` yet, so the five real replacement sites named in
  KitJumpPill.md's "Replaces" section (`chat#chat-earlier-messages-pill`,
  `chat#chat-jump-to-latest`, `embedded-message-view#embedded-message-view-jump-to-latest`,
  `team-agent-output#team-agent-output-jump`, `team-run-timeline-tab#team-run-timeline-jump`)
  are unproven against real transcript/log content — only the gallery's stand-in scene.
- The gallery's "over a transcript-like list above a composer-height inset" scene stands in
  for `KitLogPanel`'s "new lines" pill and the real chat composer (kit-KitComposer,
  kit-KitLogPanel have not merged); the composer bar is a plain `Container` publishing the
  same `KitBottomInset` clearance a real one will, same pattern KitUndo's own gallery uses for
  its dock stand-in.
- Arabic/RTL is not exercised at all (owner decision 2026-09-27, see Scope, PROC-20). The
  frozen spec's own galleries at text-2.0/Arabic 1280x800 and the wider 360x800/800x1280/
  915x412/1600x1000 sweep are not built.
- Fine-pointer hover and keyboard focus are proven by direct widget assertions
  (`test/kit/kit_jump_pill_test.dart` "8. desktop capabilities"), not by a human looking at a
  live cursor on a running app.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitJumpPill` |
| Enabled | No screen wired yet — the part exists but nothing calls it (by design, non-goal) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | first build `1f27fe32`; review fixes on `revamp/kit-KitJumpPill` |
| Deployed | No | |
| Released | No | |
