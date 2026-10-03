# Chat follow-ups that wait for chat-9

Recorded 2026-09-27 by the coordinator; apply when the chat chain has merged chat-9.

- Conversation menu (lib/ui/screens/chat/attention_card.dart session menu) gets an "Export this conversation" item; remove the dead `action != 'export'` branch in chat_screen.dart and the `exportAvailable` parameter (reachability audit).
  **Done (chat-9).** The menu's session actions carry "Export this conversation" on every server (JSON where the server exports, the loaded Markdown otherwise); `_continueOnComputer` no longer checks for an export result, and `exportAvailable` and `continueOnComputerExport` are gone from `session_handoff_sheets.dart` and its tests. The chat now opens the sheet with `offerReload: true` and, on Reload, refreshes the conversation and reopens it.
- KitTurn switches to KitIconButton.copy / KitMenuItem.copy with `redact: false` once those take the parameter (leftover planner unit).
  **Deferred.** On this base neither `KitIconButton.copy` nor `KitMenuItem.copy` takes `redact`; the leftover planner unit adds it. KitTurn's Copy already copies verbatim through `KitCopy.copy(redact: false)`; its footer-menu copy items still use the default until then.
- ToolCard.waitingForYou and onRerunCommand wiring, if chat-8 did not wire them.
  **Done by chat-8** (`message_view.dart`: `_toolWaitsForYou`, `_rerunShellCommand` on both tool paths).
- stage-revert `stage:` callback from _stageFromMessage, if chat-8 did not wire it.
  **Done by chat-8** (`_stageFromMessage` passes `stage:` to the staged-revert screen).
