// KitTaskChip and the Tasks sheet: the agent's task list as a chip in the
// line above the field (owner decision 14 Oct 2026).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit.dart';

import 'kit_motion_still.dart';

final _chip = find.byKey(const Key('task-chip'));

/// A chip whose tasks the test moves with [counts].
Future<ValueNotifier<(int, int)>> _pump(
  WidgetTester tester, {
  required int done,
  required int total,
  double textScale = 1,
  Locale locale = const Locale('en'),
  bool reduced = false,
  bool withStrip = false,
  bool withChip = true,
}) async {
  final counts = ValueNotifier((done, total));
  addTearDown(counts.dispose);
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduced,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ValueListenableBuilder<(int, int)>(
            valueListenable: counts,
            builder: (context, value, _) {
              final chip = KitTaskChip(
                done: value.$1,
                total: value.$2,
                current: 'Run the tests',
                onPressed: () {},
              );
              if (!withStrip) return chip;
              return KitComposerStatusStrip(
                stripKey: const Key('strip'),
                chips: [
                  const KitChip.action(
                    label: 'Auto-approve',
                    onPressed: _noop,
                    icon: Icons.shield,
                  ),
                  if (withChip) chip,
                ],
                model: const KitChip(label: 'gemini-4-argon'),
              );
            },
          ),
        ),
      ),
    ),
  );
  return counts;
}

void _noop() {}

const _items = [
  KitTaskItem('Find raw colours', KitTaskItemState.done),
  KitTaskItem('Run the tests', KitTaskItemState.inProgress),
  KitTaskItem('Ship it', KitTaskItemState.todo),
];

Widget _stillChip(int done, int total) =>
    KitTaskChip(done: done, total: total, onPressed: _noop);

Future<void> _openTasks(BuildContext context) =>
    showKitTaskSheet(context, items: _items, done: 1, total: 3, running: false);

