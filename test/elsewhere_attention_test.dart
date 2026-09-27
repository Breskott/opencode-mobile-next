import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/attention_feed.dart';
import 'package:opencode_mobile/domain/work_row_status.dart';
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

  test('observations preserve typed card targets and receipt time', () {
    final receipt = DateTime.utc(2026, 9, 28, 12);
    final tracker = ElsewhereAttention(now: () => receipt);
    addTearDown(tracker.dispose);
    for (final type in ['permission.v2.asked', 'question.v2.asked']) {
      tracker.handle(
        EventEnvelope(
          type: type,
          directory: '/other',
          workspace: 'workspace',
          properties: {'id': 'same-id', 'sessionID': 'conversation'},
        ),
      );
    }
    tracker.handle(
      EventEnvelope(
        type: 'form.v2.created',
        directory: '/other',
        workspace: 'workspace',
        properties: {
          'form': {
            'id': 'same-id',
            'sessionID': 'conversation',
            'title': 'Ignored content',
          },
        },
      ),
    );
    final observations = tracker.observations();
    expect(observations, hasLength(3));
    expect(observations.map((item) => item.identity).toSet(), hasLength(3));
    expect(observations.map((item) => item.kind).toSet(), {
      AttentionKind.permission,
      AttentionKind.question,
      AttentionKind.form,
    });
    for (final observation in observations) {
      expect(observation.requestID, 'same-id');
      expect(observation.sessionID, 'conversation');
      expect(observation.directory, '/other');
      expect(observation.workspace, 'workspace');
      expect(observation.observedAt, receipt);
      expect(observation.facts.phase, WorkRowPhase.needsYou);
      expect(observation.title, isNull);
    }
    expect(tracker.waitingCount(), 1);
    expect(tracker.observations(except: '/other'), isEmpty);
    tracker.handle(
      EventEnvelope(
        type: 'question.v2.replied',
        directory: '/other',
        workspace: 'workspace',
        properties: {'requestID': 'same-id', 'sessionID': 'conversation'},
      ),
    );
    expect(tracker.observations(), hasLength(2));
    expect(
      tracker.observations().any((item) => item.kind == AttentionKind.question),
      isFalse,
    );
    tracker.handle(
      EventEnvelope(
        type: 'form.v2.cancelled',
        directory: '/other',
        workspace: 'workspace',
        properties: {'id': 'same-id', 'sessionID': 'conversation'},
      ),
    );
    expect(tracker.observations().single.kind, AttentionKind.permission);
  });

  test('replies and session settlement do not remove another folder card', () {
    final tracker = ElsewhereAttention();
    addTearDown(tracker.dispose);
    for (final folder in ['/one', '/two']) {
      tracker.handle(
        _event('permission.asked', folder, {
          'id': 'same-id',
          'sessionID': 'same-session',
        }),
      );
    }
    // A reply with a different conversation cannot settle a matching id.
    tracker.handle(
      _event('permission.replied', '/one', {
        'requestID': 'same-id',
        'sessionID': 'different-session',
      }),
    );
    expect(tracker.observations(), hasLength(2));
    tracker.handle(
      _event('permission.replied', '/one', {'requestID': 'same-id'}),
    );
    expect(tracker.observations().single.directory, '/two');
    tracker.handle(
      _event('question.asked', '/one', {
        'id': 'same-id',
        'sessionID': 'same-session',
      }),
    );
    tracker.handle(
      _event('session.idle', '/one', {'sessionID': 'same-session'}),
    );
    expect(tracker.observations().single.directory, '/two');
    tracker.clear();
    expect(tracker.observations(), isEmpty);
  });

  test(
    'duplicate requests refresh one observation, malformed requests omit',
    () {
      var receipt = DateTime.utc(2026, 9, 28, 12);
      final tracker = ElsewhereAttention(now: () => receipt);
      addTearDown(tracker.dispose);
      final event = _event('permission.asked', '/work', {
        'id': 'request',
        'sessionID': 'session',
      });
      tracker.handle(event);
      receipt = receipt.add(const Duration(minutes: 1));
      tracker.handle(event);
      expect(tracker.observations(), hasLength(1));
      expect(tracker.observations().single.observedAt, receipt);
      tracker.handle(
        _event('permission.asked', '/work', {'id': 'missing-session'}),
      );
      tracker.handle(_event('form.v2.created', '/work', {'form': 'malformed'}));
      expect(tracker.observations(), hasLength(1));
      tracker.handle(
        _event('session.deleted', '/work', {
          'info': {'id': 'session'},
        }),
      );
      expect(tracker.observations(), isEmpty);
    },
  );

  test(
    'observed failure survives idle and clears only for new work or removal',
    () {
      final receipt = DateTime.utc(2026, 9, 28, 12);
      final tracker = ElsewhereAttention(now: () => receipt);
      addTearDown(tracker.dispose);
      void failed(String directory) => tracker.handle(
        _event('session.error', directory, {
          'sessionID': 'session',
          'error': {'message': 'Raw server text must never be retained'},
        }),
      );
      failed('/one');
      failed('/two');
      expect(tracker.observations(), hasLength(2));
      final failure = tracker.observations().first;
      expect(failure.kind, AttentionKind.failedRun);
      expect(failure.facts.phase, WorkRowPhase.failed);
      expect(failure.observedAt, receipt);
      expect(failure.sessionID, 'session');
      expect(failure.requestID, isNull);
      expect(failure.title, isNull);
      expect(tracker.activity(), isEmpty);
      expect(tracker.waitingCount(), 0);
      tracker.handle(_event('session.idle', '/one', {'sessionID': 'session'}));
      tracker.handle(
        _event('session.status', '/one', {
          'sessionID': 'session',
          'status': {'type': 'idle'},
        }),
      );
      expect(tracker.observations(), hasLength(2));
      tracker.handle(
        _event('session.status', '/one', {
          'sessionID': 'session',
          'status': {'type': 'busy'},
        }),
      );
      expect(tracker.observations().single.directory, '/two');
      expect(tracker.forProject('/one')!.running, {'session'});
      failed('/one');
      tracker.handle(
        _event('session.deleted', '/one', {
          'info': {'id': 'session'},
        }),
      );
      expect(tracker.observations().single.directory, '/two');
      tracker.handle(
        _event('session.status', '/two', {
          'sessionID': 'session',
          'status': 'retry',
        }),
      );
      expect(tracker.observations(), isEmpty);
      failed('/one');
      tracker.handle(
        _event('message.updated', '/one', {
          'info': {'role': 'user', 'sessionID': 'session'},
        }),
      );
      expect(tracker.observations(), isEmpty);
      failed('/one');
      tracker.clear();
      expect(tracker.observations(), isEmpty);
    },
  );

  test('unknown status and request events do not invent busy or failure', () {
    final tracker = ElsewhereAttention();
    addTearDown(tracker.dispose);
    for (final status in [
      null,
      'unknown',
      {'type': 'future-status'},
    ]) {
      tracker.handle(
        _event('session.status', '/work', {
          'sessionID': 'session',
          'status': status,
        }),
      );
    }
    expect(tracker.activity(), isEmpty);
    tracker.handle(
      _event('permission.asked', '/work', {
        'sessionID': 'session',
        'id': 'permission',
      }),
    );
    expect(tracker.observations().single.kind, AttentionKind.permission);
    expect(tracker.waitingCount(), 1);
    expect(tracker.forProject('/work')!.running, isEmpty);
  });
  test(
    'stream replacement keeps old rows stale until each is observed again',
    () {
      final tracker = ElsewhereAttention();
      addTearDown(tracker.dispose);
      tracker.handle(
        _event('permission.asked', '/work', {
          'sessionID': 'session',
          'id': 'permission',
        }),
      );
      tracker.handle(
        _event('session.error', '/other', {'sessionID': 'failed'}),
      );
      final before = tracker.observations().first.observedAt;
      tracker.markStale();
      expect(tracker.observations().every((row) => !row.isFresh), isTrue);
      expect(tracker.observations().first.observedAt, before);
      tracker.handle(
        _event('permission.asked', '/work', {
          'sessionID': 'session',
          'id': 'permission',
        }),
      );
      expect(tracker.observations().first.isFresh, isTrue);
      expect(tracker.observations().last.isFresh, isFalse);
    },
  );
}
