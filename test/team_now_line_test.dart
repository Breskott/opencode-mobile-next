import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/state/mutation_store.dart';
import 'package:opencode_mobile/state/team_now_line.dart';
import 'package:opencode_mobile/state/team_planning.dart';

final epoch = DateTime.utc(2026, 9, 27);

TeamNowInput waiting({String key = 'profile/task/step', DateTime? since}) =>
    TeamNowInput(
      activityKey: key,
      activity: TeamNowActivity.waitingForWorker,
      next: TeamNowNext.worker,
      reason: TeamNowReason.noWorkerReported,
      since: since,
    );

TeamPlanningRequest planning(TeamPlanningStatus status) => TeamPlanningRequest(
  record: MutationRecord(
    key: 'request',
    request: MutationRequest.message(teamPlannerAgentId, 'Synthetic objective'),
    createdAt: epoch,
    status: MutationStatus.confirmed,
  ),
  objective: 'Synthetic objective',
  supervision: TeamSupervision.balanced,
  status: status,
);

TeamNowInput runInput({
  RunState state = RunState.working,
  bool connected = true,
  DispatchStall? stall,
  List<OrchestrationGate> gates = const [],
}) => TeamNowInput.forRun(
  activityKey: 'profile/run/step',
  run: OrchestrationRun(
    id: 'run',
    title: 'Synthetic task',
    state: state,
    kind: RunKind.batch,
    startedAt: epoch,
  ),
  work: [
    WorkItem(id: 'step', title: 'Synthetic step', state: WorkState.working),
  ],
  cycleOf: (_) => DispatchCycle(
    step: DispatchStep.working,
    reachedAt: {DispatchStep.routed: epoch, DispatchStep.claimed: epoch},
    stalled: stall != null,
    stallReason: stall,
  ),
  agents: const [],
  gates: gates,
  connected: connected,
  canCancel: true,
);

