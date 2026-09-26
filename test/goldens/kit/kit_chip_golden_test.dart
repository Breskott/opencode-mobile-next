// Gallery (gate G4) for KitChip and KitChipWrap
// (docs/ux-system/kit-api/KitChip.md): five kinds — plain, action,
// removable, count, summary — one of each in a KitChipWrap, shown on
// `ground` and on `surface1` (KitChip.md "Galleries required"), at 412x915
// and 1280x800 only, English only (owner decision 2026-09-27).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_chip_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/kit_chip.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import '../../../tool/capture/fixtures.dart' show captureTheme;
import 'kit_gallery.dart';

/// One of each [KitChipKind] (KitChip.md "Purpose").
List<Widget> _chips({bool? selected, bool? expanded, int count = 3}) => [
  const KitChip(label: 'main'),
  KitChip.action(
    label: 'Open in terminal',
    onPressed: () {},
    selected: selected,
  ),
  KitChip.removable(label: 'file.txt', onRemove: () {}),
  KitChip.count(label: 'Tasks', count: count),
  KitChip.summary(
    label: 'Read 3 files · edited 1',
    onPressed: () {},
    expanded: expanded,
  ),
];

/// The required scene (KitChip.md "Galleries required"): a [KitChipWrap] on
/// `ground`, then the same on `surface1`.
Widget _scene(List<Widget> chips) => Builder(
  builder: (context) {
    final roles = KitTokens.of(context).roles;
    Widget level(Color color) => ColoredBox(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: KitChipWrap(children: chips),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [level(roles.ground), level(roles.surface1)],
    );
  },
);

/// A scene of two action chips (selected on and off) so the STATE.md
/// "selected" row is visible without the other four kinds crowding it.
Widget _selectedScene() => _scene([
  KitChip.action(label: 'Ask first', onPressed: () {}, selected: true),
  KitChip.action(label: 'Ask first', onPressed: () {}, selected: false),
]);

/// A scene of two summary chips (open and folded).
Widget _expandedScene() => _scene([
  KitChip.summary(
    label: 'Read 3 files · edited 1',
    onPressed: () {},
    expanded: true,
  ),
  KitChip.summary(
    label: 'Read 3 files · edited 1',
    onPressed: () {},
    expanded: false,
  ),
]);

const _long =
    'A genuinely long label that will never fit inside this short chip';

/// Every kind with a long label, each capped to 160 dp so it must
/// ellipsise (A11Y-8: "a chip may truncate").
Widget _truncatedScene() {
  Widget capped(Widget chip) => SizedBox(width: 160, child: chip);
  return _scene([
    capped(const KitChip(label: _long)),
    capped(KitChip.action(label: _long, onPressed: () {})),
    capped(KitChip.removable(label: _long, onRemove: () {})),
    capped(KitChip.count(label: _long, count: 42)),
    capped(KitChip.summary(label: _long, onPressed: () {})),
  ]);
}

/// The `focused` state (a keyboard focus ring on a removable chip's ×):
/// [kitGalleryPart] has no interaction hook, so this shot pumps its own
/// small app, Tabs to the × and settles before comparing. It does not run
/// the shared G5 accessibility scan ([expectKitGalleryAccessible] is
/// private to kit_gallery.dart, R06); every other shot in this file does.
Future<void> _focusedShot(WidgetTester tester, {required bool light}) async {
  final name = kitGalleryName(
    'kit_chip_focused',
    const Size(412, 915),
    light: light,
  );
  tester.view.physicalSize = const Size(412, 915) * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: captureTheme(light: light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: KitChip.removable(label: 'file.txt', onRemove: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    testWidgets('kit_chip default · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_chip_default',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _scene(_chips()),
      );
    });

    testWidgets('kit_chip selected · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_chip_selected',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _selectedScene(),
      );
    });

    testWidgets('kit_chip expanded · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_chip_expanded',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _expandedScene(),
      );
    });

    testWidgets('kit_chip truncated · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_chip_truncated',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: _truncatedScene(),
      );
    });

    testWidgets('kit_chip focused · $mode', (tester) async {
      await _focusedShot(tester, light: light);
    });

    // Owner decision 2026-09-27 (STANDARDS.md, commit 97975859): galleries
    // at the phone size and one wide size only, and no Arabic or RTL shots.
    testWidgets('kit_chip default · 1280x800 · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_chip_default',
          const Size(1280, 800),
          light: light,
        ),
        size: const Size(1280, 800),
        light: light,
        child: _scene(_chips()),
      );
    });

    for (final size in kitGalleryScaledSizes) {
      final at = kitGallerySize(size);
      testWidgets('kit_chip default · 2.0 text · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_chip_default',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: _scene(_chips()),
        );
      });
    }
  }
}
