# integrate-vl-gates: the visual language merge meets the wave-0b gates (2026-09-26)

## 1. Scope

- Integration step, not a unit. `feat/visual-language-v1` was merged into `feat/phone-setup-v2` as `ddcb6bc7`; it was built before the wave-0b gates (G4, G5, G6, G8x, G21, G23) existed, and ten gate tests failed on the merge (`before-gates.txt`). Finish line: every gate file, the theme, l10n and ledger tests, `test/kit/` and `test/goldens/kit/` pass, and `flutter analyze lib test` is clean. Non-goal: rebuilding any kit part; that stays with the wave-1 unit named for each entry below.
- What was added (commit `b72cf95f`):
  - Motion samples (G8x, MOT-7): `kitMotionStillTests('KitText' | 'KitRowGroup' | 'KitRowValue', …)` in `test/kit/kit_text_test.dart`, `test/kit/kit_row_group_test.dart`, `test/kit/kit_row_value_test.dart` (new), with first behaviour checks (role size and tone colour, a role's own tone, mono stays left to right in Arabic, section heading above the rows with one separator between rows, value before its chevron, a long value stays on one line).
  - Overflow scenes (G6): `KitText/default` (every role, English and Arabic) and `KitRowGroup/default` covering `KitRowGroup` and `KitRowValue`, appended to `test/kit/kit_overflow_scenes.dart`.
  - G4: `States: none — …` lines on `KitText`, `KitRowGroup`, `KitRowValue` (doc comments only); `[KitRowGroup]`, `[KitRowValue]` in the `kit.dart` doc table.
  - G23: `kit_foundation_golden_test.dart` names its goldens with `kitGalleryName` (412×915 left out; 8 PNGs renamed with `git mv`, pixels unchanged). The gate's Arabic-theme regex also accepts `kitGalleryPart(`, which the VL branch added and which renders through the same Noto Sans Arabic fallback theme as `kitGalleryShot` (`test/goldens/kit/kit_gallery.dart` `_theme`). No other G23 rule changed.
  - TEST-9: `kitGalleryPixelRatio` (3.0 phone, 2.0 tablet, 1.0 PC; dead after the merge resolution) removed from `kit_gallery.dart`, so nothing there contradicts DPR 3 everywhere.
  - G5: the one baseline entry (`kit_confirm_destructive_text2_1280x800_light` / `textContrast` / `Cancel`) now passes under the VL look and was removed; the harness ceiling is untouched (its self-tests use it).
- Rules: MOT-7, A11Y-2, LAY-4, KIT-12, KIT-14, NAME-1, TEST-9, TEST-15, TEST-20, TEST-8, LOOK-19, LOOK-21, LAY-6, LAY-7.
- Contract problems (PROC-20):
  1. {NAME-1 and G4 `name`/`gallery`/`test`, "class `Kit<Name>` in `lib/ui/kit/kit_<snake>.dart`" and one gallery per part, `docs/ux-system/kit-api/KitRow.md` §Files and open question 3 keep `KitRowGroup` and `KitRowValue` in `kit_row.dart` with one gallery file per unit, evidence `test/kit/kit_manifest_test.dart` `_creationAllowlist`, proposed: G4 maps each export to its unit's file (as KitRow.md says it will), or KitRow.md moves them to NAME-1 files; allowlisted until kit-KitRow-v2 settles it, blocks: false}.
  2. {the brief for this step, "KitActionBlock/default and KitSheet default/disabled/full/loading overflow at text 2.0", they no longer overflow: the G6 failures were "improved … fixed" (`before-gates.txt` lines 395–590), so the baseline and the ceiling shrank instead; kit-KitAction-v2 still owns KitActionBlock's stacked fallback (KIT-24), but G6 no longer holds an entry for it, blocks: false}.

## 2. Builds

- Branch `feat/phone-setup-v2`, base `e6d8ee5d` (after the VL merge `ddcb6bc7`). Code head `cd2e678e` (`b72cf95f` part coverage, `cd2e678e` baselines); this record is the next commit.
- No APK (tests and goldens only).

## 3. Devices

None: tests, goldens and analyzer only, on the maintainer's PC with the pinned Flutter 3.47.1 (`91f8bd75`).

## 4. Runs

All with `F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter` through `tool/qa/machine_lock.sh`.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | The five gate files on `e6d8ee5d` | the reported failures | `+284 -10: Some tests failed.`: G4 (13 violations), G8x (3 parts), G21 (3 new), G6 (3 parts without scenes; KitActionBlock and 4 KitSheet scenes "improved"), G23 (arabicFont + 8 golden names); see `before-gates.txt` | PASS (reproduced) |
| 2 | `test/goldens/kit` on `e6d8ee5d`, no update | goldens match the DPR 3 harness | every golden matched; 2 failures were only the stale G5 entry | PASS |
| 3 | `KIT_RATCHET_WRITE=1 … test/kit_ratchet_test.dart` once | baseline written | `wrote test/kit_ratchet_baseline.json for every gate`; diff reviewed, table below | PASS |
| 4 | `G6_OVERFLOW_WRITE=1 KIT_MANIFEST_WRITE=1 GOLDEN_HARNESS_WRITE=1` over G6, G4, G23 once | baselines written | G6 wrote `{}` (write never adds); `KitRowGroup/default` overflowed at 4 combinations and was added by hand to the ceiling and baseline; G23 rewrote an identical file; G4 had nothing stale | PASS |
| 5 | Probe (throwaway test, deleted) of KitRow + KitRowValue at 320 dp, text 2.0 | find the overflowing element | `KitRowValue('Claude Sonnet 4')` trailing: overflow; KitRowGroup label alone: none | PASS |
| 6 | Gate files, `theme_roles`, `app_theme`, `theme_packs`, `l10n_coverage`, `ui_ledger_coverage`, `test/kit`, `test/goldens/kit` at `cd2e678e`, `-j 3` | all pass | `00:42 +494: All tests passed!`; see `after-gates.txt` | PASS |
| 7 | `flutter analyze lib test` | clean | `No issues found!`; see `analyze.txt` | PASS |

### Baseline entries added, each VL-merge code, with its owner

| Gate | Entry | Source line (VL commit) | Owner unit |
|---|---|---|---|
| G21 | `lib/ui/kit/kit_request_card.dart` "BorderRadius.circular(<n>" 1 | `:177 BorderRadius.circular(10)` (`7bf7924c`) | kit-KitRequestCard-v2 |
| G21 | `lib/ui/kit/kit_confirm_sheet.dart` "EdgeInsets numeric" 1 | `:648 EdgeInsets.only(top: 1)` (`f5370bd3`) | kit-KitDetailsFold (writes `kit_confirm_sheet.dart` in wave 1) |
| G21 | `lib/ui/kit/kit_notice.dart` "stroke width not KitTokens in kit" 1 | `:228 Border.all(color: line, width: 0)` (`f5370bd3`) | kit-KitNotice-v2 |
| G6 | `KitRowGroup/default` 320x640 text 2.0 ltr and rtl (55 px), 360x740 text 2.0 ltr and rtl (15 px) | `KitRow` puts `trailing` unflexed in its `Row`, so `KitRowValue` takes its full width (`f5370bd3`) | kit-KitRow-v2 (KitRow.md test 11: no overflow at 2.0 and 320 dp) |
| G4 allowlist | `name` KitRowGroup, KitRowValue | declared in `kit_row.dart` (`f5370bd3`) | kit-KitRow-v2 |
| G4 allowlist | `gallery` KitRowGroup, KitRowValue | shown today in `kit_foundation_golden_test.dart` | kit-KitRow-v2 (`kit_row_golden_test.dart`) |
| G4 allowlist | `gallery` KitText | shown today in `kit_foundation_golden_test.dart` | kit-KitText-v2 (`kit_text_golden_test.dart`) |

`f5370bd3` and `7bf7924c` are ancestors of the VL branch head (`ddcb6bc7^2`) and not of the pre-merge base `2591391a` (`git merge-base --is-ancestor`). No pattern, scan or rule was loosened; the G4 and G6 ceilings gained only the entries above (commit bodies carry `ratchet-tighten:` lines).

### Baseline entries removed (the merge improved them)

- G16 `lib/ui/screens/chat/composer.dart` DecoratedBox 1→0.
- G17 `lib/ui/kit/glass/kit_glass.dart` Colors.* 3→2; `lib/ui/kit/kit_tokens.dart` Colors.* 1→0; `lib/ui/widgets/product_states.dart` .textTheme 5→4.
- G21 `kit_glass.dart` Radius.circular 1→0; `kit_buttons.dart` SizedBox numeric 4→2; `kit_request_card.dart` EdgeInsets numeric 6→3, SizedBox numeric 2→1; `composer.dart` boxShadow 1→0.
- G6 `KitActionBlock/default` (4 combinations) and `KitSheet/default|disabled|full|loading` (2 each): fit everywhere; removed from the baseline and the ceiling.
- G5 `kit_confirm_destructive_text2_1280x800_light` / textContrast / Cancel.

## 5. Evidence

- `before-gates.txt` (run 1), `after-gates.txt` (run 6), `analyze.txt` (run 7).
- Goldens (TEST-6, EVID-12): no kit golden changed in pixels. The only PNG changes are 8 renames: `kit_foundation_{type,work,work_ar,work_text2}_412x915_{dark,light}.png` → `kit_foundation_{type,work,work_ar,work_text2}_{dark,light}.png`. With the exact comparator, every kit gallery at every size already matched the DPR 3 harness, so `--update-goldens` had nothing to re-render. Looked at: `kit_foundation_work_dark.png`, `kit_foundation_work_ar_light.png`, `kit_sheet_default_1280x800_dark.png`, `kit_confirm_destructive_text2_1280x800_light.png`: crisp Geist and Noto Sans Arabic text, 1 px hairlines between grouped rows, right-to-left layout with mirrored chevrons in Arabic, no clipping except the confirm sheet's body scrolling under its actions at 2.0 text (as designed).
- Rule evidence (PROC-31):

  | Rule | Test | Output |
  |---|---|---|
  | MOT-7 | `KitText (MOT-7)`, `KitRowGroup (MOT-7)`, `KitRowValue (MOT-7)`; `every kit.dart part has reduced-motion samples (G8x)` | `after-gates.txt` |
  | A11Y-2, LAY-4 | `G6 kit overflow matrix KitText/default …`, `KitRowGroup/default …`, `every exported kit part has a scene` | `after-gates.txt` |
  | KIT-12, KIT-14, NAME-1, TEST-15 | `G4: every kit part and opener meets the manifest` | `after-gates.txt` |
  | TEST-8, TEST-9, TEST-20 | `G23 golden harness ratchet`; `kit_foundation_golden_test.dart` | `after-gates.txt` |
  | LOOK-19, LOOK-21, LAY-6 | `G21 look and motion` | `after-gates.txt` |

- Changed test expectations (TEST-19): none. Gate files changed: `test/golden_harness_test.dart` (the Arabic-theme regex accepts `kitGalleryPart`), `test/kit/kit_manifest_test.dart` (`_creationAllowlist` gains the 5 entries above), `test/text_scale_overflow_test.dart` (`_overflowCeiling` swapped as above); `test/kit_motion_test.dart` untouched.
- Accessibility: no `lib/` behaviour changed (doc comments only). The G5 contrast finding on the light confirm sheet at 2.0 text is gone under the VL colours.
- Privacy and security: n/a, no credentials, stored data, links or notifications changed.
- Migration: n/a, no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
tool/qa/machine_lock.sh test -- $F test -j 3 \
  test/kit/kit_manifest_test.dart test/kit_motion_test.dart \
  test/text_scale_overflow_test.dart test/kit_ratchet_test.dart \
  test/golden_harness_test.dart test/theme_roles_test.dart \
  test/app_theme_test.dart test/theme_packs_test.dart \
  test/l10n_coverage_test.dart test/ui_ledger_coverage_test.dart \
  test/kit test/goldens/kit
tool/qa/machine_lock.sh analyze -- $F analyze lib test
# Run 1: git checkout e6d8ee5d and run the five gate files.
```

## 7. NOT proven

- Not run on a device or emulator; no screen outside the kit galleries was rendered for this step.
- The full serial suite was not run; only the files in run 6. Screen goldens outside `test/goldens/kit/` that the VL merge re-rendered were not rechecked here.
- `KitRowValue` inside `KitRow` still overflows at text 2.0 on 320 and 360 dp phones (baselined, owner kit-KitRow-v2); screens that use it today carry the same overflow.
- The new tests for KitText, KitRowGroup and KitRowValue are first checks, not the kit-api contracts (G19 for KitText, KitRow.md tests 1–11); the owning units write those.
- The G5 ceiling in `kit_gallery.dart` still names the removed entry, so the same entry could come back without failing (as the gate-G5 record says); only a reviewer or G31 would see it.
- G31 (`tool/qa/check_ratchets_only_shrink.py`) does not exist yet, so the `ratchet-tighten:` lines are not machine-checked.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `b72cf95f`, `cd2e678e` |
| Enabled | Yes: the gates run in the normal suite | `test/` |
| Verified | Yes, for the files in run 6 and the analyzer; not the full suite | `after-gates.txt`, `analyze.txt` |
| Committed | Yes, locally on `feat/phone-setup-v2` | this commit |
| Deployed | No | – |
| Released | No | – |
