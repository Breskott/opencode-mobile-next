// TEAM-108: the AI Team home at 320dp × 2.5x text, LTR and RTL, English
// and Arabic: the host chip, the three segments (each with a busy list),
// the Technical details sheet and the read-only gate sheet all fit, and
// nothing overflows or scrolls sideways. At this text size the segments
// and the run filters are each one labelled menu button (stable home fix,
// 2026-09-13; test/team_home_stable_layout_test.dart covers normal text).

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

  Future<void> reveal(WidgetTester tester, Finder target) async {
    await Scrollable.ensureVisible(tester.element(target), alignment: .5);
    await tester.pump();
    expect(target.hitTestable(), findsOneWidget);
  }

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

  /// At 2.5x the three segments are one menu button (stable home,
  /// 2026-09-13): open it and pick the section; nothing scrolls sideways.
  Future<void> segment(WidgetTester tester, String name) async {
    expect(find.byKey(const ValueKey('team-home-segments')), findsNothing);
    final menu = find.byKey(const ValueKey('team-home-segments-menu'));
    expect(menu.hitTestable(), findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final item = find.byKey(ValueKey('team-home-segment-$name'));
    expect(item.hitTestable(), findsOneWidget);
    await tester.tap(item);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  /// The filter menu button in the Runs list, scrolled into view.
  Future<Finder> filterMenu(WidgetTester tester) async {
    final menu = find.byKey(const ValueKey('team-home-filter-menu'));
    await revealIn(tester, 'team-home-runs', menu, up: true);
    return menu;
  }

  for (final direction in TextDirection.values) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      final tag = '${direction.name} ${locale.languageCode}';
      final l10n = lookupAppLocalizations(locale);

      testWidgets('320dp 2.5x $tag: the three segments fit', (tester) async {
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

        // Runs: the blocked convoy with its needs-you marker, the open
        // runs and the collapsed completed group.
        expect(
          find.byKey(const ValueKey('team-home-run-oc-xru')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('team-home-run-needs-you-oc-xru')),
          findsOneWidget,
        );
        final group = find.byKey(const ValueKey('team-home-completed-group'));
        await revealIn(tester, 'team-home-runs', group);
        await tester.tap(group);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final done = find.byKey(const ValueKey('team-home-run-r5'));
        await revealIn(tester, 'team-home-runs', done);
        // Filters: one labelled menu at large text, never four stacked
        // chips; the chosen filter reads on the button.
        expect(find.byType(ChoiceChip), findsNothing);
        final filters = await filterMenu(tester);
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
        expect(
          find.byKey(const ValueKey('team-home-run-oc-xru')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('team-home-run-r3')), findsNothing);

        // The host chip wraps its long line and opens Technical details.
        final chip = find.byKey(const ValueKey('team-home-host-chip'));
        await reveal(tester, chip);
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final sheet = find.byKey(const ValueKey('team-home-host-sheet'));
        expect(sheet, findsOneWidget);
        expect(
          find.descendant(of: sheet, matching: find.text('1.4.1')),
          findsOneWidget,
        );
        // Read-only: no buttons of its own; dismiss it like a swipe would.
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);

        // Agents: every live row with its state word, then the stopped
        // dog under the collapsed "Suspended on the host" group (TEAM-115).
        await segment(tester, 'agents');
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

        // Needs you: both gates; the read-only sheet scrolls and closes.
        await segment(tester, 'needs-you');
        final gate = find.byKey(const ValueKey('team-home-gate-g1'));
        await revealIn(
          tester,
          'team-home-needs-you',
          find.byKey(const ValueKey('team-home-gate-g2')),
        );
        await revealIn(tester, 'team-home-needs-you', gate, up: true);
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
        expect(tester.takeException(), isNull);

        // Back to Runs: the filter held and the search field stays usable.
        await segment(tester, 'runs');
        expect(
          find.descendant(
            of: await filterMenu(tester),
            matching: find.text(l10n.teamUiHomeFilterBlocked),
          ),
          findsOneWidget,
          reason: 'still blocked',
        );
        final search = find.byKey(const ValueKey('team-home-search'));
        await revealIn(tester, 'team-home-runs', search);
        await tester.enterText(search, 'Sync');
        await tester.pumpAndSettle();
        // r2 carries the failed-run gate, so it counts as blocked and
        // matches the search; the convoy's title does not.
        expect(find.byKey(const ValueKey('team-home-run-r2')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('team-home-run-oc-xru')),
          findsNothing,
        );
        final clear = find.byKey(const ValueKey('team-home-search-clear'));
        await revealIn(tester, 'team-home-runs', clear, up: true);
        await tester.tap(clear);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('team-home-run-oc-xru')),
          findsOneWidget,
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
        await segment(tester, 'agents');
        expect(
          find.byKey(const ValueKey('team-home-agents-empty')),
          findsOneWidget,
        );
        await segment(tester, 'needs-you');
        expect(
          find.byKey(const ValueKey('team-home-needs-you-empty')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

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
