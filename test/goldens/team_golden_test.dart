// Golden renders of the AI Team screens migrated to the design kit
// (docs/design/design-standard.md §8, migration step 4): the home loaded,
// empty, failed and not answering after 8 s; a task's conversation (P3.5:
// the run page is retired) and its Task details sheet;
// the Start a run sheet; the Work tab's team card; an agent's live output.
// 412x915, dark and light, the app's real fonts, the scenes of
// test/support/team_golden_fixture.dart.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/team_golden_test.dart
// and look at every changed image before committing it.
import 'package:clock/clock.dart';
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
      // Elapsed words ("Running for 3 min") read the pinned clock: a task
      // is its conversation now, whose worker lines tick (TEST-11).
      testWidgets('${shot.fileName} · $mode', (tester) async {
        await withClock(
          Clock.fixed(teamSceneClock),
          () => _shot(tester, shot, light, mode),
        );
      });
    }
  }
}

Future<void> _shot(
  WidgetTester tester,
  TeamShot shot,
  bool light,
  String mode,
) async {
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
}
