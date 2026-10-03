// Golden renders of slice-P5.4 "Quota as answers": Remaining from the Codex
// account (fresh, at the alert, and offline with its age), a missing quota
// collector with how to get it, and Spent naming the days the server
// covered. Phone 412x915 and one wide window (1280x800), dark and light,
// real fonts at DPR 1. Synthetic fixtures only.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/slice_p54_golden_test.dart
// and look at every changed image before committing it.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/agent_account.dart';
import 'package:opencode_mobile/domain/provider_quota.dart';
import 'package:opencode_mobile/domain/server_gateway.dart'
    show StreamStatus, UsageStatistics;
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/provider_quota_overview.dart';
import 'package:opencode_mobile/ui/screens/provider_quota_screen.dart';
import 'package:opencode_mobile/ui/screens/usage_screen.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import '../support/account_fakes.dart';
import 'screen_usage_1_support.dart';
import 'screen_usage_2_support.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String state, Size size, bool light) => [
  'slice_p54',
  state,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

Finder _key(String key) => find.byKey(ValueKey(key));

void _limits(FakeAccountSession session, {int primary = 60}) {
  session.account = fixtureSignedIn;
  session.buckets = [
    AccountRateBucket(
      'Codex',
      AccountRateWindow(primary, 300, DateTime(2026, 9, 5, 15)),
      AccountRateWindow(30, 10080, DateTime(2026, 9, 8, 9)),
    ),
  ];
}

Future<void> _frame(
  WidgetTester tester,
  Widget Function() page,
  String state, {
  required bool light,
  Size size = _phone,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  debugPlatformCapabilities = const PlatformCapabilities.android();
  final boundary = GlobalKey();
  try {
    await tester.pumpWidget(usageApp(page(), light: light, boundary: boundary));
    await tester.pumpAndSettle();
    if (act != null) await act(tester);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(boundary),
      matchesGoldenFile('goldens/${_name(state, size, light)}.png'),
    );
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    debugDefaultTargetPlatformOverride = null;
    debugPlatformCapabilities = null;
  }
}

Future<void> _codex(
  WidgetTester tester,
  String state, {
  required bool light,
  Size size = _phone,
  int primary = 60,
  bool offline = false,
}) async {
  mockSecureStorage();
  final connection = accountConnection(
    prepare: (s) => _limits(s, primary: primary),
  );
  var now = usageNow;
  final quota = ProviderQuotaOverview(connection, clock: () => now);
  addTearDown(quota.dispose);
  await _frame(
    tester,
    () => ProviderQuotaScreen(controller: connection, overview: quota),
    state,
    light: light,
    size: size,
    act: offline
        ? (tester) async {
            connection.status = StreamStatus.disconnected;
            connection.changed();
            await tester.pumpAndSettle();
            now = usageNow.add(const Duration(minutes: 40));
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.paused,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
          }
        : null,
  );
}

void main() {
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';

    testWidgets('codex answer, $theme', (tester) async {
      await _codex(tester, 'codex_answer', light: light);
    });

    testWidgets('codex answer at 1280x800, $theme', (tester) async {
      await _codex(tester, 'codex_answer', light: light, size: _wide);
    });

    testWidgets('codex answer at the alert, $theme', (tester) async {
      await _codex(tester, 'codex_alert', light: light, primary: 85);
    });

    testWidgets('codex answer offline, $theme', (tester) async {
      await _codex(tester, 'codex_offline', light: light, offline: true);
    });

    testWidgets('collector missing, $theme', (tester) async {
      final now = DateTime(2026, 9, 6, 12);
      final h = await quotaHarness(
        clock: () => now,
        snapshot: () =>
            throw const ProviderQuotaFailure(QuotaFailureKind.unsupported),
      );
      await _frame(
        tester,
        () => QuotaHarnessOwner(
          harness: h,
          child: ProviderQuotaScreen(
            controller: h.connection,
            overview: h.quota,
          ),
        ),
        'collector_missing',
        light: light,
        act: (tester) async {
          for (final key in ['quota-consent', 'quota-read']) {
            await tester.ensureVisible(_key(key));
            await tester.pumpAndSettle();
            await tester.tap(_key(key));
            await tester.pumpAndSettle();
          }
          await tester.drag(_key('quota-content'), const Offset(0, 5000));
          await tester.pumpAndSettle();
          await tester.tap(_key('quota-collector-how-to'));
        },
      );
    });

    for (final size in [_phone, _wide]) {
      testWidgets('spent fewer days than asked, $size, $theme', (tester) async {
        final h = usageHarness();
        final stats =
            jsonDecode(jsonEncode(emptyUsage())) as Map<String, dynamic>
              ..['cost'] = 1.25
              ..['sessions'] = 3
              ..['range'] = {
                'from': DateTime(2026, 9, 2).millisecondsSinceEpoch,
                'to': DateTime(2026, 9, 7).millisecondsSinceEpoch,
              };
        h.repo.result = UsageStatistics.fromJson(stats);
        await _frame(
          tester,
          () => UsageScreen(controller: h.connection, overview: h.overview),
          'spent_partial',
          light: light,
          size: size,
        );
      });
    }
  }
}
