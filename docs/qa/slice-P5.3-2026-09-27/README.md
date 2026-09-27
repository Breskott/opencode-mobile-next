# slice-P5.3 Running on this phone (2026-09-27)

Finish line: Termux's "Running now" becomes **Running on this phone**. It
lists what runs by kind: OpenCode server, AI Team, Claude Code, dev services,
terminals and helpers. Each row has a mark and a label. Busy and Idle are
measured, memory is shown in MB, the budget line reads "18 of 32 background
processes", and each kind has one stop with one question.
Non-goal: no automatic cleanup (P6).

Builds on the Codex feasibility records
[codex-p53](../codex-p53-2026-09-27/README.md) and
[codex-x53](../codex-x53-2026-09-27/README.md). Only the parts those records
leave feasible were built, as listed below.

## What changed, per page

**termux-processes → Running on this phone** (`lib/ui/screens/termux_processes_screen.dart`, `lib/termux/processes.dart`)
- The page is still one list, ordered by urgency (owner rule): left-behind
  processes first, then the kinds in a fixed order. Within a kind, busy
  processes come first, then the one using the most memory. There are no
  section headers.
- The kind comes from the scanner's owner group first (server, team). If
  that does not settle it, the name and command decide: Claude Code, dev
  service, terminal, helper. The Termux app's own process is called "Termux
  app". It is never offered a stop and does not count against the budget.
- Each row starts with the kind's mark and then the kind in words ("Dev
  service · Idle · 293 MB · running 2 h 0 min"). A left-behind process gets
  a warning mark and its reason ("Helper · Parent gone · Busy · …"). A
  protected process gets a lock and the words "Protected · control it from
  This phone". State is never shown by colour alone.
- **Busy/Idle** compares two readings of the same process (same pid and
  name, still running and older than at the first reading). It counts as
  busy at 2 s or more of processor time and at least 25 % of the wall time
  between readings. The second reading comes 4 s after the page opens. The
  first reading shows no activity word. `ps`'s lifetime average (the old
  "CPU 108 %") and the processor time now sit under Details.
- Memory is shown in whole MB. If the reading is missing, it is left out
  rather than shown as 0.
- **Budget line:** "{n} of 32 background processes". The note under it
  explains the 32: Android 12 and later may stop the oldest processes once
  all apps together run more than 32. Past 32 the note changes to "More
  than 32: Android may stop the oldest of these at any time." The figure is
  **advisory**, as codex-p53 asked. The count covers everything Termux
  started, except the Termux app. Other apps' processes count toward
  Android's limit but are not visible here. The owner may also have lifted
  the limit (the ADB tip on the team phone sheet).
