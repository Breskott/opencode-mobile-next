// Before/after renders for the Settings migration onto the design kit
// (docs/design/design-standard.md §9 step 6): every scene in
// test/support/settings_scenes.dart at 412x915 dp, dark, real fonts.
//
// The scenes drive public widgets only, so the same files render the old
// code and the new:
//
//   flutter test --concurrency=1 --dart-define=SETTINGS_CAPTURE=before \
//     tool/capture/design_standard_settings_test.dart     # on the old commit
//   flutter test --concurrency=1 tool/capture/design_standard_settings_test.dart
//
// Output: docs/qa/design-standard-settings-2026-09-24/<before|after>-<n>-<scene>.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/settings_scenes.dart';
import 'fixtures.dart';

const _prefix = String.fromEnvironment(
  'SETTINGS_CAPTURE',
  defaultValue: 'after',
);
const _out = 'docs/qa/design-standard-settings-2026-09-24';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final scene in SettingsScene.values) {
    final name = settingsSceneName(scene);
    testWidgets('$_prefix $name', (tester) async {
      final boundary = GlobalKey();
      final done = await mountSettingsScene(
        tester,
        scene,
        light: false,
        boundary: boundary,
      );
      expect(tester.takeException(), isNull);
      await writePng(
        '$_out/$_prefix-${scene.index + 1}-$name.png',
        await capturePng(tester, boundary, pixelRatio: 1),
      );
      await done();
    });
  }
}
