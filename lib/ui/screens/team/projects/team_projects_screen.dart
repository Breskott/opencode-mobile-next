import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../domain/relative_age.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../state/team_project_controller.dart';
import '../../../app_iconography.dart';
import '../../../kit/kit.dart';
import 'team_execution_gate.dart';
import 'team_merge_flow.dart';
import 'team_project_conversation.dart';
import 'team_project_editors.dart';

// Finish line: a person can steer a persisted simulated project from goal to
// reviewed work, with every action crossing the project controller.
// Non-goal: selecting or connecting a production execution engine.
class TeamProjectsScreen extends StatefulWidget {
  const TeamProjectsScreen({
    super.key,
    required this.controller,
    this.initialProjectId,
    this.initialTaskId,
    this.onLeaveDemo,
  });
  final String? initialProjectId;
  final String? initialTaskId;
  final VoidCallback? onLeaveDemo;
  final TeamProjectController controller;
  @override
  State<TeamProjectsScreen> createState() => _TeamProjectsScreenState();
}

class _TeamProjectsScreenState extends State<TeamProjectsScreen> {
  String? _selected;
  String? _task;
  bool _initialOpened = false;
  @override
  void initState() {
    super.initState();
    _selected = widget.initialProjectId;
    _task = widget.initialTaskId;
    if (widget.controller.snapshot == null) unawaited(widget.controller.load());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l = lookupAppLocalizations(Localizations.localeOf(context));
      final c = widget.controller;
      final projects = [...?c.snapshot?.projects]
        ..sort((a, b) => _urgency(a).compareTo(_urgency(b)));
      final selected =
          projects
              .where(
                (p) =>
                    p.id == _selected ||
                    (widget.initialTaskId != null &&
                        p.tasks.any((t) => t.id == widget.initialTaskId)),
              )
              .firstOrNull ??
          projects.firstOrNull;
      final selectedTask =
          selected?.tasks.where((t) => t.id == _task).firstOrNull ??
          selected?.tasks.firstOrNull;
      if (!_initialOpened &&
          selected != null &&
          (widget.initialProjectId != null || widget.initialTaskId != null)) {
        _initialOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (widget.initialTaskId != null &&
              KitLayout.windowOf(context) != KitWindow.large) {
            _openTask(context, c, selected.id, widget.initialTaskId!);
          } else if (!KitScreen.showsDetail(context)) {
            unawaited(
              pushKitPage<void>(
                context,
                (_) =>
                    TeamProjectOverview(controller: c, projectId: selected.id),
              ),
            );
          }
        });
      }
      return KitScreen.threePane(
        topBar: KitTopBar(
          title: l.teamProjectHome,
          subtitle: c.snapshot?.simulated == true
              ? l.teamProjectDemoChip
              : null,
          actions: [
            KitAction(
              label: l.teamProjectEditorDefaults,
              icon: Icons.settings_outlined,
              onPressed: () => openTeamDefaults(context, c),
            ),
            if (widget.onLeaveDemo != null)
              KitAction(
                label: l.teamProjectOff,
                icon: Icons.logout,
                onPressed: widget.onLeaveDemo,
              ),
            KitAction(
              label: l.teamProjectRoles,
              icon: Icons.groups_outlined,
              onPressed: () => openTeamRoles(context, c),
            ),
          ],
        ),
        loading: c.loading,
        loadingLabel: l.teamProjectLoad,
        list: ListView(
          padding: KitScreen.padding(context),
          children: [
            TeamExecutionBlocked(controller: c),
            TeamProtectionLine(controller: c),
            if (c.errorCode != null) _failure(context, c),
            if (projects.isEmpty && !c.loading)
              KitStateView(icon: Icons.work_outline, title: l.teamProjectEmpty),
            for (final p in projects) ...[
              for (final request in p.requests.where((r) => !r.answered))
                KitRow(
                  title: request.title,
                  supporting: TextSpan(text: p.name),
                  onTap: () => _answer(context, c, p, request),
                ),
              KitProjectRow(
                title: p.name,
                detail: p.budgetWarning
                    ? l.teamProjectBudgetNear
                    : p.usageReported
                    ? _todayCost(l, p)
                    : null,
                status: c.errorCode == 'unavailable'
                    ? l.teamProjectTaskStale
                    : _headline(l, p),
                state: c.errorCode == 'unavailable'
                    ? KitTeamState.stale
                    : _state(p.status),
                meta: _age(context, p.updatedAt),
                onPressed: () => KitScreen.openDetail<void>(
                  context,
                  select: () => setState(() {
                    _selected = p.id;
                    _task = null;
                  }),
                  page: (_) =>
                      TeamProjectOverview(controller: c, projectId: p.id),
                ),
              ),
            ],
          ],
        ),
        detail: selected == null
            ? null
            : TeamProjectOverview(
                controller: c,
                projectId: selected.id,
                embedded: true,
                onOpenTask: (task) {
                  if (KitLayout.windowOf(context) == KitWindow.large) {
                    setState(() => _task = task.id);
                  } else {
                    _openTask(context, c, selected.id, task.id);
                  }
                },
              ),
        emptyDetail: KitStateView(
          icon: Icons.work_outline,
          title: l.teamProjectSelect,
        ),
        side: selected != null && selectedTask != null
            ? TeamProjectConversation(
                key: ValueKey(selectedTask.id),
                controller: c,
                projectId: selected.id,
                taskId: selectedTask.id,
                embedded: true,
              )
            : KitStateView(
                icon: Icons.chat_bubble_outline,
                title: l.teamProjectSelectTask,
              ),
        bottom: TeamExecutionGate.allows(c, TeamExecutionNeed.lanes)
            ? KitActionBlock(
                primary: KitAction(
                  label: l.teamProjectNew,
                  onPressed: () => openTeamNewProject(context, c),
                ),
                tertiary: [
                  KitAction(
                    label: l.teamProjectQuick,
                    onPressed: () =>
                        openTeamNewProject(context, c, quick: true),
                  ),
                ],
              )
            : null,
      );
    },
  );
}

