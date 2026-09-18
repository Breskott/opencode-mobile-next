import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/termux/bridge.dart';

/// Installs an `oc/termux` handler, exactly as the Android runner does, so
/// the Android-side expectations are tested against a channel that answers.
void _installChannel(Future<Object?> Function(MethodCall call)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('oc/termux'), handler);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugPlatformCapabilities = null;
    _installChannel(null);
  });

  group('on a platform with no Termux bridge', () {
    setUp(() {
      debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
      // Deliberately left unmocked: the Linux runner registers no handler, so
      // any invoke would raise MissingPluginException.
      _installChannel(null);
    });

    test('capabilities() reports unavailable instead of throwing', () async {
      final capabilities = await TermuxBridge.capabilities();
      expect(capabilities.platformSupported, isFalse);
      expect(capabilities.installed, isFalse);
      expect(capabilities.serviceAvailable, isFalse);
      expect(capabilities.protocolSupported, isFalse);
      expect(capabilities.permissionGranted, isFalse);
      expect(capabilities.version, isNull);
    });

    test('the boolean entry points answer false, never throw', () async {
      expect(await TermuxBridge.requestPermission(), isFalse);
      expect(await TermuxBridge.openTermux(), isFalse);
      expect(await TermuxBridge.openAppSettings(), isFalse);
    });

    test('run() fails as a bridge error the UI already handles', () async {
      await expectLater(
        TermuxBridge.run('echo hi'),
        throwsA(
          isA<TermuxBridgeException>().having(
            (error) => error.code,
            'code',
            TermuxBridge.unsupportedPlatformCode,
          ),
        ),
      );
    });

    test('every derived command reports the same unsupported error', () async {
      for (final call in <Future<Object?> Function()>[
        TermuxBridge.verifyBridge,
        TermuxBridge.ensureWakeLock,
        TermuxBridge.status,
        TermuxBridge.setupSnapshot,
        TermuxBridge.diagnostics,
      ]) {
        await expectLater(
          call(),
          throwsA(
            isA<TermuxBridgeException>().having(
              (error) => error.code,
              'code',
              TermuxBridge.unsupportedPlatformCode,
            ),
          ),
        );
      }
    });

    test('supported is false', () {
      expect(TermuxBridge.supported, isFalse);
    });
  });

  group('on Android', () {
    test('supported is true and the channel is used', () async {
      expect(TermuxBridge.supported, isTrue);
      _installChannel((call) async {
        expect(call.method, 'getCapabilities');
        return <String, dynamic>{
          'installed': true,
          'version': '0.118.0',
          'serviceAvailable': true,
          'protocolSupported': true,
          'permissionGranted': true,
        };
      });
      final capabilities = await TermuxBridge.capabilities();
      expect(capabilities.platformSupported, isTrue);
      expect(capabilities.installed, isTrue);
      expect(capabilities.version, '0.118.0');
      expect(capabilities.permissionGranted, isTrue);
    });

    test('a missing handler is a bare device, not a crash', () async {
      // Android without the plugin registered (an old engine, a torn-down
      // activity) used to raise MissingPluginException straight through
      // capabilities(), which only caught PlatformException.
      _installChannel(null);
      final capabilities = await TermuxBridge.capabilities();
      expect(capabilities.installed, isFalse);
      expect(await TermuxBridge.openTermux(), isFalse);
    });

    test(
      'a missing handler makes run() a bridge error, not a raw throw',
      () async {
        _installChannel(null);
        await expectLater(
          TermuxBridge.run('echo hi'),
          throwsA(isA<TermuxBridgeException>()),
        );
      },
    );

    test(
      'an execution killed by the Termux service shutdown is retried once',
      () async {
        // Termux stops its service once the last task ends and kills whatever
        // arrives meanwhile with exit 2 and this message; the next attempt
        // starts the service again.
        TermuxBridge.serviceShutdownRetryDelay = Duration.zero;
        addTearDown(() {
          TermuxBridge.serviceShutdownRetryDelay = const Duration(
            milliseconds: 1500,
          );
        });
        var calls = 0;
        _installChannel((call) async {
          expect(call.method, 'runInTermux');
          calls++;
          if (calls == 1) {
            return <String, dynamic>{
              'stdout': '',
              'stderr': '',
              'exitCode': 2,
              'err': 2,
              'errorMessage':
                  'Error Code: `2`\nError Message:\n```\nSending SIGKILL to '
                  'process on user request or because android is killing the '
                  'execution service\n```',
            };
          }
          return <String, dynamic>{
            'stdout': 'aiteam-started:41\n',
            'stderr': '',
            'exitCode': 0,
            'err': -1,
            'errorMessage': '',
          };
        });
        final result = await TermuxBridge.run('echo hi');
        expect(calls, 2);
        expect(result.stdout, 'aiteam-started:41\n');
      },
    );

    test(
      'a second service-shutdown kill is reported, not retried again',
      () async {
        TermuxBridge.serviceShutdownRetryDelay = Duration.zero;
        addTearDown(() {
          TermuxBridge.serviceShutdownRetryDelay = const Duration(
            milliseconds: 1500,
          );
        });
        var calls = 0;
        _installChannel((call) async {
          calls++;
          return <String, dynamic>{
            'stdout': '',
            'stderr': '',
            'exitCode': 2,
            'err': 2,
            'errorMessage':
                'Sending SIGKILL to process on user request or because android '
                'is killing the execution service',
          };
        });
        await expectLater(
          TermuxBridge.run('echo hi'),
          throwsA(
            isA<TermuxBridgeException>().having(
              (error) => error.message,
              'message',
              contains('killing the execution service'),
            ),
          ),
        );
        expect(calls, 2);
      },
    );

    test('a PlatformException still surfaces its own message', () async {
      _installChannel(
        (call) async => throw PlatformException(
          code: 'permission_denied',
          message: 'RUN_COMMAND permission is not granted.',
        ),
      );
      await expectLater(
        TermuxBridge.run('echo hi'),
        throwsA(
          isA<TermuxBridgeException>()
              .having((error) => error.code, 'code', 'permission_denied')
              .having(
                (error) => error.message,
                'message',
                'RUN_COMMAND permission is not granted.',
              ),
        ),
      );
    });
  });
}
