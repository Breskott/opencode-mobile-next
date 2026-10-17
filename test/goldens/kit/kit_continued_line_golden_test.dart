// Gallery (gate G4) for KitContinuedLine, docs/ux-system/kit-api (Continue with… parts).
//
// Galleries are phone 412x915 and one wide size 1280x800, light and dark
// (owner decision 2026-09-27); each state also at 2.0 text on both sizes.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_continued_line_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Widget _line({required bool gone}) => KitContinuedLine(
  text: 'Continued in Claude Code',
  onOpen: () {},
  gone: gone,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_continued_line default · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_continued_line_default',
            size,
            light: light,
          ),
          size: size,
          light: light,
          child: _line(gone: false),
        );
      });

      testWidgets('kit_continued_line default · 2.0 text · $at · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_continued_line_default',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _line(gone: false),
        );
      });

      testWidgets('kit_continued_line disabled · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_continued_line_disabled',
            size,
            light: light,
          ),
          size: size,
          light: light,
          child: _line(gone: true),
        );
      });

      testWidgets('kit_continued_line disabled · 2.0 text · $at · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_continued_line_disabled',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _line(gone: true),
        );
      });
    }
  }
}
