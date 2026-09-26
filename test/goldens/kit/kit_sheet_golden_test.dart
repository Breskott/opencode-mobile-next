// Gallery (gate G4) for KitSheet, docs/ux-system/kit-v2.md §1.1 and §8.2:
// a bottom sheet on phones, capped at 640 dp on a medium window, a centred
// panel on tablets in landscape and PCs, and an end-side sheet for a
// full-height sheet there.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_sheet_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import '../../../tool/capture/fixtures.dart' show loadCaptureFonts;
import 'kit_gallery.dart';

List<(IconData, String, String)> _rows(bool arabic) => arabic
    ? const [
        (AppIconography.check, 'العربية', 'لغة الهاتف'),
        (AppIconography.info, 'English', 'الإنجليزية'),
        (AppIconography.info, 'Deutsch', 'الألمانية'),
      ]
    : const [
        (AppIconography.check, 'English', 'The phone’s language'),
        (AppIconography.info, 'العربية', 'Arabic'),
        (AppIconography.info, 'Deutsch', 'German'),
      ];

Widget _body(BuildContext context, {bool arabic = false}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final (icon, title, supporting) in _rows(arabic))
      KitRow(
        padding: const EdgeInsets.symmetric(vertical: 8),
        leading: KitRowIcon(icon, current: icon == AppIconography.check),
        title: title,
        supporting: TextSpan(text: supporting),
        onTap: () {},
      ),
  ],
);

Future<void> _language(
  BuildContext context, {
  bool arabic = false,
  KitSheetHeight height = KitSheetHeight.content,
  ValueListenable<bool>? loading,
  bool disabled = false,
  ValueListenable<bool>? dirty,
}) => showKitSheet<void>(
  context,
  title: arabic ? 'اللغة' : 'Language',
  subtitle: arabic ? 'الكلمات في كل التطبيق' : 'Words across the app',
  height: height,
  loading: loading,
  dirty: dirty,
  body: (inner) => _body(inner, arabic: arabic),
  primary: KitAction(
    label: arabic ? 'استخدام العربية' : 'Use English',
    onPressed: disabled ? null : () {},
  ),
  secondary: KitAction(
    label: arabic ? 'إبقاء الحالية' : 'Keep current',
    onPressed: () {},
  ),
  tertiary: [
    KitAction(label: arabic ? 'لغات أخرى' : 'More languages', onPressed: () {}),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in kitGallerySizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_sheet default · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: 'kit_sheet_default_${at}_$mode',
          size: size,
          light: light,
          open: _language,
        );
      });
    }

    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_sheet · 2.0 text · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: 'kit_sheet_text2_${at}_$mode',
          size: size,
          light: light,
          textScale: 2,
          open: _language,
        );
      });
      testWidgets('kit_sheet · ar · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: 'kit_sheet_ar_${at}_$mode',
          size: size,
          light: light,
          locale: const Locale('ar'),
          textScale: 1.3,
          open: (context) => _language(context, arabic: true),
        );
      });
    }

    const phone = Size(412, 915);
    testWidgets('kit_sheet loading · $mode', (tester) async {
      final loading = ValueNotifier(true);
      addTearDown(loading.dispose);
      await kitGalleryShot(
        tester,
        name: 'kit_sheet_loading_$mode',
        size: phone,
        light: light,
        // The loading bar never settles; one frame shows it.
        settleAfterThen: false,
        open: (context) {
          unawaited(_language(context, loading: loading));
          // Stop the bar so the open itself can settle, then show it again.
          loading.value = false;
        },
        then: (tester) async {
          loading.value = true;
          await tester.pump();
        },
      );
    });

    testWidgets('kit_sheet disabled primary · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: 'kit_sheet_disabled_$mode',
        size: phone,
        light: light,
        open: (context) => _language(context, disabled: true),
      );
    });

    testWidgets('kit_sheet discard asked in place · $mode', (tester) async {
      final dirty = ValueNotifier(true);
      addTearDown(dirty.dispose);
      await kitGalleryShot(
        tester,
        name: 'kit_sheet_discard_$mode',
        size: phone,
        light: light,
        open: (context) => _language(context, dirty: dirty),
        then: (tester) async {
          await tester.tap(find.byTooltip('Close'));
        },
      );
    });

    testWidgets('kit_sheet half · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: 'kit_sheet_half_$mode',
        size: phone,
        light: light,
        open: (context) => _language(context, height: KitSheetHeight.half),
      );
    });

    for (final size in const [Size(412, 915), Size(1280, 800)]) {
      final at = kitGallerySize(size);
      testWidgets('kit_sheet full · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: 'kit_sheet_full_${at}_$mode',
          size: size,
          light: light,
          open: (context) => _language(context, height: KitSheetHeight.full),
        );
      });
    }
  }
}
