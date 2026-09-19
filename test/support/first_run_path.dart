import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Walks the first-run computer path from the welcome to the connect screen:
/// "On my computer", then the agent. [agent] is `opencode`, `paseo` or
/// `codex`, the suffix of the choice's key.
///
/// Large text pushes a choice below the fold, so each one is brought on
/// screen before it is tapped.
Future<void> openFirstRunConnect(
  WidgetTester tester, {
  String agent = 'opencode',
}) async {
  final computer = find.byKey(const ValueKey('welcome-choice-computer'));
  await tester.ensureVisible(computer);
  await tester.pumpAndSettle();
  await tester.tap(computer);
  await tester.pumpAndSettle();
  final choice = find.byKey(ValueKey('agent-choice-$agent'));
  await tester.ensureVisible(choice);
  await tester.pumpAndSettle();
  await tester.tap(choice);
  await tester.pumpAndSettle();
}
