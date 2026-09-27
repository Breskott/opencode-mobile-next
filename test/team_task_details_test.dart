// slice-P3.5: Task details, the sheet behind "Task details" in a team
// task's conversation menu, over the fixture gateway. It holds every fact
// the retired run page (TEAM-109, its Overview, Work, Agents and Timeline
// tabs) showed that the conversation does not: the state word, steps done
// and elapsed time (TEAM-117: timed from the hand-off to merge), the
// four-stage line, the steps as the dependency graph in rows (each opens
// its Work sheet), a formula run's own stages, and one Technical details
// fold with the host's term, ids, raw fields and what the host reported
// about the task (scoped to it, newest first). The Now line, the agents,
// the questions waiting on the person, Stop and its receipt, the merge
// section and Refresh are the conversation's (team_conversation_screen_test,
// slice_p3_5_test).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/dto/dto.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_mappers.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart';
import 'package:opencode_mobile/ui/screens/team/task_details_sheet.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/team_chat_fixture.dart';

Directory _findFixtureRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final candidate = Directory('${dir.path}/tool/qa/gascity_fixture');
    if (candidate.existsSync()) return candidate;
    dir = dir.parent;
  }
  throw StateError(
    'tool/qa/gascity_fixture not found from ${Directory.current}',
  );
}

/// The fixture with per-scope overrides, a read counter and an owned event
/// stream so a test can push events.
class _Gateway implements OrchestrationGateway {
  _Gateway(this.inner);

  final FixtureOrchestrationGateway inner;
  final calls = <String, int>{};
  final stream = StreamController<OrchestrationEvent>.broadcast();
  List<OrchestrationRun>? runsOverride;
  List<WorkItem>? workOverride;
  List<OrchestrationAgent>? agentsOverride;
  List<OrchestrationGate>? gatesOverride;

  /// A host the app can only watch: no `controlRespond`, for instance.
  OrchestrationCapabilities? capabilitiesOverride;

  int count(String name) => calls[name] ?? 0;
  void _hit(String name) => calls[name] = count(name) + 1;

  @override
  OrchestrationCapabilities get capabilities =>
      capabilitiesOverride ?? inner.capabilities;
  @override
  OrchestrationHostIdentity? get host => inner.host;
  @override
  bool get isClosed => inner.isClosed;
  @override
  Future<void> close() async {
    await stream.close();
    await inner.close();
  }

