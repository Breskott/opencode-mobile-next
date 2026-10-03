# P8.4 failed jobs carry their log — backend handoff

Date: 2026-09-27. Worktree: `oc_app-codex-p84`, branch `codex/p84`.
Base: `dcf05c5efbf82781bcfb97b629f5cda86ead2382`.

Finish line: expose a redacted report snapshot for failed setup rows, team jobs,
Run failed gates and confirmed failed dev services, ready for the UI owner.
Non-goals: UI edits, automatic upload, new log persistence, native changes,
release/signing, pushes, or new server endpoints.

Read set: AGENTS.md; STANDARDS.md sections 2, 3, 13, 15; setup progress and
engine; built-in team job/exception; orchestration gate/work/output contracts;
existing dev-service state/store/gateway; KitRedact and report diagnostics.
Write set: `lib/diagnostics/failed_job_report.dart`,
`lib/state/development_services.dart`, the two new behavior tests below, this
QA directory, and `COMMIT_MSG.txt` if git metadata cannot be written.
After: existing setup/team/managed-shell contracts and KitRedact, present here.
Acceptance for this backend unit: failed-only snapshots, correctly attributed
bounded logs, redaction before excerpting, no upload/persistence, documented UI
integration. Full product acceptance still belongs to the later UI unit.

## Feasibility

Source contracts are available; no live server or credentials were used.

- Setup v2 already exposes `SetupProgress.logTail`, `jobId`, component errors
  and failed state. The native engine supplies a job tail, not per-step logs.
- Built-in team startup failures carry script/service detail in
  `BuiltinTeamException`; `BuiltinTeamJob.error` retains it until cleared or
  retried. Generic exceptions carry only their error text.
- Team output is a session transcript, not a durable run-specific log API.
  `WorkItem.sessionId` and `AgentOutputTail.sessionId` supply attribution.
  `OrchestrationAgentOutputGateway.agentOutput` is implemented by Gas City
  (`gascity_gateway.dart`, `/session/{id}/stream`); 404 ends output.
  `lib/orchestration/client/http.dart` explicitly strips credential headers on
  reads. This feature adds no authentication or credential reuse.
- Dev services already use `ManagedShellGateway.readManagedShellOutput` through
  `DevelopmentServices.readLogs`. `lib/api2/gateway_operations.dart` implements
  the read; `lib/api2/transport.dart` uses the existing Basic authorization
  header. Ownership is confirmed by receipt, command, directory, ID and start
  time before attaching output. No credential is copied into the report.
- `KitLogPanel` is not present by that class name in this base. Its UI owner
  must supply/wire that kit part; this backend exports plain `logExcerpt`.

Limit: a missing/recycled team session cannot yield a historic log. No substitute
agent session or fabricated log is attached; Report remains available with
`hasLog == false`. Exact historical logs after process death are not proven or
implemented. Source tails may already be truncated by their producers.

## UI hook-up

Import `package:opencode_mobile/diagnostics/failed_job_report.dart`.
`FailedJobReport` has immutable `kind`, `jobId`, `title`, `detail`, `logExcerpt`,
`hasLog`, and `preview`. Factory methods return null for ineligible states.
Redaction uses KitRedact before bounding fields and logs. Logs retain the last
120 lines and at most 16,384 UTF-16 code units; ANSI controls are stripped.
Register loaded credentials with KitRedact before capture, as for other reports.

1. **Setup v2 failed row:** listen to `SetupEngine.progress`. Use
   `FailedJobReport.setup(engine.progress.value, componentId: row.id)` to
   determine Report availability. Capture again at the tap, before retry or
   clearing state. The excerpt is labeled as the whole job's tail.
2. **Built-in team startup:** listen to `BuiltinTeamJob`; use
   `FailedJobReport.teamSetup(job)`. Capture before `clearError()` or retry.
3. **Failed team work / Run failed gate:** use the same controller scope as the
   displayed work/gate. When `capabilities.agentOutput` permits it, obtain the
   existing `controller.agentOutput(agentId)` tail, or watch output with
   `watchAgentOutput` and pair it with `unwatchAgentOutput` on close. Listen to
   the returned tail while waiting for output. Pass its actual `sessionId`
   together with its `text`; never replace that ID with `work.sessionId` just
   to force a match. The builder checks work/gate links and session equality:

   ```dart
   final report = FailedJobReport.teamGate(
     gate,
     work: affectedWork,
     sessionId: tail?.sessionId,
     logTail: tail?.text ?? '',
   );
   // For the failed work row:
   final workReport = FailedJobReport.teamWork(
     work,
     sessionId: tail?.sessionId,
     logTail: tail?.text ?? '',
   );
   ```

   A gate's explicit `workId` takes precedence; when it supplies only `runId`,
   select affected work from that run. A gate with no usable link still yields
   a metadata-only report. Do not hide Report when logs are unavailable. For a
   run with several failing work items, select the displayed affected item;
   this API does not claim its session excerpt covers the entire team run.
