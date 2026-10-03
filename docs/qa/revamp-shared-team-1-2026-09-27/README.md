# revamp-shared-team-1: Revamp team (7 files) (2026-09-27)

## 1. Scope

- Unit: `shared-team-1` (wave 2a, screen-revamp). Finish line: every file in the write set has a G16 count of zero, each page is handled by its map proposal (MAP-1) with the wave-2 missing actions and states, and the look is VL. Non-goal: no gateway call, controller field or persistence added; the redesign pages keep today's structure.
- Files changed: `lib/ui/widgets/{builtin_team_section,team_agent_row,team_board_move_sheet,team_controls,team_cycle_strip,team_host_form,team_now}.dart`, `lib/l10n/app_en.arb` (+ generated `app_localizations*.dart`), `test/team_cycle_test.dart`, `test/team_plugins_layout_test.dart`, new `test/revamp/shared_team_1_test.dart`, `test/revamp/shared_team_1_golden_test.dart`, `test/revamp/goldens/team_*.png` (26 new).
- Pages (map ids): embedded-team-cycle-strip, team-board-add-sheet, team-board-cancel-confirm-sheet, team-board-move-sheet, team-board-priority-sheet, team-cycle-how-sheet, team-cycle-stop-confirm-sheet, team-host-guide-sheet, team-host-sheet, team-turn-off-sheet.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-11, KIT-16, KIT-20, KIT-22, KIT-26, KIT-28, KIT-33, KIT-34, KIT-37, KIT-43, LOOK-1, LOOK-2, LOOK-4, LOOK-5, LOOK-12, LOOK-19, LOOK-21, LAY-7, LAY-8, MAP-1, DATA-11, STATE-8; kit-v2 §9.1; visual-language §5 (sheets, rows, buttons).
- Contract problems (PROC-20):
  1. Acceptance "TeamTechnicalValue becomes a wrapper over KitTechnicalValue": `TeamTechnicalValue` lives in `lib/ui/widgets/team_technical_details.dart`, which is shared-team-2's write set (KitDetailsFold.md line 37 also assigns it there). Not touched here; shared-team-2 already merged its rebuild.
  2. Acceptance says "@Deprecated wrappers"; STANDARDS KIT-43 forbids `@Deprecated`. Followed KIT-43: `TeamReceiptChip` and `TeamComposerField` are forwarding wrappers marked `/// Retired by shared-team-1: use …`.
  3. Task text says new copy goes to `app_en.arb` and `app_ar.arb`; the later owner decision (2026-09-27, Arabic dropped) wins: `app_en.arb` only.
  4. The task's record path is `docs/qa/revamp-<unit id>/`; EVID-1 asks for the dated folder, used here.
  5. `showKitSheet` fixes its pinned actions when it opens, so a sheet whose actions change with its state (the host form: Test and turn on → working + Cancel test → Save without an answer) puts its `KitActionBlock` in the body. Opened over the plugins' legacy team sheet at 320 dp and 2.5x text, the kit sheet's body then ends below the window edge (rect 808–932 in an 844 px window), so the primary cannot be hit there; the same form opened from a plain screen fits (724–824). Proposed: `showKitSheet` takes a `ValueListenable<KitActionBlock>` (or `primary`/`secondary` listenables) so changing actions stay pinned (KIT-17). Not a blocker.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - team-host-sheet (fix): actionsMissing "Save anyway" → done: `shared_team_1_test.dart` "no answer: the reason, the raw error under Details, and Save without an answer", golden `team_host_sheet_unanswered_*`; "Cancel test" → done: "testing is progress with Cancel test; a late answer is dropped", golden `team_host_sheet_testing_*`; statesMissing "cancel while testing" → done (same test). Rationale items: progress as progress (working primary, fields stay editable and an edit cancels the test), raw error under Details (KitDetailsFold, test above), drop the kind question (test "no kind of computer; the city is the team name"), rename City → "Team name (optional)".
  - team-board-add-sheet (merge-into:start-run-sheet): "draft kept on dismiss", "start now instead of backlog" → deferred to slice-P3.5 (the one "Give the team a task" sheet); marked `// revamp: merge-into:start-run-sheet (slice-P3.5)`. Least change: kit sheet + KitField; an empty submit now says what is missing (golden `team_board_add_sheet_*`).
  - team-board-cancel-confirm-sheet (keep): "Undo snackbar (Reopen exists)" → deferred to screen-team-2 (team board); the confirm stays (kit-only, no behaviour change).
  - team-turn-off-sheet (keep): "turn back on" → deferred to slice-P3.4 (team page on/off); kit-only.
  - team-host-guide-sheet (redesign): "Enter the address", "Open the full guide (openExternalLink)", infoMissing "copyable commands" → deferred to slice-P3.4; marked `// revamp: redesign (slice-P3.4)`; kit-only rebuild of today's steps.
  - embedded-team-cycle-strip (redesign): statesMissing "blocked shown as a stage", infoMissing "the 4 outcome stages" → deferred to slice-P5.1 (Now line replaces the strip); kit-only rebuild.
  - team-cycle-how-sheet (merge-into:team-conversation): none missing; marked `// revamp: merge-into:team-conversation (slice-P5.1)`.
  - team-cycle-stop-confirm-sheet (merge-into:team-agent-stop-confirm-sheet): infoMissing "which agent" → done: the title names the agent in words ("Stop Worker · furiosa?") via `teamAgentTitle`, `test/team_cycle_test.dart` "providerLimit from the probed transcript…"; marked `// revamp: merge-into:team-agent-stop-confirm-sheet (screen-team-1)`.
  - team-board-move-sheet, team-board-priority-sheet (keep): none missing; kit-only.
