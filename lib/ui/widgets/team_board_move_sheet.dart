/// The board's sheets (docs/design/team-board-2026-09-26.md §2): the move
/// sheet a card's "⋯" or a long press opens (the moves the person may make,
/// each named with its consequence, then "Open conversation"; for a task only
/// the team moves, one sentence saying so), the priority choice, the
/// confirmation before cancelling, and "Add to backlog".
///
/// No gesture moves a card by itself: every move is a row here, and the one
/// that ends work (Cancel task) sits last, apart, and asks first (§2).
///
/// Built from kit parts only (shared-team-1): each sheet is a
/// [showKitSheet] frame, the moves are [KitRow]s in one [KitRowGroup], the
/// priority is a [KitChoiceList], the question is a [showKitConfirm].
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/team_board.dart';
import '../app_theme.dart';
import '../kit/kit_buttons.dart';
import '../kit/kit_choice_list.dart';
import '../kit/kit_field.dart';
import '../kit/kit_row.dart';
import '../kit/kit_row_parts.dart';
import '../kit/kit_sheet.dart';
import '../kit/kit_text.dart';
import '../kit/kit_task_card.dart' show KitPriorityGlyph;
import '../kit/kit_tokens.dart';
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

/// Opens the move sheet for [card]; null when dismissed. The sheet is named
/// by the task's own title and says which column it is in.
Future<TeamBoardSheetChoice?> showTeamBoardMoveSheet(
  BuildContext context, {
  required TeamBoardCard card,
  required List<TeamBoardMove> moves,
  required bool readOnly,
  required bool hasConversation,
}) {
  final l10n = _copy(context);
  return showKitSheet<TeamBoardSheetChoice>(
    context,
    sheetKey: const ValueKey('team-board-move-sheet'),
    title: card.item.title,
    subtitle: l10n.teamBoardMoveSheetWhere(
      teamBoardColumnWord(l10n, card.column),
    ),
    body: (sheetContext) => _MoveSheetBody(
      card: card,
      moves: moves,
      readOnly: readOnly,
      hasConversation: hasConversation,
    ),
  );
}

class _MoveSheetBody extends StatelessWidget {
  const _MoveSheetBody({
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
    final tokens = KitTokens.of(context);

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
      return KitRow(
        key: ValueKey('team-board-move-${move.name}'),
        // Priority leads with the current level's own bars.
        leading: move == TeamBoardMove.priority
            ? SizedBox.square(
                dimension: KitTokens.markSlotSize,
                child: Center(
                  child: KitPriorityGlyph(
                    priority: teamBoardKitPriority(card.priority),
                  ),
                ),
              )
            : KitRow.icon(context, icon),
        title: title,
        supporting: TextSpan(text: hint),
        supportingMaxLines: 2,
        destructive: move == TeamBoardMove.cancel,
        trailing: move == TeamBoardMove.priority ? const KitChevron() : null,
        onTap: () => KitSheet.close(context, TeamBoardChoseMove(move)),
      );
    }

    final note = moves.isNotEmpty
        ? null
        : readOnly
        ? l10n.teamBoardReadOnlyNote
        : l10n.teamBoardTeamMoves;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (note != null)
          Padding(
            padding: EdgeInsetsDirectional.only(bottom: tokens.space3),
            child: KitText(
              note,
              key: const ValueKey('team-board-move-note'),
              role: KitTextRole.secondary,
              tone: KitTextTone.secondary,
            ),
          ),
        // The group puts the one move that ends work (Cancel task) last,
        // after a divider (§2, KIT-28).
        KitRowGroup(
          margin: EdgeInsets.zero,
          children: [
            for (final move in moves)
              if (move != TeamBoardMove.cancel) row(move),
            KitRow(
              key: const ValueKey('team-board-move-open'),
              leading: KitRow.icon(context, AppIconography.chat),
              title: hasConversation
                  ? l10n.teamBoardOpenConversation
                  : l10n.teamBoardOpenDetails,
              trailing: const KitChevron(),
              onTap: () => KitSheet.close(context, const TeamBoardChoseOpen()),
            ),
            if (moves.contains(TeamBoardMove.cancel)) row(TeamBoardMove.cancel),
          ],
        ),
      ],
    );
  }
}

