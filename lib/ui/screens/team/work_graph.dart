/// Retired by kit-KitWorkGraph: the Work tab's Graph view now lives at
/// `package:opencode_mobile/ui/kit/kit_work_graph.dart` as `KitWorkGraph`.
///
/// This file stays as the forwarder the retired run page used; Task
/// details maps its steps through [WorkGraphNode.of] and `toKit`: [WorkGraph], [WorkGraphNode] (with `.of`),
/// [WorkGraphLayout] (thin now — it maps straight onto
/// [KitWorkGraphGeometry.layers], so its output is unchanged for the same
/// node size), [WorkGraphEdge] and [WorkGraphPainter] keep their
/// signatures (KIT-43); no `@Deprecated` (KIT-43 overrides R11/R12).
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../orchestration/models/work.dart';
import '../../kit/kit_image.dart';
import '../../kit/kit_task_mark.dart';
import '../../kit/kit_tokens.dart';
import '../../kit/kit_work_graph.dart';
import '../../theme_roles.dart';
import '../../widgets/team_vocabulary.dart';

/// Retired by kit-KitWorkGraph: use [KitWorkGraphNode].
///
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

  /// The graph's one WorkState → KitTaskState mapping: a real "needs you"
  /// mark only for a state that truly needs the person, never for
  /// "blocked" alone (LOOK-4). The word always comes from
  /// [teamWorkStateWord], so the chip and row say the true state.
  ///
  /// Contract problem (this unit's QA record): KitWorkGraph.md asks for
  /// "the blocked glyph" and for the host to map each state once through
  /// `teamWork*` (ARCH-8), but [KitTaskState] has no blocked (or queued,
  /// ready, review) value and `teamWorkGlyph` returns an icon and tone, not
  /// a [KitTaskState]. Until the coordinator decides (a `KitTaskState`
  /// value, or a `teamWorkMark` beside `teamWorkGlyph` in
  /// `widgets/team_vocabulary.dart`, owned by another unit), this is the
  /// only copy of the mapping, and KitWorkGraph shows a stuck item's word
  /// visibly on its layers chip and rows line so it never reads as waiting.
  KitTaskState get _mark => switch (state) {
    WorkState.needsInput => KitTaskState.needsYou,
    WorkState.completed => KitTaskState.done,
    WorkState.failed => KitTaskState.failed,
    WorkState.cancelled => KitTaskState.stopped,
    WorkState.working || WorkState.review => KitTaskState.working,
    WorkState.queued ||
    WorkState.ready ||
    WorkState.waiting ||
    WorkState.blocked ||
    WorkState.unknown => KitTaskState.waiting,
  };

  KitWorkGraphNode toKit(AppLocalizations l10n) => KitWorkGraphNode(
    id: id,
    title: title,
    mark: _mark,
    word: teamWorkStateWord(l10n, state),
    dependsOn: dependsOn,
    stuck: teamWorkIsStuck(state),
    open: teamWorkIsOpen(state),
  );
}

/// Retired by kit-KitWorkGraph: use [KitWorkGraphEdge].
///
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

  WorkGraphEdge._of(KitWorkGraphEdge e)
    : from = e.from,
      to = e.to,
      start = e.start,
      control1 = e.control1,
      control2 = e.control2,
      end = e.end,
      critical = e.critical,
      blocked = e.blocked;

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

  /// Both ends in the blocked chain: drawn dashed in `text1` (LOOK-4:
  /// never the attention tone).
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

/// Retired by kit-KitWorkGraph: use [KitWorkGraph].
///
/// Deterministic layered layout of a [WorkGraphNode] list. A thin mapping
/// onto [KitWorkGraphGeometry.layers], which keeps today's output for the
/// same node size (KitWorkGraph.md Notes).
class WorkGraphLayout {
  WorkGraphLayout._(this._geometry, this.nodes);

  final KitWorkGraphGeometry _geometry;

  /// The retired default chip size at 1x text (KIT-43 keeps the
  /// signature). `KitWorkGraph` itself sizes chips from its tokens:
  /// [KitTokens.graphNodeWidth] wide, at least [KitTokens.minTarget] tall.
  static const defaultNodeSize = Size(KitTokens.graphNodeWidth, 44);
  static const columnGap = KitTokens.graphColumnGap;
  static const rowGap = KitTokens.graphRowGap;
  static const padding = 16.0;

