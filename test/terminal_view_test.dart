import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/widgets/terminal_view.dart';

Future<ThemeData> _pump(WidgetTester tester, Widget child) async {
  final theme = AppTheme.dark();
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
  return Theme.of(tester.element(find.byType(TerminalView)));
}

/// Every text span drawn, with the style it resolves to.
List<(String, TextStyle?)> _spans(WidgetTester tester) {
  final text = tester.widget<SelectableText>(find.byType(SelectableText));
  final out = <(String, TextStyle?)>[];
  void walk(InlineSpan span, TextStyle? inherited) {
    if (span is! TextSpan) return;
    final style = inherited?.merge(span.style) ?? span.style;
    if (span.text case final text? when text.isNotEmpty) {
      out.add((text, style));
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      walk(child, style);
    }
  }

  walk(text.textSpan!, null);
  return out;
}

Color? _colorOf(WidgetTester tester, String text) =>
    _spans(tester).firstWhere((span) => span.$1.contains(text)).$2?.color;

void main() {
  testWidgets('the program stands out of its path; flags and strings apart', (
    tester,
  ) async {
    final theme = await _pump(
      tester,
      const TerminalView(
        command: '/tmp/opencode/flutter/bin/flutter test --concurrency=1 "a b"',
        output: '',
      ),
    );
    final spans = _spans(tester);
    final program = spans.firstWhere((span) => span.$1 == 'flutter');
    expect(program.$2?.fontWeight, FontWeight.w700);
    expect(program.$2?.color, theme.colorScheme.primary);
    expect(
      _colorOf(tester, '/tmp/opencode/flutter/bin/'),
      AppTheme.mutedOf(theme),
    );
    expect(_colorOf(tester, '--concurrency=1'), theme.colorScheme.secondary);
    expect(_colorOf(tester, '"a b"'), theme.colorScheme.tertiary);
  });

  testWidgets('output keeps its colours, or is tinted by what it says', (
    tester,
  ) async {
    final theme = await _pump(
      tester,
      const TerminalView(
        output:
            '\x1B[31mred from the tool\x1B[0m\n'
            'Error: something broke\n'
            'Found 0 errors\n'
            '00:07 +6 -1: Some tests failed.\n'
            'All tests passed!',
      ),
    );
    expect(_colorOf(tester, 'red from the tool'), theme.colorScheme.error);
    expect(_spans(tester).any((s) => s.$1.contains('\x1B')), isFalse);
    expect(_colorOf(tester, 'Error: something'), theme.colorScheme.error);
    expect(_colorOf(tester, 'Found 0 errors'), isNot(theme.colorScheme.error));
    expect(_colorOf(tester, '+6'), AppTheme.successOf(theme));
    expect(_colorOf(tester, ' -1'), theme.colorScheme.error);
    expect(_colorOf(tester, 'All tests passed!'), AppTheme.successOf(theme));
  });

  testWidgets('long output shows its end, the rest a tap away', (tester) async {
    await _pump(
      tester,
      TerminalView(
        output: [for (var i = 1; i <= 100; i++) 'line $i'].join('\n'),
      ),
    );
    final drawn = _spans(tester).map((span) => span.$1).join();
    expect(drawn, contains('line 100'));
    expect(drawn, isNot(contains('line 60\n')));
    expect(find.text('Show 60 earlier lines'), findsOneWidget);

    await tester.tap(find.byKey(const Key('terminal-show-earlier')));
    await tester.pumpAndSettle();
    expect(_spans(tester).map((span) => span.$1).join(), contains('line 1\n'));
  });
}
