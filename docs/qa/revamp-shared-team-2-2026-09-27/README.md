# revamp-shared-team-2: Revamp team (3 files) (2026-09-27)

## 1. Scope

- Unit: `shared-team-2` (wave 2a, screen-revamp). Finish line: every file in the write set has a G1, G16, G7 and look-pattern (G2, G17, G21) count of zero, and each page is handled by its map proposal. Non-goal: no gateway call, controller field or persistence is added; call sites in other units' files (run_screen, agent_screen, work_sheet, gate_sheet, plugins_screen) are not touched.
- Files changed: `lib/ui/widgets/team_technical_details.dart`, `lib/ui/widgets/team_task_row.dart`, `lib/ui/widgets/team_moments.dart`, `test/team_card_test.dart`, `test/revamp/shared_team_2_test.dart` (new), `test/revamp/goldens/*` (new, 4), `docs/design/ui-ledger/parts/i2-team-sheets.json` (the two pages' entries).
- Pages (map ids): `team-host-details-sheet` (proposal keep), `embedded-team-technical-value` (proposal fix).
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-22, KIT-23, KIT-27, KIT-32, KIT-33, LOOK-2, LOOK-6, LOOK-12, LOOK-14, LOOK-15, LOOK-21, LOOK-25, LAY-8, TEST-5, TEST-20; kit-api KitDetailsFold.md (C37: TeamTechnicalValue over KitTechnicalValue); visual-language §5 (sheet: icon tile, start-aligned title, inset panels).
- Contract problems (PROC-20):
  - KIT-33 says the technical fold is "placed last and collapsed". The host sheet *is* the Technical details place, opened by the info button for exactly these values; a collapsed "Raw values" fold inside a sheet titled "Technical details" would only add a tap. The fold is last and starts open (`initiallyExpanded: true`). Proposed text: "collapsed, except on a sheet whose only job is technical details". Blocks nothing.
  - `KitRowValue` (lib/ui/kit/kit_row.dart) puts a `Flexible` inside a `Row(mainAxisSize: min)`; as `KitRow.trailing` it gets unbounded width and throws. Not used here (the facts are the rows' supporting lines); reported for the kit owner.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - team-host-details-sheet: actionsMissing none; statesMissing none; couldBeAutomatic "no"; consistency "duplicates" → done: each value once in one fold, `test/revamp/shared_team_2_test.dart` "each raw value shows once, in one open fold".
  - embedded-team-technical-value: actionsMissing none; statesMissing none; element "copy IconButton off the rail", a11y "small copy target" → done: 48 dp `KitIconButton.copy` at the row's end, `shared_team_2_test.dart` "a 48 dp copy target on the rail"; "promote to the kit as the details fold's row" → done as far as C37 allows: `TeamTechnicalValue.asKit` hands the value to `KitDetailsFold`; the host sheet uses the fold; the 44 standalone calls in other units' files stay on the wrapper (their units move them into folds).
- States per page (STATE-20): team-host-details-sheet: open (read-only and controls variants) → goldens + `team_card_test` disclaimer group; embedded-team-technical-value: value, empty value → `shared_team_2_test.dart`.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/shared-team-2`, base `64128dba` (feat/phone-setup-v2), code head `e2e8e4c3`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2a checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first | n/a: rebuild, no behaviour fix | n/a | PASS |
| 2 | `test/revamp/shared_team_2_test.dart` | passes | 9 passed | PASS |
| 3 | `test/team_card_test.dart --plain-name 'disclaimer per host kind'` | passes | 6 passed | PASS |
| 4 | `test/team_motion_test.dart` | passes | 13 passed | PASS |
| 5 | `test/kit_ratchet_test.dart` (committed baseline) | passes | 33 passed | PASS |
| 6 | `KIT_RATCHET_WRITE=1` ratchet run, then `git checkout` of the baseline | no entry for the three files in any gate | 0 entries (G1, G2, G7, G16, G17, G21) | PASS |
| 7 | `flutter analyze` on the three files, the new/changed tests and every caller (`lib/ui/screens/team`, `plugins_screen.dart`, `team_now.dart`, `workspace_screen.dart`) | no issues | No issues found | PASS |

Not run (owner decision 2026-09-27, speed): the whole suite, `team_home_test`, `team_home_layout_test`, `team_home_stable_layout_test`, `team_discover_test`, `test/goldens/team_golden_test.dart`, design-standard, l10n and ledger tests.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-2 | `test/kit_ratchet_test.dart` G1 (no showModalBottomSheet/SnackBar left) | run 5, 6 |
  | KIT-1 | `test/kit_ratchet_test.dart` G16 | run 5, 6 |
  | KIT-23 | `shared_team_2_test.dart` "copying a value puts it on the clipboard and shows no snackbar" | run 2 |
  | KIT-22, A11Y target | `shared_team_2_test.dart` "a 48 dp copy target on the rail copies it" | run 2 |
  | KIT-33 | `shared_team_2_test.dart` "each raw value shows once, in one open fold" | run 2 |

- Changed test expectations (TEST-19): `test/team_card_test.dart` disclaimer lookup: `tester.widget<Text>(line).data` → `tester.widget<KitText>(line).text` (the line is a KitText now; LOOK-12, KIT-1). Same words expected.
- Goldens added (each opened and looked at):
  - `test/revamp/goldens/team_host_details_sheet_open_dark.png`, `_light.png`: phone bottom sheet: icon tile, title, subtitle, close; host/access panel; Terms glossary panel; Raw values fold open with copy buttons.
  - `test/revamp/goldens/team_host_details_sheet_open_1280x800_dark.png`, `_light.png`: the same as the centred panel; fold values in the label column layout.
  - Approved VL canvas render for these pages: none found (EVID-12).
- Before and after: `before-team-host-details-sheet-open.png` (census `docs/qa/screen-census/i2-team-sheets/team-host-details-sheet.png` at base), `after-team-host-details-sheet-open.png` (golden, dark 412x915); `before-embedded-team-technical-value-value.png` (census), no standalone after render (covered by the fold rows in the sheet golden).
- Other goldens that may shift (integrator-owned, not re-rendered, R07): `test/goldens/team_home_loaded_*` and `team_run_overview_*` use `TeamNeedsYouLabel`; the nudge keeps the same box and offset, so no change is expected. Work-tab renders with a team task lose the small team badge over the task mark (the "Team" word in text1 still leads the line).
- Accessibility: the Needs you label gains header semantics; each fold value reads "label: value" as one node; copy targets are 48 dp with "Copy <label>" tooltips; the host facts no longer wrap in a `Wrap` of two texts but in row title/supporting/below lines that wrap at large text.
- Privacy and security: values and the last error are shown and copied through `KitRedact` (SEC-2); the host's error text goes to the fold's masked `text`, not a value, so a quoted header is masked, not asserted.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/shared_team_2_test.dart test/team_motion_test.dart
$F test -j 1 --plain-name 'disclaimer per host kind' test/team_card_test.dart
$F test -j 1 test/kit_ratchet_test.dart
$F analyze lib/ui/widgets/team_technical_details.dart lib/ui/widgets/team_task_row.dart lib/ui/widgets/team_moments.dart test/revamp/shared_team_2_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- The full suite and the other team tests listed under Runs were not run (owner decision 2026-09-27); `team_home_test` and `team_home_layout_test` expect texts inside `team-home-host-sheet` that the new sheet still shows (title, 1.4.1, bright, polecat, read-only line), but that was not executed.
- The three files are not added to `_migrated` in `test/design_standard_test.dart` (shared, R10); the integrator adds them.
- 200 % text and the 360x800, 915x412, 800x1280 sizes were not rendered.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/shared-team-2` |
| Enabled | Yes (no flag) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `e2e8e4c3` |
| Deployed | No | |
| Released | No | |
