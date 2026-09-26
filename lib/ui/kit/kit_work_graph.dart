/// KitWorkGraph (docs/ux-system/kit-api/KitWorkGraph.md): the dependency
/// graph of a team task's work items, readable on a phone.
///
/// On a compact window, `rows` lists one item per row with the `needs`
/// links drawn as lanes in a start-side gutter and each row saying its
/// state in words. From a medium window up, `layers` draws the graph in a
/// zoomable canvas ([KitZoom]) with the critical path and blocked chain
/// picked out, fitted on open.
///
/// The part is model-free: the host maps its own work items to
/// [KitWorkGraphNode]s. [KitWorkGraphGeometry] is the pure, deterministic
/// layout the widget paints — tests assert its positions directly.
///
/// Build note (PROC-32/STANDARDS.md §2): the frozen spec makes this part
/// depend on kit-KitTappable for its nodes' focus, hover and 48dp target
/// behaviour. That unit had not merged into feat/phone-setup-v2 when this
/// one was built (wave 1, same tier), so the node button below reproduces
/// the nearest already-merged idiom instead — the same
/// DecoratedBox(foreground border) + Material + InkWell pattern
/// KitIconButton and KitButtons already use for their own focus ring — and
/// leaves the gap listed in this unit's QA record. When kit-KitTappable
/// merges, `_GraphNodeButton` should be replaced with it (KIT-3).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../app_theme.dart';
import 'kit_bidi.dart';
import 'kit_image.dart';
import 'kit_layout.dart';
import 'kit_state_view.dart';
import 'kit_task_mark.dart';
import 'kit_text.dart';
import 'kit_tokens.dart';

AppLocalizations _copy(BuildContext context) =>
    lookupAppLocalizations(Localizations.localeOf(context));

/// One work item. The host maps its own model; the kit knows no WorkState.
@immutable
class KitWorkGraphNode {
  const KitWorkGraphNode({
    required this.id,
    required this.title,
    required this.mark,
    this.paused = false,
    this.word,
    this.dependsOn = const [],
    this.stuck = false,
    this.open = true,
  });

  final String id;

  /// The item's title as written (COPY-2).
  final String title;

  /// The leading mark and its tone.
  final KitTaskState mark;

  /// Only meaningful with [KitTaskState.waiting] or [KitTaskState.working]
  /// (KitTaskMark's own rule).
  final bool paused;

  /// The state word; null takes [KitTaskMark.wordFor].
  final String? word;

  /// Ids this item needs; ids outside the graph are ignored.
  final List<String> dependsOn;

  /// Blocked, needs input or failed: seeds the blocked chain.
  final bool stuck;

  /// Not finished yet: something stuck may be waiting on it.
  final bool open;
}

/// Where [KitWorkGraph] draws its graph.
enum KitWorkGraphLayout {
  /// Rows on compact, layers from medium (the default).
  auto,

  /// One item per row, links in a start-side gutter; scrolls with its host.
  rows,

  /// The layered graph in a zoomable canvas, fitted on open.
  layers,
}

