part of '../chat_screen.dart';

// The AI Team as a conversation (docs/design/team-conversation-2026-09-26.md):
// a task is a conversation, its workers are its sub-agents. The team's own
// data is assembled into the chat's kit parts (option A) and follows the
// transcript turn model (STATE-16, KIT-41): your prompt is the task, the
// lead's reply is written by the app from real team events
// (`teamLeadLines`), the task's steps fold under one KitWorkLine, each
// worker or reviewer is a sub-agent line (KitToolRow.agent) that opens its
// real OpenCode session in watching mode, gates are the request cards, and
// the turn has one control row (its footer) once it has ended. Around the
// turn: the one "Now" line and the agent strip (KitAgentStrip) under the
// header, the merge section after the turn, and the composer, whose words
// go through the team's own message control.

/// A task just given to the team, shown before the team lists its run: the
/// person's words as the prompt, and the conversation binds to the run once
/// one carries the created work item ([workId]) or the planning request
/// ([record] with [title] as its objective).
@immutable
class TeamPendingTask {
  const TeamPendingTask({
    required this.title,
    required this.sentAt,
    this.details,
    this.workId,
    this.record,
  });

  final String title;
  final String? details;
  final DateTime sentAt;

  /// The work item the direct path created (TEAM-306), when known.
  final String? workId;

  /// The planner message (Start-a-run), when the planner got the task.
  final MutationRecord? record;
}

/// The chat page for one AI Team task.
class TeamConversationScreen extends StatefulWidget {
  const TeamConversationScreen({
    super.key,
    required this.team,
    this.runId,
    this.pending,
    this.now,
    this.onOpenAgent,
  }) : assert(runId != null || pending != null);

  final OrchestrationController team;

  /// The task (run) this conversation is; null while [pending] waits for it.
  final String? runId;
  final TeamPendingTask? pending;

  /// Clock for elapsed times; tests pin it.
  final DateTime Function()? now;

  /// Opens a worker's own conversation; [openTeamAgentConversation] when
  /// null. Tests inject their own.
  final Future<void> Function(BuildContext context, OrchestrationAgent agent)?
  onOpenAgent;

  /// Unsent words per task, kept while the app runs: leaving the page and
  /// coming back finds the draft where it was (map actionsMissing "draft
  /// kept when leaving"). Nothing is written to storage.
  static final Map<String, String> _drafts = <String, String>{};

  @override
  State<TeamConversationScreen> createState() => _TeamConversationScreenState();
}

class _TeamConversationScreenState extends State<TeamConversationScreen> {
  final _expansion = <String, bool>{};
  final _message = TextEditingController();
  final _focus = FocusNode();

  /// The transcript's scroll: a message just sent is brought into view
  /// (the Now line above can take room and leave it under the fold).
  final _scroll = ScrollController();
  Timer? _tick;
  String? _runId;

  /// The last run and steps seen: a finished task leaves the team's open
  /// list, and its conversation keeps what it last showed.
  OrchestrationRun? _lastRun;
  List<WorkItem> _lastWork = const [];

  /// Message records sent from this page (their receipts show under them).
  final _sentHere = <String>{};
  bool _sending = false;

  OrchestrationController get _team => widget.team;
  DateTime Function() get _clock => widget.now ?? DateTime.now;

  String get _draftKey =>
      _runId ?? 'pending:${widget.pending?.sentAt.microsecondsSinceEpoch ?? 0}';

