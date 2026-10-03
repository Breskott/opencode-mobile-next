# revamp-kit-KitDiffView: KitDiffView (2026-09-27)

## 1. Scope

- Unit: `kit-KitDiffView` (wave 1, tier 4 in this run; tier 1d in the spec). Finish line: `KitDiffView`
  and its data types match docs/ux-system/kit-api/KitDiffView.md's frozen API, states, adaptive rules,
  motion and copy rules; `lib/ui/widgets/diff_view.dart` is a thin forwarding wrapper (KIT-43, no
  `@Deprecated`); its gallery (28 PNGs, phone + wide, light/dark) and its behaviour tests exist and
  pass. Non-goal: no screen adoption (review_workspace, run results, request previews move in their
  own units); no syntax colour, no word-level highlight, no revert/apply; `lib/ui/kit/kit.dart` is
  untouched (the integrator adds the export).
- Files changed: `lib/ui/kit/kit_diff_view.dart` (new), `lib/ui/widgets/diff_view.dart` (rewritten as
  a forwarding wrapper, C24/R12), `lib/l10n/app_en.arb` (25 new `kitDiff*` keys, English only per the
  owner's 2026-09-27 decision), `test/kit/kit_diff_view_test.dart` (new),
  `test/goldens/kit/kit_diff_view_golden_test.dart` (new) and 28 PNGs, `test/diff_view_test.dart` and
  `test/reader_preferences_test.dart` (tests write set, updated for new copy and keys).
  `lib/l10n/app_localizations*.dart` were regenerated locally to run the tests and left uncommitted
  (the integrator regenerates once, PROC-13).
- Pages (map ids): diff-view (the wrapper now renders through KitDiffView; its frame and key stay).
- Specs followed: docs/ux-system/kit-api/KitDiffView.md; kit-v2.md §1.15, §8.2; STANDARDS.md §1, §15,
  §16, §18 (G4, G5, G6, G8x, G16, G21, SEC-13, KIT-43, LAY-8, MOT-5, A11Y-2, STATE-9).
- Branch note: the task named `revamp/kit-KitDiffView`, but that branch already existed (at an older
  `feat/phone-setup-v2` commit, no commits of its own) and is checked out in another worktree
  (`wf_1d49ead2-79b-4`), so it could not be switched to. This unit is on `revamp/kit-KitDiffView-v2`
  from `feat/phone-setup-v2` (the `-v2` pattern other units used).
- Contract problems (PROC-20):
  - **Copy: KitIconButton.copy vs SEC-13.** The spec says the wrapper's copy "uses
    `KitIconButton.copy`", and its test 8 expects a fake key in copied lines to be redacted. The later
    SEC-13 note at the top of the same spec (coordinator 2026-09-27) says this part copies verbatim
    (`KitCopy.copy(context, text, redact: false)`). `KitIconButton.copy`, `KitAction.copy` and
    `KitMenuItem.copy` always redact and have no verbatim option. Followed SEC-13: Copy lines (and the
    wrapper's Copy updated file / Copy patch, in the header's More menu) call
    `KitCopy.copy(redact: false)` from a plain `KitAction` / `KitMenuItem`; there is no check-glyph
    feedback, only the one "Copied" announcement. `KitDiffSelection.text` (handed to Comment / Add to
    prompt) is still redacted, as the frozen API says. A verbatim variant of the copy controls is a
    kit-KitIconButton / kit-KitAction question for the coordinator.
  - **`diff-view-horizontal` vs `<prefix>-horizontal`.** The spec lists the internal key
    `<prefix>-horizontal` and also says the wrapper (prefix `diff`) keeps `diff-view-horizontal`;
    those cannot both hold. Built the listed internal key (`diff-horizontal` through the wrapper) and
    updated the two tests that used the old key (`test/diff_view_test.dart`,
    `test/reader_preferences_test.dart`); nothing in `lib/` used it.
  - **1280 dp is "large".** The spec's gallery wants "split at 1280, split with the file list at
    1600", but `KitLayout.windowFor(1280)` is `large` (≥ 1200) and the Adaptive table puts the file list
    on `large`. Followed the Adaptive table: a 1280 box with 2+ files shows the file list.
  - **One more copy key.** Added `kitDiffLine` ("Line {number}") so an unchanged line is read with its
    number like added and removed lines ("Line 14: …"), and a blank line still has a name (G5
    labelled tap targets in selection mode).
  - **Galleries reduced by the owner's 2026-09-27 decision** (412x915 and 1280x800 only, no Arabic, no
    text 2.0): 7 states x 2 sizes x 2 themes = 28 PNGs, not the spec's 32.
