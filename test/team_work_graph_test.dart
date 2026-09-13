// TEAM-110: the Work graph. The layout is deterministic on a fixed
// six-node graph (exact rows, positions and edge geometry, asserted twice),
// the critical path is the longest chain of needs links, the blocked chain
// is the stuck item with what it waits on and what waits on it, cycles and
// unknown ids do not break it, chips grow with the text, and tapping a
// node (or its semantics button) reports the id.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/orchestration/models/work.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/screens/team/work_graph.dart';

/// a ← b ← c(blocked) ← d, a ← e, f alone.
const _six = [
  WorkGraphNode(id: 'a', title: 'Storage layer', state: WorkState.completed),
  WorkGraphNode(
    id: 'b',
    title: 'Sync engine',
    state: WorkState.working,
    dependsOn: ['a'],
  ),
  WorkGraphNode(
    id: 'c',
    title: 'Conflict policy',
    state: WorkState.blocked,
    dependsOn: ['b'],
  ),
  WorkGraphNode(
    id: 'd',
    title: 'Background sync',
    state: WorkState.queued,
    dependsOn: ['c'],
  ),
  WorkGraphNode(
    id: 'e',
    title: 'Unit tests',
    state: WorkState.ready,
    dependsOn: ['a'],
  ),
  WorkGraphNode(id: 'f', title: 'Docs', state: WorkState.queued),
];

