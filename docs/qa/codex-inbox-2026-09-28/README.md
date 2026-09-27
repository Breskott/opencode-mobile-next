# P4.2b / P5.5 backend — 2026-09-28

Finish line: Inbox and Work can consume one observable, urgency-ordered attention feed across saved servers, with exact navigation metadata, honest coverage/freshness and the shared row-status vocabulary.

Non-goals: chat/team/Inbox layout changes, additional watchers, answering requests, native background-service changes, release work. Base: `c9504b56`.

## UI hook-up contract for the Claude chat lane

Listen to the existing `ConnectionController` and read `controller.attentionFeed`. Reading the getter has no network, persistence, acknowledgement or automatic-action side effect. It projects saved, readable profiles only; deletion closes admission before awaiting cleanup. Do not build another polling controller for Inbox or Work.

The projection types live in `lib/state/attention_feed.dart` (exports the domain types). `AttentionFeed.fromServers(...)` is also available to isolated/test hosts; pass only the currently saved profiles, never the monitor cache as the profile inventory.

### Items and navigation

`feed.items` is immutable. Each `AttentionFeedItem` contains:

| Field | UI meaning |
| --- | --- |
| `identity` | Opaque stable row identity; includes server, location, kind and request identity. Do not display it. |
| `profileID`, `serverName` | Saved server ownership and redacted display label. Keep the server label visible for cross-server rows. |
| `kind` | `permission`, `question`, `form`, `teamGate`, or `failedRun`. |
| `title` | Optional redacted work/session title; use localized generic copy when absent. No prompt, answer, tool output or raw error is carried. |
| `target` | `AttentionTarget`: profile, directory/workspace, optional conversation `sessionID`, exact `requestID`, and separate optional `taskID` / `runID`. |
| `status` | `WorkRowStatus`: facts, receipt `observedAt`, `isFresh`, `word(l10n)`, `line(l10n, now:)`, `showLiveMark`. |

Pending decisions sort before failures, then fresh observations before stale, then oldest receipt, with stable identity as the final tie-breaker. A failed team gate uses failure urgency. Check-in reminders and automatic acts are not pending requests and are excluded. Permission and question IDs cannot collide; identical request IDs on different servers or locations remain separate.

P4.2a navigation must resolve the saved profile first, confirm any server switch, revalidate the request, select its directory/workspace, then open `sessionID` with `requestID` as the card-focus target. The opaque IDs are not display copy or authorization. Existing `prepareMonitoredRequest(MonitoredRoute)` provides request preflight for monitored permission/question/form routes; mint that route from the current saved profile and the row's receipt, using `ProfileMonitor.routeSourceIdentity(profile)`. Re-resolve the current feed row before navigation; an old captured row can have been answered, removed or invalidated by a source edit. Active-server rows use the existing current request identity/reply checks. Do not use a displayed row to submit an answer directly.

A team host can return a gate before it has a worker conversation. `target.hasConversation == false` is intentional: open the exact gate/task/run in the existing team flow instead. `taskID` and `runID` are distinct; never treat a run as a task or guess a conversation. This backend does not edit the chat route arguments or implement card scrolling; that remains the P4.2a UI owner's hook-up.

### Counts, coverage and copy intent

`knownAttentionCount` counts all rows, including last-known stale rows; `freshAttentionCount` counts fresh rows. `attentionCount` is nullable and exists only with complete, fresh coverage. `feed.isComplete` is the only permission to show an all-clear empty state. The controller's existing `unifiedAttentionCount` now uses this same deduplicated known-row count, including the existing other-project SSE observations. `unknownAttentionProfileCount` counts server checks that are not current.

Use `feed.servers` for one check state per saved server. Each `AttentionServerCheck` includes server identity/name, `state`, `checkedAt`, `nextCheckAt`, `isFresh`, and `coverageComplete`.

| State | Copy intent / action |
| --- | --- |
| `current` | Checked, with complete coverage of this monitored scope. |
| `partial` | Some work has not been checked. Keep known rows and do not say there are no requests. |
| `waiting`, `checking` | Waiting to check / checking this server. Keep old rows static. |
| `unavailable` | Couldn't check this server. Offer opening that server or retrying through the existing monitor; do not imply its queue is empty. |
| `wifiRequired` | Waiting for Wi-Fi under the person's monitoring rule. |
| `paused` | Checks paused while background execution is unavailable, or active connection is offline. |
| `disabled` | Automatic checks are off. Link to existing monitoring/automation settings; merely showing Inbox must not opt in. |
| `stale` | Last observed information; show its time and a way to open/check the server. |

Use localized kit parts for those states, never enum names or raw exceptions. The feed deliberately exposes no technical exception text. If an existing explicit navigation/check operation supplies technical details, keep its plain product error and put sanitized diagnostics only in the kit Details fold. There is no error string to interpolate from this model.

A row is never fresh just because the UI rebuilt or a connection reconnected. Active pending-request reads carry a transport revision; reconnection requires refetch. Supplemental observations retain their own receipt and freshness through partial reads. `status.line(...)` freezes stale duration/age and includes its as-of time; `showLiveMark` is false for stale rows. Use the existing shared UI clock if age labels need updates; this feed starts no timer.

### P5.5 shared row status

`WorkRowFacts.chat(...)` still derives sessions from busy/request evidence and an optional current-turn `RunResult`; idle alone is not Done. Do not load every transcript just to render rows. The cross-server feed uses the same `WorkRowStatus` projection, not a second status vocabulary.

