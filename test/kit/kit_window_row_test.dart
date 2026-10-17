// KitWindowRow (docs/ux-system/kit-api/KitWindowRow.md): one limit window,
// its name and amount on one line and a bar of what is left under them; it
// takes no taps and no focus.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

Widget _row({
  double left = .18,
  KitWindowTone tone = KitWindowTone.normal,
  String? note,
  bool inline = false,
}) => KitWindowRow(
  title: '5 hours',
  left: left,
  valueLabel: '18% left · 14:10',
  tone: tone,
  note: note,
  inline: inline,
);

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
  Locale locale = const Locale('en'),
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.dark(),
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  ),
);

void main() {
  // G8x (MOT-7): a stateless drawing with no animation of its own.
  kitMotionStillTests(
    'KitWindowRow',
    builds: {
      for (final tone in KitWindowTone.values)
        tone.name: () => _row(tone: tone),
    },
  );

  testWidgets('screen readers hear one label: title, amount and note', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, _row(note: 'Resets at Wed 1:59 AM'));
    expect(
      find.bySemanticsLabel('5 hours, 18% left · 14:10, Resets at Wed 1:59 AM'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('a short spoken value replaces the written one', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      const KitWindowRow(
        title: 'Week',
        left: .5,
        valueLabel: '50%',
        valueSemantics: '50% left, resets Thu',
      ),
    );
    expect(find.bySemanticsLabel('Week, 50% left, resets Thu'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the bar fills with the share left, clamped to 0..1', (
    tester,
  ) async {
    for (final (left, factor) in [(.25, .25), (-1.0, 0.0), (7.0, 1.0)]) {
      await _pump(tester, _row(left: left));
      final fill = tester.widget<FractionallySizedBox>(
        find.byType(FractionallySizedBox),
      );
      expect(fill.widthFactor, factor, reason: 'left $left');
    }
  });

  testWidgets('inline or not, it lays out at every text size', (tester) async {
    for (final inline in [false, true]) {
      for (final scale in [.85, 1.0, 1.3, 1.5, 2.0]) {
        await _pump(tester, _row(inline: inline), textScale: scale);
        expect(tester.takeException(), isNull, reason: '$inline at $scale');
        expect(find.byType(FractionallySizedBox), findsOneWidget);
      }
    }
  });

  testWidgets('it fits at text 2.0 in English and Arabic', (tester) async {
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      await _pump(
        tester,
        _row(note: 'Resets at Wed 1:59 AM, in 14 h'),
        textScale: 2,
        locale: locale,
      );
      expect(tester.takeException(), isNull, reason: '$locale');
    }
  });

  testWidgets('it takes no taps and no focus', (tester) async {
    await _pump(tester, _row(note: 'Resets at Wed 1:59 AM'));
    for (final control in [KitTappable, InkWell, GestureDetector, Focus]) {
      expect(
        find.descendant(
          of: find.byType(KitWindowRow),
          matching: find.byType(control),
        ),
        findsNothing,
        reason: '$control',
      );
    }
  });
}
