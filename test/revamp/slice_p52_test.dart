// slice-P5.2 "The team page answers questions" (docs/qa/slice-P5.2-2026-09-27):
//
// - Is my team working? Each agent's state comes from its session first
//   (ledger row 21): a worker the agents list calls working whose session
//   the host reports stopped is not counted or shown as working, and a
//   session that ended in an error is said on the team page.
// - An idle team is never "Paused" (row 20): asleep agents are asleep; only
//   agents switched off on purpose are paused.
// - What does it cost? Today's spend is the whole team's estimate and says
//   why it may be low (no price, missing history, not counting); a task's
//   own cost stays unreported (no host contract, docs/qa/codex-p52).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/team/team_agents_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_settings_screen.dart';
import 'package:opencode_mobile/ui/widgets/team_vocabulary.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _en = lookupAppLocalizations(const Locale('en'));
final _clock = DateTime.utc(2026, 9, 27, 14, 2);

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

class _Gateway extends FixtureOrchestrationGateway {
  _Gateway({this.agentList, this.usageFigure, this.extraRuns = const []})
    : super(
        fixturePath: _fixturePath(),
        hostMode: OrchestrationHostMode.phone,
        url: 'http://127.0.0.1:8472',
      );

  final List<OrchestrationAgent>? agentList;
  final OrchestrationUsage? usageFigure;
  final List<OrchestrationRun> extraRuns;

  /// The agents a wake was sent for, in order; the host never confirms.
  final woken = <String>[];

  @override
  Future<List<OrchestrationAgent>> agents() async =>
      agentList ?? await super.agents();

  @override
  Future<List<OrchestrationRun>> runs({String? projectId}) async => [
    ...await super.runs(projectId: projectId),
    ...extraRuns,
  ];

  @override
  Future<OrchestrationUsage?> usage() async => usageFigure;

  @override
  Future<MutationReceipt> controlAgent(
    String agentId,
    AgentControlAction action, {
    required String requestId,
  }) async {
    woken.add(agentId);
    return MutationReceipt(
      id: requestId,
      status: MutationReceiptStatus.pending,
      message: 'receive timeout',
    );
  }
}

