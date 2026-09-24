/// The AI Team home (02-ux-flows-and-screens §3, redesigned in
/// docs/design/aiteam-redesign-2026-09-24.md): what the Work tab's AI Team
/// section opens, in the person's words.
///
/// Top to bottom, in one scroll view:
///
/// 1. The top bar: "AI Team" with where the team runs as a muted subtitle
///    ("On this phone", "On pop-os", plus "· Paused" / "· Not answering");
///    its info button opens the host's Technical details. A search icon
///    joins it only when there are more than eight tasks.
/// 2. **Needs you**, only when something does: one question as a request
///    block with its answers, several as a short list of rows (the Gate
///    sheet of `gate_sheet.dart` holds the rest).
/// 3. **Tasks**: one list, what needs the person and what runs first, then
///    what waits; then **Done today** (three shown, the rest behind one
///    row). A row is the task's title, one supporting line ("Working · 3 of
///    5 steps done") and one leading mark ([KitTaskMark]); it opens
///    [RunScreen].
/// 4. One **agents** row ("3 agents · 1 working") that opens
///    [TeamAgentsScreen].
///
/// **Give the team a task** (TEAM-204, only with `controlMessage`) is the
/// screen's one primary button, pinned below the list; it opens
/// [StartRunSheet], whose planning cards sit above the tasks until the task
/// appears. Stale data shows the one status line and dims the rows; pull to
/// refresh calls [OrchestrationController.refresh].
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../widgets/team_controls.dart'
    show teamControlReceiptWord, teamControlWord;
import '../../widgets/team_receipt.dart';
import '../../widgets/team_technical_details.dart';
import '../../widgets/team_vocabulary.dart';
import 'gate_sheet.dart';
import 'run_screen.dart';
import 'start_run_sheet.dart';
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

class TeamHomeScreen extends StatefulWidget {
  const TeamHomeScreen({
    super.key,
    required this.controller,
    this.onOpenRun,
    this.onOpenAgent,
    this.now,
  });

  final OrchestrationController controller;

  /// Opens a task's detail; pushes [RunScreen] when null.
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

  /// The search field and filters, behind the top bar's search icon.
  bool _searchOpen = false;

  /// The finished tasks past the first three.
  bool _doneExpanded = false;

  /// "Show team upkeep": off on every open, never persisted.
  bool _upkeepShown = false;
  bool _refreshing = false;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _search.addListener(_changed);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _toggleSearch() => setState(() {
    _searchOpen = !_searchOpen;
    if (!_searchOpen) {
      _search.clear();
      _filter = TeamRunFilter.all;
    }
  });

