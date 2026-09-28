// The team as last read (slice-polish 2026-09-28): kept small on the device
// under the plugin's profile prefix, so the Team page can show it dimmed
// after Android stopped the phone's team, and so turning the plugin off or
// deleting the profile removes it with the rest.
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/orchestration_gateway.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final record = TeamLastKnown.of(
    asOf: DateTime.utc(2026, 9, 27, 10, 42),
    runs: const [
      OrchestrationRun(id: 'r1', title: 'Fix totals', state: RunState.working),
      OrchestrationRun(
        id: 'patrol',
        title: 'Patrol',
        state: RunState.working,
        isUpkeep: true,
      ),
    ],
    agents: const [
      OrchestrationAgent(
        id: 'a1',
        name: 'calc/polecat-1',
        pool: 'polecat',
        state: AgentState.idle,
      ),
    ],
  );

  test('keeps the person\'s tasks and the agents, not the host upkeep', () {
    expect(record.runs.map((r) => r.id), ['r1']);
    expect(record.agents.single.pool, 'polecat');
  });

  test('saves under oc.orchestration.<profile>. and reads back; the sweep '
      'removes it', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OrchestrationStore(await SharedPreferences.getInstance());
    await store.saveLastKnown('p1', record);
    expect(
      OrchestrationStore.lastKnownKey('p1'),
      startsWith(OrchestrationStore.prefix('p1')),
    );
    final read = store.readLastKnown('p1')!;
    expect(read.asOf, record.asOf);
    expect(read.runs.single.title, 'Fix totals');
    expect(read.runs.single.state, RunState.working);
    expect(read.agents.single.name, 'calc/polecat-1');
    expect(read.agents.single.state, AgentState.idle);
    expect(
      store.keysFor('p1'),
      contains(OrchestrationStore.lastKnownKey('p1')),
    );
  });

  test('anything unreadable is no record', () {
    expect(TeamLastKnown.fromJson('nope'), isNull);
    expect(TeamLastKnown.fromJson({'runs': []}), isNull);
  });
}
