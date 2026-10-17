// Gallery (gate G4) for KitContextChart (docs/ux-system/kit-api/
// KitContextChart.md): bars by level with the 80 % line and a compaction.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_context_chart_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

const _climb = [
  KitContextBar(fraction: 0.08),
  KitContextBar(fraction: 0.18),
  KitContextBar(fraction: 0.31),
  KitContextBar(fraction: 0.46),
  KitContextBar(fraction: 0.63),
  KitContextBar(fraction: 0.76),
  KitContextBar(fraction: 0.88),
  KitContextBar(fraction: 0.97),
  KitContextBar(fraction: 0.21, compactedBefore: true),
  KitContextBar(fraction: 0.34),
  KitContextBar(fraction: 0.52),
];

Widget _scene() => Builder(
  builder: (context) {
    final tokens = KitTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.fillOf(KitSurfaceLevel.surface2),
        borderRadius: BorderRadius.circular(tokens.panelCornerRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.space5),
        child: const KitContextChart(bars: _climb),
      ),
    );
  },
);

const _otherSizes = <Size>[Size(360, 800), Size(1280, 800)];

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    testWidgets('climb and compaction · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_context_chart_climb',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _scene(),
      );
    });
    for (final size in _otherSizes) {
      testWidgets('climb · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_context_chart_climb', size, light: light),
          size: size,
          light: light,
          child: _scene(),
        );
      });
    }
  }

  for (final size in const [Size(412, 915), Size(1280, 800)]) {
    testWidgets('climb · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_context_chart_climb',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        child: _scene(),
      );
    });
    testWidgets('climb · Arabic · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_context_chart_climb',
          size,
          light: false,
          ar: true,
        ),
        size: size,
        light: false,
        locale: const Locale('ar'),
        textScale: 1.3,
        child: _scene(),
      );
    });
  }
}
