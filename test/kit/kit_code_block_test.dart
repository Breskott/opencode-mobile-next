// KitCodeBlock (docs/ux-system/kit-api/KitCodeBlock.md, "Tests required"
// 1-13): copy, copy labels, the cap, wrap, the header, syntax highlight,
// redaction (G12), RTL, `.fill` virtualisation, empty text, reduced motion
// (G8x), semantics and the overflow matrix (G6).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';
import 'package:opencode_mobile/ui/kit/kit_redact.dart';

import 'kit_motion_still.dart';

Widget _app(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1,
  bool light = false,
  bool scroll = true,
}) => MaterialApp(
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
    body: scroll
        ? SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)
        : child,
  ),
);

/// Pumps [child] as a bounded (non-`.fill`) block's screen.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(412, 915),
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(child, locale: locale, textScale: textScale));
  await tester.pump();
}

/// Pumps a `.fill` block inside a fixed-height box (it needs bounded height
/// from its host, never a `Column`'s unbounded relay to a non-flex child).
Future<void> _pumpFill(
  WidgetTester tester,
  Widget child, {
  double height = 400,
  Size size = const Size(800, 900),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(SizedBox(height: height, child: child), scroll: false),
  );
  await tester.pump();
}

/// Every leaf text with the style it inherits (same walk as
/// test/code_highlight_test.dart's own helper).
List<({String text, TextStyle? style})> _leaves(
  InlineSpan span, [
  TextStyle? inherited,
]) {
  if (span is! TextSpan) return const [];
  final effective = span.style == null
      ? inherited
      : (inherited?.merge(span.style) ?? span.style);
  final result = <({String text, TextStyle? style})>[];
  if (span.text?.isNotEmpty == true) {
    result.add((text: span.text!, style: effective));
  }
  for (final child in span.children ?? const <InlineSpan>[]) {
    result.addAll(_leaves(child, effective));
  }
  return result;
}

const _copyKey = ValueKey('kit-code-copy');
const _wrapKey = ValueKey('kit-code-wrap');
const _horizontalKey = ValueKey('kit-code-horizontal');
const _showAllKey = ValueKey('kit-code-show-all');
const _blockKey = ValueKey('kit-code-block');

({
  List<MethodCall> platform,
  List<Map<Object?, Object?>> announcements,
  void Function() dispose,
})
_recordPlatform() {
  final platform = <MethodCall>[];
  final announcements = <Map<Object?, Object?>>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    platform.add(call);
    return null;
  });
  messenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (message) async {
      final map = message as Map<Object?, Object?>;
      if (map['type'] == 'announce') announcements.add(map);
      return null;
    },
  );
  return (
    platform: platform,
    announcements: announcements,
    dispose: () {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        null,
      );
    },
  );
}

String? _lastCopied(List<MethodCall> platform) {
  final call = platform.lastWhere((c) => c.method == 'Clipboard.setData');
  return (call.arguments as Map)['text'] as String?;
}

