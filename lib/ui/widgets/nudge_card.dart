import 'package:flutter/material.dart';

import '../../state/nudges.dart';
import '../app_theme.dart';

/// The one quiet inline card every one-time nudge uses: one sentence, one
/// action, one close button. It sits where the moment happened, never over
/// content, and carries no shadow or accent border so it cannot be mistaken
/// for a request that needs an answer.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.6;
    return Center(
      key: ValueKey('nudge-${id.wire}'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 4, 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // At large text the sentence needs the whole width
                        // more than it needs a decoration.
                        if (!largeText) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              icon,
                              size: 20,
                              color: AppTheme.mutedOf(theme),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          // The sentence wraps instead of truncating: at text
                          // scale 2.5 on a 320 dp phone it is the whole tip.
                          child: Semantics(
                            container: true,
                            liveRegion: true,
                            child: Text(
                              message,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Both controls share the last row, so a height-limited
                  // slot that scrolls to its end always shows them together.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: TextButton(
                          key: ValueKey('nudge-${id.wire}-action'),
                          onPressed: onAction,
                          child: Text(actionLabel, textAlign: TextAlign.end),
                        ),
                      ),
                      IconButton(
                        key: ValueKey('nudge-${id.wire}-dismiss'),
                        tooltip: dismissTooltip,
                        onPressed: onDismiss,
                        icon: const Icon(AppIconography.close, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
