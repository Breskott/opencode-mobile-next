import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opencode_mobile/state/phone_project_engine.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/orchestration/adapters/inapp/phone_engine_gateway.dart';

import 'phone_project_engine_gateway_test.dart' as fake;

class NativeBridge implements PhoneProjectEngineBridge {
  final calls = <String>[];
  bool failDelete = false;
  final Completer<void>? attachGate;
  NativeBridge({this.attachGate});
  @override
  Future<void> start(String id, {int port = 4098, String? notice}) async {
    calls.add('start:$id');
  }

  @override
  Future<({String baseUrl, String bearerToken})> credentials(String id) async {
    calls.add('credentials:$id');
    await attachGate?.future;
    return (
      baseUrl: 'http://127.0.0.1:4098',
      bearerToken: 'engine-private-token',
    );
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete:$id');
    if (failDelete) throw StateError('unsafe native details');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final secrets = <String, String>{};
  late SharedPreferences prefs;
  late ProfileStore store;
  setUp(() async {
    secrets.clear();
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            final args = call.arguments as Map? ?? {};
            final key = args['key'] as String?;
            switch (call.method) {
              case 'read':
                return secrets[key];
              case 'readAll':
                return Map<String, String>.of(secrets);
              case 'write':
                secrets[key!] = args['value'] as String;
                return null;
              case 'delete':
                secrets.remove(key);
                return null;
              case 'deleteAll':
                secrets.clear();
                return null;
              case 'containsKey':
                return secrets.containsKey(key);
            }
            return null;
          },
        );
    prefs = await SharedPreferences.getInstance();
    store = ProfileStore(prefs: prefs);
    await store.upsert(
      ServerProfile(
        id: 'phone',
        name: 'Phone',
        baseUrl: 'http://127.0.0.1:4097',
      ),
    );
    await store.upsert(
      ServerProfile(
        id: 'remote',
        name: 'Remote',
        baseUrl: 'https://example.org',
      ),
    );
    await store.setActiveId('remote');
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });
  PhoneProjectEngineController controller(
    NativeBridge bridge,
    List<String> requests,
  ) => PhoneProjectEngineController(
    store: store,
    bridge: bridge,
    gatewayBuilder:
        ({required baseUrl, required profileId, required bearerToken}) =>
            PhoneEngineGateway(
              baseUrl: baseUrl,
              profileId: profileId,
              bearerToken: bearerToken,
              adapter: fake.FakeEngineAdapter((r) async {
                requests.add(r.method);
                return fake.jsonBody(
                  r.path == '/v1/health'
                      ? fake.health(profileId)
                      : {'deleted': true},
                );
              }),
            ),
  );
  test(
    'legacy provider parsing stays compatible; new provider round trips',
    () {
      expect(
        OrchestrationProvider.fromName(null),
        OrchestrationProvider.gascity,
      );
      expect(
        OrchestrationProvider.fromName('unknown'),
        OrchestrationProvider.gascity,
      );
      expect(
        OrchestrationProvider.fromName('fixture'),
        OrchestrationProvider.fixture,
      );
      final config = OrchestrationConfig(
        provider: OrchestrationProvider.phoneEngine,
        url: 'http://127.0.0.1:4098',
        hostMode: OrchestrationHostMode.phone,
      );
      expect(
        OrchestrationConfig.fromJson(config.toJson())!.provider,
        OrchestrationProvider.phoneEngine,
      );
    },
  );
  test(
    'attach persists only nonsecret config and restores auth from Keystore',
    () async {
      final bridge = NativeBridge();
      final calls = <String>[];
      final engine = controller(bridge, calls);
      final health = await engine.attach('phone');
      expect(health.canExecute, isFalse);
      expect(bridge.calls, ['credentials:phone']);
      final profile = store.profiles.firstWhere((p) => p.id == 'phone');
      expect(
        profile.orchestration!.provider,
        OrchestrationProvider.phoneEngine,
      );
      expect(
        jsonEncode(profile.toJson()),
        isNot(contains('engine-private-token')),
      );
      expect(
        prefs.getKeys().any(
          (k) =>
              (prefs.get(k)?.toString() ?? '').contains('engine-private-token'),
        ),
        isFalse,
      );
      expect(secrets['oc.teamEngineAuth.phone'], 'engine-private-token');
      final restored = ProfileStore(prefs: prefs);
      await restored.load();
      expect(
        restored.profiles.firstWhere((p) => p.id == 'phone').teamEngineAuth,
        'engine-private-token',
      );
      await engine.close();
    },
  );
  test(
    'inactive profile deletion uses durable HTTP then native and erases auth',
    () async {
      final bridge = NativeBridge();
      final calls = <String>[];
      final engine = controller(bridge, calls);
      await engine.attach('phone');
      calls.clear();
      await engine.deleteProfile('phone');
      expect(calls, ['GET', 'DELETE']);
      expect(bridge.calls.last, 'delete:phone');
      expect(secrets.containsKey('oc.teamEngineAuth.phone'), isFalse);
      expect(prefs.getBool('oc.teamEngineDeleted.phone'), isTrue);
      await expectLater(
        engine.attach('phone'),
        throwsA(fake.safeError('profileDeleted')),
      );
      final restarted = controller(bridge, calls);
      await expectLater(
        restarted.start('phone'),
        throwsA(fake.safeError('profileDeleted')),
      );
    },
  );
  test('failed native deletion stays blocked, reports safe code, permits deletion retry', () async {
    final bridge = NativeBridge()..failDelete = true;
    final calls = <String>[];
    final engine = controller(bridge, calls);
    await engine.attach('phone');
    await expectLater(
      engine.deleteProfile('phone'),
      throwsA(fake.safeError('deleteFailed')),
    );
    expect(secrets.containsKey('oc.teamEngineAuth.phone'), isTrue);
    await expectLater(
      engine.probe('phone'),
      throwsA(fake.safeError('profileDeleted')),
    );
    bridge.failDelete = false;
    await engine.deleteProfile('phone');
    expect(secrets.containsKey('oc.teamEngineAuth.phone'), isFalse);
  });
  test(
    'attach running during deletion cannot resurrect profile config or auth',
    () async {
      final gate = Completer<void>();
      final bridge = NativeBridge(attachGate: gate);
      final engine = controller(bridge, []);
      final attach = engine.attach('phone');
      // Pump the queued native credential call without starting any processes.
      await Future<void>.delayed(Duration.zero);
      final deletion = engine.deleteProfile('phone');
      gate.complete();
      await expectLater(attach, throwsA(fake.safeError('profileDeleted')));
      await deletion;
      expect(store.profiles.first.teamEngineAuth, isEmpty);
      expect(store.profiles.first.orchestration, isNull);
    },
  );
}
