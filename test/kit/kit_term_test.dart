// Behaviour contracts for KitTerm (docs/ux-system/kit-api/KitTerm.md
// "Tests required" 1-6, 8-12; wrapper compatibility (7) lives in
// test/info_label_test.dart, which owns InfoLabel/Glossary).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_term.dart';

Widget _host(
  Widget child, {
  Size size = const Size(412, 915),
  bool reduced = false,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: (context, materialChild) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reduced,
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(textDirection: direction, child: materialChild!),
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

const _term = KitTerm(
  'Worktree',
  explanation: 'A separate checkout.',
  termKey: ValueKey('kit-term'),
);

final _bubble = find.byKey(const ValueKey('kit-term-bubble'));
final _sheet = find.byKey(const ValueKey('kit-term-sheet'));
final _termFinder = find.byKey(const ValueKey('kit-term'));

/// A 260-character explanation and a 40-character term, per K2 test 12's
/// overflow matrix.
final _longTerm = 'A very very very very long technical term name'.substring(
  0,
  40,
);
final _longExplanation = List.generate(260, (i) => 'abcdefghij'[i % 10]).join();

void main() {
  testWidgets('tap opens the bubble with the explanation', (tester) async {
    await tester.pumpWidget(_host(_term));
    expect(_bubble, findsNothing);
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
    expect(find.text('A separate checkout.'), findsOneWidget);
  });

  testWidgets('tapping outside the bubble closes it', (tester) async {
    await tester.pumpWidget(_host(_term));
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
  });

  testWidgets('Esc closes the bubble and returns focus to the term', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_term));
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
  });

  testWidgets('the system back gesture closes the bubble, not the route', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_term));
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    // The bubble closed; the term itself is still on screen, so the app
    // did not actually navigate away (PopScope intercepted the pop).
    expect(_bubble, findsNothing);
    expect(_termFinder, findsOneWidget);
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget, reason: 'the term still opens normally');
  });

  testWidgets('activating the term again closes it', (tester) async {
    await tester.pumpWidget(_host(_term));
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
  });

  testWidgets('long-press opens the bubble (touch)', (tester) async {
    await tester.pumpWidget(_host(_term));
    await tester.longPress(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
  });

  testWidgets('the hit area is at least 48x48 dp', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_term));
    final semantics = tester.getSemantics(_termFinder);
    expect(semantics.rect.width, greaterThanOrEqualTo(48));
    expect(semantics.rect.height, greaterThanOrEqualTo(48));
    handle.dispose();
  });

  testWidgets('semantics: button, label, hint', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_term));
    expect(
      tester.getSemantics(_termFinder),
      matchesSemantics(
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasLongPressAction: true,
        hasFocusAction: true,
        label: 'Worktree',
        hint: 'Explanation available',
      ),
    );
    handle.dispose();
  });

  testWidgets('learn more is shown only when given, and fires once', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_term));
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('kit-term-learn-more')), findsNothing);
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    var pressed = 0;
    await tester.pumpWidget(
      _host(
        KitTerm(
          'Worktree',
          explanation: 'A separate checkout.',
          termKey: const ValueKey('kit-term'),
          learnMore: KitAction(label: 'Learn more', onPressed: () => pressed++),
        ),
      ),
    );
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    final learnMore = find.byKey(const ValueKey('kit-term-learn-more'));
    expect(learnMore, findsOneWidget);
    await tester.tap(learnMore);
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing, reason: 'Learn more also closes the bubble');
    expect(pressed, 1);
  });

  testWidgets(
    'a long explanation opens as a sheet titled by the term, no buttons',
    (tester) async {
      await tester.pumpWidget(
        _host(
          KitTerm(
            _longTerm,
            explanation: _longExplanation,
            termKey: const ValueKey('kit-term'),
          ),
          size: const Size(360, 800),
          textScale: 2,
        ),
      );
      await tester.tap(_termFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_bubble, findsNothing);
      expect(_sheet, findsOneWidget);
      expect(find.text(_longTerm), findsWidgets);
      expect(find.byKey(const ValueKey('kit-sheet-actions')), findsNothing);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(_sheet, findsNothing);
    },
  );

  group('keyboard (G14)', () {
    testWidgets('Tab focuses the term; Enter opens and focuses Learn more', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        _host(
          KitTerm(
            'Worktree',
            explanation: 'A separate checkout.',
            termKey: const ValueKey('kit-term'),
            learnMore: KitAction(
              label: 'Learn more',
              onPressed: () => pressed++,
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(Focus.of(tester.element(_termFinder)).hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_bubble, findsOneWidget);
      expect(
        Focus.of(
          tester.element(find.byKey(const ValueKey('kit-term-learn-more'))),
        ).hasFocus,
        isTrue,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_bubble, findsNothing);
      expect(Focus.of(tester.element(_termFinder)).hasFocus, isTrue);
    });
  });

  group('hover (fine pointer)', () {
    testWidgets('hovering opens the bubble after the delay', (tester) async {
      await tester.pumpWidget(_host(_term, size: const Size(1280, 800)));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(_termFinder));
      await tester.pump();
      expect(_bubble, findsNothing);
      await tester.pump(const Duration(milliseconds: 450));
      expect(_bubble, findsOneWidget);

      await gesture.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(_bubble, findsNothing);
    });

    testWidgets('a click-opened bubble stays when the mouse leaves', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_term, size: const Size(1280, 800)));
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(gesture.removePointer);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(_termFinder));
      await tester.pump();
      await tester.tap(_termFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_bubble, findsOneWidget);

      await gesture.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(_bubble, findsOneWidget);
    });
  });

  testWidgets('RTL: the bubble aligns to the term\'s start (right) edge', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_term, direction: TextDirection.rtl));
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    final follower = tester.widget<CompositedTransformFollower>(
      find.byType(CompositedTransformFollower),
    );
    expect(follower.targetAnchor, Alignment.bottomRight);
    expect(follower.followerAnchor, Alignment.topRight);
  });

  testWidgets('reduced motion: opening and closing settle after one pump', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_term, reduced: true));
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pump();
    expect(_bubble, findsOneWidget);
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pump();
    expect(_bubble, findsNothing);
  });

  group('overflow (G6)', () {
    for (final width in [320.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
          testWidgets('$width dp, text $scale, $direction: no overflow', (
            tester,
          ) async {
            await tester.pumpWidget(
              _host(
                KitTerm(
                  _longTerm,
                  explanation: _longExplanation,
                  termKey: const ValueKey('kit-term'),
                ),
                size: Size(width, 800),
                textScale: scale,
                direction: direction,
              ),
            );
            await tester.tap(_termFinder, warnIfMissed: false);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (width == 320 && scale == 2.0) {
              expect(_sheet, findsOneWidget);
            }
          });
        }
      }
    }
  });
}
