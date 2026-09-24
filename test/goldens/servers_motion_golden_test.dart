// Golden renders of the Servers welcome and Add server after the motion pass
// (slice B of docs/design/motion-and-illustration-2026-09-25.md, ledger row
// 15): the welcome's hero, Add server for Codex and for Claude Code or Pi,
// the address unfolded, the connection moments (checking, paired, failed)
// and the first-run connect screen, at 412x915, dark and light, with the
// app's real fonts. The scenes are in test/support/servers_motion_scenes.dart;
// Add server with OpenCode chosen is servers_add in settings_golden_test.dart.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/servers_motion_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import '../support/servers_motion_scenes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final scene in ServersMotionScene.values) {
      if (scene == ServersMotionScene.addOpenCode) continue;
      final name = serversMotionSceneName(scene);
      testWidgets('$name · $mode', (tester) async {
        final boundary = GlobalKey();
        final done = await mountServersMotionScene(
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
