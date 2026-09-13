/// The Work tab's Graph view (02-ux §4.2): a top-down dependency graph of
/// a run's work items drawn with a custom painter, no new dependency.
///
/// [WorkGraphLayout] is pure Dart and deterministic: longest-path layering
/// puts every item one row below the deepest thing it needs, a barycenter
/// sweep orders each row under its neighbours, nodes have a fixed size and
/// rows are centred, so a fixture graph lays out the same way every time
/// and tests can assert positions. It also names the critical path (the
/// longest chain of `needs` links) and the blocked chain (what is stuck,
/// what waits on it and what it waits on).
///
/// [WorkGraph] paints that layout: nodes are rounded chips coloured by
/// state with the state glyph beside the title (never colour-only, §11),
/// edges are the `needs` links, the critical path is thicker and the
/// blocked chain is drawn in the attention tone. Pinch-zoom and drag-pan
/// come from [InteractiveViewer]; Fit brings the whole graph back into
/// view; tapping a node reports its id.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../l10n/app_localizations.dart';
import '../../../orchestration/models/work.dart';
import '../../app_theme.dart';
import '../../widgets/team_vocabulary.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// One node of the graph: an item, its state and what it needs.
class WorkGraphNode {
  const WorkGraphNode({
    required this.id,
    required this.title,
    required this.state,
    this.dependsOn = const [],
  });

  WorkGraphNode.of(WorkItem item)
    : id = item.id,
      title = item.title,
      state = item.state,
      dependsOn = item.dependsOn;

  final String id;
  final String title;
  final WorkState state;

  /// Ids this node needs; ids outside the graph are ignored.
  final List<String> dependsOn;
}

/// One `needs` link, drawn from the bottom of what is needed to the top of
/// what needs it as a cubic curve through [control1] and [control2].
class WorkGraphEdge {
  const WorkGraphEdge({
    required this.from,
    required this.to,
    required this.start,
    required this.control1,
    required this.control2,
    required this.end,
    required this.critical,
    required this.blocked,
  });

  /// The needed item (upstream).
  final String from;

  /// The item that needs it (downstream).
  final String to;
  final Offset start;
  final Offset control1;
  final Offset control2;
  final Offset end;

  /// On the critical path: drawn thicker.
  final bool critical;

  /// Both ends in the blocked chain: drawn in the attention tone.
  final bool blocked;

  Path toPath() => Path()
    ..moveTo(start.dx, start.dy)
    ..cubicTo(
      control1.dx,
      control1.dy,
      control2.dx,
      control2.dy,
      end.dx,
      end.dy,
    );
}

/// Deterministic layered layout of a [WorkGraphNode] list.
class WorkGraphLayout {
  WorkGraphLayout._({
    required this.nodes,
    required this.rects,
    required this.layers,
    required this.edges,
    required this.criticalPath,
    required this.blockedChain,
    required this.size,
  });

  /// Default chip size at 1x text: at least 44dp tall (§11).
  static const defaultNodeSize = Size(156, 44);
  static const columnGap = 24.0;
  static const rowGap = 48.0;
  static const padding = 16.0;

  /// The nodes in input order, duplicates (by id) dropped.
  final List<WorkGraphNode> nodes;

  /// Where each node sits, by id.
  final Map<String, Rect> rects;

  /// Node ids per row, top row first, left to right.
  final List<List<String>> layers;
  final List<WorkGraphEdge> edges;

  /// The longest chain of `needs` links, upstream first. One id when no
  /// edge exists; empty when the graph is empty.
  final List<String> criticalPath;

  /// Stuck items (blocked, needs input, failed), everything downstream of
  /// them and the open items they wait on.
  final Set<String> blockedChain;

  /// The painted area, padding included.
  final Size size;

  /// Consecutive pairs of [criticalPath] as (from, to).
  Set<(String, String)> get criticalEdges => {
    for (var i = 0; i + 1 < criticalPath.length; i++)
      (criticalPath[i], criticalPath[i + 1]),
  };

  WorkGraphNode? nodeAt(Offset point) {
    for (final node in nodes) {
      if (rects[node.id]!.contains(point)) return node;
    }
    return null;
  }

