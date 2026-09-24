// Golden renders of phone setup and the "This phone" card on the design kit
// (docs/design/design-standard.md §8, §9 step 3): start (first time, running,
// stopped, ready, Termux), Customize, progress (running, failed), ready, the
// welcome's setup line, and the card (running, stopped, setting up), at
// 412x915, dark and light, with the app's real fonts.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/phone_setup_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import '../support/phone_setup_scenes.dart';

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

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final scene in setupScenes) {
      testWidgets('${scene.name} · $mode', (tester) async {
        _mockSecureStorage(tester);
        final boundary = GlobalKey();
        try {
          await pumpSetupScene(tester, scene, boundary: boundary, light: light);
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile('${scene.name}_$mode.png'),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
      });
    }
  }
}
