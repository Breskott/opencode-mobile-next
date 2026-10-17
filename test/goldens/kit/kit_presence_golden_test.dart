// Gallery (gate G4) for KitPresence, the part that fades with its slot.
//
// Galleries are phone 412x915 and one wide size 1280x800, light and dark
// (owner decision 2026-09-27); each state also at 2.0 text on both sizes.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_presence_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

final _states = <String, Widget Function()>{
  'shown': () => const Row(
    children: [
      Flexible(
        child: KitPresence(
          show: true,
          child: KitText('Find the latest finance hub project in the folder'),
        ),
      ),
    ],
  ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      for (final MapEntry(key: state, value: build) in _states.entries) {
        testWidgets('kit_presence $state · $at · $mode', (tester) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName('kit_presence_$state', size, light: light),
            size: size,
            light: light,
            child: build(),
          );
        });

        testWidgets('kit_presence $state · 2.0 text · $at · $mode', (
          tester,
        ) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName(
              'kit_presence_$state',
              size,
              light: light,
              text2: true,
            ),
            size: size,
            light: light,
            textScale: 2,
            child: build(),
          );
        });
      }
    }
  }
}