  @override
  void initState() {
    super.initState();
    _runId = widget.runId;
    _message.text = TeamConversationScreen._drafts[_draftKey] ?? '';
    _message.addListener(_keepDraft);
    _team.watchCycles();
    _team.addListener(_bind);
    _bind();
    // Elapsed times ("waited 3 min") move without a new answer.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _team.removeListener(_bind);
    _team.unwatchCycles();
    _message
      ..removeListener(_keepDraft)
      ..dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _keepDraft() {
    final text = _message.text;
    if (text.trim().isEmpty) {
      TeamConversationScreen._drafts.remove(_draftKey);
    } else {
      TeamConversationScreen._drafts[_draftKey] = text;
    }
  }

  /// Finds the run a pending task became.
  void _bind() {
    if (_runId != null) return;
    final pending = widget.pending;
    if (pending == null) return;
    final snapshot = _team.snapshot;
    String? found;
    if (pending.workId case final workId?) {
      for (final item in snapshot.work) {
        if (item.id == workId && item.runId != null) found = item.runId;
      }
    }
    if (found == null && pending.record != null) {
      for (final run in snapshot.runs) {
        if (teamPlanningRunMatches(run, pending.record!, pending.title)) {
          found = run.id;
          break;
        }
      }
    }
    if (found != null && mounted) {
      // The draft follows the task to its run.
      final draft = TeamConversationScreen._drafts.remove(_draftKey);
      setState(() => _runId = found);
      if (draft != null) TeamConversationScreen._drafts[_draftKey] = draft;
    }
  }

  OrchestrationRun? _run() {
    final id = _runId;
    if (id == null) return null;
    for (final run in _team.snapshot.runs) {
      if (run.id == id) return _lastRun = run;
    }
    return _lastRun;
  }

  List<WorkItem> _work(OrchestrationRun run) {
    final items = [
      for (final item in _team.snapshot.work)
        if (item.runId == run.id) item,
    ];
    if (items.isNotEmpty) _lastWork = items;
    return items.isEmpty ? _lastWork : items;
  }

  /// The planner's record for a pending task, as it stands now (a refusal
  /// arrives after the page opened).
  MutationRecord? _pendingRecord() {
    final record = widget.pending?.record;
    if (record == null) return null;
    for (final latest in _team.mutations) {
      if (latest.key == record.key) return latest;
    }
    return record;
  }

  /// Who the composer's words go to: the worker on the task, else the
  /// planner when it is on. Never a worker's OpenCode session directly:
  /// the team's message control delivers it.
  OrchestrationAgent? _recipient(List<OrchestrationAgent> agents) {
    for (final agent in agents) {
      if (teamAgentRole(agent) == TeamAgentRole.worker) return agent;
    }
    if (agents.isNotEmpty) return agents.first;
    final planner = teamPlannerAgent(_team.snapshot.agents);
    if (planner != null && !teamPlannerIsOff(planner)) return planner;
    return null;
  }

  Future<void> _send(OrchestrationAgent recipient) async {
    final text = _message.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final record = await _team.messageAgent(recipient.id, text);
      if (!mounted) return;
      _sentHere.add(record.key);
      _message.clear();
      _showLatest();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Scrolls the transcript to its end once the sent message is laid out.
  void _showLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final position = _scroll.position;
      if (KitMotion.reduced(context)) {
        position.jumpTo(position.maxScrollExtent);
      } else {
        unawaited(
          position.animateTo(
            position.maxScrollExtent,
            duration: KitMotion.standard,
            curve: KitMotion.emphasized,
          ),
        );
      }
    });
  }

  Future<void> _openAgent(OrchestrationAgent agent) {
    final open = widget.onOpenAgent;
    if (open != null) return open(context, agent);
    return openTeamAgentConversation(context, agent, team: _team);
  }

  /// The team's page ([openTeamPage], the one AI Team page), over this
  /// conversation. Its row for this same task comes back here rather than
  /// stacking a second copy of the page; another task opens its own
  /// conversation. A conversation whose team is not the connected server's
  /// (none in the app today) opens that team's home directly.
  void _openTeamPage() {
    final here = ModalRoute.of(context);
    void openRun(OrchestrationRun run) {
      if (!mounted) return;
      if (run.id == _runId && here != null) {
        Navigator.of(context).popUntil((route) => route == here);
        return;
      }
      unawaited(TeamConversation.open(context, _team, runId: run.id));
    }

    ConnectionController? connection;
    try {
      connection = ProviderScope.containerOf(
        context,
        listen: false,
      ).read(connProvider);
    } catch (_) {
      connection = null;
    }
    if (connection != null && identical(connection.orchestration, _team)) {
      unawaited(
        openTeamPage(context, connection, now: widget.now, onOpenRun: openRun),
      );
      return;
    }
    unawaited(
      Navigator.of(context).push(
        KitPageRoute<void>(
          builder: (_) => TeamHomeScreen(
            controller: _team,
            now: widget.now,
            onOpenRun: openRun,
          ),
        ),
      ),
    );
  }

  /// A task the host can still stop: not finished, failed or cancelled,
  /// on a host whose team takes the cancel control.
  bool _canStop(OrchestrationRun run) =>
      _team.capabilities.controlCancelRun &&
      switch (run.state) {
        RunState.completed || RunState.cancelled || RunState.failed => false,
        _ => true,
      };

  /// Stop task: the confirm sheet names the task and what happens to its
  /// running workers; backing out sends nothing. The receipt shows in the
  /// conversation (Sent, then Confirmed or the host's refusal).
  Future<void> _stop(OrchestrationRun run) async {
    final l10n = _chatL10n(context);
    final ok = await showKitConfirm(
      context,
      title: l10n.teamChatStopConfirmTitle,
      body: l10n.teamChatStopConfirmBody(
        run.title.trim().isEmpty ? l10n.teamChatUntitled : run.title.trim(),
      ),
      confirmLabel: l10n.teamChatStopTask,
      cancelLabel: l10n.teamChatStopKeepRunning,
      kind: KitConfirmKind.stop,
      sheetKey: const ValueKey('team-conversation-stop-confirm'),
      confirmKey: const ValueKey('team-conversation-stop-confirm-action'),
    );
    if (!ok || !mounted) return;
    await _team.cancelRun(run.id);
  }

  /// Task details (P3.5): what the retired run page showed that the
  /// conversation does not — the stages, the steps as a graph, the
  /// agents' pages, the numbers and the technical fold.
  void _openDetails(String runId) =>
      unawaited(showTeamTaskDetails(context, _team, runId, now: widget.now));

  bool _refreshing = false;

  /// The page's Refresh (a computer has no pull gesture): fetches the team
  /// again, or retries a team that did not answer.
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      if (_team.phase == OrchestrationPhase.failed) {
        await _team.retry();
      } else {
        await _team.refresh();
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// Nudge or restart the stalled task's worker; restart asks first. The
  /// receipt shows under the stall's notice.
  Future<void> _control(
    OrchestrationAgent agent,
    AgentControlAction action,
  ) async {
    if (action == AgentControlAction.restart) {
      final l10n = _chatL10n(context);
      final ok = await showKitConfirm(
        context,
        title: l10n.teamUiControlRestartConfirmTitle(
          _teamAgentTitle(l10n, agent),
        ),
        body: l10n.teamUiControlRestartConfirmBody,
        confirmLabel: l10n.teamAgentScreenRestart(_teamAgentName(l10n, agent)),
        icon: AppIconography.restart,
        sheetKey: const ValueKey('team-conversation-restart-confirm'),
        confirmKey: const ValueKey('team-conversation-restart-confirm-action'),
      );
      if (!ok || !mounted) return;
    }
    await _team.controlAgent(agent.id, action);
  }

  /// Where the task's one turn stands, from the task's own state.
  KitTurnPhase _phase(
    OrchestrationRun? run,
    List<OrchestrationGate> gates,
    MutationRecord? pendingRecord,
  ) {
    if (run == null) {
      return pendingRecord?.status == MutationStatus.rejected
          ? KitTurnPhase.failed
          : KitTurnPhase.starting;
    }
    return switch (run.state) {
      RunState.completed => KitTurnPhase.finished,
      RunState.failed => KitTurnPhase.failed,
      RunState.cancelled => KitTurnPhase.stopped,
      _ when gates.isNotEmpty => KitTurnPhase.waitingForYou,
      _ => KitTurnPhase.running,
    };
  }

  /// The moment a worker begins the task, with the session's creation, is
  /// one measured start: kept per profile as "took 42 s last time".
  void _rememberWorkerStart(TeamNow now, List<OrchestrationAgent> agents) {
    if (now.kind != TeamNowKind.working) return;
    for (final agent in agents) {
      final took = teamWorkerStartMeasured(
        sessionStartedAt: agent.sessionStartedAt,
        began: now.since,
      );
      if (took != null && teamSessionState(agent) == AgentState.working) {
        unawaited(_team.workerStarts.record(_team.profileId, took));
        return;
      }
    }
  }

  /// The facts for the task's one Now line (slice-P5.1), or null when the
  /// line has nothing to add: a refused task says so in its turn, with Try
  /// again. [connected] is false once the team has not answered for 8 s.
  TeamNowInput? _nowInput({
    required OrchestrationRun? run,
    required List<WorkItem> work,
    required List<OrchestrationGate> gates,
    required MutationRecord? pendingRecord,
    required bool connected,
  }) {
    final profile = _team.profileId;
    final every = teamCheckInterval(_team);
    // How long the next stage takes, only where the app knows it: a
    // worker's start is this phone's own last measured start (nothing when
    // none was measured), and a wait for a worker on the team inside the
    // app is its own check interval.
    TeamNowInput timed(TeamNowInput input, {TeamWorkerStage? stage}) {
      if (input.activity == TeamNowActivity.startingWorker) {
        return input.withWorkerStart(
          stage: stage,
          lastStart: _team.workerStarts.read(_team.profileId),
        );
      }
      if (input.activity != TeamNowActivity.waitingForWorker) return input;
      return input.withWorkerStart(typicalUpperBound: every);
    }

    if (run != null) {
      return timed(
        TeamNowInput.forRun(
          activityKey: '$profile:${run.id}',
          run: run,
          work: work,
          cycleOf: _team.cycleFor,
          agents: _team.snapshot.agents,
          gates: gates,
          connected: connected,
          canCancel: _canStop(run),
          now: _clock(),
        ),
      );
    }
    final pending = widget.pending;
    if (pending == null) return null;
    final key = '$profile:pending:${pendingRecord?.key ?? pending.workId}';
    if (!connected) {
      return TeamNowInput(
        activityKey: key,
        activity: TeamNowActivity.unavailable,
        next: TeamNowNext.checkActivity,
        reason: TeamNowReason.connectionUnavailable,
      );
    }
    if (pendingRecord != null) {
      if (pendingRecord.status == MutationStatus.rejected) return null;
      final request = teamPlanningRequests(
        mutations: [pendingRecord],
        runs: const [],
        dismissed: const {},
        now: _clock(),
      ).firstOrNull;
      if (request != null) {
        return TeamNowInput.forPlanning(activityKey: key, request: request);
      }
    }
    // A direct task: its stage from the attempt that made it (P6.3), never
    // more than the host confirmed. Without that attempt (another device,
    // an older page) the task was made and given to the worker pool.
    final attempt = TeamDispatchAttempts.of(_team).latest;
    final stage = attempt != null && attempt.workId == pending.workId
        ? attempt.phase
        : null;
    TeamNowInput line(
      TeamNowActivity activity,
      TeamNowNext next,
      TeamNowReason reason,
    ) => TeamNowInput(
      activityKey: '$key:${stage?.name}',
      activity: activity,
      next: next,
      reason: reason,
      since: pending.sentAt,
    );
    switch (stage) {
      case TeamDispatchPhase.creating || TeamDispatchPhase.sending:
        // The assignment is on its way: the turn says "starting"; the line
        // waits for the host's answer instead of guessing it.
        return null;
      case TeamDispatchPhase.workerObserved:
        return timed(
          line(
            TeamNowActivity.startingWorker,
            TeamNowNext.work,
            TeamNowReason.workerStarting,
          ),
          stage: teamWorkerStage(
            _team.snapshot.agents
                .where((agent) => agent.currentWorkId == pending.workId)
                .firstOrNull,
          ),
        );
      case TeamDispatchPhase.assignRefused:
        return line(
          TeamNowActivity.refused,
          TeamNowNext.checkActivity,
          TeamNowReason.requestRefused,
        );
      case TeamDispatchPhase.dispatchUnconfirmed:
        return line(
          TeamNowActivity.unconfirmed,
          TeamNowNext.checkActivity,
          TeamNowReason.confirmationMissing,
        );
      case TeamDispatchPhase.unknown:
        return line(
          TeamNowActivity.unavailable,
          TeamNowNext.checkActivity,
          TeamNowReason.connectionUnavailable,
        );
      default:
        break;
    }
    return timed(
      TeamNowInput(
        activityKey: key,
        activity: TeamNowActivity.waitingForWorker,
        next: TeamNowNext.worker,
        reason: TeamNowReason.noWorkerReported,
        since: pending.sentAt,
      ),
    );
  }

  /// This page's way out for a Now line suggestion, naming its target.
  KitAction? _wayOut(
    TeamNowAction action, {
    required OrchestrationRun? run,
    required List<OrchestrationAgent> agents,
    required MutationRecord? pendingRecord,
  }) {
    final l10n = _chatL10n(context);
    switch (action) {
      case TeamNowAction.refresh:
        return KitAction(
          key: const ValueKey('team-conversation-now-refresh'),
          label: l10n.teamUiRefresh,
          working: _refreshing,
          onPressed: _refreshing ? null : () => unawaited(_refresh()),
        );
      case TeamNowAction.openActivity:
        if (run == null) {
          final planner = pendingRecord?.targetId;
          if (planner == null) return null;
          return KitAction(
            key: const ValueKey('team-conversation-now-watch'),
            label: l10n.teamNowWatchPlanner,
            onPressed: () => unawaited(
              openTeamAgentConversationById(context, _team, planner),
            ),
          );
        }
        OrchestrationAgent? worker;
        for (final agent in agents) {
          if (teamAgentRole(agent) == TeamAgentRole.worker) {
            worker = agent;
            break;
          }
        }
        worker ??= agents.firstOrNull;
        if (worker == null) {
          return KitAction(
            key: const ValueKey('team-conversation-now-details'),
            label: l10n.teamChatTaskDetails,
            onPressed: () => _openDetails(run.id),
          );
        }
        final agent = worker;
        return KitAction(
          key: const ValueKey('team-conversation-now-watch'),
          label: l10n.teamNowWatchAgent(_teamAgentName(l10n, agent)),
          onPressed: () => unawaited(_openAgent(agent)),
        );
      case TeamNowAction.dismissRequest:
        final record = pendingRecord;
        if (record == null) return null;
        return KitAction(
          key: const ValueKey('team-conversation-now-dismiss'),
          label: l10n.teamNowDismissRequest,
          onPressed: () async {
            await _team.dismissPlanning(record.key);
            if (mounted) await Navigator.of(context).maybePop();
          },
        );
      case TeamNowAction.cancelRun:
        if (run == null || !_canStop(run)) return null;
        return KitAction(
          key: const ValueKey('team-conversation-now-stop'),
          label: l10n.teamChatStopTask,
          destructive: true,
          onPressed: () => unawaited(_stop(run)),
        );
      case TeamNowAction.answer:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // The task's dispatch stage (P6.3) moves with its own attempt.
    listenable: Listenable.merge([_team, TeamDispatchAttempts.of(_team)]),
    builder: (context, _) {
      final l10n = _chatL10n(context);
      final run = _run();
      final work = run == null ? const <WorkItem>[] : _work(run);
      final snapshot = _team.snapshot;
      DispatchCycle cycleOf(String id) => _team.cycleFor(id);
      final agents = run == null
          ? const <OrchestrationAgent>[]
          : teamConversationAgents(
              agents: snapshot.agents,
              work: work,
              cycleOf: cycleOf,
            );
      final gates = run == null
          ? const <OrchestrationGate>[]
          : teamOpenGates(_team, runId: run.id);
      final lines = run == null
          ? const <TeamLeadLine>[]
          : teamLeadLines(
              run: run,
              work: work,
              cycleOf: cycleOf,
              agents: snapshot.agents,
              gates: gates,
            );
      final now = run == null
          ? null
          : teamNow(
              run: run,
              work: work,
              cycleOf: cycleOf,
              agents: snapshot.agents,
              gates: gates,
              now: _clock(),
            );
      final attempt = TeamDispatchAttempts.of(_team).latest;
      // A worker is starting: its step says so, a session is being made, or
      // (a direct task) the team just observed its worker.
      final starting =
          now?.kind == TeamNowKind.starting ||
          agents.any(
            (agent) =>
                teamWorkerStage(agent) == TeamWorkerStage.preparing &&
                teamSessionState(agent) != AgentState.stopped,
          ) ||
          (run == null &&
              attempt != null &&
              attempt.workId == widget.pending?.workId &&
              attempt.phase == TeamDispatchPhase.workerObserved);
      if (now != null) _rememberWorkerStart(now, agents);
      final title = run?.title ?? widget.pending?.title ?? '';
      final recipient = _recipient(agents);
      final loading =
          _team.phase != OrchestrationPhase.ready || !snapshot.hasData;
      // A task this page knew by id that the team no longer lists, and never
      // listed while the page was open: removed on the team's computer (map
      // statesMissing "task cancelled or removed").
      final gone =
          _runId != null &&
          run == null &&
          snapshot.hasData &&
          _team.phase == OrchestrationPhase.ready;
      final pendingRecord = run == null ? _pendingRecord() : null;
      final working =
          agents.any(
            (agent) => teamSessionState(agent) == AgentState.working,
          ) ||
          switch (now?.kind) {
            TeamNowKind.starting ||
            TeamNowKind.working ||
            TeamNowKind.review => true,
            _ => false,
          };
      return KitScreen(
        key: const ValueKey('team-conversation'),
        width: KitScreenWidth.reading,
        loading: loading,
        loadingLabel: l10n.teamChatLoading,
        topBar: KitTopBar(
          title: title.isEmpty ? l10n.teamChatUntitled : title,
          titleKey: const ValueKey('team-conversation-title'),
          // Never "Paused" while this task's worker starts or works: the
          // task's own state and its agents' sessions say so.
          subtitle: l10n.teamChatSubtitle(
            teamHostPhrase(
              l10n,
              _team,
              working: working,
              startingWorker: starting,
            ),
          ),
          needsYou: gates.length,
          actions: [
            KitAction(
              key: const ValueKey('team-conversation-team-page'),
              label: l10n.teamChatOpenTeam,
              icon: AppIconography.agent,
              onPressed: _openTeamPage,
            ),
          ],
          // The conversation menu's two kinds (P10.2): "Go to" the task's
          // details, "Do" refresh, and Stop task last (it confirms).
          menu: [
            if (run != null)
              KitMenuItem(
                key: const ValueKey('team-conversation-details'),
                label: l10n.teamChatTaskDetails,
                icon: AppIconography.info,
                group: KitMenuGroup(l10n.sessionMenuGoTo),
                onSelected: () => _openDetails(run.id),
              ),
            KitMenuItem(
              key: const ValueKey('team-conversation-refresh'),
              label: l10n.teamUiRefresh,
              icon: AppIconography.sync,
              group: KitMenuGroup(l10n.sessionMenuDo),
              enabled: !_refreshing,
              onSelected: () => unawaited(_refresh()),
            ),
            if (run != null) ...[
              // Only while the task runs and this host can stop it.
              if (_canStop(run))
                KitMenuItem(
                  key: const ValueKey('team-conversation-stop'),
                  label: l10n.teamChatStopTask,
                  icon: AppIconography.stop,
                  destructive: true,
                  onSelected: () => unawaited(_stop(run)),
                ),
            ],
          ],
          menuKey: const ValueKey('team-conversation-menu'),
        ),
        header: [
          if (!gone)
            _TeamNowLine(
              team: _team,
              clock: _clock,
              startingWorker: starting,
              input: (connected) => _nowInput(
                run: run,
                work: work,
                gates: gates,
                pendingRecord: pendingRecord,
                connected: connected,
              ),
              wayOut: (action) => _wayOut(
                action,
                run: run,
                agents: agents,
                pendingRecord: pendingRecord,
              ),
              // Quiet for an hour or more: the notice under the worker
              // line says since when and offers its ways out.
              quiet: _noProgress(now, _clock()),
            ),
          // The strip is the header's last row, with room under it and the
          // header's edge, so the transcript never reads as running under
          // its chips (owner report, build 2055).
          if (run != null && agents.isNotEmpty) ...[
            Padding(
              key: const ValueKey('team-conversation-family-band'),
              padding: EdgeInsetsDirectional.only(
                top: KitTokens.of(context).space1,
                bottom: KitTokens.of(context).space2,
              ),
              child: KitAgentStrip(
                stripKey: const ValueKey('team-conversation-family'),
                agents: [
                  KitAgent(
                    id: 'lead',
                    key: const ValueKey('team-conversation-family-lead'),
                    name: l10n.teamChatLeadName,
                    state: _teamLeadState(run, gates),
                  ),
                  for (final agent in agents)
                    KitAgent(
                      id: agent.id,
                      key: ValueKey('team-conversation-family-${agent.id}'),
                      name:
                          teamAgentShortName(agent) ??
                          teamAgentRoleWord(l10n, teamAgentRole(agent)),
                      role: teamAgentShortName(agent) == null
                          ? null
                          : teamAgentRoleWord(l10n, teamAgentRole(agent)),
                      state: _teamAgentState(agent),
                      onOpen: () => unawaited(_openAgent(agent)),
                    ),
                ],
              ),
            ),
            const KitDivider(),
          ],
        ],
        body: gone
            ? KitStateView(
                key: const ValueKey('team-conversation-gone'),
                icon: AppIconography.agent,
                title: l10n.teamChatGoneTitle,
                body: l10n.teamChatGoneBody,
                primary: KitAction(
                  key: const ValueKey('team-conversation-gone-team-page'),
                  label: l10n.teamChatGoneOpenTeam,
                  icon: AppIconography.agent,
                  onPressed: _openTeamPage,
                ),
              )
            : KitComposer.layer(
                body: _transcript(
                  context,
                  run: run,
                  work: work,
                  agents: agents,
                  gates: gates,
                  lines: lines,
                  title: title,
                  pendingRecord: pendingRecord,
                  now: now,
                ),
                composer: _composer(context, recipient),
              ),
      );
    },
  );

  /// The task's one turn, then what the person sent and the merge section.
  Widget _transcript(
    BuildContext context, {
    required OrchestrationRun? run,
    required List<WorkItem> work,
    required List<OrchestrationAgent> agents,
    required List<OrchestrationGate> gates,
    required List<TeamLeadLine> lines,
    required String title,
    required MutationRecord? pendingRecord,
    required TeamNow? now,
  }) {
    final l10n = _chatL10n(context);
    final tokens = KitTokens.of(context);
    final clock = _clock();
    // The prompt says the task once; a step or a worker's line that is
    // the task itself refers back to it instead of repeating its words.
    final soleStep =
        work.length == 1 && _sameTaskText(work.single.title, title);
    final quiet = _noProgress(now, clock);
    OrchestrationAgent? stalledAgent;
    if (quiet != null) {
      for (final agent in [...agents, ..._team.snapshot.agents]) {
        if (agent.id == now?.agentId) {
          stalledAgent = agent;
          break;
        }
      }
    }
    final prompt = [
      title,
      ?(run == null ? widget.pending?.details : _runDetails(run, work)),
    ].where((t) => t.trim().isNotEmpty).join('\n\n');
    final phase = _phase(run, gates, pendingRecord);
    final leadRows = _TeamLeadReply.rowsFor(
      context,
      lines: lines,
      pending: run == null ? widget.pending : null,
      taskTitle: title,
    );
    final sent = [
      for (final record in _team.mutations)
        if (_sentHere.contains(record.key) ||
            (record.kind == MutationKind.message &&
                agents.any((a) => a.id == record.targetId) &&
                (run?.startedAt == null ||
                    !record.createdAt.isBefore(run!.startedAt!))))
          record,
    ];
    final stop = run == null
        ? null
        : _team.latestMutation(kind: MutationKind.cancelRun, targetId: run.id);
    // The end padding is read under the composer layer, which adds its
    // height to the bottom inset.
    return Builder(
      builder: (context) => ListView(
        key: const ValueKey('team-conversation-list'),
        controller: _scroll,
        padding: EdgeInsetsDirectional.fromSTEB(
          tokens.gutter,
          tokens.space3,
          tokens.gutter,
          KitScreen.endPadding(context),
        ),
        children: [
          KitTurn(
            turnKey: const ValueKey('team-conversation-turn'),
            prompt: KitMessage.prompt(
              key: const ValueKey('team-conversation-prompt'),
              body: KitMarkdown(prompt, selectable: false),
            ),
            phase: phase,
            since: run?.startedAt ?? widget.pending?.sentAt,
            latest: sent.isEmpty,
            footer: KitTurnFooter(copyText: () => leadRows.join('\n')),
            footerKey: const ValueKey('team-conversation-footer'),
            blocks: [
              _TeamLeadReply(rows: leadRows, expansion: _expansion),
              if (pendingRecord case final record?
                  when record.status == MutationStatus.rejected)
                KitNotice(
                  key: const ValueKey('team-conversation-refused'),
                  tone: AppStatusTone.failure,
                  icon: AppIconography.error,
                  title: l10n.teamChatRefusedTitle,
                  message: teamReceiptLine(l10n, record),
                  actions: [
                    if (record.canRetry)
                      KitAction(
                        key: const ValueKey('team-conversation-refused-retry'),
                        label: l10n.teamChatRefusedRetry,
                        icon: AppIconography.retry,
                        onPressed: () =>
                            unawaited(_team.retryMutation(record.key)),
                      ),
                  ],
                ),
              // One step that is the task itself is not listed again (its
              // Work sheet is a row of Task details).
              if (work.isNotEmpty && !soleStep)
                _TeamSteps(
                  work: work,
                  expansion: _expansion,
                  onOpen: (id) => unawaited(
                    showWorkSheet(context, _team, id, now: widget.now),
                  ),
                ),
              for (final agent in agents)
                KitToolRow.agent(
                  rowKey: ValueKey('team-conversation-agent-${agent.id}'),
                  title: _teamAgentTitle(l10n, agent),
                  status: _teamAgentToolStatus(agent),
                  task: [
                    for (final item in work)
                      if (item.id == agent.currentWorkId &&
                          !_sameTaskText(item.title, title))
                        item.title,
                  ].firstOrNull,
                  startedAt:
                      teamSessionState(agent) == AgentState.working &&
                          agent.sessionStartedAt != null &&
                          !agent.sessionStartedAt!.isAfter(clock)
                      ? agent.sessionStartedAt
                      : null,
                  openLabel: l10n.teamOpenConversation,
                  onOpen: () => unawaited(_openAgent(agent)),
                ),
              if (quiet != null)
                _TeamNoProgress(
                  team: _team,
                  agent: stalledAgent,
                  quiet: quiet,
                  since: now!.quietSince!,
                  runId: run?.id,
                  agentName: stalledAgent == null
                      ? now.agentName
                      : _teamAgentName(l10n, stalledAgent),
                  onControl: _control,
                  today: clock,
                ),
              // An Inbox row or a notification for one gate lands on its
              // card (P4.2a).
              for (final gate in gates)
                KitArrival(
                  id: chatRequestArrivalId(gate.id),
                  child: TeamNeedsYouCard(
                    keyPrefix: 'team-conversation-gate-${gate.id}',
                    controller: _team,
                    gate: gate,
                    title: teamGateWho(l10n, _team.snapshot, gate),
                    onOpen: () => unawaited(
                      showGateSheet(context, _team, gate.id, now: widget.now),
                    ),
                  ),
                ),
              if (stop != null)
                _teamReceipt(
                  context,
                  stop,
                  key: const ValueKey('team-conversation-stop-receipt'),
                  control: l10n.teamChatStopTask,
                  onRetry: () => _team.retryMutation(stop.key),
                ),
            ],
          ),
          for (final record in sent)
            KitTurn(
              key: ValueKey('team-conversation-message-${record.key}'),
              prompt: KitMessage.prompt(
                body: KitMarkdown(record.request.text ?? '', selectable: false),
              ),
              // The message's own receipt; the team's answer arrives in the
              // task's turn above (the lead's lines and the workers' state).
              phase: KitTurnPhase.finished,
              latest: record == sent.last,
              blocks: [
                _teamReceipt(
                  context,
                  record,
                  key: ValueKey('team-conversation-sent-${record.key}'),
                  onRetry: () => _team.retryMutation(record.key),
                ),
              ],
            ),
          if (run != null) ...[
            // Merged: the celebration, once per task (it is remembered).
            TeamMergedCelebration(
              profileId: _team.profileId,
              runId: run.id,
              merged: run.state == RunState.completed && run.merged,
            ),
            Padding(
              padding: EdgeInsetsDirectional.only(top: tokens.space4),
              child: TeamMergeSection(
                controller: _team,
                run: run,
                now: widget.now,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "Message the team…": the words go through the team's own message
  /// control to the worker on the task (or the planner), never typed into a
  /// worker's OpenCode session. The note says who gets them before typing.
  KitComposer _composer(BuildContext context, OrchestrationAgent? to) {
    final l10n = _chatL10n(context);
    final canMessage = _team.capabilities.controlMessage;
    final readOnly = !canMessage
        ? l10n.teamChatComposerCannot
        : to == null
        ? l10n.teamChatComposerNobody
        : null;
    return KitComposer(
      composerKey: const ValueKey('team-conversation-composer'),
      fieldKey: const ValueKey('team-conversation-field'),
      sendKey: const ValueKey('team-conversation-send'),
      controller: _message,
      focusNode: _focus,
      hint: l10n.teamChatComposerHint,
      fieldLabel: l10n.teamChatComposerHint,
      readOnlyReason: readOnly,
      note: to == null
          ? null
          : l10n.teamChatComposerGoesTo(_teamAgentTitle(l10n, to)),
      sending: _sending,
      canSendWhileBusy: true,
      onSend: () {
        if (to != null) unawaited(_send(to));
      },
    );
  }

  /// The task's own text beyond its title: a one-step task's description.
  String? _runDetails(OrchestrationRun run, List<WorkItem> work) {
    final raw = run.raw['description'];
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (work.length == 1) {
      final text = work.single.raw['description'];
      if (text is String && text.trim().isNotEmpty) return text.trim();
    }
    return null;
  }
}

/// A team write's receipt in words: "Message · Sending…", then
/// "Message · Confirmed" or the host's reason, with Try again when the
/// record may be retried ([teamControlReceipt]).
Widget _teamReceipt(
  BuildContext context,
  MutationRecord record, {
  required Key key,
  String? control,
  Future<void> Function()? onRetry,
}) => teamControlReceipt(
  context,
  record,
  key: key,
  control: control,
  onRetry: onRetry,
  retryKey: ValueKey('${(key as ValueKey<String>).value}-retry'),
);

/// The lead's reply, read like any reply in the chat: one plain line per
/// real team event with its time, on the prose's edge, no frame or fill.
/// When there are many, the earlier ones fold under one quiet line and the
/// newest stay in view.
class _TeamLeadReply extends StatefulWidget {
  const _TeamLeadReply({required this.rows, required this.expansion});

  final List<String> rows;
  final Map<String, bool> expansion;

  /// Up to this many lines show unfolded; beyond it, all but the newest
  /// [_kept] fold.
  static const _openUpTo = 3;
  static const _kept = 2;
  static const _storeKey = 'team-lead-earlier';

  /// The lead's lines with their times, oldest first.
  static List<String> rowsFor(
    BuildContext context, {
    required List<TeamLeadLine> lines,
    required TeamPendingTask? pending,
    String? taskTitle,
  }) {
    final l10n = _chatL10n(context);
    String at(DateTime? time, {bool seconds = false}) {
      if (time == null) return '';
      final clock = teamClockLabel(context, time);
      if (!seconds) return ' · $clock';
      final second = time.toLocal().second.toString().padLeft(2, '0');
      return ' · $clock:$second';
    }

    return [
      if (pending case final task?)
        '${l10n.teamChatLeadSent}${at(task.sentAt)}',
      for (final line in lines)
        // The moment a worker began the task is said to the second: it is
        // the pickup the person waited for.
        '${teamLeadSentence(l10n, line, taskTitle: taskTitle)}'
            '${at(line.at, seconds: line.event == TeamLeadEvent.claimed)}',
    ];
  }

  @override
  State<_TeamLeadReply> createState() => _TeamLeadReplyState();
}

class _TeamLeadReplyState extends State<_TeamLeadReply> {
  bool get _expanded => widget.expansion[_TeamLeadReply._storeKey] ?? false;

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final tokens = KitTokens.of(context);
    final rows = widget.rows;
    final fold = rows.length > _TeamLeadReply._openUpTo;
    final earlier = fold
        ? rows.sublist(0, rows.length - _TeamLeadReply._kept)
        : const <String>[];
    final recent = fold
        ? rows.sublist(rows.length - _TeamLeadReply._kept)
        : rows;
    return Column(
      key: const ValueKey('team-conversation-lead'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Who speaks: the team's lead, whose lines the app writes.
        KitText(
          l10n.teamChatLeadName,
          role: KitTextRole.label,
          tone: KitTextTone.secondary,
        ),
        SizedBox(height: tokens.space2),
        if (fold) ...[
          KitMessage.notice(
            noticeKey: const ValueKey('team-conversation-lead-earlier'),
            icon: AppIconography.timeline,
            text: l10n.teamChatLeadEarlier(earlier.length),
            detail: KitMarkdown(earlier.join('\n\n'), selectable: false),
            expanded: _expanded,
            onExpansionChanged: (open) => setState(
              () => widget.expansion[_TeamLeadReply._storeKey] = open,
            ),
          ),
          SizedBox(height: tokens.space2),
        ],
        KitMessage.reply(
          bodyKey: const ValueKey('team-conversation-lead-reply'),
          body: KitMarkdown(
            (recent.isEmpty ? [l10n.teamChatLeadNothingYet] : recent).join(
              '\n\n',
            ),
          ),
        ),
      ],
    );
  }
}

/// The lead's words for one line (see [TeamLeadEvent]). A step that is the
/// task itself ([taskTitle], said once in the prompt) is "it", never its
/// words again (owner rule: nothing shown twice).
String teamLeadSentence(
  AppLocalizations l10n,
  TeamLeadLine line, {
  String? taskTitle,
}) {
  final title = line.workTitle ?? '';
  final name = line.agentName;
  if (_sameTaskText(line.workTitle, taskTitle)) {
    switch (line.event) {
      case TeamLeadEvent.routed:
        return l10n.teamChatLeadRoutedIt;
      case TeamLeadEvent.workerStarting:
        return l10n.teamChatLeadStartingIt;
      case TeamLeadEvent.claimed:
        return name == null
            ? l10n.teamChatLeadClaimedWorkerIt
            : l10n.teamChatLeadClaimedIt(name);
      case TeamLeadEvent.pushed:
        return l10n.teamChatLeadPushedIt;
      case TeamLeadEvent.handedToReview:
        return l10n.teamChatLeadReviewIt;
      case TeamLeadEvent.merged:
        return l10n.teamChatLeadMergedIt;
      case TeamLeadEvent.stepFailed:
        return l10n.teamChatLeadStepFailedIt;
      case TeamLeadEvent.stepCancelled:
        return l10n.teamChatLeadStepCancelledIt;
      default:
        break;
    }
  }
  return switch (line.event) {
    TeamLeadEvent.planned => l10n.teamChatLeadPlanned(line.count ?? 0),
    TeamLeadEvent.routed => l10n.teamChatLeadRouted(title),
    TeamLeadEvent.workerStarting => l10n.teamChatLeadStarting(title),
    TeamLeadEvent.claimed =>
      name == null
          ? l10n.teamChatLeadClaimedWorker(title)
          : l10n.teamChatLeadClaimed(name, title),
    TeamLeadEvent.pushed => l10n.teamChatLeadPushed(title),
    TeamLeadEvent.handedToReview => l10n.teamChatLeadReview(title),
    TeamLeadEvent.merged => l10n.teamChatLeadMerged(title),
    TeamLeadEvent.stepFailed => l10n.teamChatLeadStepFailed(title),
    TeamLeadEvent.stepCancelled => l10n.teamChatLeadStepCancelled(title),
    TeamLeadEvent.needsYou => l10n.teamChatLeadNeedsYou(line.detail ?? ''),
    TeamLeadEvent.taskMerged => l10n.teamChatLeadTaskMerged,
    TeamLeadEvent.taskFinished => l10n.teamChatLeadTaskFinished,
    TeamLeadEvent.taskFailed => l10n.teamChatLeadTaskFailed,
    TeamLeadEvent.taskCancelled => l10n.teamChatLeadTaskCancelled,
  };
}

/// The task's one Now line ([TeamNowLineView], slice-P5.1): what the team
/// is doing for this task now, for how long, what comes next and how long
/// that usually takes; after 8 s without the next stage it says why and
/// unfolds the Why in place. A team that has not answered for 8 s is
/// "not answering", with Try again.
class _TeamNowLine extends StatelessWidget {
  const _TeamNowLine({
    required this.team,
    required this.clock,
    required this.startingWorker,
    required this.input,
    required this.wayOut,
    required this.quiet,
  });

  final OrchestrationController team;
  final DateTime Function() clock;

  /// A worker is starting: a late answer is the phone being busy, not the
  /// team being gone.
  final bool startingWorker;

  /// The line's facts, given whether the team answers; null hides it.
  final TeamNowInput? Function(bool connected) input;
  final KitAction? Function(TeamNowAction action) wayOut;

  /// How long the task has shown no progress, past an hour; its notice
  /// in the transcript explains, so the line only says how long.
  final Duration? quiet;

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final waiting =
        !team.snapshot.hasData ||
        // Not answering only: a paused team answers, and says so itself; a
        // team busy starting a worker answers late and keeps its stage.
        (!teamHostBusyStarting(team, startingWorker: startingWorker) &&
            teamHostCondition(
                  l10n,
                  team,
                  working: true,
                  startingWorker: startingWorker,
                ) !=
                null);
    return GraceTimer(
      waiting: waiting,
      grace: KitMotion.escalateAfter,
      builder: (context, overdue) {
        final facts = input(!(overdue && waiting));
        final quiet = this.quiet;
        return KitReveal(
          child: facts == null
              ? null
              : TeamNowLineView(
                  keyPrefix: 'team-conversation',
                  input: facts,
                  wayOut: wayOut,
                  clock: clock,
                  message:
                      quiet == null ||
                          facts.activity == TeamNowActivity.unavailable
                      ? null
                      : l10n.teamChatNowNoProgress(
                          KitSince.durationWords(l10n, quiet),
                        ),
                  explains: quiet == null,
                ),
        );
      },
    );
  }
}

/// How long a stalled task has shown no progress, or null when it is not
/// stalled or has been quiet less than [teamNoProgressAfter].
Duration? _noProgress(TeamNow? now, DateTime clock) {
  final quiet = now?.quietSince;
  if (now == null || now.kind != TeamNowKind.stalled || quiet == null) {
    return null;
  }
  final span = clock.difference(quiet);
  return span < teamNoProgressAfter ? null : span;
}

/// Whether two texts name the same task: equal once trimmed, spaced and
/// cased alike, or one the other cut short by the host (a long title ends
/// in "…").
bool _sameTaskText(String? a, String? b) {
  String norm(String text) => text
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase()
      .replaceAll(RegExp(r'[….]+$'), '')
      .trim();
  if (a == null || b == null) return false;
  final x = norm(a), y = norm(b);
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  final (short, long) = x.length < y.length ? (x, y) : (y, x);
  return short.length >= 24 && long.startsWith(short);
}

/// "furiosa": the agent's short name, else its role word.
String _teamAgentName(AppLocalizations l10n, OrchestrationAgent agent) =>
    teamAgentShortName(agent) ?? teamAgentRoleWord(l10n, teamAgentRole(agent));

/// Under a task with no progress for [quiet]: what happened, since when,
/// and the ways forward — nudge or restart its worker (where the host
/// takes agent controls; restart asks first), or report the problem. The
/// control's receipt follows.
class _TeamNoProgress extends StatelessWidget {
  const _TeamNoProgress({
    required this.team,
    required this.agent,
    required this.agentName,
    required this.quiet,
    required this.since,
    required this.runId,
    required this.onControl,
    required this.today,
  });

  final OrchestrationController team;

  /// The page's clock now, to tell a time today from another day's.
  final DateTime today;
  final OrchestrationAgent? agent;
  final String? agentName;
  final Duration quiet;
  final DateTime since;
  final String? runId;
  final Future<void> Function(OrchestrationAgent, AgentControlAction) onControl;

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final tokens = KitTokens.of(context);
    final agent = this.agent;
    final name = agentName ?? l10n.teamChatAWorker;
    final controls = agent != null && team.capabilities.controlAgent;
    // A time from another day names the day too ("Sep 24, 02:55").
    final local = since.toLocal();
    final today = this.today.toLocal();
    final time =
        local.year == today.year &&
            local.month == today.month &&
            local.day == today.day
        ? teamClockLabel(context, since)
        : '${MaterialLocalizations.of(context).formatShortMonthDay(local)}, '
              '${teamClockLabel(context, since)}';
    final receipt = agent == null
        ? null
        : team.latestMutation(
            kind: MutationKind.controlAgent,
            targetId: agent.id,
          );
    final elapsed = KitSince.durationWords(l10n, quiet);
    return Column(
      key: const ValueKey('team-conversation-no-progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KitNotice(
          key: const ValueKey('team-conversation-no-progress-notice'),
          icon: AppIconography.waiting,
          message: controls
              ? l10n.teamChatNoProgressBody(name, time)
              : l10n.teamChatNoProgressBodyNoControls(name, time),
          liveRegion: false,
        ),
        SizedBox(height: tokens.space2),
        // Nudge is the light first step; restart (asked first) and the
        // report sit beside it.
        KitActionBlock(
          key: const ValueKey('team-conversation-no-progress-actions'),
          secondary: controls
              ? KitAction(
                  key: const ValueKey('team-conversation-no-progress-nudge'),
                  label: l10n.teamAgentScreenNudge(name),
                  onPressed: () =>
                      unawaited(onControl(agent, AgentControlAction.nudge)),
                )
              : null,
          tertiary: [
            if (controls)
              KitAction(
                key: const ValueKey('team-conversation-no-progress-restart'),
                label: l10n.teamAgentScreenRestart(name),
                onPressed: () =>
                    unawaited(onControl(agent, AgentControlAction.restart)),
              ),
            KitAction(
              key: const ValueKey('team-conversation-no-progress-report'),
              label: l10n.teamChatNoProgressReport,
              onPressed: () => unawaited(
                openBugReport(
                  context,
                  error: KitReport(
                    title: l10n.teamChatNoProgressReportTitle(elapsed),
                    source: 'team-conversation',
                    details: [
                      if (runId case final id?) 'task: $id',
                      if (agent != null) 'agent: ${agent.id}',
                      if (agent?.currentWorkId case final work?) 'step: $work',
                      'quiet since: ${since.toUtc().toIso8601String()}',
                    ].join('\n'),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (receipt != null) ...[
          SizedBox(height: tokens.space2),
          _teamReceipt(
            context,
            receipt,
            key: const ValueKey('team-conversation-no-progress-receipt'),
            onRetry: () => team.retryMutation(receipt.key),
          ),
        ],
      ],
    );
  }
}

/// An agent's state from its session (the truth about whether it runs, not
/// the host's agent list), as the agent strip's mark.
KitTaskState _teamAgentState(OrchestrationAgent agent) =>
    switch (teamSessionState(agent)) {
      AgentState.working => KitTaskState.working,
      AgentState.crashed => KitTaskState.failed,
      AgentState.stopped => KitTaskState.done,
      AgentState.idle ||
      AgentState.waiting ||
      AgentState.blocked ||
      AgentState.unknown => KitTaskState.waiting,
    };

/// The same state as a sub-agent line's status word.
KitToolStatus _teamAgentToolStatus(OrchestrationAgent agent) =>
    switch (teamSessionState(agent)) {
      AgentState.working => KitToolStatus.running,
      AgentState.crashed => KitToolStatus.failed,
      AgentState.stopped => KitToolStatus.done,
      AgentState.idle ||
      AgentState.waiting ||
      AgentState.blocked ||
      AgentState.unknown => KitToolStatus.pending,
    };

/// The lead's mark: the task's own state; it needs the person while a gate
/// of this task waits.
KitTaskState _teamLeadState(
  OrchestrationRun run,
  List<OrchestrationGate> gates,
) => switch (run.state) {
  RunState.completed => KitTaskState.done,
  RunState.failed => KitTaskState.failed,
  RunState.cancelled => KitTaskState.stopped,
  _ when gates.isNotEmpty => KitTaskState.needsYou,
  _ => KitTaskState.working,
};

/// "furiosa · Worker": the agent's own name, then its role in plain words.
String _teamAgentTitle(AppLocalizations l10n, OrchestrationAgent agent) {
  final role = teamAgentRoleWord(l10n, teamAgentRole(agent));
  final name = teamAgentShortName(agent);
  return name == null ? role : '$name · $role';
}

/// The task's steps, folded under the turn's one work line: "{n} steps ·
/// {done} done" while the task runs. Up to three steps show open; more
/// fold, and the person's choice is kept in the page's expansion store.
class _TeamSteps extends StatefulWidget {
  const _TeamSteps({
    required this.work,
    required this.expansion,
    required this.onOpen,
  });

  final List<WorkItem> work;
  final Map<String, bool> expansion;

  /// Opens a step's Work sheet (who has it, since when, what it waits on).
  final ValueChanged<String> onOpen;

  static const _openUpTo = 3;
  static const _storeKey = 'team-steps';

  @override
  State<_TeamSteps> createState() => _TeamStepsState();
}

class _TeamStepsState extends State<_TeamSteps> {
  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final work = widget.work;
    final expansion = widget.expansion;
    final done = work.where((item) => item.state == WorkState.completed).length;
    final failed = work.any((item) => item.state == WorkState.failed);
    final running = work.any(
      (item) => switch (item.state) {
        WorkState.completed || WorkState.failed || WorkState.cancelled => false,
        _ => true,
      },
    );
    final needsYou = work.any((item) => item.state == WorkState.needsInput);
    final state = needsYou
        ? KitWorkState.waitingForYou
        : running
        ? KitWorkState.running
        : failed
        ? KitWorkState.endedFailed
        : KitWorkState.done;
    return KitWorkLine(
      key: const ValueKey('team-conversation-steps'),
      lineKey: const ValueKey('team-conversation-steps-fold'),
      counts: KitWorkCounts(steps: work.length),
      state: state,
      now: l10n.teamChatStepsSummary(work.length, done),
      expanded:
          expansion[_TeamSteps._storeKey] ??
          work.length <= _TeamSteps._openUpTo,
      onExpansionChanged: (open) =>
          setState(() => expansion[_TeamSteps._storeKey] = open),
      steps: [
        for (final item in work)
          KitToolRow(
            rowKey: ValueKey('team-conversation-step-${item.id}'),
            kind: KitToolKind.todo,
            title: item.title,
            status: _teamStepStatus(item.state),
            onOpen: () => widget.onOpen(item.id),
          ),
      ],
    );
  }
}

/// A step's state as a work step's status.
KitToolStatus _teamStepStatus(WorkState state) => switch (state) {
  WorkState.completed => KitToolStatus.done,
  WorkState.failed => KitToolStatus.failed,
  WorkState.cancelled => KitToolStatus.stopped,
  WorkState.working || WorkState.review => KitToolStatus.running,
  WorkState.needsInput => KitToolStatus.waitingForYou,
  WorkState.queued ||
  WorkState.ready ||
  WorkState.waiting ||
  WorkState.blocked ||
  WorkState.unknown => KitToolStatus.pending,
};

// ---------------------------------------------------------------------------
// A worker's own conversation (watching mode)
// ---------------------------------------------------------------------------

/// Why a worker's conversation could not be opened, for Live output's line.
enum TeamAgentConversationMiss {
  /// The connected server cannot list conversations across projects, or the
  /// agent names no folder.
  unreadable,

  /// No conversation of the agent's (since it started) on the connected
  /// server: it has not started yet, or the team runs on another machine.
  notFound,
}

/// Where "Open conversation" leads for an agent: its OpenCode session, or
/// why there is none ([miss]).
@immutable
class TeamAgentConversationLookup {
  const TeamAgentConversationLookup.found(String this.sessionId) : miss = null;
  const TeamAgentConversationLookup.missing(TeamAgentConversationMiss this.miss)
    : sessionId = null;

  final String? sessionId;
  final TeamAgentConversationMiss? miss;
}

/// Looks for [agent]'s own OpenCode session on the connected server
/// ([findTeamAgentSession]): in its work folder, newest since its session
/// began. Unreadable when there is no connected server that can list
/// conversations across projects (or none above [context] at all), or the
/// agent names no folder.
Future<TeamAgentConversationLookup> lookupTeamAgentConversation(
  BuildContext context,
  OrchestrationAgent agent,
) async {
  final ConnectionController conn;
  try {
    conn = ProviderScope.containerOf(context, listen: false).read(connProvider);
  } catch (_) {
    return const TeamAgentConversationLookup.missing(
      TeamAgentConversationMiss.unreadable,
    );
  }
  final repository = conn.repository;
  if (repository == null ||
      !conn.capabilities.globalSessionSearch ||
      (agent.workDir?.trim().isEmpty ?? true)) {
    return const TeamAgentConversationLookup.missing(
      TeamAgentConversationMiss.unreadable,
    );
  }
  final sessionId = await findTeamAgentSession(
    repository,
    workDir: agent.workDir,
    startedAt: agent.sessionStartedAt,
  );
  return sessionId == null
      ? const TeamAgentConversationLookup.missing(
          TeamAgentConversationMiss.notFound,
        )
      : TeamAgentConversationLookup.found(sessionId);
}

/// Live output's words for why the agent's conversation could not open.
String teamAgentConversationMissNote(
  BuildContext context,
  TeamAgentConversationMiss miss,
) => switch (miss) {
  TeamAgentConversationMiss.unreadable => _chatL10n(
    context,
  ).teamWatchFallbackUnreadable,
  TeamAgentConversationMiss.notFound => _chatL10n(
    context,
  ).teamWatchFallbackNotFound,
};

/// Opens [agent]'s conversation: its own OpenCode session on the chat page
/// in watching mode (the session in its work folder, newest since the
/// agent's session began, [findTeamAgentSession]). When there is none on
/// the connected server (a team on a computer, a worker still starting),
/// the same watching page opens drawn from the team's live output
/// ([TeamWatchLiveScreen]), with a line saying why.
///
/// [details]: the page offers the worker's own page (its state and
/// controls); false when it was opened from there, so Back returns to it.
Future<void> openTeamAgentConversation(
  BuildContext context,
  OrchestrationAgent agent, {
  OrchestrationController? team,
  TeamAgentConversationLookup? lookup,
  bool details = true,
}) async {
  final navigator = Navigator.of(context);
  final found = lookup ?? await lookupTeamAgentConversation(context, agent);
  final sessionId = found.sessionId;
  final miss = found.miss;
  if (!context.mounted) return;
  final controller = team ?? _teamOf(context);
  if (sessionId case final id?) {
    await navigator.push(
      KitPageRoute<void>(
        builder: (context) => ChatScreen(
          sessionID: id,
          watch: teamAgentWatch(
            context,
            agent,
            team: controller,
            details: details,
          ),
        ),
      ),
    );
    return;
  }
  if (controller == null) return;
  await navigator.push(
    KitPageRoute<void>(
      builder: (context) => TeamWatchLiveScreen(
        team: controller,
        agentId: agent.id,
        details: details,
        note: teamAgentConversationMissNote(
          context,
          miss ?? TeamAgentConversationMiss.notFound,
        ),
      ),
    ),
  );
}

/// Opens the conversation of the agent the team calls [agentId] (a gate's
/// logs, the cycle strip, the planner's card): as
/// [openTeamAgentConversation] while the team lists it, else straight to
/// its live output.
Future<void> openTeamAgentConversationById(
  BuildContext context,
  OrchestrationController team,
  String agentId,
) {
  if (_teamAgentById(team, agentId) case final agent?) {
    return openTeamAgentConversation(context, agent, team: team);
  }
  return Navigator.of(context).push(
    KitPageRoute<void>(
      builder: (_) => TeamWatchLiveScreen(team: team, agentId: agentId),
    ),
  );
}

/// The agent the team lists as [id], by its id or its session's.
OrchestrationAgent? _teamAgentById(OrchestrationController team, String id) {
  for (final agent in team.snapshot.agents) {
    if (agent.id == id || agent.sessionId == id) return agent;
  }
  return null;
}

/// The controller a team screen above [context] was built with, when it
/// shared one ([TeamControllerScope]).
OrchestrationController? _teamOf(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<TeamControllerScope>()?.team;

/// Hands the team's controller to [openTeamAgentConversation] below it.
class TeamControllerScope extends InheritedWidget {
  const TeamControllerScope({
    super.key,
    required this.team,
    required super.child,
  });

  final OrchestrationController team;

  @override
  bool updateShouldNotify(TeamControllerScope oldWidget) =>
      !identical(team, oldWidget.team);
}

/// The watching-mode setup for [agent]: the status line from its session,
/// the composer addressed to it, whose words go through the team's message
/// control ([OrchestrationController.messageAgent]) with their receipt,
/// and the worker's own page as the top bar's action.
ChatWatch teamAgentWatch(
  BuildContext context,
  OrchestrationAgent agent, {
  OrchestrationController? team,
  bool details = true,
}) => _teamWatch(
  context,
  agentId: agent.id,
  agent: agent,
  team: team,
  details: details,
);

ChatWatch _teamWatch(
  BuildContext context, {
  required String agentId,
  OrchestrationAgent? agent,
  OrchestrationController? team,
  bool details = true,
}) {
  final l10n = _chatL10n(context);
  // The agent as the team lists it now: its session moves on.
  OrchestrationAgent? current() =>
      (team == null ? null : _teamAgentById(team, agentId)) ?? agent;
  final first = current();
  final name = first == null ? null : teamAgentShortName(first);
  final role = first == null ? null : teamAgentRole(first);
  final canMessage = team != null && team.capabilities.controlMessage;
  // Receipts of what was sent from this page, not an older message's.
  final sentHere = <String>{};
  // Says a message was just sent, before the team's own next word.
  final sent = ValueNotifier<int>(0);
  return ChatWatch(
    banner: () => _teamWatchBanner(l10n, current()),
    hint: name != null
        ? l10n.teamWatchComposerHint(name)
        : role == TeamAgentRole.worker
        ? l10n.teamWatchComposerHintWorker
        : l10n.teamWatchComposerHintAgent,
    readOnlyReason: l10n.teamChatComposerCannot,
    onSend: !canMessage
        ? null
        : (text) async {
            final record = await team.messageAgent(agentId, text);
            sentHere.add(record.key);
            sent.value++;
            return record.status != MutationStatus.rejected;
          },
    draftId: agentId,
    receipt: team == null
        ? null
        : (context) {
            final record = _newestSent(team, sentHere);
            if (record == null) return null;
            return _teamReceipt(
              context,
              record,
              key: const ValueKey('chat-watching-message-receipt'),
              onRetry: () => team.retryMutation(record.key),
            );
          },
    changes: team == null ? null : Listenable.merge([team, sent]),
    detailsLabel: !details || team == null || first == null
        ? null
        : name != null
        ? l10n.teamWatchAbout(name)
        : l10n.teamWatchAboutRole(teamAgentRoleWord(l10n, role!)),
    onDetails: !details || team == null || first == null
        ? null
        : (context) => unawaited(
            pushKitPage<void>(
              context,
              (_) => AgentScreen(controller: team, agentId: agentId),
            ),
          ),
  );
}

/// "Watching furiosa · Worker · Working": who, and its state as its
/// session tells it ([teamSessionState], never the agents list alone).
(String, AppStatusTone) _teamWatchBanner(
  AppLocalizations l10n,
  OrchestrationAgent? agent,
) {
  if (agent == null) {
    return (l10n.teamUiAgentOutputLive, AppStatusTone.progress);
  }
  final state = teamSessionState(agent);
  final word = teamAgentStateWord(l10n, state);
  final role = teamAgentRoleWord(l10n, teamAgentRole(agent));
  final name = teamAgentShortName(agent);
  final tone = switch (state) {
    AgentState.working => AppStatusTone.progress,
    AgentState.crashed => AppStatusTone.failure,
    // What it waits on is the conversation's own (a request card); the
    // line stays plain (LOOK-4).
    AgentState.waiting ||
    AgentState.blocked ||
    AgentState.idle ||
    AgentState.stopped ||
    AgentState.unknown => AppStatusTone.neutral,
  };
  return (
    name == null
        ? l10n.teamWatchBannerRole(role, word)
        : l10n.teamWatchBanner(name, role, word),
    tone,
  );
}

/// The newest of the team's records among [keys].
MutationRecord? _newestSent(OrchestrationController team, Set<String> keys) {
  MutationRecord? best;
  for (final record in team.mutations) {
    if (!keys.contains(record.key)) continue;
    if (best == null || record.createdAt.isAfter(best.createdAt)) {
      best = record;
    }
  }
  return best;
}

/// "Open conversation": the hook on the agent screen and the task
/// Overview. One row; opens the agent's own conversation (watching), or
/// Live output when there is none.
class TeamOpenConversationRow extends StatefulWidget {
  const TeamOpenConversationRow({
    super.key,
    required this.team,
    required this.agent,
    this.onOpen,
  });

  final OrchestrationController team;
  final OrchestrationAgent agent;

  /// Tests inject the opener; [openTeamAgentConversation] otherwise.
  final Future<void> Function(BuildContext context, OrchestrationAgent agent)?
  onOpen;

  @override
  State<TeamOpenConversationRow> createState() =>
      _TeamOpenConversationRowState();
}

class _TeamOpenConversationRowState extends State<TeamOpenConversationRow> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final open = widget.onOpen;
      if (open != null) {
        await open(context, widget.agent);
      } else {
        await openTeamAgentConversation(
          context,
          widget.agent,
          team: widget.team,
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final agent = widget.agent;
    final who =
        teamAgentShortName(agent) ??
        teamAgentRoleWord(l10n, teamAgentRole(agent));
    return KitRow(
      key: ValueKey('team-open-conversation-${agent.id}'),
      leading: KitRow.icon(context, AppIconography.chat),
      title: l10n.teamOpenConversation,
      supporting: TextSpan(
        text: _opening
            ? l10n.teamOpenConversationFinding
            : l10n.teamOpenConversationHint(who),
      ),
      trailing: const KitChevron(),
      onTap: _opening ? null : () => unawaited(_open()),
    );
  }
}

// ---------------------------------------------------------------------------
// An agent's live output, drawn as the chat draws a reply
// ---------------------------------------------------------------------------

/// Live output carries no tool output files.
Future<FilePreviewData> _noFilePreview(ToolOutputFile file) async =>
    FilePreviewData(name: file.displayName, text: '');

Future<void> _noFileAction(ToolOutputFile file, FilePreviewData data) async {}

/// An AI Team agent's live output (Live output, the fallback when its
/// OpenCode session cannot be read) drawn with the chat's own parts: what
/// the agent wrote is the reply's prose, and its `[tool: …]` calls are the
/// chat's tool lines, a run of them folded under one line. There is no
/// second renderer of work: the transcript becomes the chat's message
/// shape and the chat's message view draws it.
class TeamAgentTranscript extends StatefulWidget {
  const TeamAgentTranscript({
    super.key,
    required this.text,
    this.maxBlocks = 40,
  });

  /// The transcript as the host streams it.
  final String text;

  /// Blocks (what it said, or a run of calls) drawn; older ones are left
  /// out, as a long reply's beginning scrolls away.
  final int maxBlocks;

  @override
  State<TeamAgentTranscript> createState() => _TeamAgentTranscriptState();
}

class _TeamAgentTranscriptState extends State<TeamAgentTranscript> {
  final _expansion = <String, bool>{};

  @override
  Widget build(BuildContext context) {
    final blocks = parseAgentTranscript(widget.text);
    final first = math.max(0, blocks.length - widget.maxBlocks);
    final parts = <Part>[];
    for (var i = first; i < blocks.length; i++) {
      switch (blocks[i]) {
        case AgentProse(:final text):
          parts.add(
            Part(
              id: 'agent-output-$i',
              messageID: 'agent-output',
              type: 'text',
              text: text,
            ),
          );
        case AgentStepGroup(:final steps):
          for (var j = 0; j < steps.length; j++) {
            parts.add(_agentStepPart(steps[j], 'agent-output-$i-$j'));
          }
      }
    }
    final message = MessageWithParts(
      info: MessageInfo(
        id: 'agent-output',
        sessionID: 'agent-output',
        role: 'assistant',
        // Drawn finished: no tint on the newest words (the status line
        // above says whether it is live).
        time: MsgTime(completed: 1),
      ),
      parts: parts,
    );
    return _MessageView(
      key: const ValueKey('team-agent-transcript'),
      m: message,
      meta: const _MessageMeta(),
      parts: parts,
      reasoningExpanded: false,
      expansionStore: _expansion,
      showTimestamp: false,
      showActions: false,
      filePreviewLoader: _noFilePreview,
      onAttachFile: null,
      onDownloadFile: _noFileAction,
    );
  }
}

/// One `[tool: …]` call as the chat's tool part: a command is a shell
/// call, a file read or edit names its file, a search its pattern; its
/// output is what the call printed.
Part _agentStepPart(AgentStep step, String id) {
  final tool = step.tool.trim().toLowerCase();
  final (String name, Map<String, dynamic> input) = switch (step.kind) {
    AgentStepKind.command ||
    AgentStepKind.test => ('bash', {'command': step.command}),
    AgentStepKind.read => ('read', {'filePath': step.command}),
    AgentStepKind.edit => (
      const {
            'edit',
            'write',
            'patch',
            'apply_patch',
            'multiedit',
          }.contains(tool)
          ? tool
          : 'edit',
      {'filePath': step.command},
    ),
    AgentStepKind.search => switch (tool) {
      'list' || 'ls' => ('list', {'path': step.command}),
      'glob' => ('glob', {'pattern': step.command}),
      _ => ('grep', {'pattern': step.command}),
    },
    AgentStepKind.other => (tool, {'command': step.command}),
  };
  return Part(
    id: id,
    messageID: 'agent-output',
    type: 'tool',
    callID: id,
    toolName: name,
    toolState: ToolState(
      status: 'completed',
      title: step.command,
      input: input,
      output: step.output.isEmpty ? null : step.output,
    ),
  );
}
