// TEAM-107: the Workspace AI Team card over the fixture gateway. States
// L/E/S/X/N, header counts, run rows, the blocked segment, stale
// read-only behaviour, error copy and reduced motion.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
/// team_controller_test).
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
  bool failReads = false;

  int count(String name) => calls[name] ?? 0;
  void _hit(String name) {
    calls[name] = count(name) + 1;
    if (failReads) throw StateError('read failed: $name');
  }

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
}

/// A connection whose plugin controller a test can set directly.
class _Connection extends ConnectionController {
  _Connection(super.store);

  OrchestrationController? team;

  @override
  OrchestrationController? get orchestration => team;

  // No project catalogue: the Workspace renders its session list at once
  // instead of asking for a folder first.
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
    OrchestrationHostKind? hostKind,
    String? url,
  }) => OrchestrationConfig(
    provider: OrchestrationProvider.fixture,
    url: url ?? fixturePath,
    city: 'bright-lights',
    hostMode: hostMode,
    hostKind: hostKind,
    enabledAt: DateTime.utc(2026, 9, 10),
  );

  ServerProfile profile({OrchestrationConfig? config}) => ServerProfile(
    id: 'srv-1',
    name: 'Workstation',
    baseUrl: 'https://server.example:4096',
    orchestration: config,
  );

  /// A controller over the wrapped fixture; [start] is awaited unless
  /// [started] is false.
  Future<(OrchestrationController, _Gateway)> boot({
    bool started = true,
    OrchestrationProbe? probe,
    void Function(_Gateway gateway)? configure,
    OrchestrationHostMode hostMode = OrchestrationHostMode.computer,
    OrchestrationHostKind? hostKind,
    String? url,
  }) async {
    final gateway = _Gateway(
      FixtureOrchestrationGateway(fixturePath: fixturePath, hostMode: hostMode),
    );
    configure?.call(gateway);
    final cfg = config(hostMode: hostMode, hostKind: hostKind, url: url);
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

  Widget app(
    Widget home, {
    bool reduceMotion = true,
    Locale locale = const Locale('en'),
    bool scroll = true,
  }) => MaterialApp(
    theme: AppTheme.dark(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(body: scroll ? SingleChildScrollView(child: home) : home),
  );

  Future<void> pumpCard(
    WidgetTester tester,
    OrchestrationController controller, {
    bool reduceMotion = true,
    VoidCallback? onOpen,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      app(
        TeamCard(controller: controller, onOpen: onOpen ?? () {}),
        reduceMotion: reduceMotion,
        locale: locale,
      ),
    );
    await tester.pump();
  }

  Finder agentDots() => find.byWidgetPredicate(
    (w) => switch (w.key) {
      ValueKey<String>(:final value) => value.startsWith('team-card-agent-'),
      _ => false,
    },
  );

  Finder pulses() => find.descendant(
    of: find.byKey(const ValueKey('team-card-constellation')),
    matching: find.byType(ScaleTransition),
  );

  String clockLabel(WidgetTester tester, DateTime at) =>
      MaterialLocalizations.of(
        tester.element(find.byType(TeamCard)),
      ).formatTimeOfDay(
        TimeOfDay.fromDateTime(at.toLocal()),
        alwaysUse24HourFormat: true,
      );

  /// TEAM-117: the fixture convoy over the recorded `oc-loy` as the host
  /// last showed it — pushed and in the refinery's hands, no live agent,
  /// never closed. [updatedAt] is the bead's `updated_at` when given; the
  /// recording itself carries only `created_at`.
  void handedToRefineryShape(_Gateway gateway, {DateTime? updatedAt}) {
    final convoys = GcList<GcConvoy>.fromJson(
      readMap(
        jsonDecode(
          File('$fixturePath/recordings/convoys.json').readAsStringSync(),
        ),
      ),
      GcConvoy.fromJson,
    ).items;
    final bead = GcBead.fromJson({
      ...readMap(
        jsonDecode(
          File(
            '$fixturePath/recordings/bead_handed_to_refinery.json',
          ).readAsStringSync(),
        ),
      ),
      if (updatedAt != null) 'updated_at': updatedAt.toIso8601String(),
    });
    final context = GcWorkContext.from(convoys: convoys);
    final work = mapBeads([bead], context: context);
    gateway
      ..workOverride = work
      ..runsOverride = mapConvoys(convoys, work: work, context: context)
      ..gatesOverride = const [];
  }

  /// The `blocked` shape: the fixture convoy over a blocked `oc-loy` and a
  /// closed sibling, plus the pending choice that blocks it.
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
    // The closed sibling is tracked too so the run is half done.
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
      ..gatesOverride = mapGates(
        pending: [GcPendingInteraction.fromJson(_blockedPending)],
        beads: beads,
        runs: runs,
      );
  }

  group('N: not available', () {
    testWidgets('config null: the card is not in the Workspace tree', (
      tester,
    ) async {
      final connection = _Connection(ProfileStore(prefs: prefs));
      addTearDown(connection.dispose);
      await tester.pumpWidget(
        app(WorkspaceScreen(controller: connection), scroll: false),
      );
      await tester.pumpAndSettle();
      expect(connection.orchestration, isNull);
      expect(find.byType(TeamCard), findsNothing);
    });

    testWidgets('with a config the card sits above the sessions', (
      tester,
    ) async {
      final (controller, _) = await boot();
      final connection = _Connection(ProfileStore(prefs: prefs))
        ..team = controller;
      addTearDown(connection.dispose);
      await tester.pumpWidget(
        app(WorkspaceScreen(controller: connection), scroll: false),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TeamCard), findsOneWidget);
      expect(find.byKey(const ValueKey('team-card-data')), findsOneWidget);
      expect(find.text('AI Team · Gas City'), findsOneWidget);
    });
  });

  group('L: loading', () {
    testWidgets('before the probe answers the header sits over a skeleton', (
      tester,
    ) async {
      final (controller, _) = await boot(started: false);
      await pumpCard(tester, controller);
      expect(controller.phase, OrchestrationPhase.idle);
      expect(find.byKey(const ValueKey('team-card-loading')), findsOneWidget);
      expect(find.text('AI Team · Gas City'), findsOneWidget);
      expect(find.byKey(const ValueKey('team-card-open')), findsNothing);
      expect(find.byKey(const ValueKey('team-card-hero')), findsNothing);
    });
  });

  group('N: normal', () {
    testWidgets('header counts and run rows match the fixture', (tester) async {
      var opened = 0;
      final (controller, gateway) = await boot();
      await pumpCard(tester, controller, onOpen: () => opened += 1);

      expect(find.byKey(const ValueKey('team-card-data')), findsOneWidget);
      expect(find.text('AI Team · Gas City'), findsOneWidget);
      // Two of the five live fixture agents (refinery, witness) are
      // working; the three dog slots and the core helper are not agents.
      expect(find.text('2 agents working'), findsOneWidget);
      expect(find.text('On the computer'), findsOneWidget);
      // The host is named by the team URL, never by the profile: a
      // fixture path names no host, so the provider stands in.
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('team-card-host-name')))
            .data,
        'fixture',
      );
      expect(find.text('Workstation'), findsNothing);
      expect(find.text('city bright-lights'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('team-card-city')))
            .textDirection,
        TextDirection.ltr,
      );
      expect(find.byKey(const ValueKey('team-card-needs-you')), findsNothing);
      // One convoy, 0 of 1 tracked bead closed: named by its work and
      // waiting for an agent (the bead is open, routed to a pool, unheld).
      expect(find.text('0% done.'), findsOneWidget);
      expect(
        find.text('Add subtract function to calc.py is waiting for an agent.'),
        findsOneWidget,
      );
      expect(find.textContaining('sling-oc-loy'), findsNothing);
      expect(
        find.byKey(const ValueKey('team-card-run-oc-xru')),
        findsOneWidget,
      );
      expect(find.text('Waiting for an agent'), findsOneWidget);
      expect(find.text('Planning'), findsNothing);
      expect(find.textContaining('convoy'), findsOneWidget);
      expect(find.byKey(const ValueKey('team-card-more-runs')), findsNothing);
      expect(
        find.byKey(const ValueKey('team-card-completed-runs')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('team-card-bar-blocked')), findsNothing);
      expect(find.byKey(const ValueKey('team-card-bar-done')), findsNothing);
      expect(agentDots(), findsNWidgets(controller.snapshot.agents.length));
      expect(agentDots(), findsNWidgets(5));
      expect(find.byKey(const ValueKey('team-card-stale')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('team-card-open')));
      expect(opened, 1);
      await tester.tap(find.byKey(const ValueKey('team-card-run-oc-xru')));
      expect(opened, 2);

      final before = gateway.count('runs');
      await tester.tap(find.byKey(const ValueKey('team-card-refresh')));
      await tester.pumpAndSettle();
      expect(gateway.count('runs'), before + 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone host says so', (tester) async {
      final (controller, _) = await boot(hostMode: OrchestrationHostMode.phone);
      await pumpCard(tester, controller);
      expect(find.text('On this phone'), findsOneWidget);
      expect(find.text('On the computer'), findsNothing);
    });

    // TEAM-206: the one-line disclaimer of 03-onboarding §4 per host kind.
    group('disclaimer per host kind', () {
      const expected = {
        OrchestrationHostKind.pc:
            'Runs as fast as your computer; keep it awake',
        OrchestrationHostKind.laptop:
            'Sleep and lid-close pause the team; runs resume on wake',
        OrchestrationHostKind.wsl:
            'Sleep and lid-close pause the team; runs resume on wake. '
            'WSL also stops when its last terminal closes.',
        OrchestrationHostKind.phone:
            'Android may stop it when the screen is off; slower than a computer',
      };
      for (final entry in expected.entries) {
        testWidgets('${entry.key.name} shows its line', (tester) async {
          final (controller, _) = await boot(
            hostMode: entry.key.mode,
            hostKind: entry.key,
          );
          await pumpCard(tester, controller);
          final line = find.byKey(const ValueKey('team-card-disclaimer'));
          expect(line, findsOneWidget);
          expect(tester.widget<Text>(line).data, entry.value);
          // Exactly one disclaimer: no other kind's line leaks in.
          for (final other in expected.values) {
            expect(
              find.text(other),
              other == entry.value ? findsOneWidget : findsNothing,
            );
          }
          // Laptop and WSL are still "On the computer".
          expect(
            find.text(
              entry.key.mode == OrchestrationHostMode.phone
                  ? 'On this phone'
                  : 'On the computer',
            ),
            findsOneWidget,
          );
        });
      }

      testWidgets('a config without a kind shows the mode default', (
        tester,
      ) async {
        final (controller, _) = await boot();
        await pumpCard(tester, controller);
        expect(find.text(expected[OrchestrationHostKind.pc]!), findsOneWidget);
      });

      testWidgets('the line is there while loading and in the empty state', (
        tester,
      ) async {
        final (loading, _) = await boot(
          started: false,
          hostKind: OrchestrationHostKind.laptop,
        );
        await pumpCard(tester, loading);
        expect(find.byKey(const ValueKey('team-card-loading')), findsOneWidget);
        expect(
          find.text(expected[OrchestrationHostKind.laptop]!),
          findsOneWidget,
        );
        final (empty, _) = await boot(
          configure: (g) => g.runsOverride = const [],
          hostKind: OrchestrationHostKind.wsl,
        );
        await pumpCard(tester, empty);
        expect(find.byKey(const ValueKey('team-card-empty')), findsOneWidget);
        expect(find.text(expected[OrchestrationHostKind.wsl]!), findsOneWidget);
      });

      testWidgets('Arabic carries the laptop line', (tester) async {
        final (controller, _) = await boot(
          hostKind: OrchestrationHostKind.laptop,
        );
        await pumpCard(tester, controller, locale: const Locale('ar'));
        final l10n = lookupAppLocalizations(const Locale('ar'));
        expect(find.text(l10n.teamUiHostKindDisclaimerLaptop), findsOneWidget);
        expect(
          l10n.teamUiHostKindDisclaimerLaptop,
          isNot(expected[OrchestrationHostKind.laptop]),
        );
      });
    });

    testWidgets('runs beyond three collapse; completed runs collapse', (
      tester,
    ) async {
      OrchestrationRun run(String id, RunState state, int minutesAgo) =>
          OrchestrationRun(
            id: id,
            title: 'Run $id',
            state: state,
            kind: RunKind.formula,
            stepCount: 4,
            completedSteps: state == RunState.completed ? 4 : 1,
            updatedAt: clock.subtract(Duration(minutes: minutesAgo)),
          );
      final (controller, _) = await boot(
        configure: (g) => g
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
          ],
      );
      await pumpCard(tester, controller);
      // Active first (newest first), then blocked; waiting falls off.
      expect(
        find.byKey(const ValueKey('team-card-run-work-new')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('team-card-run-work-old')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('team-card-run-plan-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('team-card-run-blocked-1')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('team-card-run-wait-1')), findsNothing);
      expect(find.byKey(const ValueKey('team-card-run-done-1')), findsNothing);
      expect(find.text('2 more runs'), findsOneWidget);
      expect(find.text('2 completed runs'), findsOneWidget);
      // The headline is the newest active run: 1 of 4 steps.
      expect(find.text('25% done.'), findsOneWidget);
      expect(find.text('Run work-new is being worked on.'), findsOneWidget);
      expect(find.byKey(const ValueKey('team-card-bar-done')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('team-card-bar-working')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('team-card-bar-blocked')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('blocked', () {
    testWidgets('a blocked run shows the amber segment and needs you', (
      tester,
    ) async {
      final (controller, _) = await boot(configure: blockedShape);
      expect(controller.snapshot.runs.single.state, RunState.blocked);
      expect(controller.attentionCount, 1);
      await pumpCard(tester, controller);

      expect(find.byKey(const ValueKey('team-card-needs-you')), findsOneWidget);
      expect(find.text('1 needs you'), findsOneWidget);
      expect(find.text('50% done.'), findsOneWidget);
      // The pending choice names a session the fixture has no agent for,
      // so the sentence stays with the run's own state.
      expect(
        find.text('Add subtract function to calc.py is blocked.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('team-card-bar-done')), findsOneWidget);
      final blocked = find.byKey(const ValueKey('team-card-bar-blocked'));
      expect(blocked, findsOneWidget);
      final theme = Theme.of(tester.element(blocked));
      expect(
        tester.widget<ColoredBox>(blocked).color,
        AppTheme.statusColor(theme, AppStatusTone.attention),
        reason: 'blocked-by-dependency is amber, never red',
      );
      expect(find.text('Blocked'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a gate on the run\'s work item names the decision', (
      tester,
    ) async {
      final (controller, _) = await boot(
        configure: (g) {
          blockedShape(g);
          g.gatesOverride = [
            for (final gate in g.gatesOverride!)
              OrchestrationGate(
                id: gate.id,
                kind: gate.kind,
                title: gate.title,
                workId: 'oc-loy',
                agentId: gate.agentId,
                choices: gate.choices,
              ),
          ];
        },
      );
      await pumpCard(tester, controller);
      expect(
        find.text(
          'Add subtract function to calc.py is waiting for your decision.',
        ),
        findsOneWidget,
      );
      expect(find.text('1 needs you'), findsOneWidget);
    });
  });

  // TEAM-115: the host's internals never leak into the card.
  group('waiting for merge (TEAM-117)', () {
    testWidgets('a batch whose work is in the refinery\'s hands waits for '
        'the merge: word, sentence, no Working', (tester) async {
      final (controller, _) = await boot(configure: handedToRefineryShape);
      await pumpCard(tester, controller);
      expect(
        find.text(
          'Add subtract function to calc.py is waiting for the '
          'merge agent.',
        ),
        findsOneWidget,
      );
      expect(find.text('Waiting for merge'), findsOneWidget);
      expect(find.text('Waiting for an agent'), findsNothing);
      expect(find.text('Working'), findsNothing);
      expect(find.textContaining('is being worked on'), findsNothing);
      expect(find.text('0% done.'), findsOneWidget);
      expect(find.byKey(const ValueKey('team-card-needs-you')), findsNothing);
      // The strip under the row names the merge wait.
      expect(find.byKey(const ValueKey('team-card-cycle')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('what the person sees', () {
    OrchestrationRun run(
      String id,
      RunState state, {
      bool upkeep = false,
      int minutesAgo = 1,
    }) => OrchestrationRun(
      id: id,
      title: upkeep ? 'mol-$id-patrol' : 'Run $id',
      state: state,
      kind: RunKind.formula,
      formula: upkeep ? 'mol-$id-patrol' : 'ship',
      stepCount: 4,
      completedSteps: state == RunState.completed ? 4 : 1,
      isUpkeep: upkeep,
      updatedAt: clock.subtract(Duration(minutes: minutesAgo)),
    );

    testWidgets('upkeep runs are neither rows nor counted', (tester) async {
      final (controller, _) = await boot(
        configure: (g) => g
          ..workOverride = const []
          ..gatesOverride = const []
          ..runsOverride = [
            run('refinery', RunState.planning, upkeep: true),
            run('deacon', RunState.planning, upkeep: true, minutesAgo: 2),
            run('witness', RunState.completed, upkeep: true, minutesAgo: 3),
            run('shutdown', RunState.failed, upkeep: true, minutesAgo: 4),
            run('mine', RunState.working, minutesAgo: 5),
            run('done', RunState.completed, minutesAgo: 6),
          ],
      );
      await pumpCard(tester, controller);
      // The person's run heads the card; no patrol is a row.
      expect(find.text('Run mine is being worked on.'), findsOneWidget);
      expect(find.byKey(const ValueKey('team-card-run-mine')), findsOneWidget);
      expect(find.textContaining('mol-'), findsNothing);
      expect(find.textContaining('patrol'), findsNothing);
      // Only the person's completed run is counted; nothing is "more".
      expect(find.text('1 completed run'), findsOneWidget);
      expect(find.byKey(const ValueKey('team-card-more-runs')), findsNothing);
      // A failed patrol raises nothing.
      expect(find.byKey(const ValueKey('team-card-needs-you')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('only upkeep is the empty card', (tester) async {
      final (controller, _) = await boot(
        configure: (g) => g
          ..workOverride = const []
          ..gatesOverride = const []
          ..runsOverride = [
            run('refinery', RunState.planning, upkeep: true),
            run('deacon', RunState.completed, upkeep: true),
          ],
      );
      await pumpCard(tester, controller);
      expect(find.byKey(const ValueKey('team-card-empty')), findsOneWidget);
      expect(find.text('No runs yet.'), findsOneWidget);
      expect(find.byKey(const ValueKey('team-card-hero')), findsNothing);
    });

    testWidgets('dots are the live agents; red only when crashed', (
      tester,
    ) async {
      final (controller, _) = await boot(
        configure: (g) => g.agentsOverride = const [
          OrchestrationAgent(id: 'w', name: 'w', state: AgentState.working),
          OrchestrationAgent(id: 'i', name: 'i', state: AgentState.idle),
          OrchestrationAgent(id: 'c', name: 'c', state: AgentState.crashed),
          OrchestrationAgent(id: 'q', name: 'q', state: AgentState.waiting),
          OrchestrationAgent(id: 's', name: 's', state: AgentState.stopped),
          OrchestrationAgent(
            id: 'boot',
            name: 'gastown.boot',
            state: AgentState.stopped,
            suspended: true,
          ),
          OrchestrationAgent(
            id: 'mayor',
            name: 'gastown.mayor',
            state: AgentState.stopped,
            suspended: true,
          ),
        ],
      );
      await pumpCard(tester, controller);
      expect(find.text('1 agent working'), findsOneWidget);
      expect(agentDots(), findsNWidgets(4));
      for (final off in ['s', 'boot', 'mayor']) {
        expect(find.byKey(ValueKey('team-card-agent-$off')), findsNothing);
      }
      Color dotColor(String id) =>
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byKey(ValueKey('team-card-agent-$id')),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color!;
      final colors = Theme.of(
        tester.element(find.byType(TeamCard)),
      ).colorScheme;
      expect(dotColor('c'), colors.error);
      expect(dotColor('w'), colors.primary);
      expect(dotColor('i'), isNot(colors.error));
      expect(dotColor('q'), isNot(colors.error));
      final summary = tester.widget<Semantics>(
        find.byKey(const ValueKey('team-card-constellation')),
      );
      expect(summary.properties.label, startsWith('4 agents:'));
    });

    testWidgets('the header names the host by the team URL', (tester) async {
      final (named, _) = await boot(url: 'https://pop-os:7000');
      await pumpCard(tester, named);
      final name = find.byKey(const ValueKey('team-card-host-name'));
      expect(tester.widget<Text>(name).data, 'pop-os');
      expect(tester.widget<Text>(name).textDirection, TextDirection.ltr);
      expect(find.text('Workstation'), findsNothing);
      expect(find.text('On the computer'), findsOneWidget);
      expect(find.text('city bright-lights'), findsOneWidget);

      final (addressed, _) = await boot(url: 'http://100.126.15.6:7000/');
      await pumpCard(tester, addressed);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('team-card-host-name')))
            .data,
        '100.126.15.6',
      );
      expect(find.text('Workstation'), findsNothing);
    });
  });

  group('E: empty', () {
    testWidgets('no runs: "No runs yet" with the host', (tester) async {
      final (controller, _) = await boot(
        configure: (g) => g.runsOverride = const [],
      );
      await pumpCard(tester, controller);
      expect(find.byKey(const ValueKey('team-card-empty')), findsOneWidget);
      expect(find.text('No runs yet.'), findsOneWidget);
      expect(find.text('Start runs from the host for now.'), findsOneWidget);
      expect(find.text('On the computer'), findsOneWidget);
      expect(find.byKey(const ValueKey('team-card-open')), findsOneWidget);
      expect(find.byKey(const ValueKey('team-card-refresh')), findsOneWidget);
      expect(find.byKey(const ValueKey('team-card-hero')), findsNothing);
    });
  });

  group('S: stale', () {
    testWidgets('shows the time and disables taps except Refresh', (
      tester,
    ) async {
      var opened = 0;
      final (controller, gateway) = await boot();
      final refreshedAt = controller.lastRefreshedAt!;
      await pumpCard(tester, controller, onOpen: () => opened += 1);
      expect(find.byKey(const ValueKey('team-card-stale')), findsNothing);

      clock = clock.add(const Duration(seconds: 61));
      expect(controller.isStale, isTrue);
      await pumpCard(tester, controller, onOpen: () => opened += 1);

      expect(find.byKey(const ValueKey('team-card-stale')), findsOneWidget);
      final time = clockLabel(tester, refreshedAt);
      expect(
        find.text('Showing data from $time · host unreachable'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('team-card-open')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<InkWell>(
              find.descendant(
                of: find.byKey(const ValueKey('team-card-run-oc-xru')),
                matching: find.byType(InkWell),
              ),
            )
            .onTap,
        isNull,
      );
      await tester.tap(
        find.byKey(const ValueKey('team-card-open')),
        warnIfMissed: false,
      );
      await tester.tap(
        find.byKey(const ValueKey('team-card-run-oc-xru')),
        warnIfMissed: false,
      );
      expect(opened, 0);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('team-card-refresh')))
            .onPressed,
        isNotNull,
      );

      // Refresh refetches and the banner goes.
      final before = gateway.count('runs');
      await tester.tap(find.byKey(const ValueKey('team-card-refresh')));
      await tester.pumpAndSettle();
      expect(gateway.count('runs'), before + 1);
      expect(controller.isStale, isFalse);
      expect(find.byKey(const ValueKey('team-card-stale')), findsNothing);
      expect(find.byKey(const ValueKey('team-card-data')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a dropped stream is stale too', (tester) async {
      final (controller, gateway) = await boot();
      await pumpCard(tester, controller);
      gateway.stream.addError(StateError('dropped'));
      await tester.pump();
      expect(controller.streamStatus, OrchestrationStreamStatus.reconnecting);
      await tester.pump();
      expect(find.byKey(const ValueKey('team-card-stale')), findsOneWidget);
    });

    testWidgets('a failed read keeps the data and says so', (tester) async {
      final (controller, gateway) = await boot();
      final refreshedAt = controller.lastRefreshedAt!;
      await pumpCard(tester, controller);
      gateway.failReads = true;
      await controller.refresh();
      await tester.pump();
      expect(controller.lastError?.kind, OrchestrationErrorKind.readFailed);
      expect(find.byKey(const ValueKey('team-card-data')), findsOneWidget);
      expect(
        find.text(
          'Last refresh failed · showing data from '
          '${clockLabel(tester, refreshedAt)}',
        ),
        findsOneWidget,
      );
      expect(find.text('0% done.'), findsOneWidget);
    });
  });

  group('X: error', () {
    final cases = <ProbeVerdict, String>{
      const ProbeNotGasCity(statusCode: 200, detail: 'html'):
          'This server doesn’t run an AI team yet. Set one up on the '
          'computer — it takes a few minutes.',
      const ProbeCityNotRunning(city: 'bright-lights'):
          'The team host is starting. Try again in a moment.',
      const ProbePlainHttpRefused(host: 'example.com'):
          'AI Team works over your Tailscale network or on this device. Use '
          'tailscale serve on the computer, then try again.',
      const ProbeUnreachable(error: 'refused'):
          'The team host can’t be reached. AI Team works over your Tailscale '
          'network or on this device.',
    };
    for (final entry in cases.entries) {
      testWidgets('${entry.key.runtimeType} shows honest copy and Retry', (
        tester,
      ) async {
        ProbeVerdict verdict = entry.key;
        final (controller, gateway) = await boot(probe: (_) async => verdict);
        expect(controller.phase, OrchestrationPhase.failed);
        await pumpCard(tester, controller);
        expect(find.byKey(const ValueKey('team-card-error')), findsOneWidget);
        expect(find.text(entry.value), findsOneWidget);
        expect(find.text('AI Team · Gas City'), findsOneWidget);
        expect(find.byKey(const ValueKey('team-card-open')), findsNothing);
        expect(find.byKey(const ValueKey('team-card-hero')), findsNothing);

        // Retry probes again; once the host answers the card fills in.
        verdict = ProbeFound(host: gateway.host!, city: 'bright-lights');
        await tester.tap(find.byKey(const ValueKey('team-card-retry')));
        await tester.pumpAndSettle();
        expect(controller.phase, OrchestrationPhase.ready);
        expect(find.byKey(const ValueKey('team-card-data')), findsOneWidget);
        expect(find.text('0% done.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('motion', () {
    testWidgets('reduced motion: no animation controller, no ticker', (
      tester,
    ) async {
      final (controller, _) = await boot();
      await pumpCard(tester, controller, reduceMotion: true);
      final state = tester.state<TeamCardState>(find.byType(TeamCard));
      expect(state.debugHasAnimation, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(agentDots(), findsNWidgets(5));
      expect(pulses(), findsNothing);
    });

    testWidgets('with motion allowed one controller pulses working dots', (
      tester,
    ) async {
      final (controller, gateway) = await boot();
      await pumpCard(tester, controller, reduceMotion: false);
      final state = tester.state<TeamCardState>(find.byType(TeamCard));
      expect(state.debugHasAnimation, isTrue);
      expect(tester.binding.transientCallbackCount, 1);
      // Two working agents share the one controller.
      expect(pulses(), findsNWidgets(2));

      // Going stale stops the pulse; nothing on the card breathes then.
      gateway.stream.addError(StateError('dropped'));
      await tester.pump();
      expect(state.debugHasAnimation, isFalse);
      // The buttons' own disabled-colour fades end; the pulse is gone.
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      expect(pulses(), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no working agents and no moving batch: no controller '
        'even with motion', (tester) async {
      // A formula run heads the card: no dispatch cycle strip, and the
      // one idle agent gives nothing to pulse.
      final (controller, _) = await boot(
        configure: (g) => g
          ..agentsOverride = const [
            OrchestrationAgent(id: 'a', name: 'a', state: AgentState.idle),
          ]
          ..runsOverride = [
            OrchestrationRun(
              id: 'ship-1',
              title: 'Run ship-1',
              state: RunState.working,
              kind: RunKind.formula,
              stepCount: 4,
              completedSteps: 1,
              updatedAt: clock,
            ),
          ],
      );
      await pumpCard(tester, controller, reduceMotion: false);
      final state = tester.state<TeamCardState>(find.byType(TeamCard));
      expect(state.debugHasAnimation, isFalse);
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.text('No agents working'), findsOneWidget);
      expect(agentDots(), findsOneWidget);
      expect(find.byKey(const ValueKey('team-card-cycle')), findsNothing);
    });

    testWidgets('no working agents but a moving batch: the one controller '
        'pulses the cycle dot only', (tester) async {
      // TEAM-116: the headline batch (the fixture convoy, routed and
      // waiting for an agent) breathes with the card's single pulse.
      final (controller, _) = await boot(
        configure: (g) => g.agentsOverride = const [
          OrchestrationAgent(id: 'a', name: 'a', state: AgentState.idle),
        ],
      );
      await pumpCard(tester, controller, reduceMotion: false);
      final state = tester.state<TeamCardState>(find.byType(TeamCard));
      expect(state.debugHasAnimation, isTrue);
      expect(tester.binding.transientCallbackCount, 1);
      expect(pulses(), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('team-card-cycle')),
          matching: find.byType(ScaleTransition),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });
}
