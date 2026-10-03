// Behaviour of slice-P5.4 "Quota as answers": Usage → Remaining answers in
// sentences from the Codex account on a Codex host (no collector, no
// consent), keeps the last known value with its age when offline, alerts at
// 80% used by default, says a missing collector is needed on the named
// server with how to get it, and Spent names the days the server actually
// covered. Synthetic fixtures only; nothing reaches a server.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:opencode_mobile/domain/server_gateway.dart' show StreamStatus;
import 'package:opencode_mobile/domain/agent_account.dart';
import 'package:opencode_mobile/domain/provider_quota.dart';
import 'package:opencode_mobile/domain/usage_statistics.dart';
import 'package:opencode_mobile/l10n/app_localizations_en.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/provider_quota_overview.dart';
import 'package:opencode_mobile/ui/screens/provider_quota_screen.dart';
import 'package:opencode_mobile/ui/screens/usage_screen.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import '../support/account_fakes.dart';
import 'screen_usage_1_support.dart';
import 'screen_usage_2_support.dart';

final _en = AppLocalizationsEn();
Finder _key(String key) => find.byKey(ValueKey(key));

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Signed in with a 5-hour window at [primary] used resetting at 15:00
/// today, and a weekly window at [weekly] used resetting in three days.
void _limits(FakeAccountSession session, {int primary = 60, int weekly = 30}) {
  session.account = fixtureSignedIn;
  session.buckets = [
    AccountRateBucket(
      'Codex',
      AccountRateWindow(primary, 300, DateTime(2026, 9, 5, 15)),
      AccountRateWindow(weekly, 10080, DateTime(2026, 9, 8, 9)),
    ),
  ];
}

Future<({AccountConnection connection, ProviderQuotaOverview quota})>
_pumpAccount(
  WidgetTester tester, {
  required void Function(FakeAccountSession) prepare,
  DateTime Function()? clock,
}) async {
  _phone(tester);
  final connection = accountConnection(prepare: prepare);
  final quota = ProviderQuotaOverview(
    connection,
    clock: clock ?? () => usageNow,
  );
  addTearDown(quota.dispose);
  await tester.pumpWidget(
    usageApp(ProviderQuotaScreen(controller: connection, overview: quota)),
  );
  await tester.pumpAndSettle();
  return (connection: connection, quota: quota);
}

