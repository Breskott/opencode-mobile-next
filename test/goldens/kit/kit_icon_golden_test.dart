// Gallery (gate G4) for KitIcon, docs/ux-system/kit-api/KitIcon.md: the
// three designed sizes in each tone, the five AppStatusTone tones beside
// their words, and the duotone navigation glyph with its high-contrast
// fallback.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_icon_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_icon.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';

import 'kit_gallery.dart';

const _toneRows = [
  (KitTextTone.primary, 'Primary', 'أساسي'),
  (KitTextTone.secondary, 'Secondary', 'ثانوي'),
  (KitTextTone.accent, 'Accent', 'مميز'),
  (KitTextTone.success, 'Success', 'نجاح'),
  (KitTextTone.danger, 'Danger', 'خطر'),
];

String _sizeLabel(KitIconSize size, bool arabic) => switch (size) {
  KitIconSize.small => arabic ? 'صغير · 20' : 'Small · 20',
  KitIconSize.medium => arabic ? 'متوسط · 22' : 'Medium · 22',
  KitIconSize.large => arabic ? 'كبير · 24' : 'Large · 24',
};

/// One glyph at 20, 22 and 24, in each tone (KitIcon.md "Galleries
/// required").
Widget _sizesScene({bool arabic = false}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  mainAxisSize: MainAxisSize.min,
  children: [
    for (final size in KitIconSize.values)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KitText(_sizeLabel(size, arabic), role: KitTextRole.label),
            const SizedBox(height: 6),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                for (final (tone, en, ar) in _toneRows)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KitIcon(AppIconography.star, size: size, tone: tone),
                      const SizedBox(height: 4),
                      KitText(
                        arabic ? ar : en,
                        role: KitTextRole.caption,
                        tone: KitTextTone.secondary,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
  ],
);

const _statusRows = [
  (AppStatusTone.neutral, 'Idle', 'خامل'),
  (AppStatusTone.progress, 'Connecting…', 'جارٍ الاتصال…'),
  (AppStatusTone.ok, 'Connected', 'متصل'),
  (AppStatusTone.attention, 'Needs a key', 'يحتاج مفتاحاً'),
  (AppStatusTone.failure, 'Could not connect', 'تعذّر الاتصال'),
];

/// The five statuses beside their words (KitIcon.md "States": `status`).
Widget _statusScene({bool arabic = false}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  mainAxisSize: MainAxisSize.min,
  children: [
    for (final (status, en, ar) in _statusRows)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            KitIcon.status(AppIconography.info, status),
            const SizedBox(width: 10),
            KitText(arabic ? ar : en, role: KitTextRole.body),
          ],
        ),
      ),
  ],
);

/// A selected navigation glyph and its high-contrast fallback (KitIcon.md
/// "States": duotone; "Duotone glyphs" under Public API).
Widget _duotoneScene({bool arabic = false}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  mainAxisSize: MainAxisSize.min,
  children: [
    Row(
      children: [
        const KitIcon(AppIconography.workspaceSelected),
        const SizedBox(width: 12),
        KitText(
          arabic ? 'مختار (طبقتان)' : 'Selected (two layers)',
          role: KitTextRole.body,
        ),
      ],
    ),
    const SizedBox(height: 10),
    Row(
      children: [
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(highContrast: true),
            child: const KitIcon(AppIconography.workspaceSelected),
          ),
        ),
        const SizedBox(width: 12),
        KitText(
          arabic ? 'التباين العالي (طبقة واحدة)' : 'High contrast (one layer)',
          role: KitTextRole.body,
        ),
      ],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    // `sizes`, the default state, at every LAY-4 gallery size.
    for (final size in kitGallerySizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_icon sizes · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_icon_sizes', size, light: light),
          size: size,
          light: light,
          child: _sizesScene(),
        );
      });
    }

    // `status` and `duotone`, at the default size only.
    testWidgets('kit_icon status · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_icon_status',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _statusScene(),
      );
    });
    testWidgets('kit_icon duotone · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_icon_duotone',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _duotoneScene(),
      );
    });

    // `sizes` and `status` at 2.0 text and in Arabic, at the two scaled
    // sizes.
    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_icon sizes · text2 · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_icon_sizes',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _sizesScene(),
        );
      });
      testWidgets('kit_icon sizes · ar · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_icon_sizes', size, light: light, ar: true),
          size: size,
          light: light,
          locale: const Locale('ar'),
          child: _sizesScene(arabic: true),
        );
      });
      testWidgets('kit_icon status · text2 · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_icon_status',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _statusScene(),
        );
      });
      testWidgets('kit_icon status · ar · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_icon_status', size, light: light, ar: true),
          size: size,
          light: light,
          locale: const Locale('ar'),
          child: _statusScene(arabic: true),
        );
      });
    }
  }
}
