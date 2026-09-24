import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'kit_buttons.dart';

/// A condition on an otherwise working screen (design standard §5):
/// offline, out of date, something running. One row: an icon, the words,
/// an optional action, and further actions behind a small menu. At most one
/// per screen (the caller picks the most important), not a card, and one
/// live region so a screen reader announces a new status once.
class KitStatusLine extends StatelessWidget {
  const KitStatusLine({
    super.key,
    required this.icon,
    required this.message,
    this.tone = AppStatusTone.neutral,
    this.action,
    this.more = const [],
    this.onDismiss,
    this.messageKey,
    this.supporting,
    this.supportingKey,
    this.supportingSemanticsLabel,
    this.dismissTooltip,
  });

  final IconData icon;
  final String message;
  final AppStatusTone tone;
  final KitAction? action;

  /// Other ways out, in a compact menu after [action].
  final List<KitAction> more;

  /// Only when dismissing changes nothing real (§5).
  final VoidCallback? onDismiss;
  final Key? messageKey;

  /// Optional: one short muted sentence under [message], for what to do
  /// next ("Send it again") or a fact that belongs to the same condition
  /// ("2 drafts will send when connected"). Never the raw error: that goes
  /// behind a Details action.
  final String? supporting;
  final Key? supportingKey;

  /// What a screen reader says for [supporting] when its words alone would
  /// not (a bare link: "Shared conversation link …").
  final String? supportingSemanticsLabel;

  /// The dismiss button's tooltip when "Dismiss" is not the word (for
  /// example "Not now"); defaults to the shared dismiss label.
  final String? dismissTooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tint = tone == AppStatusTone.neutral
        ? AppTheme.mutedOf(theme)
        : AppTheme.statusColor(theme, tone);
    return LayoutBuilder(
      builder: (context, constraints) => _line(
        context,
        stacked: _stacks(context, constraints.maxWidth),
        tint: tint,
        l10n: l10n,
      ),
    );
  }

  /// The action moves under the words when both do not fit on one line
  /// (long words, large text), instead of squeezing the words.
  bool _stacks(BuildContext context, double width) {
    final action = this.action;
    if (action == null) return false;
    final scaler = MediaQuery.textScalerOf(context);
    final theme = Theme.of(context);
    double measure(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    final chrome =
        16 + 18 + 12 + (more.isEmpty ? 0 : 48) + (onDismiss == null ? 0 : 48);
    final actionWidth =
        measure(action.label, theme.textTheme.labelLarge) +
        2 * KitButton.tertiaryInset +
        4;
    final messageWidth = measure(message, theme.textTheme.bodyMedium);
    return messageWidth + actionWidth + chrome > width;
  }

  Widget _line(
    BuildContext context, {
    required bool stacked,
    required Color tint,
    required AppLocalizations l10n,
  }) {
    final theme = Theme.of(context);
    final action = this.action;
    final dismiss = onDismiss;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.hairline(theme))),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 4, 2),
            child: Row(
              crossAxisAlignment: stacked
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: stacked ? 15 : 0),
                  child: Icon(icon, size: 18, color: tint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: stacked ? 4 : 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (stacked) const SizedBox(height: 4),
                        Text(
                          message,
                          key: messageKey,
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (supporting case final supporting?)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Semantics(
                              label: supportingSemanticsLabel,
                              excludeSemantics:
                                  supportingSemanticsLabel != null,
                              child: Text(
                                supporting,
                                key: supportingKey,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppTheme.mutedOf(theme),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                        // At large text the action moves under the words
                        // instead of squeezing them.
                        if (stacked && action != null)
                          KitInset(
                            child: KitButton.fromAction(
                              action,
                              role: KitButtonRole.tertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!stacked && action != null)
                  KitButton.fromAction(action, role: KitButtonRole.tertiary),
                if (more.isNotEmpty)
                  PopupMenuButton<int>(
                    key: const ValueKey('kit-status-more'),
                    tooltip: l10n.chatUiMore,
                    icon: const Icon(AppIconography.more, size: 20),
                    onSelected: (index) => more[index].onPressed?.call(),
                    itemBuilder: (_) => [
                      for (var i = 0; i < more.length; i++)
                        PopupMenuItem(
                          key: more[i].key,
                          value: i,
                          enabled: more[i].onPressed != null,
                          child: Text(more[i].label),
                        ),
                    ],
                  ),
                if (dismiss != null)
                  IconButton(
                    key: const ValueKey('kit-status-dismiss'),
                    tooltip: dismissTooltip ?? l10n.workspaceDismissNotice,
                    onPressed: dismiss,
                    icon: const Icon(AppIconography.close, size: 18),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
