// slice-R15 golden: Servers with OpenCode inside this app ("This phone") as
// one row of the one urgency-ordered list (PhoneServerCard.row), beside a
// connected remote server, at the phone size (412x915) and one wide window
// (1280x800), dark and light, with the app's real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/slice_r15_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/sse.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/builtin_server.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/screens/servers_screen.dart';

import '../../tool/capture/fixtures.dart';
import '../support/setup_capture_preferences.dart';

/// OpenCode inside the app: installed and running.
class _Linux extends BuiltinLinux {
  @override
  Future<BuiltinLinuxStatus> status() async => const BuiltinLinuxStatus(
    installed: true,
    phase: BuiltinLinuxPhase.ready,
    serverRunning: true,
    bytesUsed: 734003200,
  );
}

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final size in [_phone, _wide]) {
    for (final light in [false, true]) {
      final name = [
        'slice_r15_servers_phone_row',
        if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
        light ? 'light' : 'dark',
      ].join('_');
      testWidgets(name, (tester) async {
        debugPlatformCapabilities = const PlatformCapabilities.android();
        const secure = MethodChannel(
          'plugins.it_nomads.com/flutter_secure_storage',
        );
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          secure,
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
        // No Termux on this phone: only the in-app server is listed.
        const termux = MethodChannel('oc/termux');
        messenger.setMockMethodCallHandler(
          termux,
          (call) async => call.method == 'getCapabilities'
              ? <String, Object>{'installed': false}
              : null,
        );
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final prefs = await setupCapturePreferences();
        final store = SeededProfileStore(
          prefs: prefs,
          seeded: [
            // The first profile is the active one: the server in use.
            ServerProfile(
              id: 'studio',
              name: 'Studio Mac',
              baseUrl: 'https://studio.tail0c1.ts.net',
              flavor: ServerFlavor.v2,
              serverVersion: '2.0.10',
              password: 'synthetic',
            ),
            ServerProfile(
              id: 'phone',
              name: 'This phone, built-in (OpenCode 1)',
              baseUrl: BuiltinLinux.serverUrl,
              username: BuiltinLinux.serverUsername,
              password: 'synthetic-phone',
              serverVersion: '1.18.29',
            ),
          ],
        );
        final controller = CaptureController(store)
          ..api = CaptureApi()
          ..repository = CaptureRepository()
          ..status = StreamStatus.connected
          ..directory = projectDirectory
          ..version = '2.0.10';
        final linux = _Linux();
        final boundary = GlobalKey();
        try {
          await tester.pumpWidget(
            captureApp(
              home: ProviderScope(
                overrides: [
                  builtinLinuxProvider.overrideWithValue(linux),
                  builtinServerStarterProvider.overrideWith((ref) {
                    final starter = BuiltinServerStarter(
                      linux: linux,
                      pollInterval: Duration.zero,
                    );
                    ref.onDispose(starter.dispose);
                    return starter;
                  }),
                ],
                child: const ServersScreen(),
              ),
              boundaryKey: boundary,
              controller: controller,
              light: light,
              routes: {'/home': (_) => const Scaffold()},
            ),
          );
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
          expect(tester.takeException(), isNull);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('servers-list')),
              matching: find.byKey(const ValueKey('phone-server-row')),
            ),
            findsOneWidget,
          );
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile('goldens/$name.png'),
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          await tester.pump(const Duration(minutes: 2));
          debugPlatformCapabilities = null;
          messenger.setMockMethodCallHandler(secure, null);
          messenger.setMockMethodCallHandler(termux, null);
        }
      });
    }
  }
}
