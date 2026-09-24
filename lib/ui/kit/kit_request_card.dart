import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'kit_buttons.dart';

/// Something the agent asks of the person, which they answer here: a
/// permission, a question, a form, or a wait they should know about
/// (design standard §3 "cards are for content the person works with").
///
/// Fixed slots, in this order:
///
/// 1. [icon], tinted by [tone] (the accent when null: a request, not an
///    alarm);
/// 2. [title]: one line naming the request, announced as [announcement];
/// 3. [summary]: what it concerns, in mono (a command, a path), two lines;
/// 4. [detail]: one muted line of context (why it asks);
/// 5. [body]: the answer controls when the card holds them (option rows);
/// 6. actions in the one hierarchy (§2): [primary] full width, [secondary]
///    under it, [tertiary] start-aligned.
///
/// It floats over the conversation above the composer, so it keeps the
/// raised shadow ([AppTheme.raised]) the design reserves for such surfaces.
class KitRequestCard extends StatelessWidget {
  const KitRequestCard({
    super.key,
    required this.icon,
    required this.title,
    required this.announcement,
    this.tone,
    this.summary,
    this.detail,
    this.body,
    this.primary,
    this.secondary,
    this.tertiary = const [],
    this.titleKey,
  });

  final IconData icon;
  final String title;

  /// Read by a screen reader when the card appears, for example
  /// "Permission needed: Run a shell command".
  final String announcement;

  /// Null: the accent colour. [AppStatusTone.attention] for a wait.
  final AppStatusTone? tone;
  final String? summary;
  final String? detail;
  final Widget? body;
  final KitAction? primary;
  final KitAction? secondary;
  final List<KitAction> tertiary;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = this.tone;
    final tint = tone == null
        ? scheme.primary
        : AppTheme.statusColor(theme, tone);
    final actions = KitActionBlock(
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
    );
    final summary = this.summary;
    final detail = this.detail;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
          child: Container(
            key: const ValueKey('kit-request-card'),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: tint.withValues(alpha: .4)),
              boxShadow: AppTheme.raised(theme),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Icon(icon, size: 20, color: tint),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(
                            container: true,
                            liveRegion: true,
                            label: announcement,
                            excludeSemantics: true,
                            child: Text(
                              title,
                              key: titleKey,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          if (summary != null && summary.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppTheme.monoFamily,
                                  fontSize: AppTheme.codeFontSize,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          if (detail != null && detail.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                detail,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.mutedOf(theme),
                                  height: 1.35,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (body case final body?)
                  Padding(padding: const EdgeInsets.only(top: 8), child: body),
                if (!actions.isEmpty) ...[const SizedBox(height: 12), actions],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
