# Steering a running conversation

Owner request, 2026-10-14: “Steering is missing in codex” and “I don't want any queue options, scrub it where steering is possible.” This contract covers the direct Codex backend and the UI work that follows. The backend change does not itself remove the existing delivery controls from the chat screen. Codex exposes the existing `MidTurnPromptGateway` presentation, so its current composer can already show “Add to this turn”; the OC2 queue-control removal remains UI work.

**Where steering is possible, sending during a running turn always steers; no queue choice is offered.** Steering adds the user's input to the current turn. It does not promise that a tool already executing will stop immediately, undo its effects, or consume the input before its next safe boundary.

## Runtime contract

| Runtime | Running-turn behavior | Domain evidence and UI rule |
| --- | --- | --- |
| OpenCode 1 | No native steering contract in the current client. A prompt sent while busy waits for the current work. | `capabilities.promptSteering == false`; no `MidTurnPromptGateway` join result. Do not call it steering. Existing after-reply behavior remains available for this unsupported runtime. |
| OpenCode 2 | Native steering via prompt `delivery: "steer"`; input is consumed at a step boundary. The server also supports queue delivery, but the product must not offer that choice. | `capabilities.promptSteering == true`; use `PromptDelivery.steer` while running. `capabilities.inbox` controls pending-inbox operations, not whether steering exists. |
| Paseo: Claude Code, Codex, OpenCode, Pi | Native running-turn input through `send_agent_message_request` with `activeTurnBehavior: "steer"`. | `MidTurnPromptGateway.midTurnPrompt(sessionID) == MidTurnPrompt.joinsTurn`. Call the normal prompt path without an explicit delivery enum: Paseo already selects steering. Show “Add to this turn”; no queue choice. |
| Paseo: ACP/other agents, including Copilot | The current daemon interrupts the active run and starts over from the new message. This is not native steering. | `midTurnPrompt(...) == MidTurnPrompt.restartsTurn`. Show “Stop and send” and explain that the current reply stops. Never label it steering or queued. |
| Paseo: agent identity not loaded | Running-turn behavior is not yet known. | `midTurnPrompt(...) == null`. Wait for the session/agent details before promising either join or restart behavior. Do not infer from the visible agent name. |
| Codex direct, app-server 0.153.4 | Native `turn/steer` adds input to a specifically identified active turn; it does not start another turn. | `capabilities.promptSteering == true`. Use `PromptDelivery.steer` while running. `MidTurnPromptGateway` also reports `joinsTurn` for a known session. There is no server inbox or queue choice. |

Paseo is a mixed runtime, so its server-wide `promptSteering` flag remains false. Its per-session `MidTurnPromptGateway` result supplies the stronger answer. This mapping lives in the gateway; UI code must not branch on flavor enums, provider IDs, API clients, or agent display names. The current Paseo mapping is established by the pinned daemon behavior documented in `test/paseo_midturn_send_test.dart`; it is not a guarantee for an unknown future provider.

## Codex direct: callable API and dispatch

The pinned 0.153.4 generated contract includes `turn/steer` as a normal client request. It accepts `threadId`, `input` (the same user-input union used by a new turn), and required `expectedTurnId`. An optional `clientUserMessageId` is also supported by the protocol. Its result contains `turnId`. `expectedTurnId` is a safety condition, not a suggestion: the app must not steer a replacement turn after the observed turn ends.

The exact schema and isolated real-binary probe are recorded in [Codex steering feasibility](codex-steering-feasibility.md). With experimental APIs disabled, the real 0.153.4 binary accepted steering on the active turn and rejected a stale expected turn, empty input, and an idle/completed turn. The probe used a local synthetic Responses server, without owner credentials or servers; it does not prove live model consumption. Although `turn/start` can also steer an active turn according to its schema comments, the dedicated method supplies the required turn-identity guard.

The gateway handles all wire details:

