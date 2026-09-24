/// The run detail (02-ux-flows-and-screens §4): what a run row on the AI
/// Team home opens. The app bar names the run and its Gas City term
/// ("Run · convoy"); the tabs are **Overview · Work · Agents · Timeline**.
///
/// **Overview** (§4.1) answers the five BRD questions top to bottom with
/// one element each: the objective with its state word and elapsed time;
/// "N of M done" over one segmented bar; the Working and Blocked counts,
/// then a quiet usage chip ("Team today · $0.42 est. · 12.4k tokens") when
/// the host reports `/usage` — Gas City's figures are city-level for the
/// day, never per run, and always its local estimate, so the chip says
/// so and is absent entirely when nothing was reported or the capability
/// is off; why work is blocked, when the host or the graph says; the single most
/// urgent thing waiting on the person (read-only in Sprint A: the question
/// and where to answer it); then the stages, or, for a convoy (which has
/// no stages), the dispatch cycle strip of its least-advanced item
/// (TEAM-116) over "Batch of N · M done".
///
/// **Timeline** (§4.4) lists the controller's events scoped to this run,
/// newest first, behind All / Work / Agents / Decisions chips. While the
/// list is scrolled away from the top the rows hold still and a pill counts
/// what arrived; tapping it jumps to the latest.
///
/// **Work** (§4.2) lists the run's items grouped by state in the BRD §14
/// order — Needs input, Blocked, Working, Ready, Queued, Review, Done,
/// Failed, Cancelled — each row with its owner glyph, what it waits on and
/// its age; a row opens the Work sheet. The Graph view ([WorkGraph]) is one
/// tap away behind a List / Graph toggle remembered per run
/// (`oc.orchestration.<profile>.workView.<run>`); wide screens (≥ 600dp)
/// start on Graph, phones on List.
///
/// **Agents** is a placeholder here; TEAM-111 fills it. States (§4.5):
/// loading, the stale line of the card, the honest error copy with Retry,
/// and a run the host no longer lists.
///
/// **Policy** (TEAM-207, 02-ux §7): under the state header (and the
/// cancel receipt, when any) a read-only "Supervision · Balanced" line
/// with the host's boundaries as chips, from `controller.policy`; absent
/// entirely when the host reports none (no front).
///
/// **Run controls** (TEAM-204): the app bar keeps one icon action
/// (Refresh); its overflow holds Technical details and Cancel run (a
/// formula run) or Close batch (a convoy), each two-step in the error
/// tone and present only with `controlCancelRun` on a run that is still
/// open; the receipt chip sits under the state header. The supervisor
/// has no pause / resume for a run, so none is offered.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../widgets/relative_time.dart';
import '../../widgets/team_agent_row.dart';
import '../../widgets/team_controls.dart';
import '../../widgets/team_technical_details.dart';
import '../../widgets/team_cycle_strip.dart';
import '../../widgets/team_moments.dart';
import '../../widgets/team_vocabulary.dart';
import 'agent_screen.dart';
import 'gate_sheet.dart';
import 'merge_section.dart';
import 'policy_block.dart';
import 'team_needs_you.dart';
import 'team_states.dart';
import 'work_graph.dart';
import 'work_sheet.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// The run detail's tabs, in order.
enum TeamRunTab { overview, work, agents, timeline }

/// The Timeline tab's filter chips.
enum TeamTimelineFilter { all, work, agents, decisions }

/// The Work tab's two views.
enum TeamWorkView { list, graph }

/// From this width the Work tab starts on the Graph (02-ux §4.2).
const teamWorkGraphDefaultWidth = 600.0;

/// Which chip a timeline row answers to; [other] rows show under All only.
enum _EventCategory { work, agents, decisions, other }

class RunScreen extends StatefulWidget {
  const RunScreen({
    super.key,
    required this.controller,
    required this.runId,
    this.now,
  });

  final OrchestrationController controller;
  final String runId;

