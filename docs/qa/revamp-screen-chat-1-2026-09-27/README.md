# revamp-screen-chat-1: Revamp chat (4 files) (2026-09-27)

## 1. Scope

- Unit: `screen-chat-1` (wave 2b, screen-revamp, tier 1). Finish line: `lib/ui/screens/demo_screen.dart`, `running_work_sheet.dart`, `session_context_screen.dart` and `session_destination_sheet.dart` have a G1/G2/G7/G15/G16/G17/G21 count of zero, are built from kit parts in the VL look, and their ten pages are handled by their map proposals. Non-goal: no gateway call, controller field or persistence added (only existing calls are used: `abort`, `compactSession`, `stopManagedShell`, `setManagedShellTimeout`, `moveSessionToDirectory`, `warpSessionToWorkspace`, `switchConsoleOrganization`); no Arabic (owner decision 2026-09-27).
- Files changed: the four screens; `lib/l10n/app_en.arb` (+ regenerated `app_localizations*.dart`); `test/running_work_sheet_test.dart`, `test/session_context_screen_test.dart` (tests write set); new `test/revamp/screen_chat_1_test.dart`, `test/revamp/screen_chat_1_golden_test.dart`, `test/revamp/screen_chat_1_support.dart` and 34 goldens `test/revamp/goldens/{chat_running_work_sheet,chat_session_context,chat_session_destination,chat_demo,terminal_shell_output,settings_console_organization}_*`; the `running-work-sheet` census guard in `tool/capture/census/areas/e_workspace.dart` (TEST-17: its anchor text changed from "Tasks"); this record.
- Pages (map ids): `running-work-sheet` (fix), `shell-output` (fix), `shell-output-stop-dialog` (merge-into:confirm-sheet), `shell-output-timeout-sheet` (fix), `session-context` (fix), `session-destination-sheet` (fix), `session-destination-confirm-dialog` (fix), `console-organization-sheet` (redesign), `console-organization-switch-dialog` (fix), `demo` (fix).
- Specs followed: STANDARDS.md §1.1, MAP-1, §4 (KIT-1, KIT-2, KIT-8, KIT-11, KIT-15, KIT-16, KIT-20, KIT-25, KIT-27, KIT-28, KIT-31, KIT-33, KIT-34), §5 (LOOK-4, LOOK-5, LOOK-12), §15, §16; kit-v2 §9.1; kit-api KitSheet, KitConfirmSheet, KitRow/KitRowParts, KitTaskMark/KitStatusMark, KitLogPanel, KitChoiceList, KitDetailsFold, KitProgressRow, KitSearchField, KitStateView, KitNotice, KitStatusLine, KitTopBar, KitScreen; visual language 2026-09-26 (Settings canvas for rows and panels, Confirm canvas for questions).
- Contract problems (PROC-20):
  1. **KitSheet: an in-place `showKitConfirm` gets at most half the sheet's height.** In `_KitSheetHostState.build` the question and the hidden content are two `Flexible`s with flex 1, so the question is capped at half of `modalMaxHeight` (about 411 dp at 412×915, 270 dp at 800×600) and its lower buttons scroll out of sight (seen in this unit's first renders of the move question). Proposed: give the hidden content no flex while a question shows (or drop it from the column). Worked around here for the move and organization questions: the sheet is the choice and closes, then the question opens as its own modal (no sheet on a sheet). The one in-place question left (Stop an agent, inside Running now) is short enough to fit at phone sizes.
  2. **KitProgressRow.segments legend overflows at 200 % text** when a segment's value label is a few words ("41,200 tokens" overflowed by 24 px at 320 dp): the legend row has no stacked form. Worked around by short legend values ("38 %"); the counts are in the bar's own label.
  3. The task's copy line says `app_en.arb` AND `app_ar.arb`; the later owner decision (2026-09-27) drops Arabic, so new copy is in `app_en.arb` only (R15).
  4. KitStatusMark's working mark is a spinner that never settles under `pumpAndSettle` unless the test turns animations off; this unit's tests pump with `disableAnimations: true`. Shared tests that open Running now with a busy agent and `pumpAndSettle` without reduced motion would time out (the ones found already use reduced motion or fixed pumps).
