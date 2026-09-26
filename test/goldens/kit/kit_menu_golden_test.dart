// Gallery (gate G4) for KitMenu, docs/ux-system/kit-api/KitMenu.md: the one
// popup menu, rendered as `KitMenuPanel` (no route) over a ground screen
// with a surface1 row as the invoker, at DPR 3.0 (TEST-9, TEST-20).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_menu_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
// KitMenuItem lives here now; kit.dart still exports the pre-v2 one from
// kit_row_parts.dart until kit-KitRowParts-v2 removes it (KitMenu.md, Open
// question 1).
import 'package:opencode_mobile/ui/kit/kit.dart' hide KitMenuItem;
import 'package:opencode_mobile/ui/kit/kit_menu.dart';

import '../../../tool/capture/fixtures.dart' show captureTheme;
import 'kit_gallery.dart';

/// The invoker row plus the panel, on a ground background (KitMenu.md
/// Galleries required).
Widget _scene(BuildContext context, List<KitMenuItem> items) => Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(color: KitTokens.of(context).roles.surface1),
        child: const KitRow(
          title: 'Conversation actions',
          trailing: KitChevron(),
        ),
      ),
      SizedBox(height: KitTokens.of(context).space3),
      KitMenuPanel(items: items, onSelected: (_) {}),
    ],
  ),
);

List<KitMenuItem> _defaultItems() => [
  KitMenuItem(label: 'Rename conversation', onSelected: () {}),
  KitMenuItem(label: 'Duplicate', onSelected: () {}),
  KitMenuItem(
    label: 'Archive conversation',
    onSelected: () {},
    shortcut: 'Ctrl+Shift+A',
  ),
];

List<KitMenuItem> _arabicDefaultItems() => [
  KitMenuItem(label: 'إعادة تسمية المحادثة', onSelected: () {}),
  KitMenuItem(label: 'إنشاء نسخة', onSelected: () {}),
  KitMenuItem(
    label: 'أرشفة المحادثة',
    onSelected: () {},
    shortcut: 'Ctrl+Shift+A',
  ),
];

List<KitMenuItem> _iconItems() => [
  KitMenuItem(
    label: 'Rename conversation',
    onSelected: () {},
    icon: AppIconography.edit,
  ),
  KitMenuItem(label: 'Duplicate', onSelected: () {}, icon: AppIconography.copy),
  KitMenuItem(
    label: 'Archive conversation',
    onSelected: () {},
    icon: AppIconography.archive,
  ),
];

List<KitMenuItem> _checkedItems() => [
  KitMenuItem(label: 'Sort by name', onSelected: () {}, checked: true),
  KitMenuItem(label: 'Sort by date', onSelected: () {}, checked: false),
];

List<KitMenuItem> _groupItems() => [
  KitMenuItem(label: 'Rename conversation', onSelected: () {}, group: 'edit'),
  KitMenuItem(label: 'Duplicate', onSelected: () {}, group: 'edit'),
  KitMenuItem(label: 'Archive conversation', onSelected: () {}, group: 'move'),
  KitMenuItem(label: 'Export', onSelected: () {}, group: 'move'),
];

List<KitMenuItem> _destructiveItems() => [
  KitMenuItem(
    label: 'Rename conversation',
    onSelected: () {},
    icon: AppIconography.edit,
    group: 'edit',
  ),
  KitMenuItem(
    label: 'Archive conversation',
    onSelected: () {},
    icon: AppIconography.archive,
    group: 'move',
  ),
  KitMenuItem(
    label: 'Delete conversation',
    onSelected: () {},
    icon: AppIconography.delete,
    destructive: true,
  ),
];

List<KitMenuItem> _disabledItems() => [
  KitMenuItem(label: 'Rename conversation', onSelected: () {}),
  KitMenuItem(
    label: 'Restart server',
    onSelected: () {},
    enabled: false,
    disabledReason: 'No server connected',
  ),
];

