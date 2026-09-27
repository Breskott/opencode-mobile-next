// KitWorkGraph (docs/ux-system/kit-api/KitWorkGraph.md): the frozen "Tests
// required" contract — determinism, the rows lane assignment, the auto
// breakpoint, open on tap (rows and layers, and nothing between chips),
// keyboard (Tab order, Enter, Ctrl+0), Fit, semantics (nodes, the rows'
// hint, the zoom buttons and custom actions), tones (LOOK-4: the blocked
// chain never paints the attention colour, a painted-pixel scan), the
// overflow sweep (G6, with two-line titles) and reduced motion (G8).
//
// Owner decision 2026-09-27: Arabic is dropped for this wave — no RTL
// samples here (KitWorkGraph.md's "Tests required" #10 is out of scope).

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opencode_mobile/l10n/app_localizations.dart';
import 'package:opencode_mobile/platform/platform_capabilities.dart';
import 'package:opencode_mobile/ui/app_theme.dart';
import 'package:opencode_mobile/ui/kit/kit_bidi.dart';
import 'package:opencode_mobile/ui/kit/kit_icon_button.dart';
import 'package:opencode_mobile/ui/kit/kit_image.dart';
import 'package:opencode_mobile/ui/kit/kit_layout.dart';
import 'package:opencode_mobile/ui/kit/kit_task_mark.dart';
import 'package:opencode_mobile/ui/kit/kit_tokens.dart';
import 'package:opencode_mobile/ui/kit/kit_work_graph.dart';

import 'kit_motion_still.dart';

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
      home: Scaffold(
        body: RepaintBoundary(key: _shotKey, child: child),
      ),
    ),
  );
}

const _shotKey = ValueKey('kit-work-graph-test-shot');

Key _nodeKey(String id) => ValueKey('node-$id');

/// The layers chip size for [_six] at 1x: 156 wide; `space2` above and
/// below one `rowTitle` line (22) and, since the fixture has a stuck item,
/// one `secondary` line (20) for its word: 58, over the 48 dp floor.
const _layersNode = Size(156, 58);

/// How many painted pixels are exactly [colour] (a painted-colour scan:
/// what reaches the screen, not how the mark is built).
Future<int> _countPainted(WidgetTester tester, Color colour) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shotKey),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!;
  });
  final argb = colour.toARGB32();
  final r = (argb >> 16) & 0xff, g = (argb >> 8) & 0xff, b = argb & 0xff;
  var count = 0;
  for (var i = 0; i + 3 < bytes!.lengthInBytes; i += 4) {
    if (bytes.getUint8(i) == r &&
        bytes.getUint8(i + 1) == g &&
        bytes.getUint8(i + 2) == b &&
        bytes.getUint8(i + 3) == 0xff) {
      count++;
    }
  }
  return count;
}

/// Whether the node [id]'s KitTappable holds the primary focus.
bool _focused(WidgetTester tester, String id) =>
    Focus.of(tester.element(find.byKey(_nodeKey(id)))).hasPrimaryFocus;

/// The custom semantic actions on the KitZoom viewer, by label.
Map<String, VoidCallback> _zoomActions(WidgetTester tester) {
  final matches = tester
      .widgetList<Semantics>(
        find.descendant(
          of: find.byType(KitZoom),
          matching: find.byType(Semantics),
        ),
      )
      .where((s) => s.properties.customSemanticsActions != null);
  if (matches.isEmpty) return const {};
  return {
    for (final e in matches.first.properties.customSemanticsActions!.entries)
      e.key.label ?? '': e.value,
  };
}

/// A long title that wraps to two lines on every phone width here.
const _longTitle =
    'Reconcile the offline queue with the server after a reconnect';

List<KitWorkGraphNode> _withLongTitle() => [
  ..._six(),
  const KitWorkGraphNode(
    id: 'g',
    title: _longTitle,
    mark: KitTaskState.waiting,
    word: 'Blocked',
    dependsOn: ['e'],
    stuck: true,
  ),
];

