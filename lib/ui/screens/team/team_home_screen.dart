/// The AI Team home (02-ux-flows-and-screens §3, redesigned in
/// docs/design/aiteam-redesign-2026-09-24.md): what the Work tab's AI Team
/// section opens, in the person's words.
///
/// Top to bottom, in one scroll view:
///
/// 1. The top bar ([KitTopBar]): "AI Team" with where the team runs as its
///    subtitle ("On this phone", "On pop-os", plus "· Paused" / "· Not
///    answering"); Technical details and the board are its actions. Search
///    joins them only when there are more than eight tasks, and opens the
///    pinned [KitSearchField] with its one filter menu.
/// 2. **Needs you**, only when something does: one question as a request
///    block with its answers, several as rows on one panel (the Gate sheet
///    of `gate_sheet.dart` holds the rest).
/// 3. **Tasks**: one panel of rows, what needs the person and what runs
///    first, then what waits; then **Done today** (three shown, the rest
///    behind one row). A row is the task's title, one supporting line
///    ("Working · 3 of 5 steps done") and one leading mark ([KitTaskMark]);
///    it opens the task's conversation ([TeamConversation.open]), the same
///    page every other door to a task opens.
/// 4. One **agents** row ("3 agents · 1 working") that opens
///    [TeamAgentsScreen], and the board row.
///
/// **Give the team a task** (TEAM-204, only with `controlMessage`) is the
/// screen's one primary button, pinned below the list; it opens
/// [StartRunSheet] through [TeamConversation.start], so a task given here
/// lands in its conversation like one given from Solo · Team. A task the
/// host made but its workers refused comes back as a notice at the top of
/// the list. Old data shows the one status line with its age (the rows
/// stay at full strength, LOOK-14); pull to refresh calls
/// [OrchestrationController.refresh].
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../kit/scenes/team_scenes.dart';
import '../../widgets/team_moments.dart';
import '../../widgets/team_now.dart';
import '../../widgets/team_receipt.dart';
import '../../widgets/team_technical_details.dart';
import '../../widgets/team_vocabulary.dart';
import '../team_conversation/team_conversation.dart' show TeamConversation;
import 'gate_sheet.dart';
import 'start_run_sheet.dart';
import 'team_board_screen.dart';
import 'team_agents_screen.dart';
import 'team_needs_you.dart';
import 'team_states.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// The task search's filters, offered with the search field only.
enum TeamRunFilter { active, blocked, completed, all }

/// Search and filters appear only for a longer list than this: a short
/// list needs no controls to find a task in it.
const teamHomeSearchAfter = 8;

/// Finished tasks shown before "Show N more".
const teamHomeDoneShown = 3;

// revamp: redesign (slice-P3.4)
// revamp: merge-into:team-home (slice-P3.4) for team-home-runs-tab,
// team-home-agents-tab and team-home-needs-you-tab: the three old tabs are
// this page's Tasks section, agents row and Needs you section.
class TeamHomeScreen extends StatefulWidget {
  const TeamHomeScreen({
    super.key,
    required this.controller,
    this.onOpenRun,
    this.onOpenAgent,
    this.now,
  });

  final OrchestrationController controller;

  /// Opens a task; its conversation ([TeamConversation.open]) when null.
  final ValueChanged<OrchestrationRun>? onOpenRun;

  /// Opens an agent's detail from the agents list; pushes [AgentScreen]
  /// when null.
  final ValueChanged<OrchestrationAgent>? onOpenAgent;

  /// Clock for relative ages and the "today" group; tests pin it.
  final DateTime Function()? now;

  @override
  State<TeamHomeScreen> createState() => _TeamHomeScreenState();
}

class _TeamHomeScreenState extends State<TeamHomeScreen> {
  TeamRunFilter _filter = TeamRunFilter.all;
  final _search = TextEditingController();
  String _query = '';

  /// The search field and filters, behind the top bar's search action.
  bool _searchOpen = false;

  /// The finished tasks past the first three.
  bool _doneExpanded = false;

  /// "Show team upkeep": off on every open, never persisted.
  bool _upkeepShown = false;
  bool _refreshing = false;

