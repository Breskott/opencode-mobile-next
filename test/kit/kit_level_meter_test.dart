// KitLevelMeter (docs/ux-system/kit-api/KitLevelMeter.md "Tests required"):
// the lighting formula, direction, colours, crispness, the .listen
// constructor's repaint-only contract, semantics exclusion, motion and
// overflow.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_level_meter.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

const _key = Key('kit-level-meter-test');

/// Pumps [child] under a real theme (so `KitTokens.of` resolves the same
/// colours the widget paints with) and returns those tokens.
Future<KitTokens> _pump(
  WidgetTester tester,
  Widget child, {
  bool light = false,
  double devicePixelRatio = 1,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  Size size = const Size(200, 100),
}) async {
  tester.view.physicalSize = size * devicePixelRatio;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);
  late KitTokens tokens;
  await tester.pumpWidget(
    MaterialApp(
      theme: light ? AppTheme.light() : AppTheme.dark(),
      builder: (context, widget) => Directionality(
        textDirection: direction,
        child: MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: widget!,
        ),
      ),
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (context) {
              tokens = KitTokens.of(context);
              return child;
            },
          ),
        ),
      ),
    ),
  );
  return tokens;
}

/// The meter's geometry (KitLevelMeter.md "Tokens"), computed the same way
/// as the frozen spec and the pre-wave `_LevelMeter` it replaces
/// (`lib/voice/voice_ui.dart`), independently of the part's own private
/// painter.
class _Geometry {
  _Geometry(this.tokens);

  final KitTokens tokens;

  static const bars = KitTokens.meterBars;

  /// One `12.0 + (index - 4).abs() * 2` per bar (the "V"), read off
  /// directly rather than re-derived, so a formula bug in the part would
  /// not also hide itself here.
  static const _heights = [20, 18, 16, 14, 12, 14, 16, 18, 20];

  double get gap => tokens.space1;
  double get barWidth => KitTokens.meterBarWidth;
  double get step => barWidth + gap;
  double get boxHeight => KitTokens.meterBarMax;

  double heightAt(int i) => _heights[i].toDouble();
  double topOf(int i) => (boxHeight - heightAt(i)) / 2;

  /// The centre point of bar [i] (0-based, always inside it: bars are
  /// vertically centred in [boxHeight], so its mid-height is every bar's
  /// centre regardless of its own height).
  Offset centerOf(int i, TextDirection direction) {
    final visual = direction == TextDirection.rtl ? bars - 1 - i : i;
    return Offset(visual * step + barWidth / 2, boxHeight / 2);
  }
}

/// A decoded RGBA capture of a [RenderRepaintBoundary].
class _Capture {
  _Capture(this.width, this.height, this.bytes);

  final int width;
  final int height;
  final ByteData bytes;

  /// This pixel's ARGB32, or null when out of bounds or fully transparent
  /// (nothing painted there).
  int? at(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return null;
    final i = (y * width + x) * 4;
    final a = bytes.getUint8(i + 3);
    if (a == 0) return null;
    return (a << 24) |
        (bytes.getUint8(i) << 16) |
        (bytes.getUint8(i + 1) << 8) |
        bytes.getUint8(i + 2);
  }
}

int _argb(Color c) => c.toARGB32();
int _rgb(Color c) => c.toARGB32() & 0xffffff;

/// Whether any fully-opaque pixel of [capture] has exactly [rgb] (never an
/// anti-aliased edge, whose blended colour is not a real painted role).
bool _opaquePixelMatches(_Capture capture, int rgb) {
  for (var y = 0; y < capture.height; y++) {
    for (var x = 0; x < capture.width; x++) {
      final pixel = capture.at(x, y);
      if (pixel == null) continue;
      if (((pixel >> 24) & 0xff) != 255) continue;
      if ((pixel & 0xffffff) == rgb) return true;
    }
  }
  return false;
}

