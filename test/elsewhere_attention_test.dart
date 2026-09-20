import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/state/elsewhere_attention.dart';

EventEnvelope _event(String type, String directory, Map<String, dynamic> p) =>
    EventEnvelope(type: type, properties: p, directory: directory);

void main() {
  test('projects are tallied; readers leave out the one they are in', () {
    final tracker = ElsewhereAttention();
    var notified = 0;
    tracker.addListener(() => notified++);

    tracker.handle(
      _event('session.status', '/work/app', {
        'sessionID': 'here',
        'status': {'type': 'busy'},
      }),
    );
    // Tallied, but never shown for the project you are in.
    expect(tracker.activity(except: '/work/app'), isEmpty);

    tracker.handle(
      _event('session.status', '/work/fin', {
        'sessionID': 's1',
        'status': {'type': 'busy'},
      }),
    );
    tracker.handle(
      _event('permission.v2.asked', '/work/fin', {
        'id': 'req1',
        'sessionID': 's1',
      }),
    );
    tracker.handle(
      _event('session.status', '/work/site', {
        'sessionID': 's9',
        'status': 'busy',
      }),
    );

    final activity = tracker.activity(except: '/work/app');
    // The project that needs you comes first.
    expect(activity.map((p) => p.directory), ['/work/fin', '/work/site']);
    expect(activity.first.running, {'s1'});
    expect(activity.first.waiting, {'s1'});
    expect(tracker.waitingCount(), 1);
    expect(notified, 4);
  });

  test('an answer, or the end of the run, clears what was waiting', () {
    final tracker = ElsewhereAttention();
    void feed(String type, Map<String, dynamic> p) =>
        tracker.handle(_event(type, '/work/fin', p));

    feed('question.asked', {'id': 'q1', 'sessionID': 's1'});
    feed('permission.asked', {'id': 'p1', 'sessionID': 's2'});
    expect(tracker.waitingCount(), 2);

    // A reply names the request, not the conversation.
    feed('question.replied', {'requestID': 'q1'});
    expect(tracker.waitingCount(), 1);

    feed('session.status', {
      'sessionID': 's2',
      'status': {'type': 'busy'},
    });
    feed('session.idle', {'sessionID': 's2'});
    expect(tracker.waitingCount(), 0);
    expect(tracker.activity(), isEmpty);
  });

  test('switching into a project hands it back to the app', () {
    final tracker = ElsewhereAttention();
    tracker.handle(
      _event('permission.asked', '/work/fin', {'id': 'p1', 'sessionID': 's1'}),
    );
    expect(tracker.waitingCount(except: '/work/fin'), 0);
    expect(tracker.activity(except: '/work/fin'), isEmpty);
    expect(tracker.forProject('/work/fin')!.waiting, {'s1'});
    tracker.clear();
    expect(tracker.activity(), isEmpty);
  });
}
