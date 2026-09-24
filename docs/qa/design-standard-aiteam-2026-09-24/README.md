# AI Team on the design standard (2026-09-24)

## Scope

Spec: [`docs/design/design-standard.md`](../../design/design-standard.md), migration
step 4 (AI Team home and run). The owner's complaint: "every screen looks different
and adhoc". Method as in [work-tab-cleanup-2026-09-24](../work-tab-cleanup-2026-09-24/README.md).

### Files migrated (all in `test/design_standard_test.dart`'s checked list)

| File | What changed | Goldens |
|---|---|---|
| `lib/ui/screens/team/team_states.dart` (new) | The whole-screen states the home, run and agent screens share: connecting ("Connecting to the team host…"), **not answering after 8 s** ("The team host isn’t answering", "The app keeps trying in the background.", Try again), and the errors as `KitStateView` pages: a one-line title per kind, the old sentence as the body, Try again as the primary, the raw error under Details. The one status line (`KitStatusLine`) for stale data / a failed refresh, with Try again. | `team_home_error`, `team_home_not_answering` |
| `team_home_screen.dart` | `KitScreen`: status line, one 2 dp loading bar, **one scroll view** (the host line, segments and planning cards now scroll with the rows), **Start a run** is the one primary, pinned below the list (was a floating button over it). Host line is a plain row (no pill). Empty states are inline `KitStateView`s without a second button. Run, gate and group rows are `KitRow`s. Filters and search are hidden while there are no runs at all. | `team_home_loaded`, `team_home_empty`, `team_home_error`, `team_home_not_answering` |
| `run_screen.dart` | App bar: one icon action (Refresh) and the overflow, which now holds **Technical details** and Stop run / Close batch (was two icons + overflow). Shared states; missing run is a `KitStateView`. Status line under the app bar. The needs-you box is a toned `KitPanel`. Work tab: groups are section headings with `KitRow` rows (were tinted cards). Timeline/agents/work empties are `KitStateView`. **Bug fixed:** the "N of M done" bar was never drawn (its segments were 0 dp tall); it is now 8 dp. | `team_run_overview`, `team_run_work` |
| `start_run_sheet.dart` | Field labels are `SectionLabel`s; Send is `KitButton.primary` (the spinner only while the tap is in flight; "Waking the planner…" is a line, not a spinner); planner off/missing is an inline `KitStateView` with the host guide; direct task: primary Send + tertiary host guide. The home's planning card is a toned `KitPanel` with tertiary Planner output / Dismiss. | `team_start_run` |
| `lib/ui/widgets/team_card.dart` (Work tab card) | `KitPanel` instead of `Card`; Open is **secondary** (tonal, full width) because the Work tab's one primary is New conversation; Refresh tertiary; error retry secondary. | `team_card` |
| `agent_screen.dart` | Shared states, status line, one icon action + overflow (Technical details moved there, key `team-agent-more`), `SectionLabel` sections, toned `KitPanel` for "Needs you", controls as one `KitActionBlock` (Message secondary, then Nudge, Pause/Resume as text buttons, Stop / Restart / Reassign under More, Stop and Restart destructive and still confirmed), `KitRow` rows. | `team_agent`, `team_agent_controls` |
| `agent_output_screen.dart` | Status row is a `KitStatusLine`; the jump button `KitButton.secondary`. | `team_agent_output` |
| `gate_sheet.dart` | One `KitActionBlock` per variant: Send / Mark done / Approve primary (Approve error-filled when the prompt is destructive), Deny secondary (destructive), Retry secondary on a failed run with Restart or reassign + Close as text buttons and View logs / Cancel work under More. Close is the last text button; **Technical details moved below the actions** (§3). Missing gate is a `KitStateView`. 16 dp rails. | `team_gate_sheet` |
| `work_sheet.dart` | Open session `KitButton.secondary`; missing item `KitStateView`; `SectionLabel` headings; 16 dp rails. | `team_work_sheet` |
| `merge_section.dart` | `KitPanel`; Merge primary (two-step unchanged), Approve request secondary, Review changes tertiary; title in sentence case ("Ready to merge", was "READY TO MERGE"); review sheet rows `KitRow`. | `team_merge` |

`policy_block.dart` and `work_graph.dart` needed no change (no forbidden parts, no
states or actions of their own).

### Kit additions (additive only)

- **`KitPanel`** (`lib/ui/kit/kit_panel.dart`, exported): a block of content the person
  works with: one surface, radius `AppTheme.radiusCard`, hairline border, 16 dp inside;
  a tone tints the border and washes the surface; optional icon + one-line title. It
  replaces hand-drawn containers of 10, 12, 14 and 20 dp radius.
- **`KitButton.primary(destructive: true)`**: error-filled, only where the whole sheet is
  that one confirmed act (approving a destructive confirmation gate).
