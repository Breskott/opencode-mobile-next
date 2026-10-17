// Slice R17 (docs/qa/slice-R17-2026-09-27/README.md): the move question
// names its destination in the title and every answer, the budget dialog
// says per unit what to enter and what Save saves, and the quota monitor's
// paused / Wi-Fi / source-changed states no longer borrow the Needs-you
// attention tone. Asserts what the person sees and what is sent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/session_destination_sheet.dart';
import 'package:opencode_mobile/ui/screens/usage_screen.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import 'screen_chat_1_support.dart';
import 'screen_usage_1_support.dart';

final _en = lookupAppLocalizations(const Locale('en'));

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<ChatOneConnection> _openMove(
  WidgetTester tester, {
  ChatOneRepository? repo,
  SessionDestinationMode mode = SessionDestinationMode.move,
}) async {
  final conn = await chatOneConnection(repo);
  await tester.pumpWidget(
    chatOneApp(
      opener(
        (context) => showSessionDestinationSheet(
          context,
          controller: conn,
          sessionID: 'ses_a',
          mode: mode,
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return conn;
}

void main() {
  setUpAll(loadCaptureFonts);

  group('move question', () {
    testWidgets('names the destination in the title and every answer, the '
        'alternative sits between the confirm and Cancel, and both change '
        'facts share one neutral mark', (tester) async {
      _phone(tester);
      final conn = await _openMove(tester);
      await tester.tap(
        find.byKey(const Key('move-destination-/work/checkout-retry')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Move conversation to checkout-retry?'), findsOne);
      final confirm = find.byKey(const Key('session-destination-confirm'));
      final without = find.byKey(
        const Key('session-destination-without-changes'),
      );
      expect(
        find.descendant(
          of: confirm,
          matching: find.text('Move to checkout-retry with changes'),
        ),
        findsOne,
      );
      expect(
        find.descendant(
          of: without,
          matching: find.text('Move to checkout-retry without changes'),
        ),
        findsOne,
      );
      final cancel = find.text('Cancel');
      expect(cancel, findsOne);
      // Phone: full-width answers, top to bottom.
      final confirmY = tester.getCenter(confirm).dy;
      final withoutY = tester.getCenter(without).dy;
      final cancelY = tester.getCenter(cancel).dy;
      expect(confirmY, lessThan(withoutY));
      expect(withoutY, lessThan(cancelY));

      // Where the changes go and where they stay: same neutral dot, no
      // check against an info glyph.
      expect(
        find.byKey(const ValueKey('kit-consequence-dot')),
        findsNWidgets(2),
      );

      await _tap(tester, confirm);
      expect(conn.moves, [('/work/checkout-retry', true)]);
    });

    testWidgets('with no working changes the confirm is "Move to {place}" and '
        'the body does not repeat the title', (tester) async {
      _phone(tester);
      final repo = ChatOneRepository()..changes = const [];
      final conn = await _openMove(tester, repo: repo);
      await tester.tap(
        find.byKey(const Key('move-destination-/work/checkout-retry')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Move conversation to checkout-retry?'), findsOne);
      expect(
        find.text(
          'No working changes in acme, so only the conversation '
          'moves.',
        ),
        findsOne,
      );
      expect(find.textContaining('Continue to'), findsNothing);
      expect(
        find.byKey(const Key('session-destination-without-changes')),
        findsNothing,
      );
      final confirm = find.byKey(const Key('session-destination-confirm'));
      expect(
        find.descendant(
          of: confirm,
          matching: find.text('Move to checkout-retry'),
        ),
        findsOne,
      );
      await _tap(tester, confirm);
      expect(conn.moves, [('/work/checkout-retry', false)]);
    });

    testWidgets('a cloud move names the machine and says a copy goes', (
      tester,
    ) async {
      _phone(tester);
      final conn = await _openMove(tester, mode: SessionDestinationMode.warp);
      await _tap(tester, find.byKey(const Key('warp-destination-ws-review')));

      expect(find.text('Move conversation to Review machine?'), findsOne);
      expect(
        find.text('Move to Review machine with a copy of changes'),
        findsOne,
      );
      expect(find.text('Move to Review machine without changes'), findsOne);
      await _tap(
        tester,
        find.byKey(const Key('session-destination-without-changes')),
      );
      expect(conn.warps, [('ws-review', false)]);
    });
  });

  group('budget dialog', () {
    Future<void> openBudget(WidgetTester tester, String unit) async {
      _phone(tester);
      final h = usageHarness();
      await tester.pumpWidget(
        usageApp(UsageScreen(controller: h.connection, overview: h.overview)),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(ValueKey('usage-budget-$unit')));
    }

    testWidgets('USD: opens without an error, says what to enter after an '
        'edit, and Save names the budget', (tester) async {
      await openBudget(tester, 'usd');
      expect(find.text('Save USD budget'), findsOne);
      expect(find.text('Save'), findsNothing);
      expect(find.text(_en.usageBudgetInvalidUsd), findsNothing);
      expect(find.text(_en.usageBudgetInvalidTokens), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('usage-budget-amount')),
        '0',
      );
      await tester.pumpAndSettle();
      expect(find.text('Enter an amount above 0, like 2.50'), findsOne);
      expect(find.text(_en.usageBudgetInvalidTokens), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('usage-budget-amount')),
        '2.50',
      );
      await tester.pumpAndSettle();
      expect(find.text(_en.usageBudgetInvalidUsd), findsNothing);
      await _tap(tester, find.text('Save USD budget'));
      expect(find.text('USD budget'), findsOne);
    });

    testWidgets('tokens: zero asks for a whole number above 0, and Save names '
        'the token budget', (tester) async {
      await openBudget(tester, 'tokens');
      expect(find.text('Save token budget'), findsOne);
      expect(find.text(_en.usageBudgetInvalidTokens), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('usage-budget-amount')),
        '0',
      );
      await tester.pumpAndSettle();
      expect(find.text('Enter a whole number of tokens above 0'), findsOne);
      expect(find.text(_en.usageBudgetInvalidUsd), findsNothing);
    });
  });
}
