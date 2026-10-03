import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/local_pdf.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/widgets/markdown.dart';
import 'package:opencode_mobile/ui/widgets/pdf_file_preview.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2ZKgAAAAASUVORK5CYII=',
);
Map<String, Object> page(int index, {int count = 3}) => {
  'page': index,
  'pageCount': count,
  'width': 1,
  'height': 1,
  'png': _png,
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final bytes = Uint8List.fromList('%PDF-fixture'.codeUnits);
  final calls = <MethodCall>[];
  setUp(() {
    calls.clear();
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LocalPdf.channel, null);
    debugPlatformCapabilities = null;
  });
  void handler(Future<Object?> Function(MethodCall) action) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LocalPdf.channel, (call) {
          calls.add(call);
          return action(call);
        });
  }

  Future<void> pump(WidgetTester tester, Widget child) {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  int renders() => calls.where((call) => call.method == 'render').length;
  int cancels() => calls.where((call) => call.method == 'cancel').length;
  test(
    'channel input/output budgets reject invalid transport results',
    () async {
      handler((call) async => page(0));
      await expectLater(
        LocalPdf.render(Uint8List(LocalPdf.maxBytes + 1), 0, 'big'),
        throwsA(isA<PlatformException>()),
      );
      expect(calls, isEmpty);
      handler((call) async => {...page(0), 'width': 2000});
      await expectLater(
        LocalPdf.render(bytes, 0, 'bad'),
        throwsA(isA<PlatformException>()),
      );
      final forged = Uint8List.fromList(_png);
      ByteData.sublistView(forged).setUint32(16, 100000);
      handler((call) async => {...page(0), 'png': forged});
      await expectLater(
        LocalPdf.render(bytes, 0, 'forged'),
        throwsA(isA<PlatformException>()),
      );
    },
  );
  testWidgets(
    'pages render on this device, page 1 once, capped at the page limit',
    (tester) async {
      debugPlatformCapabilities = const PlatformCapabilities.android();
      handler(
        (call) async => call.method == 'render'
            ? page((call.arguments as Map)['page'] as int, count: 201)
            : null,
      );
      await pump(tester, PdfFilePreview(bytes: bytes, name: 'report.pdf'));
      await tester.pumpAndSettle();
      expect(find.text('Page 1 of 200'), findsOneWidget);
      final pages = [
        for (final call in calls)
          if (call.method == 'render') (call.arguments as Map)['page'] as int,
      ];
      expect(pages.where((p) => p == 0), hasLength(1));
      expect(pages.every((p) => p < LocalPdf.maxPages), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('backgrounding cancels PDF work and a late page never lands', (
    tester,
  ) async {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    final pending = Completer<Object?>();
    handler(
      (call) => call.method == 'render' ? pending.future : Future.value(),
    );
    await pump(tester, PdfFilePreview(bytes: bytes, name: 'report.pdf'));
    await tester.pump();
    expect(renders(), 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(cancels(), 1);
    pending.complete(page(0));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Page 1 of 3'), findsNothing);
    expect(find.text("Couldn't open report.pdf"), findsOneWidget);
    handler(
      (call) async => call.method == 'render'
          ? page((call.arguments as Map)['page'] as int)
          : null,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Page 1 of 3'), findsOneWidget);
  });
  testWidgets('disposing a PDF view cancels a held page', (tester) async {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    final pending = Completer<Object?>();
    handler(
      (call) => call.method == 'render' ? pending.future : Future.value(),
    );
    await pump(tester, PdfFilePreview(bytes: bytes));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(cancels(), 1);
    pending.complete(page(0));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('an isolated view never reaches the renderer and says why', (
    tester,
  ) async {
    debugPlatformCapabilities = const PlatformCapabilities.android();
    handler((call) async => page(0));
    await pump(
      tester,
      MarkdownInteractionScope(
        enabled: false,
        child: PdfFilePreview(bytes: bytes),
      ),
    );
    await tester.pumpAndSettle();
    expect(renders(), 0);
    expect(find.textContaining("PDF pages don't render"), findsOneWidget);
  });
  testWidgets('desktop and encrypted PDF give useful guidance', (tester) async {
    handler((call) async => page(0));
    debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
    await pump(tester, PdfFilePreview(bytes: bytes, name: 'report.pdf'));
    await tester.pumpAndSettle();
    expect(find.text("Can't show this file"), findsOneWidget);
    expect(renders(), 0);
    debugPlatformCapabilities = const PlatformCapabilities.android();
    handler((call) async => throw PlatformException(code: 'encrypted'));
    await pump(
      tester,
      PdfFilePreview(
        bytes: Uint8List.fromList('locked'.codeUnits),
        name: 'locked.pdf',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open locked.pdf"), findsOneWidget);
  });
}
