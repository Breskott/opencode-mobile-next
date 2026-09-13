import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/launch_shortcut.dart';

/// The pinned-session half of the `oc/shortcut` channel: a cold-start
/// `consumeSessionLaunch` drain and a live `launchedSession` push, both
/// carrying IDs only, plus the Quick Settings tile's `activity` action.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('oc/shortcut');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> launchedSession(Object? payload) =>
      messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall('launchedSession', payload)),
        (_) {},
      );

  Future<void> launched(Object? action) => messenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall('launched', action)),
    (_) {},
  );

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('drains the pinned-session tap that launched the app, once', () async {
    var consumes = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'consumeSessionLaunch':
          consumes += 1;
          return {'profileID': 'server-1', 'sessionID': 'ses-1'};
        default:
          return null;
      }
    });
    final shortcut = LaunchShortcut(channel: channel);
    addTearDown(shortcut.dispose);
    await shortcut.start();
    await shortcut.start();

    expect(consumes, 1);
    expect(shortcut.pending.value, isNull);
    expect(
      shortcut.pendingSession.value,
      const SessionLaunch(profileID: 'server-1', sessionID: 'ses-1'),
    );
    expect(
      shortcut.takeSession(),
      const SessionLaunch(profileID: 'server-1', sessionID: 'ses-1'),
    );
    expect(shortcut.pendingSession.value, isNull);
    expect(shortcut.takeSession(), isNull);
  });

  test('a static action and a session tap are drained independently', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'consumeLaunchAction':
          return 'activity';
        case 'consumeSessionLaunch':
          return {'profileID': 'server-1', 'sessionID': 'ses-1'};
        default:
          return null;
      }
    });
    final shortcut = LaunchShortcut(channel: channel);
    addTearDown(shortcut.dispose);
    await shortcut.start();
    expect(shortcut.pending.value, LaunchAction.activity);
    expect(shortcut.pendingSession.value?.sessionID, 'ses-1');
  });

  test('accepts a live pinned-session tap while running', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    final shortcut = LaunchShortcut(channel: channel);
    addTearDown(shortcut.dispose);
    await shortcut.start();
    expect(shortcut.pendingSession.value, isNull);

    await launchedSession({'profileID': 'server-1', 'sessionID': ' ses-1 '});
    expect(
      shortcut.pendingSession.value,
      const SessionLaunch(profileID: 'server-1', sessionID: 'ses-1'),
    );

    await launchedSession({'profileID': 'server-1', 'sessionID': 'ses-2'});
    expect(shortcut.pendingSession.value?.sessionID, 'ses-2');
    // The static-action notifier is untouched by session taps.
    expect(shortcut.pending.value, isNull);
  });

  test('ignores payloads without both IDs, and non-map payloads', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'consumeSessionLaunch') return {'sessionID': 'x'};
      return null;
    });
    final shortcut = LaunchShortcut(channel: channel);
    addTearDown(shortcut.dispose);
    var notifications = 0;
    shortcut.pendingSession.addListener(() => notifications++);
    await shortcut.start();
    expect(shortcut.pendingSession.value, isNull);

    await launchedSession({'profileID': '', 'sessionID': 'ses-1'});
    await launchedSession({'profileID': 'server-1', 'sessionID': ''});
    await launchedSession({'profileID': 'server-1'});
    await launchedSession('server-1:ses-1');
    await launchedSession(null);
    await launchedSession(<Object?>['server-1', 'ses-1']);
    // A session tap can never masquerade as a static action either.
    await launched({'profileID': 'server-1', 'sessionID': 'ses-1'});

    expect(shortcut.pendingSession.value, isNull);
    expect(shortcut.pending.value, isNull);
    expect(notifications, 0);
  });

  test('an invalid live payload does not clear a valid pending tap', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    final shortcut = LaunchShortcut(channel: channel);
    addTearDown(shortcut.dispose);
    await shortcut.start();
    await launchedSession({'profileID': 'server-1', 'sessionID': 'ses-1'});
    await launchedSession({'profileID': 'server-1'});
    expect(shortcut.pendingSession.value?.sessionID, 'ses-1');
  });

  test('a newer live tap wins over a stale cold-start consume', () async {
    final consumed = Completer<Map<String, String>?>();
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'consumeSessionLaunch') return consumed.future;
      return null;
    });
    final shortcut = LaunchShortcut(channel: channel);
    addTearDown(shortcut.dispose);
    final start = shortcut.start();
    await launchedSession({'profileID': 'server-1', 'sessionID': 'live'});
    consumed.complete({'profileID': 'server-1', 'sessionID': 'cold'});
    await start;

    expect(shortcut.pendingSession.value?.sessionID, 'live');
    expect(shortcut.takeSession()?.sessionID, 'live');
    expect(shortcut.pendingSession.value, isNull);
  });

  test('is inert off Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return {'profileID': 'server-1', 'sessionID': 'ses-1'};
    });
    final shortcut = LaunchShortcut(channel: channel);
    addTearDown(shortcut.dispose);
    await shortcut.start();
    expect(calls, isEmpty);
    expect(shortcut.pendingSession.value, isNull);
  });

  test('dispose blocks later session notifications', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    final shortcut = LaunchShortcut(channel: channel);
    addTearDown(shortcut.dispose);
    await shortcut.start();
    var notifications = 0;
    shortcut.pendingSession.addListener(() => notifications++);
    shortcut.dispose();

    await launchedSession({'profileID': 'server-1', 'sessionID': 'ses-1'});

    expect(notifications, 0);
    expect(shortcut.takeSession(), isNull);
  });
}