Future<OrchestrationController> _team({
  List<OrchestrationAgent>? agents,
  OrchestrationUsage? usage,
  List<OrchestrationRun> runs = const [],
  bool builtin = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final config = OrchestrationConfig(
    // The team inside the app is a Gas City on the phone's own port.
    provider: builtin
        ? OrchestrationProvider.gascity
        : OrchestrationProvider.fixture,
    url: 'http://127.0.0.1:8472',
    city: 'bright-lights',
    hostMode: OrchestrationHostMode.phone,
    enabledAt: DateTime.utc(2026, 9, 10),
  );
  final team = OrchestrationController(
    profile: ServerProfile(
      id: 'phone',
      name: 'This phone',
      baseUrl: 'http://127.0.0.1:4097',
      orchestration: config,
    ),
    config: config,
    store: OrchestrationStore(prefs),
    gatewayFactory: (_, _) =>
        _Gateway(agentList: agents, usageFigure: usage, extraRuns: runs),
    // The team inside the app would be probed over the network: answer
    // here that it is there.
    probe: builtin
        ? (_) async => const ProbeFound(
            host: OrchestrationHostIdentity(
              provider: 'gascity',
              url: 'http://127.0.0.1:8472',
              hostMode: OrchestrationHostMode.phone,
              city: 'bright-lights',
            ),
            city: 'bright-lights',
          )
        : null,
    now: () => _clock,
  );
  addTearDown(team.dispose);
  await team.start();
  return team;
}

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(412, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(page));
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String _subtitle(WidgetTester tester) =>
    tester.widget<KitTopBar>(find.byType(KitTopBar)).subtitle!;

/// A worker as the agents list reports it, with its session's own facts.
OrchestrationAgent _worker(
  String id, {
  AgentState state = AgentState.working,
  String? sessionState,
  bool? sessionRunning,
  bool suspended = false,
}) => OrchestrationAgent(
  id: id,
  name: 'ocproof/gastown.$id',
  pool: 'gastown.polecat',
  state: state,
  rawState: suspended ? 'suspended' : state.name,
  sessionState: sessionState,
  sessionRunning: sessionRunning,
  suspended: suspended,
);

OrchestrationUsage _usage({
  bool partial = false,
  bool recording = true,
  int? unpriced = 0,
}) => OrchestrationUsage(
  evidence: OrchestrationUsageEvidence(
    available: true,
    recording: recording,
    isEstimated: true,
    partial: partial,
    today: OrchestrationUsageTotals(
      inputTokens: 10000,
      outputTokens: 2400,
      costUsdEstimate: 0.42,
      unpriced: unpriced,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('is my team working? states come from sessions (row 21)', () {
    test('a worker whose session the host stopped is asleep, not working', () {
      final stopped = _worker(
        'furiosa',
        sessionState: 'stopped',
        sessionRunning: false,
      );
      expect(teamAgentIsLive(stopped), isFalse);
      expect(teamAgentStanding(stopped), TeamAgentStanding.asleep);
    });

    test('a running session is at work whatever the list says', () {
      final running = _worker(
        'fox',
        state: AgentState.stopped,
        sessionRunning: true,
      );
      expect(teamAgentIsLive(running), isTrue);
      expect(teamAgentStanding(running), TeamAgentStanding.working);
      // Suspended on the list, but its session still runs: at work.
      final suspended = _worker('nux', suspended: true, sessionRunning: true);
      expect(teamAgentStanding(suspended), TeamAgentStanding.working);
    });

    test('a crashed session is crashed; switched off on purpose is paused', () {
      expect(
        teamAgentStanding(_worker('ace', sessionState: 'failed')),
        TeamAgentStanding.crashed,
      );
      expect(
        teamAgentStanding(
          _worker('max', state: AgentState.stopped, suspended: true),
        ),
        TeamAgentStanding.paused,
      );
    });
  });

  group('an idle team is never "Paused" (row 20)', () {
    testWidgets('asleep agents: the subtitle says no pause', (tester) async {
      final team = await _team(
        agents: [
          _worker('fox', state: AgentState.stopped, sessionState: 'asleep'),
          _worker('nux', state: AgentState.stopped),
        ],
      );
      await _pump(tester, TeamHomeScreen(controller: team, now: () => _clock));
      expect(_subtitle(tester), isNot(contains(_en.teamUiHostPhrasePaused)));
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('agents switched off on purpose: Paused', (tester) async {
      final team = await _team(
        agents: [_worker('fox', state: AgentState.stopped, suspended: true)],
      );
      await _pump(tester, TeamHomeScreen(controller: team, now: () => _clock));
      expect(_subtitle(tester), contains(_en.teamUiHostPhrasePaused));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('what does it cost? today, qualified; never a task', () {
    String scope(WidgetTester tester) => tester
        .widget<KitRow>(_key('team-home-spent'))
        .supporting!
        .toPlainText();

    testWidgets('the whole team\'s estimate, and a task\'s cost unreported', (
      tester,
    ) async {
      final team = await _team(usage: _usage());
      await _pump(
        tester,
        TeamSettingsScreen(controller: team, now: () => _clock),
      );
      expect(
        find.text(_en.teamHomeSpentToday(r'$0.42 est. · 12.4k tokens')),
        findsOneWidget,
      );
      expect(scope(tester), _en.teamHomeSpentHint);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('missing history says the figure is a floor', (tester) async {
      final team = await _team(usage: _usage(partial: true));
      await _pump(
        tester,
        TeamSettingsScreen(controller: team, now: () => _clock),
      );
      expect(
        scope(tester),
        '${_en.teamHomeSpentHint} ${_en.teamHomeSpentHistoryMissing}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('no price outranks missing history; not counting is said', (
      tester,
    ) async {
      final team = await _team(
        usage: _usage(partial: true, unpriced: 2, recording: false),
      );
      await _pump(
        tester,
        TeamSettingsScreen(controller: team, now: () => _clock),
      );
      expect(
        scope(tester),
        '${_en.teamHomeSpentHint} ${_en.teamHomeSpentPartial} '
        '${_en.teamHomeSpentNotRecording}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('unavailable evidence: no row, never "\$0"', (tester) async {
      final team = await _team(
        usage: const OrchestrationUsage(
          evidence: OrchestrationUsageEvidence(
            available: false,
            recording: false,
            isEstimated: true,
            partial: false,
          ),
        ),
      );
      await _pump(
        tester,
        TeamSettingsScreen(controller: team, now: () => _clock),
      );
      expect(_key('team-home-spent'), findsNothing);
      expect(find.textContaining(r'$0'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('owner, build 2055 (team on the phone)', () {
    /// The lean phone team: one worker asleep, and the planner and the
    /// three supervisors the app keeps off.
    List<OrchestrationAgent> leanTeam() => [
      _worker('demo-app/gastown.polecat', state: AgentState.stopped),
      for (final name in [
        'gastown.mayor',
        'gastown.deacon',
        'gastown.boot',
        'demo-app/gastown.witness',
      ])
        OrchestrationAgent(
          id: name,
          name: name,
          pool: name.split('/').last,
          state: AgentState.stopped,
          rawState: 'suspended',
          suspended: true,
        ),
    ];

    test('1. no two agents share a title', () {
      final agents = [
        ...leanTeam(),
        // A second supervisor with nothing else to tell it apart.
        const OrchestrationAgent(
          id: 'gastown.deacon-2',
          name: 'gastown.deacon-2',
          pool: 'gastown.deacon',
          state: AgentState.idle,
        ),
      ];
      final titles = teamAgentTitles(_en, agents);
      expect(titles.values.toSet(), hasLength(agents.length));
      final supervisor = _en.teamUiAgentRoleSupervisor;
      expect(titles['demo-app/gastown.witness'], '$supervisor · demo-app');
      expect(titles['gastown.boot'], '$supervisor · watchdog');
      expect(titles['gastown.deacon'], startsWith('$supervisor · whole team'));
      expect(
        titles['gastown.deacon-2'],
        startsWith('$supervisor · whole team'),
      );
      // An agent whose title is its own keeps it bare.
      expect(titles['gastown.mayor'], _en.teamUiAgentRolePlanner);
    });

    testWidgets('5. nothing counted is not "\$0.00 · 0 tokens"', (
      tester,
    ) async {
      final team = await _team(
        agents: [_worker('ace', sessionRunning: true)],
        usage: const OrchestrationUsage(
          evidence: OrchestrationUsageEvidence(
            available: true,
            recording: true,
            isEstimated: true,
            partial: false,
            today: OrchestrationUsageTotals(
              inputTokens: 0,
              outputTokens: 0,
              costUsdEstimate: 0,
            ),
          ),
        ),
      );
      await _pump(
        tester,
        TeamSettingsScreen(controller: team, now: () => _clock),
      );
      expect(_key('team-home-spent'), findsNothing);
      expect(find.textContaining(r'$0.00'), findsNothing);
      expect(find.textContaining('0 tokens'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('6. upkeep is one line in words, duplicates collapsed, no '
        'switch', (tester) async {
      final team = await _team(
        runs: [
          for (var i = 1; i <= 4; i++)
            OrchestrationRun(
              id: 'wisp-$i',
              title: 'mol-witness-patrol',
              formula: 'mol-witness-patrol',
              state: RunState.planning,
              kind: RunKind.formula,
              isUpkeep: true,
            ),
          const OrchestrationRun(
            id: 'order-1',
            title: 'order:gate-sweep',
            state: RunState.working,
            kind: RunKind.formula,
            isUpkeep: true,
          ),
        ],
      );
      await _pump(
        tester,
        TeamSettingsScreen(controller: team, now: () => _clock),
      );
      expect(find.byType(KitSwitchRow), findsNothing);
      expect(_key('team-home-upkeep-row'), findsOneWidget);
      final line = tester
          .widget<KitRow>(_key('team-home-upkeep-row'))
          .supporting!
          .toPlainText();
      expect(line, 'Patrol ×4 · planning; Chore · working');
      expect(find.textContaining('mol-'), findsNothing);
      expect(find.textContaining('order:'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
