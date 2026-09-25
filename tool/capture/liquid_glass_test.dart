// Renders of KitGlass for docs/qa/liquid-glass-2026-09-25: the dock over a
// scrolled list with colour in it, dark and light, in each look (liquid,
// frosted, solid). The liquid look needs Impeller, so run with it:
//
//   flutter test --enable-impeller --concurrency=1 tool/capture/liquid_glass_test.dart
//
// Without --enable-impeller the liquid captures are skipped (flutter_tester's
// Skia cannot run a backdrop shader) and only frosted and solid are written.
// Output: docs/qa/liquid-glass-2026-09-25/renders/<look>-<theme>.png
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/widgets/glass_surface.dart';

import 'fixtures.dart';

const _out = 'docs/qa/liquid-glass-2026-09-25/renders';
const _size = Size(412, 520);

const _swatches = [
  Color(0xFFE5484D),
  Color(0xFFF76B15),
  Color(0xFFFFC53D),
  Color(0xFF30A46C),
  Color(0xFF0090FF),
  Color(0xFF8E4EC6),
];

Widget _scene({required bool light, required KitEffects effects}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: light ? AppTheme.light() : AppTheme.dark(),
    home: KitEffectsScope(
      effects: effects,
      child: Builder(
        builder: (context) => Scaffold(
          extendBody: true,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SectionLabel('Running now'),
              for (var i = 0; i < 9; i++) ...[
                KitRow(
                  title: 'Fix the reconnect loop in the chat · step ${i + 1}',
                  supporting: const TextSpan(
                    text: 'opencode · 2 files changed · a minute ago',
                  ),
                  leading: KitRowIcon(
                    AppIconography.workspace,
                    color: _swatches[i % _swatches.length],
                  ),
                  onTap: () {},
                ),
                if (i % 3 == 1)
                  Container(
                    height: 34,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [
                          _swatches[i % _swatches.length],
                          _swatches[(i + 2) % _swatches.length],
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: GlassSurface(
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  backgroundColor: Colors.transparent,
                  labelTextStyle: WidgetStatePropertyAll(
                    Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: GlassSurface.foregroundColor(Theme.of(context)),
                    ),
                  ),
                  iconTheme: WidgetStatePropertyAll(
                    IconThemeData(
                      color: GlassSurface.foregroundColor(Theme.of(context)),
                    ),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: 0,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(AppIconography.workspace),
                      label: 'Work',
                    ),
                    NavigationDestination(
                      icon: Icon(AppIconography.idea),
                      label: 'Inbox',
                    ),
                    NavigationDestination(
                      icon: Icon(AppIconography.contrast),
                      label: 'Project',
                    ),
                    NavigationDestination(
                      icon: Icon(AppIconography.contrast),
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Close-up: a glass pill over diagonal colour and text, so the bend at the
/// edge and the rim are visible (the dock's own content hides most of it).
Widget _edge({required bool light, required KitEffects effects}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: light ? AppTheme.light() : AppTheme.dark(),
    home: KitEffectsScope(
      effects: effects,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Transform.rotate(
                angle: -.35,
                child: OverflowBox(
                  maxWidth: 900,
                  maxHeight: 900,
                  child: Column(
                    children: [
                      for (var i = 0; i < 30; i++)
                        Container(
                          height: 30,
                          color: i.isEven
                              ? _swatches[(i ~/ 2) % _swatches.length]
                              : Colors.transparent,
                          alignment: Alignment.centerLeft,
                          child: i.isEven
                              ? null
                              : const Text(
                                  '  the quick brown fox jumps over the lazy dog · '
                                  'the quick brown fox jumps over the lazy dog',
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 40,
              right: 40,
              top: 120,
              height: 96,
              child: KitGlass(
                borderRadius: BorderRadius.all(Radius.circular(48)),
                child: SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadCaptureFonts);
  tearDown(KitGlassShader.debugReset);

  for (final look in [KitGlassLook.liquid, KitGlassLook.frosted]) {
    testWidgets(
      'edge-${look.name}',
      skip:
          look == KitGlassLook.liquid &&
          !ui.ImageFilter.isShaderFilterSupported,
      (tester) async {
        tester.view
          ..physicalSize = const Size(412, 340) * captureDevicePixelRatio
          ..devicePixelRatio = captureDevicePixelRatio;
        addTearDown(tester.view.reset);
        if (look == KitGlassLook.liquid) {
          KitGlassShader.program.value = await tester.runAsync(
            () => ui.FragmentProgram.fromAsset(KitGlassShader.asset),
          );
        } else {
          KitGlassShader.debugSupportedOverride = false;
        }
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: _edge(light: false, effects: KitEffects.defaults),
          ),
        );
        await tester.pumpAndSettle();
        await writePng(
          '$_out/edge-${look.name}-dark.png',
          await capturePng(tester, boundary),
        );
      },
    );
  }

  for (final look in KitGlassLook.values) {
    for (final light in [false, true]) {
      final name = '${look.name}-${light ? 'light' : 'dark'}';
      testWidgets(
        name,
        skip:
            look == KitGlassLook.liquid &&
            !ui.ImageFilter.isShaderFilterSupported,
        (tester) async {
          tester.view
            ..physicalSize = _size * captureDevicePixelRatio
            ..devicePixelRatio = captureDevicePixelRatio;
          addTearDown(tester.view.reset);
          if (look == KitGlassLook.liquid) {
            KitGlassShader.program.value = await tester.runAsync(
              () => ui.FragmentProgram.fromAsset(KitGlassShader.asset),
            );
          } else {
            KitGlassShader.debugSupportedOverride = false;
          }
          final boundary = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: _scene(
                light: light,
                effects: KitEffects(glass: look != KitGlassLook.solid),
              ),
            ),
          );
          await tester.pumpAndSettle();
          // Scroll so a gradient bar sits half under the dock's edge.
          await tester.drag(find.byType(ListView), const Offset(0, -120));
          await tester.pumpAndSettle();
          expect(
            KitGlass.lookOf(tester.element(find.byType(NavigationBar))),
            look,
          );
          await writePng('$_out/$name.png', await capturePng(tester, boundary));
        },
      );
    }
  }
}
