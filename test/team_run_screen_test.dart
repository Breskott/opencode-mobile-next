// TEAM-109: the run detail over the fixture gateway. The Overview answers
// the five questions top to bottom, names blocked causes, shows the single
// most urgent needs-you item read-only and says "Batch of N" for a convoy
// (stages for a formula run); the Timeline is scoped to the run, newest
// first, filters reduce its rows and events that arrive while scrolled
// away wait behind a jump-to-latest pill; the missing, stale, loading and
// error states; the home's run row pushes the screen.

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
import 'package:opencode_mobile/ui/screens/team/run_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  int count(String name) => calls[name] ?? 0;
  void _hit(String name) => calls[name] = count(name) + 1;

  @override
  OrchestrationCapabilities get capabilities => inner.capabilities;
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

  Future<void> pumpRun(
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
        RunScreen(controller: controller, runId: runId, now: () => clock),
        locale: locale,
      ),
    );
    await tester.pump();
  }

  /// The tab bar scrolls sideways when the tabs outgrow the width.
  Future<void> tab(WidgetTester tester, String name) async {
    final target = find.byKey(ValueKey('team-run-tab-$name'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
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

  group('overview', () {
    testWidgets('the fixture convoy: title, term, state, progress, batch', (
      tester,
    ) async {
      final (controller, _) = await boot();
      await pumpRun(tester, controller, 'oc-xru');
      expect(key('team-run-data'), findsOneWidget);
      // TEAM-115: the batch is named by its work and, with nobody
      // holding the bead, is waiting for an agent; the host's own
      // `sling-` title is in Technical details only.
      expect(find.text('Add subtract function to calc.py'), findsNWidgets(2));
      expect(find.text('sling-oc-loy'), findsNothing);
      expect(find.text('Run · convoy'), findsOneWidget);
      expect(find.text('Waiting for an agent'), findsOneWidget);
      expect(find.text('Planning'), findsNothing);
      // Created 2026-09-10T18:44:53Z, the clock is 12:30 the next day.
      expect(find.text('17 h 45 min'), findsOneWidget);
      expect(find.text('0 of 1 done'), findsOneWidget);
      expect(find.text('Working 0'), findsOneWidget);
      expect(find.text('Blocked 0'), findsOneWidget);
      expect(find.text('Batch of 1 · 0 done'), findsOneWidget);
      expect(key('team-run-stages'), findsNothing);
      expect(key('team-run-blocked'), findsNothing);
      expect(key('team-run-needs-you'), findsNothing);
      expect(key('team-run-stale'), findsNothing);
      expect(key('team-run-work-placeholder'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TEAM-117: work in the refinery\'s hands is Waiting for '
        'merge, timed from the hand-off, with Working and Blocked at 0', (
      tester,
    ) async {
      // The phone showed "Working · 20 h 19 min" beside "Working 0 ·
      // Blocked 0" for exactly this bead.
      final handedAt = clock.subtract(const Duration(hours: 20, minutes: 19));
      final (controller, _) = await boot(
        configure: (g) => handedToRefineryShape(g, updatedAt: handedAt),
      );
      await pumpRun(tester, controller, 'oc-xru');
      expect(
        tester.widget<Text>(key('team-run-state')).data,
        'Waiting for merge',
      );
      expect(
        tester.widget<Text>(key('team-run-elapsed')).data,
        '20 h 19 min since hand-off',
      );
      // ("Working" still names the strip's fourth step chip.)
      expect(find.text('Waiting for an agent'), findsNothing);
      expect(find.text('Working 0'), findsOneWidget);
      expect(find.text('Blocked 0'), findsOneWidget);
      expect(find.text('0 of 1 done'), findsOneWidget);
      // The strip: every step reached at the hand-off time, the merge
      // awaited past its window.
      expect(key('team-run-cycle'), findsOneWidget);
      expect(find.text('Waiting for the merge agent'), findsOneWidget);
      final cycle = controller.cycleFor('oc-loy');
      expect(cycle.reachedAt[DispatchStep.handedToMerge], handedAt);
      expect(cycle.stallReason, DispatchStall.mergeWaiting);
      // Technical details agree with the header.
      await tester.tap(key('team-run-details'));
      await tester.pumpAndSettle();
      expect(find.text('Waiting for merge'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('TEAM-117: the recorded bead has no update time: the '
        'hand-off is counted from its creation, steps untimed', (tester) async {
      final (controller, _) = await boot(configure: handedToRefineryShape);
      await pumpRun(tester, controller, 'oc-xru');
      expect(
        tester.widget<Text>(key('team-run-state')).data,
        'Waiting for merge',
      );
      // Created 2026-09-10T18:44:45Z, the clock is 12:30 the next day.
      expect(
        tester.widget<Text>(key('team-run-elapsed')).data,
        '17 h 45 min since hand-off',
      );
      final cycle = controller.cycleFor('oc-loy');
      expect(cycle.isDone(DispatchStep.handedToMerge), isTrue);
      expect(cycle.reachedAt[DispatchStep.handedToMerge], isNull);
      expect(cycle.since, isNull);
      expect(cycle.stallReason, DispatchStall.mergeWaiting);
      expect(find.text('Waiting for the merge agent'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('answers the five questions top to bottom', (tester) async {
      final (controller, _) = await boot(configure: richShape);
      await pumpRun(tester, controller, 'oc-xru');
      const order = [
        'team-run-objective',
        'team-run-progress',
        'team-run-counts',
        'team-run-blocked',
        'team-run-needs-you',
        'team-run-batch',
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
      expect(find.text('Offline-first sessions'), findsNWidgets(2));
      expect(find.text('Blocked'), findsOneWidget);
      expect(find.text('34 min'), findsOneWidget);
      expect(find.text('1 of 4 done'), findsOneWidget);
      expect(find.text('Working 1'), findsOneWidget);
      expect(find.text('Blocked 1'), findsOneWidget);
      expect(find.text('Batch of 4 · 1 done'), findsOneWidget);
      expect(key('team-run-stages'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('names the blocked cause the host gave', (tester) async {
      final (controller, _) = await boot(configure: richShape);
      await pumpRun(tester, controller, 'oc-xru');
      expect(
        find.text('Conflict policy: Tests failed: 2 of 18'),
        findsOneWidget,
      );
      expect(key('team-run-blocked-w3'), findsOneWidget);
      expect(key('team-run-blocked-w2'), findsNothing);
    });

    testWidgets('the blocked shape: cause from the open dependency', (
      tester,
    ) async {
      final (controller, _) = await boot(configure: blockedShape);
      await pumpRun(tester, controller, 'oc-xru');
      expect(find.text('Blocked'), findsOneWidget);
      expect(find.text('1 of 3 done'), findsOneWidget);
      expect(find.text('Blocked 1'), findsOneWidget);
      expect(
        find.text(
          'Add subtract function to calc.py: waiting on one other item',
        ),
        findsOneWidget,
      );
      expect(find.text('Batch of 3 · 1 done'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a formula run with steps shows Stages, not a batch line', (
      tester,
    ) async {
      final (controller, _) = await boot(configure: richShape);
      await pumpRun(tester, controller, 'run-ship');
      expect(find.text('Run · formula'), findsOneWidget);
      // The state word and the active stage.
      expect(find.text('Working'), findsNWidgets(2));
      expect(find.text('2 h 5 min'), findsOneWidget);
      expect(find.text('Nothing counted yet'), findsOneWidget);
      expect(key('team-run-stages'), findsOneWidget);
      expect(find.text('Stages'), findsOneWidget);
      expect(find.text('Requirements'), findsOneWidget);
      expect(find.text('Implementation'), findsOneWidget);
      expect(find.text('Testing'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Planning'), findsOneWidget);
      expect(key('team-run-batch'), findsNothing);
      expect(key('team-run-needs-you'), findsNothing);
      expect(key('team-run-blocked'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the most urgent needs-you item, read-only', (tester) async {
      final (controller, _) = await boot(configure: richShape);
      await pumpRun(tester, controller, 'oc-xru');
      final card = key('team-run-needs-you');
      expect(card, findsOneWidget);
      // The decision outranks the gate bead; the other run's gate is absent.
      expect(find.text('wolf needs you'), findsOneWidget);
      expect(find.text('Which persistence strategy?'), findsOneWidget);
      expect(
        find.text('This choice controls how the tests store data.'),
        findsOneWidget,
      );
      expect(find.text('Approve the schema'), findsNothing);
      expect(find.text('Another run asks'), findsNothing);
      expect(
        find.text(
          'Answer this on the computer. The phone can only watch for now.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Decide'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone host says where to answer', (tester) async {
      final (controller, _) = await boot(
        configure: richShape,
        hostMode: OrchestrationHostMode.phone,
      );
      await pumpRun(tester, controller, 'oc-xru');
      expect(
        find.text(
          'Answer this in the host on this phone. The app can only watch '
          'for now.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Details opens the technical sheet with the ids', (
      tester,
    ) async {
      final (controller, _) = await boot(configure: richShape);
      await pumpRun(tester, controller, 'oc-xru');
      await tester.tap(key('team-run-details'));
      await tester.pumpAndSettle();
      final sheet = key('team-run-details-sheet');
      expect(sheet, findsOneWidget);
      expect(find.text('Technical details'), findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('oc-xru')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('w1, w2, w3, w4')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('convoy')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('issue_type')),
        findsOneWidget,
      );
      // The convoy's own title is here, under "Provider title" (TEAM-115).
      expect(
        find.descendant(of: sheet, matching: find.text('Provider title')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('sling-oc-loy')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Work and Agents tabs are real', (tester) async {
      final (controller, _) = await boot(configure: richShape);
      await pumpRun(tester, controller, 'oc-xru');
      await tab(tester, 'work');
      expect(key('team-run-work-placeholder'), findsNothing);
      expect(key('team-run-work'), findsOneWidget);
      await tab(tester, 'agents');
      expect(key('team-run-agents-placeholder'), findsNothing);
      expect(find.text('Coming with the next update'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('timeline', () {
    testWidgets('lists this run’s events newest first; filters reduce', (
      tester,
    ) async {
      final (controller, gateway) = await boot(configure: richShape);
      await pumpRun(tester, controller, 'oc-xru');
      await tab(tester, 'timeline');
      expect(key('team-run-timeline-empty'), findsOneWidget);
      expect(find.text('Nothing has happened yet'), findsOneWidget);

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
      // Not this run's: another bead, a controller order, another run.
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

      expect(key('team-run-timeline-empty'), findsNothing);
      for (final seq in [1, 2, 3, 7, 8]) {
        expect(key('team-run-event-${s(seq)}'), findsOneWidget, reason: '$seq');
      }
      for (final seq in [4, 5, 6]) {
        expect(key('team-run-event-${s(seq)}'), findsNothing, reason: '$seq');
      }
      // Newest first.
      final order = [8, 7, 3, 2, 1];
      for (var i = 1; i < order.length; i++) {
        expect(
          top(tester, key('team-run-event-${s(order[i - 1])}')),
          lessThan(top(tester, key('team-run-event-${s(order[i])}'))),
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
            tester.element(find.byType(RunScreen)),
          ).formatTimeOfDay(
            TimeOfDay.fromDateTime(
              clock.subtract(const Duration(minutes: 9)).toLocal(),
            ),
            alwaysUse24HourFormat: true,
          );
      expect(find.text(time), findsOneWidget);

      await tester.tap(key('team-run-timeline-filter-work'));
      await tester.pumpAndSettle();
      expect(key('team-run-event-${s(1)}'), findsOneWidget);
      expect(key('team-run-event-${s(7)}'), findsOneWidget);
      expect(key('team-run-event-${s(2)}'), findsNothing);
      expect(key('team-run-event-${s(3)}'), findsNothing);
      expect(key('team-run-event-${s(8)}'), findsNothing);

      await tester.tap(key('team-run-timeline-filter-agents'));
      await tester.pumpAndSettle();
      expect(key('team-run-event-${s(2)}'), findsOneWidget);
      expect(key('team-run-event-${s(1)}'), findsNothing);

      await tester.tap(key('team-run-timeline-filter-decisions'));
      await tester.pumpAndSettle();
      expect(key('team-run-event-${s(3)}'), findsOneWidget);
      expect(key('team-run-event-${s(2)}'), findsNothing);

      await tester.tap(key('team-run-timeline-filter-all'));
      await tester.pumpAndSettle();
      for (final seq in [1, 2, 3, 7, 8]) {
        expect(key('team-run-event-${s(seq)}'), findsOneWidget, reason: '$seq');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a filter that hides every row says so', (tester) async {
      final (controller, gateway) = await boot(configure: richShape);
      await pumpRun(tester, controller, 'oc-xru');
      await tab(tester, 'timeline');
      await push(
        tester,
        gateway,
        BeadChanged(beadId: 'w2', change: BeadChange.updated, seq: s(1)),
      );
      await tester.tap(key('team-run-timeline-filter-decisions'));
      await tester.pumpAndSettle();
      expect(key('team-run-timeline-empty-filtered'), findsOneWidget);
      expect(find.text('No events of this kind yet'), findsOneWidget);
      expect(key('team-run-timeline-empty'), findsNothing);
    });

    testWidgets('events that arrive while scrolled wait behind the pill', (
      tester,
    ) async {
      final (controller, gateway) = await boot(configure: richShape);
      await pumpRun(tester, controller, 'oc-xru', size: const Size(400, 600));
      await tab(tester, 'timeline');
      for (var seq = 1; seq <= 30; seq++) {
        gateway.stream.add(
          BeadChanged(beadId: 'w2', change: BeadChange.updated, seq: s(seq)),
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(key('team-run-event-${s(30)}'), findsOneWidget);
      expect(key('team-run-timeline-jump'), findsNothing);

      final list = key('team-run-timeline');
      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: list, matching: find.byType(Scrollable)),
      );
      expect(scroll.position.pixels, greaterThan(24));
      expect(key('team-run-timeline-jump'), findsNothing);

      // The new event holds back; the rows do not move.
      final before = scroll.position.pixels;
      await push(
        tester,
        gateway,
        BeadChanged(beadId: 'w3', change: BeadChange.closed, seq: s(31)),
      );
      expect(key('team-run-timeline-jump'), findsOneWidget);
      expect(find.text('1 new · Jump to latest'), findsOneWidget);
      expect(key('team-run-event-${s(31)}'), findsNothing);
      expect(scroll.position.pixels, before);
      await push(
        tester,
        gateway,
        BeadChanged(beadId: 'w4', change: BeadChange.updated, seq: s(32)),
      );
      expect(find.text('2 new · Jump to latest'), findsOneWidget);

      await tester.tap(key('team-run-timeline-jump'));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, 0);
      expect(key('team-run-timeline-jump'), findsNothing);
      expect(key('team-run-event-${s(32)}'), findsOneWidget);
      expect(find.text('Release notes updated'), findsOneWidget);
      expect(
        top(tester, key('team-run-event-${s(32)}')),
        lessThan(top(tester, key('team-run-event-${s(31)}'))),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolling back to the top releases the held rows', (
      tester,
    ) async {
      final (controller, gateway) = await boot(configure: richShape);
      await pumpRun(tester, controller, 'oc-xru', size: const Size(400, 600));
      await tab(tester, 'timeline');
      for (var seq = 1; seq <= 30; seq++) {
        gateway.stream.add(
          BeadChanged(beadId: 'w2', change: BeadChange.updated, seq: s(seq)),
        );
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      final list = key('team-run-timeline');
      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
      await push(
        tester,
        gateway,
        BeadChanged(beadId: 'w3', change: BeadChange.closed, seq: s(31)),
      );
      expect(key('team-run-timeline-jump'), findsOneWidget);
      await tester.drag(list, const Offset(0, 1200));
      await tester.pumpAndSettle();
      expect(key('team-run-timeline-jump'), findsNothing);
      expect(key('team-run-event-${s(31)}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('states', () {
    testWidgets('a run the host no longer lists, with Back', (tester) async {
      final (controller, _) = await boot();
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              key: const ValueKey('launcher'),
              body: TextButton(
                key: const ValueKey('open'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RunScreen(
                      controller: controller,
                      runId: 'gone',
                      now: () => clock,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(key('open'));
      await tester.pumpAndSettle();
      expect(key('team-run-missing'), findsOneWidget);
      expect(find.text('This run is no longer on the host'), findsOneWidget);
      expect(key('team-run-data'), findsNothing);
      expect(key('team-run-details'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Back'));
      await tester.pumpAndSettle();
      expect(key('team-run-missing'), findsNothing);
      expect(key('launcher'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a run that disappears on refresh turns into the state', (
      tester,
    ) async {
      final (controller, gateway) = await boot(configure: richShape);
      await pumpRun(tester, controller, 'oc-xru');
      expect(key('team-run-data'), findsOneWidget);
      gateway.runsOverride = const [];
      await tester.tap(key('team-run-refresh'));
      await tester.pumpAndSettle();
      expect(key('team-run-missing'), findsOneWidget);
      expect(key('team-run-data'), findsNothing);
    });

    testWidgets('stale shows the card’s line; Refresh clears it', (
      tester,
    ) async {
      final (controller, gateway) = await boot(configure: richShape);
      final refreshedAt = controller.lastRefreshedAt!;
      await pumpRun(tester, controller, 'oc-xru');
      expect(key('team-run-stale'), findsNothing);

      clock = clock.add(const Duration(seconds: 61));
      await pumpRun(tester, controller, 'oc-xru');
      expect(key('team-run-stale'), findsOneWidget);
      final time =
          MaterialLocalizations.of(
            tester.element(find.byType(RunScreen)),
          ).formatTimeOfDay(
            TimeOfDay.fromDateTime(refreshedAt.toLocal()),
            alwaysUse24HourFormat: true,
          );
      expect(
        find.text('Showing data from $time · host unreachable'),
        findsOneWidget,
      );
      final before = gateway.count('runs');
      await tester.tap(key('team-run-refresh'));
      await tester.pumpAndSettle();
      expect(gateway.count('runs'), before + 1);
      expect(key('team-run-stale'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('before the probe answers: loading', (tester) async {
      final (controller, _) = await boot(started: false);
      await pumpRun(tester, controller, 'oc-xru');
      expect(key('team-run-loading'), findsOneWidget);
      expect(key('team-run-data'), findsNothing);
      expect(key('team-run-missing'), findsNothing);
    });

    testWidgets('a failed probe shows honest copy and Retry recovers', (
      tester,
    ) async {
      ProbeVerdict verdict = const ProbeUnreachable(error: 'refused');
      final (controller, gateway) = await boot(probe: (_) async => verdict);
      expect(controller.phase, OrchestrationPhase.failed);
      await pumpRun(tester, controller, 'oc-xru');
      expect(key('team-run-error'), findsOneWidget);
      expect(
        find.text(
          'The team host can’t be reached. AI Team works over your Tailscale '
          'network or on this device.',
        ),
        findsOneWidget,
      );
      verdict = ProbeFound(host: gateway.host!, city: 'bright-lights');
      await tester.tap(key('team-run-refresh'));
      await tester.pumpAndSettle();
      expect(controller.phase, OrchestrationPhase.ready);
      expect(key('team-run-data'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the home’s run row pushes the run detail', (tester) async {
      final (controller, _) = await boot();
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(TeamHomeScreen(controller: controller, now: () => clock)),
      );
      await tester.pump();
      await tester.tap(key('team-home-run-oc-xru'));
      await tester.pumpAndSettle();
      expect(key('team-run'), findsOneWidget);
      expect(find.text('Run · convoy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reads in Arabic with the term and ids LTR', (tester) async {
      final (controller, _) = await boot(configure: richShape);
      await pumpRun(tester, controller, 'oc-xru', locale: const Locale('ar'));
      expect(find.text('تشغيل · convoy'), findsOneWidget);
      expect(find.text('اكتمل 1 من 4'), findsOneWidget);
      expect(find.text('دفعة من 4 · اكتمل 1'), findsOneWidget);
      expect(find.text('wolf يحتاجك'), findsOneWidget);
      await tester.tap(key('team-run-details'));
      await tester.pumpAndSettle();
      final id = find.descendant(
        of: key('team-run-details-sheet'),
        matching: find.text('oc-xru'),
      );
      expect(id, findsOneWidget);
      // find.text lands on the EditableText inside the SelectableText.
      expect(tester.widget<EditableText>(id).textDirection, TextDirection.ltr);
      expect(tester.takeException(), isNull);
    });
  });
}
