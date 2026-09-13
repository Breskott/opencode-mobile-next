// Current-source layout evidence using local fixtures; no server or model calls.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/adapters/fixture/fixture_gateway.dart';
import 'package:opencode_mobile/state/orchestration.dart';
import 'package:opencode_mobile/state/orchestration_store.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/team/team_home_screen.dart';

import '../../test/support/setup_capture_preferences.dart';

import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  for (final scale in [1.0, 2.5]) {
    testWidgets('AI Team current source at ${scale}x', (tester) async {
      tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final prefs = await setupCapturePreferences();
      final path = '${Directory.current.path}/tool/qa/gascity_fixture';
      final gateway = FixtureOrchestrationGateway(fixturePath: path);
      final config = OrchestrationConfig(
        provider: OrchestrationProvider.fixture,
        url: path,
        city: 'bright-lights',
        enabledAt: DateTime.utc(2026, 9, 10),
      );
      final controller = OrchestrationController(
        profile: ServerProfile(
          id: 'capture',
          name: 'Development PC',
          baseUrl: 'https://server.example',
          orchestration: config,
        ),
        config: config,
        store: OrchestrationStore(prefs),
        gatewayFactory: (_, _) => gateway,
        now: () => DateTime.utc(2026, 9, 11, 9, 41),
      );
      addTearDown(controller.dispose);
      await controller.start();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: captureTheme(light: false),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: RepaintBoundary(key: boundary, child: child),
          ),
          home: TeamHomeScreen(
            controller: controller,
            now: () => DateTime.utc(2026, 9, 11, 9, 41),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await writePng(
        'docs/qa/stable-ui-2026-09-13/team-${scale}x.png',
        await capturePng(tester, boundary, pixelRatio: 1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
