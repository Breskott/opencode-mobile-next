import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'kit_tokens.dart';

/// A block of content the person works with (design standard §3: "cards
/// are for content the person works with, not for wrapping a message"):
/// one `surface1` panel, 18 dp corners, no border and no shadow (surface
/// steps carry depth, visual language §4), 16 dp inside. It replaces the hand-drawn containers of 10, 12, 14 and
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

  /// The border colour for [tone]: none (transparent) when neutral, since
  /// surface steps carry depth (§4); `attentionLine` for needs you.
  static Color borderOf(ThemeData theme, AppStatusTone tone) {
    final roles = AppTheme.rolesOf(theme);
    return switch (tone) {
      AppStatusTone.neutral => Colors.transparent,
      AppStatusTone.attention => roles.attentionLine,
      _ => AppTheme.statusColor(theme, tone).withValues(alpha: .45),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final neutral = tone == AppStatusTone.neutral;
    final attention = tone == AppStatusTone.attention;
    final tint = neutral
        ? AppTheme.mutedOf(theme)
        : AppTheme.statusColor(theme, tone);
    // A panel is 18 dp; a needs-you card 22 (§4).
    final radius = BorderRadius.circular(
      attention ? tokens.cardRadius : tokens.panelCornerRadius,
    );
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
                          style: tokens.cardTitle.copyWith(
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
          ? roles.surface1
          : Color.alphaBlend(
              attention ? roles.attentionSurface : tint.withValues(alpha: .06),
              roles.surface1,
            ),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: neutral
            ? BorderSide.none
            : BorderSide(color: borderOf(theme, tone)),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
