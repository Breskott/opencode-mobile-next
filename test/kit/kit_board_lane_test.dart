// Behaviour tests for KitBoardLanes / KitBoardLane
// (docs/ux-system/kit-api/KitBoardLane.md, "Tests required"). Arabic
// review is dropped by the owner's decision of 2026-09-27; the RTL checks
// stay because they are cheap and use Directionality only.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_board_lane.dart';
import 'package:opencode_mobile/ui/kit/kit_progress.dart';
import 'package:opencode_mobile/ui/kit/kit_state_view.dart';
import 'package:opencode_mobile/ui/kit/kit_task_card.dart';
import 'package:opencode_mobile/ui/kit/kit_task_mark.dart';
import 'package:opencode_mobile/ui/kit/motion/kit_tab_switcher.dart';

import 'kit_motion_still.dart';

const _names = ['Backlog', 'Ready', 'Working', 'Review', 'Done'];
const _counts = [2, 1, 3, 0, 4];

Key _laneKey(int i) => ValueKey('lane-$i');
Key _cardKey(int lane, int i) => ValueKey('card-$lane-$i');
const _pagesKey = ValueKey('team-board-pages');

KitTaskCard _card(int lane, int i) => KitTaskCard(
  key: _cardKey(lane, i),
  title: '${_names[lane]} task ${i + 1}',
  mark: switch (lane) {
    2 when i == 0 => KitTaskState.needsYou,
    2 => KitTaskState.working,
    4 => KitTaskState.done,
    _ => KitTaskState.waiting,
  },
  flag: lane == 2 && i == 0
      ? const KitTaskFlag(kind: KitTaskFlagKind.needsYou, label: '')
      : null,
  meta: const [KitTaskMeta('fox')],
  onOpen: () {},
);

/// A host that keeps `selected` and records every [onSelected].
class _Board extends StatefulWidget {
  const _Board({
    required this.calls,
    this.initial = 2,
    this.loading = false,
    this.counts = _counts,
    this.laneCounts = _counts,
    this.onRefresh,
  });

  final List<int> calls;
  final int initial;
  final bool loading;
  final List<int?> counts;
  final List<int> laneCounts;
  final Future<void> Function()? onRefresh;

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  late int _selected = widget.initial;

  @override
  Widget build(BuildContext context) => KitBoardLanes(
    pagesKey: _pagesKey,
    loading: widget.loading,
    columns: [
      for (var i = 0; i < _names.length; i++)
        KitBoardColumn(
          label: _names[i],
          count: widget.counts[i],
          needsYou: i == 2 ? 1 : 0,
          tabKey: ValueKey('tab-$i'),
        ),
    ],
    selected: _selected,
    onSelected: (index) {
      widget.calls.add(index);
      setState(() => _selected = index);
    },
    laneBuilder: (context, lane) => KitBoardLane(
      laneKey: _laneKey(lane),
      listKey: ValueKey('list-$lane'),
      onRefresh: widget.onRefresh,
      cards: [for (var i = 0; i < widget.laneCounts[lane]; i++) _card(lane, i)],
      empty: const KitStateView(
        size: KitStateSize.inline,
        liveRegion: false,
        icon: AppIconography.checklist,
        title: 'Nothing here',
      ),
    ),
  );
}

Future<List<int>> _pump(
  WidgetTester tester, {
  Size size = const Size(412, 915),
  int initial = 2,
  bool loading = false,
  List<int?> counts = _counts,
  List<int> laneCounts = _counts,
  Future<void> Function()? onRefresh,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  bool reduced = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final calls = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduced,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: Scaffold(
        body: _Board(
          calls: calls,
          initial: initial,
          loading: loading,
          counts: counts,
          laneCounts: laneCounts,
          onRefresh: onRefresh,
        ),
      ),
    ),
  );
  await tester.pump();
  return calls;
}

Rect _lane(WidgetTester tester, int i) =>
    tester.getRect(find.byKey(_laneKey(i)));

bool _focusInside(Key key) {
  BuildContext? context = FocusManager.instance.primaryFocus?.context;
  var found = false;
  context?.visitAncestorElements((element) {
    if (element.widget.key == key) found = true;
    return !found;
  });
  return found;
}

