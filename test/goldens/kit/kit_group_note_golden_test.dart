// Gallery (gate G4) for KitGroupNote (docs/ux-system/kit-api/KitGroupNote.md):
// the line under a row group, at 412x915 dark and light, with and without
// its action, at every other gallery size (default), and at 2.0 text.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_group_note_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

const _message = "2 settings aren't available on this server";

Widget _group({bool action = true}) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Builder(
      builder: (context) => KitRowGroup(
        label: 'Conversations',
        children: [
          KitRow(
            leading: KitRow.icon(context, AppIconography.mic),
            title: 'Voice',
            trailing: const KitChevron(),
            onTap: () {},
          ),
        ],
      ),
    ),
    KitGroupNote(
      message: _message,
      action: action ? KitAction(label: 'Why', onPressed: () {}) : null,
    ),
  ],
);

const _states = Size(412, 915);

const _defaultSizes = <Size>[
  Size(360, 800),
  Size(915, 412),
  Size(800, 1280),
  Size(1280, 800),
  Size(1600, 1000),
];

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    testWidgets('text only · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_group_note_text', _states, light: light),
        size: _states,
        light: light,
        child: _group(action: false),
      );
    });
    for (final size in [_states, ..._defaultSizes]) {
      testWidgets('with action · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_group_note_default', size, light: light),
          size: size,
          light: light,
          child: _group(),
        );
      });
    }
  }

  for (final size in kitGalleryScaledSizes) {
    testWidgets('wrapped · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_group_note_default',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        child: _group(),
      );
    });
  }
}