/// A non-modal shot, matching `kitGalleryPart`'s theme and font loading, but
/// with a real mouse hover on [hoverLabel] before capture, so the 1280/1600
/// shots can show a hovered item with a fine pointer (KitMenu.md "the
/// shortcut column shows" and "one hovered item"). Runs with desktop
/// capabilities (`KitLayout.finePointer`).
Future<void> _hoverShot(
  WidgetTester tester, {
  required String name,
  required Size size,
  required bool light,
  required List<KitMenuItem> Function() items,
  required String hoverLabel,
}) async {
  final own = light ? 'light' : 'dark';
  if (!name.endsWith('_$own')) {
    throw ArgumentError.value(name, 'name', 'must end in _$own');
  }
  final stem = name.substring(0, name.length - own.length - 1);
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final semantics = tester.ensureSemantics();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
  try {
    for (final pass in [!light, light]) {
      late BuildContext context;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: captureTheme(light: pass),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (inner) {
                  context = inner;
                  return _scene(inner, items());
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();
      await gesture.moveTo(
        tester.getCenter(
          find
              .ancestor(
                of: find.text(hoverLabel),
                matching: find.byType(InkWell),
              )
              .first,
        ),
      );
      await tester.pumpAndSettle();
      await gesture.removePointer();

      expect(tester.takeException(), isNull);
      await expectKitGalleryAccessible(
        tester,
        shot: '${stem}_${pass ? 'light' : 'dark'}',
        direction: Directionality.of(context),
      );
    }
  } finally {
    debugDefaultTargetPlatformOverride = null;
    debugPlatformCapabilities = null;
    semantics.dispose();
  }
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  const phone = Size(412, 915);
  const states = <String, List<KitMenuItem> Function()>{
    'default': _defaultItems,
    'icons': _iconItems,
    'checked': _checkedItems,
    'groups': _groupItems,
    'destructive': _destructiveItems,
    'disabled': _disabledItems,
  };

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    for (final MapEntry(key: state, value: itemsOf) in states.entries) {
      testWidgets('kit_menu $state · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_menu_$state', phone, light: light),
          size: phone,
          light: light,
          child: Builder(builder: (context) => _scene(context, itemsOf())),
        );
      });
    }

    // KitMenu.md: "default" at 360x800, the LANDSCAPE census phone
    // (915x412, short enough to exercise KitLayout.isShort), 800x1280,
    // 1280x800 and 1600x1000. 1280 and 1600 show the shortcut column and a
    // hovered item, so they go through `_hoverShot` with desktop
    // capabilities; the other three have no fine pointer, so no shortcut
    // column and no hover.
    const plainSizes = [Size(360, 800), Size(915, 412), Size(800, 1280)];
    for (final size in plainSizes) {
      testWidgets('kit_menu default · ${size.width.toInt()}x'
          '${size.height.toInt()} · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName('kit_menu_default', size, light: light),
          size: size,
          light: light,
          child: Builder(
            builder: (context) => _scene(context, _defaultItems()),
          ),
        );
      });
    }
    const hoverSizes = [Size(1280, 800), Size(1600, 1000)];
    for (final size in hoverSizes) {
      testWidgets('kit_menu default · ${size.width.toInt()}x'
          '${size.height.toInt()} hovered · $mode', (tester) async {
        await _hoverShot(
          tester,
          name: kitGalleryName('kit_menu_default', size, light: light),
          size: size,
          light: light,
          items: _defaultItems,
          hoverLabel: 'Duplicate',
        );
      });
    }

    for (final size in kitGalleryScaledSizes) {
      testWidgets('kit_menu default · 2.0 text · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_menu_default',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          child: Builder(
            builder: (context) => _scene(context, _defaultItems()),
          ),
        );
      });
      testWidgets('kit_menu default · ar · $mode', (tester) async {
        await kitGalleryPart(
          tester,
          name: kitGalleryName(
            'kit_menu_default',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          textScale: 1.3,
          child: Builder(
            builder: (context) => _scene(context, _arabicDefaultItems()),
          ),
        );
      });
    }
  }
}