void main() {
  setUpAll(loadCaptureFonts);

  group('Remaining from the Codex account', () {
    setUp(mockSecureStorage);

    testWidgets('answers in sentences, attributed, without a collector', (
      tester,
    ) async {
      await _pumpAccount(tester, prepare: _limits);
      final weekday = DateFormat.E('en').format(DateTime(2026, 9, 8, 9));
      final time = DateFormat.jm('en').format(DateTime(2026, 9, 5, 15));
      expect(
        find.text('About 40% left in this 5-hour window · resets at $time'),
        findsOneWidget,
      );
      expect(
        find.text('About 70% left this week · resets $weekday'),
        findsOneWidget,
      );
      // The bar fills with what is used and its words say so.
      expect(find.text('60% used'), findsOneWidget);
      expect(
        find.text(_en.quotaAnswerFromCodex('My Codex host')),
        findsOneWidget,
      );
      // No collector, consent step or provider choice on a Codex host.
      expect(_key('quota-setup-title'), findsNothing);
      expect(_key('quota-consent'), findsNothing);
      expect(_key('quota-provider'), findsNothing);
      expect(_key('quota-collector'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Alert me at 80% used is on by default and saves per server', (
      tester,
    ) async {
      final h = await _pumpAccount(tester, prepare: _limits);
      final alert = find.byKey(const ValueKey('quota-answer-alert'));
      await tester.ensureVisible(alert);
      await tester.pumpAndSettle();
      expect(find.text(_en.quotaAnswerAlert('80%')), findsOneWidget);
      expect(tester.widget<Switch>(alert).value, isTrue);
      expect(
        h.connection.store.prefs.get('oc.quotaAnswers.account-fixture'),
        isNull,
        reason: 'default on needs nothing stored',
      );

      await tester.tap(alert);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(alert).value, isFalse);
      expect(
        jsonDecode(
          h.connection.store.prefs.getString(
            'oc.quotaAnswers.account-fixture',
          )!,
        ),
        {'version': 1, 'alert80Enabled': false},
      );
    });

    testWidgets('a fresh reading at 80% used or more says so on the page', (
      tester,
    ) async {
      await _pumpAccount(tester, prepare: (s) => _limits(s, primary: 85));
      expect(_key('quota-answer-attention'), findsOneWidget);
      expect(find.text(_en.quotaAnswerAttention('80%')), findsOneWidget);
    });

    testWidgets('below 80% there is nothing to alert', (tester) async {
      await _pumpAccount(tester, prepare: _limits);
      expect(_key('quota-answer-attention'), findsNothing);
    });

    testWidgets('offline, the last known answer stays with its age', (
      tester,
    ) async {
      var now = usageNow;
      final h = await _pumpAccount(tester, prepare: _limits, clock: () => now);
      expect(_key('quota-answer-age'), findsNothing);

      h.connection.status = StreamStatus.disconnected;
      h.connection.changed();
      await tester.pumpAndSettle();
      expect(find.text(_en.quotaAnswerAgeNow), findsOneWidget);
      expect(find.textContaining('left this week'), findsOneWidget);

      // Coming back to the app later says the age again.
      now = usageNow.add(const Duration(minutes: 12));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      // Reading the age never moves the observation time.
      expect(find.text(_en.quotaAnswerAgeMinutes(12)), findsOneWidget);
      expect(find.textContaining('left this week'), findsOneWidget);
    });

    testWidgets('reconnecting reads again on a fresh session', (tester) async {
      final sessions = <FakeAccountSession>[];
      final h = await _pumpAccount(
        tester,
        prepare: (s) {
          _limits(s);
          sessions.add(s);
        },
      );
      h.connection.status = StreamStatus.disconnected;
      h.connection.changed();
      await tester.pumpAndSettle();
      expect(_key('quota-answer-age'), findsOneWidget);

      h.connection.status = StreamStatus.connected;
      h.connection.changed();
      await tester.pumpAndSettle();
      expect(sessions, hasLength(2));
      expect(sessions.first.closed, isTrue);
      expect(sessions.last.limitReads, 1);
      expect(_key('quota-answer-age'), findsNothing);
    });

    testWidgets('signed out: one row names where to sign in and opens it', (
      tester,
    ) async {
      await _pumpAccount(tester, prepare: (s) => s.account = fixtureSignedOut);
      final row = find.text(_en.quotaAnswerSignIn('My Codex host'));
      expect(row, findsOneWidget);
      expect(_key('quota-answer-alert'), findsNothing);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text(_en.agentAccountTitle), findsOneWidget);
    });

    testWidgets('an API-key sign-in says why there is nothing to show', (
      tester,
    ) async {
      await _pumpAccount(
        tester,
        prepare: (s) {
          _limits(s);
          s.account = const AgentAccount(type: 'apiKey', requiresSignIn: true);
        },
      );
      expect(find.text(_en.quotaAnswerUnsupported), findsOneWidget);
      expect(find.textContaining('left this week'), findsNothing);
    });
  });

  group('Remaining through a collector', () {
    setUp(
      () => debugPlatformCapabilities = const PlatformCapabilities.android(),
    );
    tearDown(() => debugPlatformCapabilities = null);

    Future<QuotaHarness> pump(
      WidgetTester tester,
      ProviderQuotaSnapshot Function() answer,
    ) async {
      _phone(tester);
      final h = await quotaHarness(
        clock: () => DateTime(2026, 9, 6, 12),
        snapshot: answer,
      );
      await tester.pumpWidget(
        usageApp(
          QuotaHarnessOwner(
            harness: h,
            child: ProviderQuotaScreen(
              controller: h.connection,
              overview: h.quota,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return h;
    }

    Future<void> consentAndRead(WidgetTester tester) async {
      for (final key in ['quota-consent', 'quota-read']) {
        await tester.ensureVisible(_key(key));
        await tester.pumpAndSettle();
        await tester.tap(_key(key));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('before a read: the collector is named as needed on the '
        'server, with how to get it folded in place', (tester) async {
      await pump(tester, () => quotaSnapshot(DateTime(2026, 9, 6, 12)));
      expect(find.text(_en.quotaNeedsCollector('Studio')), findsOneWidget);
      await tester.tap(find.text(_en.quotaCollectorHowTo));
      await tester.pumpAndSettle();
      expect(
        find.text(_en.quotaCollectorStepInstall('Studio')),
        findsOneWidget,
      );
      expect(find.text(_en.quotaCollectorStepRetry), findsOneWidget);
    });

    testWidgets('a missing collector route says so, naming the server', (
      tester,
    ) async {
      await pump(
        tester,
        () => throw const ProviderQuotaFailure(QuotaFailureKind.unsupported),
      );
      await consentAndRead(tester);
      expect(find.text(_en.quotaNeedsCollector('Studio')), findsOneWidget);
      expect(_key('quota-collector-how-to'), findsOneWidget);
    });

    testWidgets('a reading answers per window; alerts start at 80%', (
      tester,
    ) async {
      await pump(tester, () => quotaSnapshot(DateTime(2026, 9, 6, 12)));
      await consentAndRead(tester);
      expect(
        find.textContaining('left in this 5-hour window · resets at'),
        findsOneWidget,
      );
      expect(find.text('25.5% used'), findsOneWidget);
      await tester.ensureVisible(_key('quota-enable-monitoring'));
      expect(find.text(_en.quotaMonitorOfferDetail('80%')), findsOneWidget);
      // The collector's address shows once, in Details.
      await tester.ensureVisible(_key('quota-details'));
      await tester.tap(_key('quota-details'));
      await tester.pumpAndSettle();
      expect(find.textContaining(quotaOrigin), findsOneWidget);
    });
  });

  group('Spent', () {
    testWidgets('a range the server answered in full says so', (tester) async {
      _phone(tester);
      final h = usageHarness();
      await tester.pumpWidget(
        usageApp(UsageScreen(controller: h.connection, overview: h.overview)),
      );
      await tester.pumpAndSettle();
      expect(find.text(_en.usageSpentThirtyDays), findsOneWidget);
    });

    testWidgets('fewer days than asked for are named, not called 30 days', (
      tester,
    ) async {
      _phone(tester);
      final h = usageHarness();
      final stats = jsonDecode(jsonEncode(emptyUsage())) as Map<String, dynamic>
        ..['cost'] = 1.25
        ..['range'] = {
          'from': DateTime(2026, 9, 2).millisecondsSinceEpoch,
          'to': DateTime(2026, 9, 7).millisecondsSinceEpoch,
        };
      h.repo.result = UsageStatistics.fromJson(stats);
      await tester.pumpWidget(
        usageApp(UsageScreen(controller: h.connection, overview: h.overview)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Spent · Sep 2 – 6'), findsOneWidget);
      expect(find.text(_en.usageSpentThirtyDays), findsNothing);
    });
  });
}
