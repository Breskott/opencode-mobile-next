// Golden renders of the AI Team screens migrated to the design kit
// (docs/design/design-standard.md §8, migration step 4): the home loaded,
// empty, failed and not answering after 8 s; a run's Overview and Work tab;
// the Start a run sheet; the Work tab's team card; an agent's live output.
// 412x915, dark and light, the app's real fonts, the scenes of
// test/support/team_golden_fixture.dart.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/team_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import '../support/team_golden_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final shot in TeamShot.values) {
      testWidgets('${shot.fileName} · $mode', (tester) async {
        addTearDown(tester.view.reset);
        final boundary = GlobalKey();
        final controller = await pumpTeamShot(
          tester,
          shot,
          light: light,
          boundary: boundary,
          theme: captureTheme,
        );
        try {
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile('${shot.fileName}_$mode.png'),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          await tester.pump();
        }
      });
    }
  }
}
