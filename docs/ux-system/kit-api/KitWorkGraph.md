# KitWorkGraph — API freeze (wave 0)

Unit: `kit-KitWorkGraph` (wave 1, tier 1c, kind `kit-part`, model sonnet), after kit-KitStatusMark-v2 (C25) plus kit-KitTappable and kit-KitImage (edges added, README.md). Spec: kit-v2.md §5 and §9.2 (Surfaces), with cut review C24 (`lib/ui/screens/team/work_graph.dart` moves from screen-team-4 into this unit) and C25 (WorkGraph = [StatusMark-v2]). The owner's verdict on `embedded-work-graph` is **Fix**; the map's rationale: "vertical one-node-per-row layout so names are readable, tone per state, fit on open; it stays one row away from the steps". Rules: KIT-1, KIT-9, KIT-12, KIT-43, LOOK-4, LOOK-5, LOOK-6, LOOK-21, STATE-9, LAY-8, LAY-9, LAY-10, A11Y-1, A11Y-2, A11Y-4, A11Y-5, MOT-2, MOT-7.

## Purpose

The dependency graph of a team task's work items, readable on a phone.

- **On a phone:** one item per row, with the `needs` links drawn in a narrow gutter at the start, and each row saying its state in words.
- **From a tablet up:** the layered graph (what is needed above what needs it), with the critical path and the blocked chain picked out, pinch and zoom, and "Fit" on open.

The graph is model-free: the host maps its work items to nodes.

## Replaces

- **Map element, 1 on 1 page:** `embedded-work-graph#work-graph` (kit-v2.json `assignment` → `module:special surface`; note: "CustomPainter + InteractiveViewer; labels truncated").
  - The owner's verdict is Fix.
  - The map's `statesMissing` entry "large graph on a phone" is this part's `rows` layout.
- **File in this unit's write set:** `lib/ui/screens/team/work_graph.dart` (614 lines; G16: `CustomPaint` 1, `GestureDetector` 1, `Icon` 1, `IconButton` 1, `InteractiveViewer` 1, `Positioned` 1). It becomes a forwarding file whose G16 count reaches zero:
  - `WorkGraph`, `WorkGraphNode` (with `.of(WorkItem)`), `WorkGraphLayout` (with `compute`, `rects`, `layers`, `edges`, `criticalPath`, `blockedChain`, `size`, `nodeAt`, `criticalEdges`), `WorkGraphEdge` and `WorkGraphPainter` keep their signatures (KIT-43);
  - `WorkGraph` forwards to `KitWorkGraph(layout: KitWorkGraphLayout.layers)`, so today's only caller (`run_screen.dart:1316`) behaves as before;
  - `WorkGraphNode.of` maps `WorkState` to a node with `teamWorkGlyph`, `teamWorkStateWord`, `teamWorkIsStuck` and `teamWorkIsOpen`, which stay in `widgets/team_vocabulary.dart`. The kit imports neither `lib/orchestration` nor `lib/ui/widgets`;
  - each is marked `/// Retired by kit-KitWorkGraph: use KitWorkGraph`, with no `@Deprecated` (KIT-43 overrides R11 and R12).
- **Look retired:**
  - the attention tone on the blocked chain (LOOK-4: blocked is not "needs you");
  - the 16 % tinted chip fills (LOOK-23: no tonal surfaces);
  - `IconButton.filledTonal` for Fit;
  - `scheme.onSurface.withValues(alpha: .75)` edges;
  - the literals `Radius.circular(12)`, `3.5`/`1.5` stroke widths and `156×44`.

## File

- `lib/ui/kit/kit_work_graph.dart` (new): `KitWorkGraph`, `KitWorkGraphNode`, `KitWorkGraphLayout`, `KitWorkGraphGeometry`, `KitWorkGraphEdge`.
- `lib/ui/screens/team/work_graph.dart` (the forwarding file).
- Tests: `test/kit/kit_work_graph_test.dart` (new). `test/team_work_graph_test.dart` and `test/team_work_tab_test.dart` import `work_graph.dart`, so they are this unit's own tests (PROC-10).
- Gallery: `test/goldens/kit/kit_work_graph_golden_test.dart`.

