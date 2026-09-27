# slice-P8.4: Failed jobs carry their log (2026-09-27)

Finish line: a failed setup row, a failed team job and a failed dev service
offer Report with the job's log (KitLogPanel excerpt, redacted). Non-goal: no
automatic upload.

Builds on Codex's backend (`docs/qa/codex-p84-2026-09-27/`,
`FailedJobReport`) and P8.2's Report a problem page (`openReportProblem`).
Codex's two test files had never run (read-only SDK cache there); they pass
here (13 tests).

## What changed, per page

| Page / part | Before | After |
|---|---|---|
| Gate sheet, Run failed (`team-gate-sheet`) | Ask the team to fix it, retry, the agent's page, View logs, Stop work (under More) | **Report this failure** as a tertiary action (under More when the agent's page and View logs are shown; beside them otherwise), present whenever the sheet can report, even with no control capability. The tap watches the failed agent's output for up to 3 s (paired `watchAgentOutput`/`unwatchAgentOutput`), then `FailedJobReport.teamGate` attaches the log **only** when the tail's session is the failed work item's session (never a reused agent's newer session). The gate's `workId` wins over the displayed stuck item. The sheet closes and Report a problem opens, titled as the sheet is ("Sync engine stopped"). |
| Development services, logs sheet (`development-services-logs`) | the log panel, Stop/Restart while running; nothing for a failed run | For a confirmed failed run (nonzero exit, timeout, unrequested kill; `model.failedReport(id) != null`) the log panel's header carries **Report this failure** (`KitLogPanel.headerAction`), off while the model is busy. The tap re-reads the log (`readLogs`), and only a successful, still-owned read opens the report; a failed read keeps the sheet open with its error and Refresh. Running, stopped-on-request and unknown runs offer nothing. |
| Settings › Plugins › AI Team on this phone (`BuiltinTeamSection`) | failure notice + folded details | A failed turn-on/start job's notice carries **Report this failure**, captured at the tap (`FailedJobReport.teamSetup`) before Turn on/Retry clears it. Quick-action errors (stop, bring in) are not jobs and offer nothing. |
| Report a problem (`app-diagnostics`) | an attached error showed as "Attached: {title}" | With a failed job attached, a **KitLogPanel** "Log of the failed job" (Failed, copy, wrap) shows the redacted excerpt under the attached line; a job that kept no log says "No log was kept for this job, so none is attached." |
| Review report (`report-problem-preview-sheet`) | description, error, environment, recent diagnostics | The job log leads the Diagnostics section ("Failed job log (last lines)", or "Failed job log: none was kept"), scrubbed by `problemReportScrub` (KitRedact, server addresses, long tokens) on top of `FailedJobReport`'s own redaction, and always included (it is part of the attached failure, not a "recent diagnostic"). A long log goes to the clipboard through P8.2's existing link-length path. |

## Reusable parts (for the setup owner)

- `KitReport.log` (`lib/ui/kit/kit_notice.dart`): the failed job's redacted
  excerpt; `''` = job without a log; null = not a job.
- `FailedJobReport.toKitReport({title})` (`lib/diagnostics/failed_job_report.dart`).
- `openFailedJobReport(context, report, {title})` and
  `failedJobReportAction(context, capture: ..., {title, before, key})`
  (`lib/feedback/bug_report.dart`): the action is null when nothing is
  reportable now (no dead button) and re-captures at the tap.
- `KitStep.report` (`lib/ui/kit/kit_checklist.dart`, documented in
  `docs/ux-system/kit-api/KitChecklist.md`): "Report this failure" on the
  failed row only (asserted), a tertiary button under the row's words after
  Try again.

### Setup call sites still to wire (owned by the P1.2 agent, not edited here)

1. `lib/ui/widgets/setup_progress_view.dart`, the `KitStep` built for each row
   (around line 281): for `row.state == ComponentState.failed` add
   `report: failedJobReportAction(context, capture: () => FailedJobReport.setup(widget.progress, componentId: row.id))`.
   Better: capture from the engine's live value
   (`engine.progress.value`) if the view gains access to it, so the tap
   captures before a retry resets progress. This is the acceptance's "v2
   failed row".
