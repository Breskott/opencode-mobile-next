// slice-close-team: the team-area gaps left by the review-board closure
// audit (docs/qa/review-board-closure-2026-09-28/README.md).
//
// - start-run-sheet: a planner that is off with no direct path opens as
//   "Team can't take tasks" in plain words with a way on:
//   Wake the planner where the host takes agent controls (then the task
//   form opens by itself), else Try again and the host guide; a refused
//   wake keeps the host's words under Technical details.
// - team-run-overview-tab / embedded-team-merge-section: a merged task
//   says where it landed with Review changes, and no Merge button.
// - team-run: stage words are outcomes (Planned · Working · In review ·
//   Merged), Merged only once every step is closed.
// - team-agent: a dependency counts only while it is open.
// - embedded-team-receipt-chip / team-home-needs-you-tab: a question row's
//   receipt is a word in its supporting line; the row keeps its chevron.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/agent_screen.dart';
import 'package:opencode_mobile/ui/screens/team/merge_section.dart';
import 'package:opencode_mobile/ui/screens/team/start_run_sheet.dart';
import 'package:opencode_mobile/ui/screens/team/task_details_sheet.dart';
import 'package:opencode_mobile/ui/screens/team/team_needs_you.dart';
import 'package:opencode_mobile/ui/widgets/team_vocabulary.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _clock = DateTime.utc(2026, 9, 28, 12, 30);
const _runId = 'oc-xru';

/// A host over fixed lists; every control recorded and answered by
/// [answer] (accepted by default).
class _Gateway implements OrchestrationGateway, OrchestrationMergeGateway {
  _Gateway(this.capabilities);

  @override
  final OrchestrationCapabilities capabilities;
  final runList = <OrchestrationRun>[];
  final workList = <WorkItem>[];
  final agentList = <OrchestrationAgent>[];
  final gateList = <OrchestrationGate>[];
  final controls = <(String, AgentControlAction)>[];
  MergeReadiness? readiness;
  Future<MutationReceipt> Function(String requestId)? answer;
  final _stream = StreamController<OrchestrationEvent>.broadcast();
  bool _closed = false;

  @override
  OrchestrationHostIdentity? get host => const OrchestrationHostIdentity(
    provider: 'gascity',
    url: 'http://127.0.0.1:8373',
    hostMode: OrchestrationHostMode.computer,
  );

  @override
  bool get isClosed => _closed;

  @override
  Future<void> close() async {
    _closed = true;
    await _stream.close();
  }

  Future<MutationReceipt> _answer(String requestId) =>
      answer?.call(requestId) ??
      Future.value(
        MutationReceipt(
          id: requestId,
          status: MutationReceiptStatus.accepted,
          upstreamStatus: 200,
        ),
      );

  @override
  Future<List<OrchestrationProject>> projects() async => const [];
  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) async => runList;
  @override
  Future<OrchestrationRun?> run(String id) async => null;
  @override
  Future<List<WorkItem>> work({String? projectId}) async => workList;
  @override
  Future<List<WorkItem>> readyWork({String? projectId}) async => const [];
  @override
  Future<WorkItem?> workItem(String id) async => null;
  @override
  Future<List<OrchestrationAgent>> agents() async => agentList;
  @override
  Future<OrchestrationAgent?> agent(String id) async => null;
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
  }) => _stream.stream;
  @override
  Future<MutationReceipt> respond(
    String gateId,
    GateResponse response, {
    required String requestId,
  }) => _answer(requestId);
  @override
  Future<MutationReceipt> message(
    String agentId,
    String text, {
    required String requestId,
  }) => _answer(requestId);
  @override
  Future<MutationReceipt> controlAgent(
    String agentId,
    AgentControlAction action, {
    required String requestId,
  }) {
    controls.add((agentId, action));
    return _answer(requestId);
  }

  @override
  Future<MutationReceipt> cancelRun(
    String runId, {
    required String requestId,
  }) => _answer(requestId);
  @override
  Future<MutationReceipt> assign(
    String workId, {
    required String agentId,
    required String requestId,
  }) => _answer(requestId);
  @override
  Future<MutationReceipt> createWork({
    required String title,
    String? description,
    String? projectId,
    required String requestId,
  }) => _answer(requestId);
  @override
  Future<MergeReadiness?> mergeReadiness(String runId) async => readiness;
  @override
  Future<MutationReceipt> approveMerge(
    String mergeRequestId, {
    required String requestId,
  }) => _answer(requestId);
  @override
  Future<MutationReceipt> merge(String runId, {required String requestId}) =>
      _answer(requestId);
}

