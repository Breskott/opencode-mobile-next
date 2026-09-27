# revamp-screen-work-3: Revamp work — cloud environments, project health, folder dialogs (2026-09-27)

## 1. Scope

- Unit: `screen-work-3` (wave 2b, tier 1, `screen-revamp`). Finish line: every file in the write set is built from kit parts only in the VL look, each page is handled by its map proposal with its wave-2 missing states and actions. Non-goal: no gateway call, controller field or persistence is added (STATE-21); no wave-3 structure.
- Files changed: `lib/ui/screens/managed_workspaces_screen.dart`, `lib/ui/screens/project_folder_actions.dart`, `lib/ui/screens/project_health_screen.dart`, `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`), `test/managed_workspaces_screen_test.dart`, `test/folder_browser_test.dart`, `test/folder_browser_termux_test.dart`, new `test/revamp/screen_work_3_{test,golden_test,fixtures}.dart` and 44 goldens in `test/revamp/goldens/work_*`, and the census guard `tool/capture/census/areas/e_workspace.dart` (remove-dialog shot only, PROC-13).
- Pages (map ids): managed-workspaces, managed-workspaces-create-dialog, managed-workspaces-remove-dialog, project-folder-new-dialog, project-folder-open-dialog, project-health, project-health-git-init-dialog.
- Specs followed: STANDARDS.md §1, §4 (KIT-1, KIT-2, KIT-8, KIT-11, KIT-15, KIT-20, KIT-25, KIT-26, KIT-27, KIT-28, KIT-33, KIT-34), §5 (LOOK-1, LOOK-5, LOOK-12, LOOK-21, LOOK-27), §9 (STATE-1 to STATE-13, STATE-20, STATE-21), §15, §16; kit-v2 §9.1; visual-language §2, §4, §5.
- Contract problems (PROC-20):
  1. **KitSheet has no entry point for a caller-built `KitSheet`.** Rule: KIT-2 / G1 (`showModalBottomSheet` only inside the kit) and this unit's acceptance ("G1 reaches 0"). What it says vs the code: `FolderBrowserSheet` (`lib/ui/widgets/folder_browser.dart`, shared-work-1) is itself a `KitSheet(handle: false)` that expects its route to draw the handle; `showKitSheet` only takes a `body` and draws its own header, so wrapping the browser doubles the header and Close. Evidence: `project_folder_actions.dart` lines with `showModalBottomSheet<FolderBrowserChoice>` (2). Proposed text: KitSheet.md adds `Future<T?> showKitSheetFrame<T>(BuildContext, {required WidgetBuilder builder, KitSheetHeight height})` that opens a caller-built `KitSheet` in the kit modal shape (bottom / panel / side), or `FolderBrowserSheet` becomes a `showKitSheet` body. Blocks: G1 = 2 (`showModalBottomSheet(`) stays for `project_folder_actions.dart`; G16 and every other gate are 0.
  2. **Arabic.** R04 says new keys go in `app_ar.arb` too; the owner decision of 2026-09-27 (later, wins) drops Arabic. New keys are in `app_en.arb` only; `app_localizations_ar.dart` falls back to English for them.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - managed-workspaces: statesMissing "no provider configured: still offers New environment" → done: `screen_work_3_test.dart` "no provider: says where to set one up, offers no New", golden `work_managed_workspaces_no_provider_*`; "environment in Error: no reason or fix" → partial: the row says "Error" in words and offers Open again / Remove; the reason is deferred (needs a reason field on `WorkspaceInfo`, no owner). actionsMissing "set up a provider" → explains where (no in-app flow exists; no owner); "stop without removing" → deferred (needs a stop call on the gateway, no owner). couldBeAutomatic "discover on open" → deferred (it would send a server write on every open; no owner). Owner rationale items: rows "ci-sandbox · Daytona · Connected" → done (state word first, provider, branch); Discover in the overflow → done; pull to refresh → kept; pinned primary → done; KitStateView for no provider → done; New hidden until a provider works → done (also hidden while the list cannot be read).
  - managed-workspaces-create-dialog: statesMissing "create takes minutes" → done: the sheet says "usually takes a few minutes" before it starts and the page shows a creating state (`screen_work_3_test.dart` "a failed create…" asserts the wait text); "create fails" → done: page notice + Try again (same test). couldBeAutomatic "preselect the only provider" → done (first provider is selected). Rationale: "Provider" label, labelled Branch field with "Leave empty to use…" helper → done; golden `work_managed_workspaces_create_sheet_form_*`.
  - managed-workspaces-remove-dialog: statesMissing "remove fails" → done: `screen_work_3_test.dart` "a failed remove stays in the question; nothing is lost". infoMissing "exactly what is deleted" → partial: body names the provider and says the environment and what is in it are deleted, plus consequences (goes back to the project folder first when open; conversations stay in history); a per-provider list is deferred (needs provider metadata, no owner). One verb "Remove" → done.
  - project-folder-new-dialog (keep): kit-only rebuild (`showKitInputDialog`); "this phone" in the helper → done; statesMissing "create fails" → done (made inside the dialog, error under the name: `screen_work_3_test.dart` "a folder that cannot be made says why and keeps the name"); "name taken" → deferred (an existing folder is opened, not refused, by the current create call; no owner). actionsMissing "start from a template or git clone" → deferred (needs a gateway call; wave 3, no owner).
  - project-folder-open-dialog: statesMissing "permission denied on the folder" → shown when the server's probe says so (the text is the server's answer under the path); actionsMissing "browse on a remote server" → deferred (OpenCode lists files only inside its project; no owner); "Create it when missing (remote)" → deferred (no folder-creation API on other servers); inside the app, "No folder there" + Create it → done (confirmation, `projects_screen_test.dart` "a typed path that does not exist offers Create it" keeps passing by behaviour). couldBeAutomatic "suggest recent paths" → deferred (no owner). Golden `work_project_folder_open_dialog_missing_*`.
  - project-health: statesMissing "unsupported vs failed read the same" → deferred (needs a typed unsupported error from the gateway; no owner); "language server crashed: no reason, no restart" → partial: the row says "Not running · <server status>"; reason and restart deferred (no restart call; no owner). actionsMissing "open a changed file's diff" → deferred (the screen receives only a gateway, no route to Review; no owner); "restart a language server" → deferred (no gateway call). Rationale: error-tone failed rows with their word → done; "Set up" row instead of a filled button → done; "1 of 2 running" → done; honest "no 0 changed beside not initialized" → done (`screen_work_3_test.dart` "no git: no \"changed\" count…").
  - project-health-git-init-dialog (keep): already `showKitConfirm`; icon tile added. couldBeAutomatic "offer git init when a new phone project is created" → deferred (the built-in create already inits; Termux path no owner).
