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
  await chooseServerKind(tester);
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

/// Answers Add server's first step (P3.9), what runs there: [kind] is
/// `opencode`, `codex` or `paseo`. Does nothing past that step.
Future<void> chooseServerKind(
  WidgetTester tester, {
  String kind = 'opencode',
}) async {
  if (find.byKey(const ValueKey('server-kind-step')).evaluate().isEmpty) {
    return;
  }
  final choice = find.byKey(ValueKey('server-backend-$kind'));
  await tester.ensureVisible(choice);
  await tester.pumpAndSettle();
  // At 2.5x text a choice can be taller than the space left on a 320 dp
  // screen, so its centre may sit below the fold; its top is always in view.
  await tester.tapAt(tester.getTopLeft(choice) + const Offset(24, 24));
  await tester.pumpAndSettle();
}

/// Leaves Add server's ready step (P3.9) through its one way on, "Open"
/// and the server's name. Does nothing when the editor is not on that step.
Future<void> openReadyServer(WidgetTester tester) async {
  final open = find.byKey(const ValueKey('server-ready-open'));
  if (open.evaluate().isEmpty) return;
  await tester.tap(open);
  await tester.pumpAndSettle();
}
