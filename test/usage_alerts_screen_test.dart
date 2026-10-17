// Usage › Alerts: one switch, a default level, the reset message, the plans
// that differ, and the app's shared quiet hours and Wi-Fi only.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/notification_preferences.dart';
import 'package:opencode_mobile/state/usage_subscriptions_controller.dart';
import 'package:opencode_mobile/ui/screens/usage/usage_alerts_screen.dart';

import 'support/usage_ui_harness.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Future<UsageHarness> _open(
  WidgetTester tester, {
  bool withPlan = false,
  bool alertsOn = true,
}) async {
  usageAndroid();
  usagePhoneView(tester, height: 1600);
  final h = await usageHarness(
    result: UsageSourceResult(
      readings: [if (withPlan) usageReading('codex', 'inapp', account: 'a')],
    ),
  );
  await h.usage.refresh();
  if (alertsOn) await h.usage.setAlertsOn(true);
  await tester.pumpWidget(
    usageApp(
      UsageAlertsScreen(
        controller: h.connection,
        usage: h.usage,
        clock: () => usageNow,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

SharedNotifyRules _rules(UsageHarness h) => h.connection.sharedNotifyRules;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  usageTestWidgets('the one switch is the shared quota-alerts value', (
    tester,
  ) async {
    final h = await _open(tester, alertsOn: false);
    expect(h.usage.alertsOn, isFalse);
    await tester.tap(usageKey('usage-alerts-switch'));
    await tester.pumpAndSettle();
    expect(_rules(h).quotaAlerts, isTrue);
    expect(h.usage.alertsOn, isTrue);
    await tester.tap(usageKey('usage-alerts-switch'));
    await tester.pumpAndSettle();
    expect(_rules(h).quotaAlerts, isFalse);
  });

  usageTestWidgets('the first row is the switch with one short line; with it '
      'off nothing else shows', (tester) async {
    final h = await _open(tester, withPlan: true, alertsOn: false);
    expect(find.text(_en.usageAlertsSwitch), findsOneWidget);
    expect(find.text(_en.usageAlertsForEvery), findsOneWidget);
    for (final key in [
      'usage-alerts-default',
      'usage-alerts-reset',
      'usage-alerts-quiet',
      'usage-alerts-wifi',
      'usage-alerts-different',
    ]) {
      expect(usageKey(key), findsNothing, reason: key);
    }
    expect(find.text(_en.usageAlertsTellMe), findsNothing);
    expect(find.text(_en.usageAlertsQuietGroup), findsNothing);
    await tester.tap(usageKey('usage-alerts-switch'));
    await tester.pumpAndSettle();
    expect(h.usage.alertsOn, isTrue);
    expect(find.text(_en.usageAlertsTellMe), findsOneWidget);
    expect(find.text(_en.usageAlertsQuietGroup), findsOneWidget);
    expect(usageKey('usage-alerts-default'), findsOneWidget);
    expect(usageKey('usage-alerts-wifi'), findsOneWidget);
  });

  usageTestWidgets('a threshold stored as 80% used reads "20% left", also in '
      'its picker; the stored value is unchanged', (tester) async {
    final h = await _open(tester);
    expect(h.usage.defaultThreshold, 80);
    expect(
      find.textContaining(_en.usageLeft(20), findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('% used'), findsNothing);
    await tester.tap(usageKey('usage-alerts-default'));
    await tester.pumpAndSettle();
    // The picker offers "% left" only: 90% used is "10% left".
    expect(find.textContaining('% used'), findsNothing);
    await tester.tap(find.text(_en.usageLeft(10)).last);
    await tester.pumpAndSettle();
    expect(h.usage.defaultThreshold, 90);
    expect(
      find.textContaining(_en.usageLeft(10), findRichText: true),
      findsWidgets,
    );
  });

  usageTestWidgets('Tell me when a limit resets is the default for every '
      'plan', (tester) async {
    final h = await _open(tester);
    expect(h.usage.notifyOnResetDefault, isFalse);
    await tester.tap(usageKey('usage-alerts-reset'));
    await tester.pumpAndSettle();
    expect(h.usage.notifyOnResetDefault, isTrue);
  });

  usageTestWidgets('"Different from default" lists only plans with their '
      'own level', (tester) async {
    final h = await _open(tester, withPlan: true);
    expect(usageKey('usage-alerts-different'), findsNothing);
    await h.usage.setThresholdFor('codex|a', 90);
    await tester.pumpAndSettle();
    expect(usageKey('usage-alerts-different'), findsOneWidget);
    expect(usageKey('usage-alerts-override-codex|a'), findsOneWidget);
    expect(find.text(_en.usageAlertsDifferent), findsOneWidget);
    await tester.tap(usageKey('usage-alerts-override-codex|a'));
    await tester.pumpAndSettle();
    expect(usageKey('usage-subscription'), findsOneWidget);
  });

  usageTestWidgets('quiet hours and Wi-Fi only are the shared notification '
      'values, written from here', (tester) async {
    final h = await _open(tester);
    expect(_rules(h).quietEnabled, isFalse);
    expect(usageKey('usage-alerts-quiet-start'), findsNothing);

    await tester.tap(usageKey('usage-alerts-quiet'));
    await tester.pumpAndSettle();
    expect(_rules(h).quietEnabled, isTrue);
    expect(_rules(h).quietStart, SharedNotifyRules.defaultQuietStart);
    expect(usageKey('usage-alerts-quiet-start'), findsOneWidget);
    expect(usageKey('usage-alerts-quiet-end'), findsOneWidget);

    // U13: the supporting line is short and wraps in full, never cut.
    expect(find.text(_en.usageWifiOnlyShort), findsOneWidget);
    expect(find.text(_en.usageQuietSameAsOthers), findsOneWidget);
    expect(find.textContaining('VPN'), findsNothing);
    expect(_rules(h).wifiOnly, isFalse);
    await tester.tap(usageKey('usage-alerts-wifi'));
    await tester.pumpAndSettle();
    expect(_rules(h).wifiOnly, isTrue);

    await tester.tap(usageKey('usage-alerts-quiet'));
    await tester.pumpAndSettle();
    expect(_rules(h).quietEnabled, isFalse);
  });

  usageTestWidgets('the page never promises a sound setting', (tester) async {
    await _open(tester);
    expect(find.textContaining('Sound'), findsNothing);
    expect(find.textContaining('sound'), findsNothing);
  });
}
