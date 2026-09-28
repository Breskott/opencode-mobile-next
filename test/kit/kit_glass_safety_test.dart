// KitGlassSafety (emulator QA of build 2062, F1): liquid glass is never
// loaded on an emulated or software renderer, and two sessions in a row that
// died with liquid glass on screen turn it off for a week; a good phone keeps
// it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/app_exit.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lets the store's writes land (they chain a few futures).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  tearDown(KitGlassSafety.debugReset);

  group('software renderer', () {
    test('the Android emulator is one', () {
      // What emulator-5554 (Pixel_6, API 34, swiftshader_indirect) reports.
      expect(
        KitGlassSafety.softwareRenderer(const {
          'ro.kernel.qemu': '1',
          'ro.boot.qemu': '1',
          'ro.hardware': 'ranchu',
          'ro.hardware.egl': 'emulation',
        }),
        isTrue,
      );
      expect(
        KitGlassSafety.softwareRenderer(const {'ro.hardware': 'goldfish'}),
        isTrue,
      );
      expect(
        KitGlassSafety.softwareRenderer(const {
          'ro.hardware.egl': 'swiftshader',
        }),
        isTrue,
      );
    });

    test('a real phone is not', () {
      // An Adreno phone (the owner's) and a Mali one.
      expect(
        KitGlassSafety.softwareRenderer(const {
          'ro.hardware': 'qcom',
          'ro.hardware.egl': 'adreno',
          'ro.kernel.qemu': '',
        }),
        isFalse,
      );
      expect(
        KitGlassSafety.softwareRenderer(const {
          'ro.hardware': 'mt6789',
          'ro.hardware.egl': 'mali',
        }),
        isFalse,
      );
      expect(KitGlassSafety.softwareRenderer(const {}), isFalse);
    });
  });

  group('strikes', () {
    var clock = DateTime(2026, 9, 29, 9);

    setUp(() {
      clock = DateTime(2026, 9, 29, 9);
      KitGlassSafety.now = () => clock;
      KitGlassSafety.readExit = () async => AppExitKind.crash;
    });

    for (final kind in [
      AppExitKind.forceStop,
      AppExitKind.lowMemory,
      AppExitKind.update,
      AppExitKind.killed,
      AppExitKind.normal,
      null,
    ]) {
      test('${kind?.name ?? 'no exit record'} is never a strike', () async {
        KitGlassSafety.readExit = () async => kind;
        SharedPreferences.setMockInitialValues({
          KitGlassSafety.activeKey: true,
        });
        final prefs = await SharedPreferences.getInstance();
        for (var i = 0; i < 4; i++) {
          expect(await KitGlassSafety.allowed(), isTrue);
          await prefs.setBool(KitGlassSafety.activeKey, true);
        }
        expect(prefs.getInt(KitGlassSafety.strikesKey) ?? 0, 0);
        expect(prefs.getInt(KitGlassSafety.offUntilKey), isNull);
        expect(KitGlassSafety.turnedOffAfterCrashes.value, isFalse);
      });
    }

    test('an unreadable exit record is not a strike', () async {
      KitGlassSafety.readExit = () => Future.error(StateError('no channel'));
      SharedPreferences.setMockInitialValues({KitGlassSafety.activeKey: true});
      expect(await KitGlassSafety.allowed(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(KitGlassSafety.strikesKey) ?? 0, 0);
    });

    test('turning it back on clears the strikes and the pause', () async {
      SharedPreferences.setMockInitialValues({KitGlassSafety.activeKey: true});
      final prefs = await SharedPreferences.getInstance();
      expect(await KitGlassSafety.allowed(), isTrue);
      await prefs.setBool(KitGlassSafety.activeKey, true);
      expect(await KitGlassSafety.allowed(), isFalse);
      expect(KitGlassSafety.turnedOffAfterCrashes.value, isTrue);

      await KitGlassSafety.turnBackOn();
      expect(KitGlassSafety.turnedOffAfterCrashes.value, isFalse);
      expect(prefs.getInt(KitGlassSafety.offUntilKey), isNull);
      expect(prefs.getInt(KitGlassSafety.strikesKey), isNull);
      expect(await KitGlassSafety.allowed(), isTrue);

      // One more crash after turning it back on is a first strike again.
      await prefs.setBool(KitGlassSafety.activeKey, true);
      expect(await KitGlassSafety.allowed(), isTrue);
      expect(prefs.getInt(KitGlassSafety.strikesKey), 1);
    });

    test('a clean start allows liquid glass', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await KitGlassSafety.allowed(), isTrue);
    });

    test('one session that crashed with glass on screen is one strike, still '
        'allowed; a second in a row turns it off for a week', () async {
      SharedPreferences.setMockInitialValues({KitGlassSafety.activeKey: true});
      expect(await KitGlassSafety.allowed(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(KitGlassSafety.strikesKey), 1);
      expect(prefs.getBool(KitGlassSafety.activeKey), isFalse);

      // It died again.
      await prefs.setBool(KitGlassSafety.activeKey, true);
      expect(await KitGlassSafety.allowed(), isFalse);
      expect(prefs.getInt(KitGlassSafety.offUntilKey), isNotNull);

      // Still off six days later; back after the week.
      clock = clock.add(const Duration(days: 6));
      expect(await KitGlassSafety.allowed(), isFalse);
      clock = clock.add(const Duration(days: 2));
      expect(await KitGlassSafety.allowed(), isTrue);
      expect(prefs.getInt(KitGlassSafety.offUntilKey), isNull);
    });

    test('no store (a failure to read it) never costs the look', () async {
      KitGlassSafety.store = () => Future.error(StateError('no store'));
      expect(await KitGlassSafety.allowed(), isTrue);
    });

    testWidgets('glass shown then sent to the background is not a strike, '
        'and a long healthy run clears strikes', (tester) async {
      SharedPreferences.setMockInitialValues({KitGlassSafety.strikesKey: 1});
      await tester.pumpWidget(const SizedBox());
      KitGlassSafety.watch();
      await tester.pump();
      await settle(tester);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(KitGlassSafety.activeKey), isTrue);

      clock = clock.add(const Duration(minutes: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      await settle(tester);
      expect(prefs.getBool(KitGlassSafety.activeKey), isFalse);
      expect(prefs.getInt(KitGlassSafety.strikesKey), isNull);
      // A clean next start: no strike counted.
      expect(await KitGlassSafety.allowed(), isTrue);
      expect(prefs.getInt(KitGlassSafety.strikesKey), isNull);
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      // Back in the foreground: the flag is set again.
      expect(prefs.getBool(KitGlassSafety.activeKey), isTrue);
    });
  });
}
