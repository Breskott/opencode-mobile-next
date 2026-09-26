// Gallery (gate G4) for KitTappable (docs/ux-system/kit-api/KitTappable.md
// "Galleries required"): a row-shaped tappable on a `KitPanel` (a
// `KitSurface.panel` sheet), each declared state in dark and light at
// 412×915.
//
// Reduced from the frozen spec's size matrix by the owner decision in
// docs/ux-system/revamp/STANDARDS.md (2026-09-27, R15: later owner
// decisions win): Arabic/RTL and 2.0-text galleries are dropped, and every
// part's gallery is phone (412x915) and one wide size (1280x800), light and
// dark, only. See docs/qa/revamp-kit-KitTappable-2026-09-27/README.md.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_tappable_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_iconography.dart';
// kit_row_parts.dart's pre-v2 KitMenuItem is superseded by kit_menu.dart's
// (KitMenu.md); hide the older one so the v2 type below is unambiguous.
import 'package:opencode_mobile/ui/kit/kit.dart' hide KitMenuItem;
import 'package:opencode_mobile/ui/kit/kit_menu.dart';
import 'package:opencode_mobile/ui/kit/kit_tappable.dart';

import '../../../tool/capture/fixtures.dart' show captureTheme;
import 'kit_gallery.dart';

/// The declared, non-interactive states this file can shoot through
/// [kitGalleryPart] (hovered, pressed, focused and menu_open need real
/// interaction, so they get their own pump below, like
/// `kit_chip_golden_test.dart`'s `_focusedShot`).
enum _State { enabled, disabled }

String _stateName(_State state) => state.name;

/// A conversation row: the shape and content KitRow's own migration will
/// wrap in KitTappable (KitTappable.md "Replaces").
Widget _row({
  required VoidCallback? onTap,
  String? disabledReason,
  List<KitMenuItem> menu = const [],
}) => Builder(
  builder: (context) {
    final roles = KitTokens.of(context).roles;
    final disabled = onTap == null;
    // KitTappable draws no disabled look of its own (KitTappable.md
    // "States": "It never looks clickable... KitTappable does not draw
    // it"); the host still must show the reason as visible text nearby
    // (STATE-8), which this demo row does like a real caller would.
    return KitPanel(
      padding: EdgeInsets.zero,
      child: KitTappable(
        onTap: onTap,
        disabledReason: disabledReason,
        shape: KitShape.panel,
        menu: menu,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                AppIconography.archive,
                color: disabled ? roles.text3 : roles.text2,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    KitText(
                      'Archive "Fix the login bug"',
                      role: KitTextRole.rowTitle,
                      tone: disabled
                          ? KitTextTone.tertiary
                          : KitTextTone.primary,
                    ),
                    if (disabled && disabledReason != null)
                      KitText(
                        disabledReason,
                        role: KitTextRole.secondary,
                        tone: KitTextTone.secondary,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
);

Widget _scene(_State state) => Padding(
  padding: const EdgeInsets.all(20),
  child: switch (state) {
    _State.enabled => _row(onTap: () {}),
    _State.disabled => _row(onTap: null, disabledReason: 'Needs a connection'),
  },
);

/// The two destructive-item-last menu, for the `menu_open` shot.
List<KitMenuItem> _menu() => [
  KitMenuItem(label: 'Rename', onSelected: () {}),
  KitMenuItem(label: 'Archive', onSelected: () {}, destructive: true),
];

/// The interactive states [kitGalleryPart] has no hook for: it pumps its own
/// small app, drives the interaction, settles, then compares — the same
/// technique as `kit_chip_golden_test.dart`'s `_focusedShot`. It does not
/// run the shared G5 accessibility scan (private to kit_gallery.dart, R06);
/// every non-interactive shot in this file does, through [kitGalleryPart].
Future<void> _interactiveShot(
  WidgetTester tester, {
  required String name,
  required bool light,
  required Future<void> Function(WidgetTester tester) act,
}) async {
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
          home: Scaffold(body: _scene(_State.enabled)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await act(tester);
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

    // Declared states x phone (412x915) and one wide size (1280x800) x dark
    // and light (owner decision 2026-09-27).
    for (final size in const [Size(412, 915), Size(1280, 800)]) {
      for (final state in _State.values) {
        testWidgets(
          'kit_tappable ${_stateName(state)} · ${kitGallerySize(size)} · '
          '$mode',
          (tester) async {
            await kitGalleryPart(
              tester,
              name: kitGalleryName(
                'kit_tappable_${_stateName(state)}',
                size,
                light: light,
              ),
              size: size,
              light: light,
              child: _scene(state),
            );
          },
        );
      }
    }

    testWidgets('kit_tappable hovered · $mode', (tester) async {
      await _interactiveShot(
        tester,
        name: kitGalleryName(
          'kit_tappable_hovered',
          const Size(412, 915),
          light: light,
        ),
        light: light,
        act: (tester) async {
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
          await mouse.moveTo(tester.getCenter(find.byType(KitTappable)));
        },
      );
    });

    testWidgets('kit_tappable pressed · $mode', (tester) async {
      await _interactiveShot(
        tester,
        name: kitGalleryName(
          'kit_tappable_pressed',
          const Size(412, 915),
          light: light,
        ),
        light: light,
        act: (tester) async {
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
          final center = tester.getCenter(find.byType(KitTappable));
          await mouse.moveTo(center);
          await mouse.down(center);
          addTearDown(mouse.up);
        },
      );
    });

    testWidgets('kit_tappable focused · $mode', (tester) async {
      await _interactiveShot(
        tester,
        name: kitGalleryName(
          'kit_tappable_focused',
          const Size(412, 915),
          light: light,
        ),
        light: light,
        act: (tester) async {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        },
      );
    });

    testWidgets('kit_tappable menu_open · $mode', (tester) async {
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
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _row(onTap: () {}, menu: _menu()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile(
          '${kitGalleryName('kit_tappable_menu_open', const Size(412, 915), light: light)}.png',
        ),
      );
    });
  }
}
