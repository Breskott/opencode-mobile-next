# UXASYNC-01: native OpenCode 2 subagent compatibility

Finish line: actual v2 `subagent` invocations render the agent, prompt, observed state and exact child-session route; eligible foreground calls appear in background promotion; v1 `task` remains supported. Non-goal: alter execution, polling, protocol mapping, controllers, chat or server synthetic-message reconciliation. Dedicated branch `fix/v2-subagent-contract` from dev724a8bd; only background-work filtering, ToolCard and focused tests/captures are changed.

## Confirmed contract and defect

The published [`@opencode-ai/core@0.0.0-beta-18600`](https://registry.npmjs.org/@opencode-ai/core/-/core-0.0.0-beta-18600.tgz) bundle `dist/chunks/project-0pepaw2y.js` defines tool name `subagent`, input `{agent,description,prompt,sessionID?,background?}` (lines32–55), early `context.progress({sessionID,status:'running'})` for either execution mode (line161), and result metadata `{sessionID,status}` (lines200–206). Local retained evidence: `/tmp/async-agent-contract/core18600__package__dist__chunks__project-0pepaw2y.js`. The research companion report is `followup/async-agent-contract.md` in the current audit folder.

Completed foreground results use `<subagent sessionID="..." state="completed">\nresult\n</subagent>`. Async launch or foreground promotion completes the tool invocation with metadata.status=`running` and model-facing instruction text; metadata.background is absent. Therefore early progress status=`running` is not sufficient evidence of detachment. Later child completion arrives as a separate server synthetic message with `{source:'subagent',childID,agent,state}`; this patch does not turn that synthetic schema into a tool call or invent an update to the original launch card.

The mapper already preserves `item.name`, input and metadata. The UI recognized only `task`, its `subagent_type` input and `<task_result>` envelope. Promotion allowed `task` and v2 `shell`, so the real v2 subagent call was omitted.

## Repair and truthful states

- Recognize `subagent` as an agent tool using `input.agent`; use existing metadata.sessionID child navigation. V1 `task` continues using `input.subagent_type` and its own task result/error envelopes.
- A completed native invocation whose child status is running says **Started in background**. It has a background badge and child-session link, while the model instruction paragraph and launch latency are not presented as the child result/runtime. No perpetual child-running spinner or completed-child checkmark is inferred from that launch record.
- Foreground running remains a working card; completed native results show the real inner result text; failed and not-executed states retain their actual meaning. A tool the server did not execute has no child-session action.
- Promotion includes running, executed, foreground native `subagent` calls only when the advertised background support includes native v2 subagents/shells. Pending, completed, error, already-background and not-executed calls remain excluded. Initial status-running progress alone does not exclude a valid foreground call.

Priority P1: a supported async workflow was absent from promotion and rendered as generic tool JSON/instruction prose. Evidence uses realistic v2 ToolState wire fixtures passed through the existing mapper; fixture task/result content is synthetic. No live child task was launched, no credentials accessed, no new server control is introduced.

Verified on pinned Shorebird Flutter3.47.2 (frameworke16cf749ccaa38d7050335ff305def49b1c7c84c):

- Initial serial background-work/card/capture command passed27 tests. Review then found that stale native progress metadata could still label an errored card running; error now overrides that metadata. The affected card/capture command was rerun and passed23 tests; the4 background-work cases and their dependencies were unchanged.
- Scoped analyzer across both production files, both test files, fixture and capture: no issues. Changed-file format and diff whitespace check pass.
- Personally inspected [dark launch](dark-launched.png), [light launch](light-launched.png), [dark completion](dark-completed.png) and [light completion](light-completed.png). These are390×844 synthetic production-widget captures, not a live child execution or native frame-time test. Existing ToolCard layout and result preview controls are retained.
- No native APK, push, CI, signing or release. No synthetic parent completion is authored by the app.

Reproduce the focused checks with the pinned SDK:

```bash
flutter test --no-pub --concurrency=1 test/background_work_test.dart test/tool_card_test.dart tool/capture/v2_subagent_test.dart
flutter analyze --no-pub lib/domain/background_work.dart lib/ui/widgets/tool_card.dart test/background_work_test.dart test/tool_card_test.dart test/support/v2_subagent_fixture.dart tool/capture/v2_subagent_test.dart
```
