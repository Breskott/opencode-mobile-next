// Before/after renders for the Add server and Servers motion pass (slice B of
// docs/design/motion-and-illustration-2026-09-25.md): every scene in
// test/support/servers_motion_scenes.dart at 412x915 dp, real fonts, dark
// (and light for the new code).
//
// The scenes drive public widgets only, so the same files render the old
// code and the new:
//
//   flutter test --concurrency=1 --dart-define=MOTION_SERVERS_CAPTURE=before \
//     tool/capture/motion_servers_test.dart     # on the old commit
//   flutter test --concurrency=1 tool/capture/motion_servers_test.dart
//
// Output: docs/qa/motion-servers-2026-09-25/<before|after>-<n>-<scene>[-light].png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_motion.dart';

import '../../test/support/servers_motion_scenes.dart';
import 'fixtures.dart';

const _prefix = String.fromEnvironment(
  'MOTION_SERVERS_CAPTURE',
  defaultValue: 'after',
);
const _out = 'docs/qa/motion-servers-2026-09-25';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  // The finished frame of every drawing, as the goldens show it; the
  // waiting scene's loop is still, its travelling dot at rest midway.
  KitMotion.loops = false;

  for (final scene in ServersMotionScene.values) {
    final name = serversMotionSceneName(scene);
    for (final light in _prefix == 'before' ? [false] : [false, true]) {
      testWidgets('$_prefix $name${light ? ' light' : ''}', (tester) async {
        final boundary = GlobalKey();
        final done = await mountServersMotionScene(
          tester,
          scene,
          light: light,
          boundary: boundary,
        );
        expect(tester.takeException(), isNull);
        final file =
            '$_out/$_prefix-${scene.index + 1}-$name${light ? '-light' : ''}';
        await writePng(
          '$file.png',
          await capturePng(tester, boundary, pixelRatio: 1),
        );
        await done();
      });
    }
  }
}
