# revamp-kit-KitChip: KitChip, the one small rounded label (2026-09-27)

## 1. Scope

- Unit: `kit-KitChip` (wave 1, tier 1a, `kit-part`). Finish line: `KitChip` exists in its own file under `lib/ui/kit/`, has its frozen API (five kinds: plain, action, removable, count, summary), every declared state (selected, expanded), its galleries at the §8.4 sizes, its contract tests, and `KitChipWrap`. Non-goal: no call site outside the kit changes; `lib/ui/kit/kit.dart` is not edited (the integrator adds the export row).
- Files changed: `lib/ui/kit/kit_chip.dart` (new); `test/kit/kit_chip_test.dart` (new); `test/goldens/kit/kit_chip_golden_test.dart` (new) plus its 28 PNGs; `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` (one new key, `kitChipRemove`).
- Pages (map ids): none. KitChip.md: "kit-v2.json assigns no element to KitChip, because the part was added by the cut review." (Its future callers — kit-KitComposerChips, kit-KitWorkLine, kit-KitSearchField — are separate, later units.)
- Specs followed: docs/ux-system/kit-api/KitChip.md (frozen API, states, tokens, adaptive, a11y, RTL, motion, data safety, tests and galleries required); docs/design/visual-language-2026-09-26.md §4–§5 (chips and pills radius 999; the work chip "Read 3 files · edited 1"); docs/ux-system/kit-v2.md §8 (window classes — KitChip is not in the §8.2 table; its own Adaptive section says every window is the same size); STANDARDS.md §4 (kit-only idioms), §12 (accessibility), §15 (tests and goldens).
- Contract problems (PROC-20):
  1. **G5 false positive at 915×412** (own file: `contract-problem-G5-915x412.txt`, evidence and full investigation there). Summary: `textContrastGuideline`, run by the shared `kitGalleryPart` harness, reports a false-positive contrast failure for a 4-letter plain-chip label ("main") at the 915×412 landscape-phone size KitChip.md's own gallery list asks for, against a colour pairing (`text2` on `surface3`) that is actually 6.33:1 (hand-computed WCAG relative luminance), well past the 4.5:1 floor. Proven by elimination to be a pixel-sampling artefact of the guideline at this aspect ratio with a short, thin-glyph run, not a colour defect — see the evidence file for the six-step isolation. Worked around **for the gallery content only**, not the colour rule: the default scene's plain-chip example is the frozen spec's own alternate ("3 agents", from KitChip.md's "'main', '3 agents'"), which does not trigger it, at every size including 915×412. `kit_gallery.dart` itself is untouched (PROC-13; "nobody raises this set"). Flagged for the coordinator to consider a `kit_gallery_g5_baseline.json` entry or a harness fix before another unit hits the same aspect ratio with a short label.
  2. **QA folder naming**: the task brief said `docs/qa/revamp-<unit id>/README.md` (no date); STANDARDS.md §16.1 EVID-1/§18.2 G32 requires `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/README.md`. Followed STANDARDS (the named rulebook) and used the dated form; noting the mismatch as instructed rather than silently picking one.
