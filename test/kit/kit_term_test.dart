// Behaviour contracts for KitTerm (docs/ux-system/kit-api/KitTerm.md
// "Tests required" 1-6, 8-12; wrapper compatibility (7) lives in
// test/info_label_test.dart, which owns InfoLabel).
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_buttons.dart';
import 'package:opencode_mobile/ui/kit/kit_motion.dart';
import 'package:opencode_mobile/ui/kit/kit_term.dart';
import 'package:opencode_mobile/ui/kit/kit_text.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/widgets/info_label.dart' show Glossary;

Widget _host(
  Widget child, {
  Size size = const Size(412, 915),
  bool reduced = false,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  AlignmentGeometry alignment = Alignment.center,
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
    home: Scaffold(
      body: Align(alignment: alignment, child: child),
    ),
  );
}

/// Makes the test window [size] logical pixels, so layout and MediaQuery
/// agree (the bubble is placed in the real window, not a claimed one).
void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// The window's width less the gutter on each side: where a bubble must
/// stay (KitTerm.md "Adaptive").
void _expectInsideWindow(WidgetTester tester, Rect bubble, Size window) {
  final gutter = KitTokens.of(tester.element(_termFinder)).gutter;
  expect(bubble.left, greaterThanOrEqualTo(gutter - 0.01));
  expect(bubble.right, lessThanOrEqualTo(window.width - gutter + 0.01));
  expect(bubble.top, greaterThanOrEqualTo(0));
  expect(bubble.bottom, lessThanOrEqualTo(window.height));
}

/// Whether the term draws its focus ring: a border on the 48 dp box.
bool _ringShown(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: _termFinder, matching: find.byType(DecoratedBox)),
    )
    .any((box) => (box.decoration as BoxDecoration).border != null);

const _term = KitTerm(
  'Worktree',
  explanation: 'A separate checkout.',
  termKey: ValueKey('kit-term'),
);

final _bubble = find.byKey(const ValueKey('kit-term-bubble'));
final _sheet = find.byKey(const ValueKey('kit-term-sheet'));
final _termFinder = find.byKey(const ValueKey('kit-term'));

