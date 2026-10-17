// The industrial live looks: visible, under their ceiling, deterministic and
// alive, plus one golden per look.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/kit_live_styles_industrial_test.dart
// and look at every changed image before committing it.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/kit/live_background/styles/kit_live_matrix_rain.dart';

import 'goldens/kit/kit_gallery.dart';

const _ids = [
  'matrixRain',
  'blueprint',
  'circuit',
  'oscilloscope',
  'radar',
  'honeycomb',
  'brushedMetal',
  'silk',
  'caustics',
  'bokeh',
];

const _phone = Size(412, 915);
const _wide = Size(1280, 800);
const _t = 7.3;

Future<KitLivePalette> _palette(WidgetTester tester, bool dark) async {
  late KitLivePalette palette;
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: Builder(
        builder: (context) {
          palette = KitLiveBackground.paletteOf(KitTokens.of(context));
          return const SizedBox();
        },
      ),
    ),
  );
  return palette;
}

/// Paints [style] over its ground and returns RGBA bytes.
Future<Uint8List> _render(
  WidgetTester tester,
  KitLiveStyle style,
  Size size,
  KitLivePalette p, {
  double running = 0,
  double strength = 1,
  double t = _t,
  KitLiveMemory? memory,
}) async {
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec);
  canvas.drawRect(Offset.zero & size, Paint()..color = p.ground);
  style.paint(
    canvas,
    size,
    KitLiveFrame(
      t: t,
      running: running,
      strength: strength,
      palette: p,
      memory: memory ?? KitLiveMemory(),
    ),
  );
  final pic = rec.endRecording();
  final bytes = await tester.runAsync(() async {
    final img = await pic.toImage(size.width.round(), size.height.round());
    final data = await img.toByteData();
    img.dispose();
    return data!.buffer.asUint8List();
  });
  pic.dispose();
  return bytes!;
}

int _maxDelta(Uint8List px, Color ground) {
  final g = [ground.r, ground.g, ground.b].map((v) => (v * 255).round());
  final gl = g.toList();
  var worst = 0;
  for (var i = 0; i < px.length; i += 4) {
    for (var c = 0; c < 3; c++) {
      final d = (px[i + c] - gl[c]).abs();
      if (d > worst) worst = d;
    }
  }
  return worst;
}

/// The registered style; matrix rain with the ASCII glyph set so the
/// pictures do not depend on a system CJK font.
KitLiveStyle _style(String id) => id == 'matrixRain'
    ? const KitLiveMatrixRain(glyphs: KitLiveMatrixRain.asciiGlyphs)
    : kitLiveStyles.firstWhere((s) => s.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadKitGalleryFonts();
    final loader = FontLoader('AppMono')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/geist/GeistMono-Variable.ttf').readAsBytesSync(),
          ),
        ),
      );
    await loader.load();
  });

  test('the ten styles are registered after the existing ones, by id', () {
    final ids = kitLiveStyles.map((s) => s.id).toList();
    expect(ids.sublist(ids.length - 10), _ids);
    expect(ids.toSet().length, ids.length);
  });

  for (final id in _ids) {
    final style = _style(id);
    for (final dark in [true, false]) {
      final mode = dark ? 'dark' : 'light';
      testWidgets('$id paints at both sizes, idle and running, $mode', (
        tester,
      ) async {
        final p = await _palette(tester, dark);
        final cap = (p.ceiling * style.ceilingFactor * 255).ceil();
        for (final size in [_phone, _wide]) {
          for (final run in [0.0, 1.0]) {
            final px = await _render(tester, style, size, p, running: run);
            final worst = _maxDelta(px, p.ground);
            expect(worst, greaterThan(0), reason: '$id is visible');
            expect(
              worst,
              lessThanOrEqualTo(cap + 2),
              reason: '$id $mode $size run=$run over the ceiling ($cap)',
            );
          }
        }
      });

      testWidgets('$id is deterministic and moves with time, $mode', (
        tester,
      ) async {
        final p = await _palette(tester, dark);
        final a = await _render(tester, style, _phone, p);
        final b = await _render(tester, style, _phone, p);
        expect(listEquals(a, b), isTrue, reason: 'same t, same picture');
        final c = await _render(tester, style, _phone, p, t: _t + 3);
        expect(listEquals(a, c), isFalse, reason: 'it is alive');
      });
    }

    testWidgets('$id golden, dark, phone', (tester) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final p = await _palette(tester, true);
      final mem = KitLiveMemory();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            child: CustomPaint(
              size: _phone,
              painter: _Painter(style, p, mem, boost: 1),
            ),
          ),
        ),
      );
      try {
        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile(
            'goldens/live_styles/kit_live_${id.toLowerCase()}_dark.png',
          ),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  for (final id in ['circuit', 'honeycomb']) {
    testWidgets('$id golden, light, phone', (tester) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final style = _style(id);
      final p = await _palette(tester, false);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            child: CustomPaint(
              size: _phone,
              painter: _Painter(style, p, KitLiveMemory(), boost: 1),
            ),
          ),
        ),
      );
      try {
        await expectLater(
          find.byType(RepaintBoundary).first,
          matchesGoldenFile(
            'goldens/live_styles/kit_live_${id.toLowerCase()}_light.png',
          ),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}

class _Painter extends CustomPainter {
  _Painter(this.style, this.p, this.mem, {required this.boost});
  final KitLiveStyle style;
  final KitLivePalette p;
  final KitLiveMemory mem;
  final double boost;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = p.ground);
    style.paint(
      canvas,
      size,
      KitLiveFrame(t: _t, running: 0, strength: boost, palette: p, memory: mem),
    );
  }

  @override
  bool shouldRepaint(_Painter old) => true;
}