OrchestrationAgent _mayor({bool off = true}) => OrchestrationAgent(
  id: 'gastown.mayor',
  name: 'gastown.mayor',
  state: off ? AgentState.stopped : AgentState.idle,
  rawState: off ? 'suspended' : 'idle',
  sessionId: 'bl-8jc',
  raw: {'name': 'gastown.mayor', 'suspended': off},
);

final _wolf = OrchestrationAgent(
  id: 'a-wolf',
  name: 'ocproof/polecat-1',
  state: AgentState.working,
  sessionId: 'bl-5qc',
  currentWorkId: 'oc-w2',
);

OrchestrationRun _run({RunState state = RunState.completed}) =>
    OrchestrationRun(
      id: _runId,
      title: 'Offline-first sessions',
      state: state,
      kind: RunKind.batch,
      stepCount: 2,
      startedAt: _clock.subtract(const Duration(hours: 3)),
      updatedAt: _clock,
    );

WorkItem _step(
  String id,
  WorkState state, {
  List<String> dependsOn = const [],
}) => WorkItem(
  id: id,
  title: id == 'oc-w1' ? 'Storage layer' : 'Sync engine',
  state: state,
  runId: _runId,
  assignee: 'a-wolf',
  dependsOn: dependsOn,
  createdAt: _clock.subtract(const Duration(hours: 3)),
);

MergeReadiness _merged() => MergeReadiness(
  runId: _runId,
  ready: true,
  rig: 'ocproof',
  targetBranch: 'main',
  lines: const [
    MergeReadinessLine(key: 'work', ok: true, detail: '2/2 work items'),
  ],
  files: 3,
  additions: 10,
  deletions: 2,
  changes: const [],
  boundaries: const [],
  mergeRequest: const MergeRequestInfo(id: 'gc-mr-14', title: 'x'),
  branches: const [],
  mergeCommit: '4f9c2a1d07b3e',
);

/// The front's capabilities without agent controls (a host that does not
/// take Wake).
const _frontWithoutAgentControls = OrchestrationCapabilities(
  projects: true,
  runs: true,
  runSteps: true,
  workGraph: true,
  workReady: true,
  agents: true,
  agentOutput: true,
  sessionLink: true,
  gatesInteractions: true,
  gatesBeads: true,
  usage: true,
  eventStream: true,
  eventReplay: true,
  controlRespond: true,
  controlMessage: true,
  controlCancelRun: true,
  controlAssign: true,
  changes: true,
  verification: true,
  mergeReadiness: true,
);

late OrchestrationStore _store;

Future<(OrchestrationController, _Gateway)> _boot({
  OrchestrationCapabilities capabilities =
      OrchestrationCapabilities.gascityFront,
  void Function(_Gateway gateway)? configure,
}) async {
  final gateway = _Gateway(capabilities);
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
      name: 'Workstation',
      baseUrl: 'https://server.example:4096',
      orchestration: config,
    ),
    config: config,
    store: _store,
    gatewayFactory: (_, _) => gateway,
    probe: (_) async => ProbeFound(
      host: gateway.host!,
      front: true,
      identityAllowed: true,
      capabilities: capabilities,
    ),
    now: () => _clock,
  );
  await controller.start();
  return (controller, gateway);
}

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Finder _key(String key) => find.byKey(ValueKey(key));

