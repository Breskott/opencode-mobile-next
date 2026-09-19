// TEAM-108: the AI Team home over the fixture gateway. Run ordering and
// the collapsed completed group, filter chips, title search, the host
// chip and its Technical details, the fleet rows, Needs you with the
// read-only gate sheet, stale, loading, error, pull-to-refresh and the
// Workspace card wiring.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart' show Session, SessionTime;
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/dto/dto.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_mappers.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:opencode_mobile/ui/widgets/team_card.dart';
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

/// The `blocked` scenario's derived `/pending` entry (as in
/// team_card_test).
const _blockedPending = <String, Object?>{
  'session_id': 'bl-polecat-1',
  'request_id': 'req-fixture-choice-1',
  'kind': 'choice',
  'prompt': 'calc.py already defines subtract(). Replace it, keep it, or stop?',
  'options': ['replace', 'keep', 'stop'],
  'metadata': {'bead': 'oc-loy', 'fixture.scenario': 'blocked'},
};

/// The fixture with per-scope overrides, a read counter and an owned event
/// stream so a test can drop the connection.
class _Gateway implements OrchestrationGateway {
  _Gateway(this.inner);

  final FixtureOrchestrationGateway inner;
  final calls = <String, int>{};
  final stream = StreamController<OrchestrationEvent>.broadcast();
  List<OrchestrationRun>? runsOverride;
  List<WorkItem>? workOverride;
  List<OrchestrationAgent>? agentsOverride;
  List<OrchestrationGate>? gatesOverride;
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
  Future<List<OrchestrationProject>> projects() {
    _hit('projects');
    return inner.projects();
  }

  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) async {
    _hit('runs');
    return runsOverride ?? await inner.runs(projectId: projectId);
  }

  @override
  Future<OrchestrationRun?> run(String id) => inner.run(id);

  @override
  Future<List<WorkItem>> work({String? projectId}) async {
    _hit('work');
    return workOverride ?? await inner.work(projectId: projectId);
  }

  @override
  Future<List<WorkItem>> readyWork({String? projectId}) =>
      inner.readyWork(projectId: projectId);

  @override
  Future<WorkItem?> workItem(String id) => inner.workItem(id);

  @override
  Future<List<OrchestrationAgent>> agents() async {
    _hit('agents');
    return agentsOverride ?? await inner.agents();
  }

  @override
  Future<OrchestrationAgent?> agent(String id) => inner.agent(id);

  @override
  Future<List<OrchestrationGate>> gates() async {
    _hit('gates');
    return gatesOverride ?? await inner.gates();
  }

  @override
  Future<OrchestrationUsage?> usage() {
    _hit('usage');
    return inner.usage();
  }

  @override
  Future<List<ActivityEvent>> activity({int? afterSeq, int limit = 100}) {
    _hit('activity');
    return inner.activity(afterSeq: afterSeq, limit: limit);
  }

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

/// A connection whose plugin controller a test can set directly.
class _Connection extends ConnectionController {
  _Connection(super.store);

  OrchestrationController? team;

  @override
  OrchestrationController? get orchestration => team;

  @override
  ServerCapabilities get capabilities =>
      const ServerCapabilities(projectManagement: false);
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

  OrchestrationConfig config({
    OrchestrationHostMode hostMode = OrchestrationHostMode.computer,
    String? url,
  }) => OrchestrationConfig(
    provider: OrchestrationProvider.fixture,
    url: url ?? fixturePath,
    city: 'bright-lights',
    hostMode: hostMode,
    enabledAt: DateTime.utc(2026, 9, 10),
  );

  ServerProfile profile({OrchestrationConfig? config}) => ServerProfile(
    id: 'srv-1',
    name: 'Workstation',
    baseUrl: 'https://server.example:4096',
    orchestration: config,
  );

