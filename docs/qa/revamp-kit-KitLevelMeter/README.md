# revamp-kit-KitLevelMeter: KitLevelMeter (2026-09-27)

## 1. Scope

- Unit: `kit-KitLevelMeter` (wave 1, tier 1a, kit-part). Finish line: `KitLevelMeter`
  exists in its own file under `lib/ui/kit/`, has its full frozen API, every
  declared state, its galleries (TEST-9), its contract tests (TEST-15) and its
  structural asserts — export into `kit.dart` and adoption are the
  integrator's and the dependent units' (kit-KitComposer, screen-voice-1) work.
  Non-goal: no call site outside the kit changes; no adoption in
  `lib/voice/voice_ui.dart` or the composer (KitLevelMeter.md "Non-goals").
- Files changed (new, nothing else touched):
  - `lib/ui/kit/kit_level_meter.dart`
  - `test/kit/kit_level_meter_test.dart`
  - `test/goldens/kit/kit_level_meter_golden_test.dart`
  - `test/goldens/kit/kit_level_meter_*.png` (22 files)
  - `docs/qa/revamp-kit-KitLevelMeter/README.md` (this record)
- Pages (map ids): none — this is a kit-part unit, not a screen unit.
- Specs followed: `docs/ux-system/kit-api/KitLevelMeter.md` (frozen API,
  states, tokens, adaptive, accessibility, RTL, motion, data safety, tests
  and galleries required, verbatim); STANDARDS.md rules KIT-1, KIT-9, KIT-12,
  LOOK-1, LOOK-5, LOOK-6, LOOK-14, LOOK-21, LAY-8, MOT-5, MOT-7, MOT-11,
  A11Y-3, PERF-4; kit-v2.md §8.2 (adaptive: identical at every window class),
  §8.4 (gallery sizes and scaled sizes), §9.1 (kit-only allowlist), §9.2
  (`KitLevelMeter` named as a new part).
