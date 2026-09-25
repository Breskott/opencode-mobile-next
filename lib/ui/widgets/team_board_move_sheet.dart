/// The board's sheets (docs/design/team-board-2026-09-26.md §2): the move
/// sheet a card's "⋯" or a long press opens (the moves the person may make,
/// each named with its consequence, then "Open conversation"; for a task only
/// the team moves, one sentence saying so), the priority choice, the
/// confirmation before cancelling, and "Add to backlog".
///
/// No gesture moves a card by itself: every move is a row here, and the one
/// that ends work (Cancel task) is error-toned and asks first (§2).
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/team_board.dart';
import '../app_theme.dart';
import '../kit/kit.dart';
import 'confirm_sheet.dart';
import 'team_board_card.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// What the person picked in the move sheet.
sealed class TeamBoardSheetChoice {
  const TeamBoardSheetChoice();
}

class TeamBoardChoseMove extends TeamBoardSheetChoice {
  const TeamBoardChoseMove(this.move);
  final TeamBoardMove move;
}

class TeamBoardChoseOpen extends TeamBoardSheetChoice {
  const TeamBoardChoseOpen();
}

/// Opens the move sheet for [card]; null when dismissed.
Future<TeamBoardSheetChoice?> showTeamBoardMoveSheet(
  BuildContext context, {
  required TeamBoardCard card,
  required List<TeamBoardMove> moves,
  required bool readOnly,
  required bool hasConversation,
}) => showModalBottomSheet<TeamBoardSheetChoice>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _MoveSheet(
    card: card,
    moves: moves,
    readOnly: readOnly,
    hasConversation: hasConversation,
  ),
);

class _MoveSheet extends StatelessWidget {
  const _MoveSheet({
    required this.card,
    required this.moves,
    required this.readOnly,
    required this.hasConversation,
  });

  final TeamBoardCard card;
  final List<TeamBoardMove> moves;
  final bool readOnly;
  final bool hasConversation;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final error = theme.colorScheme.error;

    Widget row(TeamBoardMove move) {
      final (icon, title, hint) = switch (move) {
        TeamBoardMove.startNow => (
          AppIconography.play,
          l10n.teamBoardMoveStartNow,
          l10n.teamBoardMoveStartNowHint,
        ),
        TeamBoardMove.backToBacklog => (
          AppIconography.undo,
          l10n.teamBoardMoveBackToBacklog,
          l10n.teamBoardMoveBackToBacklogHint,
        ),
        TeamBoardMove.priority => (
          AppIconography.lowPriority,
          l10n.teamBoardMovePriority,
          teamBoardPriorityWord(l10n, card.priority),
        ),
        TeamBoardMove.cancel => (
          AppIconography.stopCircle,
          l10n.teamBoardMoveCancel,
          l10n.teamBoardMoveCancelHint,
        ),
        TeamBoardMove.reopen => (
          AppIconography.restore,
          l10n.teamBoardMoveReopen,
          l10n.teamBoardMoveReopenHint,
        ),
      };
      final destructive = move == TeamBoardMove.cancel;
      return KitRow(
        key: ValueKey('team-board-move-${move.name}'),
        // Priority leads with the current level's own bars.
        leading: move == TeamBoardMove.priority
            ? SizedBox.square(
                dimension: 32,
                child: Center(
                  child: TeamBoardPriorityGlyph(priority: card.priority),
                ),
              )
            : KitRow.icon(
                context,
                icon,
                color: destructive ? error : theme.colorScheme.primary,
              ),
        title: title,
        supporting: TextSpan(text: hint),
        destructive: destructive,
        trailing: move == TeamBoardMove.priority ? const KitChevron() : null,
        onTap: () => Navigator.of(context).pop(TeamBoardChoseMove(move)),
      );
    }

    final note = moves.isNotEmpty
        ? null
        : readOnly
        ? l10n.teamBoardReadOnlyNote
        : l10n.teamBoardTeamMoves;
    return SingleChildScrollView(
      key: const ValueKey('team-board-move-sheet'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              card.item.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              l10n.teamBoardMoveSheetWhere(
                teamBoardColumnWord(l10n, card.column),
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                note,
                key: const ValueKey('team-board-move-note'),
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ),
          for (final move in moves)
            if (move != TeamBoardMove.cancel) row(move),
          KitRow(
            key: const ValueKey('team-board-move-open'),
            leading: KitRow.icon(context, AppIconography.chat),
            title: hasConversation
                ? l10n.teamBoardOpenConversation
                : l10n.teamBoardOpenDetails,
            trailing: const KitChevron(),
            onTap: () => Navigator.of(context).pop(const TeamBoardChoseOpen()),
          ),
          // The one move that ends work sits last, apart (§2).
          if (moves.contains(TeamBoardMove.cancel)) ...[
            const Divider(height: 16, indent: 16, endIndent: 16),
            row(TeamBoardMove.cancel),
          ],
        ],
      ),
    );
  }
}

/// The priority choice; null when dismissed or unchanged.
Future<WorkPriority?> showTeamBoardPrioritySheet(
  BuildContext context, {
  required WorkPriority current,
}) => showModalBottomSheet<WorkPriority>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      key: const ValueKey('team-board-priority-sheet'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              l10n.teamBoardPriorityTitle,
              style: theme.textTheme.titleMedium,
            ),
          ),
          for (final priority in WorkPriority.values)
            Semantics(
              selected: priority == current,
              child: KitRow(
                key: ValueKey('team-board-priority-${priority.name}'),
                leading: SizedBox.square(
                  dimension: 32,
                  child: Center(
                    child: TeamBoardPriorityGlyph(priority: priority),
                  ),
                ),
                title: teamBoardPriorityWord(l10n, priority),
                trailing: priority == current
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        child: Icon(
                          AppIconography.check,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : null,
                onTap: () => Navigator.of(
                  context,
                ).pop(priority == current ? null : priority),
              ),
            ),
        ],
      ),
    );
  },
);

/// Asks before cancelling [title] (§2: destructive, confirmed).
Future<bool> confirmTeamBoardCancel(BuildContext context, String title) {
  final l10n = _copy(context);
  return showConfirmSheet(
    context,
    title: l10n.teamBoardCancelTitle(title),
    message: l10n.teamBoardCancelBody,
    confirmLabel: l10n.teamBoardMoveCancel,
    cancelLabel: l10n.teamBoardCancelKeep,
    icon: AppIconography.stopCircle,
    destructive: true,
    sheetKey: const ValueKey('team-board-cancel-sheet'),
    confirmKey: const ValueKey('team-board-cancel-confirm'),
  );
}

/// "Add to backlog": the task's words; null when dismissed or empty.
Future<String?> showTeamBoardAddSheet(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _AddSheet(),
    );

class _AddSheet extends StatefulWidget {
  const _AddSheet();

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        key: const ValueKey('team-board-add-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.teamBoardAddTooltip, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('team-board-add-field'),
            controller: _text,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(hintText: l10n.teamBoardAddHint),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.teamBoardAddNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.mutedOf(theme),
            ),
          ),
          const SizedBox(height: 16),
          KitButton.primary(
            key: const ValueKey('team-board-add-submit'),
            label: l10n.teamBoardAddButton,
            icon: AppIconography.add,
            onPressed: _text.text.trim().isEmpty ? null : _submit,
          ),
        ],
      ),
    );
  }
}
