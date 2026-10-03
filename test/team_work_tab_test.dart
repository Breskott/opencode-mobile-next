// TEAM-110, after slice-P3.5 retired the run page's Work tab: a task's
// steps live in Task details as the dependency graph in rows (one step per
// row with its state word and what it needs; the List / Graph toggle and
// its remembered choice are gone). Every step of the task is there and no
// other task's; a row opens the Work sheet (owner, age, what it waits on
// and what waits on it); a task without work shows no steps; the graph's
// chain is still worked out the same way; the remembered view preference
// is still swept with the plugin.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/kit/kit_work_graph.dart';
import 'package:opencode_mobile/ui/screens/team/task_details_sheet.dart';
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

/// The Graph view's geometry for [nodes], as `KitWorkGraph`'s layers form
/// lays it out (ids deduplicated, first kept, as the Work tab passes them).
KitWorkGraphGeometry _layout(
  List<WorkGraphNode> nodes, {
  Size nodeSize = const Size(KitTokens.graphNodeWidth, 44),
}) {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final seen = <String>{};
  return KitWorkGraphGeometry.layers([
    for (final node in nodes)
      if (seen.add(node.id)) node.toKit(l10n),
  ], nodeSize: nodeSize);
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

  Future<void> pumpDetails(
    WidgetTester tester,
    OrchestrationController controller,
    String runId, {
    Size size = const Size(400, 2400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        Scaffold(
          body: SingleChildScrollView(
            child: TeamTaskDetails(
              controller: controller,
              runId: runId,
              now: () => clock,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Finder key(String name) => find.byKey(ValueKey(name));

  const prefKey = 'oc.orchestration.srv-1.workView.oc-xru';

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

  testWidgets('every step of the task is a row with its state word; '
      "another task's work is not", (tester) async {
    final (controller, _) = await boot();
    await pumpDetails(tester, controller, 'oc-xru');
    expect(key('team-task-details-graph'), findsOneWidget);
    const expected = [
      ('w-done', 'Storage layer', 'Done'),
      ('w-work-a', 'Sync engine', 'Working'),
      ('w-blocked', 'Conflict policy', 'Blocked'),
      ('w-input', 'Database tests', 'Needs input'),
      ('w-work-b', 'Android integration', 'Working'),
      ('w-ready', 'Unit tests', 'Ready'),
      ('w-queued', 'Release notes', 'Queued'),
      ('w-review', 'Background sync', 'Review'),
      ('w-failed', 'Flaky suite', 'Failed'),
      ('w-cancelled', 'Old approach', 'Cancelled'),
    ];
    for (final (id, title, word) in expected) {
      final row = key('team-task-details-step-$id');
      expect(row, findsOneWidget, reason: id);
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining(title, findRichText: true),
        ),
        findsWidgets,
        reason: title,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining(word, findRichText: true),
        ),
        findsWidgets,
        reason: '$id: $word',
      );
      // Rows are full targets.
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    }
    // Another task's item is not here.
    expect(key('team-task-details-step-w-elsewhere'), findsNothing);
    // What a step needs is said on its row.
    expect(
      find.descendant(
        of: key('team-task-details-step-w-input'),
        matching: find.textContaining(
          'needs Conflict policy',
          findRichText: true,
        ),
      ),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row opens the Work sheet', (tester) async {
    final (controller, _) = await boot();
    await pumpDetails(tester, controller, 'oc-xru');
    await tester.tap(key('team-task-details-step-w-blocked'));
    await tester.pumpAndSettle();
    expect(key('team-work-sheet'), findsOneWidget);
    expect(
      find.descendant(
        of: key('team-work-sheet'),
        matching: find.text('Conflict policy'),
      ),
      findsWidgets,
    );
    expect(key('team-work-dependency-w-work-a'), findsOneWidget);
    expect(key('team-work-blocking-w-input'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a task without work shows no steps', (tester) async {
    final (controller, _) = await boot();
    await pumpDetails(tester, controller, 'oc-empty');
    expect(key('team-task-details-body'), findsOneWidget);
    expect(key('team-task-details-steps'), findsNothing);
    expect(key('team-task-details-graph'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('the chain the graph picks out, from the task\'s steps', () async {
    final (controller, _) = await boot();
    final nodes = [
      for (final item in controller.snapshot.work)
        if (item.runId == 'oc-xru') WorkGraphNode.of(item),
    ];
    final layout = _layout(nodes, nodeSize: const Size(156, 58));
    expect(layout.blockedChain, {
      'w-work-a',
      'w-blocked',
      'w-input',
      'w-failed',
    });
    expect(layout.criticalPath, ['w-done', 'w-work-a', 'w-blocked', 'w-input']);
  });
}
