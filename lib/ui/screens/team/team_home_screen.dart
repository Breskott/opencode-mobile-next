/// The AI Team home (02-ux-flows-and-screens §3): what the Workspace card
/// opens. An app bar with the host identity chip (tap → Technical details,
/// §8), then three segments — **Runs** (active → waiting/blocked →
/// completed, the completed group collapsed; filter chips and a title
/// search), **Agents** (the fleet rows of §5.1) and **Needs you** (the
/// gates of §6; tapping one opens the read-only Gate sheet of
/// `gate_sheet.dart`, TEAM-112).
///
/// Stale data (§10) shows the "Showing data from HH:MM" line and dims the
/// lists; pull-to-refresh and the app bar button call
/// [OrchestrationController.refresh]. A run row opens [RunScreen]
/// (TEAM-109) and an agent row [AgentScreen] (TEAM-111) unless [onOpenRun]
/// or [onOpenAgent] says otherwise. The FAB **Start a run** (TEAM-204,
/// only with `controlMessage`) opens [StartRunSheet]; its "Planning…
/// (Mayor)" cards sit above the Runs list until the run appears.
library;

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../app_theme.dart';
import '../../widgets/product_states.dart';
import '../../widgets/relative_time.dart';
import '../../widgets/team_agent_row.dart';
import '../../widgets/team_discovery_card.dart' show teamHostKindFor;
import '../../widgets/team_host_form.dart' show teamHostKindLabel;
import '../../widgets/team_receipt.dart';
import '../../widgets/team_technical_details.dart';
import '../../widgets/team_vocabulary.dart';
import 'agent_screen.dart';
import 'gate_sheet.dart';
import 'run_screen.dart';
import 'start_run_sheet.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// The three segments of the home.
enum TeamHomeSegment { runs, agents, needsYou }

/// The Runs segment's filter chips.
enum TeamRunFilter { active, blocked, completed, all }

class TeamHomeScreen extends StatefulWidget {
  const TeamHomeScreen({
    super.key,
    required this.controller,
    this.onOpenRun,
    this.onOpenAgent,
    this.now,
  });

  final OrchestrationController controller;

  /// Opens a run's detail; pushes [RunScreen] when null.
  final ValueChanged<OrchestrationRun>? onOpenRun;

  /// Opens an agent's detail; pushes [AgentScreen] when null.
  final ValueChanged<OrchestrationAgent>? onOpenAgent;

  /// Clock for relative ages and the "today" group; tests pin it.
  final DateTime Function()? now;

  @override
  State<TeamHomeScreen> createState() => _TeamHomeScreenState();
}

class _TeamHomeScreenState extends State<TeamHomeScreen> {
  TeamHomeSegment _segment = TeamHomeSegment.runs;
  TeamRunFilter _filter = TeamRunFilter.all;
  final _search = TextEditingController();
  bool _completedExpanded = false;

  /// "Show team upkeep": off on every open, never persisted.
  bool _upkeepShown = false;

  /// The "Suspended on the host" group: collapsed on every open.
  bool _suspendedExpanded = false;
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

