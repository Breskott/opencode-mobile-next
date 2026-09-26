// KitChip (docs/ux-system/kit-api/KitChip.md): the frozen "Tests required"
// contract, K2 §7 G9, the reduced-motion sample (G8x, MOT-7) and the
// keyboard behaviour (G14).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_chip.dart';

import 'kit_motion_still.dart';

/// Pumps [child] as a screen's body, with the real test window sized to
/// [size] (not just a MediaQuery override), so a widget's own render
/// position — and therefore [WidgetTester.tap] and [WidgetTester.getSize] —
/// line up with what a person would actually see.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool light = false,
  Size size = const Size(412, 915),
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
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

/// Whether keyboard focus is on [target] itself or a descendant of it
/// (test/kit/kit_keyboard_test.dart's own helper, kept local so this file's
/// write set stays just its own tests).
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

const _bodyKey = ValueKey('kit-chip-body');
const _checkKey = ValueKey('kit-chip-check');
const _removeKey = ValueKey('kit-chip-remove');

void main() {
  kitMotionStillTests(
    'KitChip',
    builds: {
      'plain': () => const KitChip(label: 'main'),
      'count': () => KitChip.count(label: 'Tasks', count: 3),
      'removable': () => KitChip.removable(label: 'file.txt', onRemove: () {}),
    },
    changes: {
      'action selects': KitMotionChange(
        build: () => KitChip.action(
          label: 'Open in terminal',
          onPressed: () {},
          selected: false,
        ),
        act: (tester, stage) => stage.rebuild(
          KitChip.action(
            label: 'Open in terminal',
            onPressed: () {},
            selected: true,
          ),
        ),
        shows: 'Open in terminal',
      ),
      'summary expands': KitMotionChange(
        build: () => KitChip.summary(
          label: 'Read 3 files · edited 1',
          onPressed: () {},
          expanded: false,
        ),
        act: (tester, stage) => stage.rebuild(
          KitChip.summary(
            label: 'Read 3 files · edited 1',
            onPressed: () {},
            expanded: true,
          ),
        ),
        shows: 'Read 3 files · edited 1',
      ),
    },
  );

  group('plain', () {
    testWidgets('is not a button, has no tap action, is not focusable', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const KitChip(label: 'main'));
      expect(
        tester.getSemantics(find.text('main')),
        isSemantics(
          label: 'main',
          isButton: false,
          hasTapAction: false,
          isFocusable: false,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusIn(tester, find.text('main')), isFalse);
      handle.dispose();
    });
  });

  group('action', () {
    testWidgets('tapping calls onPressed once', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        KitChip.action(label: 'Open in terminal', onPressed: () => taps++),
      );
      // The overlay tap zone (Stack, on top of the visible label) is what
      // actually receives the tap; warnIfMissed would flag that
      // correct, deliberate layering as a mismatch.
      await tester.tap(find.text('Open in terminal'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('selected: true shows the check and toggled: true', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        KitChip.action(label: 'Ask first', onPressed: () {}, selected: true),
      );
      expect(find.byKey(_checkKey), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Ask first')),
        isSemantics(
          label: 'Ask first',
          isButton: true,
          hasToggledState: true,
          isToggled: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('selected: null has no toggled flag', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, KitChip.action(label: 'Retry', onPressed: () {}));
      expect(find.byKey(_checkKey), findsNothing);
      expect(
        tester.getSemantics(find.text('Retry')),
        isSemantics(label: 'Retry', isButton: true, hasToggledState: false),
      );
      handle.dispose();
    });
  });

  group('removable', () {
    testWidgets('the x is a separate 48x48 target labelled "Remove {label}"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        KitChip.removable(label: 'file.txt', onRemove: () {}),
      );
      final x = find.byKey(_removeKey);
      expect(x, findsOneWidget);
      final size = tester.getSize(x);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(
        tester.getSemantics(x),
        isSemantics(label: 'Remove file.txt', isButton: true),
      );
      handle.dispose();
    });

    testWidgets('tapping the x calls onRemove only, not onPressed', (
      tester,
    ) async {
      var removed = 0;
      var pressed = 0;
      await _pump(
        tester,
        KitChip.removable(
          label: 'file.txt',
          onRemove: () => removed++,
          onPressed: () => pressed++,
        ),
      );
      await tester.tap(find.byKey(_removeKey));
      await tester.pump();
      expect(removed, 1);
      expect(pressed, 0);
    });

    testWidgets('tapping the body calls onPressed only, not onRemove', (
      tester,
    ) async {
      var removed = 0;
      var pressed = 0;
      await _pump(
        tester,
        KitChip.removable(
          label: 'file.txt',
          onRemove: () => removed++,
          onPressed: () => pressed++,
        ),
      );
      await tester.tap(find.byKey(_bodyKey));
      await tester.pump();
      expect(pressed, 1);
      expect(removed, 0);
    });

    testWidgets('Delete on the focused chip calls onRemove', (tester) async {
      var removed = 0;
      await _pump(
        tester,
        KitChip.removable(label: 'file.txt', onRemove: () => removed++),
      );
      // Only the x is focusable here (no onPressed), so one Tab reaches it.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusIn(tester, find.byKey(_removeKey)), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(removed, 1);
    });

    testWidgets('Backspace on the focused x also calls onRemove', (
      tester,
    ) async {
      var removed = 0;
      await _pump(
        tester,
        KitChip.removable(label: 'file.txt', onRemove: () => removed++),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(removed, 1);
    });
  });

  group('count', () {
    testWidgets('semantics label is "{label}, {count}"', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, KitChip.count(label: 'Tasks', count: 3));
      expect(
        tester.getSemantics(find.textContaining('Tasks')),
        isSemantics(label: 'Tasks, 3'),
      );
      handle.dispose();
    });

    testWidgets('the number is formatted with intl for en and ar', (
      tester,
    ) async {
      const count = 1234;
      final en = NumberFormat.decimalPattern('en').format(count);
      final ar = NumberFormat.decimalPattern('ar').format(count);
      await _pump(tester, KitChip.count(label: 'Tasks', count: count));
      expect(find.textContaining(en), findsOneWidget);

      await _pump(
        tester,
        KitChip.count(label: 'المهام', count: count),
        locale: const Locale('ar'),
      );
      expect(find.textContaining(ar), findsOneWidget);
    });

    testWidgets('with onPressed it is a button that fires once', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        KitChip.count(label: 'Tasks', count: 3, onPressed: () => taps++),
      );
      await tester.tap(find.textContaining('Tasks'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('summary', () {
    testWidgets('a tap calls onPressed', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        KitChip.summary(
          label: 'Read 3 files · edited 1',
          onPressed: () => taps++,
        ),
      );
      await tester.tap(
        find.text('Read 3 files · edited 1'),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('expanded true/false exposes expanded semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        KitChip.summary(
          label: 'Read 3 files',
          onPressed: () {},
          expanded: false,
        ),
      );
      expect(
        tester.getSemantics(find.text('Read 3 files')),
        isSemantics(hasExpandedState: true, isExpanded: false),
      );
      await _pump(
        tester,
        KitChip.summary(
          label: 'Read 3 files',
          onPressed: () {},
          expanded: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Read 3 files')),
        isSemantics(hasExpandedState: true, isExpanded: true),
      );
      handle.dispose();
    });

    testWidgets('the chevron turns from down to up', (tester) async {
      await _pump(
        tester,
        KitChip.summary(
          label: 'Read 3 files',
          onPressed: () {},
          expanded: false,
        ),
      );
      final folded = tester.widget<AnimatedRotation>(
        find.byType(AnimatedRotation),
      );
      expect(folded.turns, 0);
      await _pump(
        tester,
        KitChip.summary(
          label: 'Read 3 files',
          onPressed: () {},
          expanded: true,
        ),
      );
      await tester.pumpAndSettle();
      final open = tester.widget<AnimatedRotation>(
        find.byType(AnimatedRotation),
      );
      expect(open.turns, 0.5);
    });
  });

  group('hit area (LAY-9)', () {
    const key = ValueKey('under-test');

    Future<void> expectFortyEight(WidgetTester tester, double textScale) async {
      await _pump(
        tester,
        KitChip.action(key: key, label: 'Open in terminal', onPressed: () {}),
        textScale: textScale,
      );
      final size = tester.getSize(find.byKey(key));
      expect(size.height, greaterThanOrEqualTo(48));
    }

    testWidgets('at least 48 dp high at text 1.0', (tester) async {
      await expectFortyEight(tester, 1);
    });

    testWidgets('at least 48 dp high at text 2.0', (tester) async {
      await expectFortyEight(tester, 2);
    });

    testWidgets(
      'ten chips in a KitChipWrap at 320 dp never overlap their hit areas',
      (tester) async {
        final keys = List.generate(10, (i) => GlobalKey());
        await _pump(
          tester,
          SizedBox(
            width: 320,
            child: KitChipWrap(
              children: [
                for (var i = 0; i < 10; i++)
                  KitChip.action(
                    key: keys[i],
                    label: 'Chip $i',
                    onPressed: () {},
                  ),
              ],
            ),
          ),
          size: const Size(320, 915),
        );
        final rects = [for (final key in keys) tester.getRect(find.byKey(key))];
        for (var i = 0; i < rects.length; i++) {
          for (var j = i + 1; j < rects.length; j++) {
            expect(
              rects[i].overlaps(rects[j]),
              isFalse,
              reason: 'chip $i and chip $j overlap: ${rects[i]} / ${rects[j]}',
            );
          }
        }
      },
    );
  });

  group('truncation (A11Y-8, G6)', () {
    const long =
        'A genuinely very long chip label that will not fit on one line at '
        'any of the overflow widths this test pumps it at';

    testWidgets(
      'at text 2.0 a long label ellipsises with the full text in semantics',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pump(
          tester,
          const KitChip(label: long),
          textScale: 2,
          size: const Size(320, 800),
        );
        final text = tester.widget<Text>(find.text(long));
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
        expect(tester.getSemantics(find.text(long)), isSemantics(label: long));
        handle.dispose();
      },
    );

    for (final width in [320.0, 360.0, 412.0]) {
      for (final ltr in [true, false]) {
        testWidgets('no overflow at $width dp, ${ltr ? 'LTR' : 'RTL'}', (
          tester,
        ) async {
          await _pump(
            tester,
            Directionality(
              textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
              child: KitChip.removable(label: long, onRemove: () {}),
            ),
            size: Size(width, 800),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('honesty (LOOK-14, LOOK-4)', () {
    testWidgets('no text is painted below full alpha, no attention role', (
      tester,
    ) async {
      final roles = ThemeRoles.resolve(AppTheme.dark());
      await _pump(
        tester,
        KitChipWrap(
          children: [
            const KitChip(label: 'main', icon: Icons.circle),
            KitChip.action(
              label: 'Open in terminal',
              onPressed: () {},
              selected: true,
            ),
            KitChip.removable(label: 'file.txt', onRemove: () {}),
            KitChip.count(label: 'Tasks', count: 3),
            KitChip.summary(
              label: 'Read 3 files · edited 1',
              onPressed: () {},
              expanded: true,
            ),
          ],
        ),
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final color = text.style?.color;
        if (color != null) {
          expect(
            color.a,
            1,
            reason: '${text.data} painted at ${color.a} alpha',
          );
        }
      }
      for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
        expect(icon.color, isNot(roles.attention));
      }
    });
  });

  group('keyboard (G14)', () {
    testWidgets('Tab order is the chip, then its x; Enter and Space activate', (
      tester,
    ) async {
      var pressed = 0;
      var removed = 0;
      await _pump(
        tester,
        KitChip.removable(
          label: 'file.txt',
          onPressed: () => pressed++,
          onRemove: () => removed++,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusIn(tester, find.byKey(_bodyKey)), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(pressed, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusIn(tester, find.byKey(_removeKey)), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(removed, 1);
    });
  });
}
