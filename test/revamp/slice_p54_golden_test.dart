// Golden renders of slice-P5.4: Spent naming the days the server covered.
// Phone 412x915 and one wide window (1280x800), dark and light, real fonts at
// DPR 1. Synthetic fixtures only.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/revamp/slice_p54_golden_test.dart
// and look at every changed image before committing it.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/server_gateway.dart'
    show UsageStatistics;
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/screens/usage_screen.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import 'screen_usage_1_support.dart';

const _phone = Size(412, 915);
const _wide = Size(1280, 800);

String _name(String state, Size size, bool light) => [
  'slice_p54',
  state,
  if (size != _phone) '${size.width.toInt()}x${size.height.toInt()}',
  light ? 'light' : 'dark',
].join('_');

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

void main() {
  setUpAll(loadCaptureFonts);

  for (final light in [false, true]) {
    final theme = light ? 'light' : 'dark';

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