class TeamProjectOverview extends StatelessWidget {
  const TeamProjectOverview({
    super.key,
    required this.controller,
    required this.projectId,
    this.embedded = false,
    this.onOpenTask,
  });
  final TeamProjectController controller;
  final String projectId;
  final bool embedded;
  final ValueChanged<TeamTask>? onOpenTask;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = lookupAppLocalizations(Localizations.localeOf(context));
      final p = controller.snapshot?.projects
          .where((p) => p.id == projectId)
          .firstOrNull;
      if (p == null) {
        return KitStateView(
          icon: Icons.work_outline,
          title: l.teamProjectSelect,
        );
      }
      final c = controller;
      final stale = c.errorCode == 'unavailable';
      void task(TeamTask t) => onOpenTask != null
          ? onOpenTask!(t)
          : _openTask(context, c, p.id, t.id);
      final unread = DateTime.tryParse(p.digestReadAt);
      final showDigest =
          p.timeline.isNotEmpty &&
          (unread == null || DateTime.now().difference(unread).inHours >= 4);
      final events = p.timeline
          .where(
            (e) =>
                unread == null ||
                (DateTime.tryParse(e.at)?.isAfter(unread) ?? false),
          )
          .toList()
          .reversed;
      final milestones = p.specDraft.milestones;
      final current = milestones.indexWhere((m) => !m.accepted);
      bool finished(TeamTask t) => t.status == 'merged' || t.status == 'done';
      final busy = p.tasks.where((t) => t.status == 'running').toList();
      final laneTotal = p.settings.mode == 'single' ? 1 : p.settings.maxLanes;
      final asked = {
        for (final r in p.requests.where((r) => !r.answered)) r.taskId,
      };
      final waiting = p.tasks
          .where(
            (t) =>
                t.status == 'queued' &&
                !asked.contains(t.id) &&
                t.dependsOn.every(
                  (id) => p.tasks.any((o) => o.id == id && finished(o)),
                ),
          )
          .take(laneTotal > busy.length ? laneTotal - busy.length : 0)
          .toList();
      final decisions = p.timeline
          .where((e) => e.kind == 'decision')
          .toList()
          .reversed
          .take(3)
          .toList();
      final open = p.status != 'stopped' && p.status != 'done';
      final menu = <KitMenuItem>[
        if (open &&
            (p.status != 'paused' ||
                TeamExecutionGate.allows(c, TeamExecutionNeed.lanes)))
          KitMenuItem(
            label: p.status == 'paused'
                ? l.teamProjectResume
                : l.teamProjectPause,
            onSelected: () => _command(
              c,
              p,
              p.status == 'paused'
                  ? TeamProjectAction.resumeProject
                  : TeamProjectAction.pauseProject,
            ),
          ),
        if (p.simulated && p.status == 'plan')
          KitMenuItem(
            label: l.teamProjectDemoPlanFailure,
            onSelected: () =>
                _command(c, p, TeamProjectAction.simulatePlanFailure),
          ),
        if (p.simulated)
          KitMenuItem(
            label: l.teamProjectAdvance,
            onSelected: () => _command(c, p, TeamProjectAction.advance),
          ),
        KitMenuItem(
          label: l.teamProjectStop,
          destructive: true,
          onSelected: () async {
            if (await showKitConfirm(
              context,
              title: l.teamProjectStop,
              body: l.teamProjectStopBody,
              confirmLabel: l.teamProjectStop,
              kind: KitConfirmKind.stop,
            )) {
              _command(c, p, TeamProjectAction.stopProject);
            }
          },
        ),
      ];
      return KitScreen(
        topBar: KitTopBar(
          title: p.name,
          subtitle: stale ? l.teamProjectTaskStale : _headline(l, p),
          menu: menu,
          menuLabel: l.teamProjectMenu,
          actions: [
            KitAction(
              label: l.teamProjectSpec,
              icon: Icons.description_outlined,
              onPressed: () => openTeamSpecEditor(context, c, p.id),
            ),
          ],
        ),
        body: ListView(
          padding: KitScreen.padding(context),
          children: [
            if (!embedded) TeamExecutionBlocked(controller: c),
            if (c.errorCode != null) _failure(context, c),
            for (final r in p.requests.where((r) => !r.answered))
              _needsYou(context, l, c, p, r),
            if (showDigest)
              KitDigest(
                title: l.teamProjectDigest,
                status: p.simulated ? l.teamProjectDemo : '',
                items: [
                  for (final e in events.take(6))
                    KitTeamItem(title: e.text, meta: _age(context, e.at)),
                ],
                actions: [
                  KitAction(
                    label: l.teamProjectDigestRead,
                    onPressed: () =>
                        _command(c, p, TeamProjectAction.acknowledgeDigest),
                  ),
                ],
              ),
            KitPlanCard(
              title: p.specDraft.goal,
              status: _goalStatus(context, l, p),
              actions: [
                KitAction(
                  label: l.teamProjectOpenSpec,
                  onPressed: () => openTeamSpecEditor(context, c, p.id),
                ),
                if (p.status == 'plan' || p.status == 'planned')
                  KitAction(
                    label: l.teamProjectPlan,
                    onPressed: () => openTeamPlanEditor(context, c, p.id),
                  ),
              ],
            ),
            if (milestones.isNotEmpty)
              KitSectionLabel.inline(l.teamProjectMilestones),
            for (var i = 0; i < milestones.length; i++)
              Builder(
                builder: (context) {
                  final m = milestones[i];
                  final phaseIds = p.phases
                      .where((ph) => ph.milestoneId == m.id)
                      .map((ph) => ph.id)
                      .toSet();
                  final tasks = p.tasks
                      .where((t) => phaseIds.contains(t.phaseId))
                      .toList();
                  final complete = tasks.where(finished).length;
                  final started =
                      i == current || tasks.any((t) => t.status != 'queued');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KitMilestoneRow(
                        title: '${i + 1} ${m.title}',
                        state: m.accepted
                            ? KitTeamState.done
                            : tasks.any((t) => t.status == 'running')
                            ? KitTeamState.running
                            : KitTeamState.empty,
                        status: m.accepted
                            ? l.teamProjectDone
                            : tasks.isEmpty
                            ? l.teamProjectMilestoneNoTasks
                            : started
                            ? l.teamProjectMilestoneTasks(
                                complete,
                                tasks.length,
                              )
                            : l.teamProjectMilestoneWaits(i),
                        completed: started && !m.accepted ? complete : null,
                        total: started && !m.accepted ? tasks.length : null,
                        onPressed: () =>
                            _openBoard(context, c, p.id, milestone: m.id),
                      ),
                      if (!m.accepted &&
                          tasks.isNotEmpty &&
                          tasks.every((task) => task.status == 'merged') &&
                          p.phases
                              .where((phase) => phase.milestoneId == m.id)
                              .every((phase) => phase.accepted))
                        KitButton(
                          role: KitButtonRole.tertiary,
                          label: l.teamProjectAccept,
                          onPressed: () => _command(
                            c,
                            p,
                            TeamProjectAction.acceptMilestone,
                            targetId: m.id,
                          ),
                        ),
                    ],
                  );
                },
              ),
            if (busy.isNotEmpty || waiting.isNotEmpty) ...[
              KitSectionLabel.inline(
                l.teamProjectLanesTitle(busy.length, laneTotal),
                trailing: KitButton.tertiary(
                  label: l.teamProjectLanesChange,
                  onPressed: () => openTeamProjectSettings(context, c, p.id),
                ),
              ),
              for (final t in [...busy, ...waiting])
                KitRow(
                  leading: KitStatusMark(
                    state: t.status == 'running' && !stale
                        ? KitMarkState.working
                        : KitMarkState.waiting,
                  ),
                  title: l.teamProjectLaneTitle(
                    _role(context, c, t.roleId),
                    t.title,
                  ),
                  supporting: TextSpan(
                    text: _laneLine(context, l, c, t, stale),
                  ),
                  trailing: const KitRowValue('', chevron: true),
                  onTap: () => task(t),
                ),
              KitText(_laneNote(l, p, laneTotal), role: KitTextRole.caption),
            ],
            for (final repo in p.repos)
              if (p.mergeQueue.any(
                (i) => i.repoId == repo.id && i.status != 'merged',
              ))
                KitMergeQueue(
                  title: '${l.teamProjectMerge} · ${repo.name}',
                  status: 'dev',
                  items: [
                    for (final i in p.mergeQueue.where(
                      (i) => i.repoId == repo.id && i.status != 'merged',
                    ))
                      KitTeamItem(
                        title:
                            p.tasks
                                .where((t) => t.id == i.taskId)
                                .firstOrNull
                                ?.title ??
                            repo.name,
                        detail: i.reason.isNotEmpty
                            ? i.reason
                            : _mergeWord(l, i),
                        state: _state(i.status),
                        onPressed: () => _openTask(context, c, p.id, i.taskId),
                      ),
                  ],
                  actions: [
                    if (TeamExecutionGate.allows(
                      c,
                      TeamExecutionNeed.mergeQueue,
                    ))
                      KitAction(
                        label: l.teamProjectMergeNext,
                        onPressed: () =>
                            confirmAndMergeToDev(context, c, p, repo),
                      ),
                  ],
                ),
            for (final repo in p.repos) ...[
              for (final item in teamReceiptItems(
                context,
                p,
                repo,
                age: (at) => _age(context, at),
              ))
                KitRow(
                  title: item.title,
                  supporting: TextSpan(text: item.detail),
                  trailing: KitRowValue(item.meta ?? ''),
                ),
              if (teamCanPromote(p, repo) &&
                  TeamExecutionGate.allows(c, TeamExecutionNeed.promotion))
                KitPromoteCard(
                  title: l.teamProjectPromoteTitle,
                  status: l.teamProjectPromoteStatus(repo.name),
                  state: KitTeamState.needsYou,
                  items: [
                    KitTeamItem(
                      title: repo.name,
                      detail: teamCommitChange(repo.mainCommit, repo.devCommit),
                    ),
                  ],
                  primary: KitAction(
                    label: l.teamProjectTaskPromote,
                    onPressed: () => confirmAndPromote(context, c, p, repo),
                  ),
                ),
            ],
            if (decisions.isNotEmpty) ...[
              KitSectionLabel.inline(l.teamProjectDecisions),
              for (final e in decisions)
                KitRow(
                  title: e.text,
                  supporting: TextSpan(
                    text: _who(context, l, c, e) == ''
                        ? _age(context, e.at)
                        : l.teamProjectDecisionBy(
                            _who(context, l, c, e),
                            _age(context, e.at),
                          ),
                  ),
                ),
            ],
            KitSectionLabel.inline(l.teamProjectPages),
            KitRow(
              leading: const KitIcon(AppIconography.kanban),
              title: l.teamProjectBoard,
              supporting: TextSpan(text: _boardSummary(l, p)),
              trailing: const KitRowValue('', chevron: true),
              onTap: () => _openBoard(context, c, p.id),
            ),
            KitRow(
              leading: const KitIcon(AppIconography.timeline),
              title: l.teamProjectTimeline,
              supporting: TextSpan(text: _timelineSummary(context, l, p)),
              trailing: const KitRowValue('', chevron: true),
              onTap: () => pushKitPage<void>(
                context,
                (_) => TeamProjectTimeline(controller: c, projectId: p.id),
              ),
            ),
            KitRow(
              leading: const KitIcon(AppIconography.server),
              title: l.teamProjectServers,
              supporting: TextSpan(
                text: l.teamProjectServersSummary(
                  {
                    for (final r in p.repos) r.serverId,
                    for (final t in p.tasks) t.serverId,
                  }.where((id) => id.isNotEmpty).length,
                ),
              ),
              trailing: const KitRowValue('', chevron: true),
              onTap: () => pushKitPage<void>(
                context,
                (_) => TeamProjectServers(controller: c, projectId: p.id),
              ),
            ),
            KitRow(
              leading: const KitIcon(AppIconography.settings),
              title: l.teamProjectSettings,
              supporting: TextSpan(
                text: p.settings.mode == 'single'
                    ? l.teamProjectSettingsSummarySingle
                    : l.teamProjectSettingsSummaryParallel(p.settings.maxLanes),
              ),
              trailing: const KitRowValue('', chevron: true),
              onTap: () => openTeamProjectSettings(context, c, p.id),
            ),
            KitSectionLabel.inline(l.teamProjectCost),
            if (p.budgetWarning) KitNotice(message: l.teamProjectBudgetNear),
            KitRow(
              leading: const KitIcon(AppIconography.usage),
              title: _costLine(l, p),
              trailing: const KitRowValue('', chevron: true),
              onTap: () => openTeamProjectSettings(context, c, p.id),
            ),
          ],
        ),
      );
    },
  );
}

