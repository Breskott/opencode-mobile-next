// slice-P3.7a "One diff component": every diff opens on KitDiffView with its
// one "Change 1 of N" navigator. Run results open a changed file's recorded
// diff directly (no record sheet in between) and walk the whole run's
// changes; the read-only diff page keeps "1 of 2" whole right to left.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/api/models.dart';
import 'package:opencode_mobile/domain/run_result.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/kit/kit_bidi.dart';
import 'package:opencode_mobile/ui/kit/kit_diff_view.dart';
import 'package:opencode_mobile/ui/screens/review_workspace.dart';
import 'package:opencode_mobile/ui/widgets/run_result_view.dart';

Part _tool(String id, String name, Map<String, dynamic> input, [Map? meta]) =>
    Part(
      id: id,
      callID: id,
      type: 'tool',
      toolName: name,
      toolState: ToolState(
        status: 'completed',
        input: input,
        output: '',
        metadata: meta == null ? null : Map<String, dynamic>.from(meta),
      ),
    );

const _cartPatch =
    '@@ -1,3 +1,3 @@\n'
    ' class Cart {\n'
    '-  int total = 0;\n'
    '+  int total = 1;\n'
    ' }\n';

const _apiPatch =
    '@@ -4,2 +4,2 @@\n'
    ' import "http";\n'
    '-const base = "v1";\n'
    '+const base = "v2";\n';

const _uiPatch =
    '@@ -9,2 +9,2 @@\n'
    ' Widget build() {\n'
    '-  return Old();\n'
    '+  return New();\n';

RunResult _run() => RunResult.fromMessages('ses_1', [
  MessageWithParts(
    info: MessageInfo(
      id: 'u1',
      sessionID: 'ses_1',
      role: 'user',
      time: MsgTime(created: 1),
    ),
    parts: const [],
  ),
  MessageWithParts(
    info: MessageInfo(
      id: 'a1',
      sessionID: 'ses_1',
      role: 'assistant',
      finish: 'stop',
      time: MsgTime(created: 2, completed: 3),
    ),
    parts: [
      _tool(
        'e1',
        'edit',
        {'filePath': 'lib/cart.dart'},
        {
          'filediff': {'patch': _cartPatch},
        },
      ),
      _tool('e2', 'edit', {
        'filePath': 'lib/notes.txt',
        'oldString': 'draft',
        'newString': 'final',
      }),
      _tool('w1', 'write', {
        'filePath': 'lib/new_file.dart',
        'content': 'void main() {}',
      }),
      _tool('p1', 'apply_patch', {}, {
        'files': [
          {'path': 'lib/api.dart', 'patch': _apiPatch},
          {'path': 'lib/ui.dart', 'patch': _uiPatch},
        ],
      }),
    ],
  ),
], historyComplete: true)!;

Widget _app(Widget home, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: home,
    );

Future<void> _openRunFile(WidgetTester tester, String name) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(
      Scaffold(
        body: RunResultView(
          result: _run(),
          observedLive: true,
          onOpenConversation: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text(name), 200);
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  group('run results open the recorded diff directly', () {
    testWidgets('an edited file opens on the diff page, at that file, with '
        'the run\'s other diffs one navigator away', (tester) async {
      await _openRunFile(tester, 'api.dart');
      expect(find.byKey(const Key('run-result-diff')), findsOneWidget);
      expect(find.byKey(const Key('run-result-output-sheet')), findsNothing);
      expect(find.text('Changed files'), findsWidgets);
      // The patch tool's own patch for this file, not its neighbour's.
      expect(find.text('const base = "v2";'), findsOneWidget);
      expect(find.textContaining('return New();'), findsNothing);
      // Four files carry a diff (the write does not): cart, notes, api, ui.
      final diff = tester.widget<KitDiffView>(find.byType(KitDiffView));
      expect(
        [for (final f in diff.files) f.path],
        ['lib/cart.dart', 'lib/notes.txt', 'lib/api.dart', 'lib/ui.dart'],
      );
      expect(diff.initialFile, 2);
      // One "Change N of 4" navigator across the run's files.
      expect(find.text('Change 3 of 4'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('kit-diff-nav-next')));
      await tester.pumpAndSettle();
      expect(find.text('Change 4 of 4'), findsOneWidget);
      expect(find.textContaining('return New();'), findsOneWidget);
      // PC: P goes back a change.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();
      expect(find.text('Change 3 of 4'), findsOneWidget);
      // Close returns to Run results.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('run-result-view')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an edit recorded as old and new text shows as a diff', (
      tester,
    ) async {
      await _openRunFile(tester, 'notes.txt');
      expect(find.byKey(const Key('run-result-diff')), findsOneWidget);
      expect(find.text('draft'), findsOneWidget);
      expect(find.text('final'), findsOneWidget);
      expect(find.text('Change 2 of 4'), findsOneWidget);
    });

    testWidgets('a written file has no diff, so it still opens its record', (
      tester,
    ) async {
      await _openRunFile(tester, 'new_file.dart');
      expect(find.byKey(const Key('run-result-diff')), findsNothing);
      expect(find.byKey(const Key('run-result-output-sheet')), findsOneWidget);
    });
  });

  testWidgets('the diff page keeps "1 of 2" whole right to left', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        DiffPage(
          diffs: [
            FileDiff(file: 'lib/a.dart', patch: _cartPatch),
            FileDiff(file: 'lib/b.dart', patch: _apiPatch),
          ],
        ),
        direction: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(' · ${KitBidi.auto('1 of 2')}', findRichText: true),
      findsOneWidget,
    );
    // Only directional insets on the page's own parts: the header's start
    // is the right edge.
    final header = tester.getRect(
      find.byKey(const ValueKey('diff-file-header-lib/a.dart')),
    );
    final name = tester.getRect(find.textContaining('a.dart').first);
    expect(name.right, greaterThan(header.center.dx));
    expect(tester.takeException(), isNull);
  });
}
