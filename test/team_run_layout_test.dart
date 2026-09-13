// TEAM-109: the run detail at 320dp × 2.5x text, LTR and RTL, English and
// Arabic: the two-line app bar, the Overview's six elements, the Technical
// details sheet, the Timeline with its filter chips and the jump-to-latest
// pill, and the missing-run state all fit, and nothing overflows or
// scrolls sideways.

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
import 'package:opencode_mobile/ui/screens/team/run_screen.dart';
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

/// The fixture with the runs, work, agents and gates a scenario needs and
/// an owned event stream.
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

  /// A blocked convoy with a long title, one item done, one working, one
  /// blocked with a long reason, an agent on it and a decision gate: every
  /// Overview element renders at once.
  void busyShape(_Gateway gateway) {
    gateway
      ..runsOverride = [
        OrchestrationRun(
          id: 'oc-xru',
          title: 'Offline-first sessions with a deliberately long title',
          state: RunState.blocked,
          rawState: 'open',
          kind: RunKind.batch,
          stepCount: 3,
          completedSteps: 1,
          startedAt: clock.subtract(const Duration(hours: 3, minutes: 14)),
          updatedAt: clock,
          raw: const {
            'id': 'oc-xru',
            'issue_type': 'convoy',
            'metadata': {'rig': 'ocproof'},
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
          title: 'Conflict policy for concurrent edits',
          state: WorkState.blocked,
          runId: 'oc-xru',
          isBlocked: true,
          raw: {
            'metadata': {
              'last_error':
                  'Tests failed: 2 of 18 in test_sync_conflicts.py '
                  'after the merge',
            },
          },
        ),
      ]
      ..agentsOverride = const [
        OrchestrationAgent(
          id: 'wolf',
          name: 'wolf',
          state: AgentState.waiting,
          sessionId: 's-wolf',
          currentWorkId: 'w3',
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
          agentId: 's-wolf',
          choices: const ['SQLite', 'Filesystem', 'Server-only'],
          createdAt: clock.subtract(const Duration(minutes: 2)),
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

  Future<void> pumpRun(
    WidgetTester tester,
    OrchestrationController controller,
    String runId,
    TextDirection direction,
    Locale locale,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      app(
        RunScreen(controller: controller, runId: runId, now: () => clock),
        direction,
        locale,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const ValueKey('team-run'))).width, 320);
  }

  /// Lists build lazily: scroll [list] until [target] exists and is on
  /// screen (tappable when [tap]; a block taller than the viewport only
  /// needs to be in view).
  Future<void> revealIn(
    WidgetTester tester,
    String list,
    Finder target, {
    bool up = false,
    bool tap = true,
  }) async {
    await tester.scrollUntilVisible(
      target,
      up ? -120 : 120,
      scrollable: find
          .descendant(
            of: find.byKey(ValueKey(list)),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    if (tap) {
      expect(target.hitTestable(), findsOneWidget);
      return;
    }
    expect(target, findsOneWidget);
    final rect = tester.getRect(target);
    expect(rect.top, lessThan(740));
    expect(rect.bottom, greaterThan(0));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
  }

  /// The tab bar scrolls sideways at this text size.
  Future<void> tab(WidgetTester tester, String name) async {
    final target = find.byKey(ValueKey('team-run-tab-$name'));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> push(
    WidgetTester tester,
    _Gateway gateway,
    OrchestrationEvent event,
  ) async {
    gateway.stream.add(event);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final direction in TextDirection.values) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      final tag = '${direction.name} ${locale.languageCode}';

      testWidgets('320dp 2.5x $tag: the Overview and its details fit', (
        tester,
      ) async {
        final (controller, _) = await boot(configure: busyShape);
        await pumpRun(tester, controller, 'oc-xru', direction, locale);
        expect(find.byKey(const ValueKey('team-run-data')), findsOneWidget);
        expect(find.byKey(const ValueKey('team-run-term')), findsOneWidget);

        for (final name in const [
          'team-run-objective',
          'team-run-progress',
          'team-run-counts',
          'team-run-blocked',
          'team-run-needs-you',
          'team-run-batch',
        ]) {
          await revealIn(
            tester,
            'team-run-overview',
            find.byKey(ValueKey(name)),
            tap: false,
          );
        }
        expect(tester.takeException(), isNull);

        // Details: the sheet scrolls; ids stay LTR.
        await tester.tap(find.byKey(const ValueKey('team-run-details')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final sheet = find.byKey(const ValueKey('team-run-details-sheet'));
        expect(sheet, findsOneWidget);
        final id = find.descendant(of: sheet, matching: find.text('oc-xru'));
        await tester.scrollUntilVisible(
          id,
          120,
          scrollable: find
              .descendant(of: sheet, matching: find.byType(Scrollable))
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<EditableText>(id).textDirection,
          TextDirection.ltr,
        );
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pumpAndSettle();
        expect(sheet, findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('320dp 2.5x $tag: the Timeline, its chips and pill fit', (
        tester,
      ) async {
        final (controller, gateway) = await boot(configure: busyShape);
        await pumpRun(tester, controller, 'oc-xru', direction, locale);
        await tab(tester, 'timeline');
        expect(
          find.byKey(const ValueKey('team-run-timeline-empty')),
          findsOneWidget,
        );
        for (var seq = 1; seq <= 12; seq++) {
          gateway.stream.add(
            seq.isEven
                ? BeadChanged(
                    beadId: 'w3',
                    change: BeadChange.updated,
                    seq: 5000 + seq,
                    raw: {'ts': clock.toIso8601String()},
                  )
                : SessionChanged(
                    sessionId: 's-wolf',
                    change: SessionChange.woke,
                    seq: 5000 + seq,
                  ),
          );
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await push(tester, gateway, const GateChanged(gateId: 'g1', seq: 5013));
        expect(
          find.byKey(const ValueKey('team-run-event-5013')),
          findsOneWidget,
        );

        // The filter chips wrap; Decisions leaves the one gate row.
        final decisions = find.byKey(
          const ValueKey('team-run-timeline-filter-decisions'),
        );
        await revealIn(tester, 'team-run-timeline', decisions, up: true);
        await tester.tap(decisions);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('team-run-event-5013')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('team-run-event-5012')), findsNothing);
        final all = find.byKey(const ValueKey('team-run-timeline-filter-all'));
        await tester.tap(all);
        await tester.pumpAndSettle();

        // Scrolled away, a new event waits behind the pill; the pill is a
        // full target and jumps back.
        final list = find.byKey(const ValueKey('team-run-timeline'));
        await revealIn(
          tester,
          'team-run-timeline',
          find.byKey(const ValueKey('team-run-event-5001')),
        );
        await push(
          tester,
          gateway,
          const BeadChanged(beadId: 'w2', change: BeadChange.closed, seq: 5014),
        );
        final pill = find.byKey(const ValueKey('team-run-timeline-jump'));
        expect(pill.hitTestable(), findsOneWidget);
        expect(tester.getSize(pill).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(pill).width, lessThanOrEqualTo(320));
        await tester.tap(pill);
        await tester.pumpAndSettle();
        expect(pill, findsNothing);
        expect(
          find.byKey(const ValueKey('team-run-event-5014')),
          findsOneWidget,
        );
        expect(
          tester
              .state<ScrollableState>(
                find.descendant(of: list, matching: find.byType(Scrollable)),
              )
              .position
              .pixels,
          0,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('320dp 2.5x $tag: the missing-run state fits', (
        tester,
      ) async {
        final (controller, _) = await boot(configure: busyShape);
        await pumpRun(tester, controller, 'gone', direction, locale);
        expect(find.byKey(const ValueKey('team-run-missing')), findsOneWidget);
        final back = find.byType(FilledButton);
        await tester.scrollUntilVisible(back, 120);
        await tester.pumpAndSettle();
        expect(back.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
