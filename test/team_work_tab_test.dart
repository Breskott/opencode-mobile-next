// TEAM-110: the run detail's Work tab. At phone width the tab defaults to
// List and Graph is one tap away; at 600dp and wider it starts on Graph;
// the choice is remembered per run in the profile's store; the List groups
// the run's items by state in the BRD §14 order with counts, each row
// carrying its owner glyph, what it waits on and its age; a row or a graph
// node opens the Work sheet; a run without work shows the empty state.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/team/run_screen.dart';
import 'package:opencode_mobile/ui/screens/team/work_graph.dart';
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

/// The fixture with the runs, work and agents a scenario needs and an
/// owned event stream.
class _Gateway implements OrchestrationGateway {
  _Gateway(this.inner);

  final FixtureOrchestrationGateway inner;
  final stream = StreamController<OrchestrationEvent>.broadcast();
  List<OrchestrationRun>? runsOverride;
  List<WorkItem>? workOverride;
  List<OrchestrationAgent>? agentsOverride;

  @override
  OrchestrationCapabilities get capabilities =>
      OrchestrationCapabilities.gascityRead;
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
  Future<List<OrchestrationRun>> runs({String? projectId}) async =>
      runsOverride ?? await inner.runs(projectId: projectId);
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
  Future<List<OrchestrationGate>> gates() async => const [];
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String fixturePath;
  late SharedPreferences prefs;
  late OrchestrationStore store;
  late DateTime clock;

  setUp(() async {
    fixturePath = _findFixtureRoot().path;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = OrchestrationStore(prefs);
    clock = DateTime.utc(2026, 9, 11, 12, 30);
  });

  /// One convoy with an item in every state of the BRD list (two working),
  /// linked so the graph has a chain, plus an item of another run.
  void everyState(_Gateway gateway) {
    WorkItem item(
      String id,
      String title,
      WorkState state, {
      List<String> dependsOn = const [],
      String? assignee,
      Duration age = const Duration(hours: 3),
      String? runId = 'oc-xru',
    }) => WorkItem(
      id: id,
      title: title,
      state: state,
      runId: runId,
      assignee: assignee,
      dependsOn: dependsOn,
      updatedAt: clock.subtract(age),
    );
    gateway
      ..runsOverride = [
        OrchestrationRun(
          id: 'oc-xru',
          title: 'Offline-first sessions',
          state: RunState.blocked,
          rawState: 'open',
          kind: RunKind.batch,
          startedAt: clock.subtract(const Duration(hours: 4)),
          raw: const {'id': 'oc-xru', 'issue_type': 'convoy'},
        ),
        OrchestrationRun(
          id: 'oc-empty',
          title: 'Nothing slung yet',
          state: RunState.planning,
          kind: RunKind.batch,
          raw: const {'id': 'oc-empty', 'issue_type': 'convoy'},
        ),
      ]
      ..workOverride = [
        item(
          'w-done',
          'Storage layer',
          WorkState.completed,
          assignee: 'ocproof/gastown.mole',
          age: const Duration(days: 1),
        ),
        item(
          'w-work-a',
          'Sync engine',
          WorkState.working,
          dependsOn: ['w-done'],
          assignee: 'fox',
          age: const Duration(minutes: 5),
        ),
        item(
          'w-blocked',
          'Conflict policy',
          WorkState.blocked,
          dependsOn: ['w-work-a', 'w-done'],
        ),
        item(
          'w-input',
          'Database tests',
          WorkState.needsInput,
          dependsOn: ['w-blocked'],
        ),
        item('w-work-b', 'Android integration', WorkState.working),
        item('w-ready', 'Unit tests', WorkState.ready, dependsOn: ['w-done']),
        item('w-queued', 'Release notes', WorkState.queued),
        item('w-review', 'Background sync', WorkState.review),
        item('w-failed', 'Flaky suite', WorkState.failed),
        item('w-cancelled', 'Old approach', WorkState.cancelled),
        item('w-elsewhere', 'Elsewhere', WorkState.working, runId: 'other'),
      ]
      ..agentsOverride = const [
        OrchestrationAgent(
          id: 'wolf',
          name: 'wolf',
          state: AgentState.waiting,
          sessionId: 's-wolf',
          currentWorkId: 'w-input',
        ),
      ];
  }

  Future<(OrchestrationController, _Gateway)> boot({
    void Function(_Gateway gateway)? configure,
  }) async {
    final gateway = _Gateway(
      FixtureOrchestrationGateway(fixturePath: fixturePath),
    );
    (configure ?? everyState)(gateway);
    final config = OrchestrationConfig(
      provider: OrchestrationProvider.fixture,
      url: fixturePath,
      city: 'bright-lights',
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
      now: () => clock,
    );
    addTearDown(controller.dispose);
    await controller.start();
    return (controller, gateway);
  }