void main() {
  // G8x (MOT-7): the chip folds in and out and pops on a change; under a
  // wish for stillness the text still changes, with nothing running.
  kitMotionStillTests(
    'KitTaskChip',
    builds: {'resting': () => _stillChip(2, 6)},
    changes: {
      'a task is done': KitMotionChange(
        build: () => _stillChip(2, 6),
        act: (tester, stage) => stage.rebuild(_stillChip(3, 6)),
        shows: '✓ 3/6',
      ),
      'a task is added': KitMotionChange(
        build: () => _stillChip(2, 6),
        act: (tester, stage) => stage.rebuild(_stillChip(2, 7)),
        shows: '+ 2/7',
      ),
    },
  );
  kitMotionStillTests(
    'showKitTaskSheet',
    opens: {'by state': const KitMotionOpen(_openTasks, shows: 'Tasks')},
    changes: {'dismissed': kitModalDismiss(_openTasks, shows: 'Tasks')},
  );

  testWidgets('the Tasks sheet takes its own key', (tester) async {
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold();
          },
        ),
      ),
    );
    unawaited(
      showKitTaskSheet(
        host,
        items: _items,
        done: 1,
        total: 3,
        running: false,
        sheetKey: const Key('my-tasks'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-tasks')), findsOneWidget);
    expect(find.byKey(const Key('task-sheet')), findsNothing);
  });

  testWidgets('it rests as a ring and "5/6", never a task title', (
    tester,
  ) async {
    await _pump(tester, done: 5, total: 6);
    expect(find.text('5/6'), findsOneWidget);
    expect(find.text('Run the tests'), findsNothing);
    expect(_chip, findsOneWidget);
  });

  testWidgets('a finished list shows nothing when it first appears', (
    tester,
  ) async {
    await _pump(tester, done: 6, total: 6);
    expect(_chip, findsNothing);
    expect(find.text('6/6'), findsNothing);
  });

  testWidgets('no tasks, no chip', (tester) async {
    await _pump(tester, done: 0, total: 0);
    expect(_chip, findsNothing);
  });

  testWidgets('a completed task pops the chip, then it settles back', (
    tester,
  ) async {
    final counts = await _pump(tester, done: 4, total: 6);
    expect(find.text('4/6'), findsOneWidget);

    counts.value = (5, 6);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('✓ 5/6'), findsOneWidget);
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, greaterThan(1));

    await tester.pump(KitTaskChip.defaultPopFor);
    await tester.pumpAndSettle();
    expect(find.text('✓ 5/6'), findsNothing);
    expect(find.text('5/6'), findsOneWidget);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('a task added to the list pops with "+"', (tester) async {
    final counts = await _pump(tester, done: 5, total: 6);
    counts.value = (5, 7);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('+ 5/7'), findsOneWidget);
    await tester.pump(KitTaskChip.defaultPopFor);
    await tester.pumpAndSettle();
    expect(find.text('5/7'), findsOneWidget);
  });

  testWidgets('everything done shows ✓ 6/6 for a moment, then it is gone', (
    tester,
  ) async {
    final counts = await _pump(tester, done: 5, total: 6);
    counts.value = (6, 6);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('✓ 6/6'), findsOneWidget);

    // Still there after the pop would have ended: it waits out its 3 s.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('✓ 6/6'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(_chip, findsNothing);

    // A new list with work to do brings it back.
    counts.value = (0, 3);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('0/3'), findsOneWidget);
  });

  testWidgets('it adds no row and no height to the line above the field', (
    tester,
  ) async {
    await _pump(tester, done: 5, total: 6, withStrip: true, withChip: false);
    final without = tester.getSize(find.byKey(const Key('strip')));

    await _pump(tester, done: 5, total: 6, withStrip: true);
    expect(_chip, findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('strip'))), without);
    // The model chip is still on the line, in view.
    expect(find.text('gemini-4-argon'), findsOneWidget);
  });

  for (final (scale, locale) in [
    (2.0, const Locale('en')),
    (1.0, const Locale('ar')),
  ]) {
    testWidgets('it fits beside the model chip at text $scale in $locale', (
      tester,
    ) async {
      await _pump(
        tester,
        done: 12,
        total: 40,
        textScale: scale,
        locale: locale,
        withStrip: true,
      );
      expect(tester.takeException(), isNull);
      expect(_chip, findsOneWidget);
    });
  }

  testWidgets('reduced motion: no scale and no tint, the text still changes', (
    tester,
  ) async {
    final counts = await _pump(tester, done: 4, total: 6, reduced: true);
    counts.value = (5, 6);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('✓ 5/6'), findsOneWidget);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await tester.pump(KitTaskChip.defaultPopFor);
    await tester.pumpAndSettle();
    expect(find.text('5/6'), findsOneWidget);
  });

  testWidgets('it reads as one polite, named button', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, done: 5, total: 6);
    final named = find.bySemanticsLabel(
      'Tasks, 5 of 6 done, now Run the tests',
    );
    expect(named, findsOneWidget);
    expect(
      tester.getSemantics(named),
      isSemantics(isButton: true, isLiveRegion: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('the Tasks sheet lists every task by state', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold();
          },
        ),
      ),
    );
    unawaited(
      showKitTaskSheet(
        host,
        done: 1,
        total: 3,
        items: const [
          KitTaskItem('Find raw colours', KitTaskItemState.done),
          KitTaskItem('Run the tests', KitTaskItemState.inProgress),
          KitTaskItem('Ship it', KitTaskItemState.todo),
        ],
      ),
    );
    // The task in progress has a spinner: it never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('1 of 3 done'), findsOneWidget);
    for (final task in ['Find raw colours', 'Run the tests', 'Ship it']) {
      expect(find.text(task), findsOneWidget);
    }
    expect(find.bySemanticsLabel(RegExp('Completed')), findsWidgets);
  });

  testWidgets('an idle agent shows no spinner: the sheet settles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext host;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            host = context;
            return const Scaffold();
          },
        ),
      ),
    );
    unawaited(
      showKitTaskSheet(
        host,
        done: 1,
        total: 2,
        running: false,
        items: const [
          KitTaskItem('Find raw colours', KitTaskItemState.done),
          KitTaskItem('Run the tests', KitTaskItemState.inProgress),
        ],
      ),
    );
    // Nothing keeps a frame scheduled once the sheet is open.
    await tester.pumpAndSettle();
    expect(find.text('Run the tests'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the chip itself never animates once its ring is set', (
    tester,
  ) async {
    await _pump(tester, done: 5, total: 6);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}
