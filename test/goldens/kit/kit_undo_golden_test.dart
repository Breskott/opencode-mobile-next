// Gallery (gate G4) for KitUndo, docs/ux-system/kit-api/KitUndo.md; K2
// §1.17, §4.1, §4.8, §8.4.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_undo_golden_test.dart
// and look at every changed image before committing it.
//
// KitNav has not merged (C25: KitUndo is a leaf, no unit dependency), so
// "shown over a KitNav dock scene" (KitUndo.md, Galleries required) is
// stood in for by a plain bottom bar publishing the same clearance a real
// dock will (KitBottomInset), recorded as a gap under NOT proven in the
// unit's QA record (PROC-32) until kit-KitNav lands and this gallery is
// updated to the real thing.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_bottom_inset.dart';
import 'package:opencode_mobile/ui/kit/kit_layout.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/kit/kit_undo.dart';

import 'kit_gallery.dart';

/// The start clearance a dock scene publishes at [size]: a rail from
/// medium, a sidebar from expanded (KitBottomInset.md Adaptive).
double _startFor(Size size) {
  final window = KitLayout.windowFor(size.width);
  if (window.isWide) return KitLayout.paneListWidth;
  if (window == KitWindow.medium) return KitLayout.railWidth;
  return 0;
}

/// A stand-in dock: a plain bottom bar at [KitTokens.navHeight], published
/// through [KitBottomInset] exactly as the real dock will (see the file
/// header note).
Widget _dockScene(BuildContext context, {required double start}) {
  final tokens = KitTokens.of(context);
  final roles = tokens.roles;
  return PositionedDirectional(
    start: 0,
    end: 0,
    bottom: 0,
    child: Container(
      height: tokens.navHeight,
      alignment: AlignmentDirectional.centerStart,
      padding: EdgeInsetsDirectional.only(start: start),
      color: roles.surface2,
    ),
  );
}

/// [AppTheme.forLocale] fixes the type roles' own faces for Arabic, but a
/// button's label keeps whatever explicit `textStyle` the app theme's own
/// button themes carry (kit_gallery.dart's `_theme` notes the same thing).
/// Real Noto Sans Arabic glyphs are already loaded by [loadKitGalleryFonts];
/// this just lets a button's text reach for them too.
ThemeData _themeFor(ThemeData theme, {required bool arabic}) {
  if (!arabic) return theme;
  const fallback = ['Noto Sans Arabic'];
  ButtonStyle? withFallback(ButtonStyle? style) {
    final text = style?.textStyle;
    if (style == null || text == null) return style;
    return style.copyWith(
      textStyle: WidgetStateProperty.resolveWith(
        (states) =>
            text.resolve(states)?.copyWith(fontFamilyFallback: fallback),
      ),
    );
  }

  return theme.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: withFallback(theme.filledButtonTheme.style),
    ),
    textButtonTheme: TextButtonThemeData(
      style: withFallback(theme.textButtonTheme.style),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: withFallback(theme.outlinedButtonTheme.style),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: withFallback(theme.elevatedButtonTheme.style),
    ),
  );
}

/// Like [kitGalleryShot], but the window has a dock scene at its bottom
/// (and, from medium up, a rail or sidebar at its start) publishing its
/// clearance through [KitBottomInset], so a floating part's distance from
/// both is visible in the shot.
Future<void> _kitUndoShot(
  WidgetTester tester, {
  required String name,
  required Size size,
  required bool light,
  required FutureOr<void> Function(BuildContext context) open,
  Future<void> Function(WidgetTester tester)? then,
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool settleAfterThen = true,
}) async {
  final own = light ? 'light' : 'dark';
  if (!name.endsWith('_$own')) {
    throw ArgumentError.value(name, 'name', 'must end in "_$own"');
  }
  final stem = name.substring(0, name.length - own.length - 1);
  final start = _startFor(size);
  final arabic = locale.languageCode == 'ar';
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final semantics = tester.ensureSemantics();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    for (final pass in [!light, light]) {
      late BuildContext context;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _themeFor(
              AppTheme.forLocale(
                pass ? AppTheme.light() : AppTheme.dark(),
                locale,
              ),
              arabic: arabic,
            ),
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (outer) => KitBottomInset.add(
                  extraBottom: KitTokens.of(outer).navHeight,
                  start: start,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Builder(
                          builder: (inner) {
                            context = inner;
                            return const SizedBox.expand();
                          },
                        ),
                      ),
                      _dockScene(outer, start: start),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      unawaited(Future.sync(() => open(context)));
      await tester.pumpAndSettle();
      if (then != null) {
        await then(tester);
        if (settleAfterThen) await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectKitGalleryAccessible(
        tester,
        shot: '${stem}_${pass ? 'light' : 'dark'}',
        direction: Directionality.of(context),
      );
    }
  } finally {
    debugDefaultTargetPlatformOverride = null;
    semantics.dispose();
    KitUndo.commitPending();
  }
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}

