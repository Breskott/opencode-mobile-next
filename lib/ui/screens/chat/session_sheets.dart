part of '../chat_screen.dart';

/// The agent's plan has one home: the transcript, where each `todowrite`
/// call is a Tasks step whose opened body is the checklist (a mark, the
/// task's words and its state per row). There is no second copy of it in a
/// sheet. The conversation menu's Tasks entry lands on that checklist: it
/// scrolls to the reply holding the latest plan and opens its work line and
/// its Tasks step in place.
extension _ChatPlan on _ChatScreenState {
  static const _planTools = {'todowrite', 'todo'};

  /// The latest plan in the loaded transcript: the reply that holds it and
  /// the tool call itself. Null when the agent has not planned here yet.
  ({MessageWithParts message, Part part})? get _latestPlan {
    for (final message in _visibleHistory.toList().reversed) {
      if (message.info.role != 'assistant') continue;
      for (final part in message.parts.reversed) {
        if (part.type == 'tool' && _planTools.contains(part.toolName)) {
          return (message: message, part: part);
        }
      }
    }
    return null;
  }

  /// Scrolls to the latest plan and opens it: the work line it is folded
  /// under (the same grouping the transcript draws) and its Tasks step.
  void _openPlan() {
    final plan = _latestPlan;
    if (plan == null) return;
    final parts = plan.message.parts
        .where((part) => part.isRenderable || _isFoldedIntoWork(part))
        .toList();
    final runs = _groupAssistantParts(parts);
    for (final stretch in _MessageView._stretches(runs)) {
      final holdsPlan = stretch.any(
        (run) => run.parts.any(
          (part) => part.id == plan.part.id && part.callID == plan.part.callID,
        ),
      );
      if (!holdsPlan) continue;
      if (stretch.length > 1 || stretch.single.grouped) {
        final first = stretch.first.parts.first;
        _transcriptExpansion['work:${first.id ?? first.callID ?? first.messageID}'] =
            true;
      }
      break;
    }
    _transcriptExpansion['tool:${plan.part.id ?? plan.part.callID}'] = true;
    _jumpToMessage(plan.message.info.id);
  }
}
