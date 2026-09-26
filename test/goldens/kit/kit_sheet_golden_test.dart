// Gallery (gate G4) for KitSheet, docs/ux-system/kit-v2.md §1.1 and §8.2,
// and the visual language's sheet header and consequences panel
// (docs/design/visual-language-2026-09-26.md §5 "Sheets"): a bottom sheet
// on phones, capped at 640 dp on a medium window, a centred panel on
// tablets in landscape and PCs, and an end-side sheet for a full-height
// sheet there.
//
// The 1280x800 with-icon and full shots stack KitActionBlock's actions
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

const _rows = [
  (AppIconography.check, 'English', 'The phone’s language'),
  (AppIconography.info, 'العربية', 'Arabic'),
  (AppIconography.info, 'Deutsch', 'German'),
];

Widget _body(BuildContext context) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final (icon, title, supporting) in _rows)
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
  KitSheetHeight height = KitSheetHeight.content,
  ValueListenable<bool>? loading,
  bool disabled = false,
  ValueListenable<bool>? dirty,
  bool dismissible = true,
  IconData? icon,
  KitSheetTone tone = KitSheetTone.neutral,
}) => showKitSheet<void>(
  context,
  title: 'Language',
  subtitle: 'Words across the app',
  height: height,
  loading: loading,
  dirty: dirty,
  dismissible: dismissible,
  icon: icon,
  tone: tone,
  body: _body,
  primary: KitAction(label: 'Use English', onPressed: disabled ? null : () {}),
  secondary: KitAction(label: 'Keep current', onPressed: () {}),
  tertiary: [KitAction(label: 'More languages', onPressed: () {})],
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

    // Owner decision 2026-09-27 (STANDARDS.md header, harness RULES): no
    // Arabic/RTL galleries, and galleries at the phone (412x915) and one
    // wide size (1280x800) only. kitGalleryScaledSizes is exactly that
    // pair; 412x915 is the with_icon shot above.
    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      if (size != _phone) {
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
