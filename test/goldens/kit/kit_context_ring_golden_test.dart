// Gallery (gate G4) for KitContextRing (docs/ux-system/kit-api/
// KitContextRing.md): the ring at each level, compacting, the list's form
// and the ring in the chat top bar, left of the overflow.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_context_ring_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_gallery.dart';

Widget _panel(List<Widget> children) => Builder(
  builder: (context) {
    final tokens = KitTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.fillOf(KitSurfaceLevel.surface2),
        borderRadius: BorderRadius.circular(tokens.panelCornerRadius),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.space5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: tokens.space3,
          children: children,
        ),
      ),
    );
  },
);

Widget _bar(double used, {bool compacting = false}) =>
    KitContextRing(used: used, compacting: compacting, openDetails: () {});

Widget _large(double used) =>
    KitContextRing(used: used, size: KitContextRingSize.large);

Widget _row(double used) =>
    KitContextRing(used: used, size: KitContextRingSize.row);

Widget _topBar(double used) => KitTopBar(
  title: 'Fix the login bug',
  subtitle: 'Working',
  exit: KitTopBarExit.none,
  accessory: _bar(used),
  menu: [KitMenuItem(label: 'Rename', onSelected: () {})],
  menuLabel: 'Conversation menu',
);

final _states = <String, Widget Function()>{
  'calm': () => _panel([_bar(0.42), _large(0.42), _row(0.42)]),
  'warning': () => _panel([_bar(0.78), _large(0.78), _row(0.78)]),
  'full': () => _panel([_bar(0.97), _large(0.97), _row(0.97)]),
  'compacting': () => _panel([_bar(0.85, compacting: true), _large(0.85)]),
  'top_bar': () => _topBar(0.78),
};

const _otherSizes = <Size>[Size(360, 800), Size(1280, 800)];

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final MapEntry(key: state, value: build) in _states.entries) {
      testWidgets('$state · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_context_ring_$state',
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          child: build(),
        );
      });
    }
    for (final size in _otherSizes) {
      testWidgets('warning · ${kitGallerySize(size)} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_context_ring_warning', size, light: light),
          size: size,
          light: light,
          child: _states['warning']!(),
        );
      });
    }
  }

  for (final size in const [Size(412, 915), Size(1280, 800)]) {
    testWidgets('compacting · 2.0 text · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_context_ring_compacting',
          size,
          light: false,
          text2: true,
        ),
        size: size,
        light: false,
        textScale: 2,
        child: _states['compacting']!(),
      );
    });
    testWidgets('top bar · Arabic · ${kitGallerySize(size)} · dark', (
      tester,
    ) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_context_ring_top_bar',
          size,
          light: false,
          ar: true,
        ),
        size: size,
        light: false,
        locale: const Locale('ar'),
        textScale: 1.3,
        child: _states['top_bar']!(),
      );
    });
  }
}
