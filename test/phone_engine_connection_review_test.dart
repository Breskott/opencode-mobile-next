import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/automatic_activity.dart';
import 'package:opencode_mobile/state/automation_policy.dart';
import 'package:opencode_mobile/orchestration/adapters/inapp/phone_engine_gateway.dart';

import 'phone_project_engine_controller_test.dart' show NativeBridge;
import 'phone_project_engine_gateway_test.dart' as engine;
import 'support/stash_memory_vault.dart';

class _ConnectingApi extends OpenCodeApi {
  _ConnectingApi() : super(baseUrl: 'http://127.0.0.1:4097');
  final healthGate = Completer<Health>();
  @override
  Future<Health> health() => healthGate.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final secrets = <String, String>{};
  late ProfileStore store;
  setUp(() async {
    addTearDown(AutomaticActivityController.resetShared);
    addTearDown(AutomationPolicyController.resetShared);
    SharedPreferences.setMockInitialValues({});
    secrets.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
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
          case 'containsKey':
            return secrets.containsKey(key);
        }
        return null;
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('oc/background'),
      (_) async => null,
    );
    store = ProfileStore(prefs: await SharedPreferences.getInstance());
    await store.upsert(
      ServerProfile(
        id: 'phone',
        name: 'Phone',
        baseUrl: 'http://127.0.0.1:4097',
      ),
    );
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('oc/background'),
      null,
    );
  });

  ConnectionController connection(NativeBridge bridge, {_ConnectingApi? api}) {
    final controller = ConnectionController(
      store,
      phoneEngineBridge: bridge,
      phoneEngineGatewayBuilder:
          ({required baseUrl, required profileId, required bearerToken}) =>
              PhoneEngineGateway(
                baseUrl: baseUrl,
                profileId: profileId,
                bearerToken: bearerToken,
                adapter: engine.FakeEngineAdapter(
                  (request) async => engine.jsonBody(
                    request.path == '/v1/health'
                        ? engine.health(profileId)
                        : {'deleted': true},
                  ),
                ),
              ),
      apiFactory: api == null ? null : (_) => api,
      localWakeLockEnsurer: () async {},
      draftAttachmentVault: StashMemoryVault(),
      stashAttachmentVault: StashMemoryVault(),
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test(
    'connection deletion sweeps an ordinary builtin profile before first activation',
    () async {
      final bridge = NativeBridge();
      final controller = connection(bridge);
      final result = await controller.deleteProfileAndLocalData('phone');
      expect(result.removedProfile, isTrue);
      expect(bridge.calls, ['delete:phone']);
      expect(store.profiles, isEmpty);
    },
  );

  test(
    'connection deletion fences first attach before any token is persisted',
    () async {
      await store.upsert(
        ServerProfile(
          id: 'phone',
          name: 'Phone alias',
          baseUrl: 'https://alias.example',
        ),
      );
      final gate = Completer<void>();
      final bridge = NativeBridge(attachGate: gate);
      final controller = connection(bridge);
      final attach = controller.phoneProjectEngine.attach('phone');
      final attachRefused = expectLater(
        attach,
        throwsA(engine.safeError('profileDeleted')),
      );
      await Future<void>.delayed(Duration.zero);
      expect(store.profiles.single.teamEngineAuth, isEmpty);
      expect(store.profiles.single.orchestration, isNull);
      final deletion = controller.deleteProfileAndLocalData('phone');
      // The deletion closes engine admission before draining the admitted attach.
      for (
        var i = 0;
        i < 100 && store.prefs.getBool('oc.teamEngineDeleted.phone') != true;
        i++
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(store.prefs.getBool('oc.teamEngineDeleted.phone'), isTrue);
      gate.complete();
      await attachRefused;
      expect((await deletion).removedProfile, isTrue);
      expect(bridge.calls.last, 'delete:phone');
      expect(store.profiles, isEmpty);
      expect(secrets.containsKey('oc.teamEngineAuth.phone'), isFalse);
    },
  );

  test(
    'phone dispatch fence exposes plain API failure when another engine cannot stop',
    () async {
      await store.upsert(
        ServerProfile(
          id: 'alias',
          name: 'Alias',
          baseUrl: 'http://127.0.0.1:4097',
          teamEngineAuth: 'private-engine-token',
          orchestration: const OrchestrationConfig(
            provider: OrchestrationProvider.phoneEngine,
            url: 'http://127.0.0.1:42761',
          ),
        ),
      );
      final bridge = NativeBridge()..failStop = true;
      final api = _ConnectingApi();
      final controller = connection(bridge, api: api);
      final connect = controller.connect(
        store.profiles.first,
        redetectOnFailure: false,
      );
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        api.promptAsync('human', text: 'Please help'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'AI Team could not pause safely. Stop AI Team before sending.',
          ),
        ),
      );
      await expectLater(
        controller.prepareActionTransport(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'AI Team could not pause safely. Stop AI Team before sending.',
          ),
        ),
      );
      expect(bridge.calls, ['stop:alias', 'stop:alias']);
      await controller.disconnect();
      api.healthGate.complete(Health(healthy: true, version: '1.18.32'));
      await connect;
    },
  );

  test('retired phone dispatch fence exposes plain API failure', () async {
    final api = _ConnectingApi();
    final controller = connection(NativeBridge(), api: api);
    final connect = controller.connect(
      store.profiles.single,
      redetectOnFailure: false,
    );
    await Future<void>.delayed(Duration.zero);
    await controller.disconnect();
    await expectLater(
      api.promptAsync('human', text: 'Please help'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'The chat connection changed. Reconnect before sending.',
        ),
      ),
    );
    api.healthGate.complete(Health(healthy: true, version: '1.18.32'));
    await connect;
  });
}
