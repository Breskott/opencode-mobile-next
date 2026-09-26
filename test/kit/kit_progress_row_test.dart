// Behaviour tests for KitProgressRow (docs/ux-system/kit-api/KitProgressRow.md):
// the states, the automatic near/at-limit words, the tone assert, the
// merged semantics node, the tap target and reduced motion (STANDARDS.md
// TEST-15). Arabic and RTL galleries are dropped for the revamp (owner
// decision 2026-09-27; STANDARDS.md header), so this file stays English.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_progress_row.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';

const _rowKey = ValueKey('row-under-test');

/// One instance for every pump: two separately built `AppTheme.dark()`
/// calls do not compare equal, so a second pump with a fresh one would
/// animate `MaterialApp`'s own `AnimatedTheme` between them — the harness
/// moving, not the part under test (kit_progress_test.dart's pattern).
final _theme = AppTheme.dark();

Future<void> _pumpRow(
  WidgetTester tester,
  Widget row, {
  bool reduced = false,
}) => tester.pumpWidget(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: child!,
    ),
    home: Scaffold(body: Center(child: row)),
  ),
);

SemanticsData _rowSemantics(WidgetTester tester, [Key key = _rowKey]) =>
    tester.getSemantics(find.byKey(key)).getSemanticsData();

void main() {
  group('KitProgressRow loading', () {
    testWidgets('a null value shows no percentage and says loading', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpRow(
        tester,
        const KitProgressRow(
          key: _rowKey,
          title: 'Claude · 5-hour window',
          value: null,
        ),
      );
      await tester.pump();
      expect(find.textContaining('%'), findsNothing);
      final data = _rowSemantics(tester);
      expect(data.label, 'Claude · 5-hour window, Loading');
      semantics.dispose();
    });
  });

  group('KitProgressRow loaded', () {
    testWidgets('renders the value label and carries it in semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpRow(
        tester,
        const KitProgressRow(
          key: _rowKey,
          title: 'Claude · 5-hour window',
          value: 0.62,
          valueLabel: '62 % · resets in 3 h',
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('62 % · resets in 3 h'), findsOneWidget);
      final data = _rowSemantics(tester);
      expect(data.label, contains('62 percent'));
      expect(data.label, contains('62 % · resets in 3 h'));
      semantics.dispose();
    });
  });

  group('KitProgressRow automatic near/at limit (LOOK-4)', () {
    testWidgets('80 % shows Near limit, 100 % shows Limit reached, 79 % '
        'shows neither', (tester) async {
      await _pumpRow(
        tester,
        const KitProgressRow(
          key: _rowKey,
          title: 'Provider quota',
          value: 0.80,
        ),
        reduced: true,
      );
      await tester.pump();
      expect(find.text('Near limit'), findsOneWidget);
      expect(find.text('Limit reached'), findsNothing);

      await _pumpRow(
        tester,
        const KitProgressRow(key: _rowKey, title: 'Provider quota', value: 1.0),
        reduced: true,
      );
      await tester.pump();
      expect(find.text('Limit reached'), findsOneWidget);
      expect(find.text('Near limit'), findsNothing);

      await _pumpRow(
        tester,
        const KitProgressRow(
          key: _rowKey,
          title: 'Provider quota',
          value: 0.79,
        ),
        reduced: true,
      );
      await tester.pump();
      expect(find.text('Near limit'), findsNothing);
      expect(find.text('Limit reached'), findsNothing);
    });

    testWidgets('an explicit tone never adds the automatic words', (
      tester,
    ) async {
      await _pumpRow(
        tester,
        const KitProgressRow(
          key: _rowKey,
          title: 'Provider quota',
          value: 1.0,
          tone: AppStatusTone.failure,
          valueLabel: 'Failed',
        ),
        reduced: true,
      );
      await tester.pump();
      expect(find.text('Limit reached'), findsNothing);
      expect(find.text('Failed'), findsOneWidget);
    });
  });

  group('KitProgressRow tone (LOOK-4)', () {
    testWidgets('attention throws an AssertionError', (tester) async {
      expect(
        () => KitProgressRow(
          title: 'x',
          value: 0.5,
          tone: AppStatusTone.attention,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('KitProgressRow stale (asOf)', () {
    testWidgets('renders "as of HH:mm" in the locale format', (tester) async {
      final at = DateTime(2026, 9, 27, 10, 42);
      await _pumpRow(
        tester,
        KitProgressRow(
          key: _rowKey,
          title: 'Usage',
          value: 0.4,
          valueLabel: '40 % used',
          asOf: at,
        ),
        reduced: true,
      );
      await tester.pump();
      final expected = DateFormat.Hm('en').format(at);
      expect(find.textContaining('as of $expected'), findsOneWidget);
      final data = _rowSemantics(tester);
      expect(data.label, contains('as of $expected'));
    });
  });

  group('KitProgressRow.segments', () {
    const segments = [
      KitProgressSegment(
        label: 'Conversation',
        value: 0.41,
        valueLabel: '41k tokens',
      ),
      KitProgressSegment(
        label: 'System prompt',
        value: 0.1,
        valueLabel: '10k tokens',
      ),
      KitProgressSegment(label: 'Tools', value: 0.05, valueLabel: '5k tokens'),
      KitProgressSegment(
        label: 'History',
        value: 0.05,
        valueLabel: '5k tokens',
      ),
      KitProgressSegment(label: 'Cache', value: 0.05, valueLabel: '5k tokens'),
    ];

    testWidgets('the legend lists every label with its value label, and a '
        'fifth segment folds into Other', (tester) async {
      await _pumpRow(
        tester,
        const KitProgressRow.segments(
          key: _rowKey,
          title: 'Context used',
          segments: segments,
          valueLabel: '71 % of 200k tokens',
        ),
        reduced: true,
      );
      await tester.pump();
      expect(find.text('Conversation'), findsOneWidget);
      expect(find.text('41k tokens'), findsOneWidget);
      expect(find.text('System prompt'), findsOneWidget);
      expect(find.text('Tools'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      // The fifth segment (Cache) folds into "Other"; its own name is gone.
      expect(find.text('Cache'), findsNothing);
      expect(find.text('Other'), findsOneWidget);
      final data = _rowSemantics(tester);
      expect(data.label, contains('Context used, 71 % of 200k tokens'));
      expect(data.label, contains('Conversation 41k tokens'));
      expect(data.label, contains('Other'));
    });

    testWidgets('the stacked bar actually paints at its full height, not a '
        "Row cross-axis collapse (regression: a childless DecoratedBox in a "
        "Row needs CrossAxisAlignment.stretch)", (tester) async {
      await _pumpRow(
        tester,
        const KitProgressRow.segments(
          key: _rowKey,
          title: 'Context used',
          segments: [KitProgressSegment(label: 'Conversation', value: 1)],
        ),
        reduced: true,
      );
      await tester.pump();
      final heights = tester
          .renderObjectList<RenderBox>(find.byType(DecoratedBox))
          .map((r) => r.size.height)
          .toList();
      expect(heights, contains(KitTokens.progressBarHeight));
    });

    testWidgets('segments summing over 1 assert in debug', (tester) async {
      await _pumpRow(
        tester,
        const KitProgressRow.segments(
          key: _rowKey,
          title: 'Context used',
          segments: [
            KitProgressSegment(label: 'A', value: 0.7),
            KitProgressSegment(label: 'B', value: 0.5),
          ],
        ),
      );
      expect(tester.takeException(), isA<AssertionError>());
    });
  });

  group('KitProgressRow onTap and target', () {
    testWidgets('the whole row is one target and tapping calls it once', (
      tester,
    ) async {
      var taps = 0;
      await _pumpRow(
        tester,
        KitProgressRow(
          key: _rowKey,
          title: 'Provider quota',
          value: 0.4,
          valueLabel: '40 % used',
          onTap: () => taps++,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getSize(find.byKey(_rowKey)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byKey(_rowKey));
      expect(taps, 1);
      final data = _rowSemantics(tester);
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
    });

    testWidgets('without onTap there is no button semantics', (tester) async {
      await _pumpRow(
        tester,
        const KitProgressRow(
          key: _rowKey,
          title: 'Provider quota',
          value: 0.4,
          valueLabel: '40 % used',
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final data = _rowSemantics(tester);
      expect(data.flagsCollection.isButton, isFalse);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
    });
  });

  group('KitProgressRow motion (G8)', () {
    testWidgets('a value change settles after one pump() under reduced '
        'motion', (tester) async {
      await _pumpRow(
        tester,
        const KitProgressRow(key: _rowKey, title: 'Usage', value: 0.2),
        reduced: true,
      );
      await tester.pump();
      await _pumpRow(
        tester,
        const KitProgressRow(key: _rowKey, title: 'Usage', value: 0.8),
        reduced: true,
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('without reduced motion a value change keeps animating '
        'briefly', (tester) async {
      await _pumpRow(
        tester,
        const KitProgressRow(key: _rowKey, title: 'Usage', value: 0.2),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await _pumpRow(
        tester,
        const KitProgressRow(key: _rowKey, title: 'Usage', value: 0.8),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
