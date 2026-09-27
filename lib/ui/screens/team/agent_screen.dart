/// The Agent detail (02-ux-flows-and-screens §5.2): what a fleet row
/// opens. A short status page whose primary is the worker's own
/// conversation; the agent's work itself is shown in one place only, the
/// chat (docs/design/team-conversation-2026-09-26.md).
///
/// Built from kit parts only (screen-team-1, STANDARDS §4), top to bottom
/// in one list ordered by urgency:
///
/// 1. The top bar ([KitTopBar]) names the agent by role and name ("Worker ·
///    fox") with what it works on as the subtitle ("On “Sync engine”").
///    Refresh is its one icon; Live output joins the overflow when it is
///    not the primary.
/// 2. A question waiting on the person, as the pointing [KitNeedsYou.row]
///    that opens the Gate sheet, when there is one.
/// 3. What went wrong, when something did: the worker didn't start, it
///    stopped or crashed (with "Start fox again"), its context is nearly
///    full ("Recycling soon").
/// 4. The status panel: the state from the agent's **session** with its
///    mark and word, context use and session age; the newest step and when
///    it was last active; the model in plain words; the current task and
///    what blocks it; the team's usage today.
/// 5. The newest control receipt, and why the primary is Live output when
///    no conversation can be matched on the connected server.
/// 6. Technical details, one [KitDetailsFold], last and collapsed.
///
/// The pinned actions ([KitActionBlock]): **Open conversation** (or **Live
/// output**) is the primary, **Message fox** the secondary. The fallbacks
/// (the team restarts, wakes and routes work itself) sit in the top bar's
/// overflow: Pause fox, Nudge fox, Restart fox and Stop fox (last, in the
/// destructive tone). Pause is undone with [showKitUndo]; Stop and Restart
/// are confirmed with [showKitConfirm] (Stop in the stop tone, Restart
/// neutral). The controls exist only when the host takes them (TEAM-204);
/// when it takes none, the page says so and offers the host guide instead
/// of hiding them.
///
/// Removed here (owner verdicts 2026-09-26): the Technical details sheet
/// (merged into the fold) and Reassign work (the dispatcher routes ready
/// work; the board's "Start now" is the manual fallback).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../domain/orchestration_gateway.dart';
import '../../../l10n/app_localizations.dart';
import '../../../state/orchestration.dart';
import '../../../state/team_conversation.dart' show teamSessionState;
import '../../app_theme.dart';
import '../../kit/kit.dart';
import '../../widgets/team_host_form.dart' show showTeamHostGuideSheet;
import '../../widgets/team_now.dart';
import '../../widgets/team_vocabulary.dart';
import '../team_conversation/team_conversation.dart';
import 'agent_output_screen.dart';
import 'gate_sheet.dart' show showGateSheet;
import 'team_states.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// Where the message typed to [agentId] is kept across dismissal
/// (P7.1, DATA-1): `oc.draft.team-agent-message.<agentId>.<profileId>`.
String teamAgentMessageDraftTarget(String agentId) =>
    'team-agent-message.$agentId';

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
  bool _busy = false;

  /// Where "Open conversation" leads, looked up once per agent session
  /// (its folder and start); null while looking.
  TeamAgentConversationLookup? _lookup;
  String? _lookupFor;

  DateTime get _now => (widget.now ?? DateTime.now)();
  OrchestrationController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _tail = _controller.watchAgentOutput(widget.agentId)..addListener(_changed);
    _controller.addListener(_rebind);
  }

  @override
  void dispose() {
    _controller.removeListener(_rebind);
    _tail.removeListener(_changed);
    _controller.unwatchAgentOutput(widget.agentId);
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
    _tail.removeListener(_changed);
    _controller.unwatchAgentOutput(widget.agentId);
    _tail = _controller.watchAgentOutput(widget.agentId)..addListener(_changed);
  }

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

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      if (_controller.phase == OrchestrationPhase.failed) {
        await _controller.retry();
      } else {
        await _controller.refresh();
      }
    } finally {
      // Look for its conversation again too: a worker still starting has
      // one by now.
      _lookupFor = null;
      if (mounted) setState(() => _refreshing = false);
    }
  }

  OrchestrationAgent? get _agent {
    for (final agent in _controller.snapshot.agents) {
      if (agent.id == widget.agentId || agent.sessionId == widget.agentId) {
        return agent;
      }
    }
    return null;
  }

  WorkItem? _workOf(OrchestrationAgent agent) {
    for (final item in _controller.snapshot.work) {
      if (item.id == agent.currentWorkId) return item;
    }
    return null;
  }

  OrchestrationGate? _gateOf(OrchestrationAgent agent, WorkItem? work) {
    for (final g in _controller.snapshot.gates) {
      if (g.kind == GateKind.reviewReady) continue;
      if (g.agentId == agent.id ||
          (agent.sessionId != null && g.agentId == agent.sessionId) ||
          (work != null && g.workId == work.id)) {
        return g;
      }
    }
    return null;
  }

  /// A worker that is not running while a task waits for one: it should
  /// have started (and the home's Now line says the same).
  bool _didNotStart(OrchestrationAgent agent) {
    if (teamAgentIsLive(agent)) return false;
    if (teamAgentRole(agent) != TeamAgentRole.worker) return false;
    final snapshot = _controller.snapshot;
    return teamVisibleRuns(snapshot.runs).any(
      (run) => teamRunWaitsForWorker(
        run,
        snapshot.work,
        cycleOf: _controller.cycleFor,
      ),
    );
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

  /// The newest control record for this agent, by any of its ids.
  MutationRecord? _receipt(OrchestrationAgent agent) {
    MutationRecord? best;
    for (final id in {agent.id, ?agent.sessionId}) {
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

  // -------------------------------------------------------------------------
  // Actions (TEAM-204)
  // -------------------------------------------------------------------------

  Future<void> _run(Future<MutationRecord> Function() send) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await send();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _control(String agentId, AgentControlAction action) =>
      _run(() => _controller.controlAgent(agentId, action));

  /// Pause, then "Paused fox · Undo" (DATA-11: undo, not a confirmation).
  Future<void> _pause(OrchestrationAgent agent) async {
    final l10n = _copy(context);
    await _control(agent.id, AgentControlAction.pause);
    if (!mounted) return;
    showKitUndo(
      context,
      message: l10n.teamAgentScreenPaused(agent.name),
      onUndo: () => _control(agent.id, AgentControlAction.resume),
      key: const ValueKey('team-agent-pause-undo'),
      undoKey: const ValueKey('team-agent-pause-undo-action'),
    );
  }

  Future<void> _stop(OrchestrationAgent agent, WorkItem? work) async {
    final l10n = _copy(context);
    final ok = await showKitConfirm(
      context,
      title: l10n.teamUiControlStopConfirmTitle(teamAgentTitle(l10n, agent)),
      body: work == null
          ? l10n.teamUiControlStopConfirmBody
          : l10n.teamAgentScreenStopBody(agent.name, work.title),
      confirmLabel: l10n.teamAgentScreenStop(agent.name),
      kind: KitConfirmKind.stop,
      sheetKey: const ValueKey('team-agent-stop-confirm'),
      confirmKey: const ValueKey('team-agent-stop-confirm-action'),
    );
    if (!ok || !mounted) return;
    await _control(agent.id, AgentControlAction.stop);
  }

  Future<void> _restart(OrchestrationAgent agent) async {
    final l10n = _copy(context);
    final ok = await showKitConfirm(
      context,
      title: l10n.teamUiControlRestartConfirmTitle(teamAgentTitle(l10n, agent)),
      body: l10n.teamUiControlRestartConfirmBody,
      confirmLabel: l10n.teamAgentScreenRestart(agent.name),
      icon: AppIconography.restart,
      sheetKey: const ValueKey('team-agent-restart-confirm'),
      confirmKey: const ValueKey('team-agent-restart-confirm-action'),
    );
    if (!ok || !mounted) return;
    await _control(agent.id, AgentControlAction.restart);
  }

  // revamp: merge-into:team-conversation (slice-P3.6) for
  // team-agent-message-sheet: messaging a worker moves to the conversation
  // composer; until then this sheet keeps the draft (P7.1).
  Future<void> _message(OrchestrationAgent agent) async {
    final l10n = _copy(context);
    final text = TextEditingController();
    final send = ValueNotifier<KitAction?>(null);
    late final KitDraft draft;
    void update() {
      final value = text.text.trim();
      send.value = KitAction(
        key: const ValueKey('team-agent-message-send'),
        label: l10n.teamUiControlMessageSend,
        icon: AppIconography.send,
        onPressed: value.isEmpty
            ? null
            : () => Navigator.of(context).pop(value),
        disabledReason: value.isEmpty ? l10n.teamAgentScreenMessageFirst : null,
      );
    }

    draft = KitDraft(
      target: teamAgentMessageDraftTarget(agent.id),
      profileId: _controller.profileId,
      controller: text,
    );
    text.addListener(update);
    update();
    try {
      final result = await showKitSheet<String>(
        context,
        title: l10n.teamUiControlMessageTitle(agent.name),
        icon: AppIconography.chat,
        sheetKey: const ValueKey('team-agent-message-sheet'),
        draft: draft,
        primaryListenable: send,
        body: (_) => KitField(
          label: l10n.teamAgentScreenMessageLabel,
          hint: l10n.teamUiControlMessageHint,
          kind: KitFieldKind.multiline,
          draft: draft,
          controller: text,
          autofocus: true,
          fieldKey: const ValueKey('team-agent-message-field'),
        ),
      );
      if (result == null || result.isEmpty || !mounted) return;
      await _run(() => _controller.messageAgent(agent.id, result));
      await draft.clear();
    } finally {
      text.removeListener(update);
      send.dispose();
      // The field may still read the controller while the sheet leaves.
      WidgetsBinding.instance.addPostFrameCallback((_) => text.dispose());
    }
  }

  void _openConversation(OrchestrationAgent agent) => unawaited(
    openTeamAgentConversation(
      context,
      agent,
      team: _controller,
      lookup: _lookup,
    ),
  );

  void _openOutput() {
    final miss = _lookup?.miss;
    unawaited(
      pushKitPage<void>(
        context,
        (context) => AgentOutputScreen(
          controller: _controller,
          agentId: widget.agentId,
          note: miss == null
              ? null
              : teamAgentConversationMissNote(context, miss),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final l10n = _copy(context);
      final agent = _agent;
      final work = agent == null ? null : _workOf(agent);
      final onRetry = _refreshing ? null : _refresh;
      final state = teamScreenState(
        context,
        controller: _controller,
        keyPrefix: 'team-agent',
        onRetry: onRetry,
      );
      if (agent != null && state == null) _lookUp(agent);
      final miss = _lookup?.miss;
      final ready = state == null && agent != null;
      return KitScreen(
        key: const ValueKey('team-agent'),
        width: KitScreenWidth.reading,
        topBar: KitTopBar(
          title: agent == null ? widget.agentId : teamAgentTitle(l10n, agent),
          subtitle: work == null ? null : l10n.teamAgentWorksOn(work.title),
          titleKey: const ValueKey('team-agent-title'),
          actions: [
            KitAction(
              key: const ValueKey('team-agent-refresh'),
              label: l10n.teamUiRefresh,
              icon: AppIconography.sync,
              onPressed: onRetry,
            ),
          ],
          menu: [
            if (ready && miss == null)
              KitMenuItem(
                key: const ValueKey('team-agent-menu-output'),
                label: l10n.teamUiAgentOutputTitle,
                icon: AppIconography.terminal,
                onSelected: _openOutput,
              ),
            if (ready) ..._controls(context, agent, work),
          ],
          menuKey: const ValueKey('team-agent-more'),
        ),
        header: [
          if (ready)
            ?teamStatusLine(
              context,
              controller: _controller,
              keyPrefix: 'team-agent',
              onRetry: onRetry,
            ),
        ],
        loading: teamScreenLoading(_controller) || _refreshing,
        loadingLabel: l10n.teamUiCardLoading,
        body:
            state ??
            (agent == null
                ? KitStateView(
                    key: const ValueKey('team-agent-missing'),
                    icon: AppIconography.cloudOff,
                    title: l10n.teamUiAgentMissingTitle,
                    body: l10n.teamUiAgentMissingHint,
                    primary: KitAction(
                      label: l10n.teamUiRunBack,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  )
                : _list(context, agent, work)),
        bottom: ready ? _actions(context, agent) : null,
      );
    },
  );

  /// The pinned block: the conversation (or Live output), then Message.
  /// Absent controls are absent; the list explains why when the host takes
  /// none.
  KitActionBlock _actions(BuildContext context, OrchestrationAgent agent) {
    final l10n = _copy(context);
    final caps = _controller.capabilities;
    VoidCallback? idle(VoidCallback action) => _busy ? null : action;
    final primary = _lookup?.miss == null
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
    return KitActionBlock(
      primary: primary,
      secondary: caps.controlMessage
          ? KitAction(
              key: const ValueKey('team-agent-control-message'),
              label: l10n.teamUiControlMessageTitle(agent.name),
              icon: AppIconography.chat,
              onPressed: idle(() => unawaited(_message(agent))),
            )
          : null,
    );
  }

  /// The fallbacks, in the top bar's overflow (the team restarts, wakes and
  /// routes work itself): Pause fox, Nudge fox, Restart fox, and Stop fox
  /// last in the destructive tone. Only when the host takes them.
  List<KitMenuItem> _controls(
    BuildContext context,
    OrchestrationAgent agent,
    WorkItem? work,
  ) {
    final l10n = _copy(context);
    if (!_controller.capabilities.controlAgent) return const [];
    final state = teamSessionState(agent);
    final stopped = state == AgentState.stopped || state == AgentState.crashed;
    final name = agent.name;
    const group = 'controls';
    return [
      if (!stopped)
        KitMenuItem(
          key: const ValueKey('team-agent-control-pause'),
          label: l10n.teamAgentScreenPause(name),
          icon: AppIconography.pause,
          group: group,
          enabled: !_busy,
          disabledReason: _busy ? l10n.teamUiReceiptSent : null,
          onSelected: () => unawaited(_pause(agent)),
        ),
      KitMenuItem(
        key: const ValueKey('team-agent-control-nudge'),
        label: l10n.teamAgentScreenNudge(name),
        icon: AppIconography.lightning,
        group: group,
        enabled: !_busy,
        disabledReason: _busy ? l10n.teamUiReceiptSent : null,
        onSelected: () =>
            unawaited(_control(agent.id, AgentControlAction.nudge)),
      ),
      KitMenuItem(
        key: const ValueKey('team-agent-control-restart'),
        label: l10n.teamAgentScreenRestart(name),
        icon: AppIconography.restart,
        group: group,
        enabled: !_busy,
        disabledReason: _busy ? l10n.teamUiReceiptSent : null,
        onSelected: () => unawaited(_restart(agent)),
      ),
      if (!stopped)
        KitMenuItem(
          key: const ValueKey('team-agent-control-stop'),
          label: l10n.teamAgentScreenStop(name),
          icon: AppIconography.stopCircle,
          destructive: true,
          enabled: !_busy,
          disabledReason: _busy ? l10n.teamUiReceiptSent : null,
          onSelected: () => unawaited(_stop(agent, work)),
        ),
    ];
  }

  Widget _list(BuildContext context, OrchestrationAgent agent, WorkItem? work) {
    final l10n = _copy(context);
    final tokens = KitTokens.of(context);
    final caps = _controller.capabilities;
    final snapshot = _controller.snapshot;
    final state = teamSessionState(agent);
    final gate = _gateOf(agent, work);
    final receipt = _receipt(agent);
    final miss = _lookup?.miss;
    final percent = agent.contextPercent;
    final inset = EdgeInsetsDirectional.symmetric(
      horizontal: tokens.gutter,
      vertical: tokens.space2,
    );
    Widget pad(Widget child) => Padding(padding: inset, child: child);

    return KitRefresh(
      key: const ValueKey('team-agent-pull'),
      onRefresh: _refresh,
      child: ListView(
        key: const ValueKey('team-agent-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.only(
          top: tokens.space2,
          bottom: KitScreen.endPadding(context),
        ),
        children: [
          // 1. What needs the person.
          if (gate != null)
            KitRowGroup(
              margin: _groupMargin(context),
              children: [
                KitNeedsYou.row(
                  key: const ValueKey('team-agent-gate'),
                  title: gate.title,
                  reason: KitNeedsYouReason.decision,
                  ifIgnored: l10n.teamAgentScreenGateIfIgnored(agent.name),
                  onOpen: () => unawaited(
                    showGateSheet(
                      context,
                      _controller,
                      gate.id,
                      now: widget.now,
                    ),
                  ),
                ),
              ],
            ),
          // 2. What went wrong.
          if (_didNotStart(agent))
            pad(
              KitNotice(
                key: const ValueKey('team-agent-did-not-start'),
                icon: AppIconography.warning,
                title: l10n.teamAgentDidNotStartTitle,
                message: l10n.teamAgentDidNotStartBody,
                actions: [
                  teamUnstickAction(
                    context,
                    _controller,
                    keyPrefix: 'team-agent-did-not-start',
                    wake: [agent],
                    wakeLabel: l10n.teamAgentStartIt,
                  ),
                ],
              ),
            )
          else if (state == AgentState.stopped || state == AgentState.crashed)
            pad(
              _stoppedNotice(
                context,
                agent,
                crashed: state == AgentState.crashed,
              ),
            ),
          if (percent != null && percent >= teamContextRecyclePercent)
            pad(
              KitNotice(
                key: const ValueKey('team-agent-recycling'),
                icon: AppIconography.restart,
                title: l10n.teamUiAgentRecyclingSoon,
                message: l10n.teamAgentScreenRecyclingBody,
              ),
            ),
          // 3. Where it stands.
          _status(context, agent, work),
          if (caps.usage) ?_usage(context, agent, snapshot.usage),
          // 4. The newest control and why the primary is Live output.
          if (receipt != null)
            pad(
              KitReceipt(
                key: const ValueKey('team-agent-receipt'),
                state: _receiptState(receipt.status),
                reason: receipt.receipt?.message,
                since: receipt.createdAt,
                onRetry: receipt.canRetry
                    ? () => unawaited(
                        _run(
                          () async =>
                              (await _controller.retryMutation(receipt.key)) ??
                              receipt,
                        ),
                      )
                    : null,
                retryKey: const ValueKey('team-agent-receipt-retry'),
              ),
            ),
          if (!caps.controlAgent && !caps.controlMessage)
            pad(
              KitNotice(
                key: const ValueKey('team-agent-controls-elsewhere'),
                icon: AppIconography.info,
                message: l10n.teamAgentScreenControlsElsewhere(agent.name),
                actions: [
                  KitAction(
                    key: const ValueKey('team-agent-controls-how'),
                    label: l10n.teamUiHow,
                    onPressed: () => unawaited(showTeamHostGuideSheet(context)),
                  ),
                ],
              ),
            ),
          if (miss != null)
            pad(
              KitText(
                teamAgentConversationMissNote(context, miss),
                key: const ValueKey('team-agent-conversation-miss'),
                role: KitTextRole.secondary,
                tone: KitTextTone.secondary,
              ),
            ),
          // 5. The technical truth, last.
          pad(
            KitDetailsFold(
              label: l10n.teamUiTechnicalDetails,
              foldKey: const ValueKey('team-agent-technical'),
              values: _technical(l10n, agent, work),
            ),
          ),
        ],
      ),
    );
  }

  /// Stopped: "Start fox again" (resume). Crashed: restart it.
  Widget _stoppedNotice(
    BuildContext context,
    OrchestrationAgent agent, {
    required bool crashed,
  }) {
    final l10n = _copy(context);
    final caps = _controller.capabilities;
    return KitNotice(
      key: const ValueKey('team-agent-stopped'),
      tone: crashed ? AppStatusTone.failure : AppStatusTone.neutral,
      icon: crashed ? AppIconography.error : AppIconography.stopCircle,
      title: crashed
          ? l10n.teamAgentScreenCrashedTitle(agent.name)
          : l10n.teamAgentScreenStoppedTitle(agent.name),
      message: crashed
          ? l10n.teamAgentScreenCrashedBody
          : l10n.teamAgentScreenStoppedBody,
      actions: [
        if (caps.controlAgent)
          KitAction(
            key: const ValueKey('team-agent-control-resume'),
            label: l10n.teamAgentScreenResume(agent.name),
            onPressed: _busy
                ? null
                : () => unawaited(
                    _control(
                      agent.id,
                      crashed
                          ? AgentControlAction.restart
                          : AgentControlAction.resume,
                    ),
                  ),
          ),
      ],
    );
  }

  /// The status panel: state with context and age, the newest step, the
  /// model in plain words, the current task.
  Widget _status(
    BuildContext context,
    OrchestrationAgent agent,
    WorkItem? work,
  ) {
    final l10n = _copy(context);
    final now = _now;
    final state = teamSessionState(agent);
    final percent = agent.contextPercent;
    final started = agent.sessionStartedAt;
    String elapsed(DateTime at) => teamElapsedLabel(
      l10n,
      now.isBefore(at) ? Duration.zero : now.difference(at),
    );
    final facts = [
      if (percent != null) l10n.teamUiAgentContextSemantics(percent),
      if (started != null) l10n.teamUiAgentSessionAge(elapsed(started)),
    ].join(teamUsageSeparator);
    final lastActive = agent.lastActivity;
    final step = _lastStep();
    final model = agent.model?.trim();
    return KitRowGroup(
      margin: _groupMargin(context),
      key: const ValueKey('team-agent-header'),
      children: [
        KitRow(
          key: const ValueKey('team-agent-state-row'),
          leading: KitStatusMark(
            state: _mark(state),
            paused: state == AgentState.stopped,
          ),
          title: teamAgentStateWord(l10n, state),
          titleKey: const ValueKey('team-agent-state'),
          supporting: facts.isEmpty ? null : TextSpan(text: facts),
          supportingKey: const ValueKey('team-agent-age'),
          supportingMaxLines: 2,
        ),
        if (step != null || lastActive != null)
          KitRow(
            key: const ValueKey('team-agent-activity-line'),
            leading: KitRow.icon(context, AppIconography.terminal),
            title: step == null
                ? l10n.teamAgentLastActive(elapsed(lastActive!))
                : l10n.teamAgentLastStep(step),
            supporting: step != null && lastActive != null
                ? TextSpan(text: l10n.teamAgentLastActive(elapsed(lastActive)))
                : null,
          ),
        if (model != null && model.isNotEmpty)
          KitRow(
            key: const ValueKey('team-agent-model'),
            leading: KitRow.icon(context, AppIconography.model),
            title: l10n.teamUiAgentLabelModel,
            supporting: TextSpan(text: _modelWords(l10n, agent, model)),
          ),
        if (work == null)
          KitRow(
            key: const ValueKey('team-agent-no-work'),
            leading: KitRow.icon(context, AppIconography.checklist),
            title: l10n.teamUiHomeAgentNoWork,
          )
        else
          KitRow(
            key: const ValueKey('team-agent-work-chip'),
            leading: KitRow.icon(context, AppIconography.checklist),
            title: work.title,
            titleMaxLines: 2,
            supporting: TextSpan(
              text: work.isBlocked
                  ? l10n.teamUiAgentWorkBlocked
                  : work.dependsOn.isNotEmpty
                  ? l10n.teamUiRunBlockedByDeps(work.dependsOn.length)
                  : l10n.teamUiAgentWorkUnblocked,
            ),
            supportingKey: const ValueKey('team-agent-work-chip-dependency'),
          ),
      ],
    );
  }

  /// "Tokens / context / cost": the team's tokens today, this agent's
  /// context and the team's estimated cost, with the hint that tokens and
  /// cost are team-wide estimates. Null when the host reported neither.
  Widget? _usage(
    BuildContext context,
    OrchestrationAgent agent,
    OrchestrationUsage? usage,
  ) {
    final l10n = _copy(context);
    final tokens = teamUsageTokensLabel(l10n, usage);
    final cost = teamUsageCostLabel(l10n, usage);
    if (tokens == null && cost == null) return null;
    final percent = agent.contextPercent;
    final value = [
      ?tokens,
      if (percent != null) l10n.teamUiAgentContextShort(percent),
      ?cost,
    ].join(teamUsageSeparator);
    return KitRowGroup(
      margin: _groupMargin(context),
      key: const ValueKey('team-agent-usage-row'),
      label: l10n.teamUiUsageRuntimeLabel,
      children: [
        KitRow(
          key: const ValueKey('team-agent-usage'),
          leading: KitRow.icon(context, AppIconography.usage),
          title: value,
          titleKey: const ValueKey('team-agent-usage-value'),
          supporting: TextSpan(text: l10n.teamUiUsageRuntimeHint),
          supportingKey: const ValueKey('team-agent-usage-hint'),
          supportingMaxLines: 3,
        ),
      ],
    );
  }

  /// A panel's place in the list: the gutter at the sides, a small step
  /// between panels.
  static EdgeInsetsDirectional _groupMargin(BuildContext context) {
    final tokens = KitTokens.of(context);
    return EdgeInsetsDirectional.fromSTEB(
      tokens.gutter,
      tokens.space2,
      tokens.gutter,
      tokens.space2,
    );
  }

  /// "gpt-x from openai": the model's own name, then who serves it.
  static String _modelWords(
    AppLocalizations l10n,
    OrchestrationAgent agent,
    String model,
  ) {
    final slash = model.indexOf('/');
    final name = slash < 0 ? model : model.substring(slash + 1);
    final provider = slash > 0 ? model.substring(0, slash) : agent.provider;
    if (provider == null || provider.trim().isEmpty || name.isEmpty) {
      return model;
    }
    return l10n.teamAgentScreenModelFrom(name, provider.trim());
  }

  static KitMarkState _mark(AgentState state) => switch (state) {
    AgentState.working => KitMarkState.working,
    AgentState.crashed => KitMarkState.failed,
    AgentState.idle ||
    AgentState.waiting ||
    AgentState.blocked ||
    AgentState.stopped ||
    AgentState.unknown => KitMarkState.waiting,
  };

  /// Every value the host reports about the agent, once each, mono and
  /// copyable (KIT-32, KIT-33): what it runs on, where it works, then the
  /// raw scalars.
  static List<KitTechnicalValue> _technical(
    AppLocalizations l10n,
    OrchestrationAgent agent,
    WorkItem? work,
  ) {
    bool has(String? value) => value != null && value.trim().isNotEmpty;
    final values = <KitTechnicalValue>[
      KitTechnicalValue(l10n.teamAgentScreenLabelId, agent.id),
      if (has(agent.sessionId))
        KitTechnicalValue(l10n.teamUiAgentLabelSessionId, agent.sessionId!),
      if (has(agent.sessionName))
        KitTechnicalValue(l10n.teamUiAgentLabelSessionName, agent.sessionName!),
      if (has(agent.provider))
        KitTechnicalValue(l10n.teamUiLabelProvider, agent.provider!),
      if (has(agent.model))
        KitTechnicalValue(l10n.teamUiAgentLabelModel, agent.model!),
      if (has(agent.harness))
        KitTechnicalValue(l10n.teamUiAgentLabelHarness, agent.harness!),
      if (has(agent.workDir))
        KitTechnicalValue(l10n.teamUiAgentLabelWorkDir, agent.workDir!),
      if (has(agent.branch))
        KitTechnicalValue(l10n.teamUiAgentLabelBranch, agent.branch!),
      if (work != null) KitTechnicalValue(l10n.teamUiGateLabelWorkId, work.id),
      if (has(agent.rawState))
        KitTechnicalValue(l10n.teamUiRunLabelRawState, agent.rawState!),
      if (has(agent.pool))
        KitTechnicalValue(l10n.teamUiAgentLabelPool, agent.pool!),
      if (has(agent.pack))
        KitTechnicalValue(l10n.teamUiAgentLabelPack, agent.pack!),
    ];
    final scalars = <(String, String)>[];
    void collect(Map<String, Object?> map, String prefix) {
      for (final entry in map.entries) {
        final value = entry.value;
        if (value is String || value is num || value is bool) {
          final text = '$value';
          if (text.trim().isEmpty || KitRedact.containsSecret(text)) continue;
          scalars.add(('$prefix${entry.key}', text));
        } else if (value is Map && prefix.isEmpty) {
          collect({
            for (final e in value.entries) '${e.key}': e.value,
          }, '${entry.key}.');
        }
      }
    }

    collect(agent.raw, '');
    scalars.sort((a, b) => a.$1.compareTo(b.$1));
    return [
      ...values,
      for (final (label, value) in scalars) KitTechnicalValue(label, value),
    ];
  }
}

KitReceiptState _receiptState(MutationStatus status) => switch (status) {
  MutationStatus.sent => KitReceiptState.sent,
  MutationStatus.confirmed => KitReceiptState.confirmed,
  MutationStatus.unconfirmed => KitReceiptState.notConfirmed,
  MutationStatus.rejected => KitReceiptState.refused,
};