/// Hosts [graph] the way a screen does: rows scroll with their host, the
/// layers canvas fills a bounded body.
Widget _host(BuildContext context, Widget graph) {
  final size = MediaQuery.sizeOf(context);
  final rows =
      KitLayout.windowOf(context) == KitWindow.compact ||
      KitLayout.isShort(context);
  return rows
      ? SingleChildScrollView(child: graph)
      : SizedBox(width: size.width, height: size.height, child: graph);
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
  kitMotionStillTests(
    'KitWorkGraph',
    builds: {
      'rows working': () => KitWorkGraph(
        nodes: const [
          KitWorkGraphNode(
            id: 'review',
            title: 'Review checkout',
            mark: KitTaskState.working,
          ),
        ],
        onOpen: (_) {},
      ),
      'layers working': () => KitWorkGraph(
        layout: KitWorkGraphLayout.layers,
        nodes: const [
          KitWorkGraphNode(
            id: 'review',
            title: 'Review checkout',
            mark: KitTaskState.working,
          ),
        ],
        onOpen: (_) {},
      ),
    },
    changes: {
      'dependent task arrives': KitMotionChange(
        build: () => KitWorkGraph(
          nodes: const [
            KitWorkGraphNode(
              id: 'review',
              title: 'Review checkout',
              mark: KitTaskState.done,
            ),
          ],
          onOpen: (_) {},
        ),
        act: (tester, stage) => stage.rebuild(
          KitWorkGraph(
            nodes: const [
              KitWorkGraphNode(
                id: 'review',
                title: 'Review checkout',
                mark: KitTaskState.done,
              ),
              KitWorkGraphNode(
                id: 'ship',
                title: 'Ship checkout',
                mark: KitTaskState.working,
                dependsOn: ['review'],
              ),
            ],
            onOpen: (_) {},
          ),
        ),
        shows: KitBidi.auto('Ship checkout'),
      ),
    },
  );

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
        nodeSize: _layersNode,
      );
      await _tapThroughZoom(tester, rect.topLeft + geometry.rects['c']!.center);
      await tester.pumpAndSettle();
      expect(opened, ['c']);

      // Between two chips of the first layer (a and f) nothing fires.
      final a = geometry.rects['a']!;
      await _tapThroughZoom(
        tester,
        rect.topLeft +
            Offset(a.right + KitTokens.graphColumnGap / 2, a.center.dy),
      );
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

  group('KitWorkGraph rows', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('a two-line title grows its row, no overflow · text $scale', (
        tester,
      ) async {
        await _pump(
          tester,
          SingleChildScrollView(
            child: KitWorkGraph(
              nodes: _withLongTitle(),
              onOpen: (_) {},
              layout: KitWorkGraphLayout.rows,
              nodeKey: _nodeKey,
            ),
          ),
          size: const Size(320, 740),
          textScale: scale,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Two rowTitle lines (22 each), the supporting line (20) and the
        // row's space2 insides (8 + 8), all at this text scale: taller than
        // the two-line row token, and nothing clipped.
        final row = tester.getSize(find.byKey(_nodeKey('g')));
        expect(row.height, greaterThanOrEqualTo((2 * 22 + 20) * scale + 16));
        final title = tester.getSize(find.text(KitBidi.auto(_longTitle)));
        expect(title.height, closeTo(2 * 22 * scale, 0.01));
        // A one-line row keeps the two-line row token as its floor.
        expect(
          tester.getSize(find.byKey(_nodeKey('f'))).height,
          greaterThanOrEqualTo(60),
        );
      });
    }
  });

  group('KitWorkGraph keyboard (desktop capabilities)', () {
    setUp(() {
      debugPlatformCapabilities = const PlatformCapabilities.linuxDesktop();
    });
    tearDown(() => debugPlatformCapabilities = null);

    testWidgets('Tab visits the nodes in geometry order, then the zoom pill; '
        'Enter opens the focused node', (tester) async {
      final opened = <String>[];
      await _pump(
        tester,
        KitWorkGraph(
          nodes: _six(),
          onOpen: opened.add,
          layout: KitWorkGraphLayout.layers,
          nodeKey: _nodeKey,
        ),
        size: const Size(1280, 800),
      );
      await tester.pumpAndSettle();
      const order = ['a', 'f', 'b', 'e', 'c', 'd'];
      final visited = <String>[];
      var pillFocused = false;
      for (var press = 0; press < 12 && !pillFocused; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        for (final id in order) {
          if (_focused(tester, id) && visited.lastOrNull != id) {
            visited.add(id);
          }
        }
        final context = FocusManager.instance.primaryFocus?.context;
        pillFocused =
            context?.findAncestorWidgetOfExactType<KitIconButton>() != null;
      }
      expect(visited, order);
      expect(pillFocused, isTrue, reason: 'the zoom pill follows the nodes');

      Focus.of(tester.element(find.byKey(_nodeKey('c')))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened, ['c']);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(opened, ['c', 'c']);
    });

    testWidgets('Ctrl+0 restores the fitted transform after a zoom', (
      tester,
    ) async {
      final zoom = KitZoomController();
      addTearDown(zoom.dispose);
      await _pump(
        tester,
        KitWorkGraph(
          nodes: _six(),
          onOpen: (_) {},
          layout: KitWorkGraphLayout.layers,
          zoomController: zoom,
        ),
        size: const Size(1280, 800),
      );
      await tester.pumpAndSettle();
      final fitted = zoom.value.clone();
      // Give the canvas focus the way a person does: a tap on it.
      await _tapThroughZoom(tester, const Offset(8, 8));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      expect(zoom.value, isNot(fitted));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
      expect(zoom.value, fitted);
    });

    testWidgets('rows: Tab visits the nodes in geometry order', (tester) async {
      await _pump(
        tester,
        KitWorkGraph(
          nodes: _six(),
          onOpen: (_) {},
          layout: KitWorkGraphLayout.rows,
          nodeKey: _nodeKey,
        ),
      );
      await tester.pumpAndSettle();
      const order = ['a', 'f', 'b', 'e', 'c', 'd'];
      final visited = <String>[];
      for (var press = 0; press < order.length; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        visited.addAll(order.where((id) => _focused(tester, id)));
      }
      expect(visited, order);
    });
  });

  group('KitWorkGraph fit', () {
    testWidgets('fitted on first layout; the Fit control restores it', (
      tester,
    ) async {
      final zoom = KitZoomController();
      addTearDown(zoom.dispose);
      await _pump(
        tester,
        KitWorkGraph(
          nodes: _six(),
          onOpen: (_) {},
          layout: KitWorkGraphLayout.layers,
          zoomController: zoom,
        ),
        size: const Size(1280, 800),
      );
      await tester.pumpAndSettle();
      final fitted = zoom.value.clone();
      final scale = fitted.getMaxScaleOnAxis();
      expect(scale, lessThanOrEqualTo(1));
      expect(scale, greaterThanOrEqualTo(KitZoom.minScale));
      // Centred: the canvas is 368 wide and 408 tall at 1x.
      final viewer = tester.getRect(
        find.byKey(const ValueKey('kit-work-graph-viewer')),
      );
      final canvas = tester.getRect(
        find.byKey(const ValueKey('kit-work-graph-canvas')),
      );
      expect(canvas.center.dx, closeTo(viewer.center.dx, 0.5));
      expect(canvas.center.dy, closeTo(viewer.center.dy, 0.5));

      zoom.zoomIn();
      await tester.pumpAndSettle();
      expect(zoom.value, isNot(fitted));
      await tester.tap(find.byKey(const ValueKey('kit-work-graph-fit')));
      await tester.pumpAndSettle();
      expect(zoom.value, fitted);
    });
  });

  group('KitWorkGraph semantics', () {
    testWidgets('rows: each node is a button labelled "{title}, {state}" '
        'with the supporting line as its hint', (tester) async {
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
      expect(find.bySemanticsLabel('Work graph'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('layers: node buttons, the viewer label, the zoom buttons '
        'and their custom actions', (tester) async {
      final handle = tester.ensureSemantics();
      final zoom = KitZoomController();
      addTearDown(zoom.dispose);
      await _pump(
        tester,
        KitWorkGraph(
          nodes: _six(),
          onOpen: (_) {},
          layout: KitWorkGraphLayout.layers,
          zoomController: zoom,
        ),
        size: const Size(1280, 800),
      );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(
        find.bySemanticsLabel('Conflict policy, Blocked'),
      );
      expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(find.bySemanticsLabel('Work graph'), findsOneWidget);

      for (final label in ['Zoom in', 'Zoom out']) {
        final button = tester.getSemantics(find.bySemanticsLabel(label));
        expect(button.getSemanticsData().flagsCollection.isButton, isTrue);
      }
      final fit = tester.getSemantics(
        find.byKey(const ValueKey('kit-work-graph-fit')),
      );
      expect(fit.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(_zoomActions(tester).keys, contains('Zoom in'));

      zoom.zoomIn();
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('kit-work-graph-fit')))
            .label,
        'Fit to screen',
      );
      expect(
        _zoomActions(tester).keys,
        containsAll(['Zoom in', 'Zoom out', 'Reset zoom']),
      );
      handle.dispose();
    });
  });

  group('KitWorkGraph tones', () {
    for (final layout in [KitWorkGraphLayout.rows, KitWorkGraphLayout.layers]) {
      testWidgets('${layout.name}: the blocked chain paints no attention '
          'colour; only a needs-you node does, with its word', (tester) async {
        final size = layout == KitWorkGraphLayout.rows
            ? const Size(412, 915)
            : const Size(1280, 800);
        await _pump(
          tester,
          KitWorkGraph(nodes: _six(), onOpen: (_) {}, layout: layout),
          size: size,
        );
        await tester.pumpAndSettle();
        final theme = Theme.of(tester.element(find.byType(KitWorkGraph)));
        final attention = AppTheme.rolesOf(theme).attention;
        expect(await _countPainted(tester, attention), greaterThan(0));
        expect(
          find.bySemanticsLabel(RegExp(r'^Unit tests, Needs you$')),
          findsOneWidget,
        );

        // The same graph with its needs-you item gone still has the
        // blocked chain (b, c, d) and paints no attention colour at all.
        await _pump(
          tester,
          KitWorkGraph(
            nodes: [
              for (final n in _six())
                if (n.mark != KitTaskState.needsYou) n,
            ],
            onOpen: (_) {},
            layout: layout,
          ),
          size: size,
        );
        await tester.pumpAndSettle();
        expect(await _countPainted(tester, attention), 0);
      });
    }
  });

  group('KitWorkGraph overflow and motion', () {
    for (final size in const [
      Size(320, 740),
      Size(412, 915),
      Size(1280, 800),
      Size(915, 412),
    ]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('no overflow at ${size.width.toInt()}x'
            '${size.height.toInt()} · text $scale', (tester) async {
          await _pump(
            tester,
            Builder(
              builder: (context) => _host(
                context,
                KitWorkGraph(nodes: _withLongTitle(), onOpen: (_) {}),
              ),
            ),
            size: size,
            textScale: scale,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('settles after one pump under reduced motion', (tester) async {
      await _pump(
        tester,
        KitWorkGraph(nodes: _six(), onOpen: (_) {}),
        size: const Size(1280, 800),
      );
      // The fit on open runs in the first post-frame callback, not as an
      // animation: one more frame and nothing is scheduled.
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });
}
