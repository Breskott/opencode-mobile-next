// Gallery (gate G4) for KitLastKnown (docs/ux-system/kit-api/KitLastKnown.md):
// the titles a list held last time, read-only while the live list loads
// (loading) and after a failed refresh (settled), at 412x915 and 1280x800,
// dark and light, and at 2.0 text.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_last_known_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Widget _list({bool refreshing = true}) => KitLastKnown(
  updated: 'Updated 12m ago',
  refreshing: refreshing,
  rows: const [
    KitLastKnownRow(title: 'Fix the login redirect loop', detail: '12m ago'),
    KitLastKnownRow(
      title: 'Release notes for 1.0.45 and the store listing copy',
      detail: '1h ago',
    ),
    KitLastKnownRow(title: 'Why is the build slow on CI?', detail: '3h ago'),
    KitLastKnownRow(title: 'Voice model download retries', detail: '1d ago'),
    KitLastKnownRow(title: 'New conversation'),
  ],
);

// The gallery already scrolls its part: a padded block, not a list.
Widget _page({bool refreshing = true}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 16),
  child: _list(refreshing: refreshing),
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      testWidgets('loading · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_last_known_loading', size, light: light),
          size: size,
          light: light,
          child: _page(),
        );
      });
    }
    testWidgets('settled · 412x915 · $mode', (tester) async {
      const size = Size(412, 915);
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_last_known_settled', size, light: light),
        size: size,
        light: light,
        child: _page(refreshing: false),
      );
    });
  }

  for (final size in kitGalleryScaledSizes) {
    testWidgets('loading · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_last_known_loading',
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
