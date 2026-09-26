// Gallery (gate G4) for KitStatusMark and KitTaskMark v2
// (docs/ux-system/kit-api/KitStatusMark.md): every declared state as it
// sits in a KitRow with its supporting word (slice-P9.5: no state shown by
// colour alone), plus the marks drawn standalone with their own visible
// word (showLabel).
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

/// The mark carrying its own visible word (`showLabel`) in a [KitRow]'s
/// leading slot, for a row whose title is not the state (a compact layout
/// that does not also spend the supporting line on it).
const _labelledRows = [
  (
    leading: KitStatusMark(state: KitMarkState.waiting, showLabel: true),
    title: 'Reach the server',
  ),
  (
    leading: KitStatusMark(state: KitMarkState.working, showLabel: true),
    title: 'Install the toolchain',
  ),
  (
    leading: KitStatusMark(state: KitMarkState.done, showLabel: true),
    title: 'Connect to the server',
  ),
  (
    leading: KitStatusMark(state: KitMarkState.failed, showLabel: true),
    title: 'Verify the certificate',
  ),
  (
    leading: KitStatusMark(
      state: KitMarkState.working,
      paused: true,
      showLabel: true,
    ),
    title: 'Update the toolchain',
  ),
  (
    leading: KitTaskMark(state: KitTaskState.needsYou, showLabel: true),
    title: 'Approve the migration',
  ),
  (
    leading: KitTaskMark(state: KitTaskState.stopped, showLabel: true),
    title: 'Refactor the parser',
  ),
];

Widget _labelled() => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final row in _labelledRows)
        KitRow(leading: row.leading, title: row.title),
    ],
  ),
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final size in kitGallerySizes) {
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

    testWidgets('labelled marks · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_status_mark_labelled',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _labelled(),
      );
    });

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
