// InfoLabel/Glossary: retired by kit-KitTerm (R11, R12), kept as a
// forwarding wrapper over KitTerm/showKitTerm. TEST-19(1): the "Got it"
// step and the old icon-affordance label changed to KitTerm's own
// behaviour (map: no button; K2 §1.20 semantics), listed here as the
// changed expectations this unit's QA record cites.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/widgets/info_label.dart';

void main() {
  testWidgets(
    'tapping a glossary term opens its explanation; tapping outside closes it '
    '(TEST-19(1): no "Got it" button, map info-label-sheet)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: InfoLabel.glossary(Glossary.mcp))),
        ),
      );
      expect(find.text('MCP'), findsOneWidget);
      await tester.tap(find.text('MCP'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Model Context Protocol'), findsOneWidget);
      expect(find.text('Got it'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.textContaining('Model Context Protocol'), findsNothing);
    },
  );

  testWidgets('term is announced as a button with the K2 hint '
      '(TEST-19(1): was "Worktree. Tap for an explanation.")', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InfoLabel('Worktree', explanation: 'A separate checkout.'),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('kit-term'))),
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

  testWidgets('style and iconSize are accepted and ignored', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: InfoLabel(
              'Worktree',
              explanation: 'A separate checkout.',
              style: const TextStyle(fontSize: 40),
              iconSize: 40,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Worktree'), findsOneWidget);
  });

  testWidgets('InfoLabel.show opens the explanation without a term on screen', (
    tester,
  ) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(find.text('MCP'), findsNothing);
    unawaited(
      InfoLabel.show(
        capturedContext,
        term: 'MCP',
        explanation: 'Model Context Protocol.',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Model Context Protocol'), findsOneWidget);
  });

  test('every glossary entry stays short enough to read in one glance', () {
    for (final entry in [
      Glossary.mcp,
      Glossary.worktree,
      Glossary.provider,
      Glossary.context,
      Glossary.agent,
      Glossary.reasoning,
      Glossary.permission,
      Glossary.variant,
    ]) {
      expect(entry.explanation.length, lessThan(260), reason: entry.term);
    }
  });
}
