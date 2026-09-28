// The reply watch (slice-builtin-speed): times each reply from the server's
// events (prompt → first output → end) and keeps the phone awake while a
// reply runs on the in-app server — renewed while it runs, released when it
// ends, and never for longer than the ceiling.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart' show EventEnvelope;
import 'package:opencode_mobile/builtin/reply_watch.dart';
import 'package:opencode_mobile/diagnostics/perf_trace.dart';

class _Source extends ChangeNotifier implements ReplySource {
  final _events = StreamController<EventEnvelope>.broadcast(sync: true);

  @override
  Stream<EventEnvelope> get events => _events.stream;

  @override
  bool onInAppServer = true;

  @override
  Set<String> busySessions = {};

  void emit(String type, Map<String, dynamic> properties) =>
      _events.add(EventEnvelope(type: type, properties: properties));

  void busy(String sessionID, bool on) {
    on ? busySessions.add(sessionID) : busySessions.remove(sessionID);
    notifyListeners();
  }

  Future<void> close() => _events.close();
}

/// The events one OpenCode reply sends, in order.
void _prompt(_Source source, {String session = 's1', int created = 1000}) =>
    source.emit('message.updated', {
      'info': {
        'id': 'u-$session-$created',
        'sessionID': session,
        'role': 'user',
        'time': {'created': created},
      },
    });

void _assistant(_Source source, {String session = 's1'}) =>
    source.emit('message.updated', {
      'info': {
        'id': 'a-$session',
        'sessionID': session,
        'role': 'assistant',
        'providerID': 'opencode',
        'modelID': 'big-pickle',
      },
    });

void _text(_Source source, {String session = 's1', int? start}) =>
    source.emit('message.part.updated', {
      'part': {
        'id': 'p1',
        'sessionID': session,
        'messageID': 'a-$session',
        'type': 'text',
        'text': 'Hi',
        'time': {'start': ?start},
      },
    });

void _status(_Source source, String type, {String session = 's1'}) =>
    source.emit('session.status', {
      'sessionID': session,
      'status': {'type': type},
    });

