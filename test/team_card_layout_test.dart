// TEAM-107: the Workspace AI Team card at 320dp × 2.5x text, LTR and RTL,
// English and Arabic, in its normal, blocked, stale, empty and error
// states: nothing overflows and every action stays reachable.

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

/// The fixture with the runs, work and gates a scenario needs.
class _Gateway implements OrchestrationGateway {
  _Gateway(this.inner);

  final FixtureOrchestrationGateway inner;
  final stream = StreamController<OrchestrationEvent>.broadcast();
  List<OrchestrationRun>? runsOverride;
  List<WorkItem>? workOverride;
  List<OrchestrationGate>? gatesOverride;

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
  Future<List<OrchestrationAgent>> agents() => inner.agents();
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
    clock = DateTime.utc(2026, 9, 11, 9, 41);
  });

  Future<(OrchestrationController, _Gateway)> boot({
    OrchestrationProbe? probe,
    void Function(_Gateway gateway)? configure,
  }) async {
    final gateway = _Gateway(
      FixtureOrchestrationGateway(fixturePath: fixturePath),
    );
    configure?.call(gateway);
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
      probe: probe,
      now: () => clock,
    );
    addTearDown(controller.dispose);
    await controller.start();
    return (controller, gateway);
  }

  /// A blocked convoy with a gate, a done step and a working step, three
  /// more open runs and one completed, so every row kind renders.
  void busyShape(_Gateway gateway) {
    OrchestrationRun run(String id, String title, RunState state) =>
        OrchestrationRun(
          id: id,
          title: title,
          state: state,
          kind: RunKind.formula,
          stepCount: 4,
          completedSteps: 1,
          updatedAt: clock,
        );
    gateway
      ..runsOverride = [
        const OrchestrationRun(
          id: 'oc-xru',
          title: 'Offline-first sessions with a deliberately long title',
          state: RunState.blocked,
          kind: RunKind.batch,
          stepCount: 3,
          completedSteps: 1,
        ),
        run('r2', 'Sync engine retry handling', RunState.working),
        run('r3', 'Android background handoff', RunState.planning),
        run('r4', 'Database tests', RunState.waiting),
        run('r5', 'Release notes', RunState.completed),
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
        ),
      ]
      ..gatesOverride = const [
        OrchestrationGate(
          id: 'g1',
          kind: GateKind.choice,
          title: 'Choose an option',
          workId: 'w3',
          runId: 'oc-xru',
        ),
      ];
  }

  Widget app(Widget card, TextDirection direction, Locale locale) =>
      MaterialApp(
        theme: AppTheme.dark(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2.5),
            disableAnimations: true,
          ),
          child: Directionality(textDirection: direction, child: child!),
        ),
        home: Scaffold(body: SingleChildScrollView(child: card)),
      );

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await tester.ensureVisible(target);
    await tester.pump();
    expect(target.hitTestable(), findsOneWidget);
  }

  for (final direction in TextDirection.values) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      final tag = '${direction.name} ${locale.languageCode}';

      testWidgets('320dp 2.5x $tag: busy card fits and actions work', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var opened = 0;
        final (controller, _) = await boot(configure: busyShape);
        await tester.pumpWidget(
          app(
            TeamCard(controller: controller, onOpen: () => opened += 1),
            direction,
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(find.byKey(const ValueKey('team-card-data')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('team-card-needs-you')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('team-card-bar-blocked')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('team-card-run-oc-xru')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('team-card-completed-runs')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('team-card-more-runs')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('team-card-constellation')),
          findsOneWidget,
        );
        // The Gas City identifier stays LTR in Arabic; the title translates.
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('team-card-city')))
              .textDirection,
          TextDirection.ltr,
        );
        if (locale.languageCode == 'ar') {
          expect(find.text('فريق الذكاء الاصطناعي · Gas City'), findsOneWidget);
          expect(find.text('اكتمل 33٪.'), findsOneWidget);
        } else {
          expect(find.text('AI Team · Gas City'), findsOneWidget);
          expect(find.text('33% done.'), findsOneWidget);
        }
        // The card never scrolls sideways: it is as wide as the screen.
        expect(tester.getSize(find.byType(TeamCard)).width, 320);

        final open = find.byKey(const ValueKey('team-card-open'));
        await reveal(tester, open);
        await tester.tap(open);
        expect(opened, 1);
        final refresh = find.byKey(const ValueKey('team-card-refresh'));
        await reveal(tester, refresh);
        await tester.tap(refresh);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('320dp 2.5x $tag: stale, empty and error states fit', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Stale.
        final (stale, _) = await boot(configure: busyShape);
        clock = clock.add(const Duration(minutes: 5));
        await tester.pumpWidget(
          app(TeamCard(controller: stale, onOpen: () {}), direction, locale),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('team-card-stale')), findsOneWidget);
        expect(tester.getSize(find.byType(TeamCard)).width, 320);
        expect(tester.takeException(), isNull);

        // Empty.
        final (empty, _) = await boot(
          configure: (g) => g.runsOverride = const [],
        );
        await tester.pumpWidget(
          app(TeamCard(controller: empty, onOpen: () {}), direction, locale),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('team-card-empty')), findsOneWidget);
        await reveal(tester, find.byKey(const ValueKey('team-card-refresh')));
        expect(tester.takeException(), isNull);

        // Error.
        final (error, _) = await boot(
          probe: (_) async => const ProbePlainHttpRefused(host: 'example.com'),
        );
        await tester.pumpWidget(
          app(TeamCard(controller: error, onOpen: () {}), direction, locale),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('team-card-error')), findsOneWidget);
        await reveal(tester, find.byKey(const ValueKey('team-card-retry')));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
