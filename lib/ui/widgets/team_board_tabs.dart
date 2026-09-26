/// The board's column strip (docs/design/team-board-2026-09-26.md §2): one
/// tab per column with its count, so the first glance answers "what is
/// where" without scrolling.
///
/// Retired by kit-KitTabSwitcher-v2: use KitTabStrip. This is a forwarding
/// wrapper that maps [TeamBoardColumn] words, counts and needs-you columns
/// onto `KitTabStrip`, keeping its constructor and test keys (KIT-43).
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/team_board.dart';
import '../kit/motion/kit_tab_switcher.dart';
import 'team_board_card.dart' show teamBoardColumnWord;

/// Retired by kit-KitTabSwitcher-v2: use KitTabStrip.
class TeamBoardTabs extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    const columns = TeamBoardColumn.values;
    return KitTabStrip(
      stripKey: const ValueKey('team-board-tabs'),
      tabs: [
        for (final column in columns)
          KitTab(
            label: teamBoardColumnWord(l10n, column),
            count: counts?[column],
            needsYou: needsYou.contains(column) ? 1 : 0,
            key: ValueKey('team-board-tab-${column.name}'),
            countKey: ValueKey('team-board-tab-count-${column.name}'),
            needsYouKey: ValueKey('team-board-tab-needs-you-${column.name}'),
          ),
      ],
      selected: columns.indexOf(selected),
      onSelected: (index) => onSelect(columns[index]),
    );
  }
}
