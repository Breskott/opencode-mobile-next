# Chat task controls repair

Base: `724a8bd`. Branch: `fix/chat-task-controls`.

Finish line: one foreground Stop, persistent related Tasks, truthful reactive background promotion, and server-delivered results refreshed into the open parent chat while preserving drafts and navigation scope.

Non-goal: a new execution service, protocol/controller refactoring, client-authored assistant results, prompt polling, manual result-to-draft import, or release work.

| ID | Before trigger and source | Final repair | Verification |
|---|---|---|---|
| UXCHAT-01 | Busy Chat shows AppBar and composer Stop for the same `_abort`; retry can add another (`chat_screen.dart`, `chat/attention_card.dart`). | Composer owns the sole foreground Stop, disabled while abort is pending. Speech and child/command Stop retain their own scope. | Busy/retry, pending abort, failure, reconnect and draft tests; normal/large-chat.png. |
| UXCHAT-02 | `runningAgentEntries` and Chat entry disappear after other agents become idle; uncached children are absent. | Persistent labeled Tasks entry; fresh current/parent children reads (at most two owners), cached siblings retained, running/idle/unknown labels, child Open and Parent return. | Sheet family discovery, uncached siblings/grandchildren, exited command details, empty state and 2.5x text tests; normal/large-tasks.png and child.png. |
| UXCHAT-03 | Initial audit proposed manual result/output-to-draft import. | Withdrawn after clarified requirement for automatic server delivery. The new result screen, callbacks, copy-to-draft keys and tests were removed; pre-existing command output/details remain. | Source diff and final UI contain no manual handoff feature. |
| UXCHAT-04 | Background promotion is hard to discover; eligibility/capability at sheet opening can go stale; v2 204 can be misread as confirmed success. | Explicit Run in background updates while Tasks stays open; unavailable/ineligible explanations, pending state, and accurate promoted/unchanged/requested outcomes. Tasks explains agent delegation and automatic result return. | Live support/eligibility, requested acknowledgement, existing eligibility/no-op tests; normal/large-background.png. |
| UXCHAT-05 | Child details/rescope awaits can finish after profile/project changes. | Pin origin, profile, endpoint and location around details lookup; verify actual target directory/workspace and unchanged draft/attachments after rescope before navigation. | Uncached lookup and superseded location selection regressions; existing child/parent navigation coverage. |
| UXCHAT-06 | Canonical v2 synthetic result arrives via `session.inbox.delivered`, with no message event; open parent remains stale (`chat_screen.dart::_onEvent`). | Every matching delivery schedules existing debounced authoritative history refresh. Unrelated session events do not refresh. Existing v2 notice renderer displays server content; no fabricated message or prompt mutation. | Two consecutive deliveries hydrate canonical synthetic notices with draft intact and zero prompts; normal message-event reconciliation remains green. |

The server owns async execution and final injection. Native OpenCode2 contract research is recorded in the coordinator's `followup/async-agent-contract.md`: a parent agent can invoke `subagent` with `background:true`; `backgroundSession` promotes eligible already-running blocking work. This branch also recognizes `subagent` in Chat's grouped tool summary. Domain eligibility/tool-card support is a separate integration commit (`f02fba35`), not modified here.

## Verification

Pinned Shorebird Flutter 3.47.2 / Dart 3.13.2 at framework `e16cf749ccaa38d7050335ff305def49b1c7c84c`.

- Dependency resolution, settled localization generation and changed-file format passed.
- 58 tests passed across `running_work_sheet_test`, `chat_server_state_ui_test`, `background_action_test`, `background_work_test`, `running_agents_strip_test` and `composer_layout_test` (`/tmp/chat-task-final-regression.log`).
- 16 selected UXCHAT/navigation/stop/reconciliation cases passed in `chat_live_events_test` (`/tmp/chat-task-final-reconciliation.log`).
- After final inbox/rescope guards, the two new exact behavior cases passed (`/tmp/chat-task-final-delta.log`). Earlier checks are not claimed as a rerun of this final delta; the coordinator owns the integrated full gate.
- Scoped analyzer was clean before the final two guards (`/tmp/chat-task-analyze.log`). Final delta format and diff checks passed; integrated analyzer remains the coordinator's gate.
- `tool/capture/chat_tasks_test.dart`: 2 capture cases passed at 390×844, text scales 1 and 2.5, producing ten PNGs. Inspected task status and large-text result/draft composition. Captures use actual app widgets with deterministic contract fixtures; they are not proof of provider-backed execution or an APK/ADB run.

Capture journey: busy parent → Tasks → background promotion → child → parent with server result, preserving the existing draft. The capture loads final server fixture history on parent return; the inbox-delivery regression separately proves live open-parent refresh.

Implemented and focused-verified locally. Native APK/runtime verification, cross-feature integration, full recursive suite, deployment and release are not claimed by this slice.
