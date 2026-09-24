import 'package:flutter/material.dart';

import '../app_theme.dart';

/// A list row (design standard §6): a leading icon or status dot, a
/// one-line title, a one-line muted supporting line, and a trailing value,
/// chevron or single icon action. State lives in the row (a tinted icon, a
/// "Needs you" word in [supporting]), not in cards above the list.
///
/// One line each is the rule. A list whose titles are the person's own words
/// (conversation titles) may let them wrap with [titleMaxLines] and
/// [supportingMaxLines], so large text does not cut them to a few letters.
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
    this.titleKey,
    this.supportingKey,
    this.padding,
  });

  final Widget? leading;
  final String title;

  /// Muted by default; spans may carry their own colour for a state word.
  final InlineSpan? supporting;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Lines the title may take before it is cut; 1 unless the titles are
  /// the person's own words (see the class doc).
  final int titleMaxLines;

  /// Lines the supporting line may take before it is cut.
  final int supportingMaxLines;

  /// Keys of the title and supporting texts, for tests.
  final Key? titleKey;
  final Key? supportingKey;

  /// The row's own padding; by default the 16 dp rails of a list. A row
  /// inside a block that already sits on the rails (a state, a card's
  /// content) passes its own, usually no side padding.
  final EdgeInsetsGeometry? padding;

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
          padding:
              padding ??
              EdgeInsetsDirectional.fromSTEB(
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
                      key: titleKey,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (supporting != null) ...[
                      const SizedBox(height: 2),
                      Text.rich(
                        supporting,
                        key: supportingKey,
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
  }
}
