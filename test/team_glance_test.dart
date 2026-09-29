import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/domain/team_glance.dart';

OrchestrationRun _run(String id, RunState state, {int? steps, int? done}) =>
    OrchestrationRun(
      id: id,
      title: 'Task $id',
      state: state,
      stepCount: steps,
      completedSteps: done,
    );

void main() {
  test('counts working and needs-you; needs-you first, at most three', () {
    final glance = TeamGlance.fromTasks(
      open: [
        _run('a', RunState.working, steps: 5, done: 2),
        _run('b', RunState.working),
        _run('c', RunState.waiting),
        _run('d', RunState.working),
      ],
      gated: {'d'},
    );
    expect(glance.working, 2);
    expect(glance.needsYou, 1);
    expect(glance.top.map((t) => t.id), ['d', 'a', 'b']);
    expect(glance.top.first.needsYou, isTrue);
    expect(glance.top[1].stepsDone, 2);
    expect(glance.top[1].stepsTotal, 5);
  });

  test('nothing open is idle', () {
    final glance = TeamGlance.fromTasks(open: const [], gated: const {});
    expect(glance.isIdle, isTrue);
    expect(glance.top, isEmpty);
  });
}