void main() {
  testWidgets('Why appears at 8 seconds without a server update', (
    tester,
  ) async {
    var now = epoch;
    final controller = TeamNowLineController(
      waiting(since: epoch),
      clock: () => now,
    );
    var notifications = 0;
    controller.addListener(() => notifications++);
    expect(controller.value.explain, isFalse);
    now = epoch.add(const Duration(seconds: 7));
    await tester.pump(const Duration(seconds: 7));
    expect(controller.value.explain, isFalse);
    // Repeated refreshes must not restart the patience window.
    controller.update(waiting(since: epoch));
    final beforeDeadline = notifications;
    now = epoch.add(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 1));
    expect(notifications, greaterThan(beforeDeadline));
    expect(controller.value.explain, isTrue);
    expect(controller.value.since, epoch);
    expect(controller.value.reason, TeamNowReason.noWorkerReported);
    expect(controller.value.next, TeamNowNext.worker);
    expect(controller.value.actions, contains(TeamNowAction.openActivity));
    expect(controller.value.typicalUpperBound, isNull);
    controller.dispose();
  });

  testWidgets('unknown times, task changes, clock skew and disposal', (
    tester,
  ) async {
    var now = epoch;
    final controller = TeamNowLineController(waiting(), clock: () => now);
    now = now.add(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 8));
    expect(controller.value.explain, isTrue);
    expect(controller.value.since, isNull);
    controller.update(
      waiting(
        key: 'other-profile/task/step',
        since: now.add(const Duration(days: 1)),
      ),
    );
    expect(controller.value.explain, isFalse);
    now = now.add(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 8));
    expect(controller.value.explain, isTrue);
    controller.update(waiting(key: 'third-task'));
    var afterDispose = 0;
    controller.addListener(() => afterDispose++);
    controller.dispose();
    now = now.add(const Duration(seconds: 8));
    await tester.pump(const Duration(seconds: 8));
    expect(afterDispose, 0);
    expect(tester.takeException(), isNull);
  });

  test(
    '31 minute planning has an honest reason and a non-resending way out',
    () {
      for (final status in [
        TeamPlanningStatus.planning,
        TeamPlanningStatus.stillPlanning,
      ]) {
        final controller = TeamNowLineController(
          TeamNowInput.forPlanning(
            activityKey: 'profile/request',
            request: planning(status),
          ),
          clock: () => epoch.add(const Duration(minutes: 31)),
        );
        expect(controller.value.explain, isTrue);
        expect(controller.value.reason, TeamNowReason.noPlanReported);
        expect(controller.value.next, TeamNowNext.plan);
        expect(controller.value.since, epoch);
        expect(controller.value.typicalUpperBound, isNull);
        expect(controller.value.actions, [
          TeamNowAction.refresh,
          TeamNowAction.openActivity,
          TeamNowAction.dismissRequest,
        ]);
        controller.dispose();
      }
      expect(
        () => TeamNowInput.forPlanning(
          activityKey: 'profile/request',
          request: planning(TeamPlanningStatus.started),
        ),
        throwsArgumentError,
      );
      for (final status in [
        TeamPlanningStatus.unconfirmed,
        TeamPlanningStatus.refused,
      ]) {
        final controller = TeamNowLineController(
          TeamNowInput.forPlanning(
            activityKey: 'profile/request',
            request: planning(status),
          ),
          clock: () => epoch,
        );
        expect(controller.value.explain, isTrue);
        expect(controller.value.next, TeamNowNext.checkActivity);
        expect(
          controller.value.reason,
          status == TeamPlanningStatus.unconfirmed
              ? TeamNowReason.confirmationMissing
              : TeamNowReason.requestRefused,
        );
        controller.dispose();
      }
    },
  );

  test(
    'run facts, stalls and unavailable connections determine next and recovery',
    () {
      final controller = TeamNowLineController(
        runInput(),
        clock: () => epoch.add(const Duration(seconds: 9)),
      );
      expect(controller.value.activity, TeamNowActivity.working);
      expect(controller.value.next, TeamNowNext.review);
      expect(controller.value.actions, contains(TeamNowAction.cancelRun));
      for (final (stall, reason) in [
        (DispatchStall.hostNotStarted, TeamNowReason.noWorkerReported),
        (DispatchStall.agentCannotStart, TeamNowReason.workerCouldNotStart),
        (DispatchStall.providerLimit, TeamNowReason.providerLimit),
        (DispatchStall.workingLong, TeamNowReason.workTakingLonger),
        (DispatchStall.mergeWaiting, TeamNowReason.reviewPending),
      ]) {
        controller.update(runInput(stall: stall));
        expect(controller.value.activity, TeamNowActivity.delayed);
        expect(controller.value.reason, reason);
        expect(controller.value.explain, isTrue);
      }
      controller.update(runInput(connected: false));
      expect(controller.value.activity, TeamNowActivity.unavailable);
      expect(controller.value.reason, TeamNowReason.connectionUnavailable);
      expect(controller.value.since, isNull);
      expect(
        controller.value.actions,
        isNot(contains(TeamNowAction.cancelRun)),
      );
      controller.dispose();
    },
  );

  test('starting estimates stay optional and a question takes priority', () {
    final controller = TeamNowLineController(
      TeamNowInput.forRun(
        activityKey: 'profile/run/step',
        run: OrchestrationRun(
          id: 'run',
          title: 'Task',
          state: RunState.working,
        ),
        work: [WorkItem(id: 'step', title: 'Step', state: WorkState.working)],
        cycleOf: (_) => DispatchCycle(
          step: DispatchStep.claimed,
          reachedAt: {DispatchStep.agentStarting: epoch},
        ),
        agents: const [],
        // Synthetic timing evidence supplied by the caller, never a default.
        typicalUpperBound: const Duration(minutes: 1),
      ),
      clock: () => epoch.add(const Duration(seconds: 8)),
    );
    expect(controller.value.activity, TeamNowActivity.startingWorker);
    expect(controller.value.next, TeamNowNext.work);
    expect(controller.value.typicalUpperBound, const Duration(minutes: 1));
    expect(controller.value.actions, isNot(contains(TeamNowAction.cancelRun)));
    controller.update(
      runInput(
        gates: [
          OrchestrationGate(
            id: 'gate',
            kind: GateKind.confirmation,
            title: 'Continue?',
            createdAt: epoch,
          ),
        ],
      ),
    );
    expect(controller.value.activity, TeamNowActivity.needsYou);
    expect(controller.value.explain, isTrue);
    expect(controller.value.reason, TeamNowReason.answerNeeded);
    expect(controller.value.next, TeamNowNext.yourAnswer);
    expect(controller.value.actions, contains(TeamNowAction.answer));
    expect(controller.value.typicalUpperBound, isNull);
    controller.dispose();
  });

  test('terminal outcomes stay distinct and do not offer cancel or timing', () {
    for (final (state, activity) in [
      (RunState.completed, TeamNowActivity.completed),
      (RunState.failed, TeamNowActivity.failed),
      (RunState.cancelled, TeamNowActivity.cancelled),
    ]) {
      final controller = TeamNowLineController(
        runInput(state: state),
        clock: () => epoch,
      );
      expect(controller.value.activity, activity);
      expect(controller.value.actions, [TeamNowAction.openActivity]);
      expect(controller.value.typicalUpperBound, isNull);
      controller.dispose();
    }
  });
}
