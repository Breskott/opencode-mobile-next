// KitRefresh without a finger: a screen reader's "Refresh" action and the
// keyboard's Ctrl+R / F5 start the same refresh a pull does.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/motion/kit_refresh.dart';

class _Host {
  int refreshes = 0;
  Completer<void> pending = Completer<void>();

  Future<void> onRefresh() {
    refreshes++;
    return pending.future;
  }

  /// Lets the running refresh finish and gets ready for the next one.
  Future<void> finish(WidgetTester tester) async {
    pending.complete();
    pending = Completer<void>();
    await tester.pumpAndSettle();
  }
}

Future<_Host> _pump(WidgetTester tester) async {
  final host = _Host();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: KitRefresh(
          onRefresh: host.onRefresh,
          child: ListView(
            children: const [
              Focus(autofocus: true, child: SizedBox(height: 48)),
              SizedBox(height: 48),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return host;
}

void main() {
  testWidgets('a screen reader offers Refresh, and it refreshes', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final host = await _pump(tester);
    final node = find.semantics.byAction(SemanticsAction.customAction);
    expect(node, findsOne);
    final data = node.evaluate().single.getSemanticsData();
    expect([
      for (final id in data.customSemanticsActionIds ?? const <int>[])
        CustomSemanticsAction.getAction(id)?.label,
    ], contains('Refresh'));

    tester.semantics.customAction(
      node,
      const CustomSemanticsAction(label: 'Refresh'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(host.refreshes, 1);
    await host.finish(tester);
    handle.dispose();
  });

  testWidgets('Ctrl+R and F5 refresh while focus is in the list', (
    tester,
  ) async {
    final host = await _pump(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(host.refreshes, 1);
    // A second press while it runs does not start another.
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pump(const Duration(milliseconds: 300));
    expect(host.refreshes, 1);
    await host.finish(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(host.refreshes, 2);
    await host.finish(tester);
  });
}
