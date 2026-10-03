import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/builtin/setup/phone_setup.dart';
import 'package:opencode_mobile/builtin/setup/setup_contract.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/launch_shortcut.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_progress_screen.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_ready_screen.dart';
import 'package:opencode_mobile/ui/screens/phone_setup/phone_setup_routes.dart';

import 'support/fake_setup_engine.dart';

// Open point 2 of phone setup v2: tapping a setup notification opens the
// setup, whether the app was running, in the background or killed. Native
// puts the action on the notification's intent (SetupService.kt) and
// MainActivity hands it over on the launcher-shortcut channel; this pins
// the Dart half and the native contract it relies on.

SetupProgress _job(SetupState state, {bool first = false}) => SetupProgress(
  jobId: 'job-1',
  state: state,
  overall: .5,
  firstSetup: first,
  components: const [
    ComponentProgress(id: 'linux', state: ComponentState.done),
    ComponentProgress(id: 'node', state: ComponentState.pending),
  ],
);

/// A navigator with a plain home, so the route pushed is the only change.
Future<NavigatorState> _navigator(WidgetTester tester) async {
  final key = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        navigatorKey: key,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Text('home')),
      ),
    ),
  );
  return key.currentState!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the shortcut channel carries the notification taps', () {
    const channel = MethodChannel('oc/shortcut');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('a tap that started the app (cold start) is drained', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'consumeLaunchAction') return 'phone_setup';
        return null;
      });
      final shortcut = LaunchShortcut(channel: channel);
      addTearDown(shortcut.dispose);
      await shortcut.start();
      expect(shortcut.pending.value, LaunchAction.phoneSetup);
    });

    test('a tap while the app runs arrives live', () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);
      final shortcut = LaunchShortcut(channel: channel);
      addTearDown(shortcut.dispose);
      await shortcut.start();
      await messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall('launched', 'phone_setup_done'),
        ),
        (_) {},
      );
      expect(shortcut.pending.value, LaunchAction.phoneSetupDone);
    });
  });

  group('where a tap lands', () {
    late FakeSetupEngine engine;

    setUp(() {
      engine = FakeSetupEngine();
      PhoneSetup.engine = engine;
      PhoneSetup.resetReadyShown();
    });

    testWidgets('a running first setup opens screen B as a first setup, '
        'after reading the job', (tester) async {
      final navigator = await _navigator(tester);
      engine.emit(_job(SetupState.running, first: true));
      Route<void>? route;
      await tester.runAsync(
        () async => route = await openPhoneSetupFromNotification(navigator),
      );
      expect(engine.restores, 1, reason: 'a cold start knows only setup.json');
      await tester.pumpAndSettle();

      expect(route?.settings.name, phoneSetupProgressRouteName);
      expect(
        tester
            .widget<PhoneSetupProgressScreen>(
              find.byType(PhoneSetupProgressScreen),
            )
            .firstSetup,
        isTrue,
      );
    });

    testWidgets('a stopped update (not a first setup) opens screen B, which '
        'ends back where it was', (tester) async {
      final navigator = await _navigator(tester);
      engine.emit(_job(SetupState.interrupted));
      await tester.runAsync(() => openPhoneSetupFromNotification(navigator));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PhoneSetupProgressScreen>(
              find.byType(PhoneSetupProgressScreen),
            )
            .firstSetup,
        isFalse,
      );
    });

    testWidgets('a tap while screen B or C is on top changes nothing', (
      tester,
    ) async {
      final navigator = await _navigator(tester);
      engine.emit(_job(SetupState.running, first: true));
      for (final top in [
        phoneSetupProgressRouteName,
        phoneSetupReadyRouteName,
      ]) {
        Route<void>? route;
        await tester.runAsync(
          () async => route = await openPhoneSetupFromNotification(
            navigator,
            topRouteName: top,
          ),
        );
        expect(route, isNull, reason: top);
      }
      await tester.pumpAndSettle();
      expect(find.byType(PhoneSetupProgressScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a finished first setup opens "name your first project" '
        'once', (tester) async {
      final navigator = await _navigator(tester);
      engine.emit(_job(SetupState.done, first: true));
      Route<void>? first;
      await tester.runAsync(
        () async => first = await openPhoneSetupFromNotification(navigator),
      );
      await tester.pumpAndSettle();
      expect(first?.settings.name, phoneSetupReadyRouteName);
      expect(find.byType(PhoneSetupReadyScreen), findsOneWidget);

      navigator.pop();
      await tester.pumpAndSettle();
      Route<void>? again;
      await tester.runAsync(
        () async => again = await openPhoneSetupFromNotification(navigator),
      );
      expect(again, isNull);
    });

    testWidgets('screen C shown by screen B is not offered again', (
      tester,
    ) async {
      final navigator = await _navigator(tester);
      engine.emit(_job(SetupState.done, first: true));
      PhoneSetup.markReadyShown('job-1');
      Route<void>? route;
      await tester.runAsync(
        () async => route = await openPhoneSetupFromNotification(navigator),
      );
      expect(route, isNull);
    });

    testWidgets('a finished update, or no job at all, just brings the app '
        'forward', (tester) async {
      final navigator = await _navigator(tester);
      for (final progress in [_job(SetupState.done), SetupProgress.idle]) {
        engine.emit(progress);
        Route<void>? route;
        await tester.runAsync(
          () async => route = await openPhoneSetupFromNotification(navigator),
        );
        expect(route, isNull, reason: progress.state.name);
      }
    });

    testWidgets('a job read that hangs falls back to what the engine holds', (
      tester,
    ) async {
      final navigator = await _navigator(tester);
      final hanging = _HangingEngine()
        ..emit(_job(SetupState.failed, first: true));
      Route<void>? route;
      await tester.runAsync(
        () async => route = await openPhoneSetupFromNotification(
          navigator,
          engine: hanging,
          restoreTimeout: const Duration(milliseconds: 20),
        ),
      );
      expect(route?.settings.name, phoneSetupProgressRouteName);
    });
  });

  group('the native half', () {
    const kotlin =
        'android/app/src/main/kotlin/io/github/eslamasabry/opencode_mobile';
    final service = File('$kotlin/SetupService.kt').readAsStringSync();
    final runner = File('$kotlin/SetupRunner.kt').readAsStringSync();

    test('both notifications open MainActivity with a whitelisted action', () {
      expect(service, contains('LAUNCH_ACTION_PROGRESS = "phone_setup"'));
      expect(service, contains('LAUNCH_ACTION_DONE = "phone_setup_done"'));
      expect(
        service,
        contains('.putExtra(MainActivity.EXTRA_LAUNCH_ACTION, action)'),
      );
      // The ongoing notification (start and every update) opens progress.
      expect(
        RegExp(
          r'build\([^)]*ongoing = true, LAUNCH_ACTION_PROGRESS\)',
        ).allMatches(service),
        hasLength(2),
      );
      // Extras alone do not make PendingIntents different: one request code
      // per action, updated in place.
      expect(service, contains('if (action == LAUNCH_ACTION_DONE) 3 else 2'));
      expect(service, contains('PendingIntent.FLAG_UPDATE_CURRENT'));
    });

    test('the result notification says whether the job finished', () {
      expect(
        service,
        contains(
          'val action = if (done) LAUNCH_ACTION_DONE else LAUNCH_ACTION_PROGRESS',
        ),
      );
      expect(runner, contains('done = ended == "done"'));
    });

    test('every action the notifications send is one Dart understands', () {
      for (final wire in ['phone_setup', 'phone_setup_done']) {
        expect(LaunchAction.fromWire(wire), isNotNull, reason: wire);
      }
    });
  });
}

class _HangingEngine extends FakeSetupEngine {
  @override
  Future<void> restore() => Completer<void>().future;
}