void main() {
  group('WorkGraphLayout', () {
    test('lays the six-node graph out the same way twice', () {
      final first = WorkGraphLayout.compute(_six);
      final second = WorkGraphLayout.compute(_six);
      const w = 156.0, h = 44.0;
      final expected = {
        'a': const Rect.fromLTWH(16, 16, w, h),
        'f': const Rect.fromLTWH(196, 16, w, h),
        'b': const Rect.fromLTWH(16, 108, w, h),
        'e': const Rect.fromLTWH(196, 108, w, h),
        'c': const Rect.fromLTWH(106, 200, w, h),
        'd': const Rect.fromLTWH(106, 292, w, h),
      };
      for (final layout in [first, second]) {
        expect(layout.layers, [
          ['a', 'f'],
          ['b', 'e'],
          ['c'],
          ['d'],
        ]);
        expect(layout.rects, expected);
        expect(layout.size, const Size(368, 352));
        expect(
          [for (final n in layout.nodes) n.id],
          ['a', 'b', 'c', 'd', 'e', 'f'],
        );
        // Every chip clears the 44dp target (02-ux §11).
        for (final rect in layout.rects.values) {
          expect(rect.height, greaterThanOrEqualTo(44));
        }
      }
      expect(first.edges.map((e) => (e.from, e.to)), [
        ('a', 'b'),
        ('b', 'c'),
        ('c', 'd'),
        ('a', 'e'),
      ]);
      final ab = first.edges.first;
      expect(ab.start, const Offset(94, 60));
      expect(ab.control1, const Offset(94, 84));
      expect(ab.control2, const Offset(94, 84));
      expect(ab.end, const Offset(94, 108));
      final ae = first.edges.last;
      expect(ae.start, const Offset(94, 60));
      expect(ae.end, const Offset(274, 108));
    });

    test('names the critical path and draws its edges thicker', () {
      final layout = WorkGraphLayout.compute(_six);
      expect(layout.criticalPath, ['a', 'b', 'c', 'd']);
      expect(layout.criticalEdges, {('a', 'b'), ('b', 'c'), ('c', 'd')});
      expect({
        for (final e in layout.edges)
          if (e.critical) (e.from, e.to),
      }, layout.criticalEdges);
      expect(
        layout.edges.where((e) => e.from == 'a' && e.to == 'e').single.critical,
        isFalse,
      );
    });

    test('the blocked chain is the stuck item, its open need, its waiters', () {
      final layout = WorkGraphLayout.compute(_six);
      expect(layout.blockedChain, {'b', 'c', 'd'});
      expect(
        {
          for (final e in layout.edges)
            if (e.blocked) (e.from, e.to),
        },
        {('b', 'c'), ('c', 'd')},
      );
      // A completed need is not part of the chain; a stuck item with no
      // links stands alone in it.
      final alone = WorkGraphLayout.compute(const [
        WorkGraphNode(id: 'x', title: 'x', state: WorkState.completed),
        WorkGraphNode(
          id: 'y',
          title: 'y',
          state: WorkState.needsInput,
          dependsOn: ['x'],
        ),
      ]);
      expect(alone.blockedChain, {'y'});
      expect(alone.edges.single.blocked, isFalse);
    });

    test('unknown ids, self links, duplicates and cycles do not break it', () {
      final layout = WorkGraphLayout.compute(const [
        WorkGraphNode(
          id: 'a',
          title: 'a',
          state: WorkState.queued,
          dependsOn: ['b', 'ghost', 'a'],
        ),
        WorkGraphNode(
          id: 'b',
          title: 'b',
          state: WorkState.queued,
          dependsOn: ['a'],
        ),
        WorkGraphNode(id: 'a', title: 'again', state: WorkState.failed),
      ]);
      expect(layout.nodes.length, 2);
      expect(layout.nodes.first.title, 'a');
      // One edge of the cycle is dropped; both nodes keep a place.
      expect(layout.edges.length, 1);
      expect(layout.layers.expand((r) => r).toSet(), {'a', 'b'});
      expect(layout.criticalPath.length, 2);
      final empty = WorkGraphLayout.compute(const []);
      expect(empty.nodes, isEmpty);
      expect(empty.criticalPath, isEmpty);
      expect(empty.size, const Size(32, 32));
    });

    test('a larger chip size moves every rect and grows the canvas', () {
      final layout = WorkGraphLayout.compute(
        _six,
        nodeSize: const Size(200, 60),
      );
      expect(layout.rects['a'], const Rect.fromLTWH(16, 16, 200, 60));
      expect(layout.rects['f'], const Rect.fromLTWH(240, 16, 200, 60));
      expect(layout.rects['c'], const Rect.fromLTWH(128, 232, 200, 60));
      expect(layout.size, const Size(456, 416));
    });
  });

  group('WorkGraph', () {
    Widget app(Widget child, {double textScale = 1}) => MaterialApp(
      theme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: widget!,
      ),
      home: Scaffold(body: child),
    );

    testWidgets('fits on first layout, taps a node, Fit restores', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transform = TransformationController();
      addTearDown(transform.dispose);
      final tapped = <String>[];
      await tester.pumpWidget(
        app(
          WorkGraph(
            nodes: _six,
            onNodeTap: tapped.add,
            transformationController: transform,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('team-work-graph-canvas')),
        findsOneWidget,
      );
      // The graph is smaller than the viewport: shown at 1x, centred.
      final fitted = transform.value.clone();
      expect(fitted.storage[0], closeTo(1, 1e-9));
      expect(fitted.getTranslation().x, closeTo((800 - 368) / 2, 1e-9));
      expect(fitted.getTranslation().y, closeTo((600 - 352) / 2, 1e-9));

      final layout = WorkGraphLayout.compute(_six);
      final origin = tester.getTopLeft(find.byType(WorkGraph));
      Offset onScreen(String id) =>
          origin +
          MatrixUtils.transformPoint(transform.value, layout.rects[id]!.center);
      await tester.tapAt(onScreen('c'));
      await tester.pumpAndSettle();
      expect(tapped, ['c']);
      // Between the chips nothing fires.
      await tester.tapAt(
        origin +
            MatrixUtils.transformPoint(transform.value, const Offset(184, 38)),
      );
      await tester.pumpAndSettle();
      expect(tapped, ['c']);

      // Zoom in by hand, then Fit brings the fitted transform back.
      transform.value = Matrix4.identity()..scaleByDouble(2, 2, 1, 1);
      await tester.pump();
      final fit = find.byKey(const ValueKey('team-work-graph-fit'));
      expect(fit.hitTestable(), findsOneWidget);
      expect(tester.getSize(fit).height, greaterThanOrEqualTo(40));
      await tester.tap(fit);
      await tester.pumpAndSettle();
      expect(transform.value, fitted);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a large graph is scaled down to fit; never below 0.2', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transform = TransformationController();
      addTearDown(transform.dispose);
      await tester.pumpWidget(
        app(
          WorkGraph(
            nodes: _six,
            onNodeTap: (_) {},
            transformationController: transform,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scale = transform.value.storage[0];
      expect(scale, closeTo((320 - 24) / 368, 1e-9));
      expect(transform.value.getTranslation().x, closeTo(12, 1e-9));
      expect(scale, greaterThanOrEqualTo(.2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('every chip is a labelled button in the semantics tree', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final tapped = <String>[];
      await tester.pumpWidget(
        app(WorkGraph(nodes: _six, onNodeTap: tapped.add)),
      );
      await tester.pumpAndSettle();
      final canvas = tester.getSemantics(
        find.byKey(const ValueKey('team-work-graph-canvas')),
      );
      SemanticsNode? found;
      final labels = <String>[];
      bool visit(SemanticsNode node) {
        final data = node.getSemanticsData();
        if (data.label.isNotEmpty) labels.add(data.label);
        if (data.label == 'Conflict policy, Blocked') found = node;
        node.visitChildren(visit);
        return true;
      }

      canvas.visitChildren(visit);
      expect(found, isNotNull, reason: labels.join(' | '));
      expect(labels, containsAll(['Storage layer, Done', 'Docs, Queued']));
      final data = found!.getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      found!.owner!.performAction(found!.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(tapped, ['c']);
      handle.dispose();
    });

    testWidgets('chips grow with the text so labels always fit', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(WorkGraph(nodes: _six, onNodeTap: (_) {}), textScale: 2.5),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final canvas = tester.getSize(
        find.byKey(const ValueKey('team-work-graph-canvas')),
      );
      // 2.5x: chips are 390 wide and at least 61.5 tall, in four rows.
      expect(canvas.width, greaterThan(2 * 390 + 24));
      expect(canvas.height, greaterThan(4 * 61 + 3 * 48));
    });
  });
}
