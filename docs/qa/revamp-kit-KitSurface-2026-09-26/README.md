# revamp-kit-KitSurface: Build KitSurface (2026-09-26)

## 1. Scope

- Unit: `kit-KitSurface` (wave 1, tier 1a, kind `kit-part`). Finish line: `KitSurface` exists in
  `lib/ui/kit/kit_surface.dart` with the frozen API (level/shape/padding, `.panel`, `.inset`,
  `.tile`), its states, its galleries and its contract tests; `KitPanel` forwards to it and its
  header icon moves 18 → 20 dp. Non-goal: no call site outside the kit changes, no screen is
  migrated, and `lib/ui/kit/kit.dart` is not touched (R06: the integrator adds the export and doc
  row).
- Files changed: `lib/ui/kit/kit_surface.dart` (new), `lib/ui/kit/kit_panel.dart` (rewritten as a
  forwarder), `test/kit/kit_surface_test.dart` (new), `test/goldens/kit/kit_surface_golden_test.dart`
  (new, 34 PNGs).
- Pages (map ids): none — a kit-part unit, no screen migration.
- Specs followed: `docs/ux-system/kit-api/KitSurface.md` (frozen API, in full); STANDARDS.md §1, §4,
  §5, §15, §16, §18 (KIT-9, KIT-23, KIT-42, KIT-43, LOOK-8, LOOK-19, LOOK-20, LOOK-21, LOOK-24,
  LOOK-33); kit-v2.md §8.2, §8.4, §9.1 (the allowlist my write set stays inside).