- **`KitRow`**: `titleMaxLines` (a run's objective may take two lines),
  `supportingMaxLines` ("… · Finished 5h ago" keeps its end), `below` (the state word
  moves under the title at large text). Defaults unchanged.
- **`KitActionBlock`**'s More menu shows a destructive action in the error colour.

### Behaviour kept

- A finished run is under **Completed** as "Done · merged" with "Batch · convoy · 1 of 1
  done · Finished 5h ago" (now allowed two lines, so the age is never cut off).
- A finished run's work is listed in its Work tab (group "Done").
- "No recent runs." empty state; "Start runs from the host for now." when this phone
  cannot start a run (no button then).
- Every widget key the suites use, the two-step confirmations, receipts, dimmed stale
  data, capability gating (absent, never disabled).

### New strings (en + ar)

`teamUiStateUnreachableTitle` "Can’t reach the team host", `teamUiStateNotGasCityTitle`
"No AI team on this server", `teamUiStateStartingTitle` "The team host is starting",
`teamUiStatePlainHttpTitle` "AI Team can’t use this address",
`teamUiStateNotAnsweringTitle` "The team host isn’t answering". The body under "not
answering" reuses `workServerKeepsTrying`.

### Test expectations changed because the standard changed the UI

| Test file | Change | Standard |
|---|---|---|
| `team_controls_test` | Run overflow is always there: open `team-run-more`, then check Technical details / no Stop run (was "no menu at all"). Agent controls past two text buttons are opened via `kit-actions-more`. The empty Runs list no longer has its own Start a run; the test taps the pinned `team-home-start-run`. | §1, §2 |
| `team_run_screen_test`, `team_run_layout_test` | Open `team-run-more` before `team-run-details`. | §1 |
| `team_agent_screen_test` | Open `team-agent-more` before `team-agent-details`. | §1 |
| `team_home_layout_test` | The host line and segments menu scroll with the list: they are scrolled back into view before tapping (was "always on screen"). | §1 |
| `team_card_test` | Reads `KitButton` (was `FilledButton`/`TextButton`) for Open/Refresh enabled state. | §2 |
| `team_gate_answer_test` | Enabled state read from the Material button inside `KitButton`; Deny is tonal (was outlined); View logs / Cancel work checked under More; Cancel's red text check dropped (it is a menu item, red via the kit). | §2 |
| `team_merge_test` | Three `KitButton`s in the section (was 1 filled + 2 outlined); titles in sentence case. | §2, §7 |
| `team_activity_test` | The unblocks chip may be 288 wide (16 dp rails; was 20). | §1 |

## Builds

- Branch `ds/aiteam`, from `feat/phone-setup-v2` @ `dca366f1`. Code, tests, goldens and
  renders: commit `6fad0334`, the WIP save `d39e9408` (made when the session was killed
  by the machine running out of memory) amended with this record; the code is the
  same one the test runs used. No APK built (no Gradle builds on this machine).

## Devices

None. Widget tests and rendered images only (`flutter test`, pinned Shorebird Flutter
`91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`, on the PC). No emulator, no phone.

## Runs

| # | Step | Expected | Actual |
|---|---|---|---|
| 1 | Home while the probe never answers, 0 s / 7 s / 9 s (`team_design_standard_test`) | "Connecting to the team host…", one 2 dp bar, no spinner / same / "The team host isn’t answering" + Try again | PASS |
| 2 | Home when the host is unreachable | one state: title, body, Try again; "Connection refused…" only under Details, below the button | PASS |
| 3 | Home loaded | Start a run pinned in the kit's bottom block, no floating button, the list ends above it | PASS |
| 4 | Finished merged run under Completed (600 dp) | "Done · merged", "Batch · convoy · 1 of 1 done · Finished 5h ago" not cut | PASS |
| 5 | Run screen app bar | Refresh + overflow only; Technical details and Stop run inside the overflow | PASS |
| 6 | Run Overview progress bar | segments drawn 8 dp tall | PASS |
| 7 | Rows 1-6 on `dca366f1` (same test file) | fail | FAIL as expected: 5 of 6 fail (row 4 passes: the old row had room for the line) — [tests-without-fix.txt](tests-without-fix.txt) |
| 8 | `design_standard_test`: the 11 migrated AI Team files have no raw progress, `Card(` or `FilledButton`; every golden exists | clean | PASS |
| 9 | Goldens: `team_golden_test` (9 shots), `team_agent_golden_test` (2), `team_sheets_golden_test` (3), × dark/light, 412×915 | match | PASS (28) |
| 10 | Large text (2.5×, 320 dp, en/ar, LTR/RTL): home segments, filters, stale/empty/loading/error; run and work layouts; card | no overflow, everything reachable | PASS (existing layout suites) |
| 11 | Every test file under `test/` that imports a changed file (152 files incl. glossary, l10n coverage, design standard) | pass | PASS: 2040 passed, 7 skipped (existing), 0 failed — [tests-with-fix.txt](tests-with-fix.txt) |

## Evidence

Before (`dca366f1`) and after (this branch), 412×915, dark, real fonts:

| # | Shot | Before → after |
|---|---|---|
| 1 | Home loaded, Completed open | pill host chip and a floating Start a run over the list → plain host line, rows on `KitRow`, Start a run pinned below the list |
| 2 | Home empty | "No recent runs." with its own Start a run beside the floating one (two primaries) → teaching state, one pinned primary, no filters/search over nothing |
| 3 | Home error | centred red-circle sentence, a lone tonal Try again and "Report a bug" → titled state, body, full-width Try again, Details |
| 4 | Home connecting after 9 s | a spinner forever with "Connecting to the team host…" → "The team host isn’t answering", Try again |
| 5 | Run Overview | two icons + overflow, no progress bar drawn → one icon + overflow, the bar drawn, toned needs-you panel |
| 6 | Run Work tab | tinted card per state → section headings and plain rows |
| 7 | Start a run sheet | same form; labels and Send on the kit |
| 8 | Work tab team card | filled Open next to Refresh (a second primary on Work) → secondary Open, tertiary Refresh |
| 9 | Agent live output | status row and jump button on the kit |
| 10-11 | Agent top / controls | a wrap of six mixed tonal/outlined/red buttons → Message, two text buttons, More |
| 12 | Gate sheet (confirmation) | Approve / outlined Deny / Technical details / tonal Close → Approve / tonal Deny / Close / Technical details last |
| 13 | Work sheet | 16 dp rails, `SectionLabel` headings |
| 14 | Merge section | "READY TO MERGE", three buttons in a wrapping row → "Ready to merge", one stacked block |

Files: `before-N-*.png`, `after-N-*.png` here; 1-9 from
`tool/capture/aiteam_design_standard_test.dart`, 10-14 are the dark goldens of
`team_agent_golden_test` / `team_sheets_golden_test` rendered on both commits.
`test/goldens/team_*_{dark,light}.png` are the reviewed renders the suite now holds
the screens to.

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test -j 3 test/team_design_standard_test.dart test/design_standard_test.dart \
  test/goldens/team_golden_test.dart test/goldens/team_agent_golden_test.dart \
  test/goldens/team_sheets_golden_test.dart
$F test -j 3 test/team_home_test.dart test/team_home_layout_test.dart \
  test/team_run_screen_test.dart test/team_controls_test.dart test/team_card_test.dart
# Renders (after):
$F test --concurrency=1 tool/capture/aiteam_design_standard_test.dart
# The old code: export it, add the scene fixture, the capture and the new test.
mkdir /tmp/old && git archive dca366f1 | tar -x -C /tmp/old
cp test/support/team_golden_fixture.dart /tmp/old/test/support/
cp tool/capture/aiteam_design_standard_test.dart /tmp/old/tool/capture/
cp test/team_design_standard_test.dart /tmp/old/test/
(cd /tmp/old && $F pub get &&
  $F test --concurrency=1 --dart-define=AITEAM_CAPTURE=before \
    tool/capture/aiteam_design_standard_test.dart &&
  $F test test/team_design_standard_test.dart)   # 5 fail
# Goldens, deliberately:
$F test --update-goldens test/goldens/team_golden_test.dart
```

## NOT proven

- Not viewed on a device: no emulator, phone or APK (machine rules). On-device viewing
  belongs to the integrated emulator run.
- The 8 s "isn’t answering" state was tested with a probe that never answers and the
  fake clock; a real slow Gas City probe (6 s timeout) was not exercised. Its Try again
  calls `refresh()` (the controller's `retry()` only acts after a failure).
- Arabic was checked by the existing layout suites (2.5×, RTL), not by a golden.
- Row 4 passes on the old code at 600 dp (the old row was wider); the two-line change
  matters at 412 dp, shown in the renders, not asserted there because the test font's
  widths differ from the real font's.

## Not migrated yet

- `lib/ui/widgets/builtin_team_section.dart` (another agent's), and the AI Team
  onboarding/plugins screens (`team_discovery_card`, `team_host_form`, plugin screens):
  not in step 4's list.
- Shared team widgets used inside these screens keep their own look: `TeamAgentRow`,
  `TeamReceiptChip`, `TeamCycleStrip`, `TeamPolicyBlock` chips, `TeamIdentityRow`, and
  the run Overview's count chips and usage chip.
- The segmented control, filter chips and search field on the home are Material
  controls the kit has no part for yet.
- The home's host line is still two lines at the top of the list; moving it into the
  app bar subtitle would save a row but changes the tests of TEAM-115.
