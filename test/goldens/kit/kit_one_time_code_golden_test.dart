// Gallery (gate G4) for KitOneTimeCode: a device code, large and mono, with
// the kit's Copy control. Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_one_time_code_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_one_time_code.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

Widget _code() => Builder(
  builder: (context) => Padding(
    padding: EdgeInsets.all(KitTokens.of(context).space4),
    child: const KitOneTimeCode(
      code: 'VPFI-KC2ZK',
      label: 'Your code',
      copyLabel: 'Copy code',
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGallerySizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_one_time_code default · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_one_time_code_default', size, light: light),
          size: size,
          light: light,
          child: _code(),
        );
      });
    }
    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_one_time_code default · 2.0 text · $at · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_one_time_code_default',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _code(),
        );
      });
    }
  }
}