  void _openRun(OrchestrationRun run) {
    final open = widget.onOpenRun;
    if (open != null) return open(run);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RunScreen(
          controller: widget.controller,
          runId: run.id,
          now: widget.now,
        ),
      ),
    );
  }

  void _openAgents() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
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
    final record = await showStartRunSheet(context, widget.controller);
    if (!mounted) return;
    // A planner message shows as the planning card; a direct task
    // (TEAM-306) has no card of its own, so its receipt is said once here:
    // "Task sent to an agent · Confirmed", or the host's refusal.
    if (record == null || record.kind == MutationKind.message) return;
    final l10n = _copy(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        key: const ValueKey('team-home-direct-receipt'),
        content: Text(
          record.status == MutationStatus.rejected
              ? teamReceiptLine(l10n, record)
              : '${teamControlWord(l10n, record.request)} · '
                    '${teamControlReceiptWord(l10n, record.status)}',
        ),
      ),
    );
  }

  /// Title and subtitle need more than the default toolbar at large text.
  double _toolbarHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final needed = scaler.scale(22) * 1.3 + scaler.scale(12) * 1.4 + 12;
    return math.max(kToolbarHeight, needed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final theme = Theme.of(context);
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
        return Scaffold(
          key: const ValueKey('team-home'),
          appBar: AppBar(
            toolbarHeight: _toolbarHeight(context),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.teamUiHomeTitle, maxLines: 1),
                // Where the team runs, in one phrase; the address, the
                // version and the engine are behind the info button.
                Text(
                  teamHostPhrase(l10n, controller),
                  key: const ValueKey('team-home-host'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.mutedOf(theme),
                  ),
                ),
              ],
            ),
            actions: [
              if (searchable || _searchOpen)
                IconButton(
                  key: const ValueKey('team-home-search-open'),
                  tooltip: _searchOpen
                      ? l10n.teamUiHomeSearchClose
                      : l10n.teamUiHomeSearchHint,
                  onPressed: _toggleSearch,
                  icon: Icon(
                    _searchOpen ? AppIconography.close : AppIconography.search,
                  ),
                ),
              IconButton(
                key: const ValueKey('team-home-info'),
                tooltip: l10n.teamUiTechnicalDetails,
                onPressed: () => showTeamHostDetailsSheet(context, controller),
                icon: const Icon(AppIconography.info),
              ),
            ],
          ),
          body: KitScreen(
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
          ),
        );
      },
    );
  }

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
    final theme = Theme.of(context);
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
    // counted; the toggle under the list reveals it.
    final runs = teamVisibleRuns(snapshot.runs);
    final upkeep = teamUpkeepRuns(snapshot.runs)
      ..sort((a, b) => teamCompareRuns(a, b, gated));
    final ordered = [...runs]..sort((a, b) => teamCompareRuns(a, b, gated));
    final query = _search.text.trim().toLowerCase();
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
          ),
        ),
        supportingKey: ValueKey('team-home-run-state-${run.id}'),
        onTap: () => _openRun(run),
      );
    }

    // The first section sits close under the top bar; the rest keep the
    // list's section spacing.
    var first = true;
    Widget label(String text, {Key? key}) {
      final padding = first
          ? const EdgeInsets.fromLTRB(16, 12, 16, 8)
          : const EdgeInsets.fromLTRB(16, 24, 16, 8);
      first = false;
      return SectionLabel(text, key: key, padding: padding);
    }

    final lead = <Widget>[
      if (_searchOpen)
        _SearchBar(
          search: _search,
          filter: _filter,
          onFilter: (f) => setState(() => _filter = f),
        ),
      for (final request in teamPendingPlanning(controller, _now))
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TeamPlanningCard(
            controller: controller,
            request: request,
            now: widget.now,
          ),
        ),
    ];

    final children = <Widget>[
      // 1. What needs the person, first, and only when something does.
      if (gates.isNotEmpty) ...[
        label(
          l10n.teamUiRunNeedsYou,
          key: const ValueKey('team-home-needs-you'),
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
      // 2. The tasks: one list, then what finished.
      if (runs.isEmpty)
        KitStateView(
          key: const ValueKey('team-home-runs-empty'),
          size: KitStateSize.inline,
          liveRegion: false,
          icon: AppIconography.checklist,
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
      if (open.isNotEmpty) ...[
        label(
          l10n.teamUiHomeTasksHeading,
          key: const ValueKey('team-home-tasks'),
        ),
        for (final run in open) row(run),
      ],
      if (done.isNotEmpty) ...[
        label(
          done.every(_today)
              ? l10n.teamUiHomeDoneToday
              : l10n.teamUiHomeDoneEarlier,
          key: const ValueKey('team-home-completed-group'),
        ),
        for (final run in doneShown) row(run),
        if (hiddenDone > 0)
          KitRow(
            key: const ValueKey('team-home-completed-more'),
            leading: KitRow.icon(context, AppIconography.chevronDown),
            title: l10n.teamUiHomeDoneMore(hiddenDone),
            onTap: () => setState(() => _doneExpanded = true),
          ),
      ],
      if (upkeep.isNotEmpty) ...[
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          key: const ValueKey('team-home-upkeep-toggle'),
          dense: true,
          value: _upkeepShown,
          onChanged: (shown) => setState(() => _upkeepShown = shown),
          title: Text(
            l10n.teamUiHomeUpkeepToggle(upkeep.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.mutedOf(theme),
            ),
          ),
          subtitle: Text(
            l10n.teamUiHomeUpkeepHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.mutedOf(theme),
            ),
          ),
        ),
        if (_upkeepShown)
          for (final run in upkeep) row(run),
      ],
      // 3. The team itself: one row, not a tab.
      const SizedBox(height: 16),
      _AgentsRow(
        key: const ValueKey('team-home-agents-row'),
        live: live.length,
        working: working,
        onTap: _openAgents,
      ),
    ];

    return KeyedSubtree(
      key: const ValueKey('team-home-data'),
      child: RefreshIndicator(
        key: const ValueKey('team-home-pull'),
        onRefresh: _refresh,
        child: ListView(
          key: const ValueKey('team-home-runs'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: KitScreen.endPadding(context)),
          children: [
            ...lead,
            // Stale rows dim; they stay readable (never colour-only).
            if (controller.isStale)
              Opacity(
                opacity: .6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              )
            else
              ...children,
          ],
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
    required this.working,
    required this.onTap,
  });

  final int live;
  final int working;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final muted = AppTheme.mutedOf(Theme.of(context));
    final title = [
      l10n.teamUiHomeAgentsRowCount(live),
      if (working > 0) l10n.teamUiHomeAgentsRowWorking(working),
    ].join(teamUsageSeparator);
    return Semantics(
      button: true,
      hint: l10n.teamUiHomeAgentsRowHint,
      child: KitRow(
        leading: KitRow.icon(context, AppIconography.agent),
        title: title,
        trailing: Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: Icon(AppIconography.chevronRight, size: 20, color: muted),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// The search field and the one filter menu, shown under the top bar once
/// its search icon is tapped (more than eight tasks only).
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.search,
    required this.filter,
    required this.onFilter,
  });

  final TextEditingController search;
  final TeamRunFilter filter;
  final ValueChanged<TeamRunFilter> onFilter;

  static String _label(AppLocalizations l10n, TeamRunFilter f) => switch (f) {
    TeamRunFilter.active => l10n.teamUiHomeFilterActive,
    TeamRunFilter.blocked => l10n.teamUiHomeFilterBlocked,
    TeamRunFilter.completed => l10n.teamUiHomeFilterCompleted,
    TeamRunFilter.all => l10n.teamUiHomeFilterAll,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final label = _label(l10n, filter);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('team-home-search'),
            controller: search,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.teamUiHomeSearchHint,
              prefixIcon: const Icon(AppIconography.search),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      key: const ValueKey('team-home-search-clear'),
                      tooltip: l10n.teamUiHomeSearchClear,
                      onPressed: search.clear,
                      icon: const Icon(AppIconography.close),
                    ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 4),
          // One menu, not a row of chips.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              label: '${l10n.e7ModelUiFilters} · $label',
              child: PopupMenuButton<TeamRunFilter>(
                key: const ValueKey('team-home-filter-menu'),
                initialValue: filter,
                position: PopupMenuPosition.under,
                onSelected: onFilter,
                itemBuilder: (context) => [
                  for (final f in TeamRunFilter.values)
                    CheckedPopupMenuItem<TeamRunFilter>(
                      key: ValueKey('team-home-filter-${f.name}'),
                      value: f,
                      checked: f == filter,
                      child: Text(_label(l10n, f)),
                    ),
                ],
                child: ExcludeSemantics(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppIconography.filter, size: 18, color: muted),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            label,
                            style: theme.textTheme.labelLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          AppIconography.chevronDown,
                          size: 18,
                          color: muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
