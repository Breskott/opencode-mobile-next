# revamp-slice-P4.5: P4.5 New conversation chooser (2026-09-27)

## 1. Scope

- Unit: `slice-P4.5` (wave 3, programme-slice, programme P4). Finish line: Work has one New conversation button, and its chooser (new-conversation-sheet) offers Solo · Team · In a separate copy · On a cloud machine where the server supports each. The choice is remembered per server, and every start ends in a conversation. Non-goal: no worktree management changes (the isolated-task sheet itself, the worktrees page and managed workspaces are untouched).
- Files changed:
  - `lib/ui/screens/new_conversation_sheet.dart` (new: `NewConversationChoice`, `NewConversationMemory`, `NewConversationOptions`, `NewConversationCloud`, `NewConversationChoices`, `showNewConversationSheet`);
  - `lib/ui/screens/workspace_screen.dart` (one New conversation → `_newConversation`; the Solo · Team segment and the project sheet's isolated-task row removed);
  - `lib/ui/widgets/team_discover.dart` (`TeamNewMode` kept as a `@Deprecated` wrapper over `NewConversationMemory`, R11);
  - `lib/l10n/app_en.arb` + generated output (8 new `newConversation*` keys, English only per the owner decision of 2026-09-27);
  - `docs/design/ui-ledger/parts/e-workspace.json` (new page `new-conversation-sheet`; `workspace-new` retargeted; `workspace-new-mode` and `workspace-isolated-task` removed; `isolated-task-sheet` reached from the chooser);
  - `tool/capture/census/areas/e_workspace.dart` (the isolated-task census guard reaches the sheet through the chooser, TEST-17);
  - tests: `test/new_conversation_sheet_test.dart` (new), `test/revamp/slice_p4_5_golden_test.dart` (new) + 4 goldens, `test/team_discover_test.dart`, `test/workspace_stable_layout_test.dart`.
- Pages (map ids): `isolated-task-sheet` (unit page), plus `new-conversation-sheet` (new) and `workspace` (its entry).
- Specs followed: STANDARDS.md §1, §15, §16; target-ia.md "New (8)" and journeys 9, 22, 24; kit-v2 §9.1 (kit only: `showKitSheet`, `KitRowGroup`, `KitRow`, `KitRowIcon`, `kitCurrentSpan`, `KitChevron`, `KitButton.primary`).
- Contract problems (PROC-20): none blocking. Note: the unit's `after` lists `chat-9`, which is not on `revamp/wave3`; this slice needs no chat file (none was touched), so it was built without it.
- New kit parts (KIT-3): none.
- Map items (EVID-11), `isolated-task-sheet` (proposal "fix"):
  - entry moves into Work's new-work choice ("In a separate copy") → done: `test/new_conversation_sheet_test.dart` "In a separate copy opens the isolated-task sheet for the project" and "one New conversation: … no separate-copy row on the project sheet".
  - actionsMissing "write the first prompt", "Start anyway after failed setup", "Run setup again", "Remove the copy" → no owner in this unit (they are changes to `isolated_task_sheet.dart`, outside this write set, and the non-goal excludes worktree management); for the coordinator to assign.
  - `workspace` actionsMissing "choose the kind of new work in one place" → done (same tests).
- States per page (STATE-20): `new-conversation-sheet`: loaded (all four ways; golden), Team off (golden + test), Team on (`test/team_discover_test.dart` "with the team on…"), last used marked (test), only Solo → no sheet (test). Loading/empty/error do not apply: the sheet is built from state the Work tab already holds.
- Deferred states (STATE-21): none.

### What moved (owner rethink rule)

| Item | Was | Now | Why |
|---|---|---|---|
| Solo · Team segmented switch | above the New conversation button | a row each in the chooser | three ways to start become one; nothing shown twice |
| "New task in a fresh worktree of <project>" | project sheet (workspace-context-sheet) | chooser row "In a separate copy of <project>" | it starts a conversation, so it lives with the start; acceptance: reached only from the chooser |
| "New team task" button label | the primary changed its label with the switch | always "New conversation" | one button, one name |
| Cloud machine start | only "Runs on" (switch the list) on the project sheet | chooser rows "On <machine>" start there; "Runs on" stays on the project sheet (it switches what the list shows, a different job) | journey 22 "Where work runs: new-conversation-sheet" |

## 2. Builds

- Branch `revamp/slice-P4.5`, base `5177502d`, code head: see the `git log` of this branch (the commit before this record).
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 3 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/new_conversation_sheet_test.dart` | passes | 9 passed | PASS |
| 2 | `test/team_discover_test.dart` | passes | 22 passed | PASS |
| 3 | `test/workspace_stable_layout_test.dart` | the tests this unit touches pass | 6 passed (the four 320dp dock tests, 320dp RTL, 390dp real fonts); 4 fail before any line this unit changed: three "339dp 2.5x … title size" (`tester.widget<Text>` on a `KitText`, line 310) and "session details disclose usage" (looks for a `PopupMenuButton` the kit row menu replaced) | PASS for this unit; pre-existing failures listed in the build record |
| 4 | `test/revamp/slice_p4_5_golden_test.dart --update-goldens` | 4 renders, looked at | 4 written, looked at | PASS |
| 5 | `flutter analyze` on the 7 changed Dart files | no issues | no issues | PASS |

Not run (owner decision 2026-09-27: run only your own files): ratchet, design-standard, l10n, glossary and ledger tests; other suites.

## 5. Evidence

- Rule evidence:

  | Rule | Test or golden |
  |---|---|
  | one button, no switch, no copy row on project sheet | `test/new_conversation_sheet_test.dart` "one New conversation: no Solo · Team switch beside it and no separate-copy row on the project sheet" |
  | Solo ends in a conversation, remembered, marked "Last used" | "the chooser names each way and where it starts, and Solo opens the new conversation and is remembered" |
  | Team off → team's off state | "Team with the team off opens its off state and is remembered for this server"; `test/team_discover_test.dart` "Team is offered in the New conversation chooser…" |
  | Team on → team conversation start | `test/team_discover_test.dart` "with the team on: … Team starts a team task" |
  | separate copy only from chooser | "In a separate copy opens the isolated-task sheet for the project" |
  | cloud machine | "On a cloud machine moves there and opens the conversation there" |
  | only what the server supports | "a server without worktrees or cloud machines offers only what it supports"; "where Solo is the only way, New conversation starts it without asking" |
  | storage key swept with the profile (SEC, DATA-5) | "round-trips every way, reads the old Solo · Team values, and is swept with the server" |

- Changed test expectations (TEST-19):
  - `test/team_discover_test.dart` "Team is offered…": tapped the `workspace-new-mode-team` segment and read "New team task" → opens the chooser, taps `new-conversation-team`, reads "Last used" on Team after a fresh Work tab (finish line: the choice lives in the chooser).
  - `test/team_discover_test.dart` "with the team on…": segment + button → button + `new-conversation-team`.
  - `test/workspace_stable_layout_test.dart` 320dp tests: the primary opens the chooser, then Solo creates the session (was: the primary created it directly); `tester.widget<Text>(_name)` → `tester.widget<KitText>(_name)` (the project name is a KitText since wave 2; TEST-19 (1)).
  - `test/workspace_stable_layout_test.dart` 390dp: the isolated row is no longer on the project sheet; the chooser holds "In a separate copy of …" with the same detail line.
- Goldens added (each opened and looked at): `test/revamp/goldens/work_new_conversation_sheet_all_{dark,light,1280x800_dark,1280x800_light}.png`: the chooser with Solo (Last used), Team (off), In a separate copy of shopfront, On feature-login. No approved VL canvas render exists for this new page (EVID-12: none).
- Before and after: no before render (new page `new-conversation-sheet`); after: `after-new-conversation-sheet-all-dark.png`, `after-new-conversation-sheet-all-1280x800-light.png`.
- Accessibility: every row is a `KitRow` (one tap target, title up to 2 lines, supporting up to 2 lines, chevron); "Last used" is a word, not only the accent tile; project and machine names are bidi-isolated. The 320dp 2.0x/2.5x dock tests open the chooser and tap Solo with no exception.
- Privacy and security: the only stored value is the choice (`solo`, `team`, `copy`, `cloud:<workspace id>`) under the existing `oc.newConversationMode.<profileId>` key, which `ProfileStore.profileScopedPreferenceKeys` sweeps (tested). No credentials, links or notifications.
- Migration: the key keeps its old values (`solo`, `team`) readable; two new values (`copy`, `cloud:<id>`) are added. An older build reading `copy`/`cloud:…` treats it as Solo (its `isTeam` check is `== 'team'`).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/new_conversation_sheet_test.dart test/team_discover_test.dart
$F test -j 1 test/workspace_stable_layout_test.dart
$F test -j 1 test/revamp/slice_p4_5_golden_test.dart
$F analyze lib/ui/screens/new_conversation_sheet.dart lib/ui/screens/workspace_screen.dart lib/ui/widgets/team_discover.dart
```

Emulator proof for the coordinator (the unit's `proof`: screenshots of each choice's landing), on a build of this branch:

1. Connect to an OpenCode 1 server on a computer (Team is possible; worktrees supported), open a git project with at least one managed workspace. Work tab → tap **New conversation**: screenshot the chooser (Solo, Team, In a separate copy of <project>, On <machine>).
2. **Solo** → screenshot the new empty conversation. Back → New conversation: Solo is marked "Last used".
3. **Team** with the AI Team off → screenshot the AI Team intro (off state). With the team on → screenshot the team task start / team conversation.
4. **In a separate copy of <project>** → screenshot the isolated-task sheet; Create and start → screenshot the conversation in the copy. Open the project sheet (project name at the top): there is no "New task in a fresh worktree" row.
5. **On <machine>** → screenshot the conversation on that machine (Work's project sheet shows it under Runs on as current).
6. On a server with no team possible (a Termux phone that cannot run it) and no worktrees (OpenCode 2): New conversation opens a conversation directly, no chooser.
7. Remove the server in Settings and add it back: New conversation shows no "Last used" (the choice was swept).

## 7. NOT proven

- Not run on a device or emulator.
- The shared tests listed in the build record (`test/projects_screen_test.dart` fresh-server create, `tool/capture/isolated_task_test.dart`, the census) were not run; the first taps New conversation and expects an immediate create, which now opens the chooser on a server where Team is possible.
- Ratchet, design-standard, l10n, glossary and ledger gates were not run (owner decision: own files only).
- The cloud-machine path is proven against a fake controller only; a live managed workspace was not used.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/slice-P4.5` |
| Enabled | Yes (no flag) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
