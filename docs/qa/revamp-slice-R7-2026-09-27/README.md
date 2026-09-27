# revamp-slice-R7: R7 KitDiffView: compact lines, one file switcher, file-change callback (2026-09-27)

## 1. Scope

- Unit: `slice-R7` (wave 3, kit-change, tier 1). Finish line: a diff with selection on reads at the text's line height, the phone header is one file switcher that says the count once, the wide file list marks the open file by highlight and viewed files by a tick, hosts hear file changes through `onFileChanged`, and a whole-hunk selection says so. Non-goal: no screen adoption (review workspace, run results and request previews move in their own units), no staging or reverting inside the part.
- Files changed: `lib/ui/kit/kit_diff_view.dart`; `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`); `test/kit/kit_diff_view_test.dart`; the part's own 12 changed gallery PNGs under `test/goldens/kit/kit_diff_view_*.png`; this record.
- Pages (map ids): none owned (kit part). Its hosts are review-workspace and diff-view, adopted elsewhere.
- Specs followed: `docs/ux-system/kit-api/KitDiffView.md` (frozen API, additive only, R11); STANDARDS KIT-3, A11Y-2, STATE-9, LAY-8, COPY-30, MOT-5, TEST-5; the owner rules of 2026-09-27 (nothing shown twice, kit parts only, English copy only).
- Contract problems (PROC-20):
  - The computed task names the record folder `docs/qa/revamp-<unit id>/`; STANDARDS EVID-1 names `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/`. This record follows EVID-1, as every other revamp record does.
  - KitDiffView.md "Accessibility" says line numbers are 48 dp-tall targets when selection is on (the row at least 48 dp only in selection mode). The unit's acceptance overrides that: rows stay at the text's line height and the 48 dp reach comes from the gutter's hit area. The frozen spec's line should be amended to match (proposed text: "With selection on, rows keep the mono line height; the gutter's hit area over the list gives each line number a 48 dp reach above and below its row, except over a gap bar or a hunk range, which are targets of their own.").
- New kit parts (KIT-3): none. The part now uses `KitRow` (file list) and `KitTappable` (switcher, hunk range), both already in the kit.
- Map items (EVID-11): n/a, the unit owns no page.
- States per page (STATE-20): the part's states are unchanged (loading, empty, error, loaded, binary, renamed, too-big, selecting); each is still covered by `test/kit/kit_diff_view_test.dart` groups 9 and 10 and by the gallery.
- Deferred states (STATE-21): none.

### What changed, item by item (owner rethink rule)

| Item | Before | After | Why |
|---|---|---|---|
| Diff line with selection on | a 48 dp-tall row; a 10-line hunk filled the phone | the text's line height (about 19-20 dp at 1.0 text) | the reach moves to the gutter, not the row |
| 48 dp target | the row itself | a gutter hit area over the list: a touch in a number column within 14 dp above or below a compact row goes to that row's line; gap bars and hunk ranges keep their own taps | A11Y-2 without the tall rows |
| Phone header | "2 files / +4 −3" on one side, the name as a picker value on the other | one switcher row "greeting.dart · 1 of 2 ›", counts at the end, the folder and status under it | the file count showed as "N files" and again in the sheet; now once |
| Header with the file list (large box) | name, folder, counts | unchanged, and no position | the list's highlight already says which file |
| Wide file list | radio marks and a "Current" word | the open file highlighted (`KitRow.selected`), a tick on each viewed file | nothing shown twice; the radio implied a setting, not a place |
| Host tracking | read from `fileActions` calls | `onFileChanged(int)` on every file change (switcher, list, navigator crossing files) | acceptance item 4 |
| Hunk selection | not reported | `KitDiffSelection.hunk` true when the range is exactly one hunk on that side; tapping a hunk's "Lines 10–13" selects the whole hunk | so a host stages a hunk as a hunk |

Moved or removed: the "N files" title of the phone header (removed; the count lives in "1 of N"), the radio and "Current" word of the wide file list (removed; highlight and tick instead). Nothing was moved to another page.

## 2. Builds

