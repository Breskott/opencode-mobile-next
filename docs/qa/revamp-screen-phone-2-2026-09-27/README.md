# revamp-screen-phone-2: Revamp phone, setup progress and Running now (2026-09-27)

## 1. Scope

- Unit: `screen-phone-2` (wave 2b, screen, tier 1). Finish line: the setup progress screen, the setup hero and Running now are built from kit parts only (G1, G2, G7, G16, G17 and G21 at zero for all three files), and their map items that the three files can hold are done. Non-goal: `SetupProgressView` (`lib/ui/widgets/setup_progress_view.dart`) and the phone start and ready screens, which are outside the write set.
- Files changed: `lib/ui/screens/phone_setup/phone_setup_hero.dart`, `lib/ui/screens/phone_setup/phone_setup_progress_screen.dart`, `lib/ui/screens/termux_processes_screen.dart`, `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`), `test/phone_setup_progress_screen_test.dart`, `test/termux_processes_test.dart`, new `test/revamp/screen_phone_2_golden_test.dart` and its goldens, `test/goldens/setup_progress_{running,failed,log}_{dark,light}.png`.
- Pages (map ids): phone-setup-progress, phone-setup-progress-stop-sheet, termux-processes, termux-processes-details-sheet, termux-processes-stop-group-sheet, termux-processes-stop-one-sheet.
- Specs followed: STANDARDS.md §1, §4 (KIT-1), §5 (LOOK-4, LOOK-5, LOOK-24), §9, §15, §16; kit-v2 §4.1 (confirm first for stops), §4.2 (destructive last, "Keep running"), §4.3 (one details fold), §4.7 (confirm replaces the sheet in place), §4.8 (feedback in place), §9.1 (allowlist); visual language §5 (sheets, consequences panel).
- Contract problems (PROC-20):
  1. `KitRowGroup.labelTrailing` is laid out unflexed next to the label (`lib/ui/kit/kit_row.dart` ~636). A "Stop all" button there overflows by 41 px at 320 dp and 2.5x text. This unit put Stop all as the group's destructive last row instead (kit-v2 §4.2 allows that), so nothing blocks. Proposed fix: wrap `labelTrailing` in `Flexible` or move it under the label when the row is too narrow. Owner: KitRow.
  2. The task text's R04 says "app_en.arb AND app_ar.arb (real Arabic)". The owner decision of 2026-09-27 (Arabic dropped) is later and wins, so the new copy is in `app_en.arb` only. `app_localizations_ar.dart` falls back to English for the 17 new keys.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - phone-setup-progress, statesMissing "waiting on the person", "no internet named", "low storage": deferred to the SetupProgressView / KitChecklist owner (no owner in this wave). The rows live in `setup_progress_view.dart`, which is outside the write set.
  - phone-setup-progress, infoMissing "host label", "failure as a body sentence": deferred, same reason.
  - phone-setup-progress, actionsMissing "person-step actions inside the checklist", "report a problem with the log": deferred, same reason (the map proposes a KitActionStep part).
  - phone-setup-progress, verticals consistency-kit "back-only chrome": done. The bar is now `KitTopBar` titled "On this phone", like the start screen. Test: `test/phone_setup_progress_screen_test.dart` "restores on open and shows the title and note".
  - phone-setup-progress-stop-sheet, infoMissing "where to continue later": done ("Continue any time from On this phone."). Test: "Cancel confirms before stopping"; golden `phone_setup_progress_stop_sheet_*`.
  - termux-processes, statesMissing "Termux not answering / bridge failed": done (KitStateView.error with Try again; KitNotice.error once a list is shown). Test: "a list that cannot be read offers Try again"; golden `phone_termux_processes_error_*`.
  - termux-processes, statesMissing "a stop that did not take": done (a problem notice titled "Not everything stopped"). Test: "a stop that did not take is said as a problem".
  - termux-processes, statesMissing "in-app host", "phone hot, team paused by the thermal guard": deferred, no owner. Needs the `phone.any` capability and a thermal signal the screen does not have.
  - termux-processes, actionsMissing "copy command": done (row menu, details sheet). Test: "details say what the process is and copy its command".
  - termux-processes, actionsMissing "undo: none, and it should say so": done. Every stop confirm says "It can't be started again from here." (the AI Team stop instead says how to start the team again).
  - termux-processes, actionsMissing "stop leftover helpers automatically", "restart a group", "open the owning conversation or task", "sort": deferred, no owner. They need a policy switch, a restart verb and an owner link that `TermuxProcesses` does not have.
  - termux-processes, proposal "one row menu per process": done (Details, Copy command, Stop on every row, or Open On this phone and Copy command on a protected row).
  - termux-processes, verticals a11y "stop controls are unlabelled colour squares": done. The orphan's stop is a `KitIconButton` with the tooltip "Stop <name>", and Stop all is a labelled row.
  - termux-processes, verticals consistency-kit "ListTile, raw spinner": done (KitRow, KitSkeletonRows).
  - termux-processes, infoMissing "owner in plain words, memory vs RAM, CPU over 100 %, trend, battery/heat cost": deferred, no owner. The process data has none of them.
  - termux-processes-details-sheet, infoMissing "what it is in plain words, why it is safe to stop": done (one line per group). Test: "details say what the process is and copy its command".
  - termux-processes-details-sheet, actionsMissing "copy command": done. "Stopped snackbar": done as the in-place KitNotice on the list (§4.8; a snackbar is only for Undo).
  - termux-processes-details-sheet, "half-width destructive filled button": done. It is now a full-width "Stop Gradle daemon" whose confirm replaces the sheet in place.
  - termux-processes-stop-group-sheet, infoMissing "that stopping the AI Team stops its tasks", "how to start it again": done. Test: "stopping the AI Team says its tasks stop and how to restart"; golden `phone_termux_processes_stop_group_sheet_*`.
  - termux-processes-stop-one-sheet, rationale "one cancel word for stops ('Keep running')": done (kind stop, default cancel). Test: "an orphan asks before stopping and reports what remained".
