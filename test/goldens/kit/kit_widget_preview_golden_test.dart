// Gallery (gate G4) for KitWidgetPreview: at 412x915 and 1280x800, dark and light, and
// at 2.0 text.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_widget_preview_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Widget _p(KitWidgetPreviewSize size, KitWidgetPreviewBackground bg, Color c) =>
    Padding(
      padding: const EdgeInsets.all(16),
      child: KitWidgetPreview(size: size, background: bg, accent: c),
    );

final _states = <String, Widget Function()>{
  'default': () => Column(
    children: [
      _p(
        KitWidgetPreviewSize.compact,
        KitWidgetPreviewBackground.solid,
        const Color(0xFF48AC6F),
      ),
      _p(
        KitWidgetPreviewSize.card,
        KitWidgetPreviewBackground.tinted,
        const Color(0xFF4187CD),
      ),
      _p(
        KitWidgetPreviewSize.list,
        KitWidgetPreviewBackground.transparent,
        const Color(0xFFBA8420),
      ),
    ],
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
              'kit_widget_preview_$state',
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
            'kit_widget_preview_$state',
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
