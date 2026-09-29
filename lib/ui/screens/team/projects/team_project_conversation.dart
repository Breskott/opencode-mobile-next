import 'package:flutter/material.dart';

import '../../../../domain/relative_age.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../state/team_project_controller.dart';
import '../../../kit/kit.dart';

/// Finish line: review, steer, verify and promote a task from its conversation.
/// Non-goal: choosing or directly calling an execution engine.
class TeamProjectConversation extends StatefulWidget {
  const TeamProjectConversation({
    super.key,
    required this.controller,
    required this.projectId,
    required this.taskId,
    this.embedded = false,
  });
  final TeamProjectController controller;
  final String projectId;
  final String taskId;
  final bool embedded;
  @override
  State<TeamProjectConversation> createState() =>
      _TeamProjectConversationState();
}

class _TeamProjectConversationState extends State<TeamProjectConversation> {
  final _message = TextEditingController();
  final _focus = FocusNode();
  final _expanded = <String>{};
  final _selected = <String>{};
  final _drafts = <(String, String), String>{};

  @override
  void didUpdateWidget(covariant TeamProjectConversation oldWidget) {
    super.didUpdateWidget(oldWidget);
    final switchedController = oldWidget.controller != widget.controller;
    if (!switchedController &&
        oldWidget.projectId == widget.projectId &&
        oldWidget.taskId == widget.taskId) {
      return;
    }
    if (switchedController) {
      _drafts.clear();
    } else {
      _drafts[(oldWidget.projectId, oldWidget.taskId)] = _message.text;
    }
    _message.text = _drafts[(widget.projectId, widget.taskId)] ?? '';
    _selected.clear();
    _expanded.clear();
    _focus.unfocus();
  }

  AppLocalizations get l => AppLocalizations.of(context);
  TeamProjectController get c => widget.controller;

