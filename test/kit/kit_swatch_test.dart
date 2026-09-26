// Behaviour tests for KitSwatch, KitSwatchGrid and KitThemePreview
// (docs/ux-system/kit-api/KitSwatch.md "Tests required"). Assertions are
// numbered to match that section.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_swatch.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

/// Pumps [child] as the whole body of an app at [size], in [light] or dark,
/// at [textScale] and in [locale] (Arabic flips the app to right to left).
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool light = false,
  Size size = const Size(700, 2000),
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: light ? AppTheme.light() : AppTheme.dark(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: widget!,
      ),
      home: Scaffold(
        body: Align(alignment: AlignmentDirectional.topStart, child: child),
      ),
    ),
  );
}

/// The number of swatches sharing the first (topmost) row's Y offset: the
/// grid's column count at whatever width it was given.
int _firstRowCount(WidgetTester tester, List<Key> keys) {
  final tops = [for (final key in keys) tester.getTopLeft(find.byKey(key)).dy];
  final first = tops.reduce((a, b) => a < b ? a : b);
  return tops.where((y) => (y - first).abs() < 1).length;
}

List<Key> _eightKeys() => List.generate(8, (i) => ValueKey('sw$i'));

/// An [Opacity] ancestor of [finder] that actually dims (opacity < 1): a
/// fully opaque `Opacity(opacity: 1.0)` from unrelated framework plumbing
/// does not count (STATE-8, LOOK-14: unavailable is said, never faded).
Finder _dimmedAncestors(Finder finder) => find.ancestor(
  of: finder,
  matching: find.byWidgetPredicate((w) => w is Opacity && w.opacity < 1),
);

/// The [Focus] widget a [KitSwatch] built with [swatchKey] wraps itself in.
Finder _swatchFocus(Key swatchKey) =>
    find.descendant(of: find.byKey(swatchKey), matching: find.byType(Focus));

/// Whether the [KitSwatch] built with [swatchKey] currently holds keyboard
/// focus. Reads the [Focus] widget's own [FocusNode] directly, since the
/// swatch's element itself sits *above* that node in the tree (`Focus.of`
/// looks upward from a context, so it cannot be used from the swatch's own
/// element).
bool _swatchHasFocus(WidgetTester tester, Key swatchKey) =>
    tester.widget<Focus>(_swatchFocus(swatchKey)).focusNode!.hasFocus;

/// Whether keyboard focus is on [target] itself or something inside it
/// (kit_keyboard_test.dart's pattern; a plain `Focus.of` cannot answer this
/// from an ancestor context, since it only looks upward).
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

Widget _eightThemeSwatches(List<Key> keys) => KitSwatchGrid(
  label: 'Theme',
  children: [
    for (var i = 0; i < keys.length; i++)
      KitSwatch(
        swatchKey: keys[i],
        roles: graphiteLight,
        label: 'Pack $i',
        selected: false,
        onPressed: () {},
      ),
  ],
);

