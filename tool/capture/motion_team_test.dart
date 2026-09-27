// Before/after captures for the AI Team's drawings and moments (motion
// spec slice D, docs/design/motion-and-illustration-2026-09-25.md): the
// scenes of test/support/team_golden_fixture.dart at 412x915 dp, dark and
// light, real fonts, each drawing's finished frame (reduced motion).
//
// Only public screens are used, and every tap is guarded by whether its key
// exists, so the same file renders the old code and the new:
//
//   flutter test --concurrency=1 --dart-define=TEAM_MOTION_CAPTURE=before \
//     tool/capture/motion_team_test.dart      # with lib/ at cf1d7464
//   flutter test --concurrency=1 tool/capture/motion_team_test.dart
//
// Output: docs/qa/motion-team-2026-09-25/<before|after>-N-<shot>-<mode>.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/team/run_screen.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';

import '../../test/support/team_golden_fixture.dart';
import 'fixtures.dart';

const _prefix = String.fromEnvironment(
  'TEAM_MOTION_CAPTURE',
  defaultValue: 'after',
);
const _out = 'docs/qa/motion-team-2026-09-25';

enum _Shot {
  homeEmpty('home-empty', TeamScene.empty),
  homeNeedsYou('home-needs-you', TeamScene.loaded),
  planning('planning', TeamScene.empty),
  homeStarting('home-starting', TeamScene.starting),
  runMerged('run-merged', TeamScene.loaded),
  runNeedsYou('run-needs-you', TeamScene.loaded);

  const _Shot(this.name, this.scene);

  final String name;
  final TeamScene scene;
}

Future<void> _tapIfThere(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) return;
  await tester.tap(finder.first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final (index, shot) in _Shot.values.indexed) {
      testWidgets('$_prefix ${shot.name} $mode', (tester) async {
        addTearDown(tester.view.reset);
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        resetTeamMoments();
        final boundary = GlobalKey();
        final controller = await teamSceneController(shot.scene);
        DateTime now() => teamSceneClock;
        final Widget home = switch (shot) {
          _Shot.runMerged => RunScreen(
            controller: controller,
            runId: teamSceneMergedRunId,
            now: now,
          ),
          _Shot.runNeedsYou => RunScreen(
            controller: controller,
            runId: teamSceneRunId,
            now: now,
          ),
          _ => TeamHomeScreen(controller: controller, now: now),
        };
        try {
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: captureTheme(light: light),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: RepaintBoundary(key: boundary, child: child),
              ),
              home: home,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          if (shot == _Shot.planning) {
            // Give the team a task: the planner's card appears on the home.
            await _tapIfThere(tester, 'team-home-start-run');
            final objective = find.byKey(
              const ValueKey('team-start-run-objective'),
            );
            if (objective.evaluate().isNotEmpty) {
              await tester.enterText(objective, 'Add a dark mode toggle');
              await tester.pump();
              await _tapIfThere(tester, 'team-start-run-send');
              await tester.pump(const Duration(seconds: 1));
            }
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          await writePng(
            '$_out/$_prefix-${index + 1}-${shot.name}-$mode.png',
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
}
