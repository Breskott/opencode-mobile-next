// Actual widgets with synthetic profiles. No live probes or installations.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';

import '../../test/support/setup_capture_preferences.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  const stage = String.fromEnvironment('CAPTURE_STAGE', defaultValue: 'after');
  for (final light in [true, false]) {
    for (final scale in [1.0, 2.0]) {
      for (final page in ['servers', 'first-run', 'editor']) {
        testWidgets('$stage $page ${light ? 'light' : 'dark'} ${scale}x', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          const secure = MethodChannel(
            'plugins.it_nomads.com/flutter_secure_storage',
          );
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            secure,
            (call) async =>
                call.method == 'readAll' ? <String, String>{} : null,
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(secure, null),
          );
          final store = SeededProfileStore(
            prefs: await setupCapturePreferences(),
            seeded: page == 'servers'
                ? [
                    ServerProfile(
                      id: 'one',
                      name: 'Work computer',
                      baseUrl: 'https://work.example',
                      serverVersion: '1.18.25',
                    ),
                    ServerProfile(
                      id: 'two',
                      name: 'OpenCode lab',
                      baseUrl: 'https://lab.example',
                      flavor: ServerFlavor.v2,
                      serverVersion: '0.0.0-beta',
                    ),
                    ServerProfile(
                      id: 'old',
                      name: 'Older connection',
                      baseUrl: 'https://old.example',
                    ),
                  ]
                : [],
          );
          final controller = ConnectionController(store);
          addTearDown(controller.dispose);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            captureApp(
              home: const ServersScreen(),
              boundaryKey: boundary,
              controller: controller,
              light: light,
            ),
          );
          await tester.pumpAndSettle();
          if (page == 'editor') {
            final entry = find.byKey(
              ValueKey(
                stage == 'before'
                    ? 'welcome-connect-card'
                    : 'connect-existing-opencode2',
              ),
            );
            await tester.ensureVisible(entry);
            await tester.pumpAndSettle();
            await tester.tap(entry);
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          await writePng(
            'docs/qa/oc2-server-discovery/$stage-$page-${light ? 'light' : 'dark'}-${scale.toInt()}x.png',
            await capturePng(tester, boundary, pixelRatio: 2),
          );
          if (stage == 'after' && page == 'first-run') {
            await tester.ensureVisible(
              find.byKey(const ValueKey('welcome-termux-card')),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await writePng(
              'docs/qa/oc2-server-discovery/after-first-run-options-${light ? 'light' : 'dark'}-${scale.toInt()}x.png',
              await capturePng(tester, boundary, pixelRatio: 2),
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
      }
    }
  }
}
