import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/domain/mobile_tool_view.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_chip.dart';
import 'package:opencode_mobile/ui/kit/kit_task_mark.dart';
import 'package:opencode_mobile/ui/widgets/mobile_task_view.dart';

void main() {
  const rows = [
    {'content': 'Review changes', 'status': 'completed'},
    {'content': 'Run focused checks', 'status': 'in_progress'},
    {'content': 'Publish', 'status': 'cancelled'},
  ];
  const prioritised = [
    {'content': 'Review changes', 'status': 'completed', 'priority': 'low'},
    {
      'content': 'Run focused checks',
      'status': 'in_progress',
      'priority': 'high',
    },
    {'content': 'Publish', 'status': 'cancelled', 'priority': 'medium'},
    {'content': 'Announce', 'status': 'pending'},
  ];

  Widget host(Widget child, {double? width, double textScale = 1}) {
    return MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: inner!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: width == null
              ? child
              : Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(width: width, child: child),
                ),
        ),
      ),
    );
  }

  test('only bundled schema and bounded known statuses render', () {
    final view = MobileTaskView.fromTodos(rows)!;
    expect(view.tasks.length, 3);
    expect(view.tasks.last.status, MobileTaskStatus.cancelled);
    expect(
      MobileTaskView.fromDeclaration({
        'renderer': MobileTaskView.rendererID,
        'version': 2,
        'tasks': rows,
      }),
      isNull,
    );
    expect(
      MobileTaskView.fromDeclaration({
        'renderer': MobileTaskView.rendererID,
        'version': 1,
        'tasks': rows,
        'action': {'url': 'https://example.test'},
      }),
      isNull,
    );
    expect(
      MobileTaskView.fromTodos([
        {'content': 'Unknown outcome', 'status': 'success'},
      ]),
      isNull,
    );
    expect(MobileTaskView.fromTodos(List.filled(65, rows.first)), isNull);
    expect(
      MobileTaskView.fromTodos([
        {'content': 'x' * 1025, 'status': 'completed'},
      ]),
      isNull,
    );
    expect(
      MobileTaskView.fromTodos(
        List.filled(40, {'content': 'x' * 1024, 'status': 'pending'}),
      ),
      isNull,
    );
  });

  test('priority is optional, reviewed values only, never coerced', () {
    final view = MobileTaskView.fromTodos(prioritised)!;
    expect(view.tasks[0].priority, MobileTaskPriority.low);
    expect(view.tasks[1].priority, MobileTaskPriority.high);
    expect(view.tasks[2].priority, MobileTaskPriority.medium);
    expect(view.tasks[3].priority, isNull);
    // Rows without the key still parse (older servers omit it).
    expect(
      MobileTaskView.fromTodos(rows)!.tasks.every((t) => t.priority == null),
      isTrue,
    );
    // Anything else rejects the structured view, like an unknown status.
    expect(
      MobileTaskView.fromTodos([
        {'content': 'Ship', 'status': 'pending', 'priority': 'urgent'},
      ]),
      isNull,
    );
    expect(
      MobileTaskView.fromTodos([
        {'content': 'Ship', 'status': 'pending', 'priority': 1},
      ]),
      isNull,
    );
    expect(
      MobileTaskView.fromTodos([
        {'content': 'Ship', 'status': 'pending', 'priority': 'HIGH'},
      ]),
      isNull,
    );
  });

  test('progress counts completed out of tracked, ignoring cancelled', () {
    final view = MobileTaskView.fromTodos(prioritised)!;
    expect(view.completedCount, 1);
    expect(view.trackedCount, 3);
    final allCancelled = MobileTaskView.fromTodos([
      {'content': 'A', 'status': 'cancelled'},
      {'content': 'B', 'status': 'cancelled'},
    ])!;
    expect(allCancelled.completedCount, 0);
    expect(allCancelled.trackedCount, 0);
  });

  test('toPlainText is deterministic, ordered and preserves task text', () {
    final view = MobileTaskView.fromTodos(prioritised)!;
    const expected =
        '[completed · low] Review changes\n'
        '[in_progress · high] Run focused checks\n'
        '[cancelled · medium] Publish\n'
        '[pending] Announce';
    expect(view.toPlainText(), expected);
    expect(view.toPlainText(), view.toPlainText());
    const tricky = '[Open](https://example.test) <script>no()</script>  \n x';
    final inert = MobileTaskView.fromTodos([
      {'content': tricky, 'status': 'pending', 'priority': 'high'},
    ])!;
    expect(inert.toPlainText(), '[pending · high] $tricky');
    final bounded = MobileTaskView.fromTodos(
      List.filled(30, {'content': 'x' * 1024, 'status': 'pending'}),
    )!;
    expect(bounded.toPlainText().length, lessThan(32768 + 30 * 16));
  });

  test('fallback preserves unknown status and priority as bounded text', () {
    expect(
      MobileTaskView.fallback([
        {'content': 'Unknown outcome', 'status': 'success'},
      ]),
      '[success] Unknown outcome',
    );
    expect(
      MobileTaskView.fallback([
        {'content': 'Ship', 'status': 'pending', 'priority': 'urgent'},
      ]),
      '[pending · urgent] Ship',
    );
    expect(
      MobileTaskView.fallback([
        {'content': 'Ship', 'status': 'pending', 'priority': 'p' * 41},
      ]),
      '[pending] Ship',
    );
    final fallback = MobileTaskView.fallback(
      List.filled(100, {'content': 'x' * 10000, 'status': 'pending'}),
    );
    expect(fallback.length, lessThan(26000));
  });

  testWidgets('filter changes presentation without mutating reported tasks', (
    tester,
  ) async {
    final view = MobileTaskView.fromTodos(rows)!;
    await tester.pumpWidget(host(MobileTaskList(view: view)));
    expect(find.text('Review changes'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    await tester.tap(find.byKey(const Key('mobile-tasks-filter')));
    await tester.pump();
    expect(find.text('Review changes'), findsNothing);
    expect(find.text('Publish'), findsNothing);
    expect(find.text('Run focused checks'), findsOneWidget);
    expect(view.tasks.length, 3);
    await tester.tap(find.byKey(const Key('mobile-tasks-filter')));
    await tester.pump();
    expect(find.text('Review changes'), findsOneWidget);
  });

  testWidgets('the filter is a chip that says whether it is on', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final view = MobileTaskView.fromTodos(rows)!;
    await tester.pumpWidget(host(MobileTaskList(view: view)));
    final control = find.byKey(const Key('mobile-tasks-filter'));
    expect(find.byType(KitChip), findsWidgets);
    expect(tester.widget<KitChip>(control).selected, isFalse);
    expect(
      find.bySemanticsLabel(RegExp('Show unfinished only')),
      findsOneWidget,
    );
    await tester.tap(control);
    await tester.pump();
    expect(find.text('Review changes'), findsNothing);
    expect(tester.widget<KitChip>(control).selected, isTrue);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('one readout, priority in words, High as a chip', (tester) async {
    final handle = tester.ensureSemantics();
    final view = MobileTaskView.fromTodos(prioritised)!;
    await tester.pumpWidget(host(MobileTaskList(view: view)));
    // No engine label: the old "Server-reported tasks" caption is gone.
    expect(find.text('Server-reported tasks · mobile view'), findsNothing);
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('High priority'), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text('High priority'),
        matching: find.byType(KitChip),
      ),
      findsOneWidget,
    );
    expect(find.text('Completed · Low priority'), findsOneWidget);
    expect(find.text('Cancelled · Medium priority'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.textContaining('1 of 3 done'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('mobile-tasks-progress-bar')),
    );
    expect(bar.value, closeTo(1 / 3, 0.001));
    // The filter never changes the reported progress.
    await tester.tap(find.byKey(const Key('mobile-tasks-filter')));
    await tester.pump();
    expect(find.textContaining('1 of 3 done'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('each task carries the team step mark for its state', (
    tester,
  ) async {
    final view = MobileTaskView.fromTodos(prioritised)!;
    await tester.pumpWidget(host(MobileTaskList(view: view)));
    final marks = tester
        .widgetList<KitTaskMark>(find.byType(KitTaskMark))
        .map((mark) => mark.state)
        .toList();
    expect(marks, [
      KitTaskState.done,
      KitTaskState.working,
      KitTaskState.stopped,
      KitTaskState.waiting,
    ]);
  });

  testWidgets('progress is hidden when nothing is tracked', (tester) async {
    final view = MobileTaskView.fromTodos([
      {'content': 'A', 'status': 'cancelled'},
      {'content': 'B', 'status': 'cancelled'},
    ])!;
    await tester.pumpWidget(host(MobileTaskList(view: view)));
    expect(find.byKey(const Key('mobile-tasks-progress-bar')), findsNothing);
    expect(find.text('Cancelled'), findsNWidgets(2));
    await tester.tap(find.byKey(const Key('mobile-tasks-filter')));
    await tester.pump();
    expect(find.byKey(const Key('mobile-tasks-empty')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long plan shows a window around the work and unfolds', (
    tester,
  ) async {
    final view = MobileTaskView.fromTodos([
      for (var i = 1; i <= 24; i++)
        {
          'content': 'Task $i',
          'status': i < 12
              ? 'completed'
              : i == 12
              ? 'in_progress'
              : 'pending',
        },
    ])!;
    await tester.pumpWidget(host(MobileTaskList(view: view)));
    // The window starts just before the first unfinished task.
    expect(find.text('Task 11'), findsOneWidget);
    expect(find.text('Task 12'), findsOneWidget);
    expect(find.text('Task 1'), findsNothing);
    expect(find.text('Task 24'), findsNothing);
    expect(
      find.byType(KitTaskMark),
      findsNWidgets(MobileTaskList.collapsedCount),
    );
    final showAll = find.text('Show all 24 tasks');
    await tester.ensureVisible(showAll);
    await tester.tap(showAll);
    await tester.pump();
    expect(find.byType(KitTaskMark), findsNWidgets(24));
    expect(find.text('Show all 24 tasks'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copy sends the full parsed list even while filtered', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final view = MobileTaskView.fromTodos(prioritised)!;
    await tester.pumpWidget(host(MobileTaskList(view: view)));
    await tester.tap(find.byKey(const Key('mobile-tasks-filter')));
    await tester.pump();
    expect(find.text('Review changes'), findsNothing);
    await tester.tap(find.byKey(const Key('mobile-tasks-copy-all')));
    await tester.pump();
    await tester.pump();
    expect(copied, view.toPlainText());
    expect(copied, contains('Review changes'));
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets(
    'plain text remains inert with RTL, large type and narrow width',
    (tester) async {
      await tester.pumpWidget(
        host(
          Directionality(
            textDirection: TextDirection.rtl,
            child: MobileTaskList(
              view: MobileTaskView.fromTodos([
                {
                  'content':
                      '[Open](https://example.test) <script>no()</script>',
                  'status': 'pending',
                  'priority': 'high',
                },
                {'content': 'Done', 'status': 'completed'},
              ])!,
            ),
          ),
          width: 320,
          textScale: 2,
        ),
      );
      expect(
        find.text('[Open](https://example.test) <script>no()</script>'),
        findsOneWidget,
      );
      expect(find.text('Pending'), findsOneWidget);
      expect(find.textContaining('1 of 2 done'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
