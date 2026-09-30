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
    TeamProject project,
  ) {
    final wire = engine.workspace(12)..['projects'] = [project.toJson()];
    final adapter = engine.FakeEngineAdapter(
      (request) async => engine.jsonBody(
        request.path == '/v1/health'
            ? engine.health('p1', execution: true, actions: ['approvePlan'])
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
    'reconciliation checkpoint is stalled while person pause and stop stay intact',
    () async {
      const interrupted = TeamPlanningState(
        stage: 'interrupted',
        reason: 'restartNeedsReconciliation',
      );
      for (final status in ['planning', 'paused', 'stopped']) {
        final project = (await client(
          planned.copyWith(status: status, planningState: interrupted),
        ).gateway.teamWorkspace()).projects.single;
        expect(project.status, status == 'planning' ? 'stalled' : status);
        expect(project.revision, 7);
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
