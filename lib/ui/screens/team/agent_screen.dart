/// The Agent detail (02-ux-flows-and-screens §5.2): what a fleet row
/// opens. A step log ending in the one thing you can do (§5.3).
///
/// The app bar names the agent and its Gas City term ("Agent · session
/// bl-5qc"). The header carries the state word with its glyph, the
/// context use as a number (not a ring) and the session age; from
/// [teamContextRecyclePercent] it adds "Recycling soon". Then the
/// sections: **Identity** (name, role, provider, model, harness),
/// **Runtime** (state, session age, context use, working directory,
/// branch — LTR mono, then "Tokens / context / cost" when the host reports
/// `/usage`: the agent's context percent beside the team's tokens and
/// estimated cost for today, which Gas City only counts city-wide, so the
/// line says so and is absent when nothing was reported), **Current work**
/// (the work chip and its dependency
/// state), **Activity** (the step log parsed from the session transcript's
/// `[tool: …]` markers, grouped and collapsed like the chat's tool groups,
/// commands in LTR mono) and **Output** (one row: "Live output", which
/// opens [AgentOutputScreen] — the tail is one tap away, not inline).
/// **Controls** (TEAM-204, §5.2 / §5.3, capability-gated: absent, never
/// disabled): Message (a composer sheet, no attachments), Nudge (one tap),
/// Pause / Resume by state, Stop and Restart (two-step, error tone) and
/// Reassign work… (a picker of ready items); the newest control's receipt
/// chip under them. "Open session" never shows for Gas City (06-decisions
/// §A.13: no session link) and "Open worktree" is omitted because the Files
/// screen has no path filter — the working directory is in Runtime.
/// Technical details (§8) expand at the end with every raw field and a
/// copy button.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../widgets/team_agent_row.dart';
import '../../widgets/team_controls.dart';
import '../../widgets/team_technical_details.dart';
import '../../widgets/team_vocabulary.dart';
import 'agent_output_screen.dart';
import 'team_states.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Transcript blocks shown in Activity; older ones are dropped.
const _activityBlocks = 40;