- An explicit `PromptDelivery.steer` requires a running turn. Missing/stale turn state fails without starting a new turn.
- With no explicit delivery, a busy direct Codex conversation also steers; an idle one uses the existing `turn/start` path.
- `PromptDelivery.queue` is rejected for direct Codex. The gateway must never silently convert this into another turn.
- Direct Codex currently accepts text prompts only; this change does not enable attachments or agent mentions, even though the wire input union is broader. The request contains the user input and the expected active turn ID. Model and reasoning settings belong to turn creation; steering does not apply a new selection to an already running turn.
- Project/location and transport epochs fence preflight and dispatch. A changed scope, replaced connection, or outdated active turn cannot redirect the input to a different conversation or turn.
- Interruption is an explicit separate user action. The gateway never implements steering by interrupting and restarting, retries a rejected steer as `turn/start`, or replays an uncertain mutation automatically.

An accepted RPC confirms delivery to the active turn, not that the assistant has already acted on the new instruction. The acknowledgement must identify the same turn; a missing/different turn ID is uncertain delivery. A completion event received while awaiting the acknowledgement wins: the acknowledgement does not mark the turn busy again. Render the subsequent transcript/events normally. Retain the current running turn, tool activity, and Stop action. Do not create a synthetic new conversation or a server-queue receipt for Codex.

## Composer behavior for the UI builder

Use only the domain gateway/capabilities. Determine the running session's action in this order:

1. A `MidTurnPromptGateway` result of `joinsTurn`, or `capabilities.promptSteering`, means the single send action adds input to the running turn. For gateways with `promptSteering`, send `delivery: PromptDelivery.steer`; for a Paseo join result, leave delivery unset because its normal send path already steers.
2. A per-session result of `restartsTurn` means “Stop and send,” with its existing honest explanation.
3. Otherwise do not claim steering. Follow the runtime's supported behavior; if session behavior is unknown, keep the text editable while session state refreshes.

Idle send is ordinary send and starts a turn. While a steer-capable turn runs, typed text, keyboard send, attachment send, and voice-text submission all use the same steering action. There must be no separate default, long-press option, keyboard shortcut, context menu, or remembered setting that selects queue delivery. In particular, an old `_delivery == PromptDelivery.queue` value must not override the running-turn rule.

Plain copy:

| State | Copy/action |
| --- | --- |
| Running, native steering available | Send action/tooltip: “Add to this turn”. Optional explanation: “The agent will read this while it works.” |
| RPC pending | “Sending…”; prevent duplicate submission of the same draft. |
| Accepted steer awaiting visible work | “Added to this turn”; do not say “Queued” or “After this reply”. |
| Running, restart behavior | “Stop and send”. Explanation: “Stops the current reply and starts again with your message.” |
| Active turn ended before explicit steer | “That turn has finished. Your message is still here.” Refresh state and require a new send action for an ordinary turn. |
| Connection/scope changed before dispatch | “The conversation changed. Your message is still here.” Restore the draft and refresh. |
| Mutation delivery uncertain | “We couldn't confirm whether this was sent. Check the conversation before sending again.” No automatic resend or queue fallback. |
| Steering not available | Do not show steering controls. For an explicit unsupported request, keep the draft and explain “This connection can't add to a running turn.” |

Do not show raw app-server errors, payloads, credential-bearing URLs, or request bodies in notices. Preserve the existing typed error and uncertain-delivery handling. Local missing/changed-turn checks return `staleRequest`; a server rejection after preflight uses the transport's generic `unavailable` error, so show the generic failure and refresh rather than parsing remote text to claim the turn finished. Restore text and attachments only when doing so cannot overwrite newer user edits.

## Queue controls to scrub

This is the UI implementation checklist, not a claim that those changes are included in this backend commit:

