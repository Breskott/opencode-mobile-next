# Steer, don't queue; Continue-with hookups; conversation identity (2026-10-14)

Branch `feat/steer-not-queue`. Evidence for the owner's three requests.

## 1. A Codex chat opened as OpenCode (owner screenshots)

Which path it was: **Codex is a Paseo native agent** (`AgentRoute.paseoNative`
in `lib/domain/agent_catalog.dart`). A chat started with the Codex chip goes
through `ConnectionController.startAgentChatIn`, which starts the Paseo helper
on demand, creates the agent there and records the conversation's own backend
connection (`_paOwners`). It is not handed to the in-app OpenCode server, and
there is no always-on Codex process: the helper is spawned when needed, which
is why `ps` after a restart shows only `opencode serve`.

Root cause: the page for a conversation (`ConversationBackendScope`) only
looked the backend up in `_paOwners`, and `_paOwners` is empty after a restart.
Any door that opens `/chat/<id>` without going through the Chats list (a
notification, a shortcut, a link, the opening screen's last-known list) found
no backend, silently fell back to the main OpenCode connection and so showed
"Ask OpenCode...", "In-app Ubuntu", and OpenCode's own health banner and
Restart.

Fixes:
- `ConversationBackendScope` now waits (skeleton transcript) while the agent's
  own connection is opened from the saved/live agent rows
  (`openBackendForConversation`), then shows the chat on it. It never falls
  back to OpenCode for a conversation the agent rows know.
- The connection line in a chat is now the conversation's own connection
  (`ConversationStatusScope`): the app-wide line reads the main connection, so
  inside a chat on another connection it is replaced by that connection's own
  line (agent name, its own Restart); heat/app-stopped lines stay.
- Reconnecting / command-group / sign-in words use the conversation's own agent
  (`_agentName`, from its provider) instead of the shared backend profile name
  (one backend serves every agent on the phone and its name follows the last
  one started).

Tests (fail without the fix, checked by reverting the scope change):
`test/phone_agents_controller_test.dart` ("a chat started with Codex says
Codex", "a Codex chat opened cold ... never opens on OpenCode"),
`test/conversation_status_scope_test.dart`.

## 2. Queue scrubbed where steering is possible

Where `capabilities.promptSteering` (OpenCode 2, direct Codex) or a Paseo
`joinsTurn` applies, a send during a running turn always adds to the turn:
one action, "Add to this turn", note "The agent will read this while it works."
Removed: the delivery segmented control, the remembered choice, the flip menu
items on waiting messages, `_flipInboxDelivery`, the strings
`kitComposerSendAfterShort/AddToTurnShort/DeliveryLabel`,
`chatUiWaitForThisRunInstead`, `chatUiSendNowAndSteerInstead`. Undo of a
cancelled waiting message now sends the ordinary way (steer), not queue.
OpenCode 1 keeps "Send after this reply" and is never called steering; Paseo
restart agents keep "Stop and send" with the contract's explanation. Offline
sending (no network) and the stored offline queue/migration are untouched.
`capabilitySteerDetail` no longer says "queue it".

Kept on purpose: existing server inbox items still show their truthful words
("Sends after this reply" / "Adds to this turn") and can be cancelled back to
the draft; the controller's `setInboxDelivery` stays as protocol support
with no reachable control.

## 3. Continue with... leftovers

- Link line: the first `continueWithLinkLines` result shows as a
  `KitContinuedLine` in the chat's existing header slot ("Continued in X" /
  "Continued from T"); tapping opens the other conversation on the same saved
  server (durable id mapped through `handoffNavigationSessionId`). One on
  another saved server says to find it in that server's chats.
- "Continue with another agent": after a provider failure on the newest reply
  (never for stops, content-filter refusals or older failures; never
  automatic; no permission refusals involved). A notice shows two actions, so
  it is inline when nothing else fixes the failure (beside Error details) and
  otherwise sits in the reply's menu; the conversation menu keeps
  "Continue with...". It opens `showContinueWith`.

Images (one phone screen each, light, 412x915): see the PNGs in this folder.

| File | What it shows |
| --- | --- |
| `before-steer-running-composer.png` | Before: running turn on a steering server, with the "Send after / Add to this turn" choice strip (composer golden at HEAD). |
| `after-steer-running-composer.png` | After: one send, "The agent will read this while it works." No choice. |
| `after-opencode1-running-composer.png` | OpenCode 1 running composer: still "Sends after this reply", never called steering. |
| `after-link-line.png` | "Continued in Claude Code" link line in the chat header slot. |
| `after-provider-failure-action.png` | Quiet "Continue with another agent" beside Send again on the newest failed reply. |

The goldens `kit_composer_busy_text_*`, were
regenerated and looked at. `kit_composer_offline_*` and `chat_disconnected_*`
were already stale at HEAD (offline wording from the stall merge) and are
regenerated with it.

## Motion

The composer's note line cross-fades (`KitSwap`, 150 ms quick pace,
instant under reduced motion) when its words change; the link line uses the
kit's `KitReveal` fold. The connection line uses the existing status slot's
fold.

## Tests run

- VPS: `pending_sends_strip_test`, `codex_chat_capabilities_test`,
  `paseo_midturn_send_test`, `kit/kit_composer_test`, `composer_layout_test`,
  `composer_desktop_enter_test`, `voice_composer_test`,
  `interaction_defaults_test`, `chat_server_state_ui_test`,
  `phone_agents_controller_test`, `conversation_status_scope_test`.
- Local (golden): `goldens/kit/*`, `goldens/chat_states_golden_test`,
  `revamp/screen_chat_1_golden_test`, `goldens/chat_approval_chip_golden_test`,
  `chat_cold_open_test`, `kit_states_scenes_test`.
- `flutter analyze lib test` clean.
