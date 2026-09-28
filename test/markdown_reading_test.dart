import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';
import 'package:opencode_mobile/ui/widgets/markdown.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  bool rtl = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

// Since 79d941e4 (KitMarkdown; markdown.dart forwards to it) a fence is a
// KitCodeBlock: Copy (and Wrap, while a line is wider than the block) sit at
// the end of the first line, there is no "Code options" menu, and the full
// reader opens from a capped block's "Open full output" (K2 §1.9, R3).

/// A fence longer than KitMarkdown's 12-line cap, so it offers the reader.
String _cappedFence(
  String first, {
  String fence = '```',
  String info = '',
  bool close = true,
}) =>
    '$fence$info\n$first\n${List.generate(13, (i) => 'line $i').join('\n')}'
    '${close ? '\n$fence' : ''}';

Future<void> _openReader(WidgetTester tester) async {
  await tester.tap(find.text('Open full output'));
  await tester.pumpAndSettle();
}

/// The leaf texts of the code body's spans (one Text.rich per block).
List<String> _codeLeaves(WidgetTester tester) {
  final leaves = <String>[];
  void walk(InlineSpan span) {
    if (span is! TextSpan) return;
    if (span.text?.isNotEmpty == true) leaves.add(span.text!);
    for (final child in span.children ?? const <InlineSpan>[]) {
      walk(child);
    }
  }

  final text = tester.widget<Text>(
    find.descendant(of: find.byType(KitCodeBlock), matching: find.byType(Text)),
  );
  walk(text.textSpan!);
  return leaves;
}

/// A Markdown table: KitMarkdown labels its box "Table, n rows".
final _table = find.byWidgetPredicate(
  (w) => w is Semantics && (w.properties.label ?? '').startsWith('Table, '),
);

