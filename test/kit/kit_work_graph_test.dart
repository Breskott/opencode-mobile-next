// KitWorkGraph (docs/ux-system/kit-api/KitWorkGraph.md): the frozen "Tests
// required" contract — determinism, the rows lane assignment, the auto
// breakpoint, open on tap (rows and layers), semantics, tones (LOOK-4: the
// blocked chain never paints the attention colour) and the reduced-motion
// sample (MOT-7).
//
// Owner decision 2026-09-27: Arabic is dropped for this wave — no RTL
// samples here (KitWorkGraph.md's "Tests required" #10 is out of scope).

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_bidi.dart';
import 'package:opencode_mobile/ui/kit/kit_task_mark.dart';
import 'package:opencode_mobile/ui/kit/kit_work_graph.dart';

/// Pumps [child] as a screen's body, with the real test window sized to
/// [size], so tap and semantics geometry line up with what a person sees.
///
/// Animations stay off by default (matching `team_work_graph_test.dart`'s
/// own `app()` helper): the fixture's `working` node's [KitStatusMark]
/// otherwise renders an indeterminate `CircularProgressIndicator`, whose
/// ticker never settles, and every `pumpAndSettle` below would time out.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(412, 915),
  double textScale = 1,
  bool disableAnimations = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: widget!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

/// a ← b ← c(stuck) ← d, a ← e, f alone; e needs the person.
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
    mark: KitTaskState.working,
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
  KitWorkGraphNode(id: 'f', title: 'Docs', mark: KitTaskState.waiting),
];

/// KitZoom's own GestureDetector carries `onDoubleTap` alongside `onTap`
/// (KitImage.md): the gesture arena holds a tap open for
/// `kDoubleTapTimeout` before resolving it as a single tap, even for a
/// descendant's own recognizer.
Future<void> _tapThroughZoom(WidgetTester tester, Offset point) async {
  await tester.tapAt(point);
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 1));
}