void main() {
  group('press (test 1)', () {
    testWidgets('tapping a swatch calls onPressed once', (tester) async {
      var count = 0;
      await _pump(
        tester,
        KitSwatch(
          swatchKey: const ValueKey('sw'),
          roles: graphiteLight,
          label: 'Graphite',
          selected: false,
          onPressed: () => count++,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('sw')));
      await tester.pump();
      expect(count, 1);
    });

    testWidgets('Enter or Space on the focused swatch presses it too', (
      tester,
    ) async {
      var count = 0;
      await _pump(
        tester,
        KitSwatch(
          swatchKey: const ValueKey('sw'),
          roles: graphiteLight,
          label: 'Graphite',
          selected: false,
          onPressed: () => count++,
        ),
      );
      // A tap also focuses the swatch, like a real button.
      await tester.tap(find.byKey(const ValueKey('sw')));
      await tester.pump();
      expect(count, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(count, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(count, 3);
    });
  });

  group('selected (test 2)', () {
    testWidgets(
      'selected gives "In use" semantics, shows the check, and a 1 physical '
      'px accent border',
      (tester) async {
        await _pump(
          tester,
          KitSwatch(
            swatchKey: const ValueKey('sw'),
            roles: graphiteLight,
            label: 'Graphite',
            selected: true,
            onPressed: () {},
          ),
        );
        final node = tester.getSemantics(find.byKey(const ValueKey('sw')));
        expect(node.flagsCollection.isSelected, Tristate.isTrue);
        expect(node.value, 'In use');
        expect(find.byKey(const ValueKey('kit-swatch-check')), findsOneWidget);

        final tile = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('kit-swatch-tile')),
        );
        final decoration = tile.decoration as BoxDecoration;
        final border = decoration.border! as Border;
        expect(border.top.color, graphiteDark.accent);
        final context = tester.element(find.byKey(const ValueKey('sw')));
        expect(border.top.width, KitTokens.hairlineWidth(context));
        expect(border.top.width, lessThan(2));
      },
    );
  });

  group('disabled with reason (test 3)', () {
    test('disabledReason is required when onPressed is null', () {
      expect(
        () => KitSwatch(
          roles: graphiteLight,
          label: 'Graphite',
          selected: false,
          onPressed: null,
        ),
        throwsAssertionError,
      );
    });

    testWidgets(
      'with a reason: the reason is visible text, the tile is skipped by '
      'Tab, and no Opacity wraps any text',
      (tester) async {
        await _pump(
          tester,
          KitSwatch(
            swatchKey: const ValueKey('sw'),
            roles: graphiteLight,
            label: 'Material You',
            selected: false,
            onPressed: null,
            disabledReason: 'Needs Android 12 or later',
          ),
        );
        expect(find.text('Needs Android 12 or later'), findsOneWidget);
        expect(
          _dimmedAncestors(find.text('Needs Android 12 or later')),
          findsNothing,
        );
        expect(
          _dimmedAncestors(find.byKey(const ValueKey('kit-swatch-label'))),
          findsNothing,
        );
        final focus = _swatchFocus(const ValueKey('sw'));
        expect(tester.widget<Focus>(focus).skipTraversal, isTrue);
        expect(tester.widget<Focus>(focus).canRequestFocus, isFalse);
      },
    );
  });

  group('miniature colours (test 4)', () {
    testWidgets(
      'a graphiteLight swatch paints its own roles even under a dark app '
      'theme',
      (tester) async {
        await _pump(
          tester,
          KitSwatch(
            swatchKey: const ValueKey('sw'),
            roles: graphiteLight,
            label: 'Graphite',
            selected: false,
            onPressed: () {},
          ),
          light: false, // the app itself stays dark
        );
        Color colorOf(String key) =>
            (tester.widget<DecoratedBox>(find.byKey(ValueKey(key))).decoration
                    as BoxDecoration)
                .color!;
        expect(colorOf('kit-swatch-ground'), graphiteLight.ground);
        expect(colorOf('kit-swatch-panel'), graphiteLight.surface1);
        expect(colorOf('kit-swatch-text-line'), graphiteLight.text1);
        expect(colorOf('kit-swatch-accent-dot'), graphiteLight.accent);
        expect(colorOf('kit-swatch-success-dot'), graphiteLight.success);
      },
    );
  });

  group('accent swatch (test 5)', () {
    testWidgets('the check paints in onColor(color)', (tester) async {
      const blue = Color(0xFF1F6FEB); // a guarded Graphite accent (blue)
      await _pump(
        tester,
        KitSwatch.accent(
          swatchKey: const ValueKey('sw'),
          color: blue,
          label: 'Blue',
          selected: true,
          onPressed: () {},
        ),
      );
      final icon = tester.widget<Icon>(
        find.byKey(const ValueKey('kit-swatch-accent-check')),
      );
      expect(icon.color, onColor(blue));
    });

    testWidgets(
      'a colour inside the attention band asserts in debug (LOOK-39)',
      (tester) async {
        await _pump(
          tester,
          KitSwatch.accent(
            swatchKey: const ValueKey('sw'),
            color: graphiteDark.attention, // #FFB547: needs-you itself
            label: 'Amber',
            selected: false,
            onPressed: () {},
          ),
        );
        expect(tester.takeException(), isAssertionError);
      },
    );
  });

  group('grid columns (test 6)', () {
    testWidgets('3 columns at 412 dp of content', (tester) async {
      final keys = _eightKeys();
      await _pump(
        tester,
        SizedBox(width: 412, child: _eightThemeSwatches(keys)),
      );
      expect(_firstRowCount(tester, keys), 3);
    });

    testWidgets('2 columns at 320 dp of content', (tester) async {
      final keys = _eightKeys();
      await _pump(
        tester,
        SizedBox(width: 320, child: _eightThemeSwatches(keys)),
      );
      expect(_firstRowCount(tester, keys), 2);
    });

    testWidgets('6 columns at 900 dp of content (capped)', (tester) async {
      final keys = _eightKeys();
      await _pump(
        tester,
        SizedBox(width: 900, child: _eightThemeSwatches(keys)),
        size: const Size(960, 2000),
      );
      expect(_firstRowCount(tester, keys), 6);
    });

    testWidgets('one fewer column from text scale 1.3', (tester) async {
      final keys = _eightKeys();
      await _pump(
        tester,
        SizedBox(width: 412, child: _eightThemeSwatches(keys)),
        textScale: 1.3,
      );
      expect(_firstRowCount(tester, keys), 2);
    });
  });

  group('keyboard (test 7)', () {
    testWidgets('Tab enters the grid once, on the first swatch', (
      tester,
    ) async {
      final keys = _eightKeys();
      const after = ValueKey('after-the-grid');
      await _pump(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 412, child: _eightThemeSwatches(keys)),
            TextButton(
              key: after,
              onPressed: () {},
              child: const Text('After'),
            ),
          ],
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_swatchHasFocus(tester, keys[0]), isTrue);
      // The grid was one Tab stop: the very next Tab reaches the widget
      // after it, never swatch 1.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      for (final key in keys) {
        expect(_swatchHasFocus(tester, key), isFalse);
      }
      expect(_focusIn(tester, find.byKey(after)), isTrue);
    });

    testWidgets('→ moves to the next swatch', (tester) async {
      final keys = _eightKeys();
      await _pump(
        tester,
        SizedBox(width: 412, child: _eightThemeSwatches(keys)),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(_swatchHasFocus(tester, keys[1]), isTrue);
    });

    testWidgets('← moves to the next swatch under RTL', (tester) async {
      final keys = _eightKeys();
      await _pump(
        tester,
        SizedBox(width: 412, child: _eightThemeSwatches(keys)),
        locale: const Locale('ar'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(_swatchHasFocus(tester, keys[1]), isTrue);
    });

    testWidgets('↓ moves one row', (tester) async {
      final keys = _eightKeys();
      await _pump(
        tester,
        SizedBox(width: 412, child: _eightThemeSwatches(keys)),
      );
      final columns = _firstRowCount(tester, keys);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(_swatchHasFocus(tester, keys[columns]), isTrue);
    });
  });

  group('preview (test 8)', () {
    testWidgets(
      'KitThemePreview(roles: graphiteLight) inside a dark app paints the '
      'sample primary button in graphiteLight.accent, as one semantics node '
      'with no button nodes',
      (tester) async {
        await _pump(
          tester,
          const KitThemePreview(
            previewKey: ValueKey('preview'),
            roles: graphiteLight,
            label: 'Preview of Graphite',
          ),
          light: false,
        );
        final primary = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Send'),
            matching: find.byType(FilledButton),
          ),
        );
        final style = primary.style!;
        expect(style.backgroundColor!.resolve({}), graphiteLight.accent);
        final node = tester.getSemantics(find.byKey(const ValueKey('preview')));
        expect(node.label, 'Preview of Graphite');
        expect(node.flagsCollection.isImage, isTrue);
        expect(
          find.bySemanticsLabel('Send'),
          findsNothing,
          reason: 'the sample button is excluded from semantics',
        );
      },
    );
  });

  group('overflow and motion (test 9)', () {
    const sizes = [320.0, 412.0, 600.0, 840.0, 1280.0];
    const scales = [1.0, 1.3, 2.0];

    for (final width in sizes) {
      for (final scale in scales) {
        for (final locale in [const Locale('en'), const Locale('ar')]) {
          testWidgets(
            'no overflow at ${width.toInt()} · text $scale · ${locale.languageCode}',
            (tester) async {
              final keys = _eightKeys();
              await _pump(
                tester,
                SizedBox(width: width, child: _eightThemeSwatches(keys)),
                textScale: scale,
                locale: locale,
                size: Size(width + 40, 3000),
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets('settles after one pump()', (tester) async {
      await _pump(
        tester,
        KitSwatch(
          swatchKey: const ValueKey('sw'),
          roles: graphiteLight,
          label: 'Graphite',
          selected: true,
          onPressed: () {},
        ),
      );
      // No animation is left ticking (KitMotion: selection changes at once).
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.byKey(const ValueKey('kit-swatch-check')), findsOneWidget);
    });

    testWidgets('a disabled reason wraps and is never cut off', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 320,
          child: KitSwatch(
            swatchKey: const ValueKey('sw'),
            roles: graphiteLight,
            label: 'Material You',
            selected: false,
            onPressed: null,
            disabledReason:
                'This device is on an Android version older than 12, so the '
                'system palette is not available yet',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final reason = tester.widget<KitText>(
        find.byKey(const ValueKey('kit-swatch-reason')),
      );
      expect(reason.maxLines, isNull);
    });
  });
}
