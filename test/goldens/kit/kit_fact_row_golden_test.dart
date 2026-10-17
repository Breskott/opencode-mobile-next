// Gallery (gate G4) for KitFactRow (docs/ux-system/kit-api/KitFactRow.md):
// told, read from a source, guessed and worked out, a guess waiting for the
// person with its two answers, a search hit, and the same in Arabic with an
// amount and a card ending kept left to right. At 412x915 and 1280x800, dark
// and light, and at 2.0 text.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_fact_row_golden_test.dart
// and look at every changed image before committing it.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

final _now = DateTime(2026, 10, 11, 12);

Widget _facts() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    KitFactRow(
      text: 'Annual fee is [AMOUNT] CUR.',
      provenance: KitProvenance.told,
      observedAt: DateTime(2026, 9, 12),
    ),
    KitFactRow(
      text: 'Statement is due on the 15th of each month.',
      provenance: KitProvenance.seen,
      source: 'a shared message',
      observedAt: DateTime(2026, 10, 3),
    ),
    KitFactRow(
      text: 'Used for groceries.',
      provenance: KitProvenance.guessed,
      source: 'a chat you saved',
      observedAt: DateTime(2026, 10, 9),
    ),
    KitFactRow(
      text: 'Total spend this year is [AMOUNT] CUR.',
      provenance: KitProvenance.calculated,
      observedAt: DateTime(2026, 10, 9),
    ),
  ],
);

Widget _waiting() => KitFactRow(
  text: 'Probably pays the electricity bill by card ••42.',
  provenance: KitProvenance.guessed,
  source: 'a chat you saved',
  observedAt: DateTime(2026, 10, 9),
  waitingForOk: true,
  answers: [
    KitAction(label: 'Yes, keep it', onPressed: () {}),
    KitAction(label: 'Not right', onPressed: () {}),
  ],
);

Widget _hits() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    KitFactRow(
      title: 'Dentist',
      text: 'Dentist appointment Wed 21 Oct 10:00. Bring the insurance card.',
      provenance: KitProvenance.told,
      observedAt: DateTime(2026, 10, 8),
      open: () {},
    ),
    KitFactRow(
      title: 'Planning the dentist visit',
      text: 'Saved chat: "book the dentist before the trip".',
      provenance: KitProvenance.seen,
      source: 'a chat you saved',
      observedAt: DateTime(2026, 10, 3),
      open: () {},
    ),
  ],
);

Widget _arabic() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    KitFactRow(
      text: 'الرسوم السنوية لبطاقة [Bank A] Visa ••42 هي [AMOUNT] CUR',
      provenance: KitProvenance.told,
      observedAt: DateTime(2026, 9, 12),
    ),
    KitFactRow(
      text: 'موعد طبيب الأسنان يوم 21/10 الساعة 10:00',
      provenance: KitProvenance.seen,
      source: 'نص شاركته',
      observedAt: DateTime(2026, 10, 8),
    ),
    KitFactRow(
      text: 'ربما يدفع سام فاتورة الكهرباء ببطاقة ••42',
      provenance: KitProvenance.guessed,
      source: 'محادثة حفظتها',
      observedAt: DateTime(2026, 10, 9),
      waitingForOk: true,
    ),
  ],
);

final _scenes = <String, Widget Function()>{
  'default': _facts,
  'waiting': _waiting,
  'hits': _hits,
};

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final MapEntry(key: scene, value: build) in _scenes.entries) {
      for (final size in kitGalleryScaledSizes) {
        testWidgets('$scene · ${kitGallerySize(size)} · $mode', (tester) async {
          await withClock(Clock.fixed(_now), () async {
            await kitGalleryPart(
              tester,
              name: kitGalleryName('kit_fact_row_$scene', size, light: light),
              size: size,
              light: light,
              child: build(),
            );
          });
        });
      }
    }
  }

  for (final size in kitGalleryScaledSizes) {
    testWidgets('default · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await withClock(Clock.fixed(_now), () async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_fact_row_default',
            size,
            light: false,
            text2: true,
          ),
          size: size,
          light: false,
          textScale: 2,
          child: _facts(),
        );
      });
    });
    testWidgets('Arabic · ${kitGallerySize(size)} · dark', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_fact_row_arabic',
            size,
            light: false,
            ar: true,
          ),
          size: size,
          light: false,
          locale: const Locale('ar'),
          child: _arabic(),
        );
      });
    });
  }
}