  /// Clock for the elapsed time; tests pin it.
  final DateTime Function()? now;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen>
    with SingleTickerProviderStateMixin {
  /// Past this offset the timeline counts as scrolled away.
  static const _scrolledAway = 24.0;

  late final TabController _tabs = TabController(
    length: TeamRunTab.values.length,
    vsync: this,
  );
  final _timelineScroll = ScrollController();
  TeamTimelineFilter _filter = TeamTimelineFilter.all;

  /// The Work view chosen for this run, read from the profile's store;
  /// null until the person picks one, when the width decides.
  TeamWorkView? _workView;

  /// The run's events as they were when the list was scrolled away; the
  /// rows hold still until the person returns to the top or taps the pill.
  List<OrchestrationEvent>? _held;
  bool _refreshing = false;

  /// The Overview's Details row (counts, usage, the host's policy):
  /// collapsed on every open.
  bool _detailsOpen = false;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTab);
    _timelineScroll.addListener(_onTimelineScroll);
    _workView = switch (widget.controller.workView(widget.runId)) {
      'graph' => TeamWorkView.graph,
      'list' => TeamWorkView.list,
      _ => null,
    };
  }

  void _chooseWorkView(TeamWorkView view) {
    setState(() => _workView = view);
    widget.controller.rememberWorkView(widget.runId, view.name);
  }

  void _openWork(String workId) =>
      showWorkSheet(context, widget.controller, workId, now: () => _now);

  @override
  void dispose() {
    _timelineScroll
      ..removeListener(_onTimelineScroll)
      ..dispose();
    _tabs
      ..removeListener(_onTab)
      ..dispose();
    super.dispose();
  }

  /// The app bar's title follows the tab (none on the Overview).
  int _shownTab = 0;
  void _onTab() {
    if (_tabs.index == _shownTab || !mounted) return;
    setState(() => _shownTab = _tabs.index);
  }

  void _onTimelineScroll() {
    if (!_timelineScroll.hasClients) return;
    final away = _timelineScroll.offset > _scrolledAway;
    if (away && _held == null) {
      setState(() => _held = _scopedEvents());
    } else if (!away && _held != null) {
      setState(() => _held = null);
    }
  }

  void _jumpToLatest() {
    setState(() => _held = null);
    if (_timelineScroll.hasClients) {
      _timelineScroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
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

  OrchestrationRun? get _run {
    for (final run in widget.controller.snapshot.runs) {
      if (run.id == widget.runId) return run;
    }
    return null;
  }

  /// A run the host can still cancel: not finished, failed or cancelled.
  static bool _open(OrchestrationRun run) => switch (run.state) {
    RunState.completed || RunState.cancelled || RunState.failed => false,
    _ => true,
  };

  /// The newest cancel record for this run, for the receipt chip.
  MutationRecord? get _cancelReceipt => widget.controller.latestMutation(
    kind: MutationKind.cancelRun,
    targetId: widget.runId,
  );

  /// Cancel run / Close batch: the first tap opened the menu, the second
  /// the confirmation, the third sends; backing out sends nothing.
  Future<void> _cancelRun(OrchestrationRun run) async {
    final l10n = _copy(context);
    final batch = run.kind == RunKind.batch;
    final ok = await confirmTeamControl(
      context,
      title: batch
          ? l10n.teamUiControlCloseBatchConfirmTitle
          : l10n.teamUiControlCancelRunConfirmTitle,
      message: batch
          ? l10n.teamUiControlCloseBatchConfirmBody
          : l10n.teamUiControlCancelRunConfirmBody,
      confirmLabel: batch
          ? l10n.teamUiControlCloseBatch
          : l10n.teamUiControlCancelRun,
      sheetKey: const ValueKey('team-run-cancel-confirm'),
      confirmKey: const ValueKey('team-run-cancel-confirm-action'),
    );
    if (!ok || !mounted) return;
    await widget.controller.cancelRun(run.id);
  }

  Future<void> _retryCancel(MutationRecord record) async {
    await widget.controller.retryMutation(record.key);
  }

  /// The controller's timeline, newest first, kept to this run.
  List<OrchestrationEvent> _scopedEvents() {
    final scope = _RunScope.of(widget.controller.snapshot, widget.runId);
    final events = widget.controller.timeline;
    return [
      for (var i = events.length - 1; i >= 0; i--)
        if (scope.includes(events[i])) events[i],
    ];
  }

  void _openDetails(OrchestrationRun run) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _RunDetailsSheet(run: run, work: widget.controller.snapshot.work),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = _copy(context);
      final theme = Theme.of(context);
      final run = _run;
      return Scaffold(
        key: const ValueKey('team-run'),
        appBar: AppBar(
          // The Overview opens with the task's title, whole, so the bar
          // stays empty there rather than say it twice; the other tabs keep
          // it on one line. The Gas City term ("convoy", "formula") is
          // under Technical details.
          title: _tabs.index == TeamRunTab.overview.index && run != null
              ? null
              : Text(
                  run?.title ?? l10n.teamUiRunTermUnknown,
                  key: const ValueKey('team-run-title'),
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          actions: [
            IconButton(
              key: const ValueKey('team-run-refresh'),
              tooltip: l10n.teamUiRefresh,
              onPressed: _refreshing ? null : _refresh,
              icon: const Icon(AppIconography.sync),
            ),
            // One icon action and the overflow (design standard §1):
            // Technical details always, Stop run / Close batch only on an
            // open run with the capability.
            if (run != null)
              PopupMenuButton<String>(
                key: const ValueKey('team-run-more'),
                tooltip: l10n.teamUiControlMoreActions,
                icon: const Icon(AppIconography.more),
                onSelected: (value) =>
                    value == 'cancel' ? _cancelRun(run) : _openDetails(run),
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    key: const ValueKey('team-run-details'),
                    value: 'details',
                    child: Text(l10n.teamUiTechnicalDetails),
                  ),
                  if (widget.controller.capabilities.controlCancelRun &&
                      _open(run))
                    PopupMenuItem<String>(
                      key: const ValueKey('team-run-cancel'),
                      value: 'cancel',
                      child: Text(
                        run.kind == RunKind.batch
                            ? l10n.teamUiControlCloseBatch
                            : l10n.teamUiControlCancelRun,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                ],
              ),
          ],
        ),
        body: KitScreen(
          header: [
            if (!teamScreenLoading(widget.controller) &&
                !teamScreenFailed(widget.controller))
              ?teamStatusLine(
                context,
                controller: widget.controller,
                keyPrefix: 'team-run',
                onRetry: _refreshing ? null : _refresh,
              ),
          ],
          loading: teamScreenLoading(widget.controller) || _refreshing,
          loadingLabel: l10n.teamUiCardLoading,
          body: _body(context, run),
        ),
      );
    },
  );

  Widget _body(BuildContext context, OrchestrationRun? run) {
    final l10n = _copy(context);
    final controller = widget.controller;
    final snapshot = controller.snapshot;
    if (teamScreenState(
          context,
          controller: controller,
          keyPrefix: 'team-run',
          onRetry: _refreshing ? null : _refresh,
        )
        case final state?) {
      return state;
    }
    if (run == null) {
      return KitStateView(
        key: const ValueKey('team-run-missing'),
        icon: AppIconography.cloudOff,
        title: l10n.teamUiRunMissingTitle,
        body: l10n.teamUiRunMissingHint,
        primary: KitAction(
          label: l10n.teamUiRunBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final stale = controller.isStale;
    final live = _scopedEvents();
    final held = _held;
    final shown = held ?? live;
    final arrived = held == null ? 0 : math.max(0, live.length - held.length);
    final tabs = TabBarView(
      controller: _tabs,
      children: [
        RefreshIndicator(
          key: const ValueKey('team-run-pull'),
          onRefresh: _refresh,
          child: _Overview(
            controller: controller,
            run: run,
            now: _now,
            receipt: _cancelReceipt,
            onRetryReceipt: _retryCancel,
            detailsOpen: _detailsOpen,
            onToggleDetails: () => setState(() => _detailsOpen = !_detailsOpen),
            onOpenStep: _openWork,
            onSeeAllSteps: () => _tabs.animateTo(TeamRunTab.work.index),
            onOpenGate: (gate) =>
                showGateSheet(context, controller, gate.id, now: () => _now),
          ),
        ),
        _WorkTab(
          key: const ValueKey('team-run-work'),
          snapshot: snapshot,
          runId: run.id,
          now: _now,
          view:
              _workView ??
              (MediaQuery.sizeOf(context).width >= teamWorkGraphDefaultWidth
                  ? TeamWorkView.graph
                  : TeamWorkView.list),
          onView: _chooseWorkView,
          onOpen: _openWork,
        ),
        _AgentsTab(
          key: const ValueKey('team-run-agents'),
          controller: controller,
          runId: run.id,
          now: _now,
          clock: widget.now,
        ),
        _Timeline(
          events: shown,
          arrived: arrived,
          filter: _filter,
          scroll: _timelineScroll,
          snapshot: snapshot,
          onFilter: (f) => setState(() => _filter = f),
          onJump: _jumpToLatest,
        ),
      ],
    );

    return Column(
      key: const ValueKey('team-run-data'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabBar(
          key: const ValueKey('team-run-tabs'),
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final tab in TeamRunTab.values)
              Tab(
                key: ValueKey('team-run-tab-${tab.name}'),
                text: switch (tab) {
                  TeamRunTab.overview => l10n.teamUiRunTabOverview,
                  TeamRunTab.work => l10n.teamUiRunTabWork,
                  TeamRunTab.agents => l10n.teamUiRunTabAgents,
                  TeamRunTab.timeline => l10n.teamUiRunTabTimeline,
                },
              ),
          ],
        ),
        // Stale numbers dim; they stay readable (never colour-only).
        Expanded(child: stale ? Opacity(opacity: .6, child: tabs) : tabs),
      ],
    );
  }
}

/// "Run · convoy" / "Run · formula": the product word with its Gas City
/// term beside it (02-ux §8).
String _term(AppLocalizations l10n, OrchestrationRun run) => switch (run.kind) {
  RunKind.batch => l10n.teamUiRunTermBatch,
  RunKind.formula => l10n.teamUiRunTermFormula,
  RunKind.unknown => l10n.teamUiRunTermUnknown,
};

/// The Agents tab (§4.3): the fleet rows of §5.1 scoped to the agents
/// working on this run's work items; a row opens [AgentScreen].
class _AgentsTab extends StatelessWidget {
  const _AgentsTab({
    super.key,
    required this.controller,
    required this.runId,
    required this.now,
    required this.clock,
  });

  final OrchestrationController controller;
  final String runId;
  final DateTime now;

  /// The screen's clock, handed to the agent detail it opens.
  final DateTime Function()? clock;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final snapshot = controller.snapshot;
    final workById = {for (final item in snapshot.work) item.id: item};
    final agents = teamAgentsOnRun(snapshot, runId);
    if (agents.isEmpty) {
      return KitStateView(
        key: const ValueKey('team-run-agents-empty'),
        icon: AppIconography.agent,
        title: l10n.teamUiAgentRunEmpty,
        body: l10n.teamUiAgentRunEmptyHint,
        liveRegion: false,
      );
    }
    return ListView(
      key: const ValueKey('team-run-agents-list'),
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        for (final agent in agents)
          TeamAgentRow(
            keyPrefix: 'team-run-agent',
            agent: agent,
            work: workById[agent.currentWorkId],
            now: now,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AgentScreen(
                  controller: controller,
                  agentId: agent.id,
                  now: clock,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Overview
// ---------------------------------------------------------------------------

/// One stage of a formula run, read from the provider's `steps` (or
/// `stages`) list when the host sent one.
class _Stage {
  const _Stage({required this.title, required this.state});

  final String title;
  final RunState state;

  static List<_Stage> of(OrchestrationRun run) {
    final steps = run.raw['steps'] ?? run.raw['stages'];
    if (steps is! List) return const [];
    return [
      for (final step in steps)
        if (step is Map)
          _Stage(
            title: _text(step['title']) ?? _text(step['id']) ?? '',
            state: RunState.fromProvider(
              _text(step['status']) ?? _text(step['state']),
            ),
          ),
    ];
  }
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Map<String, Object?> _map(Object? value) => value is Map
    ? {for (final entry in value.entries) '${entry.key}': entry.value}
    : const {};

/// Why a work item is blocked: what the host said (`last_error`, a
/// blocked reason in the metadata), else the open items it waits on.
String? _blockedCause(
  AppLocalizations l10n,
  WorkItem item,
  Map<String, WorkItem> byId,
) {
  final metadata = _map(item.raw['metadata']);
  final said =
      _text(metadata['last_error']) ??
      _text(item.raw['last_error']) ??
      _text(metadata['blocked_reason']) ??
      _text(metadata['gc.blocked_reason']) ??
      _text(metadata['reason']);
  if (said != null) return said;
  var open = 0;
  for (final id in item.dependsOn) {
    final dependency = byId[id];
    if (dependency == null) continue;
    if (dependency.state != WorkState.completed &&
        dependency.state != WorkState.cancelled) {
      open += 1;
    }
  }
  return open == 0 ? null : l10n.teamUiRunBlockedByDeps(open);
}

/// Time since the run started; for a finished run, how long it took.
Duration? _elapsed(OrchestrationRun run, DateTime now) {
  final started = run.startedAt;
  if (started == null) return null;
  final finished = switch (run.state) {
    RunState.completed ||
    RunState.failed ||
    RunState.cancelled => run.updatedAt ?? now,
    _ => now,
  };
  final elapsed = finished.difference(started);
  return elapsed.isNegative ? Duration.zero : elapsed;
}

String _elapsedLabel(AppLocalizations l10n, Duration elapsed) {
  if (elapsed.inHours < 1) {
    return l10n.teamUiRunElapsedMinutes(elapsed.inMinutes);
  }
  if (elapsed.inDays < 1) {
    return l10n.teamUiRunElapsedHours(
      elapsed.inHours,
      elapsed.inMinutes - elapsed.inHours * 60,
    );
  }
  return l10n.teamUiRunElapsedDays(elapsed.inDays);
}

/// The Overview (docs/design/aiteam-redesign-2026-09-24.md): the task's
/// title and one status line ("Working · 1 of 5 steps done · 3 h 12
/// min"); the four-stage line; one sentence when it is stuck (TEAM-116's
/// stall, from its least-advanced step); what needs the person, answered
/// here; the Merge section once the work is done; then the steps as rows.
/// Counts, usage and the host's policy sit under one collapsed Details
/// row. Gas City's words are under Technical details (the app bar's
/// overflow), never here.
class _Overview extends StatelessWidget {
  const _Overview({
    required this.controller,
    required this.run,
    required this.now,
    required this.detailsOpen,
    required this.onToggleDetails,
    required this.onOpenStep,
    required this.onSeeAllSteps,
    required this.onOpenGate,
    this.receipt,
    this.onRetryReceipt,
  });

  final OrchestrationController controller;
  final OrchestrationRun run;
  final DateTime now;

  /// The newest cancel record for the run, shown under the status line.
  final MutationRecord? receipt;
  final Future<void> Function(MutationRecord record)? onRetryReceipt;

  /// Whether the Details row is open.
  final bool detailsOpen;
  final VoidCallback onToggleDetails;

  /// Opens a step's Work sheet (where its full dispatch strip lives).
  final ValueChanged<String> onOpenStep;

  /// Moves to the Steps tab.
  final VoidCallback onSeeAllSteps;

  /// Opens the Gate sheet.
  final ValueChanged<OrchestrationGate> onOpenGate;

  /// Steps listed before "See all N steps".
  static const _stepsShown = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final snapshot = controller.snapshot;
    final progress = TeamRunProgress.of(run, snapshot.work);
    final byId = {for (final item in snapshot.work) item.id: item};
    // What needs the person first, then what is held up, then what moves.
    final items = _workOf(snapshot, run.id)
      ..sort(
        (a, b) =>
            teamWorkStateRank(a.state).compareTo(teamWorkStateRank(b.state)),
      );
    final gates = teamOpenGates(controller, runId: run.id);
    final stages = _Stage.of(run);
    final stage = teamRunStage(
      run,
      snapshot.work,
      cycleOf: controller.cycleFor,
    );
    // Waiting for merge (TEAM-117): every open item is in the merge
    // agent's hands, so the time counts from the hand-off, not from the
    // run's start.
    final handoff =
        teamRunAwaitsMerge(run, snapshot.work, cycleOf: controller.cycleFor)
        ? teamRunHandoffAt(run, snapshot.work, cycleOf: controller.cycleFor)
        : null;
    final elapsed = _elapsed(run, now);
    final String? elapsedLabel;
    if (handoff != null) {
      final waited = now.difference(handoff);
      elapsedLabel = l10n.teamUiRunSinceHandoff(
        _elapsedLabel(l10n, waited.isNegative ? Duration.zero : waited),
      );
    } else {
      elapsedLabel = elapsed == null ? null : _elapsedLabel(l10n, elapsed);
    }
    // Why it waits (TEAM-116): the stall of the batch's least-advanced
    // step, in one sentence. The step's sheet has the whole strip.
    final cycleWork = run.kind == RunKind.batch && _isOpen(run)
        ? controller.cycleWorkForRun(run.id)
        : null;
    final cycle = cycleWork == null ? null : controller.cycleFor(cycleWork);
    final stall = cycle != null && cycle.stalled ? cycle.stallReason : null;
    final usage = _usageLabel(l10n, controller, run);
    final policy = controller.policy;

    Widget rails(Widget child, {double top = 0}) =>
        Padding(padding: EdgeInsets.fromLTRB(16, top, 16, 0), child: child);

    return ListView(
      key: const ValueKey('team-run-overview'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: 16,
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        // Merged: a celebration, once per task (it is remembered).
        rails(
          TeamMergedCelebration(
            profileId: controller.profileId,
            runId: run.id,
            merged: run.state == RunState.completed && run.merged,
          ),
        ),
        rails(
          _Objective(
            key: const ValueKey('team-run-objective'),
            run: run,
            stateWord: teamRunStateWordFor(
              l10n,
              run,
              snapshot.work,
              cycleOf: controller.cycleFor,
            ),
            steps: _isOpen(run) || run.state == RunState.completed
                ? teamTaskSteps(l10n, progress)
                : null,
            elapsed: elapsedLabel,
          ),
        ),
        if (receipt case final record?)
          rails(
            top: 10,
            TeamReceiptChip(
              key: const ValueKey('team-run-receipt'),
              record: record,
              control: run.kind == RunKind.batch
                  ? l10n.teamUiControlCloseBatch
                  : l10n.teamUiControlCancelRun,
              onRetry: onRetryReceipt == null
                  ? null
                  : () => onRetryReceipt!(record),
            ),
          ),
        if (stage != null)
          rails(
            top: 20,
            _StageLine(key: const ValueKey('team-run-stage-line'), at: stage),
          ),
        if (stall != null)
          rails(
            top: 16,
            KitNotice(
              key: const ValueKey('team-run-stall'),
              tone: AppStatusTone.attention,
              icon: AppIconography.waiting,
              message: teamCycleStallSentence(l10n, stall),
              liveRegion: false,
            ),
          ),
        if (gates.isNotEmpty) ...[
          TeamNeedsYouLabel(
            l10n.teamUiRunNeedsYou,
            profileId: controller.profileId,
            gateIds: [gates.first.id],
          ),
          TeamNeedsYouCard(
            keyPrefix: 'team-run-needs-you',
            controller: controller,
            gate: gates.first,
            title: teamGateKindWord(l10n, gates.first.kind),
            onOpen: () => onOpenGate(gates.first),
          ),
        ],
        // 02-ux §8a: the Merge section, once every step is done or
        // review-ready and the host has merge roles (empty otherwise).
        rails(
          TeamMergeSection(controller: controller, run: run, now: () => now),
        ),
        if (items.isNotEmpty) ...[
          SectionLabel(
            l10n.teamUiRunStepsHeading,
            key: const ValueKey('team-run-steps'),
          ),
          for (final item in items.take(_stepsShown))
            _StepRow(
              key: ValueKey('team-run-step-${item.id}'),
              item: item,
              cause: teamWorkIsStuck(item.state)
                  ? _blockedCause(l10n, item, byId)
                  : null,
              now: now,
              onTap: () => onOpenStep(item.id),
            ),
          if (items.length > _stepsShown)
            KitRow(
              key: const ValueKey('team-run-steps-all'),
              leading: KitRow.icon(context, AppIconography.checklist),
              title: l10n.teamUiRunStepsAll(items.length),
              trailing: Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Icon(
                  AppIconography.chevronRight,
                  size: 20,
                  color: AppTheme.mutedOf(Theme.of(context)),
                ),
              ),
              onTap: onSeeAllSteps,
            ),
        ] else if (stages.isNotEmpty) ...[
          // A formula run that tracks no work: its own stages are its steps.
          SectionLabel(
            l10n.teamUiRunStepsHeading,
            key: const ValueKey('team-run-stages'),
          ),
          for (final (index, step) in stages.indexed)
            KitRow(
              key: ValueKey('team-run-stage-$index'),
              leading: KitRow.icon(
                context,
                teamRunGlyph(step.state).$1,
                color: AppTheme.statusColor(
                  Theme.of(context),
                  teamRunGlyph(step.state).$2,
                ),
              ),
              title: step.title,
              titleMaxLines: 2,
              supporting: TextSpan(text: teamRunStateWord(l10n, step.state)),
            ),
        ],
        const SizedBox(height: 8),
        _DetailsRow(
          key: const ValueKey('team-run-summary'),
          open: detailsOpen,
          onTap: onToggleDetails,
        ),
        if (detailsOpen)
          rails(
            Column(
              key: const ValueKey('team-run-summary-body'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (progress.total > 0)
                  _DetailLine(
                    label: l10n.teamUiRunDetailsStepsLabel,
                    value: l10n.teamUiRunDetailsCounts(
                      progress.done,
                      progress.working,
                      progress.blocked,
                    ),
                    valueKey: const ValueKey('team-run-counts'),
                  ),
                if (usage != null)
                  _DetailLine(
                    label: l10n.teamUiRunDetailsUsage,
                    value: usage,
                    valueKey: const ValueKey('team-run-usage'),
                    figures: true,
                  ),
                // 02-ux §7: the host's supervision level and boundaries,
                // read-only (TEAM-207); absent when the host reports none.
                if (policy != null) ...[
                  const SizedBox(height: 8),
                  TeamPolicyBlock(policy: policy),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// A task the host can still stop: not finished, failed or cancelled.
bool _isOpen(OrchestrationRun run) => switch (run.state) {
  RunState.completed || RunState.cancelled || RunState.failed => false,
  _ => true,
};

/// What the task is for and how it is doing: the title, then one status
/// line — the state word in its tone, how many steps are done, and for how
/// long.
class _Objective extends StatelessWidget {
  const _Objective({
    super.key,
    required this.run,
    required this.stateWord,
    required this.steps,
    required this.elapsed,
  });

  final OrchestrationRun run;

  /// The run's state word, with the merge wait named (TEAM-117).
  final String stateWord;

  /// "1 of 5 steps done", or null.
  final String? steps;
  final String? elapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final (_, tone) = teamRunGlyph(run.state);
    final color = AppTheme.statusColor(theme, tone);
    final quiet = theme.textTheme.bodyMedium?.copyWith(color: muted);
    final dot = Text(teamUsageSeparator, style: quiet);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          run.title,
          key: const ValueKey('team-run-objective-title'),
          style: theme.textTheme.titleLarge?.copyWith(height: 1.2),
        ),
        const SizedBox(height: 6),
        // One line that wraps at large text rather than overflowing.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              stateWord,
              key: const ValueKey('team-run-state'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (steps case final steps?) ...[
              dot,
              Text(
                steps,
                key: const ValueKey('team-run-progress-label'),
                style: quiet,
              ),
            ],
            if (elapsed case final elapsed?) ...[
              dot,
              Text(
                elapsed,
                key: const ValueKey('team-run-elapsed'),
                style: quiet,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Waiting · Working · Reviewing · Done: where the task is, at most four
/// stages, the current one named in the accent and the ones behind it
/// checked. One semantics label says it.
class _StageLine extends StatelessWidget {
  const _StageLine({super.key, required this.at});

  final TeamStage at;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final accent = theme.colorScheme.primary;
    final ok = AppTheme.statusColor(theme, AppStatusTone.ok);
    final done = at == TeamStage.done;
    Widget mark(TeamStage stage) {
      final passed = stage.index < at.index || done;
      final current = stage == at && !done;
      final Widget glyph = passed
          ? Icon(AppIconography.check, size: 16, color: ok)
          : Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: current ? accent : null,
                border: current
                    ? null
                    : Border.all(
                        color: muted.withValues(alpha: .7),
                        width: 1.5,
                      ),
              ),
            );
      return Row(
        key: ValueKey('team-run-stage-${stage.name}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: 16, child: Center(child: glyph)),
          const SizedBox(width: 6),
          // Flexible: a stage word at 2.5× on a 320 dp phone (Arabic
          // especially) wraps under its mark instead of overflowing.
          Flexible(
            child: Text(
              teamStageWord(l10n, stage),
              style: theme.textTheme.bodySmall?.copyWith(
                color: current ? accent : (passed ? null : muted),
                fontWeight: current ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      );
    }

    return Semantics(
      label: l10n.teamUiRunStageSemantics(
        at.index + 1,
        teamStageWord(l10n, at),
      ),
      child: ExcludeSemantics(
        child: Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [for (final stage in TeamStage.values) mark(stage)],
        ),
      ),
    );
  }
}

/// One step on the Overview: its state glyph, its title (two lines), and
/// one line — the state word, why it is held up when the host said, and
/// its age.
class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.item,
    required this.cause,
    required this.now,
    required this.onTap,
  });

  final WorkItem item;

  /// Why it is held up ([_blockedCause]), or null.
  final String? cause;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final (icon, tone) = teamWorkGlyph(item.state);
    final color = AppTheme.statusColor(theme, tone);
    final at = item.updatedAt ?? item.createdAt;
    final age = at == null
        ? null
        : relativeTimeLabel(at.millisecondsSinceEpoch, now: now, l10n: l10n);
    final line = [
      teamWorkStateWord(l10n, item.state),
      ?cause,
      ?age,
    ].join(teamUsageSeparator);
    return KitRow(
      leading: KitRow.icon(context, icon, color: color),
      title: item.title,
      titleMaxLines: 2,
      supporting: TextSpan(text: line),
      supportingKey: ValueKey(
        cause == null
            ? 'team-run-step-line-${item.id}'
            : 'team-run-blocked-${item.id}',
      ),
      onTap: onTap,
    );
  }
}

/// "Details": the counts, the usage and the host's policy, collapsed.
class _DetailsRow extends StatelessWidget {
  const _DetailsRow({super.key, required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final muted = AppTheme.mutedOf(Theme.of(context));
    return Semantics(
      button: true,
      expanded: open,
      child: KitRow(
        leading: KitRow.icon(context, AppIconography.info),
        title: l10n.teamUiRunDetails,
        trailing: Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: Icon(
            open ? AppIconography.chevronUp : AppIconography.chevronDown,
            size: 20,
            color: muted,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// A label over its value, under Details; [figures] holds amounts still.
class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    required this.valueKey,
    this.figures = false,
  });

  final String label;
  final String value;
  final Key valueKey;
  final bool figures;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.mutedOf(theme),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            key: valueKey,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: figures
                  ? const [FontFeature.tabularFigures()]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// The Overview's usage line, or null when there is nothing honest to
/// show: the capability is off, `/usage` returned nothing, or it carried
/// neither a cost nor a token count. Gas City reports usage for the city
/// (today), not per run, so the line is labelled "Team today"; a run that
/// carries its own `usage` in raw (no provider does yet) is preferred.
String? _usageLabel(
  AppLocalizations l10n,
  OrchestrationController controller,
  OrchestrationRun run,
) {
  if (!controller.capabilities.usage) return null;
  final own = _runUsage(run);
  final label = teamUsageLabel(l10n, own ?? controller.snapshot.usage);
  if (label == null) return null;
  return own == null ? l10n.teamUiUsageChip(label) : label;
}

/// A per-run usage figure from the run's raw payload, when a provider
/// ever reports one: `usage.{input_tokens,output_tokens,cost_usd}`.
OrchestrationUsage? _runUsage(OrchestrationRun run) {
  final usage = run.raw['usage'];
  if (usage is! Map<String, Object?>) return null;
  int? count(String key) => switch (usage[key]) {
    final int v => v,
    final num v => v.toInt(),
    _ => null,
  };
  final cost = switch (usage['cost_usd_estimate'] ?? usage['cost_usd']) {
    final num v => v.toDouble(),
    _ => null,
  };
  final mapped = OrchestrationUsage(
    inputTokens: count('input_tokens'),
    outputTokens: count('output_tokens'),
    costUsd: cost,
    raw: usage,
  );
  return mapped.isEmpty ? null : mapped;
}

// ---------------------------------------------------------------------------
// Work
// ---------------------------------------------------------------------------

/// The run's work items, in the snapshot's order.
List<WorkItem> _workOf(OrchestrationSnapshot snapshot, String runId) => [
  for (final item in snapshot.work)
    if (item.runId == runId) item,
];

/// List / Graph toggle over the grouped list or the dependency graph.
class _WorkTab extends StatelessWidget {
  const _WorkTab({
    super.key,
    required this.snapshot,
    required this.runId,
    required this.now,
    required this.view,
    required this.onView,
    required this.onOpen,
  });

  final OrchestrationSnapshot snapshot;
  final String runId;
  final DateTime now;
  final TeamWorkView view;
  final ValueChanged<TeamWorkView> onView;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final items = _workOf(snapshot, runId);
    // At large text the words alone fit 320dp; the icons go.
    final icons = !AppTheme.stackedActions(context);
    final toggle = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<TeamWorkView>(
          key: const ValueKey('team-run-work-view'),
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: TeamWorkView.list,
              icon: icons ? const Icon(AppIconography.checklist) : null,
              label: Text(
                l10n.teamUiWorkViewList,
                key: const ValueKey('team-run-work-view-list'),
              ),
            ),
            ButtonSegment(
              value: TeamWorkView.graph,
              icon: icons ? const Icon(AppIconography.fork) : null,
              label: Text(
                l10n.teamUiWorkViewGraph,
                key: const ValueKey('team-run-work-view-graph'),
              ),
            ),
          ],
          selected: {view},
          onSelectionChanged: (value) => onView(value.single),
        ),
      ),
    );
    if (items.isEmpty) {
      return ListView(
        key: const ValueKey('team-run-work-empty'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          toggle,
          KitStateView(
            size: KitStateSize.inline,
            liveRegion: false,
            icon: AppIconography.checklist,
            title: l10n.teamUiWorkEmpty,
            body: l10n.teamUiWorkEmptyHint,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        toggle,
        Expanded(
          child: switch (view) {
            TeamWorkView.list => _WorkList(
              key: const ValueKey('team-run-work-list'),
              items: items,
              snapshot: snapshot,
              now: now,
              onOpen: onOpen,
            ),
            TeamWorkView.graph => Semantics(
              key: const ValueKey('team-run-work-graph'),
              container: true,
              label: l10n.teamUiWorkGraphSemantics(items.length),
              child: WorkGraph(
                nodes: [for (final item in items) WorkGraphNode.of(item)],
                onNodeTap: onOpen,
              ),
            ),
          },
        ),
      ],
    );
  }
}

/// The items grouped by state in [teamWorkStateOrder], each group under a
/// tinted header with its count; empty groups are not shown.
class _WorkList extends StatelessWidget {
  const _WorkList({
    super.key,
    required this.items,
    required this.snapshot,
    required this.now,
    required this.onOpen,
  });

  final List<WorkItem> items;
  final OrchestrationSnapshot snapshot;
  final DateTime now;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final byId = {for (final item in snapshot.work) item.id: item};
    final groups = <(WorkState, List<WorkItem>)>[
      for (final state in teamWorkStateOrder)
        if ([
              for (final item in items)
                if (item.state == state) item,
            ]
            case final members when members.isNotEmpty)
          (state, members),
    ];
    return ListView(
      key: const ValueKey('team-run-work-groups'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: KitScreen.endPadding(context)),
      children: [
        for (final (state, members) in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _WorkGroup(
              key: ValueKey('team-run-work-group-${state.name}'),
              state: state,
              count: l10n.teamUiWorkGroupHeader(
                teamWorkStateWord(l10n, state),
                members.length,
              ),
              theme: theme,
              children: [
                for (final item in members)
                  _WorkRow(
                    key: ValueKey('team-run-work-row-${item.id}'),
                    item: item,
                    owner: workOwnerName(snapshot, item),
                    waitsOn: [
                      for (final id in item.dependsOn)
                        if (byId[id] case final dep?
                            when teamWorkIsOpen(dep.state))
                          dep,
                    ].length,
                    age: _age(l10n, item),
                    onTap: () => onOpen(item.id),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String? _age(AppLocalizations l10n, WorkItem item) {
    final at = item.updatedAt ?? item.createdAt;
    if (at == null) return null;
    return relativeTimeLabel(at.millisecondsSinceEpoch, now: now, l10n: l10n);
  }
}

/// One group: a header tinted by the state's tone over the rows.
class _WorkGroup extends StatelessWidget {
  const _WorkGroup({
    super.key,
    required this.state,
    required this.count,
    required this.children,
    required this.theme,
  });

  final WorkState state;
  final String count;
  final List<Widget> children;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final (icon, tone) = teamWorkGlyph(state);
    final color = AppTheme.statusColor(theme, tone);
    // A section heading (design standard §6) in the state's tone, then its
    // rows; the state also lives in every row's glyph.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  count,
                  key: ValueKey('team-run-work-group-count-${state.name}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

/// One row: the state glyph, the title, what it waits on and its age,
/// then the owner glyph (a letter in a ring) at the end.
class _WorkRow extends StatelessWidget {
  const _WorkRow({
    super.key,
    required this.item,
    required this.owner,
    required this.waitsOn,
    required this.age,
    required this.onTap,
  });

  final WorkItem item;
  final String? owner;

  /// Open items this one still needs.
  final int waitsOn;
  final String? age;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final (icon, tone) = teamWorkGlyph(item.state);
    final color = AppTheme.statusColor(theme, tone);
    final detail = [
      if (waitsOn > 0) l10n.teamUiWorkWaitsOn(waitsOn),
      ?age,
    ].join(' · ');
    final name = owner;
    return KitRow(
      leading: KitRow.icon(context, icon, color: color),
      title: item.title,
      titleMaxLines: 2,
      below: detail.isEmpty
          ? null
          : Text(
              detail,
              key: ValueKey('team-run-work-detail-${item.id}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: waitsOn > 0
                    ? AppTheme.statusColor(theme, AppStatusTone.attention)
                    : muted,
              ),
            ),
      trailing: Padding(
        padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
        child: Semantics(
          label: name == null
              ? l10n.teamUiWorkOwnerNone
              : l10n.teamUiWorkOwnerSemantics(name),
          child: ExcludeSemantics(
            child: Container(
              key: ValueKey('team-run-work-owner-${item.id}'),
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                name == null ? '—' : workOwnerInitial(name),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontFamily: AppTheme.monoFamily,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline
// ---------------------------------------------------------------------------

/// The ids an event must name to count as this run's: the run, its work
/// items, the agents on that work (by id, session and name) and its gates.
class _RunScope {
  const _RunScope({
    required this.runId,
    required this.workIds,
    required this.agentIds,
    required this.gateIds,
  });

  final String runId;
  final Set<String> workIds;
  final Set<String> agentIds;
  final Set<String> gateIds;

  static _RunScope of(OrchestrationSnapshot snapshot, String runId) {
    final workIds = {
      for (final item in snapshot.work)
        if (item.runId == runId) item.id,
    };
    final agentIds = <String>{};
    for (final agent in snapshot.agents) {
      if (workIds.contains(agent.currentWorkId)) {
        agentIds.addAll({
          agent.id,
          agent.name,
          ?agent.sessionId,
          ?agent.sessionName,
        });
      }
    }
    final gateIds = {
      for (final gate in snapshot.gates)
        if (teamGateRunId(snapshot, gate) == runId) gate.id,
    };
    return _RunScope(
      runId: runId,
      workIds: workIds,
      agentIds: agentIds,
      gateIds: gateIds,
    );
  }

  bool _known(String? id) =>
      id != null &&
      (id == runId ||
          workIds.contains(id) ||
          agentIds.contains(id) ||
          gateIds.contains(id));

  bool includes(OrchestrationEvent event) => switch (event) {
    BeadChanged() => workIds.contains(event.beadId) || event.beadId == runId,
    RunChanged() => event.runId == runId,
    SessionChanged() =>
      agentIds.contains(event.sessionId) || agentIds.contains(event.agentId),
    GateChanged() => gateIds.contains(event.gateId),
    RequestResult() => _mentions(event.payload),
    ActivityAppended() =>
      _known(event.event.subject) ||
          _known(event.event.actor) ||
          _mentions(event.event.payload),
    UnknownOrchestrationEvent() =>
      _known(_text(event.raw['subject'])) || _mentions(_map(event.raw)),
    StreamHeartbeat() || StreamHeadOnlyReplay() => false,
  };

  /// Whether a payload names one of the run's ids in the places Gas City
  /// puts them: the embedded bead, `bead_id`, `run_id`, `convoy_id`,
  /// `session_id`, `issue_id`, `request_id`.
  bool _mentions(Map<String, Object?> payload) {
    if (_known(_text(_map(payload['bead'])['id']))) return true;
    for (final key in const [
      'bead_id',
      'run_id',
      'convoy_id',
      'session_id',
      'issue_id',
      'request_id',
      'subject',
    ]) {
      if (_known(_text(payload[key]))) return true;
    }
    return false;
  }
}

_EventCategory _category(OrchestrationEvent event) => switch (event) {
  BeadChanged() || RunChanged() => _EventCategory.work,
  SessionChanged() => _EventCategory.agents,
  GateChanged() => _EventCategory.decisions,
  ActivityAppended() ||
  RequestResult() ||
  UnknownOrchestrationEvent() => _typeCategory(event.type),
  StreamHeartbeat() || StreamHeadOnlyReplay() => _EventCategory.other,
};

_EventCategory _typeCategory(String type) {
  final dot = type.indexOf('.');
  final family = dot < 0 ? type : type.substring(0, dot);
  return switch (family) {
    'bead' || 'beads' || 'convoy' || 'run' => _EventCategory.work,
    'session' || 'agent' => _EventCategory.agents,
    'request' || 'pending' || 'gate' || 'decision' => _EventCategory.decisions,
    _ => _EventCategory.other,
  };
}

/// When an event happened: the activity line's own stamp, else the `ts`
/// (or `timestamp`) of the raw frame or its `data`.
DateTime? _eventTime(OrchestrationEvent event) {
  if (event is ActivityAppended && event.event.timestamp != null) {
    return event.event.timestamp;
  }
  DateTime? of(Map<String, Object?> map) {
    final value = map['ts'] ?? map['timestamp'];
    return value is String ? DateTime.tryParse(value) : null;
  }

  return of(event.raw) ?? of(_map(event.raw['data']));
}

/// One line for an event: server text for activity lines, product copy
/// for the modelled changes.
String _eventText(
  AppLocalizations l10n,
  OrchestrationSnapshot snapshot,
  OrchestrationEvent event,
) {
  String workTitle(String id) {
    for (final item in snapshot.work) {
      if (item.id == id) return item.title;
    }
    return id;
  }

  String agentName(String? id, String fallback) {
    for (final agent in snapshot.agents) {
      if (agent.id == id || agent.sessionId == id || agent.name == id) {
        return agent.name;
      }
    }
    return id ?? fallback;
  }

  String gateTitle(String id) {
    for (final gate in snapshot.gates) {
      if (gate.id == id) return gate.title;
    }
    return id;
  }

  return switch (event) {
    BeadChanged() => switch (event.change) {
      BeadChange.created => l10n.teamUiRunTimelineWorkCreated(
        workTitle(event.beadId),
      ),
      BeadChange.updated => l10n.teamUiRunTimelineWorkUpdated(
        workTitle(event.beadId),
      ),
      BeadChange.closed => l10n.teamUiRunTimelineWorkClosed(
        workTitle(event.beadId),
      ),
    },
    RunChanged() => l10n.teamUiRunTimelineRunChanged(
      teamRunStateWord(l10n, event.state),
    ),
    SessionChanged() => switch (event.change) {
      SessionChange.woke => l10n.teamUiRunTimelineAgentWoke(
        agentName(event.agentId ?? event.sessionId, event.sessionId),
      ),
      SessionChange.stopped => l10n.teamUiRunTimelineAgentStopped(
        agentName(event.agentId ?? event.sessionId, event.sessionId),
      ),
    },
    GateChanged() =>
      event.resolved
          ? l10n.teamUiRunTimelineGateResolved(gateTitle(event.gateId))
          : l10n.teamUiRunTimelineGateOpened(gateTitle(event.gateId)),
    ActivityAppended() => event.event.summary ?? event.type,
    RequestResult() => event.errorMessage ?? event.type,
    UnknownOrchestrationEvent() ||
    StreamHeartbeat() ||
    StreamHeadOnlyReplay() => event.type,
  };
}

(IconData, AppStatusTone) _categoryGlyph(_EventCategory category) =>
    switch (category) {
      _EventCategory.work => (AppIconography.checklist, AppStatusTone.neutral),
      _EventCategory.agents => (AppIconography.agent, AppStatusTone.neutral),
      _EventCategory.decisions => (
        AppIconography.question,
        AppStatusTone.attention,
      ),
      _EventCategory.other => (AppIconography.timeline, AppStatusTone.neutral),
    };

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.events,
    required this.arrived,
    required this.filter,
    required this.scroll,
    required this.snapshot,
    required this.onFilter,
    required this.onJump,
  });

  /// Newest first, already scoped to the run.
  final List<OrchestrationEvent> events;

  /// Events that arrived while the list was held still.
  final int arrived;
  final TeamTimelineFilter filter;
  final ScrollController scroll;
  final OrchestrationSnapshot snapshot;
  final ValueChanged<TeamTimelineFilter> onFilter;
  final VoidCallback onJump;

  bool _passes(_EventCategory category) => switch (filter) {
    TeamTimelineFilter.all => true,
    TeamTimelineFilter.work => category == _EventCategory.work,
    TeamTimelineFilter.agents => category == _EventCategory.agents,
    TeamTimelineFilter.decisions => category == _EventCategory.decisions,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final visible = <(OrchestrationEvent, _EventCategory)>[
      for (final event in events)
        if (_category(event) case final category when _passes(category))
          (event, category),
    ];
    final list = ListView.builder(
      key: const ValueKey('team-run-timeline'),
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: 24 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: visible.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final f in TeamTimelineFilter.values)
                  ChoiceChip(
                    key: ValueKey('team-run-timeline-filter-${f.name}'),
                    label: Text(switch (f) {
                      TeamTimelineFilter.all => l10n.teamUiRunTimelineFilterAll,
                      TeamTimelineFilter.work =>
                        l10n.teamUiRunTimelineFilterWork,
                      TeamTimelineFilter.agents =>
                        l10n.teamUiRunTimelineFilterAgents,
                      TeamTimelineFilter.decisions =>
                        l10n.teamUiRunTimelineFilterDecisions,
                    }),
                    selected: filter == f,
                    onSelected: (_) => onFilter(f),
                  ),
              ],
            ),
          );
        }
        if (index == 1) {
          if (visible.isNotEmpty) return const SizedBox.shrink();
          return events.isEmpty
              ? KitStateView(
                  key: const ValueKey('team-run-timeline-empty'),
                  size: KitStateSize.inline,
                  liveRegion: false,
                  icon: AppIconography.timeline,
                  title: l10n.teamUiRunTimelineEmpty,
                  body: l10n.teamUiRunTimelineEmptyHint,
                )
              : KitStateView(
                  key: const ValueKey('team-run-timeline-empty-filtered'),
                  size: KitStateSize.inline,
                  liveRegion: false,
                  icon: AppIconography.filterOff,
                  title: l10n.teamUiRunTimelineEmptyFiltered,
                  body: l10n.teamUiRunTimelineEmptyFilteredHint,
                );
        }
        final (event, category) = visible[index - 2];
        return _TimelineRow(
          key: ValueKey('team-run-event-${event.seq ?? index}'),
          category: category,
          text: _eventText(l10n, snapshot, event),
          at: _eventTime(event),
        );
      },
    );
    return Stack(
      children: [
        list,
        if (arrived > 0)
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Center(
              child: _JumpPill(count: arrived, onTap: onJump),
            ),
          ),
      ],
    );
  }
}

/// One quiet line per event: category glyph, the text, the clock time.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    super.key,
    required this.category,
    required this.text,
    required this.at,
  });

  final _EventCategory category;
  final String text;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final (icon, tone) = _categoryGlyph(category);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                icon,
                size: 18,
                color: AppTheme.statusColor(theme, tone),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (at != null) ...[
              const SizedBox(width: 12),
              Text(
                teamClockLabel(context, at!),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "N new · Jump to latest", floating over the held list.
class _JumpPill extends StatelessWidget {
  const _JumpPill({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const ValueKey('team-run-timeline-jump'),
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 3,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIconography.chevronUp,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _copy(context).teamUiRunTimelineJump(count),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Technical details
// ---------------------------------------------------------------------------

/// The run's Technical details (02-ux §8): the term pair, the product
/// values, then every raw provider field with a copy button.
class _RunDetailsSheet extends StatelessWidget {
  const _RunDetailsSheet({required this.run, required this.work});

  final OrchestrationRun run;
  final List<WorkItem> work;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final tracked = [
      for (final item in work)
        if (item.runId == run.id) item.id,
    ];
    // Every scalar the provider sent, minus what the rows above show.
    const shown = {'id', 'run_id', 'title', 'status', 'formula'};
    final scalars = <(String, String)>[];
    void collect(Map<String, Object?> map, String prefix) {
      for (final entry in map.entries) {
        final value = entry.value;
        if (prefix.isEmpty && shown.contains(entry.key)) continue;
        if (value is String || value is num || value is bool) {
          scalars.add(('$prefix${entry.key}', '$value'));
        }
      }
    }

    collect(run.raw, '');
    collect(_map(run.raw['metadata']), 'metadata.');
    scalars.sort((a, b) => a.$1.compareTo(b.$1));
    return SingleChildScrollView(
      key: const ValueKey('team-run-details-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.teamUiTechnicalDetails, style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          TeamTermRow(_term(l10n, run)),
          const SizedBox(height: 8),
          TeamIdentityRow(
            label: l10n.teamUiRunLabelState,
            value: teamRunStateWordFor(l10n, run, work),
          ),
          if (run.startedAt case final at?)
            TeamIdentityRow(
              label: l10n.teamUiRunLabelStarted,
              value: at.toLocal().toString(),
              mono: true,
            ),
          if (run.updatedAt case final at?)
            TeamIdentityRow(
              label: l10n.teamUiRunLabelUpdated,
              value: at.toLocal().toString(),
              mono: true,
            ),
          const SizedBox(height: 12),
          Text(
            l10n.teamUiHomeHostRawHeading,
            style: theme.textTheme.labelLarge?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          TeamTechnicalValue(label: l10n.teamUiRunLabelId, value: run.id),
          TeamTechnicalValue(
            label: l10n.teamUiRunLabelKind,
            value: run.kind.name,
          ),
          TeamTechnicalValue(
            label: l10n.teamUiRunLabelRawState,
            value: run.rawState ?? '',
          ),
          // A batch is named by its work; the convoy's own title stays here.
          if (_text(run.raw['title']) case final rawTitle?
              when rawTitle != run.title)
            TeamTechnicalValue(
              label: l10n.teamUiRunLabelRawTitle,
              value: rawTitle,
            ),
          if (run.formula case final formula?)
            TeamTechnicalValue(
              label: l10n.teamUiRunLabelFormula,
              value: formula,
            ),
          if (run.projectId case final project?)
            TeamTechnicalValue(
              label: l10n.teamUiRunLabelProject,
              value: project,
            ),
          if (run.lastError case final error?)
            TeamTechnicalValue(
              label: l10n.teamUiRunLabelLastError,
              value: error,
            ),
          if (tracked.isNotEmpty)
            TeamTechnicalValue(
              label: l10n.teamUiRunLabelTrackedWork,
              value: tracked.join(', '),
            ),
          for (final (key, value) in scalars)
            TeamTechnicalValue(label: key, value: value),
        ],
      ),
    );
  }
}
