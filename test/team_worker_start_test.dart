import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/orchestration/models/agent.dart';
import 'package:opencode_mobile/state/team_worker_start.dart';
import 'package:shared_preferences/shared_preferences.dart';

OrchestrationAgent _agent(
  String? sessionState, {
  bool? running,
  Map<String, Object?> raw = const {},
}) => OrchestrationAgent(
  id: 'gc-1',
  name: 'worker',
  state: AgentState.working,
  sessionState: sessionState,
  sessionRunning: running,
  raw: raw,
);

void main() {
  test('the stage comes from the session the host reports', () {
    expect(teamWorkerStage(null), isNull);
    expect(teamWorkerStage(_agent(null)), isNull);
    expect(teamWorkerStage(_agent('creating')), TeamWorkerStage.preparing);
    expect(teamWorkerStage(_agent('start-pending')), TeamWorkerStage.preparing);
    expect(
      teamWorkerStage(_agent('active', running: true)),
      TeamWorkerStage.running,
    );
    expect(
      teamWorkerStage(
        _agent(
          'active',
          running: true,
          raw: {'last_nudge_delivered_at': '2026-09-29T10:09:40Z'},
        ),
      ),
      TeamWorkerStage.taskDelivered,
    );
  });

  test('only a plausible start is a measurement', () {
    final created = DateTime.utc(2026, 9, 29, 10, 8);
    expect(
      teamWorkerStartMeasured(
        sessionStartedAt: created,
        began: created.add(const Duration(seconds: 42)),
      ),
      const Duration(seconds: 42),
    );
    expect(
      teamWorkerStartMeasured(
        sessionStartedAt: created,
        began: created.add(const Duration(hours: 5)),
      ),
      isNull,
    );
    expect(
      teamWorkerStartMeasured(sessionStartedAt: null, began: created),
      isNull,
    );
  });

  test('the last start is kept per profile', () async {
    SharedPreferences.setMockInitialValues({});
    final store = TeamWorkerStartStore(await SharedPreferences.getInstance());
    expect(store.read('p1'), isNull);
    await store.record('p1', const Duration(seconds: 42));
    expect(store.read('p1'), const Duration(seconds: 42));
    expect(store.read('p2'), isNull);
    expect(TeamWorkerStartStore.key('p1'), 'oc.teamWorkerStart.p1');
  });
}