Widget _needsYou(
  BuildContext context,
  AppLocalizations l,
  TeamProjectController c,
  TeamProject p,
  TeamRequest r,
) {
  final t = p.tasks.where((t) => t.id == r.taskId).firstOrNull;
  final role = t == null ? '' : _role(context, c, t.roleId);
  final server = t == null
      ? null
      : c.snapshot?.servers.where((s) => s.id == t.serverId).firstOrNull;
  final after = t == null
      ? 0
      : p.tasks.where((o) => o.dependsOn.contains(t.id)).length;
  return KitPlanCard(
    title: r.title,
    status: [
      l.teamProjectNeedsYou,
      if (t != null && server != null)
        l.teamProjectRequestWhere(role, server.name),
    ].join(' · '),
    state: KitTeamState.needsYou,
    summary: t != null && after > 0
        ? l.teamProjectRequestBlocks(role, after)
        : null,
    actions: [
      KitAction(
        label: _requestLabel(l, r),
        onPressed: () => _answer(context, c, p, r),
      ),
    ],
  );
}

String _money(double v) => v == v.roundToDouble()
    ? '\$${v.toStringAsFixed(0)}'
    : '\$${v.toStringAsFixed(2)}';

String _costLine(AppLocalizations l, TeamProject p) {
  if (!p.usageReported) return l.teamProjectCostNotReported;
  final b = p.settings.budget;
  final daily = b.unlimited ? null : b.daily;
  final total = b.unlimited ? null : b.total;
  final today = daily == null
      ? l.teamProjectCostToday(_money(p.spentToday))
      : l.teamProjectCostTodayOf(_money(p.spentToday), _money(daily));
  final all = total == null
      ? l.teamProjectCostTotal(_money(p.spent))
      : l.teamProjectCostTotalOf(_money(p.spent), _money(total));
  return [
    today,
    all,
    if (daily == null && total == null) l.teamProjectNoLimit,
  ].join(' · ');
}

