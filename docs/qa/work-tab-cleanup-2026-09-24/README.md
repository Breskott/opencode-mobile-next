# Work tab cleanup and the design kit (2026-09-24)

## Scope

Specs: [`docs/design/work-tab-cleanup-2026-09-24.md`](../../design/work-tab-cleanup-2026-09-24.md)
(the owner's phone screenshots `before-phone-1..4`: "a mess") and
[`docs/design/design-standard.md`](../../design/design-standard.md) (the owner's
"every screen looks different and adhoc", screenshot `before-phone-5`). The
standard's migration steps 1 (connection states) and 2 (the Work tab) are done.

### The design kit (`lib/ui/kit/`, one import: `kit/kit.dart`)

| Part | Standard | What it is |
|---|---|---|
| `KitScreen` | §1 | fixed header rows, the one loading bar, the scroll body, and a bottom block pinned *below* the list (padded by the shell's published bottom inset, so nothing scrolls under the button or the tab bar) |
| `KitButton`, `KitActionBlock`, `KitAction` | §2 | primary (filled), secondary (tonal), tertiary (text, start-aligned, at most 2, the rest under More); stacked full width under 600 dp, one row with the primary rightmost from 600 dp. `working:` only for a tap in flight, never a status |
| `KitStateView` | §3 | icon in a tonal circle (tone from `AppStatusTone`), title, body, progress, actions, collapsed Details (mono) below the actions; page (no card, centred) and inline sizes |
| `KitLoadingBar`, `KitSkeletonRows`, `KitProgress` | §4 | 2 dp labelled bar that always keeps its 2 dp; skeleton rows excluded from semantics; waiting/known progress with a caption |
| `KitStatusLine` | §5 | icon, words, one action (+ a More menu, + dismiss); a hairline row, not a card; one live region; the action drops under the words when both do not fit |
| `KitRow` (+ `SectionLabel`, re-exported) | §6 | leading icon, 1-line title, 1-line muted supporting line (spans may carry a state word), trailing value/chevron/action |

`LoadingList`, `ProductEmptyState`, `ProductErrorState`, `ProductInlineEmpty` and
`SectionLabel` stay in `product_states.dart` (25 importers) and are re-exported
from `kit.dart`, not duplicated.

### Spec items

| # | What changed | Where |
|---|---|---|
| 1 | While the saved project (or the one picked for a fresh connection) is being opened, the header names it and the folder chooser never shows; the chooser appears only when that has finished with no folder. If a connection came up without the saved folder, Work opens that folder (`ConnectionController.restoreSavedLocation`), never another one. | `workspace_screen.dart` `_pendingDirectory`, `_restoreSaved`; `connection.dart` `savedProjectDirectory`, `restoringSavedLocation`, `restoreSavedLocation` |
| 2 | The header shows the open (or opening) folder from the first frame, before the project list; the catalog name replaces the folder name when it arrives. | `workspace_screen.dart` `_headerDirectory`, `_projectName` |
| 3 | One 2 dp bar under the header for projects, conversations, a project switch and a reconnect. The footer's "Loading conversations…" bar, the project-list bar, the other-project row spinners and, on Work, the shell banner's spinner are gone. | `KitScreen`/`KitLoadingBar`; `home_screen.dart` (banner) |
| 4 | While the list loads: 4 skeleton rows and nothing else. Empty text only after a finished load; Load more only when there is more and nothing is loading (2 skeleton rows while a page loads); Archived only when an archived conversation is known. | `workspace_screen.dart` `firstLoad`, `showEmpty` |
| 5 | The "Unreviewed work" card is gone. An unreviewed result says **Unreviewed** in its own row; its menu has **Review results** and **Mark as reviewed** (the old "Dismiss shown items", for one row: stays unread on the server, answers nothing). | `_SessionRow`; `ReturnBrief.unreviewedRun`, `ReturnBrief.single`; `return_brief_card.dart`/`return_brief_panel.dart` deleted |
| 6 | "Last observed state…" never shows on a normal start. On Work: "This may be out of date" + Refresh, only when waiting requests could not be refreshed while connected. Not connected is item 10's line. | `workspace_screen.dart` `_statusLine` |
| 7 | "OpenCode has been busy for 10 min with nothing to do" / "…busy in FinanceHub for…", "See what's running", dismissible until the process changes (pid + name). No paths: the folder under `projects/` names the project, anything else is "OpenCode". | `termux_phone_tools.dart` `TermuxRunawayWatcher`, `runawayProjectName` |
| 8 | Chips + "In other projects" replaced by one **Other projects** section after this project's list: each project once, with Needs you / Running (· n) / Unreviewed / last activity, and the live conversation's title. Row tap switches; the trailing chevron opens the live conversation. At most 3 (needs you, then running, first), then **All projects**. | `other_projects_panel.dart` on `KitRow` |
| 9 | New conversation is pinned *below* the list (`KitScreen.bottom`), so no row or header is ever under it or under the tab bar, at rest or at the end. | `KitScreen` |
| 10 | Kept the connecting screen (see decision D1), with the 8 s rule: "OpenCode on this phone isn't answering" / "<server> isn't answering", "The app keeps trying in the background.", Restart (phone server, confirmed: "A running agent turn will stop"), Try again, Choose another server. On Work, a reconnect that takes over 8 s (or has failed) is the status line: phone: Restart + (More) Try again; remote: Try again + (More) Details. No memory claims. | `saved_server_connection_card.dart`, `work_status_line.dart`, `grace_timer.dart`, `phone_server_restart.dart` |

The status line is one module (`WorkStatusLine`) with this priority: server not
answering (after 8 s, or at once when the last attempt failed) > project list
failed > workspaces failed > may be out of date > leftover process > location
notice. It also shows above the folder chooser (server only).

### The connecting / stopped screen (standard §3, `before-phone-5`)

`SavedServerConnectionCard` keeps its API and is now five `KitStateView` states:
connecting, **starting** (title "Starting OpenCode on this phone…" / "Starting
OpenCode inside the app…" with progress; it wins over a stale error, so the title
never says "stopped" while it starts, and no disabled button stands in for the
progress), not answering (8 s), stopped (stop icon, attention tone, not a red
block), failed. One primary, one secondary (Try again), tertiary Change server
and the setup link; what to check, the address and the raw error are under
Details, below the actions.

### Decisions where the spec left a choice

- **D1, item 10: the Work tab does not open before the connection is up.** The
  shell swaps `HomeScreen` for the connecting screen whenever
  `hasConnectedServer` is false, and that is false during every health check,
  including a lifecycle resume and every Try again (`_retireTransport` sets
  `api = null`/`_transportReady = false`). Mounting the shell with no gateway
  would put every tab (Inbox, Project, Settings) in front of a null
  `api`/`repository`. The safe version: the connecting screen keeps the 8 s
  rule and the ways out, and the Work tab's own line covers an SSE reconnect
  that is taking long. Opening Work early needs a controller change (keep the
  shell during a resume/retry) and is listed below.
- **Header subtitle.** No "· This device" under the project name: the app bar
  directly above already names the server; repeating it was noise.
- **Mark as reviewed** instead of a bare "Dismiss": in a row menu next to
  Archive and Delete, "Dismiss" does not say what goes. No confirm (nothing is
  lost; the next result brings the mark back).
- **"Unread result" badge** on Work rows is replaced by the Unreviewed mark (it
  meant the same finished-and-unseen result; after Mark as reviewed the row is
  calm while the server still counts it unread). All conversations keeps its
  badge.
- **Phone server line**: Restart is the visible action and Try again is in its
  menu, because the app already retries by itself; Restart is the way out it
  cannot take alone.
- **Other projects** after this project's list and before "On your other
  servers" (which only shows when something runs or waits there).
- **The shell banner** stays on the other tabs, and on Work for a rejected
  password or token (their fix is there); on Work the generic "Reconnecting…"
  banner and its spinner are replaced by the bar and, after 8 s, the line.
- **Isolated task** stays a text button beside New conversation in the pinned
  block (a deliberate earlier layout with its own tests); the standard would
  put it in the section menu. Owner decision, see "not migrated".
- New conversation is disabled while a project is being restored: the loading
  bar and skeleton rows right above are the visible reason.

### Standard rules each migrated screen now meets

| Rule | Connecting screen | Work tab |
|---|---|---|
| §1 one scroll body, 16 dp rails, last row clears pinned parts (`KitScreen`) | yes (page state) | yes (test "item 9") |
| §2 one primary, stacked full width, tertiary start-aligned, no button as status | yes | primary yes; Isolated task beside it (exception above) |
| §3 `KitStateView` for every state, title never contradicts progress, Details below actions | connecting, starting, not answering, stopped, failed | folder chooser (page), empty and no-projects (inline) |
| §4 one 2 dp bar, skeletons, 8 s rule | progress in the state; 8 s | yes |
| §5 one status line, not a card | — | yes |
| §6 rows with state in the row | — | Other projects on `KitRow`; conversation rows keep their `ListTile` (two-line titles, tested wrapping) |
| §8 source scan + goldens | yes | yes |

## Builds

- Branch `fix/work-tab-cleanup`, from `feat/phone-setup-v2` @ `4699191e`, with
  `4bd1748e` (design standard) cherry-picked as `4d5005ba`.
- Code, tests, renders and goldens: commit `acdd5efc`. No APK built.

## Devices

None. Widget tests and rendered images only (`flutter test`, pinned Shorebird
Flutter `91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`, on the PC).

## Runs

| # | Step | Expected | Actual |
|---|---|---|---|
| 1 | Saved project, connection up, folder not open yet (restore held) | header "FinanceHub3", no chooser, the saved folder is the one opened | PASS |
| 2 | No saved project, newest project being opened (held) | no chooser flash, header names it | PASS |
| 3 | No project at all | chooser | PASS |
| 4 | Project list held back | header named from the first frame | PASS |
| 5 | First load (projects and conversations loading) | exactly one `LinearProgressIndicator`; skeleton rows; no empty, "Loading conversations…", Load more or Archived | PASS |
| 6 | SSE reconnecting, shell on Work | no shell banner, one bar, no spinner in the Work tab | PASS |
| 7 | Load finished, nothing there | teaching empty state, no bar, no skeleton, no Archived | PASS |
| 8 | Unreviewed result | "Unreviewed" in its row, no card | PASS |
| 9 | Mark as reviewed; refused save; project switch mid-save; Review results; route retired on project change; no read state; partial list; failed empty list | as the old card's rules (`return_brief_widget_test`) | PASS |
| 10 | Other projects: FinanceHub running, Tradebook idle, FinanceHub3 current | each once; current not listed; trailing chevron opens the live one; >3 → All projects; needs you first and live | PASS |
| 11 | Long list in the shell at 412×915, at rest and at the end | no visible text of the list under New conversation or the tab bar; last row above the button | PASS |
| 12 | Reconnecting on Work: 7 s / 9 s / connected again | nothing / "OpenCode on this phone isn't answering" + Restart (+ Try again in More) / gone | PASS |
| 13 | Connecting screen: 7 s / 9 s; Try again, Choose another server, Restart | connecting / not answering; Restart only after the confirm | PASS |
| 14 | Stopped phone server that is starting (old error still set) | "Starting OpenCode on this phone…", progress, no "stopped", no filled button, no spinner button | PASS |
| 15 | Status priority: normal start; runaway + server lost; failed attempt; remote server; stale requests; live region | nothing / server outranks runaway, runaway back after / at once / named + Details / "This may be out of date" / one live region | PASS |
| 16 | Leftover process: `/root/projects/` (the phone's case), dismiss, same pid rescanned, new pid in FinanceHub | "OpenCode has been busy for 10 min…", no path / gone / still gone / "…busy in FinanceHub for 12 min…" | PASS |
| 17 | Text scale 2.0 at 320 dp with the status line and other projects | no overflow | PASS |
| 18 | `design_standard_test`: migrated files have no raw progress, `Card(` or `FilledButton`; every golden exists | clean | PASS |
| 19 | Goldens: 12 states × dark/light at 412×915 | match | PASS (24) |
| 20 | Tests 1-2, 4-6, 8, 10 (2), 11, 12, 13 against `4699191e` (the same test file, which only uses what existed there) | fail | FAIL as expected: 11 fail, 3 pass (rows 3, 7, 17) |
| 21 | Every test file under `test/` that imports a changed file (93 files, incl. l10n coverage and the glossary) | pass | PASS (1316 tests) |

Spec items → failing test on the old code: 1 (rows 1, 2), 3 (rows 5, 6), 4 (row
5), 8 (row 10, two tests), 9 (row 11), 10 (rows 12, 13). Also 2 (row 4) and 5
(row 8).

## Evidence

- `before-phone-1..5`: the owner's phone screenshots.
- `before-N-*.png` / `after-N-*.png`: the same controller state rendered by
  `tool/capture/work_tab_cleanup_test.dart` on `4699191e` and on this branch,
  412×915, dark, real fonts (Roboto, Space Grotesk, JetBrains Mono, Phosphor):
  1 restoring, 2 first load, 3 empty, 4 loaded (needs you, running, unreviewed,
  other projects), 5 not answering after 9 s, 6 end of a long list,
  7 connecting screen after 9 s, 8 stopped phone server, 9 starting after a
  stop (`before-9` shows the contradiction: "is stopped" over a disabled
  "Starting…" button).
- `test/goldens/connection_*_{dark,light}.png`, `test/goldens/work_*_{dark,light}.png`:
  the reviewed renders the test suite now holds the screens to.
- [tests-with-fix.txt](tests-with-fix.txt): the 12 key suites, 176 tests passed.
- [tests-without-fix.txt](tests-without-fix.txt): `test/work_tab_cleanup_test.dart`
  on `4699191e`: 11 failures.

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test test/work_tab_cleanup_test.dart test/work_tab_status_line_test.dart \
  test/design_standard_test.dart test/goldens/work_tab_golden_test.dart \
  test/return_brief_widget_test.dart test/other_projects_panel_test.dart \
  test/saved_server_connection_card_test.dart test/home_navigation_test.dart \
  test/workspace_stable_layout_test.dart test/work_tab_team_sessions_test.dart \
  test/projects_screen_test.dart test/release_blockers_test.dart
# Renders (after):
$F test --concurrency=1 tool/capture/work_tab_cleanup_test.dart
# The old code: export it, add the two old-compatible test files, run them.
mkdir /tmp/old && git archive 4699191e | tar -x -C /tmp/old
cp tool/capture/work_tab_cleanup_test.dart /tmp/old/tool/capture/
cp test/work_tab_cleanup_test.dart /tmp/old/test/
(cd /tmp/old && $F pub get &&
  $F test --concurrency=1 --dart-define=WORK_TAB_CAPTURE=before \
    tool/capture/work_tab_cleanup_test.dart &&
  $F test test/work_tab_cleanup_test.dart)   # 11 fail
# Goldens, deliberately:
$F test --update-goldens test/goldens/work_tab_golden_test.dart
```

## NOT proven

- Not viewed on a device: no emulator or phone run, no APK. On-device viewing
  belongs to the integrated emulator run.
- The chooser flash on the phone (`before-phone-1`) was reproduced in tests by
  the two paths found in code (a connection up with the saved folder not open;
  the newest project being opened on a fresh connection). The exact sequence on
  the owner's phone was not traced.
- The 8 s line was tested with a fake clock only; the real Termux health-check
  timeouts (30 s) were not exercised. Restart from the Work line runs the
  existing restart paths (`LocalServerControls.restart`, the in-app
  `BuiltinServerStarter.start`) and then `retryConnection`; neither ran here.
- The leftover-process watcher was tested with an injected scan; the Termux
  bridge script (`proc_name`, `cwd`) was not run. Its dismissal is in memory
  (for the app's lifetime), keyed by pid and name.
- Opening the Work tab before the connection is up (spec item 10, first bullet)
  is not done (decision D1).
- `ReturnBrief`'s "Review status unknown" now shows only in the project sheet
  (as before on Work when the project was known); servers without read state
  show no marks.

## Not migrated yet (next steps, standard §9)

- Work: Isolated task beside New conversation (owner decision: move it into the
  Recent section's menu so the pinned block is one full-width primary);
  conversation rows onto `KitRow` (they wrap titles to two lines at large text,
  which `KitRow` does not); `NudgeCard`, `TeamCard`, `OtherServersPanel` and the
  session menu sheets inside the Work tab.
- The shell's `ConnectionStatusBanner` on the other tabs (a `MaterialBanner`).
- Standard §9 steps 3-6: phone setup (start, progress, ready) and the "This
  phone" card, AI Team home and run, chat states, Settings.
- Opening the shell during a reconnect/resume (D1), which needs the controller
  to keep `hasConnectedServer` through a lifecycle resume.
