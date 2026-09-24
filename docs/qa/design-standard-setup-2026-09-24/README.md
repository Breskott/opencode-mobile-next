# Design standard step 3: phone setup, "This phone", and the Work tab leftovers (2026-09-24)

## Scope

Spec: [`docs/design/design-standard.md`](../../design/design-standard.md) §9 step 3
(phone setup start, progress and ready, and the "This phone" card), plus the Work tab
parts that
[work-tab-cleanup-2026-09-24](../work-tab-cleanup-2026-09-24/README.md) listed as not
migrated. The owner's complaint behind the standard: "every screen looks different
and adhoc". Screen behaviour follows
[`docs/design/phone-setup-v2-2026-09-24.md`](../../design/phone-setup-v2-2026-09-24.md);
where the standard asks for something else, the decisions below say so.

### Migrated files (now in `test/design_standard_test.dart`)

| File | What it is now |
|---|---|
| `lib/ui/screens/phone_setup/phone_setup_start_screen.dart` | Screen A as one `KitStateView` page: icon, title, promise, "Includes …", **Set up**, **Customize** (tertiary), then **Other ways** as a Details-style toggle over `KitRow`s. The screen's one loading bar shows until the job on disk has been read. |
| `lib/ui/screens/phone_setup/phone_setup_customize_sheet.dart` | 16 dp rails; **Done** / **Add** is a `KitButton.primary`, with the totals line above it as the reason it is off. |
| `lib/ui/screens/phone_setup/phone_setup_progress_screen.dart` | Screen B hosts `SetupProgressView` as the page. |
| `lib/ui/widgets/setup_progress_view.dart` | One `KitStateView`: title, note, one overall bar with one line under it, the checklist as `KitRow`s with a `KitStatusMark`, **Continue setup** (primary) or **Cancel** (destructive tertiary), and the log under **Details**. |
| `lib/ui/screens/phone_setup/phone_setup_ready_screen.dart` | Screen C as one `KitStateView`: the check draws in inside the state's circle, then the name field, **Create** full width, and **Open an existing folder** (tertiary). |
| `lib/ui/screens/phone_setup/phone_setup_welcome_entry.dart` | The welcome's setup line as an inline `KitStateView` on the welcome's own rails. |
| `lib/ui/widgets/phone_server_card.dart` | "This phone" as a `KitRow` (name; version and size; the status at the end) over one `KitActionBlock` (one primary, tertiary Stop, Continue setup and Show log, and the card's own ⋯ menu). |
| `lib/ui/screens/workspace_screen.dart` (step 2 leftovers) | Conversation rows on `KitRow` (titles wrap to 2 lines, the facts line to 2, or 3 at large text); the Archived row and the header context rows on `KitRow`. |
| `lib/ui/widgets/team_card.dart` | The AI Team is a section (label, host line, rows) instead of a bordered card. **Open** is secondary and **Refresh** tertiary, so New conversation stays the Work tab's one filled button. Its loading, empty and error states use the kit. |
| `lib/ui/widgets/nudge_card.dart` | A `KitStatusLine`, not a bordered box. |
| `lib/ui/widgets/other_servers_panel.dart` | `SectionLabel` and `KitRow`s; no spinner. |
| `lib/ui/widgets/connection_status_banner.dart` | The shell's line on the other tabs is a `KitStatusLine`, not a `MaterialBanner`. It has no spinner; **Try again** is its action and **Details** is in ⋯. The details sheet uses `KitActionBlock`. |

### Kit additions (additive only; existing callers unchanged)

| Part | Addition | Why |
|---|---|---|
| `KitRow` | `titleMaxLines`, `supportingMaxLines`, `titleKey`, `supportingKey`, `padding` | Conversation titles wrap. App words wrap at large text instead of being cut to a few letters. Rows inside a state or a card sit on its rails. |
| `KitAction` | `working` | Shows the kit's spinner for a tap in flight (Set up, Create, Continue on the welcome). It never stands in for a status. |
| `KitActionBlock` | `menu` | A caller's own overflow menu (the card's ⋯, with its keys and the red Remove) sits where the built More menu goes. |
| `KitProgress` | `tone`, `semanticsLabel` | A stopped job's bar is muted and a failed one uses the failure tone. The bar keeps its "Setup progress" label. |
| `KitStateView` | `content`, `footer`, `detailsChild`, `iconChild`, `padding` | `content` holds what a state is made of (checklist, name field, includes line); `footer` holds the ways in that are less common. `detailsChild` puts a live log under Details, and `iconChild` puts the drawn check inside the circle. `padding` lets an inline state sit on a host's rails. |
| `KitStatusMark` (new, `kit_status_mark.dart`) | Waiting, working, done and failed marks for a step's row | Setup's checklist (§6). |
| `KitStatusLine` | `dismissKey`, `dismissTooltip`, `controlsTogether` | The pin tip keeps its keys and keeps its controls on one row at large text. |

