# revamp-screen-files-1: Revamp files (2 files) (2026-09-27)

## 1. Scope

- Unit: `screen-files-1` (wave 2b, screen-revamp). Finish line: `files_screen.dart` and `project_hub_screen.dart` have a G16 count of zero, with goldens, and each page is handled by its map proposal. Non-goal: no gateway call, controller field or persistence is added (live hub lines, "since you left" and "start a conversation here" wait for wave 3).
- Files changed: `lib/ui/screens/files_screen.dart`, `lib/ui/screens/project_hub_screen.dart`, `lib/l10n/app_en.arb` (and the generated `app_localizations*.dart`), `test/files_row_actions_button_test.dart`, `test/files_screen_recovery_test.dart`, new `test/revamp/screen_files_1_test.dart`, `test/revamp/screen_files_1_golden_test.dart` and its 16 goldens in `test/revamp/goldens/`.
- Pages (map ids): files, files-changes-sheet, files-file-viewer-sheet, files-row-actions-sheet, project-hub.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-23, KIT-28, KIT-34, KIT-35, KIT-36, MAP-1, STATE-5, STATE-12; kit-api KitViewer, KitScreen, KitSearchField, KitBreadcrumb, KitRow, KitRowParts, KitMenu, KitUndo, KitNotice, KitStatusLine, KitStateView, KitSheet, KitTopBar; visual language §4, §5.
- Contract problems (PROC-20):
  - The task text says new copy goes to `app_en.arb` AND `app_ar.arb`; the owner decision of 2026-09-27 (later, so it wins, R15) drops Arabic. New keys are in `app_en.arb` only.
  - KIT-35 (one status line per window): the Files list is not a KitScreen with its own bar, so the change-marks condition goes through `KitScreen(status:)`, which contributes to the shell's slot when one exists and draws its own line only when none does (tests, the chat-hosted Files page).
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - files: "current folder as the title" → done (`KitTopBar` title from `FilesScreen.topBar`; `screen_files_1_test` "Files opens in the tab under one bar titled by the folder"). "per-file change mark" → done (status word on the row's second line; `files_loaded` golden). "reason in words" → unchanged (the listing error already says it). "visible Refresh in the empty state" → done (`files_screen_recovery_test` "empty folder refresh…"). "Show hidden files" → done (search filter; `files_row_actions_button_test` "dot entries stay hidden…"). "ask the agent about a file when not opened from chat" → deferred (needs a route into a new conversation; wave 3 files slice). Owner rationale "change-marks failure as a KitStatusLine without Retry" → done; "a row menu instead of the per-row … sheet" → done.
  - files-row-actions-sheet (merge-into:files): the sheet and the per-row button are gone; the row's `KitRowMenu` holds Attach, Add as reference, Open in Review, Copy path and Copy name (actionsMissing "Copy name" → done); no "Open" (the row's tap). Tests: `files_row_actions_button_test`.
  - files-file-viewer-sheet (merge-into:file-preview-sheet): deleted; Files opens `showKitViewer` (compact/medium sheet, page from expanded) or `KitViewer` in the two-pane detail. "Wrap lines always" → the viewer wraps on compact by default and honours the reader preference; "Open in Review when changed" → done (viewer menu). Goldens `files_viewer_sheet`, `files_viewer_pane_1280x800`.
  - files-changes-sheet (merge-into:review-workspace): least change, kit-only (`showKitSheet` + `KitRowGroup` rows, Review all as the primary), marked `// revamp: merge-into:review-workspace (slice-P3.7a)`. "discard one file's changes" → deferred to slice-P3.7a.
  - project-hub (fix): chooser when no project is open → done ("Choose a project" opens ProjectsScreen; `screen_files_1_test`). "copy the folder path" → done (menu beside the name). "Changes first", "drop Search files", "path out of the header" → done. "live supporting lines (N changed, N running, health)", "start a conversation here" → deferred (need new gateway reads; wave 3).
- States per page (STATE-20):
  - files: loading (waiting state, slow after 8 s with Try again), empty folder (Refresh), only hidden entries (Show hidden files), no match, load failed (Try again, Report a bug), change marks unavailable (status condition), loaded, two panes with the viewer, symbols hint / no symbols / symbols failed → tests above and goldens `files_loaded`, `files_viewer_pane_1280x800`.
  - viewer: loading, error with Try again, loaded, binary, pdf pages → KitViewer's own states; `files_screen_recovery_test` "failed file read…", "late file read…".
  - project-hub: loaded, no project → goldens `project_hub_loaded`, `project_hub_no_project`.
- Deferred states (STATE-21): hub "server not answering" and "counts loading" → need live per-row reads, owner wave-3 project slice.

## 2. Builds

