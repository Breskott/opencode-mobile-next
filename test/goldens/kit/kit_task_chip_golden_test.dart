// Gallery (gate G4) for KitTaskChip (the agent's task list as a chip beside the approval and model
// chips): resting at the start and part way through. At 412x915 and 1280x800,
// dark and light, and at 2.0 text.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_task_chip_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Widget _chips() => Padding(
  padding: const EdgeInsets.all(16),
  child: Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      KitTaskChip(done: 0, total: 5, onPressed: () {}),
      KitTaskChip(
        done: 5,
        total: 6,
        current: 'Run the tests',
        onPressed: () {},
      ),
    ],
  ),
);

final _scenes = <String, Widget Function()>{'default': _chips};

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
            name: kitGalleryName('kit_task_chip_$scene', size, light: light),
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
          'kit_task_chip_default',
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
}