- Contract problems (PROC-20): three, all against the already-built gate
  `test/kit/kit_manifest_test.dart` (G4). The part was built exactly to the
  frozen spec in every case; the gate was not worked around, and none of
  these files are in this unit's write set.

  1. **States vocabulary.** KitLevelMeter.md's own text says: `KIT-12 doc
     comment: "States: listening, quiet, paused (decorative; not
     interactive)"`. `kit_level_meter.dart`'s doc comment uses that exact
     sentence. `kit_manifest_test.dart`'s states parser (`_statesFrom`)
     only accepts the fixed six-word KIT-12 vocabulary
     (`kitManifestStates` = loading, empty, error, disabled, working,
     answered) or the literal `none — <reason>` form; any other word fails
     as "unknown states". KitLevelMeter's states (listening/quiet/paused)
     are outside that vocabulary by design (the spec explains at length why
     none of the six generic states apply). Evidence:
     `docs/qa/revamp-kit-KitLevelMeter/manifest-run.txt` line
     `states · KitLevelMeter: unknown states listening, quiet, paused
     (decorative; not interactive)`. Proposed text: either (a) widen
     `_statesFrom` to accept a part's own documented vocabulary when its
     kit-api spec defines one, or (b) have the coordinator amend
     KitLevelMeter.md's doc-comment instruction to the gate's accepted
     `none — …` form (for example `States: none — decorative, not
     interactive, no data (see the states table below).`). Left at
     KitLevelMeter.md's literal instruction; blocks: G4 "states" for this
     part until the coordinator resolves it.
  2. **Gallery detector doesn't know `kitGalleryPart`.** `_Gallery` (in
     `kit_manifest_test.dart`) recognises shots only from `kitGalleryShot(`
     calls or a literal `matchesGoldenFile('...')` argument in the part's
     own golden file; `test/goldens/kit/kit_level_meter_golden_test.dart`
     (like every other non-modal part's gallery) uses `kitGalleryPart(`,
     whose `matchesGoldenFile` call lives inside the shared harness
     (`test/goldens/kit/kit_gallery.dart`), so the scanner sees zero shots
     and reports `lacks kitGallerySizes, kitGalleryScaledSizes, a …text2…
     golden at textScale: 2, an …_ar_… golden in Locale('ar')` even though
     the gallery renders all of those (22 PNGs, reviewed in §5). This is a
     pre-existing gate gap, not specific to this unit: every `kitGalleryPart`
     -based part already in the tree (`KitText`, `KitButton`, `KitRow`,
     `KitPanel`, `KitNotice`, `KitStateView`, …) is already grandfathered
     into `test/kit/kit_manifest_allowlist.json`'s `gallery` list for the
     same reason. `KitLevelMeter` cannot be added there: the allowlist only
     shrinks and a new entry outside `_creationAllowlist` (frozen
     2026-09-26) fails (KIT-44). Evidence:
     `docs/qa/revamp-kit-KitLevelMeter/manifest-run.txt` line `gallery ·
     KitLevelMeter: …`. Proposed text: extend `_Gallery`'s constructor to
     also parse `kitGalleryPart\s*\(` calls (reading their `name:` the same
     way), so every future non-modal part is covered without a ceiling
     change. Blocks: G4 "gallery" for every future `kitGalleryPart`-based
     kit-part unit, not only this one.
  3. **Exported / docRow.** `kit_manifest_test.dart` also fails `exported`
     (`lib/ui/kit/kit_level_meter.dart is not reachable from
     lib/ui/kit/kit.dart`) and `docRow` (`no [KitLevelMeter] row in the
     kit.dart table`). This is the expected, temporary state of a
     standalone kit-part unit before the integrator's export commit (R06:
     `lib/ui/kit/kit.dart` is not in any unit's write set); it is not a
     defect in this part. Left for the integrator; not a new problem this
     unit introduces, but recorded since G4 currently has no allowance for
     a part landing before its export commit.

- New kit parts (KIT-3): `KitLevelMeter` (this unit's own assigned part; no
  other new part was created).
- Map items (EVID-11): n/a — no pages.
- States per page (STATE-20): n/a — not a screen unit. States by KIT-12:
  listening, quiet, paused (decorative; not interactive) → each has a
  412×915 dark+light gallery pair (8 PNGs) and behaviour tests (`litFor`,
  `paused`, `direction`, `colours`) in `test/kit/kit_level_meter_test.dart`.
- Deferred states (STATE-21): none — the spec is explicit that the part has
  no loading, empty, error, working, answered or disabled state; the host
  owns those.

## 2. Builds

- Branch `revamp/kit-KitLevelMeter`, base `2723b205` (`feat/phone-setup-v2`),
  code head: see `git log -1` after the build commit below.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `flutter analyze lib test` | no errors; no new issues | `No issues found!` | PASS |
| 2 | `test/kit/kit_level_meter_test.dart` (`-j 1`) | passes | 9 passed | PASS |
| 3 | `test/goldens/kit/kit_level_meter_golden_test.dart` (`-j 1`) | passes, 22 PNGs | 22 passed | PASS |
| 4 | `test/kit_ratchet_test.dart`, `test/design_standard_test.dart`, `test/l10n_coverage_test.dart`, `test/ui_glossary_test.dart`, `test/ui_ledger_coverage_test.dart` (`-j 1`) | pass | 72 passed | PASS |
| 5 | `test/kit/kit_manifest_test.dart` (`-j 1`) | — | 4 violations (see Contract problems: states, gallery, exported, docRow) | FAIL (reported, not worked around) |

## 5. Evidence

- No fix in this unit (all new code; TEST-2 does not apply — "New code that
  fixes nothing needs no failing-first run").
- Rule evidence (PROC-31), all from the four saved runs next to this record:

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | PROC-2, PROC-3 (analyzer clean) | `flutter analyze lib test` | `analyze-run.txt` |
  | KIT-12 (litFor thresholds) | `test/kit/kit_level_meter_test.dart` "thresholds" | `unit-test-run.txt` |
  | LAY-8 (direction mirrors in RTL) | `test/kit/kit_level_meter_test.dart` "direction: .5 lights the first six, mirrored in RTL" | `unit-test-run.txt` |
  | LOOK-1, LOOK-5, LOOK-6 (roles only, no danger/attention, opaque) | `test/kit/kit_level_meter_test.dart` "colours: only accent and surface3…" | `unit-test-run.txt` |
  | LOOK-21 pre-wave seam (whole physical pixels at DPR 3) | `test/kit/kit_level_meter_test.dart` "crisp: at DPR 3…" | `unit-test-run.txt` |
  | PERF-4 (listen repaints without rebuilding the host) | `test/kit/kit_level_meter_test.dart` "listen repaints…" | `unit-test-run.txt` |
  | A11Y-3 / "excluded from semantics" | `test/kit/kit_level_meter_test.dart` "adds no semantics node" | `unit-test-run.txt` |
  | MOT-7 (G8: no ticker under reduced motion) | `test/kit/kit_level_meter_test.dart` "settles with no ticker…" | `unit-test-run.txt` |
  | A11Y-2 (G6: no overflow at 320 dp, 2.0 text, RTL) | `test/kit/kit_level_meter_test.dart` "fits a 24 dp line…" | `unit-test-run.txt` |
  | TEST-9 (galleries at the §8.4 sizes, DPR 3, dark/light/text2/Arabic) | `test/goldens/kit/kit_level_meter_golden_test.dart` (all 22) | `golden-test-run.txt` |
  | KIT-1/4/5/7/15–17/21 etc. (shared ratchet, design-standard, l10n, glossary, ledger gates unbroken) | `test/kit_ratchet_test.dart`, `test/design_standard_test.dart`, `test/l10n_coverage_test.dart`, `test/ui_glossary_test.dart`, `test/ui_ledger_coverage_test.dart` | `shared-gates-run.txt` |
  | G4 contract problems 1–3 (states, gallery, exported/docRow) | `test/kit/kit_manifest_test.dart` | `manifest-run.txt` |

- Changed test expectations (TEST-19): none — no shared test was touched.
- Goldens changed (all new, each opened and looked at before this record):
  22 PNGs under `test/goldens/kit/kit_level_meter_*.png` — the 4 declared
  states (`listening_low`, `listening_high`, `quiet`, `paused`) at 412×915
  dark/light; `listening_high` at 360×800, 915×412 (landscape), 800×1280,
  1280×800, 1600×1000, dark/light; `listening_high` at 2.0 text and in
  Arabic at 412×915 and 1280×800, dark. Looked at: the bars form the "V"
  height profile the spec describes, light bars are the theme's `accent`
  green and unlit bars the muted `surface3` grey in both themes, the
  caption text is legible in both themes at every size, and the Arabic shot
  mirrors the caption's punctuation/number order correctly (RTL bar mirror
  itself is proven by the unit test, not visible in the `listening_high`
  gallery shot since all 9 bars light at 0.9 regardless of direction).
  No approved VL canvas render exists for this part yet (EVID-12: none).
- Before and after: n/a — new part, nothing existed before it
  (`git show 2723b205:lib/ui/kit/kit_level_meter.dart` does not exist).
- Accessibility: excluded from semantics entirely (proven by test); no
  touch target (not interactive); 200% text and Arabic galleries reviewed
  above; colour is never the only signal (the host's own words carry the
  state, per spec).
- Privacy and security: n/a — no credentials, stored data, links or
  notifications; the part holds one transient `double` and nothing else.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F analyze lib test
$F test -j 1 test/kit/kit_level_meter_test.dart
$F test -j 1 test/goldens/kit/kit_level_meter_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart \
  test/l10n_coverage_test.dart test/ui_glossary_test.dart \
  test/ui_ledger_coverage_test.dart
$F test -j 1 test/kit/kit_manifest_test.dart   # fails: see Contract problems
```

## 7. NOT proven

- Not run on a device or emulator (unit agents never do; coordinator work).
- Not exported from `lib/ui/kit/kit.dart` and no `[KitLevelMeter]` row in its
  doc table yet — integrator work (R06), and the reason G4's `exported`/
  `docRow` checks fail today (see Contract problems §3).
- `test/kit/kit_manifest_test.dart` (G4) does not pass for this part: see
  Contract problems 1–3. Nothing else in this record substitutes for that
  gate; it is left failing and reported, not silenced.
- No adoption: `lib/voice/voice_ui.dart`'s private `_LevelMeter` is
  untouched (explicit non-goal); screen-voice-1 and kit-KitComposer adopt
  this part in their own units.
- No approved visual-language canvas render exists yet for this part to
  compare against (EVID-12: none available).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitLevelMeter` |
| Enabled | No: not exported from `kit.dart` yet (integrator) | |
| Verified | Tests and goldens only (this record) | this record |
| Committed | Yes | code head (see `git log -1`) |
| Deployed | No | |
| Released | No | |
