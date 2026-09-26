import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/voice/automatic_setup_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('oc/voice');
  const platform = AndroidVoiceSetupPlatform();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    debugPlatformCapabilities = const PlatformCapabilities.android();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugPlatformCapabilities = null;
  });

  for (final state in VoiceSetupNetwork.values) {
    test('reports native ${state.name} network', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getVoiceSetupNetwork');
        return state.name;
      });
      expect(await platform.network(), state);
    });
  }

  test(
    'missing, malformed or failed network probes never allow free data',
    () async {
      for (final value in <Object?>[null, 'future-state', 1, true]) {
        messenger.setMockMethodCallHandler(channel, (_) async => value);
        expect(await platform.network(), VoiceSetupNetwork.unknown);
      }
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'unavailable');
      });
      expect(await platform.network(), VoiceSetupNetwork.unknown);
      messenger.setMockMethodCallHandler(channel, null);
      expect(await platform.network(), VoiceSetupNetwork.unknown);
    },
  );

  test(
    'permission reports actual grant without calling a connection service',
    () async {
      final calls = <String>[];
      for (final response in <Object?>[true, false, null, 'granted']) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return response;
        });
        expect(
          await platform.requestNotificationPermission(),
          response == true,
        );
      }
      expect(calls, everyElement('requestVoiceDownloadNotificationPermission'));
    },
  );

  test('permission failure and missing bridge report false', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    expect(await platform.requestNotificationPermission(), isFalse);
    messenger.setMockMethodCallHandler(channel, null);
    expect(await platform.requestNotificationPermission(), isFalse);
  });

  testWidgets(
    'a stalled permission prompt times out without blocking notices',
    (tester) async {
      final permissionReply = Completer<bool>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'requestVoiceDownloadNotificationPermission') {
          return permissionReply.future;
        }
        return true;
      });
      final permission = platform.requestNotificationPermission();
      final notification = platform.showNotification(
        phase: VoiceSetupNotificationPhase.downloading,
        receivedBytes: 10,
        totalBytes: 100,
      );
      await tester.pump();
      expect(await notification, isTrue);
      await tester.pump(const Duration(seconds: 61));
      expect(await permission, isFalse);
      // A late native grant cannot retroactively authorize the timed-out call.
      permissionReply.complete(true);
      await tester.pump();
    },
  );

  test(
    'posts all phases with numeric progress and no arbitrary text',
    () async {
      for (final phase in VoiceSetupNotificationPhase.values) {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'showVoiceDownloadNotification');
          expect(call.arguments, {
            'phase': phase.name,
            'receivedBytes': 20,
            'totalBytes': 100,
          });
          return true;
        });
        expect(
          await platform.showNotification(
            phase: phase,
            receivedBytes: 20,
            totalBytes: 100,
          ),
          isTrue,
        );
      }
    },
  );

  test('clamps invalid and overrun progress to a safe native range', () async {
    for (final sample in [
      (200, 100, 100, 100),
      (-1, 100, 0, 100),
      (3, -1, 0, 0),
    ]) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.arguments['receivedBytes'], sample.$3);
        expect(call.arguments['totalBytes'], sample.$4);
        return true;
      });
      expect(
        await platform.showNotification(
          phase: VoiceSetupNotificationPhase.downloading,
          receivedBytes: sample.$1,
          totalBytes: sample.$2,
        ),
        isTrue,
      );
    }
  });

  test(
    'notification denial and malformed native responses remain false',
    () async {
      for (final response in <Object?>[false, null, 'true']) {
        messenger.setMockMethodCallHandler(channel, (_) async => response);
        expect(
          await platform.showNotification(
            phase: VoiceSetupNotificationPhase.complete,
            receivedBytes: 100,
            totalBytes: 100,
          ),
          isFalse,
        );
      }
    },
  );

  test('notification mutations serialize across API instances', () async {
    final progressReply = Completer<bool>();
    final progressStarted = Completer<void>();
    final visible = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'dismissVoiceDownloadNotification') {
        visible.add('dismissed');
        return null;
      }
      final phase = call.arguments['phase'] as String;
      if (phase == 'downloading') {
        progressStarted.complete();
        await progressReply.future;
      }
      visible.add(phase);
      return true;
    });
    final progress = platform.showNotification(
      phase: VoiceSetupNotificationPhase.downloading,
      receivedBytes: 20,
      totalBytes: 100,
    );
    await progressStarted.future;
    final complete = const AndroidVoiceSetupPlatform().showNotification(
      phase: VoiceSetupNotificationPhase.complete,
      receivedBytes: 100,
      totalBytes: 100,
    );
    final dismiss = platform.dismissNotification();
    expect(visible, isEmpty);
    progressReply.complete(true);
    await Future.wait<void>([
      progress.then((_) {}),
      complete.then((_) {}),
      dismiss,
    ]);
    expect(visible, ['downloading', 'complete', 'dismissed']);
  });

  test(
    'notification errors do not poison later updates or dismissal',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'unavailable');
      });
      expect(
        await platform.showNotification(
          phase: VoiceSetupNotificationPhase.downloading,
          receivedBytes: 0,
          totalBytes: 100,
        ),
        isFalse,
      );
      await expectLater(platform.dismissNotification(), completes);
      messenger.setMockMethodCallHandler(channel, (_) async => true);
      expect(
        await platform.showNotification(
          phase: VoiceSetupNotificationPhase.complete,
          receivedBytes: 100,
          totalBytes: 100,
        ),
        isTrue,
      );
    },
  );

  test('unsupported voice platform never calls the native bridge', () async {
    debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return true;
    });
    expect(await platform.network(), VoiceSetupNetwork.unknown);
    expect(await platform.requestNotificationPermission(), isFalse);
    expect(
      await platform.showNotification(
        phase: VoiceSetupNotificationPhase.downloading,
        receivedBytes: 0,
        totalBytes: 100,
      ),
      isFalse,
    );
    await platform.dismissNotification();
    expect(calls, isEmpty);
  });
}
