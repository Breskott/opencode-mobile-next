import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'kit_buttons.dart';
import 'kit_tokens.dart';
import 'motion/kit_reveal.dart';

/// A message that belongs to one part of a form or a list (design standard
/// §3, for a moment too small for a whole [KitStateView]): the verdict of a
/// connection test, a save that failed, a credential the app can no longer
/// read, a condition of one section.
///
/// A tinted icon, an optional [title], the [message], optional [notes],
/// and up to two tertiary [actions] (§2) under the words. It sits on the content's
/// own rails with no filled block and no card around it (§3: "never a solid
/// red block"; cards are for content, not for wrapping a message). It is
/// one live region, so a new verdict is read out once.
///
/// Motion (§10): it fades and rises into place when it appears and again
/// when its tone changes (a verdict that turned). To have it fold away when
/// it goes, the host shows it through a [KitReveal].
class KitNotice extends StatelessWidget {
  const KitNotice({
    super.key,
    required this.message,
    this.title,
    this.tone = AppStatusTone.neutral,
    this.icon,
    this.notes = const [],
    this.actions = const [],
    this.onDismiss,
    this.messageKey,
    this.liveRegion = true,
  });

  final String? title;
  final String message;
  final AppStatusTone tone;

  /// Defaults to the tone's glyph: a check for ok, an error mark for a
  /// failure, a warning for attention, otherwise an info mark.
  final IconData? icon;

  /// Further plain lines after the message, each its own line, muted
  /// (what a verdict implies, where to look next).
  final List<String> notes;

  /// Tertiary, start-aligned, at most two shown.
  final List<KitAction> actions;

  /// Only when dismissing changes nothing real.
  final VoidCallback? onDismiss;
  final Key? messageKey;
  final bool liveRegion;

  static IconData _iconFor(AppStatusTone tone) => switch (tone) {
    AppStatusTone.ok => AppIconography.checkCircle,
    AppStatusTone.failure => AppIconography.error,
    AppStatusTone.attention => AppIconography.warning,
    _ => AppIconography.info,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = tone == AppStatusTone.neutral
        ? AppTheme.mutedOf(theme)
        : AppTheme.statusColor(theme, tone);
    final title = this.title;
    final dismiss = onDismiss;
    final shown = actions.take(2).toList();
    return KitEntrance(
      trigger: (tone, icon),
      child: Semantics(
        container: true,
        liveRegion: liveRegion,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                // Grows with the person's text size (clamped), so the mark
                // keeps up with the words beside it.
                child: Icon(
                  icon ?? _iconFor(tone),
                  size: KitTokens.of(context).iconSize(context, 20),
                  color: tint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title != null) ...[
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      message,
                      key: messageKey,
                      style:
                          (title == null
                                  ? theme.textTheme.bodyMedium
                                  : theme.textTheme.bodySmall?.copyWith(
                                      color: AppTheme.mutedOf(theme),
                                    ))
                              ?.copyWith(height: 1.4),
                    ),
                    for (final note in notes) ...[
                      const SizedBox(height: 4),
                      Text(
                        note,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.mutedOf(theme),
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (shown.isNotEmpty)
                      KitInset(
                        child: Wrap(
                          spacing: 4,
                          children: [
                            for (final action in shown)
                              KitButton.fromAction(
                                action,
                                role: KitButtonRole.tertiary,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (dismiss != null)
                IconButton(
                  key: const ValueKey('kit-notice-dismiss'),
                  tooltip: lookupAppLocalizations(
                    Localizations.localeOf(context),
                  ).workspaceDismissNotice,
                  onPressed: dismiss,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(AppIconography.close, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