## Public API

```dart
/// One work item. The host maps its own model; the kit knows no WorkState.
@immutable
class KitWorkGraphNode {
  const KitWorkGraphNode({
    required this.id,
    required this.title,           // the item's title as written (COPY-2)
    required this.mark,            // KitTaskState: the leading mark and its tone
    this.paused = false,           // with waiting or working only (KitTaskMark's rule)
    this.word,                     // the state word; null = KitTaskMark.wordFor(mark)
    this.dependsOn = const [],     // ids this item needs; ids outside the graph are ignored
    this.stuck = false,            // blocked, needs input or failed: seeds the blocked chain
    this.open = true,              // not finished yet: something stuck may be waiting on it
  });
}

enum KitWorkGraphLayout {
  auto,   // rows on compact, layers from medium (the default)
  rows,   // one item per row, links in a start-side gutter; scrolls with its host
  layers, // the layered graph in a zoomable canvas, fitted on open
}

/// States: laid out, empty, one item (no links), blocked chain, needs you.
class KitWorkGraph extends StatefulWidget {
  const KitWorkGraph({
    super.key,
    required this.nodes,
    required this.onOpen,                 // ValueChanged<String>: the node's id
    this.layout = KitWorkGraphLayout.auto,
    this.emptyText,                       // String?: shown when nodes is empty; null = kitWorkGraphEmpty
    this.zoomController,                  // KitZoomController? layers only; wraps the wrapper's TransformationController, tests read .value
    this.viewerKey,                       // default ValueKey('kit-work-graph-viewer')
    this.canvasKey,                       // default ValueKey('kit-work-graph-canvas')
    this.fitKey,                          // default ValueKey('kit-work-graph-fit'); passed to KitZoom's resetControlKey
    this.nodeKey,                         // Key Function(String id)? for tests
  });
}

/// The pure, deterministic geometry (moved unchanged from WorkGraphLayout,
/// plus the rows form). No widgets; tests assert positions.
class KitWorkGraphGeometry {
  /// Longest-path layering, then a barycenter sweep, fixed node size, rows
  /// centred. UNCHANGED algorithm and output for the same inputs.
  static KitWorkGraphGeometry layers(List<KitWorkGraphNode> nodes, {required Size nodeSize});

  /// NEW. The same order as [layers] read top to bottom, start to end, one
  /// node per row; each link gets a lane in the gutter (greedy interval
  /// assignment, at most KitTokens.graphMaxLanes lanes; extra links share
  /// the last lane).
  static KitWorkGraphGeometry rows(List<KitWorkGraphNode> nodes,
      {required double width, required double Function(KitWorkGraphNode) rowHeight});

  final List<KitWorkGraphNode> nodes;       // input order, duplicates by id dropped
  final Map<String, Rect> rects;
  final List<List<String>> layers;          // rows: one id per list
  final List<KitWorkGraphEdge> edges;
  final List<String> criticalPath;          // longest chain of needs links, upstream first
  final Set<String> blockedChain;           // stuck items, everything downstream, and the open items they wait on
  final Size size;
  final double gutter;                      // rows: the links' gutter width; layers: 0
  Set<(String, String)> get criticalEdges;
  KitWorkGraphNode? nodeAt(Offset point);
}

@immutable
class KitWorkGraphEdge {
  // UNCHANGED fields from WorkGraphEdge: from, to, start, control1, control2,
  // end, critical, blocked; plus Path toPath().
  final int lane;                           // NEW: rows only; -1 in layers
}
```

Notes:

