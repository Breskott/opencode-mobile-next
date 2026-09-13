// TEAM-111: the Agents fleet, the Agent detail and the live output page.
//
// Fleet rows carry the six status words with their glyphs, sort per 02-ux
// §5.1 and show "current work · ctx N% · age"; a run's Agents tab shows
// the same rows scoped to that run. The Agent detail renders the header
// (state, context number with its 75% / 90% tones, "Recycling soon" from
// 90%, session age), the sections of §5.2, the step log parsed from the
// real recorded polecat transcript into collapsed groups, and the "Live
// output" row. The output page is LTR mono, follows by default, stops on a
// drag up, resumes from the Follow switch and reports a session the host
// no longer serves while keeping the cached text. Layout: 320dp × 2.5x,
// LTR and RTL, English and Arabic for both pages.

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
import 'package:opencode_mobile/ui/screens/team/agent_output_screen.dart';
import 'package:opencode_mobile/ui/screens/team/agent_screen.dart';
import 'package:opencode_mobile/ui/screens/team/run_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:opencode_mobile/ui/widgets/team_vocabulary.dart';
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

/// The fixture with the runs, work, agents and gates a scenario needs, an
/// owned event stream and the fixture's session output.
class _Gateway
    implements OrchestrationGateway, OrchestrationAgentOutputGateway {
  _Gateway(this.inner);

  final FixtureOrchestrationGateway inner;
  final stream = StreamController<OrchestrationEvent>.broadcast();
  List<OrchestrationRun>? runsOverride;
  List<WorkItem>? workOverride;
  List<OrchestrationAgent>? agentsOverride;
  List<OrchestrationGate>? gatesOverride;
  final outputRequests = <String>[];

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
  Stream<AgentOutputEvent> agentOutput(String sessionId) {
    outputRequests.add(sessionId);
    return inner.agentOutput(sessionId);
  }

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

  /// The polecat whose session the fixture recorded (`bl-5qc`), working
  /// the sync engine of run `oc-xru` with a full runtime.
  OrchestrationAgent fox({int? context = 63, AgentState? state}) =>
      OrchestrationAgent(
        id: 'fox',
        name: 'fox',
        state: state ?? AgentState.working,
        rawState: 'active',
        sessionId: 'bl-5qc',
        sessionName: 'ocproof--polecat--fox',
        pool: 'gastown.polecat',
        provider: 'opencode',
        model: 'openai/gpt-x',
        harness: 'OpenCode',
        currentWorkId: 'w2',
        lastActivity: clock.subtract(const Duration(minutes: 12)),
        contextPercent: context,
        workDir: '/home/eslam/city/.gc/worktrees/ocproof/polecats/fox',
        branch: 'polecat/oc-cq6',
        sessionStartedAt: clock.subtract(const Duration(hours: 3, minutes: 14)),
        raw: const {
          'id': 'bl-5qc',
          'template': 'ocproof/gastown.polecat',
          'metadata': {'rig': 'ocproof', 'branch': 'polecat/oc-cq6'},
        },
      );

  void runShape(_Gateway gateway, {List<OrchestrationAgent>? agents}) {
    gateway
      ..runsOverride = [
        OrchestrationRun(
          id: 'oc-xru',
          title: 'Offline-first sessions',
          state: RunState.working,
          rawState: 'open',
          kind: RunKind.batch,
          stepCount: 3,
          completedSteps: 1,
          startedAt: clock.subtract(const Duration(hours: 3)),
          updatedAt: clock,
          raw: const {'id': 'oc-xru', 'issue_type': 'convoy'},
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
        ),
        WorkItem(id: 'w9', title: 'Elsewhere', state: WorkState.working),
      ]
      ..gatesOverride = const []
      ..agentsOverride =
          agents ??
          [
            fox(),
            const OrchestrationAgent(
              id: 'wolf',
              name: 'wolf',
              state: AgentState.waiting,
              sessionId: 's-wolf',
              currentWorkId: 'w3',
            ),
            const OrchestrationAgent(
              id: 'bear',
              name: 'bear',
              state: AgentState.working,
              sessionId: 's-bear',
              currentWorkId: 'w9',
            ),
            const OrchestrationAgent(
              id: 'owl',
              name: 'owl',
              state: AgentState.idle,
              pack: 'gastown',
            ),
          ];
  }

  Widget app(
    Widget home, {
    Locale locale = const Locale('en'),
    TextDirection? direction,
    double scale = 1,
  }) => MaterialApp(
    theme: AppTheme.dark(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: direction == null
          ? child!
          : Directionality(textDirection: direction, child: child!),
    ),
    home: home,
  );

  Future<void> size(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpAgent(
    WidgetTester tester,
    OrchestrationController controller,
    String agentId, {
    Locale locale = const Locale('en'),
    TextDirection? direction,
    double scale = 1,
    Size viewport = const Size(800, 2000),
  }) async {
    await size(tester, viewport);
    await tester.pumpWidget(
      app(
        AgentScreen(controller: controller, agentId: agentId, now: () => clock),
        locale: locale,
        direction: direction,
        scale: scale,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> pumpOutput(
    WidgetTester tester,
    OrchestrationController controller,
    String agentId, {
    Locale locale = const Locale('en'),
    TextDirection? direction,
    double scale = 1,
    Size viewport = const Size(800, 600),
  }) async {
    await size(tester, viewport);
    await tester.pumpWidget(
      app(
        AgentOutputScreen(controller: controller, agentId: agentId),
        locale: locale,
        direction: direction,
        scale: scale,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  double top(WidgetTester tester, Finder finder) =>
      tester.getTopLeft(finder).dy;

  Color colorOf(WidgetTester tester, Finder text) =>
      tester.widget<Text>(text).style!.color!;

  ScrollPosition outputPosition(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: key('team-agent-output-list'),
          matching: find.byType(Scrollable),
        ),
      )
      .position;

  group('fleet', () {
    testWidgets('six status words with glyphs, sorted per §5.1', (
      tester,
    ) async {
      final (controller, _) = await boot(
        configure: (g) => g
          ..workOverride = const []
          ..gatesOverride = const []
          ..agentsOverride = const [
            OrchestrationAgent(
              id: 'a-stopped',
              name: 'a-stopped',
              state: AgentState.stopped,
            ),
            OrchestrationAgent(
              id: 'b-idle',
              name: 'b-idle',
              state: AgentState.idle,
            ),
            OrchestrationAgent(
              id: 'c-working',
              name: 'c-working',
              state: AgentState.working,
            ),
            OrchestrationAgent(
              id: 'd-crashed',
              name: 'd-crashed',
              state: AgentState.crashed,
            ),
            OrchestrationAgent(
              id: 'e-blocked',
              name: 'e-blocked',
              state: AgentState.blocked,
            ),
            OrchestrationAgent(
              id: 'f-waiting',
              name: 'f-waiting',
              state: AgentState.waiting,
            ),
          ],
      );
      await size(tester, const Size(800, 2000));
      await tester.pumpWidget(
        app(TeamHomeScreen(controller: controller, now: () => clock)),
      );
      await tester.pumpAndSettle();
      await tester.tap(key('team-home-segment-agents'));
      await tester.pumpAndSettle();
      // The stopped one sits under the collapsed "Suspended on the host"
      // group (TEAM-115); open it so every word is on screen.
      expect(key('team-home-agent-a-stopped'), findsNothing);
      await tester.tap(key('team-home-suspended-group'));
      await tester.pumpAndSettle();

      // Needs-you first (blocked and waiting share the rank, by name),
      // the crashed exception, then working, idle, stopped.
      final expected = {
        'e-blocked': ('Blocked', AppIconography.blocked),
        'f-waiting': ('Waiting (needs input)', AppIconography.question),
        'd-crashed': ('Crashed', AppIconography.error),
        'c-working': ('Working', AppIconography.play),
        'b-idle': ('Idle', AppIconography.statusDot),
        'a-stopped': ('Stopped', AppIconography.stopCircle),
      };
      for (final MapEntry(key: id, value: (word, glyph)) in expected.entries) {
        final row = key('team-home-agent-$id');
        expect(
          find.descendant(of: row, matching: find.text(word)),
          findsOneWidget,
          reason: '$id says $word',
        );
        expect(
          find.descendant(of: row, matching: find.byIcon(glyph)),
          findsOneWidget,
          reason: '$id carries its glyph',
        );
      }
      final order = expected.keys.toList();
      for (var i = 1; i < order.length; i++) {
        expect(
          top(tester, key('team-home-agent-${order[i - 1]}')),
          lessThan(top(tester, key('team-home-agent-${order[i]}'))),
          reason: '${order[i - 1]} above ${order[i]}',
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the second line is current work · ctx N% · age', (
      tester,
    ) async {
      final (controller, _) = await boot(configure: runShape);
      await size(tester, const Size(800, 2000));
      await tester.pumpWidget(
        app(TeamHomeScreen(controller: controller, now: () => clock)),
      );
      await tester.pumpAndSettle();
      await tester.tap(key('team-home-segment-agents'));
      await tester.pumpAndSettle();
      final row = key('team-home-agent-fox');
      expect(
        find.descendant(of: row, matching: find.text('Sync engine')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('ctx 63%')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('12m ago')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row,
          matching: find.text('gastown.polecat · opencode / openai/gpt-x'),
        ),
        findsOneWidget,
      );
      // Owl has neither work, context nor activity: just the fallback.
      expect(
        find.descendant(
          of: key('team-home-agent-owl'),
          matching: find.text('No current work'),
        ),
        findsOneWidget,
      );

      // The row opens the Agent detail by default.
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(key('team-agent'), findsOneWidget);
      expect(key('team-agent-title'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a run’s Agents tab shows only the agents on that run', (
      tester,
    ) async {
      final (controller, _) = await boot(configure: runShape);
      await size(tester, const Size(800, 1600));
      await tester.pumpWidget(
        app(
          RunScreen(controller: controller, runId: 'oc-xru', now: () => clock),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(key('team-run-tab-agents'));
      await tester.pumpAndSettle();
      expect(key('team-run-agents-placeholder'), findsNothing);
      expect(key('team-run-agents-list'), findsOneWidget);
      expect(key('team-run-agent-fox'), findsOneWidget);
      expect(key('team-run-agent-wolf'), findsOneWidget);
      // Bear works w9, which is not on this run; owl has no work.
      expect(key('team-run-agent-bear'), findsNothing);
      expect(key('team-run-agent-owl'), findsNothing);
      // Wolf waits on input and sorts first.
      expect(
        top(tester, key('team-run-agent-wolf')),
        lessThan(top(tester, key('team-run-agent-fox'))),
      );
      await tester.tap(key('team-run-agent-fox'));
      await tester.pumpAndSettle();
      expect(key('team-agent'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a run without agents shows the empty state', (tester) async {
      final (controller, _) = await boot(
        configure: (g) => runShape(g, agents: const []),
      );
      await size(tester, const Size(800, 1600));
      await tester.pumpWidget(
        app(
          RunScreen(controller: controller, runId: 'oc-xru', now: () => clock),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(key('team-run-tab-agents'));
      await tester.pumpAndSettle();
      expect(key('team-run-agents-empty'), findsOneWidget);
      expect(find.text('No agents on this run'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('detail', () {
    testWidgets('header: state, context number, session age; sections', (
      tester,
    ) async {
      final (controller, gateway) = await boot(configure: runShape);
      await pumpAgent(tester, controller, 'fox');
      expect(find.text('fox'), findsWidgets);
      expect(key('team-agent-term'), findsOneWidget);
      expect(find.text('Agent · session bl-5qc'), findsOneWidget);
      expect(key('team-agent-state'), findsOneWidget);
      expect(
        find.descendant(
          of: key('team-agent-header'),
          matching: find.text('Working'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: key('team-agent-header'),
          matching: find.byIcon(AppIconography.play),
        ),
        findsOneWidget,
      );
      expect(find.text('ctx 63%'), findsOneWidget);
      expect(find.text('Session 3 h 14 min'), findsOneWidget);
      expect(key('team-agent-recycling'), findsNothing);
      // The output stream was opened for the agent's session.
      expect(gateway.outputRequests, ['bl-5qc']);

      for (final section in [
        'identity',
        'runtime',
        'work',
        'activity',
        'output',
        'technical',
      ]) {
        expect(key('team-agent-$section'), findsOneWidget, reason: section);
      }
      expect(find.text('gastown.polecat'), findsOneWidget);
      expect(find.text('openai/gpt-x'), findsOneWidget);
      expect(find.text('OpenCode'), findsOneWidget);
      expect(find.text('3 h 14 min'), findsOneWidget);
      final workDir = find.text(
        '/home/eslam/city/.gc/worktrees/ocproof/polecats/fox',
      );
      expect(workDir, findsOneWidget);
      expect(tester.widget<Text>(workDir).textDirection, TextDirection.ltr);
      expect(
        tester.widget<Text>(workDir).style?.fontFamily,
        AppTheme.monoFamily,
      );
      expect(find.text('polecat/oc-cq6'), findsOneWidget);
      expect(key('team-agent-work-chip'), findsOneWidget);
      expect(find.text('Sync engine'), findsOneWidget);
      expect(find.text('Nothing blocking it'), findsOneWidget);
      expect(key('team-agent-open-output'), findsOneWidget);
      expect(find.text('Live output'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the context number changes tone at 75% and 90%', (
      tester,
    ) async {
      expect(teamContextAttentionPercent, 75);
      expect(teamContextRecyclePercent, 90);
      final theme = AppTheme.dark();
      Future<void> at(int percent) async {
        final (controller, _) = await boot(
          configure: (g) => runShape(g, agents: [fox(context: percent)]),
        );
        await pumpAgent(tester, controller, 'fox');
      }

      await at(74);
      expect(colorOf(tester, find.text('ctx 74%')), AppTheme.mutedOf(theme));
      expect(key('team-agent-recycling'), findsNothing);

      await at(75);
      expect(
        colorOf(tester, find.text('ctx 75%')),
        AppTheme.statusColor(theme, AppStatusTone.attention),
      );
      expect(key('team-agent-recycling'), findsNothing);

      await at(89);
      expect(
        colorOf(tester, find.text('ctx 89%')),
        AppTheme.statusColor(theme, AppStatusTone.attention),
      );
      expect(key('team-agent-recycling'), findsNothing);

      await at(90);
      expect(
        colorOf(tester, find.text('ctx 90%')),
        AppTheme.statusColor(theme, AppStatusTone.failure),
      );
      expect(key('team-agent-recycling'), findsOneWidget);
      expect(find.text('Recycling soon · context nearly full'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no context reported: no number, no recycling line', (
      tester,
    ) async {
      final (controller, _) = await boot(
        configure: (g) => runShape(g, agents: [fox(context: null)]),
      );
      await pumpAgent(tester, controller, 'fox');
      expect(key('team-agent-context'), findsNothing);
      expect(key('team-agent-recycling'), findsNothing);
      expect(find.text('Not reported'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Activity parses the recorded transcript into collapsed groups',
      (tester) async {
        final (controller, _) = await boot(configure: runShape);
        await pumpAgent(tester, controller, 'fox');
        // The whole polecat recording replayed: 80 markers, eight groups
        // of tool calls with the agent's prose between them.
        final tail = controller.agentOutput('fox');
        expect(tail.text, contains('[tool: bash]'));
        expect(tail.received, isTrue);
        final blocks = parseAgentTranscript(tail.text);
        final groups = blocks.whereType<AgentStepGroup>().toList();
        expect(groups.length, greaterThanOrEqualTo(5));
        expect(groups.first.steps.length, 5);
        expect(groups.first.steps.first.command, startsWith('ls /home/eslam'));
        expect(groups.first.steps.first.kind, AgentStepKind.command);
        expect(groups.first.steps.first.output, contains('On branch master'));
        expect(
          blocks.whereType<AgentProse>().first.text,
          contains('Branch setup: metadata says work_dir'),
        );
        expect(
          groups.any((g) => g.steps.any((s) => s.kind == AgentStepKind.read)),
          isTrue,
          reason: 'the read tool call is classified as a read',
        );

        final headers = key('team-agent-step-group-header');
        expect(headers, findsWidgets);
        expect(key('team-agent-step-group-body'), findsNothing);
        expect(find.text('Ran 5 commands'), findsWidgets);
        expect(key('team-agent-activity-empty'), findsNothing);

        await tester.tap(headers.first);
        await tester.pumpAndSettle();
        expect(key('team-agent-step-group-body'), findsOneWidget);
        final command = find.textContaining('ls /home/eslam/Storage/Code');
        expect(command, findsWidgets);
        final text = tester.widget<Text>(command.first);
        expect(text.style?.fontFamily, AppTheme.monoFamily);
        expect(
          Directionality.of(tester.element(command.first)),
          TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Live output is one tap away and reports a gone session', (
      tester,
    ) async {
      final (controller, gateway) = await boot(configure: runShape);
      await pumpAgent(tester, controller, 'fox');
      expect(
        find.descendant(
          of: key('team-agent-open-output'),
          matching: find.text('Live'),
        ),
        findsOneWidget,
      );
      gateway.inner.endOutput(
        'bl-5qc',
        reason: 'session bl-5qc has no live output',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Session ended · output no longer on the host'),
        findsOneWidget,
      );
      final tail = controller.agentOutput('fox');
      expect(tail.ended, isTrue);
      expect(tail.text, isNotEmpty, reason: 'the cached text stays');

      await tester.tap(key('team-agent-open-output'));
      await tester.pumpAndSettle();
      expect(key('team-agent-output-page'), findsOneWidget);
      expect(
        find.text('Session ended · output no longer on the host'),
        findsOneWidget,
      );
      expect(key('team-agent-output-text'), findsOneWidget);
      // Nothing more can arrive: the switch is disabled.
      final follow = tester.widget<SwitchListTile>(
        key('team-agent-output-follow'),
      );
      expect(follow.onChanged, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an agent without a session has no live output', (
      tester,
    ) async {
      final (controller, gateway) = await boot(configure: runShape);
      await pumpAgent(tester, controller, 'owl');
      expect(gateway.outputRequests, isEmpty);
      expect(find.text('Agent'), findsOneWidget);
      expect(
        find.text('Live output is not available for this agent'),
        findsOneWidget,
      );
      expect(key('team-agent-activity-empty'), findsOneWidget);
      expect(key('team-agent-no-work'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a blocked item and its gate show under the header', (
      tester,
    ) async {
      final (controller, _) = await boot(
        configure: (g) {
          runShape(g);
          g.gatesOverride = [
            OrchestrationGate(
              id: 'g1',
              kind: GateKind.choice,
              title: 'Which persistence strategy?',
              workId: 'w3',
              agentId: 's-wolf',
              choices: const ['SQLite', 'Filesystem'],
              createdAt: clock,
            ),
          ];
        },
      );
      await pumpAgent(tester, controller, 'wolf');
      expect(key('team-agent-gate'), findsOneWidget);
      expect(find.text('Which persistence strategy?'), findsOneWidget);
      expect(
        find.textContaining('Answer this on the computer'),
        findsOneWidget,
      );
      expect(key('team-agent-work-dependency'), findsOneWidget);
      expect(find.text('Blocked'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an agent the host no longer lists', (tester) async {
      final (controller, _) = await boot(configure: runShape);
      await pumpAgent(tester, controller, 'gone');
      expect(key('team-agent-missing'), findsOneWidget);
      expect(find.text('This agent is no longer on the host'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Technical details expand with the raw fields', (tester) async {
      final (controller, _) = await boot(configure: runShape);
      await pumpAgent(tester, controller, 'fox');
      await tester.tap(key('team-agent-technical'));
      await tester.pumpAndSettle();
      expect(find.text('metadata.rig'), findsOneWidget);
      expect(find.text('ocproof/gastown.polecat'), findsOneWidget);
      await tester.tap(key('team-agent-details'));
      await tester.pumpAndSettle();
      expect(key('team-agent-details-sheet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('output page', () {
    testWidgets('is LTR mono and follows by default', (tester) async {
      final (controller, gateway) = await boot(
        configure: (g) {
          runShape(g);
          g.inner.outputReplay = 6;
        },
      );
      await pumpOutput(
        tester,
        controller,
        'fox',
        locale: const Locale('ar'),
        direction: TextDirection.rtl,
      );
      final text = key('team-agent-output-text');
      expect(text, findsOneWidget);
      expect(tester.widget<Text>(text).style?.fontFamily, AppTheme.monoFamily);
      expect(Directionality.of(tester.element(text)), TextDirection.ltr);
      expect(find.text('مباشر'), findsOneWidget);
      final follow = tester.widget<SwitchListTile>(
        key('team-agent-output-follow'),
      );
      expect(follow.value, isTrue);

      var position = outputPosition(tester);
      expect(position.maxScrollExtent, greaterThan(0));
      expect(position.pixels, position.maxScrollExtent);

      final before = position.maxScrollExtent;
      gateway.inner.emitOutput('bl-5qc', 4);
      await tester.pumpAndSettle();
      position = outputPosition(tester);
      expect(position.maxScrollExtent, greaterThan(before));
      expect(position.pixels, position.maxScrollExtent);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a drag up stops following; Follow resumes and jumps', (
      tester,
    ) async {
      final (controller, gateway) = await boot(
        configure: (g) {
          runShape(g);
          g.inner.outputReplay = 6;
        },
      );
      await pumpOutput(tester, controller, 'fox');
      expect(key('team-agent-output-jump'), findsNothing);

      await tester.drag(key('team-agent-output-list'), const Offset(0, 400));
      await tester.pumpAndSettle();
      var position = outputPosition(tester);
      expect(position.pixels, lessThan(position.maxScrollExtent - 24));
      expect(
        tester.widget<SwitchListTile>(key('team-agent-output-follow')).value,
        isFalse,
      );
      expect(key('team-agent-output-jump'), findsOneWidget);

      final held = position.pixels;
      gateway.inner.emitOutput('bl-5qc', 4);
      await tester.pumpAndSettle();
      position = outputPosition(tester);
      expect(position.pixels, held, reason: 'new text does not move it');
      expect(position.pixels, lessThan(position.maxScrollExtent));

      await tester.tap(key('team-agent-output-follow'));
      await tester.pumpAndSettle();
      position = outputPosition(tester);
      expect(
        tester.widget<SwitchListTile>(key('team-agent-output-follow')).value,
        isTrue,
      );
      expect(position.pixels, position.maxScrollExtent);
      expect(key('team-agent-output-jump'), findsNothing);

      // The pill does the same.
      await tester.drag(key('team-agent-output-list'), const Offset(0, 400));
      await tester.pumpAndSettle();
      await tester.tap(key('team-agent-output-jump'));
      await tester.pumpAndSettle();
      position = outputPosition(tester);
      expect(position.pixels, position.maxScrollExtent);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the tail is kept by the controller across pages', (
      tester,
    ) async {
      final (controller, gateway) = await boot(
        configure: (g) {
          runShape(g);
          g.inner.outputReplay = 2;
        },
      );
      await pumpOutput(tester, controller, 'fox');
      final first = controller.agentOutput('fox').text;
      expect(first, isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(controller.agentOutput('fox').watching, isFalse);
      expect(controller.agentOutput('fox').text, first);
      // Watching again reopens the stream (one request per open).
      await pumpOutput(tester, controller, 'fox');
      expect(gateway.outputRequests.length, 2);
      expect(controller.agentOutput('fox').watching, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('320dp 2.5x', () {
    for (final (direction, locale) in [
      (TextDirection.ltr, const Locale('en')),
      (TextDirection.rtl, const Locale('ar')),
      (TextDirection.ltr, const Locale('ar')),
      (TextDirection.rtl, const Locale('en')),
    ]) {
      final label = '${direction.name} ${locale.languageCode}';

      Future<void> reveal(
        WidgetTester tester,
        String list,
        Finder target,
      ) async {
        await tester.scrollUntilVisible(
          target,
          120,
          scrollable: find
              .descendant(of: key(list), matching: find.byType(Scrollable))
              .first,
        );
        await tester.pumpAndSettle();
        expect(target, findsOneWidget);
        final rect = tester.getRect(target);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }

      testWidgets('$label: the agent detail fits', (tester) async {
        final (controller, _) = await boot(
          configure: (g) => runShape(g, agents: [fox(context: 92)]),
        );
        await pumpAgent(
          tester,
          controller,
          'fox',
          locale: locale,
          direction: direction,
          scale: 2.5,
          viewport: const Size(320, 740),
        );
        expect(tester.getSize(key('team-agent')).width, 320);
        expect(key('team-agent-header'), findsOneWidget);
        expect(key('team-agent-recycling'), findsOneWidget);
        for (final section in [
          'identity',
          'runtime',
          'work',
          'activity',
          'open-output',
          'technical',
        ]) {
          await reveal(tester, 'team-agent-list', key('team-agent-$section'));
          if (section == 'activity') {
            // The list builds lazily: the first group sits right under
            // the heading, so it exists now.
            final header = key('team-agent-step-group-header').first;
            await reveal(tester, 'team-agent-list', header);
            await tester.tap(header);
            await tester.pumpAndSettle();
            expect(key('team-agent-step-group-body'), findsOneWidget);
          }
        }
        await tester.tap(key('team-agent-technical'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('$label: the output page fits', (tester) async {
        final (controller, gateway) = await boot(
          configure: (g) {
            runShape(g);
            g.inner.outputReplay = 3;
          },
        );
        await pumpOutput(
          tester,
          controller,
          'fox',
          locale: locale,
          direction: direction,
          scale: 2.5,
          viewport: const Size(320, 740),
        );
        expect(tester.getSize(key('team-agent-output-page')).width, 320);
        expect(key('team-agent-output-status'), findsOneWidget);
        expect(key('team-agent-output-follow'), findsOneWidget);
        expect(key('team-agent-output-text'), findsOneWidget);
        var position = outputPosition(tester);
        expect(position.pixels, position.maxScrollExtent);
        await tester.drag(key('team-agent-output-list'), const Offset(0, 300));
        await tester.pumpAndSettle();
        expect(key('team-agent-output-jump'), findsOneWidget);
        final pill = tester.getRect(key('team-agent-output-jump'));
        expect(pill.left, greaterThanOrEqualTo(0));
        expect(pill.right, lessThanOrEqualTo(320));
        gateway.inner.endOutput('bl-5qc');
        await tester.pumpAndSettle();
        expect(key('team-agent-output-jump'), findsNothing);
        position = outputPosition(tester);
        expect(position.viewportDimension, greaterThan(0));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