  /// A task the host made but its workers refused, said once at the top
  /// of the list until dismissed.
  MutationRecord? _refusal;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() => setState(() {
    _searchOpen = !_searchOpen;
    if (!_searchOpen) {
      _search.clear();
      _query = '';
      _filter = TeamRunFilter.all;
    }
  });

  void _openRun(OrchestrationRun run) {
    final open = widget.onOpenRun;
    if (open != null) return open(run);
    unawaited(TeamConversation.open(context, widget.controller, runId: run.id));
  }

  void _openAgents() {
    Navigator.of(context).push(
      KitPageRoute<void>(
        builder: (_) => TeamAgentsScreen(
          controller: widget.controller,
          onOpenAgent: widget.onOpenAgent,
          now: widget.now,
        ),
      ),
    );
  }

  void _openGate(OrchestrationGate gate) =>
      showGateSheet(context, widget.controller, gate.id, now: () => _now);

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

  Future<void> _startRun() async {
    // The task's conversation opens once the host took it (the planner's
    // message or the direct task); back here, a refusal the sheet did not
    // say (the work item made, its worker pool refused it) is said once.
    final record = await TeamConversation.start(context, widget.controller);
    if (!mounted) return;
    if (record == null ||
        record.kind == MutationKind.message ||
        record.status != MutationStatus.rejected) {
      return;
    }
    setState(() => _refusal = record);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final ready =
            controller.phase == OrchestrationPhase.ready &&
            controller.snapshot.hasData;
        // The one primary action (design standard §2): pinned below the
        // list, never over it, only where this phone can give a task.
        final canStart = controller.capabilities.controlMessage && ready;
        final searchable =
            ready &&
            teamVisibleRuns(controller.snapshot.runs).length >
                teamHomeSearchAfter;
        final line = ready
            ? teamStatusLine(
                context,
                controller: controller,
                keyPrefix: 'team-home',
                onRetry: _refreshing ? null : _refresh,
              )
            : null;
        return KitScreen(
          key: const ValueKey('team-home'),
          topBar: KitTopBar(
            title: l10n.teamUiHomeTitle,
            // Where the team runs, in one phrase; the address, the version
            // and the engine are behind Technical details.
            subtitle: teamHostPhrase(l10n, controller),
            actions: [
              if (searchable || _searchOpen)
                KitAction(
                  key: const ValueKey('team-home-search-open'),
                  label: _searchOpen
                      ? l10n.teamUiHomeSearchClose
                      : l10n.teamUiHomeSearchHint,
                  icon: _searchOpen
                      ? AppIconography.close
                      : AppIconography.search,
                  onPressed: _toggleSearch,
                ),
              KitAction(
                key: const ValueKey('team-home-info'),
                label: l10n.teamUiTechnicalDetails,
                icon: AppIconography.info,
                onPressed: () => showTeamHostDetailsSheet(context, controller),
              ),
              // The board (docs/design/team-board-2026-09-26.md).
              if (ready)
                KitAction(
                  key: const ValueKey('team-home-board'),
                  label: l10n.teamBoardOpenTooltip,
                  icon: AppIconography.kanban,
                  onPressed: () =>
                      openTeamBoard(context, controller, now: widget.now),
                ),
            ],
            menuKey: const ValueKey('team-home-more'),
          ),
          // A list on its own: centred at the list width on a PC.
          width: KitScreenWidth.list,
          search: _searchOpen && ready ? _searchField(l10n) : null,
          header: [?line],
          loading: teamScreenLoading(controller) || _refreshing,
          loadingLabel: l10n.teamUiCardLoading,
          body: _body(context),
          bottom: canStart
              ? KitButton.primary(
                  key: const ValueKey('team-home-start-run'),
                  label: l10n.teamUiStartRunFab,
                  icon: AppIconography.add,
                  onPressed: _startRun,
                )
              : null,
        );
      },
    );
  }

  static String _filterLabel(AppLocalizations l10n, TeamRunFilter f) =>
      switch (f) {
        TeamRunFilter.active => l10n.teamUiHomeFilterActive,
        TeamRunFilter.blocked => l10n.teamUiHomeFilterBlocked,
        TeamRunFilter.completed => l10n.teamUiHomeFilterCompleted,
        TeamRunFilter.all => l10n.teamUiHomeFilterAll,
      };

  /// The search field and its one filter menu (never a row of chips); the
  /// chosen filter reads as a removable chip in words.
  KitSearchField _searchField(AppLocalizations l10n) => KitSearchField(
    label: l10n.teamUiHomeSearchHint,
    controller: _search,
    autofocus: true,
    onChanged: (query) => setState(() => _query = query),
    filters: [
      for (final f in TeamRunFilter.values)
        KitMenuItem(
          key: ValueKey('team-home-filter-${f.name}'),
          label: _filterLabel(l10n, f),
          checked: f == _filter,
          onSelected: () => setState(() => _filter = f),
        ),
    ],
    activeFilter: _filter == TeamRunFilter.all
        ? null
        : _filterLabel(l10n, _filter),
    onClearFilter: () => setState(() => _filter = TeamRunFilter.all),
    fieldKey: const ValueKey('team-home-search'),
    clearKey: const ValueKey('team-home-search-clear'),
    filterKey: const ValueKey('team-home-filter-menu'),
  );

  static bool _isFinished(OrchestrationRun run) =>
      run.state == RunState.completed || run.state == RunState.cancelled;

  bool _matches(OrchestrationRun run, String query, Set<String> gated) {
    if (query.isNotEmpty && !run.title.toLowerCase().contains(query)) {
      return false;
    }
    return switch (_filter) {
      TeamRunFilter.active =>
        run.state == RunState.working || run.state == RunState.planning,
      TeamRunFilter.blocked =>
        run.state == RunState.blocked ||
            run.state == RunState.failed ||
            run.state == RunState.waiting ||
            gated.contains(run.id),
      TeamRunFilter.completed => _isFinished(run),
      TeamRunFilter.all => true,
    };
  }

  bool _today(OrchestrationRun run) {
    final at = (run.finishedAt ?? run.updatedAt ?? run.startedAt)?.toLocal();
    if (at == null) return false;
    final local = _now.toLocal();
    return at.year == local.year &&
        at.month == local.month &&
        at.day == local.day;
  }

  Widget _body(BuildContext context) {
    final l10n = _copy(context);
    final tokens = KitTokens.of(context);
    final controller = widget.controller;
    if (teamScreenState(
          context,
          controller: controller,
          keyPrefix: 'team-home',
          onRetry: _refreshing ? null : _refresh,
        )
        case final state?) {
      return state;
    }

    final snapshot = controller.snapshot;
    final gated = teamGatedRuns(snapshot);
    final gates = teamOpenGates(controller);
    // The host's upkeep (patrols, chores) is hidden by default and never
    // counted; the switch under the list reveals it.
    final runs = teamVisibleRuns(snapshot.runs);
    final upkeep = teamUpkeepRuns(snapshot.runs)
      ..sort((a, b) => teamCompareRuns(a, b, gated));
    final ordered = [...runs]..sort((a, b) => teamCompareRuns(a, b, gated));
    final query = (_searchOpen ? _query : '').trim().toLowerCase();
    final filtering =
        _searchOpen && (query.isNotEmpty || _filter != TeamRunFilter.all);
    final visible = [
      for (final run in ordered)
        if (!filtering || _matches(run, query, gated)) run,
    ];
    final open = [
      for (final run in visible)
        if (!_isFinished(run)) run,
    ];
    final done = [
      for (final run in visible)
        if (_isFinished(run)) run,
    ];
    final doneShown = _doneExpanded || filtering
        ? done
        : done.take(teamHomeDoneShown).toList();
    final hiddenDone = done.length - doneShown.length;
    final live = teamLiveAgents(snapshot.agents);
    final working = live.where((a) => a.state == AgentState.working).length;

    Widget row(OrchestrationRun run) {
      final needsYou = gated.contains(run.id);
      return KitRow(
        key: ValueKey('team-home-run-${run.id}'),
        leading: KitTaskMark(state: teamRunMark(run, needsYou: needsYou)),
        // A task's title is the person's own objective: two lines.
        title: run.title,
        titleMaxLines: 2,
        supporting: TextSpan(
          text: teamTaskLine(
            l10n,
            run,
            snapshot.work,
            needsYou: needsYou,
            now: _now,
            cycleOf: controller.cycleFor,
            explainWait: true,
            checkEvery: teamCheckInterval(controller),
            paused: teamRest(snapshot.agents) == TeamRest.paused,
          ),
        ),
        supportingMaxLines: 2,
        supportingKey: ValueKey('team-home-run-state-${run.id}'),
        onTap: () => _openRun(run),
      );
    }

    // The first section sits close under the top bar; the rest keep the
    // list's section spacing.
    final gap = SizedBox(height: tokens.sectionGap);
    final planning = teamPendingPlanning(controller, _now);
    // One status line (design standard §5): old data wins; else the team's
    // Now (what it is doing, what happens next) heads the list, where it
    // scrolls with it instead of taking room from the tasks.
    final now =
        teamStatusLine(
              context,
              controller: controller,
              keyPrefix: 'team-home',
              onRetry: null,
            ) ==
            null
        ? teamNowLine(
            context,
            controller: controller,
            now: _now,
            keyPrefix: 'team-home-now',
          )
        : null;
    final refusal = _refusal;
    final inset = EdgeInsetsDirectional.symmetric(
      horizontal: tokens.gutter,
      vertical: tokens.space2,
    );
    final children = <Widget>[
      ?now,
      if (refusal != null)
        Padding(
          padding: inset,
          child: KitNotice(
            key: const ValueKey('team-home-direct-receipt'),
            tone: AppStatusTone.failure,
            icon: AppIconography.error,
            message: teamReceiptLine(l10n, refusal),
            onDismiss: () => setState(() => _refusal = null),
          ),
        ),
      for (final (index, request) in planning.indexed)
        Padding(
          padding: inset,
          child: TeamPlanningCard(
            controller: controller,
            request: request,
            now: widget.now,
            // One moving drawing per screen (design standard §10).
            ambient: index == 0,
          ),
        ),
      // 1. What needs the person, first, and only when something does.
      if (gates.isNotEmpty) ...[
        // The heading's agent peeks over the block and waves once.
        TeamNeedsYouLabel(
          l10n.teamUiRunNeedsYou,
          key: const ValueKey('team-home-needs-you'),
          profileId: controller.profileId,
          gateIds: [for (final gate in gates) gate.id],
          padding: EdgeInsets.fromLTRB(
            tokens.gutter,
            tokens.space3,
            tokens.gutter,
            tokens.labelGap,
          ),
        ),
        if (gates.length == 1)
          TeamNeedsYouCard(
            keyPrefix: 'team-home-gate-${gates.single.id}',
            controller: controller,
            gate: gates.single,
            title:
                teamGateRun(snapshot, gates.single)?.title ??
                l10n.teamUiHomeNeedsYouFallbackTitle,
            onOpen: () => _openGate(gates.single),
          )
        else
          KitRowGroup(
            children: [
              for (final gate in gates)
                TeamGateRow(
                  key: ValueKey('team-home-gate-${gate.id}'),
                  receiptKey: ValueKey('team-home-gate-${gate.id}-receipt'),
                  controller: controller,
                  gate: gate,
                  now: _now,
                  onTap: () => _openGate(gate),
                ),
            ],
          ),
        gap,
      ] else
        SizedBox(height: tokens.space3),
      // 2. The tasks: one panel, then what finished.
      if (runs.isEmpty)
        KitStateView(
          key: const ValueKey('team-home-runs-empty'),
          size: KitStateSize.inline,
          liveRegion: false,
          icon: AppIconography.checklist,
          // The team gathered at an empty board, its one slot waiting;
          // not while a task is being planned, whose card has the drawing.
          illustration: planning.isEmpty ? const TeamBoardScene() : null,
          // Room for the board and its three agents to read (88 dp, the
          // inline default, cramped them).
          illustrationWidth: 168,
          title: l10n.teamUiCardEmptyTitle,
          // One sentence that teaches; the pinned button is the action, so
          // the state never repeats it.
          body: controller.capabilities.controlMessage
              ? l10n.emptyTeachTeamRunsMessage
              : l10n.teamUiCardEmptyHint,
        )
      else if (visible.isEmpty)
        KitStateView(
          key: const ValueKey('team-home-runs-empty-filtered'),
          size: KitStateSize.inline,
          liveRegion: false,
          icon: AppIconography.filterOff,
          title: l10n.teamUiHomeRunsEmptyFiltered,
          body: l10n.teamUiHomeRunsEmptyHint,
        ),
      if (runs.isEmpty || visible.isEmpty) gap,
      if (open.isNotEmpty) ...[
        KitRowGroup(
          key: const ValueKey('team-home-tasks'),
          label: l10n.teamUiHomeTasksHeading,
          children: [for (final run in open) row(run)],
        ),
        gap,
      ],
      if (done.isNotEmpty) ...[
        KitRowGroup(
          key: const ValueKey('team-home-completed-group'),
          label: done.every(_today)
              ? l10n.teamUiHomeDoneToday
              : l10n.teamUiHomeDoneEarlier,
          children: [
            for (final run in doneShown) row(run),
            if (hiddenDone > 0)
              KitRow(
                key: const ValueKey('team-home-completed-more'),
                leading: KitRow.icon(context, AppIconography.chevronDown),
                title: l10n.teamUiHomeDoneMore(hiddenDone),
                onTap: () => setState(() => _doneExpanded = true),
              ),
          ],
        ),
        gap,
      ],
      if (upkeep.isNotEmpty) ...[
        KitRowGroup(
          leadingIcons: false,
          children: [
            KitSwitchRow(
              key: const ValueKey('team-home-upkeep-row'),
              switchKey: const ValueKey('team-home-upkeep-toggle'),
              title: l10n.teamUiHomeUpkeepToggle(upkeep.length),
              supporting: l10n.teamUiHomeUpkeepHint,
              value: _upkeepShown,
              onChanged: (shown) => setState(() => _upkeepShown = shown),
            ),
            if (_upkeepShown)
              for (final run in upkeep) row(run),
          ],
        ),
        gap,
      ],
      // 3. The team itself: one row, not a tab; then every task by where
      // it stands (docs/design/team-board-2026-09-26.md).
      KitRowGroup(
        children: [
          _AgentsRow(
            key: const ValueKey('team-home-agents-row'),
            live: live.length,
            total: snapshot.agents.length,
            rest: teamRest(snapshot.agents),
            working: working,
            onTap: _openAgents,
          ),
          KitRow(
            key: const ValueKey('team-home-board-row'),
            leading: KitRow.icon(context, AppIconography.kanban),
            title: l10n.teamBoardViewRow,
            supporting: TextSpan(text: l10n.teamBoardViewRowSupporting),
            trailing: const KitChevron(),
            onTap: () => openTeamBoard(context, controller, now: widget.now),
          ),
        ],
      ),
    ];

    return KeyedSubtree(
      key: const ValueKey('team-home-data'),
      child: KitRefresh(
        key: const ValueKey('team-home-pull'),
        onRefresh: _refresh,
        child: ListView(
          key: const ValueKey('team-home-runs'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsetsDirectional.only(
            bottom: KitScreen.endPadding(context),
          ),
          children: children,
        ),
      ),
    );
  }
}

