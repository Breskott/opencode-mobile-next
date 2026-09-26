# revamp-shared-shell-1: Revamp shell (12 files) (2026-09-27)

## 1. Scope

- Unit: `shared-shell-1` (wave 2a, screen-revamp). Finish line: every file in the write set has a G16 count of zero (and zero in G1, G2, G7, G15, G17, G21), each page is handled by its map proposal, and the look is VL. Non-goal: no gateway call, controller field or persistence added; the fixed connection stages of slice-P4.4 are not built here.
- Files changed: the 12 write-set files under `lib/ui/widgets/`; new `lib/ui/kit/kit_confirm_retired.dart` (the retired `showConfirmSheet`, moved out of `confirm_sheet.dart` per R12 and re-exported from it); `lib/l10n/app_en.arb` plus generated `app_localizations*.dart`; `test/entrance_test.dart`, `test/markdown_agent_blocks_test.dart`; new `test/revamp/shared_shell_1_test.dart`, `test/revamp/shared_shell_1_golden_test.dart` and 16 PNGs in `test/revamp/goldens/`.
- Pages (map ids): confirm-sheet, connection-status-details-sheet, embedded-connection-status-banner, remove-local-agents-confirm-sheet, restart-local-agents-sheet, settings-disconnect-sheet, stop-local-agents-confirm-sheet.
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-3, KIT-11, KIT-22, KIT-23, KIT-27, KIT-28, KIT-33, KIT-34, KIT-38, KIT-43, LOOK-1, LOOK-2, LOOK-4, LOOK-5, LOOK-6, LOOK-12, LOOK-24, LAY-8, MAP-1, STATE-9, STATE-21; kit-v2 §1.2, §2.5, §4.3, §9; visual-language §5.
- Contract problems (PROC-20):
  - Record path: the task text says `docs/qa/revamp-<unit id>/README.md`; STANDARDS EVID-1 says `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/`. This record follows EVID-1. Blocks nothing.
  - The task text asks for copy in `app_en.arb` AND `app_ar.arb` (R04); the owner decision of 2026-09-27 (later, wins by R15) drops Arabic. New keys are in `app_en.arb` only.
- New kit parts (KIT-3): none. `lib/ui/kit/kit_confirm_retired.dart` is not a part: it is the retired `showConfirmSheet` wrapper moved into the kit (R12, KIT-38) so the definition no longer counts in a screen file; G2 still counts every call site. The integrator decides whether it gets a `kit.dart` row (R06); the unit that brings the call count to zero deletes it.
- Acceptance items:
  - SwipeDeleteBackground as a wrapper over KitSwipeAction (C37): **not done, blocked**. KitSwipeAction belongs to kit-KitRow-v2 and is not on `feat/phone-setup-v2`. `SwipeDeleteBackground` is rebuilt from kit parts (KitSurface surface2 + KitIcon delete in the danger tone) and its doc names the follow-up. Follow-up owner: whoever integrates kit-KitRow-v2 (or screen-work-1).
  - ```` ```choices ```` as KitChoiceList inside KitRequestCard(kind: choice) (P4.1b): **left for follow-up**, as the unit instructions allow: KitChoiceList is not on the base. AgentChoicesBlock keeps its behaviour and keys but is made kit-only (KitRowGroup of KitRows) so the file reaches zero.
  - G1, G16, G7 and the look patterns reach 0 for this unit's files: **done** (see Run 5).
- Map items (EVID-11):
  - embedded-connection-status-banner (fix): actionsMissing "Switch server from the line" → done: `test/revamp/shared_shell_1_test.dart` "Change server is one tap away in the line's menu". actionsMissing "Restart the phone server" → done in the widget (`serverOnThisPhone` + `onRestartServer`, optional, additive): "the phone's own server offers Restart after asking"; wiring it from `home_screen.dart` / chat (outside the write set) → deferred to screen-home / slice-P4.4. statesMissing "no network on the phone" → deferred (needs connectivity data; slice-P4.4). statesMissing "phone server stopped" → done when the host passes the flags ("OpenCode on this phone isn't answering"), golden `shell_embedded_connection_status_banner_phone_stopped_*`.
  - connection-status-details-sheet (merge-into:root-connecting): kit-only with the least change, `// revamp: merge-into:root-connecting (slice-P4.4)` above `showConnectionDetailsSheet`. actionsMissing and statesMissing → deferred to slice-P4.4 (its raw error is now copyable through KitDetailsFold).
  - settings-disconnect-sheet (fix): rationale "second paragraph only when something is waiting, in one sentence" → done: "nothing waiting: no count line…", "queued prompts and drafts are one sentence with the total". statesMissing "the server is this phone's own: say whether it stays running" → done: "the phone's own server says it stays running on battery". actionsMissing "Reconnect snackbar on the servers list" → deferred to the servers screen unit (it is a KitUndo on `servers_screen.dart`, outside the write set).
  - confirm-sheet (keep): kit-only; the optional secondary action and typed-name guard already exist in `showKitConfirm` (`alternative:`, `typedName:`). No missing items for this unit.
  - stop / restart / remove-local-agents sheets (keep): kit-only through `showKitConfirm`, kinds stop / neutral / destructive; remove's icon is now the delete glyph (map: "only the icon changes"). No missing items.
- States per page (STATE-20): the sheets are local-data confirmations (loaded; the working and failed states belong to their callers). Banner: reconnecting, lost, password-rejected, token-rejected (existing tests `test/codex_connection_banner_test.dart`, `test/server_v2_connect_flow_test.dart`), lost and phone-stopped goldens.
- Deferred states (STATE-21): no network on the phone → needs connectivity data, owner slice-P4.4; refused vs timed out vs DNS in the details sheet → needs a diagnosis, owner slice-P4.4.

