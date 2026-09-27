// Behaviour of screen-system-1's rebuilt pages that the owned tests do not
// cover: Keep running (one list by what is left, "You're set", the daily
// limit, a missing settings screen said in place) and the Performance part
// of App diagnostics (a failed step in words, never in the error colour).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/diagnostics/perf_trace.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/keep_running_screen.dart';
import 'package:opencode_mobile/ui/screens/perf_trace_section.dart';

import 'screen_system_1_fixtures.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Widget _app(Widget home) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

/// The step keys in list order.
List<String> _steps(WidgetTester tester) => [
  for (final element
      in find
          .byWidgetPredicate(
            (widget) =>
                widget is KitRow &&
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith(
                  'keep-running-',
                ),
          )
          .evaluate())
    (element.widget.key! as ValueKey<String>).value,
];

void _phone(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(412, 1600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('Keep running', () {
    tearDown(clearKeepAliveMock);

    testWidgets("a Pixel with battery allowed: You're set, nothing left", (
      tester,
    ) async {
      _phone(tester);
      mockKeepAlive(maker: 'Google', battery: true);
      await tester.pumpWidget(_app(const KeepRunningScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('keep-running-done')), findsOneWidget);
      expect(find.text(_en.keepRunningAllSetTitle), findsOneWidget);
      // App info › Battery › Unrestricted is the same switch on stock
      // Android: not asked again.
      expect(_steps(tester), ['keep-running-battery']);
      expect(find.text(_en.keepRunningBatteryDone), findsOneWidget);
      // The limit Android keeps even then is said on the page.
      expect(find.text(_en.keepRunningDailyLimit), findsOneWidget);
    });

    testWidgets('a Xiaomi: what is left first, an allowed step moves last', (
      tester,
    ) async {
      _phone(tester);
      mockKeepAlive(maker: 'Xiaomi', battery: true);
      await tester.pumpWidget(_app(const KeepRunningScreen()));
      await tester.pumpAndSettle();

      // The maker's own screens cannot be checked: never "You're set".
      expect(find.byKey(const ValueKey('keep-running-done')), findsNothing);
      expect(_steps(tester), [
        'keep-running-autostart',
        'keep-running-background',
        'keep-running-lockInRecents',
        'keep-running-battery',
      ]);
      // No state headings: one list.
      expect(find.text('Done'), findsNothing);
    });

    testWidgets('a settings screen the phone lacks is said in place', (
      tester,
    ) async {
      _phone(tester);
      final opened = mockKeepAlive(maker: 'Xiaomi', opens: false);
      await tester.pumpWidget(_app(const KeepRunningScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('keep-running-autostart')));
      await tester.pumpAndSettle();
      expect(opened, ['autostart']);
      expect(
        find.byKey(const ValueKey('keep-running-open-failed')),
        findsOneWidget,
      );
      expect(find.text(_en.keepRunningOpenFailed), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('Performance', () {
    tearDown(PerfTrace.clear);

    testWidgets('a failed step says so in words; Clear names the timings', (
      tester,
    ) async {
      recordSampleTimings();
      await tester.pumpWidget(
        _app(const SingleChildScrollView(child: PerfTraceSection())),
      );
      await tester.pumpAndSettle();

      final failed = find.byKey(
        const ValueKey('perf-trace-stat-sessions.refresh'),
      );
      expect(failed, findsOneWidget);
      expect(
        find.descendant(
          of: failed,
          matching: find.textContaining('1 failed', findRichText: true),
        ),
        findsOneWidget,
      );
      expect(find.text('Clear timings'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('perf-trace-clear')));
      await tester.pump();
      expect(PerfTrace.spans, isEmpty);
      expect(find.text(_en.perfTraceEmpty), findsOneWidget);
    });
  });
}
