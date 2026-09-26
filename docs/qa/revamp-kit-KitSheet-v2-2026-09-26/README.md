# revamp-kit-KitSheet-v2: KitSheet v2 (2026-09-26)

## 1. Scope

- Unit: `kit-KitSheet-v2` (wave 1, tier 1a, `kit-change`). Finish line: `showKitSheet`/`KitSheet` draw the visual-language sheet header (grabber, icon tile, left-aligned title, Close) with no call-shape change, and callers get `KitConsequences` for a sheet body's facts panel — done when every existing call site still compiles and renders, the new header states (icon, tone) and `KitConsequences` are tested and in the gallery, and KitDraft is untouched. Non-goal: moving any of the 78 `showModalBottomSheet`/5 `DraggableScrollableSheet` call sites to `showKitSheet` (wave 2), and the confirmation's own look (`kit_confirm_sheet.dart`, kit-KitDetailsFold's file).
- Files changed:
  - `lib/ui/kit/kit_sheet.dart` (the library only; `kit_confirm_sheet.dart`, its part file, is untouched — that is kit-KitDetailsFold's).
  - `lib/ui/kit/kit_consequences.dart` (new — see "New kit parts" below).
  - `test/kit/kit_sheet_test.dart` (extended in place; the existing tests are unchanged).
  - `test/kit/kit_sheet_wrap_test.dart` (new: the one test that needs the app's real face loaded).
  - `test/kit/kit_consequences_test.dart` (new).
  - `test/kit/kit_overflow_scenes.dart` (appended one scene for `KitConsequences`, per its own header: "a kit unit that adds a part adds one block at the end", PROC-13).
  - `test/goldens/kit/kit_sheet_golden_test.dart` (restructured for the new states; see §5).
  - `test/goldens/kit/kit_consequences_golden_test.dart` (new).
  - `test/goldens/kit/kit_sheet_*.png` (40 total) and `test/goldens/kit/kit_consequences_default*.png` (18 total); see §5 for exactly which are new, regenerated or removed.
- Pages (map ids): none — this is a kit-only change; kit-v2.json's 41 `KitSheet` pages move to it in wave 2 when their screens adopt `showKitSheet`.
- Specs followed: docs/ux-system/kit-api/KitSheet.md (frozen API); kit-v2.md §1.1, §4.6, §4.7, §8.2, §8.3; visual-language §5 "Sheets", §6, §7; STANDARDS.md rules KIT-11, KIT-15, KIT-16, KIT-17, KIT-18, KIT-19, KIT-39, KIT-43, LOOK-19, LOOK-21, LOOK-22, LOOK-25, LAY-3, LAY-4, LAY-10, LAY-13, DATA-1..4, MOT-2, MOT-11, A11Y-8, TEST-20, NAME-1, KIT-3, KIT-12, KIT-14.
- Contract problems (PROC-20):
  - Not a spec bug, but worth flagging for the next unit that adds a class inside an existing part's file: KitSheet.md's frozen API text places `KitConsequenceMark`/`KitConsequence`/`KitConsequences` inside `kit_sheet.dart`'s own Public API block, with no separate file named. G4 (absolute, NAME-1, KIT-3) requires every exported class to live in `lib/ui/kit/kit_<snake>.dart` with its own `test/kit/kit_<snake>_test.dart` and `test/goldens/kit/kit_<snake>_golden_test.dart` — `kit_sheet.dart`/`KitConsequences` fails that trio. Resolved without changing the frozen class shapes or their public API one bit: moved the three declarations to a new `lib/ui/kit/kit_consequences.dart`, re-exported from `kit_sheet.dart` (`export 'kit_consequences.dart';`), so every existing import path (`package:opencode_mobile/ui/kit/kit.dart`) is unaffected; added `test/kit/kit_consequences_test.dart` and `test/goldens/kit/kit_consequences_golden_test.dart` per NAME-1. `KitSheet.md` itself is not wrong to fix — the API it freezes is unchanged — but a future frozen spec that adds a new public class to an existing part's file should say up front whether it is its own NAME-1 part or an addition, to save this discovery.
  - **A real, unresolved conflict, reported rather than worked around (R16):** STANDARDS G4/KIT-14 requires "`kit.dart`'s doc table has one row for every exported public part," in the same commit that adds the part, absolute, allowlist-only-shrinks. This unit's write set (the harness task) lists `lib/ui/kit/kit.dart` under "Shared files you never stage" ("the integrator adds exports, R06"). `KitConsequences` is exported (transitively, through `kit_sheet.dart`'s own export) without any change to `kit.dart`'s export list, but it still needs a doc-table row there for G4 to go green, and this unit cannot add one without staging a file it was told never to stage. `test/kit/kit_manifest_test.dart` "G4: every kit part and opener meets the manifest" therefore fails with exactly one line: `docRow · KitConsequences: no [KitConsequences] row in the kit.dart table` (`run-1.txt`). Every other G4 check (name, states, stateScenes, gallery, test, motion) passes. Fix: the integrator adds one row, `| \`KitConsequences\` | the counted-facts panel a sheet body places wherever the facts belong |`, to `kit.dart`'s doc table when merging this branch; no export list change is needed.
- New kit parts (KIT-3): `KitConsequences` (with `KitConsequenceMark` and `KitConsequence`) — `lib/ui/kit/kit_consequences.dart`, `test/kit/kit_consequences_test.dart`, `test/goldens/kit/kit_consequences_golden_test.dart`, one scene in `test/kit/kit_overflow_scenes.dart`, one `kitMotionStillTests` registration. Its class shapes and doc comments are exactly the frozen spec's; only the file it lives in changed (see "Contract problems" above). The new private seam `_KitIconTile` and the `KitSheetTone` enum stay in `kit_sheet.dart` itself (not new parts — `_KitIconTile` is for `kit_confirm_sheet.dart`, a `part of` file, to use once kit-KitDetailsFold merges).
- Map items (EVID-11): n/a — no map page owned by this unit.
- States per page (STATE-20): n/a (kit-only). The part's own declared states (default, with-icon, consequences, loading, disabled, discard, half, not-dismissible, keyboard-open, attention, full) are all covered by the gallery (§5) and the behaviour tests (§4).
- Deferred states (STATE-21): the disabled primary's `disabledReason` line (STATE-8) and the actions-in-a-row-on-PC acceptance both need kit-KitAction-v2's `KitActionBlock`/`KitAction`; see §7 NOT proven and README.md decision D4 (already the frozen spec's own scheduling call, not a new gap this unit found).

## 2. Builds

- Branch `revamp/kit-KitSheet-v2`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4` (`feat/phone-setup-v2`), code head: this record's commit is the first commit on the branch.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_sheet_test.dart` (26 tests: the frame, the icon tile, unsaved input, not dismissible, loading, window classes, the close button and grabber, stacked actions, `routes`) | passes | 26 passed | PASS |
| 2 | `test/kit/kit_sheet_wrap_test.dart` (A11Y-8 title/subtitle wrap at 2.0 text, real face loaded) | passes | 1 passed | PASS |
| 3 | `test/kit/kit_consequences_test.dart` (6 tests: motion samples ×2, the three marks' glyph and colour, the hairline separator, semantics exclusion, an icon override) | passes | 6 passed | PASS |
| 4 | `test/kit/kit_draft_test.dart`, `test/kit/kit_keyboard_test.dart`, `test/kit/kit_confirm_sheet_test.dart` (kept passing unchanged, PROC-10) | pass | 8 + 9 + 74 passed | PASS |
| 5 | `test/kit_motion_test.dart` (gate G8x, the reduced-motion manifest) | pass, `KitConsequences` and `KitSheet` both registered | all passed | PASS |
| 6 | `test/kit/kit_manifest_test.dart` (gate G4, the kit manifest) | pass | 1 of 2 tests fails with exactly the `docRow · KitConsequences` line (`run-1.txt`); every other check (name, states, stateScenes, gallery, test, motion) passes | **FAIL — documented, see §1 Contract problems and §7** |
| 7 | `test/text_scale_overflow_test.dart` (gate G6, the kit overflow matrix, including the new `KitConsequences/default` scene, at 1.0/1.3/2.0 text, LTR and RTL) | pass, no new overflow | 76 passed (`run-7.txt`) | PASS |
| 8 | `test/goldens/kit/kit_sheet_golden_test.dart` and `test/goldens/kit/kit_consequences_golden_test.dart --update-goldens`, every changed PNG opened and looked at | 40 + 18 PNGs, all G5 checks pass in both themes | 58 passed | PASS |
| 9 | `test/kit_ratchet_test.dart`, `test/design_standard_test.dart`, `test/l10n_coverage_test.dart` (shared gates, read-only) | pass, no baseline raised | 49 passed; l10n printed only pre-existing "could lower" notes for files this unit never touched | PASS |
| 10 | `flutter analyze` on every changed/added file | no issues | "No issues found!" | PASS |

Runs 1–6 and 9 ran together as one `flutter test` invocation (303 tests, 1 known failure — `run-1.txt`); run 7 and run 8 are their own invocations (`run-7.txt`, `run-8.txt`).

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-43 (additive-only) | `test/kit/kit_sheet_test.dart` "the frame: title, subtitle, close, body and pinned actions" and the whole `unsaved input without a draft` group, unchanged | run-1.txt |
  | A11Y-8 (no truncation) | `test/kit/kit_sheet_wrap_test.dart` "title and subtitle wrap fully at 2.0 text" | run-1.txt |
  | KIT-17 | `test/kit/kit_sheet_test.dart` "pinned actions stay visible with the keyboard open (KIT-17)" | run-1.txt |
  | STATE-9 (icon tile excluded from semantics) | `test/kit/kit_sheet_test.dart` "with icon, the tile sits above the title, at the start, and is excluded from semantics"; `test/kit/kit_consequences_test.dart` "the glyphs carry no semantics of their own (STATE-9)" | run-1.txt |
  | LOOK-5/DATA-8 (`KitConsequences` marks) | `test/kit/kit_consequences_test.dart` "lost is danger, kept is a text2 check, info is a text2 info glyph" | run-1.txt |
  | LOOK-21 (hairline) | `test/kit/kit_consequences_test.dart` "the separator is one hairline, inset to the text start" | run-1.txt |
  | KIT-18 | `test/kit/kit_sheet_test.dart` "not dismissible while an irreversible step runs" | run-1.txt |
  | the `routes` contract | `test/kit/kit_sheet_test.dart` "routes: closes itself when its request is answered elsewhere" group (both tests) | run-1.txt |
  | G6 (`KitConsequences` scene) | `test/text_scale_overflow_test.dart` "G6 kit overflow matrix KitConsequences/default fits every overflow size, text scale and direction" | run-7.txt |

- Changed test expectations (TEST-19): none — every existing assertion in `test/kit/kit_sheet_test.dart`, `kit_draft_test.dart` and `kit_keyboard_test.dart` is unchanged and still passes; only new assertions and tests were added.
- Goldens changed (each opened and looked at):
  - `kit_sheet_default_{dark,light}.png`: re-rendered only (Text → KitText, IconButton → KitIconButton); no visible change beyond the intended look pass.
  - `kit_sheet_disabled_{dark,light}.png`, `kit_sheet_loading_{dark,light}.png`, `kit_sheet_half_{dark,light}.png`: re-rendered only, same reason; no visible change.
  - `kit_sheet_with_icon_*` (20 PNGs: 412×915 plus every LAY-4 size, and 2.0 text/Arabic at 412×915 and 1280×800, each dark and light): new — the icon tile above the title, at the start, in `surface3`/`text1`.
  - `kit_sheet_attention_{dark,light}.png`: new — the tile in the attention tint and glyph.
  - `kit_sheet_consequences_{dark,light}.png`: new — the `surface1`/`ground` panel, `lost` (danger warning glyph), `kept` (text2 check) and `info` (text2 info) on one panel with hairline separators.
  - `kit_sheet_not_dismissible_{dark,light}.png`: new — no Close, grabber still drawn (KIT-18).
  - `kit_sheet_keyboard_open_{dark,light}.png`: new — `viewInsets.bottom` 300, the pinned actions stay above it (KIT-17).
  - `kit_sheet_full_1280x800_{dark,light}.png`: re-rendered (icon-free header look pass); the 412×915 `kit_sheet_full_{dark,light}.png` pair is removed — "full" is no longer in the per-412×915 state list (only `default` and `with-icon` are, per the frozen spec's Galleries section).
  - Removed (dead, no longer produced by any shot; the "default" sweep is now 412×915-only and the wide sizes moved to "with-icon"): `kit_sheet_default_{360x800,800x1280,1280x800,1600x1000}_{dark,light}.png`, `kit_sheet_default_{ar,text2}_{dark,light}.png`, `kit_sheet_default_{ar,text2}_1280x800_{dark,light}.png`.
  - `kit_consequences_default_*` (18 PNGs, new): the panel alone, at every LAY-4 size, in 2.0 text and Arabic — lost's danger warning glyph, kept's text2 check, info's text2 info glyph, and the hairline separators, match the panel as it renders inside `kit_sheet_consequences_*`.
  - No approved visual-language canvas render exists yet for this cut (EVID-12: none found under `docs/design/` for KitSheet's header or the consequences panel); the frozen spec's own description ("as in the approved Confirm render") was used as the reference instead, cross-checked against `kit_confirm_sheet.dart`'s existing mark styling.
- **NOT proven, spec-acknowledged (README.md decision D4, STANDARDS §0.4):** `kit_sheet_with_icon_{800x1280,1280x800,1600x1000}_{dark,light}.png` and `kit_sheet_full_1280x800_{dark,light}.png` show today's `KitActionBlock` **stacking** the actions at those widths (its row threshold is `maxWidth >= 600`, and the 560 dp panel never reaches it). The frozen spec calls this out by name and assigns the one-time re-render, after kit-KitAction-v2 merges, to the integrator (R07). These 8 PNGs are otherwise correct (icon tile, title, close, RTL) and were kept rather than reverted, so the suite is green today; the integrator only needs to re-run `--update-goldens` on those two shots once kit-KitAction-v2 lands.
- Before and after: n/a — no screen page changed (kit-only unit); the before/after pairs belong to the wave-2 screen units that move call sites onto `showKitSheet`.
- Accessibility: the icon tile is `ExcludeSemantics`'d (tested); the grabber's "Dismiss" semantics action is tested when dismissible and the `KitIconButton` type (48×48, tooltip = semantics label) replaces the raw `IconButton`; title/subtitle now wrap fully at 200% text with no truncation and no overflow (tested against the real Geist face, since the default test font's block glyphs wrap unrealistically); every gallery shot ran G5 (`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`, reading order) in both themes with no new baseline entries.
- Privacy and security: n/a — no credentials, stored data, external links or notifications changed.
- Migration: n/a — no stored format changed (`KitDraft`'s key shape, `oc.draft.<target>.<profileId>`, is untouched, per C17).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_sheet_test.dart test/kit/kit_sheet_wrap_test.dart \
  test/kit/kit_consequences_test.dart test/kit/kit_draft_test.dart \
  test/kit/kit_keyboard_test.dart test/kit/kit_confirm_sheet_test.dart \
  test/kit_motion_test.dart test/kit/kit_manifest_test.dart \
  test/kit_ratchet_test.dart test/design_standard_test.dart test/l10n_coverage_test.dart
$F test -j 1 test/text_scale_overflow_test.dart
$F test -j 1 --update-goldens test/goldens/kit/kit_sheet_golden_test.dart \
  test/goldens/kit/kit_consequences_golden_test.dart   # then look at every changed PNG
$F analyze lib/ui/kit/kit_sheet.dart lib/ui/kit/kit_consequences.dart \
  test/kit/kit_sheet_test.dart test/kit/kit_sheet_wrap_test.dart \
  test/kit/kit_consequences_test.dart test/kit/kit_overflow_scenes.dart \
  test/goldens/kit/kit_sheet_golden_test.dart test/goldens/kit/kit_consequences_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (R19/R20: coordinator work).
- `test/kit/kit_manifest_test.dart`'s G4 fails on exactly one line, `docRow · KitConsequences: no [KitConsequences] row in the kit.dart table` — fixing it means staging `kit.dart`, which this unit's write set forbids (§1 Contract problems has the full explanation and the integrator's one-line fix).
- The "row on PC" half of the acceptance ("buttons stacked on phones and right-aligned in a row on PC") is not proven: today's `KitActionBlock` only rows at `maxWidth >= 600`, which the 560 dp panel this unit's wide shots use never reaches. The frozen spec assigns the fix and the one-time golden re-render to kit-KitAction-v2 and the integrator (README.md decision D4); "stacked on phones" is proven (`test/kit/kit_sheet_test.dart` "actions stack full width on a phone").
- The disabled primary's `disabledReason` line (STATE-8) is not proven: that is `KitAction`/`KitActionBlock`'s field (kit-KitAction-v2), not this unit's; today's disabled-primary golden shows no reason line, matching the current (pre-v2) `KitActionBlock`.
- No live OpenCode server, phone or Termux involved — this is a pure Flutter-widget-test and golden-test unit.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitSheet-v2` |
| Enabled | Yes — additive only, no flag; every existing call site keeps working (KIT-43) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | this branch's commit(s) |
| Deployed | No | |
