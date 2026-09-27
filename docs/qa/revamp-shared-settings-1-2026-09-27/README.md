# revamp-shared-settings-1: Revamp settings (3 files) (2026-09-27)

## 1. Scope

- Unit: `shared-settings-1` (wave 2a, screen-revamp). Finish line: every file in the write set has a G16 count of zero, each page is handled by its map proposal, the look is VL. Non-goal: no gateway call, controller field or persistence added; the Plugins row fold ("Found on Laptop · Turn on") is not built here (the row lives in `plugins_screen.dart` / `server_plugins_section.dart`, other units).
- Files changed: `lib/ui/widgets/appearance_picker.dart`, `lib/ui/widgets/language_picker.dart`, `lib/ui/widgets/team_discovery_card.dart`, `lib/l10n/app_en.arb` (7 new keys), `test/appearance_picker_test.dart`, `test/appearance_preview_capture_test.dart`, new `test/revamp/shared_settings_1_test.dart`, `test/revamp/shared_settings_1_golden_test.dart`, `test/revamp/shared_settings_harness.dart`, 16 PNGs under `test/revamp/goldens/settings_{language_sheet,theme_pack_preview_sheet,team_discovery_card}_*`.
- Pages (map ids): appearance-picker-sheet, embedded-team-discovery-card, language-sheet, theme-pack-preview-sheet.
- Specs followed: STANDARDS.md MAP-1, KIT-1, KIT-4, KIT-43, LOOK-1, LOOK-14, STATE-7, STATE-8, COPY-29, DATA-11, TEST-1, TEST-5, TEST-8, TEST-19, TEST-20; kit-api KitSheet, KitChoiceList, KitSegmented, KitSurface, KitSwatch (KitThemePreview), KitAction, KitUndo, KitNotice; target-ia cross-cutting ("partly translated, N %").
- Contract problems (PROC-20):
  - The task text asks for `docs/qa/revamp-<unit id>/README.md`; STANDARDS EVID-1 asks for `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/`. This record follows EVID-1.
  - The task text says copy goes to `app_en.arb` AND `app_ar.arb` (R04) but the owner decision of 2026-09-27 drops Arabic ("app_en.arb only"). The later owner decision wins (R15); no Arabic entries were added.
  - The task says "old APIs stay as @Deprecated wrappers" (R11) and also "no @Deprecated (KIT-43)". `ThemeComponentPreview` had no caller in `lib/`, `test/` or `tool/`, so it was removed outright (KIT-43: removal by the unit that brings the count to zero), not wrapped.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - appearance-picker-sheet (proposal remove → slice-P3.1): kit-only, least change; `// revamp: remove (slice-P3.1)` above `_AppearancePreviewSheet`. No actionsMissing/statesMissing. couldBeAutomatic: all "no".
  - theme-pack-preview-sheet (fix): infoMissing "the pack on real surfaces" → done: `KitThemePreview` (goldens `settings_theme_pack_preview_sheet_other_*`); actionsMissing "undo after Apply" → done: `shared_settings_1_test.dart` "Apply saves the pack and Undo puts the old one back"; honest-state "disabled button as status" → done: "In use now" line (`settings_theme_pack_preview_sheet_in_use_*`, test "the pack in use says so in words, not a disabled button"). couldBeAutomatic: all "no".
  - language-sheet (fix): infoMissing "that Arabic is partial" → done: "Partly translated (90 %)" under العربية (test "Arabic says it is partly translated, with the share"; goldens `settings_language_sheet_loaded_*`); the share is guarded by "the Arabic share is the real coverage, within 3 points". couldBeAutomatic "Use system language default (already)" → unchanged, still the default.
  - embedded-team-discovery-card (fix): "plain words, stacked buttons" → done: KitSurface panel, Turn on stacked over Not now on a phone (test "says what was found and stacks Turn on over Not now", goldens `settings_team_discovery_card_offer_*`); "fold the offer into the row" → deferred to the Plugins row owner (slice-P3.1 owns `server_plugins_section.dart`). couldBeAutomatic "no (consent stays one tap)" → unchanged.
- States per page (STATE-20):
  - language-sheet: loaded (system selected) → golden; save refused → `test/language_picker_test.dart` "save refusal stays on sheet…" (passes).
  - theme-pack-preview-sheet: other pack (Apply) → golden + test; current pack (In use now) → golden + test; Material You unavailable → golden + `appearance_picker_test.dart`; save failed → `appearance_picker_test.dart` "pack save failure…".
  - appearance-picker-sheet: current / other choice / save failed → `appearance_picker_test.dart` (no goldens: remove, MAP-1).
  - embedded-team-discovery-card: offer → golden; dismissed → `team_plugins_screen_test.dart` "appears once and stays dismissed" (passes); turning on (working) and turn-on failed → test "a failed turn-on says so…".
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/shared-settings-1`, base `2cec35ca`, code head `063f4741`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2a checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/shared_settings_1_test.dart` | passes | 6 passed | PASS |
| 2 | `test/revamp/shared_settings_1_golden_test.dart` (after `--update-goldens`, re-run clean) | passes | 16 passed | PASS |
| 3 | `test/appearance_picker_test.dart` (adapted, TEST-19) | passes | 9 passed | PASS |
| 4 | `test/language_picker_test.dart` (shared, unchanged) | passes | 5 passed | PASS |
| 5 | `test/team_plugins_screen_test.dart --plain-name "discovery card"` (shared, unchanged) | passes | 3 passed | PASS |
| 6 | `test/kit_ratchet_test.dart` | this unit's files drop to 0 in G1/G16 (and G17/G21) | G1 3→0, G16 all → 0 for the three files; the file fails on G17/G21 entries in files outside this unit (`quota_monitor_section.dart`, `kit_choice_list.dart`, `kit_task_card.dart`, `kit_markdown.dart`, `kit_board_lane.dart`, `kit_dialog.dart`, `kit_log_panel.dart`, `kit_checklist.dart`), present on the base | PASS for this unit (pre-existing failures listed) |
| 7 | `flutter analyze` on the changed files, their importers and the test files | no issues | No issues found | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | COPY-29 | `test/revamp/shared_settings_1_test.dart` "Arabic says it is partly translated, with the share", "the Arabic share is the real coverage, within 3 points" | run 1 |
  | DATA-11 | same file, "Apply saves the pack and Undo puts the old one back" | run 1 |
  | STATE-7/STATE-8 | same file, "the pack in use says so in words, not a disabled button" | run 1 |
  | STATE-3 | same file, "a failed turn-on says so, keeps the offer and can retry" | run 1 |
  | KIT-1 (G1/G16 = 0) | `test/kit_ratchet_test.dart` | run 6 |

