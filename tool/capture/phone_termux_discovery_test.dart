// Matched synthetic screenshots: remote server, no native/remote mutations.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/library_screen.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';
import '../../test/support/setup_capture_preferences.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  const stage = String.fromEnvironment('CAPTURE_STAGE', defaultValue: 'after');
  for (final light in [true, false]) {
    for (final scale in [1.0, 2.0]) {
      for (final page in ['more', 'servers', 'first-run']) {
        testWidgets('$stage $page ${light ? 'light' : 'dark'} ${scale}x', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          expect(platformCapabilities.supportsTermux, isTrue);
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
          final prefs = await setupCapturePreferences();
          final store = SeededProfileStore(
            prefs: prefs,
            seeded: page == 'first-run'
                ? []
                : [
                    ServerProfile(
                      id: 'remote',
                      name: 'Work computer',
                      baseUrl: 'https://work.example',
                    ),
                  ],
          );
          final controller = ConnectionController(store);
          addTearDown(controller.dispose);
          final boundary = GlobalKey();
          await tester.pumpWidget(
            captureApp(
              home: page == 'more'
                  ? Scaffold(
                      appBar: AppBar(title: const Text('More')),
                      body: LibraryScreen(controller: controller),
                    )
                  : const ServersScreen(),
              boundaryKey: boundary,
              controller: controller,
              light: light,
            ),
          );
          await tester.pumpAndSettle();
          if (stage == 'after') {
            expect(find.text('Termux setup'), findsOneWidget);
          }
          if (stage == 'before') {
            expect(find.text('Termux setup'), findsNothing);
          }
          expect(tester.takeException(), isNull);
          await writePng(
            'docs/qa/phone-termux-discovery/$stage-$page-${light ? 'light' : 'dark'}-${scale.toInt()}x.png',
            await capturePng(tester, boundary, pixelRatio: 2),
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
      }
    }
  }
}
