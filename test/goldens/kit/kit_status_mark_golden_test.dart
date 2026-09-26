// Gallery (gate G4) for KitStatusMark and KitTaskMark v2
// (docs/ux-system/kit-api/KitStatusMark.md): every declared state as it
// sits in a KitRow with its supporting word (slice-P9.5: no state shown by
// colour alone), at the spec's sizes including the 915x412 landscape phone,
// plus the marks drawn standalone, outside a KitRow, with their own visible
// word (showLabel), in English and Arabic.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_status_mark_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

class _Row {
  const _Row({required this.leading, required this.title, required this.word});

  final Widget leading;
  final String title;
  final String word;
}

List<_Row> _rows(bool arabic) => arabic
    ? const [
        _Row(
          leading: KitStatusMark(state: KitMarkState.waiting),
          title: 'الوصول إلى الخادم',
          word: 'بانتظار',
        ),
        _Row(
          leading: KitStatusMark(state: KitMarkState.working),
          title: 'تثبيت الأدوات',
          word: 'يعمل',
        ),
        _Row(
          leading: KitStatusMark(state: KitMarkState.done),
          title: 'الاتصال بالخادم',
          word: 'انتهى',
        ),
        _Row(
          leading: KitStatusMark(state: KitMarkState.failed),
          title: 'التحقق من الشهادة',
          word: 'فشل',
        ),
        _Row(
          leading: KitStatusMark(state: KitMarkState.working, paused: true),
          title: 'تحديث الأدوات',
          word: 'متوقف مؤقتًا',
        ),
        _Row(
          leading: KitTaskMark(state: KitTaskState.needsYou),
          title: 'الموافقة على الترحيل',
          word: 'يحتاجك',
        ),
        _Row(
          leading: KitTaskMark(state: KitTaskState.stopped),
          title: 'إعادة هيكلة المحلل',
          word: 'متوقف',
        ),
      ]
    : const [
        _Row(
          leading: KitStatusMark(state: KitMarkState.waiting),
          title: 'Reach the server',
          word: 'Waiting',
        ),
        _Row(
          leading: KitStatusMark(state: KitMarkState.working),
          title: 'Install the toolchain',
          word: 'Working',
        ),
        _Row(
          leading: KitStatusMark(state: KitMarkState.done),
          title: 'Connect to the server',
          word: 'Done',
        ),
        _Row(
          leading: KitStatusMark(state: KitMarkState.failed),
          title: 'Verify the certificate',
          word: 'Failed',
        ),
        _Row(
          leading: KitStatusMark(state: KitMarkState.working, paused: true),
          title: 'Update the toolchain',
          word: 'Paused',
        ),
        _Row(
          leading: KitTaskMark(state: KitTaskState.needsYou),
          title: 'Approve the migration',
          word: 'Needs you',
        ),
        _Row(
          leading: KitTaskMark(state: KitTaskState.stopped),
          title: 'Refactor the parser',
          word: 'Stopped',
        ),
      ];

/// One sheet of every declared state in a [KitRow], its supporting line
/// starting with the mark's own word (K2 §7 gallery scenes, KIT-12).
Widget _all(bool arabic) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final row in _rows(arabic))
        KitRow(
          leading: row.leading,
          title: row.title,
          supporting: TextSpan(text: row.word),
        ),
    ],
  ),
);

/// The marks standalone, each drawing its own visible word (`showLabel`),
/// as the API doc places it: outside a [KitRow], in a spot that does not
/// already say the state. Here that is a card header: the task's name at
/// the start, its mark and word at the end, read as one line (the header's
/// MergeSemantics, as a real header would). The word follows the mark in
/// reading order, so Arabic mirrors the pair.
///
/// Why merged: G5's textContrast (Flutter's textContrastGuideline) samples
/// a lone Text at 1x device pixels, where a 14 sp word is mostly
/// anti-aliased grey, so an unmerged text2 word that measures 5:1 and more
/// on every pack (theme_roles_test, LOOK-8) fails by luck of its letter
/// shapes. Reported in docs/qa/revamp-kit-KitStatusMark-v2-2026-09-27.
List<(String, Widget)> _labelledMarks(bool arabic) => [
  (
    arabic ? 'الوصول إلى الخادم' : 'Reach the server',
    const KitStatusMark(state: KitMarkState.waiting, showLabel: true),
  ),
  (
    arabic ? 'تثبيت الأدوات' : 'Install the toolchain',
    const KitStatusMark(state: KitMarkState.working, showLabel: true),
  ),
  (
    arabic ? 'الاتصال بالخادم' : 'Connect to the server',
    const KitStatusMark(state: KitMarkState.done, showLabel: true),
  ),
  (
    arabic ? 'التحقق من الشهادة' : 'Verify the certificate',
    const KitStatusMark(state: KitMarkState.failed, showLabel: true),
  ),
  (
    arabic ? 'تحديث الأدوات' : 'Update the toolchain',
    const KitStatusMark(
      state: KitMarkState.working,
      paused: true,
      showLabel: true,
    ),
  ),
  (
    arabic ? 'الموافقة على الترحيل' : 'Approve the migration',
    const KitTaskMark(state: KitTaskState.needsYou, showLabel: true),
  ),
  (
    arabic ? 'إعادة هيكلة المحلل' : 'Refactor the parser',
    const KitTaskMark(state: KitTaskState.stopped, showLabel: true),
  ),
];

Widget _labelled(bool arabic) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (title, mark) in _labelledMarks(arabic))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: MergeSemantics(
            child: Row(
              children: [
                Expanded(child: KitText(title, role: KitTextRole.rowTitle)),
                const SizedBox(width: 12),
                mark,
              ],
            ),
          ),
        ),
    ],
  ),
);

/// The landscape phone the spec's default-sheet list names (915x412).
/// The shared kitGallerySizes has no landscape phone, so this gallery adds
/// it itself.
const _landscapePhone = Size(915, 412);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in [...kitGallerySizes, _landscapePhone]) {
      testWidgets('all states · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_status_mark_all', size, light: light),
          size: size,
          light: light,
          child: _all(false),
        );
      });
    }

    for (final arabic in [false, true]) {
      testWidgets('labelled marks${arabic ? ' · Arabic' : ''} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_status_mark_labelled',
            const Size(412, 915),
            light: light,
            ar: arabic,
          ),
          size: const Size(412, 915),
          light: light,
          locale: arabic ? const Locale('ar') : const Locale('en'),
          child: _labelled(arabic),
        );
      });
    }

    for (final size in kitGalleryScaledSizes) {
      testWidgets('all states · 2.0 text · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_status_mark_all',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _all(false),
        );
      });

      testWidgets('all states · Arabic · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_status_mark_all',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          textScale: 1.3,
          child: _all(true),
        );
      });
    }
  }
}
