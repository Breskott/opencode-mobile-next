import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/session_inventory_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends OpenCodeApi {
  _Api() : super(baseUrl: 'https://fixture.invalid');
  @override
  Future<ServerPage<Session>> sessionPage({
    String? cursor,
    int limit = 100,
  }) async => ServerPage(
    items: [Session(id: 'fresh', title: 'Fresh title')],
  );
  @override
  Future<Map<String, String>> sessionStatuses() async => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (_) async => null);
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([
        {'id': 'one', 'name': 'One', 'baseUrl': 'https://fixture.invalid'},
        {'id': 'two', 'name': 'Two', 'baseUrl': 'https://other.invalid'},
      ]),
      'oc.activeProfile': 'one',
    });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, null),
  );

  test(
    'bounded restart preview is exact-profile/location and read-only',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = ProfileStore(prefs: prefs);
      await store.load();
      final profile = store.profiles.first;
      final scope = SessionInventoryCache.scopeFor(profile, null, null);
      final cache = SessionInventoryCache(prefs);
      await cache.save('one', scope, [
        for (var i = 0; i < 500; i++) Session(id: '$i', title: 'Label $i'),
      ], isCurrent: () => true);
      final restarted = ConnectionController(store, isIsolated: true);
      expect(restarted.api, isNull);
      expect(restarted.sessionsById, isEmpty);
      expect(restarted.cachedSessionInventory!.sessions.length, 100);
      expect(
        identical(
          restarted.cachedSessionInventory,
          restarted.cachedSessionInventory,
        ),
        isTrue,
      );
      expect(
        () => restarted.cachedSessionInventory!.sessions.clear(),
        throwsUnsupportedError,
      );
      debugPrint(
        'PERF cached inventory: 100 labels synchronously, 0 network reads; authoritative rows=0',
      );
      await store.setActiveId('two');
      expect(restarted.cachedSessionInventory, isNull);
      await store.setActiveId('one');
      await store.setLocation('one', directory: '/different');
      expect(restarted.cachedSessionInventory, isNull);
      expect(
        cache.read(
          'one',
          SessionInventoryCache.scopeFor(profile, null, 'different'),
        ),
        isNull,
      );
      expect(
        utf8
            .encode(prefs.getString(SessionInventoryCache.keyFor('one'))!)
            .length,
        lessThanOrEqualTo(SessionInventoryCache.maxBytes),
      );
      restarted.dispose();
    },
  );

  test(
    'refresh persists labels and deletion sweeps them without resurrection',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = ProfileStore(prefs: prefs);
      await store.load();
      final controller = ConnectionController(store, isIsolated: true);
      controller.api = _Api();
      controller.adoptConnectedProfileForTesting(store.profiles.first);
      await controller.refreshSessions();
      await Future<void>.delayed(Duration.zero);
      expect(controller.cachedSessionInventory!.sessions.single.id, 'fresh');
      final key = SessionInventoryCache.keyFor('one');
      expect(store.profileScopedPreferenceKeys('one'), contains(key));
      final result = await controller.deleteProfileAndLocalData('one');
      expect(result.removedProfile, isTrue);
      expect(prefs.containsKey(key), isFalse);
      expect(controller.cachedSessionInventory, isNull);
      // Retired transport callbacks must not recreate deleted profile data.
      await controller.refreshSessions();
      await Future<void>.delayed(Duration.zero);
      expect(prefs.containsKey(key), isFalse);
      controller.dispose();
    },
  );

  test(
    'corrupt/foreign previews fail closed and revoked writes are skipped',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final cache = SessionInventoryCache(prefs);
      final key = SessionInventoryCache.keyFor('one');
      await prefs.setString(key, '{');
      expect(cache.read('one', 'scope'), isNull);
      await cache.save('one', 'scope', [
        Session(id: 'safe'),
      ], isCurrent: () => false);
      expect(prefs.getString(key), '{');
      await cache.save('one', 'scope', [
        Session(id: 'safe'),
      ], isCurrent: () => true);
      expect(cache.read('one', 'other'), isNull);
      expect(cache.read('one', 'scope')!.sessions.single.id, 'safe');
      expect(cache.read('two', 'scope'), isNull);
    },
  );
}
