# revamp-shared-review-1: Revamp review (1 files) (2026-09-27)

## 1. Scope

- Unit: `shared-review-1` (wave 2a, screen-revamp). Finish line: `lib/ui/widgets/run_result_view.dart` has zero G1, G16, G7, G17 and G21 counts, is built from kit parts only, and its sheet `run-result-output-sheet` is handled by its map proposal (`fix`). Non-goal: no gateway call, controller field or persistence is added; the Run results screen frame (`run_result_screen.dart`, unit screen-review-2) is not touched.
- Files changed: `lib/ui/widgets/run_result_view.dart`, `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`), `test/run_result_screen_test.dart`, new `test/revamp/shared_review_1_golden_test.dart` and its 10 goldens under `test/revamp/goldens/review_run_result_*`.
- Pages (map ids): `run-result-output-sheet`. The view also draws the body of `run-result` (owned by screen-review-2); that page got a kit-only rebuild plus the small reorderings listed under "Moved or changed".
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-11, KIT-26, KIT-27, KIT-32, LOOK-1, LOOK-2, LOOK-5, LOOK-6, LOOK-12, LOOK-16, LOOK-25, LAY-7, STATE-9, MAP-1, TEST-5, TEST-19, TEST-20; kit-v2 §9.1; visual-language §5 (rows on a surface1 panel, sheets with grabber, icon tile and start-aligned title).
- Contract problems (PROC-20): the task text says copy goes to `app_en.arb` AND `app_ar.arb`; the later owner decision 2026-09-27 drops Arabic, so the new key is in `app_en.arb` only (the later decision wins, R15).
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - run-result-output-sheet: proposal `fix` rationale "Size to content; title 'What it did'" → done: `showKitSheet(height: content)`, title "What it did"; test `test/run_result_screen_test.dart` "opens the recorded tool output without re-fetching" (asserts the title and that the sheet is shorter than the old 60 % sheet) and goldens `review_run_result_output_sheet_one_record_*`.
  - run-result-output-sheet: actionsMissing none; statesMissing none; couldBeAutomatic "no".
  - run-result-output-sheet: element `run-result-output-sheet` (DraggableScrollableSheet, kit none) → done: KitSheet.
  - run-result (not this unit's page, recorded for the owner): "review the changed files (review-workspace)" → deferred to screen-review-2 (needs a route callback from `run_result_screen.dart`); "pinned 'Open conversation'" → deferred to screen-review-2 (the screen's KitScreen bottom primary); "one-line verdict" and "name the run by time" → deferred to screen-review-2; statesMissing "run still in progress" → the view already renders `RunOutcomeKind.running` as "Still running"; the live refresh belongs to screen-review-2.
- States per page (STATE-20): run-result-output-sheet: one-record → golden `review_run_result_output_sheet_one_record_{dark,light}` and `_1280x800_*`. View body: loaded → `review_run_result_loaded_*`; partial history + failed + no tool evidence → `review_run_result_partial_failed_*`.
- Deferred states (STATE-21): none for this unit's page.

### Moved or changed (owner rethink rule)

- Sheet title "Recorded tool output" → "What it did" (map); the sheet opens with the one record already expanded (the old sheet made you tap the card again to see anything).
- Sheet height: fixed 60 % draggable sheet → sized to the record (map "size to content"); on wide windows it is the kit's centred panel.
- File rows: the file name leads, the folder follows as a mono technical value (run-result rationale "file names not paths").
- Command rows: the exit code leads as the title, the command follows in mono (KIT-32), the other notes ("Looks like a test command…") move to the supporting line.
- Outcome: one row; when the step failed, the error leads the supporting line and the provider finish reason follows it (before: finish reason first, error underneath).
- Facts: four stacked meta lines became two ("steps · agent · model", "Started … · Finished …").
- "Open conversation": half-width tonal button → KitActionBlock secondary (full width on phone, end-aligned on wide).
- Removed nothing; no action changed what it acts on.

## 2. Builds

