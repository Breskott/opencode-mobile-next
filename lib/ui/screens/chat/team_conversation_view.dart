part of '../chat_screen.dart';

// The AI Team as a conversation (docs/design/team-conversation-2026-09-26.md):
// a task is a conversation, its workers are its sub-agents. The team's own
// data is assembled into the chat's parts (option A): your prompt is the
// task, the lead's reply is written by the app from real team events
// (`teamLeadLines`), each worker or reviewer is a sub-agent card that opens
// its real OpenCode session in watching mode, the family strip lists them,
// gates are the request cards, merge is the existing merge section, one
// "Now" line says what happens next, and the composer's words go through
// the team's own message control.

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

  @override
  State<TeamConversationScreen> createState() => _TeamConversationScreenState();
}

class _TeamConversationScreenState extends State<TeamConversationScreen> {
  final _expansion = <String, bool>{};
  final _message = TextEditingController();
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

  @override
  void initState() {
    super.initState();
    _runId = widget.runId;
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
    _message.dispose();
    super.dispose();
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
    if (found != null && mounted) setState(() => _runId = found);
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
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openAgent(OrchestrationAgent agent) {
    final open = widget.onOpenAgent;
    if (open != null) return open(context, agent);
    return openTeamAgentConversation(context, agent, team: _team);
  }

  /// The team's home, over this conversation. Its row for this same task
  /// comes back here rather than stacking a second copy of the page;
  /// another task opens its own conversation.
  void _openTeamPage() {
    final here = ModalRoute.of(context);
    unawaited(
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TeamHomeScreen(
            controller: _team,
            now: widget.now,
            onOpenRun: (run) {
              if (!mounted) return;
              if (run.id == _runId && here != null) {
                Navigator.of(context).popUntil((route) => route == here);
                return;
              }
              unawaited(TeamConversation.open(context, _team, runId: run.id));
            },
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

  void _openDetails(String runId) => unawaited(
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            RunScreen(controller: _team, runId: runId, now: widget.now),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _team,
    builder: (context, _) {
      final l10n = _chatL10n(context);
      final theme = Theme.of(context);
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
            );
      final title = run?.title ?? widget.pending?.title ?? '';
      final recipient = _recipient(agents);
      final loading =
          _team.phase != OrchestrationPhase.ready || !snapshot.hasData;
      return Scaffold(
        key: const ValueKey('team-conversation'),
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty ? l10n.teamChatUntitled : title,
                key: const ValueKey('team-conversation-title'),
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                l10n.teamChatSubtitle(
                  // Never "Paused" while this task's worker starts or works:
                  // the task's own state and its agents' sessions say so.
                  teamHostPhrase(
                    l10n,
                    _team,
                    working:
                        agents.any(
                          (agent) =>
                              teamSessionState(agent) == AgentState.working,
                        ) ||
                        switch (now?.kind) {
                          TeamNowKind.starting ||
                          TeamNowKind.working ||
                          TeamNowKind.review => true,
                          _ => false,
                        },
                  ),
                ),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.mutedOf(theme),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            IconButton(
              key: const ValueKey('team-conversation-team-page'),
              tooltip: l10n.teamChatOpenTeam,
              icon: const Icon(AppIconography.agent),
              onPressed: _openTeamPage,
            ),
            if (run != null)
              KitRowMenu(
                key: const ValueKey('team-conversation-menu'),
                items: [
                  KitMenuItem(
                    key: const ValueKey('team-conversation-details'),
                    label: l10n.teamChatTaskDetails,
                    onSelected: () => _openDetails(run.id),
                  ),
                  // Only while the task runs and this host can stop it.
                  if (_canStop(run))
                    KitMenuItem(
                      key: const ValueKey('team-conversation-stop'),
                      label: l10n.teamChatStopTask,
                      destructive: true,
                      onSelected: () => unawaited(_stop(run)),
                    ),
                ],
              ),
          ],
        ),
        body: Column(
          children: [
            KitLoadingBar(loading: loading, label: l10n.teamChatLoading),
            _TeamNowLine(
              team: _team,
              now: now,
              pending: run == null ? widget.pending : null,
              clock: _clock,
            ),
            if (run != null && agents.isNotEmpty)
              _TeamFamilyStrip(
                run: run,
                agents: agents,
                onOpen: (agent) => unawaited(_openAgent(agent)),
              ),
            Expanded(
              child: ListView(
                key: const ValueKey('team-conversation-list'),
                padding: const EdgeInsets.fromLTRB(6, 10, 6, 16),
                children: [
                  _MessageView(
                    key: const ValueKey('team-conversation-prompt'),
                    m: _teamMessage(
                      'team-prompt',
                      'user',
                      [
                        title,
                        ?(run == null
                            ? widget.pending?.details
                            : _runDetails(run, work)),
                      ].where((t) => t.trim().isNotEmpty).join('\n\n'),
                      run?.startedAt ?? widget.pending?.sentAt,
                    ),
                    meta: const _MessageMeta(),
                    parts: _teamMessage(
                      'team-prompt',
                      'user',
                      [
                        title,
                        ?(run == null
                            ? widget.pending?.details
                            : _runDetails(run, work)),
                      ].where((t) => t.trim().isNotEmpty).join('\n\n'),
                      null,
                    ).parts,
                    reasoningExpanded: false,
                    expansionStore: _expansion,
                    showTimestamp: false,
                    showActions: false,
                    filePreviewLoader: _noFilePreview,
                    onAttachFile: null,
                    onDownloadFile: _noFileAction,
                  ),
                  const SizedBox(height: 12),
                  _TeamLeadReply(
                    lines: lines,
                    pending: run == null ? widget.pending : null,
                    expansion: _expansion,
                  ),
                  if (work.isNotEmpty)
                    _TeamStepsFold(
                      work: work,
                      now: _clock(),
                      expansion: _expansion,
                    ),
                  for (final agent in agents)
                    _TeamAgentLine(
                      agent: agent,
                      work: [
                        for (final item in work)
                          if (item.id == agent.currentWorkId) item,
                      ].firstOrNull,
                      now: _clock(),
                      onOpen: () => unawaited(_openAgent(agent)),
                    ),
                  for (final record in _team.mutations)
                    if (_sentHere.contains(record.key) ||
                        (record.kind == MutationKind.message &&
                            agents.any((a) => a.id == record.targetId) &&
                            (run?.startedAt == null ||
                                !record.createdAt.isBefore(run!.startedAt!))))
                      _TeamSentMessage(record: record, expansion: _expansion),
                  for (final gate in gates)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
                      child: TeamNeedsYouCard(
                        keyPrefix: 'team-conversation-gate-${gate.id}',
                        controller: _team,
                        gate: gate,
                        title: teamGateKindWord(
                          lookupAppLocalizations(
                            Localizations.localeOf(context),
                          ),
                          gate.kind,
                        ),
                        onOpen: () => unawaited(
                          showGateSheet(
                            context,
                            _team,
                            gate.id,
                            now: widget.now,
                          ),
                        ),
                      ),
                    ),
                  if (run == null
                          ? null
                          : _team.latestMutation(
                              kind: MutationKind.cancelRun,
                              targetId: run.id,
                            )
                      case final stop?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TeamReceiptChip(
                        key: const ValueKey('team-conversation-stop-receipt'),
                        record: stop,
                        control: l10n.teamChatStopTask,
                        onRetry: () async {
                          await _team.retryMutation(stop.key);
                        },
                      ),
                    ),
                  if (run != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 0),
                      child: TeamMergeSection(
                        controller: _team,
                        run: run,
                        now: widget.now,
                      ),
                    ),
                ],
              ),
            ),
            _TeamChatComposer(
              controller: _message,
              recipient: recipient,
              canMessage: _team.capabilities.controlMessage,
              sending: _sending,
              onSend: recipient == null
                  ? null
                  : () => unawaited(_send(recipient)),
            ),
          ],
        ),
      );
    },
  );

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

