import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('oc/termux');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    debugPlatformCapabilities = const PlatformCapabilities.android();
    KitRedact.clearKnownSecrets();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(() {
    debugPlatformCapabilities = null;
    KitRedact.clearKnownSecrets();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'setup sends redacted metadata and substitutes pinned native base',
    () async {
      KitRedact.registerKnownSecret('private-fixture-value');
      await TermuxBridge.startSetup(
        jobId: 'job-12',
        components: [
          {
            'id': 'linux',
            'native': true,
            'script': 'must not become the bootstrap',
            'version': 'private-fixture-value',
            'data': {'password': 'private-fixture-value'},
          },
        ],
        params: {
          'opencode': {'runtime': 'opencode2'},
        },
        texts: {'title': 'private-fixture-value'},
      );
      final payload = calls.single.arguments as Map;
      final component = (payload['components'] as List).single as Map;
      expect(component['script'], TermuxBridge.setupBaseScript);
      expect(component['version'], KitRedact.mask);
      expect(component['data'], isEmpty);
      expect(payload.containsKey('texts'), isFalse);
      expect(payload.toString(), isNot(contains('private-fixture-value')));
    },
  );

  test('unsupported and credential parameters never dispatch', () async {
    for (final params in <Map<String, Map<String, String>>>[
      {
        'opencode': {'password': 'private-fixture-value'},
      },
      {
        'opencode': {'runtime': 'unexpected'},
      },
      {
        'opencode': {'version': '1.2.3; execute'},
      },
      {
        'unrecognised': {'value': 'x'},
      },
    ]) {
      await expectLater(
        TermuxBridge.startSetup(
          jobId: 'job-12',
          components: const [
            {'id': 'linux', 'native': true},
          ],
          params: params,
        ),
        throwsA(isA<TermuxBridgeException>()),
      );
    }
    expect(calls, isEmpty);
  });

  test('step acknowledgement sends no arbitrary error text', () async {
    KitRedact.registerKnownSecret('private-fixture-value');
    await TermuxBridge.completeSetupStep(
      jobId: 'job-12',
      id: 'start',
      ok: false,
      error: 'private-fixture-value',
      version: 'private-fixture-value',
    );
    expect(calls.single.method, 'completeSetupStep');
    expect((calls.single.arguments as Map).containsKey('error'), isFalse);
    expect(
      calls.single.arguments.toString(),
      isNot(contains('private-fixture-value')),
    );
  });
}