`docs/design/design-standard.md` §6 now names `KitStatusMark` and when titles may
wrap. New string: `phoneServerCardRemoving` ("Removing" / «جارٍ الإزالة»).

### Decisions where the standard and the spec differ

- **The illustration on screen A** (the phone with a spark) is replaced by the
  state's icon in a tonal circle (§3 slot 1). Every state screen now opens the same way.
- **The per-row indeterminate line on screen B** is gone. §4 allows one bar per screen,
  so the overall bar is it. A stage-only row says its stage, and its mark spins.
- **Screen B titles a stopped or failed job "Setup didn't finish"** and the body says
  why (interrupted, cancelled, the job's error). Before, it kept "Setting up OpenCode on
  this phone" over a stopped bar (§3: the title never contradicts the progress).
- **Open on screen A** changes the state to "Starting OpenCode on this phone…" with
  progress. Before, the filled button showed a spinner for the whole start (§2).
- **The card** has no Start, Stop or menu while it starts, stops or is removed: the
  status word says so ("Starting", "Stopping", "Removing") and its small bar is gone
  (§2, §4). A setup that stopped part way makes **Continue setup** the primary when
  nothing else is.
- **Create on screen C** stacks full width under the name instead of sitting beside it
  (§2). The "or" before Open an existing folder is gone, because the tertiary button stands on its own.
- **"Show details" is the kit's "Details"** on screen B (§3 names the row).
- **The AI Team's run rows, segmented bar, agent dots and cycle strip** keep their own
  layout inside the section, not `KitRow`: the team tests look up their exact texts,
  and the state word stays at the end of the row.
- **The pin tip is a status line.** When the connection line also shows, the Work tab
  has two lines for as long as the one-time tip stays up.
- **The shell line on the other tabs** shows at once. The Work tab's 8 s rule is not
  added there.

## Builds

- Branch `ds/setup-and-lists`, from `feat/phone-setup-v2` @ `dca366f1`.
  - `ea43d5c0`: `KitRow` wrap parameters.
  - `b1e8b593`: phone setup and the card, goldens, renders, tests.
  - `ds/work-leftovers` (`1b4a72a7`, `3a8aaa2d`, `0baf2c46`, done in a parallel
    worktree from `ea43d5c0`), merged as `ef146c96`.
  - This record is the commit after that.
- No APK built.

## Devices

None. Widget tests and rendered images only (`flutter test`, pinned Shorebird Flutter
`91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`, on the PC). No emulator, no Gradle.

## Runs

| # | Step | Expected | Actual |
|---|---|---|---|
| 1 | Start screen, ready, tap Open while the server start is held | "Starting OpenCode on this phone…", one bar, no filled button, no spinner | PASS |
| 2 | Card, stopped, tap Start while the start is held | status "Starting", no Start button, no filled button, no bar | PASS |
| 3 | Progress screen, interrupted job and cancelled job | "Setup didn't finish", never "Setting up OpenCode on this phone"; Continue setup | PASS (2) |
| 4 | Progress screen, a step that reports only its stage | the stage in the row, exactly one bar on the screen | PASS |
| 5 | Ready screen at 412 dp | Create below the name field, the same width | PASS |
| 6 | Rows 1-5 on `dca366f1` (the same test file) | fail | FAIL as expected: 6 of 6 ([tests-without-fix.txt](tests-without-fix.txt)) |
| 7 | `design_standard_test`: the 15 migrated files have no raw progress, `Card(` or `FilledButton`; every golden exists | clean | PASS. On `dca366f1` it fails: 6 of the 7 setup files still draw 27 raw parts, and their goldens are missing |
| 8 | Goldens: 13 setup and card states and 7 Work states (new or changed) × dark/light at 412×915 | match | PASS (`phone_setup_golden_test` 26, `work_parts_golden_test` 8, `work_tab_golden_test` 24) |
| 9 | Setup behaviour suites (start, customize, progress, ready, welcome line, card, notification route), including 320 dp at 2.5× text, Arabic and RTL, reduce motion, live regions | pass | PASS |
| 10 | Work suites (rows, return brief, team card, team home, nudges, other servers, the codex and v2 banners, chat live events), including text scale and accessibility | pass | PASS |
| 11 | Every test file that imports a changed file on the merged branch (139 files, with l10n coverage and the glossary), `-j 3` | pass | PASS: 1858 passed, 7 skipped ([tests-with-fix.txt](tests-with-fix.txt)) |

Expectations updated where the standard changed the UI:
- `phone_setup_progress_screen_test`: the stage line is gone (§4). "Show details" is
  now "Details" (§3), and the Details toggle key is now the kit's. The failure bar
  uses the kit's failure tone. Continue, Cancel and Details are scrolled into view on
  the 800×600 test surface, because the page is one centred state.
- `phone_setup_start_screen_test`: Other ways is a toggle, not a `ListTile`. The Add
  button's `FilledButton` is found inside the `KitButton`.
- `phone_server_card_test`: the detail is the row's supporting line, a `Text.rich`.
- `return_brief_widget_test`: row menus are found under `KitRow`.
- `team_card_test`: reads the button inside the keyed kit button.
- `chat_live_events_test`: opens the line's ⋯ before Details (§5: one visible action).

## Evidence

- `before-NN-*.png` / `after-NN-*.png`: the same state rendered by
  `tool/capture/design_standard_setup_test.dart` (states in
  `test/support/phone_setup_scenes.dart`) on `dca366f1` and on this branch, 412×915,
  dark, real fonts:
  - 01 start, first time; 02 start, running 42%; 03 start, stopped 50%; 04 start, ready; 05 start, Termux found, Other ways open;
  - 06 Customize;
  - 07 progress running; 08 progress failed (no internet);
  - 09 ready;
  - 10 the welcome's setup line;
  - 11 card running (not connected); 12 card stopped; 13 card setting up.
- `before-work-N-*.png` / `after-work-N-*.png`: `tool/capture/design_standard_work_test.dart`:
  - 1 rows (needs you, running, unreviewed, other projects); 2 the same rows at 2× text;
  - 3 the AI Team section; 4 the pin tip; 5 On your other servers;
  - 6 the shell line on Inbox.
- `test/goldens/{setup_*,phone_card_*,work_team,work_nudge,work_other_servers,shell_reconnecting}_{dark,light}.png`
  (new) and `work_loaded`, `work_not_answering`, `work_runaway` (regenerated): the
  reviewed renders the suite now holds these screens to.
- [tests-with-fix.txt](tests-with-fix.txt), [tests-without-fix.txt](tests-without-fix.txt),
  [tests-work.txt](tests-work.txt) (the Work half on its own branch).

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test -j 3 test/design_standard_setup_test.dart test/design_standard_test.dart \
  test/goldens/phone_setup_golden_test.dart test/goldens/work_parts_golden_test.dart \
  test/goldens/work_tab_golden_test.dart test/phone_setup_start_screen_test.dart \
  test/phone_setup_progress_screen_test.dart test/phone_setup_ready_screen_test.dart \
  test/phone_setup_welcome_entry_test.dart test/phone_server_card_test.dart \
  test/team_card_test.dart test/nudge_moments_test.dart \
  test/codex_connection_banner_test.dart test/return_brief_widget_test.dart
# Renders (after):
$F test --concurrency=1 tool/capture/design_standard_setup_test.dart
$F test --concurrency=1 tool/capture/design_standard_work_test.dart
# The old code: export it, add the scenes, the capture tools and the new tests.
mkdir old && git archive dca366f1 | tar -x -C old
cp test/support/phone_setup_scenes.dart old/test/support/
cp tool/capture/design_standard_*_test.dart old/tool/capture/
cp test/design_standard_setup_test.dart test/design_standard_test.dart old/test/
(cd old && $F pub get &&
  $F test --concurrency=1 --dart-define=SETUP_CAPTURE=before \
    tool/capture/design_standard_setup_test.dart &&
  $F test test/design_standard_setup_test.dart test/design_standard_test.dart)  # 8 fail
# Goldens, deliberately:
$F test --update-goldens test/goldens/phone_setup_golden_test.dart
```

The Work "before" renders need the Work fixture hooks too; see the header of
`tool/capture/design_standard_work_test.dart`.

## NOT proven

- Not viewed on a device: no emulator or phone run and no APK. Viewing it on a device
  belongs to the integrated emulator run.
- The real engine, the foreground service and a real server start were not run; the
  start, stop and removal paths ran against fakes (a held `startServer`, a fake engine).
- The welcome line was rendered in a stand-in for the welcome (the same padding and
  headline), not inside `ServersScreen`. Its own tests do run inside `ServersScreen`.
- The card was rendered in a stand-in Servers list and not in the switcher sheet. The
  switcher tests pass.
- The chat's nudge above the composer and the chat's connection line use the migrated
  widgets. They are covered by their tests but not rendered.

## Not migrated yet

- The row menu sheets inside Work. Isolated task beside New conversation is still
  waiting for the owner's decision.
- `TeamCycleStrip` and the team section's own run rows (see decisions).
- The Inbox "Status incomplete" state (visible under the shell line in `after-work-6`).
- Settings → Servers around the card (`servers_screen.dart`: `Card.filled` rows, its
  own `LinearProgressIndicator`) and the first-run welcome around the setup line:
  §9 step 6.
- §9 steps 4 to 6: AI Team home and run, chat states, Settings.
- Now-unused strings are left in the ARB files for the coordinator to prune:
  `phoneSetupReadyOr`, `phoneSetupReadyCreating`, `e7BannerTokenRejected`,
  `e7BannerPasswordChanged`, `e7BannerReconnectingServerSemantic`.