- Contract problems (PROC-20):
  1. **The task's own acceptance line contradicts the frozen spec.** The computed task text said
     "KitPanel = KitSurface.raised (icon 18 -> 20); KitGlass stays and KitSurface.glass delegates to
     it". `docs/ux-system/kit-api/KitSurface.md` explicitly overrides that exact wording in its
     "Contract resolution" section (citing STANDARDS §0.2, KIT-42, Appendix A #24 and #41): there is
     no "raised" level (it is `surface1`), and glass is **not** a level — `KitGlass` stays the one
     glass part and `KitSurface` never wraps it. This is not an open question: Appendix A #24/#41 in
     STANDARDS.md record it as already resolved, and `test/kit_ratchet_test.dart` enforces it as an
     **absolute** gate (G21, `KitSurfaceLevel.glass|raised|tonal` — no ratchet baseline allowed for
     it at all). Building `KitSurface.raised`/`KitSurface.glass` as the acceptance line asked would
     have failed that absolute gate outright. I built exactly the frozen spec's API instead (R16)
     and report the acceptance line as stale, likely carried over from kit-v2.md §9.2's original
     (pre-resolution) "plain, raised, tonal, glass" wording, which KitSurface.md itself quotes and
     overrides in the same breath.
  2. **The frozen spec's own gallery-size bullet has a transposed size.** "Default state (`panel`):
     at 360×800, **915×412**, 800×1280, 1280×800 and 1600×1000" — but kit-v2.md §8.4's G4 gallery
     sizes (the definitive list every other kit part's gallery uses, via the shared
     `kitGallerySizes` constant in `test/goldens/kit/kit_gallery.dart`) are 360×800, **412×915**,
     800×1280, 1280×800 and 1600×1000. 915×412 (landscape phone) is a G6 *overflow* width, not one
     of the five G4 gallery sizes anywhere else in the system. I followed `kitGallerySizes` (as
     every other part's gallery does) rather than the likely-transposed digits, and additionally
     covered `panel` at 412×915 under the "States" gallery bullet, so all five G4 sizes are present
     either way.
  3. **The QA folder name.** The task text says `docs/qa/revamp-<unit id>/README.md`; STANDARDS.md
     EVID-1 requires `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/README.md` (the record's own date rule).
     I followed STANDARDS.md, the named single rulebook, and used the date suffix.
- New kit parts (KIT-3): `KitSurface` (`lib/ui/kit/kit_surface.dart`), not exported from
  `lib/ui/kit/kit.dart` yet — R06, the integrator's step.
- Map items (EVID-11): n/a — no map pages in this unit's scope.
- States per page (STATE-20): n/a — a kit-part unit, not a screen.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitSurface`, base `b67e3276` (`feat/phone-setup-v2`), code head `9c68250e`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator/wave-checkpoint work.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_surface_test.dart` (`$F test -j 1`) | passes | 57 passed (30 behaviour + 27-case G6 overflow matrix) | PASS |
| 2 | `test/goldens/kit/kit_surface_golden_test.dart` (against the committed PNGs, no `--update-goldens`) | passes | 34 passed | PASS |
| 3 | `test/kit_ratchet_test.dart` | passes; `kit_panel.dart`'s G21 counts drop | 32 passed; logged "3 baseline entries dropped" (EdgeInsets numeric 2→1, SizedBox numeric 2→0, stroke width not KitTokens 1→0) — a drop is compliant (STANDARDS §1.1); the baseline JSON itself is integrator-owned (R05) | PASS |
| 4 | `test/design_standard_test.dart` | passes | 15 passed | PASS |
| 5 | `test/ui_glossary_test.dart`, `test/ui_ledger_coverage_test.dart`, `test/l10n_coverage_test.dart` | pass | 25 passed (combined run) | PASS |
| 6 | `test/kit/kit_manifest_test.dart` (G4) | may fail for `KitSurface`: unexported | failed: `exported`, `docRow` and `gallery` all name `KitSurface` — see §5 and "NOT proven" | FAIL (expected, reported) |
| 7 | Shared team screen/behaviour tests that build `KitPanel` (`team_board_test.dart`, `team_agent_screen_test.dart`, `team_merge_test.dart`, `team_motion_test.dart`, `team_agent_chat_render_test.dart`, `team_agent_chat_test.dart`, `team_policy_test.dart`, `team_controls_test.dart`, `team_now_test.dart`, `team_gate_answer_test.dart`, `team_usage_test.dart`, `test/goldens/team_sheets_golden_test.dart`) | pass | all passed (129 tests across the behaviour files, 6 in the sheets golden file) | PASS |
| 8 | `test/goldens/team_agent_golden_test.dart` | may fail: the 18→20 icon bump the frozen spec mandates | failed: 4 shots (`agent · top` and `agent · controls`, dark and light), each a 0.25 % / ~900 px pixel diff — see §5 and `sharedTestsBroken` | FAIL (expected, reported) |
| 9 | `flutter analyze lib test` (whole tree) | no errors; no new issues | no issues found (21 s) | PASS |

## 5. Evidence

- No fixes in this unit (a new part), so no `failing-first.txt` (TEST-2: "New code that fixes
  nothing needs no failing-first run").
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-42 (no raised/tonal/glass level) | `test/kit/kit_surface_test.dart` — every `levels`/`shapes` case, plus `KitPanel tone: attention keeps attentionSurface and attentionLine` (proves the retired path never touches `KitSurface`) | 57 passed |
  | LOOK-20 (no shadow, elevation 0) | `test/kit/kit_surface_test.dart` "levels … no shadow or elevation" (×4) | passed |
  | LOOK-21 (hairline exactly `1/devicePixelRatio`) | `test/kit/kit_surface_test.dart` "outlined paints a hairline edge at devicePixelRatio 2.625 and 3.0, never doubled" | passed |
  | KIT-43 (KitPanel forwards to KitSurface.panel) | `test/kit/kit_surface_test.dart` "KitPanel tone: neutral, default padding, no onTap equals KitSurface.panel" and "a custom padding still gets the panel fill and shape from KitSurface" | passed |
  | Panel shape clips a full-bleed child (18 dp) | `test/kit/kit_surface_test.dart` "shape: panel clips a full-bleed child to the 18 dp radius" (pixel probe: corner shows the ground, centre shows the child) | passed |
  | `KitSurface.tile` semantics (one image node / none) | `test/kit/kit_surface_test.dart` "KitSurface.tile: with semanticsLabel it has one image node; without, none" | passed |
  | RTL header icon at the right | `test/kit/kit_surface_test.dart` "under RTL the panel header icon sits at the right" | passed |
  | G6 overflow, no images | `test/kit/kit_surface_test.dart` group "G6 overflow matrix (no images)", 27 sizes×scales | passed |

- Changed test expectations (TEST-19): none — no existing test's expectation was edited.
- Goldens changed (new file; every PNG opened and looked at, TEST-6): I opened and visually
  confirmed `kit_surface_levels_{dark,light}.png` (each surface step's fill, plain and outlined,
  including the ground level's box being invisible against the ground background as expected),
  `kit_surface_panel_dark.png` (20 dp icon, headline title, and the no-header panel), a 4×-cropped
  `kit_surface_tile_dark.png` (all three tiles share one neutral `surface3` fill; only the glyph is
  tinted per `tone` — the danger/success icons' own filled triangle/circle artwork made this look
  like a tinted background at thumbnail size on first glance, so I cropped and zoomed to confirm the
  fill itself is uniform), `kit_surface_shapes_dark.png` (all ten `KitShape` values distinct),
  `kit_surface_inset_dark.png` (the sheet-mock surface with the nested inset panel one step down),
  and `kit_surface_panel_ar_dark.png` (RTL: icon on the right, Arabic type, Latin digits in "4 min"
  → "4 د"). The remaining 28 PNGs are the same scenes at other sizes/scales/themes rendered through
  the identical code paths already confirmed above; I did not open every one individually. No
  approved VL canvas render exists to compare against (EVID-12: none named for this unit).
- Before and after: n/a — no screen page changed; this is a new kit part plus a forwarder whose
  *default* rendering path is new (`KitSurface.panel`) and whose only visible change to existing
  screens is the header icon (18→20 dp) in the retired, non-neutral-tone path (§ "NOT proven" below
  names the one golden this moves).
- Accessibility: `KitSurface` adds no semantics node except `.tile` with `semanticsLabel` (verified:
  one `isImage`-flagged node with the label when given, none when not, via the real semantics tree,
  not the widget tree — `Icon` itself always wraps in a `Semantics(label: null)` widget regardless).
  200 % text: the panel header wraps (`maxLines`/`overflow` both null on its `Text`), proven at
  textScale 2 in a 200 dp-wide host with no overflow exception. RTL: the header icon sits at the
  visual right under `TextDirection.rtl` (proven, not just asserted). Every kit-gallery shot also
  runs the shared G5 accessibility checks (`expectKitGalleryAccessible`, both themes, every shot).
- Privacy and security: n/a — no credentials, stored data, links or notifications changed. `KitSurface`
  and `KitPanel` render only what their caller passes in; neither reads a server response.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_surface_test.dart test/goldens/kit/kit_surface_golden_test.dart \
  test/kit_ratchet_test.dart test/design_standard_test.dart test/ui_glossary_test.dart \
  test/ui_ledger_coverage_test.dart test/l10n_coverage_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator (no APK, per this unit's scope).
- `test/kit/kit_manifest_test.dart` (gate G4) fails for `KitSurface` on three checks, none fixable
  inside this unit's write set:
  - `exported` / `docRow`: `KitSurface` is not yet reachable from, or listed in the doc table of,
    `lib/ui/kit/kit.dart` — that file is explicitly the integrator's to change (R06).
  - `gallery`: the manifest's shot scanner recognises only `kitGalleryShot(...)` (modal parts) and
    literal `matchesGoldenFile(...)` calls in the gallery file's own source — not
    `kitGalleryPart(...)`, the shared helper for a **non-modal** part (`test/goldens/kit/kit_gallery.dart`:
    "a part that is not a modal: rows, buttons, cards, type"), which is what `KitSurface`'s gallery
    correctly uses. This is a pre-existing gap: `KitRequestCard` and `KitRowGroup` use the same
    helper in `kit_foundation_golden_test.dart` and are grandfathered in
    `test/kit/kit_manifest_allowlist.json` for exactly this reason. The allowlist "only shrinks" —
    a new part cannot be added to it — so this is reported (PROC-20), not routed around; the fix
    is either a coordinator tooling change (teach the scanner `kitGalleryPart(...)`) or a one-time
    allowlist exception.
  All three land in `sharedTestsBroken`, below.
- `test/goldens/team_agent_golden_test.dart` fails 4 of its shots (`agent · top` and
  `agent · controls`, dark and light; ~0.25 % pixel diff each) because the frozen spec's 18→20 dp
  icon bump changes `KitPanel`'s header, and these team screens render a `KitPanel` header. This is
  the intended, spec-mandated visual change rippling to an existing screen's golden, not a
  regression; per R07 I looked at the diffs (via the failing run's own pixel-diff percentage) and
  left the committed PNGs untouched (`git checkout -- test/goldens/failures/` after the run) rather
  than regenerate an integrator-owned golden myself.
- No approved visual-language canvas render exists for `KitSurface` to compare against (EVID-12
  names none).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitSurface` |
| Enabled | Yes (KitSurface is usable now; not yet reachable via the kit.dart barrel — R06) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `9c68250e` |
| Deployed | No | |
| Released | No | |
