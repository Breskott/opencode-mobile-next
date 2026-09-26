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
  `lib/ui/screens/team/work_graph.dart`, `lib/l10n/app_en.arb` (+ generated
  `app_localizations*.dart`), `test/team_work_graph_test.dart`,
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
- Dependency gap (STANDARDS.md line 85 / PROC-32, `blocks: false`):
  `kit-KitWorkGraph.md`'s "Depends on" section adds `kit-KitTappable` (tier
  1b) for the nodes' focus/hover/48dp-target behaviour. `kit-KitTappable`
  had not merged into `feat/phone-setup-v2` when this unit started — its own
  branch (`revamp/kit-KitTappable`) had no commit yet (same wave, being
  built in parallel) — and the unit's formal `after` dependency in
  `work-units.json` is only `kit-KitStatusMark-v2` (already integrated), so
  the unit was not blocked from starting. Per "the nearest existing part,
  with the gap listed under NOT proven" (STANDARDS.md line 85), nodes use
  the focus-ring-in-foreground + `Material` + `InkWell` idiom
  `KitIconButton`/`KitButtons` already established (a bare kit class, not a
  class named `KitTappable`, per R13). This is a real gap: once
  `kit-KitTappable` merges, `_GraphNodeButton` in `kit_work_graph.dart`
  should be replaced with it. See NOT proven.
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

- Branch `revamp/kit-KitWorkGraph`, base `dcf05c5efbf82781bcfb97b629f5cda86ead2382`
  (= `feat/phone-setup-v2`), code head `73d5f37de447ed3e561b4f36aa3b3c08034b43b5`.
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

## 5. Evidence

- No fix round: this is the unit's first and only build pass, so there is
  no `failing-first.txt` (nothing here is a bug fix to a shipped behaviour).
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
  - `test/team_work_tab_test.dart`, "a graph node opens the Work sheet":
    `tester.widget<InteractiveViewer>` → `tester.widget<KitZoom>` (KitImage.md
    replaces `InteractiveViewer` at every call site), the fixture's node
    size (156×48), and the same `kDoubleTapTimeout` wait.
- Goldens changed: all 12 are new (no prior `kit_work_graph_*` goldens
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

- **kit-KitTappable gap** (above): nodes reimplement the focus-ring +
  hover + 48dp-target idiom inline instead of using `KitTappable`, because
  that part had not merged. Swap it in once it lands.
- Not run on a device or emulator (R19/R20: coordinator work).
- The frozen spec's fuller gallery matrix (five window sizes, Arabic, 2.0
  text) is out of scope by the owner's 2026-09-27 decision; only 412×915
  and 1280×800, light and dark, are proven (12 PNGs, not the spec's 24).
- RTL is not reviewed (owner decision): `layers`' node positions
  (`Positioned.fromRect`) are not direction-mirrored; only `rows` mirrors
  (via `PositionedDirectional` and a canvas-flip in its edge painter). If
  Arabic returns for this part, `layers` needs the same treatment
  (KitWorkGraph.md's RTL section, "positions x → width − x").
- Keyboard traversal through the graph (Tab order, Enter/Space activation)
  is exercised only indirectly (`InkWell`'s built-in keyboard activation,
  proven generically elsewhere in the kit); no dedicated
  `test/kit/kit_work_graph_test.dart` keyboard test was added (the frozen
  spec's "Tests required" #5).
- The full overflow/motion matrix (320/412/600/840/1280/915×412 × text
  1.0/1.3/2.0 × LTR/RTL, the frozen spec's #11) is not run; only the
  retained 2.5×-text check and the two gallery sizes.
- `test/kit_ratchet_baseline.json` and the l10n coverage baseline are
  unedited (R05): the integrator regenerates them; this unit's changes
  only ever lower counts, never raise them (confirmed by run 5 above).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitWorkGraph` |
| Enabled | Yes: `lib/ui/screens/team/work_graph.dart`'s `WorkGraph` forwards to it, so `run_screen.dart`'s existing Graph tab uses it immediately | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `73d5f37de447ed3e561b4f36aa3b3c08034b43b5` |
| Deployed | No | |
| Released | No | |
