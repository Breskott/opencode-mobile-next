// Gallery (gate G4) for KitArrival, docs/ux-system/kit-api/KitArrival.md:
// Settings › Appearance › Effects opened by the search result "vibration",
// the Vibration row arrived at and washed. The shot is taken while the
// wash holds (reduced motion, as every gallery renders: no scroll, no fade).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_arrival_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Widget _effects() => Builder(
  builder: (context) {
    Widget row(String id, IconData icon, String title, String detail) =>
        KitArrival(
          id: id,
          child: KitSwitchRow(
            leading: KitRow.icon(context, icon),
            title: title,
            supporting: detail,
            value: true,
            onChanged: (_) {},
          ),
        );
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        KitRowGroup(
          label: 'Effects',
          children: [
            row(
              'effects-glass',
              AppIconography.layers,
              'Glass',
              'Bars and sheets float over what is behind them',
            ),
            row(
              'effects-celebrations',
              AppIconography.sparkle,
              'Celebrations',
              'A short moment when setup finishes or a task merges',
            ),
            row(
              'effects-vibration',
              AppIconography.touch,
              'Vibration',
              'A light tap when you send, and when a run finishes',
            ),
          ],
        ),
      ],
    );
  },
);

/// Opens Effects arrived at Vibration over the gallery's empty screen.
Future<void> _arrive(WidgetTester tester, BuildContext host) async {
  Navigator.of(host).push(
    PageRouteBuilder<void>(
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, _, _) => Scaffold(
        body: KitArrivalScope(rowId: 'effects-vibration', child: _effects()),
      ),
    ),
  );
  // Settling runs frames only; the wash's hold timer is not reached, so
  // the shot shows the held mark.
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_arrival marked · $at · $mode', (tester) async {
        late BuildContext host;
        await kitGalleryShot(
          tester,
          name: kitGalleryName('kit_arrival_marked', size, light: light),
          size: size,
          light: light,
          open: (context) => host = context,
          then: (tester) => _arrive(tester, host),
        );
      });

      testWidgets('kit_arrival marked · 2.0 text · $at · $mode', (
        tester,
      ) async {
        late BuildContext host;
        await kitGalleryShot(
          tester,
          name: kitGalleryName(
            'kit_arrival_marked',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          open: (context) => host = context,
          then: (tester) => _arrive(tester, host),
        );
      });
    }
  }
}