- States per page (STATE-20): host sheet idle / testing / no answer / not a team host → goldens `team_host_sheet{,_testing,_unanswered}_*`, tests; move sheet with moves / read-only → goldens `team_board_move_sheet{,_read_only}_*`; add sheet error → golden `team_board_add_sheet_*`; strip working / reduced motion / merged / stalled → `test/team_cycle_test.dart`.
- Deferred states (STATE-21): none beyond the map items above.
- Moved or removed (owner rule "rethink"): the host sheet's "kind of computer" chips (removed; the kind now comes from the caller or the host); the host verdict's bare "How" became "How to set up the computer"; the strip's "Stop" became "Stop agent"; the Now line's wake SnackBar removed (waking is harmless per DATA-11; a refusal opens the kit technical-details sheet); the builtin section's Stop moved to the quiet tertiary slot after Start/Turn on.

## 2. Builds

- Branch `revamp/shared-team-1`, base `b24addac`, code head `a0dc9aed`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2a checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/shared_team_1_test.dart` | passes | 13 passed | PASS |
| 2 | `test/revamp/shared_team_1_golden_test.dart --update-goldens`, then every image opened | renders, no exceptions | 26 passed; looked at all ten sheets | PASS |
| 3 | `test/team_cycle_test.dart` | passes | passed (with builtin section: 35 passed, 1 failed, row 4) | PASS |
| 4 | `test/builtin_team_section_test.dart` | passes | 1 failure in the pure `test()` "turn-on waits for the store prepare is making…" (BuiltinTeam script order; no widget, untouched code) | FAIL (unrelated) |
| 5 | `test/team_control_test.dart`, `test/builtin_team_bring_in_test.dart` | pass | 49 passed | PASS |
| 6 | `test/team_run_screen_test.dart` | passes | 23 passed | PASS |
| 7 | `test/team_now_test.dart`, `test/team_plugins_layout_test.dart` | pass | now test passed; layout: form and guide pass, "plugins editor" ×2 fail in `test/support/first_run_path.dart` `openFirstRunConnect` (no element; before any team code) | FAIL (unrelated) |
| 8 | Ratchet counts for the seven files (`KIT_RATCHET_WRITE=1` run, baseline restored after) | G1, G2, G7, G16, G17, G21, G48 all 0 | all 0 | PASS |
| 9 | `test/kit_ratchet_test.dart` | no row for this unit's files | fails only on other files' new rows (quota_monitor_section, kit_choice_list, kit_task_card, …: baseline lag) | PASS for this unit |
| 10 | `test/l10n_coverage_test.dart` (team_now.dart green) | passes | passed | PASS |
| 11 | `flutter analyze lib test` | no new issues in changed paths | 8 pre-existing issues elsewhere, none in changed paths | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test or golden | Output |
  |---|---|---|
  | KIT-43 wrapper | `shared_team_1_test.dart` "names the control in every state", "unconfirmed offers Try again, which retries" | row 1 |
  | KIT-20 | "send works only once there are words" (label above the field) | row 1 |
  | KIT-11/KIT-2 | "true only on the confirming button", "cancel asks, with Keep it as the way back" | row 1 |
  | KIT-28 (destructive last) | "move sheet: the task title, moves, Cancel task last" | row 1 |
  | KIT-33 | "no answer: … the raw error under Details …" | row 1 |
  | LOOK-4 | team_now paused/stuck tone neutral; ratchet G17 = 0 | row 8 |

- Changed test expectations (TEST-19): `test/team_cycle_test.dart`: ScaleTransition finders → the current step is one `KitStatusMark` in the working state (KIT-1: the strip no longer owns a pulse); `team-cycle-actions` container → the notice's action keys and their order; "Stop ocproof/gastown.furiosa?" → the agent in words, no engine address (map infoMissing). `test/team_plugins_layout_test.dart`: kind chips → no kind question (map fix); `TextField` cast → the `TextField` inside the `KitField`; submit by keyboard Done (contract problem 5).
- Goldens changed (each opened and looked at): all new under `test/revamp/goldens/` — `team_board_move_sheet` (+1280x800, read-only), `team_board_priority_sheet`, `team_board_add_sheet` (empty-submit error), `team_board_cancel_confirm_sheet`, `team_host_sheet` (idle, testing, unanswered +1280x800), `team_host_guide_sheet`, `team_turn_off_sheet`, `team_cycle_how_sheet`; dark and light. Approved render `docs/design/visual-language-2026-09-26/Confirm.png` for the cancel and turn-off questions: same frame (grabber, icon tile, start-aligned title, error-filled confirm, surface3 cancel); differences: no consequences panel (the page has none).
- Before and after (EVID-10): `before-team-host-sheet-no-answer.png` / `after-team-host-sheet-no-answer-dark.png`, `before-team-host-sheet-testing.png` / `after-team-host-sheet-testing-dark.png`, `before-team-host-guide-sheet.png` / `after-team-host-guide-sheet-dark.png`, `before-team-turn-off-sheet.png` / `after-team-turn-off-sheet-dark.png`, `before-team-cycle-how-sheet.png` / `after-team-cycle-how-sheet-dark.png` (befores from `docs/qa/screen-census/`), `before-team-board-move-sheet-dark.png` / `after-team-board-move-sheet-dark.png`, `before-team-board-cancel-confirm-sheet-dark.png` / `after-team-board-cancel-confirm-sheet-dark.png` (befores from base `test/goldens/`); `after-team-board-add-sheet-empty-dark.png`, `after-team-board-priority-sheet-dark.png`: no before render in the census.
- Accessibility: every field has a visible label (KitField); the send action is a labelled icon action; the receipt is one live region naming the control and state; step marks carry their words; the guide's header fits 320 dp at 2.5x text (layout test). Arabic/RTL not reviewed (owner decision).
- Privacy and security: no credentials, links or notifications changed. The raw platform error of a failed host test is shown only inside `KitDetailsFold` (redacted by the kit). "Save without an answer" stores the same `OrchestrationConfig` shape as a found host, with `front: false` (read-only until the host answers).
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/shared_team_1_test.dart test/revamp/shared_team_1_golden_test.dart
$F test -j 1 test/team_cycle_test.dart test/team_control_test.dart test/team_run_screen_test.dart
$F test -j 1 test/team_now_test.dart test/team_plugins_layout_test.dart test/builtin_team_section_test.dart test/builtin_team_bring_in_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared tests outside the write set were not run (owner decision 2026-09-27); likely broken: `test/team_controls_test.dart` (receipt words now "Nudge · Sent" inside bidi isolates, refusal reason inline instead of `team-receipt-reason`), `test/team_plugins_screen_test.dart` (the "host kind" group expects the removed chips), and the integrator-owned goldens `test/goldens/team_board_golden_test.dart` (move sheet, cancel confirm), `test/goldens/team_sheets_golden_test.dart` / work sheet (cycle strip look), `test/goldens/team_agent_golden_test.dart` (context number tone).
- The host sheet's in-body actions opened over the plugins' team sheet at 2.5x text (contract problem 5).
- `agent_screen.dart` still asks "Restart" with the stop tone; `confirmTeamControl` now takes `kind:` so its unit can pass `KitConfirmKind.neutral` (LOOK-5).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/shared-team-1` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `a0dc9aed` |
| Deployed | No | |
| Released | No | |