  Future<(OrchestrationController, _Gateway)> boot({
    bool started = true,
    OrchestrationProbe? probe,
    void Function(_Gateway gateway)? configure,
    OrchestrationHostMode hostMode = OrchestrationHostMode.computer,
    String? url,
  }) async {
    final gateway = _Gateway(
      FixtureOrchestrationGateway(fixturePath: fixturePath, hostMode: hostMode),
    );
    configure?.call(gateway);
    final cfg = config(hostMode: hostMode, url: url);
    final controller = OrchestrationController(
      profile: profile(config: cfg),
      config: cfg,
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

  Future<void> pumpHome(
    WidgetTester tester,
    OrchestrationController controller, {
    ValueChanged<OrchestrationRun>? onOpenRun,
    ValueChanged<OrchestrationAgent>? onOpenAgent,
  }) async {
    // Tall enough that every row of the shapes below is built.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        TeamHomeScreen(
          controller: controller,
          onOpenRun: onOpenRun,
          onOpenAgent: onOpenAgent,
          now: () => clock,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> segment(WidgetTester tester, String name) async {
    await tester.tap(find.byKey(ValueKey('team-home-segment-$name')));
    await tester.pumpAndSettle();
  }

  Finder runRow(String id) => find.byKey(ValueKey('team-home-run-$id'));

  double top(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder).dy;

  OrchestrationRun run(
    String id,
    RunState state,
    int minutesAgo, {
    RunKind kind = RunKind.formula,
  }) => OrchestrationRun(
    id: id,
    title: 'Run $id',
    state: state,
    kind: kind,
    formula: kind == RunKind.formula ? 'ship' : null,
    stepCount: 4,
    completedSteps: state == RunState.completed ? 4 : 1,
    updatedAt: clock.subtract(Duration(minutes: minutesAgo)),
  );

  /// Seven runs across every group; the failed one ranks with needs-you.
  void mixedShape(_Gateway gateway) {
    gateway
      ..workOverride = const []
      ..gatesOverride = const []
      ..runsOverride = [
        run('done-1', RunState.completed, 1),
        run('wait-1', RunState.waiting, 2),
        run('work-old', RunState.working, 30),
        run('work-new', RunState.working, 3),
        run('plan-1', RunState.planning, 4),
        run('done-2', RunState.completed, 5),
        run('blocked-1', RunState.blocked, 6),
        run('failed-1', RunState.failed, 7, kind: RunKind.batch),
      ];
  }

  /// TEAM-117: the fixture convoy over the recorded `oc-loy` as the host
  /// last showed it — pushed and in the refinery's hands, no live agent,
  /// never closed.
  void handedToRefineryShape(_Gateway gateway) {
    final convoys = GcList<GcConvoy>.fromJson(
      readMap(
        jsonDecode(
          File('$fixturePath/recordings/convoys.json').readAsStringSync(),
        ),
      ),
      GcConvoy.fromJson,
    ).items;
    final bead = GcBead.fromJson(
      readMap(
        jsonDecode(
          File(
            '$fixturePath/recordings/bead_handed_to_refinery.json',
          ).readAsStringSync(),
        ),
      ),
    );
    final context = GcWorkContext.from(convoys: convoys);
    final work = mapBeads([bead], context: context);
    gateway
      ..workOverride = work
      ..runsOverride = mapConvoys(convoys, work: work, context: context)
      ..gatesOverride = const [];
  }

  /// The `blocked` shape of team_card_test: the fixture convoy over a
  /// blocked `oc-loy` and a closed sibling, plus the pending choice.
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
          raw: item.raw,
        ),
    ];
    final runs = mapConvoys(convoys, work: work, context: context);
    gateway
      ..workOverride = work
      ..runsOverride = runs
      ..gatesOverride = [
        for (final gate in mapGates(
          pending: [GcPendingInteraction.fromJson(_blockedPending)],
          beads: beads,
          runs: runs,
        ))
          OrchestrationGate(
            id: gate.id,
            kind: gate.kind,
            title: gate.title,
            prompt: gate.prompt,
            workId: 'oc-loy',
            agentId: gate.agentId,
            choices: gate.choices,
            createdAt: clock.subtract(const Duration(minutes: 2)),
          ),
      ];
  }

