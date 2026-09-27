/// The run detail (02-ux-flows-and-screens §4): what a run row on the AI
/// Team home opens. The app bar names the run and its Gas City term
/// ("Run · convoy"); the tabs are **Overview · Work · Agents · Timeline**.
///
/// **Overview** (§4.1) answers the five BRD questions top to bottom with
/// one element each: the objective with its state word and elapsed time;
/// "N of M done" over one segmented bar; the Working and Blocked counts,
/// then, when the host reports `/usage` at all, that it reports no cost for
/// one task (slice-P5.2: Gas City's figures are the whole team's day or a
/// worker's recent window, and neither can be charged to this task without
/// billing it an earlier task's spend; the team page has the day's
/// estimate); why work is blocked, when the host or the graph says; the single most
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
/// **Run controls** (TEAM-204): the top bar keeps one icon action
/// (Refresh); its overflow holds Technical details and Cancel run (a
/// formula run) or Close batch (a convoy), each two-step in the error
/// tone and present only with `controlCancelRun` on a run that is still
/// open; the receipt chip sits under the state header. The supervisor
/// has no pause / resume for a run, so none is offered.
///
/// Built from kit parts (owner rule 2026-09-27, R6): [KitScreen] with its
/// [KitTopBar] and menu, [KitTabSwitcher.tabs] for the four tabs,
/// [KitSegmented] for the List / Graph view and the Timeline filter,
/// [KitJumpPill] for the held timeline, [KitRow], [KitText], [KitIcon] and
/// [KitAvatar] for the rest, and [showKitSheet] for Technical details.
library;

import 'dart:async';
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
import '../team_conversation/team_conversation.dart';
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

class _RunScreenState extends State<RunScreen> {
  /// Past this offset the timeline counts as scrolled away.
  static const _scrolledAway = 24.0;

