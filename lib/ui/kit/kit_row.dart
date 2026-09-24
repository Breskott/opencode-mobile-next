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
    this.titleMaxLines = 1,
    this.supportingMaxLines = 1,
    this.below,
  });

  final Widget? leading;
  final String title;

  /// Muted by default; spans may carry their own colour for a state word.
  final InlineSpan? supporting;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// One line by default (§6). A row whose title is the person's own long
  /// words (a run's objective) may take two.
  final int titleMaxLines;

  /// One line by default (§6); two where the line's end carries the state
  /// ("… · Finished 5h ago").
  final int supportingMaxLines;

  /// Shown under the supporting line: where a trailing state word moves at
  /// large text instead of squeezing the title.
  final Widget? below;

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
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
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
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
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
                    if (below case final below?) ...[
                      const SizedBox(height: 2),
                      below,
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
  }
}