- **The layers geometry keeps today's output exactly** for the same node size, so `WorkGraphLayout.compute` stays a thin mapping and `team_work_graph_test.dart`'s layout group passes unchanged.
- **Nodes are widgets, not paint.** Each node is a `KitTappable` holding a `KitTaskMark` and `KitText`, positioned by the geometry. Only the links and arrow heads are painted. So every node is a Tab stop, a hover target and a semantics button; `CustomPainterSemantics` goes away. `WorkGraphPainter` stays exported (retired), painting the links only.
- **The wrapper passes today's keys:** `WorkGraph` passes `team-work-graph-viewer`, `team-work-graph-canvas` and `team-work-graph-fit` as `viewerKey`, `canvasKey` and `fitKey` (TEST-5).
- **Kit copy** (ARB, `kit` prefix, en and ar):
  - `kitWorkGraph` "Work graph" (the viewer's label);
  - `kitWorkGraphEmpty` "No work items yet";
  - `kitWorkGraphNode` "{title}, {state}" (replaces the use of `teamUiWorkGraphNodeSemantics`, which stays for the wrapper);
  - `kitWorkGraphNeeds` "needs {title}" and `kitWorkGraphNeedsMore` "needs {title} and {count, plural, …} more";
  - the zoom controls' words are KitZoom's (`kitZoomFit`, `kitZoomIn`, `kitZoomOut`; KitImage.md), one key per action (COPY-18).

## States

| State | rows | layers |
|---|---|---|
| laid out | every item on its row: mark, title (up to 2 lines), supporting line "{word} · needs {first dependency}" | chips in layers, links, fitted on open |
| empty | inline `KitStateView` with `emptyText` (the host decides whether the graph is shown at all) | the same |
| one item | one row, no gutter | one chip, centred |
| blocked chain | rows in the chain: the title in `rowTitle` semibold, the word "Blocked" (the host's `word`) and the blocked glyph; their links drawn dashed in `text1` | chips in the chain: a 1-physical-px `text1` border and dashed `text1` links |
| needs you | a node with `mark: needsYou` shows `KitNeedsYou`'s mark and word, the only attention colour in the part | the same |
| critical path | links on it are 2 physical px in `text2`; the others 1 physical px in `text3` | the same |

Loading and error are the host's (a task still loading shows its own skeleton). Nodes are always tappable, and the part has no disabled or working state. KIT-12 doc comment: "States: laid out, empty (+ blocked chain, needs you)".

## Tokens

- **ThemeRoles:**
  - node surface `surface1` with a 1-physical-px `hairline` border (layers);
  - rows sit on the host's panel;
  - titles `text1`, supporting line `text2`;
  - links `text3`, critical `text2`, blocked `text1` (dashed);
  - arrow heads the same as their link;
  - mark tones from `KitTaskMark`: `accent` working (LOOK-6), `success` done, `text1` failed (LOOK-5), `text2` waiting and stopped, `attention` only for needs you (LOOK-4);
  - the zoom pill `surface2`.
- **KitText:** `rowTitle` (node titles; one line in layers, two in rows), `secondary` (the rows' supporting line).
- **KitTokens:**
  - `minTarget` (48: the node height floor at 1× text, LAY-9);
  - `rowHeight` / `rowHeightTwoLine` (54 / 60: rows);
  - `iconTileSize` (30: the mark's box);
  - `panelCornerRadius` (18: node chips);
  - `space2`, `space3`, `space4` (the insides of a chip, lane spacing, padding);
  - `gutter`;
  - `hairlineWidth(context)` (1 px links and borders) and `focusRingWidth(context)` (2 px critical links reuse it; LOOK-21).
- **New tokens (pre-wave, `_new-tokens.md`):**
  - `KitTokens.graphNodeWidth` = 156 (layers chip width at 1×, grown with text as today);
  - `KitTokens.graphColumnGap` = 24 and `graphRowGap` = 48 (today's `columnGap` and `rowGap`);
  - `KitTokens.graphMaxLanes` = 6 (the rows gutter's lane cap);
  - `KitTokens.graphDash` = 4 (the dash length of blocked links).

  The old `WorkGraphLayout` constants stay as aliases of these.

## Adaptive

| Window | Layout |
|---|---|
| compact | `auto` → `rows`: full width of the host's rails. The gutter width is lanes × `space3`, at the start. The list scrolls with its host, with no zoom and nothing to fit, so "large graph on a phone" becomes a long, readable list. |
| medium | `auto` → `layers` in `KitZoom(mode: KitZoomMode.canvas)`, fitted on open (scale ≤ 1, never below `KitZoom.minScale` 0.2, as today); KitZoom's controls pill with Zoom out · Fit · Zoom in at the bottom end |
| expanded / large | the same, plus Ctrl+wheel zoom at the pointer, Ctrl+= and Ctrl+− and Ctrl+0 (Fit) once the canvas has focus, and a grab cursor while panning with a fine pointer |

- A window shorter than 480 dp keeps `rows` under `auto` (LAY-3).
- **Tab order (LAY-10):** nodes in geometry order, layer by layer and start to end, then the zoom pill. Enter or Space opens the focused node. In `layers` the canvas scrolls a focused node into view.
- **Hover:** a node shows `KitTappable`'s hover fill, and the tooltip repeats the full title when it was truncated (LAY-11, A11Y-8).

## Accessibility

- **Each node** is a button named `kitWorkGraphNode` ("Conflict policy, Blocked"), so state is never colour alone (STATE-9). In `rows` the supporting line ("needs Storage layer") is read as the node's hint.
- **The viewer** is one container labelled "Work graph". Traversal is top to bottom, then start to end (A11Y-4).
- **Pinch has visible twins** (A11Y-5): KitZoom's Zoom in, Zoom out and Fit, each a 48 dp `KitIconButton` with its label, 8 dp apart, and also semantic custom actions on the viewer.
- **200 % text:**
  - `rows` wrap titles to two lines and the rows grow;
  - `layers` chips grow with the text (width and height, as today), and the fit scale adapts;
  - nothing overflows at the G6 sizes;
  - the 2.5× critical-flow check at 320×740 still passes (today's test).
- **Truncation (A11Y-8):** a layers chip title may cut to one line. Its full title is in semantics and in its tooltip.

## RTL

- **`rows`:** the gutter sits at the start (the right in Arabic), lanes are numbered from the start edge, and the rows' text is start-aligned.
- **`layers`:** columns are laid out start to end, mirrored in RTL (positions `x → width − x`). Arrow heads point down in both directions. The zoom pill sits at the bottom end.
- **Titles** are the item's words, isolated with `KitBidi.auto` (COPY-30).

## Motion and haptics

- **Fit, Zoom in and Zoom out** are KitZoom's: they animate the transform on `KitMotion.standard` with `KitMotion.enter`, and jump under reduced motion.
- **Pinch** follows the fingers.
- **No layout animation:** a node that changes state changes at once (MOT-5).
- **No haptics** (MOT-11).
- **Reduced motion:** settles after one `pump()` (G8). The fit on open runs in the first post-frame callback, not as an animation.

## Data safety and honest state

- **Read-only:** the part changes nothing; a tap reports an id.
- **The words never contradict the graph:** the row word and the chip mark come from the same node field. A blocked item is never drawn "working", and the host maps each state once, through the wrapper's `teamWork*` functions (ARCH-8).
- **Links to ids outside the graph** are ignored, not invented (unchanged).
- **Duplicate ids:** the first one wins, deterministically (unchanged), so goldens and tests are stable (TEST-11).

## Depends on

- **kit-KitStatusMark-v2** (tier 1a): `KitTaskMark` with `paused`, `label` and `wordFor` (C25).
- **kit-KitTappable** (tier 1b; edge added, README.md): nodes as focusable, hoverable buttons. It moves this unit to tier 1c. Without it, the part would reimplement focus, hover and 48 dp targets (KIT-3, "one of each").
- **kit-KitNeedsYou** (tier 1b): the needs-you mark and word, already reached through KitStatusMark-v2's `KitTaskState.needsYou`. No new edge.
- **kit-KitImage** (tier 1a; edge added): `KitZoom` in canvas mode with `KitZoomController` and `resetControlKey` (KitImage.md).
- **Existing parts:** `KitStateView` (inline empty), `KitText`, `KitTokens`, `KitLayout`, `ThemeRoles`, `KitMotion`.
- **Pre-wave seams:** `KitTokens.hairlineWidth`/`focusRingWidth`, `KitBidi`.

Depended on by: whoever shows the graph after P3.5 retires `RunScreen` (Task details in the conversation). Until then, `run_screen.dart` goes through the wrapper.

## Tests required

In `test/kit/kit_work_graph_test.dart`:

1. **Determinism:** `KitWorkGraphGeometry.layers(six)` twice gives equal rects, layers, critical path and blocked chain. The positions equal `WorkGraphLayout.compute(six)`'s (the wrapper maps exactly).
2. **Rows:** `rows(six, width: 360, …)` puts one id per row in the layers' reading order. Every edge gets a lane below `graphMaxLanes`. No two edges whose row spans overlap share a lane while a free lane exists.
3. **Auto:** at 412×915 `auto` renders rows (no viewer key). At 1280×800 it renders layers with the viewer and Fit. At 915×412 (short) it renders rows.
4. **Open:** tapping a node in rows and in layers calls `onOpen` with its id once. Tapping between chips calls nothing.
5. **Keyboard (G14, desktop capabilities):** Tab visits nodes in geometry order, then the zoom controls; Enter on a node calls `onOpen`. Ctrl+0 restores the fitted transform after a zoom.
6. **Fit:** fitted on first layout (scale ≤ 1, ≥ 0.2, centred). After zooming, the Fit control (`fitKey`) restores the fitted transform.
7. **Semantics:** each node is a button labelled "{title}, {word}"; the rows' hint is "needs {title}". Zoom in, Zoom out and Fit exist as buttons and as custom actions on the viewer.
8. **Tones:** a blocked chain paints no `attention` colour. Only a `needsYou` node does, and it carries the word "Needs you" (a painted-colour scan and a finder).
9. **Wrapper:** `WorkGraph(nodes: [WorkGraphNode.of(item)…], onNodeTap:)` renders the layers form with the `team-work-graph-*` keys. `test/team_work_graph_test.dart` and `test/team_work_tab_test.dart` pass. Any expectation changed because nodes now have a 48 dp floor (LAY-9) is changed in the same commit and listed in the QA record with LAY-9 as the reason (TEST-19 (1)).
10. **RTL:** in Arabic, rows put the gutter on the right, and the first layer's first node is at the right end in layers.
11. **Overflow and motion:** no overflow at 320, 412, 600, 840, 1280 and 915×412 at text 1.0, 1.3 and 2.0, LTR and RTL (G6); settles after one `pump()` under reduced motion (G8).

## Galleries required

`test/goldens/kit/kit_work_graph_golden_test.dart`, DPR 3, Android, with the six-item fixture from `team_work_graph_test.dart` (done, working, blocked, needs you, queued, failed).

- **Declared states × dark and light at 412×915:**
  - `rows` (the default on compact);
  - `rows_blocked` (a chain of three);
  - `layers` (forced);
  - `empty`;
  - `one`.

  That is 10 PNGs.
- **Default (`auto`) × dark and light** at 360×800, 915×412 (rows), 800×1280, 1280×800 and 1600×1000 (layers): 10 PNGs.
- **Text 2.0 and Arabic** (`auto`) at 412×915 and 1280×800, dark: 4 PNGs.
- **Names:** `kit_work_graph_<state>[_ar][_text2][_WxH]_<dark|light>.png`. That is 24 PNGs.

## Non-goals

- **No editing of dependencies**, no drag, and no filtering.
- **No placement of the graph** in the team conversation or Task details: that is P3.5 and its screen units.
- **No change to how `WorkState` maps to words or glyphs:** that stays in `team_vocabulary.dart`.

## Open questions

None. The zoom question is settled in the cross-check (README.md, decision D17): KitImage.md now freezes `KitZoomController` (`reset()`, `zoomIn()`, `zoomOut()`, `value`), canvas fit-on-open and `resetControlKey`, so the layers form sits in `KitZoom` and the kit has one zoom part. The wrapper maps its `TransformationController` into `KitZoomController(transformation:)` and passes `team-work-graph-fit` as `fitKey`.
