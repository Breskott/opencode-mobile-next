import 'dart:async';
import 'dart:convert';
import '../../../domain/orchestration_gateway.dart';
import '../../../ui/kit/kit_redact.dart';
import '../none.dart';

/// Local deterministic simulator. Never starts agents or writes repositories.
class ProjectFixtureGateway extends NullOrchestrationGateway
    implements OrchestrationProjectGateway {
  ProjectFixtureGateway({
    required this.persistence,
    DateTime Function()? now,
    Duration? tickInterval,
    this.seedDemo = true,
    this.readOnly = false,
    this.isCharging = true,
  }) : _now = now ?? DateTime.now {
    if (tickInterval != null && !readOnly) {
      _timer = Timer.periodic(tickInterval, (_) {
        unawaited(advance().catchError((Object _) {}));
      });
    }
  }
  final TeamProjectPersistence persistence;
  final DateTime Function() _now;
  final bool seedDemo;
  final bool readOnly;
  bool isCharging;
  final _changes = StreamController<TeamWorkspace>.broadcast();
  TeamWorkspace? _state;
  Map<String, dynamic> _requests = {};
  Future<void> _tail = Future.value();
  Timer? _timer;
  bool _closed = false;
  Future<void>? _closing;
  @override
  bool get isClosed => _closed;
  @override
  OrchestrationHostIdentity get host => const OrchestrationHostIdentity(
    provider: 'fixture',
    url: 'fixture://project-demo',
    hostMode: OrchestrationHostMode.computer,
  );
  @override
  OrchestrationCapabilities get capabilities => const OrchestrationCapabilities(
    projects: true,
    workGraph: true,
    gatesInteractions: true,
    controlRespond: true,
    eventStream: true,
    projectLifecycle: true,
    livingSpec: true,
    projectLanes: true,
    projectPlacement: true,
    projectVerification: true,
    projectMergeQueue: true,
    projectPromotion: true,
    projectBudgets: true,
    projectDigest: true,
  );
  String get _at => _now().toUtc().toIso8601String();
  Never _fail<T>(String code) => throw _Refused(code);
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _load() async {
    if (_state != null) return;
    final raw = await persistence.read();
    if (raw != null) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['schemaVersion'] != 1) _fail<void>('unsupportedVersion');
      _requests = Map<String, dynamic>.from(json['requests'] as Map? ?? {});
      var state = TeamWorkspace.fromJson(
        Map<String, dynamic>.from(json['workspace'] as Map),
      );
      if (readOnly) {
        _state = state;
        return;
      }
      state = state.copyWith(
        projects: state.projects
            .map(
              (p) => p.copyWith(
                tasks: p.tasks
                    .map(
                      (t) => t.status == 'running'
                          ? t.copyWith(
                              status: 'interrupted',
                              reason: 'Continue from the saved branch',
                              changedAt: _at,
                            )
                          : t,
                    )
                    .toList(),
              ),
            )
            .toList(),
      );
      await _persist(state, _requests);
      _state = state;
    } else {
      if (readOnly) {
        _state = const TeamWorkspace();
        return;
      }
      final state = _initial();
      await _persist(state, {});
      _state = state;
    }
  }

  Future<void> _persist(TeamWorkspace state, Map<String, dynamic> requests) =>
      persistence.write(
        jsonEncode(
          _redact({
            'schemaVersion': 1,
            'workspace': state.toJson(),
            'requests': requests,
          }),
        ),
      );
  Object? _redact(Object? v) => switch (v) {
    String s => KitRedact.text(s),
    List a => a.map(_redact).toList(),
    Map a => a.map((k, v) => MapEntry(k, _redact(v))),
    _ => v,
  };
  @override
  Future<TeamWorkspace> teamWorkspace() => _serial(() async {
    if (_closed) return _state ?? const TeamWorkspace();
    await _load();
    return _state!;
  });
  @override
  Stream<TeamWorkspace> watchTeamWorkspace() => _changes.stream;
  @override
  Future<TeamCommandResult> executeProject(
    TeamProjectCommand command,
  ) => _serial(() async {
    if (readOnly) {
      return const TeamCommandResult(accepted: false, code: 'readOnly');
    }
    if (_closed) {
      return const TeamCommandResult(accepted: false, code: 'closed');
    }
    try {
      await _load();
      if (command.requestId.trim().isEmpty) _fail<void>('requestIdRequired');
      final fingerprint = jsonEncode(_redact(command.toJson()));
      final previous = _requests[command.requestId];
      if (previous is Map) {
        if (previous['fingerprint'] != fingerprint) {
          _fail<void>('requestIdReused');
        }
        return TeamCommandResult(
          accepted: true,
          projectId: previous['projectId'] as String,
          revision: previous['revision'] as int,
          replayed: true,
        );
      }
      final next = _apply(_state!, command);
      final id =
          command.projectId.isEmpty &&
              (command.action == TeamProjectAction.createProject ||
                  command.action == TeamProjectAction.createQuickTask)
          ? next.projects.last.id
          : command.projectId;
      final revision =
          next.projects.where((p) => p.id == id).firstOrNull?.revision ??
          next.revision;
      final requests = Map<String, dynamic>.from(_requests)
        ..[command.requestId] = {
          'fingerprint': fingerprint,
          'projectId': id,
          'revision': revision,
        };
      // Decode the redacted representation so published snapshots also contain no secrets.
      final safe = TeamWorkspace.fromJson(
        Map<String, dynamic>.from(_redact(next.toJson()) as Map),
      );
      await _persist(safe, requests);
      _state = safe;
      _requests = requests;
      if (!_closed) _changes.add(safe);
      return TeamCommandResult(
        accepted: true,
        projectId: id,
        revision: revision,
      );
    } on _Refused catch (e) {
      return TeamCommandResult(accepted: false, code: e.code);
    } catch (_) {
      return const TeamCommandResult(accepted: false, code: 'saveFailed');
    }
  });
  Future<void> advance() async {
    if (_closed) return;
    final state = await teamWorkspace();
    for (final project in state.projects.where((p) => p.status == 'running')) {
      await executeProject(
        TeamProjectCommand(
          requestId: 'tick-${state.revision}-${project.id}',
          action: TeamProjectAction.advance,
          projectId: project.id,
          expectedRevision: project.revision,
        ),
      );
    }
  }

  @override
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    _closed = true;
    _timer?.cancel();
    await _tail;
    if (!_changes.isClosed) await _changes.close();
  }

  @override
  Stream<OrchestrationEvent> events({
    EventCursor resumeFrom = EventCursor.none,
  }) => _changes.stream.expand(
    (w) => <OrchestrationEvent>[
      BeadChanged(
        beadId: 'project-workspace',
        change: BeadChange.updated,
        seq: w.revision * 2,
      ),
      GateChanged(gateId: 'project-requests', seq: w.revision * 2 + 1),
    ],
  );

  @override
  Future<void> deleteLocalData() async {
    if (readOnly) {
      await close();
      return;
    }
    _closed = true;
    _timer?.cancel();
    await _tail;
    await persistence.delete();
    _state = const TeamWorkspace();
    _requests = {};
    if (!_changes.isClosed) await _changes.close();
  }

  @override
  Future<List<OrchestrationProject>> projects() async => (await teamWorkspace())
      .projects
      .map(
        (p) => OrchestrationProject(
          id: p.id,
          name: p.name,
          raw: {'simulated': true},
        ),
      )
      .toList();
  @override
  Future<List<WorkItem>> work({String? projectId}) async =>
      (await teamWorkspace()).projects
          .where((p) => projectId == null || p.id == projectId)
          .expand(
            (p) => p.tasks.map(
              (t) => WorkItem(
                id: t.id,
                title: t.title,
                state: WorkState.fromProvider(t.status),
                projectId: p.id,
                assignee: t.roleId,
                dependsOn: t.dependsOn,
                updatedAt: DateTime.tryParse(t.changedAt),
                raw: {'simulated': true},
              ),
            ),
          )
          .toList();
  @override
  Future<List<OrchestrationGate>> gates() async => (await teamWorkspace())
      .projects
      .expand(
        (p) => p.requests
            .where((r) => !r.answered)
            .map(
              (r) => OrchestrationGate(
                id: r.id,
                kind: GateKind.freeText,
                title: r.title,
                workId: r.taskId,
                createdAt: DateTime.tryParse(r.createdAt),
                raw: {'projectId': p.id, 'simulated': true},
              ),
            ),
      )
      .toList();
  @override
  Future<MutationReceipt> respond(
    String gateId,
    GateResponse response, {
    required String requestId,
  }) async {
    final state = await teamWorkspace();
    final p = state.projects
        .where((p) => p.requests.any((r) => r.id == gateId))
        .firstOrNull;
    if (p == null) {
      return MutationReceipt.rejected(requestId, 'Request unavailable');
    }
    final r = await executeProject(
      TeamProjectCommand(
        requestId: requestId,
        action: TeamProjectAction.answerRequest,
        projectId: p.id,
        expectedRevision: p.revision,
        targetId: gateId,
        text: response.text ?? response.choice ?? '${response.confirmed}',
      ),
    );
    return MutationReceipt(
      id: requestId,
      status: r.accepted
          ? MutationReceiptStatus.accepted
          : MutationReceiptStatus.rejected,
      message: r.code,
    );
  }

  TeamWorkspace _apply(TeamWorkspace w, TeamProjectCommand c) {
    if (c.action == TeamProjectAction.updateDefaults) {
      _validateSettings(c.settings);
      return w.copyWith(revision: w.revision + 1, defaultSettings: c.settings);
    }
    if (c.action == TeamProjectAction.saveRole) {
      final role = c.role;
      if (role == null || role.id.isEmpty || role.name.trim().isEmpty) {
        return _fail('invalidRole');
      }
      if (role.id == 'checker' && !role.readOnly) {
        return _fail('checkerMustBeReadOnly');
      }
      return w.copyWith(
        revision: w.revision + 1,
        roles: [...w.roles.where((r) => r.id != role.id), role],
      );
    }
    if (c.action == TeamProjectAction.deleteRole) {
      if (w.projects.any((p) => p.tasks.any((t) => t.roleId == c.targetId))) {
        return _fail('roleInUse');
      }

      return w.copyWith(
        revision: w.revision + 1,
        roles: w.roles.where((r) => r.id != c.targetId).toList(),
      );
    }
    if (c.action == TeamProjectAction.updateServer) {
      final server = c.server;
      if (server == null || server.id.isEmpty || server.laneCap < 1) {
        return _fail('invalidServer');
      }
      return w.copyWith(
        revision: w.revision + 1,
        servers: [...w.servers.where((s) => s.id != server.id), server],
      );
    }
    if (c.action == TeamProjectAction.createProject ||
        c.action == TeamProjectAction.createQuickTask) {
      _validateSettings(c.settings);
      if (c.name.trim().isEmpty ||
          c.spec == null ||
          c.spec!.goal.trim().isEmpty ||
          c.repos.isEmpty) {
        return _fail('missingProjectDetails');
      }
      if (c.repos.any(
        (r) => r.id.isEmpty || !w.servers.any((s) => s.id == r.serverId),
      )) {
        return _fail('invalidPlacement');
      }
      final id = 'project-${w.revision + 1}';
      var p = TeamProject(
        id: id,
        name: c.name,
        settings: c.settings!,
        repos: c.repos,
        specDraft: c.spec!,
        updatedAt: _at,
        requests: [
          TeamRequest(
            id: '$id-question',
            title: 'What must the first milestone prove?',
            createdAt: _at,
          ),
        ],
      );
      p = p.copyWith(specDraft: _plan(p).specDraft);
      if (c.action == TeamProjectAction.createQuickTask) {
        if (c.repos.length != 1) return _fail('quickTaskNeedsOneRepo');
        if (c.roleId.isNotEmpty && !w.roles.any((r) => r.id == c.roleId)) {
          return _fail('roleNotFound');
        }
        if (c.serverId.isNotEmpty &&
            !w.servers.any((s) => s.id == c.serverId)) {
          return _fail('serverNotFound');
        }
        p = _plan(p).copyWith(
          status: c.confirmed ? 'running' : 'plan',
          planApproved: c.confirmed,
          quickTask: true,
          requests: [],
          specVersions: [
            c.spec!.copyWith(approvedBy: 'person', approvedAt: _at),
          ],
        );
        p = p.copyWith(
          tasks: [
            p.tasks.first.copyWith(
              title: c.spec!.goal,
              roleId: c.roleId.isEmpty ? p.tasks.first.roleId : c.roleId,
              serverId: c.serverId.isEmpty
                  ? p.tasks.first.serverId
                  : c.serverId,
            ),
          ],
        );
      }
      p = _syncRequests(p);
      p = _log(p, 'created', 'Project created with simulated work');
      return w.copyWith(revision: w.revision + 1, projects: [...w.projects, p]);
    }
    final foundProject = w.projects
        .where((p) => p.id == c.projectId)
        .firstOrNull;
    if (foundProject == null) return _fail('projectNotFound');
    TeamProject p = foundProject;
    if (c.expectedRevision != p.revision) return _fail('staleRevision');
    if (c.action == TeamProjectAction.deleteProject) {
      if (!c.confirmed) return _fail('confirmationRequired');
      return w.copyWith(
        revision: w.revision + 1,
        projects: w.projects.where((p) => p.id != c.projectId).toList(),
      );
    }
    final before = p;
    switch (c.action) {
      case TeamProjectAction.simulatePlanFailure:
        if (p.planApproved || p.specVersions.isEmpty) {
          return _fail('planSimulationUnavailable');
        }
        p = p.copyWith(status: 'planFailed');
      case TeamProjectAction.usePlanAsTask:
        if (p.status != 'planFailed') return _fail('planFallbackUnavailable');
        final planned = _plan(p);
        p = planned.copyWith(
          status: 'plan',
          quickTask: true,
          tasks: [planned.tasks.first.copyWith(title: p.specDraft.goal)],
        );
      case TeamProjectAction.retryPlan:
        if (p.status != 'planFailed') return _fail('planFallbackUnavailable');
        p = _plan(p).copyWith(status: 'plan');
      case TeamProjectAction.simulateManualCommit:
        final repo = p.repos.where((r) => r.id == c.targetId).firstOrNull;
        if (repo == null) return _fail('repoNotFound');
        final commit = c.text.trim().isEmpty
            ? 'fixture-person-${p.revision + 1}'
            : c.text.trim();
        p = p.copyWith(
          repos: p.repos
              .map((r) => r.id == repo.id ? r.copyWith(devCommit: commit) : r)
              .toList(),
          mergeQueue: p.mergeQueue
              .map(
                (m) =>
                    m.repoId == repo.id && m.status != 'merged' && c.confirmed
                    ? m.copyWith(
                        status: 'conflict',
                        reason: 'Changes on dev need a conflict resolution',
                      )
                    : m,
              )
              .toList(),
          receipts: [
            ...p.receipts,
            TeamProjectReceipt(
              id: c.requestId,
              kind: 'manualCommit',
              repoId: repo.id,
              before: repo.devCommit,
              after: commit,
              at: _at,
            ),
          ],
        );
        p = _log(
          p,
          c.confirmed ? 'conflict' : 'rebase',
          c.confirmed
              ? 'Manual changes preserved; resolve the conflicting edits'
              : 'Manual changes preserved; task branches rebased onto dev',
          actor: 'fixture',
        );
      case TeamProjectAction.simulateConflict:
        if (!p.mergeQueue.any(
          (m) => m.id == c.targetId && m.status != 'merged',
        )) {
          return _fail('queueItemNotFound');
        }
        p = p.copyWith(
          mergeQueue: p.mergeQueue
              .map(
                (m) => m.id == c.targetId
                    ? m.copyWith(
                        status: 'conflict',
                        reason: 'Simulated overlapping edits need a resolution',
                      )
                    : m,
              )
              .toList(),
        );
      case TeamProjectAction.requestSpecChange:
        if (c.text.trim().isEmpty) return _fail('emptyMessage');
        p = p.copyWith(
          specDraft: p.specDraft.copyWith(
            constraints:
                '${p.specDraft.constraints}\nProposed change: ${c.text}'.trim(),
            version: p.specVersions.length + 1,
            approvedBy: '',
            approvedAt: '',
          ),
          tasks: p.tasks
              .map((t) => t.copyWith(affected: t.status != 'merged'))
              .toList(),
        );
      case TeamProjectAction.saveSpecDraft:
        if (c.spec == null || c.spec!.goal.trim().isEmpty) {
          return _fail('invalidSpec');
        }
        p = p.copyWith(
          specDraft: c.spec!.copyWith(
            version: p.specVersions.length + 1,
            approvedBy: '',
            approvedAt: '',
          ),
          tasks: p.tasks
              .map((t) => t.copyWith(affected: t.status != 'merged'))
              .toList(),
        );
      case TeamProjectAction.approveSpec:
        if (p.requests.any((r) => !r.answered && r.kind == 'question')) {
          return _fail('answerQuestionsFirst');
        }
        final approved = p.specDraft.copyWith(
          version: p.specVersions.length + 1,
          approvedBy: 'person',
          approvedAt: _at,
        );
        final revised = p.copyWith(
          specDraft: approved,
          specVersions: [...p.specVersions, approved],
        );
        p = p.tasks.isEmpty ? _plan(revised.copyWith(status: 'plan')) : revised;
      case TeamProjectAction.approvePlan:
        if (p.specVersions.isEmpty) return _fail('approveSpecFirst');
        if (p.tasks.any((t) => t.status != 'queued') && c.tasks != null) {
          return _fail('planAlreadyRunning');
        }
        final edited = c.tasks;
        if (edited != null &&
            edited.any(
              (t) =>
                  t.status != 'queued' || t.steps != 0 || t.findings.isNotEmpty,
            )) {
          return _fail('invalidPlan');
        }
        p = p.copyWith(tasks: edited ?? p.tasks, phases: c.phases ?? p.phases);
        _validatePlan(p, w);
        p = p.copyWith(status: 'running', planApproved: true);
      case TeamProjectAction.replan:
        if (p.specVersions.isEmpty) return _fail('approveSpecFirst');
        final incoming = c.tasks ?? _plan(p).tasks;
        if (incoming.any(
          (t) => t.steps != 0 || t.findings.isNotEmpty || t.status != 'queued',
        )) {
          return _fail('invalidPlan');
        }
        if (c.phases != null) {
          p = p.copyWith(
            phases: p.phases
                .map(
                  (phase) =>
                      p.tasks.any(
                        (t) =>
                            t.phaseId == phase.id &&
                            (t.status != 'queued' || t.steps > 0),
                      )
                      ? phase
                      : c.phases!
                                .where((next) => next.id == phase.id)
                                .firstOrNull ??
                            phase,
                )
                .toList(),
          );
        }
        p = p.copyWith(
          tasks: p.tasks
              .map(
                (t) =>
                    t.affected &&
                        const [
                          'queued',
                          'paused',
                          'interrupted',
                        ].contains(t.status)
                    ? (incoming.where((n) => n.id == t.id).firstOrNull ?? t)
                          .copyWith(affected: false)
                    : t,
              )
              .toList(),
        );
        _validatePlan(p, w);
      case TeamProjectAction.answerRequest:
        final r = p.requests.where((r) => r.id == c.targetId).firstOrNull;
        if (r == null || r.answered || c.text.trim().isEmpty) {
          return _fail('requestUnavailable');
        }
        if (r.kind != 'question' && r.kind != 'permission') {
          return _fail('useTargetedAction');
        }
        p = p.copyWith(
          requests: p.requests
              .map(
                (r) => r.id == c.targetId
                    ? r.copyWith(answered: true, answer: c.text)
                    : r,
              )
              .toList(),
          specDraft: p.specDraft.copyWith(
            decisions: '${p.specDraft.decisions}\n${c.text}'.trim(),
          ),
          tasks: p.tasks
              .map(
                (t) => t.id == r.taskId
                    ? t.copyWith(status: 'queued', reason: '')
                    : t,
              )
              .toList(),
        );
      case TeamProjectAction.updateSettings:
        _validateSettings(c.settings);
        p = p.copyWith(settings: c.settings);
      case TeamProjectAction.pauseProject:
        p = p.copyWith(
          status: 'paused',
          tasks: p.tasks
              .map(
                (t) => t.status == 'running'
                    ? t.copyWith(
                        status: 'paused',
                        reason: 'Project paused',
                        changedAt: _at,
                      )
                    : t,
              )
              .toList(),
        );
      case TeamProjectAction.resumeProject:
        if (!p.planApproved) return _fail('approvePlanFirst');
        if (p.specVersions.isEmpty) return _fail('approveSpecFirst');
        p = p.copyWith(
          status: 'running',
          tasks: p.tasks
              .map(
                (t) => const ['paused', 'interrupted'].contains(t.status)
                    ? t.copyWith(status: 'queued', reason: '')
                    : t,
              )
              .toList(),
        );
      case TeamProjectAction.stopProject:
        p = p.copyWith(
          status: 'stopped',
          tasks: p.tasks
              .map(
                (t) => const ['merged', 'done'].contains(t.status)
                    ? t
                    : t.copyWith(
                        status: 'stopped',
                        reason: 'Stopped by you',
                        changedAt: _at,
                      ),
              )
              .toList(),
        );
      case TeamProjectAction.messageTask:
      case TeamProjectAction.pauseTask:
      case TeamProjectAction.resumeTask:
      case TeamProjectAction.restartTask:
      case TeamProjectAction.stopTask:
      case TeamProjectAction.moveTask:
      case TeamProjectAction.verifyTask:
      case TeamProjectAction.fixFindings:
      case TeamProjectAction.recheckTask:
      case TeamProjectAction.ignoreFinding:
        final task = p.tasks.where((t) => t.id == c.targetId).firstOrNull;
        if (task == null) return _fail('taskNotFound');
        final changed = _task(task, c, p, w);
        p = p.copyWith(
          tasks: p.tasks.map((t) => t.id == task.id ? changed : t).toList(),
        );
        if (changed.status == 'done' && changed.id.startsWith('resolve-')) {
          p = p.copyWith(
            mergeQueue: p.mergeQueue
                .map(
                  (m) => 'resolve-${m.id}' == changed.id
                      ? m.copyWith(
                          status: 'queued',
                          reason: 'Resolution checked in the task branch',
                        )
                      : m,
                )
                .toList(),
          );
        }
        if (changed.status == 'done' &&
            !changed.id.startsWith('resolve-') &&
            !p.mergeQueue.any((m) => m.taskId == task.id)) {
          p = p.copyWith(
            mergeQueue: [
              ...p.mergeQueue,
              TeamMergeItem(
                id: 'merge-${task.id}',
                taskId: task.id,
                repoId: task.repoId,
              ),
            ],
          );
        }
      case TeamProjectAction.processMergeQueue:
        p = _merge(p, c);
      case TeamProjectAction.resolveConflict:
        final item = p.mergeQueue
            .where((m) => m.id == c.targetId && m.status == 'conflict')
            .firstOrNull;
        if (item == null) return _fail('conflictNotFound');
        if (!const ['agent', 'manual', 'recheck'].contains(c.text)) {
          return _fail('resolutionStrategyRequired');
        }
        if (c.text == 'agent') {
          if (p.tasks.any((t) => t.id == 'resolve-${item.id}')) {
            return _fail('resolutionAlreadyStarted');
          }
          final source = p.tasks.firstWhere((t) => t.id == item.taskId);
          p = p.copyWith(
            tasks: [
              ...p.tasks,
              TeamTask(
                id: 'resolve-${item.id}',
                title: 'Resolve conflicting changes',
                phaseId: source.phaseId,
                roleId: 'backend',
                repoId: source.repoId,
                serverId: source.serverId,
                branch: source.branch,
                criteria: [
                  'Both sets of changes remain intact',
                  'Repository checks pass',
                ],
                changedAt: _at,
              ),
            ],
            mergeQueue: p.mergeQueue
                .map(
                  (m) => m.id == item.id
                      ? m.copyWith(reason: 'Waiting for the resolution task')
                      : m,
                )
                .toList(),
          );
        } else if (c.text == 'manual') {
          p = p.copyWith(
            mergeQueue: p.mergeQueue
                .map(
                  (m) => m.id == item.id
                      ? m.copyWith(
                          reason: 'Waiting for your conflict resolution',
                        )
                      : m,
                )
                .toList(),
          );
        } else {
          if (item.reason != 'Waiting for your conflict resolution') {
            return _fail('manualResolutionNotStarted');
          }
          p = p.copyWith(
            mergeQueue: p.mergeQueue
                .map(
                  (m) => m.id == item.id
                      ? m.copyWith(
                          status: 'queued',
                          reason:
                              'Simulated local checks passed after your resolution',
                        )
                      : m,
                )
                .toList(),
          );
        }
      case TeamProjectAction.promote:
        p = _promote(p, c);
      case TeamProjectAction.acknowledgeDigest:
        p = p.copyWith(digestReadAt: _at);
      case TeamProjectAction.acceptPhase:
        if (!p.phases.any((phase) => phase.id == c.targetId) ||
            p.tasks
                .where((t) => t.phaseId == c.targetId)
                .any((t) => t.status != 'merged')) {
          return _fail('phaseNotReady');
        }
        p = p.copyWith(
          phases: p.phases
              .map(
                (phase) => phase.id == c.targetId
                    ? phase.copyWith(accepted: true)
                    : phase,
              )
              .toList(),
        );
      case TeamProjectAction.acceptMilestone:
        final phases = p.phases.where(
          (phase) => phase.milestoneId == c.targetId,
        );
        if (phases.isEmpty || phases.any((phase) => !phase.accepted)) {
          return _fail('milestoneNotReady');
        }
        p = p.copyWith(
          specDraft: p.specDraft.copyWith(
            milestones: p.specDraft.milestones
                .map((m) => m.id == c.targetId ? m.copyWith(accepted: true) : m)
                .toList(),
          ),
        );
        if (p.specDraft.milestones.every((m) => m.accepted)) {
          p = p.copyWith(status: 'done');
        }
      case TeamProjectAction.advance:
        p = _advance(p, w);
      case TeamProjectAction.undoMerge:
        final receipt = p.receipts.where((r) => r.id == c.targetId).firstOrNull;
        if (receipt == null || receipt.kind != 'merge' || !c.confirmed) {
          return _fail('undoUnavailable');
        }
        final repo = p.repos.firstWhere((r) => r.id == receipt.repoId);
        final after = 'fixture-revert-${p.revision + 1}';
        p = p.copyWith(
          repos: p.repos
              .map((r) => r.id == repo.id ? r.copyWith(devCommit: after) : r)
              .toList(),
          receipts: [
            ...p.receipts,
            TeamProjectReceipt(
              id: c.requestId,
              kind: 'revert',
              repoId: repo.id,
              before: repo.devCommit,
              after: after,
              at: _at,
            ),
          ],
        );
      case TeamProjectAction.updateDefaults:
      case TeamProjectAction.createProject:
      case TeamProjectAction.createQuickTask:
      case TeamProjectAction.saveRole:
      case TeamProjectAction.deleteRole:
      case TeamProjectAction.updateServer:
      case TeamProjectAction.deleteProject:
        return _fail('invalidAction');
    }
    p = _syncRequests(_budgetNotice(p));
    if (c.action == TeamProjectAction.advance) {
      for (final task in p.tasks) {
        final old = before.tasks.where((t) => t.id == task.id).firstOrNull;
        if (old?.status != task.status) {
          p = p.copyWith(
            timeline: [
              ...p.timeline,
              TeamTimelineEvent(
                id: 'event-${p.timeline.length + 1}',
                kind: 'taskState',
                text: '${task.title}: ${task.status}',
                actor: 'fixture',
                at: _at,
                taskId: task.id,
              ),
            ],
          );
        }
      }
    }
    // A tick already wrote one row per task that changed; a generic
    // "work advanced" row on top would repeat itself forever.
    if (c.action != TeamProjectAction.advance) {
      p = _log(
        p,
        c.action.name,
        c.action == TeamProjectAction.moveTask && c.confirmed
            ? 'Started over on another server with a new branch and context'
            : c.text.isEmpty
            ? _actionText(c.action)
            : c.text,
        actor: 'person',
      );
    }
    p = p.copyWith(revision: before.revision + 1, updatedAt: _at);
    return w.copyWith(
      revision: w.revision + 1,
      projects: w.projects.map((old) => old.id == p.id ? p : old).toList(),
    );
  }

  String _actionText(TeamProjectAction action) => switch (action) {
    TeamProjectAction.simulatePlanFailure =>
      'Simulated an unstructured planner reply',
    TeamProjectAction.usePlanAsTask => 'Planner notes converted into one task',
    TeamProjectAction.retryPlan => 'A new structured plan was requested',
    TeamProjectAction.simulateManualCommit =>
      'Simulated a manual commit on dev',
    TeamProjectAction.simulateConflict => 'Simulated conflicting changes',
    TeamProjectAction.saveSpecDraft => 'Spec draft saved',
    TeamProjectAction.approveSpec => 'Spec approved',
    TeamProjectAction.approvePlan => 'Plan approved',
    TeamProjectAction.replan => 'Affected tasks replanned',
    TeamProjectAction.answerRequest => 'Question answered',
    TeamProjectAction.messageTask => 'Message sent to the task',
    TeamProjectAction.pauseProject => 'Project paused',
    TeamProjectAction.resumeProject => 'Project continued',
    TeamProjectAction.stopProject => 'Project stopped',
    TeamProjectAction.pauseTask => 'Task paused',
    TeamProjectAction.resumeTask => 'Task continued from its branch',
    TeamProjectAction.restartTask => 'Task restarted from its branch',
    TeamProjectAction.stopTask => 'Task stopped',
    TeamProjectAction.moveTask => 'Task handed over',
    TeamProjectAction.verifyTask => 'Fresh acceptance check completed',
    TeamProjectAction.fixFindings => 'Selected findings fixed',
    TeamProjectAction.recheckTask => 'Earlier findings checked again',
    TeamProjectAction.ignoreFinding => 'Findings ignored with a reason',
    TeamProjectAction.updateSettings => 'Project settings updated',
    TeamProjectAction.processMergeQueue => 'Local merge queue checked',
    TeamProjectAction.resolveConflict => 'Simulated conflict resolved',
    TeamProjectAction.promote => 'Development changes promoted to main',
    TeamProjectAction.acknowledgeDigest => 'Activity digest read',
    TeamProjectAction.acceptPhase => 'Phase review accepted',
    TeamProjectAction.acceptMilestone => 'Milestone accepted',
    TeamProjectAction.advance => 'Simulated work advanced',
    TeamProjectAction.undoMerge => 'A reverting commit was added',
    TeamProjectAction.requestSpecChange => 'Spec change proposed for review',
    _ => 'Project updated',
  };

  TeamProject _syncRequests(TeamProject p) {
    p = p.copyWith(
      phases: p.phases.map((phase) {
        final tasks = p.tasks.where((t) => t.phaseId == phase.id);
        return !phase.risky &&
                p.settings.reviewLevel != 'everyStep' &&
                tasks.isNotEmpty &&
                tasks.every((t) => t.status == 'merged')
            ? phase.copyWith(accepted: true)
            : phase;
      }).toList(),
    );
    final persistent = p.requests
        .where(
          (r) =>
              r.kind == 'question' ||
              r.kind == 'permission' ||
              r.answered ||
              (r.kind == 'budget' && p.status == 'paused'),
        )
        .toList();
    void add(
      String id,
      String kind,
      String title, {
      String taskId = '',
      String phaseId = '',
    }) {
      final old = p.requests.where((r) => r.id == id).firstOrNull;
      persistent.add(
        TeamRequest(
          id: id,
          kind: kind,
          title: title,
          taskId: taskId,
          phaseId: phaseId,
          createdAt: old?.createdAt ?? _at,
        ),
      );
    }

    if (p.status == 'spec' ||
        (p.specVersions.isNotEmpty && p.specDraft.approvedAt.isEmpty)) {
      add('${p.id}-spec', 'spec', 'Review and approve the living spec');
    }
    if (!persistent.any((r) => r.kind == 'budget') &&
        p.status == 'paused' &&
        p.tasks.any((t) => t.reason == 'Budget reached')) {
      add(
        '${p.id}-budget',
        'budget',
        'Budget reached. Raise the budget or pause the project.',
      );
    }
    if (p.status == 'planFailed') {
      add(
        '${p.id}-plan-format',
        'planFormat',
        'The planner returned notes instead of a structured plan',
      );
    }
    if (p.status == 'plan') {
      add('${p.id}-plan', 'plan', 'Review and approve the plan');
    }
    for (final t in p.tasks) {
      if (const ['stalled', 'failed', 'interrupted'].contains(t.status)) {
        add('recover-${t.id}', t.status, t.reason, taskId: t.id);
      }
      if (t.status == 'findings') {
        add(
          'findings-${t.id}',
          'findings',
          'Review the findings',
          taskId: t.id,
        );
      }
    }
    for (final phase in p.phases) {
      final tasks = p.tasks.where((t) => t.phaseId == phase.id);
      if (!phase.accepted &&
          (phase.risky || p.settings.reviewLevel == 'everyStep') &&
          tasks.isNotEmpty &&
          tasks.every((t) => t.status == 'merged')) {
        add(
          'phase-${phase.id}',
          'phase',
          'Review ${phase.title}',
          phaseId: phase.id,
        );
      }
    }
    for (final milestone in p.specDraft.milestones) {
      final phases = p.phases.where(
        (phase) => phase.milestoneId == milestone.id,
      );
      if (!milestone.accepted &&
          phases.isNotEmpty &&
          phases.every((phase) => phase.accepted)) {
        add(
          'milestone-${milestone.id}',
          'milestone',
          'Review ${milestone.title}',
          phaseId: milestone.id,
        );
      }
    }
    for (final item in p.mergeQueue.where((m) => m.status == 'conflict')) {
      add('conflict-${item.id}', 'conflict', item.reason, taskId: item.taskId);
    }
    return p.copyWith(requests: persistent);
  }

  void _validateSettings(TeamProjectSettings? s) {
    if (s == null ||
        !const ['single', 'parallel'].contains(s.mode) ||
        s.maxLanes < 1 ||
        s.maxLanes > 32) {
      _fail<void>('chooseExecutionMode');
    }
    final b = s.budget;
    if (!b.chosen ||
        (!b.unlimited && b.daily == null && b.total == null) ||
        (b.daily != null && (!b.daily!.isFinite || b.daily! <= 0)) ||
        (b.total != null && (!b.total!.isFinite || b.total! <= 0)) ||
        (b.taskTokens != null && b.taskTokens! <= 0)) {
      _fail<void>('chooseBudget');
    }
    if (!const ['milestones', 'everyStep'].contains(s.reviewLevel)) {
      _fail<void>('invalidReviewLevel');
    }
    if (s.maxFixRounds < 0 || s.maxFixRounds > 3) {
      _fail<void>('invalidFixRounds');
    }
  }

  void _validatePlan(TeamProject p, TeamWorkspace w) {
    if (p.tasks.isEmpty ||
        p.tasks.map((t) => t.id).toSet().length != p.tasks.length) {
      _fail<void>('invalidPlan');
    }
    final visited = <String>{}, visiting = <String>{};
    void visit(TeamTask t) {
      if (visiting.contains(t.id)) _fail<void>('dependencyCycle');
      if (visited.contains(t.id)) return;
      visiting.add(t.id);
      for (final id in t.dependsOn) {
        final dep = p.tasks.where((t) => t.id == id).firstOrNull;
        if (dep == null) _fail<void>('missingDependency');
        visit(dep);
      }
      visiting.remove(t.id);
      visited.add(t.id);
    }

    for (final t in p.tasks) {
      if (t.title.trim().isEmpty ||
          t.criteria.isEmpty ||
          !p.repos.any((r) => r.id == t.repoId) ||
          !w.servers.any((s) => s.id == t.serverId) ||
          !w.roles.any((r) => r.id == t.roleId) ||
          !p.phases.any((phase) => phase.id == t.phaseId)) {
        _fail<void>('invalidPlan');
      }
      visit(t);
    }
  }

  TeamProject _log(
    TeamProject p,
    String kind,
    String text, {
    String actor = 'person',
  }) => p.copyWith(
    timeline: [
      ...p.timeline,
      TeamTimelineEvent(
        id: 'event-${p.timeline.length + 1}',
        kind: kind,
        text: text,
        actor: actor,
        at: _at,
      ),
    ],
  );
  TeamTask _task(
    TeamTask t,
    TeamProjectCommand c,
    TeamProject p,
    TeamWorkspace w,
  ) {
    if (t.status == 'merged' && c.action != TeamProjectAction.messageTask) {
      return _fail('taskAlreadyDone');
    }
    switch (c.action) {
      case TeamProjectAction.messageTask:
        if (c.text.trim().isEmpty) return _fail('emptyMessage');
        return t.copyWith(
          messages: [
            ...t.messages,
            TeamMessage(id: c.requestId, text: c.text, at: _at),
          ],
        );
      case TeamProjectAction.pauseTask:
        return t.copyWith(
          status: 'paused',
          reason: 'Paused by you',
          changedAt: _at,
        );
      case TeamProjectAction.stopTask:
        return t.copyWith(
          status: 'stopped',
          reason: 'Stopped by you',
          changedAt: _at,
        );
      case TeamProjectAction.resumeTask:
      case TeamProjectAction.restartTask:
        if (const ['merged', 'done'].contains(t.status)) {
          return _fail('taskAlreadyDone');
        }
        return t.copyWith(
          status: 'queued',
          reason: 'Continue from the saved branch',
          changedAt: _at,
        );
      case TeamProjectAction.moveTask:
        if (!w.servers.any((s) => s.id == c.serverId)) {
          return _fail('serverNotFound');
        }
        final repo = p.repos.firstWhere((r) => r.id == t.repoId);
        if (c.roleId.isNotEmpty && !w.roles.any((r) => r.id == c.roleId)) {
          return _fail('roleNotFound');
        }
        if ((t.status == 'running' || t.steps > 0) && !repo.sharedRemote) {
          if (!c.confirmed) return _fail('sharedRemoteRequired');
          return t.copyWith(
            serverId: c.serverId,
            roleId: c.roleId.isEmpty ? t.roleId : c.roleId,
            status: 'queued',
            steps: 0,
            tokens: 0,
            fixRounds: 0,
            findings: [],
            criterionResults: [],
            diff: '',
            branch: '${t.branch}-restart-${p.revision + 1}',
            changedAt: _at,
            reason: 'Started over on the selected server',
            messages: [
              TeamMessage(
                id: c.requestId,
                actor: 'team',
                text:
                    'Explicitly started over elsewhere. Previous work remains on ${t.branch}. Begin again from the task criteria.',
                at: _at,
              ),
            ],
          );
        }
        return t.copyWith(
          serverId: c.serverId,
          roleId: c.roleId.isEmpty ? t.roleId : c.roleId,
          messages: [
            ...t.messages,
            TeamMessage(
              id: c.requestId,
              actor: 'team',
              text:
                  'Hand-off: ${t.title}. Continue from ${t.branch}. ${t.findings.where((f) => f.status == "open").length} open findings.',
              at: _at,
            ),
          ],
        );
      case TeamProjectAction.verifyTask:
      case TeamProjectAction.recheckTask:
        if (!const ['review', 'done', 'findings'].contains(t.status)) {
          return _fail('taskNotReady');
        }
        final fresh = c.action == TeamProjectAction.verifyTask;
        final findings = fresh && t.fixRounds == 0
            ? [
                TeamFinding(
                  id: 'finding-${t.id}',
                  criterion: t.criteria.first,
                  location: 'lib/example.dart:12',
                  text: 'The empty state needs an acceptance check.',
                ),
              ]
            : t.findings;
        final open = findings.any(
          (f) => f.status == 'open' && f.severity != 'notApplicable',
        );
        return t.copyWith(
          findings: findings,
          criterionResults: t.criteria
              .map(
                (criterion) => TeamCriterionResult(
                  criterion: criterion,
                  status:
                      findings.any(
                        (f) =>
                            f.criterion == criterion &&
                            f.status == 'open' &&
                            f.severity != 'notApplicable',
                      )
                      ? 'unmet'
                      : findings.any(
                          (f) =>
                              f.criterion == criterion &&
                              f.severity == 'notApplicable',
                        )
                      ? 'notApplicable'
                      : 'met',
                ),
              )
              .toList(),
          status: open ? 'findings' : 'done',
          reason: open ? 'Review the findings' : 'Checks passed',
          changedAt: _at,
        );
      case TeamProjectAction.fixFindings:
        if (!t.findings.any(
          (f) => f.status == 'open' && f.severity != 'notApplicable',
        )) {
          return _fail('noOpenFindings');
        }
        return t.copyWith(
          findings: t.findings
              .map(
                (f) => c.findingIds.isEmpty || c.findingIds.contains(f.id)
                    ? f.copyWith(status: 'resolved')
                    : f,
              )
              .toList(),
          fixRounds: t.fixRounds + 1,
          status: 'review',
          reason: 'Fix applied; re-check the criteria',
          changedAt: _at,
        );
      case TeamProjectAction.ignoreFinding:
        if (c.text.trim().isEmpty) return _fail('reasonRequired');
        return t.copyWith(
          findings: t.findings
              .map(
                (f) =>
                    f.status == 'open' &&
                        (c.findingIds.isEmpty || c.findingIds.contains(f.id))
                    ? f.copyWith(status: 'ignored')
                    : f,
              )
              .toList(),
          status: 'review',
        );
      default:
        return _fail('invalidTaskAction');
    }
  }

  TeamProject _plan(TeamProject p) {
    final milestones = p.specDraft.milestones.isEmpty
        ? [
            const TeamMilestone(
              id: 'milestone-1',
              title: 'First usable milestone',
              criteria: ['The complete journey works'],
            ),
          ]
        : p.specDraft.milestones;
    final phases = <TeamPhase>[];
    final tasks = <TeamTask>[];
    var previousMilestoneTasks = <String>[];
    for (final m in milestones) {
      final currentMilestoneTasks = <String>[];
      final phaseId = '${p.id}-${m.id}-build';
      phases.add(
        TeamPhase(
          id: phaseId,
          milestoneId: m.id,
          title: 'Build ${m.title}',
          risky: true,
        ),
      );
      for (var i = 0; i < p.repos.length; i++) {
        final repo = p.repos[i];
        final taskId = '${p.id}-${m.id}-${repo.id}';
        currentMilestoneTasks.add(taskId);
        tasks.add(
          TeamTask(
            id: taskId,
            title: 'Deliver ${m.title} in ${repo.name}',
            phaseId: phaseId,
            dependsOn: previousMilestoneTasks,
            roleId: i.isEven ? 'frontend' : 'backend',
            repoId: repo.id,
            serverId: repo.serverId,
            criteria: m.criteria.isEmpty
                ? ['The complete journey works']
                : m.criteria,
            branch: 'team/${p.id}/$taskId',
            changedAt: _at,
          ),
        );
      }
      previousMilestoneTasks = currentMilestoneTasks;
    }
    return p.copyWith(
      specDraft: p.specDraft.copyWith(milestones: milestones),
      phases: phases,
      tasks: p.quickTask ? tasks.take(1).toList() : tasks,
    );
  }

  TeamProject _budgetNotice(TeamProject p) {
    final b = p.settings.budget;
    final near =
        !b.unlimited &&
        ((b.total != null && p.spent >= b.total! * 0.8) ||
            (b.daily != null && p.spentToday >= b.daily! * 0.8));
    final day = _at.substring(0, 10);
    final key = 'budget80-$day';
    if (near && !p.timeline.any((e) => e.kind == key)) {
      p = _log(
        p,
        key,
        '80% of the project budget has been used',
        actor: 'fixture',
      );
    }
    return p.copyWith(budgetWarning: near);
  }

  TeamProject _advance(TeamProject p, TeamWorkspace w) {
    if (p.status != 'running') return _fail('projectNotRunning');
    final day = _at.substring(0, 10);
    if (p.spendDay != day) p = p.copyWith(spentToday: 0, spendDay: day);
    final budget = p.settings.budget;
    final capped =
        !budget.unlimited &&
        ((budget.total != null && p.spent >= budget.total!) ||
            (budget.daily != null && p.spentToday >= budget.daily!));
    if (capped) {
      return _log(
        p.copyWith(
          status: 'paused',
          tasks: p.tasks
              .map(
                (t) => t.status == 'running'
                    ? t.copyWith(
                        status: 'paused',
                        reason: 'Budget reached',
                        changedAt: _at,
                      )
                    : t,
              )
              .toList(),
          requests: [
            ...p.requests.where((r) => r.id != '${p.id}-budget'),
            TeamRequest(
              id: '${p.id}-budget',
              kind: 'budget',
              title: 'Budget reached. Raise the budget or pause the project.',
              createdAt: _at,
            ),
          ],
        ),
        'budget',
        'Budget reached',
        actor: 'fixture',
      );
    }
    final tasks = [...p.tasks];
    final requests = [...p.requests];
    var spent = 0.0;
    for (var i = 0; i < tasks.length; i++) {
      var t = tasks[i];
      if (t.status != 'running') continue;
      final server = w.servers.firstWhere((s) => s.id == t.serverId);
      if (!server.online) {
        tasks[i] = t.copyWith(
          status: 'interrupted',
          reason: 'Server is not reachable',
          changedAt: _at,
        );
        continue;
      }
      if (server.chatWaiting) {
        tasks[i] = t.copyWith(
          reason: 'Waiting for your chat to receive its first word',
        );
        continue;
      }
      if (p.settings.chargingOnly && server.phone && !isCharging) {
        tasks[i] = t.copyWith(reason: 'Waiting for this phone to charge');
        continue;
      }
      if (budget.taskTokens != null && t.tokens + 100 > budget.taskTokens!) {
        tasks[i] = t.copyWith(
          status: 'stalled',
          reason: 'Task token limit reached',
          changedAt: _at,
        );
        continue;
      }
      t = t.copyWith(
        steps: t.steps + 1,
        tokens: t.tokens + 100,
        changedAt: _at,
      );
      spent += 0.01;
      if (t.steps >= 3) {
        t = t.copyWith(
          status: 'review',
          reason: 'Ready for a read-only check',
          diff:
              '--- a/lib/example.dart\n+++ b/lib/example.dart\n+// Simulated implementation of ${t.title}',
        );
      }
      if (p.id == 'demo-project' &&
          t.id == p.tasks.first.id &&
          t.steps == 2 &&
          !requests.any((r) => r.id == 'demo-question')) {
        requests.add(
          TeamRequest(
            id: 'demo-question',
            kind: 'question',
            taskId: t.id,
            title: 'Keep completed work visible in the overview?',
            createdAt: _at,
          ),
        );
        t = t.copyWith(status: 'needsInput', reason: 'Waiting for your answer');
      }
      tasks[i] = t;
    }
    final max = p.settings.mode == 'single' ? 1 : p.settings.maxLanes;
    var running = tasks.where((t) => t.status == 'running').length;
    final reachedAfterStep =
        !budget.unlimited &&
        ((budget.total != null && p.spent + spent >= budget.total!) ||
            (budget.daily != null && p.spentToday + spent >= budget.daily!));
    for (
      var i = 0;
      i < tasks.length && running < max && !reachedAfterStep;
      i++
    ) {
      final t = tasks[i];
      if (t.status != 'queued') continue;
      final server = w.servers.firstWhere((s) => s.id == t.serverId);
      if (!server.online ||
          server.chatWaiting ||
          (p.settings.chargingOnly && server.phone && !isCharging)) {
        tasks[i] = t.copyWith(
          reason: !server.online
              ? 'Waiting for ${server.name}'
              : server.chatWaiting
              ? 'Waiting for your chat to receive its first word'
              : 'Waiting for this phone to charge',
        );
        continue;
      }
      if (tasks
                  .where(
                    (t) => t.serverId == server.id && t.status == 'running',
                  )
                  .length +
              w.projects
                  .where((other) => other.id != p.id)
                  .expand((other) => other.tasks)
                  .where(
                    (other) =>
                        other.serverId == server.id &&
                        other.status == 'running',
                  )
                  .length >=
          server.laneCap) {
        continue;
      }
      if (t.dependsOn.any(
        (id) => !tasks.any(
          (d) => d.id == id && const ['done', 'merged'].contains(d.status),
        ),
      )) {
        continue;
      }
      final dependencyPhases = p.phases.where(
        (phase) =>
            phase.id != t.phaseId &&
            tasks.any(
              (d) => t.dependsOn.contains(d.id) && d.phaseId == phase.id,
            ),
      );
      if (dependencyPhases.any(
        (phase) =>
            (phase.risky || p.settings.reviewLevel == 'everyStep') &&
            !phase.accepted,
      )) {
        tasks[i] = t.copyWith(reason: 'Waiting for the previous phase review');
        continue;
      }
      tasks[i] = t.copyWith(status: 'running', reason: '', changedAt: _at);
      running++;
    }
    var next = p.copyWith(
      tasks: tasks,
      requests: requests,
      spent: p.spent + spent,
      spentToday: p.spentToday + spent,
      usageReported: true,
    );
    if (p.settings.autoFix && p.settings.reviewLevel != 'everyStep') {
      final queue = [...next.mergeQueue];
      final checked = next.tasks.map((t) {
        final previous = p.tasks.firstWhere((old) => old.id == t.id);
        if (previous.status != 'review' && previous.status != 'findings') {
          return t;
        }
        if (previous.status == 'findings') {
          if (t.fixRounds >= p.settings.maxFixRounds ||
              !t.findings.any(
                (f) =>
                    f.status == 'open' &&
                    const ['critical', 'major'].contains(f.severity),
              )) {
            return t;
          }
          return _task(
            t,
            TeamProjectCommand(
              requestId: 'auto-fix',
              action: TeamProjectAction.fixFindings,
              findingIds: t.findings
                  .where(
                    (f) =>
                        const ['critical', 'major'].contains(f.severity) &&
                        f.status == 'open',
                  )
                  .map((f) => f.id)
                  .toList(),
            ),
            p,
            w,
          );
        }
        final result = _task(
          t,
          TeamProjectCommand(
            requestId: 'auto-check',
            action: t.fixRounds > 0
                ? TeamProjectAction.recheckTask
                : TeamProjectAction.verifyTask,
          ),
          p,
          w,
        );
        if (result.status == 'done' && !queue.any((m) => m.taskId == t.id)) {
          queue.add(
            TeamMergeItem(id: 'merge-${t.id}', taskId: t.id, repoId: t.repoId),
          );
        }
        return result;
      }).toList();
      next = next.copyWith(tasks: checked, mergeQueue: queue);
      if (checked.any(
        (t) => t.status != p.tasks.firstWhere((old) => old.id == t.id).status,
      )) {
        next = _log(
          next,
          'automaticCheck',
          'Simulated acceptance checks advanced',
          actor: 'checker',
        );
      }
    }
    return _budgetNotice(next);
  }

  TeamProject _merge(TeamProject p, TeamProjectCommand c) {
    if (p.settings.reviewLevel == 'everyStep' && !c.confirmed) {
      return _fail('confirmationRequired');
    }
    final queue = [...p.mergeQueue];
    final repos = [...p.repos];
    final tasks = [...p.tasks];
    final receipts = [...p.receipts];
    for (var i = 0; i < queue.length; i++) {
      final item = queue[i];
      if (item.status != 'queued' ||
          (c.targetId.isNotEmpty && item.repoId != c.targetId)) {
        continue;
      }
      final t = tasks.firstWhere((t) => t.id == item.taskId);
      if (t.status != 'done' ||
          t.findings.any(
            (f) => f.status == 'open' && f.severity != 'notApplicable',
          )) {
        continue;
      }
      if (t.dependsOn.any(
        (id) => !tasks.any((t) => t.id == id && t.status == 'merged'),
      )) {
        continue;
      }
      final ri = repos.indexWhere((r) => r.id == item.repoId);
      final repo = repos[ri];
      if (repo.checkCommand.trim().isEmpty) return _fail('checksRequired');
      final after = 'fixture-dev-${p.revision + 1}-$i';
      repos[ri] = repo.copyWith(devCommit: after);
      queue[i] = item.copyWith(status: 'merged', checksPassed: true);
      final ti = tasks.indexWhere((t) => t.id == item.taskId);
      tasks[ti] = t.copyWith(status: 'merged', changedAt: _at);
      final resolution = tasks.indexWhere((t) => t.id == 'resolve-${item.id}');
      if (resolution >= 0) {
        tasks[resolution] = tasks[resolution].copyWith(
          status: 'merged',
          changedAt: _at,
        );
      }
      receipts.add(
        TeamProjectReceipt(
          id: '${c.requestId}-$i',
          kind: 'merge',
          repoId: repo.id,
          before: repo.devCommit,
          after: after,
          at: _at,
          actor: 'fixture',
        ),
      );
    }
    return p.copyWith(
      mergeQueue: queue,
      repos: repos,
      tasks: tasks,
      receipts: receipts,
    );
  }

  TeamProject _promote(TeamProject p, TeamProjectCommand c) {
    if (!c.confirmed) return _fail('confirmationRequired');
    final repo = p.repos.where((r) => r.id == c.targetId).firstOrNull;
    if (repo == null) return _fail('repoNotFound');
    if (c.expectedDevCommit != repo.devCommit ||
        c.expectedMainCommit != repo.mainCommit) {
      return _fail('staleCommits');
    }
    final phases = p.phases.where(
      (phase) =>
          p.tasks.any((t) => t.phaseId == phase.id && t.repoId == repo.id),
    );
    if (phases.any(
      (phase) =>
          (phase.risky || p.settings.reviewLevel == 'everyStep') &&
          !phase.accepted,
    )) {
      return _fail('phaseReviewRequired');
    }
    if (repo.devCommit == repo.mainCommit ||
        p.tasks
            .where((t) => t.repoId == repo.id)
            .any((t) => t.status != 'merged') ||
        p.mergeQueue
            .where((m) => m.repoId == repo.id)
            .any((m) => m.status != 'merged' || !m.checksPassed)) {
      return _fail('notReadyToPromote');
    }
    return p.copyWith(
      repos: p.repos
          .map(
            (r) => r.id == repo.id ? r.copyWith(mainCommit: repo.devCommit) : r,
          )
          .toList(),
      receipts: [
        ...p.receipts,
        TeamProjectReceipt(
          id: c.requestId,
          kind: 'promotion',
          repoId: repo.id,
          before: repo.mainCommit,
          after: repo.devCommit,
          at: _at,
        ),
      ],
    );
  }

  TeamWorkspace _initial() {
    final base = TeamWorkspace(
      // A person who picks Parallel expects more than one lane.
      defaultSettings: const TeamProjectSettings(maxLanes: 3),
      servers: const [
        TeamServer(id: 'computer', name: 'Home PC', memoryMb: 120),
        TeamServer(
          id: 'phone',
          name: 'This phone',
          phone: true,
          laneCap: 3,
          memoryMb: 180,
        ),
      ],
      roles: const [
        TeamProjectRole(
          id: 'frontend',
          name: 'Frontend',
          instructions: 'Build accessible user journeys',
        ),
        TeamProjectRole(
          id: 'backend',
          name: 'Backend',
          instructions: 'Implement stable domain contracts',
        ),
        TeamProjectRole(
          id: 'planner',
          name: 'Planner',
          instructions: 'Plan milestones and criteria',
        ),
        TeamProjectRole(
          id: 'checker',
          name: 'Checker',
          instructions: 'Read-only acceptance verification',
          readOnly: true,
        ),
      ],
    );
    if (!seedDemo) return base;
    return base.copyWith(
      roles: [
        ...base.roles,
        const TeamProjectRole(
          id: 'tester',
          name: 'Tester',
          instructions: 'Run the checks and report what fails',
        ),
        const TeamProjectRole(
          id: 'docs',
          name: 'Docs',
          instructions: 'Write and translate the copy',
        ),
      ],
      projects: [_syncRequests(_demoProject())],
    );
  }

  /// Presentation data for the simulator: four milestones, eight tasks in the
  /// second (five merged), three lanes (two busy), one open question, two
  /// decisions and two repos on two servers. Times are relative to the clock.
  TeamProject _demoProject() {
    final now = _now().toUtc();
    String ago(Duration d) => now.subtract(d).toIso8601String();
    TeamTask task(
      String id,
      String title,
      String phase,
      String role,
      String repo,
      String server,
      String status,
      int criteria, {
      List<String> after = const [],
      String changed = '',
    }) => TeamTask(
      id: id,
      title: title,
      phaseId: phase,
      roleId: role,
      repoId: repo,
      serverId: server,
      status: status,
      dependsOn: after,
      criteria: [for (var i = 1; i <= criteria; i++) '$title: check $i passes'],
      branch: 'team/demo/$id',
      changedAt: changed.isEmpty ? ago(const Duration(days: 1)) : changed,
      steps: status == 'running' ? 2 : 0,
    );
    const done = 'merged';
    final tasks = [
      task(
        't-tokens',
        'Colour tokens',
        'ph-m1',
        'frontend',
        'site',
        'computer',
        done,
        2,
      ),
      task(
        't-type',
        'Type scale',
        'ph-m1',
        'frontend',
        'site',
        'computer',
        done,
        2,
      ),
      task(
        't-data',
        'Pricing data model',
        'ph-data',
        'backend',
        'site',
        'computer',
        done,
        3,
      ),
      task(
        't-checkout',
        'Checkout endpoint',
        'ph-data',
        'backend',
        'site',
        'computer',
        done,
        2,
        after: ['t-data'],
      ),
      task(
        't-table',
        'Pricing table',
        'ph-screens',
        'frontend',
        'site',
        'computer',
        'running',
        4,
        after: ['t-data'],
        changed: ago(const Duration(minutes: 12, seconds: 20)),
      ),
      task(
        't-copy',
        'Arabic copy',
        'ph-screens',
        'docs',
        'docs',
        'phone',
        'queued',
        2,
        after: ['t-data'],
      ),
      task(
        't-lang',
        'Language switcher',
        'ph-screens',
        'frontend',
        'site',
        'computer',
        done,
        2,
      ),
      task(
        't-layout',
        'Pricing page layout',
        'ph-screens',
        'frontend',
        'site',
        'computer',
        done,
        3,
      ),
      task(
        't-checks',
        'Checkout checks',
        'ph-checks',
        'tester',
        'site',
        'phone',
        'running',
        2,
        after: ['t-checkout'],
        changed: ago(const Duration(minutes: 3, seconds: 20)),
      ),
      task(
        't-a11y',
        'Accessibility pass',
        'ph-checks',
        'tester',
        'docs',
        'phone',
        done,
        2,
      ),
      task(
        't-drafts',
        'Draft storage',
        'ph-docs',
        'backend',
        'site',
        'computer',
        'queued',
        2,
      ),
      task(
        't-pages',
        'Docs pages',
        'ph-docs',
        'docs',
        'docs',
        'phone',
        'queued',
        2,
        after: ['t-drafts'],
      ),
      task(
        't-search',
        'Docs search',
        'ph-docs',
        'frontend',
        'docs',
        'phone',
        'queued',
        3,
        after: ['t-drafts'],
      ),
      task(
        't-launch',
        'Launch checklist',
        'ph-launch',
        'tester',
        'site',
        'computer',
        'queued',
        2,
        after: ['t-pages'],
      ),
    ];
    const spec = TeamSpec(
      goal: 'Launch the marketing site and its docs in Arabic and English',
      constraints: 'Accessible on phones and computers',
      outOfScope: 'Public releases',
      milestones: [
        TeamMilestone(
          id: 'm1',
          title: 'Design tokens',
          accepted: true,
          criteria: ['Colours and type are named once'],
        ),
        TeamMilestone(
          id: 'm2',
          title: 'Landing and pricing',
          criteria: ['Pricing reads well at twice the text size'],
        ),
        TeamMilestone(
          id: 'm3',
          title: 'Docs site',
          criteria: ['Every docs page is searchable'],
        ),
        TeamMilestone(
          id: 'm4',
          title: 'Launch checks',
          criteria: ['Every check passes on phone and computer'],
        ),
      ],
    );
    return TeamProject(
      id: 'demo-project',
      name: 'Lumen launch site',
      status: 'running',
      planApproved: true,
      simulated: true,
      usageReported: true,
      spent: 18,
      spentToday: 4.1,
      spendDay: now.toIso8601String().substring(0, 10),
      updatedAt: ago(const Duration(minutes: 2)),
      digestReadAt: ago(const Duration(minutes: 1)),
      settings: const TeamProjectSettings(
        mode: 'parallel',
        maxLanes: 3,
        budget: TeamBudget(chosen: true, daily: 10, total: 50),
      ),
      repos: const [
        TeamRepo(
          id: 'site',
          name: 'site',
          serverId: 'computer',
          path: '~/work/lumen-site',
          devCommit: 'd4e5f6a',
          mainCommit: 'a1b2c3d',
        ),
        TeamRepo(
          id: 'docs',
          name: 'docs',
          serverId: 'phone',
          path: '/project/lumen-docs',
          devCommit: 'e7f8a9b',
          mainCommit: 'c0d1e2f',
        ),
      ],
      specDraft: spec.copyWith(
        version: 3,
        approvedBy: 'person',
        approvedAt: ago(const Duration(days: 2)),
      ),
      specVersions: [
        for (var v = 1; v <= 3; v++)
          spec.copyWith(
            version: v,
            approvedBy: 'person',
            approvedAt: ago(Duration(days: 6 - v * 2 + 2)),
          ),
      ],
      phases: const [
        TeamPhase(
          id: 'ph-m1',
          milestoneId: 'm1',
          title: 'Tokens',
          accepted: true,
        ),
        TeamPhase(
          id: 'ph-data',
          milestoneId: 'm2',
          title: 'Data',
          risky: true,
          accepted: true,
        ),
        TeamPhase(id: 'ph-screens', milestoneId: 'm2', title: 'Screens'),
        TeamPhase(id: 'ph-checks', milestoneId: 'm2', title: 'Checks'),
        TeamPhase(id: 'ph-docs', milestoneId: 'm3', title: 'Docs pages'),
        TeamPhase(id: 'ph-launch', milestoneId: 'm4', title: 'Launch'),
      ],
      tasks: tasks,
      requests: [
        TeamRequest(
          id: 'demo-question',
          kind: 'question',
          title: 'Keep drafts in SQLite?',
          taskId: 't-drafts',
          createdAt: ago(const Duration(minutes: 5)),
        ),
      ],
      mergeQueue: [
        for (final t in tasks.where((t) => t.status == done))
          TeamMergeItem(
            id: 'merge-${t.id}',
            taskId: t.id,
            repoId: t.repoId,
            status: 'merged',
            checksPassed: true,
          ),
      ],
      timeline: [
        TeamTimelineEvent(
          id: 'demo-created',
          kind: 'created',
          text: 'Project started',
          at: ago(const Duration(days: 5)),
          actor: 'person',
        ),
        TeamTimelineEvent(
          id: 'demo-decision-tests',
          kind: 'decision',
          text: 'Tests run on Home PC only',
          at: ago(const Duration(days: 2)),
          actor: 'planner',
        ),
        TeamTimelineEvent(
          id: 'demo-decision-languages',
          kind: 'decision',
          text: 'Pricing page ships in two languages',
          at: ago(const Duration(days: 1)),
          actor: 'person',
        ),
      ],
    );
  }
}

class _Refused implements Exception {
  const _Refused(this.code);
  final String code;
}
