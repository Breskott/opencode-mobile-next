import 'package:flutter/material.dart';

import '../app_theme.dart';

/// A list row (design standard §6): a leading icon or status dot, a
/// one-line title, a one-line muted supporting line, and a trailing value,
/// chevron or single icon action. State lives in the row (a tinted icon, a
/// "Needs you" word in [supporting]), not in cards above the list.
class KitRow extends StatelessWidget {
  const KitRow({
    super.key,
    required this.title,
    this.leading,
    this.supporting,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.supportingMaxLines = 1,
    this.enabled = true,
    this.destructive = false,
  });

  final Widget? leading;
  final String title;

  /// Muted by default; spans may carry their own colour for a state word.
  final InlineSpan? supporting;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// One line for a list of things (§6). A setting whose supporting line
  /// explains what it does, or carries an error to act on, may take two.
  final int supportingMaxLines;

  /// False for an action that cannot run now: the row dims and ignores
  /// taps. Its supporting line says why (§2: a disabled control needs a
  /// visible reason).
  final bool enabled;

  /// An action that deletes or ends something: an error-coloured title
  /// (tint the leading icon to match), and it always confirms before
  /// acting (§2).
  final bool destructive;

  /// A leading icon at the row's size, muted unless [color] is given.
  static Widget icon(BuildContext context, IconData icon, {Color? color}) =>
      SizedBox.square(
        dimension: 32,
        child: Icon(
          icon,
          size: 21,
          color: color ?? AppTheme.mutedOf(Theme.of(context)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supporting = this.supporting;
    final titleColor = destructive ? theme.colorScheme.error : null;
    final Widget row = InkWell(
      onTap: enabled ? onTap : null,
      onLongPress: enabled ? onLongPress : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            16,
            8,
            trailing == null ? 16 : 4,
            8,
          ),
          child: Row(
            children: [
              if (leading case final leading?) ...[
                leading,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: titleColor,
                      ),
                    ),
                    if (supporting != null) ...[
                      const SizedBox(height: 2),
                      Text.rich(
                        supporting,
                        maxLines: supportingMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.mutedOf(theme),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
    if (enabled) return row;
    return Opacity(opacity: .5, child: row);
  }
}
