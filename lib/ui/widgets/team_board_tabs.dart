/// The board's column strip (docs/design/team-board-2026-09-26.md §2): one
/// tab per column with its count, so the first glance answers "what is
/// where" without scrolling; the selected column is a filled pill. A dot
/// marks the column holding something that needs the person. A count that
/// changes while the person looks bumps once (`KitMotion.quick`); reduced
/// motion keeps it still.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/team_board.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import 'team_board_card.dart' show teamBoardColumnWord;

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

class TeamBoardTabs extends StatefulWidget {
  const TeamBoardTabs({
    super.key,
    required this.counts,
    required this.needsYou,
    required this.selected,
    required this.onSelect,
  });

  /// Cards per column, in [TeamBoardColumn] order; null while loading.
  final Map<TeamBoardColumn, int>? counts;
  final Set<TeamBoardColumn> needsYou;
  final TeamBoardColumn selected;
  final ValueChanged<TeamBoardColumn> onSelect;

  @override
  State<TeamBoardTabs> createState() => _TeamBoardTabsState();
}

class _TeamBoardTabsState extends State<TeamBoardTabs> {
  final _keys = {for (final c in TeamBoardColumn.values) c: GlobalKey()};

  @override
  void didUpdateWidget(TeamBoardTabs old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _keys[widget.selected]?.currentContext;
        if (context == null || !mounted) return;
        Scrollable.ensureVisible(
          context,
          alignment: .5,
          duration: KitMotion.reduced(this.context)
              ? Duration.zero
              : KitMotion.standard,
          curve: KitMotion.enter,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('team-board-tabs'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
      child: Row(
        children: [
          for (final column in TeamBoardColumn.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: _Tab(
                key: _keys[column],
                column: column,
                count: widget.counts?[column],
                needsYou: widget.needsYou.contains(column),
                selected: column == widget.selected,
                onTap: () => widget.onSelect(column),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.column,
    required this.count,
    required this.needsYou,
    required this.selected,
    required this.onTap,
  });

  final TeamBoardColumn column;
  final int? count;
  final bool needsYou;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final word = teamBoardColumnWord(l10n, column);
    final fg = selected ? scheme.onSecondaryContainer : AppTheme.mutedOf(theme);
    final count = this.count;
    final label = [
      l10n.teamBoardColumnSemantics(word, count ?? 0),
      if (needsYou) l10n.teamBoardColumnNeedsYouSemantics,
    ].join(', ');
    return Semantics(
      key: ValueKey('team-board-tab-${column.name}'),
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? scheme.secondaryContainer : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    word,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? fg : scheme.onSurface,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    _Count(
                      key: ValueKey('team-board-tab-count-${column.name}'),
                      count: count,
                      color: fg,
                    ),
                  ],
                  if (needsYou) ...[
                    const SizedBox(width: 4),
                    Container(
                      key: ValueKey('team-board-tab-needs-you-${column.name}'),
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.statusColor(
                          theme,
                          AppStatusTone.attention,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A column's count; bumps once when it changes after the first paint.
class _Count extends StatefulWidget {
  const _Count({super.key, required this.count, required this.color});

  final int count;
  final Color color;

  @override
  State<_Count> createState() => _CountState();
}

class _CountState extends State<_Count> with SingleTickerProviderStateMixin {
  late final _bump = AnimationController(
    vsync: this,
    duration: KitMotion.standard,
  );
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.3,
      ).chain(CurveTween(curve: KitMotion.enter)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.3,
        end: 1.0,
      ).chain(CurveTween(curve: KitMotion.exit)),
      weight: 1,
    ),
  ]).animate(_bump);

  @override
  void didUpdateWidget(_Count old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count && !KitMotion.reduced(context)) {
      _bump.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: Text(
      '${widget.count}',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: widget.color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}