/// One `needs` link. In `layers` it is a cubic curve through [control1] and
/// [control2] (UNCHANGED geometry from the retired `WorkGraphEdge`); in
/// `rows` it is a straight run through its [lane] in the start-side gutter.
@immutable
class KitWorkGraphEdge {
  const KitWorkGraphEdge({
    required this.from,
    required this.to,
    required this.start,
    required this.control1,
    required this.control2,
    required this.end,
    required this.critical,
    required this.blocked,
    this.lane = -1,
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

  /// Both ends in the blocked chain: drawn dashed, in the attention-free
  /// blocked tone.
  final bool blocked;

  /// Rows only; -1 in layers.
  final int lane;

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

/// A row/layer graph analysis shared by [KitWorkGraphGeometry.layers] and
/// [KitWorkGraphGeometry.rows]: unique nodes, the DAG of dependencies (a
/// dependency that would close a cycle is dropped), rows by longest-path
/// layer with a barycenter sweep, the critical path and the blocked chain.
/// Identical for both forms so their node order always agrees (KitWorkGraph.md
/// "the same order as layers read top to bottom, start to end").
class _Analysis {
  _Analysis({
    required this.nodes,
    required this.deps,
    required this.dependents,
    required this.rows,
    required this.criticalPath,
    required this.blockedChain,
  });

  final List<KitWorkGraphNode> nodes;
  final List<List<int>> deps;
  final List<List<int>> dependents;

  /// Row (layer) index → node indices, left/start to right/end.
  final List<List<int>> rows;
  final List<String> criticalPath;
  final Set<String> blockedChain;

  static _Analysis of(List<KitWorkGraphNode> input) {
    // 1. Unique nodes in input order; edges to known, other nodes only.
    final nodes = <KitWorkGraphNode>[];
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

    // 4. Critical path: the longest chain by node count; ties go to the
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

    // 5. Blocked chain: stuck items, everything downstream of them and the
    //    open items they wait on.
    final blocked = <int>{};
    final queue = <int>[
      for (var i = 0; i < n; i++)
        if (nodes[i].stuck) i,
    ];
    for (final i in queue) {
      for (final dep in deps[i]) {
        if (nodes[dep].open) blocked.add(dep);
      }
    }
    while (queue.isNotEmpty) {
      final i = queue.removeLast();
      if (!blocked.add(i)) continue;
      queue.addAll(dependents[i]);
    }

    return _Analysis(
      nodes: nodes,
      deps: deps,
      dependents: dependents,
      rows: rows,
      criticalPath: criticalPath,
      blockedChain: {for (final i in blocked) nodes[i].id},
    );
  }
}

/// The pure, deterministic geometry (moved unchanged from the retired
/// `WorkGraphLayout`, plus the `rows` form). No widgets; tests assert
/// positions.
class KitWorkGraphGeometry {
  KitWorkGraphGeometry._({
    required this.nodes,
    required this.rects,
    required this.layerRows,
    required this.edges,
    required this.criticalPath,
    required this.blockedChain,
    required this.size,
    required this.gutter,
  });

  /// Default chip size at 1x text (UNCHANGED from the retired
  /// `WorkGraphLayout.defaultNodeSize`: geometry keeps today's output for
  /// the same node size; the widget grows this at runtime to the 48dp
  /// target, LAY-9).
  static const defaultNodeSize = Size(KitTokens.graphNodeWidth, 44.0);
  static const double _padding = 16.0;

  /// Mirrors [KitTokens.space3]'s base (unscaled) value: geometry is pure
  /// Dart with no BuildContext, so it takes the base spacing and callers
  /// already grow node/row sizes with text before calling in.
  static const double _laneWidth = 12.0;

  /// The nodes in input order, duplicates (by id) dropped.
  final List<KitWorkGraphNode> nodes;

  /// Where each node sits, by id.
  final Map<String, Rect> rects;

  /// Node ids per row, top row first, start to end.
  ///
  /// Contract problem (PROC-20, this unit's QA record): the frozen spec
  /// names this field `layers`, the same as the static factory
  /// [KitWorkGraphGeometry.layers] on the same class — Dart refuses a
  /// static member and an instance member sharing a name
  /// (`conflicting_static_and_instance`). Kept as `layerRows` instead; the
  /// factory keeps its spec name since call sites read it as a verb.
  final List<List<String>> layerRows;
  final List<KitWorkGraphEdge> edges;

  /// The longest chain of `needs` links, upstream first. One id when no
  /// edge exists; empty when the graph is empty.
  final List<String> criticalPath;

  /// Stuck items (blocked, needs input, failed), everything downstream of
  /// them and the open items they wait on.
  final Set<String> blockedChain;

  /// The painted area, padding included.
  final Size size;

  /// `rows`: the links' gutter width; `layers`: 0.
  final double gutter;

  /// Consecutive pairs of [criticalPath] as (from, to).
  Set<(String, String)> get criticalEdges => {
    for (var i = 0; i + 1 < criticalPath.length; i++)
      (criticalPath[i], criticalPath[i + 1]),
  };

  KitWorkGraphNode? nodeAt(Offset point) {
    for (final node in nodes) {
      if (rects[node.id]!.contains(point)) return node;
    }
    return null;
  }

  /// Longest-path layering, then a barycenter sweep, fixed node size, rows
  /// centred. UNCHANGED algorithm and output for the same inputs.
  static KitWorkGraphGeometry layers(
    List<KitWorkGraphNode> nodes, {
    required Size nodeSize,
  }) {
    final a = _Analysis.of(nodes);
    final n = a.nodes.length;
    final depth = a.rows.length;

    final widest = a.rows.fold(0, (w, row) => math.max(w, row.length));
    final width = widest == 0
        ? 0.0
        : widest * nodeSize.width + (widest - 1) * KitTokens.graphColumnGap;
    final rects = <String, Rect>{};
    for (final (r, row) in a.rows.indexed) {
      final rowWidth =
          row.length * nodeSize.width +
          (row.length - 1) * KitTokens.graphColumnGap;
      final left = _padding + (width - rowWidth) / 2;
      final top = _padding + r * (nodeSize.height + KitTokens.graphRowGap);
      for (final (p, i) in row.indexed) {
        rects[a.nodes[i].id] = Rect.fromLTWH(
          left + p * (nodeSize.width + KitTokens.graphColumnGap),
          top,
          nodeSize.width,
          nodeSize.height,
        );
      }
    }
    final size = Size(
      width + 2 * _padding,
      depth == 0
          ? 2 * _padding
          : depth * nodeSize.height +
                (depth - 1) * KitTokens.graphRowGap +
                2 * _padding,
    );

    final critical = <(int, int)>{
      for (var i = 0; i < n; i++)
        if (_via(a, i) case final dep?
            when a.criticalPath.contains(a.nodes[i].id))
          (dep, i),
    };
    final edges = <KitWorkGraphEdge>[
      for (var i = 0; i < n; i++)
        for (final dep in a.deps[i])
          () {
            final start = rects[a.nodes[dep].id]!.bottomCenter;
            final end = rects[a.nodes[i].id]!.topCenter;
            return KitWorkGraphEdge(
              from: a.nodes[dep].id,
              to: a.nodes[i].id,
              start: start,
              control1: start + Offset(0, KitTokens.graphRowGap / 2),
              control2: end - Offset(0, KitTokens.graphRowGap / 2),
              end: end,
              critical: critical.contains((dep, i)),
              blocked:
                  a.blockedChain.contains(a.nodes[dep].id) &&
                  a.blockedChain.contains(a.nodes[i].id),
            );
          }(),
    ];

    return KitWorkGraphGeometry._(
      nodes: a.nodes,
      rects: rects,
      layerRows: [
        for (final row in a.rows) [for (final i in row) a.nodes[i].id],
      ],
      edges: edges,
      criticalPath: a.criticalPath,
      blockedChain: a.blockedChain,
      size: size,
      gutter: 0,
    );
  }

  /// NEW. The same order as [layers] read top to bottom, start to end, one
  /// node per row; each link gets a lane in the gutter (greedy interval
  /// assignment, at most [KitTokens.graphMaxLanes] lanes; extra links share
  /// the last lane).
  static KitWorkGraphGeometry rows(
    List<KitWorkGraphNode> nodes, {
    required double width,
    required double Function(KitWorkGraphNode) rowHeight,
  }) {
    final a = _Analysis.of(nodes);
    final order = <int>[for (final row in a.rows) ...row];
    final position = <String, int>{
      for (final (p, i) in order.indexed) a.nodes[i].id: p,
    };

    // Lane assignment: sort spans by start then length, place each in the
    // first lane whose last use ends at or before this span's start.
    final spans =
        <(int from, int to, int start, int end)>[
          for (var i = 0; i < a.nodes.length; i++)
            for (final dep in a.deps[i])
              (
                dep,
                i,
                math.min(position[a.nodes[dep].id]!, position[a.nodes[i].id]!),
                math.max(position[a.nodes[dep].id]!, position[a.nodes[i].id]!),
              ),
        ]..sort((x, y) {
          final byStart = x.$3.compareTo(y.$3);
          return byStart != 0 ? byStart : x.$4.compareTo(y.$4);
        });
    final laneEnd = <int, int>{};
    final laneOf = <(int, int), int>{};
    for (final s in spans) {
      var chosen = KitTokens.graphMaxLanes - 1;
      for (var lane = 0; lane < KitTokens.graphMaxLanes; lane++) {
        final end = laneEnd[lane];
        if (end == null || end <= s.$3) {
          chosen = lane;
          break;
        }
      }
      laneEnd[chosen] = math.max(laneEnd[chosen] ?? 0, s.$4);
      laneOf[(s.$1, s.$2)] = chosen;
    }
    final laneCount = laneOf.isEmpty ? 0 : laneOf.values.reduce(math.max) + 1;
    final gutter = laneCount == 0 ? 0.0 : laneCount * _laneWidth;

    final rects = <String, Rect>{};
    var y = 0.0;
    final rowWidth = math.max(0.0, width - gutter);
    for (final i in order) {
      final h = rowHeight(a.nodes[i]);
      rects[a.nodes[i].id] = Rect.fromLTWH(gutter, y, rowWidth, h);
      y += h;
    }
    final size = Size(width, y);

    final critical = <(int, int)>{
      for (var i = 0; i < a.nodes.length; i++)
        if (_via(a, i) case final dep?
            when a.criticalPath.contains(a.nodes[i].id))
          (dep, i),
    };
    final edges = <KitWorkGraphEdge>[
      for (var i = 0; i < a.nodes.length; i++)
        for (final dep in a.deps[i])
          () {
            final lane = laneOf[(dep, i)]!;
            final x = lane * _laneWidth + _laneWidth / 2;
            final start = Offset(x, rects[a.nodes[dep].id]!.center.dy);
            final end = Offset(x, rects[a.nodes[i].id]!.center.dy);
            return KitWorkGraphEdge(
              from: a.nodes[dep].id,
              to: a.nodes[i].id,
              start: start,
              control1: start,
              control2: end,
              end: end,
              critical: critical.contains((dep, i)),
              blocked:
                  a.blockedChain.contains(a.nodes[dep].id) &&
                  a.blockedChain.contains(a.nodes[i].id),
              lane: lane,
            );
          }(),
    ];

    return KitWorkGraphGeometry._(
      nodes: a.nodes,
      rects: rects,
      layerRows: [
        for (final row in a.rows) [for (final i in row) a.nodes[i].id],
      ],
      edges: edges,
      criticalPath: a.criticalPath,
      blockedChain: a.blockedChain,
      size: size,
      gutter: gutter,
    );
  }

  static int? _via(_Analysis a, int i) {
    // Recomputed from criticalPath's adjacency rather than kept as state:
    // the node just upstream of [i] on the critical path, if [i] is on it.
    final id = a.nodes[i].id;
    final at = a.criticalPath.indexOf(id);
    if (at <= 0) return null;
    final fromId = a.criticalPath[at - 1];
    for (final dep in a.deps[i]) {
      if (a.nodes[dep].id == fromId) return dep;
    }
    return null;
  }
}

/// States: laid out, empty, one item (no links), blocked chain, needs you.
/// KIT-12: laid out, empty (+ blocked chain, needs you).
class KitWorkGraph extends StatefulWidget {
  const KitWorkGraph({
    super.key,
    required this.nodes,
    required this.onOpen,
    this.layout = KitWorkGraphLayout.auto,
    this.emptyText,
    this.zoomController,
    this.viewerKey,
    this.canvasKey,
    this.fitKey,
    this.nodeKey,
  });

  final List<KitWorkGraphNode> nodes;

  /// The node's id.
  final ValueChanged<String> onOpen;
  final KitWorkGraphLayout layout;

  /// Shown when [nodes] is empty; null takes `kitWorkGraphEmpty`.
  final String? emptyText;

  /// Layers only; wraps the host's own [TransformationController] when it
  /// has one. Tests read `.value`.
  final KitZoomController? zoomController;
  final Key? viewerKey;
  final Key? canvasKey;

  /// Passed to [KitZoom]'s `resetControlKey`.
  final Key? fitKey;
  final Key Function(String id)? nodeKey;

  static const _viewerKey = ValueKey('kit-work-graph-viewer');
  static const _canvasKey = ValueKey('kit-work-graph-canvas');
  static const _fitKey = ValueKey('kit-work-graph-fit');

  @override
  State<KitWorkGraph> createState() => _KitWorkGraphState();
}

class _KitWorkGraphState extends State<KitWorkGraph> {
  KitZoomController? _owned;
  KitZoomController get _zoom =>
      widget.zoomController ?? (_owned ??= KitZoomController());

  @override
  void didUpdateWidget(KitWorkGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.zoomController != oldWidget.zoomController &&
        oldWidget.zoomController == null) {
      _owned?.dispose();
      _owned = null;
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  KitWorkGraphLayout _resolve(BuildContext context) {
    if (widget.layout != KitWorkGraphLayout.auto) return widget.layout;
    final window = KitLayout.windowOf(context);
    if (window == KitWindow.compact) return KitWorkGraphLayout.rows;
    if (KitLayout.isShort(context)) return KitWorkGraphLayout.rows;
    return KitWorkGraphLayout.layers;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    if (widget.nodes.isEmpty) {
      return KitStateView(
        size: KitStateSize.inline,
        icon: AppIconography.checklist,
        title: widget.emptyText ?? l10n.kitWorkGraphEmpty,
      );
    }
    return switch (_resolve(context)) {
      KitWorkGraphLayout.rows => _RowsGraph(
        nodes: widget.nodes,
        onOpen: widget.onOpen,
        nodeKey: widget.nodeKey,
      ),
      KitWorkGraphLayout.auto || KitWorkGraphLayout.layers => _LayersGraph(
        nodes: widget.nodes,
        onOpen: widget.onOpen,
        nodeKey: widget.nodeKey,
        zoomController: _zoom,
        viewerKey: widget.viewerKey ?? KitWorkGraph._viewerKey,
        canvasKey: widget.canvasKey ?? KitWorkGraph._canvasKey,
        fitKey: widget.fitKey ?? KitWorkGraph._fitKey,
      ),
    };
  }
}

/// A node's leading mark and word, in one place so `rows` and `layers`
/// (and the graph's data-safety rule, ARCH-8) read it the same way.
String _wordOf(BuildContext context, KitWorkGraphNode node) =>
    node.word ?? KitTaskMark.wordFor(context, node.mark, paused: node.paused);

/// The nearest already-merged focus/hover/48dp-target idiom (see the file
/// doc comment): a foreground focus ring plus a transparent [InkWell],
/// exactly as [KitIconButton] already builds its own. Every node is a Tab
/// stop, a hover target and a single semantics button (STATE-9).
class _GraphNodeButton extends StatefulWidget {
  const _GraphNodeButton({
    required this.label,
    required this.hint,
    required this.onTap,
    required this.borderColor,
    required this.tooltip,
    required this.child,
    this.nodeKey,
  });

  final String label;
  final String? hint;
  final VoidCallback onTap;

  /// Null: no border when not focused (rows — the row itself is the
  /// boundary). Non-null: a hairline border in this colour (layers).
  final Color? borderColor;
  final String? tooltip;
  final Widget child;
  final Key? nodeKey;

  @override
  State<_GraphNodeButton> createState() => _GraphNodeButtonState();
}

class _GraphNodeButtonState extends State<_GraphNodeButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final radius = BorderRadius.circular(tokens.panelCornerRadius);
    final color = widget.borderColor;
    Widget button = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: _focused
            ? Border.all(
                color: roles.accent,
                width: KitTokens.focusRingWidth(context),
              )
            : color == null
            ? null
            : Border.all(color: color, width: KitTokens.hairlineWidth(context)),
      ),
      child: Material(
        color: roles.surface1,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: widget.nodeKey,
          onTap: widget.onTap,
          hoverColor: roles.surface2,
          focusColor: Colors.transparent,
          highlightColor: Colors.transparent,
          canRequestFocus: true,
          onFocusChange: (value) {
            if (value != _focused) setState(() => _focused = value);
          },
          child: widget.child,
        ),
      ),
    );
    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return Semantics(
      button: true,
      label: widget.label,
      hint: widget.hint,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: button,
    );
  }
}

