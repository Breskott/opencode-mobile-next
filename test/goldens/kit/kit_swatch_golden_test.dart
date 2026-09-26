// Gallery (gate G4) for KitSwatch, KitSwatchGrid and KitThemePreview,
// docs/ux-system/kit-api/KitSwatch.md "Galleries required" and kit-v2.md
// §8.4: DPR 3, Android.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_swatch_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_swatch.dart';
import 'package:opencode_mobile/ui/theme_packs.dart';

import 'kit_gallery.dart';

/// The 8-pack grid the spec asks for: Graphite selected, Material You
/// unavailable (no palette below Android 12), the rest available.
Widget _grid({bool focusedFirst = false}) => KitSwatchGrid(
  label: 'Theme',
  children: [
    for (final id in const [
      ThemePackId.opencode,
      ThemePackId.dynamic,
      ThemePackId.catppuccin,
      ThemePackId.gruvbox,
      ThemePackId.solarized,
      ThemePackId.dracula,
      ThemePackId.nord,
      ThemePackId.tokyoNight,
    ])
      if (id == ThemePackId.dynamic)
        KitSwatch(
          swatchKey: ValueKey('theme-pack-${id.name}'),
          roles: null,
          label: themePackLabels[id]!,
          selected: false,
          onPressed: null,
          disabledReason: 'Needs Android 12 or later',
        )
      else
        KitSwatch(
          swatchKey: ValueKey('theme-pack-${id.name}'),
          roles: themePack(id).dark.themeRoles,
          label: themePackLabels[id]!,
          selected: id == ThemePackId.opencode,
          onPressed: () {},
        ),
  ],
);

/// The 3 guarded Graphite accents (`graphiteAccents`, minus the default
/// green already shown by the grid above): blue selected.
Widget _accentGrid() => KitSwatchGrid(
  label: 'Accent colour',
  children: [
    for (final accent in graphiteAccents)
      KitSwatch.accent(
        swatchKey: ValueKey('accent-${accent.name}'),
        color: accent.dark,
        label: accent.name,
        selected: accent.name == 'blue',
        onPressed: () {},
      ),
  ],
);

Widget _previewGraphite() => const KitThemePreview(
  previewKey: ValueKey('kit-theme-preview'),
  roles: graphiteLight,
  label: 'Preview of Graphite',
);

Widget _previewCatppuccin() => KitThemePreview(
  previewKey: const ValueKey('kit-theme-preview'),
  roles: themePack(ThemePackId.catppuccin).dark.themeRoles,
  label: 'Preview of Catppuccin',
);

/// [kitGalleryPart], but Tab is pressed once after the tree settles and
/// before the shot is taken — for the one state (`grid_focused`) that needs
/// a real keyboard focus ring, which [kitGalleryPart] itself has no hook
/// for. Deliberately minimal (no Arabic font fallback, not needed here):
/// `kit_gallery.dart` stays untouched (PROC-13).
Future<void> _focusedGridShot(
  WidgetTester tester, {
  required String name,
  required Size size,
  required bool light,
}) async {
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final semantics = tester.ensureSemantics();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: light ? AppTheme.light() : AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _grid(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The grid's own roving tabindex: Tab lands on the selected swatch.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectKitGalleryAccessible(
      tester,
      shot: name,
      direction: TextDirection.ltr,
    );
  } finally {
    debugDefaultTargetPlatformOverride = null;
    semantics.dispose();
  }
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  // ── Declared states × dark and light at 412×915 (10 PNGs).
  const declared = <String, Widget Function()>{
    'grid': _grid,
    'accent': _accentGrid,
    'preview_graphite': _previewGraphite,
    'preview_catppuccin': _previewCatppuccin,
  };

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final MapEntry(key: state, value: build) in declared.entries) {
      testWidgets('kit_swatch $state · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_swatch_$state',
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          child: build(),
        );
      });
    }

    testWidgets('kit_swatch grid_focused · $mode', (tester) async {
      await _focusedGridShot(
        tester,
        name: kitGalleryName(
          'kit_swatch_grid_focused',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
      );
    });
  }

  // ── Default (`grid`) × dark and light at the other LAY-4 sizes (10 PNGs).
  const otherSizes = [
    Size(360, 800),
    Size(915, 412),
    Size(800, 1280),
    Size(1280, 800),
    Size(1600, 1000),
  ];
  for (final light in [false, true]) {
    for (final size in otherSizes) {
      testWidgets(
        'kit_swatch grid · ${kitGallerySize(size)} · ${light ? 'light' : 'dark'}',
        (tester) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName('kit_swatch_grid', size, light: light),
            size: size,
            light: light,
            child: _grid(),
          );
        },
      );
    }
  }

  // ── Text 2.0 and Arabic (`grid`, `preview_graphite`) at 412×915 and
  // 1280×800, dark (8 PNGs).
  const scaledScenes = <String, Widget Function()>{
    'grid': _grid,
    'preview_graphite': _previewGraphite,
  };
  for (final MapEntry(key: state, value: build) in scaledScenes.entries) {
    for (final size in kitGalleryScaledSizes) {
      testWidgets('kit_swatch $state text2 · ${kitGallerySize(size)}', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_swatch_$state',
            size,
            light: false,
            text2: true,
          ),
          size: size,
          light: false,
          textScale: 2,
          child: build(),
        );
      });

      testWidgets('kit_swatch $state ar · ${kitGallerySize(size)}', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_swatch_$state',
            size,
            light: false,
            ar: true,
          ),
          size: size,
          light: false,
          locale: const Locale('ar'),
          child: build(),
        );
      });
    }
  }
}
