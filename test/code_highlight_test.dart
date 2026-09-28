import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';
import 'package:opencode_mobile/ui/widgets/markdown.dart';

Future<void> _pumpMarkdown(WidgetTester tester, String data) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: MarkdownText(data)),
    ),
  );
}

// Since 79d941e4 (KitMarkdown; markdown.dart forwards to it) a fence renders
// as a KitCodeBlock whose lines are Text.rich spans inside one selection
// region, not a SelectableText. These helpers read the code body's spans.
List<TextSpan> _codeSpans(WidgetTester tester, String containing) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(KitCodeBlock),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.textSpan)
    .whereType<TextSpan>()
    .where((span) => span.toPlainText().contains(containing))
    .toList();

TextSpan _codeSpan(WidgetTester tester, String containing) =>
    _codeSpans(tester, containing).single;

/// Walks the span tree collecting each leaf text with the style it inherits
/// from its ancestors, which is where the highlighter attaches token styles.
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

void main() {
  testWidgets('fenced Dart code renders emphasized keyword spans', (
    tester,
  ) async {
    await _pumpMarkdown(tester, '```dart\nclass Foo {}\n```');

    final leaves = _leaves(_codeSpan(tester, 'class Foo'));
    final keyword = leaves.firstWhere((leaf) => leaf.text == 'class');
    expect(keyword.style?.fontFamily, 'AppMono');
    expect(keyword.style?.fontWeight, FontWeight.w600);
  });

  testWidgets('an unknown fence language stays plain text', (tester) async {
    await _pumpMarkdown(tester, '```mystery\nclass Foo {}\n```');

    final leaves = _leaves(_codeSpan(tester, 'class Foo'));
    expect(leaves, hasLength(1));
    expect(leaves.single.text, 'class Foo {}');
    expect(leaves.single.style?.fontFamily, 'AppMono');
    expect(leaves.single.style?.fontWeight, isNot(FontWeight.w600));
  });

  testWidgets('diff fences color additions and deletions apart', (
    tester,
  ) async {
    await _pumpMarkdown(tester, '```diff\n+added line\n-removed line\n```');

    final leaves = [
      for (final span in _codeSpans(tester, 'line')) ..._leaves(span),
    ];
    final added = leaves.firstWhere((leaf) => leaf.text.startsWith('+'));
    final removed = leaves.firstWhere((leaf) => leaf.text.startsWith('-'));
    expect(added.style?.color, isNotNull);
    expect(removed.style?.color, isNotNull);
    expect(added.style?.color, isNot(removed.style?.color));
  });
}
