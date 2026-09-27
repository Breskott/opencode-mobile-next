// screen-team-1: the agent page, the Gate sheet and the AI Team intro on
// the kit. What the person sees, what is sent and what is kept:
//
// - the agent message survives type, swipe and reopen, and is cleared once
//   sent (P7.1, DATA-1);
// - the Gate sheet's free-text answer survives the same (P7.1);
// - a host that takes no controls explains it with the host guide instead
//   of hiding the controls (P7.4);
// - Pause is undone in place; Stop names the worker by role and task and
//   is confirmed in the stop tone; Restart is confirmed neutrally;
// - a failed run offers "Ask the team to fix it", which sends the error to
//   the worker.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_sheet.dart' show KitDraft;
import 'package:opencode_mobile/ui/screens/team/agent_screen.dart';
import 'package:opencode_mobile/ui/screens/team/gate_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Call {
  const _Call(this.verb, this.target, {this.arg});

  final String verb;
  final String target;
  final Object? arg;
}

class _Gateway
    implements OrchestrationGateway, OrchestrationAgentOutputGateway {
  _Gateway({required this.capabilities});

  @override
  final OrchestrationCapabilities capabilities;
  final stream = StreamController<OrchestrationEvent>.broadcast();
  final calls = <_Call>[];
  List<OrchestrationRun> runList = const [];
  List<WorkItem> workList = const [];
  List<OrchestrationAgent> agentList = const [];
  List<OrchestrationGate> gateList = const [];
  bool _closed = false;

  @override
  OrchestrationHostIdentity? get host => const OrchestrationHostIdentity(
    provider: 'gascity',
    url: 'http://127.0.0.1:8373',
    city: 'bright-lights',
    hostMode: OrchestrationHostMode.computer,
  );

  @override
  bool get isClosed => _closed;

  @override
  Future<void> close() async {
    _closed = true;
    await stream.close();
  }

  Future<MutationReceipt> _call(_Call call, String requestId) {
    calls.add(call);
    return Future.value(
      MutationReceipt(
        id: requestId,
        status: MutationReceiptStatus.accepted,
        correlationId: 'corr-$requestId',
        upstreamStatus: 202,
      ),
    );
  }

  @override
  Future<List<OrchestrationProject>> projects() async => const [
    OrchestrationProject(id: 'ocproof', name: 'ocproof', rig: 'ocproof'),
  ];
  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) async => runList;
  @override
  Future<OrchestrationRun?> run(String id) async {
    for (final r in runList) {
      if (r.id == id) return r;
    }
    return null;
  }

  @override
  Future<List<WorkItem>> work({String? projectId}) async => workList;
  @override
  Future<List<WorkItem>> readyWork({String? projectId}) async => [
    for (final w in workList)
      if (w.state == WorkState.ready) w,
  ];
  @override
  Future<WorkItem?> workItem(String id) async {
    for (final w in workList) {
      if (w.id == id) return w;
    }
    return null;
  }

  @override
  Future<List<OrchestrationAgent>> agents() async => agentList;
  @override
  Future<OrchestrationAgent?> agent(String id) async {
    for (final a in agentList) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Future<List<OrchestrationGate>> gates() async => gateList;
  @override
  Future<OrchestrationUsage?> usage() async => null;
  @override
  Future<List<ActivityEvent>> activity({
    int? afterSeq,
    int limit = 100,
  }) async => const [];
  @override
  Stream<OrchestrationEvent> events({
    EventCursor resumeFrom = EventCursor.none,
  }) => stream.stream;
  @override
  Stream<AgentOutputEvent> agentOutput(String sessionId) =>
      const Stream.empty();

  @override
  Future<MutationReceipt> respond(
    String gateId,
    GateResponse response, {
    required String requestId,
  }) => _call(_Call('respond', gateId, arg: response), requestId);
  @override
  Future<MutationReceipt> message(
    String agentId,
    String text, {
    required String requestId,
  }) => _call(_Call('message', agentId, arg: text), requestId);
  @override
  Future<MutationReceipt> controlAgent(
    String agentId,
    AgentControlAction action, {
    required String requestId,
  }) => _call(_Call('controlAgent', agentId, arg: action), requestId);
  @override
  Future<MutationReceipt> cancelRun(
    String runId, {
    required String requestId,
  }) => _call(_Call('cancelRun', runId), requestId);
  @override
  Future<MutationReceipt> assign(
    String workId, {
    required String agentId,
    required String requestId,
  }) => _call(_Call('assign', workId, arg: agentId), requestId);
  @override
  Future<MutationReceipt> createWork({
    required String title,
    String? description,
    String? projectId,
    required String requestId,
  }) => _call(_Call('createWork', title), requestId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OrchestrationStore store;
  final clock = DateTime.utc(2026, 9, 11, 9, 41);
  var nextKey = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = OrchestrationStore(await SharedPreferences.getInstance());
    nextKey = 0;
  });

  OrchestrationAgent fox() => OrchestrationAgent(
    id: 'fox',
    name: 'fox',
    state: AgentState.working,
    rawState: 'active',
    sessionId: 'bl-5qc',
    pool: 'gastown.polecat',
    model: 'openai/gpt-x',
    currentWorkId: 'w2',
    contextPercent: 63,
    sessionStartedAt: clock.subtract(const Duration(hours: 3)),
  );

  Future<(OrchestrationController, _Gateway)> boot({
    OrchestrationCapabilities capabilities =
        OrchestrationCapabilities.gascityFront,
    List<OrchestrationGate> gates = const [],
  }) async {
    final gateway = _Gateway(capabilities: capabilities)
      ..runList = [
        OrchestrationRun(
          id: 'oc-xru',
          title: 'Offline-first sessions',
          state: RunState.working,
          kind: RunKind.formula,
          stepCount: 3,
          completedSteps: 1,
          startedAt: clock.subtract(const Duration(hours: 1)),
        ),
      ]
      ..workList = const [
        WorkItem(
          id: 'w2',
          title: 'Sync engine',
          state: WorkState.working,
          runId: 'oc-xru',
          assignee: 'fox',
        ),
      ]
      ..agentList = [fox()]
      ..gateList = gates;
    final config = OrchestrationConfig(
      provider: OrchestrationProvider.gascity,
      url: 'http://127.0.0.1:8373',
      city: 'bright-lights',
      front: true,
      enabledAt: DateTime.utc(2026, 9, 10),
    );
    final controller = OrchestrationController(
      profile: ServerProfile(
        id: 'srv-1',
        name: 'Development PC',
        baseUrl: 'https://server.example:4096',
        orchestration: config,
      ),
      config: config,
      store: store,
      probe: (_) async => ProbeFound(
        host: gateway.host!,
        city: 'bright-lights',
        front: true,
        identityAllowed: true,
        capabilities: gateway.capabilities,
      ),
      gatewayFactory: (_, _) => gateway,
      now: () => clock,
      mintKey: () => 'key-${++nextKey}',
      refreshDebounce: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);
    await controller.start();
    expect(controller.phase, OrchestrationPhase.ready);
    return (controller, gateway);
  }

  Future<void> pumpAgent(
    WidgetTester tester,
    OrchestrationController controller,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: AgentScreen(
          controller: controller,
          agentId: 'fox',
          now: () => clock,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 61));
    await tester.pump();
  }

  group('agent message draft (P7.1)', () {
    testWidgets('survives type, swipe and reopen; cleared once sent', (
      tester,
    ) async {
      final (controller, gateway) = await boot();
      await pumpAgent(tester, controller);

      await tester.tap(key('team-agent-control-message'));
      await settle(tester);
      expect(key('team-agent-message-sheet'), findsOneWidget);
      await tester.enterText(key('team-agent-message-field'), 'Rebase first');
      await tester.pump();

      // Swipe it away: nothing is asked, nothing is lost.
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(key('team-agent-message-sheet'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      final draftKey = KitDraft.keyFor(
        teamAgentMessageDraftTarget('fox'),
        'srv-1',
      );
      expect(prefs.getString(draftKey), 'Rebase first');

      // Reopen: the words are back.
      await tester.tap(key('team-agent-control-message'));
      await settle(tester);
      expect(find.text('Rebase first'), findsOneWidget);

      await tester.tap(key('team-agent-message-send'));
      await settle(tester);
      final sent = gateway.calls.where((c) => c.verb == 'message').toList();
      expect(sent, hasLength(1));
      expect(sent.single.target, 'fox');
      expect(sent.single.arg, 'Rebase first');
      expect(prefs.getString(draftKey), isNull);
      await drain(tester);
    });
  });

  group('gate free-text draft (P7.1)', () {
    testWidgets('survives type, close and reopen', (tester) async {
      final (controller, _) = await boot(
        gates: [
          OrchestrationGate(
            id: 'g2',
            kind: GateKind.freeText,
            title: 'What should the offline banner say?',
            agentId: 'bl-5qc',
            createdAt: clock,
          ),
        ],
      );
      await pumpAgent(tester, controller);
      final context = tester.element(find.byType(AgentScreen));

      unawaited(showGateSheet(context, controller, 'g2', now: () => clock));
      await settle(tester);
      await tester.enterText(key('team-gate-composer'), 'You are offline');
      await tester.pump();
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(key('team-gate-composer'), findsNothing);

      unawaited(showGateSheet(context, controller, 'g2', now: () => clock));
      await settle(tester);
      expect(find.text('You are offline'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(KitDraft.keyFor(gateSheetDraftTarget('g2'), 'srv-1')),
        'You are offline',
      );
    });
  });

  group('explain instead of vanish (P7.4)', () {
    testWidgets('a read-only host: the agent page says why, with How', (
      tester,
    ) async {
      final (controller, _) = await boot(
        capabilities: OrchestrationCapabilities.gascityRead,
      );
      await pumpAgent(tester, controller);
      expect(key('team-agent-control-message'), findsNothing);
      expect(key('team-agent-controls-elsewhere'), findsOneWidget);
      expect(key('team-agent-controls-how'), findsOneWidget);
    });

    testWidgets('a read-only host: the gate says where to answer, with How', (
      tester,
    ) async {
      final (controller, _) = await boot(
        capabilities: OrchestrationCapabilities.gascityRead,
        gates: [
          OrchestrationGate(
            id: 'g1',
            kind: GateKind.choice,
            title: 'Which persistence strategy?',
            choices: const ['SQLite', 'Filesystem'],
            createdAt: clock,
          ),
        ],
      );
      await pumpAgent(tester, controller);
      final context = tester.element(find.byType(AgentScreen));
      unawaited(showGateSheet(context, controller, 'g1', now: () => clock));
      await settle(tester);
      expect(key('team-gate-answer-on-host'), findsOneWidget);
      expect(key('team-gate-how'), findsOneWidget);
      // The options still read; only answering is elsewhere.
      expect(find.text('SQLite'), findsOneWidget);
    });
  });

  group('controls', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(key('team-agent-more'));
      await settle(tester);
    }

    testWidgets('Pause fox is undone in place', (tester) async {
      final (controller, gateway) = await boot();
      await pumpAgent(tester, controller);
      await openMenu(tester);
      await tester.tap(find.text('Pause fox'));
      await settle(tester);
      expect(
        gateway.calls.map((c) => c.arg),
        contains(AgentControlAction.pause),
      );
      expect(find.text('Paused fox'), findsOneWidget);
      await tester.tap(key('team-agent-pause-undo-action'));
      await settle(tester);
      expect(
        gateway.calls.map((c) => c.arg),
        contains(AgentControlAction.resume),
      );
      await drain(tester);
    });

    testWidgets('Stop names the worker and its task, then stops it', (
      tester,
    ) async {
      final (controller, gateway) = await boot();
      await pumpAgent(tester, controller);
      await openMenu(tester);
      await tester.tap(find.text('Stop fox'));
      await settle(tester);
      expect(key('team-agent-stop-confirm'), findsOneWidget);
      expect(find.textContaining('Worker · fox'), findsWidgets);
      expect(find.textContaining("stops working on “Sync engine”"), findsOneWidget);
      // Nothing is sent before the second step.
      expect(gateway.calls.where((c) => c.verb == 'controlAgent'), isEmpty);
      await tester.tap(key('team-agent-stop-confirm-action'));
      await settle(tester);
      expect(
        gateway.calls.map((c) => c.arg),
        contains(AgentControlAction.stop),
      );
      await drain(tester);
    });

    testWidgets('Reassign work is gone (the dispatcher routes work)', (
      tester,
    ) async {
      final (controller, _) = await boot();
      await pumpAgent(tester, controller);
      await openMenu(tester);
      expect(key('team-agent-control-reassign'), findsNothing);
      expect(key('team-agent-details'), findsNothing);
    });
  });

  group('run failed', () {
    testWidgets('Ask the team to fix it sends the error to the worker', (
      tester,
    ) async {
      final (controller, gateway) = await boot(
        gates: [
          OrchestrationGate(
            id: 'g3',
            kind: GateKind.runFailed,
            title: 'Offline-first sessions failed',
            prompt: 'npm test exited with code 1',
            runId: 'oc-xru',
            createdAt: clock,
          ),
        ],
      );
      await pumpAgent(tester, controller);
      final context = tester.element(find.byType(AgentScreen));
      unawaited(showGateSheet(context, controller, 'g3', now: () => clock));
      await settle(tester);
      await tester.tap(key('team-gate-run-fix'));
      await settle(tester);
      final sent = gateway.calls.where((c) => c.verb == 'message').single;
      expect(sent.target, 'fox');
      expect(sent.arg, contains('npm test exited with code 1'));
      expect(sent.arg, contains('Sync engine'));
      await drain(tester);
    });
  });
}