- Changed test expectations (TEST-19):
  - `appearance_picker_test.dart` "closing a preview…": the sample `FilterChip`/"Try a control" and the text "Close" button no longer exist (KitThemePreview is a picture, KitSheet closes with its X) → now previews light via the segmented control, asserts nothing is saved, and closes with the sheet's Close tooltip (KIT-1, VL §5).
  - same, "Material You preview…": `FilledButton` with null `onPressed` → the reason is shown once and there is no Apply (STATE-8: no dead button); the harvested scheme is checked on `KitThemePreview.roles.accent` instead of a `FilterChip`'s theme (KIT-1).
  - same file: the Scrollable finder takes `.first` (KitSheet has more than one scrollable) and the host sets reduced motion so the preview's working mark settles (G8); pack tests call `KitUndo.commitPending()` so the Undo timer does not outlive the test.
  - `appearance_preview_capture_test.dart` (env-gated, skipped by default): same `.first` and reduced-motion change.
- Goldens added (each opened and looked at; 16 PNGs, 528 KB):
  - `settings_language_sheet_loaded[_1280x800]_{dark,light}.png`: kit sheet, radio choices, "Current" under the system choice, "Partly translated (90 %)" under العربية (Noto Sans Arabic loaded as the fallback a phone would use, TEST-8). No approved VL canvas for this sheet; closest `Settings.png` list look: none different.
  - `settings_theme_pack_preview_sheet_other[_1280x800]_{dark,light}.png`: KitThemePreview in Catppuccin (brightness follows the platform in the shot), Light/Dark segmented, Apply as the one primary; a centred panel on 1280x800.
  - `settings_theme_pack_preview_sheet_in_use_{dark,light}.png`: "In use now" with a check instead of Apply.
  - `settings_theme_pack_preview_sheet_unavailable_{dark,light}.png`: Material You unavailable: the reason only.
  - `settings_team_discovery_card_offer[_1280x800]_{dark,light}.png`: panel with the offer title, what was found, Turn on stacked over Not now (phone) / one end-aligned row (wide).
  - Approved render (EVID-12): no VL canvas shows these sheets; `docs/design/visual-language-2026-09-26/Settings.png` sets the surface/row look they follow.
- Before and after (EVID-10): `before-language-sheet-system-selected.png`, `before-theme-pack-preview-sheet-current-pack.png`, `before-embedded-team-discovery-card-offer.png` (base census, `2cec35ca`); `after-language-sheet-loaded.png`, `after-theme-pack-preview-sheet-in-use.png`, `after-theme-pack-preview-sheet-other.png`, `after-embedded-team-discovery-card-offer.png`.
- Accessibility: the language and appearance choices are KitChoiceList radio rows (selected semantics, 48 dp); the preview is one labelled picture ("Preview of Catppuccin"); the Light/Dark control is named "Preview in"; the Undo bar follows KitUndo's accessible-navigation rules; 320 dp at 2.5x text is exercised by `appearance_picker_test.dart` and `language_picker_test.dart` with no overflow.
- Privacy and security: n/a: no credentials, links or notifications changed. The discovery offer's stored profile is unchanged on a failed save (it used to keep the unsaved team config in memory).
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n
$F test -j 1 test/revamp/shared_settings_1_test.dart test/revamp/shared_settings_1_golden_test.dart
$F test -j 1 test/appearance_picker_test.dart test/language_picker_test.dart
$F test -j 1 test/kit_ratchet_test.dart
$F analyze lib/ui/widgets test/revamp
```

## 7. NOT proven

- Not run on a device or emulator.
- The full suite, `design_standard_test.dart`, `l10n_coverage_test.dart` and the glossary/ledger tests were not run (owner decision 2026-09-27: own tests only). `_migrated` in `design_standard_test.dart` was not edited (R10: integrator-owned).
- `LanguageSettingsTile` (the only way to the Language sheet) has no caller in `lib/`: Appearance uses its own inline language picker (`personal_settings_screens.dart`, another unit), which does not show the Arabic share yet. `arabicTranslatedPercent` is public so that owner can reuse it.
- The theme preview's brightness in the goldens follows the test platform brightness; on a device it follows the phone.
- `test/goldens/failures/` holds tracked files from the base (`team_agent_controls_*`); not this unit's, left untouched.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/shared-settings-1` |
| Enabled | Yes (the language sheet has no entry point in `lib/`, see NOT proven) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `063f4741` |
| Deployed | No | |
| Released | No | |