- Branch `revamp/shared-review-1`, base `b24addac`, code head `21e501a3`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2a checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first | n/a: no bug fix, a rebuild | n/a | PASS |
| 2 | `test/run_result_screen_test.dart` | passes | 15 passed | PASS |
| 3 | `test/revamp/shared_review_1_golden_test.dart` | passes after deliberate regeneration | 10 passed | PASS |
| 4 | `test/kit_ratchet_test.dart` (once, for this unit's counts) | run_result_view.dart counts drop to 0 | every G1/G16/G7 row for the file shows `-> 0`; G17 and G21 fail only on other files already on the base (`quota_monitor_section.dart`, `kit_choice_list.dart`, `kit_task_card.dart`, `kit_markdown.dart`, `kit_board_lane.dart`, `kit_dialog.dart`, `kit_log_panel.dart`, `kit_checklist.dart`…) | PASS for this unit |
| 5 | `flutter analyze` on the three changed Dart files | no issues | no issues | PASS |

Not run (owner decision 2026-09-27: only the unit's own files): design-standard, l10n coverage, glossary and ledger tests, the whole-tree analyze.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-1, KIT-2 | `test/kit_ratchet_test.dart` (G1, G16) | step 4 |
  | MAP-1 (size to content, title) | `test/run_result_screen_test.dart` "opens the recorded tool output without re-fetching" | step 2 |
  | LOOK-25 | `review_run_result_output_sheet_one_record_dark.png` | golden |

- Changed test expectations (TEST-19, all kind (1), how it looks):
  - "shows server facts…": `'2 assistant steps'` + `'build · gpt-5'` → `'2 assistant steps · build · gpt-5'`; `'lib/domain/run_result.dart'` → `'run_result.dart'` + `'lib/domain'`; `'lib/old.dart'` findsNothing → `'old.dart'` findsNothing; `'Exit code 0 · Looks like a test command…'` → `'Exit code 0'` + `'Looks like a test command…'` (KIT-32, map rationale).
  - "opens the recorded tool output…": `'Recorded tool output'` → `'What it did'`; the tap that expanded the card is gone (it now starts open) and a height check was added (map "size to content").
  - "no tool calls…": `'At least 1 assistant step loaded'` → `'At least 1 assistant step loaded · build · gpt-5'`.
  - "loads history, binds observation…": added `ensureVisible` before tapping "Open conversation" (the action is the list's last item; `scrollUntilVisible` stopped with its centre off screen). Behaviour asserted is unchanged.
- Goldens added (each opened and looked at), `test/revamp/goldens/`:
  - `review_run_result_loaded_{dark,light}.png`, `review_run_result_loaded_1280x800_{dark,light}.png`: body on surface1 row panels; approved render `docs/design/visual-language-2026-09-26/Settings.png` (row panel look): differences — rows here carry a mono third line; no section-less list since these are sections of one record, not state sections.
  - `review_run_result_output_sheet_one_record_{dark,light}.png`, `..._1280x800_{dark,light}.png`: "What it did" sheet, sized to the record, card open; approved render `docs/design/visual-language-2026-09-26/Confirm.png` (sheet frame): none beyond content.
  - `review_run_result_partial_failed_{dark,light}.png`: partial-history notice, failed outcome with the error leading, no-evidence notice.
- Before and after (EVID-10): `before-run-result-output-sheet-one-record.png` (base census `docs/qa/screen-census/k-session-misc/run-result-output-sheet.png`), `after-run-result-output-sheet-one-record.png`; `before-run-result-loaded.png` (base census `run-result.png`), `after-run-result-loaded.png`.
- Accessibility: every row is a KitRow (48 dp minimum, focus ring, Enter/Space); icon glyphs are decorative and the row's words carry the state (STATE-9); the sheet's close is the kit's labelled KitIconButton and its title names the route. 200 % text not rendered in goldens (not proven).
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

### For the integrator

- `test/kit_ratchet_baseline.json`: all `lib/ui/widgets/run_result_view.dart` rows (G1, G16, G7, G17, G21) can drop to 0.
- `test/design_standard_test.dart` `_migrated`: add `lib/ui/widgets/run_result_view.dart` (not staged, R10).
- `docs/qa/screen-census/k-session-misc/run-result*.png` and the census guard: title "Recorded tool output" became "What it did" (census re-render is coordinator work, TEST-17).
- Shared tests broken: none known (only this unit's tests were run).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/run_result_screen_test.dart test/revamp/shared_review_1_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart
$F analyze lib/ui/widgets/run_result_view.dart test/run_result_screen_test.dart test/revamp/shared_review_1_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Whole-tree analyze and the design-standard, l10n, glossary and ledger tests were not run (owner speed decision).
- 200 % text and the other LAY-4 overflow sizes were not rendered.
- Golden times are rendered in the machine's local time zone (fixed date, but the clock text depends on TZ).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/shared-review-1` |
| Enabled | Yes | Run results screen |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `21e501a3` |
| Deployed | No | |
| Released | No | |