  @override
  Future<List<OrchestrationProject>> projects() => inner.projects();

  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) async {
    _hit('runs');
    return runsOverride ?? await inner.runs(projectId: projectId);
  }

  @override
  Future<OrchestrationRun?> run(String id) => inner.run(id);

  @override
  Future<List<WorkItem>> work({String? projectId}) async =>
      workOverride ?? await inner.work(projectId: projectId);

  @override
  Future<List<WorkItem>> readyWork({String? projectId}) =>
      inner.readyWork(projectId: projectId);

  @override
  Future<WorkItem?> workItem(String id) => inner.workItem(id);

  @override
  Future<List<OrchestrationAgent>> agents() async =>
      agentsOverride ?? await inner.agents();

  @override
  Future<OrchestrationAgent?> agent(String id) => inner.agent(id);

  @override
  Future<List<OrchestrationGate>> gates() async =>
      gatesOverride ?? await inner.gates();

  @override
  Future<OrchestrationUsage?> usage() => inner.usage();

  @override
  Future<List<ActivityEvent>> activity({int? afterSeq, int limit = 100}) =>
      inner.activity(afterSeq: afterSeq, limit: limit);

  @override
  Stream<OrchestrationEvent> events({
    EventCursor resumeFrom = EventCursor.none,
  }) => stream.stream;

  @override
  Future<MutationReceipt> respond(
    String gateId,
    GateResponse response, {
    required String requestId,
  }) => inner.respond(gateId, response, requestId: requestId);

  @override
  Future<MutationReceipt> message(
    String agentId,
    String text, {
    required String requestId,
  }) => inner.message(agentId, text, requestId: requestId);

  @override
  Future<MutationReceipt> controlAgent(
    String agentId,
    AgentControlAction action, {
    required String requestId,
  }) => inner.controlAgent(agentId, action, requestId: requestId);

  @override
  Future<MutationReceipt> cancelRun(
    String runId, {
    required String requestId,
  }) => inner.cancelRun(runId, requestId: requestId);

  @override
  Future<MutationReceipt> assign(
    String workId, {
    required String agentId,
    required String requestId,
  }) => inner.assign(workId, agentId: agentId, requestId: requestId);

  @override
  Future<MutationReceipt> createWork({
    required String title,
    String? description,
    String? projectId,
    required String requestId,
  }) => inner.createWork(
    title: title,
    description: description,
    projectId: projectId,
    requestId: requestId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String fixturePath;
  late OrchestrationStore store;
  late DateTime clock;

  setUp(() async {
    fixturePath = _findFixtureRoot().path;
    SharedPreferences.setMockInitialValues({});
    store = OrchestrationStore(await SharedPreferences.getInstance());
    clock = DateTime.utc(2026, 9, 11, 12, 30);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  Future<(OrchestrationController, _Gateway)> boot({
    bool started = true,
    OrchestrationProbe? probe,
    void Function(_Gateway gateway)? configure,
    OrchestrationHostMode hostMode = OrchestrationHostMode.computer,
  }) async {
    final gateway = _Gateway(
      FixtureOrchestrationGateway(fixturePath: fixturePath, hostMode: hostMode),
    );
    configure?.call(gateway);
    final config = OrchestrationConfig(
      provider: OrchestrationProvider.fixture,
      url: fixturePath,
      city: 'bright-lights',
      hostMode: hostMode,
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
      store: store,
      gatewayFactory: (_, _) => gateway,
      probe: probe,
      now: () => clock,
    );
    addTearDown(controller.dispose);
    if (started) await controller.start();
    return (controller, gateway);
  }

  Widget app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
    theme: AppTheme.dark(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: home,
  );

  Future<void> pumpDetails(
    WidgetTester tester,
    OrchestrationController controller,
    String runId, {
    Size size = const Size(800, 2400),
    Locale locale = const Locale('en'),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: TeamTaskDetails(
              controller: controller,
              runId: runId,
              now: () => clock,
            ),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pump();
  }

  Future<void> push(
    WidgetTester tester,
    _Gateway gateway,
    OrchestrationEvent event,
  ) async {
    gateway.stream.add(event);
    await tester.pump();
    // The controller's refetch debounce.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder).dy;

  Finder key(String name) => find.byKey(ValueKey(name));

  /// Sequence numbers above the fixture's history, so the controller's
  /// timeline takes the event as new.
  int s(int n) => 5000 + n;

  Map<String, Object?> ts(int minutesAgo) => {
    'ts': clock.subtract(Duration(minutes: minutesAgo)).toIso8601String(),
  };

  /// TEAM-117: the fixture convoy over the recorded `oc-loy` as the host
  /// last showed it — pushed and in the refinery's hands, no live agent,
  /// never closed. [updatedAt] is the bead's `updated_at` when given; the
  /// recording itself carries only `created_at`.
  void handedToRefineryShape(_Gateway gateway, {DateTime? updatedAt}) {
    final convoys = GcList<GcConvoy>.fromJson(
      readMap(
        jsonDecode(
          File('$fixturePath/recordings/convoys.json').readAsStringSync(),
        ),
      ),
      GcConvoy.fromJson,
    ).items;
    final bead = GcBead.fromJson({
      ...readMap(
        jsonDecode(
          File(
            '$fixturePath/recordings/bead_handed_to_refinery.json',
          ).readAsStringSync(),
        ),
      ),
      if (updatedAt != null) 'updated_at': updatedAt.toIso8601String(),
    });
    final context = GcWorkContext.from(convoys: convoys);
    final work = mapBeads([bead], context: context);
    gateway
      ..workOverride = work
      ..runsOverride = mapConvoys(convoys, work: work, context: context)
      ..gatesOverride = const [];
  }

  /// A blocked convoy with four work items (one done, one working, one
  /// blocked with the host's reason, one queued), an agent on the blocked
  /// item, two gates on the run (a gate bead and a decision) and one gate
  /// elsewhere; plus a formula run with steps.
  void richShape(_Gateway gateway) {
    gateway
      ..runsOverride = [
        OrchestrationRun(
          id: 'oc-xru',
          title: 'Offline-first sessions',
          state: RunState.blocked,
          rawState: 'open',
          kind: RunKind.batch,
          stepCount: 4,
          completedSteps: 1,
          startedAt: clock.subtract(const Duration(minutes: 34)),
          updatedAt: clock,
          raw: const {
            'id': 'oc-xru',
            'title': 'sling-oc-loy',
            'issue_type': 'convoy',
          },
        ),
        OrchestrationRun(
          id: 'run-ship',
          title: 'Ship the release',
          state: RunState.working,
          rawState: 'active',
          kind: RunKind.formula,
          formula: 'ship',
          startedAt: clock.subtract(const Duration(hours: 2, minutes: 5)),
          raw: const {
            'run_id': 'run-ship',
            'formula': 'ship',
            'steps': [
              {'id': 's1', 'title': 'Requirements', 'status': 'completed'},
              {'id': 's2', 'title': 'Implementation', 'status': 'active'},
              {'id': 's3', 'title': 'Testing', 'status': 'pending'},
            ],
          },
        ),
      ]
      ..workOverride = const [
        WorkItem(
          id: 'w1',
          title: 'Storage layer',
          state: WorkState.completed,
          runId: 'oc-xru',
        ),
        WorkItem(
          id: 'w2',
          title: 'Sync engine',
          state: WorkState.working,
          runId: 'oc-xru',
        ),
        WorkItem(
          id: 'w3',
          title: 'Conflict policy',
          state: WorkState.blocked,
          runId: 'oc-xru',
          isBlocked: true,
          raw: {
            'metadata': {'last_error': 'Tests failed: 2 of 18'},
          },
        ),
        WorkItem(
          id: 'w4',
          title: 'Release notes',
          state: WorkState.queued,
          runId: 'oc-xru',
        ),
        WorkItem(id: 'w9', title: 'Elsewhere', state: WorkState.working),
      ]
      ..agentsOverride = const [
        OrchestrationAgent(
          id: 'wolf',
          name: 'wolf',
          state: AgentState.waiting,
          sessionId: 's-wolf',
          currentWorkId: 'w3',
        ),
        OrchestrationAgent(
          id: 'fox',
          name: 'fox',
          state: AgentState.working,
          sessionId: 's-fox',
          currentWorkId: 'w9',
        ),
      ]
      ..gatesOverride = [
        OrchestrationGate(
          id: 'g-bead',
          kind: GateKind.gateBead,
          title: 'Approve the schema',
          runId: 'oc-xru',
          createdAt: clock.subtract(const Duration(minutes: 1)),
        ),
        OrchestrationGate(
          id: 'g1',
          kind: GateKind.choice,
          title: 'Which persistence strategy?',
          prompt: 'This choice controls how the tests store data.',
          workId: 'w3',
          agentId: 's-wolf',
          choices: const ['SQLite', 'Filesystem'],
          createdAt: clock.subtract(const Duration(minutes: 5)),
        ),
        const OrchestrationGate(
          id: 'g9',
          kind: GateKind.choice,
          title: 'Another run asks',
          workId: 'w9',
        ),
      ];
  }

  /// The `blocked` shape of team_home_test through the real mappers: the
  /// fixture convoy over `oc-loy`, blocked behind an open dependency.
  void blockedShape(_Gateway gateway) {
    final convoys = GcList<GcConvoy>.fromJson(
      readMap(
        jsonDecode(
          File('$fixturePath/recordings/convoys.json').readAsStringSync(),
        ),
      ),
      GcConvoy.fromJson,
    ).items;
    final beads = [
      GcBead.fromJson(const {
        'id': 'oc-loy',
        'title': 'Add subtract function to calc.py',
        'status': 'open',
        'issue_type': 'task',
        'is_blocked': true,
        'dependencies': [
          {'issue_id': 'oc-loy', 'depends_on_id': 'oc-dep', 'type': 'blocks'},
        ],
      }),
      GcBead.fromJson(const {
        'id': 'oc-dep',
        'title': 'Agree the calc.py API',
        'status': 'open',
        'issue_type': 'task',
      }),
      GcBead.fromJson(const {
        'id': 'gc-2',
        'title': 'Write tests for calc.py',
        'status': 'closed',
        'issue_type': 'task',
      }),
    ];
    final context = GcWorkContext.from(convoys: convoys);
    final work = [
      for (final item in mapBeads(beads, context: context))
        WorkItem(
          id: item.id,
          title: item.title,
          state: item.state,
          runId: 'oc-xru',
          isBlocked: item.isBlocked,
          dependsOn: item.dependsOn,
          raw: item.raw,
        ),
    ];
    gateway
      ..workOverride = work
      ..runsOverride = mapConvoys(convoys, work: work, context: context)
      ..gatesOverride = const [];
  }

  /// The one Technical details fold, opened.
  Future<Finder> openTechnical(WidgetTester tester) async {
    final fold = key('team-task-details-technical');
    await tester.ensureVisible(fold);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: fold, matching: find.text('Technical details')),
    );
    await tester.pumpAndSettle();
    return fold;
  }

  group('where the task stands', () {
    testWidgets('the fixture convoy: state, elapsed, stage, its one step, '
        'the Gas City term only in Technical details', (tester) async {
      final handle = tester.ensureSemantics();
      final (controller, _) = await boot();
      await pumpDetails(tester, controller, 'oc-xru');
      expect(key('team-task-details-body'), findsOneWidget);
      // TEAM-115: nobody holds the bead, so it is waiting for a worker; the
      // host's own `sling-` title is in Technical details only.
      expect(
        _textOf(tester, key('team-task-details-state')).data,
        'Waiting for a worker',
      );
      expect(find.text('sling-oc-loy'), findsNothing);
      expect(find.text('Task · convoy', findRichText: true), findsNothing);
      // Created 2026-09-10T18:44:53Z, the clock is 12:30 the next day.
      expect(
        _textOf(tester, key('team-task-details-elapsed')).data,
        '17 h 45 min',
      );
      // One step: no "0 of 1" on the status line; the step is a row.
      expect(key('team-task-details-progress'), findsNothing);
      expect(key('team-task-details-step-oc-loy'), findsOneWidget);
      expect(find.bySemanticsLabel('Stage 1 of 4: Waiting'), findsOneWidget);
      expect(key('team-task-details-stages'), findsNothing);
      final fold = await openTechnical(tester);
      expect(
        find.descendant(
          of: fold,
          matching: find.text('Task · convoy', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fold, matching: find.text('sling-oc-loy')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('TEAM-117: work in the refinery\'s hands is Reviewing, '
        'timed from the hand-off, with nothing working or held up', (
      tester,
    ) async {
      // The phone showed "Working · 20 h 19 min" beside "Working 0 ·
      // Blocked 0" for exactly this bead.
      final handle = tester.ensureSemantics();
      final handedAt = clock.subtract(const Duration(hours: 20, minutes: 19));
      final (controller, _) = await boot(
        configure: (g) => handedToRefineryShape(g, updatedAt: handedAt),
      );
      await pumpDetails(tester, controller, 'oc-xru');
      expect(_textOf(tester, key('team-task-details-state')).data, 'Reviewing');
      expect(
        _textOf(tester, key('team-task-details-elapsed')).data,
        '20 h 19 min since hand-off',
      );
      expect(find.bySemanticsLabel('Stage 3 of 4: Reviewing'), findsOneWidget);
      expect(find.text('Waiting for a worker'), findsNothing);
      final cycle = controller.cycleFor('oc-loy');
      expect(cycle.reachedAt[DispatchStep.handedToMerge], handedAt);
      expect(cycle.stallReason, DispatchStall.mergeWaiting);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('TEAM-117: the recorded bead has no update time: the '
        'hand-off is counted from its creation, steps untimed', (tester) async {
      final (controller, _) = await boot(configure: handedToRefineryShape);
      await pumpDetails(tester, controller, 'oc-xru');
      expect(_textOf(tester, key('team-task-details-state')).data, 'Reviewing');
      // Created 2026-09-10T18:44:45Z, the clock is 12:30 the next day.
      expect(
        _textOf(tester, key('team-task-details-elapsed')).data,
        '17 h 45 min since hand-off',
      );
      final cycle = controller.cycleFor('oc-loy');
      expect(cycle.isDone(DispatchStep.handedToMerge), isTrue);
      expect(cycle.reachedAt[DispatchStep.handedToMerge], isNull);
      expect(cycle.since, isNull);
      expect(cycle.stallReason, DispatchStall.mergeWaiting);
      expect(tester.takeException(), isNull);
    });

    testWidgets('top to bottom: status, stage, steps, then Technical '
        'details', (tester) async {
      final (controller, _) = await boot(configure: richShape);
      await pumpDetails(tester, controller, 'oc-xru');
      const order = [
        'team-task-details-status',
        'team-task-details-stage',
        'team-task-details-steps',
        'team-task-details-technical',
      ];
      for (final name in order) {
        expect(key(name), findsOneWidget, reason: name);
      }
      for (var i = 1; i < order.length; i++) {
        expect(
          top(tester, key(order[i - 1])),
          lessThan(top(tester, key(order[i]))),
          reason: '${order[i - 1]} above ${order[i]}',
        );
      }
      expect(_textOf(tester, key('team-task-details-state')).data, 'Blocked');
      expect(_textOf(tester, key('team-task-details-elapsed')).data, '34 min');
      expect(
        _textOf(tester, key('team-task-details-progress')).data,
        '1 of 4 steps done',
      );
      // What the conversation says is not repeated: no question, no title.
      expect(find.text('Which persistence strategy?'), findsNothing);
      expect(find.text('Offline-first sessions'), findsNothing);
      expect(key('team-task-details-stages'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('steps', () {
    testWidgets('every step of the task is a row with its state; another '
        "task's work is not", (tester) async {
      final (controller, _) = await boot(configure: richShape);
      await pumpDetails(tester, controller, 'oc-xru');
      for (final (id, title) in const [
        ('w1', 'Storage layer'),
        ('w2', 'Sync engine'),
        ('w3', 'Conflict policy'),
        ('w4', 'Release notes'),
      ]) {
        expect(
          find.descendant(
            of: key('team-task-details-step-$id'),
            matching: find.textContaining(title, findRichText: true),
          ),
          findsWidgets,
          reason: id,
        );
      }
      expect(key('team-task-details-step-w9'), findsNothing);
      expect(
        find.descendant(
          of: key('team-task-details-step-w3'),
          matching: find.textContaining('Blocked', findRichText: true),
        ),
        findsWidgets,
      );
    });

    testWidgets('the blocked shape: the step names what it needs', (
      tester,
    ) async {
      final (controller, _) = await boot(configure: blockedShape);
      await pumpDetails(tester, controller, 'oc-xru');
      expect(_textOf(tester, key('team-task-details-state')).data, 'Blocked');
      expect(
        _textOf(tester, key('team-task-details-progress')).data,
        '1 of 3 steps done',
      );
      expect(
        find.descendant(
          of: key('team-task-details-step-oc-loy'),
          matching: find.textContaining(
            'needs Agree the calc.py API',
            findRichText: true,
          ),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a step opens its Work sheet', (tester) async {
      final (controller, _) = await boot(configure: richShape);
      await pumpDetails(tester, controller, 'oc-xru');
      await tester.tap(key('team-task-details-step-w3'));
      await tester.pumpAndSettle();
      expect(key('team-work-sheet'), findsOneWidget);
      expect(
        find.descendant(
          of: key('team-work-sheet'),
          matching: find.text('Conflict policy'),
        ),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a formula run with stages lists them as its steps', (
      tester,
    ) async {
      final (controller, _) = await boot(configure: richShape);
      await pumpDetails(tester, controller, 'run-ship');
      expect(_textOf(tester, key('team-task-details-state')).data, 'Working');
      expect(
        _textOf(tester, key('team-task-details-elapsed')).data,
        '2 h 5 min',
      );
      // It tracks no work: nothing counted on the status line.
      expect(key('team-task-details-progress'), findsNothing);
      expect(key('team-task-details-stages'), findsOneWidget);
      expect(
        find.descendant(
          of: key('team-task-details-stages'),
          matching: find.text('Steps'),
        ),
        findsOneWidget,
      );
      for (final (index, (title, state)) in const [
        ('Requirements', 'Done'),
        ('Implementation', 'Working'),
        ('Testing', 'Planning'),
      ].indexed) {
        final row = key('team-task-details-stage-$index');
        expect(
          find.descendant(of: row, matching: find.text(title)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: row,
            matching: find.text(state, findRichText: true),
          ),
          findsOneWidget,
          reason: title,
        );
      }
      expect(key('team-task-details-steps'), findsNothing);
      // The formula's term and name are in Technical details.
      expect(find.text('Task · formula', findRichText: true), findsNothing);
      final fold = await openTechnical(tester);
      expect(
        find.descendant(
          of: fold,
          matching: find.text('Task · formula', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fold, matching: find.text('ship')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the agents are the conversation\'s, not repeated here', (
      tester,
    ) async {
      final (controller, _) = await boot(configure: richShape);
      await pumpDetails(tester, controller, 'oc-xru');
      expect(find.text('wolf'), findsNothing);
      expect(find.text('fox'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Technical details', () {
    testWidgets('holds the ids, the tracked work and every raw field', (
      tester,
    ) async {
      final (controller, _) = await boot(configure: richShape);
      await pumpDetails(tester, controller, 'oc-xru');
      final fold = await openTechnical(tester);
      expect(
        find.descendant(of: fold, matching: find.text('oc-xru')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fold, matching: find.text('w1, w2, w3, w4')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fold, matching: find.text('convoy')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fold, matching: find.text('issue_type')),
        findsOneWidget,
      );
      // The convoy's own title is here, under "Provider title" (TEAM-115).
      expect(
        find.descendant(of: fold, matching: find.text('Provider title')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: fold, matching: find.text('sling-oc-loy')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets("what the host reported: this task's events, newest first", (
      tester,
    ) async {
      final (controller, gateway) = await boot(configure: richShape);
      await pumpDetails(tester, controller, 'oc-xru');
      expect(key('team-task-details-reported'), findsNothing);

      await push(
        tester,
        gateway,
        BeadChanged(
          beadId: 'w2',
          change: BeadChange.updated,
          seq: s(1),
          raw: ts(9),
        ),
      );
      await push(
        tester,
        gateway,
        SessionChanged(
          sessionId: 's-wolf',
          change: SessionChange.woke,
          seq: s(2),
          raw: ts(8),
        ),
      );
      await push(
        tester,
        gateway,
        GateChanged(gateId: 'g1', seq: s(3), raw: ts(7)),
      );
      // Not this task's: another bead, a controller order, another run.
      await push(
        tester,
        gateway,
        BeadChanged(beadId: 'w9', change: BeadChange.updated, seq: s(4)),
      );
      await push(
        tester,
        gateway,
        ActivityAppended(
          event: ActivityEvent(
            type: 'order.completed',
            seq: s(5),
            subject: 'gate-sweep',
            summary: 'order gate-sweep completed',
            timestamp: clock,
          ),
          seq: s(5),
        ),
      );
      await push(
        tester,
        gateway,
        RunChanged(runId: 'run-ship', state: RunState.working, seq: s(6)),
      );
      await push(
        tester,
        gateway,
        RunChanged(
          runId: 'oc-xru',
          state: RunState.working,
          seq: s(7),
          raw: ts(1),
        ),
      );
      // An activity line naming a tracked bead in its payload counts.
      await push(
        tester,
        gateway,
        ActivityAppended(
          event: ActivityEvent(
            type: 'order.fired',
            seq: s(8),
            subject: 'nudge-on-route',
            summary: 'nudge sent for w3',
            payload: const {'bead_id': 'w3'},
            timestamp: clock,
          ),
          seq: s(8),
        ),
      );

      final fold = await openTechnical(tester);
      expect(
        find.descendant(
          of: fold,
          matching: find.text('What the host reported'),
        ),
        findsOneWidget,
      );
      Finder event(int n) => key('team-task-details-event-${s(n)}');
      for (final seq in [1, 2, 3, 7, 8]) {
        expect(event(seq), findsOneWidget, reason: '$seq');
      }
      for (final seq in [4, 5, 6]) {
        expect(event(seq), findsNothing, reason: '$seq');
      }
      // Newest first.
      final order = [8, 7, 3, 2, 1];
      for (var i = 1; i < order.length; i++) {
        expect(
          top(tester, event(order[i - 1])),
          lessThan(top(tester, event(order[i]))),
        );
      }
      expect(find.text('Sync engine updated'), findsOneWidget);
      expect(find.text('wolf started'), findsOneWidget);
      expect(
        find.text('Needs you: Which persistence strategy?'),
        findsOneWidget,
      );
      expect(find.text('Run is now Working'), findsOneWidget);
      expect(find.text('nudge sent for w3'), findsOneWidget);
      final time =
          MaterialLocalizations.of(
            tester.element(find.byType(TeamTaskDetails)),
          ).formatTimeOfDay(
            TimeOfDay.fromDateTime(
              clock.subtract(const Duration(minutes: 9)).toLocal(),
            ),
            alwaysUse24HourFormat: true,
          );
      expect(find.text(time), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('states and doors', () {
    testWidgets('a task the host no longer lists says so', (tester) async {
      final (controller, _) = await boot();
      await pumpDetails(tester, controller, 'gone');
      expect(key('team-task-details-missing'), findsOneWidget);
      expect(find.text('This task is no longer on the host'), findsOneWidget);
      expect(key('team-task-details-body'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a task that disappears on refresh turns into the state', (
      tester,
    ) async {
      final (controller, gateway) = await boot(configure: richShape);
      await pumpDetails(tester, controller, 'oc-xru');
      expect(key('team-task-details-body'), findsOneWidget);
      gateway.runsOverride = const [];
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(key('team-task-details-missing'), findsOneWidget);
      expect(key('team-task-details-body'), findsNothing);
    });

    // P0.3 and P3.5: the home's row opens the task's conversation, whose
    // menu opens Task details as a sheet (no run page anywhere).
    testWidgets('the home’s run row opens the task, whose menu opens Task '
        'details', (tester) async {
      final (controller, _) = await boot();
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final connection = await teamConnection(
        api: TeamChatApi(const {}),
        repository: TeamChatRepository(const []),
      );
      await tester.pumpWidget(
        teamChatApp(
          connection,
          TeamHomeScreen(controller: controller, now: () => clock),
        ),
      );
      await tester.pump();
      await tester.tap(key('team-home-run-oc-xru'));
      await tester.pumpAndSettle();
      expect(find.byType(TeamConversationScreen), findsOneWidget);
      expect(key('team-run'), findsNothing);
      await tester.tap(key('team-conversation-menu'));
      await tester.pumpAndSettle();
      await tester.tap(key('team-conversation-details'));
      await tester.pumpAndSettle();
      expect(key('team-task-details'), findsOneWidget);
      expect(
        _textOf(tester, key('team-task-details-state')).data,
        'Waiting for a worker',
      );
      final fold = await openTechnical(tester);
      expect(
        find.descendant(
          of: fold,
          matching: find.text('Task · convoy', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('reads in Arabic with the term and ids LTR', (tester) async {
      final ar = lookupAppLocalizations(const Locale('ar'));
      final (controller, _) = await boot(configure: richShape);
      await pumpDetails(
        tester,
        controller,
        'oc-xru',
        locale: const Locale('ar'),
      );
      expect(
        _textOf(tester, key('team-task-details-progress')).data,
        ar.teamUiTaskSteps(1, 4),
      );
      expect(
        Directionality.of(tester.element(key('team-task-details-status'))),
        TextDirection.rtl,
      );
      expect(
        find.text(ar.teamUiRunTermBatch, findRichText: true),
        findsNothing,
      );
      final fold = key('team-task-details-technical');
      await tester.ensureVisible(fold);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: fold,
          matching: find.text(ar.teamUiTechnicalDetails),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: fold,
          matching: find.text(ar.teamUiRunTermBatch, findRichText: true),
        ),
        findsOneWidget,
      );
      final id = key('team-task-details-id');
      expect(id, findsOneWidget);
      expect(Directionality.of(tester.element(id)), TextDirection.ltr);
      expect(tester.takeException(), isNull);
    });
  });
}

Text _textOf(WidgetTester tester, Finder finder) {
  final widget = tester.widget(finder);
  if (widget is Text) return widget;
  return tester.widget<Text>(
    find.descendant(of: finder, matching: find.byType(Text)).first,
  );
}