  static WorkGraphLayout compute(
    List<WorkGraphNode> input, {
    Size nodeSize = defaultNodeSize,
  }) {
    // 1. Unique nodes in input order; edges to known, other nodes only.
    final nodes = <WorkGraphNode>[];
    final index = <String, int>{};
    for (final node in input) {
      if (index.containsKey(node.id)) continue;
      index[node.id] = nodes.length;
      nodes.add(node);
    }
    final n = nodes.length;
    final deps = <List<int>>[
      for (final node in nodes)
        [
          for (final id in {...node.dependsOn})
            if (index[id] case final i? when i != index[node.id]) i,
        ],
    ];

    // 2. Longest-path layering with cycle breaking: a dependency that
    //    closes a cycle is dropped so the graph stays a DAG.
    final layer = List<int?>.filled(n, null);
    final visiting = List<bool>.filled(n, false);
    int layerOf(int i) {
      if (layer[i] case final done?) return done;
      visiting[i] = true;
      var depth = 0;
      final kept = <int>[];
      for (final dep in deps[i]) {
        if (visiting[dep]) continue;
        kept.add(dep);
        depth = math.max(depth, layerOf(dep) + 1);
      }
      deps[i] = kept;
      visiting[i] = false;
      return layer[i] = depth;
    }

    for (var i = 0; i < n; i++) {
      layerOf(i);
    }
    final dependents = List<List<int>>.generate(n, (_) => []);
    for (var i = 0; i < n; i++) {
      for (final dep in deps[i]) {
        dependents[dep].add(i);
      }
    }

    // 3. Rows in input order, then three barycenter sweeps (down, up,
    //    down) pulling every node under the mean of its neighbours.
    final depth = n == 0 ? 0 : layer.cast<int>().reduce(math.max) + 1;
    final rows = List<List<int>>.generate(depth, (_) => []);
    for (var i = 0; i < n; i++) {
      rows[layer[i]!].add(i);
    }
    final column = List<double>.filled(n, 0);
    void place() {
      for (final row in rows) {
        for (final (position, i) in row.indexed) {
          column[i] = position - (row.length - 1) / 2;
        }
      }
    }

    void sweep(List<List<int>> neighbours, {bool upward = false}) {
      for (final row in upward ? rows.reversed : rows) {
        final key = <int, double>{};
        for (final i in row) {
          final near = neighbours[i];
          key[i] = near.isEmpty
              ? column[i]
              : near.map((j) => column[j]).reduce((a, b) => a + b) /
                    near.length;
        }
        final before = {for (final (p, i) in row.indexed) i: p};
        row.sort((a, b) {
          final byKey = key[a]!.compareTo(key[b]!);
          return byKey != 0 ? byKey : before[a]!.compareTo(before[b]!);
        });
        place();
      }
    }

    place();
    sweep(deps);
    sweep(dependents, upward: true);
    sweep(deps);

    // 4. Fixed-size nodes; each row centred under the widest.
    final widest = rows.fold(0, (w, row) => math.max(w, row.length));
    final width = widest == 0
        ? 0.0
        : widest * nodeSize.width + (widest - 1) * columnGap;
    final rects = <String, Rect>{};
    for (final (r, row) in rows.indexed) {
      final rowWidth =
          row.length * nodeSize.width + (row.length - 1) * columnGap;
      final left = padding + (width - rowWidth) / 2;
      final top = padding + r * (nodeSize.height + rowGap);
      for (final (p, i) in row.indexed) {
        rects[nodes[i].id] = Rect.fromLTWH(
          left + p * (nodeSize.width + columnGap),
          top,
          nodeSize.width,
          nodeSize.height,
        );
      }
    }
    final size = Size(
      width + 2 * padding,
      depth == 0
          ? 2 * padding
          : depth * nodeSize.height + (depth - 1) * rowGap + 2 * padding,
    );

    // 5. Critical path: the longest chain by node count; ties go to the
    //    earliest input node so the answer never flickers.
    final chain = List<int>.filled(n, 1);
    final via = List<int?>.filled(n, null);
    for (var r = 0; r < depth; r++) {
      for (final i in rows[r]) {
        for (final dep in deps[i]) {
          final length = chain[dep] + 1;
          if (length > chain[i] || (length == chain[i] && dep < via[i]!)) {
            chain[i] = length;
            via[i] = dep;
          }
        }
      }
    }
    final criticalPath = <String>[];
    if (n > 0) {
      var end = 0;
      for (var i = 1; i < n; i++) {
        if (chain[i] > chain[end]) end = i;
      }
      for (int? i = end; i != null; i = via[i]) {
        criticalPath.insert(0, nodes[i].id);
      }
    }

    // 6. Blocked chain: stuck items, everything downstream of them and
    //    the open items they wait on.
    final blocked = <int>{};
    final queue = <int>[
      for (var i = 0; i < n; i++)
        if (teamWorkIsStuck(nodes[i].state)) i,
    ];
    for (final i in queue) {
      for (final dep in deps[i]) {
        if (teamWorkIsOpen(nodes[dep].state)) blocked.add(dep);
      }
    }
    while (queue.isNotEmpty) {
      final i = queue.removeLast();
      if (!blocked.add(i)) continue;
      queue.addAll(dependents[i]);
    }
    final blockedChain = {for (final i in blocked) nodes[i].id};

    final critical = <(int, int)>{
      for (var i = 0; i < n; i++)
        if (via[i] case final dep? when criticalPath.contains(nodes[i].id))
          (dep, i),
    };
    final edges = <WorkGraphEdge>[
      for (var i = 0; i < n; i++)
        for (final dep in deps[i])
          () {
            final start = rects[nodes[dep].id]!.bottomCenter;
            final end = rects[nodes[i].id]!.topCenter;
            return WorkGraphEdge(
              from: nodes[dep].id,
              to: nodes[i].id,
              start: start,
              control1: start + const Offset(0, rowGap / 2),
              control2: end - const Offset(0, rowGap / 2),
              end: end,
              critical: critical.contains((dep, i)),
              blocked: blocked.contains(dep) && blocked.contains(i),
            );
          }(),
    ];

    return WorkGraphLayout._(
      nodes: nodes,
      rects: rects,
      layers: [
        for (final row in rows) [for (final i in row) nodes[i].id],
      ],
      edges: edges,
      criticalPath: criticalPath,
      blockedChain: blockedChain,
      size: size,
    );
  }
}

