// TEAM-108: the AI Team home at 320dp × 2.5x text, LTR and RTL, English
// and Arabic: the questions, the tasks, search and the filter menu (past
// eight tasks), the Technical details sheet, the agents list and the
// read-only gate sheet all fit, and nothing overflows or scrolls sideways
// (AI Team redesign, 2026-09-24).

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

/// The fixture with the runs, work, agents and gates a scenario needs.
class _Gateway implements OrchestrationGateway {
  _Gateway(this.inner);

  final FixtureOrchestrationGateway inner;
  final stream = StreamController<OrchestrationEvent>.broadcast();
  List<OrchestrationRun>? runsOverride;
  List<WorkItem>? workOverride;
  List<OrchestrationAgent>? agentsOverride;
  List<OrchestrationGate>? gatesOverride;

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
    clock = DateTime.utc(2026, 9, 11, 9, 41);
  });

  Future<(OrchestrationController, _Gateway)> boot({
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
        name: 'Development PC',
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

  /// A blocked convoy with a gate, working and planning runs, one
  /// completed, three agents in different states and two gates, so every
  /// row kind renders in every segment.
  void busyShape(_Gateway gateway) {
    OrchestrationRun run(String id, String title, RunState state) =>
        OrchestrationRun(
          id: id,
          title: title,
          state: state,
          kind: RunKind.formula,
          formula: 'ship',
          stepCount: 4,
          completedSteps: 1,
          updatedAt: clock,
        );
    gateway
      ..runsOverride = [
        OrchestrationRun(
          id: 'oc-xru',
          title: 'Offline-first sessions with a deliberately long title',
          state: RunState.blocked,
          kind: RunKind.batch,
          stepCount: 3,
          completedSteps: 1,
          updatedAt: clock,
        ),
        run('r2', 'Sync engine retry handling', RunState.working),
        run('r3', 'Android background handoff', RunState.planning),
        run('r4', 'Database tests', RunState.waiting),
        run('r5', 'Release notes', RunState.completed),
        // Past eight tasks the home offers search and the filter menu.
        run('r6', 'Crash reporter opt-in', RunState.working),
        run('r7', 'Widget text scaling', RunState.working),
        run('r8', 'Deep link routing', RunState.waiting),
        run('r9', 'Settings search index', RunState.waiting),
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
      ..agentsOverride = [
        OrchestrationAgent(
          id: 'fox',
          name: 'fox',
          state: AgentState.working,
          pool: 'gastown.polecat',
          provider: 'opencode',
          currentWorkId: 'w2',
          lastActivity: clock.subtract(const Duration(minutes: 12)),
        ),
        const OrchestrationAgent(
          id: 'wolf',
          name: 'wolf',
          state: AgentState.waiting,
          pool: 'gastown.polecat',
          provider: 'opencode',
          currentWorkId: 'w3',
        ),
        const OrchestrationAgent(
          id: 'dog-1',
          name: 'dog-1',
          state: AgentState.stopped,
          pack: 'gastown',
        ),
      ]
      ..gatesOverride = [
        OrchestrationGate(
          id: 'g1',
          kind: GateKind.choice,
          title: 'Which persistence strategy?',
          prompt:
              'This choice controls how the tests store and verify data. '
              'Pick one and the agent continues.',
          workId: 'w3',
          runId: 'oc-xru',
          agentId: 'wolf',
          choices: const ['SQLite', 'Filesystem', 'Server-only'],
          createdAt: clock.subtract(const Duration(minutes: 2)),
        ),
        const OrchestrationGate(
          id: 'g2',
          kind: GateKind.runFailed,
          title: 'Run failed: 2 tests failing',
          runId: 'r2',
        ),
      ];
  }

  Widget app(Widget home, TextDirection direction, Locale locale) =>
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
        home: home,
      );

  /// Lists build lazily: scroll the segment's list until [target] exists
  /// and is tappable.
  Future<void> revealIn(
    WidgetTester tester,
    String list,
    Finder target, {
    bool up = false,
  }) async {
    await tester.scrollUntilVisible(
      target,
      up ? -120 : 120,
      // The list's own Scrollable; the search field carries another.
      scrollable: find
          .descendant(
            of: find.byKey(ValueKey(list)),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(target.hitTestable(), findsOneWidget);
  }

  /// Opens search from the top bar, and returns the filter menu button.
  Future<Finder> openSearch(WidgetTester tester) async {
    final open = find.byKey(const ValueKey('team-home-search-open'));
    expect(open.hitTestable(), findsOneWidget);
    await tester.tap(open);
    await tester.pumpAndSettle();
    final menu = find.byKey(const ValueKey('team-home-filter-menu'));
    await revealIn(tester, 'team-home-runs', menu, up: true);
    return menu;
  }

  for (final direction in TextDirection.values) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      final tag = '${direction.name} ${locale.languageCode}';
      final l10n = lookupAppLocalizations(locale);

      testWidgets('320dp 2.5x $tag: the home, search and sheets fit', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final (controller, _) = await boot(configure: busyShape);
        await tester.pumpWidget(
          app(
            TeamHomeScreen(controller: controller, now: () => clock),
            direction,
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('team-home-data')), findsOneWidget);
        // The screen is as wide as the display: nothing pushes it sideways.
        expect(
          tester.getSize(find.byKey(const ValueKey('team-home'))).width,
          320,
        );

        // Needs you: two questions are rows, first; the read-only sheet
        // scrolls and closes.
        final gate = find.byKey(const ValueKey('team-home-gate-g1'));
        await revealIn(
          tester,
          'team-home-runs',
          find.byKey(const ValueKey('team-home-gate-g2')),
        );
        await revealIn(tester, 'team-home-runs', gate, up: true);
        await tester.tap(gate);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final gateSheet = find.byKey(const ValueKey('team-gate-sheet'));
        expect(gateSheet, findsOneWidget);
        expect(
          find.descendant(of: gateSheet, matching: find.text('SQLite')),
          findsOneWidget,
        );
        final close = find.byKey(const ValueKey('team-gate-close'));
        await tester.scrollUntilVisible(
          close,
          200,
          scrollable: find.descendant(
            of: gateSheet,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(gateSheet, findsNothing);

        // Tasks, then what finished.
        for (final id in ['oc-xru', 'r2', 'r3', 'r4', 'r5']) {
          await revealIn(
            tester,
            'team-home-runs',
            find.byKey(ValueKey('team-home-run-$id')),
          );
        }
        expect(tester.takeException(), isNull);

        // Search and the filter menu: a labelled menu, never chips; the
        // chosen filter reads on the button.
        await revealIn(
          tester,
          'team-home-runs',
          find.byKey(const ValueKey('team-home-run-oc-xru')),
          up: true,
        );
        final filters = await openSearch(tester);
        expect(find.byType(ChoiceChip), findsNothing);
        await tester.tap(filters);
        await tester.pumpAndSettle();
        final blocked = find.byKey(const ValueKey('team-home-filter-blocked'));
        expect(blocked.hitTestable(), findsOneWidget);
        await tester.tap(blocked);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(blocked, findsNothing, reason: 'menu closed');
        expect(
          find.descendant(
            of: filters,
            matching: find.text(l10n.teamUiHomeFilterBlocked),
          ),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('team-home-run-r3')), findsNothing);
        final search = find.byKey(const ValueKey('team-home-search'));
        await revealIn(tester, 'team-home-runs', search, up: true);
        await tester.enterText(search, 'Sync');
        await tester.pumpAndSettle();
        // r2 carries the failed-run gate, so it counts as blocked and
        // matches the search; the convoy's title does not. The questions
        // sit above the tasks, so the row is scrolled to.
        await revealIn(
          tester,
          'team-home-runs',
          find.byKey(const ValueKey('team-home-run-r2')),
        );
        expect(
          find.byKey(const ValueKey('team-home-run-oc-xru')),
          findsNothing,
        );
        final clear = find.byKey(const ValueKey('team-home-search-clear'));
        await revealIn(tester, 'team-home-runs', clear, up: true);
        await tester.tap(clear);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Technical details behind the info button.
        await tester.tap(find.byKey(const ValueKey('team-home-info')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final sheet = find.byKey(const ValueKey('team-home-host-sheet'));
        expect(sheet, findsOneWidget);
        expect(
          find.descendant(of: sheet, matching: find.text('1.4.1')),
          findsOneWidget,
        );
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);

        // Agents: one row on the home opens the list; every live row, then
        // the stopped dog under the collapsed group (TEAM-115).
        final agentsRow = find.byKey(const ValueKey('team-home-agents-row'));
        await revealIn(tester, 'team-home-runs', agentsRow);
        await tester.tap(agentsRow);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final id in ['wolf', 'fox']) {
          await revealIn(
            tester,
            'team-home-agents',
            find.byKey(ValueKey('team-home-agent-$id')),
          );
        }
        final suspended = find.byKey(
          const ValueKey('team-home-suspended-group'),
        );
        await revealIn(tester, 'team-home-agents', suspended);
        expect(
          find.byKey(const ValueKey('team-home-agent-dog-1')),
          findsNothing,
        );
        await tester.tap(suspended);
        await tester.pumpAndSettle();
        await revealIn(
          tester,
          'team-home-agents',
          find.byKey(const ValueKey('team-home-agent-dog-1')),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('320dp 2.5x $tag: stale, empty, loading and error fit', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Stale.
        final (stale, _) = await boot(configure: busyShape);
        clock = clock.add(const Duration(minutes: 5));
        expect(stale.isStale, isTrue);
        await tester.pumpWidget(
          app(
            TeamHomeScreen(controller: stale, now: () => clock),
            direction,
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('team-home-stale')), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Empty in every segment.
        final (empty, _) = await boot(
          configure: (g) => g
            ..runsOverride = const []
            ..agentsOverride = const []
            ..gatesOverride = const [],
        );
        await tester.pumpWidget(
          app(
            TeamHomeScreen(controller: empty, now: () => clock),
            direction,
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('team-home-runs-empty')),
          findsOneWidget,
        );
        // Nothing waits on the person: no section, not an empty one.
        expect(find.byKey(const ValueKey('team-home-needs-you')), findsNothing);
        // The empty board's drawing has room now (team-discover-2026-09-25):
        // at 2.5x text the agents row is further down the list.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('team-home-agents-row')),
          200,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('team-home-runs')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('team-home-agents-row')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('team-home-agents-row')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('team-home-agents-empty')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        // Back to the home, so the next scene starts on it.
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();

        // Loading: a controller that has not started.
        final config = OrchestrationConfig(
          provider: OrchestrationProvider.fixture,
          url: fixturePath,
          enabledAt: DateTime.utc(2026, 9, 10),
        );
        final idle = OrchestrationController(
          profile: ServerProfile(
            id: 'srv-2',
            name: 'Laptop',
            baseUrl: 'https://laptop.example:4096',
            orchestration: config,
          ),
          config: config,
          store: store,
          gatewayFactory: (_, _) =>
              _Gateway(FixtureOrchestrationGateway(fixturePath: fixturePath)),
          now: () => clock,
        );
        addTearDown(idle.dispose);
        await tester.pumpWidget(
          app(
            TeamHomeScreen(controller: idle, now: () => clock),
            direction,
            locale,
          ),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('team-home-loading')), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Error: the probe says the host is unreachable.
        final failed = OrchestrationController(
          profile: ServerProfile(
            id: 'srv-3',
            name: 'Laptop',
            baseUrl: 'https://laptop.example:4096',
            orchestration: config,
          ),
          config: config,
          store: store,
          gatewayFactory: (_, _) =>
              _Gateway(FixtureOrchestrationGateway(fixturePath: fixturePath)),
          probe: (_) async => const ProbeUnreachable(error: 'refused'),
          now: () => clock,
        );
        addTearDown(failed.dispose);
        await failed.start();
        await tester.pumpWidget(
          app(
            TeamHomeScreen(controller: failed, now: () => clock),
            direction,
            locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('team-home-error')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