/// The app's own messages carry no tool output files.
Future<FilePreviewData> _noFilePreview(ToolOutputFile file) async =>
    FilePreviewData(name: file.displayName, text: '');

Future<void> _noFileAction(ToolOutputFile file, FilePreviewData data) async {}

/// A message the app writes itself (the task prompt, the lead's reply),
/// in the chat's own message shape so the chat's renderer draws it.
MessageWithParts _teamMessage(
  String id,
  String role,
  String text,
  DateTime? at,
) {
  final ms = at?.millisecondsSinceEpoch;
  return MessageWithParts(
    info: MessageInfo(
      id: id,
      sessionID: 'team',
      role: role,
      // Always finished: the app wrote it whole, so it never wears the
      // tint of a reply still being written.
      time: MsgTime(created: ms, completed: ms ?? 1),
    ),
    parts: [Part(id: '$id-text', messageID: id, type: 'text', text: text)],
  );
}

/// The lead's reply, read like any reply in the chat: one plain line per
/// real team event with its time, on the prose's edge, no frame or fill.
/// When there are many, the earlier ones fold under one line (the chat's
/// fold) and the newest stay in view.
class _TeamLeadReply extends StatefulWidget {
  const _TeamLeadReply({
    required this.lines,
    required this.pending,
    required this.expansion,
  });

