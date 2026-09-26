# revamp-kit-KitChip: KitChip, the one small rounded label (2026-09-27)

## 1. Scope

- Unit: `kit-KitChip` (wave 1, tier 1a, `kit-part`). Finish line: `KitChip` exists in its own file under `lib/ui/kit/`, with its frozen API (five kinds: plain, action, removable, count, summary), every declared state (selected, expanded), its galleries, its contract tests, and `KitChipWrap`. Non-goal: no call site outside the kit changes, and `lib/ui/kit/kit.dart` is not edited (the integrator adds the export row).
- Rounds: the build (code `7bc5b32d`), then fix round 1 (code `806cba5c`), which answers the eight review findings listed in §1a.
- Files changed: `lib/ui/kit/kit_chip.dart` (new); `test/kit/kit_chip_test.dart` (new); `test/goldens/kit/kit_chip_golden_test.dart` (new) plus its 16 PNGs; `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb` (one new key, `kitChipRemove`, added in the build round and not touched since).
- Pages (map ids): none. KitChip.md says "kit-v2.json assigns no element to KitChip, because the part was added by the cut review." Its future callers (kit-KitComposerChips, kit-KitWorkLine and kit-KitSearchField) are separate, later units.
- Specs followed: docs/ux-system/kit-api/KitChip.md (frozen API, states, tokens, adaptive, a11y, motion, data safety, tests and galleries required); docs/design/visual-language-2026-09-26.md §4–§5; docs/ux-system/kit-v2.md §8; STANDARDS.md §4 (kit-only idioms), §12 (accessibility) and §15 (tests and goldens); the owner decision of 2026-09-27 at the top of STANDARDS.md on `feat/phone-setup-v2` (commit `97975859`, made after this branch's base).
- Contract problems (PROC-20):
  1. **`KitChipWrap` run spacing (KitChip.md "Tokens", "New token").** The spec says run spacing is `minTarget - chipHeight` (16) "so vertical hit areas never overlap". That sum assumes a 32 dp layout box whose 48 dp hit area hangs 8 dp outside it. Flutter hit-tests a child only inside its own layout box, so a real 48 dp hit area has to be a 48 dp layout box, and every kind now is one (finding 2). With the frozen 16 on top, two runs' pills sit 32 dp apart and their hit areas sit 16 dp apart, where the spec wanted 16 and 0. It was built as frozen (16); `kit_chip_default_dark.png` shows the gap. Proposed text: "run spacing 0: each chip's layout box is already its 48 dp hit area, so runs touch and pills sit `minTarget - chipHeight` (16) apart." It blocks nothing.
  2. **Focus and press on a removable chip's two zones (KitChip.md "States", focused row).** The spec gives one look, "a 2-physical-pixel accent focus ring around the pill", and one hover and press fill (`surface2`) for the pill. That look is built for both the body zone and the × zone, as the review asked: the ring outlines the whole 32 dp pill, and the × turns the whole pill `surface2`. So when a removable chip has `onPressed`, a keyboard user cannot see whether the body or the × holds focus; only the Tab order tells (chip, then ×). A different look was not chosen. Proposed text for the spec owner: "focused ×: the accent ring circles the × glyph's 32 dp zone inside the pill; focused body: the ring outlines the pill". It blocks nothing, and `kit_chip_focused_*.png` shows today's look.
  3. **Action chip with both `icon` and `selected` (KitChip.md "States", action selected row).** The spec says "a check glyph in accent at the start" but does not say what happens to the caller's `icon`. The build dropped it without saying so (finding 4). Now there is one start slot: the check takes the icon's place while selected, and the two cross-fade on `KitMotion.quick`. This is written in the `KitChip.action` dartdoc. The spec should say it (or say that both show). It blocks nothing.
  4. **This task's brief against the owner decision of 2026-09-27.** The brief still says "Copy (R04): app_en.arb AND app_ar.arb (real Arabic)" and "galleries at the §8.4 sizes". The owner decision, dated later, drops Arabic (no `_ar_`/RTL galleries and no Arabic ARB entries for new copy) and limits galleries to 412×915 and 1280×800. R15 says later owner decisions win, so the galleries follow the decision: the 4 `_ar_` PNGs and the 360×800, 915×412, 800×1280 and 1600×1000 PNGs are deleted, which leaves 16 of the spec's 28. The reviewer asked for the coordinator to confirm that the decision covers this unit. This agent cannot get that confirmation, so it is flagged here. The Arabic `kitChipRemove` value stays in `app_ar.arb`, and the integrator decides whether to keep it (review finding 8). The RTL behaviour tests (no overflow, LTR and RTL) were kept because they cost nothing.
  5. **G5 false positive at 915×412 (build round).** This is now moot for this unit: 915×412 is no longer rendered, and the plain chip shows the spec's own "main" again, which passes G5 at 412×915 and 1280×800. The investigation stays in `contract-problem-G5-915x412.txt` for the coordinator, because another unit can still hit the harness artefact at that size.
- New kit parts (KIT-3): `KitChip` and `KitChipWrap` (this unit's own part).
- Map items (EVID-11): none (no map page names this unit).
- States per page (STATE-20): n/a (a kit-part unit with no screen pages).
- Deferred states (STATE-21): none.

## 1a. Review findings, fix round 1

| # | Finding | Fix | Proof |
|---|---|---|---|
| 1 | The ink painted over the label and covered the 48 dp box; the × ink was a square | The tap zones paint nothing (`NoSplash`, transparent overlay). The pill's own `ShapeDecoration` fill turns `surface2` on hover or press of any zone, drawn under the Row and inside the 32 dp stadium | "hover and press" group: 12 pixel tests (6 kinds or zones × hover or press) check that every text pixel is still painted, the pill is `surface2`, and a pixel outside the pill is unchanged |
| 2 | Static chips were 32 dp tall beside 48 dp interactive ones | Every kind is a 48 dp-high box with the pill centred; static ones just have no zone | "every kind in a KitChipWrap at 320 dp …" and `kit_chip_default_*.png` |
| 3 | The tooltip sat under the tap overlay | The truncation test is lifted to the chip (the Row's own sum: padding, glyphs, label), and the `Tooltip` wraps the whole tap zone (for a removable chip, the body zone), with `excludeFromSemantics` and no long-press haptic (MOT-11) | "truncation tooltip" group: long-press on action, summary, removable (with and without a body tap), plain and count; hover with a mouse; a label that fits gets no tooltip |
| 4 | The check never cross-faded, and the icon was dropped without saying so | One start slot that always exists; an `AnimatedSwitcher` swaps check, icon or nothing on `KitMotion.quick` (`Duration.zero` under reduced motion) | "turning selection on and off cross-fades check and icon" (mid-fade opacities in both directions); MOT-7 "action selects" and "action deselects" |
| 5 | The ring was drawn around the 48 dp box | `_PillSurface` draws the ring (foreground stadium, `strokeAlignOutside`, `KitTokens.focusRingWidth`) from the zones' focus | "focus ring (around the pill)": ring rect = pill rect, 32 dp high, centred, `accent`, for action, count, summary and the ×; `kit_chip_focused_*.png`. For the ×, see contract problem 2 |
| 6 | Test #8 checked nothing | It walks the render tree: every `RenderParagraph` span's effective colour (the glyphs are included) and every decoration fill or outline, in both themes, with focus and hover on | `run-fail-first.txt`: a label at 0.6 alpha fails with `"main" painted at 0.6 alpha`, and a × in `roles.attention` fails with "painted in an attention role" (both reverted) |
| 7 | The LAY-9 test used one kind; the chevron test read `AnimatedRotation.turns` | 12 chips of all five kinds (static ones included) in a 320 dp wrap, with no overlap and pill centres equal within each run. The chevron is read from its painted transform (`getTransformTo(null)`, vertical axis +1 when folded and −1 when open) | "every kind in a KitChipWrap …", "the chevron points down folded and up open" |
| 8 | Arabic and extra sizes against the owner decision | Galleries cut to 412×915 and 1280×800, with no `_ar_` PNGs; the ARB key is left alone | See contract problem 4 |

## 2. Builds

- Branch `revamp/kit-KitChip`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`, build code head `7bc5b32d`, fix-round code head `806cba5c`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is wave-checkpoint work.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | The new tests against the reviewed code (`7bc5b32d`'s `kit_chip.dart` swapped in, then restored) | fail | 25+ failures. The press tests fail on "every pixel of the words is still painted" (644 → 0), and the honesty test fails on a deliberately faded label and on a deliberately attention-coloured glyph (`run-fail-first.txt`) | PASS |
| 2 | `flutter test -j 1 test/kit/kit_chip_test.dart` | all pass | 65 passed (`run-behavior-tests.txt`) | PASS |
| 3 | `flutter test -j 1 test/goldens/kit/kit_chip_golden_test.dart` (16 PNGs, DPR 3.0, G5 scan on every `kitGalleryPart` shot) | all pass | 16 passed (`run-golden-tests.txt`) | PASS |
| 4 | `flutter test -j 1 test/kit_ratchet_test.dart test/l10n_coverage_test.dart` | pass, and no baseline count rises | 34 passed (`run-ratchet-l10n.txt`) | PASS |
| 5 | `flutter test -j 1 test/design_standard_test.dart test/kit/kit_pre_wave_tokens_test.dart` | pass | 21 passed (`run-design-standard-pre-wave.txt`) | PASS |
| 6 | `flutter analyze lib test` | no issues | "No issues found!" (`run-analyze.txt`) | PASS |

## 5. Evidence

- `run-*.txt` hold the tails of the runs above, and `run-fail-first.txt` holds step 1.
- `contract-problem-G5-915x412.txt`: the build round's investigation (now moot for this unit).
- Rule evidence (PROC-31), all in `test/kit/kit_chip_test.dart` (output in `run-behavior-tests.txt`) unless a golden is named:

  | Rule | Test (`--plain-name`) or golden |
  |---|---|
  | #1 plain: not a button, not focusable | "is not a button, has no tap action, is not focusable" |
  | #2 action: tap, check, toggled | group "action" |
  | #3 removable: separate 48×48 ×, tap isolation, Delete and Backspace | group "removable" |
  | #4 count: "{label}, {count}", `intl` en and ar | group "count" |
  | #5 summary: tap, expanded semantics, chevron direction | group "summary" ("the chevron points down folded and up open") |
  | #6 / LAY-9: 48 dp at text 1.0 and 2.0; a mixed wrap at 320 dp | group "hit area (LAY-9)" |
  | #7 / A11Y-8, G6: ellipsis, full semantics, no overflow at 320, 360 and 412, LTR and RTL | group "truncation (A11Y-8, G6)" |
  | #8 / LOOK-14, LOOK-4: painted-colour scan | group "honesty (LOOK-14, LOOK-4)" |
  | #9 / MOT-7, G8: reduced motion settles after one `pump()` | `kitMotionStillTests('KitChip', …)` (now with "action deselects") |
  | #10 / G14: Tab order chip then ×; Enter and Space | group "keyboard (G14)" |
  | States: hover and pressed fill `surface2`, no spread past the pill | group "hover and press (the pill, under the words)" |
  | States: focus ring around the pill | group "focus ring (around the pill)"; `kit_chip_focused_*.png` |
  | Motion: check cross-fades on `KitMotion.quick` | group "selected check (KitMotion.quick cross-fade)" |
  | Adaptive: tooltip with the full label when truncated (long-press, hover) | group "truncation tooltip (KitChip.md \"Adaptive\")" |

- Changed test expectations (TEST-19), all in this unit's own file:
  - "the chevron turns from down to up" (read `AnimatedRotation.turns`) became "the chevron points down folded and up open" (reads the painted transform), finding 7.
  - "ten chips in a KitChipWrap …" (action chips only) became "every kind in a KitChipWrap at 320 dp …" (all kinds, with pill centres per run), finding 7.
  - The honesty test changed from widget `Text.style` and `Icon.color` to render-tree spans and decorations, finding 6.
- Goldens changed (each opened and looked at, cropped and enlarged):
  - `kit_chip_default_{dark,light}.png` and `kit_chip_default_1280x800_{dark,light}.png`: "main" and "Tasks · 3" now sit on the same line as their neighbours (finding 2). The plain chip reads "main" again (it was "3 agents").
  - `kit_chip_default_text2{,_1280x800}_{dark,light}.png`: the same alignment at 200 % text. The pills grow past 32 dp, and the × and chevron glyphs do not scale.
  - `kit_chip_focused_{dark,light}.png`: the accent ring now outlines the 32 dp pill of "file.txt ×", where it was a 48 dp circle around the ×.
  - `kit_chip_truncated_{dark,light}.png`: static and interactive rows now line up.
  - `kit_chip_selected_*` and `kit_chip_expanded_*` are unchanged byte for byte.
  - Deleted: `kit_chip_default_{360x800,915x412,800x1280,1600x1000}_{dark,light}.png` and `kit_chip_default_ar{,_1280x800}_{dark,light}.png` (owner decision 2026-09-27).
  - There is no approved VL canvas render for KitChip (EVID-12: "no approved render").
- Before and after: n/a. KitChip has no earlier census render (EVID-10), and the build round's goldens are the "before" in git history (`7bc5b32d`).
- Accessibility: every kind has a 48 dp box, and each interactive zone is at least 48×48. Full labels are in semantics and in the tooltip when cut. The keyboard ring sits on the pill. Selection shows a check and toggled semantics (STATE-9). Nothing uses attention roles or alpha text (scanned). Arabic was not checked (owner decision).
- Privacy and security: n/a. No credentials, stored data, links or notifications changed.
- Migration: n/a. No stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n   # kitChipRemove; the generated files are not committed (PROC-13)
$F analyze lib test
$F test -j 1 test/kit/kit_chip_test.dart
$F test -j 1 test/goldens/kit/kit_chip_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/l10n_coverage_test.dart
$F test -j 1 test/design_standard_test.dart test/kit/kit_pre_wave_tokens_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (no APK; unit agents do not build).
- The `focused` gallery shot still uses its own small harness, because `kitGalleryPart` has no hook to Tab before the compare, so the shared G5 scan does not run on it. `takeException` is asserted null. The ring itself is covered by the "focus ring" tests.
- Hover was driven by a simulated mouse in `flutter_test`, not by a real fine pointer. The tooltip's on-screen placement is not in a golden.
- No screen calls `KitChip` yet, by design.
- TalkBack was not run by a human. Semantics were checked through `flutter_test` and G5 only.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitChip` |
| Enabled | No: not exported from `lib/ui/kit/kit.dart` yet (integrator step, R06) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `806cba5c` |
| Deployed | No | |
| Released | No | |
