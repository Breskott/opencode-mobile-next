// Golden renders of the Servers, "On this phone" and Plugins cleanup
// (docs/design/phone-server-screens-cleanup-2026-09-24.md, design standard
// §8): Servers with the phone's server running beside a connected remote
// one, On this phone running and stopped, and Settings › Plugins, at
// 412x915, dark and light, with the app's real fonts. The scenes are in
// test/support/phone_server_scenes.dart.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/phone_server_screens_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import '../support/phone_server_scenes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final scene in PhoneServerScene.values) {
      final name = phoneServerSceneName(scene);
      testWidgets('$name · $mode', (tester) async {
        final boundary = GlobalKey();
        final done = await mountPhoneServerScene(
          tester,
          scene,
          light: light,
          boundary: boundary,
        );
        try {
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile('${name}_$mode.png'),
          );
        } finally {
          await done();
        }
      });
    }
  }
}