void main() {
  setUp(KitRedact.clearKnownSecrets);
  tearDown(KitRedact.clearKnownSecrets);

  group('1-2. copy', () {
    testWidgets('command copies without the \$, no SnackBar; copyText wins', (
      tester,
    ) async {
      final rec = _recordPlatform();
      addTearDown(rec.dispose);

      await _pump(
        tester,
        const KitCodeBlock(text: 'ls -la', kind: KitCodeKind.command),
      );
      await tester.tap(find.byKey(_copyKey));
      await tester.pump();
      expect(_lastCopied(rec.platform), 'ls -la');
      expect(find.byType(SnackBar), findsNothing);
      expect(
        rec.announcements
            .where((a) => (a['data'] as Map)['message'] == 'Copied')
            .length,
        1,
      );

      rec.platform.clear();
      await _pump(
        tester,
        const KitCodeBlock(
          text: 'ls -la',
          kind: KitCodeKind.command,
          copyText: 'ls -la --color=always',
        ),
      );
      await tester.tap(find.byKey(_copyKey));
      await tester.pump();
      expect(_lastCopied(rec.platform), 'ls -la --color=always');
    });

    testWidgets('copy label by kind, and the caller override', (tester) async {
      Future<String?> label(KitCodeBlock block) async {
        await _pump(tester, block);
        return tester.getSemantics(find.byKey(_copyKey)).label;
      }

      expect(
        await label(const KitCodeBlock(text: 'a', kind: KitCodeKind.code)),
        'Copy code',
      );
      expect(
        await label(const KitCodeBlock(text: 'a', kind: KitCodeKind.command)),
        'Copy command',
      );
      expect(
        await label(const KitCodeBlock(text: 'a', kind: KitCodeKind.output)),
        'Copy output',
      );
      expect(
        await label(
          const KitCodeBlock(text: 'a', copyLabel: 'Copy the recipe'),
        ),
        'Copy the recipe',
      );
    });
  });

  testWidgets(
    '3. cap: show all in place; onOpenFull calls back, never unfolds',
    (tester) async {
      final text = [for (var i = 1; i <= 40; i++) 'line $i'].join('\n');
      await _pump(tester, KitCodeBlock(text: text, maxLines: 12));
      // The shown lines join one paragraph (K2 §1.9), so a single line is
      // found by substring, not by the whole node's text.
      expect(find.textContaining('line 12'), findsOneWidget);
      expect(find.textContaining('line 13'), findsNothing);
      expect(find.text('Show all 40 lines'), findsOneWidget);
      await tester.tap(find.text('Show all 40 lines'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('line 40'), findsOneWidget);
      expect(find.text('Show all 40 lines'), findsNothing);

      var opened = 0;
      await _pump(
        tester,
        KitCodeBlock(text: text, maxLines: 12, onOpenFull: () => opened++),
      );
      expect(find.text('Open full output'), findsOneWidget);
      await tester.tap(find.text('Open full output'));
      await tester.pump();
      expect(opened, 1);
      expect(
        find.textContaining('line 13'),
        findsNothing,
        reason: 'never unfolds in place',
      );
    },
  );

  testWidgets('4. wrap: code scrolls on every window, output wraps on compact; '
      'command never wraps; toggle', (tester) async {
    const long =
        'a rather long single line of source that will need to either wrap '
        'onto a second line or scroll sideways depending on window width';

    // Code never soft-wraps by default (polish2): it scrolls sideways on
    // a phone too, with the Wrap toggle offered.
    await _pump(
      tester,
      const KitCodeBlock(text: long),
      size: const Size(360, 800),
    );
    expect(find.byKey(_horizontalKey), findsOneWidget);
    expect(find.byKey(_wrapKey), findsOneWidget);

    await _pump(
      tester,
      const KitCodeBlock(text: long, kind: KitCodeKind.output),
      size: const Size(360, 800),
    );
    expect(find.byKey(_horizontalKey), findsNothing);

    await _pump(
      tester,
      const KitCodeBlock(text: long),
      size: const Size(1280, 800),
    );
    expect(find.byKey(_horizontalKey), findsOneWidget);

    await _pump(
      tester,
      const KitCodeBlock(text: 'echo hi', kind: KitCodeKind.command),
      size: const Size(360, 800),
    );
    expect(find.byKey(_horizontalKey), findsOneWidget);
    expect(find.byKey(_wrapKey), findsNothing);

    // Self-managed toggle at a wide window (starts unwrapped).
    await _pump(
      tester,
      const KitCodeBlock(text: long),
      size: const Size(1280, 800),
    );
    expect(find.byKey(_horizontalKey), findsOneWidget);
    await tester.tap(find.byKey(_wrapKey));
    await tester.pump();
    expect(find.byKey(_horizontalKey), findsNothing);

    // Controlled: onWrapChanged calls back and the block waits for the host.
    bool? changed;
    await _pump(
      tester,
      KitCodeBlock(text: long, wrap: false, onWrapChanged: (v) => changed = v),
      size: const Size(1280, 800),
    );
    await tester.tap(find.byKey(_wrapKey));
    await tester.pump();
    expect(changed, isTrue);
    expect(
      find.byKey(_horizontalKey),
      findsOneWidget,
      reason: 'still unwrapped: only the host changes wrap',
    );
  });

  testWidgets('5. header: file name and +n -n; semantics read the sentence', (
    tester,
  ) async {
    await _pump(
      tester,
      const KitCodeBlock(
        text: 'class Foo {}',
        fileName: 'lib/main.dart',
        added: 4,
        removed: 1,
      ),
    );
    // The test harness's fallback font measures far wider than the real
    // mono face, so a narrow header may middle-ellipsis the name here even
    // though it reads whole on device (galleries prove that); the tail and
    // the full value in semantics are what matters (A11Y-8).
    final nameFinder = find.textContaining('main.dart');
    expect(nameFinder, findsOneWidget);
    expect(tester.getSemantics(nameFinder).label, 'lib/main.dart');
    expect(find.text('+4 −1'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '4 added, 1 removed',
      ),
      findsOneWidget,
    );
  });

  test('6a. KitCodeHighlight: keyword colour, unknown language, oversize', () {
    final span = KitCodeHighlight.spans('class Foo {}', 'dart', graphiteDark);
    final keyword = _leaves(span).firstWhere((l) => l.text == 'class');
    expect(keyword.style?.color, graphiteDark.codeKeyword);

    final plain = KitCodeHighlight.spans(
      'class Foo {}',
      'mystery',
      graphiteDark,
    );
    expect(plain.children, isNull);
    expect(plain.text, 'class Foo {}');

    final big = 'a' * (KitCodeHighlight.sizeLimit + 1);
    final overSize = KitCodeHighlight.spans(big, 'dart', graphiteDark);
    expect(overSize.children, isNull);
    expect(overSize.text, big);

    expect(KitCodeHighlight.supports('dart'), isTrue);
    expect(KitCodeHighlight.supports('mystery'), isFalse);
  });

  testWidgets('6b. highlight:false renders plain for a known language', (
    tester,
  ) async {
    await _pump(
      tester,
      const KitCodeBlock(text: 'class Foo {}', language: 'dart'),
    );
    Text richOf(WidgetTester t) => t
        .widgetList<Text>(find.byType(Text))
        .firstWhere((w) => w.textSpan!.toPlainText().contains('class'));
    final highlighted = _leaves(richOf(tester).textSpan!);
    expect(
      highlighted.firstWhere((l) => l.text == 'class').style?.color,
      graphiteDark.codeKeyword,
    );

    await _pump(
      tester,
      const KitCodeBlock(
        text: 'class Foo {}',
        language: 'dart',
        highlight: false,
      ),
    );
    final plain = _leaves(richOf(tester).textSpan!);
    expect(
      plain.firstWhere((l) => l.text.contains('class')).style?.color,
      isNot(graphiteDark.codeKeyword),
    );
  });

  testWidgets(
    '7. redaction (G12): a fake key never reaches the screen or clipboard',
    (tester) async {
      const key = 'sk-ant-api03-Zx9Qw8Er7Ty6Ui5Op4As3Df2';
      final rec = _recordPlatform();
      addTearDown(rec.dispose);

      await _pump(
        tester,
        const KitCodeBlock(text: 'using $key', kind: KitCodeKind.output),
      );
      expect(find.textContaining('Zx9Qw8Er7Ty6'), findsNothing);
      await tester.tap(find.byKey(_copyKey));
      await tester.pump();
      final copied = _lastCopied(rec.platform)!;
      expect(copied, isNot(contains('Zx9Qw8Er7Ty6')));
      expect(copied, contains('sk-ant-${KitRedact.mask}'));
    },
  );

  testWidgets('7b. a command with a fake key trips the debug assert', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const KitCodeBlock(
          text: 'curl -H "Authorization: Bearer sk-ant-api03-Zx9Qw8Er7Ty6"',
          kind: KitCodeKind.command,
        ),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('8. RTL: the block stays left to right and left-aligned', (
    tester,
  ) async {
    await _pump(
      tester,
      const KitCodeBlock(text: 'ls -la', kind: KitCodeKind.command),
      locale: const Locale('ar'),
    );
    final direction = tester
        .widget<Directionality>(
          find
              .ancestor(
                of: find.byKey(_blockKey),
                matching: find.byType(Directionality),
              )
              .first,
        )
        .textDirection;
    expect(direction, TextDirection.ltr);
    final blockLeft = tester.getTopLeft(find.byKey(_blockKey)).dx;
    final lineLeft = tester
        .getTopLeft(
          find
              .descendant(
                of: find.byKey(_blockKey),
                matching: find.byType(Text),
              )
              .first,
        )
        .dx;
    expect(lineLeft, closeTo(blockLeft, 24));
  });

  group('9. .fill', () {
    testWidgets('virtualises by line and scrolls to initialLine', (
      tester,
    ) async {
      final text = [for (var i = 1; i <= 5000; i++) 'line $i'].join('\n');
      await _pumpFill(
        tester,
        KitCodeBlock.fill(text: text, initialLine: 2000),
        size: const Size(800, 900),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kit-code-line-1')), findsNothing);
      expect(find.textContaining('line 2000'), findsWidgets);
    });

    testWidgets('paints marks, the active one differently', (tester) async {
      await _pumpFill(
        tester,
        const KitCodeBlock.fill(
          text: 'alpha beta gamma beta',
          marks: [TextRange(start: 6, end: 10), TextRange(start: 17, end: 21)],
          activeMark: 1,
        ),
        height: 120,
      );
      final span =
          tester
                  .widget<Text>(find.byKey(const ValueKey('kit-code-line-1')))
                  .textSpan!
              as TextSpan;
      final leaves = _leaves(span);
      final hits = leaves.where((l) => l.text == 'beta').toList();
      expect(hits, hasLength(2));
      expect(hits[0].style?.backgroundColor, isNotNull);
      expect(hits[1].style?.backgroundColor, isNotNull);
      expect(
        hits[0].style?.backgroundColor,
        isNot(hits[1].style?.backgroundColor),
      );
    });
  });

  testWidgets('10. empty text shows "Empty" with no Copy', (tester) async {
    await _pump(tester, const KitCodeBlock(text: ''));
    expect(find.text('Empty'), findsOneWidget);
    expect(find.byKey(_copyKey), findsNothing);

    await _pump(tester, const KitCodeBlock(text: '   \n  '));
    expect(find.text('Empty'), findsOneWidget);
  });

  testWidgets(
    '12. semantics: the scroller has scroll actions; wrap is toggled',
    (tester) async {
      // Wide enough that even a 1280 dp window must scroll to see the end.
      final long = 'x' * 400;
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        KitCodeBlock(text: long),
        size: const Size(1280, 800),
      );
      // A semantics update flushes on the frame after the scroll position
      // first reports its dimensions.
      await tester.pump();
      // `getSemantics` walks up from the found render object to the first
      // node carrying semantics, which lands on the header's shared
      // container (Wrap, Copy and the scroller are siblings under it); the
      // scroll extent lives on the scrollable's own child node, found by
      // searching down instead.
      final container = tester.getSemantics(find.byKey(_horizontalKey));
      // An ancestor container reports its own scrollExtentMax as 0 (not
      // null), so the real scrollable node is the one with the largest
      // value, not merely the first non-null one.
      var maxExtent = 0.0;
      void walk(SemanticsNode node) {
        final extent = node.getSemanticsData().scrollExtentMax;
        if (extent != null && extent > maxExtent) maxExtent = extent;
        node.visitChildren((child) {
          walk(child);
          return true;
        });
      }

      walk(container);
      // The default (Android/Clamping) scroll physics exposes scroll
      // position and extent to assistive tech rather than discrete
      // scrollLeft/scrollRight actions (those are an implicit-scrolling,
      // iOS-style affordance); this is what a screen reader reads here.
      expect(maxExtent, greaterThan(0));

      expect(
        tester.getSemantics(find.byKey(_wrapKey)),
        isSemantics(hasToggledState: true, isToggled: false),
      );
      handle.dispose();
    },
  );

  group('13. overflow (G6)', () {
    for (final size in const [Size(320, 640), Size(412, 915)]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final locale in const [Locale('en'), Locale('ar')]) {
          testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} · ${scale}x · '
            '${locale.languageCode}',
            (tester) async {
              await _pump(
                tester,
                KitCodeBlock(
                  text: 'echo ${'x' * 295}',
                  kind: KitCodeKind.command,
                  fileName: 'lib/${'y' * 190}/main.dart',
                ),
                size: size,
                locale: locale,
                textScale: scale,
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });

  kitMotionStillTests(
    'KitCodeBlock',
    builds: {
      'default': () =>
          const KitCodeBlock(text: 'class Foo {}', language: 'dart'),
      'capped': () => KitCodeBlock(
        text: [for (var i = 1; i <= 20; i++) 'line $i'].join('\n'),
        maxLines: 5,
      ),
    },
    changes: {
      // A single hidden line, so the revealed tail is one whole node's
      // text: KitMotionChange.shows matches a node's full text, not a
      // substring, and the shown lines join one paragraph (K2 §1.9).
      'show all': KitMotionChange(
        build: () => const KitCodeBlock(text: 'line 1\nline 2', maxLines: 1),
        act: (tester, stage) => stage.press(
          find.descendant(
            of: find.byKey(_showAllKey),
            matching: find.byType(TextButton),
          ),
        ),
        shows: 'line 2',
      ),
    },
  );
}