- New kit parts (KIT-3): none.
- Moved or removed (owner rethink rule 2026-09-27):
  - Running now: the sheet's title "Tasks" (it also meant to-dos and team tasks) became "Running now"; the Refresh button was removed (the list refreshes every 2 s while visible and on every shell/session event; errors carry Try again); the full-width "Run in background" at the top moved under the list as "Keep chatting while it runs", shown only while work holds the conversation, with one line on what it frees; the Running/Finished section headers were removed (one list by urgency).
  - Command output: Copy output moved from the bar into the log panel's Copy all; the "Follow output" switch was removed (the panel follows until the person scrolls up, KIT-31); the raw command with env and paths moved from the bold title into Details ("Command as typed"), the title is the command as a person says it; the success snackbar "Timeout updated" became the status line's "stops in 14:59".
  - Conversation context: the ring was replaced by a plain verdict plus the model's bar; the six-row request table and the model's raw id moved under Details; the four near-identical legend squares became a stacked bar with a worded legend; "Active context" moved from a bare list tile above the page into the model's panel.
  - Move / cloud move: radio marks and raw paths under each name were removed (name + kind in words; the path only when two places share a name); the snackbar "Moved to …" was removed (the move is confirmed by the question; see NOT proven).
  - Organizations: raw org ids under each name were removed; the account header is said once per account; the snackbar "Switched to …" was removed.
  - Demo: the hand-built flask bar with unlabelled icons became a KitScreen bar ("Try it offline", Reset demo, Close); the two-line disclosure became the status line's supporting text; "Set up your own server" moved from a bare text button into a finished notice and the bar's menu.