Future<_Capture> _capture(
  WidgetTester tester,
  Key key, {
  double pixelRatio = 1,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = (await tester.runAsync(
    () => boundary.toImage(pixelRatio: pixelRatio),
  ))!;
  final bytes = (await tester.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final capture = _Capture(image.width, image.height, bytes);
  image.dispose();
  return capture;
}

void main() {
  group('litFor (bar i lit when level >= (i + 1) / 12)', () {
    test('thresholds', () {
      expect(KitLevelMeter.litFor(0), 0);
      expect(KitLevelMeter.litFor(.5), 6);
      expect(KitLevelMeter.litFor(.75), 9);
      expect(KitLevelMeter.litFor(1), 9);
      expect(KitLevelMeter.litFor(-1), 0);
      expect(KitLevelMeter.litFor(double.nan), 0);
    });
  });

  testWidgets(
    'paused (active: false) paints no accent pixel, whatever level says',
    (tester) async {
      final tokens = await _pump(
        tester,
        const KitLevelMeter(level: 1, active: false, meterKey: _key),
      );
      final geo = _Geometry(tokens);
      final capture = await _capture(tester, _key);
      for (var i = 0; i < _Geometry.bars; i++) {
        final c = geo.centerOf(i, TextDirection.ltr);
        expect(
          capture.at(c.dx.round(), c.dy.round()),
          _argb(tokens.roles.surface3),
          reason: 'bar $i',
        );
      }
    },
  );

  testWidgets('direction: .5 lights the first six, mirrored in RTL', (
    tester,
  ) async {
    for (final direction in TextDirection.values) {
      final tokens = await _pump(
        tester,
        const KitLevelMeter(level: .5, meterKey: _key),
        direction: direction,
      );
      final geo = _Geometry(tokens);
      final capture = await _capture(tester, _key);
      for (var i = 0; i < _Geometry.bars; i++) {
        final c = geo.centerOf(i, direction);
        final expected = i < 6 ? tokens.roles.accent : tokens.roles.surface3;
        expect(
          capture.at(c.dx.round(), c.dy.round()),
          _argb(expected),
          reason: '$direction bar $i',
        );
      }
    }
  });

  testWidgets(
    'colours: only accent and surface3 are painted, never danger or attention',
    (tester) async {
      for (final level in [0.0, .2, .5, .9]) {
        for (final active in [true, false]) {
          final tokens = await _pump(
            tester,
            KitLevelMeter(level: level, active: active, meterKey: _key),
          );
          final geo = _Geometry(tokens);
          final capture = await _capture(tester, _key);
          final litCount = active ? KitLevelMeter.litFor(level) : 0;
          // Each bar's centre (never an anti-aliased edge, so its alpha and
          // RGB are exact): opaque, and exactly the role its state expects.
          for (var i = 0; i < _Geometry.bars; i++) {
            final c = geo.centerOf(i, TextDirection.ltr);
            final pixel = capture.at(c.dx.round(), c.dy.round());
            final expected = i < litCount
                ? tokens.roles.accent
                : tokens.roles.surface3;
            expect(
              pixel,
              _argb(expected),
              reason: 'level $level active $active bar $i',
            );
            expect(
              (pixel! >> 24) & 0xff,
              255,
              reason: 'level $level active $active bar $i is not opaque',
            );
          }
          // Nowhere in the shot (including anti-aliased edges) does the
          // danger or attention role's colour appear, at full coverage.
          for (final role in [tokens.roles.danger, tokens.roles.attention]) {
            expect(
              _opaquePixelMatches(capture, _rgb(role)),
              isFalse,
              reason: 'level $level active $active painted $role',
            );
          }
        }
      }
    },
  );

  testWidgets(
    'crisp: at DPR 3 every bar\'s edges land on whole physical pixels',
    (tester) async {
      const dpr = 3.0;
      final tokens = await _pump(
        tester,
        const KitLevelMeter(level: 1, meterKey: _key),
        devicePixelRatio: dpr,
      );
      final geo = _Geometry(tokens);
      final capture = await _capture(tester, _key, pixelRatio: dpr);

      int px(double logical) => (logical * dpr).round();

      for (var i = 0; i < _Geometry.bars; i++) {
        final left = px(i * geo.step);
        final right = left + px(geo.barWidth) - 1;
        final centerY = px(geo.boxHeight / 2);
        expect(
          capture.at(left - 1, centerY),
          isNull,
          reason: 'bar $i: left edge not crisp',
        );
        expect(
          capture.at(left, centerY),
          isNotNull,
          reason: 'bar $i: left edge not crisp',
        );
        expect(
          capture.at(right, centerY),
          isNotNull,
          reason: 'bar $i: right edge not crisp',
        );
        expect(
          capture.at(right + 1, centerY),
          isNull,
          reason: 'bar $i: right edge not crisp',
        );

        final centerX = px(i * geo.step + geo.barWidth / 2);
        final top = px(geo.topOf(i));
        final bottom = top + px(geo.heightAt(i)) - 1;
        expect(
          capture.at(centerX, top - 1),
          isNull,
          reason: 'bar $i: top edge not crisp',
        );
        expect(
          capture.at(centerX, top),
          isNotNull,
          reason: 'bar $i: top edge not crisp',
        );
        expect(
          capture.at(centerX, bottom),
          isNotNull,
          reason: 'bar $i: bottom edge not crisp',
        );
        expect(
          capture.at(centerX, bottom + 1),
          isNull,
          reason: 'bar $i: bottom edge not crisp',
        );
      }
    },
  );

  testWidgets(
    'listen repaints on a ValueNotifier change without rebuilding its parent',
    (tester) async {
      final notifier = ValueNotifier<double>(0);
      addTearDown(notifier.dispose);
      var parentBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                parentBuilds++;
                return KitLevelMeter.listen(
                  listenable: notifier,
                  meterKey: _key,
                );
              },
            ),
          ),
        ),
      );
      expect(parentBuilds, 1);
      for (var i = 1; i <= 10; i++) {
        notifier.value = i / 12;
        await tester.pump();
      }
      expect(parentBuilds, 1, reason: 'the host rebuilt on a level change');
      // The painter did receive the new values (it is not simply frozen).
      final tokens = KitTokens.of(tester.element(find.byKey(_key)));
      final capture = await _capture(tester, _key);
      final geo = _Geometry(tokens);
      final c = geo.centerOf(0, TextDirection.ltr);
      expect(
        capture.at(c.dx.round(), c.dy.round()),
        _argb(tokens.roles.accent),
        reason: 'bar 0 should be lit at level 10/12',
      );
    },
  );

  testWidgets('adds no semantics node', (tester) async {
    final handle = tester.ensureSemantics();
    try {
      await _pump(
        tester,
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [Text('before'), KitLevelMeter(level: .5), Text('after')],
        ),
      );
      final labels = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((node) => node.getSemanticsData().label)
          .where((label) => label.isNotEmpty)
          .toList();
      expect(labels, ['before', 'after']);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('settles with no ticker under reduced motion and normally (G8)', (
    tester,
  ) async {
    // One theme instance for every pump (kit_motion_still.dart): a fresh
    // AppTheme.dark() per call would not compare equal and MaterialApp's
    // AnimatedTheme would animate between the two — the harness moving,
    // not the part.
    final theme = AppTheme.dark();
    Widget app(bool reduceMotion, double level) => MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(body: KitLevelMeter(level: level)),
    );

    for (final reduceMotion in [false, true]) {
      await tester.pumpWidget(app(reduceMotion, .3));
      await tester.pump();
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: 'reduceMotion=$reduceMotion, first frame',
      );
      // A new level (the host rebuilding it) also settles at once.
      await tester.pumpWidget(app(reduceMotion, .9));
      await tester.pump();
      expect(
        tester.hasRunningAnimations,
        isFalse,
        reason: 'reduceMotion=$reduceMotion, after a level change',
      );
    }
  });

  testWidgets(
    'fits a 24 dp line at 320 dp wide, 2.0 text, RTL, with no overflow (G6)',
    (tester) async {
      tester.view.physicalSize = const Size(320, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
          ),
          home: const Scaffold(
            body: SizedBox(
              width: 320,
              height: 24,
              child: Row(
                children: [
                  Expanded(child: SizedBox()),
                  KitLevelMeter(level: .5),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