  Widget app(Widget home) => MaterialApp(
    theme: AppTheme.dark(),
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
    Size size = const Size(320, 740),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(RunScreen(controller: controller, runId: runId, now: () => clock)),
    );
    await tester.pump();
    final target = find.byKey(const ValueKey('team-run-tab-work'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Finder key(String name) => find.byKey(ValueKey(name));

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find
          .descendant(
            of: key('team-run-work-groups'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  const prefKey = 'oc.orchestration.srv-1.workView.oc-xru';

  /// Every label in the semantics tree.
  List<String> semanticLabels(WidgetTester tester) {
    final labels = <String>[];
    bool visit(SemanticsNode node) {
      final label = node.getSemanticsData().label;
      if (label.isNotEmpty) labels.add(label);
      node.visitChildren(visit);
      return true;
    }

    tester.getSemantics(key('team-run-work-groups')).visitChildren(visit);
    return labels;
  }

  testWidgets('320dp defaults to List; Graph is one tap away', (tester) async {
    final (controller, _) = await boot();
    await pumpRun(tester, controller, 'oc-xru');
    expect(key('team-run-work'), findsOneWidget);
    expect(key('team-run-work-list'), findsOneWidget);
    expect(key('team-run-work-graph'), findsNothing);
    expect(prefs.getString(prefKey), isNull);
    final graph = key('team-run-work-view-graph');
    expect(graph, findsOneWidget);
    await tester.tap(graph);
    await tester.pumpAndSettle();
    expect(key('team-run-work-graph'), findsOneWidget);
    expect(key('team-run-work-list'), findsNothing);
    expect(key('team-work-graph-fit').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('600dp and wider starts on Graph', (tester) async {
    final (controller, _) = await boot();
    await pumpRun(tester, controller, 'oc-xru', size: const Size(600, 900));
    expect(key('team-run-work-graph'), findsOneWidget);
    expect(key('team-run-work-list'), findsNothing);
    await tester.tap(key('team-run-work-view-list'));
    await tester.pumpAndSettle();
    expect(key('team-run-work-list'), findsOneWidget);
    expect(prefs.getString(prefKey), 'list');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the choice is remembered per run in the profile store', (
    tester,
  ) async {
    final (controller, _) = await boot();
    await pumpRun(tester, controller, 'oc-xru');
    await tester.tap(key('team-run-work-view-graph'));
    await tester.pumpAndSettle();
    expect(prefs.getString(prefKey), 'graph');
    expect(controller.workView('oc-xru'), 'graph');
    expect(controller.workView('oc-empty'), isNull);

    // A fresh screen over the same run opens on Graph even at 320dp; the
    // other run keeps its own default.
    await tester.pumpWidget(const SizedBox());
    await pumpRun(tester, controller, 'oc-xru');
    expect(key('team-run-work-graph'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pumpRun(tester, controller, 'oc-empty');
    expect(key('team-run-work-empty'), findsOneWidget);
    expect(find.text('No work items yet'), findsOneWidget);
    expect(key('team-run-work-view'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  test(
    'turning the plugin off sweeps the remembered view with the rest',
    () async {
      await store.saveWorkView('srv-1', 'oc-xru', 'graph');
      expect(prefs.getString(prefKey), 'graph');
      expect(store.readWorkView('srv-1', 'oc-xru'), 'graph');
      await store.saveWorkView('srv-1', 'oc-xru', null);
      expect(store.readWorkView('srv-1', 'oc-xru'), isNull);
      await store.saveWorkView('srv-1', 'oc-xru', 'list');
      // (The Keystore has no mock here; only the preference matters.)
      expect(await store.sweep('srv-1'), isNot(contains(prefKey)));
      expect(prefs.getString(prefKey), isNull);
    },
  );

  testWidgets('List groups by state in the BRD order with counts', (
    tester,
  ) async {
    final (controller, _) = await boot();
    await pumpRun(tester, controller, 'oc-xru', size: const Size(400, 2400));
    expect(key('team-run-work-list'), findsOneWidget);
    const expected = [
      ('needsInput', 'Needs input · 1'),
      ('blocked', 'Blocked · 1'),
      ('working', 'Working · 2'),
      ('ready', 'Ready · 1'),
      ('queued', 'Queued · 1'),
      ('review', 'Review · 1'),
      ('completed', 'Done · 1'),
      ('failed', 'Failed · 1'),
      ('cancelled', 'Cancelled · 1'),
    ];
    var last = -1.0;
    for (final (name, header) in expected) {
      final group = key('team-run-work-group-$name');
      await reveal(tester, group);
      expect(
        tester.widget<Text>(key('team-run-work-group-count-$name')).data,
        header,
      );
      final top = tester.getTopLeft(group).dy;
      expect(top, greaterThan(last));
      last = top;
    }
    expect(key('team-run-work-group-waiting'), findsNothing);
    expect(key('team-run-work-group-unknown'), findsNothing);
    // Another run's item is not here.
    expect(key('team-run-work-row-w-elsewhere'), findsNothing);
    expect(
      find.byKey(const ValueKey('team-run-work-row-w-done')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rows carry the owner glyph, what they wait on and age', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final (controller, _) = await boot();
    await pumpRun(tester, controller, 'oc-xru', size: const Size(400, 2400));
    // Blocked: waits on the open Sync engine, not on the done Storage.
    expect(
      tester.widget<Text>(key('team-run-work-detail-w-blocked')).data,
      'Waits on 1 item · 3h ago',
    );
    // Needs input: the agent on it is the owner.
    expect(
      tester.widget<Text>(key('team-run-work-detail-w-input')).data,
      'Waits on 1 item · 3h ago',
    );
    expect(
      find.descendant(
        of: key('team-run-work-owner-w-input'),
        matching: find.text('W'),
      ),
      findsOneWidget,
    );
    expect(semanticLabels(tester), anyElement(contains('Owner: wolf')));
    // Working on a done need: no wait, just the age; assignee initial.
    expect(
      tester.widget<Text>(key('team-run-work-detail-w-work-a')).data,
      '5m ago',
    );
    expect(
      find.descendant(
        of: key('team-run-work-owner-w-work-a'),
        matching: find.text('F'),
      ),
      findsOneWidget,
    );
    await reveal(tester, key('team-run-work-row-w-done'));
    expect(
      find.descendant(
        of: key('team-run-work-owner-w-done'),
        matching: find.text('M'),
      ),
      findsOneWidget,
    );
    expect(
      semanticLabels(tester),
      anyElement(contains('Owner: ocproof/gastown.mole')),
    );
    // Nobody on it: a dash and "Unassigned".
    expect(
      find.descendant(
        of: key('team-run-work-owner-w-queued'),
        matching: find.text('—'),
      ),
      findsOneWidget,
    );
    expect(semanticLabels(tester), anyElement(contains('Unassigned')));
    // Rows are full targets.
    expect(
      tester.getSize(key('team-run-work-row-w-blocked')).height,
      greaterThanOrEqualTo(48),
    );
    handle.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row opens the Work sheet', (tester) async {
    final (controller, _) = await boot();
    await pumpRun(tester, controller, 'oc-xru', size: const Size(400, 2400));
    await tester.tap(key('team-run-work-row-w-blocked'));
    await tester.pumpAndSettle();
    expect(key('team-work-sheet-w-blocked'), findsOneWidget);
    expect(
      tester.widget<Text>(key('team-work-sheet-title')).data,
      'Conflict policy',
    );
    expect(key('team-work-dependency-w-work-a'), findsOneWidget);
    expect(key('team-work-blocking-w-input'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a graph node opens the Work sheet; the chain is drawn', (
    tester,
  ) async {
    final (controller, _) = await boot();
    await pumpRun(tester, controller, 'oc-xru', size: const Size(800, 900));
    expect(key('team-run-work-graph'), findsOneWidget);
    final viewer = tester.widget<InteractiveViewer>(
      key('team-work-graph-viewer'),
    );
    final transform = viewer.transformationController!.value;
    final nodes = [
      for (final item in controller.snapshot.work)
        if (item.runId == 'oc-xru') WorkGraphNode.of(item),
    ];
    final layout = WorkGraphLayout.compute(nodes);
    expect(layout.blockedChain, {
      'w-work-a',
      'w-blocked',
      'w-input',
      'w-failed',
    });
    expect(layout.criticalPath, ['w-done', 'w-work-a', 'w-blocked', 'w-input']);
    // The canvas's global origin already carries the fitted transform.
    final origin = tester.getTopLeft(key('team-work-graph-canvas'));
    final scale = transform.storage[0];
    expect(scale, lessThanOrEqualTo(1));
    await tester.tapAt(origin + layout.rects['w-input']!.center * scale);
    await tester.pumpAndSettle();
    expect(key('team-work-sheet-w-input'), findsOneWidget);
    expect(
      tester.widget<Text>(key('team-work-sheet-title')).data,
      'Database tests',
    );
    expect(tester.takeException(), isNull);
  });
}
