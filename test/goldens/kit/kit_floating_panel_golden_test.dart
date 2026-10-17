// Gallery (gate G4) for KitFloatingPanel: at 412x915 and 1280x800, dark and light, and
// at 2.0 text.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_floating_panel_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

final _states = <String, Widget Function()>{
  'default': () => SizedBox(
    height: 600,
    child: KitFloatingPanel(
      onDismiss: () {},
      child: const Text('A small panel over the home screen'),
    ),
  ),
};

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final MapEntry(key: state, value: build) in _states.entries) {
    for (final light in [false, true]) {
      final mode = light ? 'light' : 'dark';
      for (final size in kitGalleryScaledSizes) {
        testWidgets('$state · ${kitGallerySize(size)} · $mode', (tester) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName(
              'kit_floating_panel_$state',
              size,
              light: light,
            ),
            size: size,
            light: light,
            child: build(),
          );
        });
      }
    }
    for (final size in kitGalleryScaledSizes) {
      testWidgets('$state · 2.0 text · ${kitGallerySize(size)} · dark', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_floating_panel_$state',
            size,
            light: false,
            text2: true,
          ),
          size: size,
          light: false,
          textScale: 2,
          child: build(),
        );
      });
    }
  }
}
