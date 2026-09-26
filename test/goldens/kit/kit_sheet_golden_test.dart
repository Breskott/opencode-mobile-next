// Gallery (gate G4) for KitSheet, docs/ux-system/kit-v2.md §1.1 and §8.2,
// and the visual language's sheet header and consequences panel
// (docs/design/visual-language-2026-09-26.md §5 "Sheets"): a bottom sheet
// on phones, capped at 640 dp on a medium window, a centred panel on
// tablets in landscape and PCs, and an end-side sheet for a full-height
// sheet there.
//
// The 800/1280/1600 with-icon and full shots stack KitActionBlock's actions
// (today's part rows only at maxWidth >= 600, which the 560 dp panel never
// reaches): the integrator regenerates them once kit-KitAction-v2 merges
// (README.md decision D4, R07). Everything else here is final.
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

import 'kit_gallery.dart';

const _phone = Size(412, 915);

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
  bool dismissible = true,
  IconData? icon,
  KitSheetTone tone = KitSheetTone.neutral,
}) => showKitSheet<void>(
  context,
  title: arabic ? 'اللغة' : 'Language',
  subtitle: arabic ? 'الكلمات في كل التطبيق' : 'Words across the app',
  height: height,
  loading: loading,
  dirty: dirty,
  dismissible: dismissible,
  icon: icon,
  tone: tone,
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

/// The visual language's consequences panel (§5), shown inside a sheet body
/// wherever the facts belong — here, all three marks on one panel.
Future<void> _consequences(BuildContext context) => showKitSheet<void>(
  context,
  title: 'Delete conversation?',
  subtitle: 'This cannot be undone',
  icon: AppIconography.delete,
  body: (_) => KitConsequences(
    items: const [
      KitConsequence(
        '3 queued prompts will be deleted',
        mark: KitConsequenceMark.lost,
      ),
      KitConsequence(
        'The exported transcript is kept',
        mark: KitConsequenceMark.kept,
      ),
      KitConsequence(
        'This runs in the background',
        mark: KitConsequenceMark.info,
      ),
    ],
  ),
  primary: KitAction(label: 'Delete conversation', onPressed: () {}),
  secondary: KitAction(label: 'Cancel', onPressed: () {}),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    testWidgets('kit_sheet default (no icon) · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_sheet_default', _phone, light: light),
        size: _phone,
        light: light,
        open: _language,
      );
    });

    testWidgets('kit_sheet with_icon · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_sheet_with_icon', _phone, light: light),
        size: _phone,
        light: light,
        open: (context) => _language(context, icon: AppIconography.globe),
      );
    });

    // The LAY-4 sizes, with the short landscape phone swapped in for the
    // usual portrait one (LAY-3: a short window keeps the compact sheet).
    for (final size in [
      for (final size in kitGallerySizes)
        if (size == const Size(412, 915)) const Size(915, 412) else size,
    ]) {
      final at = kitGallerySize(size);
      testWidgets('kit_sheet with_icon · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_sheet_with_icon', size, light: light),
          size: size,
          light: light,
          open: (context) => _language(context, icon: AppIconography.globe),
        );
      });
    }

    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_sheet with_icon · 2.0 text · $at · $mode', (
        tester,
      ) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_sheet_with_icon',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          open: (context) => _language(context, icon: AppIconography.globe),
        );
      });
      testWidgets('kit_sheet with_icon · ar · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_sheet_with_icon',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          textScale: 1.3,
          open: (context) =>
              _language(context, arabic: true, icon: AppIconography.globe),
        );
      });
    }

    testWidgets('kit_sheet consequences · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_sheet_consequences', _phone, light: light),
        size: _phone,
        light: light,
        open: _consequences,
      );
    });

    testWidgets('kit_sheet loading · $mode', (tester) async {
      final loading = ValueNotifier(true);
      addTearDown(loading.dispose);
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_sheet_loading', _phone, light: light),
        size: _phone,
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
        name: kitGalleryName('kit_sheet_disabled', _phone, light: light),
        size: _phone,
        light: light,
        open: (context) => _language(context, disabled: true),
      );
    });

    testWidgets('kit_sheet discard asked in place · $mode', (tester) async {
      final dirty = ValueNotifier(true);
      addTearDown(dirty.dispose);
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_sheet_discard', _phone, light: light),
        size: _phone,
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
        name: kitGalleryName('kit_sheet_half', _phone, light: light),
        size: _phone,
        light: light,
        open: (context) => _language(context, height: KitSheetHeight.half),
      );
    });

    testWidgets('kit_sheet not-dismissible · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_sheet_not_dismissible', _phone, light: light),
        size: _phone,
        light: light,
        open: (context) => _language(context, dismissible: false),
      );
    });

    testWidgets('kit_sheet keyboard-open · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_sheet_keyboard_open', _phone, light: light),
        size: _phone,
        light: light,
        open: (context) => _language(context),
        then: (tester) async {
          // DPR 3.0 here (TEST-9): 300 logical px of keyboard.
          tester.view.viewInsets = const FakeViewPadding(bottom: 900);
          addTearDown(tester.view.resetViewInsets);
        },
      );
    });

    testWidgets('kit_sheet attention · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName('kit_sheet_attention', _phone, light: light),
        size: _phone,
        light: light,
        open: (context) => _language(
          context,
          icon: AppIconography.globe,
          tone: KitSheetTone.attention,
        ),
      );
    });

    testWidgets('kit_sheet full · 1280x800 · $mode', (tester) async {
      await kitGalleryShot(
        tester,
        name: kitGalleryName(
          'kit_sheet_full',
          const Size(1280, 800),
          light: light,
        ),
        size: const Size(1280, 800),
        light: light,
        open: (context) => _language(context, height: KitSheetHeight.full),
      );
    });
  }
}
