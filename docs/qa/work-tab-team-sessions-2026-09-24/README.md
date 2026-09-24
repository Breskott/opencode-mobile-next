# The AI Team's own sessions kept out of the person's lists (2026-09-24)

## Scope

Seen on the Android 15 emulator on 2026-09-24, after the in-app AI Team ran one task
in the project `my-app`: the Work tab's "In other projects" listed the team's agent
sessions as the person's conversations, one with leaked model markup in its title:

- `I'll run the startup sequence to check for existing work and prime the merge queue.<tool_call><fu…` (refinery)
- `Refinery merge queue patrol` (refinery)
- `Polecat startup: claim work and execute` (`gastown.furiosa`, in
  `/root/aiteam/city/.gc/worktrees/my-app/polecats/gastown.furiosa`)

The agents are `opencode acp` processes on the same in-app OpenCode server, so each of
their runs is an ordinary OpenCode session in a folder the team made.

**The rule** (one place, `lib/domain/team_directories.dart`): a folder is the team's
when it is

1. the team home `/root/aiteam` or anything inside it (`BuiltinTeam.home` now reads
   this constant, so the two cannot drift; the Termux proot spike used the same path);
2. inside a Gas City `.gc` folder (an agent's work folder is
   `<city>/.gc/worktrees/<rig>/<agent>` wherever the city lives: Termux-native, a PC);
3. inside the Termux-native team home `~/.oc/aiteam`.

A conversation is judged by its own folder (the project's folder only when the server
names none), so the person's conversations in the team's rig, `/root/projects/my-app`,
stay. `.` and `..` segments are resolved before matching.

Applied where the person's lists are built:

| List | Code |
|---|---|
| Work tab "In other projects" | `ConnectionController.conversationsElsewhere` (also looks up to 3 pages of 40, so a busy team cannot push the person's out) |
| Work tab recent-projects strip | `OtherProjectsPanel.build` |
| Other projects' running / needs-you tally, Inbox badge (`waitingElsewhereCount`) | `ElsewhereAttention.handle` ignores team folders |
| All conversations | `GlobalSessionsScreen` first page and load more |
| Project list | `ProjectsScreen._usableProjects` |
| Project opened automatically | `ConnectionController.newestProject`, `WorkspaceScreen` initial choice |
| Import destinations | `SessionImportScreen` |

**Titles** (one place, `lib/domain/session_title_text.dart`,
`displaySessionTitleText`): cut at the first `<tool_call`, `</tool_call`, `<tool_use`,
`<function`, `</function` or `<|` (case-insensitive), or at a half-cut marker the
server ended with an ellipsis (`…<tool_ca…`); then the space and ellipsis before the
cut. Nothing is changed in stored data. `presentedSessionTitle` uses it, and every raw
title display now goes through one of the two: the Work lists, activity, session
relations, the run-command dialog, run results, the monitor screen, the home-screen
widget, pinned shortcuts, and the live notification.

## Builds

- Branch `fix/work-tab-team-sessions`, from `feat/phone-setup-v2` @ `59822303`.
- Code: commit `75e60dbd`. No APK built or published.

## Devices

None: unit and widget tests only (`flutter test`, pinned Shorebird Flutter
`91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`, on the PC).

## Runs

All test data is the real titles and folders above; the person's conversation is in
`/root/projects/my-app`, the current project `/root/projects/notes`.

| # | Step | Expected | Actual |
|---|---|---|---|
| 1 | `isAiTeamDirectory` on the polecat and refinery folders, `/root/aiteam`, `BuiltinTeam.cityDir`, an origin repo, `.`/`..` forms | team's | PASS |
| 2 | Same on a Termux-native `~/.oc/aiteam/city/.gc/worktrees/…` and a PC city `…/city2/.gc/worktrees/…` | team's | PASS |
| 3 | Same on `/root/projects/my-app`, `/root/projects/aiteam-spike`, `/root/aiteam-notes`, `/root/aiteamwork/app`, null, empty | not the team's | PASS |
| 4 | `isAiTeamConversation`: polecat session with project `/root/projects/my-app` / person's session with a team project folder | team's / person's | PASS |
| 5 | `displaySessionTitleText` on the refinery title | `I'll run … prime the merge queue.` | PASS |
| 6 | Other markup (`<function=`, `<function_calls>`, `<\|im_start\|>`, `</tool_call>`, `<TOOL_CALL>`, `<tool_use>`), half-cut markers | cut | PASS |
| 7 | Ordinary titles incl. `Compare a < b`, `Explain the <details> element`, `Use <f`, a title ending in `…` | unchanged | PASS |
| 8 | `conversationsElsewhere` on the emulator's list (3 team sessions newer than the person's) | only the person's | PASS |
| 9 | 60 team sessions then the person's, pages of 40 | person's found on page 2 | PASS |
| 10 | Team `session.status` busy + team `permission.v2.asked` + person's `question.asked` | activity lists only my-app; Inbox count 1 | PASS |
| 11 | `newestProject` with a newer team project | the person's my-app | PASS |
| 12 | Work tab panel (widget), recents include a polecat folder, team run live | person's conversation and my-app chip shown; no team title, chip or `<tool_call>` | PASS |
| 13 | Work tab panel with the leaked title on the person's own conversation | cleaned title shown; stored title unchanged | PASS |
| 14 | All conversations (widget), team sessions on pages 1 and 2 | only the person's two | PASS |
| 15 | Project list (widget) with a refinery project and an origin repo project | only my-app | PASS |
| 16 | Existing suites: conversations elsewhere, elsewhere attention, other-projects panel, session title, global sessions, projects | unchanged behaviour | PASS (85 tests) |
| 17 | Rows 8-15 and the title rows with the consumer fixes reverted (domain modules kept so tests compile) | fail | FAIL as expected: 10 tests fail, the 62 others pass |