2. Same file, a job that failed between components (no failed row; the
   `setup-progress-job-error` body): offer the whole-job report,
   `FailedJobReport.setup(progress)` without `componentId`, e.g. as the
   log panel's `headerAction` (`KitLogPanel(headerAction: ...)` at line ~312).
3. Its hosts pass nothing new: `phone_setup_progress_screen.dart:154` and
   `phone_setup_termux_screen.dart:389` (the Termux path builds its own
   `SetupProgress`, whose `logTail` is the Termux log).

## Tests

Pinned Flutter 3.47.1, `--no-pub`.

| Run | Result |
|---|---|
| New `test/failed_job_report_ui_test.dart` (9): report text (log leads, scrubbed, none-kept line, plain errors unchanged), `toKitReport` session attribution, page panel + preview, page none-kept, gate Report with the failed session's output, gate Report without output capability, AI Team failed start, dev service failed run (running offers nothing; failed opens with this run's log) | all pass |
| New `kit_checklist_test` case 12 (report on the failed row only, under Try again, asserted elsewhere) | pass |
| Codex's `test/failed_job_report_test.dart`, `test/development_services_failed_report_test.dart` | pass (first run) |
| Existing files for changed code: `app_diagnostics_screen_test`, `problem_report_test`, `bug_report_test`, `team_gate_answer_test`, `team_activity_test`, `development_services_screen_test`, `development_services_test`, `builtin_team_section_test`, `revamp/screen_team_1_test`, `kit_ratchet_test`, `ui_glossary_test`, `l10n_coverage_test`, `architecture_boundaries_test` | failures identical to base `055f47a7` (temporary second worktree), except one intended change: `team_gate_answer_test` "no control capability" expected no More; Report now sits under More there, and the test says so. Gate messages of `kit_ratchet`, `ui_glossary`, `l10n_coverage`, `architecture_boundaries` diffed against base: identical. |
| `flutter analyze` | No issues found |

Pre-existing on base (untouched): `architecture_boundaries` ARCH-1,
`builtin_team_section` "turn-on waits for the store prepare…",
`development_services_screen` "unsupported profile…", `kit_ratchet` G17/G21,
`team_activity` and `team_gate_answer` 320dp layout cases, `ui_glossary`
G11/G28.

Goldens added: `test/revamp/goldens/system_report_problem_job_log_{dark,light,1280x800_dark}.png`.

## Images

| | Before | After |
|---|---|---|
| Gate sheet Run failed, More open (phone / wide) | `before_team_gate_run_failed_more_dark.png`, `..._1280x800_dark.png` | `after_team_gate_run_failed_more_dark.png`, `..._1280x800_dark.png` |
| Dev service failed run, logs sheet (phone / wide) | `before_development_services_failed_log_dark.png`, `..._1280x800_dark.png` | `after_development_services_failed_log_dark.png`, `..._1280x800_dark.png` |
| AI Team failed start | `before_builtin_team_failed_start_dark.png` | `after_builtin_team_failed_start_dark.png` |
| Report a problem with a job log (phone / wide) | P8.2's page (no log): `../slice-P8.2-2026-09-27/after_system_app_diagnostics_dark.png` | `after_system_report_problem_job_log_dark.png`, `..._1280x800_dark.png` |
| Review report with the log (phone / wide) | P8.2's `../slice-P8.2-2026-09-27/after_system_report_problem_preview_dark.png` | `after_system_report_problem_preview_job_log_dark.png`, `..._1280x800_dark.png` |

Gate/dev-service/AI Team before-after images come from a temporary capture
test run on this branch and on base (not committed).

## Needs a device

1. The programme's proof: force a setup failure (airplane mode mid-download)
   then Report — needs the setup wiring above first (P1.2).
2. A real Gas City run failure: Report this failure waits for the agent's
   `/session/{id}/stream` and attaches it only when the failed bead's session
   is the agent's current one. A recycled session yields "none was kept".
3. A dev service that exits nonzero on a real server: Report re-reads the
   managed shell output before opening.

## State

| State | |
|---|---|
| Implemented | Gate sheet, dev services, AI Team section, Report page/preview, kit slots |
| Enabled | yes, where wired; setup v2 row not wired (owned elsewhere) |
| Verified | unit/widget tests, goldens, analyzer |
| Committed | branch `revamp/slice-P8.4` |
| Deployed / Released | no |
