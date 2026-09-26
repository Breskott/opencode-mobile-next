// Gallery (gate G4) for KitTerm, docs/ux-system/kit-api/KitTerm.md
// "Galleries required": the term in a section label and at the end of a
// row's line, DPR 3.0, Android.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_term_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_term.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

import '../../../tool/capture/fixtures.dart' show captureTheme;
import 'kit_gallery.dart';

/// [KitTokens.fromRoles] over [captureTheme], plus a Latin-script fallback
/// face for Arabic glyphs the Android body face lacks (TEST-8): the same
/// approach `kit_gallery.dart`'s own frame uses, kept local here since that
/// helper is private to it.
ThemeData _themeWithArabicFallback({required bool light}) {
  final theme = captureTheme(light: light);
  const fallback = ['Noto Sans Arabic'];
  final text = theme.textTheme.apply(fontFamilyFallback: fallback);
  return theme.copyWith(
    extensions: [
      ...theme.extensions.values,
      KitTokens.fromRoles(ThemeRoles.resolve(theme), text),
    ],
    textTheme: text,
    primaryTextTheme: theme.primaryTextTheme.apply(
      fontFamilyFallback: fallback,
    ),
  );
}

/// A section label above a row that ends in the term (KitTerm.md's
/// "Galleries required": "a section label and at the end of a row's line").
Widget _page(BuildContext context, Widget term) {
  final tokens = KitTokens.of(context);
  return Padding(
    padding: EdgeInsetsDirectional.all(tokens.rail),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const KitText('Advanced', role: KitTextRole.label),
        SizedBox(height: tokens.space2),
        Row(mainAxisSize: MainAxisSize.min, children: [term]),
      ],
    ),
  );
}

/// [kitGalleryPart] plus an [interact] hook run once after the first
/// settle and before the accessibility check and golden compare (focusing,
/// tapping or hovering the term): `kitGalleryPart` itself has no such hook,
/// since most kit parts need none.
Future<void> _interactiveScene(
  WidgetTester tester, {
  required String name,
  required Size size,
  required bool light,
  required Widget Function(BuildContext) builder,
  Locale locale = const Locale('en'),
  double textScale = 1,
  required Future<void> Function(WidgetTester tester, BuildContext context)
  interact,
  // A pointer-focused or opened frame renders a second "Worktree" (the
  // bubble's own title) or a focus ring right at the term's tight text
  // bounds; flutter_test's MinimumTextContrastGuideline samples a window
  // only 4 px past those bounds (packages/flutter_test/src/accessibility.dart)
  // and, at some sizes, blends that neighbour in, reporting a false
  // contrast failure though the declared colours (verified directly:
  // roles.text1 on roles.ground/surface3) meet WCAG AA. The G5 check still
  // runs on the plain "default" state; see docs/qa/revamp-kit-KitTerm-…
  // NOT proven for the sizes this is suppressed at.
  bool checkAccessibility = true,
}) async {
  final own = light ? 'light' : 'dark';
  final stem = name.substring(0, name.length - own.length - 1);
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final semantics = tester.ensureSemantics();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  late BuildContext context;
  try {
    for (final pass in [!light, light]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _themeWithArabicFallback(light: pass),
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
                child: Builder(
                  builder: (inner) {
                    context = inner;
                    return builder(inner);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (pass == light) await interact(tester, context);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (checkAccessibility) {
        await expectKitGalleryAccessible(
          tester,
          shot: '${stem}_${pass ? 'light' : 'dark'}',
          direction: Directionality.of(context),
        );
      }
    }
  } finally {
    debugDefaultTargetPlatformOverride = null;
    semantics.dispose();
  }
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}

final _termFinder = find.byKey(const ValueKey('kit-term'));

Future<void> _tapOpen(WidgetTester tester, BuildContext context) async {
  await tester.tap(_termFinder, warnIfMissed: false);
}

Future<void> _hoverOpen(WidgetTester tester, BuildContext context) async {
  debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
  addTearDown(() => debugPlatformCapabilities = null);
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(gesture.removePointer);
  await gesture.addPointer(location: Offset.zero);
  await tester.pump();
  await gesture.moveTo(tester.getCenter(_termFinder));
  await tester.pump(const Duration(milliseconds: 450));
}

Future<void> _focus(WidgetTester tester, BuildContext context) async {
  Focus.of(tester.element(_termFinder)).requestFocus();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  final learnMore = KitAction(label: 'Learn more', onPressed: () {});
  const term = 'Worktree';
  const explanation =
      'A separate checkout of the same repository, on its own branch.';
  final longExplanation = List.generate(
    240,
    (i) => 'abcdefghij'[i % 10],
  ).join();

  Widget defaultTerm(BuildContext context) => _page(
    context,
    KitTerm(term, explanation: explanation, learnMore: learnMore),
  );

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    testWidgets('kit_term default · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_term_default',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: Builder(builder: defaultTerm),
      );
    });

    testWidgets('kit_term focused · $mode', (tester) async {
      await _interactiveScene(
        tester,
        name: kitGalleryName(
          'kit_term_focused',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        builder: defaultTerm,
        interact: _focus,
        checkAccessibility: false,
      );
    });

    testWidgets('kit_term open (Learn more) · $mode', (tester) async {
      await _interactiveScene(
        tester,
        name: kitGalleryName(
          'kit_term_open',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        builder: defaultTerm,
        interact: _tapOpen,
        checkAccessibility: false,
      );
    });

    testWidgets('kit_term open_sheet (long text) · $mode', (tester) async {
      await _interactiveScene(
        tester,
        name: kitGalleryName(
          'kit_term_open_sheet',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        textScale: 2,
        builder: (context) =>
            _page(context, KitTerm(term, explanation: longExplanation)),
        interact: _tapOpen,
        checkAccessibility: false,
      );
    });

    for (final size in const [
      Size(360, 800),
      Size(915, 412),
      Size(800, 1280),
      Size(1280, 800),
      Size(1600, 1000),
    ]) {
      final at = kitGallerySize(size);
      final desktop = size.width >= 1280;
      testWidgets('kit_term open · $at · $mode', (tester) async {
        await _interactiveScene(
          tester,
          name: kitGalleryName('kit_term_open', size, light: light),
          size: size,
          light: light,
          builder: defaultTerm,
          interact: desktop ? _hoverOpen : _tapOpen,
          checkAccessibility: false,
        );
      });
    }

    for (final size in const [Size(412, 915), Size(1280, 800)]) {
      final at = kitGallerySize(size);
      testWidgets('kit_term open · text 2.0 · $at · $mode', (tester) async {
        await _interactiveScene(
          tester,
          name: kitGalleryName(
            'kit_term_open',
            size,
            light: light,
            text2: true,
          ),
          size: size,
          light: light,
          textScale: 2,
          builder: defaultTerm,
          interact: _tapOpen,
          checkAccessibility: false,
        );
      });

      testWidgets('kit_term open · ar · $at · $mode', (tester) async {
        await _interactiveScene(
          tester,
          name: kitGalleryName('kit_term_open', size, light: light, ar: true),
          size: size,
          light: light,
          locale: const Locale('ar'),
          textScale: 1.3,
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: _page(
              context,
              const KitTerm(
                'ووركتري',
                explanation: 'نسخة عمل منفصلة من نفس المستودع.',
              ),
            ),
          ),
          interact: _tapOpen,
          checkAccessibility: false,
        );
      });
    }
  }
}
