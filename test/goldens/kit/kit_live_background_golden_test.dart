// Gallery (gate G4) for KitLiveBackground (a page ground with a live look): at 412x915 and 1280x800, dark and
// light, and at 2.0 text. Under flutter test the live look is not painted
// (KitMotion.loops is off), so the shots hold the flat ground and the part's
// own layout; the looks themselves are in docs/qa/live-background-2026-10-14.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_live_background_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Widget _part() => KitLiveBackground(
  child: Center(child: KitText('Chats', role: KitTextRole.headline)),
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      testWidgets('default · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_live_background_default',
            size,
            light: light,
          ),
          size: size,
          light: light,
          child: _part(),
        );
      });
    }
  }

  for (final size in kitGalleryScaledSizes) {
    testWidgets('default · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_live_background_default',
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
