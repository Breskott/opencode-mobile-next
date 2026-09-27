// Behaviour of screen-usage-2's pages (wave 2b): Usage (usage-hub) and its
// Remaining section (provider-quota) with the monitoring sheet, rebuilt from
// kit parts; one alert threshold per source (owner rule 2026-09-27). The tests assert what the
// person sees, what is read and what is stored.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/provider_quota_monitor.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';
import 'package:opencode_mobile/ui/screens/provider_quota_screen.dart';
import 'package:opencode_mobile/ui/screens/usage_hub_screen.dart';
import 'package:opencode_mobile/ui/screens/usage_screen.dart';

import 'screen_usage_2_support.dart';

final _en = lookupAppLocalizations(const Locale('en'));

Finder _key(String key) => find.byKey(ValueKey(key));

Widget _app(Widget home) => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

Future<QuotaHarness> _pumpQuota(
  WidgetTester tester, {
  bool hub = false,
  bool statistics = true,
  UsageSection? initial,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = await quotaHarness(
    clock: DateTime.now,
    snapshot: () => quotaSnapshot(DateTime.now()),
    statistics: statistics,
  );
  await tester.pumpWidget(
    _app(
      QuotaHarnessOwner(
        harness: h,
        child: hub
            ? UsageHubScreen(
                controller: h.connection,
                initialSection: initial,
                usageOverview: h.usage,
                quotaOverview: h.quota,
              )
            : ProviderQuotaScreen(controller: h.connection, overview: h.quota),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return h;
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find
        .descendant(
          of: _key('quota-content'),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _consentAndRead(WidgetTester tester, QuotaHarness h) async {
  await _scrollTo(tester, _key('quota-consent'));
  await tester.tap(_key('quota-consent'));
  await tester.pumpAndSettle();
  expect(h.gateways, isEmpty, reason: 'consent alone is not a read');
  await _scrollTo(tester, _key('quota-read'));
  await tester.tap(_key('quota-read'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => debugPlatformCapabilities = const PlatformCapabilities.android());
  tearDown(() => debugPlatformCapabilities = null);

  group('provider-quota', () {
    testWidgets('reads only after consent and an explicit read, then shows '
        'each window as a kit progress row', (tester) async {
      final h = await _pumpQuota(tester);
      expect(find.text(_en.quotaSetupTitle), findsOneWidget);
      // The collector is named by its origin on the page; its route is a
      // technical value under Details.
      expect(find.textContaining(quotaOrigin), findsWidgets);
      final read = tester.widget<KitButton>(_key('quota-read'));
      expect(read.onPressed, isNull, reason: 'no read before consent');

      await _consentAndRead(tester, h);
      expect(h.gateways, hasLength(1));
      expect(h.gateways.single.reads, 1);
      expect(find.text(_en.quotaSetupTitle), findsNothing);
      expect(find.text(_en.quotaCodexAccount), findsOneWidget);
      final bar = tester.widget<KitProgressRow>(
        _key('quota-window-bar-primary'),
      );
      expect(bar.value, closeTo(.255, 1e-9));
      expect(bar.valueLabel, '74.5% remaining');
      expect(bar.asOf, isNull, reason: 'a fresh reading carries no age');
      // The unreported window says so instead of drawing an empty bar.
      await _scrollTo(tester, _key('quota-window-secondary'));
      expect(
        find.descendant(
          of: _key('quota-window-secondary'),
          matching: find.text(_en.quotaNotReported),
        ),
        findsOneWidget,
      );
      // No Material stand-ins survive the rebuild.
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(CheckboxListTile), findsNothing);
      expect(find.byType(Card), findsNothing);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('one threshold per source: the windows carry none, and a '
        'monitored account keeps its threshold and Stop in its own block, '
        'not again under Quota monitoring', (tester) async {
      final h = await _pumpQuota(tester);
      await _consentAndRead(tester, h);
      // No personal page threshold, attention switch or clear row.
      expect(_key('quota-threshold-primary'), findsNothing);
      expect(_key('quota-attention-primary'), findsNothing);
      expect(_key('quota-clear'), findsNothing);
      expect(find.text(_en.quotaBudgetClearAll), findsNothing);

      await _scrollTo(tester, _key('quota-enable-monitoring'));
      // The row names the provider and server it turns on; it acts at
      // once, starting at 90% (the enrol sheet merged into the page).
      expect(
        find.text(_en.quotaMonitorOffer(_en.quotaCodex, 'Studio')),
        findsOneWidget,
      );
      await tester.tap(_key('quota-enable-monitoring'));
      await tester.pumpAndSettle();
      expect(_key('quota-enroll-sheet'), findsNothing);
      // The save touches the device alert (a platform call) before it
      // notifies; let that real async work finish.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();

      // The account block now holds the threshold and the named Stop.
      expect(_key('quota-enable-monitoring'), findsNothing);
      final threshold = _key('quota-threshold-$quotaProfileId-codex');
      await _scrollTo(tester, threshold);
      expect(
        find.descendant(
          of: _key('quota-account-monitoring'),
          matching: find.text(_en.quotaBudgetPercent('90')),
        ),
        findsOneWidget,
      );
      final stop = _en.quotaMonitorDisable(_en.quotaCodex, 'Studio');
      expect(find.text(stop), findsOneWidget);
      // The monitoring section lists no card for the source shown above,
      // and its cards carry no Refresh of their own.
      expect(_key('quota-source-$quotaProfileId-codex'), findsNothing);
      expect(threshold, findsOneWidget);
      expect(_key('quota-monitor-empty'), findsNothing);

      await tester.tap(find.text(stop));
      await tester.pumpAndSettle();
      // The save touches the device alert (a platform call) before it
      // notifies; let that real async work finish.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(find.text(stop), findsNothing);
      await _scrollTo(tester, _key('quota-enable-monitoring'));
      expect(_key('quota-enable-monitoring'), findsOneWidget);
    });

    testWidgets('monitoring is turned on in place at 90%, and stopping the '
        'collector returns to setup', (tester) async {
      final h = await _pumpQuota(tester);
      await _consentAndRead(tester, h);

      await _scrollTo(tester, _key('quota-enable-monitoring'));
      await tester.tap(_key('quota-enable-monitoring'));
      await tester.pumpAndSettle();
      expect(_key('quota-enroll-sheet'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(DropdownButton<double>), findsNothing);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      final stored =
          jsonDecode(
                h.connection.store.prefs.getString(
                  ProviderQuotaMonitor.key(quotaProfileId),
                )!,
              )
              as Map<String, dynamic>;
      final rules = (stored['rules'] as Map<String, dynamic>)['codex'] as Map;
      expect(rules['threshold'], 90);
      expect(_key('quota-monitor-save-failed'), findsNothing);

      await _scrollTo(tester, _key('quota-stop'));
      await tester.tap(_key('quota-stop'));
      await tester.pumpAndSettle();
      await tester.drag(_key('quota-content'), const Offset(0, 5000));
      await tester.pumpAndSettle();
      expect(find.text(_en.quotaSetupTitle), findsOneWidget);
    });

    testWidgets('changing provider asks for consent again; Claude explains '
        'why it is unavailable', (tester) async {
      final h = await _pumpQuota(tester);
      await _consentAndRead(tester, h);
      await tester.drag(_key('quota-content'), const Offset(0, 5000));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_en.quotaClaude));
      await tester.pumpAndSettle();
      expect(_key('quota-provider-unavailable'), findsOneWidget);
      expect(find.text(_en.quotaClaudeUnavailable), findsOneWidget);
      await tester.tap(find.text(_en.quotaMiniMax));
      await tester.pumpAndSettle();
      expect(find.text(_en.quotaSetupTitle), findsOneWidget);
    });
  });

  group('usage-hub', () {
    testWidgets('two sections under one bar: Spent first, Remaining one tap '
        'away, both kept alive', (tester) async {
      await _pumpQuota(tester, hub: true);
      expect(find.byType(KitTopBar), findsOneWidget);
      expect(find.text(_en.settingsHubGroupUsage), findsWidgets);
      expect(find.byType(KitTabStrip), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
      expect(find.byType(UsageScreen), findsOneWidget);

      await tester.tap(_key('usage-tab-remaining'));
      await tester.pumpAndSettle();
      expect(find.byType(ProviderQuotaScreen), findsOneWidget);
      expect(
        find.descendant(
          of: _key('usage-section-remaining'),
          matching: find.text(_en.quotaSetupTitle),
        ),
        findsOneWidget,
      );
      // One bar only: the sections add none of their own.
      expect(find.byType(KitTopBar), findsOneWidget);
    });

    testWidgets('an entry point opens straight at Remaining', (tester) async {
      await _pumpQuota(tester, hub: true, initial: UsageSection.remaining);
      expect(
        find.descendant(
          of: _key('usage-section-remaining'),
          matching: find.text(_en.quotaSetupTitle),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the bar holds one Refresh, named for the active tab; the '
        'sections carry none of their own', (tester) async {
      final h = await _pumpQuota(tester, hub: true);
      KitTopBar bar() => tester.widget<KitTopBar>(find.byType(KitTopBar));
      expect(bar().actions.map((a) => a.label), [_en.usageRefreshSpending]);
      expect(
        find.descendant(
          of: _key('usage-section-spent'),
          matching: _key('refresh-usage'),
        ),
        findsNothing,
      );

      await tester.tap(_key('usage-tab-remaining'));
      await tester.pumpAndSettle();
      // Nothing to refresh before the collector may be read.
      expect(bar().actions, isEmpty);
      await _consentAndRead(tester, h);
      expect(bar().actions.map((a) => a.label), [_en.quotaRefresh]);
      bar().actions.single.onPressed!();
      await tester.pumpAndSettle();
      expect(h.gateways.fold<int>(0, (n, g) => n + g.reads), 2);
      expect(
        find.descendant(
          of: _key('usage-section-remaining'),
          matching: _key('quota-refresh'),
        ),
        findsNothing,
      );

      await tester.tap(_key('usage-tab-spent'));
      await tester.pumpAndSettle();
      expect(bar().actions.map((a) => a.label), [_en.usageRefreshSpending]);
    });

    testWidgets('one section left: no tab strip', (tester) async {
      await _pumpQuota(tester, hub: true, statistics: false);
      expect(find.byType(KitTabStrip), findsNothing);
      expect(_key('usage-section-remaining'), findsOneWidget);
      expect(find.byType(UsageScreen), findsNothing);
    });
  });
}
