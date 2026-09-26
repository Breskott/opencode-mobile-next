/// The Agent detail (02-ux-flows-and-screens §5.2): what a fleet row
/// opens. A short status page; the agent's work itself is shown in one
/// place only, the chat (docs/design/team-conversation-2026-09-26.md).
///
/// The app bar names the agent by role and name ("Worker · furiosa") and
/// what it works on ("On “Sync engine”"). The header is one status line:
/// the state from the agent's **session** (not the agents list), the
/// context use as a number and the session's elapsed time, "Recycling
/// soon" from [teamContextRecyclePercent]; under it one muted line with the
/// newest step from its live output and when it was last active. Then
/// "The worker didn't start" and a question waiting on you, when true.
///
/// The actions, in the one button hierarchy: the primary is **Open
/// conversation** (the agent's own OpenCode session on the chat page in
/// watching mode) — or, when no session can be matched on the connected
/// server, **Live output** ([AgentOutputScreen], drawn with the chat's own
/// parts) with a line saying why. Then the controls (TEAM-204,
/// capability-gated: absent, never disabled): Message (secondary), Nudge,
/// Pause / Resume, and under More Stop and Restart (confirmed, error tone)
/// and Reassign work…; the newest receipts under them.
///
/// Technical details (§8) fold at the end: provider, model, harness,
/// context, working directory, branch, usage, the current work, and every
/// raw field with a copy button.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../../state/team_conversation.dart' show teamSessionState;
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../widgets/team_agent_row.dart';
import '../../widgets/team_controls.dart';
import '../../widgets/team_now.dart';
import '../../widgets/team_technical_details.dart';
import '../../widgets/team_vocabulary.dart';
import '../team_conversation/team_conversation.dart';
import 'agent_output_screen.dart';
import 'team_states.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

class AgentScreen extends StatefulWidget {
  const AgentScreen({
    super.key,
    required this.controller,
    required this.agentId,
    this.now,
  });

  final OrchestrationController controller;
  final String agentId;

  /// Clock for the session age; tests pin it.
  final DateTime Function()? now;

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  late AgentOutputTail _tail;
  bool _refreshing = false;

  /// Where "Open conversation" leads, looked up once per agent session
  /// (its folder and start); null while looking.
  TeamAgentConversationLookup? _lookup;
  String? _lookupFor;

  DateTime get _now => (widget.now ?? DateTime.now)();

  /// Looks for the agent's OpenCode session when the agent's folder or
  /// session start changed since the last look.
  void _lookUp(OrchestrationAgent agent) {
    final key = '${agent.workDir}|${agent.sessionStartedAt}';
    if (key == _lookupFor) return;
    _lookupFor = key;
    _lookup = null;
    unawaited(() async {
      final found = await lookupTeamAgentConversation(context, agent);
      if (!mounted || _lookupFor != key) return;
      setState(() => _lookup = found);
    }());
  }

  void _openConversation(OrchestrationAgent agent) => unawaited(
    openTeamAgentConversation(
      context,
      agent,
      team: widget.controller,
      lookup: _lookup,
    ),
  );

