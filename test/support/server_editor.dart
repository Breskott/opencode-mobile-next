import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the server editor's "More options" (display name, username, AI
/// Team), which starts closed on a new server.
Future<void> openServerMoreOptions(WidgetTester tester) async {
  if (find
      .byKey(const ValueKey('server-username-field'))
      .evaluate()
      .isNotEmpty) {
    return;
  }
  final tile = find.byKey(const ValueKey('server-editor-more-options'));
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(of: tile, matching: find.byType(ListTile)).first,
  );
  await tester.pumpAndSettle();
}
