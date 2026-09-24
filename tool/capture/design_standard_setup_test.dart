// Before/after renders of phone setup and the "This phone" card for the
// design standard's migration step 3 (docs/design/design-standard.md §9):
// 412x915 dp, dark theme, real fonts, the states in
// test/support/phone_setup_scenes.dart.
//
//   flutter test --concurrency=1 --dart-define=SETUP_CAPTURE=before \
//     tool/capture/design_standard_setup_test.dart     # on the old commit
//   flutter test --concurrency=1 tool/capture/design_standard_setup_test.dart
//
// Output: docs/qa/design-standard-setup-2026-09-24/<before|after>-<nn>-<state>.png
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/phone_setup_scenes.dart';
import 'fixtures.dart';

const _prefix = String.fromEnvironment('SETUP_CAPTURE', defaultValue: 'after');
const _out = 'docs/qa/design-standard-setup-2026-09-24';

void _mockSecureStorage(WidgetTester tester) {
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    secure,
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      secure,
      null,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final (index, scene) in setupScenes.indexed) {
    testWidgets('${index + 1} ${scene.name}', (tester) async {
      _mockSecureStorage(tester);
      final boundary = GlobalKey();
      try {
        await pumpSetupScene(tester, scene, boundary: boundary);
        expect(tester.takeException(), isNull);
        final name = scene.name.replaceAll('_', '-');
        final number = '${index + 1}'.padLeft(2, '0');
        await writePng(
          '$_out/$_prefix-$number-$name.png',
          await capturePng(tester, boundary, pixelRatio: 1),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    });
  }
}