  final List<TeamLeadLine> lines;
  final TeamPendingTask? pending;
  final Map<String, bool> expansion;

  /// Up to this many lines show unfolded; beyond it, all but the newest
  /// [_kept] fold.
  static const _openUpTo = 3;
  static const _kept = 2;
  static const _storeKey = 'team-lead-earlier';

  @override
  State<_TeamLeadReply> createState() => _TeamLeadReplyState();
}

class _TeamLeadReplyState extends State<_TeamLeadReply> {
  bool get _expanded => widget.expansion[_TeamLeadReply._storeKey] ?? false;

  Widget _reply(String id, List<String> rows) {
    final message = _teamMessage(id, 'assistant', rows.join('\n\n'), null);
    return _MessageView(
      m: message,
      meta: const _MessageMeta(),
      parts: message.parts,
      reasoningExpanded: false,
      expansionStore: widget.expansion,
      showTimestamp: false,
      showActions: false,
      filePreviewLoader: _noFilePreview,
      onAttachFile: null,
      onDownloadFile: _noFileAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    String at(DateTime? time) =>
        time == null ? '' : ' · ${teamClockLabel(context, time)}';
    final rows = <String>[
      if (widget.pending case final task?)
        '${l10n.teamChatLeadSent}${at(task.sentAt)}',
      for (final line in widget.lines)
        '${teamLeadSentence(l10n, line)}${at(line.at)}',
    ];
    final fold = rows.length > _TeamLeadReply._openUpTo;
    final earlier = fold
        ? rows.sublist(0, rows.length - _TeamLeadReply._kept)
        : const <String>[];
    final recent = fold
        ? rows.sublist(rows.length - _TeamLeadReply._kept)
        : rows;
    return Column(
      key: const ValueKey('team-conversation-lead'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 10, 0),
          child: Text(
            l10n.teamChatLeadName,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppTheme.mutedOf(Theme.of(context)),
            ),
          ),
        ),
        if (fold)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
            child: _FoldLine(
              headerKey: const ValueKey('team-conversation-lead-earlier'),
              icon: AppIconography.timeline,
              title: l10n.teamChatLeadEarlier(earlier.length),
              expanded: _expanded,
              onTap: () => setState(
                () => widget.expansion[_TeamLeadReply._storeKey] = !_expanded,
              ),
            ),
          ),
        if (fold && _expanded)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
            child: _FoldSteps(
              key: const ValueKey('team-conversation-lead-earlier-lines'),
              children: [_reply('team-lead-earlier', earlier)],
            ),
          ),
        _reply(
          'team-lead',
          recent.isEmpty ? [l10n.teamChatLeadNothingYet] : recent,
        ),
      ],
    );
  }
}

