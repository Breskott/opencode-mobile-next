# Async subagent contract — read-only feasibility, 2026-09-09

**Supported in OpenCode 2.** The genuine server tool is `subagent` with `background:true`. It launches a linked child, returns `running` to its parent, and the server later injects completion into the parent through its synthetic-input mechanism. The mobile client must display that authoritative transcript, not fabricate an assistant message or ask the user to copy a child result.

## Exact versions and primary sources

1. OpenCode 2 published `@opencode-ai/core@0.0.0-beta-18600`, matching the app's `contracts/opencode2-openapi-beta-18600.json` and protocol notes. Downloaded the publisher's [versioned npm artifact](https://registry.npmjs.org/@opencode-ai/core/-/core-0.0.0-beta-18600.tgz) without installing/executing it. Relevant bundled files: `dist/chunks/project-0pepaw2y.js` (subagent), `project-p2k7bd69.js` (session background), `dist/session/execution/restart.js`. Companion [server artifact](https://registry.npmjs.org/@opencode-ai/server/-/server-0.0.0-beta-18600.tgz), `dist/handlers/session.js:274–275`, routes background requests. npm metadata has no gitHead, so no commit identity is invented for this published beta.
2. Current official `anomalyco/opencode` **beta** branch was resolved live to **d461154a8d2b24c4ad24a89b589069cf08ab168c**. Inspected [subagent tool](https://github.com/anomalyco/opencode/blob/d461154a8d2b24c4ad24a89b589069cf08ab168c/packages/core/src/tool/plugin/subagent.ts), [subagent job](https://github.com/anomalyco/opencode/blob/d461154a8d2b24c4ad24a89b589069cf08ab168c/packages/core/src/session/subagent-job.ts), and [completion delivery](https://github.com/anomalyco/opencode/blob/d461154a8d2b24c4ad24a89b589069cf08ab168c/packages/core/src/session/subagent-completion.ts). Same supported behavior, with completion helpers refactored into dedicated modules. This checkout's beta source is separate from the v1 contract commit.
3. OpenCode 1 **v1.18.25** [task tool](https://github.com/anomalyco/opencode/blob/v1.18.25/packages/opencode/src/tool/task.ts), also inspected at app contract **f12e14cf1640cbf0dfb6b1ff425b2daaef459eec**. Local CLI version1.18.25 was supplied by coordinator; the phone's actual server version/flag has not been verified here.

## OpenCode 2 launch and parent continuation

Model-callable schema:

```json
{
  "agent": "an available subagent ID",
  "description": "short task label",
  "prompt": "complete independent task and relevant context",
  "background": true,
  "sessionID": "optional existing child session ID"
}
```

The last field is omitted to create a child. Agent must resolve, must not be `primary`, and must pass `subagent` permission checks. Default nesting limit is1, controlled by `experimental.subagent_depth`; existing child IDs must belong to this parent. Model comes from agent configuration or inherits the parent; it is not an argument on this tool.

`background:true` is opt-in per invocation; omitted means foreground. No global default-background configuration or experiment flag was found in this tool or the app's captured v2 experimental schema. New children receive fresh context, so task instructions must include what they need. The tool returns `{sessionID,status:"running",output}` immediately after server job registration/backgrounding. The parent can proceed on independent work or end its turn; the app does not need to poll or remain open to implement the server's observer. Sources: beta subagent schema/launch and published18600 bundle lines44–66,160–185.

## OpenCode 2 automatic completion and failure

The server observer waits on the child job. Completion delivers its final assistant text; no text gets an explicit no-text outcome. Errors and cancellation deliver named error/cancelled states. The server calls `sessions.synthetic` for `recovery.parentSessionID`, with a `<subagent ... state=...>` payload and metadata `{source:"subagent",childID,agent,state}`. It uses the job's notification ID when available and marks delivery complete afterward. That is genuine server-originated parent context, not a mobile-created assistant reply. Source: pinned beta `subagent-completion.ts:17–42`.

The job observer is scoped server work, deduplicated per child/job generation. It resumes the child and collects the latest completed, non-error assistant message. Source: pinned beta `subagent-job.ts:16–58`. Published beta18600 also has restart recovery for unfinished subagent jobs and undelivered notifications (`session/execution/restart.js:235–286`), including explicit failure when retry/resume is exhausted. This is source support, not a live restart guarantee from this audit.

Foreground tool interruption explicitly interrupts the child and cancels its job. The completion path can report cancelled background jobs. Exact effect of the parent's general Stop action on an already detached v2 child was not established in this bounded review; do not promise that Stop always preserves or always cancels detached children. Permission/agent/parent validation failures occur before launch and must not be shown as Running.

## Existing background endpoint is promotion, not creation

App code: `lib/api2/gateway_operations.dart:465` sends `POST /api/session/{id}/background`; contract returns204 and describes idle calls as no-op. Published beta18600 session implementation (`project-p2k7bd69.js:652–668`) calls `jobs.backgroundAll({sessionID})`, then adds an ongoing-work note to the parent if any tools moved. That note is not completion. It releases foreground observation for existing backgroundable jobs, including an already running subagent. It cannot create a child from an arbitrary prompt.

Therefore the current UI can directly expose **Continue in background** for a parent blocked on an actual backgroundable task. Keep204 as Requested; do not infer a new child or completion from it.

## OpenCode 1 counterpart

Tool is `task({description,prompt,subagent_type,task_id?,command?,background:true})`. **Requires `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true`** on the server. The advertised tool schema omits background while disabled; execute also rejects it. `GET /experimental/capabilities` reports `backgroundSubagents`. [Pinned experimental handler](https://github.com/anomalyco/opencode/blob/f12e14cf1640cbf0dfb6b1ff425b2daaef459eec/packages/opencode/src/server/routes/instance/httpapi/handlers/experimental.ts:145) promotes only running foreground task jobs whose parent matches the requested session; true means at least one promoted, false can mean disabled or nothing eligible.

Task execution returns immediately for background mode and later injects a synthetic prompt into the parent containing completed/error output. Foreground promotion registers the same observer without restarting child work. V1's notify branch does not inject a cancelled-state notification. Upstream task tests cover parent/child deletion and parent cancellation cancelling background work; don't describe this as detached from all parent lifecycle actions. Source: v1 task.ts and [task tests](https://github.com/anomalyco/opencode/blob/f12e14cf1640cbf0dfb6b1ff425b2daaef459eec/packages/opencode/test/tool/task.test.ts:686).

V1 `SubtaskPartInput` has no background field. Its prompt handler maps only prompt/description/subagent_type/command to `task`; agent mentions likewise do not enforce async execution. Adding an invented field to the client prompt is unsupported.

## Actionable integration boundary

- **Supported today:** parent model calls the genuine v2 `subagent` tool with background:true; server owns child execution and automatic parent injection. For v1, first verify capability/flag. Retain normal permission/depth restrictions.
- **Direct deterministic existing API:** promote a currently blocking child through `backgroundSession`. It is not a launch button.
- **Parent launch intent:** ordinary user instructions can request the parent use `subagent` with background:true. Only show Launched after authoritative tool output/child metadata proves that happened. A submitted prompt is not proof the model called it.
- **Missing contract for a stronger button:** the inspected public HTTP API has no dedicated spawn-background-child endpoint taking agent/prompt/parent. If a UI must guarantee launch without the parent choosing a tool, that requires a supported server API addition or exposed tool-execution contract; don't simulate one by manually linking sessions and injecting client messages.
- **Runtime gate still needed:** identify the phone's actual OpenCode2 beta and inspect its available `subagent` schema/permissions, then verify one real launch → parent proceeds → final injected result. This review made no provider call, config change, process repair, server mutation or Flutter/native test run.

Raw source extracts used for inspection are retained in `/tmp/async-agent-contract`; authoritative versioned URLs above are the durable references. The report is source-backed feasibility, not live end-to-end verification.


## Follow-up: parent completion visibility (read-only, app 724a8bd)

**Confirmed client freshness gap, not a `Part.synthetic` filtering bug.** A server-authored subagent completion is visible after REST transcript hydration, but current open Chat does not reliably hydrate the delivered synthetic inbox item. The parent model can consume the completion and stream an ordinary assistant reply while the direct child result itself remains absent until a later refresh/reopen/reconnect.

### Exact native delivery and schema

Published primary source: https://registry.npmjs.org/@opencode-ai/core/-/core-0.0.0-beta-18600.tgz . Extracted evidence under `/tmp/async-agent-contract/`.

- `dist/chunks/project-0pepaw2y.js:86–105` observes finished child and calls `runtime.session.synthetic` with parent session ID, text `<subagent sessionID="…" state="completed|error|cancelled" description="…">\n<actual output/error>\n</subagent>`, description, and metadata `{source:"subagent",childID,agent,state}`.
- `dist/chunks/project-p2k7bd69.js:674–699` admits an inbox item `{type:"synthetic",payload:{text,description,metadata},delivery:"steer"}` and wakes parent unless explicitly disabled/reverted.
- **`dist/chunks/project-qxpt6zan.js:344–368`** projects `SessionEvent.InboxDelivered`: loads the admitted inbox item and inserts a canonical message `{id:input.id,type:"synthetic",text:input.payload.text,description:input.payload.description,metadata:input.payload.metadata,time:{created:event.created}}`. This is the exact completion path; it does not require a separate `session.synthetic` event.
- Local `contracts/opencode2-openapi-beta-18600.json`, schemas `Session.Inbox.Synthetic`, `Session.Inbox.SyntheticPayload`, and `Session.Message.Synthetic` agree: synthetic message requires `id,time,text,type`, optionally description and metadata. Inbox-delivered event identifies sessionID/inboxID; it does not contain final message text.
- `dist/chunks/project-a9vdgkgd.js:200–201` converts a canonical synthetic message into model context as role user with message.text. Subsequent actual parent assistant output uses ordinary assistant/text events.

### Current app render and event path

- `lib/api2/models.dart:668–677` parses `Api2SyntheticMessage`, retaining text/description/metadata.
- `lib/api2/gateway_mappers.dart:268–276,387–412` maps it to `Part(type:"v2:notice",toolName:"synthetic",text:<full text>,filename:<description>)`. It does **not** set `synthetic:true`; arbitrary metadata currently is not carried into this tagged part.
- `lib/ui/screens/chat_screen.dart:6394–6403` selects `V2TranscriptRow` before generic renderability filtering. `lib/ui/screens/chat/message_view.dart:397–406,670–704` detects the v2 tag and displays a notice with the server description header. `:575–599` shows two plain-text lines collapsed and the full body when expanded. Raw subagent wrapper can dominate the preview; content is not stripped or lost.
- `lib/api2/gateway_events.dart:254–269`: every inbox phase is passed through, but only user enqueue also creates message events. A synthetic delivery therefore creates no client message. `Api2SessionSyntheticEvent` also falls through `:608–609` and is ignored, but that is a separate synthetic path.
- `lib/state/connection.dart:2470–2473` handles delivery by removing the pending inbox item. Chat `_onEvent` (`chat_screen.dart:1248+`) does not refresh canonical history on inbox delivery. Connection busy→idle handling (`connection.dart:2575–2584`) refreshes session metadata, not transcript; Chat `_noteRunFinished` (`chat_screen.dart:4340–4347`) only performs a haptic. Reconnect/data refresh does hydrate canonical transcript (`chat_screen.dart:4280–4305`).
- Ordinary parent assistant step/text events already map to normal message/part updates (`gateway_events.dart:291–339`), so a genuine parent response naturally renders.

### Minimal justified repair

On matching-session **`session.inbox.delivered`**, schedule the existing canonical recent-history refresh in Chat. Refresh all deliveries since that event has no item type and the pending entry may already have been removed; do not synthesize a message from an enqueue payload. Use existing debouncing/scope/reconcile handling. This single Chat event hook covers the proven subagent completion path without protocol edits. Optionally, separate follow-up can pass `session.synthetic` as a neutral refresh hint for other server-generated contexts; not necessary for this exact delivered-inbox path. Add a focused event→REST hydration regression using the actual synthetic schema and preserve streamed parent text. No source edits/tests were performed by this read-only audit.

A richer child-result card (extract validated subagent metadata for header/state/link and present body without protocol wrappers) is a UI refinement, not a prerequisite to truthful delivery. Current raw notice remains expandable. No live phone server/provider execution was performed; findings are source/contract-confirmed at beta18600 and app724a8bd.
