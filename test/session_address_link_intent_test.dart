import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/session_address_link.dart';
import 'package:opencode_mobile/platform/session_link.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('oc/link');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final encoded = SessionAddressLink.build(
    origin: 'https://workstation.example-tailnet.ts.net',
    instanceId: '9e30af6d-422d-4d89-baad-006ac07cb9d1',
    sessionId: 'ses_first',
    includeServerAddress: true,
  ).encode();
  const legacy = 'opencode-mobile://session?profile=server-1&session=ses_1';
  Future<void> linked(Object? value) => messenger.handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall('linked', value)),
    (_) {},
  );
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('cold v2 capture and dismissal only consume native text once', () async {
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return encoded;
    });
    final intent = SessionLinkIntent(channel: channel);
    addTearDown(intent.dispose);
    await intent.start();
    await intent.start();
    expect(methods, ['consumeSessionLink']);
    expect(intent.pending.value, isNull);
    expect(intent.pendingTeam.value, isNull);
    expect(intent.takeAddress()?.sessionId, 'ses_first');
    expect(intent.takeAddress(), isNull);
    // This ingress owns no client, profile store or credential reader; all
    // channel traffic has been captured above and consists of text consumption.
  });

  test(
    'duplicate v2 coalesces and newer valid route replaces other kinds',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      final intent = SessionLinkIntent(channel: channel);
      addTearDown(intent.dispose);
      await intent.start();
      var events = 0;
      intent.pendingAddress.addListener(() => events++);
      await linked(encoded);
      await linked(encoded);
      expect(events, 1);
      await linked(legacy);
      expect(intent.pendingAddress.value, isNull);
      expect(intent.pending.value, isNotNull);
      await linked(encoded);
      expect(intent.pending.value, isNull);
      expect(intent.pendingAddress.value, isNotNull);
      await linked(encoded.replaceFirst('/v2', '/v3'));
      expect(intent.pendingAddress.value, isNull);
      expect(
        intent.pendingAddressFailure.value,
        SessionAddressFailureCode.invalidLink,
      );
      await linked('opencode-mobile://team/gate/server-1/gate-1');
      expect(intent.pendingAddressFailure.value, isNull);
      expect(intent.pendingTeam.value, isNotNull);
      await linked(encoded);
      expect(intent.pendingTeam.value, isNull);
      expect(intent.pendingAddress.value, isNotNull);
    },
  );

  test('warm v2 wins over late cold legacy and late cold v2', () async {
    for (final cold in [legacy, encoded]) {
      final gate = Completer<String>();
      messenger.setMockMethodCallHandler(channel, (call) => gate.future);
      final intent = SessionLinkIntent(channel: channel);
      final start = intent.start();
      await linked(encoded.replaceFirst('ses_first', 'ses_newer'));
      gate.complete(cold);
      await start;
      expect(intent.pendingAddress.value?.sessionId, 'ses_newer');
      expect(intent.pending.value, isNull);
      intent.dispose();
    }
  });

  test('invalid credentials never become a pending address route', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    final intent = SessionLinkIntent(channel: channel);
    addTearDown(intent.dispose);
    await intent.start();
    await linked(
      encoded.replaceFirst('ses_first', 'sk-abcdefghijklmnopqrstuv'),
    );
    expect(intent.pendingAddress.value, isNull);
    expect(intent.pending.value, isNull);
    expect(intent.takeAddressFailure(), SessionAddressFailureCode.credentials);
    expect(intent.takeAddressFailure(), isNull);
  });

  test(
    'malformed warm locator replaces routes with a metadata-free category',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      final intent = SessionLinkIntent(channel: channel);
      addTearDown(intent.dispose);
      await intent.start();
      await linked(legacy);
      await linked(encoded.replaceFirst('session=ses_first', 'session=%zz'));
      expect(intent.pending.value, isNull);
      expect(intent.pendingTeam.value, isNull);
      expect(intent.pendingAddress.value, isNull);
      expect(
        intent.pendingAddressFailure.value,
        SessionAddressFailureCode.invalidLink,
      );
      // The only retained error value is an enum, without raw input or fields.
      expect(
        intent.takeAddressFailure().toString(),
        'SessionAddressFailureCode.invalidLink',
      );
      await linked(encoded.replaceFirst('/v2', '/v9'));
      expect(
        intent.pendingAddressFailure.value,
        SessionAddressFailureCode.invalidLink,
      );
      await linked(encoded);
      expect(intent.pendingAddressFailure.value, isNull);
      expect(intent.pendingAddress.value, isNotNull);
    },
  );

  test(
    'warm failure suppresses late cold route even after dismissal',
    () async {
      final gate = Completer<String>();
      messenger.setMockMethodCallHandler(channel, (call) => gate.future);
      final intent = SessionLinkIntent(channel: channel);
      addTearDown(intent.dispose);
      final start = intent.start();
      await linked('OPENCODE-MOBILE://SESSION/v9?unknown=synthetic');
      expect(
        intent.takeAddressFailure(),
        SessionAddressFailureCode.invalidLink,
      );
      gate.complete(encoded);
      await start;
      expect(intent.pendingAddress.value, isNull);
      expect(intent.pendingAddressFailure.value, isNull);
    },
  );
}
