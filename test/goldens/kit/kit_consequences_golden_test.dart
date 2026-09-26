// Gallery (gate G4) for KitConsequences, docs/design/visual-language-
// 2026-09-26.md §5 "Sheets": the counted-facts panel a sheet body places
// wherever the facts belong — lost (danger), kept and info, on one panel
// with hairlines inset to the words. No declared states (KIT-12): it only
// ever shows the facts it is given.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_consequences_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

List<KitConsequence> _items(bool arabic) => arabic
    ? const [
        KitConsequence(
          'سيتم حذف 3 مطالبات قيد الانتظار',
          mark: KitConsequenceMark.lost,
        ),
        KitConsequence(
          'يتم الاحتفاظ بالنسخة المصدَّرة',
          mark: KitConsequenceMark.kept,
        ),
        KitConsequence('يعمل هذا في الخلفية'),
      ]
    : const [
        KitConsequence(
          '3 queued prompts will be deleted',
          mark: KitConsequenceMark.lost,
        ),
        KitConsequence(
          'The exported transcript is kept',
          mark: KitConsequenceMark.kept,
        ),
        KitConsequence('This runs in the background'),
      ];

/// Opens a plain screen with the panel on it: [kitGalleryShot] compares the
/// whole window, and the part is not a modal, so a pushed page stands in
/// for "the caller's screen" the way one would host it.
void _open(BuildContext context, {bool arabic = false}) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: KitConsequences(items: _items(arabic)),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in kitGallerySizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_consequences default · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_consequences_default', size, light: light),
          size: size,
          light: light,
          open: _open,
        );
      });
    }

    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_consequences · 2.0 text · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_consequences_default',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          open: _open,
        );
      });
      testWidgets('kit_consequences · ar · $at · $mode', (tester) async {
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_consequences_default',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          textScale: 1.3,
          open: (context) => _open(context, arabic: true),
        );
      });
    }
  }
}