`WorkRowFacts.team(item:, needsYou:, stalled: false, ...)` now supports `WorkRowPhase.stalled`, localized by the new English `workStalled` key. Pass actual P3.5 evidence: the relevant run/task's `teamNow(...).kind == TeamNowKind.stalled`, or its confirmed dispatch-cycle stall. Restrict work/gates/agents to that run. Do not infer a stall from task creation/update age or server idleness. Needs-you and terminal done/failed/cancelled outcomes outrank stale stall evidence. Stalled rows are static; they do not show a working mark. Measured steps and explicit run timestamps remain optional, never invented from task timestamps.

Keep one `WorkRowStatusController` per profile/location for ordinary session/team lists, using its generation before the existing gateway read. Clear/dispose on scope removal; only a successful current-generation observation can refresh a row. The feed's per-item `status` is already projected and should be consumed directly.

## Executor, lifetime and persistence contract

The existing `ProfileMonitor` remains the sole other-server poll owner. It reads sequentially, at most eight profiles per pass, with the existing one-minute foreground/five-minute permitted-background intervals and failure backoff capped at 15 minutes. Wi-Fi, notification and quiet-hour rules remain intact; quiet hours suppress alerts, not observations. No SSE connection is added. The active server reuses its existing request/event transport and `ElsewhereAttention` server-wide SSE tally.

Every automatic read is gated by both monitor settings and `AutomationPolicyController.forProfile(...).value.allows(AutomationBehavior.monitorOtherServers)`. Admission is rechecked between reads and before publication. Revocation closes the active gateway and invalidates in-flight generations. Unrelated policy/settings edits cannot grant monitoring. `setEnabled(id, true)` is explicit consent; enabling through a false-to-true rules transition is also consent. Stored legacy enabled rules migrate only when there is no policy record. The old implicit two-phone-server default is not consent. An explicit/corrupt policy cannot be overridden by migration.

Runtime admission still comes from `keepLiveInBackground && backgroundLive.active`; when Android stops permitting the existing background service, polling stops and late reads cannot publish even if the app foregrounds again. No service or exemption is introduced, and no code assumes unlimited background lifetime.

`MonitorAttentionReader` enriches a successful poll within an eight-second total budget: four rotating sessions from the monitor's latest session page, at most 50 newest messages per session; team reads reuse the saved orchestration configuration and existing probe/gateway factories, retaining at most 256 records per team collection. It closes owned team gateways even when their factory completes late. Reads only: no team controller, dispatch loop or housekeeping executor is created.

Failed runs require the current user-turn boundary plus terminal message evidence, or a confirmed session-error event. A busy/new turn clears an older failure; idle alone does not. Successful sampled sessions retire their old failures independently of unsampled sessions. Partial team reads retain confirmed gates and stale older observations; absent failed/partial results are never interpreted as resolution.

Coverage is intentionally honest: other servers are checked at their saved location, the existing pending-request surfaces, and the latest bounded session page. No scan of every historical conversation or every project is implied. Unscanned/history-truncated/team-failed inventories remain partial. Other-project requests/failures already observed by the active server-wide SSE join the feed without claiming an inventory of unobserved projects. Codex has no pollable pending-request surface: an inactive saved Codex server remains unavailable; its active transport can still contribute requests. Missing team session links retain gate/task/run fallback targets.

Feed/enrichment state is in memory. No new preference schema, queue, stored error or activity blob is added. Existing monitor/policy keys retain the `oc.<what>.<profileId>` convention and deletion lanes. Source fingerprints include backend, credentials, socket directory and team configuration; changing a source invalidates its old observation. All display labels pass through KitRedact. Opaque routing IDs are never shown as labels or logged.

P6.2 automatic activity remains separate: polling and reading are observations, not confirmed automatic acts. They create no `AutomaticActKind.other` entries, acknowledgements or Undo callbacks. Existing automatic-action executors and their post-confirmation recorders are unchanged.

## Verification

Pinned SDK: `~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin`. Heavy checks serialized through `OC_TEST_SLOTS=1 tool/qa/machine_lock.sh`.

The final focused manifest is [focused-tests.txt](focused-tests.txt). It covers feed/controller/reader behavior with fakes, row status, monitor policy/runtime/deletion, the existing background/notification paths, F2/F3 deletion regressions, automation history, and all requested gates. Reproduce with pinned `flutter test --no-pub --concurrency=1 $(cat docs/qa/codex-inbox-2026-09-28/focused-tests.txt) --reporter expanded`.

Final focused run: **420 tests passed** in 46 seconds, including `kit_ratchet`, `redaction`, `kit_redact`, `ui_glossary` and `no_raw_error_text`. Initial development runs exposed two fake-fixture compilation issues (an import and an inherited member name), both corrected. The existing monitor-screen text-scaling test used an obsolete `SwitchListTile` finder; it now targets the existing `KitSwitchRow`, with no product UI change. The final full focused manifest was rerun after those fixes and the volatile-stream freshness regression.

Pinned `flutter analyze --no-pub`: **No issues found** (15.6 seconds).

Pinned `dart format --language-version=3.10 --output=none --set-exit-if-changed` passed for all 15 authored/changed Dart files. Localization was regenerated once after adding English `workStalled`; English keys are unique, with generated Arabic fallback and no authored Arabic change. `git diff --check` passed. No guard allowlist expanded.

No full-suite, device/emulator, APK, signing or release result is claimed.

## Delivery boundary

Backend connected to the existing controller/monitor and badge count. Inbox/Work row rendering and P4.2a card-focus navigation remain a Claude UI hook-up; no protected chat library, kit chat component or team page was edited. No push or release.
