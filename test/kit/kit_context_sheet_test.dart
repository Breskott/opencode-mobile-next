// KitContextSheet (docs/ux-system/kit-api/KitContextSheet.md): the rows, the
// tokens in words, the paragraph and the per-reply chart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

const _chartKey = Key('sheet-chart');

KitContextSheet _sheet({
  List<KitContextBar> bars = const [
    KitContextBar(fraction: 0.2),
    KitContextBar(fraction: 0.55),
    KitContextBar(fraction: 0.42, compactedBefore: true),
    KitContextBar(fraction: 0.84),
  ],
  bool compacting = false,
}) => KitContextSheet(
  tokens: 84000,
  limit: 200000,
  modelName: 'Claude Sonnet',
  bars: bars,
  compacting: compacting,
  chartKey: _chartKey,
);

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  ),
);

void main() {
  kitMotionStillTests(
    'KitContextSheet',
    builds: {
      'default': () => _sheet(),
      'compacting': () => _sheet(compacting: true),
    },
  );

  testWidgets(
    'says the tokens, the model, the window and when it was measured',
    (tester) async {
      await tester.pumpWidget(_app(_sheet()));
      await tester.pumpAndSettle();
      expect(find.text('84,000 of 200,000 tokens'), findsOneWidget);
      expect(find.text('42 %'), findsOneWidget);
      expect(find.text('Model'), findsOneWidget);
      expect(find.text('Claude Sonnet'), findsOneWidget);
      expect(find.text('Context window'), findsOneWidget);
      expect(find.text('200,000'), findsOneWidget);
      expect(find.text('Measured'), findsOneWidget);
      expect(find.text('After the last reply'), findsOneWidget);
      expect(
        find.textContaining('how much of the conversation'),
        findsOneWidget,
      );
    },
  );

  testWidgets('draws one chart bar per reply and notes the compaction', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_sheet()));
    final painter =
        tester.widget<CustomPaint>(find.byKey(_chartKey)).painter!
            as KitContextChartPainter;
    expect(painter.bars, hasLength(4));
    expect(find.text('Compacted here'), findsOneWidget);
  });

  testWidgets('a single reply has no history: no chart, no note', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_sheet(bars: const [KitContextBar(fraction: 0.4)])),
    );
    expect(find.byKey(_chartKey), findsNothing);
    expect(find.text('Each reply'), findsNothing);
  });

  testWidgets('while compacting the big ring says so', (tester) async {
    await tester.pumpWidget(_app(_sheet(compacting: true)));
    expect(find.text('Compacting'), findsOneWidget);
  });
}
