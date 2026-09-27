// screen-team-2 goldens: the AI Team home rebuilt from kit parts (KitScreen
// with KitTopBar, rows on KitRowGroup panels, KitSwitchRow, the pinned
// KitSearchField) and the Start-a-task sheet in the kit sheet frame, at
// 412x915 and 1280x800, light and dark, with the app's real fonts and the
// recorded team fixture (test/support/team_golden_fixture.dart).
//
// Regenerate deliberately and look at every image:
//   flutter test --update-goldens test/revamp/screen_team_2_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import '../support/team_golden_fixture.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

enum _Shot {
  homeLoaded(TeamScene.loaded, 'team_home_loaded', _phone),
  homeLoadedWide(TeamScene.loaded, 'team_home_loaded', _wide),
  homeEmpty(TeamScene.empty, 'team_home_empty', _phone),
  homeSearch(TeamScene.busy, 'team_home_search', _phone),
  startRun(TeamScene.loaded, 'team_start_run', _phone),
  startRunWide(TeamScene.loaded, 'team_start_run', _wide);

  const _Shot(this.scene, this.state, this.size);
  final TeamScene scene;
  final String state;
  final Size size;

  String name(bool light) {
    final sized = size == _phone
        ? ''
        : '_${size.width.toInt()}x${size.height.toInt()}';
    return '$state${sized}_${light ? 'light' : 'dark'}';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    for (final shot in _Shot.values) {
      testWidgets(shot.name(light), (tester) async {
        tester.view.physicalSize = shot.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        resetTeamMoments();
        final controller = await teamSceneController(shot.scene);
        addTearDown(controller.dispose);
        final boundary = GlobalKey();
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
            home: TeamHomeScreen(
              controller: controller,
              now: () => teamSceneClock,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        switch (shot) {
          case _Shot.homeSearch:
            await tester.tap(
              find.byKey(const ValueKey('team-home-search-open')),
            );
          case _Shot.startRun || _Shot.startRunWide:
            await tester.tap(find.byKey(const ValueKey('team-home-start-run')));
          case _Shot.homeLoaded || _Shot.homeLoadedWide || _Shot.homeEmpty:
            break;
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(boundary),
          matchesGoldenFile('goldens/${shot.name(light)}.png'),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
