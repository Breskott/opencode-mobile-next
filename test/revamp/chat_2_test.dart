// chat-2: the find mark (KitFindMark, new kit part) and the transcript
// highlight and excerpt rebuilt on it. What the person sees: every hit gets
// the same accent wash, the active one stronger; the letters keep their own
// colour (LOOK-14), and the plain text never changes (selection and copy).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/transcript_search.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/chat/kit_find_mark.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/widgets/transcript_highlight.dart';

Future<BuildContext> _host(WidgetTester tester, Widget child) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            captured = context;
            return child;
          },
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  testWidgets('KitFindMark is only an accent wash; active is stronger', (
    tester,
  ) async {
    final context = await _host(tester, const SizedBox.shrink());
    final accent = KitTokens.of(context).roles.accent;
    final passive = KitFindMark.style(context);
    final active = KitFindMark.style(context, active: true);
    expect(passive.color, isNull);
    expect(passive.fontSize, isNull);
    expect(passive.fontWeight, isNull);
    expect(passive.backgroundColor!.a, closeTo(KitFindMark.passiveAlpha, .01));
    expect(active.backgroundColor!.a, closeTo(KitFindMark.activeAlpha, .01));
    expect(passive.backgroundColor!.r, closeTo(accent.r, .01));
    expect(active.backgroundColor!.a, greaterThan(passive.backgroundColor!.a));
  });

  testWidgets('the highlight marks every hit and keeps the plain text', (
    tester,
  ) async {
    late TextSpan decorated;
    const span = TextSpan(text: 'Retry the checkout, then retry again');
    await _host(
      tester,
      TranscriptHighlight(
        query: 'retry',
        child: Builder(
          builder: (context) {
            decorated = TranscriptHighlight.decorate(context, span);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(
      decorated.toPlainText(includeSemanticsLabels: false),
      span.toPlainText(includeSemanticsLabels: false),
    );
    final marked = <String>[];
    decorated.visitChildren((child) {
      if (child is TextSpan && child.style?.backgroundColor != null) {
        marked.add(child.text!);
      }
      return true;
    });
    expect(marked, ['Retry', 'retry']);
  });

  testWidgets('the excerpt says which match and marks the hit', (tester) async {
    const text = 'The flaky checkout test fails one run in five on CI.';
    final start = text.indexOf('checkout');
    await _host(
      tester,
      const TranscriptMatchExcerpt(
        label: 'Match 2 of 5',
        match: TranscriptMatch(
          messageID: 'm1',
          partIndex: 0,
          start: 10,
          end: 18,
          text: text,
          kind: 'tool',
        ),
      ),
    );
    expect(start, 10);
    expect(find.text('Match 2 of 5 · Tool data'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('transcript-match-m1/0/10')),
      findsOneWidget,
    );
    final rich = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('checkout'),
      ),
    );
    TextSpan? hit;
    rich.text.visitChildren((child) {
      if (child is TextSpan && child.text == 'checkout') hit = child;
      return true;
    });
    expect(hit?.style?.backgroundColor, isNotNull);
    expect(hit?.style?.color, isNull);
  });
}