/// `rows`: one item per row, mark, title (up to 2 lines), a supporting line
/// naming the state word and first dependency.
class _RowsGraph extends StatelessWidget {
  const _RowsGraph({required this.nodes, required this.onOpen, this.nodeKey});

  final List<KitWorkGraphNode> nodes;
  final ValueChanged<String> onOpen;
  final Key Function(String id)? nodeKey;

  double _rowHeight(BuildContext context, KitTokens tokens) {
    final scaler = MediaQuery.textScalerOf(context);
    final title = scaler.scale(16) * 1.3;
    final secondary = scaler.scale(14) * 1.3;
    return math.max(
      tokens.minTarget,
      tokens.space2 * 2 + title * 2 + secondary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final tokens = KitTokens.of(context);
    final rowHeight = _rowHeight(context, tokens);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : KitWorkGraphGeometry.defaultNodeSize.width * 2;
        final geometry = KitWorkGraphGeometry.rows(
          nodes,
          width: width,
          rowHeight: (_) => rowHeight,
        );
        final titleById = {for (final n in geometry.nodes) n.id: n.title};
        return Semantics(
          container: true,
          label: l10n.kitWorkGraph,
          child: SizedBox(
            width: width,
            height: geometry.size.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _RowEdgePainter(
                        geometry: geometry,
                        theme: Theme.of(context),
                        hairline: KitTokens.hairlineWidth(context),
                        focusWidth: KitTokens.focusRingWidth(context),
                        textDirection: Directionality.of(context),
                      ),
                    ),
                  ),
                ),
                for (final node in geometry.nodes)
                  if (geometry.rects[node.id] case final rect?)
                    PositionedDirectional(
                      start: rect.left,
                      top: rect.top,
                      width: rect.width,
                      height: rect.height,
                      child: _RowNode(
                        node: node,
                        word: _wordOf(context, node),
                        dependencyTitles: [
                          for (final id in node.dependsOn) ?titleById[id],
                        ],
                        l10n: l10n,
                        onOpen: () => onOpen(node.id),
                        nodeKey: nodeKey?.call(node.id),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RowNode extends StatelessWidget {
  const _RowNode({
    required this.node,
    required this.word,
    required this.dependencyTitles,
    required this.l10n,
    required this.onOpen,
    this.nodeKey,
  });

  final KitWorkGraphNode node;
  final String word;
  final List<String> dependencyTitles;
  final AppLocalizations l10n;
  final VoidCallback onOpen;
  final Key? nodeKey;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final hint = dependencyTitles.isEmpty
        ? null
        : dependencyTitles.length == 1
        ? l10n.kitWorkGraphNeeds(dependencyTitles.first)
        : l10n.kitWorkGraphNeedsMore(
            dependencyTitles.first,
            dependencyTitles.length - 1,
          );
    final supporting = dependencyTitles.isEmpty
        ? word
        : '$word · ${l10n.kitWorkGraphNeeds(dependencyTitles.first)}';
    final label = l10n.kitWorkGraphNode(node.title, word);
    return _GraphNodeButton(
      label: label,
      hint: hint,
      onTap: onOpen,
      borderColor: null,
      tooltip: null,
      nodeKey: nodeKey,
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: tokens.space3,
          vertical: tokens.space2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KitTaskMark(state: node.mark, paused: node.paused, label: word),
            SizedBox(width: tokens.space2),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KitText(
                    KitBidi.auto(node.title),
                    role: KitTextRole.rowTitle,
                    tone: node.stuck ? KitTextTone.primary : null,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  KitText(
                    supporting,
                    role: KitTextRole.secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `layers`: the layered graph in a zoomable canvas, fitted on open.
class _LayersGraph extends StatelessWidget {
  const _LayersGraph({
    required this.nodes,
    required this.onOpen,
    required this.zoomController,
    required this.viewerKey,
    required this.canvasKey,
    required this.fitKey,
    this.nodeKey,
  });

  final List<KitWorkGraphNode> nodes;
  final ValueChanged<String> onOpen;
  final KitZoomController zoomController;
  final Key viewerKey;
  final Key canvasKey;
  final Key fitKey;
  final Key Function(String id)? nodeKey;

  Size _nodeSize(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final line = scaler.scale(14) * 1.3;
    final tokens = KitTokens.of(context);
    return Size(
      math.max(
        KitWorkGraphGeometry.defaultNodeSize.width,
        scaler.scale(KitTokens.graphNodeWidth),
      ),
      // LAY-9: the 48dp target floor, grown with text like the retired
      // wrapper's 44dp floor.
      math.max(tokens.minTarget, line + 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = _copy(context);
    final theme = Theme.of(context);
    final geometry = KitWorkGraphGeometry.layers(
      nodes,
      nodeSize: _nodeSize(context),
    );
    final direction = Directionality.of(context);
    return KitZoom(
      key: viewerKey,
      mode: KitZoomMode.canvas,
      label: l10n.kitWorkGraph,
      controller: zoomController,
      resetControlKey: fitKey,
      child: SizedBox.fromSize(
        key: canvasKey,
        size: geometry.size,
        child: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _LayerEdgePainter(
                    geometry: geometry,
                    theme: theme,
                    hairline: KitTokens.hairlineWidth(context),
                    focusWidth: KitTokens.focusRingWidth(context),
                  ),
                ),
              ),
            ),
            for (final node in geometry.nodes)
              if (geometry.rects[node.id] case final rect?)
                Positioned.fromRect(
                  rect: rect,
                  child: _LayerChip(
                    node: node,
                    word: _wordOf(context, node),
                    inChain: geometry.blockedChain.contains(node.id),
                    l10n: l10n,
                    onOpen: () => onOpen(node.id),
                    nodeKey: nodeKey?.call(node.id),
                    textDirection: direction,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _LayerChip extends StatelessWidget {
  const _LayerChip({
    required this.node,
    required this.word,
    required this.inChain,
    required this.l10n,
    required this.onOpen,
    required this.textDirection,
    this.nodeKey,
  });

  final KitWorkGraphNode node;
  final String word;
  final bool inChain;
  final AppLocalizations l10n;
  final VoidCallback onOpen;
  final TextDirection textDirection;
  final Key? nodeKey;

  @override
  Widget build(BuildContext context) {
    final tokens = KitTokens.of(context);
    final roles = tokens.roles;
    final label = l10n.kitWorkGraphNode(node.title, word);
    return _GraphNodeButton(
      label: label,
      hint: null,
      onTap: onOpen,
      borderColor: inChain ? roles.text1 : roles.hairline,
      tooltip: KitBidi.auto(node.title),
      nodeKey: nodeKey,
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: tokens.space3,
          vertical: tokens.space2,
        ),
        child: Row(
          children: [
            KitTaskMark(state: node.mark, paused: node.paused, label: word),
            SizedBox(width: tokens.space2),
            Expanded(
              child: KitText(
                KitBidi.auto(node.title),
                role: KitTextRole.rowTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashes [path] with [dash]-long segments and equal gaps.
Path _dashed(Path path, double dash) {
  final result = Path();
  for (final metric in path.computeMetrics()) {
    var distance = 0.0;
    var draw = true;
    while (distance < metric.length) {
      final next = math.min(distance + dash, metric.length);
      if (draw) {
        result.addPath(metric.extractPath(distance, next), Offset.zero);
      }
      distance = next;
      draw = !draw;
    }
  }
  return result;
}

void _arrowHead(Canvas canvas, Offset tip, Paint paint) {
  final head = Path()
    ..moveTo(tip.dx - 5, tip.dy - 7)
    ..lineTo(tip.dx, tip.dy)
    ..lineTo(tip.dx + 5, tip.dy - 7);
  canvas.drawPath(head, paint);
}

/// Paints [KitWorkGraphGeometry.layers]'s links: critical 2 physical px in
/// `text2`, others 1 physical px in `text3`, blocked dashed in `text1`
/// (LOOK-4: never the attention colour). No nodes: they are widgets.
class _LayerEdgePainter extends CustomPainter {
  _LayerEdgePainter({
    required this.geometry,
    required this.theme,
    required this.hairline,
    required this.focusWidth,
  });

  final KitWorkGraphGeometry geometry;
  final ThemeData theme;
  final double hairline;
  final double focusWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final roles = AppTheme.rolesOf(theme);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final edge in geometry.edges) {
      final path = edge.toPath();
      paint
        ..strokeWidth = edge.critical ? focusWidth : hairline
        ..color = edge.blocked
            ? roles.text1
            : edge.critical
            ? roles.text2
            : roles.text3;
      canvas.drawPath(
        edge.blocked ? _dashed(path, KitTokens.graphDash) : path,
        paint,
      );
      _arrowHead(canvas, edge.end, paint);
    }
  }

  @override
  bool shouldRepaint(_LayerEdgePainter oldDelegate) =>
      oldDelegate.geometry != geometry || oldDelegate.theme != theme;
}

/// Paints [KitWorkGraphGeometry.rows]'s gutter links: straight lane runs,
/// same tones as `layers`.
class _RowEdgePainter extends CustomPainter {
  _RowEdgePainter({
    required this.geometry,
    required this.theme,
    required this.hairline,
    required this.focusWidth,
    required this.textDirection,
  });

  final KitWorkGraphGeometry geometry;
  final ThemeData theme;
  final double hairline;
  final double focusWidth;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final roles = AppTheme.rolesOf(theme);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.save();
    if (textDirection == TextDirection.rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    for (final edge in geometry.edges) {
      final path = edge.toPath();
      paint
        ..strokeWidth = edge.critical ? focusWidth : hairline
        ..color = edge.blocked
            ? roles.text1
            : edge.critical
            ? roles.text2
            : roles.text3;
      canvas.drawPath(
        edge.blocked ? _dashed(path, KitTokens.graphDash) : path,
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RowEdgePainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.theme != theme ||
      oldDelegate.textDirection != textDirection;
}
