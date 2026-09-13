// TEAM-204: agent controls, run controls and Start a run.
//
// Controls are absent (not disabled) without the `control*` capabilities
// and present with `gascityFront`; Nudge is one tap with a receipt chip
// that follows the record (Sent → Confirmed / Unconfirmed); Stop, Restart
// and Cancel run are two-step (the first tap opens the confirmation, the
// second sends, backing out sends nothing); Message sends the text;
// Reassign picks a ready item and sends assignWork; Start a run sends the
// objective and the supervision line to the Mayor, shows "Planning…
// (Mayor)" on the home, resolves when a run carrying the objective
// appears, and a suspended Mayor shows the host-off copy without sending.
// Layout: 320dp × 2.5x, LTR and RTL, for the agent controls and the sheet.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/team_planning.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/team/agent_output_screen.dart';
import 'package:opencode_mobile/ui/screens/team/agent_screen.dart';
import 'package:opencode_mobile/ui/screens/team/run_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One recorded control call.
class _Call {
  const _Call(this.verb, this.target, this.requestId, {this.arg});

  final String verb;
  final String target;
  final String requestId;
  final Object? arg;

  @override
  String toString() => '$verb $target ${arg ?? ''}';
}

/// An in-memory host: lists the tests set, every control recorded and
/// answered as accepted with a correlation id, an owned event stream.
class _Gateway
    implements OrchestrationGateway, OrchestrationAgentOutputGateway {
  _Gateway({this.capabilities = OrchestrationCapabilities.gascityFront});

  @override
  final OrchestrationCapabilities capabilities;
  final stream = StreamController<OrchestrationEvent>.broadcast();
  final calls = <_Call>[];
  List<OrchestrationProject> projectList = const [];
  List<OrchestrationRun> runList = const [];
  List<WorkItem> workList = const [];
  List<OrchestrationAgent> agentList = const [];
  Future<MutationReceipt> Function(_Call call)? answer;
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

  void push(OrchestrationEvent event) => stream.add(event);

  Future<MutationReceipt> _call(_Call call) {
    calls.add(call);
    final script = answer;
    if (script != null) return script(call);
    return Future.value(
      MutationReceipt(
        id: call.requestId,
        status: MutationReceiptStatus.accepted,
        correlationId: 'corr-${call.requestId}',
        upstreamStatus: 202,
      ),
    );
  }

  @override
  Future<List<OrchestrationProject>> projects() async => projectList;
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
  Future<List<OrchestrationGate>> gates() async => const [];
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
  }) => _call(_Call('respond', gateId, requestId, arg: response));
  @override
  Future<MutationReceipt> message(
    String agentId,
    String text, {
    required String requestId,
  }) => _call(_Call('message', agentId, requestId, arg: text));
  @override
  Future<MutationReceipt> controlAgent(
    String agentId,
    AgentControlAction action, {
    required String requestId,
  }) => _call(_Call('controlAgent', agentId, requestId, arg: action));
  @override
  Future<MutationReceipt> cancelRun(
    String runId, {
    required String requestId,
  }) => _call(_Call('cancelRun', runId, requestId));
  @override
  Future<MutationReceipt> assign(
    String workId, {
    required String agentId,
    required String requestId,
  }) => _call(_Call('assign', workId, requestId, arg: agentId));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OrchestrationStore store;
  late DateTime clock;
  var nextKey = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = OrchestrationStore(await SharedPreferences.getInstance());
    clock = DateTime.utc(2026, 9, 11, 9, 41);
    nextKey = 0;
  });

  OrchestrationAgent fox({AgentState state = AgentState.working}) =>
      OrchestrationAgent(
        id: 'fox',
        name: 'fox',
        state: state,
        rawState: state == AgentState.stopped ? 'stopped' : 'active',
        sessionId: 'bl-5qc',
        pool: 'gastown.polecat',
        provider: 'opencode',
        model: 'openai/gpt-x',
        harness: 'OpenCode',
        currentWorkId: 'w2',
        contextPercent: 63,
        workDir: '/home/eslam/city/.gc/worktrees/ocproof/polecats/fox',
        branch: 'polecat/oc-cq6',
        sessionStartedAt: clock.subtract(const Duration(hours: 3)),
      );

  OrchestrationAgent mayor({bool suspended = false, bool session = true}) =>
      OrchestrationAgent(
        id: 'gastown.mayor',
        name: 'gastown.mayor',
        state: suspended ? AgentState.stopped : AgentState.idle,
        rawState: suspended ? 'suspended' : 'idle',
        sessionId: session ? 'bl-8jc' : null,
        pack: 'gastown',
        raw: {'name': 'gastown.mayor', 'suspended': suspended},
      );

  OrchestrationRun run({
    String id = 'oc-xru',
    String title = 'Offline-first sessions',
    RunKind kind = RunKind.formula,
    RunState state = RunState.working,
    DateTime? startedAt,
  }) => OrchestrationRun(
    id: id,
    title: title,
    state: state,
    kind: kind,
    stepCount: 3,
    completedSteps: 1,
    startedAt: startedAt ?? clock.subtract(const Duration(hours: 1)),
    raw: {'id': id},
  );

  void shape(_Gateway gateway, {List<OrchestrationAgent>? agents}) {
    gateway
      ..projectList = const [
        OrchestrationProject(id: 'ocproof', name: 'ocproof', rig: 'ocproof'),
      ]
      ..runList = [run()]
      ..workList = const [
        WorkItem(
          id: 'w2',
          title: 'Sync engine',
          state: WorkState.working,
          runId: 'oc-xru',
        ),
        WorkItem(
          id: 'w4',
          title: 'Conflict policy',
          state: WorkState.ready,
          runId: 'oc-xru',
        ),
        WorkItem(
          id: 'w5',
          title: 'Storage layer',
          state: WorkState.queued,
          runId: 'oc-xru',
        ),
      ]
      ..agentList = agents ?? [fox(), mayor()];
  }

  Future<(OrchestrationController, _Gateway)> boot({
    OrchestrationCapabilities capabilities =
        OrchestrationCapabilities.gascityFront,
    void Function(_Gateway gateway)? configure,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final gateway = _Gateway(capabilities: capabilities);
    shape(gateway);
    configure?.call(gateway);
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
      mutationTimeout: timeout,
    );
    addTearDown(controller.dispose);
    await controller.start();
    expect(controller.phase, OrchestrationPhase.ready);
    return (controller, gateway);
  }

  Widget app(
    Widget home, {
    Locale locale = const Locale('en'),
    TextDirection? direction,
    double scale = 1,
  }) => MaterialApp(
    theme: AppTheme.dark(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: direction == null
          ? child!
          : Directionality(textDirection: direction, child: child!),
    ),
    home: home,
  );

  Future<void> size(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> pumpAgent(
    WidgetTester tester,
    OrchestrationController controller, {
    Locale locale = const Locale('en'),
    TextDirection? direction,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      app(
        AgentScreen(controller: controller, agentId: 'fox', now: () => clock),
        locale: locale,
        direction: direction,
        scale: scale,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> scrollToControls(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      key('team-agent-controls'),
      300,
      scrollable: find.descendant(
        of: key('team-agent-list'),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
  }

  /// Lets the receipt window of every sent record elapse so no timer is
  /// left pending when the tree is torn down.
  Future<void> drain(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 31));
    await tester.pump();
  }

  group('gating', () {
    testWidgets('read-only host: no controls, no FAB, no run menu', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, _) = await boot(
        capabilities: OrchestrationCapabilities.gascityRead,
      );
      await pumpAgent(tester, controller);
      expect(key('team-agent-controls'), findsNothing);
      expect(key('team-agent-control-nudge'), findsNothing);
      expect(find.text('Open session'), findsNothing);

      await tester.pumpWidget(
        app(TeamHomeScreen(controller: controller, now: () => clock)),
      );
      await settle(tester);
      expect(key('team-home-start-run'), findsNothing);

      await tester.pumpWidget(
        app(
          RunScreen(controller: controller, runId: 'oc-xru', now: () => clock),
        ),
      );
      await settle(tester);
      expect(key('team-run-more'), findsNothing);
      expect(key('team-run-details'), findsOneWidget);
    });

    testWidgets('front host: every control, never Open session', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, _) = await boot();
      await pumpAgent(tester, controller);
      await scrollToControls(tester);
      for (final id in [
        'message',
        'nudge',
        'pause',
        'stop',
        'restart',
        'reassign',
      ]) {
        expect(key('team-agent-control-$id'), findsOneWidget, reason: id);
      }
      expect(key('team-agent-control-resume'), findsNothing);
      expect(find.text('Open session'), findsNothing);
      expect(find.text('Open worktree'), findsNothing);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Reassign work…'), findsOneWidget);
    });

    testWidgets('only the granted controls exist', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, _) = await boot(
        capabilities: const OrchestrationCapabilities(
          runs: true,
          agents: true,
          agentOutput: true,
          controlMessage: true,
        ),
      );
      await pumpAgent(tester, controller);
      await scrollToControls(tester);
      expect(key('team-agent-control-message'), findsOneWidget);
      expect(key('team-agent-control-nudge'), findsNothing);
      expect(key('team-agent-control-stop'), findsNothing);
      expect(key('team-agent-control-reassign'), findsNothing);
    });

    testWidgets('a stopped agent offers Resume and no Stop', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, _) = await boot(
        configure: (g) => g.agentList = [fox(state: AgentState.stopped)],
      );
      await pumpAgent(tester, controller);
      await scrollToControls(tester);
      expect(key('team-agent-control-resume'), findsOneWidget);
      expect(key('team-agent-control-pause'), findsNothing);
      expect(key('team-agent-control-stop'), findsNothing);
      expect(key('team-agent-control-restart'), findsOneWidget);
    });
  });

  group('nudge', () {
    testWidgets('one tap sends the nudge and the chip follows the record', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot(
        timeout: const Duration(seconds: 30),
      );
      await pumpAgent(tester, controller);
      await scrollToControls(tester);
      await tester.tap(key('team-agent-control-nudge'));
      await settle(tester);
      expect(gateway.calls, hasLength(1));
      expect(gateway.calls.single.verb, 'controlAgent');
      expect(gateway.calls.single.target, 'fox');
      expect(gateway.calls.single.arg, AgentControlAction.nudge);
      final record = controller.latestMutation(
        kind: MutationKind.controlAgent,
        targetId: 'fox',
      );
      expect(record?.status, MutationStatus.sent);
      expect(key('team-agent-receipt'), findsOneWidget);
      expect(find.text('Nudge · Sent'), findsOneWidget);

      gateway.push(
        const RequestResult(requestId: 'corr-key-1', ok: true, seq: 10),
      );
      await settle(tester);
      expect(find.text('Nudge · Confirmed'), findsOneWidget);
      expect(gateway.calls, hasLength(1));
    });

    testWidgets('no result inside the window: Unconfirmed, never re-sent', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot(
        timeout: const Duration(milliseconds: 100),
      );
      await pumpAgent(tester, controller);
      await scrollToControls(tester);
      await tester.tap(key('team-agent-control-nudge'));
      await settle(tester);
      expect(find.text('Nudge · Sent'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await settle(tester);
      expect(find.text('Nudge · Unconfirmed'), findsOneWidget);
      expect(key('team-receipt-retry'), findsOneWidget);
      expect(gateway.calls, hasLength(1));
    });

    testWidgets('the host refuses: Refused with the reason', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot(
        configure: (g) =>
            g.answer = (call) async =>
                MutationReceipt.rejected(call.requestId, 'session is gone'),
      );
      await pumpAgent(tester, controller);
      await scrollToControls(tester);
      await tester.tap(key('team-agent-control-pause'));
      await settle(tester);
      expect(gateway.calls.single.arg, AgentControlAction.pause);
      expect(find.text('Pause · Refused'), findsOneWidget);
      expect(find.text('session is gone'), findsOneWidget);
    });
  });

  group('two-step', () {
    testWidgets('Stop: first tap confirms, second sends', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot();
      await pumpAgent(tester, controller);
      await scrollToControls(tester);
      await tester.tap(key('team-agent-control-stop'));
      await tester.pumpAndSettle();
      expect(key('team-agent-stop-confirm'), findsOneWidget);
      expect(find.text('Stop fox?'), findsOneWidget);
      expect(gateway.calls, isEmpty);
      await tester.tap(key('team-agent-stop-confirm-action'));
      await tester.pumpAndSettle();
      expect(gateway.calls.single.arg, AgentControlAction.stop);
      expect(find.text('Stop · Sent'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('Stop: backing out sends nothing', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot();
      await pumpAgent(tester, controller);
      await scrollToControls(tester);
      await tester.tap(key('team-agent-control-stop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();
      expect(key('team-agent-stop-confirm'), findsNothing);
      expect(gateway.calls, isEmpty);
      expect(key('team-agent-receipt'), findsNothing);
    });

    testWidgets('Restart: confirmation then the restart action', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot();
      await pumpAgent(tester, controller);
      await scrollToControls(tester);
      await tester.tap(key('team-agent-control-restart'));
      await tester.pumpAndSettle();
      expect(find.text('Restart fox?'), findsOneWidget);
      expect(gateway.calls, isEmpty);
      await tester.tap(key('team-agent-restart-confirm-action'));
      await tester.pumpAndSettle();
      expect(gateway.calls.single.arg, AgentControlAction.restart);
      expect(find.text('Restart · Sent'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('Cancel run: overflow → confirmation → cancelRun', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot();
      await tester.pumpWidget(
        app(
          RunScreen(controller: controller, runId: 'oc-xru', now: () => clock),
        ),
      );
      await settle(tester);
      await tester.tap(key('team-run-more'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel run'), findsOneWidget);
      await tester.tap(find.text('Cancel run'));
      await tester.pumpAndSettle();
      expect(key('team-run-cancel-confirm'), findsOneWidget);
      expect(gateway.calls, isEmpty);
      await tester.tap(key('team-run-cancel-confirm-action'));
      await tester.pumpAndSettle();
      expect(gateway.calls.single.verb, 'cancelRun');
      expect(gateway.calls.single.target, 'oc-xru');
      expect(key('team-run-receipt'), findsOneWidget);
      expect(find.text('Cancel run · Sent'), findsOneWidget);
      // The chip sits under the state header, before the progress bar.
      final chipY = tester.getTopLeft(key('team-run-receipt')).dy;
      expect(chipY, greaterThan(tester.getTopLeft(key('team-run-state')).dy));
      expect(chipY, lessThan(tester.getTopLeft(key('team-run-progress')).dy));
      await drain(tester);
    });

    testWidgets('Cancel run: backing out sends nothing', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot();
      await tester.pumpWidget(
        app(
          RunScreen(controller: controller, runId: 'oc-xru', now: () => clock),
        ),
      );
      await settle(tester);
      await tester.tap(key('team-run-more'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel run'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();
      expect(gateway.calls, isEmpty);
      expect(key('team-run-receipt'), findsNothing);
    });

    testWidgets('a batch offers Close batch; a finished run offers nothing', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, _) = await boot(
        configure: (g) => g.runList = [
          run(kind: RunKind.batch),
          run(id: 'oc-done', state: RunState.completed),
        ],
      );
      await tester.pumpWidget(
        app(
          RunScreen(controller: controller, runId: 'oc-xru', now: () => clock),
        ),
      );
      await settle(tester);
      await tester.tap(key('team-run-more'));
      await tester.pumpAndSettle();
      expect(find.text('Close batch'), findsOneWidget);
      expect(find.text('Cancel run'), findsNothing);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        app(
          RunScreen(controller: controller, runId: 'oc-done', now: () => clock),
        ),
      );
      await settle(tester);
      expect(key('team-run-more'), findsNothing);
    });
  });

  group('message and reassign', () {
    testWidgets('Message: the sheet sends the text', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot();
      await pumpAgent(tester, controller);
      await scrollToControls(tester);
      await tester.tap(key('team-agent-control-message'));
      await tester.pumpAndSettle();
      expect(key('team-agent-message-sheet'), findsOneWidget);
      expect(find.text('Message fox'), findsOneWidget);
      // Empty text cannot be sent.
      expect(
        tester.widget<IconButton>(key('team-agent-message-send')).onPressed,
        isNull,
      );
      await tester.enterText(
        key('team-agent-message-field'),
        'Use the offline queue for the tests',
      );
      await tester.pump();
      await tester.tap(key('team-agent-message-send'));
      await tester.pumpAndSettle();
      expect(gateway.calls.single.verb, 'message');
      expect(gateway.calls.single.target, 'fox');
      expect(gateway.calls.single.arg, 'Use the offline queue for the tests');
      expect(find.text('Message · Sent'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('Reassign: the picker lists ready work and sends assign', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot();
      await pumpAgent(tester, controller);
      await scrollToControls(tester);
      await tester.tap(key('team-agent-control-reassign'));
      await tester.pumpAndSettle();
      expect(key('team-agent-reassign-sheet'), findsOneWidget);
      expect(key('team-agent-reassign-w4'), findsOneWidget);
      expect(key('team-agent-reassign-w5'), findsNothing);
      expect(key('team-agent-reassign-w2'), findsNothing);
      await tester.tap(key('team-agent-reassign-w4'));
      await tester.pumpAndSettle();
      expect(gateway.calls.single.verb, 'assign');
      expect(gateway.calls.single.target, 'w4');
      expect(gateway.calls.single.arg, 'fox');
      expect(key('team-agent-assign-receipt'), findsOneWidget);
      expect(find.text('Reassign work… · Sent'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('Reassign: nothing ready says so', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot(
        configure: (g) => g.workList = const [
          WorkItem(id: 'w2', title: 'Sync engine', state: WorkState.working),
        ],
      );
      await pumpAgent(tester, controller);
      await scrollToControls(tester);
      await tester.tap(key('team-agent-control-reassign'));
      await tester.pumpAndSettle();
      expect(key('team-agent-reassign-empty'), findsOneWidget);
      expect(gateway.calls, isEmpty);
    });
  });

  group('start a run', () {
    Future<void> pumpHome(
      WidgetTester tester,
      OrchestrationController controller, {
      Locale locale = const Locale('en'),
      TextDirection? direction,
      double scale = 1,
    }) async {
      await tester.pumpWidget(
        app(
          TeamHomeScreen(controller: controller, now: () => clock),
          locale: locale,
          direction: direction,
          scale: scale,
        ),
      );
      await settle(tester);
    }

    testWidgets(
      'sends objective + supervision to the Mayor, shows Planning, resolves',
      (tester) async {
        await size(tester, const Size(400, 900));
        final (controller, gateway) = await boot(
          timeout: const Duration(seconds: 30),
        );
        await pumpHome(tester, controller);
        expect(key('team-home-start-run'), findsOneWidget);
        await tester.tap(key('team-home-start-run'));
        await tester.pumpAndSettle();
        expect(key('team-start-run-sheet'), findsOneWidget);
        expect(find.text('Mayor'), findsOneWidget);
        expect(find.text('gastown.mayor'), findsOneWidget);
        expect(find.text('Boundaries'), findsNothing);

        // Empty objective: validation, nothing sent.
        await tester.tap(key('team-start-run-send'));
        await tester.pumpAndSettle();
        expect(find.text('Write an objective first.'), findsOneWidget);
        expect(gateway.calls, isEmpty);

        await tester.enterText(
          key('team-start-run-objective'),
          'Ship offline-first sessions with conflict resolution',
        );
        await tester.tap(key('team-start-run-supervision-autonomous'));
        await tester.pump();
        await tester.tap(key('team-start-run-send'));
        await tester.pumpAndSettle();

        expect(gateway.calls, hasLength(1));
        final call = gateway.calls.single;
        expect(call.verb, 'message');
        expect(call.target, 'gastown.mayor');
        final text = call.arg! as String;
        expect(text, startsWith(teamPlanningMarker));
        expect(
          text,
          contains(
            'Objective: Ship offline-first sessions with conflict resolution',
          ),
        );
        expect(text, contains('Supervision: Autonomous'));
        expect(text, contains('inside the host boundaries'));
        expect(text, isNot(contains('Project:')));

        // The home shows the pending card with the planner's output a tap
        // away.
        expect(key('team-start-run-sheet'), findsNothing);
        expect(find.text('Planning… (Mayor)'), findsOneWidget);
        expect(
          find.text('Ship offline-first sessions with conflict resolution'),
          findsOneWidget,
        );
        await tester.tap(key('team-planning-output'));
        await tester.pumpAndSettle();
        expect(find.byType(AgentOutputScreen), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        // A run carrying the objective appears: the card resolves.
        gateway.runList = [
          run(),
          run(
            id: 'oc-new',
            title: 'Ship offline-first sessions with conflict resolution',
            state: RunState.planning,
            startedAt: clock,
          ),
        ];
        await controller.refresh();
        await settle(tester);
        expect(find.text('Planning… (Mayor)'), findsNothing);
        expect(key('team-planning-key-1'), findsNothing);
        expect(
          find.text('Ship offline-first sessions with conflict resolution'),
          findsOneWidget,
        );
        await drain(tester);
      },
    );

    testWidgets('a chosen project is named in the message', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot();
      await pumpHome(tester, controller);
      await tester.tap(key('team-home-start-run'));
      await tester.pumpAndSettle();
      await tester.enterText(key('team-start-run-objective'), 'Add dark mode');
      await tester.tap(key('team-start-run-project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ocproof').last);
      await tester.pumpAndSettle();
      await tester.tap(key('team-start-run-send'));
      await tester.pumpAndSettle();
      final text = gateway.calls.single.arg! as String;
      expect(text, contains('Project: ocproof'));
      expect(text, contains('Supervision: Balanced'));
      await drain(tester);
    });

    testWidgets('a suspended Mayor: host-off copy, nothing sent', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot(
        configure: (g) => g.agentList = [fox(), mayor(suspended: true)],
      );
      await pumpHome(tester, controller);
      await tester.tap(key('team-home-start-run'));
      await tester.pumpAndSettle();
      expect(key('team-start-run-planner-off'), findsOneWidget);
      expect(
        find.text('The planner (Mayor) is off on this host'),
        findsOneWidget,
      );
      expect(key('team-start-run-host-guide'), findsOneWidget);
      expect(key('team-start-run-send'), findsNothing);
      expect(key('team-start-run-objective'), findsNothing);
      expect(gateway.calls, isEmpty);
    });

    testWidgets('no Mayor listed: the missing copy', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot(
        configure: (g) => g.agentList = [fox()],
      );
      await pumpHome(tester, controller);
      await tester.tap(key('team-home-start-run'));
      await tester.pumpAndSettle();
      expect(key('team-start-run-planner-missing'), findsOneWidget);
      expect(gateway.calls, isEmpty);
    });

    testWidgets('a Mayor without a session is woken before the message', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot(
        configure: (g) => g.agentList = [fox(), mayor(session: false)],
      );
      await pumpHome(tester, controller);
      await tester.tap(key('team-home-start-run'));
      await tester.pumpAndSettle();
      await tester.enterText(key('team-start-run-objective'), 'Add dark mode');
      await tester.tap(key('team-start-run-send'));
      await tester.pumpAndSettle();
      expect(gateway.calls.map((c) => c.verb), ['controlAgent', 'message']);
      expect(gateway.calls.first.arg, AgentControlAction.start);
      expect(gateway.calls.first.target, 'gastown.mayor');
      await drain(tester);
    });

    testWidgets('after 30 minutes: Still planning; Dismiss hides it', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, _) = await boot(timeout: const Duration(seconds: 30));
      await pumpHome(tester, controller);
      await tester.tap(key('team-home-start-run'));
      await tester.pumpAndSettle();
      await tester.enterText(key('team-start-run-objective'), 'Add dark mode');
      await tester.tap(key('team-start-run-send'));
      await tester.pumpAndSettle();
      expect(find.text('Planning… (Mayor)'), findsOneWidget);

      clock = clock.add(const Duration(minutes: 31));
      await pumpHome(tester, controller);
      expect(
        find.text('Still planning — check the planner\'s output'),
        findsOneWidget,
      );
      await tester.tap(key('team-planning-dismiss'));
      await settle(tester);
      expect(key('team-planning-key-1'), findsNothing);
      expect(controller.isPlanningDismissed('key-1'), isTrue);
      await drain(tester);
    });

    testWidgets('a refused objective says why', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, _) = await boot(
        configure: (g) => g.answer = (call) async =>
            MutationReceipt.rejected(call.requestId, 'identity not allowed'),
      );
      await pumpHome(tester, controller);
      await tester.tap(key('team-home-start-run'));
      await tester.pumpAndSettle();
      await tester.enterText(key('team-start-run-objective'), 'Add dark mode');
      await tester.tap(key('team-start-run-send'));
      await tester.pumpAndSettle();
      expect(
        find.text('The host refused the objective: identity not allowed'),
        findsOneWidget,
      );
    });

    test('the planning message round-trips through its record', () {
      final text = composeTeamPlanningMessage(
        objective: '  Add dark mode  ',
        supervision: TeamSupervision.high,
        projectName: 'ocproof',
      );
      final record = MutationRecord(
        key: 'k',
        request: MutationRequest.message('gastown.mayor', text),
        createdAt: clock,
        status: MutationStatus.confirmed,
      );
      final parsed = TeamPlanningRequest.parse(record);
      expect(parsed?.objective, 'Add dark mode');
      expect(parsed?.supervision, TeamSupervision.high);
      expect(parsed?.projectName, 'ocproof');
      expect(
        TeamPlanningRequest.parse(
          MutationRecord(
            key: 'k2',
            request: MutationRequest.message('fox', 'please continue'),
            createdAt: clock,
            status: MutationStatus.sent,
          ),
        ),
        isNull,
      );
      // A run that started well before the request is not its run.
      expect(
        teamPlanningRunMatches(
          run(
            title: 'Add dark mode',
            startedAt: clock.subtract(const Duration(hours: 2)),
          ),
          record,
          'Add dark mode',
        ),
        isFalse,
      );
      expect(
        teamPlanningRunMatches(
          run(title: 'ADD DARK MODE to the app', startedAt: clock),
          record,
          'Add dark mode',
        ),
        isTrue,
      );
      expect(
        teamPlanningRunMatches(
          OrchestrationRun(
            id: 'r',
            title: 'unrelated',
            state: RunState.planning,
            raw: const {
              'metadata': {'request_id': 'k'},
            },
          ),
          record,
          'Add dark mode',
        ),
        isTrue,
      );
    });
  });

  group('layout', () {
    for (final (direction, locale) in [
      (TextDirection.ltr, const Locale('en')),
      (TextDirection.rtl, const Locale('ar')),
    ]) {
      testWidgets(
        'agent controls and the start sheet at 320dp × 2.5x ${direction.name}',
        (tester) async {
          await size(tester, const Size(320, 640));
          final (controller, _) = await boot();
          await pumpAgent(
            tester,
            controller,
            locale: locale,
            direction: direction,
            scale: 2.5,
          );
          await scrollToControls(tester);
          expect(key('team-agent-control-nudge'), findsOneWidget);
          expect(tester.takeException(), isNull);
          // Buttons are at least 48dp tall.
          final nudge = tester.getSize(key('team-agent-control-nudge'));
          expect(nudge.height, greaterThanOrEqualTo(48));
          await tester.tap(key('team-agent-control-message'));
          await tester.pumpAndSettle();
          expect(key('team-agent-message-sheet'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(160, 10));
          await tester.pumpAndSettle();

          await tester.pumpWidget(
            app(
              TeamHomeScreen(controller: controller, now: () => clock),
              locale: locale,
              direction: direction,
              scale: 2.5,
            ),
          );
          await settle(tester);
          await tester.tap(key('team-home-start-run'));
          await tester.pumpAndSettle();
          expect(key('team-start-run-sheet'), findsOneWidget);
          await tester.scrollUntilVisible(
            key('team-start-run-send'),
            200,
            scrollable: find
                .descendant(
                  of: key('team-start-run-sheet'),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pump();
          expect(key('team-start-run-send'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (direction == TextDirection.rtl) {
            expect(
              tester.widget<Text>(find.text('gastown.mayor')).textDirection,
              TextDirection.ltr,
            );
          }
        },
      );
    }
  });
}
