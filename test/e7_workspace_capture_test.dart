import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/screens/activity_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/capture/fixtures.dart'
    show capturePng, captureTheme, loadCaptureFonts;
import 'support/return_brief_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final output = Platform.environment['OC_E7_WORKSPACE_CAPTURE_DIR'];
  testWidgets('capture workspace inventory and activity at narrow RTL scale', (
    tester,
  ) async {
    final directory = Directory(output!);
    expect(directory.existsSync(), isTrue);
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => null,
        );
    await loadCaptureFonts();
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await briefController();
    addTearDown(c.dispose);
    c.known = false;
    c.partial = true;
    for (final variant in [
      (name: 'workspace-dark', rtl: false, scale: 1.0, activity: false),
      (name: 'workspace-rtl-large', rtl: true, scale: 2.5, activity: false),
      (name: 'activity-rtl-large', rtl: true, scale: 2.5, activity: true),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: briefApp(
            c,
            scale: variant.scale,
            rtl: variant.rtl,
            theme: captureTheme(),
            home: variant.activity
                ? ActivityScreen(controller: c, embedded: true)
                : null,
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      File(
        '${directory.path}/${variant.name}.png',
      ).writeAsBytesSync(await capturePng(tester, boundary, pixelRatio: 2));
      if (!variant.activity && variant.rtl) {
        await tester.scrollUntilVisible(
          find.text('Load more conversations'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        File(
          '${directory.path}/workspace-rtl-large-continuation.png',
        ).writeAsBytesSync(await capturePng(tester, boundary, pixelRatio: 2));
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: output == null || output.trim().isEmpty);
}