- Branch `revamp/screen-files-1`, base `2cec35ca` (feat/phone-setup-v2), code head `6f21d378`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/files_row_actions_button_test.dart` | passes | 5 passed | PASS |
| 2 | `test/files_screen_recovery_test.dart` | passes | 6 passed | PASS |
| 3 | `test/revamp/screen_files_1_test.dart` + `screen_files_1_golden_test.dart` | pass | 19 passed | PASS |
| 4 | `test/kit_ratchet_test.dart` with `KIT_RATCHET_WRITE=1` (baseline restored afterwards, not staged) | both files absent from every gate's baseline | no entry for either file in G1, G2, G7, G15, G16, G17, G21 | PASS |
| 5 | `flutter analyze --no-pub lib` and the four test files | no issues | no issues | PASS |

Not run (owner decision 2026-09-27: only the unit's own test files): design-standard, l10n coverage, glossary and ledger tests, and the shared tests below.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test or golden | Output |
  |---|---|---|
  | KIT-28 | `test/files_row_actions_button_test.dart` "rows carry no per-row button…" | run 1 |
  | KIT-34 | `test/files_row_actions_button_test.dart` "Add to prompt stages a reference with Undo…" | run 1 |
  | STATE-12 | `test/revamp/screen_files_1_test.dart` "with no project open the hub offers the chooser" | run 3 |

- Changed test expectations (TEST-19):
  - `files_row_actions_button_test`: per-row "Actions for …" button and `file-row-actions-sheet` → the row's KitRowMenu (KIT-28); the in-place notice replaces the snackbar.
  - `files_screen_recovery_test`: a file read that crosses a server switch now shows KitViewer's "Couldn't open README.md" with Try again (which reads from the current server) instead of "Server changed. Close and reopen this file." with no retry; a failed read's reason is in the viewer's Details instead of the body; tests need the app's localization delegates (kit parts read `AppLocalizations.of`).
- Goldens (each opened and looked at), `test/revamp/goldens/`: `files_loaded`, `files_row_menu`, `files_viewer_sheet`, `files_changes_sheet`, `files_viewer_pane_1280x800`, `project_hub_loaded`, `project_hub_loaded_1280x800`, `project_hub_no_project`, each `_dark` and `_light`. Approved renders: `Main.png` (large title, rows on a surface1 panel) and `Desktop.png` (flat sidebar lists, changes list) — the file tree is a flat list of KitRows with hairlines, as the Desktop sidebar lists are, so a long folder stays lazily built.
- Before and after: `before-files-loaded.png` → `after-files-loaded.png`; `before-files-row-actions-sheet.png` → `after-files-row-menu.png`; `before-files-file-viewer-sheet.png` → `after-files-viewer-sheet.png` and `after-files-viewer-pane-1280x800.png`; `before-files-changes-sheet.png` → `after-files-changes-sheet.png`; `before-project-hub-loaded.png` → `after-project-hub-loaded.png`, `after-project-hub-no-project.png`.
- Accessibility: every row action is also a semantic custom action (KitRow.menu); the hub menu and the viewer's More are labelled `KitIconButton`s; the changes sheet's add button is labelled with the path; paths are isolated left to right (`KitBidi.ltr`).
- Privacy and security: no links, credentials or stored data changed. Copying uses `KitCopy` (default redaction for paths and names; review comments verbatim).
- Migration: n/a, no stored format changed. Reader preferences (`sourceFirst`, `wrapCode`) are read and written as before.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/files_row_actions_button_test.dart test/files_screen_recovery_test.dart
$F test -j 1 test/revamp/screen_files_1_test.dart test/revamp/screen_files_1_golden_test.dart
$F analyze lib
```

## 7. NOT proven

- Not run on a device or emulator; PDF pages through `LocalPdf` are not exercised (no platform renderer in tests; a PDF falls back to "Can't show this file").
- Shared tests not run and likely to need the integrator (they expect the old widgets): `test/project_hub_test.dart` (Search row, header text, ListTile header), `test/desktop_context_menu_test.dart` (`file-menu-open`), `test/desktop_pointer_test.dart` (`files-split-handle`: the draggable splitter is gone, KitScreen.twoPane sets the list width), `test/product_ui_regression_test.dart`, `test/desktop_scrollbar_test.dart`, `test/reader_preferences_test.dart`, `test/motion_states_test.dart` (host FilesScreen without the app's localization delegates), `test/home_navigation_test.dart`.
- The viewer sheet's Reload: KitViewer's source is fixed once `showKitViewer` opens, so Reload is only in the two-pane viewer's menu; in the sheet, Try again covers failures and closing and reopening reloads.
- `design_standard_test.dart` `_migrated` entries for these files are the integrator's (R10).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-files-1` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `6f21d378` |
| Deployed | No | |
| Released | No | |
