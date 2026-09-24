import 'package:flutter/material.dart';

import '../app_theme.dart';

/// One condition on an otherwise working screen (docs/design/design-standard.md
/// §5): an icon, one line of text, and an optional action. Not a card; at
/// most one per screen.
class KitStatusLine extends StatelessWidget {
  const KitStatusLine({
    super.key,
    required this.icon,
    required this.text,
    this.tone = AppStatusTone.neutral,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final AppStatusTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.statusColor(theme, tone);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedOf(theme),
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}
