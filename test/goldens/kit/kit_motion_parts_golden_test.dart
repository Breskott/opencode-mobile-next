// Gallery (gate G4) for KitMotionParts (docs/ux-system/kit-api/
// KitMotionParts.md): KitSwap, KitSpin, KitAnimatedBox, KitDim,
// KitAnimatedValue. kitGalleryPart disables animations, so every shot is a
// settled frame (VL §7: the parts show their final state at once), at DPR
// 3, rendered as Android, in dark and light, at the K2 §8.4 sizes.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_motion_parts_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/kit/motion/kit_motion_parts.dart';

import 'kit_gallery.dart';

/// A caption above [content], the way this gallery labels each demoed part.
Widget _scene(String caption, Widget content) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      KitText(caption, role: KitTextRole.label),
      const SizedBox(height: 12),
      content,
    ],
  ),
);

/// Reads tokens from [context] and builds the scene: every demo needs
/// `KitTokens.of` for colours, which a plain top-level function has no
/// context for.
Widget _demo(Widget Function(BuildContext context) build) =>
    Builder(builder: build);

Widget _pill(BuildContext context, String label, Key key) {
  final tokens = KitTokens.of(context);
  return Container(
    key: key,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: tokens.roles.surface2,
      borderRadius: BorderRadius.circular(999),
    ),
    child: KitText(label, role: KitTextRole.rowTitle),
  );
}

/// A drawing placeholder (a filled circle): content with no paragraph in
/// its render subtree, so it is a valid KitDim child (an icon glyph is not:
/// it paints through a RenderParagraph, and dimming a glyph is
/// kit-KitIcon's job — see the spec's Replaces table).
class _DotPainter extends CustomPainter {
  const _DotPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _DotPainter oldDelegate) =>
      oldDelegate.color != color;
}

Widget _imageMark(BuildContext context) {
  final tokens = KitTokens.of(context);
  return Container(
    width: 56,
    height: 56,
    decoration: BoxDecoration(
      color: tokens.roles.surface3,
      borderRadius: BorderRadius.circular(tokens.iconTileRadius),
    ),
  );
}

Widget _drawingMark(BuildContext context) {
  final tokens = KitTokens.of(context);
  return SizedBox(
    width: 56,
    height: 56,
    child: CustomPaint(painter: _DotPainter(tokens.roles.accent)),
  );
}

Widget _swapScene(String label) => _demo(
  (context) =>
      _scene('KitSwap', KitSwap(child: _pill(context, label, ValueKey(label)))),
);

Widget _spinChevronScene(bool expanded, {String? label}) => _demo(
  (context) => _scene(
    'KitSpin.chevron',
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KitText(
          label ?? (expanded ? 'Hide details' : 'Show details'),
          role: KitTextRole.rowTitle,
        ),
        const SizedBox(width: 8),
        KitSpin.chevron(expanded: expanded),
      ],
    ),
  ),
);

Widget _spinFixedScene() => _demo((context) {
  final tokens = KitTokens.of(context);
  return _scene(
    'KitSpin.fixed',
    KitSpin.fixed(
      quarterTurns: 1,
      child: Icon(Icons.terminal, size: 28, color: tokens.roles.text2),
    ),
  );
});

Widget _boxScene(
  String label, {
  KitSurfaceLevel? level,
  bool outlined = false,
}) => _demo(
  (context) => _scene(
    'KitAnimatedBox ($label)',
    KitAnimatedBox(
      level: level,
      outlined: outlined,
      child: const SizedBox(width: 96, height: 56),
    ),
  ),
);

Widget _dimScene(String label, KitDimLevel level) => _demo(
  (context) => _scene(
    'KitDim ($label)',
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KitDim(level: level, child: _imageMark(context)),
        const SizedBox(width: 16),
        KitDim(level: level, child: _drawingMark(context)),
      ],
    ),
  ),
);

