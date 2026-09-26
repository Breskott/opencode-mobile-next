// Gallery (gate G4) for KitIcon, docs/ux-system/kit-api/KitIcon.md: the
// three designed sizes in each tone, the five AppStatusTone tones beside
// their words, and the duotone navigation glyph with its high-contrast
// fallback. Every scene carries a direction row (back and a chevron, which
// mirror under RTL, beside check, which does not), so the Arabic shots show
// LAY-8 mirroring at render time, and a brand-mark shot shows KitBrandMark
// at its two sizes. After every shot, each glyph's global rect must land on
// whole physical pixels at DPR 3 (VL §7: no half-pixel edges).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_icon_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_icon.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';

import 'kit_gallery.dart';

/// The 16 px side gutter every scene sits in (LAY-4).
Widget _gutter(Widget child) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

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

const _directionRows = [
  (AppIconography.back, 'Back', 'رجوع'),
  (AppIconography.chevronRight, 'Open', 'فتح'),
  (AppIconography.forward, 'Forward', 'تقدّم'),
  (AppIconography.check, 'Done (never mirrors)', 'تم (لا ينعكس)'),
];

/// Directional glyphs beside one that never mirrors (KitIcon.md "Galleries
/// required": the Arabic shot shows mirrored directional glyphs; LAY-8).
Widget _directionRow({required bool arabic}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 10),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      KitText(arabic ? 'الاتجاه' : 'Direction', role: KitTextRole.label),
      const SizedBox(height: 6),
      Wrap(
        spacing: 20,
        runSpacing: 10,
        children: [
          for (final (glyph, en, ar) in _directionRows)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                KitIcon(glyph),
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
);

/// One glyph at 20, 22 and 24, in each tone (KitIcon.md "Galleries
/// required"), then the direction row.
Widget _sizesScene({bool arabic = false}) => _gutter(
  Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      _directionRow(arabic: arabic),
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
  ),
);

const _statusRows = [
  (AppStatusTone.neutral, 'Idle', 'خامل'),
  (AppStatusTone.progress, 'Connecting…', 'جارٍ الاتصال…'),
  (AppStatusTone.ok, 'Connected', 'متصل'),
  (AppStatusTone.attention, 'Needs a key', 'يحتاج مفتاحاً'),
  (AppStatusTone.failure, 'Could not connect', 'تعذّر الاتصال'),
];

/// The five statuses beside their words (KitIcon.md "States": `status`),
/// then the direction row.
Widget _statusScene({bool arabic = false}) => _gutter(
  Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      _directionRow(arabic: arabic),
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
  ),
);

/// A selected navigation glyph and its high-contrast fallback (KitIcon.md
/// "States": duotone; "Duotone glyphs" under Public API).
Widget _duotoneScene({bool arabic = false}) => _gutter(
  Column(
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
            arabic
                ? 'التباين العالي (طبقة واحدة)'
                : 'High contrast (one layer)',
            role: KitTextRole.body,
          ),
        ],
      ),
    ],
  ),
);

/// KitBrandMark at its two sizes: the row tile (30) and the standalone
/// mark (44).
Widget _brandScene() => _gutter(
  Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (size, words) in [
        (KitBrandMarkSize.tile, 'Tile · 30'),
        (KitBrandMarkSize.mark, 'Mark · 44'),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              KitBrandMark(size: size),
              const SizedBox(width: 12),
              KitText(words, role: KitTextRole.body),
            ],
          ),
        ),
    ],
  ),
);

/// VL §7 ("aligned to whole pixels"; "a golden that shows ... a half-pixel
/// offset is a bug"): every glyph and brand mark on screen has its global
/// rect on whole physical pixels at the gallery's DPR.
void _expectPixelAligned(WidgetTester tester) {
  final dpr = tester.view.devicePixelRatio;
  final glyphs = [
    ...find.byType(Icon).evaluate(),
    ...find.byType(SvgPicture).evaluate(),
  ];
  expect(glyphs, isNotEmpty);
  for (final element in glyphs) {
    final box = element.renderObject! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    for (final (edge, value) in [
      ('left', rect.left),
      ('top', rect.top),
      ('right', rect.right),
      ('bottom', rect.bottom),
    ]) {
      final physical = value * dpr;
      expect(
        (physical - physical.roundToDouble()).abs(),
        lessThan(1e-3),
        reason:
            '${element.widget} $edge edge at $value logical = $physical '
            'physical px (DPR $dpr) is not a whole pixel',
      );
    }
  }
}

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
        _expectPixelAligned(tester);
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
      _expectPixelAligned(tester);
    });
    testWidgets('kit_icon brand · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_icon_brand',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _brandScene(),
      );
      _expectPixelAligned(tester);
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
      _expectPixelAligned(tester);
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
        _expectPixelAligned(tester);
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
        _expectPixelAligned(tester);
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
        _expectPixelAligned(tester);
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
        _expectPixelAligned(tester);
      });
    }
  }
}
