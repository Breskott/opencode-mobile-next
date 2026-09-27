import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_effects.dart';
import 'package:opencode_mobile/ui/theme_packs.dart';
import 'package:opencode_mobile/ui/widgets/glass_surface.dart';
import 'package:opencode_mobile/ui/widgets/product_states.dart';

void main() {
  for (final media in <String, MediaQueryData>{
    'high contrast': const MediaQueryData(highContrast: true),
    'accessible navigation': const MediaQueryData(accessibleNavigation: true),
    'reduced motion': const MediaQueryData(disableAnimations: true),
  }.entries) {
    testWidgets(
      '${media.key} uses opaque navigation without decorative depth',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark(),
            home: MediaQuery(
              data: media.value,
              child: const GlassSurface(child: Text('Workspace')),
            ),
          ),
        );
        final decorations = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(GlassSurface),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((widget) => widget.decoration)
            .whereType<BoxDecoration>();
        expect(decorations.where((box) => box.color != null), isNotEmpty);
        for (final box in decorations) {
          if (box.color != null) expect(box.color!.a, 1);
          expect(box.boxShadow ?? [], isEmpty);
        }
        expect(find.text('Workspace'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);
      },
    );
  }

  testWidgets('the dock turned to solid by Settings › Appearance › Glass', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const KitEffectsScope(
          effects: KitEffects(glass: false),
          child: GlassSurface(child: SizedBox(width: 320, height: 72)),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsNothing);
    final fills = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where((box) => box.color != null);
    // Visual language §6: glass off is a solid surface2 at 94 %.
    expect(fills.single.color!.a, closeTo(.94, .001));
  });

  testWidgets('frosted material clips a single backdrop filter', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const GlassSurface(child: SizedBox(width: 320, height: 72)),
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(BackdropFilter),
        matching: find.byType(ClipRRect),
      ),
      findsOneWidget,
    );
    final fills = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where((box) => box.color != null);
    expect(fills.single.color!.a, lessThan(1));
  });

  for (final pack in ThemePackId.values.where(
    (id) => id != ThemePackId.dynamic,
  )) {
    for (final dark in [false, true]) {
      testWidgets(
        'frosted foreground contrast ${pack.name} ${dark ? 'dark' : 'light'}',
        (tester) async {
          final theme = dark
              ? AppTheme.dark(themePack(pack))
              : AppTheme.light(themePack(pack));
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              home: const GlassSurface(child: SizedBox(width: 320, height: 72)),
            ),
          );
          final fill = tester
              .widgetList<DecoratedBox>(
                find.descendant(
                  of: find.byType(GlassSurface),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .map((box) => box.decoration)
              .whereType<BoxDecoration>()
              .singleWhere((box) => box.color != null)
              .color!;
          var minimum = double.infinity;
          for (final r in [0, 64, 128, 192, 255]) {
            for (final g in [0, 64, 128, 192, 255]) {
              for (final b in [0, 64, 128, 192, 255]) {
                final backdrop = Color.fromARGB(255, r, g, b);
                final surface = Color.alphaBlend(fill, backdrop);
                final selected = Color.alphaBlend(
                  theme.navigationBarTheme.indicatorColor!,
                  surface,
                );
                for (final background in [surface, selected]) {
                  final luminances = [
                    GlassSurface.foregroundColor(theme).computeLuminance(),
                    background.computeLuminance(),
                  ]..sort();
                  final contrast =
                      (luminances.last + .05) / (luminances.first + .05);
                  if (contrast < minimum) minimum = contrast;
                }
              }
            }
          }
          debugPrint(
            'Glass contrast ${pack.name} ${dark ? 'dark' : 'light'}: ${minimum.toStringAsFixed(2)}',
          );
          expect(
            minimum,
            greaterThanOrEqualTo(4.5),
            reason:
                'Actual translucent fill and selected indicator over 125 RGB backdrop samples',
          );
        },
      );
    }
  }

  for (final dark in [false, true]) {
    // A failure is a kit alert now, never a snackbar (KIT-34): the alert's
    // own contrast is the kit's (KitDialog galleries); this checks the
    // failure still reaches the person, readable, in both themes.
    testWidgets('an action failure is an alert in ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      final theme = dark ? AppTheme.dark() : AppTheme.light();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showProductError(context, 'Unable to save'),
                child: const Text('Save'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text("Couldn't finish that"), findsOneWidget);
      expect(find.text('Unable to save'), findsOneWidget);
      final body = tester.renderObject<RenderParagraph>(
        find.text('Unable to save'),
      );
      final colour = body.text.style?.color;
      expect(colour, isNotNull);
      final luminances = [
        colour!.computeLuminance(),
        theme.colorScheme.surface.computeLuminance(),
      ]..sort();
      expect(
        (luminances.last + .05) / (luminances.first + .05),
        greaterThan(4.5),
      );
    });
  }
}
