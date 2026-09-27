// TEAM-109 after slice-P3.5: Task details (the retired run page's facts)
// at 320dp × 2.5x text, LTR and RTL, English and Arabic: the status line,
// the stage line, the step rows, the team's usage, the Technical details
// fold with its LTR ids and what the host reported, and the missing-task
// state all fit, and nothing overflows or scrolls sideways. (The run
// page's tabs, Timeline filter chips and jump-to-latest pill are gone.)

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
import 'package:opencode_mobile/ui/screens/team/task_details_sheet.dart';
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

  Future<void> pumpDetails(
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
        Scaffold(
          body: SingleChildScrollView(
            key: const ValueKey('details-scroll'),
            child: TeamTaskDetails(
              controller: controller,
              runId: runId,
              now: () => clock,
            ),
          ),
        ),
        direction,
        locale,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  /// Scrolls the details until [target] is on screen and within the width
  /// (tappable when [tap]; a block taller than the viewport only needs to
  /// be in view).
  Future<void> reveal(
    WidgetTester tester,
    Finder target, {
    bool tap = false,
  }) async {
    await tester.scrollUntilVisible(
      target,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('details-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    if (tap) expect(target.hitTestable(), findsOneWidget);
    expect(target, findsOneWidget);
    final rect = tester.getRect(target);
    expect(rect.top, lessThan(740));
    expect(rect.bottom, greaterThan(0));
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
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

  Finder key(String name) => find.byKey(ValueKey(name));

  for (final direction in TextDirection.values) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      final tag = '${direction.name} ${locale.languageCode}';

      testWidgets('320dp 2.5x $tag: Task details and its fold fit', (
        tester,
      ) async {
        final (controller, gateway) = await boot(configure: busyShape);
        await pumpDetails(tester, controller, 'oc-xru', direction, locale);
        final l10n = lookupAppLocalizations(locale);
        await push(
          tester,
          gateway,
          BeadChanged(
            beadId: 'w3',
            change: BeadChange.updated,
            seq: 5001,
            raw: {'ts': clock.toIso8601String()},
          ),
        );
        await push(
          tester,
          gateway,
          const SessionChanged(
            sessionId: 's-wolf',
            change: SessionChange.woke,
            seq: 5002,
          ),
        );
        expect(key('team-task-details-body'), findsOneWidget);

        // Top to bottom: the status line, the four-stage line, the step
        // rows (full targets), the team's usage.
        for (final name in const [
          'team-task-details-status',
          'team-task-details-stage',
        ]) {
          await reveal(tester, key(name));
        }
        for (final id in const ['w1', 'w2', 'w3']) {
          final row = key('team-task-details-step-$id');
          await reveal(tester, row, tap: true);
          expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
        }
        await reveal(tester, key('team-task-details-usage'));
        expect(tester.takeException(), isNull);

        // Technical details: the Gas City term is there, not above it;
        // ids stay LTR; what the host reported fits.
        expect(
          find.text(l10n.teamUiRunTermBatch, findRichText: true),
          findsNothing,
        );
        final fold = key('team-task-details-technical');
        await reveal(tester, fold);
        await tester.tap(
          find.descendant(
            of: fold,
            matching: find.text(l10n.teamUiTechnicalDetails),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await reveal(
          tester,
          find.descendant(
            of: fold,
            matching: find.text(l10n.teamUiRunTermBatch, findRichText: true),
          ),
        );
        final id = key('team-task-details-id');
        await reveal(tester, id);
        expect(Directionality.of(tester.element(id)), TextDirection.ltr);
        for (final seq in const [5001, 5002]) {
          await reveal(tester, key('team-task-details-event-$seq'));
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('320dp 2.5x $tag: the missing-task state fits', (
        tester,
      ) async {
        final (controller, _) = await boot(configure: busyShape);
        await pumpDetails(tester, controller, 'gone', direction, locale);
        await reveal(tester, key('team-task-details-missing'));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