Widget _valueScene(double value) => _demo((context) {
  final tokens = KitTokens.of(context);
  return _scene(
    'KitAnimatedValue',
    SizedBox(
      width: 240,
      height: 8,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.roles.surface3,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned.fill(
            child: KitAnimatedValue(
              value: value,
              jump: true,
              builder: (context, v) => FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: v.clamp(0, 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.roles.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
});

/// The states gallery (TEST-9): 412×915, dark and light.
final _states = <(String, Widget Function())>[
  ('swap_before', () => _swapScene('Sending…')),
  ('swap_after', () => _swapScene('Sent')),
  ('spin_chevron_closed', () => _spinChevronScene(false)),
  ('spin_chevron_open', () => _spinChevronScene(true)),
  ('spin_fixed', _spinFixedScene),
  ('box_default', () => _boxScene('default')),
  (
    'box_surface1',
    () => _boxScene('surface1', level: KitSurfaceLevel.surface1),
  ),
  (
    'box_surface2',
    () => _boxScene('surface2', level: KitSurfaceLevel.surface2),
  ),
  (
    'box_surface3',
    () => _boxScene('surface3', level: KitSurfaceLevel.surface3),
  ),
  ('box_outlined', () => _boxScene('outlined', outlined: true)),
  ('dim_stale', () => _dimScene('stale', KitDimLevel.stale)),
  ('dim_disabled', () => _dimScene('disabled', KitDimLevel.disabled)),
  ('value_030', () => _valueScene(.3)),
  ('value_080', () => _valueScene(.8)),
];

const _otherSizes = [
  Size(360, 800),
  Size(915, 412),
  Size(800, 1280),
  Size(1280, 800),
  Size(1600, 1000),
];

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    for (final (state, build) in _states) {
      testWidgets('$state (${light ? 'light' : 'dark'})', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_motion_$state',
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          child: build(),
        );
      });
    }

    // Default state (box) at the other K2 §8.4 sizes.
    for (final size in _otherSizes) {
      testWidgets(
        'box_default ${kitGallerySize(size)} (${light ? 'light' : 'dark'})',
        (tester) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName('kit_motion_box_default', size, light: light),
            size: size,
            light: light,
            child: _boxScene('default'),
          );
        },
      );
    }

    // _text2 and _ar for spin and swap, at 412×915 and 1280×800.
    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      final mode = light ? 'light' : 'dark';
      testWidgets('swap text2 $at ($mode)', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_motion_swap_after',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _swapScene('Sent'),
        );
      });
      testWidgets('swap ar $at ($mode)', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_motion_swap_after',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          textScale: 1.3,
          child: _swapScene('أُرسلت'),
        );
      });
      testWidgets('spin text2 $at ($mode)', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_motion_spin_chevron_open',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _spinChevronScene(true),
        );
      });
      testWidgets('spin ar $at ($mode)', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_motion_spin_chevron_open',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          textScale: 1.3,
          child: _spinChevronScene(true, label: 'إخفاء التفاصيل'),
        );
      });
    }
  }

  // G6 overflow matrix (no images): every other state and size (TEST-9),
  // narrower and no golden — a plain widget-test check that nothing throws
  // (a RenderFlex overflow surfaces as an exception here), not an image
  // comparison. Each part is exercised on its own, without extra demo text
  // that isn't part of the widget itself.
  group('G6 overflow matrix (no images)', () {
    const narrow = Size(320, 480);
    final scenes = <String, Widget Function()>{
      'swap_before': () => _swapScene('Sending…'),
      'swap_after': () => _swapScene('Sent'),
      'spin_chevron_closed': () => _spinChevronScene(false),
      'spin_chevron_open': () => _spinChevronScene(true),
      'spin_fixed': _spinFixedScene,
      'box_default': () => _boxScene('default'),
      'box_outlined': () => _boxScene('outlined', outlined: true),
      'dim_stale': () => _dimScene('stale', KitDimLevel.stale),
      'dim_disabled': () => _dimScene('disabled', KitDimLevel.disabled),
      'value_030': () => _valueScene(.3),
      'value_080': () => _valueScene(.8),
    };
    for (final rtl in [false, true]) {
      final direction = rtl ? 'rtl' : 'ltr';
      for (final MapEntry(key: state, value: build) in scenes.entries) {
        testWidgets('$state at ${narrow.width.toInt()}w, 2.0x, $direction', (
          tester,
        ) async {
          tester.view.physicalSize = narrow;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: rtl ? const Locale('ar') : const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(body: SingleChildScrollView(child: build())),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$state overflowed at ${narrow.width}w, 2.0x, $direction',
          );
        });
      }
    }
  });
}