void main() {
  late int micros;
  late List<(bool, Duration)> holds;

  ReplyWatch watch({bool held = true}) => ReplyWatch(
    holdAwake: (on, hold) async {
      holds.add((on, hold));
      return on && held;
    },
    nowMicros: () => micros,
  );

  setUp(() {
    micros = 0;
    holds = [];
    PerfTrace.clear();
  });

  test('times prompt → first output → end, by the app and the server', () {
    final source = _Source();
    final replies = watch()..attach(source);
    addTearDown(replies.dispose);

    _prompt(source, created: 50000);
    _status(source, 'busy');
    micros = 1200000;
    _assistant(source);
    // The user's own text part is not the reply's first output.
    source.emit('message.part.updated', {
      'part': {
        'sessionID': 's1',
        'messageID': 'u-s1-50000',
        'type': 'text',
        'text': 'hello',
      },
    });
    expect(
      PerfTrace.spans.where((s) => s.name == 'reply.first_token'),
      isEmpty,
    );
    micros = 3400000;
    _text(source, start: 53100);
    micros = 9000000;
    _text(source, start: 53100);
    _status(source, 'idle');

    final last = replies.lastInApp!;
    expect(last.firstToken, const Duration(milliseconds: 3400));
    expect(last.serverFirstToken, const Duration(milliseconds: 3100));
    expect(last.total, const Duration(seconds: 9));
    expect(last.model, 'opencode/big-pickle');
    expect(last.failed, isFalse);
    expect(replies.last, same(last));

    final first = PerfTrace.spans.singleWhere(
      (s) => s.name == 'reply.first_token',
    );
    expect(first.durationMs, 3400);
    expect(first.attrs['server'], 'in-app');
    expect(first.attrs['server_ms'], '3100');
    final done = PerfTrace.spans.singleWhere((s) => s.name == 'reply.done');
    expect(done.durationMs, 9000);
    expect(done.attrs['first_ms'], '3400');
  });

  test('a reply that fails before any output says so', () {
    final source = _Source();
    final replies = watch()..attach(source);
    addTearDown(replies.dispose);

    _prompt(source);
    micros = 2000000;
    source.emit('session.error', {'sessionID': 's1'});

    final last = replies.lastInApp!;
    expect(last.firstToken, isNull);
    expect(last.failed, isTrue);
    expect(last.total, const Duration(seconds: 2));
    expect(
      PerfTrace.spans.singleWhere((s) => s.name == 'reply.done').failed,
      isTrue,
    );
  });

  test('a reply on another server is timed but is not the in-app one', () {
    final source = _Source()..onInAppServer = false;
    final replies = watch()..attach(source);
    addTearDown(replies.dispose);

    _prompt(source);
    _assistant(source);
    micros = 500000;
    source.emit('message.part.delta', {
      'sessionID': 's1',
      'messageID': 'a-s1',
      'delta': 'H',
    });
    source.emit('session.idle', {'sessionID': 's1'});

    expect(replies.last!.firstToken, const Duration(milliseconds: 500));
    expect(replies.last!.inApp, isFalse);
    expect(replies.lastInApp, isNull);
  });

  test('a user message seen again after the reply does not time a new one', () {
    final source = _Source();
    final replies = watch()..attach(source);
    addTearDown(replies.dispose);

    _prompt(source);
    _status(source, 'busy');
    _status(source, 'idle');
    final first = replies.last;
    // OpenCode updates the user message (its summary) after the reply.
    _prompt(source);
    _status(source, 'idle');
    expect(replies.last, same(first));
  });

  // Widget tests run in a fake clock, so the renewal timer can be walked.
  testWidgets(
    'keeps the phone awake while an in-app reply runs, then lets go',
    (tester) async {
      final source = _Source();
      final replies = watch()..attach(source);

      source.busy('s1', true);
      await tester.pump();
      expect(holds, [(true, const Duration(minutes: 10))]);
      expect(replies.holdingAwake, isTrue);

      // Renewed while it runs, so no hold runs out under a long reply.
      await tester.pump(const Duration(minutes: 5));
      expect(holds.where((h) => h.$1), hasLength(2));

      // A second session finishing first changes nothing.
      source.busy('s2', true);
      source.busy('s2', false);
      await tester.pump();
      expect(holds.where((h) => !h.$1), isEmpty);

      source.busy('s1', false);
      await tester.pump();
      expect(holds.last.$1, isFalse);
      expect(replies.holdingAwake, isFalse);

      // No more renewals once idle.
      final count = holds.length;
      await tester.pump(const Duration(minutes: 30));
      expect(holds, hasLength(count));

      replies.dispose();
      await source.close();
    },
  );

  testWidgets('never keeps the phone awake past the ceiling in one stretch', (
    tester,
  ) async {
    final source = _Source();
    final replies = watch()..attach(source);

    source.busy('s1', true);
    for (var i = 0; i < 73; i++) {
      await tester.pump(const Duration(minutes: 5));
    }
    expect(holds.last.$1, isFalse);
    expect(replies.awakeCapped, isTrue);
    expect(replies.holdingAwake, isFalse);
    final count = holds.length;
    await tester.pump(const Duration(hours: 2));
    expect(holds, hasLength(count));

    // A new stretch after the replies stop may hold again.
    source.busy('s1', false);
    source.busy('s1', true);
    await tester.pump();
    expect(holds.last.$1, isTrue);
    expect(replies.awakeCapped, isFalse);

    replies.dispose();
    await tester.pump();
    expect(holds.last.$1, isFalse);
    await source.close();
  });

  testWidgets('only replies on the in-app server keep the phone awake', (
    tester,
  ) async {
    final source = _Source()..onInAppServer = false;
    final replies = watch()..attach(source);
    source.busy('s1', true);
    await tester.pump(const Duration(minutes: 10));
    expect(holds, isEmpty);
    replies.dispose();
    await source.close();
  });
}
