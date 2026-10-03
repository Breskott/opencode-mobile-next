import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/dto/dto.dart';
import 'package:opencode_mobile/orchestration/adapters/gascity/gascity_mappers.dart';
import 'package:opencode_mobile/state/team_conversation.dart';

/// The owner's phone (2026-09-25): Gas City's `/agents` said furiosa was
/// stopped while `/sessions` said active and running. The joined agent
/// carries the session's own state so the app can trust the session.
void main() {
  const workDir = '/root/aiteam/city/.gc/worktrees/my-app/polecats/furiosa';
  final session = GcSession.fromJson({
    'id': 'ma-7',
    'template': 'my-app/gastown.polecat',
    'state': 'active',
    'alias': 'my-app/gastown.furiosa',
    'session_name': 'my-app--gastown__furiosa',
    'work_dir': workDir,
    'created_at': '2026-09-25T19:51:05Z',
    'running': true,
    'active_bead': 'ma-3',
    'agent_kind': 'pool',
    'pool': 'polecat',
  });

  test('mapAgent carries the joined session state and running flag', () {
    final agent = GcAgent.fromJson({
      'name': 'my-app/gastown.furiosa',
      'state': 'stopped',
      'running': false,
      'pool': 'my-app/gastown.polecat',
      'session': {'name': 'my-app--gastown__furiosa'},
    });
    final mapped = mapAgents([agent], [session]).single;
    expect(mapped.rawState, 'stopped', reason: 'what /agents said');
    expect(mapped.sessionState, 'active');
    expect(mapped.sessionRunning, isTrue);
    expect(mapped.workDir, workDir);
    expect(teamSessionState(mapped), AgentState.working);
  });

  test('mapSession (a pool instance with no agent entry) carries them', () {
    final mapped = mapAgents(const [], [session]).single;
    expect(mapped.sessionState, 'active');
    expect(mapped.sessionRunning, isTrue);
  });

  test('an agent with no session has neither', () {
    final agent = GcAgent.fromJson({
      'name': 'gastown.mayor',
      'state': 'idle',
      'running': true,
    });
    final mapped = mapAgent(agent);
    expect(mapped.sessionState, isNull);
    expect(mapped.sessionRunning, isNull);
    expect(teamSessionState(mapped), AgentState.idle);
  });
}
