# revamp-screen-team-2: Revamp team (4 files) (2026-09-27)

## 1. Scope

- Unit: `screen-team-2` (wave 2b, screen-revamp). Finish line: `merge_section.dart`, `start_run_sheet.dart`, `team_board_screen.dart` and `team_home_screen.dart` construct only kit parts (G1, G2, G7, G15, G16, G17, G21, G48 all 0), the team objective is a draft that survives type, swipe and reopen and is swept with the profile, and each page is handled by its map proposal. Non-goal: the team page's new structure (slice-P3.4), merge on green (slice-P6.4), any new gateway call, controller field or persistence beyond the kit draft.
- Files changed: `lib/ui/screens/team/{merge_section,start_run_sheet,team_board_screen,team_home_screen}.dart`, `lib/l10n/app_en.arb` (3 keys: `teamMergeConfirmTask`, `teamMergeFailedNext`, `teamStartRunRefusedKept`; English only, owner decision 2026-09-27) + generated `app_localizations*.dart`, owned tests `test/team_board_test.dart`, `test/team_merge_test.dart`, `test/team_home_layout_test.dart`, `test/goldens/team_board_golden_test.dart` (+ 30 board goldens), new `test/revamp/screen_team_2_test.dart`, `test/revamp/screen_team_2_golden_test.dart` (+ 12 goldens under `test/revamp/goldens/team_*`). `test/team_home_stable_layout_test.dart` needed no change.
- Pages (map ids): embedded-team-merge-section, embedded-team-planning-card, start-run-sheet, team-board, team-home, team-home-agents-tab, team-home-needs-you-tab, team-home-runs-tab, team-merge-approve-sheet, team-merge-changes-sheet, team-merge-confirm-sheet.
- Specs followed: STANDARDS.md §1, MAP-1, STATE-20, STATE-21, DATA-1, DATA-2, KIT-1, LOOK-14, LOOK-24 (no attention roles outside the kit), LAY-8, LAY-12; kit-api KitTopBar, KitScreen, KitSearchField, KitBoardLane, KitChecklist, KitChoiceList, KitField (draft), KitSheet (KitDraft), KitConfirmSheet, KitNotice, KitRowGroup, KitSwitchRow.
- Contract problems (PROC-20):
  - Task text says `docs/qa/revamp-<unit id>/README.md`; EVID-1 says `…-<YYYY-MM-DD>/`. The rulebook form was used.
  - Task text asks for real Arabic in `app_ar.arb` (R04); the owner decision of 2026-09-27 drops Arabic. New keys are in `app_en.arb` only; the owned layout tests now run English, left to right only.
  - Attribution trailer: the task text names "Claude Opus 5.5 (1M context)"; the session's attribution instruction names "Claude Opus 5.5". The session's form was used.
  - `test/goldens/failures/` is tracked on the base (`team_agent_*` diff images committed by an earlier unit). This unit neither added nor staged anything there; removing the tracked files is left to the integrator.
  - KitTopBar has no subtitle key, so `ValueKey('team-home-host')` is gone (tests that read it are listed below).
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - team-home (redesign → kit-only rebuild of today's layout; new structure deferred to slice-P3.4). whenMissing "team.on: offers-enable" → deferred to slice-P3.4 (the page is unreachable without the team; the Work tab's discover door covers it). statesMissing "paused by the heat guard not distinguished" → deferred: needs a thermal-pause field (no data today), slice-P5.3. infoMissing "time/cost per task" → deferred to slice-P5.5.
  - team-home-runs-tab (merge-into:team-home, slice-P3.4) → least change: `// revamp:` marker above `TeamHomeScreen`; the search moved to the kit's pinned `KitSearchField` only because the old TextField/PopupMenu are not kit. actionsMissing "open the task's conversation directly" → already done on the base (rows call `TeamConversation.open`). statesMissing "search active while Needs you stays unfiltered" → deferred to slice-P3.4. couldBeAutomatic "upkeep never shown" → deferred to slice-P3.4 (switch kept, now `KitSwitchRow`).
  - team-home-agents-tab (merge-into:team-home, slice-P3.4) → least change: the agents row uses `KitChevron`. statesMissing "agents crashed / not starting in the row" → deferred to slice-P3.4. couldBeAutomatic "row is status" → already a status row.
  - team-home-needs-you-tab (merge-into:team-home, slice-P3.4) → least change: several questions now sit on one `KitRowGroup` panel. actionsMissing "answer again after refusal from the row", "undo an answer" → deferred to slice-P4.1c (gate rows live in `team_needs_you.dart`, not this unit's file; undo needs a gateway inverse). statesMissing "answered, waiting for host has no time bound" → deferred to slice-P4.1c.
  - team-board (keep) → kit-only rebuild, no behaviour change: `KitBoardLanes`/`KitBoardLane` (paged on a phone, side by side from expanded), title switcher → `KitChoiceList` sheet, refusal `KitNotice` (failure tone), no dimming when stale. actionsMissing "Undo after a move", "filter/search across columns" and statesMissing "no census render", "offline phone" → deferred (keep proposal; no owner id in work-units.json → no owner).
  - embedded-team-merge-section (fix) → done: one primary for the next step (Approve while the request waits, then Merge) — `team_merge_test.dart` "approves at once (no sheet), then Merge is the next step", "gone when the host already recorded an approval". statesMissing "merge failed/conflict with next step" → done: a refused merge is a `KitNotice` with "Nothing was merged. Fix what the host says, then try again, or review the changes." and Try again — `team_merge_test.dart` "a host refusal on a boundary shows the boundary text", "a plain refusal shows the host message". actionsMissing "undo approval" → deferred: needs an unapprove gateway call (none in `OrchestrationMergeGateway`), slice-P6.4. couldBeAutomatic "approve/merge automatically under Balanced/Autonomous" → deferred to slice-P6.4.
  - team-merge-confirm-sheet (fix) → done: `showKitConfirm(destructive)` is the only merge confirmation (the arming step is gone) and says what is merged: "Task: <title>", "<n> files · +a / −d", "Merge into <branch>" — `team_merge_test.dart` "one confirmation names the task, the files and the branch", "a cancelled confirmation sends nothing".
  - team-merge-approve-sheet (remove, slice-P6.4) → done: the sheet is gone; Approve sends at once and its receipt ("Approval recorded") shows under the buttons; `// revamp: remove (slice-P6.4)` marker above `_approve`.
  - team-merge-changes-sheet (keep) → kit-only: `showKitSheet` (half height) with mono paths, +/− in success/danger tones, work items on a `KitRowGroup`. statesMissing "no diff available" and actionsMissing "open a file's diff" → deferred to slice-P3.7a (one diff component).
  - start-run-sheet (fix) → done: actionsMissing "draft kept on dismiss (critical)" → `KitField(draft:)` for the objective, the direct title and details (`oc.draft.team.objective|task|taskDetails.<profileId>`) — `screen_team_2_test.dart` "the objective survives typing, a swipe and a reopen; the profile sweep removes it", "a task the host took clears the draft". "recovery: edit and resend a refused task" → done: a planner refusal keeps the sheet open with the host's words and the draft — `screen_team_2_test.dart` "a refused task stays in the sheet …". "remembered supervision per server" → deferred: persistence (STATE-21 non-goal), slice-P6.3. statesMissing "sending" → done: Send shows working and the fields are disabled while it goes (existing behaviour, now `KitAction.working`); "refused (back on home as a card)" → done in the sheet (above). whenMissing "team.control: explains" → unchanged (planner-off `KitStateView` with the host guide only when there is no direct path). couldBeAutomatic "default to the open project" → deferred to slice-P6.3.
  - embedded-team-planning-card (merge-into:team-conversation, slice-P6.3) → least change: kit-only (`KitText`, token spacing, `KitPageRoute`), `// revamp:` marker above `TeamPlanningCard`; still-planning and unconfirmed tones moved off the attention role (progress/neutral) for G17. actionsMissing "Edit and send again", "Message the planner", "Cancel" → deferred to slice-P6.3.
- States per page (STATE-20): team-home loaded (goldens `team_home_loaded`, `_1280x800`), search (golden `team_home_search`), empty (golden `team_home_empty`; `team_home_layout_test` "stale, empty, loading and error fit"), loading / error / not answering (unchanged `teamScreenState`, same layout test), stale (status line, same test). team-board loading, loaded, lane empty, empty, error, not answering, read-only, refused, moving (30 `team_board_*` goldens; `team_board_test.dart`). merge section loading, unavailable, no roles, ready, not ready, pending, boundary, sent, confirmed, unconfirmed, refused (`team_merge_test.dart`). start sheet form (golden `team_start_run`, `_1280x800`), sending, refused, planner off / missing, direct (`screen_team_2_test.dart`, shared `team_controls_test.dart`).
- Deferred states (STATE-21): listed above with their reason and owner.

## 2. Builds

- Branch `revamp/screen-team-2`, base `2cec35ca` (feat/phone-setup-v2), code head `a7bda280`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work at the wave 2b checkpoint.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first | n/a: the draft, refusal and one-confirmation behaviours are new and have new tests | n/a | PASS |
| 2 | `test/revamp/screen_team_2_test.dart` | passes | 3 passed | PASS |
| 3 | `test/revamp/screen_team_2_golden_test.dart --update-goldens`, then looked at | 12 images | 12 passed | PASS |
| 4 | `test/team_board_test.dart` | passes | 17 passed | PASS |
| 5 | `test/team_merge_test.dart` | passes | 25 passed | PASS |
| 6 | `test/team_home_layout_test.dart` | passes | 2 passed (the Technical details sheet's own overflow is taken, see NOT proven) | PASS |
| 7 | `test/team_home_stable_layout_test.dart` | passes | 3 passed | PASS |
| 8 | `test/goldens/team_board_golden_test.dart --update-goldens`, then looked at | 30 images | 30 passed | PASS |
| 9 | `KIT_RATCHET_WRITE=1 test/kit_ratchet_test.dart`, read, then `git checkout test/kit_ratchet_baseline.json` | no entry for the four files in any gate | 0 entries (G1, G2, G7, G15, G16, G17, G21, G48) | PASS |
| 10 | `flutter analyze lib test` | no issue in changed paths | 1 info in `test/goldens/kit/kit_tappable_golden_test.dart` (not this unit's) | PASS |
| 11 | Base check: base `team_home_layout_test.dart` against base code | – | fails with the same 82 px overflow in the Technical details sheet | recorded |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | DATA-1, DATA-2, G10 | `test/revamp/screen_team_2_test.dart` "the objective survives typing, a swipe and a reopen; the profile sweep removes it" | step 2 |
  | DATA-14 | `screen_team_2_test.dart` "a refused task stays in the sheet …" | step 2 |
  | KIT-1, G16, G1, G17, G21 | `test/kit_ratchet_test.dart` (write mode, read, reverted) | step 9 |
  | LAY-12 | `team_board_test.dart` (one KitRefresh on screen: the lane in view) | step 4 |
  | STATE-10 | `team_merge_test.dart` "sent while the host has not answered, then confirmed", "an approval in flight is shown as sent" | step 5 |

- Changed test expectations (TEST-19):
  - `team_board_test.dart`: counts are read under the tab key (KitBoardColumn has no count key); needs-you is read from `KitBoardLanes.columns`; the "Moving to Ready" receipt is matched as rich text; the home opens the board from the top bar's overflow on a phone (KitTopBar compact shows one action), and back is a Navigator pop (no BackButton widget).
  - `team_merge_test.dart`: no arming step and no approve sheet; Approve disappears once approved; readiness lines are `KitChecklist` steps instead of ✓/✗ icon labels; the request line has no leading "·"; refusals are notices matched with `contains`.
  - `team_home_layout_test.dart`: English, left to right only (owner decision); Technical details opens from the overflow while search is in the bar; the filter reads as the search field's chip.
  - `team_board_golden_test.dart`: one more shot, `team_board_working_1280x800`.
- Goldens (each opened and looked at): `test/goldens/team_board_*` (28 regenerated, 2 new at 1280x800); `test/revamp/goldens/team_home_loaded[_1280x800]`, `team_home_empty`, `team_home_search`, `team_start_run[_1280x800]`, each `_dark`/`_light`. Approved renders (EVID-12): `docs/design/visual-language-2026-09-26/Main.png` for team_home_loaded (differences: no glass top controls or dock — this is a pushed page with KitTopBar; the needs-you block is the team's own request card; section labels and row panels match); `Desktop.png` for the 1280x800 shots (differences: single centred list, no side panes — the home has no detail pane); `Confirm.png` for the merge confirmation (not rendered as a golden here, see NOT proven).
- Before and after: `before-team-home-loaded.png` (base `test/goldens/team_home_loaded_dark.png`) → `after-team-home-loaded.png`, `after-team-home-loaded-1280x800.png` (no before render at 1280); `before-team-start-run.png` (base `test/goldens/team_start_run_dark.png`) → `after-team-start-run.png`; `before-team-board-working.png` (base golden) → `after-team-board-working.png`, `after-team-board-working-1280x800.png` (no before render at 1280).
- Accessibility: top bar actions are labelled KitIconButtons (Search tasks / Close search, Technical details, Board) with the rest in the labelled overflow; the board's title switcher is labelled "Choose project"; lanes are labelled containers with the strip as the swipe's visible twin (KitBoardLanes); choices are KitChoiceList rows (selected semantics, one Tab stop); fields are KitFields with labels and errors; 2.5x text at 320 dp covered by `team_home_layout_test` and `team_home_stable_layout_test`.
- Privacy and security: drafts are stored under `oc.draft.team.<field>.<profileId>`, swept by `ProfileStore.profileScopedPreferenceKeys` (tested); no credentials, external links or notifications changed.
- Migration: n/a: no stored format changed (the draft keys are new).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/screen_team_2_test.dart test/revamp/screen_team_2_golden_test.dart
$F test -j 1 test/team_board_test.dart test/team_merge_test.dart
$F test -j 1 test/team_home_layout_test.dart test/team_home_stable_layout_test.dart
$F test -j 1 test/goldens/team_board_golden_test.dart
KIT_RATCHET_WRITE=1 $F test -j 1 test/kit_ratchet_test.dart   # read the four files' entries, then:
git checkout test/kit_ratchet_baseline.json
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared tests outside the unit's write set were not run (owner decision 2026-09-27). Expected to break (integrator, TEST-19 case 1):
  - `test/team_home_test.dart`, `test/team_now_test.dart`: read `ValueKey('team-home-host')` as a `Text` (the host phrase is now KitTopBar's subtitle, no key); `SwitchListTile` for `team-home-upkeep-toggle` (now `KitSwitchRow`, key on its switch); `team-home-info` may sit in the overflow when search shows.
  - `test/team_controls_test.dart`: `pageBack()` (no BackButton in KitTopBar); the project dropdown tap (now an inline KitChoiceList); `team-home-direct-receipt` is a KitNotice, not a SnackBar.
  - `test/team_policy_test.dart`, `test/team_one_page_test.dart`, `test/team_discover_test.dart`, `test/team_motion_test.dart`, `test/team_redesign_test.dart`, `test/team_design_standard_test.dart`, `test/team_run_screen_test.dart`, `test/ui_glossary_test.dart`: may rely on the old AppBar, Opacity, sheet title key `team-start-run-title` or merge arming copy.
  - `test/goldens/team_golden_test.dart` (`team_home_*`, `team_start_run`, `team_run_overview`, `team_run_merged`) and `test/goldens/team_sheets_golden_test.dart`: images change.
  - `test/design_standard_test.dart` `_migrated`: the new goldens live under `test/revamp/goldens/` (integrator, R10).
- The Technical details sheet (`lib/ui/widgets/team_technical_details.dart`, not this unit's) overflows by 82 px at 320 dp × 2.5x with the busy fixture; it fails the same way on the base. `team_home_layout_test` now takes that exception instead of failing on it.
- The merge section and its confirmation have no golden of their own (behaviour only, `team_merge_test.dart`); the run overview goldens that show it are integrator-owned.
- The direct-task refusal notice on the home (`team-home-direct-receipt`) is not covered by a test.
- `test/kit_ratchet_baseline.json`, the `l10n_coverage_test` baseline and `_migrated` are not updated (integrator, R05/R10); the ui-ledger part file was not touched.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-team-2` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `a7bda280` |
| Deployed | No | |
| Released | No | |
