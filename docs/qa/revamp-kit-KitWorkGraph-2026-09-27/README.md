# revamp-kit-KitWorkGraph: Build KitWorkGraph (2026-09-27)

## 1. Scope

- Unit: `kit-KitWorkGraph` (wave 1, kit-part). Finish line: `KitWorkGraph`
  renders a team task's work-item dependency graph as `rows` on a compact
  window and `layers` (zoomable, fitted on open) from medium up, with real
  focusable/hoverable node widgets, and `lib/ui/screens/team/work_graph.dart`
  forwards to it so `run_screen.dart`'s call site is unchanged. Non-goal:
  editing dependencies, drag, filtering, or placing the graph anywhere new
  (P3.5's job).
- Files changed: `lib/ui/kit/kit_work_graph.dart` (new),
  `lib/ui/screens/team/work_graph.dart`, `lib/l10n/app_en.arb` (the
  generated `app_localizations*.dart` are the integrator's: the branch now
  sits on `feat/phone-setup-v2` after the integrator's gen-l10n, so it
  carries no generated l10n diff of its own), `test/team_work_graph_test.dart`,
  `test/team_work_tab_test.dart`, `test/kit/kit_work_graph_test.dart` (new),
  `test/goldens/kit/kit_work_graph_golden_test.dart` (new) + 12 PNGs.
- Pages (map ids): `embedded-work-graph`.
- Specs followed: `docs/ux-system/kit-api/KitWorkGraph.md` (frozen API);
  kit-v2.md §5, §9.2; STANDARDS.md KIT-1, KIT-9, KIT-12, KIT-43, LOOK-4,
  LOOK-5, LOOK-6, LOOK-21, STATE-9, LAY-8, LAY-9, LAY-10, A11Y-1, A11Y-2,
  A11Y-4, A11Y-5, MOT-2, MOT-7.
- Contract problems (PROC-20):
  - `KitWorkGraph.md`'s Public API block names both a static factory and an
    instance field `layers` on `KitWorkGraphGeometry`. Dart refuses a static
    member and an instance member sharing a name
    (`conflicting_static_and_instance`; confirmed with `dart analyze`).
    Kept the factory's name (call sites read it as a verb: `.layers(...)`);
    the field is `layerRows` instead. `blocks: false` — noted in the
    implementation's doc comment and here; every test reads the field by
    its new name.
  - **KitTaskState has no blocked value** (review round 1, finding 3;
    `blocks: false`, the coordinator decides). KitWorkGraph.md asks a
    blocked row for "the blocked glyph" and says the host maps each state
    once through the `teamWork*` functions (ARCH-8), but `KitTaskState` is
    `{waiting, working, done, failed, needsYou, stopped}` and
    `teamWorkGlyph` returns `(IconData, AppStatusTone)`, not a
    `KitTaskState`. So the spec's blocked glyph cannot be drawn, and the
    wrapper holds the only WorkState → KitTaskState mapping
    (`WorkGraphNode._mark`: blocked, queued, ready, waiting, unknown →
    waiting; working, review → working). Options for the coordinator: add
    `KitTaskState.blocked` (kit-KitStatusMark-v2's unit), or add a
    `teamWorkMark` beside `teamWorkGlyph` in
    `lib/ui/widgets/team_vocabulary.dart` (outside this unit's write set).
    Until then the graph never lets a blocked item read as waiting: its
    word ("Blocked", from `teamWorkStateWord`) is visible on the rows
    supporting line and — new in this round — on a second line of its
    layers chip, and its title is semibold with a `text1` border / dashed
    `text1` links.
- Dependency gap (round 1): resolved. `kit-KitTappable` merged into
  `feat/phone-setup-v2` (097c9079); this round fast-forwarded the branch
  onto `feat/phone-setup-v2` (024e97b0) and deleted the local
  `_GraphNodeButton` substitute. Every node is now a `KitTappable`
  (label, tooltip, `tappableKey: nodeKey`, token shape and surface) holding
  a `KitTaskMark` and `KitText`; the rows hint goes through
  `MergeSemantics` + `Semantics(hint:)`.
- Additive note: `kitWorkGraphPaintLinks` is a top-level function in
  `kit_work_graph.dart` shared by `KitWorkGraph` and the retired
  `WorkGraphPainter` (which now paints the links again, as the spec's Notes
  require). It is not in the frozen API; the kit barrel should not export
  it. The unfrozen `KitWorkGraphGeometry.defaultNodeSize` (156×44) moved
  to the retired `WorkGraphLayout.defaultNodeSize` (its only user).
- New kit parts (KIT-3): none.
- Map items (EVID-11): `embedded-work-graph#work-graph`
  → done: `test/kit/kit_work_graph_test.dart`, `test/team_work_graph_test.dart`,
  `test/team_work_tab_test.dart`, `test/goldens/kit/kit_work_graph_golden_test.dart`.
  The map's `statesMissing` entry "large graph on a phone" → done: the
  `rows` layout (`kit_work_graph_rows_*.png`).
- States per page (STATE-20): laid out (rows/layers goldens), empty
  (`kit_work_graph_empty_*.png`), one item (`kit_work_graph_one_*.png`),
  blocked chain (`kit_work_graph_rows_blocked_*.png`, and the blocked chain
  in `kit_work_graph_layers_*.png`), needs you (the `e` node in the
  six-item fixture, all rows/layers goldens) → tests/goldens above.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitWorkGraph`. Round 1: base `dcf05c5e`, code head
  `73d5f37d`. Round 2 (review fixes): fast-forwarded to
  `feat/phone-setup-v2` `024e97b0` (which already contains round 1 via
  `aa98068d`), fixes committed on top.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator/checkpoint
work (R19, R20).

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `dart analyze lib/ui/kit/kit_work_graph.dart lib/ui/screens/team/work_graph.dart` | no issues | no issues | PASS |
| 2 | `flutter test -j 1 test/kit/kit_work_graph_test.dart` | all pass | 11 passed | PASS |
| 3 | `flutter test -j 1 test/goldens/kit/kit_work_graph_golden_test.dart` | all pass, goldens stable (no `--update-goldens`) | 12 passed | PASS |
| 4 | `flutter test -j 1 test/team_work_graph_test.dart test/team_work_tab_test.dart` | all pass | 17 passed | PASS |
| 5 | `flutter test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart` | all pass, no new findings | 33 + 14 passed | PASS |
| 6 | `flutter analyze --no-pub` (whole repo) | no new issues in changed paths | 6 pre-existing issues, none in files this unit touched (`kit_image_test.dart`'s `KitIconButton.label`, `kit_since.dart`'s `clock` package — both pre-date this branch) | PASS |
| 7 | Round 2: `flutter analyze --no-pub` on the six changed Dart files | no issues | no issues | PASS |
| 8 | Round 2: `flutter test -j 1 test/kit/kit_work_graph_test.dart` | all pass | 28 passed (`run-kit-work-graph-test.txt`) | PASS |
| 9 | Round 2: `flutter test -j 1 test/team_work_graph_test.dart`, then `test/team_work_tab_test.dart` | all pass | 9 + 8 passed (`run-team-work-*.txt`) | PASS |
| 10 | Round 2: `flutter test -j 1 --update-goldens test/goldens/kit/kit_work_graph_golden_test.dart`, images opened, then the same without `--update-goldens` | all pass, stable | 12 + 12 passed (`run-goldens-*.txt`) | PASS |
| 11 | Round 2: `flutter test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart` | all pass | 48 passed (`run-ratchet-design.txt`) | PASS |
| 12 | Round 2 failing-first: the new two-line-title test against round 1's kit file | fails | overflowed by 4.2 px (`failing-first.txt`) | PASS |

## 5. Evidence

- Fix round 2 (review of round 1), finding by finding:
  1. `_GraphNodeButton` deleted; nodes are `KitTappable` (see Scope).
  2. Rows no longer get a fixed computed height: `rows` is a `Column` of
     intrinsic-height rows (floor `rowHeightTwoLine`), each painting its own
     slice of the gutter, so a wrapped title grows its row.
     `failing-first.txt` shows round 1 overflowing by 4.2 px; the new test
     "a two-line title grows its row, no overflow" (text 1.0 and 2.0) and
     the overflow sweep now pass. Layers chip heights come from KitText's
     real `rowTitle`/`secondary` line heights, rounded up to the physical
     pixel.
  3. Contract problem listed (Scope); stuck items show their word on layers
     chips too.
  4. Rows have no fill or radius of their own (`KitShape.square`, only
     KitTappable's hover/pressed fills). Layers chips keep `KitSurface`
     `surface1` with a hairline border (`text1` in the chain).
  5. Rows gutter links have a stub into the row at both ends (the needed
     row's leaves just below its centre, the dependent's arrives just above
     it) and an arrow head at the dependent end, in the link's tone, width
     and dash; lane x and stub y are snapped to the physical pixel grid
     (half-pixel offset for 1-px strokes).
  6. Generated l10n: the branch now sits on the integrator's regenerated
     output, so it has no `app_localizations*.dart` diff of its own.
  7. `WorkGraphPainter.paint` paints the links again through
     `kitWorkGraphPaintLinks` (same curves, arrow heads, tones, widths).
  8. New behaviour tests: keyboard (Tab order in layers then the zoom pill,
     Tab order in rows, Enter/Space open, Ctrl+0 restores the fit), Fit
     (fitted, centred, Fit control restores), between-chips tap in layers,
     semantics for layers nodes, the viewer label, the zoom buttons and the
     viewer's custom actions, a painted-pixel tone scan in rows and layers
     (replacing the `Icon.color` check), the overflow sweep at 320×740,
     412×915, 1280×800 and 915×412 × text 1.0 and 2.0 with a two-line title,
     and the reduced-motion single-pump check.
  9. Gallery: `b` is `working` (accent mark, LOOK-6). The blocked chain gets
     semibold `rowTitle` titles, its host word "Blocked", dashed `text1`
     links, and in layers a `text1` border; the blocked glyph itself is the
     contract problem above. `rows_blocked`'s stuck title now wraps to two
     lines. All 12 goldens re-rendered and opened before keeping.
  10. Layers nodes use `PositionedDirectional` (and the link painter mirrors
     in RTL); spacing from `KitTokens` (`space1`–`space3`, `minTarget`,
     `rowHeightTwoLine`); named constants for the arrow head and the pure
     geometry's padding/lane width (documented as the tokens' values, since
     the geometry has no BuildContext and its layers output must stay the
     retired layout's); `WorkGraphEdge.blocked`/`KitWorkGraphEdge.blocked`
     docs say dashed `text1`.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-43 (old API keeps its signature) | `test/team_work_tab_test.dart` "a graph node opens the Work sheet; the chain is drawn" | run 4 above |
  | LOOK-4 (blocked ≠ needs you) | `test/kit/kit_work_graph_test.dart` "the blocked chain paints no attention colour" | run 2 above |
  | STATE-9 (state never colour-only) | `test/kit/kit_work_graph_test.dart` "each node is a button labelled …" | run 2 above |
  | LAY-3/auto breakpoint | `test/kit/kit_work_graph_test.dart` "412x915 renders rows" / "1280x800 renders layers" / "915x412 (short) renders rows" | run 2 above |
  | TEST-11 (deterministic, duplicate ids) | `test/kit/kit_work_graph_test.dart` "layers is deterministic and matches the retired layout" | run 2 above |
  | LOOK-21 (stroke widths from KitTokens) | `test/kit_ratchet_test.dart` "G21 look and motion" | run 5 above |

- Changed test expectations (TEST-19 (1)):
  - `test/team_work_graph_test.dart`, "fits on first layout, taps a node,
    Fit restores": the six-item fixture's canvas height changed 352 → 368
    (LAY-9: the widget's node-size floor is now 48dp, not the retired
    44dp), and the fit translation changed accordingly; a manual coordinate
    tap now waits `kDoubleTapTimeout` before checking (KitZoom's own
    `onDoubleTap` + `onTap` + `onScaleStart` on one `GestureDetector`, KitImage.md).
  - `test/team_work_graph_test.dart`, "a large graph is scaled down to fit;
    never below 0.2": the fit scale and translation changed because KitZoom's
    canvas fit carries no extra margin (KitImage.md), unlike the retired
    `WorkGraph._fit`'s 12dp one.
  - Round 2, `test/team_work_graph_test.dart` "fits on first layout…" and
    `test/team_work_tab_test.dart` "a graph node opens the Work sheet": the
    chip height is 58, not 48, because the fixtures have a stuck item and
    every chip then holds a second line for its state word (finding 3):
    canvas 368×408, fit translation y (600 − 408) / 2, node size 156×58.
  - `test/team_work_tab_test.dart`, "a graph node opens the Work sheet":
    `tester.widget<InteractiveViewer>` → `tester.widget<KitZoom>` (KitImage.md
    replaces `InteractiveViewer` at every call site), the fixture's node
    size (156×48), and the same `kDoubleTapTimeout` wait.
- Goldens changed (round 2): all 12 re-rendered and opened — rows now sit
  on the host (no cards), with stubs and arrow heads in the gutter; the
  working mark shows; layers chips show "Blocked" on the stuck chip.
- Goldens (round 1): all 12 are new (no prior `kit_work_graph_*` goldens
  existed). Each was rendered once, opened and looked at (see the four
  images described inline in this session) before being kept. No VL canvas
  render was approved for this part yet, so EVID-12 is "none".
- Before and after (EVID-10): n/a — no prior golden or census PNG existed
  for `embedded-work-graph`'s graph element under this name; "no before
  render", page id `embedded-work-graph`.
- Accessibility: each node is one `Semantics(button: true)` node labelled
  `kitWorkGraphNode` ("{title}, {state}"); in `rows` its hint names the
  first dependency (`kitWorkGraphNeeds`/`kitWorkGraphNeedsMore`); the
  `layers` viewer is one container labelled "Work graph" (via `KitZoom`);
  Zoom in/out/Fit are 48dp `KitIconButton`s with labels (`KitZoom`'s own,
  unchanged). 200% text and the 320–1280 size sweep were checked in the
  retained `test/team_work_graph_test.dart` overflow test ("chips grow with
  the text") and the goldens' 1280×800 shot, not the full G6 matrix (see
  NOT proven).
- Privacy and security: n/a — no credentials, stored data, external links
  or notifications changed. The part is read-only (a tap only reports an id).
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_work_graph_test.dart
$F test -j 1 test/goldens/kit/kit_work_graph_golden_test.dart
$F test -j 1 test/team_work_graph_test.dart test/team_work_tab_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart
$F analyze lib/ui/kit/kit_work_graph.dart lib/ui/screens/team/work_graph.dart
```

## 7. NOT proven

- **KitTaskState has no blocked value** (contract problem above): a blocked
  item shows the waiting mark with its word, not a blocked glyph.
- **Layers does not scroll a focused node into view** (KitWorkGraph.md
  Adaptive, "In layers the canvas scrolls a focused node into view"):
  `KitZoomController` has no "show this rect" call; with the graph fitted
  on open every node is already visible, but after a zoom Tab can land on
  a node outside the viewport.
- Not run on a device or emulator (R19/R20: coordinator work).
- The frozen spec's fuller gallery matrix (five window sizes, Arabic, 2.0
  text) is out of scope by the owner's 2026-09-27 decision; only 412×915
  and 1280×800, light and dark, are proven (12 PNGs, not the spec's 24).
- RTL is not reviewed or tested (owner decision). Both forms now mirror
  (rows: gutter at the start, painter flipped; layers:
  `PositionedDirectional` and a flipped link painter), but no Arabic test
  or golden proves it.
- The overflow sweep covers 320×740, 412×915, 1280×800 and 915×412 at text
  1.0 and 2.0 (LTR); 600, 840, text 1.3 and RTL from the spec's #11 are
  not run.
- Rows' dashed blocked links restart their dash phase at each row edge
  (each row paints its own gutter slice).
- `test/kit_ratchet_baseline.json` and the l10n coverage baseline are
  unedited (R05): the integrator regenerates them.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitWorkGraph` |
| Enabled | Yes: `lib/ui/screens/team/work_graph.dart`'s `WorkGraph` forwards to it, so `run_screen.dart`'s existing Graph tab uses it immediately | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | round 1 `73d5f37d`; round 2 fixes on `revamp/kit-KitWorkGraph` (see git log) |
| Deployed | No | |
| Released | No | |