String _todayCost(AppLocalizations l, TeamProject p) {
  final b = p.settings.budget;
  final daily = b.unlimited ? null : b.daily;
  return daily == null
      ? l.teamProjectCostToday(_money(p.spentToday))
      : l.teamProjectCostTodayOf(_money(p.spentToday), _money(daily));
}

String _headline(AppLocalizations l, TeamProject p) {
  if (p.status != 'running') return _word(l, p.status);
  final ms = p.specDraft.milestones;
  if (ms.isEmpty) return _progress(l, p);
  final i = ms.indexWhere((m) => !m.accepted);
  return i < 0
      ? l.teamProjectHeadlineDone(ms.length)
      : l.teamProjectHeadlineMilestone(
          i + 1,
          ms.length,
          p.tasks.where((t) => t.status == 'running').length,
        );
}

String _goalStatus(BuildContext context, AppLocalizations l, TeamProject p) {
  final spec = p.specDraft;
  final approved = p.specVersions.lastOrNull;
  final at = DateTime.tryParse(approved?.approvedAt ?? '');
  return at == null
      ? l.teamProjectGoalStatusDraft(
          spec.version,
          spec.milestones.length,
          p.repos.length,
        )
      : l.teamProjectGoalStatus(
          spec.version,
          _age(context, approved!.approvedAt),
          spec.milestones.length,
          p.repos.length,
        );
}

