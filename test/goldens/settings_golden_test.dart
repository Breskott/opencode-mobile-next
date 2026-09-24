// Golden renders of the Settings area on the design kit
// (docs/design/design-standard.md §8, §9 step 6): the hub, its sub-screens,
// the servers list and form, diagnostics, About and the old Termux setup
// screen, at 412x915, dark and light, with the app's real fonts. The scenes
// are in test/support/settings_scenes.dart.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/settings_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import '../support/settings_scenes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final scene in SettingsScene.values) {
      final name = settingsSceneName(scene);
      testWidgets('$name · $mode', (tester) async {
        final boundary = GlobalKey();
        final done = await mountSettingsScene(
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
