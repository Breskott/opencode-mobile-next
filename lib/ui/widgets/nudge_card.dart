import 'package:flutter/material.dart';

import '../../state/nudges.dart';
import '../app_theme.dart';
import '../kit/kit.dart';

/// The one quiet line every one-time nudge uses: one sentence, one action,
/// one close button (design standard §5: a condition on a working screen is
/// a status line, not a card). It sits where the moment happened, never over
/// content, and carries no box, shadow or accent so it cannot be mistaken
/// for a request that needs an answer.
///
/// The sentence always wraps whole. When it needs more than one line, the
/// action and the close button share the row under it, so a height-limited
/// slot that scrolls to its end always shows them together.
class NudgeCard extends StatelessWidget {
  const NudgeCard({
    super.key,
    required this.id,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.dismissTooltip,
    required this.onDismiss,
    this.icon = AppIconography.idea,
  });

  final NudgeId id;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final String dismissTooltip;
  final VoidCallback onDismiss;
  final IconData icon;

  @override
  Widget build(BuildContext context) => KitStatusLine(
    key: ValueKey('nudge-${id.wire}'),
    icon: icon,
    message: message,
    action: KitAction(
      key: ValueKey('nudge-${id.wire}-action'),
      label: actionLabel,
      onPressed: onAction,
    ),
    onDismiss: onDismiss,
    dismissKey: ValueKey('nudge-${id.wire}-dismiss'),
    dismissTooltip: dismissTooltip,
    controlsTogether: true,
  );
}
