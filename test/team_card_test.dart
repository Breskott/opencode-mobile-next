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
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/screens/workspace_screen.dart';
import 'package:opencode_mobile/ui/widgets/team_card.dart';
import 'package:opencode_mobile/ui/widgets/team_technical_details.dart';
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

  /// The card's header line: "AI Team · <where it runs>".
  String titleOf(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('team-card-title')))
      .textSpan!
      .toPlainText();

  /// A task row's one supporting line.
  String? lineOf(WidgetTester tester, String id) {
    final line = find.descendant(
      of: find.byKey(ValueKey('team-card-run-line-$id')),
      matching: find.byType(RichText),
    );
    return line.evaluate().isEmpty
        ? null
        : tester.widget<RichText>(line.first).text.toPlainText();
  }

  /// Engine words and numbers the card never shows (AI Team redesign).
  void noEngineWords() {
    for (final word in [
      'Gas City',
      'convoy',
      'formula',
      'bright-lights',
      '%',
      'sling-',
    ]) {
      expect(find.textContaining(word), findsNothing, reason: word);
    }
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

    testWidgets('with a config the Work tab lists the team, not the card', (
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
      // docs/design/team-conversation-2026-09-26.md: the team's tasks are
      // rows in the Work tab's one list; its page is reached from Settings
      // (owner rule R4), so Work has no door row.
      expect(find.byType(TeamCard), findsNothing);
      expect(find.byKey(const ValueKey('team-work-door')), findsNothing);
      expect(
        find.byKey(const ValueKey('team-work-task-oc-xru')),
        findsOneWidget,
      );
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
      expect(find.byKey(const ValueKey('team-card-data')), findsNothing);
    });
  });

  group('N: normal', () {
    testWidgets('the header says where the team runs; a task is one row '
        'with one plain line', (tester) async {
      var opened = 0;
      final (controller, _) = await boot();
      await pumpCard(tester, controller, onOpen: () => opened += 1);

      expect(find.byKey(const ValueKey('team-card-data')), findsOneWidget);
      expect(titleOf(tester), startsWith('AI Team · On '));
      // The host is named by the team URL, never by the profile.
      expect(find.textContaining('Workstation'), findsNothing);
      expect(find.byKey(const ValueKey('team-card-needs-you')), findsNothing);
      // One convoy, routed and waiting: named by its work, not its bead.
      expect(
        find.byKey(const ValueKey('team-card-run-oc-xru')),
        findsOneWidget,
      );
      expect(find.text('Add subtract function to calc.py'), findsOneWidget);
      // What happens next follows (docs/qa/team-discover-2026-09-25): the
      // recorded task has waited days, so no worker has started.
      expect(lineOf(tester, 'oc-xru'), startsWith('Waiting for a worker · '));
      expect(lineOf(tester, 'oc-xru'), endsWith('no worker has started'));
      noEngineWords();
      expect(find.byKey(const ValueKey('team-card-stale')), findsNothing);
      // The card refreshes itself: no Refresh button.
      expect(find.byKey(const ValueKey('team-card-refresh')), findsNothing);

      // The header and a task row both open the team.
      await tester.tap(find.byKey(const ValueKey('team-card-open')));
      expect(opened, 1);
      await tester.tap(find.byKey(const ValueKey('team-card-run-oc-xru')));
      expect(opened, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a phone host says so', (tester) async {
      final (controller, _) = await boot(hostMode: OrchestrationHostMode.phone);
      await pumpCard(tester, controller);
      expect(titleOf(tester), 'AI Team · On this phone');
    });

    testWidgets('a named computer is named; an address is not', (tester) async {
      final (named, _) = await boot(url: 'https://pop-os:7000');
      await pumpCard(tester, named);
      expect(titleOf(tester), 'AI Team · On pop-os');
      expect(find.textContaining('Workstation'), findsNothing);

      final (addressed, _) = await boot(url: 'http://100.126.15.6:7000/');
      await pumpCard(tester, addressed);
      expect(titleOf(tester), 'AI Team · On your computer');
      expect(find.textContaining('100.126.15.6'), findsNothing);
    });

    // TEAM-206: the one-line disclaimer of 03-onboarding §4 per host kind,
    // moved from the card to Technical details by the AI Team redesign.
    group('disclaimer per host kind (Technical details)', () {
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

      Future<String?> disclaimerIn(
        WidgetTester tester,
        OrchestrationController controller, {
        Locale locale = const Locale('en'),
      }) async {
        await tester.pumpWidget(
          app(
            Builder(
              builder: (context) => TextButton(
                onPressed: () => showTeamHostDetailsSheet(context, controller),
                child: const Text('details'),
              ),
            ),
            locale: locale,
          ),
        );
        await tester.tap(find.text('details'));
        await tester.pumpAndSettle();
        final line = find.byKey(const ValueKey('team-host-disclaimer'));
        return line.evaluate().isEmpty
            ? null
            : tester.widget<KitText>(line).text;
      }

      for (final entry in expected.entries) {
        testWidgets('${entry.key.name} shows its line, and only its line', (
          tester,
        ) async {
          final (controller, _) = await boot(
            hostMode: entry.key.mode,
            hostKind: entry.key,
          );
          expect(await disclaimerIn(tester, controller), entry.value);
          for (final other in expected.values) {
            expect(
              find.text(other),
              other == entry.value ? findsOneWidget : findsNothing,
            );
          }
        });
      }

      testWidgets('a config without a kind shows the mode default', (
        tester,
      ) async {
        final (controller, _) = await boot();
        expect(
          await disclaimerIn(tester, controller),
          expected[OrchestrationHostKind.pc],
        );
      });

      testWidgets('Arabic carries the laptop line', (tester) async {
        final (controller, _) = await boot(
          hostKind: OrchestrationHostKind.laptop,
        );
        final l10n = lookupAppLocalizations(const Locale('ar'));
        expect(
          await disclaimerIn(tester, controller, locale: const Locale('ar')),
          l10n.teamUiHostKindDisclaimerLaptop,
        );
        expect(
          l10n.teamUiHostKindDisclaimerLaptop,
          isNot(expected[OrchestrationHostKind.laptop]),
        );
      });
    });

    testWidgets('at most two running tasks, active first; nothing counted '
        'or collapsed', (tester) async {
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
      // Active first, newest first; the rest waits on the team's home.
      expect(
        find.byKey(const ValueKey('team-card-run-work-new')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('team-card-run-work-old')),
        findsOneWidget,
      );
      for (final hidden in ['plan-1', 'blocked-1', 'wait-1', 'done-1']) {
        expect(
          find.byKey(ValueKey('team-card-run-$hidden')),
          findsNothing,
          reason: hidden,
        );
      }
      expect(lineOf(tester, 'work-new'), 'Working · 1 of 4 steps done');
      // No "N more", no completed count, no percentage or bar.
      expect(find.textContaining('more'), findsNothing);
      expect(find.textContaining('completed'), findsNothing);
      noEngineWords();
      expect(tester.takeException(), isNull);
    });
  });

  group('needs you', () {
    testWidgets('a question comes first, with Answer', (tester) async {
      final (controller, _) = await boot(configure: blockedShape);
      expect(controller.attentionCount, 1);
      await pumpCard(tester, controller);
      final question = controller.snapshot.gates.single;
      expect(find.byKey(const ValueKey('team-card-needs-you')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('team-card-question')))
            .data,
        question.title.split('\n').first,
      );
      expect(find.text('Answer'), findsOneWidget);
      // This choice names a session the fixture has no agent for, so it
      // cannot be tied to a task: the task keeps its row, under it.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('team-card-needs-you'))).dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('team-card-run-oc-xru')))
              .dy,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a question tied to a task by its work item: the task is '
        'not repeated under it', (tester) async {
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
      expect(find.byKey(const ValueKey('team-card-needs-you')), findsOneWidget);
      expect(find.byKey(const ValueKey('team-card-run-oc-xru')), findsNothing);
    });
  });

  group('reviewing (TEAM-117)', () {
    testWidgets('a task whose work is in the merge agent\'s hands reads '
        'Reviewing, never Working', (tester) async {
      final (controller, _) = await boot(configure: handedToRefineryShape);
      await pumpCard(tester, controller);
      expect(lineOf(tester, 'oc-xru'), 'Reviewing');
      expect(find.textContaining('Working'), findsNothing);
      expect(find.textContaining('Waiting for a worker'), findsNothing);
      expect(find.byKey(const ValueKey('team-card-needs-you')), findsNothing);
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
      expect(find.byKey(const ValueKey('team-card-run-mine')), findsOneWidget);
      expect(find.textContaining('mol-'), findsNothing);
      expect(find.textContaining('patrol'), findsNothing);
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
      expect(find.textContaining('Nothing running'), findsOneWidget);
    });
  });

  group('E: empty', () {
    testWidgets('no tasks: one muted line that opens the team', (tester) async {
      var opened = 0;
      final (controller, _) = await boot(
        configure: (g) => g.runsOverride = const [],
      );
      await pumpCard(tester, controller, onOpen: () => opened += 1);
      final empty = find.byKey(const ValueKey('team-card-empty'));
      expect(empty, findsOneWidget);
      expect(find.textContaining('Nothing running'), findsOneWidget);
      expect(find.byKey(const ValueKey('team-card-open')), findsOneWidget);
      await tester.tap(empty);
      expect(opened, 1);
    });
  });

  group('S: stale', () {
    testWidgets('stale: the header says Not answering, rows dim and stop '
        'opening; the header still opens the team', (tester) async {
      var opened = 0;
      final (controller, _) = await boot();
      await pumpCard(tester, controller, onOpen: () => opened += 1);
      expect(find.byKey(const ValueKey('team-card-stale')), findsNothing);

      clock = clock.add(const Duration(seconds: 61));
      expect(controller.isStale, isTrue);
      await pumpCard(tester, controller, onOpen: () => opened += 1);

      expect(find.byKey(const ValueKey('team-card-stale')), findsOneWidget);
      expect(titleOf(tester), endsWith(' · Not answering'));
      await tester.tap(
        find.byKey(const ValueKey('team-card-run-oc-xru')),
        warnIfMissed: false,
      );
      expect(opened, 0, reason: 'old rows do not open');
      // The team's home is where the person refreshes.
      await tester.tap(find.byKey(const ValueKey('team-card-open')));
      expect(opened, 1);
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
      await pumpCard(tester, controller);
      gateway.failReads = true;
      await controller.refresh();
      await tester.pump();
      expect(controller.lastError?.kind, OrchestrationErrorKind.readFailed);
      expect(find.byKey(const ValueKey('team-card-data')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('team-card-run-oc-xru')),
        findsOneWidget,
      );
      expect(titleOf(tester), endsWith(' · Not answering'));
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
        expect(find.byKey(const ValueKey('team-card-data')), findsNothing);

        // Retry probes again; once the host answers the card fills in.
        verdict = ProbeFound(host: gateway.host!, city: 'bright-lights');
        await tester.tap(find.byKey(const ValueKey('team-card-retry')));
        await tester.pumpAndSettle();
        expect(controller.phase, OrchestrationPhase.ready);
        expect(find.byKey(const ValueKey('team-card-data')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('motion', () {
    // The redesigned card shows state in words; nothing on it breathes, so
    // it never holds a ticker, whether or not motion is reduced.
    for (final reduce in [true, false]) {
      testWidgets('reduced motion $reduce: no ticker, no scheduled frame', (
        tester,
      ) async {
        final (controller, _) = await boot();
        await pumpCard(tester, controller, reduceMotion: reduce);
        await tester.pump(const Duration(seconds: 1));
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }
  });
}
