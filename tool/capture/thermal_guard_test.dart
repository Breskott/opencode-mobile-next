// Renders for the thermal guard (docs/qa/thermal-guard-2026-09-26):
// 412x915 dp, dark, real fonts.
//
//   flutter test --concurrency=1 tool/capture/thermal_guard_test.dart
//
// 1 the Work tab after Android reported SEVERE while the phone's AI Team
//   worked; 2 the same after two cool minutes; 3 the Keep running screen
//   with the "Pause the AI Team when the phone is hot" switch.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/app_exit_recovery.dart';
import 'package:opencode_mobile/builtin/thermal_guard.dart';
import 'package:opencode_mobile/builtin/thermal_guard_teams.dart';
import 'package:opencode_mobile/platform/app_exit.dart';
import 'package:opencode_mobile/platform/thermal.dart';
import 'package:opencode_mobile/ui/screens/home_screen.dart';
import 'package:opencode_mobile/ui/screens/keep_running_screen.dart';

import '../../test/support/setup_capture_preferences.dart';
import 'fixtures.dart';

const _out = 'docs/qa/thermal-guard-2026-09-26';

class _Bridge extends ThermalBridge {
  @override
  Future<ThermalReading> current() async => ThermalReading.unknown;

  @override
  Stream<ThermalReading> readings() => const Stream.empty();

  @override
  Future<bool> notify({required String title, String text = ''}) async => false;
}

class _PhoneTeam implements ThermalTeamPort {
  static const team = ThermalTeam(
    id: 'phone',
    url: 'http://127.0.0.1:8472',
    city: 'phone',
    builtin: true,
  );

  @override
  Future<List<ThermalTeam>> runningHere() async => [team];

  @override
  Future<ThermalTeamHold?> pause(
    ThermalTeam team, {
    required DateTime now,
  }) async => ThermalTeamHold(team: team, since: now, sessions: ['gc-1']);

  @override
  Future<ThermalTeamHold> stop(ThermalTeamHold hold) async => hold;

  @override
  Future<bool> resume(ThermalTeamHold hold) async => true;
}

class _Pixel extends AppLifecycleBridge {
  @override
  Future<KeepAliveInfo> keepAliveInfo() async => const KeepAliveInfo(
    manufacturer: 'Google',
    brand: 'google',
    batteryOptimizationIgnored: true,
  );
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

  for (final shot in [
    (resumed: false, file: '1-work-tab-paused'),
    (resumed: true, file: '2-work-tab-resumed'),
  ]) {
    testWidgets(shot.file, (tester) async {
      view(tester);
      final prefs = await setupCapturePreferences();
      final controller = await captureController(prefs: prefs);
      var now = DateTime(2026, 9, 26, 14);
      final guard = ThermalGuard(
        bridge: _Bridge(),
        port: _PhoneTeam(),
        prefs: prefs,
        clock: () => now,
        inBackground: () => false,
      );
      await tester.runAsync(
        () => guard.observe(
          const ThermalReading(status: ThermalStatus.severe, headroom: 1.02),
        ),
      );
      if (shot.resumed) {
        const cool = ThermalReading(status: ThermalStatus.light);
        await tester.runAsync(() => guard.observe(cool));
        now = now.add(const Duration(minutes: 2));
        await tester.runAsync(() => guard.observe(cool));
      }
      final boundary = GlobalKey();
      try {
        await tester.pumpWidget(
          captureApp(
            home: ProviderScope(
              overrides: [
                thermalGuardSlotProvider.overrideWithValue(
                  ValueNotifier<ThermalGuard?>(guard),
                ),
              ],
              child: const HomeScreen(initialTab: 0),
            ),
            boundaryKey: boundary,
            controller: controller,
          ),
        );
        await _settle(tester);
        expect(tester.takeException(), isNull);
        await writePng(
          '$_out/${shot.file}.png',
          await capturePng(tester, boundary, pixelRatio: 1),
        );
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        guard.dispose();
        await tester.pump();
      }
    });
  }

  testWidgets('3-keep-running-thermal-switch', (tester) async {
    view(tester);
    final prefs = await setupCapturePreferences();
    final controller = await captureController(prefs: prefs);
    final guard = ThermalGuard(
      bridge: _Bridge(),
      port: _PhoneTeam(),
      prefs: prefs,
    );
    final boundary = GlobalKey();
    try {
      await tester.pumpWidget(
        captureApp(
          home: ProviderScope(
            overrides: [
              thermalGuardSlotProvider.overrideWithValue(
                ValueNotifier<ThermalGuard?>(guard),
              ),
              appLifecycleBridgeProvider.overrideWithValue(_Pixel()),
            ],
            child: const Scaffold(
              body: SingleChildScrollView(child: KeepRunningSection()),
            ),
          ),
          boundaryKey: boundary,
          controller: controller,
        ),
      );
      await _settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('keep-running-thermal')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await writePng(
        '$_out/3-keep-running-thermal-switch.png',
        await capturePng(tester, boundary, pixelRatio: 1),
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      guard.dispose();
      await tester.pump();
    }
  });
}
