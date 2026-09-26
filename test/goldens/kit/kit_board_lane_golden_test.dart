// Gallery (gate G4) for KitBoardLanes / KitBoardLane,
// docs/ux-system/kit-api/KitBoardLane.md; K2 §8.2.
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_board_lane_golden_test.dart
// and look at every changed image before committing it.
//
// Owner decision 2026-09-27 (dated later than KitBoardLane.md, R15): Arabic
// is dropped — no Arabic/RTL galleries, no text-2.0 sweep; galleries are
// phone 412x915 and one wide size 1280x800 only, light and dark. This
// replaces KitBoardLane.md's own 24-shot list (a PROC-20 note in the unit's
// QA record): each declared state at 412x915, and `loaded` at 1280x800
// (four lanes side by side).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_board_lane.dart';
import 'package:opencode_mobile/ui/kit/kit_state_view.dart';
import 'package:opencode_mobile/ui/kit/kit_task_card.dart';
import 'package:opencode_mobile/ui/kit/kit_task_mark.dart';

import 'kit_gallery.dart';

const _names = ['Backlog', 'Ready', 'Working', 'Review', 'Done'];

/// Fixed card words (TEST-11: no clock in the gallery).
const _titles = [
  ['Write the release notes', 'Tidy the settings screen'],
  ['Add the Arabic plural rules'],
  [
    'Fix the sync engine retry',
    'Index the new project',
    'Rename the export button',
  ],
  <String>[],
  [
    'Ship 1.0.44',
    'Move the voice packs',
    'Trim the setup log',
    'Answer issue 87',
  ],
];

KitTaskCard _card(int lane, int i, {required int needsYou}) {
  final titles = _titles[lane];
  final title = i < titles.length ? titles[i] : 'Follow-up task ${i + 1}';
  final needs = lane == 2 && i < needsYou;
  return KitTaskCard(
    key: ValueKey('card-$lane-$i'),
    title: title,
    mark: needs
        ? KitTaskState.needsYou
        : switch (lane) {
            2 => KitTaskState.working,
            4 => KitTaskState.done,
            _ => KitTaskState.waiting,
          },
    flag: needs
        ? const KitTaskFlag(kind: KitTaskFlagKind.needsYou, label: '')
        : null,
    meta: [
      KitTaskMeta(i.isEven ? 'fox' : 'owl'),
      KitTaskMeta('${(i + 1) * 4} min ago'),
    ],
    onOpen: () {},
  );
}

Widget _board({
  required int selected,
  bool loading = false,
  int needsYou = 1,
  int working = 3,
}) {
  final counts = [2, 1, working, 0, 4];
  return KitBoardLanes(
    pagesKey: const ValueKey('team-board-pages'),
    loading: loading,
    columns: [
      for (var i = 0; i < _names.length; i++)
        KitBoardColumn(
          label: _names[i],
          count: loading ? null : counts[i],
          needsYou: i == 2 ? needsYou : 0,
        ),
    ],
    selected: selected,
    onSelected: (_) {},
    laneBuilder: (context, lane) => KitBoardLane(
      listKey: ValueKey('list-$lane'),
      cards: [
        for (var i = 0; i < counts[lane]; i++)
          _card(lane, i, needsYou: needsYou),
      ],
      empty: const KitStateView(
        size: KitStateSize.inline,
        liveRegion: false,
        icon: AppIconography.checklist,
        title: 'Nothing waiting for review',
      ),
    ),
  );
}

class _Scene {
  const _Scene(this.build, {this.then});
  final Widget Function() build;
  final Future<void> Function(WidgetTester tester)? then;
}

Future<void> _shot(
  WidgetTester tester, {
  required String name,
  required Size size,
  required bool light,
  required _Scene scene,
}) async {
  final own = light ? 'light' : 'dark';
  final stem = name.substring(0, name.length - own.length - 1);
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  final semantics = tester.ensureSemantics();
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    // G5 checks both themes (A11Y-6); the golden is the shot's own theme.
    for (final pass in [!light, light]) {
      late BuildContext context;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: pass ? AppTheme.light() : AppTheme.dark(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: Scaffold(
              body: SafeArea(
                child: Builder(
                  builder: (inner) {
                    context = inner;
                    return scene.build();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      if (scene.then != null) await scene.then!(tester);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectKitGalleryAccessible(
        tester,
        shot: '${stem}_${pass ? 'light' : 'dark'}',
        direction: Directionality.of(context),
      );
    }
  } finally {
    debugDefaultTargetPlatformOverride = null;
    semantics.dispose();
  }
  await expectLater(find.byKey(boundary), matchesGoldenFile('$name.png'));
}

final _scenes = <String, _Scene>{
  'loading': _Scene(() => _board(selected: 2, loading: true)),
  'loaded': _Scene(() => _board(selected: 2)),
  'lane_empty': _Scene(() => _board(selected: 3)),
  'needs_you': _Scene(() => _board(selected: 2, needsYou: 2)),
  'long_lane': _Scene(
    () => _board(selected: 2, working: 12),
    then: (tester) async {
      await tester.drag(
        find.byKey(const ValueKey('list-2')),
        const Offset(0, -420),
      );
      await tester.pumpAndSettle();
    },
  ),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';
    for (final entry in _scenes.entries) {
      testWidgets('kit_board_lane ${entry.key} · $mode', (tester) async {
        await _shot(
          tester,
          name: kitGalleryName(
            'kit_board_lane_${entry.key}',
            const Size(412, 915),
            light: light,
          ),
          size: const Size(412, 915),
          light: light,
          scene: entry.value,
        );
      });
    }
    testWidgets('kit_board_lane loaded · 1280x800 · $mode', (tester) async {
      const size = Size(1280, 800);
      await _shot(
        tester,
        name: kitGalleryName('kit_board_lane_loaded', size, light: light),
        size: size,
        light: light,
        scene: _Scene(() => _board(selected: 0)),
      );
    });
  }
}