4. **Dev services:** listen to `DevelopmentServices` and call `refresh()` to
   confirm current state. `model.failedReport(service.id) != null` enables
   Report. Disable load actions while `model.busy`. On tap, await the existing
   `model.readLogs(id)`, then obtain `model.failedReport(id)` and preview it.
   A read/ownership error returns null; show a retryable load failure, not the
   earlier cached log. Recheck current route/profile before opening a preview.
   Unknown exits, successful exits, explicit stops and active runs return null;
   nonzero exits, timeouts and unrequested kills are reportable. Replaced
   receipts cannot attach the prior run's cached log.
5. **Preview and export:** hold one snapshot for the preview and explicit
   Copy/Share. Show `logExcerpt` through the rebuilt KitLogPanel and a localized
   unavailable state when `hasLog` is false. Preview exactly `report.preview`
   for export; Copy uses `KitCopy.copy` with redaction enabled. Share invokes
   the existing explicit share flow, with its destination visible. No new
   automatic sending or persistence is provided here. Dispose/drop previews
   on profile deletion or scope changes; this service owns no persistent data.

The two Report affordances required by acceptance (v2 failed row and Run failed
gate) are intentionally not wired in this backend-only worktree. Localization,
accessibility, screenshots and UI behavior checks belong to that UI unit.

## Verification

New behavior tests (Flutter test):

- `test/failed_job_report_test.dart`: setup eligibility and job log, team
  work/gate attribution and unavailable logs, built-in team failure lifecycle,
  full multiline redaction before truncation, bounds, dev-service identity and
  terminal-failure eligibility. All credential fixtures are synthetic.
- `test/development_services_failed_report_test.dart`: real state/controller
  integration using the existing fake gateway; no report persistence or new
  command execution, stale read removal, runtime invalidation, scope/ownership
  rejection, replaced-receipt log isolation.
- Existing affected regression file: `test/development_services_test.dart`.

Commands attempted with the pinned SDK:

```sh
SDK="$HOME/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5"
"$SDK/bin/dart" format --language-version=3.10 lib/diagnostics/failed_job_report.dart lib/state/development_services.dart test/failed_job_report_test.dart test/development_services_failed_report_test.dart
"$SDK/bin/flutter" test --concurrency=1 test/failed_job_report_test.dart test/development_services_failed_report_test.dart test/development_services_test.dart
"$SDK/bin/flutter" analyze lib test
```

Both launchers cannot update `bin/cache/engine.stamp.tmp.*` / `engine.realm`
because the SDK cache is read-only. Tests and analysis **did not start**;
see [tests.txt](tests.txt) and [analyze.txt](analyze.txt). No test pass is claimed.
There is also no local `.dart_tool/package_config.json` yet.

Formatting completed using the same SDK's cached Dart binary, with
`--suppress-analytics` to avoid a telemetry write to the read-only home:

```sh
"$SDK/bin/cache/dart-sdk/bin/dart" --suppress-analytics format --language-version=3.10 lib/diagnostics/failed_job_report.dart lib/state/development_services.dart test/failed_job_report_test.dart test/development_services_failed_report_test.dart
```

See [format.txt](format.txt) and the unchanged-tree [format-check.txt](format-check.txt).
Package-lint resolution warnings reflect missing
package configuration. Formatting and `git diff --check` passed; they do not
substitute for type analysis or tests. A verifier must resolve dependencies and
run the three affected files plus full lib/test analysis with the pinned SDK.
No full suite, native checks, emulator, live-server validation or UI checks ran.

## State

- Implemented: backend report API and dev-service state hook.
- Enabled: callable by UI; no screens changed.
- Verified: formatting/diff only; tests and analysis blocked by environment.
- Committed: local commit on `codex/p84`; no push requested or performed.
- Deployed/released/pushed: no.
- Full P8.4 product acceptance: partial, awaiting the separate UI unit and
  verifier. Contract problems: unavailable historical team logs are explicit;
  there is no new historical-log endpoint or workaround.
