# revamp-shared-servers-1: Revamp servers (2026-09-27)

## 1. Scope

- Unit: `shared-servers-1` (wave 2a, screen revamp, tier 1). Finish line: every file in the write set has a G1, G16, G7, G17 and G21 count of zero, and each page is handled by its map proposal, with the wave-2 missing states and actions, in the VL look. Non-goal: no gateway call, controller field or persistence added; no change outside the write set (LocalServerRow, PhoneServerCard, WorkRunawayNotice stay as they are).
- Files changed: `lib/ui/widgets/server_switcher_sheet.dart`, `lib/ui/widgets/other_servers_panel.dart`, `lib/ui/widgets/local_agent_server_entry.dart`, `lib/ui/widgets/termux_phone_tools.dart`; `lib/l10n/app_en.arb` (6 keys) and the generated `app_localizations*.dart`; tests `test/server_switcher_test.dart`, `test/revamp/shared_servers_1_test.dart`, `test/revamp/shared_servers_1_golden_test.dart`, `test/revamp/shared_servers_1_fixtures.dart`, 12 goldens under `test/revamp/goldens/`. `lib/ui/widgets/termux_running_server_entry.dart` was already kit-only (all gates 0) and its page is `keep`: unchanged.
- Pages (map ids): `server-switcher-sheet` (fix), `embedded-local-agent-server-entry` (fix), `embedded-termux-running-server-entry` (keep), `embedded-termux-attention-line` (fix).
- Specs followed: STANDARDS.md KIT-1, KIT-2, KIT-15, KIT-16, KIT-27, KIT-28, KIT-32, LOOK-1, LOOK-4, LOOK-6, LOOK-12, LOOK-24, LOOK-25, STATE-5, STATE-8, STATE-9, STATE-20, STATE-21, MAP-1; kit-v2 §9.1; visual language §5.
- Contract problems (PROC-20): the unit task names the record folder `docs/qa/revamp-shared-servers-1/`, EVID-1 names it with the date; the EVID-1 form was used. The task text asks for `app_ar.arb` entries, the later owner decision (2026-09-27) drops Arabic; English only was written.
- New kit parts (KIT-3): none.
- Map items (EVID-11):
  - server-switcher-sheet: title "Servers" → done: `shared_servers_1_test.dart` "is titled Servers…"; one current mark → done: same test + golden `server_switcher_sheet_*`; Disconnect into the current row's menu → done: "the current row opens its menu, and Disconnect there confirms in place…"; statesMissing "another server needs you" → done: "other servers say Needs you, how many run…"; statesMissing "a saved server needs credentials" → done: same test ("Password re-entry required"); infoMissing "which other server has something waiting or running" → done: same test and golden.
  - embedded-local-agent-server-entry: actionsMissing "Sign in to Claude when signed out" → done: "signed out: the line says so and the menu signs in through Termux"; "Update" → done: "an older Paseo offers Update…" (opens the setup page, where the update's progress is shown; the row does not run the multi-minute update itself); "Remove" → done: "Remove confirms first, then removes"; statesMissing "signed out" → done (same test, golden); "starting over 8 s" → done: "a start past 8 s says it is still starting"; "failed to start" → done: "a failed start says it did not start…"; "Termux not answering" → done: "Termux not answering keeps a saved server as Not answering with Try again"; infoMissing "its own agent mark" → deferred: the icon is drawn by `LocalServerRow` (not in this write set), no owner.
  - embedded-termux-running-server-entry (keep): statesMissing "starting over 8 s", "Termux not answering" → not built (MAP-1 keep: no behaviour change); "Termux not answering" is already shown ("No access" / "Not answering" rows).
  - embedded-termux-attention-line: actionsMissing "Stop it (confirmed)" → deferred, no owner: the line is drawn by `WorkRunawayNotice` in `lib/ui/widgets/work_status_line.dart`, outside this write set, which has one action slot; `TermuxProcesses.stopPid` and `confirmStopProcess` exist for whoever owns it. "always stop leftover helpers" → deferred (needs persistence, wave 3), no owner. statesMissing "in-app host runaway" → deferred (needs a process scan of the in-app host, not received today), no owner; "stopped confirmation" → deferred with "Stop it". infoMissing "blame the helper" → deferred with the line's copy (work_status_line.dart). This unit only moved the watcher's two routes to `pushKitPage`.
- States per page (STATE-20, embedded parts take their host's states; sheet with local data):
  - server-switcher-sheet: one server, other saved servers (plain, needs you, working, password again), reconnecting, phone rows → `shared_servers_1_test.dart` + `server_switcher_test.dart` + golden `server_switcher_sheet_{dark,light,1280x800_dark,1280x800_light}`.
  - embedded-local-agent-server-entry: running, signed out, didn't start, stopped with update, not answering → golden `local_agent_server_entry_states_*`; still starting, menu → tests.
  - other servers panel (Work tab part): needs you, working, hidden → tests + golden `other_servers_panel_*`.
- Deferred states (STATE-21): see the attention-line items above.

## 2. Builds

- Branch `revamp/shared-servers-1`, base `2cec35ca`, code head `58c17ec3`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/revamp/shared_servers_1_test.dart` | passes | 13 passed | PASS |
| 2 | `test/revamp/shared_servers_1_golden_test.dart --update-goldens`, then each image opened | 12 renders, no exception | 12 passed; images looked at | PASS |
| 3 | `test/server_switcher_test.dart` | passes | whole file: 11 passed, 4 failed; the two "fit 320 dp at 2.5x" cases used the removed AppBar, were fixed and re-run with `--plain-name` (2 passed); left failing, "the app bar server name opens the switcher; no overflow menu" and "a renamed profile shows at once / renamed in place and saved" look for the key `server-profile-title`, which no longer exists anywhere in `lib/` since the shell revamp (home_screen.dart); unrelated to this unit | FAIL (pre-existing) |
| 4 | `KIT_RATCHET_WRITE=1 test/kit_ratchet_test.dart`, then the baseline restored | no entry left for the five files | 0 entries on G1, G2, G7, G15x, G16, G17, G21 for all five files | PASS |
| 5 | `flutter analyze lib test` | no issues in changed paths | 1 info outside this unit (`test/goldens/kit/kit_tappable_golden_test.dart` unnecessary import); none in changed paths | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-2, KIT-16 | `shared_servers_1_test.dart` "the current row opens its menu, and Disconnect there confirms in place" | run 1 |
  | LOOK-24, STATE-9 | `shared_servers_1_test.dart` "other servers say Needs you…", "a waiting server leads with the needs-you mark…" | run 1 |
  | STATE-5 | `shared_servers_1_test.dart` "a start past 8 s says it is still starting" | run 1 |
  | KIT-1, LOOK-1, LOOK-4 | kit ratchet counts | run 4 |

- Changed test expectations (TEST-19): `test/server_switcher_test.dart`: "Connected" and the address are now read from the current row's rich line (`findRichText`), Disconnect is opened from the current row's menu instead of a bottom button (map: server-switcher-sheet), and the 320 dp check measures against the window instead of the removed AppBar.
- Goldens changed (each opened and looked at): new `test/revamp/goldens/server_switcher_sheet_*`, `local_agent_server_entry_states_*`, `other_servers_panel_*` (phone and 1280x800, dark and light). Approved render `docs/design/visual-language-2026-09-26/Main.png` (rows, needs-you mark) and `Confirm.png` (sheet frame): same grabber, icon tile, start-aligned title, surface1 panels of rows. Differences: in light the sheet and its row panels share the same white (the theme's sheet colour), so the panels do not read as panels; kit/theme concern, not changed here.
- Before and after: `before-server-switcher-sheet-one-server.png` (base `docs/qa/screen-census/a-shell/server-switcher-sheet.png`) → `after-server-switcher-sheet-loaded.png`; `before-embedded-local-agent-server-entry-running.png` (base `docs/qa/screen-census/h-termux/embedded-local-agent-server-entry--running.png`) → `after-embedded-local-agent-server-entry-states.png`; other servers panel: no before render (page not in the census) → `after-other-servers-panel-loaded.png`.
- Accessibility: the current server row is `selected` in semantics and its state word leads the line; needs-you rows carry the word, not only the amber mark; the current row's menu is a named menu ("Server actions") that a tap, long-press, right-click or the keyboard opens; the address is isolated left to right with its plain URL as the semantic label. Sheet fits 320 dp at 2.5x text (`server_switcher_test.dart` "fit 320 dp at 2.5x").
- Privacy and security: Sign in to Claude opens Claude's own sign-in in Termux; the app never sees the credential. No links, storage keys or notifications changed.
- Migration: n/a: no stored format changed.
- Shared tests expected to break (for the integrator): `test/safety_confirms_test.dart` "Disconnect" group taps `server-switcher-disconnect` directly (now inside the current row's menu); `test/goldens/work_parts_golden_test.dart` `work_other_servers` golden (panel restyled); `test/phone_server_card_test.dart` switcher cases may read the current row's "Connected" as plain text. Not run (owner decision 2026-09-27).
- Not changed, noted: `LocalServerRow` (shared by both phone rows) still draws a per-row ⋮ button (KIT-28) and error text in the error colour (LOOK-5 B2), and gives Claude Code the same phone icon as OpenCode; `lib/ui/widgets/work_status_line.dart` owns the runaway line.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/shared_servers_1_test.dart test/revamp/shared_servers_1_golden_test.dart
$F test -j 1 test/server_switcher_test.dart
KIT_RATCHET_WRITE=1 $F test -j 1 test/kit_ratchet_test.dart && git diff test/kit_ratchet_baseline.json; git checkout test/kit_ratchet_baseline.json
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator.
- The phone rows inside the switcher (Termux server, Claude Code) were exercised by `server_switcher_test.dart` on the fake Termux channel only.
- `test/phone_server_screens_test.dart`, `test/local_agent_onboarding_test.dart`, `test/termux_running_server_test.dart`, the design-standard, l10n and glossary tests were not run (owner decision 2026-09-27: only the unit's own new files).
- Sign in to Claude and Remove against a real Termux.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Partial: attention-line Stop is deferred (outside the write set) | `revamp/shared-servers-1` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | code head `58c17ec3` |
| Deployed | No | |
| Released | No | |
