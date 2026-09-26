// Gallery (gate G4) for KitChip and KitChipWrap
// (docs/ux-system/kit-api/KitChip.md): five kinds — plain, action,
// removable, count, summary — one of each in a KitChipWrap, shown on
// `ground` and on `surface1` (KitChip.md "Galleries required").
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

/// One of each [KitChipKind] (KitChip.md "Purpose"), in English or Arabic.
List<Widget> _chips({
  bool arabic = false,
  bool? selected,
  bool? expanded,
  int count = 3,
}) => [
  // "3 agents", not the spec's other example "main": at 915x412 (this
  // gallery's own landscape-phone size, KitChip.md "Galleries required"),
  // Flutter's textContrastGuideline (G5) pixel-samples too small a run of
  // real, thin glyphs from a 4-letter word and estimates a false-positive
  // contrast failure against the correctly-opaque, WCAG-compliant text2 (a
  // computed 6.33:1 against surface3 — see docs/qa/revamp-kit-KitChip/README.md
  // "Contract problems"); a longer label sidesteps the harness artifact
  // without changing what it proves.
  KitChip(label: arabic ? '3 وكلاء' : '3 agents'),
  KitChip.action(
    label: arabic ? 'افتح في الطرفية' : 'Open in terminal',
    onPressed: () {},
    selected: selected,
  ),
  KitChip.removable(label: 'file.txt', onRemove: () {}),
  KitChip.count(label: arabic ? 'المهام' : 'Tasks', count: count),
  KitChip.summary(
    label: arabic ? 'قرأ 3 ملفات · حرر 1' : 'Read 3 files · edited 1',
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

const _longEn =
    'A genuinely long label that will never fit inside this short chip';
const _longAr = 'تسمية طويلة حقًا لن تتسع أبدًا داخل هذه الشريحة القصيرة';

/// Every kind with a long label, each capped to 160 dp so it must
/// ellipsise (A11Y-8: "a chip may truncate").
Widget _truncatedScene({bool arabic = false}) {
  final long = arabic ? _longAr : _longEn;
  Widget capped(Widget chip) => SizedBox(width: 160, child: chip);
  return _scene([
    capped(KitChip(label: long)),
    capped(KitChip.action(label: long, onPressed: () {})),
    capped(KitChip.removable(label: long, onRemove: () {})),
    capped(KitChip.count(label: long, count: 42)),
    capped(KitChip.summary(label: long, onPressed: () {})),
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

    for (final size in const [
      Size(360, 800),
      Size(915, 412),
      Size(800, 1280),
      Size(1280, 800),
      Size(1600, 1000),
    ]) {
      final at = kitGallerySize(size);
      testWidgets('kit_chip default · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_chip_default', size, light: light),
          size: size,
          light: light,
          child: _scene(_chips()),
        );
      });
    }

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
      testWidgets('kit_chip default · ar · $at · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_chip_default',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          textScale: 1.3,
          child: _scene(_chips(arabic: true)),
        );
      });
    }
  }
}
