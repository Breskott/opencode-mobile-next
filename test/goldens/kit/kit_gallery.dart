// Shared frame for the kit part galleries (gate G4, docs/ux-system/kit-v2.md
// §7 and §8.4): every part at the five window sizes in light and dark, and
// at 412 and 1280 wide with 2.0 text and in Arabic (right to left). The
// app's real fonts come from tool/capture; Arabic falls back to Noto Sans
// Arabic (test/fixtures/fonts, OFL), as it does on an Android device.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';

import '../../../tool/capture/fixtures.dart'
    show captureTheme, loadCaptureFonts;

const _arabicFallback = 'KitGalleryNotoSansArabic';

/// The capture fonts plus the Arabic fallback family, and the families
/// AppTheme.forLocale names for Arabic ('sans-serif', which is Roboto on
/// Android, and 'Noto Sans Arabic'), so a screen rendered through it reads
/// like the device (TEST-8, gate G23).
Future<void> loadKitGalleryFonts() async {
  await loadCaptureFonts();
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final path in paths) {
      loader.addFont(File(path).readAsBytes().then(ByteData.sublistView));
    }
    await loader.load();
  }

  const noto = [
    'test/fixtures/fonts/NotoSansArabic-Regular.ttf',
    'test/fixtures/fonts/NotoSansArabic-Bold.ttf',
  ];
  await load(_arabicFallback, noto);
  await load('Noto Sans Arabic', noto);
  await load('sans-serif', const [
    'tool/capture/fonts/Roboto-Regular.ttf',
    'tool/capture/fonts/Roboto-Medium.ttf',
    'tool/capture/fonts/Roboto-Bold.ttf',
  ]);
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

  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
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

String kitGallerySize(Size size) =>
    '${size.width.toInt()}x${size.height.toInt()}';

/// The TEST-20 golden name for a gallery shot:
/// `<shot>[_ar][_text2][_<W>x<H>]_<dark|light>`, where [shot] is
/// `kit_<part>_<state>` and the size is left out for 412x915. Gate G23
/// (test/golden_harness_test.dart) rejects any other kit golden name.
String kitGalleryName(
  String shot,
  Size size, {
  required bool light,
  bool ar = false,
  bool text2 = false,
}) {
  if (!RegExp(r'^kit_[a-z0-9]+(_[a-z0-9]+)+$').hasMatch(shot)) {
    throw ArgumentError.value(shot, 'shot', 'must be kit_<part>_<state>');
  }
  return [
    shot,
    if (ar) 'ar',
    if (text2) 'text2',
    if (size != const Size(412, 915)) kitGallerySize(size),
    light ? 'light' : 'dark',
  ].join('_');
}

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
  // TEST-9: DPR 3.0, [size] in logical pixels. ARCH-11: rendered as Android;
  // the override is cleared at the end of the shot (flutter_test checks it
  // before tear-downs run), and by the tear-down if the shot throws.
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
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

  debugDefaultTargetPlatformOverride = null;
}
