// Settings › Appearance › Effects (design standard §10): the four choices
// persist app-wide, the app provides them above its navigator, and each one
// changes what the app does — glass off is solid, Calm never loops, Off shows
// finished frames, Vibration off never reaches the platform.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/main.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:opencode_mobile/ui/theme_packs.dart';
import 'package:opencode_mobile/update/shorebird_update_notice.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Profiles in memory: `load` would otherwise wait on secure storage.
class _MemoryProfileStore extends ProfileStore {
  _MemoryProfileStore({required super.prefs});

  bool refuseEffects = false;

  @override
  List<ServerProfile> get profiles => const [];

  @override
  String? get activeId => null;

  @override
  Future<void> setEffects(KitEffects effects) async {
    if (refuseEffects) throw StateError('disk full');
    await super.setEffects(effects);
  }
}

class _NoUpdateService implements AppUpdateService {
  @override
  bool get isAvailable => false;
  @override
  Future<AppUpdateState> checkForUpdate() async => AppUpdateState.unavailable;
  @override
  Future<void> downloadUpdate() async {}
}

Future<(ConnectionController, _MemoryProfileStore)> _controller([
  Map<String, Object> saved = const {},
]) async {
  SharedPreferences.setMockInitialValues(saved);
  final store = _MemoryProfileStore(
    prefs: await SharedPreferences.getInstance(),
  );
  return (ConnectionController(store), store);
}

Widget _page(ConnectionController controller, {bool reduce = false}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: child!,
      ),
      home: AppearanceSettingsScreen(controller: controller),
    );