- Branch `revamp/slice-R7`, base `643a5104` (revamp/leftovers), code head `af3ab9dd`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 3 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_diff_view_test.dart` | passes | 46 passed | PASS |
| 2 | `test/goldens/kit/kit_diff_view_golden_test.dart --update-goldens` (dark, then light) | 28 shots render; changed ones looked at | 14 + 14 passed; 12 PNGs changed (unified, selecting, binary_renamed × 2 sizes × 2 themes) | PASS |
| 3 | `flutter analyze lib/ui/kit/kit_diff_view.dart test/kit/kit_diff_view_test.dart` | no issues | no issues | PASS |

Not run (owner decision 2026-09-27: run only the unit's own files): `test/diff_view_test.dart`, `test/review_workspace_test.dart`, `test/kit/kit_request_sheet_test.dart`, `test/kit_ratchet_test.dart`, `test/revamp/screen_review_1_golden_test.dart` and the goldens of other parts that embed a KitDiffView (`kit_request_sheet`, `kit_tool_row`).

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | A11Y-2 (compact rows, 48 dp reach) | `test/kit/kit_diff_view_test.dart` "compact lines: a 10-line hunk stays short" | run 1 |
  | nothing shown twice (switcher) | `test/kit/kit_diff_view_test.dart` "412: one switcher row" | run 1 |
  | file list highlight + viewed tick | `test/kit/kit_diff_view_test.dart` "a 1600 dp box shows the file list" | run 1 |
  | onFileChanged | the two tests above and "5. the navigator moves across files" | run 1 |
  | hunk flag | `test/kit/kit_diff_view_test.dart` "a hunk selects as a hunk", and "drag line numbers 12-14" (hunk false) | run 1 |

- Changed test expectations (TEST-19):
  - "drag line numbers 12-14": number cell height `>= 48` → `< 30` (acceptance item 1 replaces the 48 dp row).
  - "412: the picker sheet …": `find.text('3 files')` one → none; the switcher text "one.dart · 1 of 3" instead (acceptance item 2).
  - Taps on line-number keys pass `warnIfMissed: false`: the tap lands on the gutter's hit area above the number, which is the intended target.
- Goldens changed (each opened and looked at):
  - `kit_diff_view_unified_{dark,light}.png`, `…_1280x800_{dark,light}.png`: phone header is now the switcher row with counts at the end; at 1280 the file list has a highlight and a tick instead of radios and "Current".
  - `kit_diff_view_selecting_*`: rows at the line height instead of 48 dp; the whole fixture now fits above the selection bar.
  - `kit_diff_view_binary_renamed_*`: the switcher row "logo.png · 2 of 2 ›".
  - No approved VL canvas render exists for this part (EVID-12: none).
- Before and after (EVID-10): `before-kit_diff_view-unified_dark.png` / `after-kit_diff_view-unified_dark.png`, `before-kit_diff_view-selecting_dark.png` / `after-kit_diff_view-selecting_dark.png`, `before-kit_diff_view-selecting_1280x800_dark.png` / `after-kit_diff_view-selecting_1280x800_dark.png` (before from base `643a5104`).
- Accessibility: the switcher is a `KitTappable` button (48 dp minimum) read as "lib/ui/greeting.dart, 4 added, 3 removed, file 1 of 2"; the viewed tick is named "Viewed"; the open file row carries `selected`; each line row keeps its own semantics node with its select action ("Line 12 added: …"), so screen-reader selection is unchanged. The line rows' semantic rects are now the compact row height, so Android's tap-target guideline would flag them if checked; touch reach is supplied by the gutter hit area, which the guideline does not see. The overflow matrix (320-1280 dp × text 1.0/1.3/2.0) passes.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed. Selection text is still redacted for handlers; copy stays verbatim (SEC-13).
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test --no-pub -j 1 test/kit/kit_diff_view_test.dart
$F test --no-pub -j 1 test/goldens/kit/kit_diff_view_golden_test.dart
$F analyze lib/ui/kit/kit_diff_view.dart test/kit/kit_diff_view_test.dart
```

## 7. NOT proven

- Not run on a device or emulator; the gutter reach is proven by widget tests only.
- Shared suites that embed KitDiffView were not run (see Runs); `test/diff_view_test.dart` and `test/review_workspace_test.dart` may assert the old "N files" title or 48 dp rows; `kit_request_sheet` / `kit_tool_row` / `screen_review_1` goldens may shift where they show a multi-file diff.
- The KitDiffView.md accessibility line needs the amendment named under Contract problems.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/slice-R7` |
| Enabled | Yes (the kit part; hosts adopt it in their units) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `af3ab9dd` |
| Deployed | No | |
| Released | No | |
