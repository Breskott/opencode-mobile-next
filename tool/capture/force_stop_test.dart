// Renders for the force-stop resilience slice (docs/qa/force-stop-2026-09-26):
// 412x915 dp, dark, real fonts.
//
//   flutter test --concurrency=1 tool/capture/force_stop_test.dart
//
// 1 the Work tab the next launch after Android force-stopped the app while
//   the phone's OpenCode and the AI Team ran (the owner's record);
// 2 Settings with the "Keep running in the background" row;
// 3 the guidance on a RedMagic (nubia) and 4 on a Pixel.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/app_exit_recovery.dart';
import 'package:opencode_mobile/builtin/builtin_linux.dart';
import 'package:opencode_mobile/builtin/builtin_server.dart';
import 'package:opencode_mobile/platform/app_exit.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:opencode_mobile/ui/screens/keep_running_screen.dart';

import '../../test/support/setup_capture_preferences.dart';
import 'fixtures.dart';

const _out = 'docs/qa/force-stop-2026-09-26';

class _OwnerBridge extends AppLifecycleBridge {
  @override
  Future<AppLaunchReport> launchReport() async {
    final today = DateTime.now();
    return AppLaunchReport.fromMap({
      'exit': {
        'reason': 10,
        'subReason': 21,
        'importance': 125,
        'timestamp': DateTime(
          today.year,
          today.month,
          today.day,
          0,
          6,
          33,
        ).millisecondsSinceEpoch,
      },
      'previousServices': ['server', 'aiteam'],
    });
  }
}

class _NoLinux extends BuiltinLinux {
  @override
  Future<BuiltinLinuxStatus> status() async =>
      const BuiltinLinuxStatus.absent();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  void view(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const secure = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      secure,
      (call) async => call.method == 'readAll' ? <String, String>{} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        secure,
        null,
      ),
    );
  }

  Widget use24h(Widget child) => Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child,
    ),
  );

  for (final tab in [0, 3]) {
    testWidgets('shell tab $tab after a force stop', (tester) async {
      view(tester);
      final prefs = await setupCapturePreferences();
      final controller = await captureController(prefs: prefs);
      final recovery = AppExitRecovery(bridge: _OwnerBridge());
      final starter = BuiltinServerStarter(linux: _NoLinux());
      await recovery.runOnce(
        store: controller.store,
        active: controller.profile,
        starter: starter,
      );
      final boundary = GlobalKey();
      try {
        await tester.pumpWidget(
          captureApp(
            home: ProviderScope(
              overrides: [appExitRecoveryProvider.overrideWithValue(recovery)],
              child: use24h(HomeScreen(initialTab: tab)),
            ),
            boundaryKey: boundary,
            controller: controller,
          ),
        );
        await _settle(tester);
        if (tab == 3) {
          final row = find.byKey(
            const ValueKey('settings-category-background'),
          );
          await tester.scrollUntilVisible(
            row,
            300,
            scrollable: find.byType(Scrollable).last,
          );
          await _settle(tester);
        }
        expect(tester.takeException(), isNull);
        await writePng(
          tab == 0
              ? '$_out/1-work-tab-notice.png'
              : '$_out/2-settings-notifications-and-background-row.png',
          await capturePng(tester, boundary, pixelRatio: 1),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        starter.dispose();
        await tester.pump();
      }
    });
  }

  for (final phone in [
    (maker: 'nubia', file: '3-keep-running-redmagic'),
    (maker: 'Google', file: '4-keep-running-pixel'),
  ]) {
    testWidgets('guidance on ${phone.maker}', (tester) async {
      view(tester);
      const channel = MethodChannel(AppLifecycleBridge.channelName);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          'manufacturer': phone.maker,
          'brand': phone.maker == 'nubia' ? 'RedMagic' : 'google',
          'batteryOptimizationIgnored': phone.maker == 'Google',
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final prefs = await setupCapturePreferences();
      final controller = await captureController(prefs: prefs);
      final boundary = GlobalKey();
      try {
        await tester.pumpWidget(
          captureApp(
            home: const KeepRunningScreen(),
            boundaryKey: boundary,
            controller: controller,
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await writePng(
          '$_out/${phone.file}.png',
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
