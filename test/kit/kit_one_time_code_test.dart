// KitOneTimeCode: a device code shown large and monospaced, left to right,
// with the kit's Copy control; copied as shown (not redacted), announced once.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_one_time_code.dart';

import 'kit_motion_still.dart';

void main() {
  // G8x (MOT-7): a StatelessWidget with no ticker (the copy glyph's check
  // is KitIconButton's own, sampled there): one build sample.
  kitMotionStillTests(
    'KitOneTimeCode',
    builds: {'default': () => const KitOneTimeCode(code: 'VPFI-KC2ZK')},
  );

  late List<MethodCall> platform;

  setUp(() {
    platform = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platform.add(call);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(
    WidgetTester tester, {
    String code = 'VPFI-KC2ZK',
    Locale locale = const Locale('en'),
    String? label = 'Your code',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: KitOneTimeCode(
            code: code,
            label: label,
            copyLabel: 'Copy code',
          ),
        ),
      ),
    );
  }

  testWidgets('shows the code mono, large, left to right', (tester) async {
    await pump(tester, locale: const Locale('ar'));
    final text = tester.widget<Text>(find.text('VPFI-KC2ZK'));
    expect(text.style!.fontSize, 28);
    expect(text.style!.fontFamily, isNotNull);
    expect(
      Directionality.of(tester.element(find.text('VPFI-KC2ZK'))),
      TextDirection.ltr,
    );
    expect(find.text('Your code'), findsOneWidget);
  });

  testWidgets('Copy puts the code on the clipboard exactly, once', (
    tester,
  ) async {
    await pump(tester, code: 'AB12-CD34');
    await tester.tap(find.byKey(const ValueKey('kit-one-time-code-copy')));
    await tester.pump();
    final copies = platform.where((c) => c.method == 'Clipboard.setData');
    expect(copies, hasLength(1));
    expect((copies.single.arguments as Map)['text'], 'AB12-CD34');
  });

  testWidgets('a long code at twice the text size scales down, no overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2),
          ),
          child: const Scaffold(
            body: KitOneTimeCode(code: 'ABCDEFGH-IJKLMNOP'),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('ABCDEFGH-IJKLMNOP'), findsOneWidget);
  });
}
