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
  Timer? _tick;
  String? _runId;

  /// The last run and steps seen: a finished task leaves the team's open
  /// list, and its conversation keeps what it last showed.
  OrchestrationRun? _lastRun;
  List<WorkItem> _lastWork = const [];

  /// Message records sent from this page (their receipts show under them).
  final _sentHere = <String>{};
  bool _sending = false;

  /// A pending task waits this long before its Now line says it is slow and
  /// offers the team's page (map statesMissing "still planning after N min
  /// with an action").
  static const _pendingSlowAfter = Duration(minutes: 10);

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
        KitPageRoute<void>(
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
      KitPageRoute<void>(
        builder: (_) =>
            RunScreen(controller: _team, runId: runId, now: widget.now),
      ),
    ),
  );

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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _team,
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
            );
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
            teamHostPhrase(l10n, _team, working: working),
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
          menu: [
            if (run != null) ...[
              KitMenuItem(
                key: const ValueKey('team-conversation-details'),
                label: l10n.teamChatTaskDetails,
                icon: AppIconography.info,
                onSelected: () => _openDetails(run.id),
              ),
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
          _TeamNowLine(
            team: _team,
            now: now,
            pending: run == null && !gone ? widget.pending : null,
            clock: _clock,
            slowAfter: _pendingSlowAfter,
            onOpenTeam: _openTeamPage,
          ),
          if (run != null && agents.isNotEmpty)
            KitAgentStrip(
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
  }) {
    final l10n = _chatL10n(context);
    final tokens = KitTokens.of(context);
    final prompt = [
      title,
      ?(run == null ? widget.pending?.details : _runDetails(run, work)),
    ].where((t) => t.trim().isNotEmpty).join('\n\n');
    final phase = _phase(run, gates, pendingRecord);
    final leadRows = _TeamLeadReply.rowsFor(
      context,
      lines: lines,
      pending: run == null ? widget.pending : null,
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
    final now = _clock();
    // The end padding is read under the composer layer, which adds its
    // height to the bottom inset.
    return Builder(
      builder: (context) => ListView(
        key: const ValueKey('team-conversation-list'),
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
              if (work.isNotEmpty)
                _TeamSteps(work: work, expansion: _expansion),
              for (final agent in agents)
                KitToolRow.agent(
                  rowKey: ValueKey('team-conversation-agent-${agent.id}'),
                  title: _teamAgentTitle(l10n, agent),
                  status: _teamAgentToolStatus(agent),
                  task: [
                    for (final item in work)
                      if (item.id == agent.currentWorkId) item.title,
                  ].firstOrNull,
                  startedAt:
                      teamSessionState(agent) == AgentState.working &&
                          agent.sessionStartedAt != null &&
                          !agent.sessionStartedAt!.isAfter(now)
                      ? agent.sessionStartedAt
                      : null,
                  openLabel: l10n.teamOpenConversation,
                  onOpen: () => unawaited(_openAgent(agent)),
                ),
              for (final gate in gates)
                TeamNeedsYouCard(
                  keyPrefix: 'team-conversation-gate-${gate.id}',
                  controller: _team,
                  gate: gate,
                  title: teamGateWho(l10n, _team.snapshot, gate),
                  onOpen: () => unawaited(
                    showGateSheet(context, _team, gate.id, now: widget.now),
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
          if (run != null)
            Padding(
              padding: EdgeInsetsDirectional.only(top: tokens.space4),
              child: TeamMergeSection(
                controller: _team,
                run: run,
                now: widget.now,
              ),
            ),
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
  }) {
    final l10n = _chatL10n(context);
    String at(DateTime? time) =>
        time == null ? '' : ' · ${teamClockLabel(context, time)}';
    return [
      if (pending case final task?)
        '${l10n.teamChatLeadSent}${at(task.sentAt)}',
      for (final line in lines) '${teamLeadSentence(l10n, line)}${at(line.at)}',
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
/// Honest after 8 s: a team that does not answer says so, with Retry. A
/// task the team has not picked up after [slowAfter] says so and offers
/// the team's page.
class _TeamNowLine extends StatelessWidget {
  const _TeamNowLine({
    required this.team,
    required this.now,
    required this.pending,
    required this.clock,
    required this.slowAfter,
    required this.onOpenTeam,
  });

  final OrchestrationController team;
  final TeamNow? now;
  final TeamPendingTask? pending;
  final DateTime Function() clock;
  final Duration slowAfter;
  final VoidCallback onOpenTeam;

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final waiting =
        !team.snapshot.hasData ||
        // Not answering only: a paused team answers, and says so itself.
        teamHostCondition(l10n, team, working: true) != null;
    return GraceTimer(
      waiting: waiting,
      grace: KitMotion.escalateAfter,
      builder: (context, overdue) {
        final line = _line(context, overdue && waiting);
        return KitReveal(child: line);
      },
    );
  }

  Widget? _line(BuildContext context, bool overdue) {
    final l10n = _chatL10n(context);
    Duration waited(DateTime at) {
      final span = clock().difference(at);
      return span.isNegative ? Duration.zero : span;
    }

    String since(DateTime? at) =>
        at == null ? '' : teamElapsedLabel(l10n, waited(at));

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
        // A degraded state, never the attention look (LOOK-4): the error
        // line's neutral glyph, and the fix as its action.
        tone: AppStatusTone.failure,
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
      if (waited(task.sentAt) >= slowAfter) {
        return status(
          l10n.teamChatNowPendingSlow(since(task.sentAt)),
          tone: AppStatusTone.neutral,
          icon: AppIconography.waiting,
          action: KitAction(
            key: const ValueKey('team-conversation-pending-team-page'),
            label: l10n.teamChatOpenTeam,
            onPressed: onOpenTeam,
          ),
        );
      }
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
        tone: AppStatusTone.neutral,
        icon: AppIconography.question,
      ),
      TeamNowKind.stalled => status(
        [
          if (now.stall case final stall?) teamCycleStallSentence(l10n, stall),
          if (now.since != null) since(now.since),
        ].join(' · '),
        tone: AppStatusTone.neutral,
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
  const _TeamSteps({required this.work, required this.expansion});

  final List<WorkItem> work;
  final Map<String, bool> expansion;

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
      KitPageRoute<void>(
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
    KitPageRoute<void>(
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
  // Typed words survive a swipe or back (DATA-2): kept per agent and server
  // profile until they are sent.
  String? profileId;
  try {
    profileId = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(connProvider).profile?.id;
  } catch (_) {
    profileId = null;
  }
  final text = TextEditingController();
  final draft = profileId == null || profileId.isEmpty
      ? null
      : KitDraft(
          target: 'team-message.${agent.id}',
          profileId: profileId,
          controller: text,
        );
  try {
    await showKitSheet<void>(
      context,
      title: l10n.teamUiControlMessageTitle(
        teamAgentShortName(agent) ??
            teamAgentRoleWord(l10n, teamAgentRole(agent)),
      ),
      sheetKey: const ValueKey('chat-watching-message-sheet'),
      draft: draft,
      body: (_) => _TeamMessageSheet(
        team: team,
        agent: agent,
        controller: text,
        draft: draft,
      ),
    );
  } finally {
    text.dispose();
  }
}

/// The message field for one agent: Send goes through the team's message
/// control, and the sheet stays open with the message's receipt in words
/// ("Message · Sent", then Confirmed or the host's reason) until the person
/// closes it.
class _TeamMessageSheet extends StatefulWidget {
  const _TeamMessageSheet({
    required this.team,
    required this.agent,
    required this.controller,
    required this.draft,
  });

  final OrchestrationController team;
  final OrchestrationAgent agent;

  /// Owned by the caller, which disposes it after the sheet closes.
  final TextEditingController controller;
  final KitDraft? draft;

  @override
  State<_TeamMessageSheet> createState() => _TeamMessageSheetState();
}

class _TeamMessageSheetState extends State<_TeamMessageSheet> {
  TextEditingController get _text => widget.controller;
  String? _sentKey;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
  }

  @override
  void dispose() {
    _text.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final record = await widget.team.messageAgent(widget.agent.id, text);
      if (!mounted) return;
      _text.clear();
      unawaited(widget.draft?.clear());
      setState(() => _sentKey = record.key);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _chatL10n(context);
    final tokens = KitTokens.of(context);
    final canSend = !_sending && _text.text.trim().isNotEmpty;
    return ListenableBuilder(
      listenable: widget.team,
      builder: (context, _) {
        final sent = _sentKey == null
            ? null
            : widget.team.mutations
                  .where((record) => record.key == _sentKey)
                  .firstOrNull;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KitField(
              label: l10n.teamUiControlMessageHint,
              controller: _text,
              kind: KitFieldKind.multiline,
              autofocus: true,
              enabled: !_sending,
              fieldKey: const ValueKey('chat-watching-message-field'),
              actionKey: const ValueKey('chat-watching-message-send'),
              action: KitAction(
                label: l10n.teamUiControlMessageSend,
                icon: AppIconography.send,
                onPressed: canSend ? () => unawaited(_send()) : null,
              ),
            ),
            if (sent != null) ...[
              SizedBox(height: tokens.space3),
              _teamReceipt(
                context,
                sent,
                key: const ValueKey('chat-watching-message-receipt'),
                onRetry: () => widget.team.retryMutation(sent.key),
              ),
            ],
          ],
        );
      },
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
