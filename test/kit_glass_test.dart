// KitGlass (design standard §10, glass): which look it takes, that it stays
// bounded, that it shares a backdrop read, and — under Impeller only — that
// the liquid shader follows the glass. flutter_tester's default Skia cannot
// run a backdrop shader, so the liquid group runs with:
//   flutter test --enable-impeller test/kit_glass_test.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
          matching: find.byWidgetPredicate((w) => w is ClipRRect),
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

  group('rim, shadow and corners come from the theme', () {
    // Unmistakable roles, so the pixels say where each came from.
    const rimLight = Color(0xFFFF0000);
    const rimDark = Color(0xFF0000FF);
    const shadow = Color(0x8000FF00);
    final theme = AppTheme.fromRoles(
      graphiteDark.copyWith(
        glassRimLight: rimLight,
        glassRimDark: rimDark,
        glassShadow: shadow,
      ),
    );
    const boundary = ValueKey('glass-boundary');

    Future<void> pumpGlass(WidgetTester tester) async {
      KitGlassShader.debugSupportedOverride = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Center(
              child: RepaintBoundary(key: boundary, child: _glass),
            ),
          ),
        ),
      );
      expect(_look(tester), KitGlassLook.frosted);
    }

    testWidgets('the one shadow is the glassShadow role, tight, only '
        'outside the glass', (tester) async {
      // Build 2057 (owner, light theme): a wide grey halo round the glass
      // and a grey ledge inside its bottom edge, where the glass read its
      // own shadow from the backdrop.
      KitGlassShader.debugSupportedOverride = false;
      const shot = ValueKey('shadow-shot');
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: shot,
                child: ColoredBox(
                  color: const Color(0xFFFFFFFF),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: _glass,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final tokens = theme.extension<KitTokens>()!;
      final spec = tokens.glassShadows.single;
      expect(spec.color, shadow);
      expect(spec.offset, const Offset(0, 6));
      expect(spec.blurRadius, 16);
      final dpr = tester.view.devicePixelRatio;
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(shot),
      );
      final image = (await tester.runAsync(
        () => render.toImage(pixelRatio: dpr),
      ))!;
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      // How green (the shadow role) a logical point is: green over red.
      int green(double x, double y) {
        final i = ((y * dpr).round() * image.width + (x * dpr).round()) * 4;
        return bytes.getUint8(i + 1) - bytes.getUint8(i);
      }

      const middle = 32 + 160.0;
      // Below the glass: the shadow.
      expect(green(middle, 32 + 72 + 4), greaterThan(12));
      // Just above it: no halo (this test's shadow is 50 % green, stronger
      // than the real 30 % black; what is left here is under 1 % there).
      expect(green(middle, 32 - 2), lessThan(6));
      // Inside, by the bottom edge: no ledge (the glass never reads its
      // own shadow).
      expect(green(middle, 32 + 72 - 3), lessThan(4));
      image.dispose();
    });

    testWidgets('the glass sits on physical pixels wherever it is laid out', (
      tester,
    ) async {
      // §7: a half-pixel offset is a bug. The glass may be laid out at any
      // fraction (a centred pill, text-sized pieces); its edges still land
      // on the pixel grid, so the one-physical-pixel rim is crisp.
      KitGlassShader.debugSupportedOverride = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.fromLTRB(10.1, 7.37, 0, 0),
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 200.45,
                  height: 47.9,
                  child: KitGlass(child: Text('Laptop')),
                ),
              ),
            ),
          ),
        ),
      );
      final dpr = tester.view.devicePixelRatio;
      final clip = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(KitGlass),
          matching: find.byWidgetPredicate((w) => w is ClipRRect),
        ),
      );
      final clipper = tester
          .widget<ClipRRect>(
            find.descendant(
              of: find.byType(KitGlass),
              matching: find.byWidgetPredicate((w) => w is ClipRRect),
            ),
          )
          .clipper!;
      final drawn = clipper.getClip(clip.size);
      final origin = clip.localToGlobal(Offset.zero);
      for (final edge in [
        origin.dx + drawn.left,
        origin.dy + drawn.top,
        origin.dx + drawn.right,
        origin.dy + drawn.bottom,
      ]) {
        final physical = edge * dpr;
        expect(physical, closeTo(physical.roundToDouble(), 1e-6));
      }
    });

    testWidgets('the corners default to the floating tab bar token', (
      tester,
    ) async {
      await pumpGlass(tester);
      final clip = tester.widget<ClipRRect>(
        find.descendant(
          of: find.byType(KitGlass),
          matching: find.byWidgetPredicate((w) => w is ClipRRect),
        ),
      );
      final tokens = theme.extension<KitTokens>()!;
      expect(clip.borderRadius, BorderRadius.circular(tokens.navRadius));
    });

    testWidgets('the rim paints glassRimLight on top, glassRimDark below', (
      tester,
    ) async {
      await pumpGlass(tester);
      final dpr = tester.view.devicePixelRatio;
      final render = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundary),
      );
      final image = (await tester.runAsync(
        () => render.toImage(pixelRatio: dpr),
      ))!;
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      ({int r, int g, int b}) pixel(int x, int y) {
        final i = (y * image.width + x) * 4;
        return (
          r: bytes.getUint8(i),
          g: bytes.getUint8(i + 1),
          b: bytes.getUint8(i + 2),
        );
      }

      final middle = image.width ~/ 2;
      final top = pixel(middle, 0);
      final bottom = pixel(middle, image.height - 1);
      // One physical pixel of rim at each edge: red above, blue below.
      expect(top.r, greaterThan(top.b + 60), reason: 'top $top');
      expect(bottom.b, greaterThan(bottom.r + 60), reason: 'bottom $bottom');
      // Crisp (LOOK-21): the next physical row in is no longer the rim.
      final inside = pixel(middle, 2);
      expect(inside.r, lessThan(top.r), reason: 'inside $inside');
      image.dispose();
    });
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
            matching: find.byWidgetPredicate((w) => w is ClipRRect),
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
