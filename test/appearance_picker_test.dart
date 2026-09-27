import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_swatch.dart';
import 'package:opencode_mobile/ui/kit/kit_undo.dart';
import 'package:opencode_mobile/ui/theme_packs.dart';
import 'package:opencode_mobile/ui/widgets/appearance_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _FailingStore extends ProfileStore {
  _FailingStore({required super.prefs});
  bool fail = true;

  @override
  Future<void> setAppearance(AppAppearance appearance) async {
    if (fail) throw StateError('Storage unavailable');
    await super.setAppearance(appearance);
  }

  @override
  Future<void> setThemePack(ThemePackId pack) async {
    if (fail) throw StateError('Storage unavailable');
    await super.setThemePack(pack);
  }
}

class _RefusedPlatformStore extends InMemorySharedPreferencesStore {
  _RefusedPlatformStore(super.data) : super.withData();
  bool fail = true;
  bool throwWrite = false;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (throwWrite) throw StateError('Disk unavailable');
    return fail ? false : super.setValue(type, key, value);
  }
}

Future<void> _open(
  WidgetTester tester,
  ConnectionController controller, {
  required ThemePackId pack,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        // Reduced motion: the preview's working mark holds still (G8).
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => showThemePackPreview(
              context,
              controller: controller,
              pack: pack,
            ),
            child: const Text('Open appearance'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open appearance'));
  await tester.pumpAndSettle();
}

Finder get _scrollable => find
    .descendant(
      of: find.byKey(const Key('appearance-picker')),
      matching: find.byType(Scrollable),
    )
    .first;

/// Scrolls [finder] into view and then centres it: at 2.5x a single tile can
/// be taller than half the sheet, and a tap lands on its centre.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 160, scrollable: _scrollable);
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'oc.appearance': 'system'});
    harvestedDynamicPack.value = null;
  });

  for (final throws in [false, true]) {
    test(
      'refused display preference restores the cache (throws=$throws)',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final disk = _RefusedPlatformStore(
          await SharedPreferencesStorePlatform.instance.getAll(),
        )..throwWrite = throws;
        SharedPreferencesStorePlatform.instance = disk;
        final controller = ConnectionController(
          ProfileStore(prefs: prefs),
          isIsolated: true,
        );
        addTearDown(controller.dispose);
        await expectLater(
          controller.setAppearance(AppAppearance.dark),
          throwsStateError,
        );
        await expectLater(
          controller.setThemePack(ThemePackId.solarized),
          throwsStateError,
        );
        final restarted = ConnectionController(
          ProfileStore(prefs: prefs),
          isIsolated: true,
        );
        addTearDown(restarted.dispose);
        expect(restarted.appearance.value, AppAppearance.system);
        expect(restarted.themePack.value, ThemePackId.opencode);
        disk.fail = false;
        disk.throwWrite = false;
        await controller.setAppearance(AppAppearance.dark);
        await controller.setThemePack(ThemePackId.solarized);
        expect(controller.store.appearance, AppAppearance.dark);
        expect(controller.store.themePack, ThemePackId.solarized);
      },
    );
  }

  testWidgets(
    'closing a preview discards the draft and previewing light does not apply',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      final controller = ConnectionController(ProfileStore(prefs: preferences));
      addTearDown(controller.dispose);
      await _open(tester, controller, pack: ThemePackId.solarized);
      expect(find.byType(KitThemePreview), findsOneWidget);
      await tester.tap(find.byKey(const Key('appearance-preview-light')));
      await tester.pumpAndSettle();
      expect(controller.themePack.value, ThemePackId.opencode);
      expect(controller.appearance.value, AppAppearance.system);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(preferences.getString('oc.themePack'), isNull);
      expect(controller.themePack.value, ThemePackId.opencode);
    },
  );

  testWidgets('a failed theme save keeps the current theme and supports retry', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final store = _FailingStore(prefs: prefs);
    final controller = ConnectionController(store);
    addTearDown(controller.dispose);
    await _open(tester, controller, pack: ThemePackId.gruvbox);
    await _reveal(tester, find.text('Apply'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not save the appearance. Your previous setting is unchanged. Try again.',
      ),
      findsOneWidget,
    );
    expect(controller.appearance.value, AppAppearance.system);
    expect(controller.themePack.value, ThemePackId.opencode);
    store.fail = false;
    await _reveal(tester, find.text('Apply'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('appearance-picker')), findsNothing);
    expect(controller.themePack.value, ThemePackId.gruvbox);
    KitUndo.commitPending();
  });

  testWidgets(
    'Material You preview uses the harvested scheme and refuses an unavailable one',
    (tester) async {
      final controller = ConnectionController(
        ProfileStore(prefs: await SharedPreferences.getInstance()),
      );
      addTearDown(controller.dispose);
      await _open(tester, controller, pack: ThemePackId.dynamic);
      // Said once, with nothing to preview or apply (no dead button).
      expect(
        find.text('Material You colors are not available on this device.'),
        findsOneWidget,
      );
      expect(find.byType(KitThemePreview), findsNothing);
      expect(find.text('Apply'), findsNothing);
      expect(controller.themePack.value, ThemePackId.opencode);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
      harvestedDynamicPack.value = dynamicThemePack(
        lightScheme: scheme,
        darkScheme: scheme.copyWith(brightness: Brightness.dark),
      );
      await _open(tester, controller, pack: ThemePackId.dynamic);
      final preview = tester.widget<KitThemePreview>(
        find.byType(KitThemePreview),
      );
      expect(
        preview.roles.accent,
        harvestedDynamicPack.value!.light.themeRoles.accent,
      );
      await _reveal(tester, find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(controller.themePack.value, ThemePackId.dynamic);
      harvestedDynamicPack.value = null;
      KitUndo.commitPending();
    },
  );

  for (final direction in TextDirection.values) {
    testWidgets(
      'preview actions remain reachable at 320dp and 2.5x in ${direction.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = ConnectionController(
          ProfileStore(prefs: await SharedPreferences.getInstance()),
        );
        addTearDown(controller.dispose);
        await _open(
          tester,
          controller,
          pack: ThemePackId.solarized,
          scale: 2.5,
          direction: direction,
        );
        await _reveal(tester, find.byKey(const Key('appearance-preview-dark')));
        await tester.tap(find.byKey(const Key('appearance-preview-dark')));
        await tester.pumpAndSettle();
        await _reveal(tester, find.text('Apply'));
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        // Previewing dark never changes light or dark itself.
        expect(controller.appearance.value, AppAppearance.system);
        expect(controller.themePack.value, ThemePackId.solarized);
        expect(tester.takeException(), isNull);
        KitUndo.commitPending();
      },
    );
  }
}
