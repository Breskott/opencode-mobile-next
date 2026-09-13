import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/session_handoff.dart';
import 'package:opencode_mobile/platform/session_link.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('oc/link');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const good = 'opencode-mobile://session?profile=server-1&session=ses_1';

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

  test('drains the link that launched the app, once', () async {
    var consumes = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'consumeSessionLink') {
        consumes += 1;
        return good;
      }
      return null;
    });
    final intent = SessionLinkIntent(channel: channel);
    addTearDown(intent.dispose);
    await intent.start();
    await intent.start();

    expect(consumes, 1);
    expect(
      intent.pending.value,
      const SessionLink(profileID: 'server-1', sessionID: 'ses_1'),
    );
    expect(intent.take()?.sessionID, 'ses_1');
    expect(intent.pending.value, isNull);
    expect(intent.take(), isNull);
  });

  test('accepts a live link while running', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    final intent = SessionLinkIntent(channel: channel);
    addTearDown(intent.dispose);
    await intent.start();
    expect(intent.pending.value, isNull);

    await linked(good);
    expect(intent.pending.value?.profileID, 'server-1');

    await linked('opencode-mobile://session?profile=server-2&session=ses_2');
    expect(intent.pending.value?.profileID, 'server-2');
    expect(intent.pending.value?.sessionID, 'ses_2');
  });

  test('malformed links never become pending', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'consumeSessionLink') return 'https://evil.test/x';
      return null;
    });
    final intent = SessionLinkIntent(channel: channel);
    addTearDown(intent.dispose);
    var notifications = 0;
    intent.pending.addListener(() => notifications++);
    await intent.start();
    expect(intent.pending.value, isNull);

    for (final raw in <Object?>[
      null,
      42,
      '',
      'opencode-mobile://session?profile=server-1',
      'opencode-mobile://session?profile=server-1&session=-s',
      'opencode-mobile://settings?profile=server-1&session=ses_1',
      'opencode-mobile://session?profile=a%20b&session=ses_1',
    ]) {
      await linked(raw);
      expect(intent.pending.value, isNull, reason: 'raw=$raw');
    }
    expect(notifications, 0);
  });

  test('a missing channel implementation leaves nothing pending', () async {
    final intent = SessionLinkIntent(channel: channel);
    addTearDown(intent.dispose);
    await intent.start();
    expect(intent.pending.value, isNull);
  });

  test('is inert off Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    var consumes = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      consumes += 1;
      return good;
    });
    final intent = SessionLinkIntent(channel: channel);
    addTearDown(intent.dispose);
    await intent.start();
    expect(consumes, 0);
    expect(intent.pending.value, isNull);
  });
}
