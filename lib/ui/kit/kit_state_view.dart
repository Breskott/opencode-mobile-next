import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'kit_buttons.dart';
import 'kit_progress.dart';

enum KitStateSize {
  /// Fills the body, centred vertically, with no card around it.
  page,

  /// Inside a list, the same slots at smaller type.
  inline,
}

/// Every "not the normal content" moment (design standard §3): loading a
/// whole screen, empty, error, stopped or offline, blocked. Fixed slots, in
/// this order:
///
/// 1. [icon] in a tonal circle, tinted by [tone] (never a solid red block);
/// 2. [title]: one line that says the state now, never contradicting the
///    progress ("Starting OpenCode…", not "stopped" while it starts);
/// 3. [body]: at most two short sentences;
/// 4. [progress] (§4);
/// 5. actions in the one hierarchy (§2);
/// 6. [details]: a collapsed "Details" row for technical text (address,
///    error), in mono, never above the actions. [detailNotes] are plain
///    lines shown above that text when it opens (for example what to check).
///    [detailsChild] shows richer technical content there instead (a live
///    log).
///
/// Two optional places hold what a state is made of, without new slots in
/// that order: [content] sits between the progress and the actions (the
/// steps a progress is made of, a name field), and [footer] after
/// everything (the less common ways in, folded away).
class KitStateView extends StatefulWidget {
  const KitStateView({
    super.key,
    required this.icon,
    required this.title,
    this.tone = AppStatusTone.neutral,
    this.body,
    this.progress,
    this.primary,
    this.secondary,
    this.tertiary = const [],
    this.details,
    this.detailNotes = const [],
    this.size = KitStateSize.page,
    this.titleKey,
    this.bodyKey,
    this.liveRegion = true,
    this.iconChild,
    this.content,
    this.footer,
    this.detailsChild,
    this.padding,
  });

  final IconData icon;
  final AppStatusTone tone;
  final String title;
  final String? body;
  final KitProgress? progress;
  final KitAction? primary;
  final KitAction? secondary;
  final List<KitAction> tertiary;
  final String? details;
  final List<String> detailNotes;
  final KitStateSize size;
  final Key? titleKey;
  final Key? bodyKey;

  /// Announce the state when it changes (a page state usually should).
  final bool liveRegion;

  /// Drawn inside the tonal circle instead of [icon] (a check that draws
  /// itself in); [icon] still names the state.
  final Widget? iconChild;

  /// Between the progress and the actions: what the state is made of.
  final Widget? content;

  /// After the actions and the details: the less common ways on.
  final Widget? footer;

  /// Shown under "Details" when it opens, after [detailNotes] and
  /// [details]; for technical content that is not one string (a log view).
  final Widget? detailsChild;

  /// Overrides the inline size's padding, for a host already on the rails.
  final EdgeInsetsGeometry? padding;

  @override
  State<KitStateView> createState() => _KitStateViewState();
}

class _KitStateViewState extends State<KitStateView> {
  bool _detailsOpen = false;

  /// The icon's colour for [tone]; neutral is the muted text colour.
  static Color toneColor(ThemeData theme, AppStatusTone tone) =>
      tone == AppStatusTone.neutral
      ? AppTheme.mutedOf(theme)
      : AppTheme.statusColor(theme, tone);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final page = widget.size == KitStateSize.page;
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    final tint = toneColor(theme, widget.tone);
    final hasDetails =
        widget.details != null ||
        widget.detailNotes.isNotEmpty ||
        widget.detailsChild != null;
    final actions = KitActionBlock(
      primary: widget.primary,
      secondary: widget.secondary,
      tertiary: widget.tertiary,
    );
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            key: const ValueKey('kit-state-icon'),
            width: page ? 48 : 36,
            height: page ? 48 : 36,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: .14),
              shape: BoxShape.circle,
            ),
            child:
                widget.iconChild ??
                Icon(widget.icon, size: page ? 24 : 19, color: tint),
          ),
        ),
        SizedBox(height: page ? 20 : 12),
        Text(
          widget.title,
          key: widget.titleKey,
          style: page ? theme.textTheme.titleLarge : theme.textTheme.titleSmall,
        ),
        if (widget.body case final body?) ...[
          SizedBox(height: page ? 8 : 4),
          Text(
            body,
            key: widget.bodyKey,
            style:
                (page ? theme.textTheme.bodyMedium : theme.textTheme.bodySmall)
                    ?.copyWith(color: AppTheme.mutedOf(theme), height: 1.4),
          ),
        ],
        if (widget.progress case final progress?) ...[
          SizedBox(height: page ? 20 : 12),
          KitProgressView(progress: progress),
        ],
        if (widget.content case final content?) ...[
          SizedBox(height: page ? 20 : 12),
          content,
        ],
        if (!actions.isEmpty) ...[SizedBox(height: page ? 24 : 12), actions],
        if (hasDetails) ...[
          SizedBox(height: page ? 12 : 4),
          KitInset(
            child: TextButton.icon(
              key: const ValueKey('kit-state-details'),
              onPressed: () => setState(() => _detailsOpen = !_detailsOpen),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.mutedOf(theme),
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: KitButton.tertiaryInset,
                ),
              ),
              icon: Icon(
                _detailsOpen
                    ? AppIconography.chevronUp
                    : AppIconography.chevronDown,
                size: 18,
              ),
              label: Text(
                _detailsOpen ? l10n.e7SetupHideDetails : l10n.e7SetupDetails,
              ),
            ),
          ),
          if (_detailsOpen)
            Container(
              key: const ValueKey('kit-state-details-text'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final note in widget.detailNotes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        note,
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                      ),
                    ),
                  if (widget.details case final details?)
                    SelectableText(
                      details,
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: AppTheme.monoFamily,
                        color: AppTheme.mutedOf(theme),
                      ),
                    ),
                  ?widget.detailsChild,
                ],
              ),
            ),
        ],
        if (widget.footer case final footer?) ...[
          SizedBox(height: page ? 16 : 8),
          footer,
        ],
      ],
    );
    final announced = Semantics(
      container: true,
      liveRegion: widget.liveRegion,
      child: column,
    );
    if (!page) {
      return Padding(
        padding: widget.padding ?? const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: announced,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: announced,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
