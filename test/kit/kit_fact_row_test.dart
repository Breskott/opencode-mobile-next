// KitFactRow (docs/ux-system/kit-api/KitFactRow.md): the provenance word and
// the source and date on every fact (D25), the dated line in each of the
// four provenances, the answers under a waiting guess, a hit that opens, and
// bidi-safe values in a right-to-left layout.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

final _now = DateTime(2026, 10, 11, 12);

Widget _app(Widget child, {Locale? locale}) => MaterialApp(
  theme: AppTheme.dark(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> _pump(WidgetTester tester, Widget child, {Locale? locale}) =>
    withClock(Clock.fixed(_now), () async {
      await tester.pumpWidget(_app(child, locale: locale));
      await tester.pump();
    });

void main() {
  // G8x (MOT-7): a stateless row; press and focus come from KitTappable.
  kitMotionStillTests(
    'KitFactRow',
    builds: {
      'told': () => KitFactRow(
        text: 'Annual fee is [AMOUNT] CUR.',
        provenance: KitProvenance.told,
        observedAt: DateTime(2026, 9, 12),
      ),
      'a hit that opens': () => KitFactRow(
        title: 'Dentist',
        text: 'Dentist appointment Wed 21 Oct 10:00.',
        provenance: KitProvenance.seen,
        observedAt: DateTime(2026, 10, 8),
        open: () {},
      ),
      'a guess waiting': () => KitFactRow(
        text: 'Probably pays the electricity bill by card.',
        provenance: KitProvenance.guessed,
        observedAt: DateTime(2026, 10, 9),
        waitingForOk: true,
        answers: [
          KitAction(label: 'Yes, keep it', onPressed: () {}),
          KitAction(label: 'Not right', onPressed: () {}),
        ],
      ),
    },
  );

  group('the provenance line carries the word, the source and the date', () {
    testWidgets('told', (tester) async {
      await _pump(
        tester,
        KitFactRow(
          text: 'Annual fee is [AMOUNT] CUR.',
          provenance: KitProvenance.told,
          observedAt: DateTime(2026, 9, 12),
        ),
      );
      expect(find.text('Annual fee is [AMOUNT] CUR.'), findsOneWidget);
      expect(find.text('You told it · Sep 12'), findsOneWidget);
    });

    testWidgets('read from a source names the source', (tester) async {
      await _pump(
        tester,
        KitFactRow(
          text: 'Statement is due on the 15th.',
          provenance: KitProvenance.seen,
          source: 'a shared message',
          observedAt: DateTime(2026, 10, 3),
        ),
      );
      expect(find.text('From a shared message · Oct 3'), findsOneWidget);
    });

    testWidgets('a source with no name still says it is a source', (
      tester,
    ) async {
      await _pump(
        tester,
        KitFactRow(
          text: 'x',
          provenance: KitProvenance.seen,
          observedAt: DateTime(2026, 10, 3),
        ),
      );
      expect(find.text('From a source · Oct 3'), findsOneWidget);
    });

    testWidgets('guessed, with its source and while it waits', (tester) async {
      await _pump(
        tester,
        KitFactRow(
          text: 'Used for groceries.',
          provenance: KitProvenance.guessed,
          source: 'a chat you saved',
          observedAt: DateTime(2026, 10, 9),
          waitingForOk: true,
        ),
      );
      expect(
        find.text(
          'It guessed · Oct 9 · from a chat you saved · waiting for your OK',
        ),
        findsOneWidget,
      );
    });

    testWidgets('worked out', (tester) async {
      await _pump(
        tester,
        KitFactRow(
          text: 'x',
          provenance: KitProvenance.calculated,
          observedAt: DateTime(2026, 10, 9),
        ),
      );
      expect(find.text('Worked out · Oct 9'), findsOneWidget);
    });

    testWidgets('a date from an earlier year carries the year', (tester) async {
      await _pump(
        tester,
        KitFactRow(
          text: 'x',
          provenance: KitProvenance.told,
          observedAt: DateTime(2025, 3, 14),
        ),
      );
      expect(find.text('You told it · Mar 14, 2025'), findsOneWidget);
    });
  });

  testWidgets('the screen reader reads title, text, word and line', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      KitFactRow(
        title: 'Dentist',
        text: 'Wed 21 Oct 10:00.',
        provenance: KitProvenance.told,
        observedAt: DateTime(2026, 10, 8),
        open: () {},
      ),
    );
    expect(
      tester.getSemantics(find.byType(KitTappable)).label,
      'Dentist. Wed 21 Oct 10:00.. You told it. You told it · Oct 8',
    );
    handle.dispose();
  });

  testWidgets('a hit with open is one target and opens', (tester) async {
    var opened = 0;
    await _pump(
      tester,
      KitFactRow(
        title: 'Dentist',
        text: 'Appointment',
        provenance: KitProvenance.told,
        observedAt: DateTime(2026, 10, 8),
        open: () => opened++,
      ),
    );
    await tester.tap(find.text('Appointment'));
    expect(opened, 1);
  });

  testWidgets('a row you read has no target', (tester) async {
    await _pump(
      tester,
      KitFactRow(
        text: 'Appointment',
        provenance: KitProvenance.told,
        observedAt: DateTime(2026, 10, 8),
      ),
    );
    expect(find.byType(KitTappable), findsNothing);
  });

  testWidgets('a waiting guess shows its answers, at most two', (tester) async {
    var kept = 0;
    await _pump(
      tester,
      KitFactRow(
        text: 'Used for groceries.',
        provenance: KitProvenance.guessed,
        observedAt: DateTime(2026, 10, 9),
        waitingForOk: true,
        answers: [
          KitAction(label: 'Yes, keep it', onPressed: () => kept++),
          KitAction(label: 'Not right', onPressed: () {}),
          KitAction(label: 'Third', onPressed: () {}),
        ],
      ),
    );
    expect(find.text('Not right'), findsOneWidget);
    expect(find.text('Third'), findsNothing);
    await tester.tap(find.text('Yes, keep it'));
    expect(kept, 1);
  });

  group('bidi-safe values', () {
    test('only a right-to-left layout gets the marks', () {
      const text = 'الرسوم [AMOUNT] CUR لبطاقة [Bank A] Visa ••42 عند 10:00.';
      expect(KitFactRow.isolateValues(text, rtl: false), text);
      final isolated = KitFactRow.isolateValues(text, rtl: true);
      expect(isolated, contains('\u2066[AMOUNT] CUR\u2069'));
      expect(isolated, contains('\u2066[Bank A] Visa ••42\u2069'));
      expect(isolated, contains('\u206610:00\u2069.'));
    });

    test('an address is one left-to-right run', () {
      final isolated = KitFactRow.isolateValues(
        'اكتب إلى billing@provider-a.example اليوم',
        rtl: true,
      );
      expect(isolated, contains('\u2066billing@provider-a.example\u2069'));
    });

    testWidgets('Arabic draws the isolated text and the Arabic words', (
      tester,
    ) async {
      await _pump(
        tester,
        KitFactRow(
          text: 'الرسوم هي [AMOUNT] CUR لبطاقة [Bank A] Visa ••42',
          provenance: KitProvenance.told,
          observedAt: DateTime(2026, 9, 12),
        ),
        locale: const Locale('ar'),
      );
      expect(
        find.text(
          'الرسوم هي \u2066[AMOUNT] CUR\u2069 لبطاقة \u2066[Bank A] Visa ••42\u2069',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('قلت ذلك'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('large text wraps and nothing overflows', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await withClock(Clock.fixed(_now), () async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: KitFactRow(
                title: 'A card with a very long name for the bank',
                text:
                    'Statement is due on the 15th of each month and the '
                    'annual fee is [AMOUNT] CUR unless waived.',
                provenance: KitProvenance.guessed,
                source: 'a message that was shared from another app',
                observedAt: DateTime(2026, 10, 9),
                waitingForOk: true,
                answers: [
                  KitAction(label: 'Yes, keep it', onPressed: () {}),
                  KitAction(label: 'Not right', onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    });
    expect(tester.takeException(), isNull);
  });
}
