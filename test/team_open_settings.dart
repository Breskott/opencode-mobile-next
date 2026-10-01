import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens Team settings from the team home. On a phone the top bar keeps one
/// action in view and the rest wait in the overflow, so go there when the
/// action is not drawn.
Future<void> openTeamSettingsFromHome(WidgetTester tester) async {
  final direct = find.byKey(const ValueKey('team-home-settings'));
  if (direct.evaluate().isNotEmpty) {
    await tester.tap(direct);
  } else {
    await tester.tap(find.byKey(const ValueKey('team-home-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team settings'));
  }
  await tester.pumpAndSettle();
}
