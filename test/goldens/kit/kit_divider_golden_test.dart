// Gallery (gate G4) for KitDivider, docs/ux-system/kit-api/KitDivider.md:
// the one hairline separator, its three horizontal insets and its vertical
// form. KitDivider is not exported from kit.dart yet (the integrator adds
// that row, R06), so this file imports it directly rather than through
// package:opencode_mobile/ui/kit/kit.dart.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_divider_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit_divider.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

/// One placeholder row (a row group's real anatomy is KitRow's job; this
/// gallery only has to show where the hairline sits relative to it): a
/// leading icon tile when [leadingIcon], then a title.
Widget _row(String label, {bool leadingIcon = false}) => Builder(
  builder: (context) {
    final tokens = KitTokens.of(context);
    return SizedBox(
      height: tokens.rowHeight,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: tokens.space4,
          end: tokens.space4,
        ),
        child: Row(
          children: [
            if (leadingIcon) ...[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: tokens.roles.surface2,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SizedBox(
                  width: tokens.iconTileSize,
                  height: tokens.iconTileSize,
                  child: Icon(
                    AppIconography.terminal,
                    size: 16,
                    color: tokens.roles.text2,
                  ),
                ),
              ),
              SizedBox(width: tokens.space3),
            ],
            Expanded(
              child: Text(
                label,
                style: tokens.rowTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  },
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

/// The `vertical` state: a toolbar with two icon groups split by a vertical
/// hairline, such as a chat composer's tool groups.
Widget _vertical() => Builder(
  builder: (context) {
    final tokens = KitTokens.of(context);
    Widget button(IconData icon) => DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.roles.surface2,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, size: 20, color: tokens.roles.text2),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.roles.surface1),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space4,
          vertical: tokens.space3,
        ),
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              button(AppIconography.terminal),
              SizedBox(width: tokens.space3),
              button(AppIconography.check),
              SizedBox(width: tokens.space4),
              const KitDivider.vertical(),
              SizedBox(width: tokens.space4),
              button(AppIconography.info),
              SizedBox(width: tokens.space3),
              button(AppIconography.copy),
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

    for (final size in kitGallerySizes) {
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
