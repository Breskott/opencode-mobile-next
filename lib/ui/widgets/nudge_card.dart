import 'package:flutter/material.dart';

import '../../state/nudges.dart';
import '../app_theme.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_notice.dart';
import '../kit/kit_tokens.dart';

/// Retired by kit-KitNotice-v2: use KitNotice.offer.
///
/// A one-time nudge: one sentence, one action, one close button, drawn by
/// [KitNotice.offer]. It sits where the moment happened, never over
/// content, and carries no box, shadow or accent so it cannot be mistaken
/// for a request that needs an answer.
///
/// The sentence always wraps whole. When it needs more than one line, the
/// action and the close button share the row under it, so a height-limited
/// slot that scrolls to its end always shows them together. It keeps the
/// screen's side rails itself, as the status line it used to be did, so its
/// two call sites stay unchanged until their screens adopt the offer.
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
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: tokens.gutter,
        end: tokens.space1,
      ),
      child: KitNotice.offer(
        key: ValueKey('nudge-${id.wire}'),
        message: message,
        icon: icon,
        action: KitAction(
          key: ValueKey('nudge-${id.wire}-action'),
          label: actionLabel,
          onPressed: onAction,
        ),
        onDismiss: onDismiss,
        dismissKey: ValueKey('nudge-${id.wire}-dismiss'),
        dismissLabel: dismissTooltip,
      ),
    );
  }
}
