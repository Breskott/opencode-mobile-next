// screen-team-3 goldens: the AI Team's agents list (one list by urgency,
// one mark style, "furiosa · Worker", Wake on a paused agent, "checked …"
// in the top bar) and the Work sheet in the kit sheet frame (rows for what
// it depends on and what waits on it, output and validation, Technical
// details folded last), at 412x915 and 1280x800, light and dark, with the
// app's real fonts and the screen-team-3 fixture.
//
// Regenerate deliberately and look at every image:
//   flutter test --update-goldens test/revamp/screen_team_3_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/team/team_agents_screen.dart';
import 'package:opencode_mobile/ui/screens/team/work_sheet.dart';

import '../../tool/capture/fixtures.dart' show captureTheme, loadCaptureFonts;
import 'screen_team_3_fixtures.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

enum _Shot {
  agents('team_agents', _phone),
  agentsWide('team_agents', _wide),
  workSheet('team_work_sheet', _phone),
  workSheetWide('team_work_sheet', _wide);

  const _Shot(this.state, this.size);
  final String state;
  final Size size;

  bool get sheet => this == workSheet || this == workSheetWide;

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
        final (controller, _) = await team3Controller();
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
            home: TeamAgentsScreen(
              controller: controller,
              now: () => team3Clock,
              // The sheet opens over the list, from any row.
              onOpenAgent: (_) {},
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        if (shot.sheet) {
          final context = tester.element(
            find.byKey(const ValueKey('team-agents')),
          );
          showWorkSheet(context, controller, 'oc-loy', now: () => team3Clock);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
        }
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
