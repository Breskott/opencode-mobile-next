// Gallery (gate G4) for KitLevelMeter (docs/ux-system/kit-api/KitLevelMeter.md
// "Galleries required"): the meter centred on a surface2 panel under a
// "Listening 0:07" label — a gallery fixture standing in for the voice
// sheet's own words, since the meter carries none of its own.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_level_meter_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_level_meter.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

const _listeningEn = 'Listening 0:07';
const _listeningAr = 'يستمع · 0:07';
const _pausedEn = 'Paused · mic off';

/// The panel every state is shown on: the meter is decorative, so it is
/// never shown alone (KitLevelMeter.md "Purpose").
Widget _scene({
  required double level,
  bool active = true,
  required String listening,
}) => Builder(
  builder: (context) {
    final tokens = KitTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.fillOf(KitSurfaceLevel.surface2),
        borderRadius: BorderRadius.circular(tokens.panelCornerRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KitLevelMeter(level: level, active: active),
            SizedBox(height: tokens.space2),
            KitText(listening, role: KitTextRole.secondary),
          ],
        ),
      ),
    );
  },
);

Widget _listeningLow() => _scene(level: .2, listening: _listeningEn);
Widget _listeningHigh() => _scene(level: .9, listening: _listeningEn);
Widget _listeningHighAr() => _scene(level: .9, listening: _listeningAr);
Widget _quiet() => _scene(level: 0, listening: _listeningEn);
Widget _paused() => _scene(level: .6, active: false, listening: _pausedEn);

/// The declared states (KIT-12), at the census phone size only.
final _declaredStates = <String, Widget Function()>{
  'listening_low': _listeningLow,
  'listening_high': _listeningHigh,
  'quiet': _quiet,
  'paused': _paused,
};

/// The other §8.4 sizes the default state (listening_high) is shown at,
/// including the landscape phone G6 adds (kit-v2.md §8.4).
const _otherSizes = <Size>[
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

    for (final MapEntry(key: state, value: build) in _declaredStates.entries) {
      testWidgets('$state · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_level_meter_$state',
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          child: build(),
        );
      });
    }

    for (final size in _otherSizes) {
      testWidgets('listening_high · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_level_meter_listening_high',
            size,
            light: light,
          ),
          size: size,
          light: light,
          child: _listeningHigh(),
        );
      });
    }
  }

  for (final size in const [Size(412, 915), Size(1280, 800)]) {
    testWidgets('listening_high · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_level_meter_listening_high',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        child: _listeningHigh(),
      );
    });
    testWidgets('listening_high · Arabic · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_level_meter_listening_high',
          size,
          light: false,
          ar: true,
        ),
        size: size,
        light: false,
        locale: const Locale('ar'),
        textScale: 1.3,
        child: _listeningHighAr(),
      );
    });
  }
}
