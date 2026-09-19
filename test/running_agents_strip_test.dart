import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/ui/widgets/running_agents_strip.dart';

Session _session(String id, {String? parentID, int created = 0}) => Session(
  id: id,
  title: 'Session $id',
  parentID: parentID,
  directory: '/work',
  time: SessionTime(created: created),
);

void main() {
  test('strip is empty unless another family member is running', () {
    final sessions = {
      'p': _session('p', created: 1),
      'a': _session('a', parentID: 'p', created: 2),
      'b': _session('b', parentID: 'p', created: 3),
    };
    expect(
      runningAgentEntries(sessionID: 'a', sessions: sessions, busy: {'a'}),
      isEmpty,
      reason: 'only the current session works: nothing to switch to',
    );
    final entries = runningAgentEntries(
      sessionID: 'a',
      sessions: sessions,
      busy: {'b'},
    );
    expect(entries.map((e) => e.session.id), ['b', 'a', 'p']);
    expect(entries.first.busy, isTrue);
    expect(entries[1].current, isTrue);
    expect(entries.last.relation, RunningAgentRelation.parent);
  });

  test('parent session lists its running children', () {
    final sessions = {
      'p': _session('p', created: 1),
      'a': _session('a', parentID: 'p', created: 2),
      'b': _session('b', parentID: 'p', created: 3),
    };
    final entries = runningAgentEntries(
      sessionID: 'p',
      sessions: sessions,
      busy: {'p', 'a'},
    );
    expect(entries.map((e) => e.session.id), ['a', 'p', 'b']);
    expect(entries.map((e) => e.relation), [
      RunningAgentRelation.child,
      RunningAgentRelation.current,
      RunningAgentRelation.child,
    ]);
  });
}
