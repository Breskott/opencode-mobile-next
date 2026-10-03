// Long code lines never break mid-identifier (slice-polish2; the
// kit_markdown_streaming golden showed "getStringExt / ra"): code scrolls
// sideways by default on a phone too, the Wrap toggle wraps it, and a
// wrapping line breaks at spaces and punctuation. Selection copies the
// source, without the zero-width break chances.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_markdown.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';

const _zwsp = '​';
const _horizontalKey = ValueKey('kit-code-horizontal');
const _wrapKey = ValueKey('kit-code-wrap');

const _kotlin =
    'class ShareReceiver : BroadcastReceiver() {\n'
    '    override fun onReceive(context: Context, intent: Intent) {\n'
    '        val text = intent.getStringExtra(Intent.EXTRA_TEXT)';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(412, 915),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: widget!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The code paragraph's painted text and the offsets where its visual
/// lines start.
({String text, List<int> starts}) _lines(WidgetTester tester, String probe) {
  final paragraph = tester
      .renderObjectList<RenderParagraph>(find.byType(RichText))
      .firstWhere(
        (p) => p.text.toPlainText().replaceAll(_zwsp, '').contains(probe),
      );
  final text = paragraph.text.toPlainText();
  // A visual line starts at the first character whose box sits lower than
  // the previous character's (zero-width and newline characters have no box
  // of their own and are skipped).
  final starts = <int>[0];
  double? lastTop;
  for (var i = 0; i < text.length; i++) {
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: i, extentOffset: i + 1),
    );
    if (boxes.isEmpty || text[i] == '\n' || text[i] == _zwsp) continue;
    final top = boxes.first.top;
    if (lastTop != null && top > lastTop + 1) starts.add(i);
    lastTop = top;
  }
  return (text: text, starts: starts);
}

bool _word(String char) => RegExp(r'[A-Za-z0-9_]').hasMatch(char);

/// A visual line that starts between two identifier characters broke a
/// word in half ("getStringExt" / "ra").
void _expectNoMidWordBreak(String text, List<int> starts) {
  for (final start in starts) {
    if (start == 0 || start >= text.length) continue;
    var before = start - 1;
    while (before > 0 && text[before] == _zwsp) {
      before--;
    }
    final after = text[start];
    if (text[before] == '\n') continue;
    expect(
      _word(text[before]) && _word(after),
      isFalse,
      reason:
          'line broke mid-word at "${text.substring(before, start + 1)}" '
          '(offset $start)',
    );
  }
}

