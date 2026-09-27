/// Retired by kit-KitWorkGraph: the Work tab's Graph view now lives at
/// `package:opencode_mobile/ui/kit/kit_work_graph.dart` as `KitWorkGraph`.
///
/// What stays is what `run_screen.dart` (today's only caller) still uses:
/// [WorkGraphNode], the one mapping from the app's work item to a
/// `KitWorkGraphNode` (the kit reads no app model), and [WorkGraph], which
/// forwards to `KitWorkGraph` with the `team-work-graph-*` keys. The retired
/// layout, edge and painter are gone (kit-hygiene): geometry is
/// `KitWorkGraphGeometry.layers`. This file goes with run_screen.dart
/// (slice-P3.5).
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../orchestration/models/work.dart';
import '../../kit/kit_image.dart';
import '../../kit/kit_task_mark.dart';
import '../../kit/kit_work_graph.dart';
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

/// Retired by kit-KitWorkGraph: use [KitWorkGraph]
/// (`KitWorkGraph(layout: KitWorkGraphLayout.layers)`).
///
/// The graph view: pinch-zoom, drag-pan, Fit, node tap. Forwards to
/// [KitWorkGraph] so today's only caller (`run_screen.dart:1316`) behaves
/// as before, keeping the `team-work-graph-*` keys (TEST-5).
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
