# revamp-kit-KitIcon: KitIcon (2026-09-26)

## 1. Scope

- Unit: `kit-KitIcon` (wave 1, tier 1a, kit-part). Finish line: KitIcon is
  the one way to draw a glyph, at exactly 20/22/24 logical px, in an opaque
  colour role, and `AppGlyph`/`AppBrandMark` move into it unchanged so the
  34 existing importers of `app_iconography.dart` keep compiling and that
  file's own G16 count reaches zero. Non-goal: no call-site migration (no
  screen changes any `Icon(`/`AppGlyph(` to `KitIcon(`), no new glyphs, no
  `KitIconButton`/tooltip/tap handling, no `kit.dart` export or doc-table
  row (R06, the integrator's job).
- Files changed: `lib/ui/app_iconography.dart` (trimmed: `AppGlyph`,
  `AppBrandMark` and the duotone background map moved out; adds a
  re-export), `lib/ui/kit/kit_icon.dart` (new: `KitIcon`, `KitIconSize`,
  `KitBrandMark`, `KitBrandMarkSize`, plus the moved `AppGlyph`/
  `AppBrandMark`), `test/kit/kit_icon_test.dart` (new), `test/goldens/kit/
  kit_icon_golden_test.dart` (new, 30 PNGs).
- Pages (map ids): none — KitIcon is a kit-only part with no page of its
  own (kit-v2.json `assignment`: no element assigned, per KitIcon.md).
- Specs followed: `docs/ux-system/kit-api/KitIcon.md` (frozen API, full
  text); `docs/ux-system/kit-v2.md` §7, §9.1, §9.2; `docs/design/
  visual-language-2026-09-26.md` §7 (icon sizes, pixel alignment);
  STANDARDS.md §1, §4, §5.5, §12, §15 (this unit's read set per §0.4).
- Contract problems (PROC-20):
  1. **`KitTokens.toneFor` is not a pre-wave seam, though KitIcon.md's
     "Open questions" says it is settled.** KitIcon.md (Public API,
     `KitIcon.status` doc comment) and its Open Questions section both
     say `KitTokens.toneFor`/`toneColor(AppStatusTone)` is a pre-wave seam
     the coordinator adds "with the other seams," with "no open
     questions." But `docs/ux-system/kit-api/_new-tokens.md`'s own "Not
     added here" section says: *"`KitTokens.toneFor` / `toneColor
     (AppStatusTone)` (README.md decision D12; ...): the tone map needs
     the D12 table, which is not in the mention list"* — i.e. it was not
     added. `docs/ux-system/revamp/STANDARDS.md` §0.5 step 2 lists the
     exact seams the coordinator adds before wave 1 (`KitCopy.copy`,
     `KitBidi.ltr`/`auto`, `KitTokens.hairlineWidth`/`focusRingWidth`, the
     named `KitLayout` widths, the named `kit_motion.dart` waits) and
     `toneFor`/`toneColor` is not among them. §0.5 step 3 also forbids a
     wave-1 unit from editing `kit_tokens.dart`, so this unit cannot add
     the missing seam itself. Two other pre-wave tokens the same doc's
     Public API section names (`KitTokens.duotoneWash`, confirmed present
     at `lib/ui/kit/kit_tokens.dart:305`; `KitTokens.popoverRadius`,
     present at line 316) really were added, which is why this one
     specific gap was not obvious from a first read.
     - Evidence: `docs/ux-system/kit-api/_new-tokens.md:118-122`;
       `docs/ux-system/revamp/STANDARDS.md:96-97` (§0.5 step 2); KitIcon.md
       lines 68, 82, 161, 190.
     - Resolution taken: §0.2 does not settle this (it is not a
       same-level VL/K2/DS conflict; it is a coordinator seam that was
       never built). Per PROC-20(2), the item is left at the one
       behaviour the frozen spec's own prose already spells out in full
       (KitIcon.md lines 67-72: neutral → secondary, progress → accent,
       ok → success, attention → primary, failure → primary), implemented
       as a private `_statusTone` map in `kit_icon.dart` that calls the
       existing shared `KitText.toneColor` (never a new literal colour),
       documented at the top of the file and beside the map itself.
     - Proposed replacement text: `_new-tokens.md`'s "Not added here"
       entry for `toneFor`/`toneColor` moves to the main seam table with
       the D12 mapping KitIcon.md, KitNotice.md, KitStatusMark.md,
       KitStateView.md, KitProgress.md and KitStatusLine.md all already
       state in words, and STANDARDS §0.5 step 2 gains it as a sixth
       bullet; the coordinator then deletes `kit_icon.dart`'s private
       `_statusTone` in favour of the shared token.
     - `blocks: false` — every KitIcon.md acceptance criterion and all 11
       required behaviour tests pass with this reading (see §4 below);
       nothing about the unit's own finish line depends on the token's
       name being `KitTokens.toneFor` rather than a local equivalent.
  2. **Minor, non-blocking:** this task's own instructions name the QA
     path as `docs/qa/revamp-<unit id>/README.md` (no date), but
     STANDARDS.md EVID-1 and the G32 folder-name gate both require
     `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/`. Followed STANDARDS.md (the
     higher-ranked, gate-checked rule per its own §0.2) and recorded the
     conflict here rather than picking one silently.
- New kit parts (KIT-3): `KitIcon` (+`KitIconSize`), `KitBrandMark`
  (+`KitBrandMarkSize`) in `lib/ui/kit/kit_icon.dart`.
- Map items (EVID-11): n/a — no map page is assigned to this unit.
- States per page (STATE-20): n/a — not a page; KitIcon's own states
  (fixed/growsWithText, `.status`'s five tones, duotone/high-contrast) are
  covered by `test/kit/kit_icon_test.dart` and the golden gallery (§4, §5).
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitIcon`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`
  (`feat/phone-setup-v2` tip at branch creation), code head
  `72f4dac6` (the branch's only commit so far).
- No APK (unit agents do not build; R19/R20 also forbid it here).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator/wave
checkpoint work (R19, R20).

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `flutter analyze lib/ui/kit lib/ui/app_iconography.dart test/kit/kit_icon_test.dart test/goldens/kit/kit_icon_golden_test.dart` | no issues | "No issues found! (ran in 4.5s)" | PASS |
| 2 | `flutter test -j 1 test/kit/kit_icon_test.dart` | all 11 frozen-spec behaviours pass | 25 passed | PASS |
| 3 | `flutter test -j 1 test/goldens/kit/kit_icon_golden_test.dart` | 30 shots, each theme, G5 accessibility clean | 30 passed | PASS |
| 4 | `flutter test -j 1 test/kit_ratchet_test.dart` | G16 drops for `app_iconography.dart` (Icon 2→0, Opacity 1→0), G17 drops (`.colorScheme` 1→0); nothing rises | 33 passed, printed the two drops (baseline untouched, R05) | PASS |
| 5 | `flutter test -j 1 test/app_iconography_test.dart test/kit/kit_pre_wave_tokens_test.dart` | unchanged, still pass | 11 passed | PASS |
| 6 | `flutter test -j 1 test/composer_layout_test.dart test/desktop_context_menu_test.dart test/desktop_shortcuts_test.dart` | unchanged, still pass | 39 passed | PASS |
| 7 | `flutter test -j 1 test/global_sessions_screen_test.dart test/permission_sheet_test.dart test/session_context_screen_test.dart` | unchanged, still pass | 46 passed | PASS |
| 8 | `flutter test -j 1 test/termux_setup_screen_test.dart` | unchanged, still pass | 54 passed | PASS |
| 9 | `flutter test -j 1 test/text_scale_overflow_test.dart` (G6) | unaffected (KitIcon not yet in the kit.dart manifest) | 75 passed | PASS |
| 10 | `flutter test -j 1 test/kit_motion_test.dart` (G8x) | unaffected (same reason) | 179 passed | PASS |
| 11 | `flutter test -j 1 test/design_standard_test.dart` (G3x) | unaffected | 15 passed | PASS |
| 12 | `flutter test -j 1 test/l10n_coverage_test.dart` | unaffected (no new user-facing copy) | 2 passed | PASS |
| 13 | `flutter test -j 1 test/kit/kit_manifest_test.dart` (G4) | **fails**: KitIcon/KitBrandMark/AppGlyph/AppBrandMark are not yet exported from `kit.dart` (R06, integrator) | 1 passed, 1 failed, 22 violations listed | **FAIL — sharedTestsBroken, see below** |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule/req | Test (`file` + `--plain-name`) | Result |
  |---|---|---|
  | Sizes 20/22/24 (VL §7, C02) | `test/kit/kit_icon_test.dart` "fixed sizes render at exactly 20, 22 and 24 logical px at text scale 1.0 and 2.0" | pass |
  | growsWithText rounding | `test/kit/kit_icon_test.dart` "growsWithText scales up to 1.5x and rounds to a whole physical pixel" | pass |
  | Debug assert (font family) | `test/kit/kit_icon_test.dart` "the debug assert rejects Icons.add and passes AppIconography.add and AppIcons.copy" | pass |
  | A11Y-1 decorative default / labelled | `test/kit/kit_icon_test.dart` "decorative by default; semanticsLabel gives one image node" | pass |
  | D12 tone map (contract problem §1) | `test/kit/kit_icon_test.dart` "maps each AppStatusTone to the tone the spec names; failure is not danger and attention is not the attention role" | pass |
  | LAY-8 RTL mirroring | `test/kit/kit_icon_test.dart` "AppIconography.back mirrors under RTL; AppIconography.check does not" | pass |
  | Duotone + high contrast | `test/kit/kit_icon_test.dart` "draws two layers, one under high contrast" | pass |
  | Alpha 255 (§7) | `test/kit/kit_icon_test.dart` "every KitTextTone colour is fully opaque" | pass |
  | KIT-43 AppGlyph/AppBrandMark re-export | `test/kit/kit_icon_test.dart` "AppGlyph still builds..." / "AppBrandMark still builds..." | pass |
  | Reduced motion (MOT-7) | `test/kit/kit_icon_test.dart` `kitMotionStillTests('KitIcon', ...)` — 8 sub-tests | pass |
  | G16 zero on `app_iconography.dart` | `test/kit_ratchet_test.dart` (prints the drop; baseline re-bake is R05/the integrator's) | pass (drop observed) |
  | Galleries (states, sizes, text2, ar) | `test/goldens/kit/kit_icon_golden_test.dart` — 30 shots | pass |

- Goldens changed (each opened and looked at with the Read tool before
  committing):
  - `kit_icon_sizes_light.png` / `_dark.png`: three rows (small/medium/
    large), five tones each (primary/secondary/accent/success/danger);
    sizes visibly increase, tone colours match the theme roles, no
    approved VL canvas render exists for this brand-new part (EVID-12:
    "none").
  - `kit_icon_status_light.png` / `_dark.png`: the five `AppStatusTone`
    icons beside their words; confirms visually that "Needs a key"
    (attention) and "Could not connect" (failure) both render in the
    neutral/primary tone, not amber or red — the contract-problem
    resolution above, seen, not just asserted.
  - `kit_icon_duotone_light.png` / `_dark.png`: the selected workspace
    glyph and its high-contrast fallback; the wash is subtle by design
    (`duotoneWash` = 0.2), confirmed structurally by the widget test
    (exactly one `Opacity` at that value) since the two shots read as
    near-identical at this print size.
  - `kit_icon_sizes_ar_dark.png`, `kit_icon_sizes_text2_light.png`:
    looked at directly; Arabic mirrors the row (labels right-aligned,
    RTL text), 2.0 text wraps each tone's caption onto its own line
    without overflow.
  - The other 24 PNGs (the remaining LAY-4 sizes and the `status`/`sizes`
    ar/text2 combinations at 1280×800) were generated and pass the G5
    accessibility gate (which itself fails loudly on contrast, tap-target
    or reading-order problems) and the pixel-diff comparison on the
    unmodified second run, but were not each individually opened with the
    Read tool — sampled by scene/theme/variant rather than exhaustively
    (see NOT proven).
  - No approved `docs/design/visual-language-2026-09-26.md` canvas render
    exists for KitIcon yet (EVID-12: "none" for every shot).
- Before/after (EVID-10): n/a — `KitIcon` is new; there is no earlier
  golden or census PNG of it to diff against. `app_iconography.dart`'s own
  behaviour is unchanged (`test/app_iconography_test.dart` passes
  byte-for-byte against its prior assertions), so no before/after pair
  applies there either.
- Accessibility: decorative by default (`ExcludeSemantics`), one image
  node with `semanticsLabel` when given (tested); RTL mirroring verified
  for a directional glyph and not for a non-directional one; 200% text
  keeps the fixed sizes exactly at 20/22/24 and caps a growing icon at
  1.5×, both asserted; every gallery shot runs
  `androidTapTargetGuideline`/`labeledTapTargetGuideline`/
  `textContrastGuideline`/reading-order (G5) and all 30 passed clean, no
  new `kit_gallery_g5_baseline.json` entry needed.
- Privacy and security: n/a — no credentials, stored data, external links
  or notifications are touched by this unit.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F analyze lib/ui/kit lib/ui/app_iconography.dart test/kit/kit_icon_test.dart test/goldens/kit/kit_icon_golden_test.dart
$F test -j 1 test/kit/kit_icon_test.dart
$F test -j 1 test/goldens/kit/kit_icon_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/app_iconography_test.dart test/kit/kit_pre_wave_tokens_test.dart
$F test -j 1 test/composer_layout_test.dart test/desktop_context_menu_test.dart test/desktop_shortcuts_test.dart
$F test -j 1 test/global_sessions_screen_test.dart test/permission_sheet_test.dart test/session_context_screen_test.dart
$F test -j 1 test/termux_setup_screen_test.dart
$F test -j 1 test/text_scale_overflow_test.dart test/kit_motion_test.dart test/design_standard_test.dart test/l10n_coverage_test.dart
$F test -j 1 test/kit/kit_manifest_test.dart   # expected to fail — see "sharedTestsBroken"
```

## 7. NOT proven

- Not run on a device or emulator (R19/R20: coordinator work).
- 24 of the 30 golden PNGs were generated and pass every automated check
  (pixel diff, G5 accessibility) but were not each individually opened
  with the Read tool — only a representative sample per scene/theme/
  variant was (see §5).
- `flutter build apk --release` was not run (out of this unit's scope; no
  Android/Kotlin surface changed).
- Whole-repo `flutter analyze`/`flutter test` were not run (out of budget
  for a single kit-part unit; scoped runs above cover every file this
  unit touched or that names it in its explicit tests write set).
- `test/kit/kit_manifest_test.dart` (G4) fails until the integrator
  exports `KitIcon`/`KitBrandMark` from `kit.dart` with doc-table rows
  (R06); see `sharedTestsBroken`. `AppGlyph`/`AppBrandMark` also fail
  G4's `Kit<Name>`/gallery/test/docRow checks purely because they are
  retired shims living in the kit folder (R12), not new kit citizens —
  the integrator decides whether that needs an allowlist entry
  (`test/kit/kit_manifest_allowlist.json`, which this unit does not
  edit).
- `KitBrandMark` living inside `kit_icon.dart` (as the frozen spec's own
  "File" section requires) conflicts with G4's NAME-1 expectation that a
  `Kit<Name>` class lives in its own `kit_<snake>.dart` file; not resolved
  here since fixing it would mean either violating the frozen write set
  (R16) or contradicting the frozen spec text — left for the integrator/
  coordinator alongside the `toneFor` contract problem.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitIcon` |
| Enabled | Yes — `KitIcon`/`KitBrandMark` are usable today by any file that imports `package:opencode_mobile/ui/kit/kit_icon.dart` directly; not yet reachable via `kit.dart` (integrator, R06) |
| Verified | Tests and goldens only (no device) |
| Committed | Yes | code head `72f4dac6` |
| Deployed | No | |
| Released | No | |
