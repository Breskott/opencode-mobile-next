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
  _Gateway({this.agentList, this.usageFigure})
    : super(
        fixturePath: _fixturePath(),
        hostMode: OrchestrationHostMode.phone,
        url: 'http://127.0.0.1:8472',
      );

  final List<OrchestrationAgent>? agentList;
  final OrchestrationUsage? usageFigure;

  @override
  Future<List<OrchestrationAgent>> agents() async =>
      agentList ?? await super.agents();

  @override
  Future<OrchestrationUsage?> usage() async => usageFigure;
}

Future<OrchestrationController> _team({
  List<OrchestrationAgent>? agents,
  OrchestrationUsage? usage,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final config = OrchestrationConfig(
    provider: OrchestrationProvider.fixture,
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
    gatewayFactory: (_, _) => _Gateway(agentList: agents, usageFigure: usage),
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

String _agentsRow(WidgetTester tester) => tester
    .widget<KitRow>(
      find.descendant(
        of: _key('team-home-agents-row'),
        matching: find.byType(KitRow),
      ),
    )
    .title;

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

    testWidgets('the team page counts only running sessions as working', (
      tester,
    ) async {
      final team = await _team(
        agents: [
          _worker('fox', sessionRunning: true),
          // The list says working; the host says its session stopped.
          _worker('furiosa', sessionState: 'stopped', sessionRunning: false),
          _worker('nux', state: AgentState.idle, sessionState: 'asleep'),
        ],
      );
      await _pump(tester, TeamHomeScreen(controller: team, now: () => _clock));
      expect(
        _agentsRow(tester),
        '${_en.teamUiHomeAgentsRowCount(2)} · '
        '${_en.teamUiHomeAgentsRowWorking(1)}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a session that ended in an error is said on the row', (
      tester,
    ) async {
      final team = await _team(
        agents: [
          _worker('fox', sessionRunning: true),
          _worker('ace', sessionState: 'crashed'),
        ],
      );
      await _pump(tester, TeamHomeScreen(controller: team, now: () => _clock));
      expect(
        _agentsRow(tester),
        '${_en.teamUiHomeAgentsRowCount(2)} · '
        '${_en.teamUiHomeAgentsRowWorking(1)} · '
        '${_en.teamHomeAgentsRowCrashed(1)}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('what each worker is doing: the session word and its step', (
      tester,
    ) async {
      final team = await _team(
        agents: [
          _worker('furiosa', sessionState: 'stopped', sessionRunning: false),
          _worker('fox', state: AgentState.idle, sessionRunning: true),
        ],
      );
      await _pump(
        tester,
        TeamAgentsScreen(controller: team, now: () => _clock),
      );
      String line(String id) => tester
          .widget<KitRow>(_key('team-home-agent-$id'))
          .supporting!
          .toPlainText();
      // Stopped by the host: asleep, never "Working".
      expect(line('furiosa'), startsWith(_en.teamAgentsAsleep));
      expect(line('furiosa'), isNot(contains(_en.teamUiHomeAgentStateWorking)));
      // Idle on the list but its session runs: working, listed first.
      expect(line('fox'), startsWith(_en.teamUiHomeAgentStateWorking));
      expect(
        tester.getTopLeft(_key('team-home-agent-fox')).dy,
        lessThan(tester.getTopLeft(_key('team-home-agent-furiosa')).dy),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('an idle team is never "Paused" (row 20)', () {
    testWidgets('asleep agents: asleep, and the subtitle says no pause', (
      tester,
    ) async {
      final team = await _team(
        agents: [
          _worker('fox', state: AgentState.stopped, sessionState: 'asleep'),
          _worker('nux', state: AgentState.stopped),
        ],
      );
      await _pump(tester, TeamHomeScreen(controller: team, now: () => _clock));
      expect(_subtitle(tester), isNot(contains(_en.teamUiHostPhrasePaused)));
      expect(
        _agentsRow(tester),
        '${_en.teamUiHomeAgentsRowCount(2)} · ${_en.teamNowAgentsAsleep}',
      );
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
      await _pump(tester, TeamHomeScreen(controller: team, now: () => _clock));
      expect(
        find.text(_en.teamHomeSpentToday(r'$0.42 est. · 12.4k tokens')),
        findsOneWidget,
      );
      expect(scope(tester), _en.teamHomeSpentHint);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('missing history says the figure is a floor', (tester) async {
      final team = await _team(usage: _usage(partial: true));
      await _pump(tester, TeamHomeScreen(controller: team, now: () => _clock));
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
      await _pump(tester, TeamHomeScreen(controller: team, now: () => _clock));
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
      await _pump(tester, TeamHomeScreen(controller: team, now: () => _clock));
      expect(_key('team-home-spent'), findsNothing);
      expect(find.textContaining(r'$0'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