  @override
  void initState() {
    super.initState();
    _tail = widget.controller.watchAgentOutput(widget.agentId)
      ..addListener(_changed);
    widget.controller.addListener(_rebind);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebind);
    _tail.removeListener(_changed);
    widget.controller.unwatchAgentOutput(widget.agentId);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    // Live output opening on top notifies the shared tail from its own
    // initState, mid-build: redraw after that frame instead.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  /// The screen may open before the snapshot names the agent's session;
  /// once it does, the tail is opened for real.
  void _rebind() {
    if (_tail.sessionId != null || _tail.watching) return;
    final agent = _agent;
    if (agent?.sessionId == null) return;
    final controller = widget.controller;
    _tail.removeListener(_changed);
    controller.unwatchAgentOutput(widget.agentId);
    _tail = controller.watchAgentOutput(widget.agentId)..addListener(_changed);
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

  OrchestrationAgent? get _agent {
    for (final agent in widget.controller.snapshot.agents) {
      if (agent.id == widget.agentId || agent.sessionId == widget.agentId) {
        return agent;
      }
    }
    return null;
  }

  void _openDetails(OrchestrationAgent agent) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AgentDetailsSheet(agent: agent),
    );
  }

  void _openOutput() {
    final miss = _lookup?.miss;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AgentOutputScreen(
          controller: widget.controller,
          agentId: widget.agentId,
          note: miss == null
              ? null
              : teamAgentConversationMissNote(context, miss),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l10n = _copy(context);
      final theme = Theme.of(context);
      final agent = _agent;
      // The agent by its role and short name ("Worker · furiosa") with the
      // task it works on; the engine's full name, pool, pack and session
      // are under Technical details.
      final task = agent == null ? null : _workOf(agent)?.title;
      final term = task == null ? null : l10n.teamAgentWorksOn(task);
      return Scaffold(
        key: const ValueKey('team-agent'),
        appBar: AppBar(
          toolbarHeight: _toolbarHeight(context),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                agent == null ? widget.agentId : teamAgentTitle(l10n, agent),
                key: const ValueKey('team-agent-title'),
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (term != null)
                Text(
                  term,
                  key: const ValueKey('team-agent-term'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.mutedOf(theme),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          actions: [
            IconButton(
              key: const ValueKey('team-agent-refresh'),
              tooltip: l10n.teamUiRefresh,
              onPressed: _refreshing ? null : _refresh,
              icon: const Icon(AppIconography.sync),
            ),
            // One icon action, then the overflow (design standard §1):
            // Live output when it is not the primary, Technical details.
            if (agent != null)
              PopupMenuButton<String>(
                key: const ValueKey('team-agent-more'),
                tooltip: l10n.teamUiControlMoreActions,
                icon: const Icon(AppIconography.more),
                onSelected: (value) =>
                    value == 'output' ? _openOutput() : _openDetails(agent),
                itemBuilder: (context) => [
                  if (_lookup?.miss == null)
                    PopupMenuItem<String>(
                      key: const ValueKey('team-agent-menu-output'),
                      value: 'output',
                      child: Text(l10n.teamUiAgentOutputTitle),
                    ),
                  PopupMenuItem<String>(
                    key: const ValueKey('team-agent-details'),
                    value: 'details',
                    child: Text(l10n.teamUiTechnicalDetails),
                  ),
                ],
              ),
          ],
        ),
        body: _body(context, agent),
      );
    },
  );

  /// Two lines of title need more than the default toolbar at large text.
  double _toolbarHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final needed = scaler.scale(16) * 1.4 + scaler.scale(12) * 1.4 + 12;
    return math.max(kToolbarHeight, needed);
  }

  /// The screen on the kit (design standard §1, §3-§5): the one loading
  /// bar under the app bar, the one status line when the data is old, and
  /// the state page or the agent's sections.
  Widget _body(BuildContext context, OrchestrationAgent? agent) {
    final l10n = _copy(context);
    final controller = widget.controller;
    final onRetry = _refreshing ? null : _refresh;
    final state = teamScreenState(
      context,
      controller: controller,
      keyPrefix: 'team-agent',
      onRetry: onRetry,
    );
    final Widget body;
    Widget? status;
    if (state != null) {
      body = state;
    } else if (agent == null) {
      body = KitStateView(
        key: const ValueKey('team-agent-missing'),
        icon: AppIconography.cloudOff,
        title: l10n.teamUiAgentMissingTitle,
        body: l10n.teamUiAgentMissingHint,
        primary: KitAction(
          label: l10n.teamUiRunBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      );
    } else {
      status = teamStatusLine(
        context,
        controller: controller,
        keyPrefix: 'team-agent',
        onRetry: onRetry,
      );
      body = _sections(context, agent);
    }
    return KitScreen(
      header: [?status],
      loading: teamScreenLoading(controller),
      loadingLabel: l10n.teamUiCardLoading,
      body: body,
    );
  }

  WorkItem? _workOf(OrchestrationAgent agent) {
    for (final item in widget.controller.snapshot.work) {
      if (item.id == agent.currentWorkId) return item;
    }
    return null;
  }

  /// A worker that is not running while a task waits for one: it should
  /// have started (and the home's Now line says the same).
  bool _didNotStart(OrchestrationAgent agent) {
    if (teamAgentIsLive(agent)) return false;
    if (teamAgentRole(agent) != TeamAgentRole.worker) return false;
    final snapshot = widget.controller.snapshot;
    return teamVisibleRuns(snapshot.runs).any(
      (run) => teamRunWaitsForWorker(
        run,
        snapshot.work,
        cycleOf: widget.controller.cycleFor,
      ),
    );
  }

  Widget _sections(BuildContext context, OrchestrationAgent agent) {
    final l10n = _copy(context);
    final controller = widget.controller;
    final snapshot = controller.snapshot;
    final work = _workOf(agent);
    OrchestrationGate? gate;
    for (final g in snapshot.gates) {
      if (g.kind == GateKind.reviewReady) continue;
      if (g.agentId == agent.id ||
          (agent.sessionId != null && g.agentId == agent.sessionId) ||
          (work != null && g.workId == work.id)) {
        gate = g;
        break;
      }
    }
    final stale = controller.isStale;
    _lookUp(agent);
    Widget pad(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
    // The primary: the agent's own conversation, or Live output when no
    // session of its can be matched on the connected server.
    final miss = _lookup?.miss;
    final primary = miss == null
        ? KitAction(
            key: const ValueKey('team-agent-open-conversation'),
            label: l10n.teamOpenConversation,
            icon: AppIconography.chat,
            onPressed: () => _openConversation(agent),
          )
        : KitAction(
            key: const ValueKey('team-agent-open-output'),
            label: l10n.teamUiAgentOutputTitle,
            icon: AppIconography.terminal,
            onPressed: _openOutput,
          );
    final body = KitRefresh(
      key: const ValueKey('team-agent-pull'),
      onRefresh: _refresh,
      child: ListView(
        key: const ValueKey('team-agent-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          top: 12,
          bottom: KitScreen.endPadding(context),
        ),
        children: [
          pad(
            _Header(
              agent: agent,
              now: _now,
              lastStep: _lastStep(),
              blocked: work?.isBlocked ?? false,
            ),
          ),
          if (_didNotStart(agent)) ...[
            const SizedBox(height: 12),
            pad(
              KitNotice(
                key: const ValueKey('team-agent-did-not-start'),
                tone: AppStatusTone.attention,
                icon: AppIconography.warning,
                title: l10n.teamAgentDidNotStartTitle,
                message: l10n.teamAgentDidNotStartBody,
                actions: [
                  teamUnstickAction(
                    context,
                    controller,
                    keyPrefix: 'team-agent-did-not-start',
                    wake: [agent],
                    wakeLabel: l10n.teamAgentStartIt,
                  ),
                ],
              ),
            ),
          ],
          if (gate != null) ...[
            const SizedBox(height: 16),
            pad(
              _NeedsYou(
                key: const ValueKey('team-agent-gate'),
                gate: gate,
                hostMode:
                    controller.host?.hostMode ?? controller.config.hostMode,
              ),
            ),
          ],
          const SizedBox(height: 20),
          pad(
            _Controls(
              key: const ValueKey('team-agent-controls'),
              controller: controller,
              agent: agent,
              work: work,
              primary: primary,
              primaryNote: miss == null
                  ? null
                  : teamAgentConversationMissNote(context, miss),
            ),
          ),
          const SizedBox(height: 8),
          pad(
            _TechnicalDetails(
              agent: agent,
              work: work,
              usage: controller.capabilities.usage ? snapshot.usage : null,
              showUsage: controller.capabilities.usage,
            ),
          ),
        ],
      ),
    );
    // Stale numbers dim; they stay readable (never colour-only).
    return stale ? Opacity(opacity: .6, child: body) : body;
  }

  /// The newest tool call in the agent's live output, its first line: what
  /// it is doing now or did last.
  String? _lastStep() {
    final blocks = parseAgentTranscript(_tail.text);
    for (final block in blocks.reversed) {
      if (block is AgentStepGroup && block.steps.isNotEmpty) {
        final command = block.steps.last.command.trim();
        final line = command.split('\n').first.trim();
        return line.isEmpty ? null : line;
      }
    }
    return null;
  }
}

bool _has(String? value) => value != null && value.trim().isNotEmpty;

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// The status: glyph + state word (from the session), the context number
/// and the session's elapsed time on one wrapping line; one muted line
/// under it with the newest step and when it was last active (and that
/// its task is blocked); "Recycling soon" from the recycle threshold.
class _Header extends StatelessWidget {
  const _Header({
    required this.agent,
    required this.now,
    required this.lastStep,
    required this.blocked,
  });

  final OrchestrationAgent agent;
  final DateTime now;
  final String? lastStep;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final state = teamSessionState(agent);
    final (icon, tone) = teamAgentGlyph(state);
    final color = AppTheme.statusColor(theme, tone);
    final percent = agent.contextPercent;
    final started = agent.sessionStartedAt;
    final age = started == null
        ? null
        : teamElapsedLabel(
            l10n,
            now.isBefore(started) ? Duration.zero : now.difference(started),
          );
    final small = theme.textTheme.bodyMedium?.copyWith(color: muted);
    final lastActive = agent.lastActivity;
    final activity = [
      if (lastStep case final step?) l10n.teamAgentLastStep(step),
      if (lastActive != null)
        l10n.teamAgentLastActive(
          teamElapsedLabel(
            l10n,
            now.isBefore(lastActive)
                ? Duration.zero
                : now.difference(lastActive),
          ),
        ),
    ].join(teamUsageSeparator);
    return Column(
      key: const ValueKey('team-agent-header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            Icon(icon, size: 18, color: color),
            Text(
              teamAgentStateWord(l10n, state),
              key: const ValueKey('team-agent-state'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (percent != null) ...[
              Text(' · ', style: small),
              TeamContextNumber(
                key: const ValueKey('team-agent-context'),
                percent: percent,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (age != null) ...[
              Text(' · ', style: small),
              Text(
                l10n.teamUiAgentSessionAge(age),
                key: const ValueKey('team-agent-age'),
                style: small,
              ),
            ],
          ],
        ),
        if (activity.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              activity,
              key: const ValueKey('team-agent-activity-line'),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (blocked)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.teamUiAgentWorkBlocked,
              key: const ValueKey('team-agent-work-dependency'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.statusColor(theme, AppStatusTone.attention),
              ),
            ),
          ),
        if (percent != null && percent >= teamContextRecyclePercent)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              key: const ValueKey('team-agent-recycling'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  AppIconography.warning,
                  size: 16,
                  color: AppTheme.statusColor(theme, AppStatusTone.failure),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.teamUiAgentRecyclingSoon,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.statusColor(theme, AppStatusTone.failure),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The question waiting on the person, read-only in Sprint A: the gate
/// kind and title, then where to answer it.
class _NeedsYou extends StatelessWidget {
  const _NeedsYou({super.key, required this.gate, required this.hostMode});

  final OrchestrationGate gate;
  final OrchestrationHostMode hostMode;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final (icon, tone) = teamGateGlyph(gate.kind);
    return KitPanel(
      tone: tone,
      icon: icon,
      title: l10n.teamUiAgentNeedsYou,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teamGateKindWord(l10n, gate.kind),
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          Text(gate.title, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(switch (hostMode) {
            OrchestrationHostMode.computer =>
              l10n.teamUiHomeGateAnswerOnComputer,
            OrchestrationHostMode.phone => l10n.teamUiHomeGateAnswerOnPhone,
          }, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Controls (TEAM-204)
// ---------------------------------------------------------------------------

/// The one thing you can do (§5.3), as buttons that exist only when the
/// host allows them: Message and Nudge first, then Pause / Resume by the
/// agent's state, Stop and Restart in the error tone behind a two-step
/// confirmation, and Reassign work…. The newest receipt for this agent
/// sits under the row.
class _Controls extends StatefulWidget {
  const _Controls({
    super.key,
    required this.controller,
    required this.agent,
    required this.work,
    required this.primary,
    this.primaryNote,
  });

  final OrchestrationController controller;
  final OrchestrationAgent agent;
  final WorkItem? work;

  /// Open conversation, or Live output when there is none to open.
  final KitAction primary;

  /// Why the primary is Live output, under it.
  final String? primaryNote;

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  bool _busy = false;

  OrchestrationController get _controller => widget.controller;
  OrchestrationAgent get _agent => widget.agent;

  /// The newest control record for this agent, by any of its ids.
  MutationRecord? get _receipt {
    MutationRecord? best;
    for (final id in {_agent.id, ?_agent.sessionId}) {
      for (final kind in const [
        MutationKind.controlAgent,
        MutationKind.message,
      ]) {
        final record = _controller.latestMutation(kind: kind, targetId: id);
        if (record != null &&
            (best == null || record.createdAt.isAfter(best.createdAt))) {
          best = record;
        }
      }
    }
    return best;
  }

  /// The newest assignment onto this agent.
  MutationRecord? get _assignReceipt {
    MutationRecord? best;
    for (final record in _controller.mutations) {
      if (record.kind != MutationKind.assign ||
          record.retriedBy != null ||
          record.request.agentId != _agent.id) {
        continue;
      }
      if (best == null || record.createdAt.isAfter(best.createdAt)) {
        best = record;
      }
    }
    return best;
  }

  Future<void> _run(Future<MutationRecord> Function() send) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await send();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _nudge() =>
      _run(() => _controller.controlAgent(_agent.id, AgentControlAction.nudge));

  Future<void> _pause() =>
      _run(() => _controller.controlAgent(_agent.id, AgentControlAction.pause));

  Future<void> _resume() => _run(
    () => _controller.controlAgent(_agent.id, AgentControlAction.resume),
  );

  Future<void> _stop() async {
    final l10n = _copy(context);
    final ok = await confirmTeamControl(
      context,
      title: l10n.teamUiControlStopConfirmTitle(_agent.name),
      message: l10n.teamUiControlStopConfirmBody,
      confirmLabel: l10n.teamUiControlStopConfirmAction,
      sheetKey: const ValueKey('team-agent-stop-confirm'),
      confirmKey: const ValueKey('team-agent-stop-confirm-action'),
    );
    if (!ok || !mounted) return;
    await _run(
      () => _controller.controlAgent(_agent.id, AgentControlAction.stop),
    );
  }

  Future<void> _restart() async {
    final l10n = _copy(context);
    final ok = await confirmTeamControl(
      context,
      title: l10n.teamUiControlRestartConfirmTitle(_agent.name),
      message: l10n.teamUiControlRestartConfirmBody,
      confirmLabel: l10n.teamUiControlRestartConfirmAction,
      sheetKey: const ValueKey('team-agent-restart-confirm'),
      confirmKey: const ValueKey('team-agent-restart-confirm-action'),
    );
    if (!ok || !mounted) return;
    await _run(
      () => _controller.controlAgent(_agent.id, AgentControlAction.restart),
    );
  }

  Future<void> _message() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MessageSheet(agent: _agent),
    );
    if (text == null || text.trim().isEmpty || !mounted) return;
    await _run(() => _controller.messageAgent(_agent.id, text.trim()));
  }

  Future<void> _reassign() async {
    final ready = [
      for (final item in _controller.snapshot.work)
        if (item.state == WorkState.ready && item.id != widget.work?.id) item,
    ];
    final workId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ReassignSheet(agent: _agent, ready: ready),
    );
    if (workId == null || !mounted) return;
    await _run(() => _controller.assignWork(workId, agentId: _agent.id));
  }

  Future<void> _retry(MutationRecord record) =>
      _run(() async => (await _controller.retryMutation(record.key)) ?? record);

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final caps = _controller.capabilities;
    // By the session, as the status line above says it (Resume never shows
    // beside "Working").
    final state = teamSessionState(_agent);
    final stopped = state == AgentState.stopped || state == AgentState.crashed;
    final receipt = _receipt;
    final assign = _assignReceipt;
    // The one button hierarchy (design standard §2): Message is the likely
    // next step (secondary, full width), the rest are text buttons, two
    // shown and the others under More. Stop and Restart stay confirmed.
    VoidCallback? idle(VoidCallback action) => _busy ? null : action;
    final message = caps.controlMessage
        ? KitAction(
            key: const ValueKey('team-agent-control-message'),
            label: l10n.teamUiControlMessage,
            icon: AppIconography.chat,
            onPressed: idle(_message),
          )
        : null;
    final rest = <KitAction>[
      if (caps.controlAgent) ...[
        KitAction(
          key: const ValueKey('team-agent-control-nudge'),
          label: l10n.teamUiControlNudge,
          onPressed: idle(_nudge),
        ),
        if (stopped)
          KitAction(
            key: const ValueKey('team-agent-control-resume'),
            label: l10n.teamUiControlResume,
            onPressed: idle(_resume),
          )
        else
          KitAction(
            key: const ValueKey('team-agent-control-pause'),
            label: l10n.teamUiControlPause,
            onPressed: idle(_pause),
          ),
        if (!stopped)
          KitAction(
            key: const ValueKey('team-agent-control-stop'),
            label: l10n.teamUiControlStop,
            destructive: true,
            onPressed: idle(_stop),
          ),
        KitAction(
          key: const ValueKey('team-agent-control-restart'),
          label: l10n.teamUiControlRestart,
          destructive: true,
          onPressed: idle(_restart),
        ),
      ],
      if (caps.controlAssign)
        KitAction(
          key: const ValueKey('team-agent-control-reassign'),
          label: l10n.teamUiControlReassign,
          onPressed: idle(_reassign),
        ),
    ];
    final secondary = message ?? (rest.isEmpty ? null : rest.removeAt(0));
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.primaryNote case final note?)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              note,
              key: const ValueKey('team-agent-conversation-miss'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.mutedOf(theme),
              ),
            ),
          ),
        KitActionBlock(
          primary: widget.primary,
          secondary: secondary,
          tertiary: rest,
        ),
        if (receipt != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TeamReceiptChip(
                key: const ValueKey('team-agent-receipt'),
                record: receipt,
                onRetry: () => _retry(receipt),
              ),
            ),
          ),
        if (assign != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TeamReceiptChip(
                key: const ValueKey('team-agent-assign-receipt'),
                record: assign,
                onRetry: () => _retry(assign),
              ),
            ),
          ),
      ],
    );
  }
}

