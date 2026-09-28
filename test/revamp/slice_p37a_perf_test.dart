// slice-P3.7a speed probe: a 5,000-line diff opened on the read-only diff
// page stays fast because KitDiffView builds only the lines on screen.
// Prints wall-clock numbers (debug test harness, so compare runs on the same
// machine, not with a device) and asserts the part that does not depend on
// the machine: how many lines are built at once.
//
//   flutter test test/revamp/slice_p37a_perf_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/screens/review_workspace.dart';

/// One file, 5,000 patch lines: 250 hunks of 10 kept, 5 removed, 5 added.
FileDiff _bigDiff() {
  final out = StringBuffer()
    ..writeln('--- a/lib/big.dart')
    ..writeln('+++ b/lib/big.dart');
  var oldLine = 1;
  var newLine = 1;
  for (var h = 0; h < 250; h++) {
    out.writeln('@@ -$oldLine,15 +$newLine,15 @@');
    for (var i = 0; i < 10; i++) {
      out.writeln(' final kept${h}_$i = compute($h, $i);');
    }
    for (var i = 0; i < 5; i++) {
      out.writeln('-  oldValue${h}_$i = legacy($i);');
    }
    for (var i = 0; i < 5; i++) {
      out.writeln('+  newValue${h}_$i = modern($i);');
    }
    oldLine += 15;
    newLine += 15;
  }
  return FileDiff(
    file: 'lib/big.dart',
    additions: 1250,
    deletions: 1250,
    patch: out.toString(),
  );
}

Widget _page(List<FileDiff> diffs) => DiffPage(diffs: diffs);

void main() {
  testWidgets('a 5,000-line diff opens, jumps and scrolls with only the '
      'visible lines built', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final diff = _bigDiff();
    expect('\n'.allMatches(diff.patch!).length, 5000 + 2 + 250);

    final open = Stopwatch()..start();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: _page([diff]),
      ),
    );
    await tester.pumpAndSettle();
    open.stop();
    expect(tester.takeException(), isNull);

    // Virtualised: a phone window shows a few dozen lines, never thousands.
    final built = find.textContaining(RegExp(r'Value\d+_|kept\d+_'));
    final builtLines = built.evaluate().length;
    expect(builtLines, greaterThan(10));
    expect(builtLines, lessThan(300));

    // Next change x20 through the one "Change 1 of N" navigator.
    final next = find.byKey(const ValueKey('diff-nav-next'));
    expect(next, findsOneWidget);
    final jumps = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    jumps.stop();
    expect(find.text('Change 21 of 250'), findsOneWidget);

    // The same with the keyboard (PC): N moves on, P moves back.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.pumpAndSettle();
    expect(find.text('Change 22 of 250'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await tester.pumpAndSettle();
    expect(find.text('Change 21 of 250'), findsOneWidget);

    // Scroll: 30 drags of 600 px.
    final lines = find.byType(Scrollable).last;
    final scroll = Stopwatch()..start();
    for (var i = 0; i < 30; i++) {
      await tester.drag(lines, const Offset(0, -600));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    scroll.stop();
    expect(built.evaluate().length, lessThan(300));
    expect(tester.takeException(), isNull);

    debugPrint(
      'PERF diff5000 open_ms=${open.elapsedMilliseconds} '
      'built_lines=$builtLines '
      'next_x20_ms=${jumps.elapsedMilliseconds} '
      'scroll_x30_ms=${scroll.elapsedMilliseconds}',
    );
  });
}
