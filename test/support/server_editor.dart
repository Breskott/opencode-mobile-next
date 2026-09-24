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
  final header = find.byKey(
    const ValueKey('server-editor-more-options-header'),
  );
  await tester.ensureVisible(header);
  await tester.pumpAndSettle();
  await tester.tap(header);
  await tester.pumpAndSettle();
}

/// Opens "Enter the address instead", where a new OpenCode server keeps its
/// address and password behind pairing (ledger row 15). Does nothing where
/// the fields are already shown (editing a saved server, Codex, Paseo).
Future<void> openServerManualAddress(WidgetTester tester) async {
  if (find.byKey(const ValueKey('server-url-field')).evaluate().isNotEmpty) {
    return;
  }
  final header = find.byKey(const ValueKey('server-manual-address'));
  if (header.evaluate().isEmpty) return;
  await tester.ensureVisible(header);
  await tester.pumpAndSettle();
  await tester.tap(header);
  await tester.pumpAndSettle();
}