- New kit parts (KIT-3): `KitChip`, `KitChipWrap` (both this unit's own charter — not new beyond it).
- Map items (EVID-11): none (no map page names this unit).
- States per page (STATE-20): n/a — kit-part unit, no screen pages.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitChip`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`, code head `7bc5b32d7e01abde5c16f8a69b347450372328b2`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is wave-checkpoint work.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `flutter analyze lib test` | no errors, no new issues | "No issues found!" (`run-analyze.txt`) | PASS |
| 2 | `flutter test -j 1 test/kit/kit_chip_test.dart` (the frozen "Tests required" #1–10, plus the G8x reduced-motion samples and G14 keyboard behaviour) | all pass | 37 passed (`run-behavior-tests.txt`) | PASS |
| 3 | `flutter test -j 1 test/goldens/kit/kit_chip_golden_test.dart` (the 28 required PNGs, DPR 3.0, G5 accessibility scan on every shot) | all pass | 28 passed (`run-golden-tests.txt`) | PASS |
| 4 | `flutter test -j 1 test/kit_ratchet_test.dart test/l10n_coverage_test.dart` | pass, no baseline count rises | 34 passed (`run-ratchet-l10n.txt`) | PASS |
| 5 | `flutter test -j 1 test/design_standard_test.dart test/kit/kit_pre_wave_tokens_test.dart` | pass (KitChip touches no `_migrated` file; the pre-wave tokens it depends on — `chipHeight`, `focusRingWidth`, `KitShape.pill` — are already merged) | 21 passed (`run-design-standard-pre-wave.txt`) | PASS |

This unit fixes nothing (new code only), so no failing-first run applies (TEST-2).

## 5. Evidence

- `run-analyze.txt`, `run-behavior-tests.txt`, `run-golden-tests.txt`, `run-ratchet-l10n.txt`, `run-design-standard-pre-wave.txt`: tails of the runs above.
- `contract-problem-G5-915x412.txt`: the PROC-20 investigation in full.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KitChip.md "Tests required" #1 (plain: not a button, no tap action, not focusable) | `test/kit/kit_chip_test.dart` "plain is not a button, has no tap action, is not focusable" | `run-behavior-tests.txt` |
  | #2 (action: onPressed once; selected shows check + toggled; null selected has no toggled flag) | `test/kit/kit_chip_test.dart` group "action" (3 tests) | `run-behavior-tests.txt` |
  | #3 (removable: separate 48×48 ×, tap isolation, Delete/Backspace) | `test/kit/kit_chip_test.dart` group "removable" (5 tests) | `run-behavior-tests.txt` |
  | #4 (count: "{label}, {count}" semantics; `intl` formatting en/ar) | `test/kit/kit_chip_test.dart` group "count" (3 tests) | `run-behavior-tests.txt` |
  | #5 (summary: tap, expanded semantics, chevron direction) | `test/kit/kit_chip_test.dart` group "summary" (3 tests) | `run-behavior-tests.txt` |
  | #6 (48 dp hit area at 1.0/2.0 text; 10 chips in `KitChipWrap` at 320 dp never overlap) | `test/kit/kit_chip_test.dart` group "hit area (LAY-9)" (3 tests) | `run-behavior-tests.txt` |
  | #7 (200 % text ellipsis, full semantics label, no overflow at 320/360/412, LTR/RTL) | `test/kit/kit_chip_test.dart` group "truncation (A11Y-8, G6)" (7 tests) | `run-behavior-tests.txt` |
  | #8 (no text below full alpha, no attention role) | `test/kit/kit_chip_test.dart` group "honesty (LOOK-14, LOOK-4)" | `run-behavior-tests.txt` |
  | #9 (reduced motion settles after one `pump()`) | `test/kit/kit_chip_test.dart` `kitMotionStillTests('KitChip', ...)` (G8x, MOT-7) | `run-behavior-tests.txt` |
  | #10 (keyboard: Tab order chip-then-×, Enter/Space activate) | `test/kit/kit_chip_test.dart` group "keyboard (G14)" | `run-behavior-tests.txt` |
  | Galleries required (28 PNGs at the stated states/sizes/scales, DPR 3.0) | `test/goldens/kit/kit_chip_golden_test.dart` | `run-golden-tests.txt`, the 28 PNGs |
  | KIT-24 (ChoiceChip stays with KitSegmented) | not built here (non-goal) | n/a |

- Changed test expectations (TEST-19): none (no existing test touched).
- Goldens changed (each opened and looked at):
  - All 28 `test/goldens/kit/kit_chip_*.png` are new (first commit of this part); no approved VL canvas render exists for KitChip to compare against (EVID-12: "no approved render"). Looked at: `kit_chip_default_dark.png` (all five kinds, ground and surface1 rows), `kit_chip_selected_dark.png` (check on/off), `kit_chip_expanded_dark.png` (chevron up/down), `kit_chip_focused_dark.png` (accent ring around the × specifically, per KitChip.md's own gallery description), `kit_chip_truncated_dark.png` (all five kinds ellipsised), `kit_chip_default_text2_1280x800_light.png` (pill grows past `chipHeight` at 200 % text — this fixed a real bug, see below), `kit_chip_default_ar_dark.png` (RTL mirroring: × and the plain/count/summary content flow start-to-end correctly, `file.txt` stays LTR-isolated).
- Bug found and fixed while regenerating: `_PillSurface` first used a fixed-height `SizedBox(height: chipHeight)`, so a chip's pill could not grow past 32 dp at 200 % text, contradicting KitChip.md's "200 % text: the pill grows in height with the text (chipHeight is a minimum)". Changed to `ConstrainedBox(minHeight: chipHeight)`; only the four `*_text2_*` PNGs changed on regeneration (diffed byte-for-byte against the pre-fix set before committing the fix).
- Before and after: n/a — KitChip has no earlier golden or census render (EVID-10, "no before render", page id: none — KitChip is not a map page).
- Accessibility: 48 dp targets asserted at text 1.0 and 2.0 (test #6); full labels in semantics under truncation at text 2.0 (test #7); keyboard Tab order and Enter/Space activation (test #10); RTL mirroring rendered in the gallery (`*_ar_*.png`); focus ring rendered in the gallery (`kit_chip_focused_*.png`); no colour-only state (STATE-9: selected uses a check glyph *and* `toggled` semantics; no attention role used, test #8).
- Privacy and security: n/a — no credentials, stored data, external links or notifications changed.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F analyze lib test
$F test -j 1 test/kit/kit_chip_test.dart
$F test -j 1 test/goldens/kit/kit_chip_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/l10n_coverage_test.dart
$F test -j 1 test/design_standard_test.dart test/kit/kit_pre_wave_tokens_test.dart
```

`lib/l10n/app_localizations*.dart` were regenerated locally (`flutter gen-l10n`) to compile and run the above, then left uncommitted per PROC-13 (the integrator regenerates and commits them after merge, G27).

## 7. NOT proven

- Not run on a device or emulator (no APK; unit agents do not build).
- G5's automated accessibility scan (`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`, reading-order check) does not run on the `focused` gallery shot: it needs `kit_gallery.dart`'s private `expectKitGalleryAccessible`, and that shot uses a small local harness instead (no interaction hook exists on the shared `kitGalleryPart`/`kitGalleryShot` for driving keyboard focus before comparing). `tester.takeException()` is asserted null on that shot; nothing else in this file skips the shared scan.
- No screen anywhere calls `KitChip` yet (by design — this unit's non-goal); its first real callers (kit-KitComposerChips, kit-KitWorkLine, kit-KitSearchField) are separate, later units per KitChip.md "Depends on: Depend on it (C25)".
- TalkBack/VoiceOver was not run by a human; semantics were checked through `flutter_test`'s semantics tree and the G5 guideline only.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitChip` |
| Enabled | No: not exported from `lib/ui/kit/kit.dart` yet (integrator step, R06) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `7bc5b32d7e01abde5c16f8a69b347450372328b2` |
| Deployed | No | |
| Released | No | |
