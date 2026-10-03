// Before/after renders of the two ways into the move from Termux
// (slice-migration-ui): This phone for the Termux server (its new first
// row) and Servers (the one-time offer under the Termux row). The scenes
// drive public widgets only (test/support/phone_server_scenes.dart), so the
// same file renders the old code and the new:
//
//   flutter test --concurrency=1 --dart-define=MIGRATION_CAPTURE=before \
//     tool/capture/termux_migration_entry_capture_test.dart   # on the base
//   flutter test --concurrency=1 tool/capture/termux_migration_entry_capture_test.dart
//
// Output: docs/qa/slice-migration-ui-2026-09-28/<before|after>-<scene>-<size>-<mode>.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/phone_server_scenes.dart';
import 'fixtures.dart';

const _prefix = String.fromEnvironment(
  'MIGRATION_CAPTURE',
  defaultValue: 'after',
);
const _out = 'docs/qa/slice-migration-ui-2026-09-28';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final scene in [
    PhoneServerScene.phoneRunning,
    PhoneServerScene.servers,
  ]) {
    for (final size in const [Size(412, 915), Size(1280, 800)]) {
      for (final light in [false, true]) {
        final mode = light ? 'light' : 'dark';
        final dims = '${size.width.toInt()}x${size.height.toInt()}';
        final name = scene == PhoneServerScene.servers
            ? 'entry-servers'
            : 'entry-this-phone';
        testWidgets('$_prefix $name $dims $mode', (tester) async {
          final boundary = GlobalKey();
          final done = await mountPhoneServerScene(
            tester,
            scene,
            light: light,
            boundary: boundary,
          );
          tester.view.physicalSize = size;
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(tester.takeException(), isNull);
          await writePng(
            '$_out/$_prefix-$name-$dims-$mode.png',
            await capturePng(tester, boundary, pixelRatio: 1),
          );
          await done();
        });
      }
    }
  }
}
