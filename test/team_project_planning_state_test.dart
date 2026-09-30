import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/team_project.dart';

void main() {
  test('legacy project snapshots remain readable without planner metadata', () {
    final project = TeamProject.fromJson({
      'id': 'legacy',
      'status': 'planning',
      'revision': 4,
    });
    expect(project.status, 'planning');
    expect(project.revision, 4);
    expect(project.planningState, isNull);
    expect(project.timelineTruncated, isFalse);
    expect(project.timeline, isEmpty);
    expect(TeamProject.fromJson(project.toJson()).planningState, isNull);
  });

  test('typed planner gate and durable timeline survive domain round trip', () {
    final project = TeamProject.fromJson({
      'id': 'project',
      'status': 'planning',
      'revision': 3,
      'planningState': {
        'jobId': 'planner-1',
        'stage': 'queued',
        'reason': 'chatStatusUnknown',
        'updatedAt': '2026-10-01T00:01:00.000Z',
      },
      'timelineTruncated': true,
      'timeline': [
        {
          'id': 'event-1',
          'kind': 'planner',
          'text': 'Planning is waiting for chat status to be checked.',
          'actor': 'engine',
          'at': '2026-10-01T00:01:00.000Z',
          'taskId': '',
        },
      ],
    });
    expect(project.planningState!.jobId, 'planner-1');
    expect(project.planningState!.stage, 'queued');
    expect(project.planningState!.reason, 'chatStatusUnknown');
    expect(project.timeline.single.actor, 'engine');
    expect(project.status, 'planning');
    final roundTrip = TeamProject.fromJson(project.toJson());
    expect(roundTrip.planningState!.toJson(), project.planningState!.toJson());
    expect(
      roundTrip.timeline.single.toJson(),
      project.timeline.single.toJson(),
    );
    expect(roundTrip.timelineTruncated, isTrue);
    final renamed = project.copyWith(name: 'Renamed');
    expect(renamed.planningState!.reason, 'chatStatusUnknown');
    expect(renamed.timelineTruncated, isTrue);
  });

  test('planner checkpoint updates preserve project workflow and revision', () {
    const project = TeamProject(
      id: 'project',
      status: 'planning',
      revision: 9,
      planningState: TeamPlanningState(
        jobId: 'planner-1',
        stage: 'queued',
        reason: 'chatBusy',
      ),
    );
    final running = project.copyWith(
      planningState: const TeamPlanningState(
        jobId: 'planner-1',
        stage: 'running',
      ),
    );
    expect(running.status, 'planning');
    expect(running.revision, 9);
    expect(running.planningState!.stage, 'running');
    expect(running.planningState!.reason, isEmpty);
  });
}
