// Gallery (gate G4) for KitTranscriptExcerpt
// (docs/ux-system/kit-api/KitTranscriptExcerpt.md): the end of a
// conversation as it read last time, read-only while its live history loads
// (loading), at 412x915 and 1280x800, dark and light, and at 2.0 text.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_transcript_excerpt_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

const _messages = [
  KitExcerptMessage(text: 'Fix the flaky checkout test', fromPerson: true),
  KitExcerptMessage(
    text:
        'The checkout test waited on a timer that the payment stub never '
        'fired. It now waits for the **order confirmed** event instead, and '
        'the suite passed ten runs in a row.',
    fromPerson: false,
  ),
  KitExcerptMessage(text: 'Run the full suite once more', fromPerson: true),
  KitExcerptMessage(
    text: 'All 412 tests passed in 3 minutes 20 seconds.',
    fromPerson: false,
  ),
];

// The part fills the height it is given, newest at the bottom.
Widget _page() => const SizedBox(
  height: 600,
  child: KitTranscriptExcerpt(messages: _messages, updated: 'Updated 12m ago'),
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      testWidgets('loading · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_transcript_excerpt_loading',
            size,
            light: light,
          ),
          size: size,
          light: light,
          child: _page(),
        );
      });
    }
  }

  for (final size in kitGalleryScaledSizes) {
    testWidgets('loading · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_transcript_excerpt_loading',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        child: _page(),
      );
    });
  }
}
