/// One card of the AI Team's board (docs/design/team-board-2026-09-26.md §2
/// "Card anatomy"): the task's mark, its title in the person's words (two
/// lines), one muted meta line (priority when not normal, type when not a
/// plain task, who has it, how long ago) and at most one flag line (needs
/// you, blocked by, stopped with an error, moving, in its epic). A trailing
/// "⋯" only when the person may change something here.
library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../state/team_board.dart';
import '../app_theme.dart';
import '../kit/kit.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// The column's one word.
String teamBoardColumnWord(AppLocalizations l10n, TeamBoardColumn column) =>
    switch (column) {
      TeamBoardColumn.backlog => l10n.teamBoardColumnBacklog,
      TeamBoardColumn.ready => l10n.teamBoardColumnReady,
      TeamBoardColumn.working => l10n.teamBoardColumnWorking,
      TeamBoardColumn.review => l10n.teamBoardColumnReview,
      TeamBoardColumn.done => l10n.teamBoardColumnDone,
    };

/// How long since a card last changed, coarsely: "just now", "12 min ago",
/// "3 h ago", "2 d ago".
String teamBoardAgeLabel(AppLocalizations l10n, Duration elapsed) {
  if (elapsed.inMinutes < 1) return l10n.teamBoardAgeJustNow;
  if (elapsed.inHours < 1) return l10n.teamBoardAgeMinutes(elapsed.inMinutes);
  if (elapsed.inDays < 1) return l10n.teamBoardAgeHours(elapsed.inHours);
  return l10n.teamBoardAgeDays(elapsed.inDays);
}

/// The priority's one word.
String teamBoardPriorityWord(AppLocalizations l10n, WorkPriority priority) =>
    switch (priority) {
      WorkPriority.urgent => l10n.teamBoardPriorityUrgent,
      WorkPriority.high => l10n.teamBoardPriorityHigh,
      WorkPriority.normal => l10n.teamBoardPriorityNormal,
      WorkPriority.low => l10n.teamBoardPriorityLow,
      WorkPriority.someday => l10n.teamBoardPrioritySomeday,
    };

/// The type's one word, null for a plain task or a type the app does not
/// name (it is on the task's details).
String? teamBoardTypeWord(AppLocalizations l10n, String? type) =>
    switch (type) {
      'bug' => l10n.teamBoardTypeBug,
      'feature' => l10n.teamBoardTypeFeature,
      'epic' => l10n.teamBoardTypeEpic,
      'chore' => l10n.teamBoardTypeChore,
      _ => null,
    };

/// The card's leading mark.
KitTaskState teamBoardMark(TeamBoardCard card) {
  if (card.needsYou) return KitTaskState.needsYou;
  if (card.failed) return KitTaskState.failed;
  if (card.cancelled) return KitTaskState.stopped;
  return switch (card.column) {
    TeamBoardColumn.done => KitTaskState.done,
    TeamBoardColumn.working || TeamBoardColumn.review => KitTaskState.working,
    TeamBoardColumn.backlog || TeamBoardColumn.ready => KitTaskState.waiting,
  };
}

/// The card's one flag line and its tone; null when there is none.
(IconData, AppStatusTone, String)? teamBoardFlag(
  AppLocalizations l10n,
  TeamBoardCard card, {
  TeamBoardColumn? movingTo,
}) {
  if (card.moving) {
    return (
      AppIconography.forward,
      AppStatusTone.progress,
      l10n.teamBoardFlagMoving(teamBoardColumnWord(l10n, card.column)),
    );
  }
  if (card.needsYou) {
    return (
      AppIconography.question,
      AppStatusTone.attention,
      l10n.teamBoardFlagNeedsYou,
    );
  }
  if (card.failed) {
    return (
      AppIconography.error,
      AppStatusTone.failure,
      l10n.teamBoardFlagFailed,
    );
  }
  if (card.isBlocked && card.column != TeamBoardColumn.done) {
    final blockers = card.blockers;
    return (
      AppIconography.blocked,
      AppStatusTone.attention,
      blockers.isEmpty
          ? l10n.teamBoardFlagBlocked
          : blockers.length == 1
          ? l10n.teamBoardFlagBlockedBy(blockers.first.title)
          : l10n.teamBoardFlagBlockedByMore(
              blockers.first.title,
              blockers.length - 1,
            ),
    );
  }
  if (card.cancelled) {
    return (
      AppIconography.stopCircle,
      AppStatusTone.neutral,
      l10n.teamBoardFlagCancelled,
    );
  }
  if (card.epic case final epic?) {
    return (
      AppIconography.layers,
      AppStatusTone.neutral,
      l10n.teamBoardFlagInEpic(epic.title),
    );
  }
  return null;
}

class TeamBoardCardView extends StatelessWidget {
  const TeamBoardCardView({
    super.key,
    required this.card,
    required this.now,
    required this.onOpen,
    this.onMoves,
    this.onLongPress,
  });

  final TeamBoardCard card;
  final DateTime now;
  final VoidCallback onOpen;

  /// Opens the move sheet from the trailing "⋯"; null when the person may
  /// change nothing here (no "⋯").
  final VoidCallback? onMoves;

  /// The same sheet from a long press (moves, or why there are none).
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final flag = teamBoardFlag(l10n, card);
    final id = card.id;

    final meta = <InlineSpan>[];
    void add(InlineSpan span) {
      if (meta.isNotEmpty) meta.add(const TextSpan(text: '  ·  '));
      meta.add(span);
    }

