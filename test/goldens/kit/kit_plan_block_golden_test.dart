// Gallery (gate G4) for KitPlanBlock (one plan of a group of plans): at 412x915 and 1280x800, dark and
// light, and at 2.0 text.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_plan_block_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Widget _part() => KitRowGroup(
  leadingIcons: false,
  children: [
    for (final (name, tier, summary, five, week) in const [
      ('Codex', 'Plus', '12% left', 12, 14),
      ('MiniMax', 'Pro', 'Back at 1:25 PM', 0, 36),
    ])
      KitPlanBlock(
        title: name,
        titleNote: tier,
        summary: summary,
        onTap: () {},
        children: [
          KitWindowRow(
            inline: true,
            title: '5 hours',
            left: five / 100,
            valueLabel: '$five% · 1:25 PM',
          ),
          KitWindowRow(
            inline: true,
            title: 'Week',
            left: week / 100,
            valueLabel: '$week% · Thu',
          ),
        ],
      ),
  ],
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      testWidgets('default · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_plan_block_default', size, light: light),
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
          'kit_plan_block_default',
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