  void _openRun(OrchestrationRun run) {
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

  void _openAgent(OrchestrationAgent agent) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AgentScreen(
          controller: widget.controller,
          agentId: agent.id,
          now: widget.now,
        ),
      ),
    );
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

  Future<void> _startRun() async {
    await showStartRunSheet(context, widget.controller);
    if (mounted) setState(() => _segment = TeamHomeSegment.runs);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final showFab =
            controller.capabilities.controlMessage &&
            controller.phase == OrchestrationPhase.ready &&
            controller.snapshot.hasData;
        return Scaffold(
          key: const ValueKey('team-home'),
          appBar: AppBar(
            title: Text(l10n.teamUiHomeTitle),
            actions: [
              IconButton(
                key: const ValueKey('team-home-refresh'),
                tooltip: l10n.teamUiRefresh,
                onPressed: _refreshing ? null : _refresh,
                icon: const Icon(AppIconography.sync),
              ),
            ],
          ),
          floatingActionButton: showFab
              ? FloatingActionButton.extended(
                  key: const ValueKey('team-home-start-run'),
                  onPressed: _startRun,
                  icon: const Icon(AppIconography.sparkle),
                  label: Text(l10n.teamUiStartRunFab),
                )
              : null,
          body: _body(context),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    final l10n = _copy(context);
    final controller = widget.controller;
    final snapshot = controller.snapshot;
    final ready =
        controller.phase == OrchestrationPhase.ready && snapshot.hasData;
    if (controller.phase == OrchestrationPhase.failed ||
        (controller.phase == OrchestrationPhase.ready &&
            !snapshot.hasData &&
            controller.lastError != null)) {
      return ProductErrorState(
        key: const ValueKey('team-home-error'),
        message: teamErrorCopy(l10n, controller.lastError?.kind),
        onRetry: _refresh,
      );
    }
    if (!ready) {
      return Center(
        key: const ValueKey('team-home-loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.teamUiCardLoading),
          ],
        ),
      );
    }

    final stale = controller.isStale;
    final gated = teamGatedRuns(snapshot);
    final attention = controller.attentionCount;
    final liveAgents = teamLiveAgents(snapshot.agents);
    final offAgents = teamOffAgents(snapshot.agents);
    final Widget list = switch (_segment) {
      TeamHomeSegment.runs => _RunsSegment(
        snapshot: snapshot,
        gated: gated,
        filter: _filter,
        search: _search,
        completedExpanded: _completedExpanded,
        upkeepShown: _upkeepShown,
        now: _now,
        cycleOf: widget.controller.cycleFor,
        onFilter: (f) => setState(() => _filter = f),
        onToggleCompleted: () =>
            setState(() => _completedExpanded = !_completedExpanded),
        onToggleUpkeep: (shown) => setState(() => _upkeepShown = shown),
        onOpenRun: widget.onOpenRun ?? _openRun,
      ),
      TeamHomeSegment.agents => _AgentsSegment(
        snapshot: snapshot,
        live: liveAgents,
        off: offAgents,
        suspendedExpanded: _suspendedExpanded,
        now: _now,
        onToggleSuspended: () =>
            setState(() => _suspendedExpanded = !_suspendedExpanded),
        onOpenAgent: widget.onOpenAgent ?? _openAgent,
      ),
      TeamHomeSegment.needsYou => _NeedsYouSegment(
        controller: controller,
        now: _now,
      ),
    };

    return Column(
      key: const ValueKey('team-home-data'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _HostChip(controller: controller),
        ),
        if (stale)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _StaleLine(
              key: const ValueKey('team-home-stale'),
              icon: AppIconography.cloudOff,
              text: l10n.teamUiCardStale(
                controller.lastRefreshedAt == null
                    ? ''
                    : teamClockLabel(context, controller.lastRefreshedAt!),
              ),
            ),
          )
        else if (controller.lastError?.kind ==
                OrchestrationErrorKind.readFailed &&
            controller.lastRefreshedAt != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: _StaleLine(
              key: const ValueKey('team-home-refresh-failed'),
              icon: AppIconography.warning,
              text: l10n.teamUiCardRefreshFailed(
                teamClockLabel(context, controller.lastRefreshedAt!),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: _Segments(
            selected: _segment,
            runs: teamVisibleRuns(snapshot.runs).length,
            agents: liveAgents.length,
            agentsOff: offAgents.length,
            needsYou: attention,
            onSelected: (s) => setState(() => _segment = s),
          ),
        ),
        if (_segment == TeamHomeSegment.runs)
          for (final request in teamPendingPlanning(controller, _now))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: TeamPlanningCard(
                controller: controller,
                request: request,
                now: widget.now,
              ),
            ),
        Expanded(
          child: RefreshIndicator(
            key: const ValueKey('team-home-pull'),
            onRefresh: _refresh,
            // Stale numbers dim; they stay readable (never colour-only).
            child: stale ? Opacity(opacity: .6, child: list) : list,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header pieces
// ---------------------------------------------------------------------------

/// "pop-os · Desktop computer · Gas City 1.4.1 · city bright-lights ·
/// read-only": the host in one line; tap for Technical details (§8). The
/// host is named by the orchestration URL's host (a name, else its
/// address) and the kind of computer, never by the connected OpenCode
/// profile: the team may run somewhere else. Two lines at most so the
/// chip never eats the list at large text; the full line is the
/// semantics label and the sheet has every value.
class _HostChip extends StatelessWidget {
  const _HostChip({required this.controller});

  final OrchestrationController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final config = controller.config;
    final host = controller.host;
    final hostMode = host?.hostMode ?? config.hostMode;
    final city = config.city.isNotEmpty ? config.city : (host?.city ?? '');
    final version = host?.version ?? l10n.teamUiVersionUnknown;
    final access = teamReadOnly(config, controller)
        ? l10n.teamUiHomeChipReadOnly
        : l10n.teamUiHomeChipControls;
    final kind = teamHostKindFor(config, hostMode);
    final name = l10n.teamUiHomeHostChipHost(
      teamHostNameOf(controller),
      teamHostKindLabel(l10n, kind),
    );
    final label = city.isEmpty
        ? l10n.teamUiHomeHostChipNoCity(name, version, access)
        : l10n.teamUiHomeHostChip(name, version, city, access);
    return Semantics(
      button: true,
      label: label,
      hint: l10n.teamUiTechnicalDetails,
      child: InkWell(
        key: const ValueKey('team-home-host-chip'),
        borderRadius: BorderRadius.circular(999),
        onTap: () => showTeamHostDetailsSheet(context, controller),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                switch (hostMode) {
                  OrchestrationHostMode.computer => AppIconography.computer,
                  OrchestrationHostMode.phone => AppIconography.phone,
                },
                size: 16,
                color: muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    label,
                    key: const ValueKey('team-home-host-chip-label'),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(AppIconography.info, size: 16, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaleLine extends StatelessWidget {
  const _StaleLine({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

/// One choice among a few, as a labelled menu button: the current choice
/// on the button, every option (the current one checked) in the menu.
/// Used at large text, where a row of segments or chips no longer fits a
/// compact phone and would push the list off screen or scroll sideways.
class _CompactChoice<T> extends StatelessWidget {
  const _CompactChoice({
    super.key,
    required this.icon,
    required this.heading,
    required this.selected,
    required this.values,
    required this.labelOf,
    required this.keyOf,
    required this.onSelected,
  });

  final IconData icon;

  /// Read before the current value ("Filters · Blocked"); null when the
  /// value speaks for itself.
  final String? heading;
  final T selected;
  final List<T> values;
  final String Function(T value) labelOf;
  final Key Function(T value) keyOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final label = labelOf(selected);
    return Semantics(
      label: [?heading, label].join(' · '),
      child: PopupMenuButton<T>(
        initialValue: selected,
        position: PopupMenuPosition.under,
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final value in values)
            CheckedPopupMenuItem<T>(
              key: keyOf(value),
              value: value,
              checked: value == selected,
              child: Text(labelOf(value)),
            ),
        ],
        child: ExcludeSemantics(
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(AppIconography.chevronDown, size: 18, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Runs · Agents · Needs you with their counts. Segments while they fit;
/// at large text one menu button so the selector stays reachable on a
/// compact phone instead of scrolling sideways.
class _Segments extends StatelessWidget {
  const _Segments({
    required this.selected,
    required this.runs,
    required this.agents,
    required this.agentsOff,
    required this.needsYou,
    required this.onSelected,
  });

  final TeamHomeSegment selected;
  final int runs;

  /// Live agents; [agentsOff] are the suspended or stopped ones, shown
  /// beside the count ("Agents (1 · 4 off)") and never added to it.
  final int agents;
  final int agentsOff;
  final int needsYou;
  final ValueChanged<TeamHomeSegment> onSelected;

  static Key keyOf(TeamHomeSegment segment) => ValueKey(switch (segment) {
    TeamHomeSegment.runs => 'team-home-segment-runs',
    TeamHomeSegment.agents => 'team-home-segment-agents',
    TeamHomeSegment.needsYou => 'team-home-segment-needs-you',
  });

  String _label(AppLocalizations l10n, TeamHomeSegment segment) =>
      switch (segment) {
        TeamHomeSegment.runs => l10n.teamUiHomeSegmentRuns(runs),
        TeamHomeSegment.agents =>
          agentsOff > 0
              ? l10n.teamUiHomeSegmentAgentsOff(agents, agentsOff)
              : l10n.teamUiHomeSegmentAgents(agents),
        TeamHomeSegment.needsYou => l10n.teamUiHomeSegmentNeedsYou(needsYou),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    if (AppTheme.stackedActions(context)) {
      return _CompactChoice<TeamHomeSegment>(
        key: const ValueKey('team-home-segments-menu'),
        icon: AppIconography.menu,
        heading: null,
        selected: selected,
        values: TeamHomeSegment.values,
        labelOf: (s) => _label(l10n, s),
        keyOf: keyOf,
        onSelected: onSelected,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<TeamHomeSegment>(
        key: const ValueKey('team-home-segments'),
        showSelectedIcon: false,
        segments: [
          for (final segment in TeamHomeSegment.values)
            ButtonSegment(
              value: segment,
              label: Text(_label(l10n, segment), key: keyOf(segment)),
            ),
        ],
        selected: {selected},
        onSelectionChanged: (value) => onSelected(value.single),
      ),
    );
  }
}

/// One empty state per segment, in the list so pull-to-refresh still works.
class _Empty extends StatelessWidget {
  const _Empty({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
  });

  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) =>
      ProductInlineEmpty(icon: icon, title: title, message: hint);
}

// ---------------------------------------------------------------------------
// Runs
// ---------------------------------------------------------------------------

class _RunsSegment extends StatelessWidget {
  const _RunsSegment({
    required this.snapshot,
    required this.gated,
    required this.filter,
    required this.search,
    required this.completedExpanded,
    required this.upkeepShown,
    required this.now,
    required this.cycleOf,
    required this.onFilter,
    required this.onToggleCompleted,
    required this.onToggleUpkeep,
    required this.onOpenRun,
  });

  final OrchestrationSnapshot snapshot;
  final Set<String> gated;
  final TeamRunFilter filter;
  final TextEditingController search;
  final bool completedExpanded;

  /// Whether the host's upkeep runs are revealed under the list.
  final bool upkeepShown;
  final DateTime now;

  /// The dispatch cycle of a work item, for the merge-wait word
  /// (TEAM-117).
  final DispatchCycle? Function(String workId) cycleOf;
  final ValueChanged<TeamRunFilter> onFilter;
  final VoidCallback onToggleCompleted;
  final ValueChanged<bool> onToggleUpkeep;
  final ValueChanged<OrchestrationRun>? onOpenRun;

  static bool _isCompleted(OrchestrationRun run) =>
      run.state == RunState.completed || run.state == RunState.cancelled;

  static String _filterLabel(AppLocalizations l10n, TeamRunFilter f) =>
      switch (f) {
        TeamRunFilter.active => l10n.teamUiHomeFilterActive,
        TeamRunFilter.blocked => l10n.teamUiHomeFilterBlocked,
        TeamRunFilter.completed => l10n.teamUiHomeFilterCompleted,
        TeamRunFilter.all => l10n.teamUiHomeFilterAll,
      };

  bool _matches(OrchestrationRun run, String query) {
    if (query.isNotEmpty && !run.title.toLowerCase().contains(query)) {
      return false;
    }
    return switch (filter) {
      TeamRunFilter.active =>
        run.state == RunState.working || run.state == RunState.planning,
      TeamRunFilter.blocked =>
        run.state == RunState.blocked ||
            run.state == RunState.failed ||
            run.state == RunState.waiting ||
            gated.contains(run.id),
      TeamRunFilter.completed => _isCompleted(run),
      TeamRunFilter.all => true,
    };
  }

  bool _today(OrchestrationRun run) {
    final at = (run.updatedAt ?? run.startedAt)?.toLocal();
    if (at == null) return false;
    final local = now.toLocal();
    return at.year == local.year &&
        at.month == local.month &&
        at.day == local.day;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final query = search.text.trim().toLowerCase();
    // The host's upkeep (patrols, chores) is hidden by default and never
    // counted; the toggle under the list reveals it.
    final runs = teamVisibleRuns(snapshot.runs);
    final upkeep = teamUpkeepRuns(snapshot.runs)
      ..sort((a, b) => teamCompareRuns(a, b, gated));
    final ordered = [...runs]..sort((a, b) => teamCompareRuns(a, b, gated));
    final visible = [
      for (final run in ordered)
        if (_matches(run, query)) run,
    ];
    // Under "All" the completed runs collapse into one group; the
    // Completed chip lists them directly.
    final collapse = filter == TeamRunFilter.all;
    final open = [
      for (final run in visible)
        if (!collapse || !_isCompleted(run)) run,
    ];
    final completed = [
      for (final run in visible)
        if (collapse && _isCompleted(run)) run,
    ];
    final allToday = completed.isNotEmpty && completed.every(_today);
    final nothingAtAll =
        runs.isEmpty && filter == TeamRunFilter.all && query.isEmpty;

    Widget row(OrchestrationRun run) => _RunRow(
      key: ValueKey('team-home-run-${run.id}'),
      run: run,
      progress: TeamRunProgress.of(run, snapshot.work),
      stateWord: teamRunStateWordFor(
        l10n,
        run,
        snapshot.work,
        cycleOf: cycleOf,
      ),
      needsYou: gated.contains(run.id),
      onTap: onOpenRun == null ? null : () => onOpenRun!(run),
    );

    return ListView(
      key: const ValueKey('team-home-runs'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (AppTheme.stackedActions(context))
          // Large text: one labelled menu instead of four stacked chips
          // that would eat most of the list on a compact phone.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _CompactChoice<TeamRunFilter>(
              key: const ValueKey('team-home-filter-menu'),
              icon: AppIconography.filter,
              heading: l10n.e7ModelUiFilters,
              selected: filter,
              values: TeamRunFilter.values,
              labelOf: (f) => _filterLabel(l10n, f),
              keyOf: (f) => ValueKey('team-home-filter-${f.name}'),
              onSelected: onFilter,
            ),
          )
        else
          // One row of chips; it scrolls sideways on a narrow phone rather
          // than wrapping into a second row.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final f in TeamRunFilter.values) ...[
                  if (f != TeamRunFilter.values.first) const SizedBox(width: 8),
                  ChoiceChip(
                    key: ValueKey('team-home-filter-${f.name}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    label: Text(_filterLabel(l10n, f)),
                    selected: filter == f,
                    onSelected: (_) => onFilter(f),
                  ),
                ],
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            key: const ValueKey('team-home-search'),
            controller: search,
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
        ),
        if (nothingAtAll)
          _Empty(
            key: const ValueKey('team-home-runs-empty'),
            icon: AppIconography.agent,
            title: l10n.teamUiCardEmptyTitle,
            hint: l10n.teamUiCardEmptyHint,
          )
        else if (visible.isEmpty)
          _Empty(
            key: const ValueKey('team-home-runs-empty-filtered'),
            icon: AppIconography.filterOff,
            title: l10n.teamUiHomeRunsEmptyFiltered,
            hint: l10n.teamUiHomeRunsEmptyHint,
          ),
        for (final run in open) row(run),
        if (completed.isNotEmpty) ...[
          InkWell(
            key: const ValueKey('team-home-completed-group'),
            onTap: onToggleCompleted,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIconography.check,
                      size: 18,
                      color: AppTheme.statusColor(theme, AppStatusTone.ok),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        allToday
                            ? l10n.teamUiHomeCompletedToday(completed.length)
                            : l10n.teamUiHomeCompletedGroup(completed.length),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.mutedOf(theme),
                        ),
                      ),
                    ),
                    Icon(
                      completedExpanded
                          ? AppIconography.chevronUp
                          : AppIconography.chevronDown,
                      size: 18,
                      color: AppTheme.mutedOf(theme),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (completedExpanded)
            for (final run in completed) row(run),
        ],
        if (upkeep.isNotEmpty) ...[
          SwitchListTile.adaptive(
            key: const ValueKey('team-home-upkeep-toggle'),
            dense: true,
            value: upkeepShown,
            onChanged: onToggleUpkeep,
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
          if (upkeepShown)
            for (final run in upkeep) row(run),
        ],
      ],
    );
  }
}

/// One idea per row: glyph, title, kind and progress underneath, the state
/// word (and "Needs you") at the end — under the title at large text.
class _RunRow extends StatelessWidget {
  const _RunRow({
    super.key,
    required this.run,
    required this.progress,
    required this.stateWord,
    required this.needsYou,
    required this.onTap,
  });

  final OrchestrationRun run;
  final TeamRunProgress progress;

  /// The run's state word, with the merge wait named (TEAM-117).
  final String stateWord;
  final bool needsYou;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final (icon, tone) = needsYou
        ? (AppIconography.warning, AppStatusTone.attention)
        : teamRunGlyph(run.state);
    final color = AppTheme.statusColor(theme, tone);
    final kind = switch (run.kind) {
      RunKind.batch => l10n.teamUiHomeRunKindBatch,
      RunKind.formula =>
        run.formula == null || run.formula!.isEmpty
            ? l10n.teamUiHomeRunKindFormula
            : l10n.teamUiHomeRunKindFormulaNamed(run.formula!),
      RunKind.unknown => null,
    };
    final steps = progress.total > 0
        ? l10n.teamUiHomeRunProgress(progress.done, progress.total)
        : null;
    final subtitle = [?kind, ?steps].join(' · ');
    final stacked = AppTheme.stackedActions(context);
    final state = Column(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stateWord,
          key: ValueKey('team-home-run-state-${run.id}'),
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
        if (needsYou)
          Text(
            l10n.teamUiHomeRunNeedsYou,
            key: ValueKey('team-home-run-needs-you-${run.id}'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.statusColor(theme, AppStatusTone.attention),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      run.title,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    if (stacked) ...[const SizedBox(height: 2), state],
                  ],
                ),
              ),
              if (!stacked) ...[const SizedBox(width: 12), state],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Agents
// ---------------------------------------------------------------------------

/// The live agents as rows, then the ones switched off on the host
/// (suspended or stopped) under one collapsed "Suspended on the host (N)"
/// group: they exist, they are not the team at work.
class _AgentsSegment extends StatelessWidget {
  const _AgentsSegment({
    required this.snapshot,
    required this.live,
    required this.off,
    required this.suspendedExpanded,
    required this.now,
    required this.onToggleSuspended,
    required this.onOpenAgent,
  });

  final OrchestrationSnapshot snapshot;
  final List<OrchestrationAgent> live;
  final List<OrchestrationAgent> off;
  final bool suspendedExpanded;
  final DateTime now;
  final VoidCallback onToggleSuspended;
  final ValueChanged<OrchestrationAgent>? onOpenAgent;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final workById = {for (final item in snapshot.work) item.id: item};
    final agents = [...live]..sort(teamCompareAgents);
    final suspended = [...off]..sort(teamCompareAgents);
    Widget row(OrchestrationAgent agent) => TeamAgentRow(
      keyPrefix: 'team-home-agent',
      agent: agent,
      work: workById[agent.currentWorkId],
      now: now,
      onTap: onOpenAgent == null ? null : () => onOpenAgent!(agent),
    );
    return ListView(
      key: const ValueKey('team-home-agents'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (agents.isEmpty)
          _Empty(
            key: const ValueKey('team-home-agents-empty'),
            icon: AppIconography.agent,
            title: l10n.teamUiHomeAgentsEmpty,
            hint: l10n.teamUiHomeAgentsEmptyHint,
          ),
        for (final agent in agents) row(agent),
        if (suspended.isNotEmpty) ...[
          InkWell(
            key: const ValueKey('team-home-suspended-group'),
            onTap: onToggleSuspended,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(AppIconography.stopCircle, size: 18, color: muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.teamUiHomeSuspendedGroup(suspended.length),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                    Icon(
                      suspendedExpanded
                          ? AppIconography.chevronUp
                          : AppIconography.chevronDown,
                      size: 18,
                      color: muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (suspendedExpanded)
            for (final agent in suspended) row(agent),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Needs you
// ---------------------------------------------------------------------------

class _NeedsYouSegment extends StatelessWidget {
  const _NeedsYouSegment({required this.controller, required this.now});

  final OrchestrationController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final snapshot = controller.snapshot;
    final gates = [...snapshot.gates]
      ..sort((a, b) {
        final rank = teamGateRank(a.kind).compareTo(teamGateRank(b.kind));
        if (rank != 0) return rank;
        final at = a.createdAt, bt = b.createdAt;
        if (at == null || bt == null) return 0;
        return bt.compareTo(at);
      });
    return ListView(
      key: const ValueKey('team-home-needs-you'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        if (gates.isEmpty)
          _Empty(
            key: const ValueKey('team-home-needs-you-empty'),
            icon: AppIconography.inbox,
            title: l10n.teamUiHomeNeedsYouEmpty,
            hint: l10n.teamUiHomeNeedsYouEmptyHint,
          ),
        // A gate answered from here leaves once the host confirmed
        // (02-ux §6); until then it stays with its receipt chip.
        for (final gate in gates)
          if (!teamGateAnswered(controller, gate))
            _GateRow(
              key: ValueKey('team-home-gate-${gate.id}'),
              gate: gate,
              link: teamGateLink(l10n, snapshot, gate),
              record: teamGateMutation(controller, gate),
              now: now,
              onTap: () =>
                  showGateSheet(context, controller, gate.id, now: () => now),
            ),
      ],
    );
  }
}

/// One row, one thing: kind glyph, the title, what it belongs to, its age,
/// and the receipt chip once an answer left this phone (TEAM-203).
class _GateRow extends StatelessWidget {
  const _GateRow({
    super.key,
    required this.gate,
    required this.link,
    required this.record,
    required this.now,
    required this.onTap,
  });

  final OrchestrationGate gate;
  final String? link;
  final MutationRecord? record;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final (icon, tone) = teamGateGlyph(gate.kind);
    final color = AppTheme.statusColor(theme, tone);
    final age = gate.createdAt == null
        ? null
        : relativeTimeLabel(
            gate.createdAt!.millisecondsSinceEpoch,
            now: now,
            l10n: l10n,
          );
    final subtitle = [
      teamGateKindWord(l10n, gate.kind),
      ?link,
      ?age,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gate.title,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (record case final record?
                  when record.status != MutationStatus.confirmed)
                TeamReceiptChip(
                  key: ValueKey('team-home-gate-${gate.id}-receipt'),
                  record: record,
                  onOpen: onTap,
                )
              else
                Icon(AppIconography.chevronRight, size: 18, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
