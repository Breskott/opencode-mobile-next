import 'package:flutter/material.dart';

import '../app_theme.dart';

/// An action of a [KitStateView]: a label and what it does.
class KitStateAction {
  const KitStateAction({
    required this.label,
    required this.onPressed,
    this.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Key? key;
}

/// Every "not the normal content" moment (docs/design/design-standard.md §3):
/// icon in a tonal circle, a one-line title, a short body, optional progress,
/// actions in the one button hierarchy, and technical details collapsed last.
///
/// [inline] is the smaller size for a place inside other content; the page
/// size fills the body, centred, with no card around it.
class KitStateView extends StatelessWidget {
  const KitStateView({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.tone = AppStatusTone.neutral,
    this.progress,
    this.primary,
    this.secondary,
    this.tertiary = const [],
    this.detailsLabel,
    this.details,
    this.inline = false,
  });

  final IconData icon;
  final String title;
  final String? body;
  final AppStatusTone tone;

  /// A determinate or indeterminate bar with its own line (§4), or null.
  final Widget? progress;

  final KitStateAction? primary;
  final KitStateAction? secondary;

  /// At most two; more belong in an overflow menu.
  final List<KitStateAction> tertiary;

  /// The collapsed row's label ("Details") and its text, shown in mono.
  final String? detailsLabel;
  final String? details;

  final bool inline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.statusColor(theme, tone);
    final circle = inline ? 40.0 : 64.0;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: circle,
            height: circle,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: circle * .5),
          ),
        ),
        SizedBox(height: inline ? 8 : 16),
        Semantics(
          header: true,
          liveRegion: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: inline
                ? theme.textTheme.titleSmall
                : theme.textTheme.titleMedium,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 6),
          Text(
            body!,
            textAlign: TextAlign.center,
            style:
                (inline
                        ? theme.textTheme.bodySmall
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(color: AppTheme.mutedOf(theme)),
          ),
        ],
        if (progress != null) ...[const SizedBox(height: 16), progress!],
        if (primary != null) ...[
          SizedBox(height: inline ? 12 : 20),
          FilledButton(
            key: primary!.key,
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: primary!.onPressed,
            child: Text(primary!.label),
          ),
        ],
        if (secondary != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            key: secondary!.key,
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: secondary!.onPressed,
            child: Text(secondary!.label),
          ),
        ],
        for (final action in tertiary.take(2))
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: action.key,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: action.onPressed,
              child: Text(action.label),
            ),
          ),
        if (details != null && details!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey('kit-state-details'),
                tilePadding: EdgeInsets.zero,
                title: Text(
                  detailsLabel ?? '',
                  style: theme.textTheme.bodyMedium,
                ),
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: SelectableText(
                      details!.trim(),
                      style: const TextStyle(
                        fontFamily: AppTheme.monoFamily,
                        fontSize: AppTheme.codeFontSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    if (inline) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: content,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight
                ? (constraints.maxHeight - 48).clamp(0, double.infinity)
                : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
