# Non-golden regression repairs — tests-b, 2026-09-28

Finish line: each existing assigned non-golden file passes or has an explicit product blocker, with clean analysis and local commits. Non-goals: golden refreshes, excluded production files, push, signing, release.

Base: `f83e1e30`, branch `codex/tests-b`. Test-only ownership is partitioned into Team controls/detail/activity/now/redesign, Team home/work/layout, phone setup/first run, and shell navigation; the coordinator owns recovery/profile/platform tests, production fixes, verification, and this record. Workers do not run tests. All Flutter processes for this job run serially with `--concurrency=1`.

## Verification

Pinned toolchain: `~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin`.

- `flutter pub get --offline`: passed.
- Each assigned file: `flutter test --no-pub --concurrency=1 --reporter=json test/<file>_test.dart`.
- Changed Dart files: `dart format --language-version=3.10`.
- `flutter analyze --no-pub`: **No issues found**. The first run found one redundant test import; it was removed, and the final whole-tree run is clean.

This job checks the assigned non-golden files, not the whole repository or golden gate. No PNG or gate baseline is changed.

## Results and remaining work

All 20 assigned files exist. Baseline: **211 passed / 101 failed** (312 tests). Counts exclude hidden loader/setup events; there were no skips or timeouts. After: **311 passed / 2 failed** (313 tests, including one added regression case). **18 files pass; two retain the same shared product defect.** The three unchanged files retain their passing baseline results: none of the production fixes changes their exercised behavior.

| File | Before pass / fail | After pass / fail | Classification / repair |
|---|---:|---:|---|
| `team_controls_test.dart` | 11 / 19 | 31 / 0 | Menus/role names; named receipts and honest pause result; +1 regression case |
| `team_agent_screen_test.dart` | 19 / 5 | 24 / 0 | Selectable technical text; lazy-list scrolling |
| `team_activity_test.dart` | 17 / 8 | 25 / 0 | Scroll actual sheet header into view |
| `team_home_test.dart` | 20 / 10 | 30 / 0 | One list, counts, host row, debounce, Arabic |
| `team_home_layout_test.dart` | 1 / 1 | 2 / 0 | Moved details; strict overflow check |
| `team_now_test.dart` | 8 / 3 | 11 / 0 | Visible host/title wrappers |
| `team_work_layout_test.dart` | 8 / 0 | 8 / 0 | Unchanged |
| `team_work_tab_test.dart` | 5 / 0 | 5 / 0 | Unchanged |
| `team_one_page_test.dart` | 7 / 0 | 7 / 0 | Unchanged |
| `team_redesign_test.dart` | 3 / 3 | 6 / 0 | Deduplicated task, kit search, distinct agent names |
| `phone_setup_start_screen_test.dart` | 26 / 3 | 28 / 1 | Sheet/animation selectors; locked-label fix; transition blocker |
| `phone_setup_ready_screen_test.dart` | 12 / 2 | 14 / 0 | Kit form field and editable direction |
| `phone_setup_welcome_entry_test.dart` | 10 / 2 | 11 / 1 | Lazy welcome row; native mock; transition blocker |
| `first_run_landing_test.dart` | 5 / 5 | 10 / 0 | Selected navigation destination |
| `first_run_welcome_test.dart` | 6 / 10 | 16 / 0 | Demo, long-press, kit field, settled scroll, both setup engines |
| `builtin_server_autostart_test.dart` | 4 / 1 | 5 / 0 | Both setup engines mocked for route |
| `app_exit_recovery_test.dart` | 26 / 2 | 28 / 0 | Bidi-isolated manufacturer copy |
| `server_profile_reentry_test.dart` | 4 / 2 | 6 / 0 | Long-press row actions and current confirmation |
| `desktop_platform_gating_test.dart` | 15 / 4 | 19 / 0 | Composer label; safe guide placeholder |
| `home_navigation_test.dart` | 4 / 21 | 25 / 0 | Kit navigation, badges, breadcrumbs, insets and semantics |

## Intentional changes used as evidence

- Team agent controls moved into the top-bar menu; manual Reassign was removed because dispatch owns assignment. Technical values became selectable. [Team detail revamp](../revamp-screen-team-1-2026-09-27/README.md), commit `346ca55c`; [details fold](../revamp-kit-KitDetailsFold-2026-09-27/README.md).
- Cramped sheets move their header with body scrolling while keeping it outside the body's render ancestry. Tests now scroll until the actual target is hit-testable. [Live sheet record](../revamp-kit-KitSheet-live-2026-09-27/README.md), `2d0ac9fe`.
- Team home became one list: the question also represents its task, asleep/paused agents remain visible, and counts include every listed agent. Agent names distinguish workers by nickname and role. [One-list record](../team-home-one-list-2026-09-27/README.md), [Team home](../revamp-screen-team-2-2026-09-27/README.md), [agents](../revamp-screen-team-3-2026-09-27/README.md), [P5.2](../slice-P5.2-2026-09-27/README.md); `a7bda280`, `ac649a70`, `10cf32d9`.
- Technical details moved to the Team home host row. Search now debounces through the kit. [P3.4](../slice-P3.4-2026-09-27/README.md), `d42ba768`. The old layout test silently consumed an exception; it now requires no exception and passes.
- Setup uses kit forms, sheet-owned scrolling, and fade transitions. [Phone screen record](../revamp-screen-phone-1-2026-09-27/README.md), `5088cc85`. Tests still check the suggested name, validation, routing, Arabic direction, reduced motion, target size, and 320dp/2.5x layout.
- The shell names the destination through navigation selection instead of a repeated title; kit navigation, glass, badges, breadcrumbs, and insets replaced the Material wrappers. [Shell record](../revamp-screen-shell-2-2026-09-27/README.md), `f4b7a51f`, `635f69ac`, `6f21d378`. Back handling, badges, file state, keyboard clearance, and geometry checks remain.
- Saved-server actions moved to long-press, fields became kit forms, and the demo remains on the welcome rather than the saved-server list. [Servers record](../revamp-screen-servers-1-2026-09-27/README.md), `aea34722`, `51b0340e`. The demo title/exit changed with [chat entry](../revamp-screen-chat-1-2026-09-27/README.md), `63b5410f`, `253a6919`; demo exit still verifies no profiles were saved.
- Keep-running copy now isolates the manufacturer name for bidi text. [System record](../revamp-screen-system-1/README.md), `c2889432`. The setup route observes both native setup engines; route fixtures now fake both and answer device probes rather than leaving real native polling timers pending. [Phone host integration](../slice-P1.2-2026-09-27/README.md), [root record](../coord-main-2026-09-27/README.md).
- Composer's tools label is now “Attach and more.” [Composer record](../revamp-kit-KitComposer-2026-09-27/README.md). Both Android availability and desktop absence assertions remain.