  group('runs', () {
    testWidgets('the fixture run lists with its kind, progress and state', (
      tester,
    ) async {
      OrchestrationRun? opened;
      final (controller, _) = await boot();
      await pumpHome(tester, controller, onOpenRun: (run) => opened = run);
      expect(find.byKey(const ValueKey('team-home-data')), findsOneWidget);
      expect(find.text('AI Team'), findsOneWidget);
      expect(find.text('Runs (1)'), findsOneWidget);
      // Five live agents; the dog slots and the core helper are not agents.
      expect(find.text('Agents (5)'), findsOneWidget);
      expect(find.text('Needs you (0)'), findsOneWidget);
      expect(runRow('oc-xru'), findsOneWidget);
      // The batch is named by its work and honest about nobody having it.
      expect(find.text('Add subtract function to calc.py'), findsOneWidget);
      expect(find.text('sling-oc-loy'), findsNothing);
      expect(find.text('Batch · convoy · 0 of 1 done'), findsOneWidget);
      expect(find.text('Waiting for an agent'), findsOneWidget);
      expect(find.text('Planning'), findsNothing);
      expect(
        find.byKey(const ValueKey('team-home-upkeep-toggle')),
        findsNothing,
        reason: 'no upkeep in the recording: no toggle',
      );
      expect(
        find.byKey(const ValueKey('team-home-completed-group')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('team-home-stale')), findsNothing);

      await tester.tap(runRow('oc-xru'));
      expect(opened?.id, 'oc-xru');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'ordered needs-you → active → waiting/blocked, completed collapsed',
      (tester) async {
        final (controller, _) = await boot(configure: mixedShape);
        await pumpHome(tester, controller);

        expect(find.text('Runs (8)'), findsOneWidget);
        final order = [
          'failed-1',
          'work-new',
          'work-old',
          'plan-1',
          'blocked-1',
          'wait-1',
        ];
        for (final id in order) {
          expect(runRow(id), findsOneWidget, reason: id);
        }
        for (var i = 1; i < order.length; i++) {
          expect(
            top(tester, runRow(order[i - 1])),
            lessThan(top(tester, runRow(order[i]))),
            reason: '${order[i - 1]} above ${order[i]}',
          );
        }
        // Completed runs are one collapsed row until tapped.
        expect(runRow('done-1'), findsNothing);
        expect(runRow('done-2'), findsNothing);
        final group = find.byKey(const ValueKey('team-home-completed-group'));
        expect(group, findsOneWidget);
        expect(find.text('Completed today (2)'), findsOneWidget);
        expect(top(tester, group), greaterThan(top(tester, runRow('wait-1'))));
        await tester.tap(group);
        await tester.pumpAndSettle();
        expect(runRow('done-1'), findsOneWidget);
        expect(runRow('done-2'), findsOneWidget);
        expect(
          top(tester, runRow('done-1')),
          lessThan(top(tester, runRow('done-2'))),
        );
        await tester.tap(group);
        await tester.pumpAndSettle();
        expect(runRow('done-1'), findsNothing);
        // Kind subtitles: batch says so, formula runs name the formula.
        expect(find.text('Batch · convoy · 1 of 4 done'), findsOneWidget);
        expect(find.text('Run · formula ship · 1 of 4 done'), findsNWidgets(5));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('filter chips reduce the rows', (tester) async {
      final (controller, _) = await boot(configure: mixedShape);
      await pumpHome(tester, controller);

      await tester.tap(find.byKey(const ValueKey('team-home-filter-active')));
      await tester.pumpAndSettle();
      expect(runRow('work-new'), findsOneWidget);
      expect(runRow('work-old'), findsOneWidget);
      expect(runRow('plan-1'), findsOneWidget);
      expect(runRow('blocked-1'), findsNothing);
      expect(runRow('wait-1'), findsNothing);
      expect(runRow('failed-1'), findsNothing);
      expect(
        find.byKey(const ValueKey('team-home-completed-group')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('team-home-filter-blocked')));
      await tester.pumpAndSettle();
      expect(runRow('failed-1'), findsOneWidget);
      expect(runRow('blocked-1'), findsOneWidget);
      expect(runRow('wait-1'), findsOneWidget);
      expect(runRow('work-new'), findsNothing);
      expect(runRow('plan-1'), findsNothing);

      // Completed lists the finished runs directly, no group.
      await tester.tap(
        find.byKey(const ValueKey('team-home-filter-completed')),
      );
      await tester.pumpAndSettle();
      expect(runRow('done-1'), findsOneWidget);
      expect(runRow('done-2'), findsOneWidget);
      expect(runRow('work-new'), findsNothing);
      expect(
        find.byKey(const ValueKey('team-home-completed-group')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('team-home-filter-all')));
      await tester.pumpAndSettle();
      expect(runRow('work-new'), findsOneWidget);
      expect(runRow('done-1'), findsNothing);
      expect(
        find.byKey(const ValueKey('team-home-completed-group')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('search filters by title and clears', (tester) async {
      final (controller, _) = await boot(configure: mixedShape);
      await pumpHome(tester, controller);

      await tester.enterText(
        find.byKey(const ValueKey('team-home-search')),
        'WORK-NEW',
      );
      await tester.pumpAndSettle();
      expect(runRow('work-new'), findsOneWidget);
      expect(runRow('work-old'), findsNothing);
      expect(runRow('failed-1'), findsNothing);
      expect(
        find.byKey(const ValueKey('team-home-completed-group')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const ValueKey('team-home-search')),
        'nothing like this',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('team-home-runs-empty-filtered')),
        findsOneWidget,
      );
      expect(find.text('No runs match.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('team-home-search-clear')));
      await tester.pumpAndSettle();
      expect(runRow('work-new'), findsOneWidget);
      expect(runRow('work-old'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('team-home-runs-empty-filtered')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('TEAM-117: work in the refinery\'s hands reads Waiting for '
        'merge', (tester) async {
      final (controller, _) = await boot(configure: handedToRefineryShape);
      await pumpHome(tester, controller);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('team-home-run-state-oc-xru')),
            )
            .data,
        'Waiting for merge',
      );
      expect(find.text('Waiting for an agent'), findsNothing);
      expect(find.text('Batch · convoy · 0 of 1 done'), findsOneWidget);
      expect(find.text('Needs you (0)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a gated run carries the needs-you marker', (tester) async {
      final (controller, _) = await boot(configure: blockedShape);
      await pumpHome(tester, controller);
      expect(find.text('Needs you (1)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('team-home-run-needs-you-oc-xru')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('team-home-run-state-oc-xru')),
            )
            .data,
        'Blocked',
      );
      expect(find.text('Batch · convoy · 1 of 2 done'), findsOneWidget);
    });

    testWidgets('no runs at all: the empty state', (tester) async {
      final (controller, _) = await boot(
        configure: (g) => g.runsOverride = const [],
      );
      await pumpHome(tester, controller);
      expect(
        find.byKey(const ValueKey('team-home-runs-empty')),
        findsOneWidget,
      );
      expect(find.text('No runs yet.'), findsOneWidget);
      expect(find.text('Start runs from the host for now.'), findsOneWidget);
      expect(find.text('Runs (0)'), findsOneWidget);
    });
  });

  group('host chip', () {
    testWidgets('names the server, version, city and access; opens details', (
      tester,
    ) async {
      // The read path alone: no control capability, so read-only.
      final (controller, _) = await boot(
        configure: (g) =>
            g.capabilitiesOverride = OrchestrationCapabilities.gascityRead,
      );
      await pumpHome(tester, controller);
      // The host is named by the team URL and the kind of computer, never
      // by the profile; a fixture path names no host, so the provider
      // stands in.
      expect(
        find.text(
          'fixture · Desktop computer · Gas City 1.4.1 · city bright-lights'
          ' · read-only',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Workstation'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('team-home-host-chip')));
      await tester.pumpAndSettle();
      final sheet = find.byKey(const ValueKey('team-home-host-sheet'));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('Technical details')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('fixture')),
        findsNWidgets(2),
        reason: 'identity row and raw value',
      );
      // The sheet still names the host by the profile's own address: the
      // chip's host name comes from the team URL, not from here.
      expect(
        find.descendant(of: sheet, matching: find.text('Workstation')),
        findsNothing,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('1.4.1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('bright-lights')),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Read-only')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('team-home-host-read-only')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Computer')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.textContaining('polecat')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a host with controls says so', (tester) async {
      // The fixture switches every capability on, controls included.
      final (controller, _) = await boot(url: 'https://pop-os:7000');
      await pumpHome(tester, controller);
      expect(
        find.text(
          'pop-os · Desktop computer · Gas City 1.4.1 · city bright-lights'
          ' · controls',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('team-home-host-chip')));
      await tester.pumpAndSettle();
      expect(find.text('Decisions and controls'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('team-home-host-read-only')),
        findsNothing,
      );
    });

    testWidgets('an address names the host by its IP (TEAM-115)', (
      tester,
    ) async {
      final (controller, _) = await boot(url: 'http://100.126.15.6:7000');
      await pumpHome(tester, controller);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('team-home-host-chip-label')),
            )
            .data,
        '100.126.15.6 · Desktop computer · Gas City 1.4.1 · '
        'city bright-lights · controls',
      );
      expect(find.textContaining('Workstation'), findsNothing);
    });

    testWidgets('a phone host is named with its kind word (TEAM-115)', (
      tester,
    ) async {
      final (controller, _) = await boot(
        hostMode: OrchestrationHostMode.phone,
        url: 'http://localhost:7000',
      );
      await pumpHome(tester, controller);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('team-home-host-chip-label')),
            )
            .data,
        startsWith('localhost · This phone · '),
      );
    });

    testWidgets('a phone host says so', (tester) async {
      final (controller, _) = await boot(hostMode: OrchestrationHostMode.phone);
      await pumpHome(tester, controller);
      await tester.tap(find.byKey(const ValueKey('team-home-host-chip')));
      await tester.pumpAndSettle();
      expect(find.text('This phone'), findsOneWidget);
    });
  });

  group('agents', () {
    testWidgets('lists the fleet with states, needs-you first', (tester) async {
      OrchestrationAgent? opened;
      final (controller, _) = await boot(
        configure: (g) => g.agentsOverride = [
          OrchestrationAgent(
            id: 'fox',
            name: 'fox',
            state: AgentState.working,
            pool: 'gastown.polecat',
            provider: 'opencode',
            currentWorkId: 'oc-loy',
            lastActivity: clock.subtract(const Duration(minutes: 12)),
          ),
          const OrchestrationAgent(
            id: 'bear',
            name: 'bear',
            state: AgentState.idle,
            pack: 'gastown',
          ),
          const OrchestrationAgent(
            id: 'wolf',
            name: 'wolf',
            state: AgentState.waiting,
            pool: 'gastown.polecat',
          ),
          const OrchestrationAgent(
            id: 'dog-1',
            name: 'dog-1',
            state: AgentState.stopped,
          ),
          const OrchestrationAgent(
            id: 'nova',
            name: 'nova',
            state: AgentState.crashed,
          ),
        ],
      );
      await pumpHome(tester, controller, onOpenAgent: (a) => opened = a);
      // Four live, the stopped dog counted apart (TEAM-115).
      expect(find.text('Agents (4 · 1 off)'), findsOneWidget);
      await segment(tester, 'agents');
      expect(find.byKey(const ValueKey('team-home-agents')), findsOneWidget);
      Finder row(String id) => find.byKey(ValueKey('team-home-agent-$id'));
      final order = ['wolf', 'nova', 'fox', 'bear'];
      for (var i = 1; i < order.length; i++) {
        expect(
          top(tester, row(order[i - 1])),
          lessThan(top(tester, row(order[i]))),
          reason: '${order[i - 1]} above ${order[i]}',
        );
      }
      expect(find.text('Waiting (needs input)'), findsOneWidget);
      expect(find.text('Crashed'), findsOneWidget);
      expect(find.text('Working'), findsOneWidget);
      expect(find.text('Idle'), findsOneWidget);
      expect(find.text('gastown.polecat · opencode'), findsOneWidget);
      // Fox works the fixture's sling bead; the others have no work.
      expect(find.textContaining('12m ago'), findsOneWidget);
      expect(find.text('No current work'), findsNWidgets(3));
      // The stopped dog sits under the collapsed group, below the live.
      final group = find.byKey(const ValueKey('team-home-suspended-group'));
      expect(group, findsOneWidget);
      expect(find.text('Suspended on the host (1)'), findsOneWidget);
      expect(row('dog-1'), findsNothing);
      expect(find.text('Stopped'), findsNothing);
      expect(top(tester, row('bear')), lessThan(top(tester, group)));
      await tester.tap(group);
      await tester.pumpAndSettle();
      expect(row('dog-1'), findsOneWidget);
      expect(find.text('Stopped'), findsOneWidget);
      expect(top(tester, group), lessThan(top(tester, row('dog-1'))));
      await tester.tap(group);
      await tester.pumpAndSettle();
      expect(row('dog-1'), findsNothing);

      await tester.tap(row('fox'));
      expect(opened?.id, 'fox');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the fixture fleet has one row per agent', (tester) async {
      final (controller, _) = await boot();
      await pumpHome(tester, controller);
      await segment(tester, 'agents');
      final rows = find.byWidgetPredicate(
        (w) => switch (w.key) {
          ValueKey<String>(:final value) =>
            value.startsWith('team-home-agent-') &&
                !value.startsWith('team-home-agent-state-'),
          _ => false,
        },
      );
      expect(rows, findsNWidgets(controller.snapshot.agents.length));
      expect(rows, findsNWidgets(5));
      expect(find.text('Working'), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('team-home-suspended-group')),
        findsNothing,
        reason: 'every recorded agent is live once the slots are dropped',
      );
    });

    testWidgets('no agents: the empty state', (tester) async {
      final (controller, _) = await boot(
        configure: (g) => g.agentsOverride = const [],
      );
      await pumpHome(tester, controller);
      await segment(tester, 'agents');
      expect(
        find.byKey(const ValueKey('team-home-agents-empty')),
        findsOneWidget,
      );
      expect(find.text('No agents on this host.'), findsOneWidget);
    });
  });

  group('needs you', () {
    testWidgets('lists the gate and opens the read-only sheet', (tester) async {
      // Without `controlRespond` the sheet stays Sprint A read-only; the
      // actions are TEAM-203's and tested in team_gate_answer_test.
      final (controller, _) = await boot(
        configure: (g) {
          blockedShape(g);
          g.capabilitiesOverride = OrchestrationCapabilities.gascityRead;
        },
      );
      await pumpHome(tester, controller);
      await segment(tester, 'needs-you');
      final gate = controller.snapshot.gates.single;
      final row = find.byKey(ValueKey('team-home-gate-${gate.id}'));
      expect(row, findsOneWidget);
      expect(find.text(gate.title), findsOneWidget);
      expect(
        find.text('Decision · Work Add subtract function to calc.py · 2m ago'),
        findsOneWidget,
      );

      await tester.tap(row);
      await tester.pumpAndSettle();
      final sheet = find.byKey(const ValueKey('team-gate-sheet'));
      expect(sheet, findsOneWidget);
      // The mapper titled the gate with its prompt: said once, not twice.
      expect(find.byKey(const ValueKey('team-gate-prompt')), findsNothing);
      expect(
        find.descendant(
          of: sheet,
          matching: find.text(
            'calc.py already defines subtract(). Replace it, keep it, or stop?',
          ),
        ),
        findsOneWidget,
      );
      for (final choice in ['replace', 'keep', 'stop']) {
        expect(
          find.descendant(of: sheet, matching: find.text(choice)),
          findsOneWidget,
        );
      }
      expect(
        find.text('Answer this on the host. The phone can only watch for now.'),
        findsOneWidget,
      );
      // Read-only: nothing to send.
      expect(find.byType(Radio<String>), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byKey(const ValueKey('team-gate-close')));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone host is named in the sheet', (tester) async {
      final (controller, _) = await boot(
        configure: (g) {
          blockedShape(g);
          g.capabilitiesOverride = OrchestrationCapabilities.gascityRead;
        },
        hostMode: OrchestrationHostMode.phone,
      );
      await pumpHome(tester, controller);
      await segment(tester, 'needs-you');
      await tester.tap(
        find.byKey(const ValueKey('team-home-gate-req-fixture-choice-1')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Answer this in the host on this phone. The app can only watch '
          'for now.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('ordered decision → run failed → review → gate', (
      tester,
    ) async {
      final (controller, _) = await boot(
        configure: (g) => g.gatesOverride = const [
          OrchestrationGate(
            id: 'gate',
            kind: GateKind.gateBead,
            title: 'Gate bead',
          ),
          OrchestrationGate(
            id: 'review',
            kind: GateKind.reviewReady,
            title: 'Review me',
          ),
          OrchestrationGate(
            id: 'failed',
            kind: GateKind.runFailed,
            title: 'Run failed',
            runId: 'oc-xru',
          ),
          OrchestrationGate(
            id: 'ask',
            kind: GateKind.freeText,
            title: 'Which branch?',
            prompt: 'main is frozen; dev has the fix.',
          ),
        ],
      );
      await pumpHome(tester, controller);
      // Review-ready is informational: three need the person.
      expect(find.text('Needs you (3)'), findsOneWidget);
      await segment(tester, 'needs-you');
      Finder row(String id) => find.byKey(ValueKey('team-home-gate-$id'));
      final order = ['ask', 'failed', 'review', 'gate'];
      for (var i = 1; i < order.length; i++) {
        expect(
          top(tester, row(order[i - 1])),
          lessThan(top(tester, row(order[i]))),
          reason: '${order[i - 1]} above ${order[i]}',
        );
      }
      expect(
        find.text('Run failed · Run Add subtract function to calc.py'),
        findsOneWidget,
      );
      // A prompt that differs from the title is shown under it.
      await tester.tap(row('ask'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('team-gate-prompt')))
            .data,
        'main is frozen; dev has the fix.',
      );
      expect(find.text('Which branch?'), findsNWidgets(2));
    });

    testWidgets('nothing waiting: the empty state', (tester) async {
      final (controller, _) = await boot();
      await pumpHome(tester, controller);
      await segment(tester, 'needs-you');
      expect(
        find.byKey(const ValueKey('team-home-needs-you-empty')),
        findsOneWidget,
      );
      expect(find.text('Nothing needs you right now.'), findsOneWidget);
    });
  });

  group('stale, refresh, loading, error', () {
    testWidgets('stale shows the time and the refresh button clears it', (
      tester,
    ) async {
      final (controller, gateway) = await boot();
      final refreshedAt = controller.lastRefreshedAt!;
      await pumpHome(tester, controller);
      expect(find.byKey(const ValueKey('team-home-stale')), findsNothing);

      clock = clock.add(const Duration(seconds: 61));
      await pumpHome(tester, controller);
      expect(find.byKey(const ValueKey('team-home-stale')), findsOneWidget);
      final time =
          MaterialLocalizations.of(
            tester.element(find.byType(TeamHomeScreen)),
          ).formatTimeOfDay(
            TimeOfDay.fromDateTime(refreshedAt.toLocal()),
            alwaysUse24HourFormat: true,
          );
      expect(
        find.text('Showing data from $time · host unreachable'),
        findsOneWidget,
      );

      final before = gateway.count('runs');
      await tester.tap(find.byKey(const ValueKey('team-home-refresh')));
      await tester.pumpAndSettle();
      expect(gateway.count('runs'), before + 1);
      expect(find.byKey(const ValueKey('team-home-stale')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pull-to-refresh calls refresh once', (tester) async {
      final (controller, gateway) = await boot();
      await pumpHome(tester, controller);
      final before = gateway.count('runs');
      // The indicator arms at a quarter of the (tall) viewport.
      await tester.drag(
        find.byKey(const ValueKey('team-home-runs')),
        const Offset(0, 900),
      );
      await tester.pump();
      // The indicator's arm, settle and hide animations.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(gateway.count('runs'), before + 1);
      // Pulling on the Agents list refreshes the same way.
      await segment(tester, 'agents');
      await tester.drag(
        find.byKey(const ValueKey('team-home-agents')),
        const Offset(0, 900),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(gateway.count('runs'), before + 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('before the probe answers: loading', (tester) async {
      final (controller, _) = await boot(started: false);
      await pumpHome(tester, controller);
      expect(find.byKey(const ValueKey('team-home-loading')), findsOneWidget);
      expect(find.byKey(const ValueKey('team-home-data')), findsNothing);
      expect(find.text('AI Team'), findsOneWidget);
    });

    testWidgets('a failed probe shows honest copy and Retry recovers', (
      tester,
    ) async {
      ProbeVerdict verdict = const ProbeUnreachable(error: 'refused');
      final (controller, gateway) = await boot(probe: (_) async => verdict);
      expect(controller.phase, OrchestrationPhase.failed);
      await pumpHome(tester, controller);
      expect(find.byKey(const ValueKey('team-home-error')), findsOneWidget);
      expect(
        find.text(
          'The team host can’t be reached. AI Team works over your Tailscale '
          'network or on this device.',
        ),
        findsOneWidget,
      );
      verdict = ProbeFound(host: gateway.host!, city: 'bright-lights');
      await tester.tap(find.byKey(const ValueKey('team-home-refresh')));
      await tester.pumpAndSettle();
      expect(controller.phase, OrchestrationPhase.ready);
      expect(find.byKey(const ValueKey('team-home-data')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('workspace wiring', () {
    testWidgets('the card follows Recent and precedes Archived', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (controller, _) = await boot();
      final connection = _Connection(ProfileStore(prefs: prefs))
        ..team = controller;
      addTearDown(connection.dispose);
      connection.sessionsById = {
        'recent': Session(
          id: 'recent',
          title: 'recent conversation',
          time: SessionTime(created: 1, updated: 5),
        ),
        'old': Session(
          id: 'old',
          title: 'old conversation',
          time: SessionTime(created: 1, updated: 2, archived: 3),
        ),
      };
      await tester.pumpWidget(
        app(Scaffold(body: WorkspaceScreen(controller: connection))),
      );
      await tester.pumpAndSettle();

      // UX plan 5.5 and 5.7: the person's own conversations come first.
      double top(Finder finder) => tester.getTopLeft(finder).dy;
      final card = find.byType(TeamCard);
      expect(card, findsOneWidget);
      expect(top(card), greaterThan(top(find.text('Recent conversations'))));
      expect(top(card), greaterThan(top(find.text('recent conversation'))));
      expect(top(card), lessThan(top(find.text('Archived conversations'))));
    });

    testWidgets('Open on the card pushes the home', (tester) async {
      final (controller, _) = await boot();
      final connection = _Connection(ProfileStore(prefs: prefs))
        ..team = controller;
      addTearDown(connection.dispose);
      await tester.pumpWidget(app(WorkspaceScreen(controller: connection)));
      await tester.pumpAndSettle();
      expect(find.byType(TeamHomeScreen), findsNothing);
      // The card follows the person's own conversations (UX plan 5.7).
      await tester.ensureVisible(find.byKey(const ValueKey('team-card-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('team-card-open')));
      await tester.pumpAndSettle();
      expect(find.byType(TeamHomeScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('team-home-data')), findsOneWidget);
      expect(find.text('Runs (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // TEAM-115: the host's internals stay out of the counts and lists.
  group('upkeep and suspended (TEAM-115)', () {
    OrchestrationRun upkeep(String name, RunState state, int minutesAgo) =>
        OrchestrationRun(
          id: 'oc-wisp-$name',
          title: 'mol-$name-patrol',
          state: state,
          kind: RunKind.formula,
          isUpkeep: true,
          updatedAt: clock.subtract(Duration(minutes: minutesAgo)),
        );

    testWidgets('upkeep runs are hidden and uncounted until revealed', (
      tester,
    ) async {
      OrchestrationRun? opened;
      final (controller, _) = await boot(
        configure: (g) => g
          ..workOverride = const []
          ..gatesOverride = const []
          ..runsOverride = [
            upkeep('refinery', RunState.planning, 1),
            upkeep('deacon', RunState.planning, 2),
            upkeep('witness', RunState.completed, 3),
            run('mine', RunState.working, 4),
            run('done', RunState.completed, 5),
          ],
      );
      await pumpHome(tester, controller, onOpenRun: (r) => opened = r);
      expect(find.text('Runs (2)'), findsOneWidget);
      expect(runRow('mine'), findsOneWidget);
      expect(find.textContaining('mol-'), findsNothing);
      for (final name in ['refinery', 'deacon', 'witness']) {
        expect(runRow('oc-wisp-$name'), findsNothing);
      }
      // The completed group counts the person's run only.
      expect(find.text('Completed today (1)'), findsOneWidget);

      // The toggle sits under the list, off, with the hidden count.
      final toggle = find.byKey(const ValueKey('team-home-upkeep-toggle'));
      expect(toggle, findsOneWidget);
      expect(find.text('Show team upkeep (3)'), findsOneWidget);
      expect(
        top(tester, find.byKey(const ValueKey('team-home-completed-group'))),
        lessThan(top(tester, toggle)),
      );
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      for (final name in ['refinery', 'deacon', 'witness']) {
        expect(runRow('oc-wisp-$name'), findsOneWidget);
        expect(
          top(tester, toggle),
          lessThan(top(tester, runRow('oc-wisp-$name'))),
        );
      }
      expect(find.text('mol-refinery-patrol'), findsOneWidget);
      // Counts do not move when upkeep is revealed.
      expect(find.text('Runs (2)'), findsOneWidget);
      // A revealed upkeep run opens like any other.
      await tester.tap(runRow('oc-wisp-refinery'));
      expect(opened?.id, 'oc-wisp-refinery');

      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(runRow('oc-wisp-refinery'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('only upkeep: the empty state, with the toggle', (
      tester,
    ) async {
      final (controller, _) = await boot(
        configure: (g) => g
          ..workOverride = const []
          ..gatesOverride = const []
          ..runsOverride = [upkeep('refinery', RunState.planning, 1)],
      );
      await pumpHome(tester, controller);
      expect(find.text('Runs (0)'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('team-home-runs-empty')),
        findsOneWidget,
      );
      final toggle = find.byKey(const ValueKey('team-home-upkeep-toggle'));
      expect(find.text('Show team upkeep (1)'), findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(runRow('oc-wisp-refinery'), findsOneWidget);
    });

    testWidgets('suspended agents count apart and sit collapsed', (
      tester,
    ) async {
      final (controller, _) = await boot(
        configure: (g) => g.agentsOverride = const [
          OrchestrationAgent(
            id: 'ocproof/gastown.refinery',
            name: 'ocproof/gastown.refinery',
            state: AgentState.idle,
          ),
          OrchestrationAgent(
            id: 'gastown.boot',
            name: 'gastown.boot',
            state: AgentState.stopped,
            suspended: true,
          ),
          OrchestrationAgent(
            id: 'gastown.deacon',
            name: 'gastown.deacon',
            state: AgentState.stopped,
            suspended: true,
          ),
          OrchestrationAgent(
            id: 'gastown.mayor',
            name: 'gastown.mayor',
            state: AgentState.stopped,
            suspended: true,
          ),
          OrchestrationAgent(
            id: 'ocproof/gastown.witness',
            name: 'ocproof/gastown.witness',
            state: AgentState.stopped,
          ),
        ],
      );
      await pumpHome(tester, controller);
      expect(find.text('Agents (1 · 4 off)'), findsOneWidget);
      await segment(tester, 'agents');
      Finder row(String id) => find.byKey(ValueKey('team-home-agent-$id'));
      expect(row('ocproof/gastown.refinery'), findsOneWidget);
      expect(find.text('Suspended on the host (4)'), findsOneWidget);
      for (final off in [
        'gastown.boot',
        'gastown.deacon',
        'gastown.mayor',
        'ocproof/gastown.witness',
      ]) {
        expect(row(off), findsNothing);
      }
      await tester.tap(find.byKey(const ValueKey('team-home-suspended-group')));
      await tester.pumpAndSettle();
      expect(row('gastown.boot'), findsOneWidget);
      expect(row('ocproof/gastown.witness'), findsOneWidget);
      expect(find.text('Stopped'), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });
  });

  group('Arabic', () {
    testWidgets('the home reads in Arabic with identifiers LTR', (
      tester,
    ) async {
      final (controller, _) = await boot(configure: blockedShape);
      await tester.pumpWidget(
        app(
          TeamHomeScreen(controller: controller, now: () => clock),
          locale: const Locale('ar'),
        ),
      );
      await tester.pump();
      expect(find.text('فريق الذكاء الاصطناعي'), findsOneWidget);
      expect(find.text('التشغيلات (1)'), findsOneWidget);
      expect(find.text('يحتاجك (1)'), findsOneWidget);
      expect(
        find.text(
          'fixture · حاسوب مكتبي · Gas City 1.4.1 · المدينة bright-lights'
          ' · تحكّم',
        ),
        findsOneWidget,
      );
      expect(find.text('دفعة · convoy · اكتمل 1 من 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
