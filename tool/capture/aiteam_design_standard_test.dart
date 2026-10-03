// Before/after captures for the AI Team on the design standard (migration
// step 4, 2026-09-24): the scenes of test/support/team_golden_fixture.dart
// at 412x915 dp, dark theme, real fonts.
//
// The scenes only drive public screens (TeamHomeScreen, RunScreen,
// TeamCard) with controller state, so the same file renders the old code
// and the new:
//
//   flutter test --concurrency=1 --dart-define=AITEAM_CAPTURE=before \
//     tool/capture/aiteam_design_standard_test.dart     # on dca366f1
//   flutter test --concurrency=1 tool/capture/aiteam_design_standard_test.dart
//
// Output: docs/qa/design-standard-aiteam-2026-09-24/<before|after>-N-<shot>.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/team_golden_fixture.dart';
import 'fixtures.dart';

const _prefix = String.fromEnvironment('AITEAM_CAPTURE', defaultValue: 'after');
const _out = 'docs/qa/design-standard-aiteam-2026-09-24';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final (index, shot) in TeamShot.values.indexed) {
    testWidgets('$_prefix ${shot.fileName}', (tester) async {
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      final controller = await pumpTeamShot(
        tester,
        shot,
        light: false,
        boundary: boundary,
        theme: captureTheme,
      );
      try {
        await writePng(
          '$_out/$_prefix-${index + 1}-'
          '${shot.fileName.replaceFirst('team_', '').replaceAll('_', '-')}.png',
          await capturePng(tester, boundary, pixelRatio: 1),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        await tester.pump();
      }
    });
  }
}
