// Evidence frames for docs/qa/effects-preview-2026-10-15: Settings ›
// Appearance with the live sample of the chosen look in the Effects card,
// phone size, dark and light, at the top of the page. The look is painted (a frozen frame) for the picture.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opencode_mobile/ui/kit/kit.dart';

import '../../test/support/settings_scenes.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  setUp(() {
    KitLiveBackground.paintWithoutLoops = true;
    KitLiveBackground.frozenSeconds = 8;
    KitMotion.loops = false;
  });
  tearDown(() {
    KitLiveBackground.paintWithoutLoops = false;
    KitLiveBackground.frozenSeconds = null;
  });

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final scrolled in [false]) {
      testWidgets('$mode ${scrolled ? 'scrolled' : 'top'}', (tester) async {
        final boundary = GlobalKey();
        final done = await mountSettingsScene(
          tester,
          SettingsScene.appearance,
          light: light,
          boundary: boundary,
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        if (scrolled) {
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('effects-live-style')),
            -120,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
        }
        await writePng(
          'docs/qa/effects-preview-2026-10-15/after-$mode-${scrolled ? 'scrolled' : 'top'}.png',
          await capturePng(tester, boundary, pixelRatio: 2),
        );
        await done();
      });
    }
  }
}
