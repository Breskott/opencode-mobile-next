import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_code_block.dart';
import 'package:opencode_mobile/ui/widgets/markdown.dart';

Widget _host(String data) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: MarkdownText(data, selectable: false)),
  ),
);

/// Counts rebuilds per widget type while [body] runs.
Future<Map<String, int>> _rebuildsDuring(Future<void> Function() body) async {
  final counts = <String, int>{};
  debugOnRebuildDirtyWidget = (element, _) {
    final name = element.widget.runtimeType.toString();
    counts[name] = (counts[name] ?? 0) + 1;
  };
  try {
    await body();
  } finally {
    debugOnRebuildDirtyWidget = null;
  }
  return counts;
}

void main() {
  const settled =
      '## Plan\n\n'
      'Read the **controller** first.\n\n'
      '```dart\nvoid main() => print(1);\n```\n\n'
      '- one\n- two\n\n';

  testWidgets('a growing reply rebuilds only its streaming tail', (
    tester,
  ) async {
    await tester.pumpWidget(_host('${settled}The tail'));

    final counts = await _rebuildsDuring(() async {
      for (final more in [' keeps', ' streaming', ' in.']) {
        await tester.pumpWidget(_host('${settled}The tail$more'));
      }
    });

    // Settled blocks come back as the same widget instances, so Flutter
    // skips them: no re-highlighting of the closed fence, no re-parse of the
    // heading, list or earlier paragraph on each delta.
    expect(counts['KitCodeBlock'], isNull);
    expect(counts['_Heading'], isNull);
    expect(counts['_List'], isNull);
    // Only the growing paragraph rebuilds, once per delta.
    expect(counts['_RichLines'], 3);
    expect(find.textContaining('The tail in.', findRichText: true), findsOne);
  });

  testWidgets('an edited earlier block still re-renders', (tester) async {
    await tester.pumpWidget(_host('${settled}The tail'));
    await tester.pumpWidget(
      _host('${settled.replaceFirst('first', 'second')}The tail'),
    );

    expect(
      find.textContaining('controller second', findRichText: true),
      findsOne,
    );
    expect(find.textContaining('The tail', findRichText: true), findsOne);
  });

  testWidgets('a fence that closes switches to the highlighted block', (
    tester,
  ) async {
    await tester.pumpWidget(_host('```dart\nfinal a = 1;'));
    await tester.pumpWidget(_host('```dart\nfinal a = 1;\n```'));

    expect(
      tester.widget<KitCodeBlock>(find.byType(KitCodeBlock)).highlight,
      isTrue,
    );
  });
}
