// KitText (lib/ui/kit/kit_text.dart), added by the visual language merge
// before the wave-0b gates existed. Its reduced-motion samples (G8x, MOT-7)
// and the first behaviour checks live here; kit-KitText-v2 owns this file
// and adds the full G19 contracts (LOOK-10–LOOK-17), plus KitText.selectable,
// KitText.mono, KitSelectable and KitLtr (docs/ux-system/kit-api/KitText.md).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

Widget _host(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      theme: AppTheme.dark(),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(body: Center(child: child)),
      ),
    );

/// A full app under the Arabic locale, so `Theme.of(context).textTheme`
/// carries the system-face fallback [AppTheme.forLocale] adds (test 2).
Widget _arabicHost(Widget child) => MaterialApp(
  theme: AppTheme.forLocale(AppTheme.dark(), const Locale('ar')),
  locale: const Locale('ar'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

/// Whether keyboard focus is on [target] itself or something inside it (the
/// pattern test/kit/kit_keyboard_test.dart uses for G14).
bool _focusIn(WidgetTester tester, Finder target) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final element = tester.element(target);
  if (focused == element) return true;
  var found = false;
  (focused as Element).visitAncestorElements((ancestor) {
    if (ancestor == element) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// The button showing [label] (the pattern test/kit/kit_keyboard_test.dart
/// uses, so [_focusIn] is asked about the whole control, not its label,
/// which sits inside the control's own focus node, never around it).
Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
);

/// The global rect of [text]'s painted glyphs (not the box Flutter lays the
/// paragraph out in, which can be wider than its content): [RenderParagraph]
/// gives the run's own boxes, in its local coordinates.
Rect _glyphRect(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  var rect = boxes.first.toRect();
  for (final box in boxes.skip(1)) {
    rect = rect.expandToInclude(box.toRect());
  }
  return paragraph.localToGlobal(rect.topLeft) & rect.size;
}

void main() {
  kitMotionStillTests(
    'KitText',
    builds: {
      'default': () => const KitText('Fix flaky checkout test'),
      'rich': () => const KitText.rich(
        TextSpan(
          children: [
            TextSpan(text: 'Needs you'),
            TextSpan(text: ' · 40 s ago'),
          ],
        ),
        role: KitTextRole.caption,
      ),
      'mono': () => const KitText(
        r'$ flutter test test/checkout_test.dart',
        role: KitTextRole.mono,
      ),
      'selectable': () => const KitText.selectable('Copy this line'),
      'mono middle cut': () => const SizedBox(
        width: 160,
        child: KitText.mono(
          '/home/user/projects/very/long/path/main.dart',
          cut: KitMonoCut.middle,
        ),
      ),
    },
  );

  // KitSelectable and KitLtr are new parts declared in this file (KitText
  // v2); each registers its own reduced-motion samples here (NAME-1) so
  // test/kit_motion_test.dart, which every kit unit leaves alone, finds one.
  kitMotionStillTests(
    'KitSelectable',
    builds: {
      'default': () =>
          const KitSelectable(child: KitText('Select and copy this')),
    },
  );

  kitMotionStillTests(
    'KitLtr',
    builds: {
      'default': () => const KitLtr(child: KitText.mono('/home/user/project')),
    },
  );

  testWidgets('KitText shows its words in the role size and the tone colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const KitText(
          'Needs you · 40 s ago',
          role: KitTextRole.caption,
          tone: KitTextTone.attention,
        ),
      ),
    );
    expect(find.text('Needs you · 40 s ago'), findsOneWidget);
    final style = tester.widget<Text>(find.byType(Text)).style!;
    final roles = ThemeRoles.resolve(AppTheme.dark());
    expect(style.fontSize, 12);
    expect(style.color, roles.attention);
  });

  testWidgets('KitText without a tone takes its role\'s own tone', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KitText('Settings', role: KitTextRole.largeTitle),
            KitText('Laptop', role: KitTextRole.label),
          ],
        ),
      ),
    );
    final roles = ThemeRoles.resolve(AppTheme.dark());
    Color? colour(String text) =>
        tester.widget<Text>(find.text(text)).style!.color;
    expect(colour('Settings'), roles.text1);
    expect(colour('Laptop'), roles.text2);
  });

  testWidgets('mono KitText stays left to right inside Arabic', (tester) async {
    await tester.pumpWidget(
      _host(
        const KitText('src/checkout.dart', role: KitTextRole.mono),
        direction: TextDirection.rtl,
      ),
    );
    expect(
      tester.widget<Text>(find.text('src/checkout.dart')).textDirection,
      TextDirection.ltr,
    );
  });

  // --- KitText v2 (docs/ux-system/kit-api/KitText.md "Tests required") -----

  test('1. styleFor(role) equals LOOK-12 exactly for all ten roles', () {
    const table = <KitTextRole, (double, double, FontWeight)>{
      KitTextRole.largeTitle: (32, 38, FontWeight(650)),
      KitTextRole.title: (24, 30, FontWeight(650)),
      KitTextRole.headline: (17, 22, FontWeight.w600),
      KitTextRole.body: (16, 24, FontWeight.w400),
      KitTextRole.rowTitle: (16, 22, FontWeight.w500),
      KitTextRole.secondary: (14, 20, FontWeight.w400),
      KitTextRole.label: (13, 18, FontWeight.w600),
      KitTextRole.caption: (12, 16, FontWeight.w600),
      KitTextRole.button: (16, 20, FontWeight.w600),
      KitTextRole.mono: (13, 19, FontWeight.w400),
    };
    for (final MapEntry(key: role, value: (size, line, weight))
        in table.entries) {
      final style = KitText.styleFor(role);
      expect(style.fontSize, size, reason: '$role font size');
      expect(style.height, closeTo(line / size, 1e-9), reason: '$role height');
      expect(style.fontWeight, weight, reason: '$role weight');
    }
    // G19: the button role in particular is pinned at 16/20 w600, unchanged
    // from the visual-language branch (no value change in this unit).
    final button = KitText.styleFor(KitTextRole.button);
    expect(button.fontSize, 16);
    expect(button.height, 20 / 16);
    expect(button.fontWeight, FontWeight.w600);
  });

  testWidgets(
    '2. under Arabic every non-mono role has letter spacing 0 and falls '
    'back to Noto Sans Arabic',
    (tester) async {
      for (final role in KitTextRole.values) {
        late BuildContext capturedContext;
        await tester.pumpWidget(
          _arabicHost(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        final style = KitText.styleOf(capturedContext, role);
        expect(style.letterSpacing, 0, reason: '$role letter spacing');
        if (role != KitTextRole.mono) {
          // KitText.mono keeps AppMono (a technical value): the Arabic face
          // swap is for the nine prose roles that read Arabic words.
          expect(
            style.fontFamilyFallback,
            contains('Noto Sans Arabic'),
            reason: '$role fallback',
          );
        }
      }
    },
  );

  test('3. every tone colour is opaque in graphiteDark, graphiteLight and a '
      'deriveRoles pack', () {
    final packs = [
      graphiteDark,
      graphiteLight,
      deriveRoles(
        accent: const Color(0xFF3D8BFF),
        ground: const Color(0xFF101418),
        brightness: Brightness.dark,
      ),
    ];
    for (final roles in packs) {
      for (final tone in KitTextTone.values) {
        expect(
          KitText.toneColor(roles, tone).a,
          1.0,
          reason: '$tone in $roles',
        );
      }
    }
  });

  group('4. KitText.mono direction under TextDirection.rtl', () {
    testWidgets('the paragraph itself is left to right', (tester) async {
      await tester.pumpWidget(
        _host(
          const KitText.mono('src/checkout.dart'),
          direction: TextDirection.rtl,
        ),
      );
      final text = tester.widgetList<Text>(find.byType(Text)).single;
      expect(text.textDirection, TextDirection.ltr);
    });

    testWidgets('a short value sits at the parent\'s right edge under rtl', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(width: 300, child: KitText.mono('short-id')),
          direction: TextDirection.rtl,
        ),
      );
      final box = tester.getRect(find.byType(SizedBox).first);
      final glyphs = _glyphRect(tester, 'short-id');
      expect(glyphs.right, closeTo(box.right, 1.0));
    });

    testWidgets('under ltr the same value sits at the parent\'s left edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const SizedBox(width: 300, child: KitText.mono('short-id'))),
      );
      final box = tester.getRect(find.byType(SizedBox).first);
      final glyphs = _glyphRect(tester, 'short-id');
      expect(glyphs.left, closeTo(box.left, 1.0));
    });
  });

  group('5. KitMonoCut', () {
    const longPath = '/home/user/projects/very/long/path/main.dart';

    testWidgets('middle keeps a head and a tail around one ellipsis', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 200,
            child: KitText.mono(longPath, cut: KitMonoCut.middle),
          ),
        ),
      );
      final shown = tester.widgetList<Text>(find.byType(Text)).single.data!;
      expect(shown, isNot(longPath), reason: 'it must actually be cut');
      final parts = shown.split('…');
      expect(parts, hasLength(2), reason: 'exactly one ellipsis');
      final [head, tail] = parts;
      expect(head, isNotEmpty);
      expect(tail, isNotEmpty);
      expect(
        longPath.startsWith(head),
        isTrue,
        reason: 'the head is the path\'s own root',
      );
      expect(
        longPath.endsWith(tail),
        isTrue,
        reason: 'the tail is the path\'s own end (the file name)',
      );
      expect(head.length + tail.length, lessThan(longPath.length));
      final semantics = tester.getSemantics(find.text(shown));
      expect(semantics.label, longPath);
    });

    testWidgets('end keeps the head, cut off with a trailing ellipsis', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            width: 120,
            child: KitText.mono(longPath, cut: KitMonoCut.end),
          ),
        ),
      );
      final text = tester.widgetList<Text>(find.byType(Text)).single;
      expect(text.data, longPath);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
      final semantics = tester.getSemantics(find.byType(Text).first);
      expect(semantics.label, longPath);
    });
  });

  group('6. KitText.selectable', () {
    testWidgets(
      'a long-press selects, and the toolbar offers only Copy and Select '
      'all',
      (tester) async {
        // debugDefaultTargetPlatformOverride is one of the framework's own
        // "unset by the end of the test" invariants (ARCH-11, the pattern
        // test/goldens/kit/kit_gallery.dart uses): reset it in a finally,
        // synchronously before the test body returns, not addTearDown, which
        // the invariant check runs ahead of.
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await tester.pumpWidget(
            _host(const KitText.selectable('Copy me now')),
          );
          await tester.longPress(find.text('Copy me now'));
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.text('Copy'), findsOneWidget);
          expect(find.text('Select all'), findsOneWidget);
          expect(find.text('Cut'), findsNothing);
          expect(find.text('Paste'), findsNothing);
          expect(find.text('Share'), findsNothing);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets('Tab from a preceding button skips the text', (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                autofocus: true,
                onPressed: () {},
                child: const Text('Before'),
              ),
              const KitText.selectable('Copy this'),
              TextButton(onPressed: () {}, child: const Text('After')),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(_focusIn(tester, _button('Before')), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        _focusIn(tester, _button('After')),
        isTrue,
        reason: 'Tab from Before must skip the selectable text',
      );
    });
  });

  testWidgets(
    '7. KitSelectable(mode: finePointer): off on touch (an ancestor keeps '
    'the gesture), on for a fine pointer',
    (tester) async {
      addTearDown(() => debugPlatformCapabilities = null);

      debugPlatformCapabilities = const PlatformCapabilities.android();
      var longPressed = false;
      await tester.pumpWidget(
        _host(
          GestureDetector(
            onLongPress: () => longPressed = true,
            // Stands in for the not-yet-built KitTappable (R13): what
            // matters here is that the region does not eat the gesture.
            child: const KitSelectable(
              mode: KitSelectMode.finePointer,
              child: KitText('Row title'),
            ),
          ),
        ),
      );
      expect(find.byType(SelectionArea), findsNothing);
      await tester.longPress(find.text('Row title'));
      await tester.pump();
      expect(longPressed, isTrue);

      debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
      await tester.pumpWidget(
        _host(
          const KitSelectable(
            mode: KitSelectMode.finePointer,
            child: KitText('Row title'),
          ),
        ),
      );
      expect(
        find.byType(SelectionArea),
        findsOneWidget,
        reason: 'a fine pointer turns selection on, so a drag can select',
      );
    },
  );

  testWidgets(
    '8. KitSelectable.excluded leaves its content out of Select all + Copy',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final copied = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments! as Map)['text'] as String);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );

        await tester.pumpWidget(
          _host(
            const KitSelectable(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KitText('Selectable line'),
                  KitSelectable.excluded(child: KitText('secret-42')),
                ],
              ),
            ),
          ),
        );
        await tester.longPress(find.text('Selectable line'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Select all'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Copy'));
        await tester.pump();

        expect(copied, isNotEmpty);
        expect(copied.last, contains('Selectable line'));
        expect(copied.last, isNot(contains('secret-42')));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('9. tabular: true sets FontFeature.tabularFigures()', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const KitText('42', tabular: true)));
    final style = tester.widget<Text>(find.text('42')).style!;
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  testWidgets('10. KitLtr lays a Row left to right under an RTL ambient', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const KitLtr(child: Row(children: [KitText('A'), KitText('B')])),
        direction: TextDirection.rtl,
      ),
    );
    final a = tester.getCenter(find.text('A'));
    final b = tester.getCenter(find.text('B'));
    expect(a.dx, lessThan(b.dx));
  });

  testWidgets('11. at TextScaler.linear(2) the rendered size doubles', (
    tester,
  ) async {
    Future<double> widthAt(double scale) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: KitText('Hello'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getSize(find.text('Hello')).width;
    }

    final at1 = await widthAt(1);
    final at2 = await widthAt(2);
    expect(at2, closeTo(at1 * 2, 1.0));
  });

  // 12. Reduced motion (G8) is the kitMotionStillTests groups above: every
  // KitText sample (including 'selectable' and the middle-cut mono) and the
  // new KitSelectable/KitLtr parts settle after one pump() with no ticker
  // running, under both stillness settings.
}
