/// The AI Team's board (docs/design/team-board-2026-09-26.md): a project's
/// tasks (Gas City beads) in five columns — Backlog · Ready · Working ·
/// Review · Done — paged one at a time with the next one peeking, under a
/// strip of column tabs with counts. It opens on Working.
///
/// - A card opens its team conversation ([openTeamBoardCard], the one swap
///   point for `TeamConversation.open` once that lands; until then the task
///   ([RunScreen]) or, for a card that belongs to no task, its Work sheet).
/// - A card's "⋯" and a long press open the move sheet. The person may start
///   a Backlog task, take a Ready one back, reprioritise either, cancel either
///   (confirmed), and put a cancelled one back; Working, Review and Done are
///   the team's. No gesture moves a card by itself.
/// - A move shows at once ("Moving to Ready…" in its new column) and stays
///   until the host shows it there; a refusal puts it back with a notice.
/// - The host's bookkeeping beads never appear ([teamBoardIsBookkeeping]).
/// - A host that allows no writes shows the board read-only and says so in
///   the one status line.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../domain/orchestration_work_edits.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../../state/team_board.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../kit/scenes/team_scenes.dart';
import '../../widgets/grace_timer.dart';
import '../../widgets/team_board_card.dart';
import '../../widgets/team_board_move_sheet.dart';
import '../../widgets/team_board_tabs.dart';
import '../team_conversation/team_conversation.dart';
import 'team_states.dart';
import 'work_sheet.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// How long a moved card waits in its new column for the host to show it
/// there before the board goes back to what the host says.
const teamBoardPendingHold = Duration(seconds: 30);

/// Opens [card]'s team conversation
/// (docs/design/team-conversation-2026-09-26.md) when it belongs to a task,
/// else the card's Work sheet.
Future<void> openTeamBoardCard(
  BuildContext context,
  OrchestrationController controller,
  TeamBoardCard card, {
  DateTime Function()? now,
}) {
  final runId = card.runId;
  if (runId != null) {
    return TeamConversation.open(context, controller, runId: runId);
  }
  return showWorkSheet(context, controller, card.id, now: now);
}

/// Opens the board for [controller].
Future<void> openTeamBoard(
  BuildContext context,
  OrchestrationController controller, {
  DateTime Function()? now,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => TeamBoardScreen(controller: controller, now: now),
  ),
);

class TeamBoardScreen extends StatefulWidget {
  const TeamBoardScreen({
    super.key,
    required this.controller,
    this.projectId,
    this.onOpenCard,
    this.edits,
    this.now,
  });

  final OrchestrationController controller;

  /// The project to show first; the first one with open work when null.
  final String? projectId;

  /// Opens a card; [openTeamBoardCard] when null.
  final ValueChanged<TeamBoardCard>? onOpenCard;

  /// The bead edits; resolved from the controller's gateway when null.
  final OrchestrationWorkEditGateway? edits;

  /// Clock for ages and the Done window; tests pin it.
  final DateTime Function()? now;

  @override
  State<TeamBoardScreen> createState() => _TeamBoardScreenState();
}

class _TeamBoardScreenState extends State<TeamBoardScreen> {
  late final TeamBoardEdits _edits = TeamBoardEdits(
    widget.controller,
    edits: widget.edits,
  );
  PageController? _pages;
  TeamBoardColumn _column = TeamBoardColumn.working;
  String? _project;
  bool _projectChosen = false;
  bool _refreshing = false;
  int _busy = 0;

  /// Cards the person moved, by id, until the host shows them there.
  final _pending = <String, TeamBoardColumn>{};
  final _pendingTimers = <String, Timer>{};

