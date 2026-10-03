import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'server_editor.dart';

/// Walks the first-run computer path from the welcome to the connect step:
/// "On my computer", then what runs there (Add server's first step, P3.9).
/// [agent] is `opencode`, `paseo` or `codex`, the suffix of the choice's
/// key.
///
/// Large text pushes a choice below the fold, so each one is brought on
/// screen before it is tapped.
Future<void> openFirstRunConnect(
  WidgetTester tester, {
  String agent = 'opencode',
}) async {
  final computer = find.byKey(const ValueKey('welcome-choice-computer'));
  // The welcome is a lazy list: at large text the choice is not built
  // until it is scrolled near.
  await tester.scrollUntilVisible(
    computer,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(computer);
  await tester.pumpAndSettle();
  await tester.tap(computer);
  await tester.pumpAndSettle();
  await chooseServerKind(tester, kind: agent);
}