/// "Message fox": the composer field alone; Send pops with the text.
class _MessageSheet extends StatefulWidget {
  const _MessageSheet({required this.agent});

  final OrchestrationAgent agent;

  @override
  State<_MessageSheet> createState() => _MessageSheetState();
}

class _MessageSheetState extends State<_MessageSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      key: const ValueKey('team-agent-message-sheet'),
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.teamUiControlMessageTitle(widget.agent.name),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TeamComposerField(
            controller: _text,
            hint: l10n.teamUiControlMessageHint,
            sendLabel: l10n.teamUiControlMessageSend,
            onSend: _send,
            fieldKey: const ValueKey('team-agent-message-field'),
            sendKey: const ValueKey('team-agent-message-send'),
          ),
        ],
      ),
    );
  }
}

/// The ready work items on the host; a row pops with its id.
class _ReassignSheet extends StatelessWidget {
  const _ReassignSheet({required this.agent, required this.ready});

  final OrchestrationAgent agent;
  final List<WorkItem> ready;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final height = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      key: const ValueKey('team-agent-reassign-sheet'),
      constraints: BoxConstraints(maxHeight: height * .7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.teamUiControlReassignTitle(agent.name),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.teamUiControlReassignHint,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          if (ready.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Text(
                l10n.teamUiControlReassignEmpty,
                key: const ValueKey('team-agent-reassign-empty'),
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.only(
                  bottom: 8 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  for (final item in ready)
                    KitRow(
                      key: ValueKey('team-agent-reassign-${item.id}'),
                      leading: KitRow.icon(context, AppIconography.checklist),
                      title: item.title,
                      supporting: TextSpan(text: l10n.teamUiWorkTerm(item.id)),
                      onTap: () => Navigator.of(context).pop(item.id),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Technical details
// ---------------------------------------------------------------------------

/// "Context use" with the toned number, or "Not reported".
class _ContextRow extends StatelessWidget {
  const _ContextRow({super.key, required this.percent});

  final int? percent;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final percent = this.percent;
    if (percent == null) {
      return TeamIdentityRow(
        label: l10n.teamUiAgentLabelContext,
        value: l10n.teamUiAgentValueUnknown,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        children: [
          Text(
            l10n.teamUiAgentLabelContext,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.mutedOf(theme),
            ),
          ),
          TeamContextNumber(
            percent: percent,
            style: theme.textTheme.bodyMedium,
            label: '$percent%',
          ),
        ],
      ),
    );
  }
}

/// "Tokens / context / cost": the team's tokens today, this agent's
/// context percent and the team's estimated cost on one line, with a hint
/// that tokens and cost are city-wide estimates. Nothing at all when the
/// host reported neither tokens nor cost — the context number already has
/// its own row.
class _UsageRow extends StatelessWidget {
  const _UsageRow({
    super.key,
    required this.usage,
    required this.contextPercent,
  });

  final OrchestrationUsage? usage;
  final int? contextPercent;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final tokens = teamUsageTokensLabel(l10n, usage);
    final cost = teamUsageCostLabel(l10n, usage);
    if (tokens == null && cost == null) return const SizedBox.shrink();
    final percent = contextPercent;
    final value = [
      ?tokens,
      if (percent != null) l10n.teamUiAgentContextShort(percent),
      ?cost,
    ].join(teamUsageSeparator);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TeamIdentityRow(
          key: const ValueKey('team-agent-usage'),
          label: l10n.teamUiUsageRuntimeLabel,
          value: value,
        ),
        Text(
          l10n.teamUiUsageRuntimeHint,
          key: const ValueKey('team-agent-usage-hint'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppTheme.mutedOf(theme),
          ),
        ),
      ],
    );
  }
}

/// The work chip ("Sync engine · oc-abc12") and its dependency state.
class _CurrentWork extends StatelessWidget {
  const _CurrentWork({required this.work});

