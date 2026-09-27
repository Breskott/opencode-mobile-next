// Behaviour of screen-usage-1's pages (wave 2b): Usage "Spent" (usage), its
// budget dialog (usage-budget-dialog) and clear confirmation
// (usage-budget-clear-dialog), and the Codex account (agent-account).
// Asserts what the person sees and what is stored or sent.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api2/transport.dart';
import 'package:opencode_mobile/domain/agent_account.dart';
import 'package:opencode_mobile/ui/screens/agent_account_screen.dart';
import 'package:opencode_mobile/ui/screens/usage_screen.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import '../support/account_fakes.dart';
import 'screen_usage_1_support.dart';

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester, [Size size = const Size(412, 915)]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(loadCaptureFonts);

  group('Usage (Spent)', () {
    testWidgets('the total comes first, then the range that shapes it', (
      tester,
    ) async {
      _phone(tester);
      final h = usageHarness();
      await tester.pumpWidget(
        usageApp(UsageScreen(controller: h.connection, overview: h.overview)),
      );
      await tester.pumpAndSettle();
      final total = tester.getTopLeft(
        find.byKey(const ValueKey('usage-total-cost')),
      );
      final range = tester.getTopLeft(find.text('Time range'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('usage-total-cost')),
          matching: find.text(r'$3.42'),
        ),
        findsOneWidget,
      );
      expect(total.dy, lessThan(range.dy));
      await _tapText(tester, 'Time range');
      await _tapText(tester, 'All time');
      expect(h.repo.queries.last.from, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a server without usage statistics explains why in place', (
      tester,
    ) async {
      _phone(tester);
      final h = usageHarness();
      h.repo.supported = false;
      await tester.pumpWidget(
        usageApp(UsageScreen(controller: h.connection, overview: h.overview)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('usage-unsupported')), findsOneWidget);
      expect(find.text('OpenCode 2 server'), findsOneWidget);
      expect(
        find.textContaining('Needs a server running OpenCode 2'),
        findsOneWidget,
      );
      // The old bare error line is gone.
      expect(
        find.text('This server does not support aggregate usage.'),
        findsNothing,
      );
    });

    testWidgets('a failed refresh keeps the last total and says so', (
      tester,
    ) async {
      _phone(tester);
      final h = usageHarness();
      await tester.pumpWidget(
        usageApp(UsageScreen(controller: h.connection, overview: h.overview)),
      );
      await tester.pumpAndSettle();
      h.repo.failure = const Api2NetworkError('Offline');
      await tester.tap(find.byTooltip('Refresh usage'));
      await tester.pumpAndSettle();
      expect(
        find.text('Showing the previous result for these filters.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('usage-total-cost')),
          matching: find.text(r'$3.42'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('an empty range says so and hides the zero breakdowns', (
      tester,
    ) async {
      _phone(tester);
      final h = usageHarness();
      h.repo.result = usageStats(empty: true);
      await tester.pumpWidget(
        usageApp(UsageScreen(controller: h.connection, overview: h.overview)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No activity in this range. Try a wider range or All projects.',
        ),
        findsOneWidget,
      );
      expect(find.text('Tool reliability'), findsNothing);
    });

    testWidgets(
      'a USD budget is set, shown against spend, reached, and removed',
      (tester) async {
        _phone(tester);
        final h = usageHarness();
        await tester.pumpWidget(
          usageApp(UsageScreen(controller: h.connection, overview: h.overview)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Not set'), findsNWidgets(2));
        await _tapKey(tester, const ValueKey('usage-budget-usd'));
        // The dialog says the unit and the effect, and offers no Remove
        // while there is nothing to remove.
        expect(find.textContaining('In US dollars'), findsOneWidget);
        expect(find.text('Remove budget'), findsNothing);
        await tester.enterText(
          find.byKey(const ValueKey('usage-budget-amount')),
          '2.5',
        );
        await tester.pump();
        await _tapText(tester, 'Save');
        expect(find.text('USD budget'), findsOneWidget);
        expect(find.textContaining('3.42 of 2.5 USD'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('usage-budget-reached')),
          findsOneWidget,
        );
        expect(
          find.text('Personal budget reached in this reading.'),
          findsOneWidget,
        );
        await _tapKey(tester, const ValueKey('usage-budget-usd'));
        await _tapText(tester, 'Remove budget');
        expect(find.text('Not set'), findsNWidgets(2));
        expect(
          find.byKey(const ValueKey('usage-budget-reached')),
          findsNothing,
        );
      },
    );

    testWidgets('an invalid amount keeps Save disabled with the reason', (
      tester,
    ) async {
      _phone(tester);
      final h = usageHarness();
      await tester.pumpWidget(
        usageApp(UsageScreen(controller: h.connection, overview: h.overview)),
      );
      await tester.pumpAndSettle();
      await _tapKey(tester, const ValueKey('usage-budget-tokens'));
      await tester.enterText(
        find.byKey(const ValueKey('usage-budget-amount')),
        '0',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Enter a positive finite'), findsWidgets);
      await _tapText(tester, 'Save');
      // Still open: nothing was saved.
      expect(find.byKey(const ValueKey('usage-budget-amount')), findsOneWidget);
    });

    testWidgets('clearing budgets asks first, in its own words', (
      tester,
    ) async {
      _phone(tester);
      final h = usageHarness();
      await tester.pumpWidget(
        usageApp(UsageScreen(controller: h.connection, overview: h.overview)),
      );
      await tester.pumpAndSettle();
      // With both budgets "Not set" there is nothing to clear: no row.
      expect(find.byKey(const ValueKey('usage-budget-clear')), findsNothing);
      await _tapKey(tester, const ValueKey('usage-budget-usd'));
      await tester.enterText(
        find.byKey(const ValueKey('usage-budget-amount')),
        '25',
      );
      await tester.pump();
      await _tapText(tester, 'Save');
      expect(find.text('Budgets'), findsOneWidget);
      expect(find.text('Clear both budgets'), findsOneWidget);
      await _tapKey(tester, const ValueKey('usage-budget-clear'));
      expect(find.text('Clear consumption budgets?'), findsOneWidget);
      await _tapText(tester, 'Clear budgets');
      // The page may have scrolled past the rows to reach Clear.
      expect(find.text('Not set', skipOffstage: false), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('usage-budget-clear'), skipOffstage: false),
        findsNothing,
      );
    });

    for (final size in const [
      Size(320, 640),
      Size(412, 915),
      Size(915, 412),
      Size(1280, 800),
    ]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('lays out without overflow at $size, text $scale', (
          tester,
        ) async {
          _phone(tester, size);
          final h = usageHarness();
          await tester.pumpWidget(
            usageApp(
              UsageScreen(controller: h.connection, overview: h.overview),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          await tester.drag(
            find.byKey(const ValueKey('usage-content')),
            const Offset(0, -3000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Codex account', () {
    setUp(mockSecureStorage);

    testWidgets('signed in: who, how, the limits with a relative reset', (
      tester,
    ) async {
      _phone(tester);
      final connection = accountConnection(prepare: signedIn);
      await withClock(Clock.fixed(usageNow), () async {
        await tester.pumpWidget(
          usageApp(AgentAccountScreen(connection: connection)),
        );
        await tester.pumpAndSettle();
      });
      expect(find.text('Signed in on the host'), findsOneWidget);
      expect(find.text('Signed in with'), findsOneWidget);
      expect(find.text('ChatGPT'), findsOneWidget);
      expect(find.text('Codex · 5-hour window'), findsOneWidget);
      expect(find.textContaining('Resets in 6 h'), findsOneWidget);
      expect(find.byKey(const ValueKey('agent-account-sign-in')), findsNothing);
      expect(
        find.byKey(const ValueKey('agent-account-limit-reached')),
        findsNothing,
      );
    });

    testWidgets('a window at its limit says so and when it resets', (
      tester,
    ) async {
      _phone(tester);
      final connection = accountConnection(
        prepare: (s) => signedIn(s, primaryPercent: 100),
      );
      await withClock(Clock.fixed(usageNow), () async {
        await tester.pumpWidget(
          usageApp(AgentAccountScreen(connection: connection)),
        );
        await tester.pumpAndSettle();
      });
      expect(
        find.byKey(const ValueKey('agent-account-limit-reached')),
        findsOneWidget,
      );
      expect(
        find.textContaining('You’ve reached a Codex limit. Resets in 6 h'),
        findsOneWidget,
      );
    });

    testWidgets('sign-in shows the code with Copy, then Cancel ends it', (
      tester,
    ) async {
      _phone(tester);
      final connection = accountConnection();
      await tester.pumpWidget(
        usageApp(AgentAccountScreen(connection: connection)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ready to sign in'), findsOneWidget);
      await _tapKey(tester, const ValueKey('agent-account-sign-in'));
      expect(find.text('TEST-1234'), findsOneWidget);
      expect(find.byTooltip('Copy sign-in code'), findsOneWidget);
      expect(find.text('Open official sign-in'), findsOneWidget);
      await _tapKey(tester, const ValueKey('agent-account-cancel'));
      expect(find.text('TEST-1234'), findsNothing);
      expect(find.text('Sign-in cancelled'), findsOneWidget);
    });

    testWidgets('a failed sign-in says so and offers a fresh one', (
      tester,
    ) async {
      _phone(tester);
      late FakeAccountSession session;
      final connection = accountConnection(prepare: (s) => session = s);
      await tester.pumpWidget(
        usageApp(AgentAccountScreen(connection: connection)),
      );
      await tester.pumpAndSettle();
      await _tapKey(tester, const ValueKey('agent-account-sign-in'));
      session.notifications.add(
        const AccountEvent(AccountEventKind.loginCompleted, success: false),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-account-login-failed')),
        findsOneWidget,
      );
      expect(find.textContaining('Sign-in did not complete'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-account-sign-in')),
        findsOneWidget,
      );
    });

    testWidgets('a server that cannot host a Codex account explains it', (
      tester,
    ) async {
      _phone(tester);
      final connection = accountConnection(accountEnabled: false);
      await tester.pumpWidget(
        usageApp(AgentAccountScreen(connection: connection)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-account-unsupported')),
        findsOneWidget,
      );
      expect(find.text('Codex server'), findsOneWidget);
      expect(find.text('Needs a computer running Codex.'), findsOneWidget);
    });

    testWidgets('a changed server says so and leads back to Servers', (
      tester,
    ) async {
      _phone(tester);
      final connection = accountConnection();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        usageApp(const SizedBox.expand(), navigator: navigator),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => AgentAccountScreen(connection: connection),
        ),
      );
      await tester.pumpAndSettle();
      connection.locationRevision++;
      connection.changed();
      await tester.pumpAndSettle();
      expect(find.text('This server changed'), findsOneWidget);
      await _tapText(tester, 'Back to Servers');
      expect(find.byType(AgentAccountScreen), findsNothing);
    });

    testWidgets('not connected yet says so instead of "server changed"', (
      tester,
    ) async {
      _phone(tester);
      final connection = accountConnection(connected: false);
      await tester.pumpWidget(
        usageApp(AgentAccountScreen(connection: connection)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('agent-account-not-connected')),
        findsOneWidget,
      );
      expect(find.text('This server changed'), findsNothing);
    });

    for (final size in const [Size(320, 640), Size(1280, 800)]) {
      testWidgets('signed in lays out at $size, text 2.0', (tester) async {
        _phone(tester, size);
        final connection = accountConnection(prepare: signedIn);
        await tester.pumpWidget(
          usageApp(AgentAccountScreen(connection: connection), scale: 2),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
