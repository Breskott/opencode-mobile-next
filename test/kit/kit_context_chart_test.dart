// KitContextChart (docs/ux-system/kit-api/KitContextChart.md): one bar per
// reply, the newest 40, level colours, the 80 % line, the compaction mark,
// semantics, nothing for fewer than two replies.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

const _key = Key('chart-under-test');

Widget _app(Widget child, {TextDirection? direction}) => MaterialApp(
  theme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Directionality(
    textDirection: direction ?? TextDirection.ltr,
    child: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

KitContextChart _chart(List<double> values, {Set<int> compacted = const {}}) =>
    KitContextChart(
      chartKey: _key,
      bars: [
        for (var i = 0; i < values.length; i++)
          KitContextBar(
            fraction: values[i],
            compactedBefore: compacted.contains(i),
          ),
      ],
    );

KitContextChartPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(_key)).painter!
        as KitContextChartPainter;

void main() {
  kitMotionStillTests(
    'KitContextChart',
    builds: {
      'three replies': () => _chart(const [0.2, 0.5, 0.85]),
    },
  );

  testWidgets('draws one bar per reply', (tester) async {
    await tester.pumpWidget(_app(_chart(const [0.1, 0.3, 0.6, 0.9])));
    expect(_painter(tester).bars, hasLength(4));
  });

  testWidgets('draws nothing for fewer than two replies', (tester) async {
    await tester.pumpWidget(_app(_chart(const [0.4])));
    expect(find.byKey(_key), findsNothing);
    await tester.pumpWidget(_app(_chart(const [])));
    expect(find.byKey(_key), findsNothing);
  });

  testWidgets('keeps the newest 40 replies', (tester) async {
    final values = [for (var i = 0; i < 55; i++) i / 100];
    await tester.pumpWidget(_app(_chart(values)));
    final bars = _painter(tester).bars;
    expect(bars, hasLength(KitContextChart.maxBars));
    expect(bars.last.fraction, 0.54);
    expect(bars.first.fraction, 0.15);
  });

  testWidgets('bars are coloured by level; the newest is never muted', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_chart(const [0.2, 0.75, 0.97, 0.3])));
    final roles = ThemeRoles.resolve(AppTheme.dark());
    final painter = _painter(tester);
    expect(painter.colorOf(0), roles.text3);
    expect(painter.colorOf(1), roles.attention);
    expect(painter.colorOf(2), roles.danger);
    expect(painter.colorOf(3), roles.accent);
  });

  testWidgets('the 80 % line is labelled and a compaction is noted', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_chart(const [0.5, 0.9, 0.2, 0.3], compacted: {2})),
    );
    final painter = _painter(tester);
    expect(painter.threshold, 0.8);
    expect(painter.marker, '80 %');
    expect(painter.bars[2].compactedBefore, isTrue);
  });

  testWidgets('semantics sum the chart up in a sentence', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(_chart(const [0.2, 0.5, 0.72])));
    expect(
      find.bySemanticsLabel(
        'Context after each of 3 replies, the newest at 72 %',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('paints in a right-to-left layout too', (tester) async {
    await tester.pumpWidget(
      _app(_chart(const [0.2, 0.5, 0.9]), direction: TextDirection.rtl),
    );
    expect(_painter(tester).direction, TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });
}
