# revamp-shared-phone-1: Revamp phone (6 files) (2026-09-27)

## 1. Scope

- Unit: `shared-phone-1` (wave 2a, screen revamp, tier 1). Finish line: every file in the write set has a G1, G2, G7, G16, G17 and G21 count of zero, "This phone" has its own "Disconnect from This phone", and each page is handled by its map proposal in the VL look. Non-goal: no gateway call, controller field or persistence added; nothing outside the write set changed (the server switcher keeps its own Disconnect row until its owner wires the card's; see "Not changed, noted").
- Files changed: `lib/ui/widgets/local_server_row.dart`, `lib/ui/widgets/managed_server_recovery_option.dart`, `lib/ui/widgets/phone_server_card.dart`, `lib/ui/widgets/phone_server_restart.dart`, `lib/ui/widgets/setup_terminal.dart`, `lib/ui/widgets/team_phone_section.dart`; `lib/l10n/app_en.arb` (19 keys) and the generated `app_localizations*.dart`; tests `test/revamp/shared_phone_1_test.dart`, `test/revamp/shared_phone_1_golden_test.dart`, `test/revamp/shared_phone_1_fixtures.dart`, 24 goldens `test/revamp/goldens/{phone_server_card_states,setup_terminal_states,team_phone_section_states,team_phone_stop_sheet,team_phone_remove_sheet,team_phone_tips_sheet}_*`; expectations in the unit's own test files `test/e7_setup_layout_test.dart`, `test/design_standard_setup_test.dart`, `test/team_phone_onboarding_test.dart`.
- Pages (map ids): `embedded-setup-terminal` (fix), `embedded-team-phone-section` (merge-into:team-home), `team-phone-stop-sheet` (fix), `team-phone-remove-sheet` (fix), `team-phone-tips-sheet` (merge-into:keep-running), `embedded-team-phone-reoffer-card` (remove). Also the unit's acceptance item for PhoneServerCard (no page id of its own).
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-8, KIT-11, KIT-15, KIT-16, KIT-23, KIT-27, KIT-28 (partly, see below), KIT-31, KIT-32, KIT-34, KIT-43, LOOK-1, LOOK-2, LOOK-5, LOOK-12, LOOK-21, LOOK-37, LAY-8, MAP-1, STATE-8, STATE-9, DATA-11; kit-v2 §9.1; visual language §5.
- Contract problems (PROC-20):
  1. The task text asks for `app_ar.arb` entries and STANDARDS §1.1 "Copy" does too; the later owner decision (2026-09-27) drops Arabic. English only was written; `app_localizations_ar.dart` is regenerated output (falls back to English).
  2. The task names the record folder `docs/qa/revamp-shared-phone-1/`; EVID-1 names it with the date. The EVID-1 form was used.
  3. `team-phone-tips-sheet` is `merge-into:keep-running`, but no unit or slice in `work-units.json` owns that merge (only `screen-system-1` revamps `keep-running` itself). The marker reads `// revamp: merge-into:keep-running (no owning slice yet)`; G30 should flag it for the coordinator.
- New kit parts (KIT-3): none.
- Moved or removed items (owner rule 2026-09-27, rethink):
  - "Disconnect" for the phone server moves onto the thing it acts on: `PhoneServerCard.onDisconnect` puts "Disconnect from This phone" in the card's own menu. The switcher's stray last row (`server-switcher-disconnect` when the phone card is current) can now go; that file is outside this write set (see "Not changed, noted").
  - Every act names what it acts on: "Start"/"Stop"/"Open" on the card become "Start OpenCode", "Stop OpenCode", "Connect to This phone"; "Terminal" becomes "Open terminal"; "Show log" becomes "Show server log"; the remove confirm "Remove" becomes "Remove OpenCode". On the team section "Stop"/"Start"/"Start again"/"Delete from this phone" become "Stop the team", "Start the team", "Start the team again", "Delete the team from this phone"; the stop confirm is "Stop the team" and the delete confirm "Delete the team" (map).
  - Removed: the status dot (the row's mark and state word carry it), the setup log's uppercase "LIVE OUTPUT/LAST OUTPUT" header with its waveform icon (the panel's own live/ended words replace it), the "Waiting…" detail line, the team section's waking drawing inside the status line (LOOK-37: no drawing in a row; the working mark stays), success toasts ("OpenCode was removed", "The AI team was deleted", "Commands copied": the result is on screen or KitCopy announces it, KIT-34).
  - Delete the team is the last row of the section's panel, apart (KitRow.destructive), not a red text button in the middle.
- Map items (EVID-11):
  - embedded-setup-terminal: actionsMissing "expand/collapse" → done in part: the panel's Wrap toggle and the host's `expand` (fill); folding it under Details is the host's placement (termux setup, storage, builtin server, local agent, team onboarding screens) → deferred to those screens' units (no owner named in wave 2a); "jump to end" → done: KitLogPanel follows the newest line and shows the jump pill, End key jumps (kit tests); "send with a bug report" → done in part: a host's report copy ("Copy failure report") is a named button under the panel (`shared_phone_1_test.dart` "a host report copy is its own named button"); sending a report → no owner. Rationale fixes: sentence case title, no wrap on medium+, accent only for… (no accent at all now; error and warning glyphs) → done: golden `setup_terminal_states_*`.
  - embedded-team-phone-section (merge-into:team-home, slice-P3.4): actionsMissing "auto-restart toggle" → deferred to slice-P3.4; infoMissing "memory and battery use now" → deferred to slice-P3.4; couldBeAutomatic "heat guard/idle policy stops and resumes it", "restart automatically after an Android kill", "section polls every 2 s already" → deferred to slice-P3.4 (the section still polls while busy, unchanged).
  - team-phone-stop-sheet (fix): "use the one stop tone" → done: `showKitConfirm(kind: stop)`, `shared_phone_1_test.dart` "running: Stop the team asks the one stop question", golden `team_phone_stop_sheet_*`; couldBeAutomatic "heat guard pauses; idle team could sleep itself" → deferred to slice-P3.4.
  - team-phone-remove-sheet (fix): infoMissing "space freed" → done: "Frees about {size} MB" from the manifest's declared download size, shown only when declared; "say what is removed in plain words", button "Delete the team" → done: consequences lost/kept/info, `shared_phone_1_test.dart` "delete: what goes, what stays, the space, then deletes", golden `team_phone_remove_sheet_*`.
  - team-phone-tips-sheet (merge-into:keep-running, no owning slice): actionsMissing "request the battery exemption directly", infoMissing "which ones are already done", couldBeAutomatic "request the battery exemption in-app; detect what's done" → deferred, no owner (the merge target has no slice). Made kit-only: KitSheet, KitNotice tips, KitCodeBlock (command) with its own Copy commands.
  - embedded-team-phone-reoffer-card (remove, slice-P3.4): made kit-only with the least change (one KitNotice.offer); marker `// revamp: remove (slice-P3.4)`.
- States per page (STATE-20):
  - embedded-setup-terminal: empty/waiting (running), live, ended, with a host report → test + golden `setup_terminal_states_*`.
  - embedded-team-phone-section: running, stopped by Android, stopped, not installed (offers Open phone setup), not available (explains), failed (KitNotice with the reason) → tests; running and killed → golden `team_phone_section_states_*`.
  - team-phone-stop-sheet, team-phone-remove-sheet, team-phone-tips-sheet: open → goldens and tests.
  - PhoneServerCard: running in use (Disconnect in menu), running, stopped → golden `phone_server_card_states_*`; remove, log, start, connect → tests.
- Deferred states (STATE-21): none beyond the map items above.

## 2. Builds

- Branch `revamp/shared-phone-1`, base `b24addac`, code head `a840e233`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first | n/a: new behaviour, no fix of a defect | n/a | PASS |
| 2 | `test/revamp/shared_phone_1_test.dart` | passes | 19 passed (two cases fixed in place first: the delete case needed `runAsync` for the orchestration sweep, the copy case needed `ensureVisible`) | PASS |
| 3 | `test/revamp/shared_phone_1_golden_test.dart --update-goldens`, then images opened | 24 renders, no exception | 24 passed; phone and wide, dark and light looked at | PASS |
| 4 | `KIT_RATCHET_WRITE=1 test/kit_ratchet_test.dart`, then the baseline restored | no entry left for the six files | 0 entries on G1, G2, G7, G15x, G16, G17, G21 for all six files | PASS |
| 5 | `flutter analyze lib test` | no issues in changed paths | 2 warnings in `lib/ui/screens/settings_screen.dart` (unused import, unused `_Chevron`) and 5 infos in other units' tests, all pre-existing; none in changed paths | PASS |
| 6 | `test/e7_setup_layout_test.dart`, `test/design_standard_setup_test.dart`, `test/team_phone_onboarding_test.dart` (expectations updated) | pass | not run (owner decision 2026-09-27: only the unit's own new files) | n/a |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-2, KIT-11, DATA-11 | `shared_phone_1_test.dart` "Remove asks first, names OpenCode, then removes", "running: Stop the team asks the one stop question", "delete: what goes, what stays, the space, then deletes" | run 2 |
  | KIT-34 | same tests: `find.byType(SnackBar)` finds nothing | run 2 |
  | KIT-31, KIT-32, LAY-8 | `shared_phone_1_test.dart` "one log panel: control bytes gone, left to right", "the server log opens in the one log view" | run 2 |
  | KIT-23 | `shared_phone_1_test.dart` "Keep it running: the tips and the commands, copyable" (copies the exact commands through KitCopy) | run 2 |
  | LOOK-5 | `shared_phone_1_test.dart` "a failure is words in text1; long-press opens its menu" | run 2 |
  | KIT-28 (row menu) | same test: long-press opens the row's items | run 2 |
  | Acceptance: own Disconnect | `shared_phone_1_test.dart` "in use: its menu disconnects from it by name", "not in use, or no host to leave through: no Disconnect" | run 2 |
  | KIT-1, LOOK-1, LOOK-2, LOOK-12 | kit ratchet counts | run 4 |

- Changed test expectations (TEST-19):
  - `test/e7_setup_layout_test.dart` output page: `SelectableText.textDirection == ltr` → the Directionality around a log line is ltr (the output is a KitLogPanel now; map: embedded-setup-terminal fix).
  - `test/design_standard_setup_test.dart` "This phone: Start shows Starting": `widget<Text>(phone-server-status).data` → `find.text('Starting')` under that key (the state word is a KitText).
  - `test/team_phone_onboarding_test.dart`: versions line matched with `textContaining` (now isolated left to right); tips commands and live output checked through the Directionality around their text instead of a `SelectableText` (KitCodeBlock, KitLogPanel); remove body `teamUiPhoneRemoveBody` → `teamPhoneRemoveBody` (map: team-phone-remove-sheet fix).
- Goldens changed (each opened and looked at; new files, none replaced):
  - `phone_server_card_states_*`: rows on surface1 panels, current mark and "Connected ·", state word at the end, ⋮, one primary; approved render `docs/design/visual-language-2026-09-26/Main.png` (rows) and `Settings.png` (panels): same panel radius, icon tile and hairlines. Differences: the tertiary actions sit on the panel under a hairline, which the canvas has no example of.
  - `team_phone_section_states_*`: one panel with the state row, Keep it running and Delete last; approved render `Settings.png`: same panel, label and rows. Difference: the status row leads with a status mark, not an icon tile, so its words sit 2 dp off the tile rows' words.
  - `team_phone_stop_sheet_*`, `team_phone_remove_sheet_*`, `team_phone_tips_sheet_*`: approved render `docs/design/visual-language-2026-09-26/Confirm.png`: same grabber, icon tile, start-aligned title, consequences panel, stacked full-width buttons on the phone and an end-aligned row on the wide window. Differences: none seen.
  - `setup_terminal_states_*`: no approved render for logs. Seen: in light the panel's details surface is close to the ground, so the log reads without a box (kit/theme concern, not changed here); the host report button sits under the folded panel's fixed height.
- Before and after (EVID-10): `before-embedded-setup-terminal-last-output.png` → `after-embedded-setup-terminal-states.png`; `before-embedded-team-phone-section-running.png` and `before-embedded-team-phone-reoffer-card-offer.png` → `after-embedded-team-phone-section-states.png`; `before-team-phone-stop-sheet-confirm.png` → `after-team-phone-stop-sheet-confirm.png`; `before-team-phone-remove-sheet-confirm.png` → `after-team-phone-remove-sheet-confirm.png`; `before-team-phone-tips-sheet-open.png` → `after-team-phone-tips-sheet-open.png`; PhoneServerCard: no before render (no census page) → `after-phone-server-card-states.png`. Befores are the base's `docs/qa/screen-census/` PNGs.
- Accessibility: the card's row is `selected` in semantics when in use and says "Connected" in words; its menu is a named ⋮ (label "More", menu named after the server) that tap, long-press, right-click and the keys open, and its items are the row's semantic actions; state words are live regions; the log panel's state words are its one polite live region and the body is not; icon-only controls are KitIconButtons with labels; large text moves the state word under the name (the switcher's 320 dp 2.5x check lives in `server_switcher_test.dart`, not run).
- Privacy and security: the server log and setup output are redacted by KitLogPanel before they are shown or copied (SEC-2); the plain "Copy all" copies the redacted lines, where the old header copied the raw output through each host's callback (a host's own report copy still copies what the host builds). No links, storage keys, credentials or notifications changed.
- Migration: n/a: no stored format changed.
- Shared tests expected to break (for the integrator; not run, owner decision 2026-09-27):
  - `test/phone_server_card_test.dart`: reads `widget<Text>(phone-server-status)` (now KitText), the connected detail now starts with "Connected · ", labels changed ("Start OpenCode", "Open terminal", "Remove OpenCode", "Connect to This phone"), removal no longer shows a snack bar, the log sheet is a KitLogPanel (was TerminalView), `phone-server-dot` is gone.
  - `test/termux_setup_screen_test.dart` lines ~1306 and ~1434: look for the text "LIVE OUTPUT" (the panel is titled "Setup output" and says "Live").
  - Goldens rendering these parts: `test/goldens/phone_setup_golden_test.dart` (phone_card_* scenes), `test/goldens/phone_server_screens_golden_test.dart` (recovery option notes, phone rows), `test/goldens/team_discover_golden_test.dart` (if it shows the plugins sheet), and `tool/capture/*` renders of setup, plugins and phone server screens. Not regenerated (not this unit's goldens).
- Not changed, noted:
  - `lib/ui/widgets/server_switcher_sheet.dart` (outside this write set) should pass `onDisconnect: () => unawaited(leave())` to its `phoneCard(current)` and delete the `if (currentIsPhone) KitRow(key: 'server-switcher-disconnect', …)` row; `test/server_switcher_test.dart` and `test/safety_confirms_test.dart` then find Disconnect under the card's menu (`phone-server-menu` → `phone-server-disconnect`). The Servers screen can pass the same for the current phone server.
  - `LocalServerRow` keeps its visible ⋮ as well as the new long-press menu: its tap is taken by its one likely act (connect, start, details), so Restart and Stop would otherwise be long-press only. KIT-28 asks for no per-row ⋮; the owner or coordinator decides.
  - `SetupTerminal.controller` is kept (KIT-43) but no longer read.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/shared_phone_1_test.dart
$F test -j 1 test/revamp/shared_phone_1_golden_test.dart
KIT_RATCHET_WRITE=1 $F test -j 1 test/kit_ratchet_test.dart && git diff test/kit_ratchet_baseline.json; git checkout test/kit_ratchet_baseline.json
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- The unit's other test files (`test/e7_setup_layout_test.dart`, `test/design_standard_setup_test.dart`, `test/team_phone_onboarding_test.dart`, `test/motion_setup_test.dart`) were edited or left as they were but not run; the design-standard, l10n, glossary and ledger tests were not run.
- The switcher still shows its own Disconnect row for the phone card until its owner wires `onDisconnect`.
- `phoneServerRestartFor`'s failure alert has no test of its own (it needs a live starter or Termux bridge).
- Start OpenCode and the log's re-read run against a fake BuiltinLinux only.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Partial: the switcher's use of the card's Disconnect is outside this write set | `revamp/shared-phone-1` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `a840e233` |
| Deployed | No | |
| Released | No | |