/// "3 agents · 1 working", opening the agents list.
class _AgentsRow extends StatelessWidget {
  const _AgentsRow({
    super.key,
    required this.live,
    required this.total,
    required this.rest,
    required this.working,
    required this.onTap,
  });

  final int live;

  /// Every agent the host lists, asleep and paused ones included.
  final int total;
  final TeamRest rest;
  final int working;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    // Asleep agents are the team too: "3 agents · asleep until there is
    // work", not "No agents".
    final title = switch (rest) {
      TeamRest.asleep => [
        l10n.teamUiHomeAgentsRowCount(total),
        l10n.teamNowAgentsAsleep,
      ],
      TeamRest.paused => [
        l10n.teamUiHomeAgentsRowCount(total),
        l10n.teamNowAgentsPaused,
      ],
      TeamRest.awake => [
        l10n.teamUiHomeAgentsRowCount(live),
        if (working > 0) l10n.teamUiHomeAgentsRowWorking(working),
      ],
    }.join(teamUsageSeparator);
    return Semantics(
      button: true,
      hint: l10n.teamUiHomeAgentsRowHint,
      child: KitRow(
        leading: KitRow.icon(context, AppIconography.agent),
        title: title,
        trailing: const KitChevron(),
        onTap: onTap,
      ),
    );
  }
}
