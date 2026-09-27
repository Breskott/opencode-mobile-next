import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/api/opencode_api.dart';
import 'package:opencode_mobile/api/product_repository.dart';
import 'package:opencode_mobile/domain/server_gateway.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/state/session_inventory_cache.dart';
import 'package:opencode_mobile/state/session_tail_cache.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api extends OpenCodeApi {
  _Api() : super(baseUrl: 'https://fixture.invalid');
  final result = Completer<ServerPage<MessageWithParts>>();
  int reads = 0;
  @override
  Future<ServerPage<MessageWithParts>> messagePage(
    String id, {
    String? cursor,
    int limit = 100,
  }) {
    reads++;
    return result.future;
  }
}

MessageWithParts _message(int n) => MessageWithParts(
  info: MessageInfo(id: 'm$n', sessionID: 'session', role: 'user'),
  parts: [Part(type: 'text', text: 'Excerpt $n')],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (_) async => null);
    SharedPreferences.setMockInitialValues({
      'oc.profiles': jsonEncode([
        {'id': 'one', 'name': 'One', 'baseUrl': 'https://fixture.invalid'},
      ]),
      'oc.activeProfile': 'one',
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, null);
    KitRedact.clearKnownSecrets();
  });

  test('bounded redacted tail survives restart and preserves scope', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ProfileStore(prefs: prefs);
    await store.load();
    final scope = SessionInventoryCache.scopeFor(
      store.profiles.first,
      null,
      null,
    );
    final messages = [for (var i = 0; i < 20; i++) _message(i)];
    const secret = 'synthetic-private-value';
    KitRedact.registerKnownSecret(secret);
    messages.last.parts = [
      Part(type: 'text', text: secret),
      Part(type: 'reasoning', text: 'excluded reasoning'),
      Part(type: 'file', url: 'excluded attachment'),
    ];
    await SessionTailCache(
      prefs,
    ).save('one', scope, 'session', messages, isCurrent: () => true);
    final controller = ConnectionController(store, isIsolated: true);
    final preview = controller.cachedSessionTail('session')!;
    expect(preview.messages.length, 12);
    expect(preview.messages.first.id, 'm8');
    expect(preview.messages.last.text == KitRedact.mask, isTrue);
    expect(
      prefs.getString(SessionTailCache.keyFor('one'))!.contains(secret),
      isFalse,
    );
    expect(controller.cachedSessionTail('other'), isNull);
    expect(controller.sessionsById, isEmpty);
    expect(identical(preview, controller.cachedSessionTail('session')), isTrue);
    debugPrint(
      'PERF chat opening: 12 cached text excerpts synchronously; 0 network reads',
    );
    final result = await controller.deleteProfileAndLocalData('one');
    expect(result.removedProfile, isTrue);
    expect(prefs.containsKey(SessionTailCache.keyFor('one')), isFalse);
    expect(controller.cachedSessionTail('session'), isNull);
    controller.dispose();
  });

  test('shared live tail persists preview and hides staged history', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ProfileStore(prefs: prefs);
    await store.load();
    final api = _Api();
    final controller = ConnectionController(store, isIsolated: true)
      ..api = api
      ..repository = SdkProductRepository(api.sdkClient)
      ..status = StreamStatus.connected;
    controller.adoptConnectedProfileForTesting(store.profiles.first);
    final warm = controller.prefetchSessionTail('session');
    final live = controller.loadSessionTail('session');
    expect(api.reads, 1);
    api.result.complete(ServerPage(items: [_message(1)], nextCursor: 'older'));
    expect((await live).nextCursor, 'older');
    await warm;
    await Future<void>.delayed(Duration.zero);
    expect(controller.cachedSessionTail('session')!.messages.single.id, 'm1');
    controller.sessionsById['session'] = Session(
      id: 'session',
      stagedRevert: SessionRevert(messageID: 'm0'),
    );
    expect(controller.cachedSessionTail('session'), isNull);
    controller.dispose();
  });

  test('a changed staged boundary rejects an in-flight tail', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = ProfileStore(prefs: prefs);
    await store.load();
    final api = _Api();
    final controller = ConnectionController(store, isIsolated: true)
      ..api = api
      ..repository = SdkProductRepository(api.sdkClient)
      ..status = StreamStatus.connected;
    controller.adoptConnectedProfileForTesting(store.profiles.first);
    final pending = controller.loadSessionTail('session');
    final rejected = expectLater(pending, throwsA(isA<ProductException>()));
    controller.sessionsById['session'] = Session(
      id: 'session',
      stagedRevert: SessionRevert(messageID: 'm0'),
    );
    api.result.complete(ServerPage(items: [_message(1)]));
    await rejected;
    expect(prefs.containsKey(SessionTailCache.keyFor('one')), isFalse);
    controller.dispose();
  });

  test(
    'prefetch joins hydration and late deleted-profile result is rejected',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = ProfileStore(prefs: prefs);
      await store.load();
      final api = _Api();
      final controller = ConnectionController(store, isIsolated: true)
        ..api = api
        ..repository = SdkProductRepository(api.sdkClient)
        ..status = StreamStatus.connected;
      controller.adoptConnectedProfileForTesting(store.profiles.first);
      final prefetch = controller.prefetchSessionTail('session');
      final hydration = controller.loadSessionTail('session');
      final rejected = expectLater(hydration, throwsA(isA<ProductException>()));
      expect(api.reads, 1);
      final deletion = await controller.deleteProfileAndLocalData('one');
      expect(deletion.removedProfile, isTrue);
      api.result.complete(ServerPage(items: [_message(1)]));
      await prefetch;
      await rejected;
      expect(prefs.containsKey(SessionTailCache.keyFor('one')), isFalse);
      debugPrint(
        'PERF prefetch + hydration: 2 consumers, 1 HTTP read; late deletion rejected',
      );
      controller.dispose();
    },
  );
}
