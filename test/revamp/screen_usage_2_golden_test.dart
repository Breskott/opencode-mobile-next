// Golden renders of screen-usage-2's pages (wave 2b): Usage (usage-hub) on
// its Remaining tab, Remaining usage (provider-quota) before consent and
// with a reading, the monitoring sheet (provider-quota-enroll-dialog) and
// the clear-thresholds confirmation (provider-quota-clear-dialog), rebuilt
// from kit parts. Phone 412x915 and one wide window (1280x800), dark and
// light (owner decision 2026-09-27: no Arabic), real fonts at DPR 1.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/screen_usage_2_golden_test.dart
// and look at every changed image before committing it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
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

Future<void> _readWithThreshold(WidgetTester tester) async {
  await _read(tester);
  await _scrollTo(tester, _key('quota-threshold-primary'));
  await tester.tap(_key('quota-threshold-primary'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('90% used').last);
  await tester.pumpAndSettle();
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
        act: _readWithThreshold,
      );
    });

    testWidgets('quota loaded, window panel, $theme', (tester) async {
      await _shot(
        tester,
        'quota_window',
        light: light,
        act: (tester) async {
          await _readWithThreshold(tester);
          await _scrollTo(tester, _key('quota-attention-primary'));
        },
      );
    });

    testWidgets('quota loaded at 1280x800, $theme', (tester) async {
      await _shot(
        tester,
        'quota_loaded',
        light: light,
        size: _wide,
        act: _readWithThreshold,
      );
    });

    testWidgets('quota enroll sheet, $theme', (tester) async {
      await _shot(
        tester,
        'quota_enroll_sheet',
        light: light,
        act: (tester) async {
          await _read(tester);
          await _scrollTo(tester, _key('quota-enable-monitoring'));
          await tester.tap(_key('quota-enable-monitoring'));
          await tester.pumpAndSettle();
        },
      );
    });

    testWidgets('quota clear confirm, $theme', (tester) async {
      await _shot(
        tester,
        'quota_clear_confirm',
        light: light,
        act: (tester) async {
          await _read(tester);
          await _scrollTo(tester, _key('quota-clear'));
          await tester.tap(_key('quota-clear'));
          await tester.pumpAndSettle();
        },
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
