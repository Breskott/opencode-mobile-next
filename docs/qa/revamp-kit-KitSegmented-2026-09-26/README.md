# revamp-kit-KitSegmented: KitSegmented, the row-form single choice (2026-09-26)

## 1. Scope

- Unit: `kit-KitSegmented` (wave 1, tier 1d, `kit-part`). Finish line: `KitSegmented` exists in `lib/ui/kit/kit_segmented.dart`, matches its frozen API, renders every declared state except "stacked" (blocked, see below), and has its galleries, contract tests and structural asserts. Non-goal: no local `KitChoiceRow` substitute, and no screen migrates to it (wave 2).
- Files changed: `lib/ui/kit/kit_segmented.dart` (new), `test/kit/kit_segmented_test.dart` (new), `test/goldens/kit/kit_segmented_golden_test.dart` (new), 26 new PNGs beside it.
- Pages (map ids): none touched — this unit builds the part only (R14 non-goal: "No migration of call sites (wave 2)").
- Specs followed: docs/ux-system/kit-api/KitSegmented.md (frozen API, in full); kit-v2.md §1.6, §8.2; STANDARDS.md KIT-24, LOOK-6, LOOK-21, LOOK-15, STATE-8, STATE-9, MOT-2, MOT-5, MOT-7, MOT-11, A11Y-1, A11Y-3, A11Y-4, A11Y-5, LAY-9, LAY-10, LAY-11, DATA-11, G8, G37, NAME-1; Appendix A #78.
- Contract problems (PROC-20):
  - {rule: kit.dart export/doc row, STANDARDS.md PROC-13 ("kit.dart: add exactly one export line and one doc-table row per new part") vs this unit's dispatch, R06 ("Shared files you never stage: lib/ui/kit/kit.dart … the integrator adds exports"). Evidence: `docs/ux-system/revamp/STANDARDS.md` line ~187 (PROC-13) vs the dispatch's hard-rules list. Followed R06 (the more specific, unit-scoped instruction) and left `kit.dart` untouched; `KitSegmented`/`KitSegment` are imported by path (`package:opencode_mobile/ui/kit/kit_segmented.dart`) everywhere, including this unit's own tests. Proposed text: STANDARDS.md PROC-13's kit.dart line should say "the integrator adds it," matching R06 and PROC-11's single-owner rule for shared registries. blocks: false — this is a routine, expected gap at integration, not a defect in the part.}
  - {rule: dependency, docs/ux-system/kit-api/KitSegmented.md "Depends on" (KitChoiceList → KitChoiceRow, kit-KitChoiceList tier 1c). Evidence: `lib/ui/kit/` has no `kit_choice_list.dart` and no `KitChoiceList`/`KitChoiceRow` class anywhere in the repository (checked by directory listing and `grep -rl` on `lib/`); this unit was dispatched before that tier-1c dependency merged into `feat/phone-setup-v2`. Per the dispatch's own hard rule ("If you need another unit's part that has not merged, stop and report it; never build a local substitute") and PROC-32, the stacked form is left unbuilt rather than reimplemented locally. blocks: true for the "stacked" state only — see State below and PROC-32 blockers.}
  - {rule: G4 gallery/stateScenes scan, `test/kit/kit_manifest_test.dart`'s `_Gallery` shot reader. What it does: it only recognises a shot from a literal `kitGalleryShot(name: …)` call or a `matchesGoldenFile('literal')` call written directly in the part's own gallery file; `kitGalleryPart` — the harness's own doc-recommended helper for "a part that is not a modal: rows, buttons, cards, type" (`test/goldens/kit/kit_gallery.dart`, exactly this unit's shape) — calls `matchesGoldenFile('$name.png')` *inside kit_gallery.dart*, so a gallery file built the doc-recommended way, like this one, is invisible to that scan. Why wrong: it contradicts the harness's own documented, intended usage for a non-modal part, so no new non-modal `kit-part` unit that follows that doc can ever satisfy the `gallery`/`stateScenes` checks, and the allowlist cannot absorb it (PROC-13/G4: "a new part cannot be added to it"). Evidence: `flutter test -j 1 test/kit/kit_manifest_test.dart` on this branch reports exactly `exported`, `docRow` (the R06 gap above) plus `stateScenes · KitSegmented: no 412x915 golden kit_segmented_disabled_…dark, kit_segmented_disabled_…light` and `gallery · KitSegmented: … lacks a …text2… golden at textScale: 2, an …_ar_… golden in Locale('ar')` — although `kit_segmented_disabled_dark.png`/`_light.png` and both the `text2` and `_ar_` galleries exist, pass, and were looked at (§4 Runs, §5 Evidence). Proposed text: `_Gallery` in `test/kit/kit_manifest_test.dart` should also recognise a `kitGalleryPart(name: kitGalleryName(...), …)` call the same way it recognises `kitGalleryShot`. blocks: false — the actual galleries exist, pass and were reviewed; only the gate's own recognition of them is short, and fixing the gate is coordinator work (PROC-13 forbids this unit editing it).}
- New kit parts (KIT-3): `KitSegmented` (and its data class `KitSegment<T>`), `lib/ui/kit/kit_segmented.dart`.
- Map items (EVID-11): none — migration of the map's 25 elements across 22 pages (docs/ux-system/kit-api/KitSegmented.md "Replaces") is explicitly wave 2 for this unit; no page's map record is owned here.
- States per page (STATE-20): n/a — no page changed.
- Deferred states (STATE-21): n/a — no page changed. (The part's own "stacked" state is deferred; see State and NOT proven.)

## 2. Builds

- Branch `revamp/kit-KitSegmented`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4` (`feat/phone-setup-v2`), code head `bcd1b31542e203104f479d8a523a9fc750daeee1`.
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work (R19/R20).

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `flutter analyze lib/ui/kit/kit_segmented.dart test/kit/kit_segmented_test.dart test/goldens/kit/kit_segmented_golden_test.dart` | no issues | "No issues found!" | PASS |
| 2 | `flutter test -j 1 test/kit/kit_segmented_test.dart` | all pass | 27 passed (0 failed) | PASS |
| 3 | `flutter test -j 1 test/goldens/kit/kit_segmented_golden_test.dart` (no `--update-goldens`, comparing against the committed PNGs) | all pass | 26 passed (0 failed) | PASS |
| 4 | Look at every regenerated golden before committing (TEST-6, TEST-20) | each one matches the frozen spec's look and states | 5 spot-checked directly (default/counts/segment-disabled/disabled at 412×915 dark, default at 1600×1000 dark, default light, default 915×412 dark, default Arabic 412×915 dark) plus visual review of the rest for gross errors; no overflow, no mis-rendered glyphs, RTL order and check placement mirrored correctly | PASS |
| 5 | `flutter test -j 1 test/kit/kit_manifest_test.dart` (G4, shared; run read-only to see this unit's exact impact, not edited) | fails only on `exported`/`docRow` (the R06 gap) | fails on 4: `exported`, `docRow` (both R06/integrator, expected) plus `stateScenes` and `gallery` (a G4 scanner gap — see Contract problems; the goldens those two name do exist and pass in step 3) | FAIL (both causes recorded as Contract problems, `blocks: false`) |

Ratchet, design-standard, l10n, glossary tests, the ledger test, `kit_motion_test.dart`, `text_scale_overflow_test.dart` and a whole-tree `flutter analyze` were **not run**: they are shared/integration gates outside this unit's write set (PROC-10, PROC-13).

## 5. Evidence

- No fix round: this is a new part, not a fix, so there is no `failing-first.txt` (TEST-1 does not apply; G32's failing-first requirement is only for a `fix(` commit).
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | G37 (structural asserts) | `test/kit/kit_segmented_test.dart` "construction (G37)" group, 5 cases | all 5 PASS |
  | STATE-9 (selection not colour only) | `test/kit/kit_segmented_test.dart` "the selected segment shows a check glyph" | PASS |
  | A11Y-1 (group and segment semantics) | `test/kit/kit_segmented_test.dart` "each segment carries button, selected and group semantics" | PASS |
  | STATE-8 (honest disabled reason) | `test/kit/kit_segmented_test.dart` "disabled reasons (STATE-8)" group, 2 cases | both PASS |
  | LAY-10/LAY-11 (keyboard, RTL arrows) | `test/kit/kit_segmented_test.dart` "keyboard (LAY-10, LAY-11)" group, 4 cases | all 4 PASS |
  | G8 (reduced motion settles in one pump) | `test/kit/kit_segmented_test.dart` "reduced motion (G8)" plus `kitMotionStillTests('KitSegmented', …)` (8 cases) | 1 + 8 PASS |
  | LAY-9 (48 dp targets) | `test/kit/kit_segmented_test.dart` "sizing (LAY-9)" | PASS |
  | TEST-9/TEST-14 (galleries, DPR 3, required sizes, text 2.0, Arabic) | `test/goldens/kit/kit_segmented_golden_test.dart`, 26 shots | all 26 PASS |

- Changed test expectations (TEST-19): none — every test file here is new.
- Goldens changed (each opened and looked at): all 26 are new (not changed); see Runs #4 for what was looked at. No approved VL canvas render exists for this part yet (EVID-12: "no approved render").
- Before and after (EVID-10): n/a — no page changed, so there is no before/after page render. This is a new kit part, not a screen revamp.
- Accessibility: group semantics (`semanticsLabel`) plus per-segment `button`/`selected`/`inMutuallyExclusiveGroup`/`enabled` and a composed label including the count, checked by `matchesSemantics` (test/kit/kit_segmented_test.dart). 48 dp targets checked at 412×915. Text scale checked at 1.0 (behaviour tests, default galleries) and 2.0 (`kit_segmented_default_text2_*` galleries, short labels only — see NOT proven). Arabic RTL checked in both a behaviour test (arrow-key direction) and galleries (`kit_segmented_default_ar_*`, mirrored order and check placement confirmed by eye).
- Privacy and security: n/a — no credentials, stored data, external links or notifications; the part is local, stateless-in-the-domain-sense UI only.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F analyze lib/ui/kit/kit_segmented.dart test/kit/kit_segmented_test.dart test/goldens/kit/kit_segmented_golden_test.dart
$F test -j 1 test/kit/kit_segmented_test.dart
$F test -j 1 test/goldens/kit/kit_segmented_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (coordinator work, R19/R20).
- **The "stacked" state does not exist yet (blocked, PROC-32).** `KitSegmented` always renders the single-row form. It depends on `KitChoiceList` → `KitChoiceRow` (kit-KitChoiceList, tier 1c), which has not merged into `feat/phone-setup-v2`; building a local substitute is explicitly forbidden (R14; the frozen spec itself rejects "Segmented drawing its own stacked rows" as giving `KitChoiceRow`'s job to two parts). Concretely not proven or covered:
  - Tests-required item 5 (stacking behaviour and its `onChanged` wiring) and the RTL half of item 6 covering the stacked form's Up/Down arrows.
  - The "stacked" gallery scene, and the two "text 2.0" gallery scenes (412×915 and 1280×800) that the spec says "show the stacked form" — the committed `kit_segmented_default_text2_*` galleries instead show the flat row, which happens not to overflow only because the sample labels ("Today"/"Week"/"Month") are short; a longer label at 2.0 text, or at 320 dp, will truncate (ellipsis) rather than stack, which is not spec-compliant (A11Y-2, KIT-24, G6).
  - The fit-measurement helper the spec asks this unit to build ("re-implemented or lifted into a shared private helper," reusing `KitAskLine`'s approach) is not implemented, since nothing here would consume its result without the stacked layout to switch into.
- **The fine-pointer tooltip is not implemented.** The spec's "Fine pointer" section asks for a tooltip repeating the full label when a count or icon shortens it. The only conduits the dispatch's Kit-only rule allows (`KitIconButton`, `KitTerm`, `KitTappable.tooltip`) do not fit a label-plus-icon-plus-count segment button (`KitIconButton` is icon-only) or do not exist yet (`KitTappable`, itself a planned, not-yet-merged part). This is a minor, untested gap, not covered by any required behaviour test.
- No explicit minimum-width enforcement per segment: 48 dp is satisfied at every tested size (320–1600 dp, 2–4 segments) by equal division of the available width, not by a hard constraint; an unusually narrow host (< ~200 dp for 4 segments) is not proven.
- `test/kit_manifest_test.dart` (G4) was run read-only (§4 Runs #5) and fails today for four reasons, two expected and two a gate gap, all recorded in Contract problems: `exported`/`docRow` (R06, the integrator's step) and `stateScenes`/`gallery` (the scanner does not recognise `kitGalleryPart`-built galleries, even though this file's galleries exist and pass). `test/kit_motion_test.dart` and `test/text_scale_overflow_test.dart` were not run; the overflow gate only discovers a part through `kit.dart`'s exports, so it will not see `KitSegmented` at all until the integrator's export lands, and `kit_motion_test.dart`'s own coverage check is likewise scoped to exported parts.
- Ratchet, design-standard, l10n, glossary and ledger tests were not run (nothing in this unit's write set touches what they check; no ARB keys were added — this part ships no copy of its own, matching the frozen spec's "Kit copy: none of its own").

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Partial (PROC-32: blocked on kit-KitChoiceList for the "stacked" state and its dependent tests/galleries; everything else in the frozen spec is implemented) | `revamp/kit-KitSegmented` |
| Enabled | No: not exported from `kit.dart` yet (R06, integrator step) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `bcd1b31542e203104f479d8a523a9fc750daeee1` |
| Deployed | No | |
| Released | No | |
