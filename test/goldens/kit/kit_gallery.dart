// Shared frame for the kit part galleries (gate G4, docs/ux-system/kit-v2.md
// §7 and §8.4): every part at the five window sizes in light and dark, and
// at 412 and 1280 wide with 2.0 text and in Arabic (right to left). The
// app's real fonts come from tool/capture; Arabic falls back to Noto Sans
// Arabic (test/fixtures/fonts, OFL), as it does on an Android device.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import '../../../tool/capture/fixtures.dart'
    show captureTheme, loadCaptureFonts;

const _arabicFallback = 'KitGalleryNotoSansArabic';

/// The capture fonts plus the Arabic fallback family.
Future<void> loadKitGalleryFonts() async {
  await loadCaptureFonts();
  final arabic = FontLoader(_arabicFallback);
  for (final weight in ['Regular', 'Bold']) {
    arabic.addFont(
      File(
        'test/fixtures/fonts/NotoSansArabic-$weight.ttf',
      ).readAsBytes().then(ByteData.sublistView),
    );
  }
  await arabic.load();
}

/// The capture theme with Arabic falling back to Noto, like a device.
ThemeData _theme({required bool light}) {
  final theme = captureTheme(light: light);
  const fallback = [_arabicFallback];
  // Buttons carry their own text styles in the app theme.
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

  final text = theme.textTheme.apply(fontFamilyFallback: fallback);
  return theme.copyWith(
    // The kit's own styles carry the fallback too.
    extensions: [
      ...theme.extensions.values,
      KitTokens.fromRoles(ThemeRoles.resolve(theme), text),
    ],
    textTheme: text,
    primaryTextTheme: theme.primaryTextTheme.apply(
      fontFamilyFallback: fallback,
    ),
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

/// The §8.4 sizes: phone, the census phone, tablet portrait, tablet
/// landscape or PC, large PC.
const kitGallerySizes = <Size>[
  Size(360, 800),
  Size(412, 915),
  Size(800, 1280),
  Size(1280, 800),
  Size(1600, 1000),
];

/// Where 2.0 text and Arabic are rendered.
const kitGalleryScaledSizes = <Size>[Size(412, 915), Size(1280, 800)];

/// The device pixel ratio a window of [size] renders at (visual language
/// §7: goldens at the device's ratio, so a soft edge or a doubled hairline
/// shows): 3.0 for a phone, 2.0 for a tablet, 1.0 for a PC window.
double kitGalleryPixelRatio(Size size) => size.width < 600
    ? 3
    : size.shortestSide < 900 && size.width < 1200
    ? 2
    : 1;

String kitGallerySize(Size size) =>
    '${size.width.toInt()}x${size.height.toInt()}';

/// Pumps an empty screen at [size], runs [open] against a context under the
/// navigator (it opens the modal part), settles, and compares the whole
/// window with `goldens/kit/<name>.png`.
Future<void> kitGalleryShot(
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
  final dpr = kitGalleryPixelRatio(size);
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  late BuildContext context;
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(light: light),
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
            builder: (inner) {
              context = inner;
              return const SizedBox.expand();
            },
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
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}

/// Pumps [child] as a screen's body at [size] (a part that is not a modal:
/// rows, buttons, cards, type), settles, and compares the whole window with
/// `goldens/kit/<name>.png`.
Future<void> kitGalleryPart(
  WidgetTester tester, {
  required String name,
  required Size size,
  required bool light,
  required Widget child,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  final dpr = kitGalleryPixelRatio(size);
  tester.view.physicalSize = size * dpr;
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _theme(light: light),
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
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}