  /// The tab in view ([TeamRunTab] index).
  int _tab = TeamRunTab.overview.index;
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
    super.dispose();
  }

  void _selectTab(int index) => setState(() => _tab = index);

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
        duration: KitMotion.standard,
        curve: KitMotion.enter,
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
    final l10n = _copy(context);
    unawaited(
      showKitSheet<void>(
        context,
        title: l10n.teamUiTechnicalDetails,
        icon: AppIconography.info,
        body: (_) =>
            _RunDetailsSheet(run: run, work: widget.controller.snapshot.work),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = _copy(context);
      final run = _run;
      // The Overview opens with the task's title, whole, so the bar stays
      // empty there rather than say it twice; the other tabs keep it on
      // one line. The Gas City term ("convoy", "formula") is under
      // Technical details.
      final overview = _tab == TeamRunTab.overview.index && run != null;
      return KitScreen(
        key: const ValueKey('team-run'),
        topBar: KitTopBar(
          title: overview ? '' : run?.title ?? l10n.teamUiRunTermUnknown,
          titleKey: overview ? null : const ValueKey('team-run-title'),
          actions: [
            KitAction(
              key: const ValueKey('team-run-refresh'),
              label: l10n.teamUiRefresh,
              icon: AppIconography.sync,
              onPressed: _refreshing ? null : _refresh,
            ),
          ],
          // One icon action and the overflow (design standard §1):
          // Technical details always, Stop run / Close batch only on an
          // open run with the capability.
          menu: [
            if (run != null)
              KitMenuItem(
                key: const ValueKey('team-run-details'),
                label: l10n.teamUiTechnicalDetails,
                icon: AppIconography.info,
                onSelected: () => _openDetails(run),
              ),
            if (run != null &&
                widget.controller.capabilities.controlCancelRun &&
                _open(run))
              KitMenuItem(
                key: const ValueKey('team-run-cancel'),
                label: run.kind == RunKind.batch
                    ? l10n.teamUiControlCloseBatch
                    : l10n.teamUiControlCancelRun,
                destructive: true,
                onSelected: () => unawaited(_cancelRun(run)),
              ),
          ],
          menuKey: const ValueKey('team-run-more'),
        ),
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

    final live = _scopedEvents();
    final held = _held;
    final shown = held ?? live;
    final arrived = held == null ? 0 : math.max(0, live.length - held.length);
    final pages = <Widget>[
      KitRefresh(
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
          onSeeAllSteps: () => _selectTab(TeamRunTab.work.index),
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
    ];

    // Old numbers stay at full strength; the one status line above says
    // how old they are (LOOK-14).
    return KeyedSubtree(
      key: const ValueKey('team-run-data'),
      child: KitTabSwitcher.tabs(
        stripKey: const ValueKey('team-run-tabs'),
        index: _tab,
        onSelected: _selectTab,
        tabs: [
          for (final tab in TeamRunTab.values)
            KitTab(
              key: ValueKey('team-run-tab-${tab.name}'),
              label: switch (tab) {
                TeamRunTab.overview => l10n.teamUiRunTabOverview,
                TeamRunTab.work => l10n.teamUiRunTabWork,
                TeamRunTab.agents => l10n.teamUiRunTabAgents,
                TeamRunTab.timeline => l10n.teamUiRunTabTimeline,
              },
            ),
        ],
        children: pages,
      ),
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
      padding: EdgeInsetsDirectional.only(
        bottom: KitScreen.endPadding(context),
      ),
      children: [
        for (final agent in agents)
          TeamAgentRow(
            keyPrefix: 'team-run-agent',
            agent: agent,
            work: workById[agent.currentWorkId],
            now: now,
            onTap: () => Navigator.of(context).push(
              KitPageRoute<void>(
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
    // A task's own cost is not reported (docs/qa/codex-p52-2026-09-27):
    // said once under Details where the host reports usage at all, never
    // replaced by the team's day total or a worker's recent window.
    final costUnreported = controller.capabilities.usage;
    final policy = controller.policy;
    final tokens = KitTokens.of(context);

    Widget rails(Widget child, {double top = 0}) => Padding(
      padding: EdgeInsetsDirectional.only(
        start: tokens.gutter,
        end: tokens.gutter,
        top: top,
      ),
      child: child,
    );

    return ListView(
      key: const ValueKey('team-run-overview'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsetsDirectional.only(
        top: tokens.space4,
        bottom: KitScreen.endPadding(context),
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
        TeamTaskConversationRow(team: controller, runId: run.id),
        if (receipt case final record?)
          rails(
            top: tokens.space2,
            teamControlReceipt(
              context,
              record,
              key: const ValueKey('team-run-receipt'),
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
            top: tokens.space5,
            _StageLine(key: const ValueKey('team-run-stage-line'), at: stage),
          ),
        if (stall != null)
          rails(
            top: tokens.space4,
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
            title: teamGateWho(l10n, controller.snapshot, gates.first),
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
              trailing: const KitChevron(),
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
        SizedBox(height: tokens.space2),
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
                if (costUnreported)
                  _DetailLine(
                    label: l10n.teamUiRunDetailsUsage,
                    value: l10n.teamRunCostUnreported,
                    valueKey: const ValueKey('team-run-usage'),
                  ),
                // 02-ux §7: the host's supervision level and boundaries,
                // read-only (TEAM-207); absent when the host reports none.
                if (policy != null) ...[
                  SizedBox(height: tokens.space2),
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
    final tokens = KitTokens.of(context);
    final (_, tone) = teamRunGlyph(run.state);
    const dot = KitText(
      teamUsageSeparator,
      role: KitTextRole.secondary,
      tone: KitTextTone.secondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KitText(
          run.title,
          key: const ValueKey('team-run-objective-title'),
          role: KitTextRole.title,
        ),
        SizedBox(height: tokens.space1),
        // One line that wraps at large text rather than overflowing.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            KitText(
              stateWord,
              key: const ValueKey('team-run-state'),
              role: KitTextRole.label,
              tone: _textTone(tone),
            ),
            if (steps case final steps?) ...[
              dot,
              KitText(
                steps,
                key: const ValueKey('team-run-progress-label'),
                role: KitTextRole.secondary,
                tone: KitTextTone.secondary,
              ),
            ],
            if (elapsed case final elapsed?) ...[
              dot,
              KitText(
                elapsed,
                key: const ValueKey('team-run-elapsed'),
                role: KitTextRole.secondary,
                tone: KitTextTone.secondary,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// A status tone as a text tone: the state word in its colour, never the
/// only sign (the word itself says it).
KitTextTone? _textTone(AppStatusTone tone) => switch (tone) {
  AppStatusTone.ok => KitTextTone.success,
  AppStatusTone.failure => KitTextTone.danger,
  AppStatusTone.progress => KitTextTone.primary,
  AppStatusTone.neutral => KitTextTone.secondary,
  _ => KitTextTone.attention,
};

/// Waiting · Working · Reviewing · Done: where the task is, at most four
/// stages, the current one named in the accent and the ones behind it
/// checked. One semantics label says it.
class _StageLine extends StatelessWidget {
  const _StageLine({super.key, required this.at});

  final TeamStage at;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final tokens = KitTokens.of(context);
    final done = at == TeamStage.done;
    Widget mark(TeamStage stage) {
      final passed = stage.index < at.index || done;
      final current = stage == at && !done;
      // Passed: the done check; current: the accent dot; ahead: a quiet
      // dot. The words say it too (never colour-only).
      final Widget glyph = passed
          ? const KitIcon.status(AppStatusTone.ok, icon: AppIconography.check)
          : current
          ? const KitIcon.status(
              AppStatusTone.progress,
              icon: AppIconography.statusDot,
            )
          : const KitIcon(
              AppIconography.statusDot,
              size: KitIconSize.small,
              tone: KitTextTone.tertiary,
            );
      return Row(
        key: ValueKey('team-run-stage-${stage.name}'),
        mainAxisSize: MainAxisSize.min,
        children: [
          glyph,
          SizedBox(width: tokens.space1),
          // Flexible: a stage word at 2.5× on a 320 dp phone (Arabic
          // especially) wraps under its mark instead of overflowing.
          Flexible(
            child: KitText(
              teamStageWord(l10n, stage),
              role: current ? KitTextRole.label : KitTextRole.secondary,
              tone: current || passed
                  ? KitTextTone.primary
                  : KitTextTone.secondary,
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
          spacing: tokens.space4,
          runSpacing: tokens.space2,
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
    final tokens = KitTokens.of(context);
    return Semantics(
      button: true,
      expanded: open,
      child: KitRow(
        leading: KitRow.icon(context, AppIconography.info),
        title: l10n.teamUiRunDetails,
        trailing: Padding(
          padding: EdgeInsetsDirectional.only(end: tokens.space3),
          child: KitIcon(
            open ? AppIconography.chevronUp : AppIconography.chevronDown,
            size: KitIconSize.small,
            tone: KitTextTone.secondary,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// A label over its value, under Details.
class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(vertical: tokens.space1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KitText(
            label,
            role: KitTextRole.caption,
            tone: KitTextTone.secondary,
          ),
          KitText(value, key: valueKey),
        ],
      ),
    );
  }
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
    final tokens = KitTokens.of(context);
    final items = _workOf(snapshot, runId);
    // At large text the words alone fit 320dp; the icons go.
    final icons = !AppTheme.stackedActions(context);
    final toggle = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        tokens.gutter,
        tokens.space2,
        tokens.gutter,
        tokens.space1,
      ),
      child: KitSegmented<TeamWorkView>(
        key: const ValueKey('team-run-work-view'),
        semanticsLabel: l10n.teamUiRunTabWork,
        segments: [
          KitSegment(
            key: const ValueKey('team-run-work-view-list'),
            value: TeamWorkView.list,
            icon: icons ? AppIconography.checklist : null,
            label: l10n.teamUiWorkViewList,
          ),
          KitSegment(
            key: const ValueKey('team-run-work-view-graph'),
            value: TeamWorkView.graph,
            icon: icons ? AppIconography.fork : null,
            label: l10n.teamUiWorkViewGraph,
          ),
        ],
        selected: view,
        onChanged: onView,
      ),
    );
    if (items.isEmpty) {
      return ListView(
        key: const ValueKey('team-run-work-empty'),
        padding: EdgeInsetsDirectional.symmetric(vertical: tokens.space2),
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
    final tokens = KitTokens.of(context);
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
            padding: EdgeInsetsDirectional.only(bottom: tokens.space1),
            child: _WorkGroup(
              key: ValueKey('team-run-work-group-${state.name}'),
              state: state,
              count: l10n.teamUiWorkGroupHeader(
                teamWorkStateWord(l10n, state),
                members.length,
              ),
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
  });

  final WorkState state;
  final String count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final (icon, tone) = teamWorkGlyph(state);
    // A section heading (design standard §6) with the state's glyph, then
    // its rows; the state also lives in every row's glyph.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            tokens.gutter,
            tokens.space4,
            tokens.gutter,
            tokens.space1,
          ),
          child: Row(
            children: [
              KitIcon.status(tone, icon: icon),
              SizedBox(width: tokens.space2),
              Expanded(
                child: KitText(
                  count,
                  key: ValueKey('team-run-work-group-count-${state.name}'),
                  role: KitTextRole.label,
                  tone: _textTone(tone),
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
    final tokens = KitTokens.of(context);
    final (icon, tone) = teamWorkGlyph(item.state);
    final color = AppTheme.statusColor(Theme.of(context), tone);
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
          : KitText(
              detail,
              key: ValueKey('team-run-work-detail-${item.id}'),
              role: KitTextRole.secondary,
              // What it waits on is the part to notice.
              tone: waitsOn > 0 ? _textTone(tone) : KitTextTone.secondary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Padding(
        padding: EdgeInsetsDirectional.symmetric(horizontal: tokens.space3),
        child: Semantics(
          label: name == null
              ? l10n.teamUiWorkOwnerNone
              : l10n.teamUiWorkOwnerSemantics(name),
          child: ExcludeSemantics(
            // The owner as the kit's one identity mark: its initial.
            child: KeyedSubtree(
              key: ValueKey('team-run-work-owner-${item.id}'),
              child: KitAvatar(
                name: name == null ? '—' : workOwnerInitial(name),
                decorative: true,
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
    final tokens = KitTokens.of(context);
    final list = ListView.builder(
      key: const ValueKey('team-run-timeline'),
      controller: scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsetsDirectional.only(
        bottom: KitScreen.endPadding(context),
      ),
      itemCount: visible.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          // The one filter: one choice among four short, always-visible
          // options (KitSegmented), never a row of chips.
          return Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              tokens.gutter,
              tokens.space2,
              tokens.gutter,
              tokens.space1,
            ),
            child: KitSegmented<TeamTimelineFilter>(
              semanticsLabel: l10n.teamUiRunTabTimeline,
              segments: [
                for (final f in TeamTimelineFilter.values)
                  KitSegment(
                    key: ValueKey('team-run-timeline-filter-${f.name}'),
                    value: f,
                    label: switch (f) {
                      TeamTimelineFilter.all => l10n.teamUiRunTimelineFilterAll,
                      TeamTimelineFilter.work =>
                        l10n.teamUiRunTimelineFilterWork,
                      TeamTimelineFilter.agents =>
                        l10n.teamUiRunTimelineFilterAgents,
                      TeamTimelineFilter.decisions =>
                        l10n.teamUiRunTimelineFilterDecisions,
                    },
                  ),
              ],
              selected: filter,
              onChanged: onFilter,
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
    // "N new · Jump to latest" over the held list (the kit's one pill).
    return KitJumpPillLayer(
      clearBottomInset: false,
      pill: KitJumpPill.older(
        pillKey: const ValueKey('team-run-timeline-jump'),
        label: l10n.teamUiRunTimelineJump(arrived),
        visible: arrived > 0,
        onPressed: onJump,
      ),
      child: list,
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
    final tokens = KitTokens.of(context);
    final (icon, tone) = _categoryGlyph(category);
    // One quiet row: the category glyph, the words, the clock time.
    return KitRow(
      leading: KitRow.icon(
        context,
        icon,
        color: AppTheme.statusColor(Theme.of(context), tone),
      ),
      title: text,
      titleMaxLines: 3,
      trailing: at == null
          ? null
          : Padding(
              padding: EdgeInsetsDirectional.only(end: tokens.space3),
              child: KitText(
                teamClockLabel(context, at!),
                role: KitTextRole.caption,
                tone: KitTextTone.secondary,
                tabular: true,
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
    final tokens = KitTokens.of(context);
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
    // The kit sheet frame gives the title and scrolls the body.
    return KeyedSubtree(
      key: const ValueKey('team-run-details-sheet'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TeamTermRow(_term(l10n, run)),
          SizedBox(height: tokens.space2),
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
          SizedBox(height: tokens.space3),
          KitText(
            l10n.teamUiHomeHostRawHeading,
            role: KitTextRole.label,
            tone: KitTextTone.secondary,
          ),
          SizedBox(height: tokens.space1),
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