    if (card.priority != WorkPriority.normal) {
      final word = teamBoardPriorityWord(l10n, card.priority);
      final hot = card.priority.value <= WorkPriority.high.value;
      add(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: TeamBoardPriorityGlyph(priority: card.priority),
              ),
            ),
            TextSpan(
              text: word,
              style: hot
                  ? TextStyle(
                      color: card.priority == WorkPriority.urgent
                          ? AppTheme.statusColor(theme, AppStatusTone.failure)
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    )
                  : null,
            ),
          ],
        ),
      );
    }
    final typeWord = teamBoardTypeWord(l10n, card.type);
    if (typeWord != null) {
      add(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: Icon(_typeIcon(card.type), size: 14, color: muted),
              ),
            ),
            TextSpan(
              text: card.isEpic && card.epicTotal > 0
                  ? '$typeWord · '
                        '${l10n.teamBoardEpicProgress(card.epicDone, card.epicTotal)}'
                  : typeWord,
            ),
          ],
        ),
      );
    }
    if (card.agentName case final name?) add(TextSpan(text: name));
    final at = card.item.updatedAt ?? card.item.createdAt;
    if (at != null) {
      add(TextSpan(text: teamBoardAgeLabel(l10n, now.difference(at))));
    }

    final flagLine = flag == null
        ? null
        : Padding(
            key: ValueKey('team-board-card-flag-$id'),
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Icon(
                  flag.$1,
                  size: 16,
                  color: flag.$2 == AppStatusTone.neutral
                      ? muted
                      : AppTheme.statusColor(theme, flag.$2),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    flag.$3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: flag.$2 == AppStatusTone.neutral
                          ? muted
                          : AppTheme.statusColor(theme, flag.$2),
                      fontWeight: flag.$2 == AppStatusTone.neutral
                          ? null
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );

    final done = card.column == TeamBoardColumn.done;
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: KitTaskMark(state: teamBoardMark(card))),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // The person's own words: two lines (§6).
                Text(
                  card.item.title,
                  key: ValueKey('team-board-card-title-$id'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: done && !card.needsYou ? muted : null,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(children: meta),
                    key: ValueKey('team-board-card-meta-$id'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
                ?flagLine,
              ],
            ),
          ),
        ),
        if (onMoves case final moves?)
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              key: ValueKey('team-board-card-more-$id'),
              tooltip: l10n.teamBoardMoveMenuTooltip,
              padding: EdgeInsets.zero,
              iconSize: 20,
              color: muted,
              // 40 dp drawn, 48 dp to touch (the card's own padding).
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: moves,
              icon: const Icon(AppIconography.more),
            ),
          )
        else
          const SizedBox(width: 8),
      ],
    );

    return Semantics(
      key: ValueKey('team-board-card-$id'),
      button: true,
      onLongPressHint: onMoves == null ? null : l10n.teamBoardCardHint,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: KitPanel(
          tone: card.needsYou ? AppStatusTone.attention : AppStatusTone.neutral,
          padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 4, 10),
          onTap: onOpen,
          child: content,
        ),
      ),
    );
  }

  static IconData _typeIcon(String? type) => switch (type) {
    'bug' => AppIconography.bug,
    'feature' => AppIconography.sparkle,
    'epic' => AppIconography.layers,
    _ => AppIconography.checklist,
  };
}

/// A priority drawn as signal bars (Linear's convention): three bars filled
/// to the level, a filled square with a bang for urgent, a dashed line for
/// someday. Decorative: the word beside it says the priority.
class TeamBoardPriorityGlyph extends StatelessWidget {
  const TeamBoardPriorityGlyph({super.key, required this.priority});

  final WorkPriority priority;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: CustomPaint(
        size: const Size.square(14),
        painter: _PriorityPainter(
          priority: priority,
          on: priority == WorkPriority.urgent
              ? AppTheme.statusColor(theme, AppStatusTone.failure)
              : theme.colorScheme.onSurface,
          off: AppTheme.mutedOf(theme).withValues(alpha: .35),
          ink: theme.colorScheme.surface,
        ),
      ),
    );
  }
}

class _PriorityPainter extends CustomPainter {
  const _PriorityPainter({
    required this.priority,
    required this.on,
    required this.off,
    required this.ink,
  });

  final WorkPriority priority;
  final Color on;
  final Color off;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (priority == WorkPriority.urgent) {
      final box = RRect.fromLTRBR(1, 1, w - 1, h - 1, const Radius.circular(3));
      canvas.drawRRect(box, Paint()..color = on);
      final bang = Paint()
        ..color = ink
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round;
      canvas
        ..drawLine(Offset(w / 2, h * .28), Offset(w / 2, h * .56), bang)
        ..drawCircle(Offset(w / 2, h * .74), 1, Paint()..color = ink);
      return;
    }
    if (priority == WorkPriority.someday) {
      final dash = Paint()
        ..color = off
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var x = 2.0; x < w - 1; x += 4) {
        canvas.drawLine(Offset(x, h / 2), Offset(x + 1, h / 2), dash);
      }
      return;
    }
    final lit = switch (priority) {
      WorkPriority.high => 3,
      WorkPriority.normal => 2,
      _ => 1,
    };
    const bar = 3.0;
    const gap = 1.5;
    for (var i = 0; i < 3; i++) {
      final left = 1 + i * (bar + gap);
      final top = h - 2 - (h - 4) * (i + 1) / 3;
      canvas.drawRRect(
        RRect.fromLTRBR(left, top, left + bar, h - 2, const Radius.circular(1)),
        Paint()..color = i < lit ? on : off,
      );
    }
  }

  @override
  bool shouldRepaint(_PriorityPainter old) =>
      old.priority != priority || old.on != on || old.off != off;
}
