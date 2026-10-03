// Gallery (gate G4) for KitDivider, docs/ux-system/kit-api/KitDivider.md:
// the one hairline separator, its three horizontal insets and its vertical
// form. KitDivider is not exported from kit.dart yet (the integrator adds
// that row, R06), so this file imports it directly rather than through
// package:opencode_mobile/ui/kit/kit.dart. The rows and the toolbar around
// the lines are the kit's own parts (KitRow with its icon tile,
// KitIconButton), so the gallery shows the real anatomy the insets line up
// with.
//
// Sizes: kitGallerySizes (kit_gallery.dart) follows kit-v2.md §8.4 and lacks
// the landscape phone 915x412 that STANDARDS.md LAY-4/TEST-9 and
// KitDivider.md require, so this file adds that shot itself (reported as a
// contract problem in docs/qa/revamp-kit-KitDivider-2026-09-26/README.md).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_divider_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit_divider.dart';
import 'package:opencode_mobile/ui/kit/kit_icon_button.dart';
import 'package:opencode_mobile/ui/kit/kit_row.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

/// One row of a row group, the kit's own [KitRow]: a title, after the
/// kit's leading icon tile ([KitRow.icon]) when [leadingIcon].
Widget _row(String label, {bool leadingIcon = false}) => Builder(
  builder: (context) => KitRow(
    title: label,
    leading: leadingIcon ? KitRow.icon(context, AppIconography.terminal) : null,
  ),
);

/// The `insets` state (KitDivider.md §Galleries): a row group with `none`,
/// `gutter` and `text` dividers between 54 dp rows.
Widget _insets({bool arabic = false}) => Builder(
  builder: (context) {
    final tokens = KitTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.roles.surface1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(arabic ? 'بلا فاصل' : 'Section header'),
          const KitDivider(),
          _row(arabic ? 'بلا أيقونة بادئة' : 'No leading icon'),
          const KitDivider(inset: KitDividerInset.gutter),
          _row(
            arabic ? 'بأيقونة بادئة' : 'With a leading icon',
            leadingIcon: true,
          ),
          const KitDivider(inset: KitDividerInset.text),
          _row(arabic ? 'الصف الأخير' : 'Last row', leadingIcon: true),
        ],
      ),
    );
  },
);

/// The `vertical` state: a toolbar with two groups of the kit's icon
/// buttons ([KitIconButton], 48 dp targets) split by a vertical hairline,
/// such as a chat composer's tool groups. The toolbar is one target tall
/// ([KitTokens.minTarget]); the line keeps [KitTokens.space3] clear of its
/// top and bottom, so it is as tall as the glyphs beside it.
Widget _vertical() => Builder(
  builder: (context) {
    final tokens = KitTokens.of(context);
    Widget button(IconData icon, String label) =>
        KitIconButton(icon: icon, label: label, onPressed: () {});
    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.roles.surface1),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space4,
          vertical: tokens.space2,
        ),
        child: SizedBox(
          height: tokens.minTarget,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              button(AppIconography.terminal, 'Open terminal'),
              button(AppIconography.check, 'Mark done'),
              SizedBox(width: tokens.space2),
              Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.space3),
                child: const KitDivider.vertical(),
              ),
              SizedBox(width: tokens.space2),
              button(AppIconography.info, 'Details'),
              button(AppIconography.copy, 'Copy'),
            ],
          ),
        ),
      ),
    );
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    // TEST-9 / LAY-4: the §8.4 sizes of the shared helper, plus the
    // landscape phone it lacks (see the note at the top of this file).
    for (final size in [...kitGallerySizes, const Size(915, 412)]) {
      final at = kitGallerySize(size);
      testWidgets('kit_divider insets · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_divider_insets', size, light: light),
          size: size,
          light: light,
          child: _insets(),
        );
      });
    }

    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_divider insets · 2.0 text · $at · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_divider_insets',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _insets(),
        );
      });

      testWidgets('kit_divider insets · ar · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_divider_insets',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          textScale: 1.3,
          child: _insets(arabic: true),
        );
      });
    }

    testWidgets('kit_divider vertical · $mode', (tester) async {
      const phone = Size(412, 915);
      await kitGalleryPart(
        tester,
        name: kitGalleryName('kit_divider_vertical', phone, light: light),
        size: phone,
        light: light,
        child: _vertical(),
      );
    });
  }
}