- States per page (STATE-20):
  - phone-setup-progress: running → `setup_progress_running_*`, `phone_setup_progress_running_1280x800_*`; failed → `setup_progress_failed_*`; details open → `setup_progress_log_*`; interrupted, done → the unit's widget tests.
  - phone-setup-progress-stop-sheet: default → `phone_setup_progress_stop_sheet_*`.
  - termux-processes: loading → KitSkeletonRows (code); loaded → `phone_termux_processes_loaded_*` (phone and 1280x800); empty → `phone_termux_processes_empty_*`; error → `phone_termux_processes_error_*`; busy → KitScreen loading bar (code).
  - termux-processes-details-sheet: stoppable → `phone_termux_processes_details_sheet_*`.
  - termux-processes-stop-group-sheet: default → `phone_termux_processes_stop_group_sheet_*`.
  - termux-processes-stop-one-sheet: default → the widget tests (the same confirm as the group sheet).
- Deferred states (STATE-21): termux-processes "in-app host" (needs `phone.any`, no owner); "thermal pause" (needs a thermal signal, no owner); phone-setup-progress person-step states (need KitActionStep in SetupProgressView, no owner).

## 2. Builds

- Branch `revamp/screen-phone-2`, base `2cec35ca` (feat/phone-setup-v2), code head `66f6ed58`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2b checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/termux_processes_test.dart` | passes | 18 passed (5 new) | PASS |
| 2 | `test/phone_setup_progress_screen_test.dart` | passes | 25 passed | PASS |
| 3 | `test/revamp/screen_phone_2_golden_test.dart` | renders, no exceptions | 16 rendered and looked at | PASS |
| 4 | `test/goldens/phone_setup_golden_test.dart --plain-name setup_progress_` | re-render my page | 6 re-rendered and looked at | PASS |
| 5 | `KIT_RATCHET_WRITE=1 test/kit_ratchet_test.dart`, then the baseline restored | no entry for the three files | 0 entries in G1, G2, G7, G15, G16, G17, G21 | PASS |
| 6 | `test/kit_ratchet_test.dart` | my files pass | G1 and G16 pass. G17 fails on `lib/ui/widgets/quota_monitor_section.dart` and G21 on kit files (`kit_choice_list`, `kit_task_card`, ...). Neither is this unit's; both fail the same way on the base | PASS (for this unit) |
| 7 | `flutter analyze` on the changed files, tests and `lib/l10n` | no issues | No issues found | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-1 / G16 | `test/kit_ratchet_test.dart` write mode | step 5 |
  | kit-v2 §4.2 cancel word | `test/termux_processes_test.dart` "an orphan asks before stopping and reports what remained" | step 1 |
  | kit-v2 §4.7 | `test/termux_processes_test.dart` "a group stop is two-step and a plain row confirms in its sheet" | step 1 |
  | kit-v2 §4.8 | `test/termux_processes_test.dart` "a stop that did not take is said as a problem" | step 1 |
  | STATE-12 / error | `test/termux_processes_test.dart` "a list that cannot be read offers Try again" | step 1 |

- Changed test expectations (TEST-19):
  - `test/termux_processes_test.dart`: two taps on "Keep" became "Keep running" (kit-v2 §4.2, one cancel word for stops; map termux-processes-stop-one-sheet).
  - `test/phone_setup_progress_screen_test.dart`: expectations were added, none changed.
- Goldens changed (each opened and looked at):
  - `test/goldens/setup_progress_{running,failed,log}_{dark,light}.png`: new KitTopBar "On this phone" with Back, and the base's visual-language drift. The whole `phone_setup_golden_test.dart` was already failing on the base (for example phone_card_* and setup_welcome_entry_*, which this unit does not touch). Approved render: none for this page. Differences: n/a.
  - `test/revamp/goldens/phone_setup_progress_running_1280x800_{dark,light}.png`, `phone_setup_progress_stop_sheet_{dark,light}.png`: new. Approved render `docs/design/visual-language-2026-09-26/Confirm.png`. Differences: the sheet is "Stop setup?" with one info line rather than two marked consequences, and the cancel reads "Keep going" (kept copy, map proposal "keep").
  - `test/revamp/goldens/phone_termux_processes_{loaded,loaded_1280x800,empty,error,details_sheet,stop_group_sheet}_{dark,light}.png`: new. Approved render `docs/design/visual-language-2026-09-26/Settings.png` for the grouped panels and `Confirm.png` for the stop sheet. Differences: a group's hint sits under its panel as secondary text, and Stop all is the panel's last row in the danger tone. Otherwise none.
- Before and after: `before-phone-setup-progress-running.png` (base `test/goldens/setup_progress_running_dark.png`) / `after-phone-setup-progress-running.png`; `before-phone-setup-progress-stop-sheet.png` / `after-phone-setup-progress-stop-sheet.png`; `before-termux-processes-loaded.png` / `after-termux-processes-loaded.png`; `before-termux-processes-empty.png` / `after-termux-processes-empty.png`; `before-termux-processes-details-sheet-stoppable.png` / `after-termux-processes-details-sheet-stoppable.png`; `before-termux-processes-stop-group-sheet.png` / `after-termux-processes-stop-group-sheet.png`. All before images are from the base census `docs/qa/screen-census/h-termux/` except the first. `after-termux-processes-error.png` has no before render (a new state).
- Accessibility: the orphan stop is a `KitIconButton` whose tooltip and label are "Stop <name>". Stop all is a labelled row. Every row has a menu (long-press, right-click, Shift+F10) that doubles as semantic custom actions. Disabled stops carry "Stopping…" as their reason. The 320 dp at 2.5x text tests pass (the RTL variant is kept from the base; Arabic review was dropped by the owner). The Back button on setup progress has the tooltip "Back".
- Privacy and security: no credentials, stored data, links or notifications changed. Copy command copies the process command line, which the screen already showed. `KitDetailsFold` redacts values before showing or copying them.
- Migration: n/a, no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/termux_processes_test.dart test/phone_setup_progress_screen_test.dart
$F test -j 1 test/revamp/screen_phone_2_golden_test.dart
$F test -j 1 --plain-name setup_progress_ test/goldens/phone_setup_golden_test.dart
KIT_RATCHET_WRITE=1 $F test -j 1 test/kit_ratchet_test.dart   # then: git checkout test/kit_ratchet_baseline.json
$F analyze lib/ui/screens/termux_processes_screen.dart lib/ui/screens/phone_setup/ test/termux_processes_test.dart test/phone_setup_progress_screen_test.dart test/revamp/screen_phone_2_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator. The census re-render of h-termux is coordinator work.
- The start, customize and ready goldens in `test/goldens/phone_setup_golden_test.dart` were not re-rendered. They fail on the base already, and the hero's new type roles also change them. The integrator re-renders them.
- The full suite was not run (owner decision 2026-09-27). Tests that use the hero or these screens indirectly were not run: `test/motion_setup_test.dart`, `test/design_standard_setup_test.dart`, `test/phone_setup_start_screen_test.dart`, `test/phone_setup_welcome_entry_test.dart`, `test/launch_shortcut_routing_test.dart`, `test/phone_setup_notification_route_test.dart`.
- `termux_processes_screen.dart` is not yet in `_migrated` in `test/design_standard_test.dart` (R10, integrator-owned).
- No Arabic copy for the 17 new keys (owner decision).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-phone-2` |
| Enabled | Yes | the default app path (no flag) |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `66f6ed58` |
| Deployed | No | |
| Released | No | |
