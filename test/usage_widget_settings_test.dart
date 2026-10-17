// Usage › Home screen widget settings: which plans, 5-hour / weekly / both,
// and the rows that need setup. Every control writes through
// UsageSubscriptionsController.setWidgetSettings.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/background/usage_widget_snapshot.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/state/usage_subscriptions_controller.dart';
import 'package:opencode_mobile/ui/screens/usage_widget_screen.dart';

import 'support/usage_ui_harness.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Future<UsageHarness> _open(WidgetTester tester, {bool plans = true}) async {
  usagePhoneView(tester, height: 1600);
  final h = await usageHarness(
    result: UsageSourceResult(
      readings: [
        if (plans) ...[
          usageReading('codex', 'inapp', account: 'a'),
          usageReading('glm', 'inapp', account: 'b'),
        ],
      ],
    ),
  );
  await h.usage.refresh();
  await tester.pumpWidget(
    usageApp(UsageWidgetScreen(controller: h.connection, usage: h.usage)),
  );
  await tester.pumpAndSettle();
  return h;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  usageTestWidgets('every plan has a switch, all on, and turning one off '
      'hides exactly that plan', (tester) async {
    final h = await _open(tester);
    expect(find.text(_en.usageWidgetSettingsShow), findsOneWidget);
    expect(usageKey('usage-widget-plan-codex|a'), findsOneWidget);
    expect(usageKey('usage-widget-plan-glm|b'), findsOneWidget);
    expect(h.usage.widgetSettings.hiddenKeys, isEmpty);

    await tester.tap(usageKey('usage-widget-plan-glm|b'));
    await tester.pumpAndSettle();
    expect(h.usage.widgetSettings.hiddenKeys, {'glm|b'});

    await tester.tap(usageKey('usage-widget-plan-glm|b'));
    await tester.pumpAndSettle();
    expect(h.usage.widgetSettings.hiddenKeys, isEmpty);
  });

  usageTestWidgets('5-hour, weekly or both is saved', (tester) async {
    final h = await _open(tester);
    expect(h.usage.widgetSettings.windows, UsageWidgetWindows.both);
    await tester.tap(usageKey('usage-widget-windows-weekly'));
    await tester.pumpAndSettle();
    expect(h.usage.widgetSettings.windows, UsageWidgetWindows.weekly);
    await tester.tap(usageKey('usage-widget-windows-fiveHour'));
    await tester.pumpAndSettle();
    expect(h.usage.widgetSettings.windows, UsageWidgetWindows.fiveHour);
    await tester.tap(usageKey('usage-widget-windows-both'));
    await tester.pumpAndSettle();
    expect(h.usage.widgetSettings.windows, UsageWidgetWindows.both);
  });

  usageTestWidgets('rows that need setup are on by default and can be turned '
      'off', (tester) async {
    final h = await _open(tester);
    expect(h.usage.widgetSettings.showSetupRows, isTrue);
    await tester.tap(usageKey('usage-widget-setup'));
    await tester.pumpAndSettle();
    expect(h.usage.widgetSettings.showSetupRows, isFalse);
    // The choice survives a restart: it is read back from storage.
    expect(UsageWidgetSettings.load(h.usage.prefs).showSetupRows, isFalse);
  });

  usageTestWidgets('with no plans the list says so and the other choices '
      'still show', (tester) async {
    await _open(tester, plans: false);
    expect(usageKey('usage-widget-none'), findsOneWidget);
    expect(usageKey('usage-widget-setup'), findsOneWidget);
    expect(usageKey('usage-widget-windows'), findsOneWidget);
  });
}
