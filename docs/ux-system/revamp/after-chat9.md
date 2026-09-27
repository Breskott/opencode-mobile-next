# Chat follow-ups that wait for chat-9

Recorded 2026-09-27 by the coordinator; apply when the chat chain has merged chat-9.

- Conversation menu (lib/ui/screens/chat/attention_card.dart session menu) gets an "Export this conversation" item; remove the dead `action != 'export'` branch in chat_screen.dart and the `exportAvailable` parameter (reachability audit).
- KitTurn switches to KitIconButton.copy / KitMenuItem.copy with `redact: false` once those take the parameter (leftover planner unit).
- ToolCard.waitingForYou and onRerunCommand wiring, if chat-8 did not wire them.
- stage-revert `stage:` callback from _stageFromMessage, if chat-8 did not wire it.