void main() {
  kitMotionStillTests(
    'KitBoardLane',
    builds: {
      'loaded': () => KitBoardLane(cards: [_card(2, 0)]),
      'loading': () => const KitBoardLane.loading(),
    },
    changes: {
      'card arrives': KitMotionChange(
        build: () => const KitBoardLane(cards: [], empty: Text('No tasks yet')),
        act: (tester, stage) =>
            stage.rebuild(KitBoardLane(cards: [_card(0, 0)])),
        shows: 'Backlog task 1',
      ),
    },
  );
  kitMotionStillTests(
    'KitBoardLanes',
    builds: {
      'loaded': () => _Board(calls: []),
      'loading': () => _Board(calls: [], loading: true),
    },
    changes: {
      'strip selects another lane': KitMotionChange(
        build: () => _Board(calls: []),
        act: (tester, stage) async {
          tester.widget<KitTabStrip>(find.byType(KitTabStrip)).onSelected(0);
        },
        shows: 'Backlog task 1',
      ),
    },
  );

  testWidgets('1 opens on selected; the strip shows that tab selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    final lane = _lane(tester, 2);
    expect(lane.left, moreOrLessEquals(22));
    expect(lane.right, moreOrLessEquals(390));
    expect(find.text('Working task 1'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('tab-2'))),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('tab-1'))),
      isNot(isSemantics(isSelected: true)),
    );
    handle.dispose();
  });

  testWidgets('2 a swipe calls onSelected(selected + 1) once on settle', (
    tester,
  ) async {
    final calls = await _pump(tester);
    await tester.drag(find.byKey(_laneKey(2)), const Offset(-240, 0));
    await tester.pumpAndSettle();
    expect(calls, [3]);
    expect(_lane(tester, 3).left, moreOrLessEquals(22));
    expect(
      tester.getSemantics(find.byKey(const ValueKey('tab-3'))),
      isSemantics(isSelected: true),
    );
  });

  testWidgets('3 a strip tap animates to the lane; reduced motion jumps', (
    tester,
  ) async {
    var calls = await _pump(tester, reduced: false);
    await tester.tap(find.byKey(const ValueKey('tab-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // Moving, not there yet.
    expect(_lane(tester, 0).left, lessThan(22));
    await tester.pumpAndSettle();
    expect(calls, [0]);
    expect(_lane(tester, 0).left, moreOrLessEquals(22));

    calls = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await tester.pump();
    expect(calls, [1]);
    expect(_lane(tester, 1).left, moreOrLessEquals(22));
  });

  testWidgets(
    '4 lane width: 372 slot with 20 dp peeks, 400 cap, side by side',
    (tester) async {
      await _pump(tester);
      // The page slot is 372 (412 − 2 × 20); the lane surface keeps space1
      // (4) between neighbours, 2 on each side.
      expect(_lane(tester, 2).width, moreOrLessEquals(368));
      expect(_lane(tester, 1).right, moreOrLessEquals(18));
      expect(_lane(tester, 3).left, moreOrLessEquals(394));
      expect(find.byKey(_pagesKey), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);

      await _pump(tester, size: const Size(700, 1000));
      expect(_lane(tester, 2).width, moreOrLessEquals(396));
      expect(find.byType(PageView), findsOneWidget);

      await _pump(tester, size: const Size(1024, 768), initial: 0);
      expect(find.byType(PageView), findsNothing);
      for (var i = 0; i < 3; i++) {
        final rect = _lane(tester, i);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(1024));
        expect(rect.width, greaterThanOrEqualTo(296));
      }
      expect(_lane(tester, 3).left, greaterThan(1024 - 16));

      await _pump(tester, size: const Size(1600, 1000), initial: 0);
      for (var i = 0; i < 5; i++) {
        final rect = _lane(tester, i);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(1600));
      }
    },
  );

  testWidgets('5 loading: labels, no counts, 4 skeleton cards, no swipe', (
    tester,
  ) async {
    final calls = await _pump(
      tester,
      loading: true,
      counts: const [null, null, null, null, null],
    );
    for (final name in _names) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.textContaining(RegExp(r'\d')), findsNothing);
    expect(find.byType(KitSkeletonRows), findsNWidgets(4));
    expect(find.byType(PageView), findsNothing);
    await tester.drag(find.byType(KitBoardLane), const Offset(-240, 0));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
  });

  testWidgets('6 an empty lane says so; no cards and no empty asserts', (
    tester,
  ) async {
    await _pump(tester, initial: 3);
    expect(
      find.descendant(
        of: find.byKey(_laneKey(3)),
        matching: find.text('Nothing here'),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: KitBoardLane(cards: [])),
      ),
    );
    expect(tester.takeException(), isA<AssertionError>());
  });

  testWidgets('7 a count that differs from the lane asserts', (tester) async {
    await _pump(tester, laneCounts: const [2, 1, 2, 0, 4]);
    expect(tester.takeException(), isA<AssertionError>());
  });

  testWidgets('8 stale is not dimming: card text is never faded', (
    tester,
  ) async {
    await _pump(tester);
    final lanes = find.byType(KitBoardLane);
    expect(
      find.descendant(of: lanes, matching: find.byType(Opacity)),
      findsNothing,
    );
    final paragraphs = tester.renderObjectList<RenderParagraph>(
      find.descendant(of: lanes, matching: find.byType(RichText)),
    );
    expect(paragraphs, isNotEmpty);
    for (final paragraph in paragraphs) {
      paragraph.text.visitChildren((span) {
        final color = span.style?.color;
        if (color != null) expect(color.a, 1.0, reason: '$span');
        return true;
      });
    }
  });

  testWidgets('9 keyboard: Tab from the strip into the lane; Ctrl+→ pages', (
    tester,
  ) async {
    final calls = await _pump(tester);
    Focus.of(
      tester.element(
        find.descendant(
          of: find.byKey(const ValueKey('tab-2')),
          matching: find.text('Working'),
        ),
      ),
    ).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_focusInside(_cardKey(2, 0)), isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(calls, [3]);
    expect(_focusInside(_cardKey(3, 0)), isFalse); // Review is empty.
    expect(_lane(tester, 3).left, moreOrLessEquals(22));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(calls, [3, 4]);
    expect(_focusInside(_cardKey(4, 0)), isTrue);
    expect(_lane(tester, 4).left, moreOrLessEquals(22));
  });

  testWidgets('10 each lane is a labelled container; pages scroll', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel('Working, 3 tasks'), findsOneWidget);
    expect(find.bySemanticsLabel('Review, no tasks'), findsOneWidget);
    // The pages (below the strip, the full lane height) page both ways.
    final pages = find.semantics.byPredicate((node) {
      final data = node.getSemanticsData();
      return data.hasAction(SemanticsAction.scrollLeft) &&
          data.hasAction(SemanticsAction.scrollRight) &&
          node.rect.height > 400;
    });
    expect(pages, findsOne);
    handle.dispose();
  });

  testWidgets('11 RTL: the first column at the right edge; Ctrl+← forward', (
    tester,
  ) async {
    final calls = await _pump(tester, initial: 0, direction: TextDirection.rtl);
    expect(_lane(tester, 0).right, moreOrLessEquals(390));
    expect(_lane(tester, 1).right, moreOrLessEquals(18));
    await tester.drag(find.byKey(_laneKey(0)), const Offset(240, 0));
    await tester.pumpAndSettle();
    expect(calls, [1]);
    Focus.of(tester.element(find.text('Ready task 1'))).requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(calls, [1, 2]);
    expect(_focusInside(_cardKey(2, 0)), isTrue);
  });

  testWidgets('12 pull on the visible lane refreshes once', (tester) async {
    var refreshes = 0;
    await _pump(tester, onRefresh: () async => refreshes++);
    await tester.fling(
      find.byKey(const ValueKey('list-2')),
      const Offset(0, 400),
      1200,
    );
    await tester.pumpAndSettle();
    expect(refreshes, 1);
  });

  testWidgets('13 no overflow at every size, scale and direction', (
    tester,
  ) async {
    const sizes = [
      Size(320, 800),
      Size(412, 915),
      Size(600, 960),
      Size(840, 1000),
      Size(1280, 800),
      Size(1600, 1000),
      Size(915, 412),
    ];
    for (final size in sizes) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final direction in TextDirection.values) {
          await _pump(
            tester,
            size: size,
            textScale: scale,
            direction: direction,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$size × $scale $direction',
          );
        }
      }
    }
  });

  testWidgets('13b reduced motion settles after one pump', (tester) async {
    await _pump(tester);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
