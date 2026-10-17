// Gallery (gate G4) for KitWindowRow (docs/ux-system/kit-api/KitWindowRow.md): one limit window in
// each tone, with a note, stacked and inline. At 412x915 and 1280x800, dark and
// light, and at 2.0 text.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_window_row_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Widget _windows() => Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: const [
      KitWindowRow(title: '5 hours', left: .72, valueLabel: '72% left · 14:10'),
      KitWindowRow(
        title: 'Week',
        left: .18,
        valueLabel: '18% left · Thu',
        tone: KitWindowTone.low,
        note: 'Resets at Wed 1:59 AM, in 14 h',
      ),
      KitWindowRow(
        title: 'Month',
        left: 0,
        valueLabel: 'Used up · Sep 1',
        tone: KitWindowTone.out,
      ),
      KitWindowRow(
        title: 'Last read',
        left: .4,
        valueLabel: '40% left · 2 days ago',
        tone: KitWindowTone.calm,
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: KitWindowRow(
          inline: true,
          title: '5 hours',
          left: .12,
          valueLabel: '12% · 1:25 PM',
        ),
      ),
    ],
  ),
);

Widget _arabic() => Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: const [
      KitWindowRow(
        title: '٥ ساعات',
        left: .72,
        valueLabel: 'متبقي 72% · 14:10',
      ),
      KitWindowRow(
        title: 'الأسبوع',
        left: .18,
        valueLabel: 'متبقي 18% · الخميس',
        tone: KitWindowTone.low,
        note: 'يُعاد الضبط الأربعاء 1:59 ص',
      ),
    ],
  ),
);

final _scenes = <String, Widget Function()>{'default': _windows};

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final MapEntry(key: scene, value: build) in _scenes.entries) {
      for (final size
          in scene == 'default'
              ? kitGalleryScaledSizes
              : const [Size(412, 915)]) {
        testWidgets('$scene · ${kitGallerySize(size)} · $mode', (tester) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName('kit_window_row_$scene', size, light: light),
            size: size,
            light: light,
            child: build(),
          );
        });
      }
    }
  }

  for (final size in kitGalleryScaledSizes) {
    testWidgets('default · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_window_row_default',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        child: _scenes['default']!(),
      );
    });
  }

  for (final size in kitGalleryScaledSizes) {
    testWidgets('Arabic · ${kitGallerySize(size)} · dark', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_window_row_default',
          size,
          light: false,
          ar: true,
        ),
        size: size,
        light: false,
        locale: const Locale('ar'),
        child: _arabic(),
      );
    });
  }
}
