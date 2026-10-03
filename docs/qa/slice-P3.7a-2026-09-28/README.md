# slice-P3.7a: one diff component (2026-09-28)

Finish line: every diff in the app renders through the kit's `KitDiffView` with its one
"Change 1 of N" navigator (previous/next change, N / P / F7 on a keyboard), `files-changes-sheet`
is gone, and `lib/ui/widgets/diff_view.dart` is retired. Non-goal: no Undo flow changes.

Branch `revamp/slice-P3.7a`, base `53c2bf2a` (feat/phone-setup-v2).

## What changed, per page

- **files-changes-sheet: removed.** The "N changed files" row at the top of Files now opens Review
  (`pushWorkingTreeReview`, `KitDiffView` with its navigator and, when the window is wide, its file list).
  It no longer opens a sheet that listed the same files first. The row shows the totals it used to
  hide ("3 changed files", with "+31 −3" under it). Adding a changed file to the prompt now happens
  from the diff's own file menu ("Add … to the prompt", which already existed in Review). Strings
  `readerUiReviewAll`, `readerUiChangeSummary` and `readerUiAddPath` are deleted (en and ar).
- **diff-view (read-only diff page)**: now `DiffPage` in `lib/ui/screens/review_workspace.dart`.
  It shares Review's `FileDiff` to `KitDiffFile` converter and copy entry, so the app has one
  converter where it had two. Same key (`diff-view`), same `diff-…` inner keys, same title rules.
  Copy now prefers the patch, as Review does, and falls back to the updated file.
  Callers moved: staged revert's file rows (`DiffPage.single`), tests, and the capture/census tools.
  `lib/ui/widgets/diff_view.dart` is now a 10-line export + `typedef DiffView = DiffPage` shim. It
  stays only because `chat_screen.dart` (chat lane, off limits) imports it. The one-line hook is in
  lane notes; the file can be deleted once chat drops that import.
- **Converter fix**: a diff whose server sent no counts now shows the counts parsed from its patch.
  Before, Review showed "+0 −0" for these.
- **run-results**: tapping a changed file opens its recorded diff straight on the kit diff page
  (`showKitDiff`, key `run-result-diff`, titled "Changed files"). Before, it opened a record sheet
  with a 12-line preview. The page is opened at that file, and one navigator walks every change in
  the run, file by file. The diff is read from the edit record (`filediff.patch`, `diff`, or
  `oldString`/`newString`) or from that file's own entry in a patch record. A written file has no
  diff, so it still opens its record sheet.
- **team merge section**: `EdgeInsets.zero` changed to `EdgeInsetsDirectional.zero`. It has no diff
  to show. **Blocker (feasibility):** Gas City `MergeReadiness.changes` carries only the path and
  +/− counts, with no patch (`lib/orchestration/models/merge.dart`). Showing the change needs a
  patch per run in the readiness contract; the next step is recorded in lane notes for Codex and the
  team page owner.
- **Request "See the change"**: this already renders `KitDiffView` directly (`kit_request_sheet`,
  chat `permission_sheet`). No change needed.
- **RTL (kit fix)**: the file switcher's position ("1 of 2") is now bidi-isolated
  (`KitBidi.auto`). Before, it was scrambled into "of 2 1 ·" in a right-to-left window (see
  `before-diff_page_rtl_dark.png`). This was verified by a failing-then-passing test.
- **Directional paddings**: every file touched uses `EdgeInsetsDirectional`. `review_workspace.dart`
  has 0 non-directional insets (the 13 counted in the review were cleared by earlier slices). The
  5 in `kit_diff_view.dart` are the part's deliberately forced-LTR code block (LAY-8, allowlisted).

## Speed (5,000-line diff, widget-test probe)

`test/revamp/slice_p37a_perf_test.dart`: one file with 5,000 patch lines (250 hunks), phone 412x915, debug test harness on this PC.

| | open (pump + settle) | lines built | next change x20 | 30 drags of 600 px |
|---|---|---|---|---|
| before (`DiffView`, base) | 627 ms | 16 | 1701 ms | 783 ms |
| after (`DiffPage`), 3 runs | 617 / 633 / 723 ms | 16 | 1720 / 1817 / 2053 ms | 799 / 845 / 792 ms |

Before and after render through the same virtualized `KitDiffView`, and the numbers match within
run-to-run noise. The probe asserts the machine-independent part: fewer than 300 lines are built
before and after scrolling. It also checks the keyboard N/P moves.

## Tests

New:
- `test/revamp/slice_p37a_test.dart` (4): Run results open an edited file on the diff page, at that
  file, with "Change 3 of 4" across the run; Next, P and Close work. An edit recorded as old/new text
  shows as a diff. A written file keeps its record sheet. The RTL position is isolated (this test
  failed without the kit fix).
- `test/revamp/slice_p37a_perf_test.dart` (1): the 5,000-line probe.
- `test/revamp/slice_p37a_golden_test.dart` (13 goldens): three doors, phone and wide, dark and
  light, plus RTL.

Changed:
- `test/diff_view_test.dart` renamed to `test/diff_page_test.dart`, on `DiffPage`.
- `test/reader_preferences_test.dart`, `test/demo_isolation_test.dart`: now use `DiffPage`.
- `test/product_ui_regression_test.dart`: the changes-row test now expects Review directly, with
  staging from the diff's menu.
- `test/redaction_test.dart`: the `diff_view.dart` entry is removed, and `review_workspace.dart`
  goes from 2 verbatim copies to 1 (shared helper).
- `test/kit/kit_diff_view_test.dart`: the isolated position.
- `test/revamp/screen_files_1_golden_test.dart`: the changes-sheet shot is removed (the page is
  gone). The Files goldens were refreshed for the row's new "+31 −3" line (looked at).
- Census shot `files-changes-sheet` removed from `tool/capture/census/areas/f_files_review_terminal.dart`.

Runs, each once for the affected files: the new tests, `diff_page`, `reader_preferences`,
`product_ui_regression`, `redaction`, `screen_files_1_golden`, `run_result`, `staged_revert_*`,
`team_merge`, `team_sheets_golden`, `review_workspace`, `kit_diff_view` (+ golden), `kit_request_sheet`,
`permission_sheet`, `files_screen_recovery`, `search_index`, `kit_ratchet`, `architecture_boundaries`,
`kit_map_gate` and `design_standard` all pass. `flutter analyze` is clean.

Two failures were already there on base `53c2bf2a`: both also fail in a clean base worktree, and
neither was edited here.
- `demo_isolation_test` "compact demo keeps send and exit reachable…" (`permission-card-review`
  missing, chat lane).
- `run_result_screen_test` "opens the recorded tool output…": the bash record sheet is 444 px, over
  the test's 360 px cap. That sheet is untouched here.

## Images

`before-*` come from base `53c2bf2a` and `after-*` from this slice (same test,
`slice_p37a_golden_test`). Each shot has phone (412x915) and wide (`_1280x800`) versions in dark and light.
- `*files_changes*`: before is the Changes sheet; after is Review opened directly.
- `*run_file*`: before is the record sheet with a 12-line preview; after is the full diff page at that
  file, "2 of 2", "Change 2 of 2".
- `*diff_page*`: the read-only diff page. `*_rtl_dark` shows the position fix.
- `contact-sheet-phone.png`: before | after for five of them.

## Still needs a device

- An emulator pass through the three doors (Files row, Run results file, staged revert file) on
  phone and a PC window with a hardware keyboard (N/P/F7).
- The chat lane's one-line swap, then deleting `lib/ui/widgets/diff_view.dart`.
