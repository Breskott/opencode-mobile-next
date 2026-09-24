/// The AI Team home (02-ux-flows-and-screens §3): what the Workspace card
/// opens. An app bar with the host identity chip (tap → Technical details,
/// §8), then three segments — **Runs** (active → waiting/blocked →
/// completed, the completed group collapsed; filter chips and a title
/// search), **Agents** (the fleet rows of §5.1) and **Needs you** (the
/// gates of §6; tapping one opens the read-only Gate sheet of
/// `gate_sheet.dart`, TEAM-112).
///
/// Stale data (§10) shows the "Showing data from HH:MM" status line and
/// dims the rows; pull-to-refresh and the app bar button call
/// [OrchestrationController.refresh]. A run row opens [RunScreen]
/// (TEAM-109) and an agent row [AgentScreen] (TEAM-111) unless [onOpenRun]
/// or [onOpenAgent] says otherwise. **Start a run** (TEAM-204, only with
/// `controlMessage`) is the screen's one primary button, pinned below the
/// list; it opens [StartRunSheet], whose "Planning… (Mayor)" cards sit
/// above the Runs list until the run appears.
///
/// Design standard (docs/design/design-standard.md): one scroll view with
/// the host line and segments at its top, one loading bar, the shared
/// states of `team_states.dart`, rows on `KitRow`.
library;

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../widgets/relative_time.dart';
import '../../widgets/team_agent_row.dart';
import '../../widgets/team_discovery_card.dart' show teamHostKindFor;
import '../../widgets/team_host_form.dart' show teamHostKindLabel;
import '../../widgets/team_controls.dart'
    show teamControlReceiptWord, teamControlWord;
import '../../widgets/team_receipt.dart';
import '../../widgets/team_technical_details.dart';
import '../../widgets/team_vocabulary.dart';
import 'agent_screen.dart';
import 'gate_sheet.dart';
import 'run_screen.dart';
import 'start_run_sheet.dart';
import 'team_states.dart';

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
    final record = await showStartRunSheet(context, widget.controller);
    if (!mounted) return;
    setState(() => _segment = TeamHomeSegment.runs);
    // A planner message shows as the Planning card; a direct task
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
        // list, never over it, only where this phone can start a run.
        final canStart = controller.capabilities.controlMessage && ready;
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
          body: KitScreen(
            header: [?line],
            loading: teamScreenLoading(controller) || _refreshing,
            loadingLabel: l10n.teamUiCardLoading,
            body: _body(context),
            bottom: canStart
                ? KitButton.primary(
                    key: const ValueKey('team-home-start-run'),
                    label: l10n.teamUiStartRunFab,
                    icon: AppIconography.sparkle,
                    onPressed: _startRun,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    final controller = widget.controller;
    final snapshot = controller.snapshot;
    if (teamScreenState(
          context,
          controller: controller,
          keyPrefix: 'team-home',
          onRetry: _refreshing ? null : _refresh,
        )
        case final state?) {
      return state;
    }

    final stale = controller.isStale;
    final gated = teamGatedRuns(snapshot);
    final attention = controller.attentionCount;
    final liveAgents = teamLiveAgents(snapshot.agents);
    final offAgents = teamOffAgents(snapshot.agents);
    // The header scrolls with the rows (design standard §1: one scroll
    // view), so at large text nothing fixed eats the list.
    final lead = <Widget>[
      _HostChip(controller: controller),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
    ];
    final Widget list = switch (_segment) {
      TeamHomeSegment.runs => _RunsSegment(
        lead: lead,
        dim: stale,
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
        // The same gate as the Start a run button: the capability, not the
        // backend, decides whether the empty list may teach it.
        canStartRun: widget.controller.capabilities.controlMessage,
      ),
      TeamHomeSegment.agents => _AgentsSegment(
        lead: lead,
        dim: stale,
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
        lead: lead,
        dim: stale,
        controller: controller,
        now: _now,
      ),
    };

    return KeyedSubtree(
      key: const ValueKey('team-home-data'),
      child: RefreshIndicator(
        key: const ValueKey('team-home-pull'),
        onRefresh: _refresh,
        child: list,
      ),
    );
  }
}

/// The home's one scroll view: [lead] (the header rows), then [children],
/// dimmed while the data is stale (they stay readable, never colour-only).
Widget _homeList(
  BuildContext context, {
  required Key key,
  required List<Widget> lead,
  required bool dim,
  required List<Widget> children,
}) => ListView(
  key: key,
  physics: const AlwaysScrollableScrollPhysics(),
  padding: EdgeInsets.only(bottom: KitScreen.endPadding(context)),
  children: [
    ...lead,
    if (dim)
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
);

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
        onTap: () => showTeamHostDetailsSheet(context, controller),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
            child: Row(
              children: [
                Icon(
                  switch (hostMode) {
                    OrchestrationHostMode.computer => AppIconography.computer,
                    OrchestrationHostMode.phone => AppIconography.phone,
                  },
                  size: 18,
                  color: muted,
                ),
                const SizedBox(width: 12),
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
                const SizedBox(width: 8),
                Icon(AppIconography.info, size: 18, color: muted),
              ],
            ),
          ),
        ),
      ),
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

/// One empty state per segment, in the list so pull-to-refresh still works
/// (design standard §3, inline). No button of its own: where a run can be
/// started, the screen's one primary action is pinned below the list.
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
  Widget build(BuildContext context) => KitStateView(
    size: KitStateSize.inline,
    liveRegion: false,
    icon: icon,
    title: title,
    body: hint,
  );
}