/// The lead's words for one line (see [TeamLeadEvent]).
String teamLeadSentence(AppLocalizations l10n, TeamLeadLine line) {
  final title = line.workTitle ?? '';
  final name = line.agentName;
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

/// The one status line: what is happening now and what happens next.
/// Honest after 8 s: a team that does not answer says so, with Retry.
class _TeamNowLine extends StatelessWidget {
  const _TeamNowLine({
    required this.team,
    required this.now,
    required this.pending,
    required this.clock,
  });

  final OrchestrationController team;
  final TeamNow? now;
  final TeamPendingTask? pending;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final waiting =
        !team.snapshot.hasData ||
        // Not answering only: a paused team answers, and says so itself.
        teamHostCondition(l10n, team, working: true) != null;
    return GraceTimer(
      waiting: waiting,
      grace: const Duration(seconds: 8),
      builder: (context, overdue) {
        final line = _line(context, overdue && waiting);
        return KitReveal(child: line);
      },
    );
  }

  Widget? _line(BuildContext context, bool overdue) {
    final l10n = _chatL10n(context);
    String since(DateTime? at) {
      if (at == null) return '';
      final waited = clock().difference(at);
      return teamElapsedLabel(l10n, waited.isNegative ? Duration.zero : waited);
    }

    KitStatusLine status(
      String message, {
      AppStatusTone tone = AppStatusTone.progress,
      IconData icon = AppIconography.statusDot,
      KitAction? action,
    }) => KitStatusLine(
      key: const ValueKey('team-conversation-now'),
      messageKey: const ValueKey('team-conversation-now-text'),
      icon: icon,
      tone: tone,
      message: message,
      action: action,
    );

    if (overdue) {
      return status(
        l10n.teamChatNowNotAnswering,
        tone: AppStatusTone.attention,
        icon: AppIconography.cloudOff,
        action: KitAction(
          key: const ValueKey('team-conversation-retry'),
          label: l10n.commonRetry,
          onPressed: () => unawaited(
            team.phase == OrchestrationPhase.failed
                ? team.retry()
                : team.refresh(),
          ),
        ),
      );
    }
    final task = pending;
    if (task != null) {
      return status(l10n.teamChatNowPending(since(task.sentAt)));
    }
    final now = this.now;
    if (now == null) return null;
    final onPhone =
        (team.host?.hostMode ?? team.config.hostMode) ==
        OrchestrationHostMode.phone;
    final name = now.agentName;
    return switch (now.kind) {
      TeamNowKind.finished => status(
        l10n.teamChatNowFinished,
        tone: AppStatusTone.ok,
        icon: AppIconography.check,
      ),
      TeamNowKind.needsYou => status(
        l10n.teamChatNowNeedsYou(now.gateTitle ?? ''),
        tone: AppStatusTone.attention,
        icon: AppIconography.question,
      ),
      TeamNowKind.stalled => status(
        [
          if (now.stall case final stall?)
            teamCycleStallSentence(
              lookupAppLocalizations(Localizations.localeOf(context)),
              stall,
            ),
          if (now.since != null) since(now.since),
        ].join(' · '),
        tone: AppStatusTone.attention,
        icon: AppIconography.waiting,
      ),
      TeamNowKind.waitingForWorker => status(
        l10n.teamChatNowWaitingForWorker(since(now.since)),
      ),
      TeamNowKind.starting => status(
        onPhone
            ? l10n.teamChatNowStartingPhone(
                name ?? l10n.teamChatAWorker,
                since(now.since),
              )
            : l10n.teamChatNowStarting(
                name ?? l10n.teamChatAWorker,
                since(now.since),
              ),
      ),
      TeamNowKind.working => status(
        l10n.teamChatNowWorking(
          name ?? l10n.teamChatAWorker,
          now.workTitle ?? '',
          since(now.since),
        ),
      ),
      TeamNowKind.review => status(l10n.teamChatNowReview(since(now.since))),
    };
  }
}

/// The mark for an agent, from its session (the truth about whether it
/// runs, not the host's agent list).
KitMarkState _teamAgentMark(OrchestrationAgent agent) =>
    switch (teamSessionState(agent)) {
      AgentState.working => KitMarkState.working,
      AgentState.crashed => KitMarkState.failed,
      AgentState.stopped => KitMarkState.done,
      AgentState.idle ||
      AgentState.waiting ||
      AgentState.blocked ||
      AgentState.unknown => KitMarkState.waiting,
    };

/// "furiosa · Worker": the agent's own name, then its role in plain words.
String _teamAgentTitle(AppLocalizations l10n, OrchestrationAgent agent) {
  final role = teamAgentRoleWord(l10n, teamAgentRole(agent));
  final name = teamAgentShortName(agent);
  return name == null ? role : '$name · $role';
}

