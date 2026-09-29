import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../domain/relative_age.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../state/team_project_controller.dart';
import '../../../kit/kit.dart';
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
          subtitle: c.snapshot?.simulated == true ? l.teamProjectDemo : null,
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
                detail: p.budgetWarning ? l.teamProjectBudgetNear : null,
                status: c.errorCode == 'unavailable'
                    ? l.teamProjectTaskStale
                    : _progress(l, p),
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
        bottom: KitActionBlock(
          primary: KitAction(
            label: l.teamProjectNew,
            onPressed: () => openTeamNewProject(context, c),
          ),
          tertiary: [
            KitAction(
              label: l.teamProjectQuick,
              onPressed: () => openTeamNewProject(context, c, quick: true),
            ),
          ],
        ),
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
      return KitScreen(
        topBar: embedded
            ? null
            : KitTopBar(
                title: p.name,
                subtitle: c.errorCode == 'unavailable'
                    ? l.teamProjectTaskStale
                    : _progress(l, p),
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
            if (embedded) KitText(p.name, role: KitTextRole.title),
            if (c.errorCode != null) _failure(context, c),
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
            for (final r in p.requests.where((r) => !r.answered))
              KitPlanCard(
                title: r.title,
                status: l.teamProjectNeedsYou,
                state: KitTeamState.needsYou,
                actions: [
                  KitAction(
                    label: _requestLabel(l, r),
                    onPressed: () => _answer(context, c, p, r),
                  ),
                ],
              ),
            KitPlanCard(
              title: p.specDraft.goal,
              status: _word(l, p.status),
              summary: p.specDraft.constraints,
              actions: [
                KitAction(
                  label: l.teamProjectSpec,
                  onPressed: () => openTeamSpecEditor(context, c, p.id),
                ),
                KitAction(
                  label: l.teamProjectPlan,
                  onPressed: () => openTeamPlanEditor(context, c, p.id),
                ),
              ],
            ),
            KitSectionLabel.inline(l.teamProjectMilestones),
            for (final m in p.specDraft.milestones)
              Builder(
                builder: (context) {
                  final phaseIds = p.phases
                      .where((ph) => ph.milestoneId == m.id)
                      .map((ph) => ph.id)
                      .toSet();
                  final tasks = p.tasks
                      .where((t) => phaseIds.contains(t.phaseId))
                      .toList();
                  final complete = tasks
                      .where((t) => t.status == 'merged' || t.status == 'done')
                      .length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      KitMilestoneRow(
                        title: m.title,
                        status: m.accepted
                            ? l.teamProjectDone
                            : _progress(l, p.copyWith(tasks: tasks)),
                        completed: complete,
                        total: tasks.length,
                        detail: m.criteria.join('\n'),
                        onPressed: () =>
                            _openBoard(context, c, p.id, milestone: m.id),
                      ),
                      if (!m.accepted &&
                          tasks.isNotEmpty &&
                          complete == tasks.length)
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
            KitSectionLabel.inline(l.teamProjectLanes),
            KitText(
              l.teamProjectLaneCount(
                p.tasks.where((t) => t.status == 'running').length,
                p.settings.mode == 'single' ? 1 : p.settings.maxLanes,
              ),
              role: KitTextRole.secondary,
            ),
            for (final server in c.snapshot!.servers)
              if (p.tasks.any((t) => t.serverId == server.id))
                KitServerLane(
                  title: server.name,
                  status: c.errorCode == 'unavailable'
                      ? l.teamProjectTaskStale
                      : server.online
                      ? l.teamProjectOnline
                      : l.teamProjectOffline,
                  state: c.errorCode == 'unavailable'
                      ? KitTeamState.stale
                      : server.online
                      ? KitTeamState.running
                      : KitTeamState.stale,
                  items: [
                    for (final t in p.tasks.where(
                      (t) => t.serverId == server.id && t.status != 'merged',
                    ))
                      KitTeamItem(
                        title: t.title,
                        detail:
                            '${_role(context, c, t.roleId)} · ${c.errorCode == 'unavailable' ? l.teamProjectTaskStale : _word(l, t.status)}',
                        state: c.errorCode == 'unavailable'
                            ? KitTeamState.stale
                            : _state(t.status),
                        onPressed: () => task(t),
                      ),
                  ],
                ),
            if (p.simulated)
              KitText(l.teamProjectCostDemo, role: KitTextRole.caption),
            for (final repo in p.repos)
              if (p.mergeQueue.any((i) => i.repoId == repo.id))
                KitMergeQueue(
                  title: '${l.teamProjectMerge} · ${repo.name}',
                  status: 'dev',
                  items: [
                    for (final i in p.mergeQueue.where(
                      (i) => i.repoId == repo.id,
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
                            : _word(l, i.status),
                        state: _state(i.status),
                        onPressed: () => _openTask(context, c, p.id, i.taskId),
                      ),
                  ],
                  actions: [
                    KitAction(
                      label: l.teamProjectMergeNext,
                      onPressed: () => _merge(context, c, p, repo),
                    ),
                  ],
                ),
            KitSectionLabel.inline(l.teamProjectDecisions),
            for (final e
                in p.timeline
                    .where((e) => e.kind == 'decision')
                    .toList()
                    .reversed
                    .take(3))
              KitRow(
                title: e.text,
                supporting: TextSpan(text: _age(context, e.at)),
              ),
            KitSectionLabel.inline(l.teamProjectCost),
            if (p.budgetWarning) KitNotice(message: l.teamProjectBudgetNear),
            KitText(
              l.teamProjectSpend(
                p.usageReported
                    ? p.spentToday.toStringAsFixed(2)
                    : l.teamProjectUnknown,
                p.settings.budget.daily?.toStringAsFixed(2) ??
                    l.teamProjectNoLimit,
                p.usageReported
                    ? p.spent.toStringAsFixed(2)
                    : l.teamProjectUnknown,
                p.settings.budget.total?.toStringAsFixed(2) ??
                    l.teamProjectNoLimit,
              ),
            ),
            KitRow(
              title: l.teamProjectBoard,
              onTap: () => _openBoard(context, c, p.id),
            ),
            KitRow(
              title: l.teamProjectTimeline,
              onTap: () => pushKitPage<void>(
                context,
                (_) => TeamProjectTimeline(controller: c, projectId: p.id),
              ),
            ),
            KitRow(
              title: l.teamProjectServers,
              onTap: () => pushKitPage<void>(
                context,
                (_) => TeamProjectServers(controller: c, projectId: p.id),
              ),
            ),
            KitRow(
              title: l.teamProjectSettings,
              onTap: () => openTeamProjectSettings(context, c, p.id),
            ),
            KitButton(
              role: KitButtonRole.tertiary,
              label: p.status == 'paused'
                  ? l.teamProjectResume
                  : l.teamProjectPause,
              onPressed: () => _command(
                c,
                p,
                p.status == 'paused'
                    ? TeamProjectAction.resumeProject
                    : TeamProjectAction.pauseProject,
              ),
            ),
            if (p.simulated && p.status == 'plan')
              KitButton(
                role: KitButtonRole.tertiary,
                label: l.teamProjectDemoPlanFailure,
                onPressed: () =>
                    _command(c, p, TeamProjectAction.simulatePlanFailure),
              ),
            if (p.simulated)
              KitButton(
                role: KitButtonRole.tertiary,
                label: l.teamProjectAdvance,
                onPressed: () => _command(c, p, TeamProjectAction.advance),
              ),
            KitButton(
              role: KitButtonRole.tertiary,
              label: l.teamProjectStop,
              destructive: true,
              onPressed: () async {
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
          ],
        ),
      );
    },
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
Future<void> _merge(
  BuildContext context,
  TeamProjectController c,
  TeamProject p,
  TeamRepo repo,
) async {
  final l = lookupAppLocalizations(Localizations.localeOf(context));
  final reviewed = p;
  var confirmed = false;
  if (p.settings.reviewLevel == 'everyStep') {
    confirmed = await showKitConfirm(
      context,
      title: l.teamProjectMergeNext,
      body: l.teamProjectMergeConfirmBody,
      confirmLabel: l.teamProjectMergeNext,
    );
    if (!confirmed) return;
  }
  await _command(
    c,
    reviewed,
    TeamProjectAction.processMergeQueue,
    targetId: repo.id,
    confirmed: confirmed,
  );
}

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
  _ => KitTeamState.done,
};
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
  int _column = 0;
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
          KitSegmented<bool>(
            segments: [
              KitSegment(value: false, label: l.teamProjectBoard),
              KitSegment(value: true, label: l.teamProjectGraph),
            ],
            selected: _graph,
            onChanged: (value) => setState(() => _graph = value),
            semanticsLabel: l.teamProjectBoard,
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
                selected: _column,
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
                  for (final e in day.value)
                    KitTeamItem(
                      title: e.text,
                      detail: _role(context, widget.controller, e.actor),
                      meta: _age(context, e.at),
                      onPressed: e.taskId.isEmpty
                          ? null
                          : () => _openTask(
                              context,
                              widget.controller,
                              widget.projectId,
                              e.taskId,
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
                  s.laneCap,
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
