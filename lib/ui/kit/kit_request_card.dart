import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'kit_buttons.dart';
import 'kit_tokens.dart';

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
/// It is the needs-you card of the transcript (visual language §5): solid,
/// no shadow (§7), 22 dp corners, amber surface and line when its [tone]
/// is attention.
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
    final tokens = KitTokens.of(context);
    final attention = tone == AppStatusTone.attention;
    final large = MediaQuery.textScalerOf(context).scale(10) >= 20;
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
            padding: EdgeInsets.all(tokens.space4),
            // A request is content (no shadow, §7): a 22 dp card whose
            // needs-you tone is the amber surface and line (§3).
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                attention
                    ? tokens.roles.attentionSurface
                    : tint.withValues(alpha: .06),
                tokens.roles.surface1,
              ),
              borderRadius: BorderRadius.circular(tokens.cardRadius),
              border: Border.all(
                color: attention
                    ? tokens.roles.attentionLine
                    : tint.withValues(alpha: .35),
                width: 0,
              ),
            ),
            // At large text (2x and up) never more than 45 % of the
            // window: past that the words scroll and the answers stay in
            // sight on a short phone.
            constraints: large
                ? BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .45,
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MaybeScroll(
                  scroll: large,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox.square(
                            dimension: tokens.markSize - 8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: tint.withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(
                                  tokens.markRadius - 2,
                                ),
                              ),
                              child: Center(
                                child: Icon(icon, size: 20, color: tint),
                              ),
                            ),
                          ),
                          SizedBox(width: tokens.space3),
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
                                    style: tokens.cardTitle,
                                  ),
                                ),
                                if (detail != null && detail.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      detail,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: tokens.rowSupporting,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      // The command or path under the header, the card's full
                      // width (visual language §5), so it wraps as late as it can.
                      if (summary != null && summary.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: tokens.space3),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: tokens.roles.ground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: tokens.space3,
                                vertical: tokens.space2,
                              ),
                              // A command or a path reads left to right inside
                              // any language.
                              child: Text(
                                summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.ltr,
                                style: tokens.technicalValue,
                              ),
                            ),
                          ),
                        ),
                      if (body case final body?)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: body,
                        ),
                    ],
                  ),
                ),
                if (!actions.isEmpty) ...[const SizedBox(height: 12), actions],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrolls [child] only when [scroll] (a request card at large text);
/// otherwise the card lays out at its own height with no scrollable in it.
class _MaybeScroll extends StatelessWidget {
  const _MaybeScroll({required this.scroll, required this.child});

  final bool scroll;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      scroll ? Flexible(child: SingleChildScrollView(child: child)) : child;
}
