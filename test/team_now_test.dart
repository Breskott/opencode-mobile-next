// What the AI Team is doing and what happens next (the owner, build 2054:
// "I have no idea to know when is next cycle and whats happening?", "Wtf",
// "Taking a year"; docs/qa/team-discover-2026-09-25): asleep is not
// paused; a waiting task says for how long and when a worker starts; a
// stuck one says no worker started and offers the one action that helps;
// the home's Now line; the agent screen by role, with a worker that did not
// start; live output that never spins forever.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/team/builtin_team.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/agent_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:opencode_mobile/ui/screens/team_conversation/team_conversation.dart'
    show TeamWatchLiveScreen;
import 'package:opencode_mobile/ui/widgets/team_now.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _clock = DateTime.utc(2026, 9, 25, 19, 57);

Finder _key(String key) => find.byKey(ValueKey(key));

String _fixturePath() {
  var dir = Directory.current;
  for (var i = 0; i < 5; i++) {
    final candidate = Directory('${dir.path}/tool/qa/gascity_fixture');
    if (candidate.existsSync()) return candidate.path;
    dir = dir.parent;
  }
  throw StateError('tool/qa/gascity_fixture not found');
}

/// The recorded fixture with a scenario's runs and agents, the controls it
/// allows, the controls it was sent, and an output stream that stays
/// silent.
class _Gateway
    implements OrchestrationGateway, OrchestrationAgentOutputGateway {
  _Gateway(this.inner, {required this.controls});

  final FixtureOrchestrationGateway inner;
  final bool controls;
  final events_ = StreamController<OrchestrationEvent>.broadcast();
  final sent = <(String, AgentControlAction)>[];

  /// Output that never says anything.
  final silence = StreamController<AgentOutputEvent>.broadcast();
  List<OrchestrationRun> runsOverride = const [];
  List<OrchestrationAgent> agentsOverride = const [];

  @override
  OrchestrationCapabilities get capabilities => controls
      ? OrchestrationCapabilities.gascityFront
      : const OrchestrationCapabilities(
          runs: true,
          agents: true,
          agentOutput: true,
        );
  @override
  OrchestrationHostIdentity? get host => const OrchestrationHostIdentity(
    provider: 'gascity',
    url: 'http://127.0.0.1:8472',
    hostMode: OrchestrationHostMode.phone,
  );
  @override
  bool get isClosed => inner.isClosed;
  @override
  Future<void> close() async {
    await events_.close();
    await silence.close();
    await inner.close();
  }

  @override
  Stream<AgentOutputEvent> agentOutput(String sessionId) => silence.stream;

  @override
  Future<List<OrchestrationProject>> projects() => inner.projects();
  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) async =>
      runsOverride;
  @override
  Future<OrchestrationRun?> run(String id) async => null;
  @override
  Future<List<WorkItem>> work({String? projectId}) async => const [];
  @override
  Future<List<WorkItem>> readyWork({String? projectId}) async => const [];
  @override
  Future<WorkItem?> workItem(String id) async => null;
  @override
  Future<List<OrchestrationAgent>> agents() async => agentsOverride;
  @override
  Future<OrchestrationAgent?> agent(String id) async => null;
  @override
  Future<List<OrchestrationGate>> gates() async => const [];
  @override
  Future<OrchestrationUsage?> usage() async => null;
  @override
  Future<List<ActivityEvent>> activity({
    int? afterSeq,
    int limit = 100,
  }) async => const [];
  @override
  Stream<OrchestrationEvent> events({
    EventCursor resumeFrom = EventCursor.none,
  }) => events_.stream;
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
  }) async {
    sent.add((agentId, action));
    return MutationReceipt(
      id: requestId,
      status: MutationReceiptStatus.accepted,
    );
  }

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

/// The owner's worker: a pool polecat of demo-app.
OrchestrationAgent _worker({
  AgentState state = AgentState.stopped,
  String rawState = 'stopped',
  bool suspended = false,
}) => OrchestrationAgent(
  id: 'demo-app/gastown.furiosa',
  name: 'demo-app/gastown.furiosa',
  state: state,
  rawState: rawState,
  suspended: suspended,
  pool: 'demo-app/gastown.polecat',
  pack: 'gastown',
  sessionId: 'ph-yqt',
  sessionStartedAt: _clock.subtract(const Duration(minutes: 2)),
);

OrchestrationAgent _reviewer({bool suspended = false}) => OrchestrationAgent(
  id: 'demo-app/refinery',
  name: 'demo-app/refinery',
  state: AgentState.stopped,
  rawState: suspended ? 'suspended' : 'stopped',
  suspended: suspended,
);