/// The family strip: the lead, then every worker and reviewer on this
/// task, each with its mark; a tap opens that agent's conversation.
class _TeamFamilyStrip extends StatelessWidget {
  const _TeamFamilyStrip({
    required this.run,
    required this.agents,
    required this.onOpen,
  });

  final OrchestrationRun run;
  final List<OrchestrationAgent> agents;
  final ValueChanged<OrchestrationAgent> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final team = lookupAppLocalizations(Localizations.localeOf(context));
    final leadMark = switch (run.state) {
      RunState.completed => KitMarkState.done,
      RunState.failed => KitMarkState.failed,
      RunState.cancelled => KitMarkState.done,
      _ => KitMarkState.working,
    };
    Widget chip({
      required Key key,
      required KitMarkState mark,
      required String label,
      required String semantics,
      VoidCallback? onTap,
    }) => Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Semantics(
        button: onTap != null,
        label: semantics,
        excludeSemantics: true,
        child: InkWell(
          key: key,
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsetsDirectional.fromSTEB(2, 0, 12, 0),
            decoration: ShapeDecoration(
              shape: StadiumBorder(
                side: BorderSide(color: AppTheme.hairline(Theme.of(context))),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(scale: .8, child: KitStatusMark(state: mark)),
                Text(label, style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
          ),
        ),
      ),
    );
    String word(KitMarkState mark) => switch (mark) {
      KitMarkState.working => l10n.teamChatFamilyRunning,
      KitMarkState.waiting => l10n.teamChatFamilyWaiting,
      KitMarkState.done => l10n.teamChatFamilyDone,
      KitMarkState.failed => l10n.teamChatFamilyFailed,
    };
    return SizedBox(
      height: 52,
      child: ListView(
        key: const ValueKey('team-conversation-family'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          chip(
            key: const ValueKey('team-conversation-family-lead'),
            mark: leadMark,
            label: l10n.teamChatLeadName,
            semantics: '${l10n.teamChatLeadName}, ${word(leadMark)}',
          ),
          for (final agent in agents)
            chip(
              key: ValueKey('team-conversation-family-${agent.id}'),
              mark: _teamAgentMark(agent),
              label:
                  teamAgentShortName(agent) ??
                  teamAgentRoleWord(team, teamAgentRole(agent)),
              semantics:
                  '${_teamAgentTitle(team, agent)}, '
                  '${word(_teamAgentMark(agent))}',
              onTap: () => onOpen(agent),
            ),
        ],
      ),
    );
  }
}

/// The task's steps with the Overview's marks; folded under one line when
/// there are more than three.
class _TeamStepsFold extends StatelessWidget {
  const _TeamStepsFold({
    required this.work,
    required this.now,
    required this.expansion,
  });

  final List<WorkItem> work;
  final DateTime now;
  final Map<String, bool> expansion;

