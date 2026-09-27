# revamp-screen-work-2: Revamp work (3 files) (2026-09-27)

## 1. Scope

- Unit: `screen-work-2` (wave 2b, screen-revamp). Finish line: `global_sessions_screen.dart`, `session_import_screen.dart` and `worktrees_screen.dart` have G1, G2, G7, G16, G17 and G21 counts of zero, Archived is a filter of All conversations (P3.12), and each page is handled by its map proposal. Non-goal: the All conversations redesign's new structure (wave 3) and any new gateway call, controller field or persistence.
- Files changed: `lib/ui/screens/global_sessions_screen.dart`, `lib/ui/screens/session_import_screen.dart`, `lib/ui/screens/worktrees_screen.dart`, `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`), owned tests `test/global_sessions_screen_test.dart`, `test/session_import_test.dart`, `test/worktrees_screen_test.dart`, new `test/revamp/screen_work_2_golden_test.dart` with 36 goldens `test/revamp/goldens/work_{global_sessions,session_import,worktrees}_*`, census guards (PROC-13 registry) `tool/capture/census/areas/e_workspace.dart` and `k_session_misc.dart`, ledger parts `docs/design/ui-ledger/parts/e-workspace.json` and `k-session-misc.json`.
- Pages (map ids): global-sessions, global-sessions-continue-here-sheet, session-import, session-import-destination-sheet, worktrees, worktrees-create-dialog, worktrees-remove-dialog, worktrees-reset-dialog.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-8, KIT-11, KIT-15, KIT-20, KIT-24, KIT-25, KIT-27, KIT-28, KIT-32, KIT-33, KIT-34, KIT-38, LOOK-1, LOOK-2, LOOK-5, LOOK-6, LOOK-12, LOOK-21, LAY-7, LAY-8, LAY-12, STATE-1 to STATE-9, STATE-12, STATE-20, STATE-21, DATA-11, DATA-14, MAP-1, TEST-5, TEST-19; kit-api KitScreen, KitSearchField, KitSegmented, KitRow, KitRowParts, KitChoiceList, KitDialog, KitConfirmSheet, KitDetailsFold, KitStateView, KitNotice, KitSince; visual-language §5.
- Contract problems (PROC-20):
  - Task text says the record lives at `docs/qa/revamp-<unit id>/README.md`; STANDARDS EVID-1 says `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/`. The rulebook form was used. Blocks nothing.
  - Task text asks for real Arabic in `app_ar.arb` (R04); the owner decision of 2026-09-27 drops Arabic. The later decision was followed: new keys are in `app_en.arb` only.
  - Attribution trailer: the task text names "Claude Opus 5.5 (1M context)"; the session's attribution instruction names "Claude Opus 5.5". The session's form was used.
  - `test/goldens/failures/team_agent_*.png` (24 files) are committed on the base (TEST-12). They are outside this unit's write set, so they were left for the integrator rather than deleted here.
  - `KitSearchField` reads `AppLocalizations.of(context)` (non-null), so a widget test app without the app's localization delegates crashes on it. The owned tests now pass the delegates; shared tests that pump these screens without them will fail (listed below).
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - global-sessions (redesign → kit-only rebuild; structure deferred to the Work redesign slice, no owner id in work-units.json):
    - actionsMissing "open and switch Work to that project" → done: opening a row calls `selectLocationForExistingSession` before the chat (`global_sessions_screen_test.dart` "cross-project result switches location before opening chat").
    - actionsMissing "restore an archived one" → deferred: needs an unarchive gateway call (none exists), no owner.
    - statesMissing "offline: filters stay live over the error" → done: search and the Active / Archived choice sit in the screen header over the error state (golden `work_global_sessions_error_*`).
    - statesMissing "more than ~5 projects: chips run off screen" → done: the chips became one KitSearchField filter menu (`global_sessions_screen_test.dart` "folders with the same name are told apart by their parent").
    - infoMissing "project names instead of path fragments" → done: sections are named by the project (same test); "which project is current" → done: "<project> · In use" ("the project Work has open is named In use").
    - acceptance "Archived is a filter of All conversations (P3.12)" → done: `KitSegmented` Active / Archived; the Archived filter asks for archived ones too and pages on by itself until they arrive ("Archived is a filter: only archived rows, paged until found", "an empty Archived filter says so and leads back to Active", golden `work_global_sessions_archived_*`). `GlobalSessionsScreen(archived: true)` opens on it; Work's Archived row (`workspace_screen.dart`, another unit's file) should pass `archived: true` — integrator follow-up.
    - redesign items deferred to wave 3: auto-paging for the Active list (the Load more button stays), rows opening in a Work pane.
  - global-sessions-continue-here-sheet (fix): title "Move to <project>?", body naming both projects, a "To move it back…" line, confirm "Move conversation" (the Move sheet's verb) → done (golden `work_global_sessions_move_confirm_*`, "stealing confirms, calls the repository, and opens the chat"). actionsMissing "move back later" → done as the stated way back (Continue here from the other project); a one-tap inverse needs a gateway call, deferred, no owner. statesMissing "move fails" → done: the move runs inside `showKitConfirm(action:)`, the question stays open ("a failed steal reports inline and keeps the list"); "session running while moved" → done: a lost-mark consequence ("moving a working conversation warns before it moves").
  - session-import (fix): "title only in the preview" → done (id, parent id, file, folder under one Details fold); "plural fixed" → done (`importMessages` "12 messages"); "destination as a KitRow" → done; infoMissing "project name" → done (row title is the project's name when known). statesMissing "invalid file" → done ("an unreadable file says so by the file and keeps Import off", golden `work_session_import_error_*`); "import failed" → done: the failure notice sits by the file and the file stays chosen ("review precedes import, conflicts retain file and chosen destination").
  - session-import-destination-sheet (fix): current mark → done (KitChoiceList.single with the current destination selected, golden `work_session_import_destination_sheet_*`); "hide the change action when there is one option" → done once the chooser has loaded ("one place to import into: chosen, then nothing to change").
  - worktrees (fix): one pinned primary → done; KitStateView empty without the card → done (golden `work_worktrees_empty_*`); "Main copy · Current" → done ("Current · Main copy" on the project's own row); per-row state words → done. actionsMissing "start a conversation in a copy" → done (row menu and the ready notice, "New conversation here switches to the worktree and opens it"); "merge a copy back" → deferred: no gateway call, no owner. statesMissing "uncommitted changes per copy" and "which conversation uses a copy" → deferred: needs a status call per row / a session-to-worktree link (STATE-21, no owner). "one noun for this feature across Work, Manage, Move and the task sheet" → deferred: a cross-screen copy decision, no owner. whenMissing server.oc1 (hidden) → New worktree and Reset stay hidden without `worktreeCreate` / `worktreeReset` ("without the create call there is no New worktree at all").
  - worktrees-create-dialog (fix): shorter wrapped helper ending "Spaces become dashes." → done; statesMissing "create fails" → done: the create runs inside `showKitInputDialog(onSubmit:)` and the failure shows under the field ("a failing worktree action reports product copy, not the raw exception"); "setup takes minutes" → done: the preparing row adds "Waiting N min" after 8 s through KitSince; actionsMissing "start a conversation in it right away" → done: the ready notice offers New conversation here ("compact worktree creation grows into global ready state").
  - worktrees-remove-dialog (keep): kit-only; "remove fails" → done: removal inside the question ("a failed delete keeps the question open with Try again"). The verb stays "Delete" in both menu and title.
  - worktrees-reset-dialog (keep): typed name when there are changes → done ("reset explains and confirms every destructive file class", "a clean worktree resets without typing its name"); "reset fails" → done: reset inside the question.
- States per page (STATE-20): global-sessions: loading (KitSkeletonRows + bar, not golden), empty (golden `empty`), archived empty (test), no match (test), error (golden `error`), error with rows (tests "failed next page…", "failed refresh…"), loaded (goldens `loaded`, `loaded_1280x800`), archived (golden `archived`), partial/paging (tests). continue-here: confirming (golden `move_confirm`), failed (test). session-import: empty (golden), review (goldens `review`, `review_1280x800`), error (golden), importing/imported (tests). destination sheet: loaded (golden), one option (test). worktrees: loading (skeleton, not golden), empty (golden), error (golden), loaded (goldens `loaded`, `loaded_1280x800`), preparing (test), create dialog (golden), remove / reset confirming (goldens), failed (test).
- Deferred states (STATE-21): per-copy uncommitted changes and linked conversation (needs per-row status / link data, no owner); restoring an archived conversation (needs an unarchive call, no owner).

## 2. Builds

- Branch `revamp/screen-work-2`, base `2cec35ca`, code head `93e42ef3`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first | n/a: the new behaviour has new tests; no pre-existing bug was fixed | n/a | PASS |
| 2 | `test/global_sessions_screen_test.dart` | passes | 29 passed | PASS |
| 3 | `test/session_import_test.dart` | passes | 24 passed | PASS |
| 4 | `test/worktrees_screen_test.dart` | passes | 8 passed | PASS |
| 5 | `test/revamp/screen_work_2_golden_test.dart --update-goldens` (three runs by page) | 36 goldens written, no exception | 36 written; each opened and looked at | PASS |
| 5b | `test/revamp/screen_work_2_golden_test.dart` (verify) | 36 match | 36 passed | PASS |
| 6 | `test/kit_ratchet_test.dart` | every entry of the three files drops to 0 | 58 entries → 0; the run's 2 failures are in other files (`quota_monitor_section.dart` G17; kit files G21), present on the base | PASS (for this unit) |
| 7 | `test/l10n_coverage_test.dart` | passes, counts only drop | passed; global_sessions 1 → 0, worktrees 23 → 0 | PASS |
| 8 | `flutter analyze` on the changed Dart files | no issues | no issues | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | P3.12 | `test/global_sessions_screen_test.dart` "Archived is a filter: only archived rows, paged until found" | step 2 |
  | DATA-14 | `global_sessions_screen_test.dart` "a failed steal reports inline and keeps the list"; `worktrees_screen_test.dart` "a failed delete keeps the question open with Try again" | steps 2, 4 |
  | KIT-28 | `worktrees_screen_test.dart` "reset explains…" (long-press menu); `global_sessions_screen_test.dart` "steal affordance appears only for sessions elsewhere" | steps 2, 4 |
  | KIT-33 | `session_import_test.dart` "review shows the title and a plural count; ids wait folded" | step 3 |
  | STATE-8 | `session_import_test.dart` "an unreadable file says so by the file and keeps Import off" | step 3 |
  | STATE-12 | `worktrees_screen_test.dart` "without the create call there is no New worktree at all" | step 4 |
  | LAY-12 | golden `work_worktrees_error_*` (Try again is the one primary; New worktree hides while the list failed) | step 5 |
  | KIT-1, G16 | `test/kit_ratchet_test.dart` | step 6 |

- Changed test expectations (TEST-19, case 1):
  - `global_sessions_screen_test.dart`: the folder chips became a filter menu (open `global-session-filters`, pick the item; pick again to clear) and the section shows the label once (KIT-24, the map's "chips run off screen"); the archived chip became the Archived segment and archived is a filter (P3.12); sections are ordered by position, not by path Text (paths moved to the row menu, KIT-33); row menus open on long-press, not a per-row PopupMenuButton (KIT-28); the move question is "Move to active?" with confirm key `global-sessions-move-confirm` (map fix); a failed move keeps the question open instead of a snackbar (KIT-34, DATA-14); the row's semantics are KitRow's (title + supporting), not "Open …" (KIT-27); the count is read after scrolling back up (it now scrolls with the list); the test app passes the localization delegates (KitSearchField needs them).
  - `session_import_test.dart`: Import is the `import-action` KitButton, not a FilledButton; the destination is the `import-destination` row and the chooser's items are keyed `import-destination-<dir>` (map fix); the test app passes the localization delegates.
  - `worktrees_screen_test.dart`: the preparing row says "Preparing files and project tasks…" in words instead of a spinner (STATE-9); menus open on long-press (KIT-28); reset with changes asks for the typed name (map: align friction with Remove).
- Goldens added (each opened and looked at), `test/revamp/goldens/work_<page>_<state>[_1280x800]_<dark|light>.png`: global_sessions loaded, loaded_1280x800, archived, empty, error, move_confirm; session_import empty, review, review_1280x800, error, destination_sheet; worktrees loaded, loaded_1280x800, empty, error, create_dialog, remove_confirm, reset_confirm (36 PNGs, 1.8 MB).
- Approved renders (EVID-12): `docs/design/visual-language-2026-09-26/Confirm.png` for move_confirm, remove_confirm, reset_confirm (differences: the move question is neutral, so accent fill instead of danger; consequences are one info or lost line; typed-name field shown for delete and reset with changes); `Main.png` / `WorkLight.png` row and panel shape for the three lists (differences: no needs-you card or composer, not part of these pages); `Desktop.png` for the 1280x800 goldens (differences: single centred list at KitScreenWidth.list, no side panes; these pages are not two-pane).
- Before and after: `before-global-sessions-loaded.png` (base census `e-workspace/global-sessions--loaded.png`) → `after-global-sessions-loaded.png`, plus `after-global-sessions-archived.png`; `before-global-sessions-continue-here-sheet.png` → `after-global-sessions-continue-here-sheet.png`; `before-worktrees-loaded.png` → `after-worktrees-loaded.png`; `before-session-import-review.png` (base census `k-session-misc/session-import--review.png`) → `after-session-import-review.png`.
- Accessibility: every icon-only control is a kit KitIconButton with a label (search clear and filter from KitSearchField; top-bar refresh); row menus are semantic custom actions (KitRow); state words carry every mark (Working, Archived, Unread result, Current, Preparing, Setup failed); disabled Import says why under the button; targets ≥ 48 dp from the kit; 320 dp at 2x/2.5x text checked by the owned tests ("320dp 2.5x … finder keeps filters…", "steal flow fits a 320dp phone at 2x text", "import review and action fit at 320").
- Privacy and security: no credentials, storage keys or external links changed; folder paths are copied only through `KitMenuItem.copy` (KitCopy); ids and paths are shown only under Details (KitDetailsFold redacts).
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/global_sessions_screen_test.dart test/worktrees_screen_test.dart
$F test -j 1 test/session_import_test.dart
$F test -j 1 test/revamp/screen_work_2_golden_test.dart --name "^global sessions"
$F test -j 1 test/revamp/screen_work_2_golden_test.dart --name "^import"
$F test -j 1 test/revamp/screen_work_2_golden_test.dart --name "^worktrees"
$F test -j 1 test/kit_ratchet_test.dart test/l10n_coverage_test.dart
$F analyze lib/ui/screens/global_sessions_screen.dart lib/ui/screens/session_import_screen.dart lib/ui/screens/worktrees_screen.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared tests outside the unit's write set were not run (owner decision 2026-09-27). Expected to break (integrator, TEST-19 case 1): `test/teaching_empty_states_test.dart` (New worktree is the pinned primary, no longer inside the empty state), `test/motion_states_test.dart` and `tool/capture/motion_states_test.dart` (GlobalSessionsScreen now needs the localization delegates; row/filter keys changed), possibly `test/e7_library_layout_test.dart` and `test/isolated_task_sheet_test.dart` (worktrees layout: no FAB/ListTile, localization delegates), `test/design_standard_test.dart` (`_migrated` needs the three files, R10).
- `flutter analyze` on the whole tree was not run; only the changed files.
- The census shots for these pages were not re-rendered (coordinator, TEST-17); only their guards were updated.
- The base's `test/kit_ratchet_baseline.json`, the `test/l10n_coverage_test.dart` baseline and `_migrated` are not updated (integrator, R05/R10).
- Work's Archived row still opens All conversations on Active until `workspace_screen.dart` passes `archived: true`.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-work-2` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `93e42ef3` |
| Deployed | No | |
| Released | No | |