  final WorkItem? work;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final work = this.work;
    if (work == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          l10n.teamUiHomeAgentNoWork,
          key: const ValueKey('team-agent-no-work'),
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
      );
    }
    final dependency = work.isBlocked
        ? l10n.teamUiAgentWorkBlocked
        : work.dependsOn.isNotEmpty
        ? l10n.teamUiRunBlockedByDeps(work.dependsOn.length)
        : l10n.teamUiAgentWorkUnblocked;
    final tone = work.isBlocked ? AppStatusTone.attention : AppStatusTone.ok;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        key: const ValueKey('team-agent-work-chip'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Icon(AppIconography.checklist, size: 16, color: muted),
              Text(work.title, style: theme.textTheme.bodyMedium),
              Text(
                work.id,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  fontFamily: AppTheme.monoFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            dependency,
            key: const ValueKey('team-agent-work-chip-dependency'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: work.isBlocked ? AppTheme.statusColor(theme, tone) : muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Every scalar the provider sent about the agent, with copy buttons.
List<(String, String)> _rawFields(OrchestrationAgent agent) {
  final scalars = <(String, String)>[];
  void collect(Map<String, Object?> map, String prefix) {
    for (final entry in map.entries) {
      final value = entry.value;
      if (value is String || value is num || value is bool) {
        scalars.add(('$prefix${entry.key}', '$value'));
      } else if (value is Map && prefix.isEmpty) {
        collect({
          for (final e in value.entries) '${e.key}': e.value,
        }, '${entry.key}.');
      }
    }
  }

  collect(agent.raw, '');
  scalars.sort((a, b) => a.$1.compareTo(b.$1));
  return scalars;
}

/// Folded at the end: what the host reports about the agent in plain rows
/// (a value it does not report is left out), its current work, then every
/// raw field with a copy button.
class _TechnicalDetails extends StatelessWidget {
  const _TechnicalDetails({
    required this.agent,
    required this.work,
    required this.usage,
    required this.showUsage,
  });

  final OrchestrationAgent agent;
  final WorkItem? work;
  final OrchestrationUsage? usage;
  final bool showUsage;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    return ExpansionTile(
      key: const ValueKey('team-agent-technical'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      title: Text(l10n.teamUiTechnicalDetails),
      children: [
        TeamIdentityRow(
          label: l10n.teamUiAgentLabelRole,
          value: teamAgentRoleWord(l10n, teamAgentRole(agent)),
        ),
        if (_has(agent.provider))
          TeamIdentityRow(
            label: l10n.teamUiLabelProvider,
            value: agent.provider!,
            mono: true,
          ),
        if (_has(agent.model))
          TeamIdentityRow(
            label: l10n.teamUiAgentLabelModel,
            value: agent.model!,
            mono: true,
          ),
        if (_has(agent.harness))
          TeamIdentityRow(
            label: l10n.teamUiAgentLabelHarness,
            value: agent.harness!,
          ),
        if (agent.contextPercent != null)
          _ContextRow(
            key: const ValueKey('team-agent-context-row'),
            percent: agent.contextPercent,
          ),
        if (_has(agent.workDir))
          TeamIdentityRow(
            label: l10n.teamUiAgentLabelWorkDir,
            value: agent.workDir!,
            mono: true,
          ),
        if (_has(agent.branch))
          TeamIdentityRow(
            label: l10n.teamUiAgentLabelBranch,
            value: agent.branch!,
            mono: true,
          ),
        if (showUsage)
          _UsageRow(
            key: const ValueKey('team-agent-usage-row'),
            usage: usage,
            contextPercent: agent.contextPercent,
          ),
        _CurrentWork(work: work),
        const SizedBox(height: 8),
        _RawFields(agent: agent),
      ],
    );
  }
}

class _RawFields extends StatelessWidget {
  const _RawFields({required this.agent});

  final OrchestrationAgent agent;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TeamTechnicalValue(label: l10n.teamUiRunLabelId, value: agent.id),
        TeamTechnicalValue(
          label: l10n.teamUiAgentLabelSessionId,
          value: agent.sessionId ?? '',
        ),
        TeamTechnicalValue(
          label: l10n.teamUiAgentLabelSessionName,
          value: agent.sessionName ?? '',
        ),
        TeamTechnicalValue(
          label: l10n.teamUiRunLabelRawState,
          value: agent.rawState ?? '',
        ),
        TeamTechnicalValue(
          label: l10n.teamUiAgentLabelPool,
          value: agent.pool ?? '',
        ),
        TeamTechnicalValue(
          label: l10n.teamUiAgentLabelPack,
          value: agent.pack ?? '',
        ),
        for (final (label, value) in _rawFields(agent))
          TeamTechnicalValue(label: label, value: value),
      ],
    );
  }
}

/// The app bar's sheet: the same raw fields, reachable without scrolling.
class _AgentDetailsSheet extends StatelessWidget {
  const _AgentDetailsSheet({required this.agent});

  final OrchestrationAgent agent;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      key: const ValueKey('team-agent-details-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.teamUiTechnicalDetails, style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          TeamTermRow(l10n.teamUiTermAgent),
          const SizedBox(height: 8),
          _RawFields(agent: agent),
        ],
      ),
    );
  }
}
