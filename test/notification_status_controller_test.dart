import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/background/live_background.dart';
import 'package:opencode_mobile/background/notification_status.dart';
import 'package:opencode_mobile/background/thermal_pause_signal.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

Session _session(String id, {String? title, String? directory, int at = 0}) =>
    Session(
      id: id,
      title: title,
      directory: directory,
      time: SessionTime(created: at, updated: at),
    );

EventEnvelope _event(String type, Map<String, dynamic> properties) =>
    EventEnvelope(type: type, properties: properties);

Future<ConnectionController> _controller() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final live = BackgroundLiveController(
    preferences: preferences,
    liveStatusDebounce: Duration.zero,
    invoke: (method, [arguments]) async => const {},
  );
  final controller = ConnectionController(
    ProfileStore(prefs: preferences),
    backgroundLive: live,
  );
  controller.sessionsById = {
    'a': _session(
      'a',
      title: 'UI review',
      directory: '/home/me/IPTV_King',
      at: 20,
    ),
    'b': _session('b', title: 'shopfront', directory: '/home/me/shop', at: 10),
    'child': Session(id: 'child', parentID: 'a', title: 'sub'),
  };
  return controller;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('one busy chat with tasks reads as working, 5 of 6', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.busySessions = {'a'};
    controller.handleEventForTesting(
      _event('message.part.updated', {
        'part': {
          'type': 'tool',
          'sessionID': 'a',
          'tool': 'todowrite',
          'state': {
            'status': 'completed',
            'input': {
              'todos': [
                for (var i = 0; i < 5; i++)
                  {'content': 'done $i', 'status': 'completed'},
                {'content': 'Running the tests', 'status': 'in_progress'},
              ],
            },
          },
        },
      }),
    );
    final status = controller.liveStatus().status!;
    expect(status.kind, NotificationStatusKind.working);
    expect(status.title, 'Running the tests');
    expect(status.text, 'UI review · 5 of 6 tasks');
    expect(status.progress, 83);
    expect(status.subText, 'IPTV_King');
    expect(status.sessionId, 'a');
  });

  test('a plan that arrives before the polled busy state is kept', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.handleEventForTesting(
      _event('message.part.updated', {
        'part': {
          'type': 'tool',
          'sessionID': 'a',
          'tool': 'todowrite',
          'state': {
            'status': 'running',
            'input': {
              'todos': [
                {'id': '1', 'content': 'one', 'status': 'completed'},
                {
                  'id': '2',
                  'content': 'Running the tests',
                  'status': 'in_progress',
                },
              ],
            },
          },
        },
      }),
    );
    // A publish happens while the session is not yet known busy.
    controller.notifyListeners();
    controller.busySessions = {'a'};
    final status = controller.liveStatus().status!;
    expect(status.title, 'Running the tests');
    expect(status.text, 'UI review · 1 of 2 tasks');
  });

  test('todo.updated moves the count while the chat runs', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.busySessions = {'a'};
    controller.handleEventForTesting(
      _event('todo.updated', {
        'sessionID': 'a',
        'todos': [
          {'content': 'one', 'status': 'completed'},
          {'content': 'two', 'status': 'pending'},
        ],
      }),
    );
    expect(controller.liveStatus().status!.text, 'UI review · 1 of 2 tasks');
  });

  test('subagent sessions are not chats', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.busySessions = {'a', 'child'};
    expect(
      controller.liveStatus().status!.kind,
      NotificationStatusKind.working,
    );
  });

  test(
    'a chat waiting on the person is counted as needing, not working',
    () async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      controller.busySessions = {'a', 'b'};
      controller.permissions = {
        'p1': PermissionRequest(id: 'p1', sessionID: 'a', permission: 'bash'),
      };
      final status = controller.liveStatus().status!;
      expect(status.kind, NotificationStatusKind.needsYou);
      expect(status.title, '1 needs you');
      expect(status.text, 'UI review · IPTV_King · 1 still working');
      expect(status.lines.single, startsWith('shopfront'));
    },
  );

  test('retry is waiting, never plain busy', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.handleEventForTesting(
      _event('session.status', {
        'sessionID': 'a',
        'status': {
          'type': 'retry',
          'attempt': 2,
          'message': 'raw provider text must never show',
          'next': DateTime(2099, 1, 1, 13, 12).millisecondsSinceEpoch,
        },
      }),
    );
    final status = controller.liveStatus().status!;
    expect(status.kind, NotificationStatusKind.waiting);
    expect(status.title, startsWith('Waiting'));
    expect(status.text, contains('Tries again at'));
    expect(status.text, contains('UI review'));
    expect(status.text, isNot(contains('raw provider')));
    expect(status.actions, contains(NotificationStatusAction.stopReply));
    expect(status.sessionId, 'a');

    controller.handleEventForTesting(
      _event('session.status', {
        'sessionID': 'a',
        'status': {'type': 'busy'},
      }),
    );
    expect(
      controller.liveStatus().status!.kind,
      NotificationStatusKind.working,
    );
  });

  test('a finished reply becomes "Last reply" on the idle status', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.handleEventForTesting(
      _event('session.status', {
        'sessionID': 'a',
        'status': {'type': 'busy'},
      }),
    );
    expect(
      controller.liveStatus().status!.kind,
      NotificationStatusKind.working,
    );
    controller.handleEventForTesting(
      _event('session.status', {
        'sessionID': 'a',
        'status': {'type': 'idle'},
      }),
    );
    final status = controller.liveStatus().status!;
    expect(status.kind, NotificationStatusKind.idle);
    expect(status.text, 'Last reply just now · UI review');
  });

  test('reconnecting says so, with what it was doing', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.busySessions = {'a'};
    controller.liveStatus();
    controller.status = StreamStatus.reconnecting;
    final status = controller.liveStatus().status!;
    expect(status.kind, NotificationStatusKind.reconnecting);
    expect(status.text, 'UI review');
  });

  test(
    'the heat guard folds into the status, no second notification',
    () async {
      final controller = await _controller();
      addTearDown(controller.dispose);
      addTearDown(() => thermalPauseActive.value = false);
      thermalPauseActive.value = true;
      expect(
        controller.liveStatus().status!.kind,
        NotificationStatusKind.pausedHot,
      );
      thermalPauseActive.value = false;
      expect(controller.liveStatus().status!.kind, NotificationStatusKind.idle);
    },
  );

  test("Android's background limit is its own status", () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    controller.backgroundLive.handleNativeTimeout(const {
      'reason': 'systemTimeout',
    });
    final status = controller.liveStatus().status!;
    expect(status.kind, NotificationStatusKind.pausedAndroid);
  });

  test('the status follows the app language', () async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    await controller.setAppLocale(const Locale('ar'));
    final status = controller.liveStatus().status!;
    expect(status.title, isNot('Ready · nothing running'));
  });
}
