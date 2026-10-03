// Before/after captures for the AI Team redesign (2026-09-24,
// docs/design/aiteam-redesign-2026-09-24.md): the scenes of
// test/support/team_golden_fixture.dart at 412x915 dp, dark theme, real
// fonts.
//
// Only public screens (TeamHomeScreen, the task conversation) and the scene
// controller are used, and every tap is guarded by whether its key exists,
// so the same file renders the old code and the new:
//
//   flutter test --concurrency=1 --dart-define=AITEAM_CAPTURE=before \
//     tool/capture/aiteam_redesign_test.dart          # on 51a775cf
//   flutter test --concurrency=1 tool/capture/aiteam_redesign_test.dart
//
// Output: docs/qa/aiteam-redesign-2026-09-24/<before|after>-N-<shot>.png
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/chat_screen.dart'
    show TeamConversationScreen;
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';

import '../../test/support/team_golden_fixture.dart';
import 'fixtures.dart';

const _prefix = String.fromEnvironment('AITEAM_CAPTURE', defaultValue: 'after');
const _out = 'docs/qa/aiteam-redesign-2026-09-24';

enum _Shot {
  homeLoaded('home-loaded', TeamScene.loaded),
  homeLoadedPhone('home-loaded-phone', TeamScene.loaded, onPhone: true),
  homeEmpty('home-empty', TeamScene.empty),
  runOverview('run-overview', TeamScene.loaded),
  runSteps('run-steps', TeamScene.loaded),
  agents('agents', TeamScene.loaded);

  const _Shot(this.name, this.scene, {this.onPhone = false});

  final String name;
  final TeamScene scene;
  final bool onPhone;
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

  for (final (index, shot) in _Shot.values.indexed) {
    testWidgets('$_prefix ${shot.name}', (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      final boundary = GlobalKey();
      final controller = await teamSceneController(
        shot.scene,
        onPhone: shot.onPhone,
      );
      DateTime now() => teamSceneClock;
      final Widget home = switch (shot) {
        _Shot.runOverview || _Shot.runSteps => TeamConversationScreen(
          team: controller,
          runId: teamSceneRunId,
          now: now,
        ),
        _ => TeamHomeScreen(controller: controller, now: now),
      };
      try {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: captureTheme(),
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
        switch (shot) {
          case _Shot.homeLoaded || _Shot.homeLoadedPhone:
            // The old home kept finished runs behind a collapsed group; the
            // new one lists up to three without a tap.
            if (_prefix == 'before') {
              await _tapIfThere(tester, 'team-home-completed-group');
            }
          case _Shot.runSteps:
            // Old: the Work tab; since P3.5: Task details from the menu.
            await _tapIfThere(tester, 'team-run-tab-work');
            await _tapIfThere(tester, 'team-conversation-menu');
            await _tapIfThere(tester, 'team-conversation-details');
          case _Shot.agents:
            // Old: the Agents segment; new: the agents row opens the list.
            await _tapIfThere(tester, 'team-home-segment-agents');
            await _tapIfThere(tester, 'team-home-agents-row');
          case _Shot.homeEmpty || _Shot.runOverview:
            break;
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        await writePng(
          '$_out/$_prefix-${index + 1}-${shot.name}.png',
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