  /// The nodes in input order, duplicates (by id) dropped.
  final List<WorkGraphNode> nodes;

  /// Where each node sits, by id.
  Map<String, Rect> get rects => _geometry.rects;

  /// Node ids per row, top row first, left to right.
  List<List<String>> get layers => _geometry.layerRows;
  List<WorkGraphEdge> get edges => [
    for (final e in _geometry.edges) WorkGraphEdge._of(e),
  ];

  /// The longest chain of `needs` links, upstream first. One id when no
  /// edge exists; empty when the graph is empty.
  List<String> get criticalPath => _geometry.criticalPath;

  /// Stuck items (blocked, needs input, failed), everything downstream of
  /// them and the open items they wait on.
  Set<String> get blockedChain => _geometry.blockedChain;

  /// The painted area, padding included.
  Size get size => _geometry.size;

  /// Consecutive pairs of [criticalPath] as (from, to).
  Set<(String, String)> get criticalEdges => _geometry.criticalEdges;

  WorkGraphNode? nodeAt(Offset point) {
    final hit = _geometry.nodeAt(point);
    if (hit == null) return null;
    for (final node in nodes) {
      if (node.id == hit.id) return node;
    }
    return null;
  }

  static WorkGraphLayout compute(
    List<WorkGraphNode> input, {
    Size nodeSize = defaultNodeSize,
  }) {
    // The retired API has no BuildContext/AppLocalizations; the word never
    // reaches the pure-geometry mapping, so a bare English fallback stands
    // in (this class only ever fed positions, never displayed text).
    final l10n = lookupAppLocalizations(const Locale('en'));
    final index = <String>{};
    final unique = <WorkGraphNode>[
      for (final node in input)
        if (index.add(node.id)) node,
    ];
    final geometry = KitWorkGraphGeometry.layers([
      for (final node in unique) node.toKit(l10n),
    ], nodeSize: nodeSize);
    return WorkGraphLayout._(geometry, unique);
  }
}

/// Retired by kit-KitWorkGraph: use [KitWorkGraph]
/// (`KitWorkGraph(layout: KitWorkGraphLayout.layers)`).
///
/// The graph view: pinch-zoom, drag-pan, Fit, node tap. Forwards to
/// [KitWorkGraph] as the retired run page's Graph view did, keeping the `team-work-graph-*` keys (TEST-5).
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
  KitZoomController? _zoom;

  KitZoomController _zoomFor(TransformationController? host) {
    final existing = _zoom;
    if (existing != null) return existing;
    return _zoom = KitZoomController(transformation: host);
  }

  @override
  void dispose() {
    _zoom?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = lookupAppLocalizations(Localizations.localeOf(context));
    return KitWorkGraph(
      nodes: [for (final node in widget.nodes) node.toKit(l10n)],
      onOpen: widget.onNodeTap,
      layout: KitWorkGraphLayout.layers,
      zoomController: _zoomFor(widget.transformationController),
      viewerKey: const ValueKey('team-work-graph-viewer'),
      canvasKey: const ValueKey('team-work-graph-canvas'),
      fitKey: const ValueKey('team-work-graph-fit'),
    );
  }
}

/// Retired by kit-KitWorkGraph: use [KitWorkGraph], whose nodes are
/// widgets now, not paint.
///
/// Stays exported, painting the links only (KitWorkGraph.md Notes): the
/// same curves, arrow heads, tones and widths as `KitWorkGraph`'s `layers`
/// form, from [theme]'s roles, and no nodes. [l10n], [textScaler] and
/// [onNodeTap] are kept for the signature (KIT-43) and unused.
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

  @override
  void paint(Canvas canvas, Size size) => kitWorkGraphPaintLinks(
    canvas,
    size,
    layout._geometry,
    ThemeRoles.resolve(theme),
    // No BuildContext here: one logical pixel stands in for the one
    // physical pixel `KitWorkGraph` draws, and two for the critical path.
    hairline: 1,
    focusWidth: 2,
    textDirection: textDirection,
  );

  @override
  bool shouldRepaint(WorkGraphPainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.theme != theme ||
      oldDelegate.textDirection != textDirection;
}
