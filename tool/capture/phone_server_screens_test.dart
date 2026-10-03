// Before/after renders for the Servers, "On this phone" and Plugins cleanup
// (docs/design/phone-server-screens-cleanup-2026-09-24.md): every scene in
// test/support/phone_server_scenes.dart at 412x915 dp, dark, real fonts,
// plus the page under the fold and, where the new code has one, the folded
// part opened.
//
// The scenes drive public widgets only, so the same files render the old
// code and the new:
//
//   flutter test --concurrency=1 --dart-define=PHONE_SERVER_CAPTURE=before \
//     tool/capture/phone_server_screens_test.dart     # on the old commit
//   flutter test --concurrency=1 tool/capture/phone_server_screens_test.dart
//
// Output: docs/qa/phone-server-screens-2026-09-24/<before|after>-<n>-<scene>*.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/phone_server_scenes.dart';
import 'fixtures.dart';

const _prefix = String.fromEnvironment(
  'PHONE_SERVER_CAPTURE',
  defaultValue: 'after',
);
const _out = 'docs/qa/phone-server-screens-2026-09-24';

Future<void> _settle(WidgetTester tester) async {
  // Long enough for a tap's ink to fade before the capture.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final scene in PhoneServerScene.values) {
    final name = phoneServerSceneName(scene);
    testWidgets('$_prefix $name', (tester) async {
      final boundary = GlobalKey();
      final done = await mountPhoneServerScene(
        tester,
        scene,
        light: false,
        boundary: boundary,
      );
      expect(tester.takeException(), isNull);
      final file = '$_out/$_prefix-${scene.index + 1}-$name';
      await writePng(
        '$file.png',
        await capturePng(tester, boundary, pixelRatio: 1),
      );
      // What sits under the fold (the old Servers and On this phone pages
      // ran on well past one screen).
      final scrollable = find.byType(Scrollable);
      if (scene != PhoneServerScene.plugins &&
          scrollable.evaluate().isNotEmpty) {
        await tester.drag(scrollable.first, const Offset(0, -800));
        await _settle(tester);
        await writePng(
          '$file-scrolled.png',
          await capturePng(tester, boundary, pixelRatio: 1),
        );
      }
      // The folded parts, opened: the built-in plugins, and the other
      // OpenCode versions.
      for (final key in const ['plugins-builtin-group']) {
        final folded = find.byKey(ValueKey(key));
        if (folded.evaluate().isEmpty) continue;
        await tester.tap(folded);
        await _settle(tester);
        await writePng(
          '$file-open.png',
          await capturePng(tester, boundary, pixelRatio: 1),
        );
      }
      await done();
    });
  }
}