OrchestrationRun _task({required Duration waited}) => OrchestrationRun(
  id: 'da-r7d',
  title: 'Get all skills required online',
  state: RunState.waiting,
  kind: RunKind.formula,
  startedAt: _clock.subtract(waited),
);

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  late OrchestrationStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = OrchestrationStore(await SharedPreferences.getInstance());
  });

  /// A team on this phone (the in-app team, whose checks run every
  /// minute), or on a computer whose checks the app cannot know.
  Future<(OrchestrationController, _Gateway)> boot({
    required List<OrchestrationRun> runs,
    required List<OrchestrationAgent> agents,
    bool controls = true,
    bool onPhone = true,
  }) async {
    final gateway =
        _Gateway(
            FixtureOrchestrationGateway(fixturePath: _fixturePath()),
            controls: controls,
          )
          ..runsOverride = runs
          ..agentsOverride = agents;
    final config = onPhone
        ? BuiltinTeam.config(now: _clock)
        : OrchestrationConfig(
            provider: OrchestrationProvider.fixture,
            url: _fixturePath(),
            enabledAt: _clock,
          );
    final controller = OrchestrationController(
      profile: ServerProfile(
        id: 'phone',
        name: 'This phone',
        baseUrl: 'http://127.0.0.1:4097',
        orchestration: config,
      ),
      config: config,
      store: store,
      probe: (_) async => ProbeFound(host: gateway.host!),
      gatewayFactory: (_, _) => gateway,
      now: () => _clock,
    );
    addTearDown(controller.dispose);
    await controller.start();
    return (controller, gateway);
  }

  Future<void> pumpHome(
    WidgetTester tester,
    OrchestrationController controller,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(TeamHomeScreen(controller: controller, now: () => _clock)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Tears the tree down and lets a sent control's confirmation window and
  /// its snackbar run out, so no timer outlives the test.
  Future<void> done(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 61));
  }

  String text(WidgetTester tester, String key) {
    final widget = tester.widget(_key(key));
    return switch (widget) {
      Text(:final data?) => data,
      Text(:final textSpan?) => textSpan.toPlainText(),
      KitStatusLine(:final message) => message,
      _ => '$widget',
    };
  }

  group('asleep is not paused', () {
    testWidgets('agents asleep: no "Paused"', (tester) async {
      final (controller, _) = await boot(
        runs: [_task(waited: const Duration(seconds: 30))],
        agents: [_worker(), _reviewer()],
      );
      await pumpHome(tester, controller);
      expect(find.text(_en.teamUiHostPhrasePhone), findsOneWidget);
      expect(find.textContaining(_en.teamUiHostPhrasePaused), findsNothing);
      await done(tester);
    });

    testWidgets('agents switched off on purpose: Paused, with Resume', (
      tester,
    ) async {
      final (controller, gateway) = await boot(
        runs: [_task(waited: const Duration(seconds: 30))],
        agents: [
          _worker(rawState: 'suspended', suspended: true),
          _reviewer(suspended: true),
        ],
      );
      await pumpHome(tester, controller);
      expect(
        find.text(
          '${_en.teamUiHostPhrasePhone} · ${_en.teamUiHostPhrasePaused}',
        ),
        findsOneWidget,
      );
      expect(text(tester, 'team-home-now-paused'), _en.teamNowPausedLine);
      await tester.tap(find.text(_en.teamUiControlResume));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(gateway.sent, [
        ('demo-app/gastown.furiosa', AgentControlAction.resume),
        ('demo-app/refinery', AgentControlAction.resume),
      ]);
      await done(tester);
    });
  });

  group('a waiting task says when a worker starts', () {
    testWidgets('fresh: how often the team checks, on the task\'s row', (
      tester,
    ) async {
      final (controller, _) = await boot(
        runs: [_task(waited: const Duration(seconds: 30))],
        agents: [_worker()],
      );
      await pumpHome(tester, controller);
      expect(
        text(tester, 'team-home-run-state-da-r7d'),
        '${_en.teamUiCardRunStateWaiting} · ${_en.teamNowChecksEveryMinute}',
      );
      // The task's own row says it; no Now line repeats the task above
      // the list (owner rule 2026-09-27).
      expect(_key('team-home-now-waiting'), findsNothing);
      await done(tester);
    });

    testWidgets('on a computer: what starts a worker, not a made-up time', (
      tester,
    ) async {
      final (controller, _) = await boot(
        runs: [_task(waited: const Duration(minutes: 1))],
        agents: [_worker()],
        onPhone: false,
      );
      await pumpHome(tester, controller);
      expect(
        text(tester, 'team-home-run-state-da-r7d'),
        '${_en.teamUiCardRunStateWaiting} · 1 min · ${_en.teamNowNextCheck}',
      );
      await done(tester);
    });

    testWidgets('stuck: how long, no worker started, Start a worker wakes '
        'one', (tester) async {
      final (controller, gateway) = await boot(
        runs: [_task(waited: const Duration(minutes: 6))],
        agents: [_worker(), _reviewer()],
      );
      await pumpHome(tester, controller);
      expect(
        text(tester, 'team-home-run-state-da-r7d'),
        '${_en.teamUiCardRunStateWaiting} · 6 min · '
        '${_en.teamNowNoWorkerStarted}',
      );
      // The Now line is about the team, never the task's title or its
      // wait: the row above says those (slice-P5.1).
      expect(text(tester, 'team-home-now-stuck'), _en.teamNowNotStartingLine);
      expect(
        text(tester, 'team-home-now-stuck'),
        isNot(contains('Get all skills required online')),
      );
      await tester.tap(_key('team-home-now-wake'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(gateway.sent, [
        ('demo-app/gastown.furiosa', AgentControlAction.resume),
      ]);
      await done(tester);
    });

    testWidgets('stuck without controls: Why? opens the technical details', (
      tester,
    ) async {
      final (controller, _) = await boot(
        runs: [_task(waited: const Duration(minutes: 6))],
        agents: [_worker()],
        controls: false,
      );
      await pumpHome(tester, controller);
      expect(_key('team-home-now-wake'), findsNothing);
      await tester.tap(_key('team-home-now-why'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(BottomSheet), findsOneWidget);
      await done(tester);
    });
  });

  group('the agent screen', () {
    Future<void> pumpAgent(
      WidgetTester tester,
      OrchestrationController controller,
    ) async {
      tester.view.physicalSize = const Size(412, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          AgentScreen(
            controller: controller,
            agentId: 'demo-app/gastown.furiosa',
            now: () => _clock,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('named by role; engine names only under details; no '
        '"Not reported" rows; a worker that did not start says so', (
      tester,
    ) async {
      final (controller, gateway) = await boot(
        runs: [_task(waited: const Duration(minutes: 6))],
        agents: [_worker()],
      );
      await pumpAgent(tester, controller);
      expect(
        find.descendant(
          of: _key('team-agent-title'),
          matching: find.text('Worker · furiosa'),
        ),
        findsOneWidget,
      );
      expect(find.text('demo-app/gastown.furiosa'), findsNothing);
      expect(find.text('demo-app/gastown.polecat'), findsNothing);
      expect(find.text(_en.teamUiAgentValueUnknown), findsNothing);
      expect(_key('team-agent-did-not-start'), findsOneWidget);
      expect(find.text(_en.teamAgentDidNotStartTitle), findsOneWidget);
      await tester.tap(find.text(_en.teamAgentStartIt));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(gateway.sent, [
        ('demo-app/gastown.furiosa', AgentControlAction.resume),
      ]);
      await done(tester);
    });

    testWidgets('a working worker has no "did not start" notice', (
      tester,
    ) async {
      final (controller, _) = await boot(
        runs: [_task(waited: const Duration(minutes: 6))],
        agents: [_worker(state: AgentState.working, rawState: 'active')],
      );
      await pumpAgent(tester, controller);
      expect(_key('team-agent-did-not-start'), findsNothing);
      await done(tester);
    });
  });

  group('live output never spins forever', () {
    Future<void> pumpOutput(
      WidgetTester tester,
      OrchestrationController controller,
    ) async {
      await tester.pumpWidget(
        _app(
          TeamWatchLiveScreen(
            team: controller,
            agentId: 'demo-app/gastown.furiosa',
          ),
        ),
      );
      await tester.pump();
    }

    String status(WidgetTester tester) =>
        tester.widget<KitStatusLine>(_key('chat-watching-banner')).message;

    testWidgets('not running: says so at once, with the action', (
      tester,
    ) async {
      final (controller, _) = await boot(runs: const [], agents: [_worker()]);
      await pumpOutput(tester, controller);
      expect(status(tester), _en.teamOutputNotRunning('furiosa'));
      expect(_key('chat-watching-live-wake'), findsOneWidget);
      await done(tester);
    });

    testWidgets('running and silent on a phone: starting up after 8 s', (
      tester,
    ) async {
      final (controller, _) = await boot(
        runs: const [],
        agents: [_worker(state: AgentState.working, rawState: 'active')],
      );
      await pumpOutput(tester, controller);
      expect(status(tester), _en.teamUiAgentOutputConnecting);
      await tester.pump(const Duration(seconds: 9));
      expect(status(tester), startsWith('Starting up · '));
      expect(status(tester), contains('a few minutes on a phone'));
      await done(tester);
    });
  });

  test('the in-app team checks every minute (its own tuning)', () {
    expect(
      teamCheckPhrase(_en, const Duration(minutes: 1)),
      _en.teamNowChecksEveryMinute,
    );
    expect(
      teamStuckAfter(const Duration(minutes: 1)),
      const Duration(minutes: 2),
    );
    expect(teamStuckAfter(null), const Duration(minutes: 3));
  });
}