/// Records every haptic the app asks the platform for.
List<String> _recordHaptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add('${call.arguments}');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    KitGlassShader.debugReset();
    KitHaptics.enabled = true;
    KitMotion.loops = false;
    harvestedDynamicPack.value = null;
  });

  group('stored', () {
    test('everything is on until the person chooses', () async {
      final (controller, store) = await _controller();
      addTearDown(controller.dispose);
      expect(store.effects, KitEffects.defaults);
      expect(controller.effects.value, KitEffects.defaults);
    });

    test('a choice survives a restart and is app-wide', () async {
      final (controller, store) = await _controller();
      const chosen = KitEffects(
        glass: false,
        motion: KitMotionLevel.calm,
        celebrations: false,
        haptics: false,
      );
      await controller.setEffects(chosen);
      controller.dispose();

      // A new store over the same preferences: the next launch.
      final next = ProfileStore(prefs: store.prefs);
      expect(next.effects, chosen);
      final restarted = ConnectionController(next);
      addTearDown(restarted.dispose);
      expect(restarted.effects.value, chosen);

      // Not scoped to a server: deleting one never resets them.
      const keys = [
        'oc.effectsGlass',
        'oc.effectsMotion',
        'oc.effectsCelebrations',
        'oc.effectsHaptics',
      ];
      for (final key in keys) {
        expect(store.prefs.containsKey(key), isTrue, reason: key);
      }
      expect(
        store
            .profileScopedPreferenceKeys('3f2a9c1e-7d4b-4e21-9a0f-5c6d7e8f9a0b')
            .intersection(keys.toSet()),
        isEmpty,
      );
      expect(store.prefs.getString('oc.effectsMotion'), 'calm');
    });

    test('an unknown stored motion reads as Full', () async {
      final (controller, store) = await _controller({
        'oc.effectsMotion': 'wobbly',
      });
      addTearDown(controller.dispose);
      expect(store.effects.motion, KitMotionLevel.full);
    });
  });

  group('the Effects section', () {
    testWidgets('shows the four choices, with glass honest about the phone', (
      tester,
    ) async {
      final (controller, _) = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_page(controller));
      await tester.pumpAndSettle();

      await _show(tester, find.text('Glass effects'));
      // flutter_tester's renderer cannot run the shader: frosted, said so.
      expect(find.text('Uses a frosted surface on this phone'), findsOneWidget);
      await _show(tester, find.text('Animations'));
      expect(
        find.text('Drawings move and waiting screens breathe'),
        findsOneWidget,
      );
      await _show(tester, find.text('Vibration'));
      expect(find.text('Celebrations'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says once when glass was turned off after crashes, and '
        'turning it back on clears that', (tester) async {
      final (controller, _) = await _controller();
      addTearDown(controller.dispose);
      addTearDown(KitGlassSafety.debugReset);
      await tester.pumpWidget(_page(controller));
      await tester.pumpAndSettle();
      expect(find.textContaining('Liquid glass was turned off'), findsNothing);

      KitGlassSafety.turnedOffAfterCrashes.value = true;
      await tester.pumpAndSettle();
      await _show(tester, find.textContaining('Liquid glass was turned off'));
      expect(
        find.text(
          'Liquid glass was turned off after the app closed unexpectedly twice.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Turn it back on'));
      await tester.pumpAndSettle();
      expect(KitGlassSafety.turnedOffAfterCrashes.value, isFalse);
      expect(find.textContaining('Liquid glass was turned off'), findsNothing);
    });

    testWidgets('glass off turns the glass solid and is saved', (tester) async {
      final (controller, store) = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_page(controller));
      await tester.pumpAndSettle();
      final preview = find.byKey(const ValueKey('effects-preview-glass'));
      await _show(tester, preview);
      expect(
        KitGlass.lookOf(
          tester.element(find.byKey(const ValueKey('effects-preview-glass'))),
        ),
        KitGlassLook.frosted,
      );
      expect(
        find.descendant(of: preview, matching: find.byType(BackdropFilter)),
        findsOneWidget,
      );

      await _show(tester, find.text('Glass effects'));
      await tester.tap(find.text('Glass effects'));
      await tester.pumpAndSettle();

      expect(controller.effects.value.glass, isFalse);
      expect(store.prefs.getBool('oc.effectsGlass'), isFalse);
      await _show(tester, preview);
      expect(
        find.descendant(of: preview, matching: find.byType(BackdropFilter)),
        findsNothing,
      );
    });

    testWidgets('Animations: Calm and Off are chosen and saved', (
      tester,
    ) async {
      final (controller, store) = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_page(controller));
      await tester.pumpAndSettle();

      await _show(tester, find.text('Calm'));
      await tester.tap(find.text('Calm'));
      await tester.pumpAndSettle();
      expect(controller.effects.value.motion, KitMotionLevel.calm);
      expect(store.prefs.getString('oc.effectsMotion'), 'calm');
      expect(
        find.text('Drawings appear, nothing keeps moving'),
        findsOneWidget,
      );

      await tester.tap(find.text('Off'));
      await tester.pumpAndSettle();
      expect(controller.effects.value.motion, KitMotionLevel.off);
      expect(find.text('Everything shows at once'), findsOneWidget);
    });

    testWidgets('Celebrations and Vibration switch off and are saved', (
      tester,
    ) async {
      final (controller, store) = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_page(controller));
      await tester.pumpAndSettle();

      await _show(tester, find.text('Celebrations'));
      await tester.tap(find.text('Celebrations'));
      await tester.pumpAndSettle();
      await _show(tester, find.text('Vibration'));
      await tester.tap(find.text('Vibration'));
      await tester.pumpAndSettle();
      expect(controller.effects.value.celebrations, isFalse);
      expect(controller.effects.value.haptics, isFalse);
      expect(store.prefs.getBool('oc.effectsCelebrations'), isFalse);
      expect(store.prefs.getBool('oc.effectsHaptics'), isFalse);
    });

    testWidgets('the system Remove animations wins and the page says so', (
      tester,
    ) async {
      final (controller, _) = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_page(controller, reduce: true));
      await tester.pumpAndSettle();
      await _show(tester, find.text('Animations'));
      expect(
        find.textContaining('Remove animations is on, so nothing moves'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Solid while high contrast, a screen reader or Remove animations is on',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a refused save puts the choice back and says so', (
      tester,
    ) async {
      final (controller, store) = await _controller();
      addTearDown(controller.dispose);
      store.refuseEffects = true;
      await tester.pumpWidget(_page(controller));
      await tester.pumpAndSettle();
      await _show(tester, find.text('Glass effects'));
      await tester.tap(find.text('Glass effects'));
      await tester.pumpAndSettle();
      expect(controller.effects.value.glass, isTrue);
      expect(
        find.text('Could not save this choice on this device. Try again.'),
        findsOneWidget,
      );
    });
  });

  group('the app obeys the stored choice', () {
    Widget app(ConnectionController controller) => ProviderScope(
      overrides: [
        bootstrapProvider.overrideWithValue(AppBootstrap(controller.store)),
        connProvider.overrideWithValue(controller),
      ],
      child: OcApp(updateService: _NoUpdateService()),
    );

    BuildContext underNavigator(WidgetTester tester) =>
        tester.element(find.byType(Scaffold).first);

    testWidgets('every route reads the choices and follows a change', (
      tester,
    ) async {
      KitMotion.loops = true;
      final (controller, _) = await _controller({
        'oc.effectsMotion': 'calm',
        'oc.effectsHaptics': false,
      });
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller));
      await tester.pump();

      var context = underNavigator(tester);
      expect(KitEffects.of(context).motion, KitMotionLevel.calm);
      // Calm: drawings still draw in, nothing loops.
      expect(KitMotion.loopsIn(context), isFalse);
      expect(KitMotion.reduced(context), isFalse);
      expect(KitHaptics.enabled, isFalse);

      await controller.setEffects(
        const KitEffects(motion: KitMotionLevel.full),
      );
      await tester.pump();
      context = underNavigator(tester);
      expect(KitMotion.loopsIn(context), isTrue);
      expect(KitHaptics.enabled, isTrue);

      await controller.setEffects(const KitEffects(motion: KitMotionLevel.off));
      await tester.pump();
      // Off: every drawing shows its finished frame, pages change at once.
      expect(KitMotion.reduced(underNavigator(tester)), isTrue);
    });

    testWidgets('Vibration off never reaches the platform', (tester) async {
      final calls = _recordHaptics(tester);
      final (controller, _) = await _controller();
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller));
      await tester.pump();

      KitHaptics.send();
      KitHaptics.send(underNavigator(tester));
      expect(calls, hasLength(2));

      await controller.setEffects(const KitEffects(haptics: false));
      await tester.pump();
      KitHaptics.send();
      KitHaptics.send(underNavigator(tester));
      KitHaptics.done(underNavigator(tester));
      expect(calls, hasLength(2));
    });

    testWidgets('glass off: glass anywhere in the app is solid', (
      tester,
    ) async {
      final (controller, _) = await _controller({'oc.effectsGlass': false});
      addTearDown(controller.dispose);
      await tester.pumpWidget(app(controller));
      await tester.pump();
      expect(KitGlass.lookOf(underNavigator(tester)), KitGlassLook.solid);
      await controller.setEffects(KitEffects.defaults);
      await tester.pump();
      expect(KitGlass.lookOf(underNavigator(tester)), KitGlassLook.frosted);
    });
  });
}
