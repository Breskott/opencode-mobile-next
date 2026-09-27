# revamp-screen-work-1: Revamp work (1 files) (2026-09-27)

## 1. Scope

- Unit: `screen-work-1` (wave 2b, screen-revamp). Finish line: `lib/ui/screens/workspace_screen.dart` has a G1/G16/G7 and look-pattern count of zero, uses `KitScreen.twoPane` from expanded, archives through one swipe/menu path with `showKitUndo`, and handles each page by its map proposal. Non-goal: the Work redesign's new structure (one New conversation with a kind chooser, one "N need you" row to Inbox, the AI Team as a notice); no gateway call, controller field or persistence added.
- Files changed: `lib/ui/screens/workspace_screen.dart`, `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`), `docs/design/ui-ledger/parts/e-workspace.json`, owned tests `test/workspace_hierarchy_test.dart`, `test/session_needs_you_test.dart`, `test/session_pins_test.dart`, new `test/revamp/screen_work_1_test.dart`, `test/revamp/screen_work_1_golden_test.dart`, 16 goldens under `test/revamp/goldens/work_workspace_*`.
- Pages (map ids): workspace, workspace-archive-session-sheet, workspace-archived-sheet, workspace-context-sheet, workspace-delete-session-sheet, workspace-directory-details-dialog, workspace-folder-chooser, workspace-rename-session-dialog, workspace-session-details-sheet, workspace-share-session-sheet.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-11, KIT-15, KIT-23, KIT-28, KIT-29, KIT-33, KIT-34, LOOK-1, LOOK-2, LOOK-4, LOOK-6, LOOK-12, LOOK-24, LAY-1, LAY-5, LAY-7, LAY-8, DATA-11, DATA-14, STATE-9, MAP-1; kit-api KitScreen (Panes), KitSwipeAction, KitRow, KitUndo; visual-language §5.
- Contract problems (PROC-20):
  - Task text says the record lives at `docs/qa/revamp-<unit id>/README.md`; STANDARDS EVID-1 says `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/`. The rulebook form was used. Blocks nothing.
  - Task text asks for real Arabic in `app_ar.arb` (R04); the owner decision of 2026-09-27 drops Arabic. The later owner decision was followed: new keys are in `app_en.arb` only.
  - Attribution trailer: the task text names "Claude Opus 5.5 (1M context)"; the session's attribution instruction names "Claude Opus 5.5". The session's form was used.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - workspace (proposal redesign → kit-only rebuild; structure deferred to the Work redesign slice, no owner id in work-units.json): actionsMissing "answer a waiting request from the row", "choose the kind of new work in one place", "restore an archived conversation" → deferred (redesign slice; restore needs an unarchive gateway call, none exists). statesMissing "disconnected: Running rows keep a green live dot", "Codex/Paseo: no project context", "Team segment hidden without a word" → deferred (redesign slice).
  - workspace-archive-session-sheet (remove, P3.12) → done: deleted; menu Archive = swipe path; `screen_work_1_test.dart` "the menu archives at once with Undo and no confirmation…". "archive fails" → done: a failed commit says "Couldn't archive …" in a KitNotice above the list (not separately tested). "Undo" → done: "Undo brings the row back and the server is never told".
  - workspace-archived-sheet (fix, but deleted by P3.12 acceptance) → done: deleted; the Archived row opens All conversations. "Restore" → deferred: needs an unarchive gateway call (none) and the Archived filter of All conversations (global_sessions_screen.dart's unit, P3.12). "empty after the last one is deleted", "load error" → n/a with the sheet gone.
  - workspace-context-sheet (fix) → done: title = project, subtitle "On <server>", "Runs on" section with KitRowIcon(current) and the word "In use", folder under KitDetailsFold (copy), New project row; "environment switch fails" → done: locationError becomes the KitNotice above the list. "disconnected environment: can it be picked?" → deferred: needs per-workspace reachability (no data today), no owner.
  - workspace-delete-session-sheet (keep) → done: showKitConfirm(destructive) with the act inside; "delete fails" → done (stays open, `screen_work_1_test.dart` "delete of a shared conversation…"); "shared link stops working" → done (consequence line, same test and golden `delete_confirm`).
  - workspace-directory-details-dialog (merge-into:workspace-context-sheet, P3.11) → least change: a KitSheet with the path in KitDetailsFold (copyable); `// revamp:` marker above it.
  - workspace-folder-chooser (fix) → done: error title "Couldn't load your projects", Try again as primary, body that does not repeat the title, "Enter a folder path" / "Recent projects" (`screen_work_1_test.dart` "a project list that failed…", golden `folder_chooser_error`). "server with one fixed folder" → deferred: not detectable today, no owner. actionsMissing "pick a recent project in one tap", "clone a repository" → deferred (redesign / no gateway call).
  - workspace-rename-session-dialog (keep) → done: showKitInputDialog; "rename fails" → done: failure under the field, dialog stays (`screen_work_1_test.dart` "rename: …").
  - workspace-session-details-sheet (merge-into:session-context, P3.11) → least change: KitSheet with labelled, copyable KitTechnicalValues (folder, shared link) and the usage lines as notes; `// revamp:` marker above it.
  - workspace-share-session-sheet (keep) → done: showKitConfirm with the share inside (failure stays open), consequence "The link is copied once sharing starts.", link copied through KitCopy (`screen_work_1_test.dart` "share says the link is copied, then copies it").
- States per page (STATE-20): workspace: loading (existing `work_tab_golden_test` loading), empty (golden `empty`), error (status line, unchanged), not answering (unchanged `GraceTimer` path), loaded (goldens `loaded`, `loaded_1280x800`); twoPane empty detail (golden `loaded_1280x800`), twoPane selected (`screen_work_1_test.dart` "at 1280x800 …"). folder chooser: loaded (golden `folder_chooser`), error (golden `folder_chooser_error`). context sheet: loaded (golden `context_sheet`). delete: loaded + failed (golden `delete_confirm`, test). archive: acted (golden `archive_undo`).
- Deferred states (STATE-21): listed above with their reason.

## 2. Builds

- Branch `revamp/screen-work-1`, base `8dc27c66`, code head `23b2efb5`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first | n/a: no pre-existing behaviour fixed; new behaviour has new tests | n/a | PASS |
| 2 | `test/revamp/screen_work_1_test.dart` | passes | 11 passed | PASS |
| 3 | `test/revamp/screen_work_1_golden_test.dart` (after `--update-goldens`) | passes | 16 passed | PASS |
| 4 | Owned: `workspace_hierarchy_test`, `session_needs_you_test`, `session_pins_test`, `work_tab_status_line_test`, `team_card_test`, `usage_labels_test`, `e7_workspace_localized_helpers_test` | pass | 22 + 19 + 32 passed | PASS |
| 5 | `test/kit_ratchet_test.dart` | every `workspace_screen.dart` entry drops to 0 | all its G1, G2, G7, G15, G16, G17, G21 entries → 0; the run has 2 failures in other files (`quota_monitor_section.dart` G17; kit files G21), present on the base | PASS (for this unit) |
| 6 | `flutter analyze` on the changed files | no issues | no issues | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-29, DATA-11 | `test/revamp/screen_work_1_test.dart` "a swipe runs the same act, never a confirmation" | step 2 |
  | KIT-34 | `screen_work_1_test.dart` "the menu archives at once with Undo…" | step 2 |
  | DATA-14 | `screen_work_1_test.dart` "delete of a shared conversation…" | step 2 |
  | LAY-5 (C37) | `screen_work_1_test.dart` "at 1280x800 the list sits beside an empty detail…" | step 2 |
  | KIT-1, G16 | `test/kit_ratchet_test.dart` | step 5 |

- Changed test expectations (TEST-19):
  - `workspace_hierarchy_test.dart` and `session_needs_you_test.dart`: the row's first span is now "Needs you · " (attention tone, KitNeedsYou) and the blocker name is the second span (LOOK-24, STATE-9).
  - `workspace_hierarchy_test.dart` "a two-line session name…": title x 60 → 58 (30 dp icon tile, VL §4).
  - `workspace_hierarchy_test.dart` project path tests: the path is under the sheet's Details fold, not a SelectableText (KIT-33).
  - `workspace_hierarchy_test.dart`, `session_pins_test.dart`: the row menu opens on long-press, not a per-row PopupMenuButton (KIT-28).
- Goldens added (each opened and looked at), `test/revamp/goldens/work_workspace_<state>[_1280x800]_<dark|light>.png`: loaded, loaded_1280x800, empty, context_sheet, archive_undo, delete_confirm, folder_chooser, folder_chooser_error (16 PNGs). Approved renders (EVID-12): `docs/design/visual-language-2026-09-26/Main.png` and `WorkLight.png` for loaded (differences: no grouped surface1 panels around the session sections, no needs-you card, no composer pill — all part of the deferred redesign); `Desktop.png` for loaded_1280x800 (differences: no search field or Ctrl-key hints in the list pane, no changes pane; the detail shows the empty state because no row is selected).
- Before and after: `before-workspace-loaded.png` (base `test/goldens/work_loaded_dark.png`) → `after-workspace-loaded.png`; `before-workspace-folder-chooser.png` (base `test/goldens/work_chooser_dark.png`) → `after-workspace-folder-chooser.png`; `after-workspace-loaded-1280x800.png` (no before render at 1280).
- Accessibility: every icon-only control is a KitIconButton with a label (search: "Search conversation titles across every project on this server"; isolated task); row actions are KitRowMenu items and semantic custom actions; the Needs-you mark carries its word; the header is a KitTappable with a tooltip; targets ≥ 48 dp from the kit; 2.0/2.5 text checked by `workspace_hierarchy_test` (320 dp).
- Privacy and security: the share link is copied with `KitCopy.copy(redact: false)` (it is the product of sharing, not a secret); no credentials, storage keys or external links changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/screen_work_1_test.dart test/revamp/screen_work_1_golden_test.dart
$F test -j 1 test/workspace_hierarchy_test.dart test/session_needs_you_test.dart test/session_pins_test.dart
$F test -j 1 test/kit_ratchet_test.dart
$F analyze lib/ui/screens/workspace_screen.dart test/revamp/screen_work_1_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared tests outside the unit's write set were not run (owner decision 2026-09-27); those expected to break are listed for the integrator (below).
- The embedded ChatScreen in the detail pane: back-gesture and draft behaviour inside a pane (ChatScreen's own PopScope) are not tested.
- A failed archive commit's notice is not covered by a test.
- `flutter analyze` on the whole tree was not run; only changed files.
- The base's `test/kit_ratchet_baseline.json`, `test/l10n_coverage_test.dart` baseline and `_migrated` list are not updated (integrator, R05/R10).

Shared tests expected to break (integrator, TEST-19 case 1): `test/work_tab_cleanup_test.dart` and `test/workspace_stable_layout_test.dart` (`widget<Text>` on `current-project-name`, now a KitText; name font rungs; `TextButton`/`IconButton` isolated task; per-row PopupMenuButton), `test/projects_screen_test.dart` (archived sheet rows, PopupMenuButton, SnackBarAction Undo, "Conversation actions" tooltip), `test/safety_confirms_test.dart` and `test/v2_feature_gating_test.dart` ("Conversation actions" tooltip button), `test/nudge_moments_test.dart` (Work pin tip is KitNotice.offer, not NudgeCard), `test/goldens/work_tab_golden_test.dart` (work_* goldens change), possibly `test/desktop_context_menu_test.dart`, `test/accessibility_guidelines_test.dart`, `test/team_discover_test.dart` (KitSegmented in place of SegmentedButton), and the census shots `tool/capture/census/areas/e_workspace.dart` for the two deleted pages.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-work-1` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `23b2efb5` |
| Deployed | No | |
| Released | No | |