  /// A move the host refused: the card's title and the host's words.
  (String, String?)? _failure;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _project = widget.projectId;
    _projectChosen = widget.projectId != null;
    widget.controller.addListener(_prune);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_prune);
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pages?.dispose();
    super.dispose();
  }

  bool get _ready =>
      widget.controller.phase == OrchestrationPhase.ready &&
      widget.controller.snapshot.hasData;

  TeamBoard _board() => buildTeamBoard(
    widget.controller.snapshot,
    projectId: _projectFilter,
    now: _now,
    pending: _pending,
  );

  /// The project filter: none when the host reports at most one project.
  String? get _projectFilter =>
      widget.controller.snapshot.projects.length > 1 ? _project : null;

  /// Drops the moves the host now shows (or whose card is gone).
  void _prune() {
    if (_pending.isEmpty || !mounted) return;
    final board = _board();
    final settled = [
      for (final id in _pending.keys)
        if (board.find(id)?.moving != true) id,
    ];
    if (settled.isEmpty) return;
    setState(() => settled.forEach(_dropPending));
  }

  void _dropPending(String id) {
    _pending.remove(id);
    _pendingTimers.remove(id)?.cancel();
  }

  void _chooseDefaultProject() {
    if (_projectChosen) return;
    final snapshot = widget.controller.snapshot;
    final projects = snapshot.projects;
    if (projects.length <= 1) return;
    _projectChosen = true;
    for (final project in projects) {
      final board = buildTeamBoard(snapshot, projectId: project.id, now: _now);
      if (board.total - board.count(TeamBoardColumn.done) > 0) {
        _project = project.id;
        return;
      }
    }
    _project = projects.first.id;
  }

  /// Working, unless it is empty: then the first column with something.
  TeamBoardColumn _openingColumn(TeamBoard board) {
    if (board.count(TeamBoardColumn.working) > 0) {
      return TeamBoardColumn.working;
    }
    for (final column in TeamBoardColumn.values) {
      if (board.count(column) > 0) return column;
    }
    return TeamBoardColumn.working;
  }

  PageController _pagesFor(BuildContext context, TeamBoard board) {
    final existing = _pages;
    if (existing != null) return existing;
    _column = _openingColumn(board);
    final width = MediaQuery.sizeOf(context).width;
    // One column almost full width with its neighbours peeking (Jira,
    // Notion); on a wide screen a column stays phone-sized.
    final fraction = width <= 0
        ? .9
        : math.min((width - 40) / width, 400 / width).clamp(.3, .95);
    return _pages = PageController(
      initialPage: _column.index,
      viewportFraction: fraction,
    );
  }

  void _select(TeamBoardColumn column) {
    setState(() => _column = column);
    final pages = _pages;
    if (pages == null || !pages.hasClients) return;
    if (KitMotion.reduced(context)) {
      pages.jumpToPage(column.index);
    } else {
      pages.animateToPage(
        column.index,
        duration: KitMotion.standard,
        curve: KitMotion.emphasized,
      );
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final controller = widget.controller;
      if (controller.phase == OrchestrationPhase.failed) {
        await controller.retry();
      } else {
        await controller.refresh();
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _open(TeamBoardCard card) {
    final open = widget.onOpenCard;
    if (open != null) return open(card);
    openTeamBoardCard(context, widget.controller, card, now: widget.now);
  }

  Future<void> _showMoves(TeamBoardCard card) async {
    final moves = _edits.movesFor(card);
    final choice = await showTeamBoardMoveSheet(
      context,
      card: card,
      moves: moves,
      readOnly: _edits.readOnly,
      hasConversation: card.runId != null,
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case TeamBoardChoseOpen():
        _open(card);
      case TeamBoardChoseMove(:final move):
        await _move(card, move);
    }
  }

  Future<void> _move(TeamBoardCard card, TeamBoardMove move) async {
    WorkPriority? priority;
    if (move == TeamBoardMove.priority) {
      priority = await showTeamBoardPrioritySheet(
        context,
        current: card.priority,
      );
      if (priority == null || !mounted) return;
    }
    if (move == TeamBoardMove.cancel) {
      final sure = await confirmTeamBoardCancel(context, card.item.title);
      if (!sure || !mounted) return;
    }
    final target = teamBoardMoveTarget(move);
    setState(() {
      _failure = null;
      _busy++;
      if (target != null) {
        _pending[card.id] = target;
        _pendingTimers.remove(card.id)?.cancel();
      }
    });
    final result = await _edits.run(move, card, priority: priority);
    if (!mounted) return;
    setState(() {
      _busy--;
      if (!result.ok) {
        _dropPending(card.id);
        _failure = (card.item.title, result.message);
      } else if (target != null && _pending.containsKey(card.id)) {
        // The host took it; if it has not shown it yet, wait a while
        // for it, then trust what it says.
        _pendingTimers[card.id] = Timer(teamBoardPendingHold, () {
          if (mounted) setState(() => _dropPending(card.id));
        });
      }
    });
    _prune();
  }

  Future<void> _add() async {
    final title = await showTeamBoardAddSheet(context);
    if (title == null || !mounted) return;
    setState(() {
      _failure = null;
      _busy++;
    });
    final result = await _edits.addToBacklog(
      title,
      projectId: _projectFilter ?? _singleProject,
    );
    if (!mounted) return;
    setState(() {
      _busy--;
      if (!result.ok) _failure = (title, result.message);
    });
    if (result.ok) _select(TeamBoardColumn.backlog);
  }

  String? get _singleProject {
    final projects = widget.controller.snapshot.projects;
    return projects.length == 1 ? projects.single.id : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        final controller = widget.controller;
        final ready = _ready;
        if (ready) _chooseDefaultProject();
        final board = ready ? _board() : null;
        final projects = controller.snapshot.projects;
        final project = projects
            .where((p) => p.id == _projectFilter)
            .firstOrNull;
        // Once per screen (§6): an empty board offers it in its state instead.
        final canAdd =
            ready && _edits.canCreate && board != null && !board.isEmpty;
        final line = ready
            ? teamStatusLine(
                    context,
                    controller: controller,
                    keyPrefix: 'team-board',
                    onRetry: _refreshing ? null : _refresh,
                  ) ??
                  (_edits.readOnly
                      ? KitStatusLine(
                          key: const ValueKey('team-board-read-only'),
                          icon: AppIconography.locked,
                          tone: AppStatusTone.neutral,
                          message: l10n.teamBoardStatusReadOnly,
                        )
                      : null)
            : null;
        final failure = _failure;
        return Scaffold(
          key: const ValueKey('team-board'),
          appBar: AppBar(
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.teamBoardTitle, maxLines: 1),
                if (projects.length > 1 && project != null)
                  _ProjectSwitcher(
                    projects: projects,
                    current: project,
                    onSelect: (id) => setState(() {
                      _project = id;
                      _pending.clear();
                      for (final t in _pendingTimers.values) {
                        t.cancel();
                      }
                      _pendingTimers.clear();
                    }),
                  )
                else if (projects.length == 1)
                  Text(
                    projects.single.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.mutedOf(theme),
                    ),
                  ),
              ],
            ),
            actions: [
              if (canAdd)
                IconButton(
                  key: const ValueKey('team-board-add'),
                  tooltip: l10n.teamBoardAddTooltip,
                  onPressed: _add,
                  icon: const Icon(AppIconography.add),
                ),
            ],
          ),
          body: KitScreen(
            header: [
              ?line,
              // While the first answer comes the columns are already
              // there, without counts.
              if (board == null && teamScreenLoading(controller))
                TeamBoardTabs(
                  counts: null,
                  needsYou: const {},
                  selected: TeamBoardColumn.working,
                  onSelect: (_) {},
                )
              else if (board != null && !board.isEmpty)
                TeamBoardTabs(
                  counts: {
                    for (final c in TeamBoardColumn.values) c: board.count(c),
                  },
                  needsYou: {
                    for (final c in TeamBoardColumn.values)
                      if (board.needsYou(c)) c,
                  },
                  selected: _column,
                  onSelect: _select,
                ),
              KitReveal(
                child: failure == null
                    ? null
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: KitNotice(
                          key: const ValueKey('team-board-failure'),
                          tone: AppStatusTone.attention,
                          title: l10n.teamBoardMoveFailedTitle(failure.$1),
                          message: l10n.teamBoardMoveFailedBody,
                          notes: [
                            if (failure.$2?.trim() case final m?
                                when m.isNotEmpty)
                              m,
                          ],
                          onDismiss: () => setState(() => _failure = null),
                        ),
                      ),
              ),
            ],
            loading: teamScreenLoading(controller) || _refreshing || _busy > 0,
            loadingLabel: l10n.teamUiCardLoading,
            body: _body(context, board),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, TeamBoard? board) {
    final l10n = _copy(context);
    final controller = widget.controller;
    if (teamScreenFailed(controller)) {
      return teamScreenState(
            context,
            controller: controller,
            keyPrefix: 'team-board',
            onRetry: _refreshing ? null : _refresh,
          ) ??
          const SizedBox.shrink();
    }
    if (board == null) {
      // The first answer: skeleton cards in a lane (§4), and after 8 s
      // the honest "isn't answering".
      return GraceTimer(
        waiting: true,
        builder: (context, overdue) => overdue
            ? KitStateView(
                key: const ValueKey('team-board-not-answering'),
                icon: AppIconography.cloudOff,
                tone: AppStatusTone.attention,
                title: l10n.teamUiStateNotAnsweringTitle,
                body: l10n.workServerKeepsTrying,
                secondary: KitAction(
                  key: const ValueKey('team-board-retry'),
                  label: l10n.teamUiCardRetry,
                  onPressed: _refreshing ? null : _refresh,
                  icon: AppIcons.retry,
                ),
              )
            : Padding(
                key: const ValueKey('team-board-loading'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _Lane(
                  child: ListView(
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (var i = 0; i < 4; i++)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: KitPanel(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: KitSkeletonRows(count: 1),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      );
    }
    if (board.isEmpty) {
      return KitRefresh(
        onRefresh: _refresh,
        child: ListView(
          key: const ValueKey('team-board-empty'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: KitScreen.endPadding(context)),
          children: [
            KitStateView(
              icon: AppIconography.checklist,
              illustration: const TeamBoardScene(),
              title: l10n.teamBoardEmptyTitle,
              body: l10n.teamBoardEmptyBody,
              primary: _edits.canCreate
                  ? KitAction(
                      key: const ValueKey('team-board-empty-add'),
                      label: l10n.teamBoardAddButton,
                      icon: AppIconography.add,
                      onPressed: _add,
                    )
                  : null,
            ),
          ],
        ),
      );
    }
    final pages = _pagesFor(context, board);
    final stale = controller.isStale;
    return Opacity(
      // Stale cards dim; they stay readable (never colour-only).
      opacity: stale ? .6 : 1,
      child: PageView.builder(
        key: const ValueKey('team-board-pages'),
        controller: pages,
        itemCount: TeamBoardColumn.values.length,
        onPageChanged: (index) =>
            setState(() => _column = TeamBoardColumn.values[index]),
        itemBuilder: (context, index) {
          final column = TeamBoardColumn.values[index];
          return Padding(
            padding: EdgeInsets.fromLTRB(
              4,
              0,
              4,
              8 + MediaQuery.paddingOf(context).bottom,
            ),
            child: _Lane(
              key: ValueKey('team-board-column-${column.name}'),
              child: _columnView(context, board, column),
            ),
          );
        },
      ),
    );
  }

  Widget _columnView(
    BuildContext context,
    TeamBoard board,
    TeamBoardColumn column,
  ) {
    final l10n = _copy(context);
    final cards = board.cards(column);
    final now = _now;
    final Widget content;
    if (cards.isEmpty) {
      final (icon, title, body) = switch (column) {
        TeamBoardColumn.backlog => (
          AppIconography.inbox,
          l10n.teamBoardEmptyBacklogTitle,
          l10n.teamBoardEmptyBacklogBody,
        ),
        TeamBoardColumn.ready => (
          AppIconography.queueAdd,
          l10n.teamBoardEmptyReadyTitle,
          l10n.teamBoardEmptyReadyBody,
        ),
        TeamBoardColumn.working => (
          AppIconography.agent,
          l10n.teamBoardEmptyWorkingTitle,
          l10n.teamBoardEmptyWorkingBody,
        ),
        TeamBoardColumn.review => (
          AppIconography.review,
          l10n.teamBoardEmptyReviewTitle,
          l10n.teamBoardEmptyReviewBody,
        ),
        TeamBoardColumn.done => (
          AppIconography.checkCircle,
          l10n.teamBoardEmptyDoneTitle,
          l10n.teamBoardEmptyDoneBody,
        ),
      };
      content = KitStateView(
        key: ValueKey('team-board-column-empty-${column.name}'),
        size: KitStateSize.inline,
        liveRegion: false,
        icon: icon,
        title: title,
        body: body,
      );
    } else {
      content = KitAnimatedRows(
        key: ValueKey('team-board-rows-${column.name}-$_projectFilter'),
        children: [
          for (final card in cards)
            Padding(
              key: ValueKey('team-board-slot-${card.id}'),
              padding: const EdgeInsets.only(bottom: 8),
              child: TeamBoardCardView(
                card: card,
                now: now,
                onOpen: () => _open(card),
                onMoves: _edits.movesFor(card).isEmpty
                    ? null
                    : () => _showMoves(card),
                onLongPress: () => _showMoves(card),
              ),
            ),
        ],
      );
    }
    return KitRefresh(
      onRefresh: _refresh,
      child: ListView(
        key: ValueKey('team-board-list-${column.name}'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        children: [content],
      ),
    );
  }
}

/// A column's lane: a faint surface the cards sit on, so the neighbour
/// that peeks reads as another column.
class _Lane extends StatelessWidget {
  const _Lane({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? scheme.surfaceContainerLowest
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard + 4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard + 4),
        child: child,
      ),
    );
  }
}

/// The project under the title ("oc_app ▾"), opening the host's projects.
class _ProjectSwitcher extends StatelessWidget {
  const _ProjectSwitcher({
    required this.projects,
    required this.current,
    required this.onSelect,
  });

  final List<OrchestrationProject> projects;
  final OrchestrationProject current;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    return PopupMenuButton<String>(
      key: const ValueKey('team-board-project'),
      tooltip: l10n.teamBoardProjectTooltip,
      initialValue: current.id,
      position: PopupMenuPosition.under,
      onSelected: onSelect,
      itemBuilder: (context) => [
        for (final project in projects)
          CheckedPopupMenuItem<String>(
            key: ValueKey('team-board-project-${project.id}'),
            value: project.id,
            checked: project.id == current.id,
            child: Text(project.name),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              current.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
          Icon(AppIconography.chevronDown, size: 16, color: muted),
        ],
      ),
    );
  }
}