- Map items (EVID-11):
  - `running-work-sheet`: statesMissing "idle agents filed under Finished" → done: `test/running_work_sheet_test.dart` "UXCHAT child Tasks discovers…" (`Agent · Idle`, no "Finished"); infoMissing "what 'Run in background' frees" → done: "UXCHAT background eligibility…"; actionsMissing "stop a running agent from here" → done: "a running agent is stopped from its row, asked first"; couldBeAutomatic "move a command to background automatically when it outlives the turn" → no owner (needs a policy and server support; wave 3). Owner rationale "Failed · 2:00", "KitStateView 'Nothing running'", rename → done (goldens `chat_running_work_sheet_{loaded,empty}_*`, test "Running now lists running work first…").
  - `shell-output`: statesMissing "about to hit its timeout" → done: "a command about to hit its time limit says so on its page"; infoMissing "time until the timeout" → done for a limit set on this page ("stops in 14:59"; the server does not report a limit it was started with); "exit code under Details" → done (Details "Exit code"); actionsMissing "re-run" → deferred: no owner (starting a shell needs an owner token for the conversation, a new behaviour); couldBeAutomatic "follow while at the bottom" → done by KitLogPanel.
  - `shell-output-stop-dialog` (merge-into:confirm-sheet): already `showKitConfirm`; statesMissing "stop fails" → done: "a stop the server refuses keeps the question open"; actionsMissing "copy the output first" → done (alternative "Copy output first", same test, golden `terminal_shell_output_stop_dialog_*`).
  - `shell-output-timeout-sheet`: statesMissing "current timeout not marked" → done (golden `terminal_shell_output_timeout_sheet_*`, KitChoiceList marks "15 minutes · Current"); "apply fails" → done: "a time limit the server refuses is said with Try again"; retitle "Stop it after…" → done.
  - `session-context`: statesMissing "near the limit: what to do" → done: `test/session_context_screen_test.dart` "near the limit, the page says so and offers to compact"; infoMissing "plain verdict" → done ("context surface stays flat…" expects "20 % used · plenty left"); actionsMissing "compact now" → done (same test); "start a fresh conversation with a summary" → no owner (no gateway call to seed a new conversation with a summary); couldBeAutomatic: n/a.
  - `session-destination-sheet`: statesMissing "no other destination exists" → done: `screen_chat_1_test.dart` "with nowhere else to go the sheet says so"; "disconnected destination: why it can't be picked" → done: "a cloud machine that is not connected says why…"; infoMissing "destination kind in words" → done: "move names each place and its kind…"; actionsMissing "create a new separate copy as the destination" → deferred: no owner (creating a worktree from this sheet is a new flow; the Worktrees screen exists).
  - `session-destination-confirm-dialog`: statesMissing "move fails" → done: "a move the server refuses keeps the question open"; "changes conflict at the destination" → no owner (the server reports no conflict state); infoMissing "what happens to changes left behind" → done: "the move question says where changes go and where they stay…".
  - `console-organization-sheet` (redesign, owner verdict Rethink): kit-only rebuild of today's layout; account header said once, raw ids removed, what switching changes said. statesMissing "single organization" → done: "with one organization there is nothing to switch, said once"; "signed out of Console" → deferred to the Settings account slice (no owner in work-units.json); infoMissing "role or plan" → no owner (not reported); actionsMissing "find it outside a conversation (Settings)" and the Settings row → deferred to the Settings/account slice (no owner in work-units.json).
  - `console-organization-switch-dialog`: doubled period → fixed (body ends with fixed words; "…switch says what changes" asserts no ".."); infoMissing "effect on running conversations" → done ("nothing running is stopped"); statesMissing "switch fails" → done: "a switch that fails keeps the question open".
  - `demo`: statesMissing "keyboard open hides 'Set up your own server'" → done: the bar's menu always has it (`screen_chat_1_test.dart` "the demo is titled, says it is simulated…"); infoMissing "what comes next (a review of an edit)" → the empty state says "Send the sample prompt below, then review the proposed edit." (golden `chat_demo_ready_*`); rationale "drop 'Simulated reply'" → **not done**: that label is the demo model's name in `lib/demo/demo_gateway.dart`, outside this unit's write set; couldBeAutomatic "play the sample on open" → no owner.
- States per page (STATE-20): running-work-sheet: loaded (golden ×4), empty (golden), loading (skeleton rows), error (KitNotice.error + Try again), disconnected (notice, rows disabled with reason), scope changed (KitStateView), requesting background (working action), result (notice) — tests above. shell-output: running (golden ×4), stopped (test), about to stop (test), error (notice + Try again), limit refused (test), server restarted / unavailable / disconnected / scope changed (notices, "reconnect refreshes status…" test). session-context: loaded (golden ×4), near limit (golden + test), compacting started (test), loading (skeleton), error (KitStateView.error), refresh failed (notice, test), empty (KitStateView + action, test), moved (KitStateView, test). session-destination-sheet: move (golden ×4), warp (golden), none (test), loading (skeleton), error (KitStateView.error + Try again), no match (KitSearchNoMatch). console-organization-sheet: loaded (golden), one (test), loading, error, empty. Questions: goldens and tests above. demo: ready (golden), finished (notice; covered by `test/demo_isolation_test.dart`, not run here).
- Deferred states (STATE-21): none beyond the map items marked "no owner" or "deferred" above.

## 2. Builds