/// Pumps a page with a button that opens [open], and taps it.
Future<void> _open(
  WidgetTester tester,
  Future<void> Function(BuildContext context) open,
) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              key: const ValueKey('open'),
              onPressed: () => unawaited(open(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(_key('open'));
  // A current stage's mark moves: pump, never settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _drain(WidgetTester tester, OrchestrationController c) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await c.stop();
  c.dispose();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _store = OrchestrationStore(await SharedPreferences.getInstance());
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
  });

  group('start-run-sheet: the planner is off, no direct path', () {
    testWidgets('plain title and words; Wake the planner opens the form', (
      tester,
    ) async {
      final (controller, gateway) = await _boot(
        configure: (g) => g.agentList.addAll([_wolf, _mayor()]),
      );
      await _open(tester, (context) => showStartRunSheet(context, controller));
      expect(find.text("Team can't take tasks"), findsOneWidget);
      expect(find.text('Give the team a task'), findsNothing);
      expect(find.text('The planner is switched off'), findsOneWidget);
      // No engine words.
      expect(find.textContaining('Mayor'), findsNothing);
      expect(find.textContaining('profile'), findsNothing);
      expect(_key('team-start-run-objective'), findsNothing);
      expect(_key('team-start-run-host-guide'), findsOneWidget);

      // The host wakes it; once it lists the planner awake the task form
      // takes the sheet's place, titled for the task.
      gateway.answer = (id) async {
        gateway.agentList
          ..removeWhere((a) => a.id == 'gastown.mayor')
          ..add(_mayor(off: false));
        return MutationReceipt(
          id: id,
          status: MutationReceiptStatus.accepted,
          upstreamStatus: 200,
        );
      };
      await tester.tap(find.text('Wake the planner'));
      await tester.pumpAndSettle();
      expect(gateway.controls, [('gastown.mayor', AgentControlAction.resume)]);
      expect(_key('team-start-run-objective'), findsOneWidget);
      expect(find.text('Give the team a task'), findsOneWidget);
      expect(find.text("Team can't take tasks"), findsNothing);
      await _drain(tester, controller);
    });

    testWidgets('a refused wake: plain words, the host words under details', (
      tester,
    ) async {
      final (controller, gateway) = await _boot(
        configure: (g) => g
          ..agentList.addAll([_wolf, _mayor()])
          ..answer = (id) async =>
              MutationReceipt.rejected(id, 'agent gastown.mayor: EPERM'),
      );
      await _open(tester, (context) => showStartRunSheet(context, controller));
      await tester.tap(find.text('Wake the planner'));
      await tester.pumpAndSettle();
      expect(find.text("Couldn't wake the planner"), findsOne);
      expect(find.textContaining('EPERM'), findsNothing);
      expect(_key('team-start-run-wake-refused-details'), findsOneWidget);
      expect(_key('team-start-run-objective'), findsNothing);
      await _drain(tester, controller);
    });

    testWidgets('without agent controls: Try again and the host guide', (
      tester,
    ) async {
      final (controller, gateway) = await _boot(
        capabilities: _frontWithoutAgentControls,
        configure: (g) => g.agentList.addAll([_wolf, _mayor()]),
      );
      await _open(tester, (context) => showStartRunSheet(context, controller));
      expect(find.text('Wake the planner'), findsNothing);
      expect(find.textContaining("this app can't switch it on"), findsOne);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('The planner is still switched off.'), findsOneWidget);
      expect(gateway.controls, isEmpty);

      // Switched on at the host: the next check moves on to the form.
      gateway.agentList
        ..removeWhere((a) => a.id == 'gastown.mayor')
        ..add(_mayor(off: false));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(_key('team-start-run-objective'), findsOneWidget);
      await _drain(tester, controller);
    });

    testWidgets('no planner listed: plain words, no engine names', (
      tester,
    ) async {
      final (controller, _) = await _boot(
        configure: (g) => g.agentList.add(_wolf),
      );
      await _open(tester, (context) => showStartRunSheet(context, controller));
      expect(find.text("Team can't take tasks"), findsOneWidget);
      expect(find.text('This team has no planner'), findsOneWidget);
      expect(find.textContaining('Gas Town'), findsNothing);
      expect(find.textContaining('Mayor'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
      await _drain(tester, controller);
    });
  });

  testWidgets('a merged task: where it landed, Review changes, no Merge', (
    tester,
  ) async {
    final (controller, _) = await _boot(
      configure: (g) => g
        ..runList.add(_run())
        ..workList.addAll([
          _step('oc-w1', WorkState.completed),
          _step('oc-w2', WorkState.completed),
        ])
        ..readiness = _merged(),
    );
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: ListView(
            children: [
              TeamMergeSection(
                controller: controller,
                run: _run(),
                now: () => _clock,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_key('team-merge-section'), findsOneWidget);
    expect(find.text('Merged into main · 4f9c2a1'), findsOneWidget);
    expect(_key('team-merge-review'), findsOneWidget);
    expect(_key('team-merge-merge'), findsNothing);
    expect(find.text('Merge'), findsNothing);
    expect(find.text('Tests'), findsNothing);
    await _drain(tester, controller);
  });

  group('team-run: stage words are outcomes', () {
    for (final (last, words) in const [
      (WorkState.review, 'Stage 3 of 4: In review'),
      (WorkState.completed, 'Stage 4 of 4: Merged'),
    ]) {
      testWidgets('a completed task whose last step is ${last.name}', (
        tester,
      ) async {
        final (controller, _) = await _boot(
          configure: (g) => g
            ..runList.add(_run())
            ..workList.addAll([
              _step('oc-w1', WorkState.completed),
              _step('oc-w2', last, dependsOn: const ['oc-w1']),
            ])
            ..agentList.add(_wolf),
        );
        await _open(
          tester,
          (context) => showTeamTaskDetails(
            context,
            controller,
            _runId,
            now: () => _clock,
          ),
        );
        expect(find.bySemanticsLabel(words), findsOneWidget);
        for (final word in ['Planned', 'Working', 'In review', 'Merged']) {
          expect(
            find.descendant(
              of: _key('team-task-details-stage'),
              matching: find.text(word),
            ),
            findsOneWidget,
          );
        }
        await _drain(tester, controller);
      });
    }
  });

  group('team-agent: a dependency counts only while open', () {
    for (final (dep, hold) in const [
      (WorkState.completed, 'nothing blocking it'),
      (WorkState.working, 'waiting on one other step'),
    ]) {
      testWidgets('its dependency is ${dep.name}', (tester) async {
        final (controller, _) = await _boot(
          configure: (g) => g
            ..runList.add(_run(state: RunState.working))
            ..workList.addAll([
              _step('oc-w1', dep),
              _step('oc-w2', WorkState.working, dependsOn: const ['oc-w1']),
            ])
            ..agentList.add(_wolf),
        );
        await tester.pumpWidget(
          _app(
            AgentScreen(
              controller: controller,
              agentId: 'a-wolf',
              now: () => _clock,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.textContaining(hold), findsOneWidget);
        await _drain(tester, controller);
      });
    }
  });

  testWidgets('a question row: the receipt is a word, the chevron stays', (
    tester,
  ) async {
    final gate = OrchestrationGate(
      id: 'req-1',
      kind: GateKind.choice,
      rawKind: 'choice',
      title: 'Which storage?',
      runId: _runId,
      createdAt: _clock.subtract(const Duration(minutes: 3)),
    );
    final (controller, _) = await _boot(
      configure: (g) => g
        ..runList.add(_run(state: RunState.blocked))
        ..gateList.add(gate)
        ..answer = (id) async =>
            MutationReceipt(id: id, status: MutationReceiptStatus.pending),
    );
    await controller.answerGate('req-1', const GateResponse.choice('SQLite'));
    var opened = 0;
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: TeamGateRow(
            controller: controller,
            gate: gate,
            now: _clock,
            onTap: () => opened++,
            receiptKey: const ValueKey('row-line'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final line = tester.widget<Text>(_key('row-line')).textSpan!;
    expect(line.toPlainText(), startsWith('Decision · '));
    expect(line.toPlainText(), contains('Not confirmed yet'));
    expect(find.byType(KitReceipt), findsNothing);
    expect(find.byType(KitChevron), findsOneWidget);
    await tester.tap(find.text('Which storage?'));
    expect(opened, 1);
    await _drain(tester, controller);
  });

  test('teamOpenDependencies counts only listed open steps', () {
    final work = [
      _step('oc-w1', WorkState.completed),
      _step('oc-w2', WorkState.working, dependsOn: const ['oc-w1', 'gone']),
    ];
    expect(teamOpenDependencies(work[1], work), isEmpty);
  });
}
