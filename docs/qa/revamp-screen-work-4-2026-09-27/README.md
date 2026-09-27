# revamp-screen-work-4: Revamp work, 3 files (2026-09-27)

## 1. Scope

- Unit: `screen-work-4` (wave 2b, screen-revamp, tier 1). Finish line: every file in the write set has G1, G16, G2, G7, G17, G21 and G48 counts of zero, each page is handled by its map proposal, and the look is VL. Non-goal: no gateway call, controller field or persistence format added (wave-3 behaviour stays deferred).
- Files changed: `lib/ui/screens/development_services_screen.dart`, `lib/ui/screens/isolated_task_sheet.dart`, `lib/ui/screens/projects_screen.dart`, `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`), `test/development_services_screen_test.dart`, `test/codex_project_navigation_test.dart`, new `test/revamp/screen_work_4_test.dart`, `test/revamp/screen_work_4_golden_test.dart` and 32 PNGs in `test/revamp/goldens/work_*.png`.
- Pages (map ids): development-services, development-services-confirm-sheet, development-services-editor-sheet, development-services-logs-sheet, isolated-task-sheet, projects, projects-rename-dialog.
- Specs followed: STANDARDS.md §1, §4 (KIT-1, KIT-2, KIT-11, KIT-15, KIT-18, KIT-20, KIT-22, KIT-23, KIT-26, KIT-27, KIT-28, KIT-29, KIT-31, KIT-32, KIT-33, KIT-34, KIT-38), §5 (LOOK-5, LOOK-12, LOOK-19, LOOK-21), §15, §16; kit-v2 §9.1; visual-language rows and sheets (§5).
- Contract problems (PROC-20):
  - The task text asks for `docs/qa/revamp-<unit id>/README.md`; STANDARDS.md EVID-1 asks for `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/README.md`. The rulebook path was used.
  - The task text says copy goes to `app_en.arb` **and** `app_ar.arb` (R04); the later owner decision (2026-09-27, Arabic dropped) wins, so new keys are in `app_en.arb` only. gen-l10n fills Arabic with the English text.
  - KIT-18 (`dismissible: false` only while an irreversible step runs): `showKitSheet` takes `dismissible` once, at open time, and a swipe on a bottom sheet pops without asking any PopScope. The isolated task sheet must never be swiped away while its conversation is being opened, so it opens with `dismissible: false` (as the old sheet did: `isDismissible: false`, `enableDrag: false`) and its body turns back, Esc and a tap outside into Close in every other state. A kit follow-up could offer a `ValueListenable<bool>` dismissible.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - development-services: actionsMissing "undo Remove (snackbar)" → done: `development_services_screen_test.dart` "Remove of a saved service offers Undo…"; "ask the agent to add or fix a dev command" → deferred (no owner; needs an agent entry point); "stop everything this project runs" → deferred (no owner; Running now respec). statesMissing "loading skeleton" → n/a: the list is local and shows at once, runtime refresh uses the KitScreen loading bar; "server offline" → done: offline KitNotice (`servicesOffline`), no golden; "command exited or crashed (exit code)" → done: row says "Stopped · Recorded exit code: n" and the log ends with the exit code; "preview not reachable yet" → deferred (no owner; needs a reachability probe). couldBeAutomatic "Start without a confirm" → done: "Start runs at once with Stop as its undo…"; "restart on crash (opt-in)" → deferred (no owner).
  - development-services-confirm-sheet: statesMissing "action failed (stay open with the reason)" → done: every question runs its act through `showKitConfirm(action:)` (failure keeps it open); actionsMissing "undo for Remove" → done (above); Start has no question → done.
  - development-services-editor-sheet: statesMissing "saving" → n/a (save is local and immediate); "save failed" → done: the screen shows the error notice and the drafts are kept for the next open; "dirty-dismiss confirm" → done differently: every field keeps a draft, so dismissal loses nothing and asks nothing (KitDraft rule); "duplicate name" → done: "the editor says what is missing and refuses a duplicate name". actionsMissing "Cancel" → done: the frame's labelled Close; "discard guard" → done via drafts ("draft carry…" test); "ask the agent to fill it in" → deferred (no owner). couldBeAutomatic "suggest scripts from the project" → deferred (no owner; needs a file read of package.json).
  - development-services-logs-sheet: statesMissing "empty log" → done: `servicesLogEmpty` in KitLogPanel; "command stopped (last log)" → done: KitLogEnd with exit code; "fetch failed" → done: KitNotice.error with Refresh. actionsMissing "copy log", "follow new output" → done by KitLogPanel (copy all, follow, poll only while open); "Stop/Restart from the log" → done: sheet primary Stop, secondary Restart (golden `work_development_services_logs_sheet_*`).
  - isolated-task-sheet: statesMissing "setup takes minutes: no expectation or elapsed time" → done: KitProgress.staged 1–3 of 3 with "Usually 1–3 minutes" and KitStateView `since` escalation ("the wait is staged…" test, golden `work_isolated_task_sheet_creating_*`); "failed setup: the copy exists but can't be used or removed here" → partly: it says the copy stays listed under Manage project; actionsMissing "write the first prompt", "Start anyway after failed setup", "Run setup again", "Remove the copy" → deferred (no owner in wave 2; each needs a new gateway call or sending a prompt, which this unit's non-goal forbids).
  - projects: statesMissing "project folder deleted on the server" → deferred (no owner; needs server data). actionsMissing "forget a project" → deferred (no owner; needs a gateway call); "New conversation on the read-only variant" → deferred (no owner; needs the shell's new-conversation route); the read-only variant keeps the title Projects and says "This server works in one folder" → done (`codex_project_navigation_test.dart`, golden `work_projects_one_folder_*`). Rename moved into the row menu, the current project has KitRowIcon(current) and the word "Current" → done ("the current project says so…", "rename runs from the row menu…").
  - projects-rename-dialog (keep): statesMissing "rename fails" → done: the rename runs inside `showKitInputDialog(onSubmit:)` and a failure stays under the field ("a failed rename stays in the dialog…").
- States per page (STATE-20): projects: loading (KitSkeletonRows + bar), error (golden), empty (KitStateView), no match (KitSearchNoMatch, test), loaded (golden), one folder (golden), switch failed (test); development-services: empty, running, unsupported (goldens), scope changed, unknown, offline (tests/notice); editor (golden), log (golden), Stop question (golden); isolated-task-sheet: form, creating, failed (goldens), unconfirmed/ready-open-failed/cancelled (code; shared test `test/isolated_task_sheet_test.dart`).
- Deferred states (STATE-21): see the map items above.

## 2. Builds

- Branch `revamp/screen-work-4`, base `8dc27c66`, code head `fd451271`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first | n/a | this unit is a rebuild; no bug fix was claimed | n/a |
| 2 | `test/development_services_screen_test.dart` | passes | 15 passed | PASS |
| 3 | `test/revamp/screen_work_4_test.dart` | passes | 12 passed | PASS |
| 4 | `test/codex_project_navigation_test.dart` | passes | 2 passed | PASS |
| 5 | `test/revamp/screen_work_4_golden_test.dart --update-goldens`, then each PNG opened | 32 renders, no exception | 32 passed | PASS |
| 6 | `KIT_RATCHET_WRITE=1 … test/kit_ratchet_test.dart` (measurement only; baseline restored with `git checkout`) | no entry left for the three files in any gate | none left in G1, G2, G7, G16, G17, G21, G48 | PASS |
| 7 | `flutter analyze lib test` | no issues in changed paths | 1 info, in `test/goldens/kit/kit_tappable_golden_test.dart` (not this unit) | PASS |

Not run (owner decision 2026-09-27: only the unit's own test files): the other suites, including the shared tests listed under NOT proven.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test or golden | Output |
  |---|---|---|
  | KIT-2, KIT-11 | ratchet write-mode measurement (run 6) | no G1 entry for the three files |
  | DATA-1 (P7.1 draft carry) | `development_services_screen_test.dart` "draft carry: typed input survives swipe, reopen and a restart; the profile sweep removes it" | run 2 |
  | KIT-34 / DATA-11 | "Remove of a saved service offers Undo…", "Undo after Start stops the command it started" | run 2 |
  | KIT-28 | "rename runs from the row menu and saves inside the dialog" | run 3 |
  | KIT-31 | "Start runs at once… the log follows the run" | run 2 |
  | LAY-4 overflow | "lays out without overflow: phone / narrow large text / wide" (both screens) | runs 2, 3 |

- Changed test expectations (TEST-19), in this unit's own test files:
  - `development_services_screen_test.dart`: Start no longer asks (map: "Start needs no confirm") → the test taps the row's Start and checks the undo bar; confirm buttons found by `development-services-confirm` instead of `FilledButton`; row text is RichText (`findRichText`); Logs, Visit, Forget and Remove are reached through the row menu (KIT-28); the refresh tooltip moved into the top bar menu; the capture-to-disk variant was replaced by overflow checks at 412, 320 @ 2.0 and 1280 (the census owns captures, TEST-17).
  - `codex_project_navigation_test.dart`: title "Project context" → "Projects" plus "This server works in one folder" (map proposal for `projects`); the app now has the localization delegates the kit's search field needs.
- Goldens added (each opened and looked at), `test/revamp/goldens/`:
  - `work_projects_{loaded,error,one_folder,rename_dialog}_{dark,light}.png`, `work_projects_loaded_1280x800_{dark,light}.png`.
  - `work_development_services_{empty,running,unsupported,editor_sheet,logs_sheet,confirm_sheet_stop}_{dark,light}.png`, `work_development_services_running_1280x800_{dark,light}.png`.
  - `work_isolated_task_sheet_{form,creating,failed}_{dark,light}.png`, `work_isolated_task_sheet_form_1280x800_{dark,light}.png`.
  - Approved renders (EVID-12): `docs/design/visual-language-2026-09-26/WorkLight.png` (rows in surface1 panels with hairlines, icon tiles, a muted supporting line) — the Projects and Development services lists follow it; differences: no floating dock or composer (these are pushed pages), and the current project's row is also filled as selected. `Confirm.png` — the Stop question uses showKitConfirm unchanged. `Desktop.png` — wide windows centre the list at 960 dp; no sidebar here (pushed page).
- Before and after (EVID-10): `before-projects-loaded.png` / `after-projects-loaded.png`, `before-development-services-running.png` / `after-development-services-running.png`, `before-development-services-editor-sheet.png` / `after-development-services-editor-sheet.png`, `before-isolated-task-sheet-creating.png` / `after-isolated-task-sheet-creating.png` (before from base `8dc27c66` census PNGs).
- Accessibility: every icon-only control is a KitIconButton with a label (Start, Stop, the top bar Add and Refresh); rows expose their menus as semantic custom actions (KitRow); the current project is named in words ("Current · …"), not by colour; state views are live regions; checked at 2.0 text on a 320 dp window with no overflow.
- Privacy and security: Visit still goes through `openExternalLink`; the editor rejects unsafe preview URLs (`safeExternalLinkUri`). Drafts are stored as `oc.draft.developmentService.<field>.<scope>.<profileId>` and swept by `ProfileStore.profileScopedPreferenceKeys` (tested). No credentials involved.
- Migration: n/a — the saved-services format is unchanged; the drafts are new keys.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/development_services_screen_test.dart test/revamp/screen_work_4_test.dart test/codex_project_navigation_test.dart
$F test -j 1 test/revamp/screen_work_4_golden_test.dart
KIT_RATCHET_WRITE=1 $F test -j 1 test/kit_ratchet_test.dart && git diff test/kit_ratchet_baseline.json; git checkout test/kit_ratchet_baseline.json
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared tests not run (owner decision): `test/projects_screen_test.dart` is expected to fail — its apps have no localization delegates (KitSearchField reads `AppLocalizations.of`), and it taps `rename-project-project-1` directly, which is now a row-menu item (long-press first). `test/isolated_task_sheet_test.dart`, `test/e7_project_attention_layout_test.dart`, `test/workspace_stable_layout_test.dart`, `test/search_index_test.dart`, `test/kit_ratchet_test.dart` (read mode), `test/design_standard_test.dart`, `test/l10n_coverage_test.dart` and the census guards in `tool/capture/census/areas/{e_workspace,h_termux}.dart` were not run.
- The ratchet baseline, `_migrated` and the l10n baseline are integrator-owned and were not regenerated.
- Glass is not used on these pages (they are pushed pages without the floating navigation layer).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-work-4` |
| Enabled | Yes (no flag) | |
| Verified | Partly: own tests and goldens only | this record |
| Committed | Yes | `3599f22f`, `fd451271` and the record commit |
| Deployed | No | |
| Released | No | |