- Branch `revamp/screen-chat-1`, base `7011dc46` (`feat/phone-setup-v2`), code head `63b5410f`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work at the wave checkpoint.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: failing-first | n/a: a rebuild; each map fix is a new state with its own test | n/a | PASS |
| 2 | `test/revamp/screen_chat_1_test.dart`, `test/running_work_sheet_test.dart`, `test/session_context_screen_test.dart` | pass | 38 passed (`run-1.txt`) | PASS |
| 3 | `test/revamp/screen_chat_1_golden_test.dart` (compare, no update) | pass | 34 passed (`run-2.txt`) | PASS |
| 4 | `flutter analyze` on the four screens, the five test files and `lib/l10n` | no issues | No issues found | PASS |
| 5 | G1/G2/G7/G15/G16/G17/G21 for the four files: `KIT_RATCHET_WRITE=1 flutter test test/kit_ratchet_test.dart`, then read the regenerated baseline and `git checkout` it | no entry for any of the four files | no entry (all zero); baseline restored, not staged | PASS |
| 6 | Design-standard, l10n, glossary, ledger tests; `flutter analyze lib test` | pass | not run (owner decision 2026-09-27: run only the unit's own test files) | NOT RUN |

## 5. Evidence

- `run-1.txt`: behaviour tests. `run-2.txt`: golden comparison.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-34 (no success snackbars) | `test/running_work_sheet_test.dart` "timeout replacement and clearing use the selected duration" (the limit is said in the status line); `test/session_context_screen_test.dart` "near the limit…" (compacting said in place) | `run-1.txt` |
  | DATA-11 (confirm before ending work) | "a running agent is stopped from its row, asked first"; "Stop requires confirmation and retains already loaded output" | `run-1.txt` |
  | STATE-3 (a failed act keeps the question open) | "a stop the server refuses keeps the question open"; `screen_chat_1_test.dart` "a move the server refuses…", "a switch that fails…" | `run-1.txt` |
  | STATE-8 (disabled says why) | "a cloud machine that is not connected says why it cannot be picked" | `run-1.txt` |
  | STATE-9 / owner rule (mark + word, no state sections) | "Running now lists running work first, then the rest, by outcome" | `run-1.txt` |
  | LAY-4 (large text) | "running work and output remain scrollable at 360 dp with 2.5x text"; "context surface stays flat and fits compact large text" (320 dp, 2.0) | `run-1.txt` |

- Changed test expectations (TEST-19), all in this unit's tests write set:
  - `running_work_sheet_test.dart`: "Run in background" → "Keep chatting while it runs" and the explanation is now expected (map infoMissing); `find.text('Idle')` ×2 → the rows' "Agent · Idle" and no "Finished" (map statesMissing); "Finished · " / "Exit code 1" → "Command · Finished/Failed/Stopped · 0:30" and no section headers (owner rule, map rationale "Failed · 2:00"); "Tasks"/"No tasks yet" → "Nothing running" (map rename); `FilledButton`/`TextButton` finders → keys `shell-output-stop`, `shell-output-stop-confirm` (KIT-8, TEST-5); the stopped output's `find.text(output)` → a line of it in the log panel, "Follow output" absence → Stop/limit keys gone (KIT-31); the disabled Refresh `IconButton` → Refresh absent from the bar (KitTopBar keeps a disabled action in the overflow, KIT-36). The sheet body is pumped inside a scroll view, as the sheet frame hosts it (KIT-17), and with animations off (contract problem 4).
  - `session_context_screen_test.dart`: the disabled retry `IconButton` → Refresh absent from the bar (KIT-36); "20%" → "20 % used · plenty left" (map infoMissing).
- Goldens added (each opened and looked at), 34 PNGs, 2.9 MB: `chat_running_work_sheet_{loaded,loaded_1280x800,empty}_{dark,light}`, `terminal_shell_output_{running,running_1280x800,timeout_sheet,stop_dialog}_{dark,light}`, `chat_session_context_{loaded,loaded_1280x800,near_limit}_{dark,light}`, `chat_session_destination_sheet_{move,move_1280x800,warp}_{dark,light}`, `chat_session_destination_confirm_dialog_with_changes_{dark,light}`, `settings_console_organization_{sheet_loaded,switch_dialog_confirming}_{dark,light}`, `chat_demo_ready_{dark,light}`.
  - Approved renders (EVID-12): `docs/design/visual-language-2026-09-26/Confirm.png` for the three questions — matches: icon tile, start-aligned title, body, consequences panel with info/kept marks, full-width stacked primary and Cancel; differences: the icon tile is the neutral info tile for a move/switch (neutral kind), the stop question uses the stop tile and dangerFill as in the canvas. `Settings.png` for the rows — matches: surface1 panels, 30 px icon tiles, hairlines inset to the words, text3 trailing values, sentence-case section labels; differences: rows in sheets sit on the sheet's rails (no screen gutter). `Chat.png` for the demo — the demo's composer and transcript are the production chat (another unit's parts); difference: the bar is the plain page bar, not the conversation header.
- Before and after (EVID-10): `before-<page>-<state>.png` from the base census (`docs/qa/screen-census/{e-workspace,k-session-misc,a-shell}/`) and `after-<page>-<state>.png` (dark goldens) for running-work-sheet loaded/empty, shell-output running, shell-output-stop-dialog, shell-output-timeout-sheet, session-context loaded (+ after near-limit), session-destination-sheet move/warp, session-destination-confirm-dialog, console-organization-sheet, console-organization-switch-dialog, demo.
- Accessibility: every row mark carries its word (KitTaskMark label; the word is also in the supporting line); icon-only controls are KitTopBar actions/KitIconButtons with labels ("Reset demo", "Refresh context", "Close"); disabled rows and actions carry their reason (not-connected machines, offline command rows, compact while a reply runs); the log panel is LTR mono and not a live region; 200 % and 250 % text checked by the tests above.
- Privacy and security: no credentials, stored formats, links or notifications changed. "Copy output first" goes through `KitCopy.copy` (redacted); the log panel redacts every line; the command as typed is shown only under Details.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/screen_chat_1_test.dart test/running_work_sheet_test.dart test/session_context_screen_test.dart
$F test -j 1 test/revamp/screen_chat_1_golden_test.dart
$F analyze lib/ui/screens/demo_screen.dart lib/ui/screens/running_work_sheet.dart lib/ui/screens/session_context_screen.dart lib/ui/screens/session_destination_sheet.dart test/revamp/screen_chat_1_test.dart test/revamp/screen_chat_1_golden_test.dart test/revamp/screen_chat_1_support.dart test/running_work_sheet_test.dart test/session_context_screen_test.dart
# ratchet counts (then restore the baseline, never stage it):
KIT_RATCHET_WRITE=1 $F test -j 1 test/kit_ratchet_test.dart && git checkout test/kit_ratchet_baseline.json
```

## 7. NOT proven

- Not run on a device or emulator (a live OpenCode 1 server with managed shells, workspaces and Console organizations).
- Shared tests that exercise these pages were not run (owner decision); expected breaks are listed in the build record's `sharedTestsBroken` (the demo's title and exit tooltip).
- After a move or an organization switch the sheet closes with no receipt beyond the question itself (the old snackbar was removed, KIT-34); a "Moved to …" receipt belongs on the conversation (chat screen, another unit's file).
- The time left is shown only for a limit set from this page: the server does not report the limit a command was started with.
- The ratchet, design-standard, l10n-coverage, glossary and ledger gates and the whole-tree analyze were not run; the integrator regenerates `test/kit_ratchet_baseline.json` and the l10n `_baseline` and adds the four screens to `_migrated` (R05, R10).
- The ui-ledger page titles for `running-work-sheet` ("Tasks") and `demo` ("Offline demo") were not changed (append-only registry, R09).
- No Arabic or right-to-left render (owner decision 2026-09-27).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/screen-chat-1` |
| Enabled | Yes (same entry points: chat bar and session menu, command launcher /move /warp /org, Servers and welcome "Try demo") | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `63b5410f` |
| Deployed | No | |
| Released | No | |
