// Golden renders of screen-usage-2's pages (wave 2b): Usage (usage-hub) on
// its Remaining tab, Remaining usage (provider-quota) before consent, with a
// reading and with that account monitored, rebuilt from kit parts (the
// monitoring sheet, provider-quota-enroll-dialog, merged into the page in
// slice-P3.11a). Phone 412x915 and one wide window (1280x800), dark and
// light (owner decision 2026-09-27: no Arabic), real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_usage_2_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/provider_quota.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/state/provider_quota_monitor.dart';
import 'package:opencode_mobile/ui/screens/provider_quota_screen.dart';
import 'package:opencode_mobile/ui/screens/usage_hub_screen.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import 'screen_usage_1_support.dart' show usageApp;
import 'screen_usage_2_support.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);
final _now = DateTime(2026, 9, 6, 12);

String _name(String state, Size size, bool light) => [
  state,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

enum _Page { quota, hub }

/// Pushes [page] over a blank route (so its bar has Back), runs [act],
/// settles and compares the whole window.
Future<void> _shot(
  WidgetTester tester,
  String state, {
  required bool light,
  _Page page = _Page.quota,
  Size size = _phone,
  bool monitored = false,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  debugPlatformCapabilities = const PlatformCapabilities.android();
  final boundary = GlobalKey();
  final navigator = GlobalKey<NavigatorState>();
  try {
    final h = await quotaHarness(
      clock: () => _now,
      snapshot: () => quotaSnapshot(_now),
      statistics: page == _Page.hub,
    );
    if (monitored) await _monitor(h);
    await tester.pumpWidget(
      usageApp(
        QuotaHarnessOwner(harness: h, child: const SizedBox.expand()),
        light: light,
        boundary: boundary,
        navigator: navigator,
      ),
    );
    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => switch (page) {
            _Page.quota => ProviderQuotaScreen(
              controller: h.connection,
              overview: h.quota,
            ),
            _Page.hub => UsageHubScreen(
              controller: h.connection,
              initialSection: UsageSection.remaining,
              usageOverview: h.usage,
              quotaOverview: h.quota,
            ),
          },
        ),
      ),
    );
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

Finder _key(String key) => find.byKey(ValueKey(key));

const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

/// This account already monitored at 90% used. The record's source is not
/// this server's hash, so the monitor never starts a read (no network) while
/// the page shows the source's threshold and Stop in the account's block.
Future<void> _monitor(QuotaHarness h) => h.connection.store.prefs.setString(
  ProviderQuotaMonitor.key(quotaProfileId),
  jsonEncode({
    'version': 1,
    'rules': {
      QuotaProvider.codex.name: const QuotaMonitorRules(
        source: _hash,
        account: _hash,
        token: _hash,
        threshold: 90,
      ).toJson(),
    },
  }),
);

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

Future<void> _read(WidgetTester tester) async {
  await _scrollTo(tester, _key('quota-consent'));
  await tester.tap(_key('quota-consent'));
  await tester.pumpAndSettle();
  await _scrollTo(tester, _key('quota-read'));
  await tester.tap(_key('quota-read'));
  await tester.pumpAndSettle();
}

Future<void> _readToTop(WidgetTester tester) async {
  await _read(tester);
  await tester.drag(_key('quota-content'), const Offset(0, 5000));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';

    testWidgets('quota setup, $theme', (tester) async {
      await _shot(tester, 'quota_setup', light: light);
    });

    testWidgets('quota loaded, $theme', (tester) async {
      await _shot(
        tester,
        'quota_loaded',
        light: light,
        monitored: true,
        act: _readToTop,
      );
    });

    testWidgets('quota loaded, window panel, $theme', (tester) async {
      await _shot(
        tester,
        'quota_window',
        light: light,
        monitored: true,
        act: (tester) async {
          await _readToTop(tester);
          await _scrollTo(tester, _key('quota-window-primary'));
        },
      );
    });

    testWidgets('quota loaded at 1280x800, $theme', (tester) async {
      await _shot(
        tester,
        'quota_loaded',
        light: light,
        size: _wide,
        monitored: true,
        act: _readToTop,
      );
    });

    testWidgets('usage hub on Remaining, $theme', (tester) async {
      await _shot(tester, 'usage_hub_remaining', light: light, page: _Page.hub);
    });

    testWidgets('usage hub on Remaining at 1280x800, $theme', (tester) async {
      await _shot(
        tester,
        'usage_hub_remaining',
        light: light,
        page: _Page.hub,
        size: _wide,
      );
    });
  }
}
