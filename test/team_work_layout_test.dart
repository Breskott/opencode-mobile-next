// TEAM-110 after slice-P3.5: a task's steps in Task details (the graph in
// rows; the run page's Work tab with its List / Graph toggle is retired)
// and the Work sheet at 320dp × 2.5x text, LTR and RTL, English and
// Arabic: the step rows, and the sheet with its chips, LTR mono branch and
// worktree, timestamps and Technical details all fit, scroll, and nothing
// overflows or scrolls sideways.

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
  /// blocked behind the working one with a branch, a worktree, a markdown
  /// description and a long reason; an agent on it and a decision gate.
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
      ..workOverride = [
        const WorkItem(
          id: 'w1',
          title: 'Storage layer',
          state: WorkState.completed,
          runId: 'oc-xru',
        ),
        const WorkItem(
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
          dependsOn: const ['w2', 'w1'],
          assignee: 'ocproof/gastown.wolf',
          createdAt: DateTime.utc(2026, 9, 11, 6, 41),
          raw: {
            'id': 'w3',
            'description':
                'Resolve **concurrent** edits without losing '
                'either side; see `docs/sync.md`.',
            'metadata': {
              'branch': 'polecat/w3',
              'gc.work_dir': '/srv/city/.gc/worktrees/w3',
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

  Future<void> pumpWork(
    WidgetTester tester,
    OrchestrationController controller,
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
              runId: 'oc-xru',
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
    expect(
      tester
          .getSize(find.byKey(const ValueKey('team-task-details-body')))
          .width,
      320,
    );
  }

  Finder key(String name) => find.byKey(ValueKey(name));

  /// Scrolls [list] until [target] is on screen and within the width.
  Future<void> revealIn(
    WidgetTester tester,
    Finder list,
    Finder target, {
    bool tap = true,
    bool up = false,
  }) async {
    await tester.scrollUntilVisible(
      target,
      up ? -120 : 120,
      scrollable: find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    if (tap) {
      expect(target.hitTestable(), findsOneWidget);
    } else {
      expect(target, findsOneWidget);
    }
    final rect = tester.getRect(target);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(320));
  }

  for (final direction in TextDirection.values) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      final tag = '${direction.name} ${locale.languageCode}';

      testWidgets('320dp 2.5x $tag: the step rows fit', (tester) async {
        final (controller, _) = await boot(configure: busyShape);
        await pumpWork(tester, controller, direction, locale);
        final details = key('details-scroll');
        expect(key('team-task-details-graph'), findsOneWidget);
        for (final id in const ['w1', 'w2', 'w3']) {
          final row = key('team-task-details-step-$id');
          await revealIn(tester, details, row);
          expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(row).width, lessThanOrEqualTo(320));
        }
        expect(tester.takeException(), isNull);
      });

      testWidgets('320dp 2.5x $tag: the Work sheet scrolls, ids stay LTR', (
        tester,
      ) async {
        final (controller, _) = await boot(configure: busyShape);
        await pumpWork(tester, controller, direction, locale);
        final row = key('team-task-details-step-w3');
        await revealIn(tester, key('details-scroll'), row);
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final sheet = key('team-work-sheet');
        expect(sheet, findsOneWidget);
        expect(tester.getSize(sheet).width, lessThanOrEqualTo(320));
        // The step's title is the sheet's header (no separate title row).
        expect(key('team-work-sheet-title'), findsNothing);
        expect(
          find.descendant(
            of: sheet,
            matching: find.textContaining('Conflict policy'),
          ),
          findsWidgets,
        );
        expect(key('team-work-sheet-state'), findsNothing);
        expect(key('team-work-sheet-owner'), findsOneWidget);

        // Dependency row and the created stamp.
        await revealIn(tester, sheet, key('team-work-dependency-w2'));
        await revealIn(
          tester,
          sheet,
          key('team-work-sheet-created'),
          tap: false,
        );

        // Technical details expand: the id, branch and worktree stay LTR
        // in the mono face.
        final expander = key('team-work-sheet-technical');
        await revealIn(tester, sheet, expander, tap: false);
        await tester.tap(
          find.descendant(of: expander, matching: find.byType(Text)).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final (name, value) in const [
          ('team-work-sheet-branch', 'polecat/w3'),
          ('team-work-sheet-worktree', '/srv/city/.gc/worktrees/w3'),
        ]) {
          await revealIn(tester, sheet, key(name), tap: false);
          final text = tester.widget<EditableText>(
            find.descendant(of: key(name), matching: find.text(value)),
          );
          expect(text.textDirection, TextDirection.ltr);
          expect(text.style.fontFamily, AppTheme.monoFamily);
        }
        final id = find.descendant(of: sheet, matching: find.text('w3')).first;
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
    }
  }
}
