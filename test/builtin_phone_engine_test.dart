import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test.phone_engine_native');
  final bridge = BuiltinLinux(channel: channel);
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'phoneEngineCredentials') {
            return {
              'baseUrl': 'http://127.0.0.1:4098',
              'bearerToken': 'a' * 64,
            };
          }
          return {
            'profileId': 'phone-profile',
            'running': call.method != 'stopPhoneEngine',
            'port': 4098,
            'boundary': false,
            'execution': false,
            'restartRequired': true,
            'boundaryReason': 'boundary_unverified',
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('native status exposes each recognized boundary tier', () {
    for (final tier in ['none', 'landlock', 'proot']) {
      final status = BuiltinPhoneEngineStatus.fromMap({
        'profileId': 'phone-profile',
        'boundaryTier': tier,
        'boundary': tier != 'none',
        'execution': tier != 'none',
      });
      expect(status.boundaryTier, tier);
      expect(status.boundary, tier != 'none');
      expect(status.execution, tier != 'none');
    }
  });

  test('old native status keeps flags without inferring a tier', () {
    final status = BuiltinPhoneEngineStatus.fromMap({
      'profileId': 'phone-profile',
      'boundary': true,
      'execution': true,
    });
    expect(status.boundaryTier, 'none');
    expect(status.boundary, isTrue);
    expect(status.execution, isTrue);
  });

  test('native status rejects unknown or malformed boundary tiers safely', () {
    for (final bad in ['unsupported', '', null, 1, false]) {
      expect(
        () => BuiltinPhoneEngineStatus.fromMap({
          'profileId': 'phone-profile',
          'boundaryTier': bad,
        }),
        throwsA(
          isA<BuiltinLinuxException>()
              .having((error) => error.code, 'code', 'engine_status_invalid')
              .having(
                (error) => error.message,
                'message',
                'Phone engine status is unavailable.',
              ),
        ),
      );
    }
  });

  test(
    'native lifecycle keeps the server restart prerequisite visible',
    () async {
      final started = await bridge.startPhoneEngine(profileId: 'phone-profile');
      expect(started.running, isTrue);
      expect(started.execution, isFalse);
      expect(started.boundary, isFalse);
      expect(started.restartRequired, isTrue);
      expect(calls.single.method, 'startPhoneEngine');
      expect(calls.single.arguments, {
        'profileId': 'phone-profile',
        'port': 4098,
      });
      final stopped = await bridge.stopPhoneEngine('phone-profile');
      expect(stopped.running, isFalse);
      await bridge.deletePhoneEngine('phone-profile');
      expect(calls.last.method, 'deletePhoneEngine');
    },
  );

  test('only an engine setup stop requests native server rollback', () async {
    await bridge.stopServer();
    expect(calls.single.method, 'stopServer');
    expect(calls.single.arguments, isNull);
    calls.clear();
    await bridge.stopServerForPhoneEngineSetup();
    expect(calls.single.arguments, {'phoneEngineSetup': true});
  });

  test(
    'unconfined child prerequisite survives stopped daemon status',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => {
              'profileId': 'phone-profile',
              'running': false,
              'restartRequired': false,
              'unconfinedChildren': true,
              'boundary': false,
              'execution': false,
            },
          );
      final status = await bridge.phoneEngineStatus('phone-profile');
      expect(status.running, isFalse);
      expect(status.unconfinedChildren, isTrue);
      expect(status.boundary, isFalse);
      expect(
        BuiltinPhoneEngineStatus.fromMap({
          'profileId': 'old-native',
        }).unconfinedChildren,
        isFalse,
      );
    },
  );

  test(
    'credentials have a separate handoff and a redacted representation',
    () async {
      final credentials = await bridge.phoneEngineCredentials('phone-profile');
      expect(credentials.baseUrl, 'http://127.0.0.1:4098');
      expect(credentials.bearerToken, 'a' * 64);
      expect(credentials.toString(), isNot(contains(credentials.bearerToken)));
      expect(calls.single.method, 'phoneEngineCredentials');
    },
  );

  test('credential handoff refuses non-loopback and malformed auth', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => {
            'baseUrl': 'http://example.invalid:4098',
            'bearerToken': 'a' * 64,
          },
        );
    await expectLater(
      bridge.phoneEngineCredentials('phone-profile'),
      throwsA(
        isA<BuiltinLinuxException>().having(
          (e) => e.code,
          'code',
          'engine_auth_unavailable',
        ),
      ),
    );
  });

  test('missing native boundary evidence parses as unavailable', () {
    final status = BuiltinPhoneEngineStatus.fromMap({
      'profileId': 'phone-profile',
    });
    expect(status.boundary, isFalse);
    expect(status.execution, isFalse);
    expect(status.boundaryReason, 'boundary_unverified');
    expect(status.boundaryGeneration, isNull);
    expect(status.protectionRequired, isFalse);
  });

  test(
    'native attestation generation and persistent confinement remain visible',
    () {
      final status = BuiltinPhoneEngineStatus.fromMap({
        'profileId': 'phone-profile',
        'running': true,
        'boundary': true,
        'execution': false,
        'protectionRequired': true,
        'boundaryGeneration': 'd5c7d154-e9db-4b38-81f2-3dfe501d5076',
        'boundaryReason': 'boundary_attested',
      });
      expect(status.boundary, isTrue);
      expect(
        status.execution,
        isFalse,
      ); // OC1 protocol readiness is independent.
      expect(status.protectionRequired, isTrue);
      expect(status.boundaryGeneration, 'd5c7d154-e9db-4b38-81f2-3dfe501d5076');
      expect(status.boundaryReason, 'boundary_attested');
    },
  );
}