- States per page (STATE-20):
  - managed-workspaces: loading (bar + skeleton rows), empty (goldens via no-provider; empty with provider in code), no provider (golden + test), error (golden + test), creating (code + test path), failed refresh/discover/create/open (tests), loaded (golden + LAY-4 overflow tests).
  - managed-workspaces-create-dialog: form (golden), failed (page notice, test).
  - managed-workspaces-remove-dialog: typing (golden), working and failed (kit confirm, test).
  - project-folder-new-dialog: typing (golden), working and failed (test).
  - project-folder-open-dialog: checking (kit working state), missing/refused (golden), missing inside the app → Create it (shared test).
  - project-health: loading (bar + skeleton per section), error per section (golden), empty sections (code; shared tests assert the copy), no git (golden + test), gated git init (test), loaded (golden + LAY-4 overflow tests).
  - project-health-git-init-dialog: confirming (golden).
- Deferred states (STATE-21): environment error reason → needs `WorkspaceInfo` reason, no owner; unsupported vs failed health read → needs a typed unsupported error, no owner; language server crash reason → needs server detail, no owner.

## 2. Builds

- Branch `revamp/screen-work-3`, base `8dc27c66`, code head `9e901d21`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/screen_work_3_test.dart` + `test/managed_workspaces_screen_test.dart` | pass | 22 passed (`run2.txt`) | PASS |
| 2 | `test/folder_browser_test.dart` + `test/folder_browser_termux_test.dart` | pass | 15 passed (`run3.txt`) | PASS |
| 3 | `test/revamp/screen_work_3_golden_test.dart` (phone, after regeneration) | match | 22 passed (`run4.txt`); wide goldens rendered with `--update-goldens`, 22 passed | PASS |
| 4 | `flutter analyze --no-pub lib test tool` | no issues in changed paths | 1 pre-existing info in `test/goldens/kit/kit_tappable_golden_test.dart` (not this unit) | PASS |
| 5 | Ratchet, design-standard, l10n, glossary, ledger tests | pass | not run (owner decision 2026-09-27: run only this unit's files); G1/G16/G2/G7/G17/G21 patterns checked by source grep: 0 in all three files except G1 `showModalBottomSheet(` ×2 (contract problem 1) | NOT RUN |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | STATE-12, STATE-13 | `test/revamp/screen_work_3_test.dart` "no provider: says where to set one up, offers no New" | `run2.txt` |
  | STATE-9 | `test/revamp/screen_work_3_test.dart` "rows say their state in words and which one is in use" | `run2.txt` |
  | STATE-3 | `test/revamp/screen_work_3_test.dart` "a list that cannot be read says why and tries again" | `run2.txt` |
  | STATE-6, KIT-34 | `test/revamp/screen_work_3_test.dart` "a failed create says so on the page with Try again" | `run2.txt` |
  | DATA-11, KIT-28 | `test/revamp/screen_work_3_test.dart` "a failed remove stays in the question; nothing is lost" | `run2.txt` |
  | LAY-4 | `test/revamp/screen_work_3_test.dart` "loaded fits Size(…)" (5 sizes × 2 screens) | `run2.txt` |
  | KIT-20 | `test/revamp/screen_work_3_test.dart` "a folder that cannot be made says why and keeps the name" | `run2.txt` |

- Changed test expectations (TEST-19, all kind (1): how it is built):
  - `managed_workspaces_screen_test.dart`: Discover is opened from the top bar overflow (map rationale); the outcome is read at the top of the list instead of a SnackBar (KIT-34); the row menu is opened by long-press, not a `PopupMenuButton` (KIT-28), and its item is Remove, not Delete (map: one verb); "nothing removed before the name is typed" is asserted by the repository call instead of a `FilledButton.onPressed`; the create sheet closes with Close, not Cancel (KIT-19).
  - `folder_browser_test.dart`, `folder_browser_termux_test.dart` (were already failing on the base after shared-work-1 rebuilt the browser): the shown path is read from `KitText`, the LTR check reads the rendered `RichText`, taps first scroll the control into view (the folders now sit in the sheet's scrolling body), the keyboard test focuses the field with `showKeyboard`, and the path field is read through its `EditableText` (it is a `KitField`).
- Goldens added (each opened and looked at): 44 PNGs `test/revamp/goldens/work_{managed_workspaces_{loaded,no_provider,error,create_sheet_form,remove_sheet_typing},project_health_{loaded,no_git,error,git_init_sheet_confirming},project_folder_{new_dialog_typing,open_dialog_missing}}[_1280x800]_{dark,light}.png`. Approved renders (EVID-12): `docs/design/visual-language-2026-09-26/Settings.png` (rows on surface1 panels, sentence-case section labels, icon tiles) and `Desktop.png` (wide: content centred at the reading width). Differences: pushed pages use `KitTopBar` with Back instead of a large title (the renders show tab roots); otherwise none noted.
- Before and after (EVID-10): `before-managed-workspaces-loaded.png` / `after-managed-workspaces-loaded.png`, `before-managed-workspaces-create-dialog-form.png` / `after-managed-workspaces-create-dialog-form.png`, `before-project-health-loaded.png` / `after-project-health-loaded.png`, `before-project-folder-open-dialog-missing.png` / `after-project-folder-open-dialog-missing.png` (before: base census PNGs).
- Accessibility: every row is a `KitRow` (48 dp+, menu items exposed as semantic actions); icon-only top bar actions carry labels ("Refresh", "Refresh project health"); line counts are read as words ("24 lines added, 3 removed"); state never by colour alone (words on every row); 200 % text checked by `managed_workspaces_screen_test.dart` at 320 dp.
- Privacy and security: n/a: no credentials, stored data, external links or notifications changed. "Copy ID" copies the environment id through `KitMenuItem.copy` (not a secret).
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/screen_work_3_test.dart test/managed_workspaces_screen_test.dart
$F test -j 1 test/folder_browser_test.dart test/folder_browser_termux_test.dart
$F test -j 1 test/revamp/screen_work_3_golden_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- The shared gates (`kit_ratchet_test`, `design_standard_test`, `l10n_coverage_test`, glossary, ledger) were not run (owner decision 2026-09-27); `_migrated` entries for these files are the integrator's (R10).
- Shared tests not run; expected to need the integrator: `test/v2_feature_gating_test.dart` "v2 hides both sections and explains git init in place" reads the gated row as a `ListTile` (now `KitRow.unavailable`); `test/e7_library_layout_test.dart` expects a "Cancel" after opening New environment (the sheet closes with Close); `test/project_health_screen_test.dart` and `test/projects_screen_test.dart` were written against visible text and keys that are kept, but were not run.
- The in-app "No folder there → Cancel → back to the path" loop has no test of its own.
- Arabic and right-to-left were not reviewed (dropped by the owner).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | partial (G1 `showModalBottomSheet` ×2 blocked, PROC-32) | `revamp/screen-work-3` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `9e901d21` |
| Deployed | No | |
| Released | No | |