String _elapsed(AppLocalizations l, String raw) {
  final at = DateTime.tryParse(raw);
  if (at == null) return '';
  final d = DateTime.now().difference(at);
  if (d.inMinutes < 1) {
    return l.teamProjectElapsedSeconds(d.inSeconds < 0 ? 0 : d.inSeconds);
  }
  if (d.inHours < 1) return l.teamProjectElapsedMinutes(d.inMinutes);
  return l.teamProjectElapsedHours(d.inHours, d.inMinutes % 60);
}

String _laneLine(
  BuildContext context,
  AppLocalizations l,
  TeamProjectController c,
  TeamTask t,
  bool stale,
) {
  final server = c.snapshot?.servers
      .where((s) => s.id == t.serverId)
      .firstOrNull;
  final name = server?.name ?? '';
  if (stale) return '$name · ${l.teamProjectTaskStale}';
  if (server != null && !server.online) {
    return '$name · ${l.teamProjectOffline}';
  }
  return t.status == 'running'
      ? l.teamProjectLaneRunning(name, _elapsed(l, t.changedAt))
      : l.teamProjectLaneWaiting(name);
}

String _laneNote(AppLocalizations l, TeamProject p, int total) {
  final note = p.settings.mode == 'single'
      ? l.teamProjectLaneNoteSingle
      : l.teamProjectLaneNoteParallel(total);
  return p.simulated ? l.teamProjectLaneNoteDemo(note) : note;
}

String _who(
  BuildContext context,
  AppLocalizations l,
  TeamProjectController c,
  TeamTimelineEvent e,
) {
  if (e.actor == 'person') return l.teamProjectYou;
  return c.snapshot?.roles.where((r) => r.id == e.actor).firstOrNull?.name ??
      '';
}

String _boardSummary(AppLocalizations l, TeamProject p) {
  if (p.tasks.isEmpty) return l.teamProjectBoardEmpty;
  final withTasks = p.specDraft.milestones.where(
    (m) => p.tasks.any(
      (t) => p.phases.any((ph) => ph.id == t.phaseId && ph.milestoneId == m.id),
    ),
  );
  return l.teamProjectBoardSummary(
    p.tasks.length,
    withTasks.isEmpty ? 1 : withTasks.length,
  );
}

String _timelineSummary(
  BuildContext context,
  AppLocalizations l,
  TeamProject p,
) {
  if (p.timeline.isEmpty) return l.teamProjectTimelineEmpty;
  return l.teamProjectTimelineSummary(
    p.timeline.length,
    _age(context, p.timeline.last.at),
  );
}

void _openTask(
  BuildContext context,
  TeamProjectController c,
  String p,
  String t,
) {
  unawaited(
    pushKitPage<void>(
      context,
      (_) => TeamProjectConversation(controller: c, projectId: p, taskId: t),
    ),
  );
}

void _openBoard(
  BuildContext context,
  TeamProjectController c,
  String p, {
  String? milestone,
}) {
  unawaited(
    pushKitPage<void>(
      context,
      (_) =>
          TeamProjectBoard(controller: c, projectId: p, milestone: milestone),
    ),
  );
}

Future<TeamCommandResult> _command(
  TeamProjectController c,
  TeamProject p,
  TeamProjectAction action, {
  String targetId = '',
  String text = '',
  String serverId = '',
  bool confirmed = false,
}) => c.execute(
  TeamProjectCommand(
    requestId: c.newRequestId(),
    projectId: p.id,
    expectedRevision: p.revision,
    action: action,
    targetId: targetId,
    text: text,
    serverId: serverId,
    confirmed: confirmed,
  ),
);
Future<void> _answer(
  BuildContext context,
  TeamProjectController c,
  TeamProject p,
  TeamRequest r,
) async {
  final l = lookupAppLocalizations(Localizations.localeOf(context));
  switch (r.kind) {
    case 'spec':
      await openTeamSpecEditor(context, c, p.id);
      return;
    case 'planFormat':
    case 'plan':
      await openTeamPlanEditor(context, c, p.id);
      return;
    case 'budget':
      await openTeamProjectSettings(context, c, p.id);
      return;
    case 'milestone':
      final milestone = p.specDraft.milestones
          .where((m) => m.id == r.phaseId)
          .firstOrNull;
      if (milestone != null &&
          await showKitConfirm(
            context,
            title: milestone.title,
            body: milestone.criteria.join('\n'),
            confirmLabel: l.teamProjectAccept,
          )) {
        await _command(
          c,
          p,
          TeamProjectAction.acceptMilestone,
          targetId: milestone.id,
        );
      }
      return;
    case 'phase':
      final task = p.tasks.where((t) => t.phaseId == r.phaseId).firstOrNull;
      if (task != null) _openTask(context, c, p.id, task.id);
      return;
    case 'question':
    case 'permission':
      break;
    default:
      if (r.taskId.isNotEmpty) _openTask(context, c, p.id, r.taskId);
      return;
  }
  if (!context.mounted) return;
  await showKitInputDialog(
    context,
    title: r.title,
    label: l.teamProjectAnswerLabel,
    confirmLabel: l.teamProjectAnswer,
    onSubmit: (value) async {
      final latest =
          c.snapshot?.projects.where((v) => v.id == p.id).firstOrNull ?? p;
      final result = await _command(
        c,
        latest,
        TeamProjectAction.answerRequest,
        targetId: r.id,
        text: value,
      );
      return result.accepted ? null : l.teamProjectError;
    },
  );
}