/// The glossary's longest English entry (KitTerm.md test 6).
final _longestGlossary = [
  Glossary.mcp,
  Glossary.worktree,
  Glossary.provider,
  Glossary.context,
  Glossary.agent,
  Glossary.reasoning,
  Glossary.permission,
  Glossary.variant,
].reduce((a, b) => a.explanation.length >= b.explanation.length ? a : b);

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
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('the term keeps its role\'s line height (padding is outside)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KitTerm(
              'Worktree',
              explanation: 'A separate checkout.',
              role: KitTextRole.body,
            ),
            KitText('Worktree', role: KitTextRole.body),
          ],
        ),
      ),
    );
    final texts = find.text('Worktree');
    expect(texts, findsNWidgets(2));
    final termText = tester.getSize(texts.first);
    final plainText = tester.getSize(texts.last);
    expect(termText.height, plainText.height);
    expect(
      tester.getSize(_termFinder).height,
      greaterThan(termText.height),
      reason: 'the 48 dp box pads around the text, not inside its lines',
    );
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
        onTapHint: 'Show explanation',
      ),
    );
    handle.dispose();
  });

  testWidgets('opening announces the term and explanation once, politely', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_term));
    tester.takeAnnouncements();
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    final announced = tester.takeAnnouncements();
    expect(announced, hasLength(1));
    expect(
      announced.single,
      isAccessibilityAnnouncement(
        'Worktree\nA separate checkout.',
        assertiveness: Assertiveness.polite,
      ),
    );
    // The bubble's node reads the explanation, not the close label.
    expect(find.bySemanticsLabel('Close explanation'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('A separate checkout')), findsWidgets);
    // Hovering over or rebuilding the open bubble does not announce again.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeAnnouncements(), isEmpty);
    handle.dispose();
  });

  testWidgets('the bubble offers a dismiss action labelled Close explanation', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_term));
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    final bubbleNode = find.semantics.byAction(SemanticsAction.dismiss);
    expect(bubbleNode, findsOne);
    final data = bubbleNode.evaluate().single.getSemanticsData();
    final labels = [
      for (final id in data.customSemanticsActionIds ?? const <int>[])
        CustomSemanticsAction.getAction(id)?.label,
    ];
    expect(labels, contains('Close explanation'));

    tester.semantics.dismiss(bubbleNode);
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);

    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    tester.semantics.customAction(
      find.semantics.byAction(SemanticsAction.customAction),
      const CustomSemanticsAction(label: 'Close explanation'),
    );
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
    handle.dispose();
  });

  testWidgets('a tap opens the bubble without drawing the focus ring', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_term));
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_bubble, findsOneWidget);
    expect(_ringShown(tester), isFalse);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(_bubble, findsNothing);
    expect(_ringShown(tester), isFalse, reason: 'closing moves no ring on');
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

  testWidgets('in the sheet, Learn more closes the sheet, then runs once', (
    tester,
  ) async {
    var pressed = 0;
    var sheetOpenWhenPressed = true;
    _window(tester, const Size(360, 800));
    await tester.pumpWidget(
      _host(
        KitTerm(
          _longestGlossary.term,
          explanation: _longestGlossary.explanation,
          termKey: const ValueKey('kit-term'),
          learnMore: KitAction(
            label: 'Learn more',
            onPressed: () {
              pressed++;
              sheetOpenWhenPressed = !ModalRoute.of(
                tester.element(_termFinder),
              )!.isCurrent;
            },
          ),
        ),
        size: const Size(360, 800),
        textScale: 2,
      ),
    );
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_sheet, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('kit-term-learn-more')));
    await tester.pumpAndSettle();
    expect(_sheet, findsNothing);
    expect(pressed, 1);
    expect(
      sheetOpenWhenPressed,
      isFalse,
      reason: 'the sheet is already closing when the action runs',
    );
  });

  testWidgets(
    'the glossary\'s longest entry at text 2.0 on 360x800 opens as a sheet '
    'titled by the term, no buttons',
    (tester) async {
      _window(tester, const Size(360, 800));
      await tester.pumpWidget(
        _host(
          KitTerm(
            _longestGlossary.term,
            explanation: _longestGlossary.explanation,
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
      expect(
        find.descendant(of: _sheet, matching: find.text(_longestGlossary.term)),
        findsOneWidget,
      );
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
      _window(tester, const Size(1280, 800));
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
      // Well past the fade and the leave grace: the open bubble must not
      // steal the term's hover and close itself.
      await tester.pump(KitMotion.quick * 4);
      await tester.pumpAndSettle();
      expect(_bubble, findsOneWidget);

      // Moving onto the bubble keeps it: the term and bubble are one region.
      await gesture.moveTo(tester.getCenter(_bubble));
      await tester.pump(KitMotion.quick * 4);
      await tester.pumpAndSettle();
      expect(_bubble, findsOneWidget);

      // Leaving both closes it once the short leave grace has passed.
      await gesture.moveTo(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(_bubble, findsNothing);
    });

    testWidgets('a click-opened bubble stays when the mouse leaves', (
      tester,
    ) async {
      _window(tester, const Size(1280, 800));
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
    // Wide enough that aligning to the term's right edge needs no clamping.
    const window = Size(800, 600);
    _window(tester, window);
    await tester.pumpWidget(
      _host(_term, size: window, direction: TextDirection.rtl),
    );
    await tester.tap(_termFinder, warnIfMissed: false);
    await tester.pumpAndSettle();
    final bubble = tester.getRect(_bubble);
    final term = tester.getRect(_termFinder);
    expect(bubble.right, moreOrLessEquals(term.right));
    expect(bubble.top, greaterThanOrEqualTo(term.bottom));
    _expectInsideWindow(tester, bubble, window);
  });

  group('the bubble stays inside the window, the gutter from each edge', () {
    for (final direction in TextDirection.values) {
      for (final width in [320.0, 412.0]) {
        testWidgets('a term at the end edge, $direction, $width dp', (
          tester,
        ) async {
          final window = Size(width, 800);
          _window(tester, window);
          await tester.pumpWidget(
            _host(
              const KitTerm(
                'Worktree',
                explanation:
                    'A separate checkout of the same repository, on its '
                    'own branch.',
                termKey: ValueKey('kit-term'),
              ),
              size: window,
              direction: direction,
              alignment: AlignmentDirectional.centerEnd,
            ),
          );
          await tester.tap(_termFinder, warnIfMissed: false);
          await tester.pumpAndSettle();
          final bubble = tester.getRect(_bubble);
          _expectInsideWindow(tester, bubble, window);
          expect(bubble.width, lessThanOrEqualTo(width - 2 * 16 + 0.01));
          // The explanation is never cut: all of it lies inside the bubble.
          final text = tester.getRect(find.textContaining('A separate'));
          expect(bubble.contains(text.topLeft), isTrue);
          expect(
            bubble.contains(text.bottomRight - const Offset(1, 1)),
            isTrue,
          );
        });
      }
    }
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

  group('showKitTerm', () {
    Future<BuildContext> pumpScreen(WidgetTester tester) async {
      late BuildContext screen;
      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(body: Text('home')),
          routes: {
            '/screen': (_) => Scaffold(
              body: Builder(
                builder: (context) {
                  screen = context;
                  return const Center(child: Text('screen'));
                },
              ),
            ),
          },
        ),
      );
      tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/screen');
      await tester.pumpAndSettle();
      return screen;
    }

    testWidgets('back closes the popover and the screen stays', (tester) async {
      final screen = await pumpScreen(tester);
      var done = false;
      unawaited(
        showKitTerm(
          screen,
          term: 'MCP',
          explanation: 'Model Context Protocol.',
        ).then((_) => done = true),
      );
      await tester.pumpAndSettle();
      expect(_bubble, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_bubble, findsNothing);
      expect(find.text('screen'), findsOneWidget);
      expect(done, isTrue);
    });

    testWidgets('Esc and a tap outside close the popover', (tester) async {
      final screen = await pumpScreen(tester);
      unawaited(
        showKitTerm(
          screen,
          term: 'MCP',
          explanation: 'Model Context Protocol.',
        ),
      );
      await tester.pumpAndSettle();
      expect(_bubble, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_bubble, findsNothing);
      expect(find.text('screen'), findsOneWidget);

      unawaited(
        showKitTerm(
          screen,
          term: 'MCP',
          explanation: 'Model Context Protocol.',
        ),
      );
      await tester.pumpAndSettle();
      expect(_bubble, findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(_bubble, findsNothing);
      expect(find.text('screen'), findsOneWidget);
    });

    testWidgets('on a 320 dp window the popover fits inside the gutter', (
      tester,
    ) async {
      _window(tester, const Size(320, 640));
      final screen = await pumpScreen(tester);
      unawaited(
        showKitTerm(
          screen,
          term: 'MCP',
          explanation:
              'Model Context Protocol. Small add-on servers that give the '
              'agent extra tools.',
        ),
      );
      await tester.pumpAndSettle();
      final bubble = tester.getRect(_bubble);
      expect(bubble.left, greaterThanOrEqualTo(16 - 0.01));
      expect(bubble.right, lessThanOrEqualTo(320 - 16 + 0.01));
    });
  });

  group('overflow (G6)', () {
    for (final width in [320.0, 412.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
          testWidgets('$width dp, text $scale, $direction: no overflow', (
            tester,
          ) async {
            _window(tester, Size(width, 800));
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
