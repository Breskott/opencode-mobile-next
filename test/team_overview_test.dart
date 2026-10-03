import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/thermal_guard.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/state/team_overview.dart';

const host = OrchestrationHostIdentity(
  provider: 'gascity',
  url: 'http://127.0.0.1:8472/',
  city: 'demo',
  hostMode: OrchestrationHostMode.phone,
);

OrchestrationAgent agent(AgentState state, {String? sessionState}) =>
    OrchestrationAgent(
      id: 'worker',
      name: 'worker',
      state: state,
      sessionState: sessionState,
    );

TeamOverview overview({
  List<OrchestrationAgent>? agents = const [],
  bool stale = false,
  ThermalTeamHold? hold,
  OrchestrationHostIdentity? identity = host,
}) => teamOverview(
  profileId: 'profile',
  host: identity,
  agents: agents,
  isStale: stale,
  heatHold: hold,
);

void main() {
  test('session evidence wins while waiting and blocked remain explicit', () {
    final active = overview(
      agents: [agent(AgentState.stopped, sessionState: 'active')],
    );
    expect(active.activity, TeamActivity.working);
    expect(active.agentCounts, {AgentState.working: 1});
    expect(active.hostMode, OrchestrationHostMode.phone);
    expect(
      overview(
        agents: [agent(AgentState.waiting, sessionState: 'active')],
      ).activity,
      TeamActivity.needsYou,
    );
    expect(
      overview(
        agents: [agent(AgentState.blocked, sessionState: 'active')],
      ).activity,
      TeamActivity.blocked,
    );
  });

  test(
    'idle is not paused; missing, stale and unknown evidence stay unknown',
    () {
      expect(overview().activity, TeamActivity.idle);
      expect(
        overview(agents: [agent(AgentState.stopped)]).activity,
        TeamActivity.idle,
      );
      expect(overview(agents: null).activity, TeamActivity.unknown);
      expect(overview(identity: null).activity, TeamActivity.unknown);
      expect(
        overview(agents: [agent(AgentState.unknown)]).activity,
        TeamActivity.unknown,
      );
      final stale = overview(agents: [agent(AgentState.working)], stale: true);
      expect(stale.activity, TeamActivity.unknown);
      expect(stale.isStale, isTrue);
      expect(stale.agentCounts[AgentState.working], 1);
      expect(
        () => stale.agentCounts[AgentState.working] = 2,
        throwsUnsupportedError,
      );
    },
  );

  test('heat reason requires matching profile, phone host and city', () {
    final since = DateTime.utc(2026, 9, 27);
    ThermalTeamHold hold({
      String profile = 'profile',
      String city = 'demo',
      String url = 'http://127.0.0.1:8472',
    }) => ThermalTeamHold(
      team: ThermalTeam(id: profile, url: url, city: city),
      since: since,
    );
    final paused = overview(hold: hold(), stale: true);
    expect(paused.activity, TeamActivity.pausedForHeat);
    expect(paused.heatHold?.since, since);
    expect(
      overview(hold: hold().copyWith(serviceStopped: true)).activity,
      TeamActivity.stoppedForHeat,
    );
    for (final wrong in [
      hold(profile: 'other'),
      hold(city: 'other'),
      hold(url: 'http://127.0.0.1:8372'),
    ]) {
      expect(overview(hold: wrong).heatHold, isNull);
      expect(overview(hold: wrong).activity, TeamActivity.idle);
    }
    expect(overview(hold: hold(), identity: null).heatHold, isNull);
    expect(
      overview(
        hold: hold(),
        identity: const OrchestrationHostIdentity(
          provider: 'gascity',
          url: 'http://127.0.0.1:8472',
          city: 'demo',
          hostMode: OrchestrationHostMode.computer,
        ),
      ).heatHold,
      isNull,
    );
  });
}
