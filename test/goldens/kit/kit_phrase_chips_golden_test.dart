// Gallery (gate G4) for KitPhraseChips (the person's own short phrases above
// the message box): at 412x915 and 1280x800, dark and light, at 2.0 text,
// and the empty state (nothing drawn).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_phrase_chips_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Widget _part({
  List<String> phrases = const ['Continue', 'Run the tests', 'Commit this'],
}) => KitPhraseChips(
  phrases: phrases,
  onChoose: (_) {},
  onEdit: (_) {},
  onHide: (_) {},
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      testWidgets('default · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_phrase_chips_default', size, light: light),
          size: size,
          light: light,
          child: _part(),
        );
      });
    }
    testWidgets('empty · 412x915 · $mode', (tester) async {
      const size = Size(412, 915);
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_phrase_chips_empty', size, light: light),
        size: size,
        light: light,
        child: _part(phrases: const []),
      );
    });
  }

  for (final size in kitGalleryScaledSizes) {
    testWidgets('default · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_phrase_chips_default',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        child: _part(),
      );
    });
  }
}
