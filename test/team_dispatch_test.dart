import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/team_dispatch.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Gateway extends FixtureOrchestrationGateway {
  _Gateway() : super(fixturePath: 'tool/qa/gascity_fixture');

  OrchestrationCapabilities allowed = OrchestrationCapabilities.fixture;
  @override
  OrchestrationCapabilities get capabilities => allowed;
  final calls = <String>[];
  List<OrchestrationAgent> workers = [];
  Completer<void>? holdCreate;
  MutationReceiptStatus createReceipt = MutationReceiptStatus.accepted;
  MutationReceiptStatus assignReceipt = MutationReceiptStatus.accepted;
  bool includeId = true;
  bool failAgentRead = false;
  String? sentTitle;

  @override
  Future<List<OrchestrationAgent>> agents() async {
    if (failAgentRead) throw StateError('fixture read failed');
    return workers;
  }

  @override
  Future<MutationReceipt> createWork({
    required String title,
    String? description,
    String? projectId,
    required String requestId,
  }) async {
    calls.add('create');
    sentTitle = title;
    await holdCreate?.future;
    return MutationReceipt(
      id: requestId,
      status: createReceipt,
      upstreamStatus: 201,
      raw: {if (includeId) 'id': 'new-task'},
    );
  }

  @override
  Future<MutationReceipt> assign(
    String workId, {
    required String agentId,
    required String requestId,
  }) async {
    calls.add('assign:$workId:$agentId');
    return MutationReceipt(
      id: requestId,
      status: assignReceipt,
      upstreamStatus: 200,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<OrchestrationController> boot(_Gateway gateway) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final config = OrchestrationConfig(
      provider: OrchestrationProvider.fixture,
      url: 'fixture://gascity',
      enabledAt: DateTime.utc(2026, 9, 27),
    );
    final source = OrchestrationController(
      profile: ServerProfile(
        id: 'dispatch-test',
        name: 'Fixture',
        baseUrl: 'http://127.0.0.1:4096',
        orchestration: config,
      ),
      config: config,
      store: OrchestrationStore(prefs),
      probe: (_) async => ProbeFound(host: gateway.host!, city: 'fixture'),
      gatewayFactory: (_, _) => gateway,
    );
    addTearDown(source.dispose);
    await source.start();
    return source;
  }

  TeamDispatchController track(OrchestrationController source) {
    final dispatch = TeamDispatchController(source);
    addTearDown(dispatch.dispose);
    return dispatch;
  }

  Future<void> submit(TeamDispatchController dispatch) => dispatch.submit(
    title: 'Fix startup',
    projectId: 'project',
    agentId: 'project/pool',
  );

  test('gates both capabilities and validates before any create', () async {
    for (final capabilities in [
      const OrchestrationCapabilities(controlCreateWork: true),
      const OrchestrationCapabilities(controlAssign: true),
    ]) {
      final gateway = _Gateway()..allowed = capabilities;
      final dispatch = track(await boot(gateway));
      expect(dispatch.canSubmit, isFalse);
      await submit(dispatch);
      expect(dispatch.phase, TeamDispatchPhase.unavailable);
      expect(gateway.calls, isEmpty);
    }
    final gateway = _Gateway();
    final dispatch = track(await boot(gateway));
    await dispatch.submit(title: ' ', projectId: 'project', agentId: 'pool');
    expect(dispatch.phase, TeamDispatchPhase.invalidInput);
    expect(gateway.calls, isEmpty);
    expect(dispatch.canSubmit, isTrue);
    await gateway.close();
    await Future<void>.delayed(Duration.zero);
    expect(dispatch.canSubmit, isFalse);
    await submit(dispatch);
    expect(dispatch.phase, TeamDispatchPhase.unavailable);
    expect(gateway.calls, isEmpty);
  });

  test(
    'one create and immediate assign; only matching running session counts',
    () async {
      final gateway = _Gateway()..holdCreate = Completer<void>();
      final source = await boot(gateway);
      final dispatch = track(source);
      var notifications = 0;
      dispatch.addListener(() => notifications++);
      final first = submit(dispatch);
      expect(identical(first, submit(dispatch)), isTrue);
      expect(dispatch.phase, TeamDispatchPhase.submitting);
      gateway.holdCreate!.complete();
      await first;
      // giveTask's work/run refresh is deliberately fire-and-forget. Drain
      // those microtasks before changing the next agent snapshot.
      await Future<void>.delayed(Duration.zero);
      expect(gateway.calls, ['create', 'assign:new-task:project/pool']);
      expect(dispatch.workId, 'new-task');
      expect(dispatch.assignStatus, MutationStatus.confirmed);
      expect(dispatch.assignmentReceipt, MutationReceiptStatus.accepted);
      expect(dispatch.phase, TeamDispatchPhase.awaitingWorker);
      expect(identical(first, submit(dispatch)), isTrue);

      for (final candidate in [
        const OrchestrationAgent(
          id: 'worker',
          name: 'Worker',
          state: AgentState.working,
          currentWorkId: 'other-task',
          sessionId: 'other',
          sessionRunning: true,
        ),
        const OrchestrationAgent(
          id: 'worker',
          name: 'Worker',
          state: AgentState.working,
          currentWorkId: 'new-task',
          sessionId: 'stopped',
          sessionRunning: false,
        ),
        const OrchestrationAgent(
          id: 'worker',
          name: 'Worker',
          state: AgentState.working,
          currentWorkId: 'new-task',
          sessionId: 'unknown',
        ),
      ]) {
        gateway.workers = [candidate];
        await source.refresh();
        expect(dispatch.workerSessionId, isNull);
        expect(dispatch.phase, TeamDispatchPhase.awaitingWorker);
      }
      gateway.workers = [
        const OrchestrationAgent(
          id: 'worker',
          name: 'Worker',
          state: AgentState.stopped,
          currentWorkId: 'new-task',
          sessionId: 'matching',
          sessionRunning: true,
        ),
      ];
      await source.refresh();
      expect(dispatch.workerSessionId, 'matching');
      expect(dispatch.phase, TeamDispatchPhase.workerObserved);
      expect(notifications, greaterThan(1));
      gateway.failAgentRead = true;
      await source.refresh();
      expect(source.lastError, isNotNull);
      expect(dispatch.workerSessionId, isNull);
      await source.stop();
      expect(dispatch.workerSessionId, isNull);
    },
  );

  test(
    'refusal or missing created ID never claims dispatch or retries',
    () async {
      for (final rejected in [true, false]) {
        final gateway = _Gateway()
          ..createReceipt = rejected
              ? MutationReceiptStatus.rejected
              : MutationReceiptStatus.accepted
          ..includeId = false;
        final dispatch = track(await boot(gateway));
        await submit(dispatch);
        expect(
          dispatch.phase,
          rejected ? TeamDispatchPhase.rejected : TeamDispatchPhase.unconfirmed,
        );
        expect(dispatch.assignMutationKey, isNull);
        await submit(dispatch);
        expect(gateway.calls, ['create']);
      }
    },
  );

  test(
    'uncertain assignment stays unconfirmed and preserves sent task text',
    () async {
      final gateway = _Gateway()..assignReceipt = MutationReceiptStatus.pending;
      final dispatch = track(await boot(gateway));
      await dispatch.submit(
        title: 'Fix startup token=fake-test-value',
        projectId: 'project',
        agentId: 'project/pool',
      );
      expect(gateway.sentTitle, 'Fix startup token=fake-test-value');
      expect(dispatch.phase, TeamDispatchPhase.unconfirmed);
      expect(dispatch.workId, 'new-task');
      expect(dispatch.assignmentReceipt, MutationReceiptStatus.pending);
      await submit(dispatch);
      expect(gateway.calls.length, 2);
    },
  );

  test(
    'dispose during submission detaches and suppresses late notification',
    () async {
      final gateway = _Gateway()..holdCreate = Completer<void>();
      final source = await boot(gateway);
      final dispatch = TeamDispatchController(source);
      var notifications = 0;
      dispatch.addListener(() => notifications++);
      final pending = submit(dispatch);
      dispatch.dispose();
      final before = notifications;
      gateway.holdCreate!.complete();
      await pending;
      await source.refresh();
      expect(notifications, before);
      expect(dispatch.canSubmit, isFalse);
      await submit(dispatch);
      expect(gateway.calls.length, 2);
    },
  );
}