- `lib/ui/screens/chat/chat_send.dart`: remove the running-turn queue default and ensure all send entry points obtain the same automatic steering decision.
- `lib/ui/screens/chat/chat_queue.dart`: replace `_activeDelivery`'s inbox/remembered-choice decision with capability/session behavior; remove the user path that flips a steering item to queue. Keep server reconciliation/cancel logic and truthful display of already admitted work.
- `lib/ui/screens/chat/chat_composer_region.dart` and `composer.dart`: remove `canChooseDelivery`, queue selection callbacks, and the “Send after” choice for steering-capable sessions. Supply the correct fixed delivery presentation.
- `lib/ui/kit/chat/kit_composer.dart`: do not render the `composer-delivery-control` choice for steering-capable chats. Keep Kit-only composition. Check tooltips, keyboard behavior, accessibility labels, wide layouts, and translated copy.
- `lib/ui/screens/chat/pending_sends_strip.dart`: remove `inbox-action-queue` / “Wait for this run instead” wherever steering is supported. Existing older/externally queued inbox items must retain their truthful “after this reply” status until actually changed; they may be canceled or explicitly moved to steering, never silently relabeled. Do not create new queue-choice menus.
- `lib/state/connection/forms_inbox.dart` and the domain inbox API can retain protocol support for reading/reconciling existing server items. Their queue mutation must have no reachable queue-choice control in steer-capable chat UI.
- Recheck the model/agent chip during a running Codex turn: a steering message cannot change that turn's model or reasoning settings. Do not imply otherwise; apply changed selection to a later ordinary turn.

An OC2 pending steering item is real server state and may be displayed as “Add to this turn” while it waits for a boundary. Removing queue choices does not mean hiding pending work. Nor does this contract relabel an offline draft as a steer: disconnected drafts have not reached a running turn. Preserve honest existing offline-draft recovery for runtimes that support it, without offering it as an alternative running-turn delivery mode. Direct Codex and Paseo do not gain an offline queue from this change.

## Acceptance and tests

Backend acceptance: direct Codex busy sends invoke `turn/steer` for the same thread/turn; idle sends still invoke `turn/start`; explicit stale/idle steering and queue delivery cause no new turn; no interrupt RPC appears; response and scope races fail safely; uncertain delivery is not replayed. OC2 advertises native steering independently of inbox support. Paseo's per-agent join/restart semantics remain intact.

UI acceptance for the next slice: all entry points steer while supported and running; queue choice is absent from composer, shortcuts, pending-item actions, and restored preferences; OC1 remains truthfully after-reply, ACP remains truthfully restart; existing inbox/offline items retain truthful state. Update the tests that currently expect the old queue default, delivery toggle, or reversible steer-to-queue action. Add the real screen's updated Widgetbook states and check localization/accessibility as required by the repository.

Flutter test files to run (not run for this backend task):

- `test/codex_steering_test.dart` — new direct steering dispatch, capability, guard, race, and uncertain-delivery coverage.
- `test/codex_gateway_test.dart` — existing direct dispatch and lifecycle regression.
- `test/codex_transport_test.dart` — epoch/disconnect/mutation behavior.
- `test/codex_journey_test.dart` — direct conversation lifecycle regression.
- `test/codex_chat_capabilities_test.dart` — advertised chat capabilities and UI gating.
- `test/api2_interaction_gateway_test.dart` — OC2 delivery and inbox contract.
- `test/paseo_midturn_send_test.dart` — native join versus ACP restart.
- `test/pending_sends_strip_test.dart` — existing queue/default assertions need the UI rule above.
- `test/composer_desktop_enter_test.dart`, `test/composer_layout_test.dart`, `test/voice_composer_test.dart` — send entry-point/layout regression.
- `test/kit/kit_composer_test.dart`, `test/goldens/kit/kit_composer_golden_test.dart` — fixed send presentation and absence of the choice in the UI slice.

This document separates protocol feasibility, implemented backend dispatch, and pending UI removal. A schema/binary contract check is not a model-backed running-turn or owner-phone qualification.

Local backend validation: pinned Dart formatting and focused Dart analysis passed
for the four changed libraries, `codex_steering_test.dart`, and the existing
Codex gateway/chat-capability and OC2 interaction test files. Analysis used the
existing cached dependencies through this worktree's local package map; no pub
install or Flutter command ran. The isolated real-binary probe above passed its
admission/error checks. The 13 new Flutter tests are supplied and analyzed, not
executed. No app build, live provider, owner phone, or UI acceptance was run.
