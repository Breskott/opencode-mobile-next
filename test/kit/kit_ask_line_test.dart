// KitAskLine and KitSkeletonTranscript take the look
// (docs/ux-system/kit-api/KitAskLine.md): ThemeRoles, KitText and the kit's
// tokens only, with no API or behaviour change (KIT-43).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

Widget _host(
  Widget child, {
  bool light = false,
  double textScale = 1,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  theme: light ? AppTheme.light() : AppTheme.dark(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: app!,
  ),
  home: Scaffold(body: child),
);

void _setWidth(WidgetTester tester, double width, [double height = 900]) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

KitAskLine _askLine({
  String question = 'Tell me when the first reply arrives?',
  VoidCallback? onAccept,
  VoidCallback? onDecline,
}) => KitAskLine(
  icon: AppIconography.inbox,
  question: question,
  decline: KitAction(label: 'Not now', onPressed: onDecline ?? () {}),
  accept: KitAction(label: 'Notify me', onPressed: onAccept ?? () {}),
);

/// Every colour the paragraphs under [finder] paint their text with.
List<Color> _paintedTextColours(WidgetTester tester, Finder finder) {
  final colours = <Color>[];
  for (final paragraph in tester.renderObjectList<RenderParagraph>(
    find.descendant(of: finder, matching: find.byType(RichText)),
  )) {
    paragraph.text.visitChildren((span) {
      final colour = span.style?.color;
      if (colour != null) colours.add(colour);
      return true;
    });
  }
  return colours;
}

bool _opaque(Color colour) => colour.toARGB32() >> 24 == 0xFF;

void main() {
  group('KitAskLine', () {
    test('reads no colorScheme, textTheme, accent or partial-alpha text '
        '(LOOK-2, LOOK-6, LOOK-14)', () {
      final source = File('lib/ui/kit/kit_ask_line.dart').readAsStringSync();
      expect(source.contains('colorScheme'), isFalse);
      expect(source.contains('.textTheme'), isFalse);
      expect(source.contains('accent'), isFalse);
      expect(source.contains('withValues(alpha'), isFalse);
      expect(source.contains('withOpacity'), isFalse);
    });

    for (final light in [false, true]) {
      // Tertiary buttons are neutral (crit-look-2026-09-29): both answers
      // read in text1, never the accent, and the glyph and question keep
      // their opaque text roles.
      testWidgets('paints the glyph and question in opaque text roles and '
          'both answers in neutral text1 (${light ? 'light' : 'dark'})', (
        tester,
      ) async {
        _setWidth(tester, 412);
        await tester.pumpWidget(_host(_askLine(), light: light));
        final roles = ThemeRoles.of(tester.element(find.byType(KitAskLine)));

        Color only(Finder finder) {
          final colours = _paintedTextColours(tester, finder).toSet();
          expect(colours, hasLength(1), reason: '$finder');
          return colours.single;
        }

        final glyph = only(find.byIcon(AppIconography.inbox));
        final question = only(
          find.text('Tell me when the first reply arrives?'),
        );
        final decline = only(find.text('Not now'));
        final accept = only(find.text('Notify me'));
        expect(glyph, roles.text2);
        expect(question, roles.text1);
        expect(decline, roles.text1);
        expect(accept, roles.text1);

        final all = _paintedTextColours(tester, find.byType(KitAskLine));
        expect(all, isNotEmpty);
        for (final colour in all) {
          expect(_opaque(colour), isTrue, reason: '$colour is translucent');
          expect([roles.text1, roles.text2, roles.accent], contains(colour));
        }
      });
    }

    testWidgets('renders the question, a 20 dp text2 glyph and both answers; '
        'each answer fires once', (tester) async {
      _setWidth(tester, 412);
      var accepted = 0;
      var declined = 0;
      await tester.pumpWidget(
        _host(
          _askLine(onAccept: () => accepted++, onDecline: () => declined++),
        ),
      );

      expect(
        find.text('Tell me when the first reply arrives?'),
        findsOneWidget,
      );
      expect(find.text('Not now'), findsOneWidget);
      expect(find.text('Notify me'), findsOneWidget);

      final icon = tester.widget<Icon>(find.byIcon(AppIconography.inbox));
      expect(icon.size, 20);
      final roles = ThemeRoles.of(
        tester.element(find.byIcon(AppIconography.inbox)),
      );
      expect(icon.color, roles.text2);

      await tester.tap(find.text('Not now'));
      await tester.tap(find.text('Notify me'));
      expect(declined, 1);
      expect(accepted, 1);
    });

    testWidgets('sits beside the question when it fits; moves under it, '
        'start-aligned, at 2.0x text', (tester) async {
      // A wide window, not the literal 412 dp of item 2: the test font has
      // no narrow proportional metrics, so a width tuned for the real Geist
      // face would already wrap here. 412 dp with the real face is the
      // golden gallery's job (kit_ask_line_ask_inline_{dark,light}.png).
      _setWidth(tester, 900);
      await tester.pumpWidget(_host(_askLine(question: 'New reply?')));
      final inlineQuestion = tester.getRect(find.text('New reply?'));
      final inlineAccept = tester.getRect(find.text('Notify me'));
      // Beside: the button starts after the question and overlaps it
      // vertically, rather than sitting entirely below it.
      expect(inlineAccept.left, greaterThan(inlineQuestion.right));
      expect(inlineAccept.top, lessThan(inlineQuestion.bottom));

      await tester.pumpWidget(
        _host(_askLine(question: 'New reply?'), textScale: 2),
      );
      await tester.pumpAndSettle();
      final stackedQuestion = tester.getRect(find.text('New reply?'));
      final stackedAccept = tester.getRect(find.text('Notify me'));
      // Under, start-aligned: the button starts at or after the
      // question's own start edge and below its last line.
      expect(stackedAccept.top, greaterThanOrEqualTo(stackedQuestion.bottom));
      expect(stackedAccept.left, greaterThanOrEqualTo(stackedQuestion.left));
      expect(tester.takeException(), isNull);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('a long question at 320 dp stacks under it, start-aligned, '
          'with no overflow '
          '(${locale.languageCode})', (tester) async {
        _setWidth(tester, 320);
        await tester.pumpWidget(
          _host(
            _askLine(
              question:
                  'Tell me the moment the agent finishes its very first '
                  'reply in this conversation',
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final line = tester.getRect(find.byType(KitAskLine));
        expect(line.width, lessThanOrEqualTo(320));

        // Under the question: both answers start at or below its last line.
        final question = tester.getRect(
          find.textContaining('Tell me the moment'),
        );
        final accept = tester.getRect(find.text('Notify me'));
        final decline = tester.getRect(find.text('Not now'));
        expect(accept.top, greaterThanOrEqualTo(question.bottom));
        expect(decline.top, greaterThanOrEqualTo(question.bottom));
        // Start-aligned: the first answer's label (accept, then decline)
        // begins at the question's start edge (the button's own inset is
        // outdented by KitInset), right in RTL, left in LTR.
        final rtl = locale.languageCode == 'ar';
        expect(
          Directionality.of(tester.element(find.byType(KitAskLine))),
          rtl ? TextDirection.rtl : TextDirection.ltr,
        );
        if (rtl) {
          expect(accept.right, moreOrLessEquals(question.right, epsilon: 1));
          // Decline follows accept on its line, or wraps start-aligned.
          expect(
            decline.right < accept.left ||
                (decline.top >= accept.bottom &&
                    (decline.right - question.right).abs() <= 1),
            isTrue,
            reason: 'decline $decline after accept $accept',
          );
        } else {
          expect(accept.left, moreOrLessEquals(question.left, epsilon: 1));
          expect(
            decline.left > accept.right ||
                (decline.top >= accept.bottom &&
                    (decline.left - question.left).abs() <= 1),
            isTrue,
            reason: 'decline $decline after accept $accept',
          );
        }
      });
    }

    testWidgets('stacked at 2.0x text, the glyph is centred on the '
        "question's first line", (tester) async {
      _setWidth(tester, 412);
      await tester.pumpWidget(_host(_askLine(), textScale: 2));
      await tester.pumpAndSettle();
      final glyph = tester.getRect(find.byIcon(AppIconography.inbox));
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.text('Tell me when the first reply arrives?'),
          matching: find.byType(RichText),
        ),
      );
      final firstLine = paragraph
          .getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 1),
          )
          .single
          .toRect();
      final origin = paragraph.localToGlobal(Offset.zero);
      final lineCentre = origin.dy + firstLine.center.dy;
      expect(glyph.center.dy, moreOrLessEquals(lineCentre, epsilon: 2));
      // The block keeps a space3 (12 dp) inset above the question.
      final line = tester.getRect(find.byType(KitAskLine));
      expect(
        tester.getRect(find.text('Tell me when the first reply arrives?')).top -
            line.top,
        greaterThanOrEqualTo(12),
      );
    });

    testWidgets('no overflow from 320 to 1600 dp', (tester) async {
      for (final width in const <double>[320, 360, 412, 600, 800, 1200, 1600]) {
        _setWidth(tester, width);
        await tester.pumpWidget(_host(_askLine()));
        expect(tester.takeException(), isNull, reason: 'at ${width}dp');
      }
    });

    testWidgets('settles after one pump under reduced motion (G8)', (
      tester,
    ) async {
      _setWidth(tester, 412);
      await tester.pumpWidget(_host(_askLine()));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('first_reply_notify_card and chat_states callers compile '
        'against the unchanged constructor', (tester) async {
      // KIT-43: the same three positional dependencies (icon, question,
      // accept/decline as KitAction) and semanticsLabel still build.
      _setWidth(tester, 412);
      await tester.pumpWidget(
        _host(
          KitAskLine(
            key: const ValueKey('caller-key'),
            icon: AppIconography.inbox,
            question: 'Notify you when a reply is ready?',
            semanticsLabel: 'Notify you when a reply is ready?',
            decline: const KitAction(
              key: ValueKey('decline'),
              label: 'Not now',
              onPressed: null,
            ),
            accept: const KitAction(
              key: ValueKey('accept'),
              label: 'Notify me',
              onPressed: null,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('decline')), findsOneWidget);
      expect(find.byKey(const ValueKey('accept')), findsOneWidget);
    });
  });

  group('KitSkeletonTranscript', () {
    test('reads no colorScheme, textTheme, accent or alpha (LOOK-2)', () {
      final source = File(
        'lib/ui/kit/kit_skeleton_transcript.dart',
      ).readAsStringSync();
      expect(source.contains('colorScheme'), isFalse);
      expect(source.contains('.textTheme'), isFalse);
      expect(source.contains('accent'), isFalse);
      expect(source.contains('withValues(alpha'), isFalse);
      expect(source.contains('withOpacity'), isFalse);
    });

    for (final light in [false, true]) {
      testWidgets('paints every block and bar in opaque surface3, never the '
          'accent (${light ? 'light' : 'dark'})', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: light ? AppTheme.light() : AppTheme.dark(),
            home: const Scaffold(body: KitSkeletonTranscript()),
          ),
        );
        final roles = ThemeRoles.of(
          tester.element(find.byType(KitSkeletonTranscript)),
        );
        final boxes = tester.renderObjectList<RenderDecoratedBox>(
          find.descendant(
            of: find.byType(KitSkeletonTranscript),
            matching: find.byType(DecoratedBox),
          ),
        );
        // Two turns: a prompt block and three or four reply bars each.
        expect(boxes.length, 9);
        expect(_opaque(roles.surface3), isTrue);
        for (final box in boxes) {
          final decoration = box.decoration as ShapeDecoration;
          final colour = decoration.color!;
          expect(colour, roles.surface3);
          expect(_opaque(colour), isTrue);
          expect(colour, isNot(roles.accent));
          expect(decoration.gradient, isNull);
        }
      });
    }

    testWidgets('excluded from semantics; keeps its key', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox())),
      );
      final bareCount = tester.semantics
          .simulatedAccessibilityTraversal()
          .length;

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: KitSkeletonTranscript())),
      );
      expect(
        find.byKey(const ValueKey('kit-skeleton-transcript')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(KitSkeletonTranscript),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
      // The skeleton adds no semantics nodes over the bare screen.
      expect(
        tester.semantics.simulatedAccessibilityTraversal().length,
        bareCount,
      );
      handle.dispose();
    });

    testWidgets('at most 700 dp wide at 1280 dp', (tester) async {
      _setWidth(tester, 1280);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: KitSkeletonTranscript())),
      );
      final rect = tester.getRect(
        find.byKey(const ValueKey('kit-skeleton-transcript')),
      );
      expect(rect.width, lessThanOrEqualTo(700));
    });

    testWidgets('clips instead of overflowing in a 200 dp tall box', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(height: 200, child: KitSkeletonTranscript()),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('settles after one pump under reduced motion (G8)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: KitSkeletonTranscript())),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('chat_states caller compiles against the unchanged '
        'constructor', (tester) async {
      // KIT-43: `const KitSkeletonTranscript(key: ...)` still builds.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KitSkeletonTranscript(key: ValueKey('chat-loading')),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('chat-loading')), findsOneWidget);
    });
  });
}
