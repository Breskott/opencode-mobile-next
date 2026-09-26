// KitGlass (design standard §10, glass): which look it takes, that it stays
// bounded, that it shares a backdrop read, and — under Impeller only — that
// the liquid shader follows the glass. flutter_tester's default Skia cannot
// run a backdrop shader, so the liquid group runs with:
//   flutter test --enable-impeller test/kit_glass_test.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/glass/liquid_glass_filter.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

Widget _app(Widget child, {KitEffects effects = KitEffects.defaults}) =>
    MaterialApp(
      theme: AppTheme.dark(),
      home: KitEffectsScope(
        effects: effects,
        child: Scaffold(body: Center(child: child)),
      ),
    );

const _glass = SizedBox(
  width: 320,
  height: 72,
  child: KitGlass(child: Text('Workspace')),
);

Iterable<BoxDecoration> _fills(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(
        of: find.byType(KitGlass),
        matching: find.byType(DecoratedBox),
      ),
    )
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .where((box) => box.color != null);

KitGlassLook _look(WidgetTester tester) =>
    KitGlass.lookOf(tester.element(find.text('Workspace')));

void main() {
  tearDown(KitGlassShader.debugReset);

  group('where the phone cannot run the shader', () {
    testWidgets('glass is the frosted blur, clipped to its rounded shape', (
      tester,
    ) async {
      KitGlassShader.debugSupportedOverride = false;
      await tester.pumpWidget(_app(_glass));
      expect(_look(tester), KitGlassLook.frosted);
      expect(find.byType(LiquidGlassFilter), findsNothing);
      final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(filter.filter, isA<ui.ImageFilter>());
      expect(
        find.ancestor(
          of: find.byType(BackdropFilter),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
      );
      // Bounded: the filter covers the glass and nothing more.
      expect(
        tester.getRect(find.byType(BackdropFilter)),
        tester.getRect(find.byType(KitGlass)),
      );
      expect(_fills(tester).single.color!.a, lessThan(1));
      // Nothing was loaded for a renderer that cannot use it.
      expect(KitGlassShader.program.value, isNull);
    });

    testWidgets('under the default test renderer the shader is unsupported', (
      tester,
    ) async {
      // The engine's own answer (no override): Skia in flutter_tester.
      expect(KitGlassShader.supported, ui.ImageFilter.isShaderFilterSupported);
      await tester.pumpWidget(_app(_glass));
      if (!ui.ImageFilter.isShaderFilterSupported) {
        expect(_look(tester), KitGlassLook.frosted);
      }
    });
  });

  group('solid', () {
    testWidgets('glass turned off in Settings is a solid surface', (
      tester,
    ) async {
      KitGlassShader.debugSupportedOverride = false;
      await tester.pumpWidget(
        _app(_glass, effects: const KitEffects(glass: false)),
      );
      expect(_look(tester), KitGlassLook.solid);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(LiquidGlassFilter), findsNothing);
      // Visual language §6: glass off is a solid surface2 at 94 %.
      expect(_fills(tester).single.color!.a, closeTo(.94, .001));
    });

    for (final media in <String, MediaQueryData>{
      'high contrast': const MediaQueryData(highContrast: true),
      'accessible navigation': const MediaQueryData(accessibleNavigation: true),
      'remove animations': const MediaQueryData(disableAnimations: true),
    }.entries) {
      testWidgets('${media.key} makes even liquid-capable glass solid', (
        tester,
      ) async {
        // A phone that could draw liquid glass, shader loaded.
        KitGlassShader.debugSupportedOverride = true;
        KitGlassShader.program.value = await tester.runAsync(
          () => ui.FragmentProgram.fromAsset(KitGlassShader.asset),
        );
        late KitGlassLook look;
        await tester.pumpWidget(
          _app(
            MediaQuery(
              data: media.value,
              child: Builder(
                builder: (context) {
                  look = KitGlass.lookOf(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        );
        expect(look, KitGlassLook.solid);
      });
    }
  });

  testWidgets('liquid is chosen once the shader loaded on a capable phone', (
    tester,
  ) async {
    KitGlassShader.debugSupportedOverride = true;
    late KitGlassLook before;
    late KitGlassLook after;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            before = KitGlass.lookOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    // Before the shader arrives the glass is frosted, never blank.
    expect(before, KitGlassLook.frosted);
    KitGlassShader.program.value = await tester.runAsync(
      () => ui.FragmentProgram.fromAsset(KitGlassShader.asset),
    );
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            after = KitGlass.lookOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(after, KitGlassLook.liquid);
  });

  testWidgets('glass under a BackdropGroup shares its backdrop read', (
    tester,
  ) async {
    KitGlassShader.debugSupportedOverride = false;
    await tester.pumpWidget(
      _app(
        BackdropGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              SizedBox(
                width: 200,
                height: 48,
                child: KitGlass(child: Text('a')),
              ),
              SizedBox(
                width: 200,
                height: 48,
                child: KitGlass(child: Text('b')),
              ),
            ],
          ),
        ),
      ),
    );
    final keys = tester
        .widgetList<BackdropFilter>(find.byType(BackdropFilter))
        .map((filter) => filter.backdropGroupKey)
        .toSet();
    expect(keys, hasLength(1));
    expect(keys.single, isNotNull);
  });

  group('liquid (Impeller)', () {
    final impeller = ui.ImageFilter.isShaderFilterSupported;

    Future<void> load(WidgetTester tester) async {
      KitGlassShader.program.value = await tester.runAsync(
        () => ui.FragmentProgram.fromAsset(KitGlassShader.asset),
      );
    }

    testWidgets(
      'the lens is bounded by the clip and placed in physical pixels',
      skip: !impeller,
      (tester) async {
        await load(tester);
        await tester.pumpWidget(_app(_glass));
        expect(_look(tester), KitGlassLook.liquid);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(
          find.ancestor(
            of: find.byType(LiquidGlassFilter),
            matching: find.byType(ClipRRect),
          ),
          findsOneWidget,
        );
        final render = tester.renderObject<RenderLiquidGlass>(
          find.byType(LiquidGlassFilter),
        );
        final logical = tester.getRect(find.byType(KitGlass));
        final dpr = tester.view.devicePixelRatio;
        expect(render.debugBackdropRect, logical.shift(Offset.zero) * dpr);
        // The shader lays the tint; the child has no fill of its own.
        expect(_fills(tester), isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'the lens follows glass that moves without repainting',
      skip: !impeller,
      (tester) async {
        await load(tester);
        Widget at(double dx) => _app(
          Transform.translate(
            offset: Offset(dx, 0),
            child: const RepaintBoundary(child: _glass),
          ),
        );
        await tester.pumpWidget(at(0));
        final render = tester.renderObject<RenderLiquidGlass>(
          find.byType(LiquidGlassFilter),
        );
        final start = render.debugBackdropRect!;
        await tester.pumpWidget(at(30));
        // One frame to notice, one to repaint.
        await tester.pump();
        final dpr = tester.view.devicePixelRatio;
        expect(render.debugBackdropRect, start.shift(Offset(30 * dpr, 0)));
        // The watch after each frame never asks for frames of its own: the
        // screen settles (pumpAndSettle would time out otherwise).
        await tester.pumpAndSettle();
        expect(render.debugBackdropRect, start.shift(Offset(30 * dpr, 0)));
      },
    );
  });
}

extension on Rect {
  Rect operator *(double factor) => Rect.fromLTRB(
    left * factor,
    top * factor,
    right * factor,
    bottom * factor,
  );
}