- **One stop for each kind:** in the menu of every row whose kind has two or
  more stoppable processes, e.g. "Stop all 2 AI Team processes". One
  question names every process ("gc, opencode acp: each gets a polite stop,
  then a forced one after 5 seconds") and says what the stop costs for that
  kind (team work lost / restart from AI Team; dev services come back with
  the next build). Only the processes the question named are sent. The
  Termux script checks each one again and refuses any that has ended or is
  protected. The bulk stop for left-behind processes now works the same
  way, with the exact pids instead of the `orphans` group.
- Details sheet: the subtitle is the kind (the pid line moved under
  Details). It shows what the process is doing (Busy/Idle, MB, running
  time). The fold adds average processor use and processor time. The Termux
  app's own row has no Stop.
- Errors: "Couldn't read what's running", with "Termux did not answer.
  Open Termux, then try again." The bridge or parser text appears only
  under Details, through `productErrorDetails`. A failed refresh or stop
  gets its own plain words.

**This phone** (`lib/ui/screens/this_phone_screen.dart`, `lib/ui/widgets/termux_phone_tools.dart`)
- The Termux "Running on this phone" row shows the budget line as its
  summary.
- **Owner review fix:** if the list cannot be read, the row is left out of
  the row group entirely. The dead "Running now · Not available right now"
  row is gone, and no stray hairline is left behind (the page reads the
  list itself; the row is a plain `PhoneProcessesRow`). The Storage row is
  now its own `TermuxStorageRow`.
- On the in-app host there is still no row (see blockers).

**Copy:** "Running now" (processes) is now "Running on this phone"
everywhere: the title, the storage "in use" line and its button, and the
search entry keywords. Work's conversation sheet keeps "Running now"
(conversations), so the two are no longer confused. That meets the
acceptance "running-work-sheet keeps conversations; this tool keeps
processes"; running_work_sheet.dart is unchanged.

**tools.sh** (`lib/termux/bridge.dart`): `procs-stop` also accepts a
comma-separated pid list. Each pid is checked again (not_found / protected).
The tools argument check allows commas and up to 400 characters, still
single-quoted.

**Coordinator extra: no raw error text in phone setup.** In
phone_setup_termux_job_screen.dart, Termux, native and unknown failures now
show plain words (`productErrorText`, `e7SetupInspectTermuxFailed`,
`termuxGuideCopyOpenFailed`). The raw text goes to the setup view's Details
fold through `logTail`. In phone_setup_ready_screen.dart and
phone_setup_start_screen.dart, `connection.lastError`, the location error
and `BuiltinLinuxException` go through `productErrorText`. Their allowlist
entries were removed from `test/no_raw_error_text_test.dart`.

## Tests

- New: script `procs-stop` with a pid list (real `sleep` processes; a
  bystander stays alive; gone and protected pids are refused); argument
  quoting; the six kinds on the owner's fixture plus Claude Code and the
  Termux app; budget count; MB rounding and unknown memory; Busy/Idle from
  two readings (unknown on first reading, reused pid or other name); screen
  order, lines, measured Busy and budget text; the kind stop names every
  target and sends exactly `400,402`; a kind with one process has no second
  stop; past 32 said in words; This phone shows the budget row and, with an
  unreadable list, no row and dividers = children − 1.
- Updated: bulk orphan stop sends `200,500`; details subtitle; plain error
  body; storage "in use" copy; the ready screen's "cannot create" test now
  expects plain words; This phone's "Update not offered" used an old pin
  (it failed at base 601b4ec1, fixed by using the runtime's pin).
- Run: test/termux_processes_test.dart, test/this_phone_screen_test.dart,
  test/termux_storage_test.dart, test/search_index_test.dart and the phone
  setup screen tests all pass, except failures that also fail at base
  (listed below). `flutter analyze` is clean.
- Failures that also fail at base 601b4ec1 (compared in a second worktree),
  not from this slice: kit_ratchet G17/G21 (other files);
  no_raw_error_text on team_phone_onboarding.dart (another owner);
  ui_glossary G11/G28 (none of this slice's keys; the baseline entry
  termuxProcsGroupOpenCode was renamed to termuxProcsKindOpenCode, same
  count); oc2_server_discovery, phone_setup_start_screen (320 dp and
  motion), builtin_server_autostart, first_run_welcome (26 in all in that
  set); and 38 goldens in screen_phone_1/2 and team_phone_v2 that differ
  slightly from their masters at base.
- Goldens regenerated: `screen_phone_2` "running now *" (plus a new "stop a
  kind" sheet) and `team_v2_this_phone_installed_light` (the dead row is
  gone). Other stale goldens were left for their owners.

## Images

`contact_sheet.png` shows before and after:
- running phone: `before_running_phone_dark.png` / `after_running_phone_dark.png`
- running wide window: `before_running_wide_dark.png` / `after_running_wide_dark.png`
- details sheet: `before_running_details_dark.png` / `after_running_details_dark.png`
- could not read: `before_running_error_dark.png` / `after_running_error_dark.png`
- This phone in Termux, with the list unreadable: `before_this_phone_termux_light.png`
  (dead "Running now · Not available right now" row) / `after_this_phone_termux_light.png` (no row, no stray line)
- the new kind stop: `after_running_stop_kind_dark.png`

## Blockers kept unavailable (AGENTS rule 2)

- **In-app host inventory:** there is no callable process list for the
  app-owned Linux (codex-p53). This phone on the in-app host still has no
  Running on this phone row. No shell-based scanner was built.
- **Background hours used today** (codex-x53): there is no native dataSync
  accounting, so nothing is shown and nothing assumes unbounded lifetime.
- **Identity:** stops are still by pid. The script re-reads and
  re-classifies, but it does not check start time, so a pid reused within
  seconds of the question is a residual risk. The same was already true of
  the single stop.

## Still needs a device

The emulator proof asked for by the slice has not been done: server, team
and a terminal running in Termux, a screenshot, and a TalkBack walk of the
kind marks, Busy/Idle words, budget line and stop labels. Kit menu items
and sheet buttons carry the 48 dp targets; this was not measured on a
device. Also still to check on a phone: the 4 s second reading, and whether
`ps` on the phone reports the Termux app as `com.termux`.

Implemented: yes (Termux host). Enabled: yes. Verified: widget, script and
golden tests only. Committed: local, `[skip ci]`. Deployed/released: no.