void main() {
  group('kitCodeBreakable', () {
    test('adds break chances after punctuation, never inside a word', () {
      const line = 'val text = intent.getStringExtra(Intent.EXTRA_TEXT)';
      final out = kitCodeBreakable(line);
      expect(out.replaceAll(_zwsp, ''), line);
      expect(out, contains('intent.${_zwsp}getStringExtra($_zwsp'));
      expect(out, contains('Intent.${_zwsp}EXTRA_TEXT'));
      expect(out, isNot(contains('EXTRA_$_zwsp')), reason: '_ is a word');
    });

    test('runs and closers stay whole; plain words are untouched', () {
      // "::" stays whole; the break chance comes after the run.
      expect(
        kitCodeBreakable('a::b == c && d // e'),
        'a::${_zwsp}b == c && d // e',
      );
      expect(kitCodeBreakable('foo()'), 'foo()');
      expect(
        kitCodeBreakable('list[0].first'),
        'list[${_zwsp}0].${_zwsp}first',
      );
      // A file extension stays with its name; a short member mid-chain
      // does not count as one.
      expect(
        kitCodeBreakable('test/offline_queue_test.dart'),
        'test/${_zwsp}offline_queue_test.dart',
      );
      expect(kitCodeBreakable('a.b.c'), 'a.${_zwsp}b.c');
      expect(kitCodeBreakable('plain words only'), 'plain words only');
      expect(kitCodeBreakable(''), '');
    });
  });

  testWidgets('a phone scrolls a long code line sideways by default and '
      'offers Wrap', (tester) async {
    await _pump(tester, const KitCodeBlock(text: _kotlin, language: 'kotlin'));
    expect(find.byKey(_horizontalKey), findsOneWidget);
    expect(find.byKey(_wrapKey), findsOneWidget);
    final lines = _lines(tester, 'getStringExtra');
    expect(lines.text, isNot(contains(_zwsp)));
    // Three source lines, three visual lines: nothing soft-wraps.
    expect(lines.starts, hasLength(3));
  });

  testWidgets('Wrap wraps at spaces and punctuation, never mid-identifier', (
    tester,
  ) async {
    // The test font's glyphs are one em wide: at these widths every token
    // fits on a line, so any mid-word break would be a bad choice, not a
    // forced one (a token wider than the line still breaks where it must).
    for (final width in [360.0, 412.0]) {
      await _pump(
        tester,
        const KitCodeBlock(text: _kotlin, language: 'kotlin', wrap: true),
        size: Size(width, 915),
      );
      expect(find.byKey(_horizontalKey), findsNothing);
      final lines = _lines(tester, 'getStringExtra');
      expect(lines.starts.length, greaterThan(3), reason: 'wraps at $width');
      _expectNoMidWordBreak(lines.text, lines.starts);
    }
  });

  testWidgets('the toggle wraps a block and still breaks at punctuation, at '
      '2.0 text too', (tester) async {
    await _pump(
      tester,
      const KitCodeBlock(text: _kotlin, language: 'kotlin'),
      // Room for "BroadcastReceiver()" whole in the one-em test font.
      size: const Size(800, 915),
      textScale: 2,
    );
    await tester.tap(find.byKey(_wrapKey));
    await tester.pump();
    expect(find.byKey(_horizontalKey), findsNothing);
    final lines = _lines(tester, 'getStringExtra');
    _expectNoMidWordBreak(lines.text, lines.starts);
  });

  testWidgets('a wrapped command keeps its own breaks (spaces and /), no '
      'added break chances', (tester) async {
    await _pump(
      tester,
      const KitCodeBlock(
        text: 'flutter test --concurrency=1 test/offline_queue_test.dart',
        kind: KitCodeKind.command,
        wrap: true,
      ),
      size: const Size(360, 915),
    );
    final lines = _lines(tester, 'offline_queue_test');
    expect(lines.text, isNot(contains(_zwsp)));
  });

  testWidgets('selecting wrapped code copies the source, without the break '
      'chances', (tester) async {
    final copied = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await _pump(
      tester,
      const KitCodeBlock(text: _kotlin, language: 'kotlin', wrap: true),
    );
    expect(_lines(tester, 'getStringExtra').text, contains(_zwsp));
    final region = tester.state<SelectableRegionState>(
      find.byType(SelectableRegion),
    );
    region.selectAll(SelectionChangedCause.keyboard);
    await tester.pump();
    // Ctrl+C's intent, from inside the region (its own action copies).
    Actions.invoke(
      tester.element(
        find
            .descendant(
              of: find.byType(SelectableRegion),
              matching: find.byType(RichText),
            )
            .first,
      ),
      CopySelectionTextIntent.copy,
    );
    await tester.pump();
    expect(copied, hasLength(1));
    expect(copied.single, _kotlin);
  });

  testWidgets('a streaming reply\'s fence scrolls sideways on a phone '
      'instead of breaking "getStringExtra"', (tester) async {
    await _pump(
      tester,
      const KitMarkdown(
        'Here is the fix, still arriving:\n\n```kotlin\n$_kotlin',
      ),
    );
    expect(find.byKey(_horizontalKey), findsOneWidget);
    final lines = _lines(tester, 'getStringExtra');
    expect(lines.starts, hasLength(3));
    _expectNoMidWordBreak(lines.text, lines.starts);
  });
}