void main() {
  group('KitWorkGraphGeometry', () {
    test('layers is deterministic and matches the retired layout', () {
      const nodeSize = Size(156, 44);
      final first = KitWorkGraphGeometry.layers(_six(), nodeSize: nodeSize);
      final second = KitWorkGraphGeometry.layers(_six(), nodeSize: nodeSize);
      expect(first.rects, second.rects);
      expect(first.layerRows, second.layerRows);
      expect(first.criticalPath, second.criticalPath);
      expect(first.blockedChain, second.blockedChain);
      expect(first.layerRows, [
        ['a', 'f'],
        ['b', 'e'],
        ['c'],
        ['d'],
      ]);
      expect(first.rects['a'], const Rect.fromLTWH(16, 16, 156, 44));
      expect(first.rects['c'], const Rect.fromLTWH(106, 200, 156, 44));
      expect(first.size, const Size(368, 352));
      expect(first.criticalPath, ['a', 'b', 'c', 'd']);
      // c is stuck; b is the open item it directly waits on; d is
      // downstream of c. a is done (not open), so it never joins the
      // chain even though it feeds b.
      expect(first.blockedChain, {'b', 'c', 'd'});
    });

    test(
      'rows: one id per row in the layers order, every edge under the lane cap',
      () {
        final rows = KitWorkGraphGeometry.rows(
          _six(),
          width: 360,
          rowHeight: (_) => 60,
        );
        final order = [for (final row in rows.layerRows) ...row];
        expect(order, ['a', 'f', 'b', 'e', 'c', 'd']);
        // One row per node, stacked top to bottom in that order.
        for (final (i, id) in order.indexed) {
          expect(rows.rects[id]!.top, i * 60);
        }
        for (final edge in rows.edges) {
          expect(edge.lane, greaterThanOrEqualTo(0));
          expect(edge.lane, lessThan(6));
        }
        // No two edges whose row span overlaps share a lane while a free
        // lane exists: with 4 links and a lane cap of 6, none need share.
        final byLane = <int, List<(int, int)>>{};
        for (final edge in rows.edges) {
          final from = order.indexOf(edge.from);
          final to = order.indexOf(edge.to);
          byLane.putIfAbsent(edge.lane, () => []).add((
            from < to ? from : to,
            from < to ? to : from,
          ));
        }
        for (final spans in byLane.values) {
          for (var i = 0; i < spans.length; i++) {
            for (var j = i + 1; j < spans.length; j++) {
              final overlaps =
                  spans[i].$1 < spans[j].$2 && spans[j].$1 < spans[i].$2;
              expect(overlaps, isFalse, reason: '$spans');
            }
          }
        }
      },
    );

    test('one item has no gutter; empty has no rows', () {
      final one = KitWorkGraphGeometry.rows(
        const [KitWorkGraphNode(id: 'a', title: 'a', mark: KitTaskState.done)],
        width: 300,
        rowHeight: (_) => 54,
      );
      expect(one.gutter, 0);
      final empty = KitWorkGraphGeometry.layers(
        const [],
        nodeSize: const Size(156, 44),
      );
      expect(empty.nodes, isEmpty);
      expect(empty.criticalPath, isEmpty);
    });
  });

  group('KitWorkGraph auto', () {
    testWidgets('412x915 renders rows (no viewer key)', (tester) async {
      await _pump(
        tester,
        KitWorkGraph(nodes: _six(), onOpen: (_) {}),
        size: const Size(412, 915),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kit-work-graph-viewer')), findsNothing);
    });

    testWidgets('1280x800 renders layers with the viewer and Fit', (
      tester,
    ) async {
      await _pump(
        tester,
        KitWorkGraph(nodes: _six(), onOpen: (_) {}),
        size: const Size(1280, 800),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('kit-work-graph-viewer')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('kit-work-graph-fit')), findsOneWidget);
    });

    testWidgets('915x412 (short) renders rows', (tester) async {
      await _pump(
        tester,
        KitWorkGraph(nodes: _six(), onOpen: (_) {}),
        size: const Size(915, 412),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kit-work-graph-viewer')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('KitWorkGraph open', () {
    testWidgets('rows: tapping a node calls onOpen with its id once', (
      tester,
    ) async {
      final opened = <String>[];
      await _pump(
        tester,
        KitWorkGraph(
          nodes: _six(),
          onOpen: opened.add,
          layout: KitWorkGraphLayout.rows,
        ),
      );
      await tester.pumpAndSettle();
      // The title renders through KitBidi.auto (COPY-30), so it alone
      // carries the invisible directional isolate that tells it apart
      // from d's supporting line, "Waiting · needs Conflict policy".
      await tester.tap(find.text(KitBidi.auto('Conflict policy')));
      await tester.pumpAndSettle();
      expect(opened, ['c']);
    });

    testWidgets('layers: tapping a node calls onOpen with its id once', (
      tester,
    ) async {
      final opened = <String>[];
      await _pump(
        tester,
        KitWorkGraph(
          nodes: _six(),
          onOpen: opened.add,
          layout: KitWorkGraphLayout.layers,
        ),
        size: const Size(1280, 800),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find.byKey(const ValueKey('kit-work-graph-canvas')),
      );
      final geometry = KitWorkGraphGeometry.layers(
        _six(),
        nodeSize: const Size(156, 48),
      );
      await _tapThroughZoom(tester, rect.topLeft + geometry.rects['c']!.center);
      await tester.pumpAndSettle();
      expect(opened, ['c']);
    });

    testWidgets('empty shows the inline empty state, never onOpen', (
      tester,
    ) async {
      var opened = false;
      await _pump(
        tester,
        KitWorkGraph(nodes: const [], onOpen: (_) => opened = true),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No work items yet'), findsOneWidget);
      expect(opened, isFalse);
    });
  });

  group('KitWorkGraph semantics', () {
    testWidgets('each node is a button labelled "{title}, {state}"', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        KitWorkGraph(
          nodes: _six(),
          onOpen: (_) {},
          layout: KitWorkGraphLayout.rows,
        ),
      );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(
        find.bySemanticsLabel('Conflict policy, Blocked'),
      );
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(node.getSemanticsData().hint, 'needs Sync engine');
      handle.dispose();
    });
  });

  group('KitWorkGraph tones', () {
    testWidgets('the blocked chain paints no attention colour', (tester) async {
      await _pump(
        tester,
        KitWorkGraph(
          nodes: _six(),
          onOpen: (_) {},
          layout: KitWorkGraphLayout.rows,
        ),
      );
      await tester.pumpAndSettle();
      final theme = Theme.of(tester.element(find.byType(KitWorkGraph)));
      final attention = AppTheme.rolesOf(theme).attention;
      // The stuck node's mark is `waiting` (LOOK-4), not `needsYou`: no
      // Icon anywhere paints the attention colour except the needs-you
      // node's own mark.
      final icons = tester.widgetList<Icon>(find.byType(Icon));
      final attentionIcons = icons.where((i) => i.color == attention);
      expect(attentionIcons.length, 1);
    });
  });
}