/// Lines of a tool's output shown under its command.
const _outputPreviewLines = 6;

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

  DateTime get _now => (widget.now ?? DateTime.now)();

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
    if (mounted) setState(() {});
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AgentOutputScreen(
          controller: widget.controller,
          agentId: widget.agentId,
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
      final sessionId = agent?.sessionId;
      final term = agent == null
          ? null
          : sessionId != null && sessionId.isNotEmpty
          ? l10n.teamUiAgentTermSession(sessionId)
          : l10n.teamUiAgentTermNoSession;
      return Scaffold(
        key: const ValueKey('team-agent'),
        appBar: AppBar(
          toolbarHeight: _toolbarHeight(context),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Agent names are identifiers: LTR in every locale.
              Text(
                agent?.name ?? widget.agentId,
                key: const ValueKey('team-agent-title'),
                style: theme.textTheme.titleMedium,
                textDirection: TextDirection.ltr,
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
            // One icon action, then the overflow (design standard §1).
            if (agent != null)
              PopupMenuButton<String>(
                key: const ValueKey('team-agent-more'),
                tooltip: l10n.teamUiControlMoreActions,
                icon: const Icon(AppIconography.more),
                onSelected: (_) => _openDetails(agent),
                itemBuilder: (context) => [
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

  Widget _sections(BuildContext context, OrchestrationAgent agent) {
    final l10n = _copy(context);
    final controller = widget.controller;
    final snapshot = controller.snapshot;
    WorkItem? work;
    for (final item in snapshot.work) {
      if (item.id == agent.currentWorkId) {
        work = item;
        break;
      }
    }
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
    // Rows (Live output) run edge to edge like every list; the rest sits on
    // the 16 dp rails.
    Widget pad(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
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
          pad(_Header(agent: agent, now: _now)),
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
          const SizedBox(height: 16),
          _Section(
            key: const ValueKey('team-agent-identity'),
            title: l10n.teamUiAgentSectionIdentity,
            children: [
              TeamIdentityRow(
                label: l10n.teamUiAgentLabelName,
                value: agent.name,
                mono: true,
              ),
              TeamIdentityRow(
                label: l10n.teamUiAgentLabelRole,
                value: agent.pool ?? agent.pack ?? l10n.teamUiAgentValueUnknown,
                mono: agent.pool != null || agent.pack != null,
              ),
              TeamIdentityRow(
                label: l10n.teamUiLabelProvider,
                value: _or(agent.provider, l10n),
                mono: agent.provider != null,
              ),
              TeamIdentityRow(
                label: l10n.teamUiAgentLabelModel,
                value: _or(agent.model, l10n),
                mono: agent.model != null,
              ),
              TeamIdentityRow(
                label: l10n.teamUiAgentLabelHarness,
                value: _or(agent.harness, l10n),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            key: const ValueKey('team-agent-runtime'),
            title: l10n.teamUiAgentSectionRuntime,
            children: [
              TeamIdentityRow(
                label: l10n.teamUiRunLabelState,
                value: teamAgentStateWord(l10n, agent.state),
              ),
              TeamIdentityRow(
                label: l10n.teamUiAgentLabelSessionAge,
                value: agent.sessionStartedAt == null
                    ? l10n.teamUiAgentValueUnknown
                    : teamElapsedLabel(l10n, _age(agent)),
              ),
              _ContextRow(
                key: const ValueKey('team-agent-context-row'),
                percent: agent.contextPercent,
              ),
              TeamIdentityRow(
                label: l10n.teamUiAgentLabelWorkDir,
                value: _or(agent.workDir, l10n),
                mono: agent.workDir != null,
              ),
              TeamIdentityRow(
                label: l10n.teamUiAgentLabelBranch,
                value: _or(agent.branch, l10n),
                mono: agent.branch != null,
              ),
              if (controller.capabilities.usage)
                _UsageRow(
                  key: const ValueKey('team-agent-usage-row'),
                  usage: snapshot.usage,
                  contextPercent: agent.contextPercent,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _Section(
            key: const ValueKey('team-agent-work'),
            title: l10n.teamUiAgentSectionCurrentWork,
            children: [_CurrentWork(work: work)],
          ),
          const SizedBox(height: 16),
          _Section(
            key: const ValueKey('team-agent-activity'),
            title: l10n.teamUiAgentSectionActivity,
            children: [_Activity(tail: _tail)],
          ),
          const SizedBox(height: 16),
          _Section(
            key: const ValueKey('team-agent-output'),
            title: l10n.teamUiAgentSectionOutput,
            flush: true,
            children: [_OutputRow(tail: _tail, onTap: _openOutput)],
          ),
          if (controller.capabilities.controlMessage ||
              controller.capabilities.controlAgent ||
              controller.capabilities.controlAssign) ...[
            const SizedBox(height: 16),
            _Section(
              key: const ValueKey('team-agent-controls'),
              title: l10n.teamUiControlSectionTitle,
              children: [
                _Controls(controller: controller, agent: agent, work: work),
              ],
            ),
          ],
          const SizedBox(height: 8),
          pad(_TechnicalDetails(agent: agent)),
        ],
      ),
    );
    // Stale numbers dim; they stay readable (never colour-only).
    return stale ? Opacity(opacity: .6, child: body) : body;
  }

  Duration _age(OrchestrationAgent agent) {
    final started = agent.sessionStartedAt;
    if (started == null) return Duration.zero;
    final age = _now.difference(started);
    return age.isNegative ? Duration.zero : age;
  }
}

String _or(String? value, AppLocalizations l10n) =>
    value == null || value.isEmpty ? l10n.teamUiAgentValueUnknown : value;

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// Glyph + state word, the context number and the session age on one
/// wrapping line; "Recycling soon" under it from the recycle threshold.
class _Header extends StatelessWidget {
  const _Header({required this.agent, required this.now});

  final OrchestrationAgent agent;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final (icon, tone) = teamAgentGlyph(agent.state);
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
              teamAgentStateWord(l10n, agent.state),
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
    required this.controller,
    required this.agent,
    required this.work,
  });

  final OrchestrationController controller;
  final OrchestrationAgent agent;
  final WorkItem? work;

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
    final state = _agent.state;
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: KitActionBlock(secondary: secondary, tertiary: rest),
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
// Sections
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.title,
    required this.children,
    this.flush = false,
  });

  final String title;
  final List<Widget> children;

  /// The children are rows that run edge to edge ([KitRow]); only the
  /// label sits on the rails.
  final bool flush;

  @override
  Widget build(BuildContext context) {
    const rails = EdgeInsets.symmetric(horizontal: 16);
    final section = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          title,
          padding: flush
              ? const EdgeInsets.fromLTRB(16, 0, 16, 4)
              : const EdgeInsets.only(bottom: 4),
        ),
        ...children,
      ],
    );
    return flush ? section : Padding(padding: rails, child: section);
  }
}

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
            key: const ValueKey('team-agent-work-dependency'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: work.isBlocked ? AppTheme.statusColor(theme, tone) : muted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity: the step log
// ---------------------------------------------------------------------------

class _Activity extends StatelessWidget {
  const _Activity({required this.tail});

  final AgentOutputTail tail;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final blocks = parseAgentTranscript(tail.text);
    if (blocks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          key: const ValueKey('team-agent-activity-empty'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.teamUiAgentActivityEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            Text(
              l10n.teamUiAgentActivityEmptyHint,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      );
    }
    final shown = blocks.length > _activityBlocks
        ? blocks.sublist(blocks.length - _activityBlocks)
        : blocks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++)
          switch (shown[i]) {
            AgentProse(:final text) => Padding(
              key: ValueKey('team-agent-prose-$i'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            AgentStepGroup(:final steps) => _StepGroup(
              key: ValueKey('team-agent-steps-$i'),
              steps: steps,
            ),
          },
      ],
    );
  }
}

/// One human sentence for a group: "ran 3 commands · read 1 file".
String _stepSummary(AppLocalizations l10n, AgentStepGroup group) {
  final segments = <String>[
    if (group.count(AgentStepKind.read) case final n when n > 0)
      l10n.teamUiAgentStepsReads(n),
    if (group.count(AgentStepKind.search) case final n when n > 0)
      l10n.teamUiAgentStepsSearches(n),
    if (group.count(AgentStepKind.edit) case final n when n > 0)
      l10n.teamUiAgentStepsEdits(n),
    if (group.count(AgentStepKind.command) case final n when n > 0)
      l10n.teamUiAgentStepsCommands(n),
    if (group.count(AgentStepKind.test) case final n when n > 0)
      l10n.teamUiAgentStepsTests(n),
    if (group.count(AgentStepKind.other) case final n when n > 0)
      l10n.teamUiAgentStepsOther(n),
  ];
  final sentence = segments.join(' · ');
  if (sentence.isEmpty) return sentence;
  return sentence[0].toUpperCase() + sentence.substring(1);
}

IconData _stepIcon(AgentStepKind kind) => switch (kind) {
  AgentStepKind.command => AppIconography.terminal,
  AgentStepKind.test => AppIconography.checks,
  AgentStepKind.read => AppIconography.fileText,
  AgentStepKind.edit => AppIconography.edit,
  AgentStepKind.search => AppIconography.search,
  AgentStepKind.other => AppIconography.tools,
};

/// Consecutive tool calls behind one header, collapsed by default like the
/// chat's tool groups; tapping the header opens the steps.
class _StepGroup extends StatefulWidget {
  const _StepGroup({super.key, required this.steps});

  final List<AgentStep> steps;

  @override
  State<_StepGroup> createState() => _StepGroupState();
}

class _StepGroupState extends State<_StepGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final group = AgentStepGroup(widget.steps);
    final summary = _stepSummary(l10n, group);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .28),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.hairline(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label: l10n.teamUiAgentStepsSemantics(summary, widget.steps.length),
            child: InkWell(
              key: const ValueKey('team-agent-step-group-header'),
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 8, 8),
                  child: Row(
                    children: [
                      Icon(AppIconography.tools, size: 16, color: muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.teamUiAgentStepsTitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              summary,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _expanded
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
          ),
          if (_expanded)
            Padding(
              key: const ValueKey('team-agent-step-group-body'),
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final step in widget.steps) _StepRow(step: step),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A command in LTR mono with the first lines of its output under it.
class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final AgentStep step;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final muted = AppTheme.mutedOf(theme);
    final lines = step.output.isEmpty
        ? const <String>[]
        : step.output.split('\n');
    final preview = lines.take(_outputPreviewLines).join('\n');
    final more = lines.length - _outputPreviewLines;
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: AppTheme.monoFamily,
      fontSize: AppTheme.codeFontSize,
      height: AppTheme.codeLineHeight,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(_stepIcon(step.kind), size: 14, color: muted),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Commands, paths and output stay LTR in every locale.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.command,
                        style: mono,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (preview.isNotEmpty)
                        Text(
                          preview,
                          style: mono?.copyWith(color: muted),
                          maxLines: _outputPreviewLines,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (more > 0)
                  Text(
                    l10n.teamUiAgentStepMoreLines(more),
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
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
// Output row and technical details
// ---------------------------------------------------------------------------

/// "Live output" with its status word; opens the output page.
class _OutputRow extends StatelessWidget {
  const _OutputRow({required this.tail, required this.onTap});

  final AgentOutputTail tail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final status = tail.ended
        ? l10n.teamUiAgentOutputEnded
        : !tail.available
        ? l10n.teamUiAgentOutputUnavailable
        : tail.received
        ? l10n.teamUiAgentOutputLive
        : l10n.teamUiAgentOutputConnecting;
    return KitRow(
      key: const ValueKey('team-agent-open-output'),
      leading: KitRow.icon(context, AppIconography.terminal),
      title: l10n.teamUiAgentOutputTitle,
      supporting: TextSpan(text: status),
      trailing: Icon(
        AppIconography.chevronRight,
        size: 18,
        color: AppTheme.mutedOf(Theme.of(context)),
      ),
      onTap: onTap,
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

class _TechnicalDetails extends StatelessWidget {
  const _TechnicalDetails({required this.agent});

  final OrchestrationAgent agent;

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    return ExpansionTile(
      key: const ValueKey('team-agent-technical'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(l10n.teamUiTechnicalDetails),
      children: [_RawFields(agent: agent)],
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