Also run and passing (no evidence file): 30 other suites that import the changed
files (activity, session relations, run result, profile monitor screen, widget
snapshot, pinned shortcuts, live status, session import, built-in team, workspace
hierarchy and layout, team home/card, accessibility, text scale, l10n coverage and
more).

## Evidence

- [tests-with-fix.txt](tests-with-fix.txt): `flutter test --reporter expanded` on the
  nine suites, 85 passed.
- [tests-without-fix.txt](tests-without-fix.txt): the five new/extended suites with
  `connection.dart`, `elsewhere_attention.dart`, `other_projects_panel.dart`,
  `global_sessions_screen.dart`, `projects_screen.dart` and `session_title.dart`
  checked out from `59822303`: 10 failures, each a test above.

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test test/team_directories_test.dart test/session_title_text_test.dart \
  test/work_tab_team_sessions_test.dart test/global_sessions_screen_test.dart \
  test/projects_screen_test.dart test/conversations_elsewhere_test.dart \
  test/elsewhere_attention_test.dart test/other_projects_panel_test.dart \
  test/session_title_test.dart
# Without the fix:
git checkout 59822303 -- lib/state/connection.dart lib/state/elsewhere_attention.dart \
  lib/ui/widgets/other_projects_panel.dart lib/ui/screens/global_sessions_screen.dart \
  lib/ui/screens/projects_screen.dart lib/ui/widgets/session_title.dart
$F test test/work_tab_team_sessions_test.dart test/session_title_text_test.dart \
  test/global_sessions_screen_test.dart test/projects_screen_test.dart
git checkout HEAD -- lib/
```

## NOT proven

- Not viewed on a device: no emulator or phone run, no APK.
- The refinery's exact folder was not read from the emulator; the tests use
  `/root/aiteam/city/.gc/worktrees/my-app/refinery` (any folder under `/root/aiteam`
  is covered by the rule). The Termux-native path is inferred from `aiteam.sh`
  (`$HOME/.oc/aiteam/city`); what folder the proot OpenCode reports for those agents
  was not observed.
- A Gas City city outside `/root/aiteam` and `~/.oc/aiteam` is recognised only inside
  its `.gc` folder; agents running in the city folder itself (mayor, deacon) on a PC
  city would still be listed.
- Background notifications of other servers (`ProfileMonitor`) read one project folder
  per server and were not changed; a team agent asking for permission in the
  current project folder would still be reported there.
- The team's own "needs you" (a team agent stopped on a permission in its folder) no
  longer counts on the Inbox badge; the AI Team screen is expected to show it, which
  was not checked here.
- Not every title display was audited beyond the searched patterns
  (`session.title`, `presentedSessionTitle`); the rename fields (Work tab, chat) still
  show the stored title on purpose.
