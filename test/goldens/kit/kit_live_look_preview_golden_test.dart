// Gallery (gate G4) for KitLiveLookPreview (the chosen look in a short tile):
// on and disabled, 412x915 and 1280x800, dark and light, and at 2.0 text. Under
// flutter test the live look is not painted (KitMotion.loops is off), so the
// shots hold the flat ground and the mock lines; the looks themselves are in
// docs/qa/effects-preview-2026-10-15.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_live_look_preview_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Widget _part(bool enabled) => Padding(
  padding: const EdgeInsets.all(16),
  child: KitLiveLookPreview(
    style: kitLiveStyleById('aurora'),
    intensity: KitLiveIntensity.normal,
    enabled: enabled,
    onTap: () {},
  ),
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final enabled in [true, false]) {
    final state = enabled ? 'on' : 'disabled';
    for (final light in [false, true]) {
      final mode = light ? 'light' : 'dark';
      for (final size in kitGalleryScaledSizes) {
        // The disabled phone shots are the KIT-12 state scenes below.
        if (!enabled && size.width == 412) continue;
        testWidgets('$state · ${kitGallerySize(size)} · $mode', (tester) async {
          await kitGalleryPart(
            tester,
            name: kitGalleryName(
              'kit_live_look_preview_$state',
              size,
              light: light,
            ),
            size: size,
            light: light,
            child: _part(enabled),
          );
        });
      }
    }
  }

  // disabled is KitLiveLookPreview's declared state (its `/// States:` line):
  // gate G4 (stateScenes) reads the 412x915 names from a literal
  // `kitGalleryShot` call.
  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    testWidgets('disabled · 412x915 · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_live_look_preview_disabled',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        open: (context) => Navigator.of(context).push<void>(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => Scaffold(
              body: Align(alignment: Alignment.topCenter, child: _part(false)),
            ),
          ),
        ),
      );
    });
  }

  for (final size in kitGalleryScaledSizes) {
    testWidgets('on · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_live_look_preview_on',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        child: _part(true),
      );
    });
  }
}