## Real product defects

Fixed, with existing failing behavioral coverage (plus one new unconfirmed-pause case):

1. `lib/ui/screens/team/agent_screen.dart`: the agent receipt bypassed the shared action-naming contract. It now uses `teamControlReceipt`, retaining retry keys and behavior. [P4.1c](../slice-P4.1c-2026-09-27/README.md), `4cfbf10a`, explicitly requires “Nudge · Sending…”. The repaired controls test failed on this wording before the source fix.
2. The same screen showed “Paused” and Undo even when the host refused the request. Refused/unconfirmed results now keep the receipt without a success notice or Undo. Tests assert the reason/status, one request, and no automatic resend.
3. `lib/ui/setup_commands.dart:15`: the guide's legacy command used a password-shaped literal and tripped the existing SEC-4 credential assertion on both platforms. It now uses the explicit `<your-password>` placeholder; the credential guard remains unchanged. [Code-block record](../revamp-kit-KitCodeBlock-2026-09-27/README.md).
4. `lib/ui/kit/kit_row_parts.dart:362`: required setup components overflowed by 164px at 320dp/2.5x because the locked label had no flex. The label can now wrap within its trailing width. This was already called out by the phone screen record; correcting the test's sheet scroll exposed it again.

Unresolved (tests remain enabled; no expected-error suppression):

- `lib/ui/screens/phone_setup/phone_setup_start_screen.dart:471` uses `KitSwap`; `lib/ui/kit/motion/kit_motion_parts.dart:77` retains outgoing and incoming action-bearing children. `lib/ui/kit/kit_screen.dart:633` counts both and raises the one-primary assertion at line 652. Scenarios: an already-running Termux hero changes to interrupted setup, and returning to the welcome after setup begins. The affected tests are `phone_setup_start_screen_test.dart` (“the progress and Termux heroes fit 320 dp at 2.5x”) and `phone_setup_welcome_entry_test.dart` (“coming back from phone setup reads the job again”). Resolving shared transition ownership/visibility semantics is outside this bounded test repair; the gate has not been relaxed and animations have not been disabled to hide it.


## Candidate and delivery

All test evidence uses the pinned toolchain and one worker process per invocation. Each file was rerun after its final relevant edit; unchanged passing files were not rerun without a relevant change. Intermediate failures were followed by file-level repairs and reruns, never a repository-wide test loop. Supplemental checks cover the shared row component and accepted-pause Undo. No golden tests were run or PNGs regenerated.

Production changes are limited to the agent detail receipt/pause handling, the guide command placeholder, and locked-label wrapping. No excluded file, baseline, skip, or assertion guard was changed. No device/emulator, APK, signing, deployment, release, push, or full-repository test gate is claimed.

Final source/test diff fingerprint (`git diff f83e1e30 -- lib test | sha256sum`):

`8c81780c46ddb99b303973515f39c1c69525a96dc9c4812f6c23a67e564ba765`

Local implementation commits:

- `b8a30bf9` — test: repair recovery and profile reentry harnesses [skip ci]
- `7443306c` — fix: keep setup guide examples within credential guard [skip ci]
- `8d7c5349` — test: align shell navigation checks with kit contracts [skip ci]
- `7ae2eeac` — test: restore team home and sheet behavior checks [skip ci]
- `c2b897cd` — fix: show honest named agent control receipts [skip ci]
- `958612ae` — fix: wrap locked setup labels and repair setup tests [skip ci]

Every commit has `[skip ci]` and both requested trailers. The final QA commit also removes one redundant import found by analysis; this has no runtime behavior change. The work is committed locally only; nothing was pushed.

Supplemental validation:

- `flutter test --no-pub --concurrency=1 test/kit/kit_row_parts_test.dart`: **17 passed**.
- `flutter test --no-pub --concurrency=1 test/revamp/screen_team_1_test.dart --plain-name "Pause fox is undone in place"`: **1 passed**.
- `dart format --language-version=3.10 --output=none --set-exit-if-changed` on all 20 changed Dart files: **0 changes**.
- Protected-file/PNG/baseline audit, `git diff f83e1e30 --check`, and every README evidence link: **passed**.
- Final whole-tree `flutter analyze --no-pub`: **No issues found**.

Delivery state: implemented and locally committed; verified with the assigned tests and supplemental checks above, with two explicit product failures still open. No deployment or release.