/// The graph view: pinch-zoom, drag-pan, Fit, node tap.
class WorkGraph extends StatefulWidget {
  const WorkGraph({
    super.key,
    required this.nodes,
    required this.onNodeTap,
    this.transformationController,
  });

  final List<WorkGraphNode> nodes;
  final ValueChanged<String> onNodeTap;

  /// Lets a test read the transform; the widget owns one otherwise.
  final TransformationController? transformationController;

  @override
  State<WorkGraph> createState() => _WorkGraphState();
}

class _WorkGraphState extends State<WorkGraph> {
  static const _minScale = .2;
  static const _maxScale = 3.0;

  TransformationController? _owned;
  TransformationController get _transform =>
      widget.transformationController ??
      (_owned ??= TransformationController());
  Size? _fitted;

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  /// Chips grow with the text so they are never smaller than their label.
  Size _nodeSize(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final line = scaler.scale(14) * 1.3;
    return Size(
      math.max(WorkGraphLayout.defaultNodeSize.width, scaler.scale(156)),
      math.max(WorkGraphLayout.defaultNodeSize.height, line + 16),
    );
  }

  void _fit(Size viewport, WorkGraphLayout layout) {
    const margin = 12.0;
    final scale = math
        .min(
          (viewport.width - 2 * margin) / layout.size.width,
          (viewport.height - 2 * margin) / layout.size.height,
        )
        .clamp(_minScale, 1.0);
    final dx = (viewport.width - layout.size.width * scale) / 2;
    final dy = math.max(
      margin,
      (viewport.height - layout.size.height * scale) / 2,
    );
    _transform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final layout = WorkGraphLayout.compute(
      widget.nodes,
      nodeSize: _nodeSize(context),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        if (_fitted != viewport) {
          _fitted = viewport;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fit(viewport, layout);
          });
        }
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                key: const ValueKey('team-work-graph-viewer'),
                transformationController: _transform,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                minScale: _minScale,
                maxScale: _maxScale,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final node = layout.nodeAt(details.localPosition);
                    if (node != null) widget.onNodeTap(node.id);
                  },
                  child: SizedBox.fromSize(
                    size: layout.size,
                    child: CustomPaint(
                      key: const ValueKey('team-work-graph-canvas'),
                      painter: WorkGraphPainter(
                        layout: layout,
                        theme: theme,
                        l10n: l10n,
                        textDirection: Directionality.of(context),
                        textScaler: MediaQuery.textScalerOf(context),
                        onNodeTap: widget.onNodeTap,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 8,
              end: 8,
              child: IconButton.filledTonal(
                key: const ValueKey('team-work-graph-fit'),
                tooltip: l10n.teamUiWorkGraphFit,
                onPressed: () => _fit(viewport, layout),
                icon: const Icon(AppIconography.collapse),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Paints [WorkGraphLayout]: edges first (critical thicker, blocked chain
/// in the attention tone), then the chips with glyph and title. Each chip
/// is a button in the semantics tree so a screen reader can walk the graph.
class WorkGraphPainter extends CustomPainter {
  WorkGraphPainter({
    required this.layout,
    required this.theme,
    required this.l10n,
    required this.textDirection,
    required this.textScaler,
    required this.onNodeTap,
  });

  final WorkGraphLayout layout;
  final ThemeData theme;
  final AppLocalizations l10n;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final ValueChanged<String> onNodeTap;

  static const _glyphSize = 18.0;
  static const _inset = 12.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scheme = theme.colorScheme;
    final attention = AppTheme.statusColor(theme, AppStatusTone.attention);
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final edge in layout.edges) {
      edgePaint
        ..strokeWidth = edge.critical ? 3.5 : 1.5
        ..color = edge.blocked
            ? attention
            : edge.critical
            ? scheme.onSurface.withValues(alpha: .75)
            : scheme.outline;
      canvas.drawPath(edge.toPath(), edgePaint);
      // A small arrow head says which way the link runs.
      final tip = edge.end;
      final head = Path()
        ..moveTo(tip.dx - 5, tip.dy - 7)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + 5, tip.dy - 7);
      canvas.drawPath(head, edgePaint);
    }

    final fill = Paint()..style = PaintingStyle.fill;
    final border = Paint()..style = PaintingStyle.stroke;
    for (final node in layout.nodes) {
      final rect = layout.rects[node.id]!;
      final (icon, tone) = teamWorkGlyph(node.state);
      final color = AppTheme.statusColor(theme, tone);
      final inChain = layout.blockedChain.contains(node.id);
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
      fill.color = Color.alphaBlend(
        color.withValues(alpha: .16),
        scheme.surfaceContainerHigh,
      );
      canvas.drawRRect(rrect, fill);
      border
        ..color = inChain ? attention : color
        ..strokeWidth = inChain ? 3 : 1.5;
      canvas.drawRRect(rrect, border);

      final glyph = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: _glyphSize,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      glyph.paint(
        canvas,
        Offset(rect.left + _inset, rect.center.dy - glyph.height / 2),
      );

      final label = TextPainter(
        text: TextSpan(
          text: node.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: inChain ? FontWeight.w600 : null,
          ),
        ),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(0, rect.width - 3 * _inset - _glyphSize));
      label.paint(
        canvas,
        Offset(
          rect.left + 2 * _inset + _glyphSize,
          rect.center.dy - label.height / 2,
        ),
      );
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder =>
      (size) => [
        for (final node in layout.nodes)
          CustomPainterSemantics(
            rect: layout.rects[node.id]!,
            properties: SemanticsProperties(
              label: l10n.teamUiWorkGraphNodeSemantics(
                node.title,
                teamWorkStateWord(l10n, node.state),
              ),
              textDirection: textDirection,
              button: true,
              onTap: () => onNodeTap(node.id),
            ),
          ),
      ];

  @override
  bool shouldRepaint(WorkGraphPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.theme != theme ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.textScaler != textScaler;

  @override
  bool shouldRebuildSemantics(WorkGraphPainter oldDelegate) =>
      oldDelegate.layout != layout;
}