void _default(BuildContext context) => showKitUndo(
  context,
  key: const Key('the-undo-bar'),
  undoKey: const Key('the-undo-action'),
  message: 'Archived "Fix login"',
  onUndo: () {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    const phone = Size(412, 915);

    testWidgets('kit_undo default · $mode', (tester) async {
      await _kitUndoShot(
        tester,
        name: kitGalleryName('kit_undo_default', phone, light: light),
        size: phone,
        light: light,
        open: _default,
      );
    });

    testWidgets('kit_undo working · $mode', (tester) async {
      final never = Completer<void>();
      await _kitUndoShot(
        tester,
        name: kitGalleryName('kit_undo_working', phone, light: light),
        size: phone,
        light: light,
        open: (context) => showKitUndo(
          context,
          key: const Key('the-undo-bar'),
          undoKey: const Key('the-undo-action'),
          message: 'Archived "Fix login"',
          onUndo: () => never.future,
        ),
        settleAfterThen: false,
        then: (tester) async {
          await tester.tap(find.byKey(const Key('the-undo-action')));
          await tester.pump();
        },
      );
    });

    testWidgets('kit_undo error · $mode', (tester) async {
      await _kitUndoShot(
        tester,
        name: kitGalleryName('kit_undo_error', phone, light: light),
        size: phone,
        light: light,
        open: (context) => showKitUndo(
          context,
          key: const Key('the-undo-bar'),
          undoKey: const Key('the-undo-action'),
          message: 'Archived "Fix login"',
          onUndo: () => throw StateError('offline'),
        ),
        then: (tester) async {
          await tester.tap(find.byKey(const Key('the-undo-action')));
        },
      );
    });

    testWidgets('kit_undo accessible · $mode', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(accessibleNavigation: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _kitUndoShot(
        tester,
        name: kitGalleryName('kit_undo_accessible', phone, light: light),
        size: phone,
        light: light,
        open: _default,
      );
    });

    for (final size in kitGallerySizes) {
      if (size == phone) continue;
      testWidgets('kit_undo default · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await _kitUndoShot(
          tester,
          name: kitGalleryName('kit_undo_default', size, light: light),
          size: size,
          light: light,
          open: _default,
        );
      });
    }

    // KitUndo.md's own galleries list also names 915×412 (the phone
    // landscape size); kitGallerySizes (test/goldens/kit/kit_gallery.dart,
    // shared, not this unit's to change) does not include it.
    testWidgets('kit_undo default · 915x412 · $mode', (tester) async {
      const landscape = Size(915, 412);
      await _kitUndoShot(
        tester,
        name: kitGalleryName('kit_undo_default', landscape, light: light),
        size: landscape,
        light: light,
        open: _default,
      );
    });

    for (final size in kitGalleryScaledSizes) {
      testWidgets('kit_undo default · text 2.0 · ${kitGallerySize(size)} '
          '· $mode', (tester) async {
        await _kitUndoShot(
          tester,
          name: kitGalleryName(
            'kit_undo_default',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          open: _default,
        );
      });

      testWidgets('kit_undo default · ar · ${kitGallerySize(size)} · $mode', (
        tester,
      ) async {
        await _kitUndoShot(
          tester,
          name: kitGalleryName(
            'kit_undo_default',
            size,
            light: light,
            ar: true,
          ),
          size: size,
          light: light,
          locale: const Locale('ar'),
          open: (context) => showKitUndo(
            context,
            key: const Key('the-undo-bar'),
            undoKey: const Key('the-undo-action'),
            message: 'أرشفة "إصلاح تسجيل الدخول"',
            onUndo: () {},
          ),
        );
      });
    }
  }
}
