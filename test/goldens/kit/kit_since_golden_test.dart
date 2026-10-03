// Gallery (gate G4) for KitSince (docs/ux-system/kit-api/KitSince.md): the
// part draws nothing itself, so this renders the minimal host the spec
// names — a KitText line driven by KitSince — in its three phases:
// "Connecting…" (waiting), "Still waiting after 8 s" (slow) and, with
// ticks: minutes, "Waiting 4 min".
//
// Every `since` here is offset from `clock.now()` by a fixed Duration, so
// the rendered words never depend on the wall clock (TEST-11): the same
// image comes out whenever this is regenerated.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_since_golden_test.dart
// and look at every changed image before committing it.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_motion.dart';
import 'package:opencode_mobile/ui/kit/kit_since.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';

import 'kit_gallery.dart';

/// The minimal host KitSince.md's "Galleries required" names: one KitText
/// line whose words come from the host's own phase-to-copy mapping, exactly
/// as a real host (KitStateView, KitStatusLine, KitReceipt, …) would do it.
Widget _sinceLine({
  required DateTime? since,
  KitSinceTicks ticks = KitSinceTicks.none,
}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 20),
  child: KitSince(
    since: since,
    ticks: ticks,
    builder: (context, status) {
      final text = switch (status.phase) {
        KitSincePhase.idle => '',
        KitSincePhase.waiting => 'Connecting…',
        KitSincePhase.slow =>
          ticks == KitSinceTicks.minutes
              ? KitSince.waitingLabel(context, status.elapsed)
              : KitSince.slowLabel(context),
      };
      return KitText(text, role: KitTextRole.secondary);
    },
  ),
);

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    // Waiting: "Connecting…", well clear of the 8 s escalation.
    testWidgets('connecting (waiting) · $mode', (tester) async {
      final since = clock.now();
      await tester.pumpWidget(const SizedBox.shrink());
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_since_connecting',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _sinceLine(since: since),
      );
    });

    // Slow: "Still waiting after 8 s", at every kit-v2.md §8.4 size (a
    // superset of the 412x915, 360x800 and 1280x800 KitSince.md names).
    for (final size in kitGallerySizes) {
      testWidgets('slow · ${kitGallerySize(size)} · $mode', (tester) async {
        final since = clock.now().subtract(
          KitMotion.escalateAfter * 2,
        ); // well past 8 s
        await tester.pumpWidget(const SizedBox.shrink());
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_since_slow', size, light: light),
          size: size,
          light: light,
          child: _sinceLine(since: since),
        );
      });
    }

    // ticks: minutes at 4 min, plus 2.0 text and Arabic at 412 and 1280 to
    // catch the plural and its wrapping.
    testWidgets('ticks: minutes at 4 min · $mode', (tester) async {
      final since = clock.now().subtract(const Duration(minutes: 4));
      await tester.pumpWidget(const SizedBox.shrink());
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_since_minutes',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _sinceLine(since: since, ticks: KitSinceTicks.minutes),
      );
    });

    for (final size in kitGalleryScaledSizes) {
      testWidgets(
        'ticks: minutes at 4 min · 2.0 text · ${kitGallerySize(size)} · $mode',
        (tester) async {
          final since = clock.now().subtract(const Duration(minutes: 4));
          await tester.pumpWidget(const SizedBox.shrink());
          await kitGalleryPart(
            tester,
            name: kitGalleryName(
              'kit_since_minutes',
              size,
              light: light,
              text2: true,
            ),
            size: size,
            light: light,
            textScale: 2,
            child: _sinceLine(since: since, ticks: KitSinceTicks.minutes),
          );
        },
      );

      testWidgets(
        'ticks: minutes at 4 min · Arabic · ${kitGallerySize(size)} · $mode',
        (tester) async {
          final since = clock.now().subtract(const Duration(minutes: 4));
          await tester.pumpWidget(const SizedBox.shrink());
          await kitGalleryPart(
            tester,
            name: kitGalleryName(
              'kit_since_minutes',
              size,
              light: light,
              ar: true,
            ),
            size: size,
            light: light,
            locale: const Locale('ar'),
            textScale: 1.3,
            child: _sinceLine(since: since, ticks: KitSinceTicks.minutes),
          );
        },
      );
    }
  }
}