## 2. Builds

- Branch `revamp/shared-shell-1`, base `64128dba` (`feat/phone-setup-v2`), code head `e10d84a4`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Failing-first on the base | n/a | not run: owner decision 2026-09-27 (speed); the new tests use APIs the base lacks, so they would not compile there | n/a |
| 2 | `test/revamp/shared_shell_1_test.dart` | passes | 11 passed | PASS |
| 3 | `test/revamp/shared_shell_1_golden_test.dart --update-goldens` | 16 renders, looked at | 16 passed, all opened | PASS |
| 4 | `test/markdown_agent_blocks_test.dart`, `test/entrance_test.dart`, `test/other_projects_panel_test.dart`, `test/first_reply_notify_card_test.dart` | pass | 5 + 4 + 7 + 16 passed | PASS |
| 5 | `KIT_RATCHET_WRITE=1 test/kit_ratchet_test.dart`, then diff for the 12 files, then `git checkout` of the baseline | every G1, G2, G15, G16, G17, G21 entry of the 12 files gone | all gone (e.g. G16 agent_blocks 17 → 0, G1 safety_confirms 9 → 0) | PASS |
| 6 | `test/kit_ratchet_test.dart`, `test/golden_harness_test.dart`, `test/l10n_coverage_test.dart` | pass | 41 + harness + 2 passed | PASS |
| 7 | `flutter analyze --no-pub lib test` | no issues | No issues found | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-23 | `test/markdown_agent_blocks_test.dart` "```choices without a handler copies the option and says so" | Run 4 |
  | LOOK-4 | `test/revamp/shared_shell_1_test.dart` "a lost connection is a failure line, not \"needs you\"" | Run 2 |
  | LOOK-5 | goldens `phone_restart_local_agents_sheet_busy_*` (neutral accent confirm), `phone_stop_…`, `phone_remove_…` (danger fill) | Run 3 |
  | KIT-33 | `showConnectionDetailsSheet` raw error in `KitDetailsFold` | code review |

- Changed test expectations (TEST-19):
  - `test/markdown_agent_blocks_test.dart`: the copied-choice message was a SnackBar text; now it is the one KitCopy announcement (KIT-23, KIT-34).
  - `test/entrance_test.dart`: `Opacity` finders → `FadeTransition` under `KitEntrance` (the kit's one entrance, MOT-1); the per-index stagger is gone.
- Shared tests this unit breaks (for the integrator, TEST-19 case 1):
  - `test/safety_confirms_test.dart` lines 158-159 and 209 expect "No queued prompts." / "No unsent drafts.": the map's settings-disconnect-sheet fix removes those zero counts. New expectation: no count line when nothing waits.
  - Not run, possibly affected: goldens that include the Work tab's other-projects panel (`work_loaded`), the shell/work status line (`shell_reconnecting`, `work_not_answering`, `work_runaway`: tone attention → failure/neutral changes the icon colour), and the census pages above. Integrator-owned; not re-rendered here.
- Goldens added (each opened and looked at): `test/revamp/goldens/` — `servers_settings_disconnect_sheet_waiting_{,1280x800_}{dark,light}`, `phone_stop_local_agents_confirm_sheet_confirming_{dark,light}`, `phone_restart_local_agents_sheet_busy_{dark,light}`, `phone_remove_local_agents_confirm_sheet_confirming_{dark,light}`, `shell_embedded_connection_status_banner_lost_{,1280x800_}{dark,light}`, `shell_embedded_connection_status_banner_phone_stopped_{dark,light}`. Approved VL canvas renders for these pages: none known (EVID-12: n/a).
- Before and after (EVID-10): `before-settings-disconnect-sheet-confirming.png` (base census) / `after-settings-disconnect-sheet-waiting.png`; `before-stop-local-agents-confirm-sheet-confirming.png` / `after-stop-local-agents-confirm-sheet-confirming.png`; `before-embedded-connection-status-banner-lost.png` / `after-embedded-connection-status-banner-lost.png`. Confirm-sheet, restart and remove sheets: no separate before copied (same frame as stop).
- Accessibility: every icon-only control is a `KitIconButton` with a label (open live conversation, copy command, wrap toggle with toggled semantics); choice rows keep their "Choose option …" button label; checklist items keep "Done/To do: …" labels; rows are ≥ 48 dp. 200 % text not re-rendered (owner: galleries at 1.0 only).
- Privacy and security: copying agent choices is verbatim (`redact: false`, agent text); commands copy through `KitIconButton.copy`, which redacts registered secrets. No credentials, links or notifications changed.
- Migration: n/a, no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/shared_shell_1_test.dart test/revamp/shared_shell_1_golden_test.dart
$F test -j 1 test/markdown_agent_blocks_test.dart test/entrance_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/golden_harness_test.dart
$F analyze --no-pub lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- The full suite was not run (owner decision 2026-09-27); shared tests other than those in Run 4 and 6 are unverified, including `test/safety_confirms_test.dart` (known to break, above), `test/home_navigation_test.dart`, `test/chat_live_events_test.dart`, `test/work_tab_status_line_test.dart` and `test/design_standard_test.dart`.
- Restart from the shell's connection line is not reachable in the app until `home_screen.dart` passes `serverOnThisPhone` / `onRestartServer`.
- No failing-first output for the fixes (Run 1).
- No Arabic, RTL or 200 % text renders (owner decision).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Partial: KitSwipeAction and KitChoiceList adoption blocked on unmerged parts | `revamp/shared-shell-1` |
| Enabled | Yes (no flag); banner Restart needs host wiring | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `e10d84a4` |
| Deployed | No | |
| Released | No | |
