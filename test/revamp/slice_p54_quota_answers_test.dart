// Behaviour of slice-P5.4 "Quota as answers": Usage → Remaining answers in
// sentences from the Codex account on a Codex host (no collector, no
// consent), keeps the last known value with its age when offline, alerts at
// 80% used by default, says a missing collector is needed on the named
// server with how to get it, and Spent names the days the server actually
// covered. Synthetic fixtures only; nothing reaches a server.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/usage_statistics.dart';
import 'package:opencode_mobile/l10n/app_localizations_en.dart';
import 'package:opencode_mobile/ui/screens/usage_screen.dart';

import '../../tool/capture/fixtures.dart' show loadCaptureFonts;
import 'screen_usage_1_support.dart';

final _en = AppLocalizationsEn();
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(loadCaptureFonts);

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
