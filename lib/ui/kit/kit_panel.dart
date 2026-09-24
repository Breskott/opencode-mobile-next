import 'package:flutter/material.dart';

import '../app_theme.dart';

/// A block of content the person works with (design standard §3: "cards
/// are for content the person works with, not for wrapping a message"):
/// one surface, one radius ([AppTheme.radiusCard]), one hairline border,
/// 16 dp inside. It replaces the hand-drawn containers of 10, 12, 14 and
/// 20 dp radius that each screen used to draw its own way.
///
/// A [tone] other than neutral tints the border and washes the surface
/// faintly: something in it needs the person (a question waiting, a
/// request being planned). The optional header is the tone's [icon] and a
/// one-line [title] in that tone, above the [child].
///
/// Never used for a state message: that is `KitStateView`.
class KitPanel extends StatelessWidget {
  const KitPanel({
    super.key,
    required this.child,
    this.tone = AppStatusTone.neutral,
    this.icon,
    this.title,
    this.titleKey,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final AppStatusTone tone;
  final IconData? icon;
  final String? title;
  final Key? titleKey;
  final EdgeInsetsGeometry padding;

  /// The whole panel opens something (a run, a sheet).
  final VoidCallback? onTap;

  /// The border colour for [tone]: the hairline when neutral.
  static Color borderOf(ThemeData theme, AppStatusTone tone) =>
      tone == AppStatusTone.neutral
      ? AppTheme.hairline(theme)
      : AppTheme.statusColor(theme, tone).withValues(alpha: .5);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final neutral = tone == AppStatusTone.neutral;
    final tint = neutral
        ? AppTheme.mutedOf(theme)
        : AppTheme.statusColor(theme, tone);
    final radius = BorderRadius.circular(AppTheme.radiusCard);
    final title = this.title;
    final content = Padding(
      padding: padding,
      child: title == null && icon == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon case final icon?) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(icon, size: 18, color: tint),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (title != null)
                      Expanded(
                        child: Text(
                          title,
                          key: titleKey,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: neutral ? null : tint,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
    );
    return Material(
      color: neutral
          ? theme.colorScheme.surfaceContainerLow
          : Color.alphaBlend(
              tint.withValues(alpha: .06),
              theme.colorScheme.surfaceContainerLow,
            ),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderOf(theme, tone)),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
