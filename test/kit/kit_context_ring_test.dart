// KitContextRing (docs/ux-system/kit-api/KitContextRing.md): the level
// thresholds and the whole-percent maths, hidden when unknown, the label and
// its semantics, the counting number, the one halo per upward crossing,
// reduced motion, compacting and the list's quiet form.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

const _ringKey = Key('ring-under-test');

Widget _app(Widget child, {bool reduce = false, Locale? locale}) => MaterialApp(
  theme: AppTheme.dark(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, widget) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
    child: widget!,
  ),
  home: Scaffold(body: Center(child: child)),
);

KitContextRing _ring(
  double? used, {
  bool compacting = false,
  VoidCallback? openDetails,
  KitContextRingSize size = KitContextRingSize.bar,
}) => KitContextRing(
  used: used,
  compacting: compacting,
  openDetails: openDetails,
  size: size,
  ringKey: _ringKey,
);

KitContextArcPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(_ringKey)).painter!
        as KitContextArcPainter;

void main() {
  kitMotionStillTests(
    'KitContextRing',
    builds: {
      'calm': () => _ring(0.4),
      'warning': () => _ring(0.8),
      'compacting': () => _ring(0.8, compacting: true),
      'list': () => _ring(0.9, size: KitContextRingSize.row),
      'unknown': () => _ring(null),
    },
    changes: {
      'value rises past 70 %': KitMotionChange(
        build: () => _ring(0.5),
        act: (tester, stage) => stage.rebuild(_ring(0.8)),
        shows: '80 %',
      ),
      'compaction ends': KitMotionChange(
        build: () => _ring(0.9, compacting: true),
        act: (tester, stage) => stage.rebuild(_ring(0.3)),
        shows: '30 %',
      ),
    },
  );

  group('levels and maths', () {
    test('thresholds: under 70 calm, 70 to 94 warning, 95 and over full', () {
      expect(KitContextLevel.of(0), KitContextLevel.normal);
      expect(KitContextLevel.of(0.6999), KitContextLevel.normal);
      expect(KitContextLevel.of(0.7), KitContextLevel.high);
      expect(KitContextLevel.of(0.9499), KitContextLevel.high);
      expect(KitContextLevel.of(0.95), KitContextLevel.full);
      expect(KitContextLevel.of(1.4), KitContextLevel.full);
    });

    test('the percent is whole, floored, and held to 0 to 100', () {
      expect(KitContextLevel.percentOf(0.7), 70);
      expect(KitContextLevel.percentOf(0.945), 94);
      expect(KitContextLevel.percentOf(0.95), 95);
      expect(KitContextLevel.percentOf(2), 100);
      expect(KitContextLevel.percentOf(-1), 0);
    });
  });

  testWidgets('unknown use draws nothing at all', (tester) async {
    await tester.pumpWidget(_app(_ring(null)));
    expect(find.byKey(_ringKey), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(tester.getSize(find.byType(KitContextRing)), Size.zero);
  });

  testWidgets('shows the percent and says it in words, as a button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(_app(_ring(0.72, openDetails: () => taps += 1)));
    expect(find.text('72 %'), findsOneWidget);
    final node = tester.getSemantics(
      find.bySemanticsLabel('Context 72 % used'),
    );
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(
      tester.getSize(find.byType(KitTappable)).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.text('72 %'));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('the ring is 24 dp with a 2.5 dp stroke and a 9 dp radius', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_ring(0.3)));
    expect(tester.getSize(find.byKey(_ringKey)), const Size(24, 24));
    final painter = _painter(tester);
    expect(painter.stroke, 2.5);
    expect(painter.radius, 9);
    expect(painter.arc, closeTo(0.3, 1e-9));
  });

  testWidgets('the number counts in whole percents while the arc moves', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_ring(0.2)));
    await tester.pumpWidget(_app(_ring(0.6)));
    await tester.pump(const Duration(milliseconds: 150));
    final mid = tester.widget<Text>(find.textContaining('%')).data!;
    final whole = int.parse(mid.replaceAll(RegExp(r'[^0-9]'), ''));
    expect(whole, greaterThan(20));
    expect(whole, lessThan(60));
    final arc = _painter(tester).arc;
    expect(arc, greaterThan(0.2));
    expect(arc, lessThan(0.6));
    await tester.pumpAndSettle();
    expect(find.text('60 %'), findsOneWidget);
    expect(_painter(tester).arc, closeTo(0.6, 1e-9));
  });

  group('the halo', () {
    Future<bool> halo(WidgetTester tester, double from, double to) async {
      await tester.pumpWidget(_app(_ring(from)));
      await tester.pumpAndSettle();
      await tester.pumpWidget(_app(_ring(to)));
      await tester.pump(const Duration(milliseconds: 100));
      final out = find.byKey(KitContextRing.haloKey).evaluate().isNotEmpty;
      await tester.pumpAndSettle();
      expect(find.byKey(KitContextRing.haloKey), findsNothing);
      return out;
    }

    testWidgets('fires once on crossing 70 % upward', (tester) async {
      expect(await halo(tester, 0.6, 0.75), isTrue);
    });

    testWidgets('fires once on crossing 95 % upward', (tester) async {
      expect(await halo(tester, 0.9, 0.96), isTrue);
    });

    testWidgets('does not repeat while it stays above, or on the way down', (
      tester,
    ) async {
      expect(await halo(tester, 0.75, 0.85), isFalse);
      expect(await halo(tester, 0.96, 0.99), isFalse);
      expect(await halo(tester, 0.8, 0.5), isFalse);
    });

    testWidgets('is one circle that is gone when it has faded', (tester) async {
      await tester.pumpWidget(_app(_ring(0.6)));
      await tester.pumpWidget(_app(_ring(0.75)));
      await tester.pump(const Duration(milliseconds: 350));
      final halo = tester.widget<CustomPaint>(
        find.byKey(KitContextRing.haloKey),
      );
      final painter = halo.painter! as KitContextHaloPainter;
      expect(painter.radius, 11);
      expect(painter.strokeFrom, 2);
      expect(painter.strokeTo, 9);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(KitContextRing.haloKey), findsNothing);
    });
  });

  testWidgets('reduced motion: the value lands at once, no halo, no count', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_ring(0.5), reduce: true));
    await tester.pumpWidget(_app(_ring(0.96), reduce: true));
    await tester.pump();
    expect(find.text('96 %'), findsOneWidget);
    expect(find.byKey(KitContextRing.haloKey), findsNothing);
    expect(_painter(tester).arc, closeTo(0.96, 1e-9));
  });

  group('compacting', () {
    testWidgets('a short arc and the word, not the number', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(_ring(0.9, compacting: true, openDetails: () {})),
      );
      expect(find.text('Compacting'), findsOneWidget);
      expect(find.text('90 %'), findsNothing);
      expect(_painter(tester).arc, KitContextRing.compactingArc);
      expect(find.bySemanticsLabel('Context, compacting'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('when it ends the arc drains to the new value', (tester) async {
      await tester.pumpWidget(_app(_ring(0.9, compacting: true)));
      await tester.pumpWidget(_app(_ring(0.3)));
      await tester.pump(const Duration(milliseconds: 450));
      final mid = _painter(tester).arc;
      expect(mid, lessThan(0.9));
      expect(mid, greaterThan(0.3));
      await tester.pumpAndSettle();
      expect(find.text('30 %'), findsOneWidget);
      expect(_painter(tester).arc, closeTo(0.3, 1e-9));
    });
  });

  group('the list ring', () {
    testWidgets('18 dp, 2 dp stroke, no number under 70 %', (tester) async {
      await tester.pumpWidget(_app(_ring(0.5, size: KitContextRingSize.row)));
      await tester.pumpAndSettle();
      expect(find.textContaining('%'), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('shows the number from 70 %', (tester) async {
      await tester.pumpWidget(_app(_ring(0.82, size: KitContextRingSize.row)));
      await tester.pumpAndSettle();
      expect(find.text('82 %'), findsOneWidget);
    });
  });

  testWidgets('Arabic: the label is formatted for the locale', (tester) async {
    await tester.pumpWidget(_app(_ring(0.72), locale: const Locale('ar')));
    await tester.pumpAndSettle();
    expect(find.textContaining('%'), findsOneWidget);
  });
}
