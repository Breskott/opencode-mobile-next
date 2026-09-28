// Before/after renders for slice-termux-clarity (owner report, build 2061):
// the owner's three screens after an app storage reset on a phone whose
// OpenCode 1 runs in Termux. Android took the Termux permission back with
// the data; Termux still has allow-external-apps and its server answers.
//
//   flutter test tool/capture/termux_clarity_test.dart \
//     --dart-define=CAPTURE_STAGE=after   (or before, on the base commit)
//
// Uses public widgets and the `oc/termux` channel only, so the same file
// renders the old code and the new.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/phone_host.dart';
import 'package:opencode_mobile/ui/screens/about_screen.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import 'package:opencode_mobile/ui/screens/this_phone_screen.dart';

import '../../test/revamp/screen_phone_1_fixtures.dart' show pumpPhone;
import '../../test/support/setup_capture_preferences.dart';
import '../../test/support/termux_reset_phone.dart';
import 'fixtures.dart';

const _out = 'docs/qa/slice-termux-clarity-2026-09-28';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  const stage = String.fromEnvironment('CAPTURE_STAGE', defaultValue: 'after');
  setUp(useResetTermuxPhone);

  const sizes = {'412x915': Size(412, 915), '1280x800': Size(1280, 800)};

  for (final MapEntry(key: label, value: size) in sizes.entries) {
    for (final page in ['first-screen', 'about']) {
      testWidgets('$stage $page $label', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final prefs = await setupCapturePreferences();
        final controller = ConnectionController(
          SeededProfileStore(prefs: prefs, seeded: const []),
        );
        addTearDown(controller.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          captureApp(
            home: page == 'about' ? const AboutScreen() : const ServersScreen(),
            boundaryKey: boundary,
            controller: controller,
          ),
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await writePng(
          '$_out/${stage}_${page}_$label.png',
          await capturePng(tester, boundary, pixelRatio: 1.5),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      });
    }

    testWidgets('$stage this-phone $label', (tester) async {
      final boundary = GlobalKey();
      await pumpPhone(
        tester,
        size: size,
        boundary: boundary,
        home: const ThisPhoneScreen(kind: PhoneHostKind.termux),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await writePng(
        '$_out/${stage}_this-phone_$label.png',
        await capturePng(tester, boundary, pixelRatio: 1.5),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
