import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/team_project_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/inapp/phone_engine_gateway.dart';

import 'phone_project_engine_gateway_test.dart' as engine;

void main() {
  const planner = TeamPlanningState(
    jobId: 'job-planner',
    stage: 'completed',
    updatedAt: '2026-10-01T12:00:00Z',
  );
  const task = TeamTask(
    id: 'task-one',
    title: 'Implement approved work',
    criteria: ['Works'],
  );
  const phase = TeamPhase(id: 'phase-one', title: 'First phase');
  const planned = TeamProject(
    id: 'project-one',
    name: 'Real phone project',
    status: 'needsPlanApproval',
    revision: 7,
    planningState: planner,
    tasks: [task],
    phases: [phase],
    specDraft: TeamSpec(goal: 'Build this project', approvedBy: 'person'),
  );

  ({PhoneEngineGateway gateway, engine.FakeEngineAdapter adapter}) client(
    TeamProject project, {
    List<String> actions = const ['approvePlan', 'resumeProject', 'resumeTask'],
  }) {
    final wire = engine.workspace(12)..['projects'] = [project.toJson()];
    final adapter = engine.FakeEngineAdapter(
      (request) async => engine.jsonBody(
        request.path == '/v1/health'
            ? engine.health('p1', execution: true, actions: actions)
            : request.path == '/v1/commands'
            ? {
                'accepted': true,
                'code': '',
                'projectId': project.id,
                'revision': 8,
                'replayed': false,
              }
            : wire,
      ),
    );
    final gateway = engine.gateway(adapter);
    addTearDown(gateway.close);
    return (gateway: gateway, adapter: adapter);
  }

  test(
    'completed native planner exposes reviewed plan without changing command truth',
    () async {
      final harness = client(planned);
      final workspace = await harness.gateway.teamWorkspace();
      final project = workspace.projects.single;
      expect(project.status, 'plan');
      expect(workspace.revision, 12);
      expect(project.revision, 7);
      expect(project.planApproved, isFalse);
      expect(project.planningState!.toJson(), planner.toJson());
      expect(project.tasks.single.toJson(), task.toJson());
      expect(project.phases.single.toJson(), phase.toJson());
      expect(project.specDraft.toJson(), planned.specDraft.toJson());
      final result = await harness.gateway.executeProject(
        TeamProjectCommand(
          requestId: 'approve-reviewed-plan',
          action: TeamProjectAction.approvePlan,
          projectId: project.id,
          expectedRevision: project.revision,
          tasks: project.tasks,
          phases: project.phases,
        ),
      );
      expect(result.accepted, isTrue);
      final command = harness.adapter.requests.last.data as Map;
      expect(command['action'], 'approvePlan');
      expect(command['expectedRevision'], 7);
      expect(command['requestId'], 'approve-reviewed-plan');
      expect(command['tasks'], [task.toJson()]);
      expect(command['phases'], [phase.toJson()]);
      expect(planned.status, 'needsPlanApproval');
    },
  );

  test(
    'unconfirmed quick task needs plan approval without a planner checkpoint',
    () async {
      const quick = TeamProject(
        id: 'quick',
        status: 'needsPlanApproval',
        quickTask: true,
        tasks: [task],
      );
      final project = (await client(
        quick,
      ).gateway.teamWorkspace()).projects.single;
      expect(project.status, 'plan');
      expect(project.quickTask, isTrue);
      expect(project.planApproved, isFalse);
      expect(project.planningState, isNull);
    },
  );

  test(
    'planning checkpoint presentation stays separate from raw engine stage',
    () async {
      for (final pair in {
        'queued': 'waiting',
        'planning': 'running',
        'submitting': 'running',
        'resuming': 'running',
        'failed': 'failed',
        'interrupted': 'failed',
      }.entries) {
        final source = planned.copyWith(
          status: 'planning',
          planningState: TeamPlanningState(
            jobId: 'job-planner',
            stage: pair.key,
            reason: pair.key == 'failed' ? 'modelUnavailable' : '',
          ),
        );
        final project = (await client(
          source,
        ).gateway.teamWorkspace()).projects.single;
        expect(project.status, pair.value, reason: pair.key);
        expect(project.planningState!.stage, pair.key);
        expect(project.planningState!.reason, source.planningState!.reason);
        expect(project.status, isNot('planFailed'));
        expect(project.planApproved, isFalse);
      }
    },
  );

  test(
    'terminal checkpoint shows only an allowlisted static reason without retrying',
    () async {
      for (final reason in [
        'sessionFailed',
        'promptUncertain',
        'modelUnavailable',
        'invalid_model',
        'authentication_failed',
        'sessionUnknown',
        'structuredOutputInvalid',
        'untrusted private token path',
      ]) {
        final harness = client(
          planned.copyWith(
            status: 'planning',
            planningState: TeamPlanningState(
              jobId: 'job-planner',
              stage: 'interrupted',
              reason: reason,
            ),
          ),
        );
        final project = (await harness.gateway.teamWorkspace()).projects.single;
        expect(project.status, 'failed');
        expect(project.timeline.last.kind, 'planningCheckpoint');
        if (reason.startsWith('untrusted')) {
          expect(
            project.timeline.last.text,
            'Planning stopped and needs review.',
          );
        } else {
          expect(project.timeline.last.text, contains('($reason)'));
        }
        expect(
          harness.adapter.requests.every((request) => request.method == 'GET'),
          isTrue,
        );
        expect(project.planningState!.reason, reason);
        expect(project.status, isNot('planFailed'));
      }
    },
  );

  test(
    'reconciliation checkpoint offers Resume while person pause and stop stay intact',
    () async {
      const interrupted = TeamPlanningState(
        stage: 'interrupted',
        reason: 'restartNeedsReconciliation',
      );
      for (final status in ['planning', 'paused', 'stopped']) {
        final project = (await client(
          planned.copyWith(status: status, planningState: interrupted),
        ).gateway.teamWorkspace()).projects.single;
        expect(project.status, status == 'planning' ? 'paused' : status);
        expect(
          project.timeline.last.text,
          status == 'stopped' ? isNot(contains('Resume')) : contains('Resume'),
        );
        expect(project.revision, 7);
      }
    },
  );

  test(
    'interrupted approved work exposes the existing Resume controls',
    () async {
      for (final reason in [
        'restartNeedsReconciliation',
        'pauseNeedsReconciliation',
      ]) {
        final source = planned.copyWith(
          status: 'interrupted',
          planApproved: true,
          tasks: [task.copyWith(status: 'interrupted', reason: reason)],
        );
        final harness = client(source);
        final project = (await harness.gateway.teamWorkspace()).projects.single;
        expect(project.status, 'paused');
        expect(project.tasks.single.status, 'paused');
        expect(project.tasks.single.reason, reason);
        expect(project.revision, source.revision);
        expect(project.planningState!.toJson(), source.planningState!.toJson());
        expect(project.timeline.last.kind, 'taskCheckpoint');
        expect(project.timeline.last.taskId, task.id);
        expect(project.timeline.last.text, contains('($reason)'));
        expect(project.timeline.last.text, contains('Resume'));
        expect(source.status, 'interrupted');
        expect(source.tasks.single.status, 'interrupted');
        expect(
          harness.adapter.requests.every((r) => r.method == 'GET'),
          isTrue,
        );
        final result = await harness.gateway.executeProject(
          TeamProjectCommand(
            requestId: 'resume-existing-session',
            action: TeamProjectAction.resumeProject,
            projectId: project.id,
            expectedRevision: project.revision,
          ),
        );
        expect(result.accepted, isTrue);
        final command = harness.adapter.requests.last.data as Map;
        expect(command['action'], 'resumeProject');
        expect(command['expectedRevision'], source.revision);
      }
    },
  );

  test(
    'Resume presentation respects the native command advertisement',
    () async {
      final source = planned.copyWith(
        status: 'interrupted',
        planApproved: true,
        tasks: [
          task.copyWith(
            status: 'interrupted',
            reason: 'restartNeedsReconciliation',
          ),
        ],
      );
      for (final actions in [
        <String>[],
        ['resumeProject'],
        ['resumeTask'],
      ]) {
        final harness = client(source, actions: actions);
        final project = (await harness.gateway.teamWorkspace()).projects.single;
        expect(
          project.status,
          actions.contains('resumeProject') ? 'paused' : 'failed',
        );
        expect(
          project.tasks.single.status,
          actions.contains('resumeTask') ? 'paused' : 'review',
        );
        if (!actions.contains('resumeProject')) {
          final result = await harness.gateway.executeProject(
            TeamProjectCommand(
              requestId: 'unsupported-resume',
              action: TeamProjectAction.resumeProject,
              projectId: project.id,
              expectedRevision: project.revision,
            ),
          );
          expect(result.accepted, isFalse);
          expect(result.code, 'unsupportedCommand');
          expect(
            harness.adapter.requests.every((r) => r.method == 'GET'),
            isTrue,
          );
        }
      }
      final planning = planned.copyWith(
        status: 'interrupted',
        planningState: const TeamPlanningState(
          stage: 'interrupted',
          reason: 'restartNeedsReconciliation',
        ),
      );
      expect(
        (await client(
          planning,
          actions: [],
        ).gateway.teamWorkspace()).projects.single.status,
        'failed',
      );
    },
  );

  test('reviewable interruption never suggests a safe prompt resend', () async {
    for (final reason in [
      'recoveryNeedsReview',
      'sessionUnknown',
      'sessionFailed',
      'promptUncertain',
      'sessionCreateUncertain',
      'untrusted private token path',
      '',
    ]) {
      final source = planned.copyWith(
        status: 'interrupted',
        planApproved: true,
        tasks: [task.copyWith(status: 'interrupted', reason: reason)],
      );
      final harness = client(source);
      final project = (await harness.gateway.teamWorkspace()).projects.single;
      expect(project.status, 'failed');
      expect(project.tasks.single.status, 'review');
      expect(project.tasks.single.reason, reason);
      expect(project.timeline.last.kind, 'taskCheckpoint');
      expect(project.timeline.last.text, isNot(contains('Resume')));
      if (reason.isEmpty || reason.startsWith('untrusted')) {
        expect(
          project.timeline.last.text,
          'Work was interrupted and needs review.',
        );
      } else {
        expect(project.timeline.last.text, contains('($reason)'));
      }
      expect(harness.adapter.requests.every((r) => r.method == 'GET'), isTrue);
    }
  });

  test(
    'refetch failure remains reviewable when the native parent still runs',
    () async {
      for (final reason in [
        'sessionUnknown',
        'sessionFailed',
        'recoveryNeedsReview',
        'restartNeedsReconciliation',
      ]) {
        final source = planned.copyWith(
          status: 'running',
          planApproved: true,
          tasks: [
            task.copyWith(status: 'interrupted', reason: reason),
            task.copyWith(
              id: 'blocked',
              status: 'queued',
              dependsOn: [task.id],
            ),
          ],
        );
        final harness = client(source);
        final project = (await harness.gateway.teamWorkspace()).projects.single;
        expect(
          project.status,
          reason == 'restartNeedsReconciliation' ? 'paused' : 'failed',
        );
        expect(
          project.tasks.first.status,
          reason == 'restartNeedsReconciliation' ? 'paused' : 'review',
        );
        expect(project.tasks.last.status, 'queued');
        expect(project.tasks.last.dependsOn, [task.id]);
        expect(project.timeline.last.text, contains('($reason)'));
        expect(project.revision, source.revision);
        expect(source.status, 'running');
        expect(
          harness.adapter.requests.every((r) => r.method == 'GET'),
          isTrue,
        );
      }
    },
  );

  test(
    'an interrupted lane does not hide another active parallel lane',
    () async {
      for (final active in [
        'running',
        'working',
        'resuming',
        'checking',
        'review',
        'merging',
        'submitting',
      ]) {
        final source = planned.copyWith(
          status: 'running',
          planApproved: true,
          tasks: [
            task.copyWith(status: 'interrupted', reason: 'sessionUnknown'),
            task.copyWith(id: 'active', status: active),
          ],
        );
        final project = (await client(
          source,
        ).gateway.teamWorkspace()).projects.single;
        expect(project.status, 'running', reason: active);
        expect(project.tasks.first.status, 'review');
        expect(project.tasks.first.reason, 'sessionUnknown');
        expect(project.revision, source.revision);
      }
    },
  );

  test(
    'scheduler admission codes remain visible in interrupted checkpoints',
    () async {
      // Exact static codes returned by engine/phone/src/scheduler.rs, including
      // budgetReached/taskTokenBudgetReached rather than invented budget codes.
      for (final reason in [
        'jobNotQueued',
        'projectNotRunning',
        'serverOffline',
        'chatBusy',
        'chatStateUnknown',
        'chargingRequired',
        'chargingUnknown',
        'chooseExecutionMode',
        'serverCapUnknown',
        'laneCap',
        'invalidDependencies',
        'dependencyPending',
        'missingDependency',
        'chooseBudget',
        'totalUsageUnknown',
        'dailyUsageUnknown',
        'invalidBudget',
        'budgetReached',
        'tokenUsageUnknown',
        'taskTokenBudgetReached',
      ]) {
        for (final planApproved in [false, true]) {
          final source = planned.copyWith(
            status: 'interrupted',
            planApproved: planApproved,
            planningState: TeamPlanningState(
              stage: 'interrupted',
              reason: reason,
            ),
            tasks: planApproved
                ? [task.copyWith(status: 'interrupted', reason: reason)]
                : [],
          );
          final harness = client(source);
          final project =
              (await harness.gateway.teamWorkspace()).projects.single;
          expect(project.timeline.last.text, contains('($reason)'));
          expect(project.timeline.last.text, isNot(contains('Resume')));
          expect(project.revision, source.revision);
          expect(
            harness.adapter.requests.every((r) => r.method == 'GET'),
            isTrue,
          );
        }
      }
    },
  );

  test(
    'checkpoint diagnostics reject unknown budget codes and secret text',
    () async {
      for (final reason in [
        'budgetExceeded',
        'private key secret-provider-value',
      ]) {
        for (final planApproved in [false, true]) {
          final source = planned.copyWith(
            status: 'interrupted',
            planApproved: planApproved,
            planningState: TeamPlanningState(
              stage: 'interrupted',
              reason: reason,
            ),
            tasks: planApproved
                ? [task.copyWith(status: 'interrupted', reason: reason)]
                : [],
          );
          final project = (await client(
            source,
          ).gateway.teamWorkspace()).projects.single;
          expect(project.timeline.last.text, isNot(contains(reason)));
          expect(
            project.timeline.last.text,
            planApproved
                ? 'Work was interrupted and needs review.'
                : 'Planning stopped and needs review.',
          );
        }
      }
    },
  );

  test(
    'mixed safe and review-only checkpoints do not offer project Resume',
    () async {
      final source = planned.copyWith(
        status: 'interrupted',
        planApproved: true,
        tasks: [
          task.copyWith(
            status: 'interrupted',
            reason: 'restartNeedsReconciliation',
          ),
          task.copyWith(
            id: 'unsafe',
            status: 'interrupted',
            reason: 'recoveryNeedsReview',
          ),
        ],
      );
      final project = (await client(
        source,
      ).gateway.teamWorkspace()).projects.single;
      expect(project.status, 'failed');
      expect(project.tasks.map((t) => t.status), ['paused', 'review']);
      expect(
        project.timeline.where((e) => e.kind == 'taskCheckpoint'),
        hasLength(2),
      );
    },
  );

  test(
    'existing session refetch is running without a new prompt or receipt',
    () async {
      final source = planned.copyWith(
        status: 'running',
        planApproved: true,
        tasks: [task.copyWith(status: 'resuming', reason: 'chatStatusUnknown')],
      );
      final harness = client(source);
      final project = (await harness.gateway.teamWorkspace()).projects.single;
      expect(project.status, 'running');
      expect(project.tasks.single.status, 'running');
      expect(project.tasks.single.reason, 'chatStatusUnknown');
      expect(project.revision, source.revision);
      expect(project.receipts, isEmpty);
      expect(harness.adapter.requests.every((r) => r.method == 'GET'), isTrue);
    },
  );

  test(
    'reconciliation presentation never overrides an explicit stop or pause',
    () async {
      for (final status in ['paused', 'stopped']) {
        final source = planned.copyWith(
          status: status,
          planApproved: true,
          tasks: [
            task.copyWith(
              status: 'interrupted',
              reason: 'restartNeedsReconciliation',
            ),
          ],
        );
        final project = (await client(
          source,
        ).gateway.teamWorkspace()).projects.single;
        expect(project.status, status);
        expect(project.planApproved, isTrue);
        expect(project.revision, source.revision);
      }
    },
  );

  test(
    'checker and merge stages use existing domain vocabulary without inventing receipts',
    () async {
      final source = planned.copyWith(
        status: 'running',
        planApproved: true,
        tasks: [
          for (final status in [
            'review',
            'checked',
            'needsFix',
            'merging',
            'merged',
          ])
            task.copyWith(id: status, status: status),
        ],
      );
      final project = (await client(
        source,
      ).gateway.teamWorkspace()).projects.single;
      expect(project.tasks.map((task) => task.status), [
        'review',
        'verified',
        'review',
        'running',
        'merged',
      ]);
      expect(project.mergeQueue, isEmpty);
      expect(project.receipts, isEmpty);
      expect(project.status, 'running');
      expect(project.planningState!.toJson(), planner.toJson());
    },
  );

  test(
    'legacy needsFix presents review and open findings without checker-authored closure',
    () async {
      final findings = [
        for (final status in ['met', 'fixed', 'ignored', 'closed', 'open'])
          TeamFinding(
            id: status,
            status: status,
            text: 'Check this criterion',
            criterion: 'Works',
          ),
      ];
      const results = [TeamCriterionResult(criterion: 'Works', status: 'met')];
      final blocked = task.copyWith(
        status: 'needsFix',
        findings: findings,
        criterionResults: results,
      );
      final fulfilled = task.copyWith(
        id: 'fulfilled',
        status: 'merged',
        findings: findings,
        criterionResults: results,
      );
      final source = planned.copyWith(
        status: 'running',
        planApproved: true,
        tasks: [blocked, fulfilled],
      );
      final project = (await client(
        source,
      ).gateway.teamWorkspace()).projects.single;
      final review = project.tasks.first;
      expect(review.status, 'review');
      expect(review.reason, 'checkerFindings');
      expect(
        review.findings.map((finding) => finding.status),
        everyElement('open'),
      );
      expect(
        review.findings.map((finding) => finding.id),
        findings.map((finding) => finding.id),
      );
      expect(
        review.findings.map((finding) => finding.text),
        findings.map((finding) => finding.text),
      );
      expect(
        review.criterionResults.map((result) => result.toJson()),
        results.map((result) => result.toJson()),
      );
      expect(project.revision, source.revision);
      expect(project.tasks.last.toJson(), fulfilled.toJson());
      expect(blocked.findings.map((finding) => finding.status), [
        'met',
        'fixed',
        'ignored',
        'closed',
        'open',
      ]);

      final explicit = blocked.copyWith(reason: 'checkInvalid');
      final preserved = (await client(
        source.copyWith(tasks: [explicit]),
      ).gateway.teamWorkspace()).projects.single.tasks.single;
      expect(preserved.reason, 'checkInvalid');
      expect(preserved.status, 'review');
    },
  );
}
