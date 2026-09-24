import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/connection.dart';
import 'package:opencode_mobile/state/profiles.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/settings_screen.dart';
import 'package:opencode_mobile/ui/theme_packs.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ConnectionController> _controller() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  return ConnectionController(ProfileStore(prefs: preferences));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => harvestedDynamicPack.value = null);

  test('the default OpenCode pack preserves identity and semantic colors', () {
    final dark = AppTheme.dark();
    expect(dark.colorScheme.primary, const Color(0xFF83CDAA));
    expect(dark.colorScheme.onPrimary, const Color(0xFF052117));
    expect(dark.colorScheme.surface, const Color(0xFF151A17));
    expect(dark.colorScheme.onSurface, const Color(0xFFE3E8E4));
    expect(dark.colorScheme.surfaceContainerLow, const Color(0xFF171C19));
    expect(dark.colorScheme.error, const Color(0xFFFFB4AB));
    expect(dark.scaffoldBackgroundColor, const Color(0xFF101310));
    expect(AppTheme.successOf(dark), const Color(0xFF86D8A5));

    final light = AppTheme.light();
    expect(light.colorScheme.primary, const Color(0xFF176B4B));
    expect(light.colorScheme.surface, const Color(0xFFFFFFFF));
    expect(light.colorScheme.surfaceContainerLow, const Color(0xFFF0F5F1));
    expect(light.scaffoldBackgroundColor, const Color(0xFFF6F9F6));
    expect(AppTheme.successOf(light), const Color(0xFF1E7A44));
  });

  test('every static pack has complete, distinct dark and light palettes', () {
    for (final id in ThemePackId.values.where(
      (id) => id != ThemePackId.dynamic,
    )) {
      final pack = themePack(id);
      expect(pack.dark.scheme.brightness, Brightness.dark, reason: '$id');
      expect(pack.light.scheme.brightness, Brightness.light, reason: '$id');
      expect(pack.dark.background, isNot(pack.light.background), reason: '$id');
      // Pack-owned success reaches the ThemeData extension.
      expect(
        AppTheme.successOf(AppTheme.dark(pack)),
        pack.dark.success,
        reason: '$id',
      );
    }
  });

  test('every theme keeps text and controls readable in both modes', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + .05) / (lo + .05);
    }

    final failures = <String>[];
    void floor(String what, Color fg, Color bg, double min) {
      final ratio = contrast(fg, bg);
      if (ratio < min) {
        failures.add('$what ${ratio.toStringAsFixed(2)} < $min');
      }
    }

    // The generated themes. The four hand-written packs keep their authors'
    // exact colours (Solarized's famous low contrast included) and have
    // goldens instead.
    for (final id in ThemePackId.values.where(
      (id) => id != ThemePackId.dynamic && !curatedThemePacks.contains(id),
    )) {
      for (final brightness in Brightness.values) {
        final palette = themePack(id).palette(brightness);
        final s = palette.scheme;
        final tag = '${id.name}/${brightness.name}';
        // Reading text: WCAG AA. On the page and on every surface it sits on.
        for (final surface in [
          palette.background,
          s.surface,
          s.surfaceContainer,
          s.surfaceContainerHigh,
        ]) {
          floor('$tag text', s.onSurface, surface, 4.5);
          floor('$tag muted text', s.onSurfaceVariant, surface, 4.5);
        }
        floor('$tag on primary', s.onPrimary, s.primary, 4.5);
        floor(
          '$tag on primary container',
          s.onPrimaryContainer,
          s.primaryContainer,
          4.5,
        );
        floor(
          '$tag on secondary container',
          s.onSecondaryContainer,
          s.secondaryContainer,
          4.5,
        );
        floor(
          '$tag on error container',
          s.onErrorContainer,
          s.errorContainer,
          4.5,
        );
        // Things recognised by colour (accent, status): the 3:1 of
        // non-text contrast.
        floor('$tag accent', s.primary, palette.background, 3);
        floor('$tag error', s.error, palette.background, 3);
        floor('$tag success', palette.success, palette.background, 3);
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('a stored theme from before the new ones still loads', () {
    // Stored by name, so adding packs in the middle of the enum is safe.
    expect(ThemePackId.values.byName('solarized'), ThemePackId.solarized);
    expect(ThemePackId.values.last, ThemePackId.dynamic);
    expect(ThemePackId.values.length, greaterThan(25));
    expect(themePackLabels.keys.toSet(), ThemePackId.values.toSet());
  });

  test('theme pack persistence round-trips through the store', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = ProfileStore(prefs: preferences);
    expect(store.themePack, ThemePackId.opencode);
    await store.setThemePack(ThemePackId.gruvbox);
    expect(ProfileStore(prefs: preferences).themePack, ThemePackId.gruvbox);
  });

  testWidgets('switching packs restyles the app live', (tester) async {
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ListenableBuilder(
        listenable: Listenable.merge([
          controller.themePack,
          harvestedDynamicPack,
        ]),
        builder: (context, _) {
          final pack = effectiveThemePack(controller.themePack.value);
          return MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            themeMode: ThemeMode.dark,
            theme: AppTheme.light(pack),
            darkTheme: AppTheme.dark(pack),
            home: const Scaffold(body: Text('themed')),
          );
        },
      ),
    );
    BuildContext context = tester.element(find.text('themed'));
    expect(Theme.of(context).colorScheme.primary, const Color(0xFF83CDAA));

    await controller.setThemePack(ThemePackId.gruvbox);
    await tester.pumpAndSettle();
    context = tester.element(find.text('themed'));
    expect(Theme.of(context).colorScheme.primary, const Color(0xFFFE8019));
    expect(AppTheme.successOf(Theme.of(context)), const Color(0xFFB8BB26));
  });

  testWidgets('the appearance page picks packs and gates Material You', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await _controller();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AppearanceSettingsScreen(controller: controller),
      ),
    );
    await tester.pump();

    // Unharvested Material You stays visible but disabled with truth.
    final dynamicTile = find.byKey(const ValueKey('theme-pack-dynamic'));
    await tester.dragUntilVisible(
      dynamicTile,
      find.byType(ListView),
      const Offset(0, -120),
    );
    expect(
      find.text('Material You colors are not available on this device.'),
      findsOneWidget,
    );
    await tester.tap(dynamicTile, warnIfMissed: false);
    await tester.pump();
    expect(controller.themePack.value, ThemePackId.opencode);

    final solarized = find.byKey(const ValueKey('theme-pack-solarized'));
    await tester.dragUntilVisible(
      solarized,
      find.byType(ListView),
      const Offset(0, -120),
    );
    // Centre the tile: at 2x its centre can still sit below the fold.
    await Scrollable.ensureVisible(tester.element(solarized), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(solarized);
    await tester.pumpAndSettle();
    expect(controller.themePack.value, ThemePackId.opencode);
    await tester.scrollUntilVisible(
      find.text('Apply'),
      160,
      scrollable: find.descendant(
        of: find.byKey(const Key('appearance-picker')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(controller.themePack.value, ThemePackId.solarized);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a harvested Material You pack becomes selectable', (
    tester,
  ) async {
    final controller = await _controller();
    addTearDown(controller.dispose);
    harvestedDynamicPack.value = dynamicThemePack(
      lightScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      darkScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        home: AppearanceSettingsScreen(controller: controller),
      ),
    );
    await tester.pump();

    final dynamicTile = find.byKey(const ValueKey('theme-pack-dynamic'));
    await tester.dragUntilVisible(
      dynamicTile,
      find.byType(ListView),
      const Offset(0, -120),
    );
    expect(
      find.text('Material You colors are not available on this device.'),
      findsNothing,
    );
    await tester.tap(dynamicTile);
    await tester.pumpAndSettle();
    expect(controller.themePack.value, ThemePackId.opencode);
    await tester.scrollUntilVisible(
      find.text('Apply'),
      160,
      scrollable: find.descendant(
        of: find.byKey(const Key('appearance-picker')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(controller.themePack.value, ThemePackId.dynamic);
  });
}