  @override
  void dispose() {
    _message.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<TeamCommandResult> _run(
    TeamProject p,
    TeamProjectAction action, {
    String? target,
    String text = '',
    bool confirmed = false,
    TeamRepo? repo,
    List<String> findingIds = const [],
  }) => c.execute(
    TeamProjectCommand(
      requestId: c.newRequestId(),
      action: action,
      projectId: p.id,
      expectedRevision: p.revision,
      targetId: target ?? widget.taskId,
      text: text,
      findingIds: findingIds,
      confirmed: confirmed,
      expectedDevCommit: repo?.devCommit ?? '',
      expectedMainCommit: repo?.mainCommit ?? '',
    ),
  );

  KitAction _action(
    String label,
    VoidCallback callback, {
    bool destructive = false,
  }) => KitAction(
    label: label,
    onPressed: c.busy ? null : callback,
    destructive: destructive,
    disabledReason: c.busy ? l.teamProjectTaskWaiting : null,
  );

  String _age(String value) {
    final at = DateTime.tryParse(value);
    return at == null
        ? ''
        : relativeAgeLabel(DateTime.now().difference(at), at: at, l10n: l);
  }

  KitTeamState _state(String status) => switch (status) {
    'running' || 'verifying' || 'fixing' => KitTeamState.running,
    'needsYou' ||
    'needs_you' ||
    'question' ||
    'review' => KitTeamState.needsYou,
    'failed' => KitTeamState.failed,
    'stalled' => KitTeamState.stalled,
    'done' || 'merged' || 'accepted' => KitTeamState.done,
    _ => KitTeamState.empty,
  };
  String _status(String status) => switch (_state(status)) {
    KitTeamState.running => l.teamProjectTaskRunning,
    KitTeamState.needsYou => l.teamProjectTaskReview,
    KitTeamState.failed => l.teamProjectTaskFailed,
    KitTeamState.done => l.teamProjectTaskDone,
    _ => l.teamProjectTaskWaiting,
  };

  Future<void> _answer(TeamProject p, TeamRequest request) async {
    await showKitInputDialog(
      context,
      title: request.title,
      label: l.teamProjectTaskAnswerLabel,
      confirmLabel: l.teamProjectTaskAnswer,
      maxLines: 5,
      validate: (v) =>
          v.trim().isEmpty ? l.teamProjectTaskReasonRequired : null,
      onSubmit: (v) async {
        final result = await _run(
          p,
          TeamProjectAction.answerRequest,
          target: request.id,
          text: v.trim(),
        );
        return result.accepted ? null : l.teamProjectTaskSaveFailed;
      },
    );
  }

  Future<void> _ignore(TeamProject p) async {
    final selected = _selected
        .where(
          (id) => p.tasks.any(
            (task) =>
                task.id == widget.taskId &&
                task.findings.any((f) => f.id == id && f.status == 'open'),
          ),
        )
        .single;
    await showKitInputDialog(
      context,
      title: l.teamProjectTaskIgnore,
      label: l.teamProjectTaskIgnoreReason,
      confirmLabel: l.teamProjectTaskIgnore,
      maxLines: 4,
      validate: (v) =>
          v.trim().isEmpty ? l.teamProjectTaskReasonRequired : null,
      onSubmit: (v) async {
        final result = await _run(
          p,
          TeamProjectAction.ignoreFinding,
          findingIds: [selected],
          text: v.trim(),
        );
        return result.accepted ? null : l.teamProjectTaskSaveFailed;
      },
    );
  }

  List<KitAction> _requestActions(
    TeamProject p,
    TeamTask task,
    TeamRequest request,
  ) {
    switch (request.kind) {
      case 'question':
      case 'permission':
        return [_action(l.teamProjectTaskAnswer, () => _answer(p, request))];
      case 'interrupted':
        return [
          _action(
            l.teamProjectTaskResume,
            () => _run(p, TeamProjectAction.resumeTask),
          ),
        ];
      case 'stalled':
      case 'failed':
        return [
          _action(
            l.teamProjectTaskRestart,
            () => _run(p, TeamProjectAction.restartTask),
          ),
        ];
      case 'findings':
        return [
          _action(
            l.teamProjectTaskReviewFindings,
            () => setState(() {
              _selected.addAll(
                task.findings.where((f) => f.status == 'open').map((f) => f.id),
              );
            }),
          ),
        ];
      case 'conflict':
        final item = p.mergeQueue
            .where(
              (m) =>
                  m.taskId == task.id &&
                  const ['conflict', 'manual'].contains(m.status),
            )
            .firstOrNull;
        if (item == null) return [];
        return [
          _action(
            l.teamProjectTaskResolveAgent,
            () => _run(
              p,
              TeamProjectAction.resolveConflict,
              target: item.id,
              text: 'agent',
            ),
          ),
          _action(
            l.teamProjectTaskResolveManually,
            () => _run(
              p,
              TeamProjectAction.resolveConflict,
              target: item.id,
              text: 'manual',
            ),
          ),
          if (item.reason == 'Waiting for your conflict resolution')
            _action(
              l.teamProjectTaskRecheckResolution,
              () => _run(
                p,
                TeamProjectAction.resolveConflict,
                target: item.id,
                text: 'recheck',
              ),
            ),
        ];
      default:
        return [];
    }
  }

  Future<void> _merge(TeamProject p, TeamRepo? repo) async {
    if (repo == null) return;
    final requiresConfirmation = p.settings.reviewLevel == 'everyStep';
    if (requiresConfirmation) {
      final yes = await showKitConfirm(
        context,
        title: l.teamProjectTaskMergeRun,
        body: l.teamProjectMergeConfirmBody,
        confirmLabel: l.teamProjectTaskMergeRun,
      );
      if (!yes || !mounted) return;
    }
    await _run(
      p,
      TeamProjectAction.processMergeQueue,
      target: repo.id,
      confirmed: requiresConfirmation,
    );
  }

  Future<void> _promote(TeamProject p, TeamRepo repo) async {
    final yes = await showKitConfirm(
      context,
      title: l.teamProjectTaskPromote,
      body: l.teamProjectTaskPromoteBody,
      confirmLabel: l.teamProjectTaskPromote,
      consequences: ['${repo.name}: ${repo.mainCommit} → ${repo.devCommit}'],
    );
    if (!yes || !mounted) return;
    await _run(
      p,
      TeamProjectAction.promote,
      target: repo.id,
      repo: repo,
      confirmed: true,
    );
  }

  Future<void> _stop(TeamProject p) async {
    final yes = await showKitConfirm(
      context,
      title: l.teamProjectTaskStop,
      body: l.teamProjectTaskStopBody,
      confirmLabel: l.teamProjectTaskStop,
      kind: KitConfirmKind.stop,
    );
    if (yes && mounted) {
      await _run(p, TeamProjectAction.stopTask, confirmed: true);
    }
  }

  Future<void> _send(TeamProject p) async {
    final text = _message.text;
    final sentTask = (widget.projectId, widget.taskId);
    final sentController = c;
    if (text.trim().isEmpty || c.busy) return;
    final result = await _run(p, TeamProjectAction.messageTask, text: text);
    if (!mounted || !result.accepted || c != sentController) return;
    if (sentTask == (widget.projectId, widget.taskId)) {
      if (_message.text == text) _message.clear();
    } else if (_drafts[sentTask] == text) {
      _drafts.remove(sentTask);
    }
  }

  Widget _fold(String id, String title, List<Widget> children) => KitExpandRow(
    title: title,
    expanded: _expanded.contains(id),
    children: children,
    onExpansionChanged: (value) => setState(() {
      if (value) {
        _expanded.add(id);
      } else {
        _expanded.remove(id);
      }
    }),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final p = c.snapshot?.projects
          .where((p) => p.id == widget.projectId)
          .firstOrNull;
      final t = p?.tasks.where((t) => t.id == widget.taskId).firstOrNull;
      if (p == null || t == null) {
        return KitScreen(
          loading: c.loading,
          body: KitStateView.error(
            title: l.teamProjectTaskMissing,
            retry: _action(l.teamProjectRefreshTask, c.load),
          ),
        );
      }
      final unavailable = c.errorCode == 'unavailable';
      final running = !unavailable && _state(t.status) == KitTeamState.running;
      final role = c.snapshot?.roles.where((r) => r.id == t.roleId).firstOrNull;
      final server = c.snapshot?.servers
          .where((s) => s.id == t.serverId)
          .firstOrNull;
      final requests = p.requests
          .where((r) => r.taskId == t.id && !r.answered)
          .toList();
      final phase = p.phases.where((f) => f.id == t.phaseId).firstOrNull;
      final repo = p.repos.where((r) => r.id == t.repoId).firstOrNull;
      final queue = p.mergeQueue.where((m) => m.taskId == t.id).toList();
      final events = p.timeline.where((e) => e.taskId == t.id).toList();
      final selected = _selected.intersection(
        t.findings.where((f) => f.status == 'open').map((f) => f.id).toSet(),
      );
      return KitScreen(
        topBar: widget.embedded
            ? null
            : KitTopBar(
                title: t.title,
                subtitle: [
                  if (role != null) role.name,
                  if (server != null) server.name,
                ].join(' · '),
              ),
        loading: c.loading,
        body: ListView(
          padding: KitScreen.padding(context),
          children: [
            if (widget.embedded) KitText(t.title, role: KitTextRole.title),
            if (unavailable)
              KitMessage.notice(
                text: '${l.teamProjectTaskStale} · ${_age(p.updatedAt)}',
              ),
            if (c.errorCode != null)
              KitStateView.error(
                title: l.teamProjectTaskSaveFailed,
                size: KitStateSize.inline,
                secondary: _action(l.teamProjectRefreshTask, c.load),
              ),
            if (_expanded.isNotEmpty)
              KitButton.tertiary(
                label: l.teamProjectTaskCollapse,
                onPressed: () => setState(_expanded.clear),
              ),
            if (t.messages.isEmpty)
              KitMessage.notice(text: l.teamProjectTaskEmpty),
            for (final m in t.messages)
              if (m.actor == 'person')
                KitMessage.prompt(
                  bubbleWidth: KitBubbleWidth.compact,
                  body: KitMarkdown(m.text, selectable: false),
                  time: DateTime.tryParse(m.at),
                )
              else if (m.actor == 'team')
                KitMessage.thought(
                  heading: l.teamProjectTaskInstructions,
                  body: KitMarkdown(m.text, role: KitTextRole.secondary),
                  expanded: _expanded.contains(m.id),
                  onExpansionChanged: (v) => setState(() {
                    if (v) {
                      _expanded.add(m.id);
                    } else {
                      _expanded.remove(m.id);
                    }
                  }),
                )
              else
                KitMessage.reply(body: KitMarkdown(m.text)),
            KitPlanCard(
              title: l.teamProjectTaskPlan,
              status: (p.status == 'plan' || p.status == 'planned')
                  ? l.teamProjectTaskReview
                  : l.teamProjectTaskApprovedPlan,
              state: (p.status == 'plan' || p.status == 'planned')
                  ? KitTeamState.needsYou
                  : KitTeamState.done,
              summary: p.specDraft.goal,
              items: [
                for (final criterion in t.criteria)
                  KitTeamItem(title: criterion),
              ],
            ),
            if (phase != null)
              KitPhaseCard(
                title: phase.title,
                status: phase.accepted
                    ? l.teamProjectTaskAccepted
                    : t.status == 'failed'
                    ? l.teamProjectTaskFailed
                    : l.teamProjectTaskCriteria,
                state: t.status == 'failed'
                    ? KitTeamState.failed
                    : p.requests.any(
                        (r) => r.phaseId == phase.id && !r.answered,
                      )
                    ? KitTeamState.needsYou
                    : KitTeamState.done,
                items: [KitTeamItem(title: t.title)],
                actions: [
                  if (!phase.accepted)
                    _action(
                      l.teamProjectTaskAcceptPhase,
                      () => _run(
                        p,
                        TeamProjectAction.acceptPhase,
                        target: phase.id,
                      ),
                    ),
                ],
              ),
            for (final request in requests)
              KitPhaseCard(
                title: request.title,
                status: _age(request.createdAt),
                state: KitTeamState.needsYou,
                actions: _requestActions(p, t, request),
              ),
            if (events.isNotEmpty)
              _fold('work', l.teamProjectTaskWork, [
                for (final event
                    in (running
                        ? events.reversed.take(3).toList().reversed
                        : events))
                  KitText('${event.text} · ${_age(event.at)}'),
              ]),
            if (t.criterionResults.isNotEmpty)
              KitPhaseCard(
                title: l.teamProjectTaskCriteria,
                status: l.teamProjectTaskVerificationResults,
                state: KitTeamState.done,
                items: [
                  for (final result in t.criterionResults)
                    KitTeamItem(
                      title: result.criterion,
                      detail: switch (result.status) {
                        'met' => l.teamProjectTaskCriterionMet,
                        'unmet' => l.teamProjectTaskCriterionUnmet,
                        _ => l.teamProjectTaskCriterionNotApplicable,
                      },
                      state: result.status == 'unmet'
                          ? KitTeamState.failed
                          : KitTeamState.done,
                    ),
                ],
              ),
            if (t.findings.isNotEmpty)
              KitFindingsCard(
                title: l.teamProjectTaskFindings,
                status: t.findings.any((f) => f.status == 'open')
                    ? l.teamProjectTaskOpenFindings
                    : l.teamProjectTaskFindingsAddressed,
                state:
                    t.findings.any((f) => f.status == 'open') &&
                        t.status == 'review'
                    ? KitTeamState.needsYou
                    : KitTeamState.done,
                findings: [
                  for (final f in t.findings)
                    KitTeamFinding(
                      id: f.id,
                      title: f.text,
                      detail: f.criterion,
                      location: f.location,
                      severity: switch (f.severity) {
                        'critical' => KitFindingSeverity.critical,
                        'minor' => KitFindingSeverity.minor,
                        _ => KitFindingSeverity.major,
                      },
                      severityLabel: switch (f.severity) {
                        'critical' => l.teamProjectTaskCritical,
                        'minor' => l.teamProjectTaskMinor,
                        _ => l.teamProjectTaskMajor,
                      },
                      selected: selected.contains(f.id),
                      onChanged: f.status == 'open'
                          ? (v) => setState(() {
                              if (v) {
                                _selected.add(f.id);
                              } else {
                                _selected.remove(f.id);
                              }
                            })
                          : null,
                    ),
                ],
                actions: [
                  if (selected.isNotEmpty)
                    _action(
                      l.teamProjectTaskFix,
                      () => _run(
                        p,
                        TeamProjectAction.fixFindings,
                        findingIds: selected.toList(),
                      ),
                    ),
                  _action(
                    l.teamProjectTaskRecheck,
                    () => _run(p, TeamProjectAction.recheckTask),
                  ),
                  if (selected.length == 1)
                    _action(l.teamProjectTaskIgnore, () => _ignore(p)),
                ],
              ),
            if (queue.isNotEmpty)
              KitMergeQueue(
                title: l.teamProjectTaskMerge,
                status: _status(queue.first.status),
                state: _state(queue.first.status),
                items: [
                  for (final q in queue)
                    KitTeamItem(
                      title: t.title,
                      detail: q.reason,
                      meta: _status(q.status),
                    ),
                ],
                actions: [
                  _action(l.teamProjectTaskMergeRun, () => _merge(p, repo)),
                  if (p.simulated)
                    _action(
                      l.teamProjectTaskDemoConflict,
                      () => _run(
                        p,
                        TeamProjectAction.simulateConflict,
                        target: queue.first.id,
                      ),
                    ),
                  if (p.simulated && repo != null)
                    _action(
                      l.teamProjectTaskDemoCommit,
                      () => _run(
                        p,
                        TeamProjectAction.simulateManualCommit,
                        target: repo.id,
                      ),
                    ),
                ],
              ),
            if (repo != null && repo.devCommit != repo.mainCommit)
              KitPromoteCard(
                title: l.teamProjectTaskPromote,
                status: l.teamProjectTaskPromotion,
                state: KitTeamState.needsYou,
                summary: '${repo.name}: ${repo.mainCommit} → ${repo.devCommit}',
              ),
            for (final receipt in p.receipts.where(
              (r) =>
                  r.repoId == t.repoId &&
                  const ['promote', 'promotion'].contains(r.kind),
            ))
              KitPhaseCard(
                title: l.teamProjectTaskReceipt,
                status: _age(receipt.at),
                state: KitTeamState.done,
                summary: '${receipt.before} → ${receipt.after}',
              ),
            KitActionBlock(
              tertiary: [
                if (t.diff.isNotEmpty)
                  _action(
                    l.teamProjectTaskDiff,
                    () => showKitDiff(
                      context,
                      title: t.title,
                      files: [KitDiffFile.fromPatch(t.title, t.diff)],
                    ),
                  ),
                if (running)
                  _action(
                    l.teamProjectTaskPause,
                    () => _run(p, TeamProjectAction.pauseTask),
                  ),
                if (t.status == 'paused')
                  _action(
                    l.teamProjectTaskResume,
                    () => _run(p, TeamProjectAction.resumeTask),
                  ),
                if (t.status == 'failed' || t.status == 'stopped')
                  _action(
                    l.teamProjectTaskRestart,
                    () => _run(p, TeamProjectAction.restartTask),
                  ),
                if (t.status == 'done')
                  _action(
                    l.teamProjectTaskVerify,
                    () => _run(p, TeamProjectAction.verifyTask),
                  ),
                if (running || t.status == 'paused' || requests.isNotEmpty)
                  _action(
                    l.teamProjectTaskStop,
                    () => _stop(p),
                    destructive: true,
                  ),
              ],
            ),
            if (t.branch.isNotEmpty) KitDetailsFold(text: t.branch),
          ],
        ),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((p.status == 'plan' || p.status == 'planned'))
              KitButton.fromAction(
                _action(
                  l.teamProjectTaskApprovePlan,
                  () => _run(p, TeamProjectAction.approvePlan),
                ),
                role: widget.embedded
                    ? KitButtonRole.tertiary
                    : KitButtonRole.primary,
              )
            else if (repo != null && repo.devCommit != repo.mainCommit)
              KitButton.fromAction(
                _action(l.teamProjectTaskPromote, () => _promote(p, repo)),
                role: widget.embedded
                    ? KitButtonRole.tertiary
                    : KitButtonRole.primary,
              ),
            KitComposer(
              controller: _message,
              focusNode: _focus,
              hint: l.teamProjectTaskMessage,
              fieldLabel: l.teamProjectTaskMessage,
              onSend: () => _send(p),
              busy: running,
              sending: c.busy,
              canSendWhileBusy: true,
              rail: !unavailable && (running || requests.isNotEmpty)
                  ? KitTurnLive(
                      activity: requests.isNotEmpty
                          ? KitTurnActivity.waitingForYou
                          : KitTurnActivity.working,
                      since: DateTime.tryParse(t.changedAt),
                      onStop: c.busy ? null : () => _stop(p),
                    )
                  : null,
            ),
          ],
        ),
      );
    },
  );
}