  static const _openUpTo = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final team = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final done = work.where((item) => item.state == WorkState.completed).length;
    final rows = [
      for (final item in work)
        KitRow(
          key: ValueKey('team-conversation-step-${item.id}'),
          leading: KitRow.icon(
            context,
            teamWorkGlyph(item.state).$1,
            color: AppTheme.statusColor(theme, teamWorkGlyph(item.state).$2),
          ),
          title: item.title,
          titleMaxLines: 2,
          supporting: TextSpan(text: teamWorkStateWord(team, item.state)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
    ];
    final summary = l10n.teamChatStepsSummary(work.length, done);
    if (work.length <= _openUpTo) {
      return Padding(
        key: const ValueKey('team-conversation-steps'),
        padding: const EdgeInsets.only(top: 4),
        child: Column(children: rows),
      );
    }
    return Padding(
      key: const ValueKey('team-conversation-steps'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: KitExpandRow(
        headerKey: const ValueKey('team-conversation-steps-fold'),
        leading: KitRow.icon(context, AppIconography.checklist),
        title: summary,
        children: rows,
      ),
    );
  }
}

/// One worker or reviewer as the chat draws a sub-agent: one line of the
/// reply on the prose's edge, no frame or fill (as [ToolCard] draws a
/// `task` call). Who it is, what it works on, its state from its session
/// and for how long; a tap opens its conversation.
class _TeamAgentLine extends StatelessWidget {
  const _TeamAgentLine({
    required this.agent,
    required this.work,
    required this.now,
    required this.onOpen,
  });

  final OrchestrationAgent agent;
  final WorkItem? work;
  final DateTime now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final team = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final state = teamSessionState(agent);
    final started = agent.sessionStartedAt;
    final elapsed = started == null
        ? null
        : teamElapsedLabel(
            team,
            now.difference(started).isNegative
                ? Duration.zero
                : now.difference(started),
          );
    // The state and how long, where a sub-agent call shows its state.
    final line = [
      teamAgentStateWord(team, state),
      ?elapsed,
    ].join(teamUsageSeparator);
    final title = _teamAgentTitle(team, agent);
    final mark = _teamAgentMark(agent);
    final (markIcon, markColor) = switch (mark) {
      KitMarkState.working => (
        AppIconography.waitingStart,
        theme.colorScheme.primary,
      ),
      KitMarkState.done => (
        AppIconography.checkCircle,
        AppTheme.successOf(theme),
      ),
      KitMarkState.failed => (AppIconography.error, theme.colorScheme.error),
      KitMarkState.waiting => (
        AppIconography.waiting,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6, 4, 6, 0),
      child: Semantics(
        button: true,
        label: [title, ?work?.title, line].join(', '),
        hint: l10n.teamOpenConversation,
        excludeSemantics: true,
        child: InkWell(
          key: ValueKey('team-conversation-agent-${agent.id}'),
          onTap: onOpen,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              // The prose's inset, as a sub-agent call on its own.
              padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 8),
              child: Row(
                children: [
                  Icon(
                    AppIconography.agent,
                    size: 16,
                    color: AppTheme.mutedOf(theme),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TitleWithDetail(
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: .9,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      detail: work == null
                          ? null
                          : Text(
                              work!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      line,
                      key: ValueKey('team-conversation-agent-line-${agent.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(markIcon, size: 14, color: markColor),
                  const SizedBox(width: 4),
                  Icon(
                    AppIconography.chevronRight,
                    size: 16,
                    color: AppTheme.mutedOf(theme),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A message the person sent the team, with what became of it.
class _TeamSentMessage extends StatelessWidget {
  const _TeamSentMessage({required this.record, required this.expansion});

  final MutationRecord record;
  final Map<String, bool> expansion;

  @override
  Widget build(BuildContext context) {
    final message = _teamMessage(
      'team-sent-${record.key}',
      'user',
      record.request.text ?? '',
      record.createdAt,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MessageView(
            m: message,
            meta: const _MessageMeta(),
            parts: message.parts,
            reasoningExpanded: false,
            expansionStore: expansion,
            showTimestamp: false,
            showActions: false,
            filePreviewLoader: _noFilePreview,
            onAttachFile: null,
            onDownloadFile: _noFileAction,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 16, top: 4),
            child: TeamReceiptChip(
              key: ValueKey('team-conversation-sent-${record.key}'),
              record: record,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Message the team…": the words go through the team's own message
/// control to the worker on the task (or the planner), never typed into a
/// worker's OpenCode session.
class _TeamChatComposer extends StatelessWidget {
  const _TeamChatComposer({
    required this.controller,
    required this.recipient,
    required this.canMessage,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final OrchestrationAgent? recipient;
  final bool canMessage;
  final bool sending;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final team = lookupAppLocalizations(Localizations.localeOf(context));
    final theme = Theme.of(context);
    final to = recipient;
    final note = !canMessage
        ? l10n.teamChatComposerCannot
        : to == null
        ? l10n.teamChatComposerNobody
        : l10n.teamChatComposerGoesTo(_teamAgentTitle(team, to));
    return SafeArea(
      top: false,
      child: Padding(
        key: const ValueKey('team-conversation-composer'),
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (canMessage && to != null)
              TeamComposerField(
                controller: controller,
                hint: l10n.teamChatComposerHint,
                sendLabel: l10n.chatUiSend,
                autofocus: false,
                enabled: !sending,
                onSend: onSend ?? () {},
                fieldKey: const ValueKey('team-conversation-field'),
                sendKey: const ValueKey('team-conversation-send'),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                note,
                key: const ValueKey('team-conversation-composer-note'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.mutedOf(theme),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

/// Opens [agent]'s own OpenCode session on the chat page in watching mode:
/// the session in its work folder, newest since the agent's session began
/// ([findTeamAgentSession]). When there is none on the connected server
/// (a team on a computer, a worker still starting) Live output opens
/// instead with a line saying why.
Future<void> openTeamAgentConversation(
  BuildContext context,
  OrchestrationAgent agent, {
  OrchestrationController? team,
  TeamAgentConversationLookup? lookup,
}) async {
  final navigator = Navigator.of(context);
  final found = lookup ?? await lookupTeamAgentConversation(context, agent);
  final sessionId = found.sessionId;
  final miss = found.miss;
  if (!context.mounted) return;
  final controller = team ?? _teamOf(context);
  if (sessionId case final id?) {
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (context) => ChatScreen(
          sessionID: id,
          watch: teamAgentWatch(context, agent, team: controller),
        ),
      ),
    );
    return;
  }
  if (controller == null) return;
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (context) => AgentOutputScreen(
        controller: controller,
        agentId: agent.id,
        note: teamAgentConversationMissNote(
          context,
          miss ?? TeamAgentConversationMiss.notFound,
        ),
      ),
    ),
  );
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

/// The watching-mode setup for [agent]: the banner in plain words and the
/// one "Message the worker" action, which goes through the team's message
/// control ([OrchestrationController.messageAgent]).
ChatWatch teamAgentWatch(
  BuildContext context,
  OrchestrationAgent agent, {
  OrchestrationController? team,
}) {
  final l10n = _chatL10n(context);
  final role = teamAgentRole(agent);
  final roleWord = teamAgentRoleWord(l10n, role);
  final name = teamAgentShortName(agent);
  final canMessage = team != null && team.capabilities.controlMessage;
  return ChatWatch(
    banner: name == null
        ? l10n.teamWatchBannerRole(roleWord)
        : l10n.teamWatchBanner(name, roleWord),
    note: canMessage ? l10n.teamWatchNote : l10n.teamWatchNoteNoMessage,
    messageLabel: role == TeamAgentRole.worker
        ? l10n.teamWatchMessageWorker
        : l10n.teamWatchMessageAgent,
    onMessage: !canMessage
        ? null
        : (context) => _messageTeamAgent(context, team, agent),
  );
}

Future<void> _messageTeamAgent(
  BuildContext context,
  OrchestrationController team,
  OrchestrationAgent agent,
) async {
  final l10n = _chatL10n(context);
  final text = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TeamMessageSheet(
      title: l10n.teamUiControlMessageTitle(
        teamAgentShortName(agent) ??
            teamAgentRoleWord(l10n, teamAgentRole(agent)),
      ),
    ),
  );
  if (text == null || text.trim().isEmpty || !context.mounted) return;
  final record = await team.messageAgent(agent.id, text.trim());
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      key: const ValueKey('chat-watching-message-receipt'),
      content: Text(
        record.status == MutationStatus.rejected
            ? teamReceiptLine(l10n, record)
            : '${teamControlWord(l10n, record.request)} · '
                  '${teamControlReceiptWord(l10n, record.status)}',
      ),
    ),
  );
}

/// The composer field alone; Send pops with the text (as the agent
/// screen's Message sheet).
class _TeamMessageSheet extends StatefulWidget {
  const _TeamMessageSheet({required this.title});

  final String title;

  @override
  State<_TeamMessageSheet> createState() => _TeamMessageSheetState();
}

class _TeamMessageSheetState extends State<_TeamMessageSheet> {
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
    final l10n = _chatL10n(context);
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      key: const ValueKey('chat-watching-message-sheet'),
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TeamComposerField(
            controller: _text,
            hint: l10n.teamUiControlMessageHint,
            sendLabel: l10n.teamUiControlMessageSend,
            onSend: _send,
            fieldKey: const ValueKey('chat-watching-message-field'),
            sendKey: const ValueKey('chat-watching-message-send'),
          ),
        ],
      ),
    );
  }
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
      trailing: Icon(
        AppIconography.chevronRight,
        size: 18,
        color: AppTheme.mutedOf(Theme.of(context)),
      ),
      onTap: _opening ? null : () => unawaited(_open()),
    );
  }
}

// ---------------------------------------------------------------------------
// An agent's live output, drawn as the chat draws a reply
// ---------------------------------------------------------------------------

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