/// A collapsible group heading row ("Completed (3)", "Suspended on the
/// host (4)"): the state lives in the row, the chevron says it opens.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    super.key,
    required this.icon,
    required this.title,
    required this.expanded,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.mutedOf(Theme.of(context));
    return Semantics(
      button: true,
      expanded: expanded,
      child: KitRow(
        leading: KitRow.icon(context, icon, color: iconColor),
        title: title,
        trailing: Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: Icon(
            expanded ? AppIconography.chevronUp : AppIconography.chevronDown,
            size: 20,
            color: muted,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Runs
// ---------------------------------------------------------------------------

class _RunsSegment extends StatelessWidget {
  const _RunsSegment({
    required this.lead,
    required this.dim,
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
    required this.canStartRun,
  });

  /// The header rows that scroll with this list (host, segments, planning).
  final List<Widget> lead;

  /// Stale data: the rows dim, the header does not.
  final bool dim;

  /// Whether this phone can start a run on this host (the pinned Start a
  /// run button shows); the empty list then teaches it, else it keeps the
  /// "from the host" sentence.
  final bool canStartRun;

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
      now: now,
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

    return _homeList(
      context,
      key: const ValueKey('team-home-runs'),
      lead: lead,
      dim: dim,
      children: [
        // Nothing to filter or search yet: the empty state stands alone.
        if (!nothingAtAll) ...[
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
                    if (f != TeamRunFilter.values.first)
                      const SizedBox(width: 8),
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
        ],
        if (nothingAtAll)
          _Empty(
            key: const ValueKey('team-home-runs-empty'),
            icon: AppIconography.agent,
            title: l10n.teamUiCardEmptyTitle,
            hint: canStartRun
                ? l10n.emptyTeachTeamRunsMessage
                : l10n.teamUiCardEmptyHint,
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
          _GroupRow(
            key: const ValueKey('team-home-completed-group'),
            icon: AppIconography.check,
            iconColor: AppTheme.statusColor(theme, AppStatusTone.ok),
            title: allToday
                ? l10n.teamUiHomeCompletedToday(completed.length)
                : l10n.teamUiHomeCompletedGroup(completed.length),
            expanded: completedExpanded,
            onTap: onToggleCompleted,
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
    required this.now,
    required this.progress,
    required this.stateWord,
    required this.needsYou,
    required this.onTap,
  });

  final OrchestrationRun run;

  /// Clock for the "Finished 5h ago" age of a finished run.
  final DateTime now;
  final TeamRunProgress progress;

  /// The run's state word, with the merge wait named (TEAM-117).
  final String stateWord;
  final bool needsYou;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
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
    final finishedAt = run.finishedAt;
    final finished =
        finishedAt != null &&
            (run.state == RunState.completed || run.state == RunState.cancelled)
        ? l10n.teamUiHomeRunFinished(
            relativeTimeLabel(
              finishedAt.millisecondsSinceEpoch,
              now: now,
              l10n: l10n,
            ),
          )
        : null;
    final subtitle = [?kind, ?steps, ?finished].join(' · ');
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
    // A run's title is the person's own objective: two lines before it
    // ends. At large text the state word moves under it (§6 row, state in
    // the row) instead of squeezing the title.
    return KitRow(
      leading: KitRow.icon(context, icon, color: color),
      title: run.title,
      titleMaxLines: 2,
      // "Batch · convoy · 1 of 1 done · Finished 5h ago" keeps its end.
      supportingMaxLines: 2,
      supporting: subtitle.isEmpty ? null : TextSpan(text: subtitle),
      below: stacked ? state : null,
      trailing: stacked
          ? null
          : Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
              child: state,
            ),
      onTap: onTap,
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
    required this.lead,
    required this.dim,
    required this.snapshot,
    required this.live,
    required this.off,
    required this.suspendedExpanded,
    required this.now,
    required this.onToggleSuspended,
    required this.onOpenAgent,
  });

  /// The header rows that scroll with this list (host, segments, planning).
  final List<Widget> lead;

  /// Stale data: the rows dim, the header does not.
  final bool dim;

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
    return _homeList(
      context,
      key: const ValueKey('team-home-agents'),
      lead: lead,
      dim: dim,
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
          _GroupRow(
            key: const ValueKey('team-home-suspended-group'),
            icon: AppIconography.stopCircle,
            title: l10n.teamUiHomeSuspendedGroup(suspended.length),
            expanded: suspendedExpanded,
            onTap: onToggleSuspended,
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
  const _NeedsYouSegment({
    required this.lead,
    required this.dim,
    required this.controller,
    required this.now,
  });

  /// The header rows that scroll with this list (host, segments, planning).
  final List<Widget> lead;

  /// Stale data: the rows dim, the header does not.
  final bool dim;

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
    return _homeList(
      context,
      key: const ValueKey('team-home-needs-you'),
      lead: lead,
      dim: dim,
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
    return KitRow(
      leading: KitRow.icon(context, icon, color: color),
      title: gate.title,
      titleMaxLines: 2,
      supporting: TextSpan(text: subtitle),
      trailing: Padding(
        padding: const EdgeInsetsDirectional.only(start: 8, end: 12),
        child: (record != null && record!.status != MutationStatus.confirmed)
            ? TeamReceiptChip(
                key: ValueKey('team-home-gate-${gate.id}-receipt'),
                record: record!,
                onOpen: onTap,
              )
            : Icon(AppIconography.chevronRight, size: 20, color: muted),
      ),
      onTap: onTap,
    );
  }
}