String _requestLabel(AppLocalizations l, TeamRequest r) => switch (r.kind) {
  'spec' => l.teamProjectSpec,
  'plan' || 'planFormat' => l.teamProjectPlan,
  'budget' => l.teamProjectSettings,
  'milestone' => l.teamProjectAccept,
  'question' || 'permission' => l.teamProjectAnswer,
  _ => l.teamProjectReview,
};
Widget _failure(BuildContext context, TeamProjectController c) {
  final l = lookupAppLocalizations(Localizations.localeOf(context));
  return KitNotice(
    message: l.teamProjectError,
    actions: [KitAction(label: l.teamProjectRetry, onPressed: c.load)],
  );
}

String _role(BuildContext context, TeamProjectController c, String id) =>
    c.snapshot?.roles.where((r) => r.id == id).firstOrNull?.name ??
    lookupAppLocalizations(Localizations.localeOf(context)).teamProjectHome;
String _age(BuildContext context, String raw) {
  final at = DateTime.tryParse(raw);
  if (at == null) return '';
  return relativeAgeLabel(
    DateTime.now().difference(at),
    at: at,
    l10n: lookupAppLocalizations(Localizations.localeOf(context)),
  );
}

int _urgency(TeamProject p) => p.requests.any((r) => !r.answered)
    ? 0
    : p.status == 'running'
    ? 1
    : p.status == 'done'
    ? 3
    : 2;
String _progress(AppLocalizations l, TeamProject p) => l.teamProjectProgress(
  p.tasks.where((t) => t.status == 'merged' || t.status == 'done').length,
  p.tasks.length,
  p.tasks.where((t) => t.status == 'running').length,
);
KitTeamState _state(String value) => switch (value) {
  'running' => KitTeamState.running,
  'failed' || 'conflict' => KitTeamState.failed,
  'stalled' => KitTeamState.stalled,
  'findings' || 'review' => KitTeamState.needsYou,
  'offline' => KitTeamState.stale,
  'done' || 'merged' || 'passed' => KitTeamState.done,
  _ => KitTeamState.empty,
};

/// Header rows sit on the page's one gutter, like the list rows below.
Widget _gutter(BuildContext context, Widget child) => Padding(
  padding: EdgeInsetsDirectional.symmetric(
    horizontal: KitTokens.of(context).gutter,
  ),
  child: child,
);

int _lanesHere(TeamProject p, int serverCap) {
  if (p.settings.mode == 'single') return 1;
  return serverCap < p.settings.maxLanes ? serverCap : p.settings.maxLanes;
}

/// What a merge-queue row says when it has no reason of its own: a queued
/// item is waiting for its turn (or its checks), never for dependencies.
String _mergeWord(AppLocalizations l, TeamMergeItem i) => i.status == 'queued'
    ? (i.checksPassed ? l.teamProjectMergeReady : l.teamProjectMergeChecking)
    : _word(l, i.status);

String _word(AppLocalizations l, String value) => switch (value) {
  'running' => l.teamProjectWorking,
  'failed' || 'conflict' => l.teamProjectFailed,
  'stalled' => l.teamProjectStalled,
  'paused' => l.teamProjectPaused,
  'stopped' => l.teamProjectStopped,
  'done' || 'merged' || 'passed' => l.teamProjectDone,
  'review' || 'verified' || 'findings' => l.teamProjectReview,
  'spec' => l.teamProjectPlanning,
  'plan' => l.teamProjectPlanWaiting,
  'waiting' => l.teamProjectNeedsYou,
  _ => l.teamProjectWaiting,
};

class TeamProjectBoard extends StatefulWidget {
  const TeamProjectBoard({
    super.key,
    required this.controller,
    required this.projectId,
    this.milestone,
  });
  final TeamProjectController controller;
  final String projectId;
  final String? milestone;
  @override
  State<TeamProjectBoard> createState() => _TeamProjectBoardState();
}

