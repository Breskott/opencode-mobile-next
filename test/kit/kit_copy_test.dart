// KitCopy: the clipboard gets redacted text, a screen reader hears "Copied"
// once, a light tick plays, and no SnackBar appears.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_copy.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';

import 'kit_harness.dart';

void main() {
  late List<MethodCall> platform;
  late List<Map<Object?, Object?>> announcements;

  setUp(() {
    KitRedact.clearKnownSecrets();
    platform = [];
    announcements = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platform.add(call);
      return null;
    });
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (message) async {
        final map = message as Map<Object?, Object?>;
        if (map['type'] == 'announce') announcements.add(map);
        return null;
      },
    );
  });

  tearDown(() {
    KitRedact.clearKnownSecrets();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      null,
    );
  });

  String? copied() {
    final call = platform.lastWhere((c) => c.method == 'Clipboard.setData');
    return (call.arguments as Map)['text'] as String?;
  }

  testWidgets('copies redacted text, ticks, announces Copied once', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    await KitCopy.copy(context, 'export KEY=sk-ant-api03-AbCdEfGhIjKlMnOp');
    await tester.pump();

    expect(copied(), 'export KEY=sk-ant-${KitRedact.mask}');
    expect(
      platform.where((c) => c.method == 'HapticFeedback.vibrate'),
      hasLength(1),
    );
    expect(announcements, hasLength(1));
    expect((announcements.single['data'] as Map)['message'], 'Copied');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'registered secrets are masked by default and verbatim is explicit',
    (tester) async {
      final context = await pumpKitHost(tester);
      const input = 'diagnostic fixture-value repeated fixture-value';
      KitRedact.registerKnownSecret('fixture-value');
      await KitCopy.copy(context, input);
      expect(
        copied(),
        'diagnostic ${KitRedact.mask} repeated ${KitRedact.mask}',
      );
      await KitCopy.copy(context, input, redact: false);
      expect(copied(), input);
      KitRedact.clearKnownSecrets();
      await KitCopy.copy(context, input);
      expect(copied(), input);
      await tester.pump();
    },
  );

  testWidgets('a quoted password is masked whole', (tester) async {
    final context = await pumpKitHost(tester);
    await KitCopy.copy(context, 'password="correct horse battery staple"');
    await tester.pump();

    expect(copied(), 'password="${KitRedact.mask}"');
  });

  testWidgets('redact false copies code and message text verbatim', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    const text = 'const token = await getToken();\npassword="fixture-secret"';
    await KitCopy.copy(context, text, redact: false);
    await tester.pump();

    expect(copied(), text);
    expect(
      platform.where((c) => c.method == 'HapticFeedback.vibrate'),
      hasLength(1),
    );
    expect(announcements, hasLength(1));
    expect((announcements.single['data'] as Map)['message'], 'Copied');
  });

  testWidgets('plain text is copied as is, with a custom announcement', (
    tester,
  ) async {
    final context = await pumpKitHost(tester);
    await KitCopy.copy(context, 'lib/main.dart', announcement: 'Path copied');
    await tester.pump();

    expect(copied(), 'lib/main.dart');
    expect(announcements, hasLength(1));
    expect((announcements.single['data'] as Map)['message'], 'Path copied');
  });

  testWidgets('announces in Arabic', (tester) async {
    final context = await pumpKitHost(tester, locale: const Locale('ar'));
    await KitCopy.copy(context, 'x');
    await tester.pump();

    expect((announcements.single['data'] as Map)['message'], 'تم النسخ');
  });
}
