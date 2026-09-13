// Synthetic rendered evidence; all Termux mutations are refused.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/termux/bridge.dart';
import 'package:opencode_mobile/ui/screens/termux_setup_screen.dart';

import '../../test/support/setup_capture_preferences.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);
  for (final variant in [
    (name: 'light', light: true, width: 390.0, scale: 1.0),
    (name: 'dark', light: false, width: 390.0, scale: 1.0),
    (name: 'large', light: true, width: 320.0, scale: 2.0),
  ]) {
    for (final state in ['oc1', 'oc2', 'failed', 'progress', 'legacy-oc2']) {
      testWidgets('managed switch ${variant.name} $state', (tester) async {
        tester.view.physicalSize = Size(variant.width * 2, 844 * 2);
        tester.view.devicePixelRatio = 2;
        tester.platformDispatcher.textScaleFactorTestValue = variant.scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        const channel = MethodChannel('oc/termux');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final runtime = state == 'oc1' ? 'opencode1' : 'opencode2';
        final phase = state == 'failed'
            ? 'failed'
            : state == 'progress'
            ? 'installing_opencode'
            : 'ready';
        final pending = state == 'failed' || state == 'progress';
        final snapshot =
            'phase=$phase\nmessage=${state == 'failed'
                ? 'OpenCode server did not become authenticated and ready within 30 seconds'
                : state == 'progress'
                ? 'Installing OpenCode 2 beta'
                : 'OpenCode is ready'}\n'
            'port=4096\nrunner=proot\nversion=${runtime == 'opencode1' ? '1.18.29' : '0.0.0-beta-18600'}\nruntime=$runtime\npid=123\n'
            '${state == 'legacy-oc2' ? '' : 'switch_return=opencode1\n'}'
            '${pending ? 'switch_previous=opencode1\nswitch_target=opencode2\nswitch_phase=starting\n' : ''}'
            '__OC_SETUP_OUTPUT__\n[oc] Checking the selected runtime\n';
        Map<String, Object> result(String output) => {
          'stdout': output,
          'stderr': '',
          'exitCode': 0,
          'err': -1,
          'errorMessage': '',
        };
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getCapabilities') {
            return {
              'installed': true,
              'version': '0.118.3',
              'serviceAvailable': true,
              'protocolSupported': true,
              'permissionGranted': true,
            };
          }
          if (call.method == 'runInTermux') {
            final script = (call.arguments as Map)['script'] as String;
            if (script.contains("printf 'opencode-bridge-ok'")) {
              return result('opencode-bridge-ok');
            }
            if (script.contains('ubuntu=absent')) {
              return result(
                'ubuntu=installed\nversion=${runtime == 'opencode1' ? '1.18.29' : '0.0.0-beta-18600'}\nruntime=$runtime\n',
              );
            }
            if (script.contains(' status')) return result(snapshot);
          }
          throw StateError('Capture refuses a mutation: ${call.method}');
        });
        final store = SeededProfileStore(
          prefs: await setupCapturePreferences(),
          seeded: [
            ServerProfile(
              id: 'remote',
              name: 'Laptop',
              baseUrl: 'https://example.invalid',
            ),
            ServerProfile(
              id: 'oc1',
              name: 'This phone · OpenCode 1',
              baseUrl: TermuxBridge.managedServerUrl,
              password: 'fixture-one',
              serverVersion: '1.18.29',
            ),
            ServerProfile(
              id: 'oc2',
              name: 'This phone · OpenCode 2 beta',
              baseUrl: TermuxBridge.managedServerUrl,
              flavor: ServerFlavor.v2,
              password: 'fixture-two',
              serverVersion: '0.0.0-beta-18600',
            ),
          ],
        );
        final controller = CaptureController(store);
        try {
          final boundary = GlobalKey();
          await tester.pumpWidget(
            captureApp(
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(variant.scale)),
                  child: const TermuxSetupScreen(),
                ),
              ),
              boundaryKey: boundary,
              controller: controller,
              store: store,
              light: variant.light,
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
          expect(
            find.text(
              state == 'progress'
                  ? 'Switching to OpenCode 2 beta'
                  : runtime == 'opencode1'
                  ? 'OpenCode 1'
                  : 'OpenCode 2 beta',
            ),
            findsOneWidget,
          );
          await writePng(
            'docs/qa/oc2-managed-switch/${variant.name}-$state.png',
            await capturePng(tester, boundary, pixelRatio: 2),
          );
          if (state == 'oc1') {
            await tester.tap(find.text('Try OpenCode 2 beta'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await writePng(
              'docs/qa/oc2-managed-switch/${variant.name}-confirmation.png',
              await capturePng(tester, boundary, pixelRatio: 2),
            );
          }
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          controller.dispose();
          messenger.setMockMethodCallHandler(channel, null);
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}