class _TeamProjectBoardState extends State<TeamProjectBoard> {
  String? _milestone, _repo, _server;
  bool _graph = false;
  int? _column;
  @override
  void initState() {
    super.initState();
    _milestone = widget.milestone;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final l = lookupAppLocalizations(Localizations.localeOf(context));
      final p = c.snapshot?.projects
          .where((p) => p.id == widget.projectId)
          .firstOrNull;
      if (p == null) {
        return KitStateView(
          icon: Icons.work_outline,
          title: l.teamProjectSelect,
        );
      }
      final phases = p.phases
          .where((ph) => _milestone == null || ph.milestoneId == _milestone)
          .map((ph) => ph.id)
          .toSet();
      final tasks = p.tasks
          .where(
            (t) =>
                phases.contains(t.phaseId) &&
                (_repo == null || t.repoId == _repo) &&
                (_server == null || t.serverId == _server),
          )
          .toList();
      final columns = [
        l.teamProjectBacklog,
        l.teamProjectReady,
        l.teamProjectWorking,
        l.teamProjectReview,
        l.teamProjectDone,
      ];
      int column(TeamTask t) => switch (t.status) {
        'running' => 2,
        'review' || 'verified' || 'waiting' || 'failed' || 'stalled' => 3,
        'done' || 'merged' => 4,
        _ => t.dependsOn.isEmpty ? 1 : 0,
      };
      KitTaskState mark(TeamTask t) => switch (column(t)) {
        2 => KitTaskState.working,
        3 => t.status == 'failed' ? KitTaskState.failed : KitTaskState.needsYou,
        4 => KitTaskState.done,
        _ => KitTaskState.waiting,
      };
      return KitScreen(
        topBar: KitTopBar(title: l.teamProjectBoard, subtitle: p.name),
        header: [
          _gutter(
            context,
            KitSegmented<bool>(
              segments: [
                KitSegment(value: false, label: l.teamProjectBoard),
                KitSegment(value: true, label: l.teamProjectGraph),
              ],
              selected: _graph,
              onChanged: (value) => setState(() => _graph = value),
              semanticsLabel: l.teamProjectBoard,
            ),
          ),
          KitPickerRow<String>(
            title: l.teamProjectMilestoneFilter,
            choices: [
              KitChoice(value: '', title: l.teamProjectAll),
              for (final m in p.specDraft.milestones)
                KitChoice(value: m.id, title: m.title),
            ],
            selected: _milestone ?? '',
            onSelected: (value) =>
                setState(() => _milestone = value.isEmpty ? null : value),
          ),
          KitPickerRow<String>(
            title: l.teamProjectRepoFilter,
            choices: [
              KitChoice(value: '', title: l.teamProjectAll),
              for (final r in p.repos) KitChoice(value: r.id, title: r.name),
            ],
            selected: _repo ?? '',
            onSelected: (value) =>
                setState(() => _repo = value.isEmpty ? null : value),
          ),
          KitPickerRow<String>(
            title: l.teamProjectServerFilter,
            choices: [
              KitChoice(value: '', title: l.teamProjectAll),
              for (final s in c.snapshot!.servers)
                KitChoice(value: s.id, title: s.name),
            ],
            selected: _server ?? '',
            onSelected: (value) =>
                setState(() => _server = value.isEmpty ? null : value),
          ),
        ],
        body: _graph
            ? ListView(
                padding: KitScreen.padding(context),
                children: [
                  KitWorkGraph(
                    nodes: [
                      for (final t in tasks)
                        KitWorkGraphNode(
                          id: t.id,
                          title: t.title,
                          mark: mark(t),
                          dependsOn: t.dependsOn,
                          word: _word(l, t.status),
                        ),
                    ],
                    onOpen: (id) => _openTask(context, c, p.id, id),
                  ),
                ],
              )
            : KitBoardLanes(
                columns: [
                  for (var i = 0; i < columns.length; i++)
                    KitBoardColumn(
                      label: columns[i],
                      count: tasks.where((t) => column(t) == i).length,
                    ),
                ],
                // Opens where the work is, not on an empty Backlog.
                selected:
                    _column ??
                    () {
                      for (var i = 0; i < columns.length; i++) {
                        if (tasks.any((t) => column(t) == i)) return i;
                      }
                      return 0;
                    }(),
                onSelected: (value) => setState(() => _column = value),
                laneBuilder: (context, i) => KitBoardLane(
                  cards: [
                    for (final t in tasks.where((t) => column(t) == i))
                      KitTaskCard(
                        key: ValueKey(t.id),
                        title: t.title,
                        mark: mark(t),
                        onOpen: () => _openTask(context, c, p.id, t.id),
                      ),
                  ],
                  empty: KitStateView(
                    icon: Icons.task_alt,
                    title: l.teamProjectNoTasks,
                    size: KitStateSize.inline,
                  ),
                ),
              ),
      );
    },
  );
}

class TeamProjectTimeline extends StatefulWidget {
  const TeamProjectTimeline({
    super.key,
    required this.controller,
    required this.projectId,
  });
  final TeamProjectController controller;
  final String projectId;
  @override
  State<TeamProjectTimeline> createState() => _TeamProjectTimelineState();
}

