// Gallery (gate G4) for KitContextSheet (docs/ux-system/kit-api/
// KitContextSheet.md): the details body at 84 % and while compacting.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_context_sheet_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

const _bars = [
  KitContextBar(fraction: 0.12),
  KitContextBar(fraction: 0.27),
  KitContextBar(fraction: 0.45),
  KitContextBar(fraction: 0.71),
  KitContextBar(fraction: 0.18, compactedBefore: true),
  KitContextBar(fraction: 0.39),
  KitContextBar(fraction: 0.62),
  KitContextBar(fraction: 0.84),
];

Widget _scene({bool compacting = false}) => Builder(
  builder: (context) {
    final tokens = KitTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.fillOf(KitSurfaceLevel.surface2),
        borderRadius: BorderRadius.circular(tokens.panelCornerRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.space5),
        child: SingleChildScrollView(
          child: KitContextSheet(
            tokens: 168000,
            limit: 200000,
            modelName: 'Claude Sonnet',
            bars: _bars,
            compacting: compacting,
          ),
        ),
      ),
    );
  },
);

const _otherSizes = <Size>[Size(360, 800), Size(1280, 800)];

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    testWidgets('details · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_context_sheet_details',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _scene(),
      );
    });
    testWidgets('compacting · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_context_sheet_compacting',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _scene(compacting: true),
      );
    });
    for (final size in _otherSizes) {
      testWidgets('details · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_context_sheet_details', size, light: light),
          size: size,
          light: light,
          child: _scene(),
        );
      });
    }
  }

  for (final size in const [Size(412, 915), Size(1280, 800)]) {
    testWidgets('details · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_context_sheet_details',
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
    testWidgets('details · Arabic · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_context_sheet_details',
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