/// The priority choice; null when dismissed or unchanged.
Future<WorkPriority?> showTeamBoardPrioritySheet(
  BuildContext context, {
  required WorkPriority current,
}) async {
  final l10n = _copy(context);
  final chosen = await showKitChoiceSheet<WorkPriority>(
    context,
    sheetKey: const ValueKey('team-board-priority-sheet'),
    title: l10n.teamBoardPriorityTitle,
    selected: current,
    choices: [
      for (final priority in WorkPriority.values)
        KitChoice(
          key: ValueKey('team-board-priority-${priority.name}'),
          value: priority,
          title: teamBoardPriorityWord(l10n, priority),
          leading: KitPriorityGlyph(priority: teamBoardKitPriority(priority)),
        ),
    ],
  );
  return chosen == current ? null : chosen;
}

/// Asks before cancelling [title] (§2: ends work, confirmed). The task can
/// be put back later (Reopen), so the body says so.
Future<bool> confirmTeamBoardCancel(BuildContext context, String title) {
  final l10n = _copy(context);
  return showKitConfirm(
    context,
    title: l10n.teamBoardCancelTitle(title),
    body: l10n.teamBoardCancelBody,
    confirmLabel: l10n.teamBoardMoveCancel,
    cancelLabel: l10n.teamBoardCancelKeep,
    kind: KitConfirmKind.stop,
    icon: AppIconography.stopCircle,
    sheetKey: const ValueKey('team-board-cancel-sheet'),
    confirmKey: const ValueKey('team-board-cancel-confirm'),
  );
}

// revamp: merge-into:start-run-sheet (slice-P3.5)
/// "Add to backlog": the task's words; null when dismissed or empty. An
/// empty submit says what is missing under the field instead of a dead
/// button.
Future<String?> showTeamBoardAddSheet(BuildContext context) {
  final l10n = _copy(context);
  final form = _AddForm();
  void submit() {
    final words = form.text.trim();
    if (words.isEmpty) {
      form.error?.value = l10n.teamBoardMoveSheetAddEmpty;
      return;
    }
    Navigator.of(context).pop(words);
  }

  return showKitSheet<String>(
    context,
    sheetKey: const ValueKey('team-board-add-sheet'),
    title: l10n.teamBoardAddTooltip,
    subtitle: l10n.teamBoardAddNote,
    icon: AppIconography.add,
    primary: KitAction(
      key: const ValueKey('team-board-add-submit'),
      label: l10n.teamBoardAddButton,
      icon: AppIconography.add,
      onPressed: submit,
    ),
    body: (_) => _AddSheetBody(form: form, onSubmit: submit),
  );
}

/// What the add sheet's body holds, read by its pinned action. The body's
/// state owns the controller and the notifier, so they live exactly as
/// long as the field does.
class _AddForm {
  String text = '';
  ValueNotifier<String?>? error;
}

class _AddSheetBody extends StatefulWidget {
  const _AddSheetBody({required this.form, required this.onSubmit});

  final _AddForm form;
  final VoidCallback onSubmit;

  @override
  State<_AddSheetBody> createState() => _AddSheetBodyState();
}

class _AddSheetBodyState extends State<_AddSheetBody> {
  final _text = TextEditingController();
  final _error = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    widget.form.error = _error;
  }

  @override
  void dispose() {
    if (widget.form.error == _error) widget.form.error = null;
    _text.dispose();
    _error.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    return ValueListenableBuilder<String?>(
      valueListenable: _error,
      builder: (context, message, _) => KitField(
        label: l10n.teamBoardAddHint,
        controller: _text,
        maxLines: 4,
        autofocus: true,
        error: message,
        textInputAction: TextInputAction.done,
        onChanged: (value) {
          widget.form.text = value;
          if (_error.value != null) _error.value = null;
        },
        onSubmitted: (_) => widget.onSubmit(),
        fieldKey: const ValueKey('team-board-add-field'),
      ),
    );
  }
}