class _TeamProjectTimelineState extends State<TeamProjectTimeline> {
  String _filter = '';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final l = lookupAppLocalizations(Localizations.localeOf(context));
      final p = widget.controller.snapshot?.projects
          .where((p) => p.id == widget.projectId)
          .firstOrNull;
      final events = [...?p?.timeline].reversed.where(
        (e) =>
            _filter.isEmpty ||
            (_filter == 'problem'
                ? ['failed', 'problem', 'stalled', 'paused'].contains(e.kind)
                : e.kind == _filter),
      );
      final days = <String, List<TeamTimelineEvent>>{};
      for (final e in events) {
        final at = DateTime.tryParse(e.at);
        final day = at == null
            ? l.teamProjectUnknown
            : shortDateLabel(at, localeName: l.localeName);
        (days[day] ??= []).add(e);
      }
      return KitScreen(
        topBar: KitTopBar(title: l.teamProjectTimeline, subtitle: p?.name),
        header: [
          _gutter(
            context,
            KitSegmented<String>(
              segments: [
                KitSegment(value: '', label: l.teamProjectAll),
                KitSegment(value: 'decision', label: l.teamProjectDecisions),
                KitSegment(value: 'merge', label: l.teamProjectMerges),
                KitSegment(value: 'problem', label: l.teamProjectProblems),
              ],
              selected: _filter,
              onChanged: (v) => setState(() => _filter = v),
              semanticsLabel: l.teamProjectTimeline,
            ),
          ),
        ],
        body: ListView(
          padding: KitScreen.padding(context),
          children: [
            if (days.isEmpty)
              KitStateView(icon: Icons.history, title: l.teamProjectNoTasks),
            for (final day in days.entries)
              KitTimelineDay(
                title: day.key,
                status: p?.simulated == true ? l.teamProjectDemo : '',
                items: [
                  for (final group in _foldRepeats(day.value))
                    KitTeamItem(
                      title: group.count > 1
                          ? l.teamProjectTimelineRepeated(
                              group.first.text,
                              group.count,
                            )
                          : group.first.text,
                      detail: _role(
                        context,
                        widget.controller,
                        group.first.actor,
                      ),
                      meta: _age(context, group.first.at),
                      onPressed: group.first.taskId.isEmpty
                          ? null
                          : () => _openTask(
                              context,
                              widget.controller,
                              widget.projectId,
                              group.first.taskId,
                            ),
                    ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

class TeamProjectServers extends StatelessWidget {
  const TeamProjectServers({
    super.key,
    required this.controller,
    required this.projectId,
  });
  final TeamProjectController controller;
  final String projectId;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = lookupAppLocalizations(Localizations.localeOf(context));
      final p = controller.snapshot?.projects
          .where((p) => p.id == projectId)
          .firstOrNull;
      if (p == null) {
        return KitStateView(
          icon: Icons.work_outline,
          title: l.teamProjectSelect,
        );
      }
      return KitScreen(
        topBar: KitTopBar(title: l.teamProjectServers, subtitle: p.name),
        body: ListView(
          padding: KitScreen.padding(context),
          children: [
            if (controller.snapshot!.servers.any((s) => s.phone && !s.online))
              TeamPhoneServerProblem(controller: controller)
            else
              TeamExecutionBlocked(controller: controller),
            if (controller.errorCode != null) _failure(context, controller),
            if (p.simulated)
              KitText(l.teamProjectCostDemo, role: KitTextRole.secondary),
            for (final s in controller.snapshot!.servers) ...[
              KitServerLane(
                title: s.name,
                status: controller.errorCode == 'unavailable'
                    ? l.teamProjectTaskStale
                    : s.online
                    ? l.teamProjectOnline
                    : l.teamProjectOffline,
                state: controller.errorCode == 'unavailable'
                    ? KitTeamState.stale
                    : s.online
                    ? KitTeamState.done
                    : KitTeamState.stale,
                summary: l.teamProjectLaneCount(
                  p.tasks
                      .where((t) => t.serverId == s.id && t.status == 'running')
                      .length,
                  // The project's own limit applies on this server too.
                  _lanesHere(p, s.laneCap),
                ),
                items: [
                  for (final t in p.tasks.where((t) => t.serverId == s.id))
                    KitTeamItem(
                      title: t.title,
                      detail: controller.errorCode == 'unavailable'
                          ? l.teamProjectTaskStale
                          : _word(l, t.status),
                      onPressed: () =>
                          _openTask(context, controller, p.id, t.id),
                    ),
                ],
              ),
              KitButton(
                role: KitButtonRole.tertiary,
                label: l.teamProjectEditorMaxLanes,
                onPressed: () async {
                  final revision = controller.snapshot!.revision;
                  await showKitInputDialog(
                    context,
                    title: s.name,
                    label: l.teamProjectEditorMaxLanes,
                    initial: s.laneCap.toString(),
                    kind: KitFieldKind.number,
                    confirmLabel: l.teamProjectEditorSave,
                    validate: (value) => (int.tryParse(value) ?? 0) > 0
                        ? null
                        : l.teamProjectEditorPositiveLanes,
                    onSubmit: (value) async {
                      final result = await controller.execute(
                        TeamProjectCommand(
                          requestId: controller.newRequestId(),
                          action: TeamProjectAction.updateServer,
                          expectedRevision: revision,
                          server: s.copyWith(laneCap: int.parse(value)),
                        ),
                      );
                      return result.accepted ? null : l.teamProjectError;
                    },
                  );
                },
              ),
              for (final t in p.tasks.where(
                (t) =>
                    TeamExecutionGate.allows(
                      controller,
                      TeamExecutionNeed.placement,
                    ) &&
                    t.serverId == s.id &&
                    t.status != 'merged' &&
                    t.status != 'done',
              ))
                KitPickerRow<String>(
                  title: '${l.teamProjectMove} · ${t.title}',
                  choices: [
                    for (final target in controller.snapshot!.servers)
                      KitChoice(value: target.id, title: target.name),
                  ],
                  selected: t.serverId,
                  onSelected: (target) async {
                    if (target == t.serverId) return;
                    final note = await showKitInputDialog(
                      context,
                      title: l.teamProjectMoveTo,
                      label: l.teamProjectHandoff,
                      confirmLabel: l.teamProjectMove,
                    );
                    if (note == null) return;
                    final latest = controller.snapshot!.projects.firstWhere(
                      (value) => value.id == p.id,
                    );
                    final result = await _command(
                      controller,
                      latest,
                      TeamProjectAction.moveTask,
                      targetId: t.id,
                      serverId: target,
                      text: note,
                    );
                    if ((result.code == 'branchUnavailable' ||
                            result.code == 'sharedRemoteRequired') &&
                        context.mounted) {
                      final restart = await showKitConfirm(
                        context,
                        title: l.teamProjectRestartElsewhere,
                        body: l.teamProjectRestartElsewhereBody,
                        confirmLabel: l.teamProjectRestartElsewhere,
                        cancelLabel: l.teamProjectWaitForServer,
                      );
                      if (restart) {
                        await _command(
                          controller,
                          latest,
                          TeamProjectAction.moveTask,
                          targetId: t.id,
                          serverId: target,
                          text: note,
                          confirmed: true,
                        );
                      }
                    }
                  },
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _Repeat {
  _Repeat(this.first) : count = 1;
  final TeamTimelineEvent first;
  int count;
}

/// Newest-first events with back-to-back rows of identical words and task
/// folded into one row that says how many there were.
List<_Repeat> _foldRepeats(List<TeamTimelineEvent> events) {
  final out = <_Repeat>[];
  for (final e in events) {
    final last = out.lastOrNull;
    if (last != null &&
        last.first.text == e.text &&
        last.first.taskId == e.taskId &&
        last.first.actor == e.actor) {
      last.count++;
    } else {
      out.add(_Repeat(e));
    }
  }
  return out;
}
