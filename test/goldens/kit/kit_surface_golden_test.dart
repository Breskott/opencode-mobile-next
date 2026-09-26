// Gallery (gate G4) for KitSurface, docs/ux-system/kit-api/KitSurface.md:
// the one solid box — a fill from the surface steps, a token shape and
// padding, an optional hairline edge, and the `panel`, `inset` and `tile`
// forms.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_surface_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit_surface.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import 'kit_gallery.dart';

class _Copy {
  const _Copy({
    required this.cardTitle,
    required this.cardMeta,
    required this.plain,
    required this.sheetTitle,
    required this.sheetConsequence,
    required this.terminal,
    required this.warning,
    required this.done,
  });

  final String cardTitle;
  final String cardMeta;
  final String plain;
  final String sheetTitle;
  final String sheetConsequence;
  final String terminal;
  final String warning;
  final String done;
}

const _en = _Copy(
  cardTitle: 'Fix flaky checkout test',
  cardMeta: 'Editing workflow files · 4 min',
  plain: 'No header here, just the child content.',
  sheetTitle: 'Delete workspace fox?',
  sheetConsequence: '3 queued messages will be discarded.',
  terminal: 'Terminal',
  warning: 'Warning',
  done: 'Done',
);

const _ar = _Copy(
  cardTitle: 'إصلاح اختبار الدفع المتقطع',
  cardMeta: 'تعديل ملفات سير العمل · 4 د',
  plain: 'لا عنوان هنا، محتوى فرعي فقط.',
  sheetTitle: 'حذف مساحة العمل fox؟',
  sheetConsequence: 'ستُحذف 3 رسائل في قائمة الانتظار.',
  terminal: 'طرفية',
  warning: 'تحذير',
  done: 'تم',
);

Widget _levelBox(KitSurfaceLevel level, {required bool outlined}) => SizedBox(
  width: 96,
  height: 56,
  child: KitSurface(
    level: level,
    outlined: outlined,
    padding: KitSurfacePadding.none,
    child: const SizedBox.expand(),
  ),
);

Widget _levels() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final level in KitSurfaceLevel.values) ...[
      KitText(level.name, role: KitTextRole.label),
      const SizedBox(height: 8),
      Row(
        children: [
          _levelBox(level, outlined: false),
          const SizedBox(width: 12),
          _levelBox(level, outlined: true),
        ],
      ),
      const SizedBox(height: 16),
    ],
  ],
);

Widget _shapes() => Wrap(
  spacing: 12,
  runSpacing: 12,
  children: [
    for (final shape in KitShape.values)
      SizedBox(
        width: 72,
        height: 72,
        child: KitSurface(
          shape: shape,
          level: KitSurfaceLevel.surface2,
          padding: KitSurfacePadding.none,
          child: const SizedBox.expand(),
        ),
      ),
  ],
);

Widget _panel(_Copy copy) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    KitSurface.panel(
      title: copy.cardTitle,
      icon: AppIconography.terminal,
      child: KitText(copy.cardMeta, role: KitTextRole.secondary),
    ),
    const SizedBox(height: 16),
    KitSurface.panel(child: KitText(copy.plain, role: KitTextRole.body)),
  ],
);

Widget _inset(_Copy copy) => KitSurface(
  level: KitSurfaceLevel.surface2,
  shape: KitShape.sheet,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      KitText(copy.sheetTitle, role: KitTextRole.title),
      const SizedBox(height: 12),
      KitSurface.inset(
        child: KitText(copy.sheetConsequence, role: KitTextRole.secondary),
      ),
    ],
  ),
);

Widget _tiles(_Copy copy) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    KitSurface.tile(AppIconography.terminal, semanticsLabel: copy.terminal),
    const SizedBox(width: 12),
    KitSurface.tile(
      AppIconography.warning,
      tone: KitTextTone.danger,
      semanticsLabel: copy.warning,
    ),
    const SizedBox(width: 12),
    KitSurface.tile(
      AppIconography.check,
      tone: KitTextTone.success,
      semanticsLabel: copy.done,
    ),
  ],
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    // States, at 412x915: levels, shapes, panel, inset, tile.
    testWidgets('surface · levels · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_surface_levels',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _levels(),
      );
    });

    testWidgets('surface · shapes · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_surface_shapes',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _shapes(),
      );
    });

    testWidgets('surface · panel · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_surface_panel',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _panel(_en),
      );
    });

    testWidgets('surface · inset · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_surface_inset',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _inset(_en),
      );
    });

    testWidgets('surface · tile · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_surface_tile',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _tiles(_en),
      );
    });

    // Default state (panel) at the other LAY-4 sizes.
    for (final size in kitGallerySizes) {
      if (size == const Size(412, 915)) continue;
      final at = kitGallerySize(size);
      testWidgets('surface · panel · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_surface_panel', size, light: light),
          size: size,
          light: light,
          child: _panel(_en),
        );
      });
    }

    // _text2 and _ar: panel and tile at 412x915 and 1280x800.
    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('surface · panel · text2 · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_surface_panel',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _panel(_en),
        );
      });

      testWidgets('surface · tile · text2 · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_surface_tile',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _tiles(_en),
        );
      });

      testWidgets('surface · panel · Arabic · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_surface_panel',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          textScale: 1.3,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: _panel(_ar),
          ),
        );
      });

      testWidgets('surface · tile · Arabic · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_surface_tile',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          textScale: 1.3,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: _tiles(_ar),
          ),
        );
      });
    }
  }
}