void main() {
  for (final scale in [1.0, 2.5]) {
    testWidgets('short code keeps a single toolbar row at ${scale}x', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pump(
        tester,
        const Padding(
          padding: EdgeInsets.all(16),
          child: MarkdownText('```bash\nnpm run dev\n```'),
        ),
        scale: scale,
      );
      // No menu: Copy is the block's one action, on its first line, with
      // Wrap stacked under it only while a line is wider than the block.
      expect(find.byTooltip('Code options'), findsNothing);
      final block = tester.getTopLeft(find.byType(KitCodeBlock)).dy;
      final copy = find.byTooltip('Copy code');
      expect(tester.getSize(copy), const Size(48, 48));
      expect(tester.getTopLeft(copy).dy - block, lessThanOrEqualTo(4));
      final data = tester.getSemantics(copy).getSemanticsData();
      expect('${data.label} ${data.tooltip}', contains('Copy code'));
      final wrap = find.byTooltip('Wrap lines');
      if (wrap.evaluate().isNotEmpty) {
        expect(tester.getSize(wrap), const Size(48, 48));
      }
      // Even with 2.5x text, a one-line snippet should not become a card
      // dominated by several rows of actions: the card is as tall as the
      // taller of its lines and its one column of controls, plus insets.
      final lines = tester
          .getSize(
            find.descendant(
              of: find.byType(KitCodeBlock),
              matching: find.byType(Text),
            ),
          )
          .height;
      final controls = wrap.evaluate().isEmpty ? 48.0 : 96.0;
      expect(
        tester.getSize(find.byType(KitCodeBlock)).height,
        lessThanOrEqualTo((lines > controls ? lines : controls) + 8 + 1),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('RTL code starts at the beginning of its horizontal viewport', (
    tester,
  ) async {
    await _pump(
      tester,
      MarkdownText(_cappedFence('final start = ${'value' * 100};')),
      rtl: true,
    );
    final horizontal = find.byWidgetPredicate(
      (w) =>
          w is Scrollable &&
          axisDirectionToAxis(w.axisDirection) == Axis.horizontal,
    );
    // This host reads as a compact window, where code wraps by default;
    // turning Wrap off gives the block its sideways scroller.
    await tester.tap(find.byTooltip('Wrap lines'));
    await tester.pump();
    final state = tester.state<ScrollableState>(horizontal);
    expect(state.position.axisDirection, AxisDirection.right);
    expect(state.position.pixels, state.position.minScrollExtent);
    expect(state.position.maxScrollExtent, greaterThan(0));
    await _openReader(tester);
    final readerState = tester.state<ScrollableState>(horizontal);
    expect(readerState.position.axisDirection, AxisDirection.right);
    expect(readerState.position.pixels, readerState.position.minScrollExtent);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('open reader retires controls when source becomes inert', (
    tester,
  ) async {
    final enabled = ValueNotifier(true);
    addTearDown(enabled.dispose);
    await _pump(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: enabled,
        builder: (_, value, _) => MarkdownInteractionScope(
          enabled: value,
          child: MarkdownText(_cappedFence('snapshot')),
        ),
      ),
    );
    await _openReader(tester);
    expect(find.byTooltip('Copy code'), findsOneWidget);
    enabled.value = false;
    await tester.pumpAndSettle();
    expect(find.byTooltip('Copy code'), findsNothing);
    expect(find.byTooltip('Wrap lines'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('reader stays local and retires after source row is removed', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await _pump(
      tester,
      ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (_, value, _) =>
            value ? MarkdownText(_cappedFence('snapshot')) : const SizedBox(),
      ),
    );
    await _openReader(tester);
    expect(find.byTooltip('Copy code'), findsOneWidget);
    visible.value = false;
    await tester.pumpAndSettle();
    expect(find.byTooltip('Copy code'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  final fences = <(String, String, bool)>[
    (
      '````markdown\n```dart\nclass A {}\n```\n````',
      '```dart\nclass A {}\n```',
      true,
    ),
    ('~~~dart\nclass A {}\n~~~~', 'class A {}', true),
    (
      '````dart\nfirst\n```\n~~~\n```` extra\nlast\n````',
      'first\n```\n~~~\n```` extra\nlast',
      true,
    ),
    ('~~~dart\nclass A {}\n```', 'class A {}\n```', false),
    ('   ~~~dart\n   one\n two\n   ~~~', 'one\ntwo', true),
    ('```dart\nclass A {', 'class A {', false),
    ('~~~text | hint\n--- | ---\nvalue\n~~~', '--- | ---\nvalue', true),
  ];
  for (var i = 0; i < fences.length; i++) {
    testWidgets('fence delimiter case $i preserves body and streaming state', (
      tester,
    ) async {
      final (input, expected, closed) = fences[i];
      await _pump(tester, MarkdownText(input));
      final block = tester.widget<KitCodeBlock>(find.byType(KitCodeBlock));
      expect(block.text, expected);
      expect(block.highlight, closed);
      if (!closed) {
        // A streaming fence is plain mono: each line is one unstyled leaf.
        expect(
          _codeLeaves(tester).where((leaf) => leaf != '\n'),
          expected.split('\n'),
        );
      }
    });
  }

  testWidgets('invalid backtick info and four-space opening are not fences', (
    tester,
  ) async {
    await _pump(
      tester,
      const MarkdownText('```bad`info\ntext\n\n    ~~~dart\ncode'),
    );
    expect(find.byType(KitCodeBlock), findsNothing);
  });

  testWidgets(
    'Copy preserves original CRLF, indent and trailing newline after wrap',
    (tester) async {
      final copies = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copies.add((call.arguments as Map)['text'] as String);
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
      // A line wider than the block, so Wrap is offered and changes.
      final line = '  final a = 1; // ${'value ' * 30} ';
      await _pump(tester, MarkdownText('  ~~~dart\r\n$line\r\n  \r\n  ~~~'));
      await tester.tap(find.byTooltip('Wrap lines'));
      await tester.pump();
      await tester.tap(find.byTooltip('Copy code'));
      await tester.pump();
      expect(copies, ['$line\r\n  \r\n']);
    },
  );

  testWidgets(
    'clipboard failure is recoverable and retries the exact snapshot',
    (tester) async {
      var fail = true;
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            if (fail) throw PlatformException(code: 'denied');
            copied.add((call.arguments as Map)['text'] as String);
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
      final source = '${'x' * 1200}\n\n';
      await _pump(tester, KitCodeBlock(text: source));
      await tester.tap(find.byTooltip('Copy code'));
      await tester.pumpAndSettle();
      expect(find.text('Could not copy code. Try again.'), findsOneWidget);
      expect(find.text('Code copied'), findsNothing);
      fail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(copied, [source]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('inert code has selection and actions disabled', (tester) async {
    await _pump(
      tester,
      MarkdownInteractionScope(
        enabled: false,
        child: MarkdownText(_cappedFence('local only ${'value ' * 40}')),
      ),
    );
    expect(find.byTooltip('Copy code'), findsNothing);
    expect(find.text('Open full output'), findsNothing);
    expect(find.byTooltip('Code options'), findsNothing);
    expect(find.byTooltip('Wrap lines'), findsNothing);
    final ignored = find.ancestor(
      of: find.byType(KitCodeBlock),
      matching: find.byType(IgnorePointer),
    );
    expect(
      tester.widgetList<IgnorePointer>(ignored).any((w) => w.ignoring),
      isTrue,
    );
  });

  testWidgets(
    'table aligns center/right and grows inline-code headers and long cells at 2x',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(
        tester,
        const MarkdownText(
          '| Long `inline_header_with_a_long_name` | Center | Right |\n| --- | :---: | ---: |\n| A readable cell with several lines of detail | middle | 123 |',
        ),
        scale: 2,
      );
      expect(_table, findsOneWidget);
      final center = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.textSpan?.toPlainText() == 'middle',
        ),
      );
      expect(center.textAlign, TextAlign.center);
      final right = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.textSpan?.toPlainText() == '123',
        ),
      );
      // Directional end (LAY-8): the right edge in this LTR table.
      expect(right.textAlign, TextAlign.end);
      // Rows grow with their cells rather than clipping them.
      expect(tester.getSize(_table).height, greaterThan(180));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('validated path chips grow once at large text scale', (
    tester,
  ) async {
    Widget content() => MarkdownFileLinks(
      validate: (_) async => true,
      open: (_) {},
      child: const MarkdownText('Read `count` and `lib/a.dart`.'),
    );
    double paintedWidth(String value) {
      final box = tester.renderObject<RenderBox>(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText() == value,
        ),
      );
      return (box.localToGlobal(Offset(box.size.width, 0)) -
              box.localToGlobal(Offset.zero))
          .dx;
    }

    await _pump(tester, content());
    await tester.pumpAndSettle();
    // Plain inline code is part of the paragraph and scales with it; the
    // validated path stays a chip and must scale exactly once.
    // The confirmed path is a link drawn by its own RichText.
    final pathWidth = paintedWidth('lib/a.dart');
    await _pump(tester, content(), scale: 2);
    await tester.pumpAndSettle();
    expect(paintedWidth('lib/a.dart'), closeTo(pathWidth * 2, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'table escaped pipes retain literal cells and mismatched delimiters are prose',
    (tester) async {
      await _pump(
        tester,
        const MarkdownText(
          r'| A\|B | C |'
          '\n| --- | --- |\n'
          r'| x\|y | z |',
        ),
      );
      expect(_table, findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.textSpan?.toPlainText() == 'x|y',
        ),
        findsOneWidget,
      );
      await _pump(tester, const MarkdownText('| A | B |\n| --- |\n| C | D |'));
      expect(_table, findsNothing);
    },
  );

  testWidgets(
    'unchanged parse cache and leading code widget survive later streaming',
    (tester) async {
      final source = ValueNotifier(
        '```dart\nclass A {}\n```\n\n~~~dart\nclass B',
      );
      addTearDown(source.dispose);
      final parent = ValueNotifier(0);
      addTearDown(parent.dispose);
      await _pump(
        tester,
        ValueListenableBuilder<int>(
          valueListenable: parent,
          builder: (_, value, _) => ValueListenableBuilder<String>(
            valueListenable: source,
            builder: (_, text, _) => MarkdownText(text),
          ),
        ),
      );
      final before = MarkdownText.debugParseCount;
      final first = tester
          .widgetList<KitCodeBlock>(find.byType(KitCodeBlock))
          .first;
      parent.value++;
      await tester.pump();
      expect(MarkdownText.debugParseCount, before);
      source.value += ' {\n  int n = 0;';
      await tester.pump();
      expect(
        identical(
          tester.widgetList<KitCodeBlock>(find.byType(KitCodeBlock)).first,
          first,
        ),
        isTrue,
      );
      expect(
        tester
            .widgetList<KitCodeBlock>(find.byType(KitCodeBlock))
            .last
            .highlight,
        isFalse,
      );
    },
  );

  testWidgets(
    'reader retains snapshot and selection across parent streaming then returns',
    (tester) async {
      final source = ValueNotifier(
        _cappedFence(
          'final first = 1;',
          fence: '~~~',
          info: 'dart',
          close: false,
        ),
      );
      addTearDown(source.dispose);
      await _pump(
        tester,
        ValueListenableBuilder<String>(
          valueListenable: source,
          builder: (_, text, _) => MarkdownText(text),
        ),
      );
      final snapshot = source.value.substring('~~~dart\n'.length);
      await _openReader(tester);
      expect(find.text('Code reader'), findsOneWidget);
      // The reader's selection lives in its selection region: the same
      // region (and the same text) across parent streaming keeps it.
      final region = tester.state(find.byType(SelectableRegion));
      source.value += '\nfinal later = 2;\n~~~';
      await tester.pump();
      expect(
        tester.widget<KitCodeBlock>(find.byType(KitCodeBlock)).text,
        snapshot,
      );
      expect(tester.state(find.byType(SelectableRegion)), same(region));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester.widget<KitCodeBlock>(find.byType(KitCodeBlock)).text,
        contains('final later'),
      );
    },
  );

  testWidgets(
    'wrap and reader preserve parent scroll offset and 48dp controls',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              controller: scroll,
              child: Column(
                children: [
                  const SizedBox(height: 150),
                  MarkdownText(_cappedFence('long ${'value ' * 80}')),
                  const SizedBox(height: 900),
                ],
              ),
            ),
          ),
        ),
      );
      scroll.jumpTo(100);
      await tester.pump();
      final before = scroll.offset;
      for (final label in ['Wrap lines', 'Copy code']) {
        expect(
          tester.getSize(find.byTooltip(label)).height,
          greaterThanOrEqualTo(48),
        );
      }
      await tester.tap(find.byTooltip('Wrap lines'));
      await tester.pump();
      expect(scroll.offset, before);
      await _openReader(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(scroll.offset, before);
    },
  );

  testWidgets('links and code inside headings and bold are drawn, not shown', (
    tester,
  ) async {
    await _pump(
      tester,
      const MarkdownText(
        '# [Download APK](http://localhost:4052/a.apk)\n\n'
        '**[Open app](http://localhost:4051)** and `run`',
      ),
    );
    Finder has(String text) => find.textContaining(text, findRichText: true);
    expect(has('Download APK'), findsWidgets);
    expect(has('Open app'), findsWidgets);
    expect(has(']('), findsNothing);
    expect(has('**'), findsNothing);
  });
}