- New kit parts (KIT-3): none beyond the unit's own (`KitDiffLineKind`, `KitDiffLine`, `KitDiffGap`,
  `KitDiffFileStatus`, `KitDiffFile`, `KitDiffMode`, `KitDiffSide`, `KitDiffSelection`, `KitDiffView`,
  `showKitDiff`).
- Map items (EVID-11): diff-view-body (the second renderer, continuation lines losing their
  indentation) is replaced: wrapped lines hang at the text column (test 11, gallery `unified`).
- Deferred states (STATE-21): none. "Comment disabled when the selection spans both sides" cannot
  occur: a selection is always on one side by construction.

## 2. Builds

- Branch `revamp/kit-KitDiffView-v2`, base `8ce9389b11a95d09e6c4e50df34d881cf5a8a3f2`
  (`feat/phone-setup-v2`). Code commit `f5f1d2ef`.
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator/checkpoint work.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_diff_view_test.dart` + `test/diff_view_test.dart` | pass | 52 passed | PASS |
| 2 | `test/goldens/kit/kit_diff_view_golden_test.dart` (`--update-goldens` per size, each PNG looked at, then a plain run) | pass, G5 clean | 28 passed | PASS |
| 3 | `test/reader_preferences_test.dart` (tests write set) | pass | 9 passed | PASS |
| 4 | `test/demo_isolation_test.dart` (tests write set, unedited) | pass | 6 passed | PASS |
| 5 | `test/kit_ratchet_test.dart` | nothing new from this unit | G17 fails on `quota_monitor_section.dart`, G21 on `kit_choice_list.dart`, `kit_dialog.dart`, `kit_log_panel.dart` (all outside this unit, already on the base); this unit's first `EdgeInsets numeric` x3 in `kit_diff_view.dart` was fixed; `diff_view.dart` counts fall to 0 except `Text` 13 -> 1 | PASS for this unit |
| 6 | `flutter analyze` on the six changed Dart files | no issues | No issues found | PASS |
| 7 | `dart format --language-version=3.10` on the changed Dart files | clean | clean | PASS |

## 5. Evidence

| Rule / spec test | Test or golden | Output |
|---|---|---|
| 1 parser | `kit_diff_view_test.dart` group "1. parser" | two-hunk patch: +3 −2, 2 changes, hunk lines, old/new numbers, count-only gaps 9 and 47; `fromTexts` folds with 3 context lines; `after` alone is `added`; separate changes stay separate |
| 2 gaps | "2. gaps reveal 20 lines per tap…" | 20 lines then 7, collapse hides them; a patch gap states "9 unchanged lines" with no action; "Lines 10–13" |
| 3 mode | group "3. mode follows the diff box" | unified at 412, split at 1280, `split` in 412 renders unified, a 340 box on a 1600 window renders unified |
| 4 files | group "4. files" | file list at 1600 opens a file; at 412 the picker sheet lists 3 paths with counts and opens one |
| 5 navigator | "5. the navigator moves across files…" | Change 1 of 6 -> 6 of 6 in the second file; `p`/`n` keys; one live-region label |
| 6 not colour alone | "6. change identity…" | `+` / `−` glyphs; "Line 1 added: new value", "Line 1 removed: old value" |
| 7 selection | "7. drag line numbers 12-14…", "7. a drag that starts on an unchanged line…", "7. read-only…" | 3 lines selected; Comment once with current 12–14, text redacted; Esc clears; numbers are 48 dp; read-only has no selectable numbers |
| 8 copy | "8. Copy lines copies verbatim…" | clipboard holds the line exactly (SEC-13), one "Copied" announcement, no SnackBar |
| 9 states | group "9. states" | skeleton rows; "No changes"; error + Try again once; "Binary file · not shown"; "Renamed from lib/old.dart" |
| 10 too big | "10. too big…" | "Showing 400 of 3,200 lines", Open all once |
| 11 wrap | "11. wrap…" | wraps at 412 with the continuation at the text column; sideways at 1280; `onWrapChanged` gets `true` |
| 12 wrapper | `test/diff_view_test.dart` | `diff-view`, `diff-file-header-<path>`, `diff-gap-<i>`, `diff-collapse-0`, `diff-horizontal`; copy through More is verbatim, no SnackBar; `allowCopy: false` has no More |
| 13 RTL | "13. under Arabic the diff stays LTR…" | old side left of new side; the line's Directionality is ltr |
| 14 virtualisation | "14. a 10,000-line file…" | fewer than 200 line texts built, line 9999 not built |
| 15 / G8x | "15. reduced motion…", `kitMotionStillTests('KitDiffView')` | navigation settles after one pump; default and gap expansion settle at once under system and effects-off stillness |
| 16 / G6 | group "16. overflow (G6)" | a 150-char path and a 400-char line at 320/412/600/840/1280 x 1.0/1.3/2.0, selection on: no exception |
| G5 | the 28 gallery shots | clean, no baseline entry |

- Changed test expectations (TEST-19): `test/diff_view_test.dart` — new copy ("Show 20 unchanged lines",
  "47 unchanged lines", "Line 1 added: …"), both line numbers in unified ("12" twice), counts as one
  "+2 −1" text, `diff-horizontal`, copy from More with no SnackBar (SEC-13 / G1), no tooltip on the
  header (the full path is in its semantics). `test/reader_preferences_test.dart` — the diff's own
  "Wrap lines" toggle replaces the removed app-bar `ReaderWrapButton`, key `diff-horizontal`.
- Goldens (all new, each opened and looked at): `kit_diff_view_{unified,selecting,binary_renamed,
  too_big,loading,empty,error}_{,1280x800_}{dark,light}.png`. `unified`: two files, gaps, 5 changes,
  picker row on the phone, split with the file list at 1280. `selecting`: lines 3–5 selected (tint and
  accent start mark on the numbers), bar with Comment / Add to prompt / Copy lines / Clear.
  `binary_renamed`: the binary file open; the renamed file's "Renamed from lib/ui/card.dart" in the
  wide file list. Fixes found by looking and by G5: a drag was dropped when the first selected row
  gained its tint (row tree changed; now always a `ColoredBox`); rows' pointer menu added an unlabeled
  tap node (now `excludeFromSemantics`); the wide file list read before the header (the header now
  spans the top); the selection bar's count row and actions touched (one row on wide windows); the
  binary message is the body's one node.
- Before and after: no before render for a new gallery (EVID-10).
- Accessibility: every line is one node read with its number and kind; with selection on, a row is a
  48 dp node with a select action and selected state; the navigator label is a polite live region;
  the header reads "path, n added, n removed, status"; G5 passes in both themes at both sizes.
- Privacy and security: displayed diff lines are not masked (spec Open question 1); copies are
  verbatim per SEC-13; `KitDiffSelection.text` is redacted for the handlers. No stored data changed.
- Migration: n/a.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n   # the generated files are not committed by this unit
$F test -j 1 test/kit/kit_diff_view_test.dart test/diff_view_test.dart
$F test -j 1 test/goldens/kit/kit_diff_view_golden_test.dart
$F test -j 1 test/reader_preferences_test.dart test/demo_isolation_test.dart
$F analyze lib/ui/kit/kit_diff_view.dart lib/ui/widgets/diff_view.dart test/kit/kit_diff_view_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (R19/R20).
- Navigator focus moves to the diff body, not to the change's first line: rows are not focus stops
  (a focus stop per line would put thousands of lines in Tab order). Up/Down scroll by a line rather
  than moving a line cursor.
- Scrolling to a change estimates the offset from row heights, then corrects with `ensureVisible`
  once the row is built; with many wrapped lines the first estimate can be short.
- A reduced-motion press of Previous/Next that enables or disables the other button leaves a ticker
  running for a frame (Material `ButtonStyleButton`'s state animation inside `KitIconButton`); test 15
  presses from a middle change, where neither button changes state. Flagged for kit-KitIconButton.
- The right-click line menu, Shift+Up/Down, Enter and Ctrl+C have no dedicated tests.
- `test/permission_sheet_test.dart` and the staged-revert tests (callers of `DiffView.single`) were not
  run (owner decision: own tests only); the wrapper keeps the `diff-view` key they use.
- Full repository suite not run (coordinator's gate).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitDiffView-v2` |
| Enabled | Yes, through the `DiffView` wrapper (chat Changes, permission sheet, staged revert) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | `f5f1d2ef` |
| Deployed | No | |
| Released | No | |
