// Gallery (gate G4) for KitWorkGraph (docs/ux-system/kit-api/KitWorkGraph.md).
//
// Owner decision 2026-09-27: Arabic is dropped for this wave — no `_ar`
// shots and no RTL review. Galleries: phone 412x915 and one wide size
// (1280x800) only, light and dark (the spec's fuller size/text2.0 matrix is
// out of scope for this wave).
//
// Regenerate deliberately:
//   flutter test --update-goldens test/goldens/kit/kit_work_graph_golden_test.dart
// and look at every changed image before committing it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/ui/kit/kit_task_mark.dart';
import 'package:opencode_mobile/ui/kit/kit_work_graph.dart';

import 'kit_gallery.dart';

/// The six-item fixture (done, working, blocked, needs you, queued,
/// failed), matching `test/team_work_graph_test.dart`'s `_six`.
List<KitWorkGraphNode> _six() => const [
  KitWorkGraphNode(
    id: 'a',
    title: 'Storage layer',
    mark: KitTaskState.done,
    open: false,
  ),
  KitWorkGraphNode(
    id: 'b',
    title: 'Sync engine',
    mark: KitTaskState.waiting,
    dependsOn: ['a'],
  ),
  KitWorkGraphNode(
    id: 'c',
    title: 'Conflict policy',
    mark: KitTaskState.waiting,
    word: 'Blocked',
    dependsOn: ['b'],
    stuck: true,
  ),
  KitWorkGraphNode(
    id: 'd',
    title: 'Background sync',
    mark: KitTaskState.waiting,
    dependsOn: ['c'],
  ),
  KitWorkGraphNode(
    id: 'e',
    title: 'Unit tests',
    mark: KitTaskState.needsYou,
    dependsOn: ['a'],
  ),
  KitWorkGraphNode(id: 'f', title: 'Docs', mark: KitTaskState.failed),
];

/// A chain of three, all stuck-or-downstream (the "blocked chain" state).
List<KitWorkGraphNode> _blockedChain() => const [
  KitWorkGraphNode(
    id: 'x',
    title: 'Provision the runner',
    mark: KitTaskState.waiting,
    word: 'Blocked',
    stuck: true,
  ),
  KitWorkGraphNode(
    id: 'y',
    title: 'Run the migration',
    mark: KitTaskState.waiting,
    dependsOn: ['x'],
  ),
  KitWorkGraphNode(
    id: 'z',
    title: 'Publish the release',
    mark: KitTaskState.waiting,
    dependsOn: ['y'],
  ),
];

void main() {
  setUpAll(loadKitGalleryFonts);

  for (final light in [false, true]) {
    final mode = light ? 'light' : 'dark';

    testWidgets('rows · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_work_graph_rows',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: KitWorkGraph(
          nodes: _six(),
          onOpen: (_) {},
          layout: KitWorkGraphLayout.rows,
        ),
      );
    });

    testWidgets('rows blocked · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_work_graph_rows_blocked',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: KitWorkGraph(
          nodes: _blockedChain(),
          onOpen: (_) {},
          layout: KitWorkGraphLayout.rows,
        ),
      );
    });

    testWidgets('layers (forced) · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_work_graph_layers',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: SizedBox(
          height: 640,
          child: KitWorkGraph(
            nodes: _six(),
            onOpen: (_) {},
            layout: KitWorkGraphLayout.layers,
          ),
        ),
      );
    });

    testWidgets('empty · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_work_graph_empty',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: KitWorkGraph(
          nodes: const [],
          onOpen: (_) {},
          layout: KitWorkGraphLayout.rows,
        ),
      );
    });

    testWidgets('one · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_work_graph_one',
          const Size(412, 915),
          light: light,
        ),
        size: const Size(412, 915),
        light: light,
        child: KitWorkGraph(
          nodes: const [
            KitWorkGraphNode(
              id: 'a',
              title: 'Storage layer',
              mark: KitTaskState.working,
            ),
          ],
          onOpen: (_) {},
          layout: KitWorkGraphLayout.rows,
        ),
      );
    });

    testWidgets('auto at 1280x800 (layers) · $mode', (tester) async {
      await kitGalleryPart(
        tester,
        name: kitGalleryName(
          'kit_work_graph_auto',
          const Size(1280, 800),
          light: light,
        ),
        size: const Size(1280, 800),
        light: light,
        child: SizedBox(
          height: 640,
          child: KitWorkGraph(nodes: _six(), onOpen: (_) {}),
        ),
      );
    });
  }
}
