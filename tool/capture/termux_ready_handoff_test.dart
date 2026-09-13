// Synthetic readiness and delayed client connection; no native mutations.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../test/termux_setup_screen_test.dart' as scenarios;
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  for (final large in [false, true]) {
    for (final connected in [false, true]) {
      testWidgets('ready handoff large=$large connected=$connected', (
        tester,
      ) async {
        tester.view.physicalSize = Size(large ? 320 : 390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        final complete = await scenarios.showReadyHandoffCapture(
          tester,
          captureKey: key,
          theme: captureTheme(light: true),
          textScale: large ? 2 : 1,
          connected: connected,
        );
        expect(tester.takeException(), isNull);
        await writePng(
          'docs/qa/termux-ready-handoff/${large ? '320-large' : '390'}-${connected ? 'continue' : 'connecting'}.png',
          await capturePng(tester, key),
        );
        if (!connected) {
          await tester.scrollUntilVisible(find.text('Cancel connection'), 150);
          await tester.pump();
          expect(find.text('Cancel connection').hitTestable(), findsOneWidget);
        }
        complete();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
