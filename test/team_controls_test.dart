// TEAM-204: agent controls, run controls and Start a run.
//
// Controls are absent (not disabled) without the `control*` capabilities
// and present with `gascityFront`; Nudge is one tap with a receipt chip
// that follows the record (Sent → Confirmed / Unconfirmed); Stop, Restart
// and Cancel run are two-step (the first tap opens the confirmation, the
// second sends, backing out sends nothing); messaging the worker is its
// conversation's composer (slice-P3.6), which sends the text;
// Manual reassign is absent (the dispatcher owns it); Start a run sends the
// objective and the supervision line to the Mayor, shows "Planning…
// (Mayor)" on the home, resolves when a run carrying the objective
// appears, and a suspended Mayor opens "Team can't take tasks" with Wake
// the planner, without sending.
// TEAM-306: on a host that creates work (the phone's loopback) a suspended
// Mayor shows the direct task form instead, which creates one bead and
// slings it at the project's polecat pool; a refused create stays on the
// sheet and says why; a front host keeps the host-off copy.
// Layout: 320dp × 2.5x, LTR and RTL, for the agent controls and the sheet.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/team_dispatch.dart';
import 'package:opencode_mobile/state/team_planning.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/team/agent_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:opencode_mobile/ui/screens/team_conversation/team_conversation.dart'
    show TeamConversationScreen, TeamWatchLiveScreen;
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

  @override
  Future<MutationReceipt> createWork({
    required String title,
    String? description,
    String? projectId,
    required String requestId,
  }) => _call(_Call('createWork', title, requestId, arg: projectId));
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

  /// Controls moved into the top bar in screen-team-1 (2026-09-27).
  Future<void> openMore(WidgetTester tester) async {
    await tester.tap(key('team-agent-more'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder target) async {
    // Let a newly focused field finish its caret reveal before scrolling
    // to the next action; otherwise it scrolls back after ensureVisible.
    await tester.pumpAndSettle();
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
    await tester.tap(target);
  }

  /// The task's conversation, where the run page's controls moved.
  Widget conversation(OrchestrationController controller, String runId) =>
      TeamConversationScreen(
        key: ValueKey('conversation-$runId'),
        team: controller,
        runId: runId,
        now: () => clock,
      );

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
      // Only the way to its work (its conversation) remains.
      expect(key('team-agent-control-message'), findsNothing);
      expect(key('team-agent-control-nudge'), findsNothing);
      expect(key('team-agent-control-pause'), findsNothing);
      expect(key('team-agent-open-conversation'), findsOneWidget);
      expect(key('team-agent-open-output'), findsNothing);
      expect(find.text('Open session'), findsNothing);

      await tester.pumpWidget(
        app(TeamHomeScreen(controller: controller, now: () => clock)),
      );
      await settle(tester);
      expect(key('team-home-start-run'), findsNothing);

      // The task's conversation (RunScreen retired, P3.5): its menu holds
      // Task details, and a read-only host adds no Stop task.
      await tester.pumpWidget(app(conversation(controller, 'oc-xru')));
      await settle(tester);
      await tester.tap(key('team-conversation-menu'));
      await tester.pumpAndSettle();
      expect(key('team-conversation-details'), findsOneWidget);
      expect(key('team-conversation-stop'), findsNothing);
    });

    testWidgets('front host: every control, never Open session', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, _) = await boot();
      await pumpAgent(tester, controller);
      await openMore(tester);
      // Messaging is the conversation's composer, not a control here.
      expect(key('team-agent-control-message'), findsNothing);
      expect(key('team-agent-open-conversation'), findsOneWidget);
      for (final id in ['nudge', 'pause', 'stop', 'restart']) {
        expect(key('team-agent-control-$id'), findsOneWidget, reason: id);
      }
      expect(key('team-agent-control-resume'), findsNothing);
      expect(find.text('Open session'), findsNothing);
      expect(find.text('Open worktree'), findsNothing);
      expect(key('team-agent-control-reassign'), findsNothing);
      expect(find.text('Reassign work…'), findsNothing);
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
      // Messaging lives in the conversation; the page offers it.
      expect(key('team-agent-open-conversation'), findsOneWidget);
      expect(key('team-agent-control-message'), findsNothing);
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
      expect(key('team-agent-control-resume'), findsOneWidget);
      expect(key('team-agent-control-pause'), findsNothing);
      await openMore(tester);
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
      await openMore(tester);
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
      expect(find.textContaining('Nudge · Sending…'), findsOneWidget);

      gateway.push(
        const RequestResult(requestId: 'corr-key-1', ok: true, seq: 10),
      );
      await settle(tester);
      expect(find.textContaining('Nudge · Confirmed'), findsOneWidget);
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
      await openMore(tester);
      await tester.tap(key('team-agent-control-nudge'));
      await settle(tester);
      expect(find.textContaining('Nudge · Sending…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      await settle(tester);
      expect(find.textContaining('Not confirmed yet'), findsOneWidget);
      expect(key('team-agent-receipt-retry'), findsOneWidget);
      expect(gateway.calls, hasLength(1));
    });

    testWidgets('the host refuses: Not accepted with the reason', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot(
        configure: (g) =>
            g.answer = (call) async =>
                MutationReceipt.rejected(call.requestId, 'session is gone'),
      );
      await pumpAgent(tester, controller);
      await openMore(tester);
      await tester.tap(key('team-agent-control-pause'));
      await settle(tester);
      expect(gateway.calls.single.arg, AgentControlAction.pause);
      // The one KitReceipt says the host's reason in its refusal words.
      expect(
        find.textContaining('Not accepted', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('session is gone'), findsOneWidget);
      expect(key('team-agent-pause-undo'), findsNothing);
    });
    testWidgets('an unconfirmed pause never claims the agent paused', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot(
        configure: (g) => g.answer = (call) async => MutationReceipt(
          id: call.requestId,
          status: MutationReceiptStatus.pending,
          retryable: true,
        ),
      );
      await pumpAgent(tester, controller);
      await openMore(tester);
      await tester.tap(key('team-agent-control-pause'));
      await settle(tester);
      expect(gateway.calls, hasLength(1));
      expect(gateway.calls.single.verb, 'controlAgent');
      expect(gateway.calls.single.target, 'fox');
      expect(gateway.calls.single.arg, AgentControlAction.pause);
      expect(
        controller
            .latestMutation(kind: MutationKind.controlAgent, targetId: 'fox')
            ?.status,
        MutationStatus.unconfirmed,
      );
      expect(find.textContaining('Not confirmed yet'), findsOneWidget);
      expect(key('team-agent-receipt-retry'), findsOneWidget);
      expect(key('team-agent-pause-undo'), findsNothing);
      expect(find.text('Paused fox'), findsNothing);
      await drain(tester);
      expect(
        gateway.calls,
        hasLength(1),
        reason: 'never automatically retried',
      );
    });
  });

  group('two-step', () {
    testWidgets('Stop: first tap confirms, second sends', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot();
      await pumpAgent(tester, controller);
      await openMore(tester);
      await tester.tap(key('team-agent-control-stop'));
      await tester.pumpAndSettle();
      expect(key('team-agent-stop-confirm'), findsOneWidget);
      expect(find.text('Stop Worker · fox?'), findsOneWidget);
      expect(gateway.calls, isEmpty);
      await tester.tap(key('team-agent-stop-confirm-action'));
      await tester.pumpAndSettle();
      expect(gateway.calls.single.arg, AgentControlAction.stop);
      expect(find.textContaining('Stop · Sending…'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('Stop: backing out sends nothing', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot();
      await pumpAgent(tester, controller);
      await openMore(tester);
      await tester.tap(key('team-agent-control-stop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep running'));
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
      await openMore(tester);
      await tester.tap(key('team-agent-control-restart'));
      await tester.pumpAndSettle();
      expect(find.text('Restart Worker · fox?'), findsOneWidget);
      expect(gateway.calls, isEmpty);
      await tester.tap(key('team-agent-restart-confirm-action'));
      await tester.pumpAndSettle();
      expect(gateway.calls.single.arg, AgentControlAction.restart);
      expect(find.textContaining('Restart · Sending…'), findsOneWidget);
      await drain(tester);
    });

    // RunScreen's Cancel run / Close batch is retired (P3.5): the task's
    // conversation owns Stop task, confirmed, with its receipt.
    testWidgets('Stop task: menu → confirmation → cancelRun', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot();
      await tester.pumpWidget(app(conversation(controller, 'oc-xru')));
      await settle(tester);
      await tester.tap(key('team-conversation-menu'));
      await tester.pumpAndSettle();
      await tester.tap(key('team-conversation-stop'));
      await tester.pumpAndSettle();
      expect(key('team-conversation-stop-confirm'), findsOneWidget);
      expect(gateway.calls, isEmpty);
      await tester.tap(key('team-conversation-stop-confirm-action'));
      await tester.pumpAndSettle();
      expect(gateway.calls.single.verb, 'cancelRun');
      expect(gateway.calls.single.target, 'oc-xru');
      expect(key('team-conversation-stop-receipt'), findsOneWidget);
      expect(find.textContaining('Stop task · Sending…'), findsOneWidget);
      await drain(tester);
    });

    testWidgets('Stop task: backing out sends nothing', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot();
      await tester.pumpWidget(app(conversation(controller, 'oc-xru')));
      await settle(tester);
      await tester.tap(key('team-conversation-menu'));
      await tester.pumpAndSettle();
      await tester.tap(key('team-conversation-stop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep running'));
      await tester.pumpAndSettle();
      expect(gateway.calls, isEmpty);
      expect(key('team-conversation-stop-receipt'), findsNothing);
    });

    testWidgets('a batch offers Stop task; a finished task offers nothing', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, _) = await boot(
        configure: (g) => g.runList = [
          run(kind: RunKind.batch),
          run(id: 'oc-done', state: RunState.completed),
        ],
      );
      await tester.pumpWidget(app(conversation(controller, 'oc-xru')));
      await settle(tester);
      await tester.tap(key('team-conversation-menu'));
      await tester.pumpAndSettle();
      expect(key('team-conversation-stop'), findsOneWidget);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();

      await tester.pumpWidget(app(conversation(controller, 'oc-done')));
      await settle(tester);
      // The menu holds Refresh and Task details only: nothing to stop.
      await tester.tap(key('team-conversation-menu'));
      await tester.pumpAndSettle();
      expect(key('team-conversation-details'), findsOneWidget);
      expect(key('team-conversation-stop'), findsNothing);
    });
  });

  group('message and reassign', () {
    testWidgets('Message: the conversation composer sends the text', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot();
      await tester.pumpWidget(
        app(TeamWatchLiveScreen(team: controller, agentId: 'fox')),
      );
      await settle(tester);
      // The composer addresses the worker; empty text cannot be sent.
      expect(key('chat-watching-composer'), findsOneWidget);
      expect(find.text('Message Worker…'), findsWidgets);
      await tester.tap(key('chat-watching-message-send'));
      await tester.pump();
      expect(gateway.calls, isEmpty);
      await tester.enterText(
        key('chat-watching-message-field'),
        'Use the offline queue for the tests',
      );
      await tester.pump();
      await tester.tap(key('chat-watching-message-send'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(gateway.calls.single.verb, 'message');
      expect(gateway.calls.single.target, 'fox');
      expect(gateway.calls.single.arg, 'Use the offline queue for the tests');
      // Taken: the field is cleared and the receipt is above the composer.
      expect(key('chat-watching-message-receipt'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: key('chat-watching-message-field'),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await drain(tester);
    });

    for (final readyWork in [true, false]) {
      testWidgets('manual reassign is absent with ready work: $readyWork', (
        tester,
      ) async {
        await size(tester, const Size(400, 900));
        final (controller, gateway) = await boot(
          configure: readyWork
              ? null
              : (g) => g.workList = const [
                  WorkItem(
                    id: 'w2',
                    title: 'Sync engine',
                    state: WorkState.working,
                  ),
                ],
        );
        await pumpAgent(tester, controller);
        await openMore(tester);
        // screen-team-1 removed manual reassignment: the dispatcher owns
        // routing. The menu must not offer a dead or hidden assign path.
        expect(key('team-agent-control-reassign'), findsNothing);
        expect(find.text('Reassign work…'), findsNothing);
        expect(key('team-agent-reassign-sheet'), findsNothing);
        expect(gateway.calls, isEmpty);
      });
    }
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

    testWidgets('an empty Runs list teaches and offers Start a run', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot(
        configure: (g) => g.runList = const [],
      );
      await pumpHome(tester, controller);
      expect(key('team-home-runs-empty'), findsOneWidget);
      expect(find.text('No recent tasks'), findsOneWidget);
      expect(
        find.text(
          'Say what you need, and the team splits it into steps and shows '
          'its progress here.',
        ),
        findsOneWidget,
      );
      expect(find.text('Start tasks on the computer for now.'), findsNothing);
      // Design standard §2: one primary per screen. The empty state teaches;
      // Start a run is the button pinned below the list, not a second one
      // inside the empty state.
      expect(
        find.descendant(
          of: key('team-home-runs-empty'),
          matching: find.text('Give the team a task'),
        ),
        findsNothing,
      );
      await tester.tap(key('team-home-start-run'));
      await tester.pumpAndSettle();
      expect(key('team-start-run-sheet'), findsOneWidget);
      expect(gateway.calls, isEmpty);
    });

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
        expect(find.text('Send to the Mayor'), findsOneWidget);
        expect(find.text('gastown.mayor'), findsNothing);
        await tapVisible(tester, key('team-start-run-technical'));
        await tester.pumpAndSettle();
        expect(find.text('gastown.mayor'), findsOneWidget);
        expect(find.text('Boundaries'), findsNothing);

        // Empty objective: validation, nothing sent.
        await tapVisible(tester, key('team-start-run-send'));
        await tester.pumpAndSettle();
        expect(find.text('Write an objective first.'), findsOneWidget);
        expect(gateway.calls, isEmpty);

        await tester.enterText(
          key('team-start-run-objective'),
          'Ship offline-first sessions with conflict resolution',
        );
        await tapVisible(tester, key('team-start-run-supervision-autonomous'));
        await tester.pump();
        await tapVisible(tester, key('team-start-run-send'));
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

        // The task's conversation opens (P0.3); back on the home, the task
        // is a row of the one list until the planner lists it
        // (slice-P5.1: no planning card), and the row opens the task's
        // conversation, whose Why leads to the planner.
        expect(key('team-start-run-sheet'), findsNothing);
        expect(find.byType(TeamConversationScreen), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(key('team-home-planning-key-1'), findsOneWidget);
        expect(
          find.descendant(
            of: key('team-home-planning-key-1'),
            matching: find.textContaining(
              'Waiting for a plan',
              findRichText: true,
            ),
          ),
          findsWidgets,
        );
        expect(
          find.text('Ship offline-first sessions with conflict resolution'),
          findsOneWidget,
        );
        await tester.tap(key('team-home-planning-key-1'));
        await tester.pumpAndSettle();
        expect(find.byType(TeamConversationScreen), findsOneWidget);
        // Eight seconds with no plan: the line says why, and its Why
        // unfolds the ways out in place. The page reads the pinned clock,
        // so the clock moves with the pump.
        clock = clock.add(const Duration(seconds: 9));
        await tester.pump(const Duration(seconds: 9));
        await tester.pumpAndSettle();
        await tester.tap(key('team-conversation-now-why'));
        await tester.pumpAndSettle();
        await tester.tap(key('team-conversation-now-watch'));
        await tester.pumpAndSettle();
        // The planner's conversation, from the team's live output.
        expect(find.byType(TeamWatchLiveScreen), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
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
        expect(key('team-home-planning-key-1'), findsNothing);
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
      await tapVisible(tester, key('team-start-run-project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ocproof').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, key('team-start-run-send'));
      await tester.pumpAndSettle();
      final text = gateway.calls.single.arg! as String;
      expect(text, contains('Project: ocproof'));
      // The server's level from What runs by itself: High until chosen
      // (P6.1, personas-verticals.md §3).
      expect(text, contains('Supervision: High'));
      await drain(tester);
    });

    testWidgets('a suspended Mayor: the team can\'t take tasks, nothing sent', (
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
      // slice-close-team: plain title and words, and a way on.
      expect(find.text("Team can't take tasks"), findsOneWidget);
      expect(find.text('The planner is switched off'), findsOneWidget);
      expect(key('team-start-run-wake'), findsOneWidget);
      expect(key('team-start-run-host-guide'), findsOneWidget);
      expect(key('team-start-run-send'), findsNothing);
      expect(key('team-start-run-objective'), findsNothing);
      // A front host has no create route: no direct form (TEAM-306).
      expect(controller.capabilities.controlCreateWork, isFalse);
      expect(key('team-start-run-direct'), findsNothing);
      expect(key('team-start-run-direct-send'), findsNothing);
      expect(gateway.calls, isEmpty);
    });

    MutationReceipt created(_Call call) => MutationReceipt(
      id: call.requestId,
      status: MutationReceiptStatus.accepted,
      raw: {'id': 'fx-new-1', 'status': 'open', 'title': call.target},
      upstreamStatus: 201,
    );

    MutationReceipt slung(_Call call) => MutationReceipt(
      id: call.requestId,
      status: MutationReceiptStatus.accepted,
      correlationId: 'corr-${call.requestId}',
      upstreamStatus: 202,
    );

    testWidgets(
      'TEAM-306: a suspended Mayor on the phone host shows the direct task '
      'form; Send creates the work and slings it at the project pool',
      (tester) async {
        await size(tester, const Size(400, 900));
        final (controller, gateway) = await boot(
          capabilities: OrchestrationCapabilities.gascityLoopback,
          configure: (g) {
            g.agentList = [fox(), mayor(suspended: true)];
            g.answer = (call) async =>
                call.verb == 'createWork' ? created(call) : slung(call);
          },
        );
        await pumpHome(tester, controller);
        await tester.tap(key('team-home-start-run'));
        await tester.pumpAndSettle();
        expect(key('team-start-run-direct'), findsOneWidget);
        expect(key('team-start-run-planner-off'), findsNothing);
        expect(key('team-start-run-objective'), findsNothing);
        expect(
          find.text(
            'The planner is off on this host. Give one task straight to '
            "the project's agent.",
          ),
          findsOneWidget,
        );
        expect(key('team-start-run-direct-project'), findsOneWidget);
        expect(find.text('ocproof'), findsOneWidget);
        expect(find.text('Send to an agent'), findsOneWidget);
        expect(key('team-start-run-host-guide'), findsOneWidget);

        // Empty title: validation, nothing sent.
        await tester.tap(key('team-start-run-direct-send'));
        await tester.pumpAndSettle();
        expect(find.text('Write a task first.'), findsOneWidget);
        expect(gateway.calls, isEmpty);

        await tester.enterText(
          key('team-start-run-direct-title'),
          'Add a docstring to add() in calc.py',
        );
        await tester.enterText(
          key('team-start-run-direct-details'),
          'One line, nothing else.',
        );
        await tester.tap(key('team-start-run-direct-send'));
        await tester.pumpAndSettle();

        expect(gateway.calls.map((c) => c.verb), ['createWork', 'assign']);
        expect(gateway.calls[0].target, 'Add a docstring to add() in calc.py');
        expect(gateway.calls[0].arg, 'ocproof');
        expect(gateway.calls[1].target, 'fx-new-1');
        expect(gateway.calls[1].arg, 'ocproof/gastown.polecat');

        // The sheet closed on the task's own conversation (P0.3).
        expect(key('team-start-run-sheet'), findsNothing);
        expect(find.byType(TeamConversationScreen), findsOneWidget);
        expect(
          find.descendant(
            of: key('team-conversation-title'),
            matching: find.text('Add a docstring to add() in calc.py'),
          ),
          findsOneWidget,
        );
        final record = controller.latestMutation(
          kind: MutationKind.createWork,
        )!;
        expect(record.status, MutationStatus.confirmed);
        expect(record.receipt?.createdId, 'fx-new-1');
        expect(record.request.text, 'One line, nothing else.');
        expect(record.request.projectId, 'ocproof');
        expect(
          controller.latestMutation(kind: MutationKind.assign)?.targetId,
          'fx-new-1',
        );
        await drain(tester);
      },
    );

    testWidgets('TEAM-306: a refused direct task stays on the sheet and says '
        'why; nothing is slung', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot(
        capabilities: OrchestrationCapabilities.gascityLoopback,
        configure: (g) {
          g.agentList = [fox(), mayor(suspended: true)];
          g.answer = (call) async =>
              MutationReceipt.rejected(call.requestId, 'rig ocproof unknown');
        },
      );
      await pumpHome(tester, controller);
      await tester.tap(key('team-home-start-run'));
      await tester.pumpAndSettle();
      await tester.enterText(key('team-start-run-direct-title'), 'Add tests');
      await tester.tap(key('team-start-run-direct-send'));
      await tester.pumpAndSettle();
      expect(gateway.calls.map((c) => c.verb), ['createWork']);
      expect(key('team-start-run-sheet'), findsOneWidget);
      expect(key('team-start-run-direct-error'), findsOneWidget);
      // Plain words; the host's own words only under Technical details.
      expect(
        find.text('The task wasn’t made. Change it and send it again.'),
        findsOneWidget,
      );
      expect(find.textContaining('rig ocproof unknown'), findsNothing);
      await tapVisible(tester, key('team-start-run-direct-error-details'));
      await tester.pumpAndSettle();
      expect(find.textContaining('rig ocproof unknown'), findsOneWidget);
      expect(
        controller.latestMutation(kind: MutationKind.createWork)?.status,
        MutationStatus.rejected,
      );
      // Nothing was made, so nothing is said on the page behind.
      expect(TeamDispatchAttempts.of(controller).latest, isNull);
    });

    group('P6.3 dispatch stages', () {
      Future<void> openDirect(
        WidgetTester tester,
        OrchestrationController controller,
        String title,
      ) async {
        await pumpHome(tester, controller);
        await tester.tap(key('team-home-start-run'));
        await tester.pumpAndSettle();
        expect(key('team-start-run-direct'), findsOneWidget);
        await tester.enterText(key('team-start-run-direct-title'), title);
        await tester.pump();
      }

      String textOf(WidgetTester tester, String value) {
        final text = tester.widget<Text>(
          find
              .descendant(
                of: key(value),
                matching: find.byType(Text),
                matchRoot: true,
              )
              .first,
        );
        return text.data ?? text.textSpan?.toPlainText() ?? '';
      }

      String stage(WidgetTester tester) =>
          textOf(tester, 'team-start-run-direct-stage-text');

      String homeLine(WidgetTester tester) =>
          textOf(tester, 'team-home-dispatch-text');

      OrchestrationAgent worker({bool running = true}) => OrchestrationAgent(
        id: 'ocproof/polecat-1',
        name: 'polecat-1',
        state: AgentState.working,
        rawState: 'active',
        pool: 'gastown.polecat',
        sessionId: 'bl-new',
        sessionRunning: running,
        currentWorkId: 'fx-new-1',
      );

      testWidgets(
        'the sheet says each stage once the host confirmed it; the home '
        'status line carries it on; one request per step; timing probe',
        (tester) async {
          await size(tester, const Size(412, 915));
          final createGate = Completer<void>();
          final assignGate = Completer<void>();
          final (controller, gateway) = await boot(
            capabilities: OrchestrationCapabilities.gascityLoopback,
            configure: (g) {
              g.agentList = [fox(), mayor(suspended: true)];
              g.answer = (call) async {
                if (call.verb == 'createWork') {
                  await createGate.future;
                  return created(call);
                }
                await assignGate.future;
                return slung(call);
              };
            },
          );
          await openDirect(tester, controller, 'Add a docstring');
          await tester.tap(key('team-start-run-direct-send'));
          await tester.pump();
          expect(stage(tester), 'Creating your task…');
          expect(gateway.calls.map((c) => c.verb), ['createWork']);

          // Timing probe: create receipt -> first visible next stage.
          final watch = Stopwatch()..start();
          createGate.complete();
          await tester.pump();
          watch.stop();
          expect(stage(tester), 'Task created · sending it to the team…');
          debugPrint(
            'P6.3 timing probe: create receipt -> "Task created" visible in '
            '1 frame, ${watch.elapsedMicroseconds} µs test time',
          );
          expect(gateway.calls.map((c) => c.verb), ['createWork', 'assign']);
          expect(gateway.calls[1].target, 'fx-new-1');

          assignGate.complete();
          await tester.pumpAndSettle();
          // The task's conversation opened; back on the page, the line.
          expect(find.byType(TeamConversationScreen), findsOneWidget);
          Navigator.of(
            tester.element(find.byType(TeamConversationScreen)),
          ).pop();
          await tester.pumpAndSettle();
          expect(key('team-home-dispatch-awaitingWorker'), findsOneWidget);
          expect(
            homeLine(tester),
            'Task sent to the team · waiting for a worker',
          );
          expect(
            find.text('Next: a worker starts · usually within 5 min'),
            findsOneWidget,
          );

          // Only a running session on this exact task says more.
          gateway.agentList = [fox(), mayor(suspended: true), worker()];
          await controller.refresh();
          await settle(tester);
          expect(key('team-home-dispatch-workerObserved'), findsOneWidget);
          expect(homeLine(tester), 'A worker started your task');

          // Reopening the page sends nothing again.
          await tester.pumpWidget(const SizedBox());
          await pumpHome(tester, controller);
          expect(key('team-home-dispatch-workerObserved'), findsOneWidget);
          expect(gateway.calls.map((c) => c.verb), ['createWork', 'assign']);
          await tester.tap(find.byKey(const ValueKey('kit-status-dismiss')));
          await settle(tester);
          expect(key('team-home-dispatch-workerObserved'), findsNothing);
          expect(gateway.calls.length, 2);
          await drain(tester);
        },
      );

      testWidgets(
        'the task\'s own conversation Now line follows the same attempt: '
        'nothing claimed before the host answers, then the real stage',
        (tester) async {
          await size(tester, const Size(412, 915));
          final assignGate = Completer<void>();
          final (controller, gateway) = await boot(
            capabilities: OrchestrationCapabilities.gascityLoopback,
            timeout: const Duration(seconds: 5),
            configure: (g) {
              g.agentList = [fox(), mayor(suspended: true)];
              g.answer = (call) async {
                if (call.verb == 'createWork') return created(call);
                await assignGate.future;
                return slung(call);
              };
            },
          );
          String nowText() => textOf(tester, 'team-conversation-now-text');
          await openDirect(tester, controller, 'Add a docstring');
          await tester.tap(key('team-start-run-direct-send'));
          await tester.pump();
          await tester.pump();
          assignGate.complete();
          await tester.pumpAndSettle();
          expect(find.byType(TeamConversationScreen), findsOneWidget);
          expect(nowText(), contains('Waiting for a worker'));

          // Only a running session on this exact task says more.
          gateway.agentList = [fox(), mayor(suspended: true), worker()];
          await controller.refresh();
          await settle(tester);
          expect(nowText(), contains('Starting a worker'));
          expect(gateway.calls.map((c) => c.verb), ['createWork', 'assign']);
          await drain(tester);
        },
      );

      testWidgets(
        'an assignment the host never confirms reads "couldn\'t confirm", '
        'not sent',
        (tester) async {
          await size(tester, const Size(412, 915));
          final (controller, gateway) = await boot(
            capabilities: OrchestrationCapabilities.gascityLoopback,
            timeout: const Duration(seconds: 5),
            configure: (g) {
              g.agentList = [fox(), mayor(suspended: true)];
              g.answer = (call) async =>
                  call.verb == 'createWork' ? created(call) : slung(call);
            },
          );
          await openDirect(tester, controller, 'Add a docstring');
          await tester.tap(key('team-start-run-direct-send'));
          await tester.pumpAndSettle();
          Navigator.of(
            tester.element(find.byType(TeamConversationScreen)),
          ).pop();
          await tester.pumpAndSettle();
          expect(key('team-home-dispatch-awaitingWorker'), findsOneWidget);
          await tester.pump(const Duration(seconds: 6));
          await settle(tester);
          expect(key('team-home-dispatch-dispatchUnconfirmed'), findsOneWidget);
          expect(
            homeLine(tester),
            'Task created · couldn’t confirm it reached the team',
          );
          expect(gateway.calls.map((c) => c.verb), ['createWork', 'assign']);
          await drain(tester);
        },
      );

      testWidgets(
        'a refused assignment keeps the task; the host\'s words only under '
        'Technical details, redacted',
        (tester) async {
          await size(tester, const Size(412, 915));
          const secret = 'sk-ant-api03-abcdefghijklmnopqrstuvwxyz0123456789';
          final (controller, gateway) = await boot(
            capabilities: OrchestrationCapabilities.gascityLoopback,
            configure: (g) {
              g.agentList = [fox(), mayor(suspended: true)];
              g.answer = (call) async => call.verb == 'createWork'
                  ? created(call)
                  : MutationReceipt.rejected(
                      call.requestId,
                      'pool suspended (key $secret)',
                    );
            },
          );
          await openDirect(tester, controller, 'Add a docstring');
          await tester.tap(key('team-start-run-direct-send'));
          await tester.pumpAndSettle();
          // No conversation opens on a task nobody took.
          expect(find.byType(TeamConversationScreen), findsNothing);
          expect(key('team-start-run-sheet'), findsNothing);
          expect(key('team-home-dispatch-assignRefused'), findsOneWidget);
          expect(
            homeLine(tester),
            'Task created, but it could not be sent to the team',
          );
          expect(
            find.text('The task stays on the board, given to no one.'),
            findsOneWidget,
          );
          expect(find.textContaining('pool suspended'), findsNothing);
          expect(gateway.calls.map((c) => c.verb), ['createWork', 'assign']);

          await tester.tap(find.byKey(const ValueKey('kit-status-more')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Technical details').last);
          await tester.pumpAndSettle();
          expect(key('team-home-dispatch-details-sheet'), findsOneWidget);
          expect(find.textContaining('fx-new-1'), findsWidgets);
          expect(find.textContaining('pool suspended'), findsOneWidget);
          expect(find.textContaining(secret), findsNothing);
          expect(gateway.calls.length, 2);
        },
      );

      testWidgets(
        'a create with no task ID opens nothing, keeps the words and sends '
        'nothing more',
        (tester) async {
          await size(tester, const Size(412, 915));
          final (controller, gateway) = await boot(
            capabilities: OrchestrationCapabilities.gascityLoopback,
            timeout: const Duration(seconds: 5),
            configure: (g) {
              g.agentList = [fox(), mayor(suspended: true)];
              g.answer = (call) async => MutationReceipt(
                id: call.requestId,
                status: MutationReceiptStatus.accepted,
                upstreamStatus: 202,
              );
            },
          );
          await openDirect(tester, controller, 'Add a docstring');
          await tester.tap(key('team-start-run-direct-send'));
          await tester.pumpAndSettle();
          expect(find.byType(TeamConversationScreen), findsNothing);
          expect(key('team-start-run-sheet'), findsNothing);
          expect(key('team-home-dispatch-createUnconfirmed'), findsOneWidget);
          expect(
            homeLine(tester),
            'Couldn’t confirm whether the task was created',
          );
          expect(gateway.calls.map((c) => c.verb), ['createWork']);
          // The words wait for a deliberate new send.
          await tester.tap(key('team-home-start-run'));
          await tester.pumpAndSettle();
          expect(find.text('Add a docstring'), findsOneWidget);
          expect(gateway.calls.length, 1);
          await drain(tester);
        },
      );
    });

    testWidgets('TEAM-306: no project listed: the host-off copy, even on '
        'the phone host', (tester) async {
      await size(tester, const Size(400, 900));
      final (controller, gateway) = await boot(
        capabilities: OrchestrationCapabilities.gascityLoopback,
        configure: (g) => g
          ..agentList = [fox(), mayor(suspended: true)]
          ..projectList = const [],
      );
      await pumpHome(tester, controller);
      await tester.tap(key('team-home-start-run'));
      await tester.pumpAndSettle();
      expect(key('team-start-run-planner-off'), findsOneWidget);
      expect(key('team-start-run-direct'), findsNothing);
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
      await tapVisible(tester, key('team-start-run-send'));
      await tester.pumpAndSettle();
      expect(gateway.calls.map((c) => c.verb), ['controlAgent', 'message']);
      expect(gateway.calls.first.arg, AgentControlAction.start);
      expect(gateway.calls.first.target, 'gastown.mayor');
      await drain(tester);
    });

    testWidgets('after 31 minutes: a reason and a way out, never "Still '
        'planning" alone (slice-P5.1)', (tester) async {
      // Tall enough for the whole start sheet and its Send.
      await size(tester, const Size(400, 1400));
      final (controller, _) = await boot(timeout: const Duration(seconds: 30));
      await pumpHome(tester, controller);
      await tester.tap(key('team-home-start-run'));
      await tester.pumpAndSettle();
      await tester.enterText(key('team-start-run-objective'), 'Add dark mode');
      await tapVisible(tester, key('team-start-run-send'));
      await tester.pumpAndSettle();
      expect(find.byType(TeamConversationScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(key('team-home-planning-key-1'), findsOneWidget);

      clock = clock.add(const Duration(minutes: 31));
      await pumpHome(tester, controller);
      expect(
        find.descendant(
          of: key('team-home-planning-key-1'),
          matching: find.textContaining(
            'Waiting for a plan · 31 min',
            findRichText: true,
          ),
        ),
        findsWidgets,
      );
      await tester.tap(key('team-home-planning-key-1'));
      await tester.pumpAndSettle();
      // Already 31 minutes old: the reason shows at once, with no
      // engine word and no "Still planning".
      expect(
        find.textContaining(
          'No plan has been reported yet',
          findRichText: true,
        ),
        findsWidgets,
      );
      expect(find.textContaining('Still planning'), findsNothing);
      await tester.tap(key('team-conversation-now-why'));
      await tester.pumpAndSettle();
      await tester.tap(key('team-conversation-now-dismiss'));
      await tester.pumpAndSettle();
      expect(find.byType(TeamConversationScreen), findsNothing);
      expect(key('team-home-planning-key-1'), findsNothing);
      expect(controller.isPlanningDismissed('key-1'), isTrue);
      await drain(tester);
    });

    testWidgets('a refused objective stays on the sheet and says why', (
      tester,
    ) async {
      await size(tester, const Size(400, 900));
      final (controller, _) = await boot(
        configure: (g) => g.answer = (call) async =>
            MutationReceipt.rejected(call.requestId, 'identity not allowed'),
      );
      await pumpHome(tester, controller);
      await tester.tap(key('team-home-start-run'));
      await tester.pumpAndSettle();
      await tester.enterText(key('team-start-run-objective'), 'Add dark mode');
      await tapVisible(tester, key('team-start-run-send'));
      await tester.pumpAndSettle();
      expect(key('team-start-run-sheet'), findsOneWidget);
      expect(
        find.descendant(
          of: key('team-start-run-refused'),
          matching: find.text(
            'The host refused the objective: identity not allowed',
          ),
        ),
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
          await openMore(tester);
          expect(key('team-agent-control-nudge'), findsOneWidget);
          expect(tester.takeException(), isNull);
          // Buttons are at least 48dp tall.
          final nudge = tester.getSize(key('team-agent-control-nudge'));
          expect(nudge.height, greaterThanOrEqualTo(48));
          await tester.tapAt(Offset.zero);
          await tester.pumpAndSettle();
          expect(key('team-agent-open-conversation'), findsOneWidget);
          expect(key('team-agent-control-message'), findsNothing);

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
            await tapVisible(tester, key('team-start-run-technical'));
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<EditableText>(find.text('gastown.mayor'))
                  .textDirection,
              TextDirection.ltr,
            );
          }
        },
      );
    }
  });
}
