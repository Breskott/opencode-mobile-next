# revamp-kit-KitImage: KitImage, KitAvatar, KitZoom (2026-09-26)

## 1. Scope

- Unit: `kit-KitImage` (wave 1, tier 1a, `kit-part`). Finish line: `KitImage`,
  `KitAvatar` and `KitZoom` exist in `lib/ui/kit/kit_image.dart` with their
  full §4 API, every declared state, their galleries (TEST-9) and their
  contract tests (TEST-15). Non-goal: no call site outside the kit changes
  (no screen migration).
- Files changed: `lib/ui/kit/kit_image.dart` (new); `test/kit/kit_image_test.dart`
  (new); `test/goldens/kit/kit_image_golden_test.dart` (new, plus its 36 PNGs);
  `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` and the three generated
  `lib/l10n/app_localizations*.dart` (new copy only, `flutter gen-l10n` run
  once).
- Pages (map ids): none — this is a kit part, not a screen.
- Specs followed: `docs/ux-system/kit-api/KitImage.md` (the frozen block);
  `docs/ux-system/revamp/STANDARDS.md` §4 (KIT-1–KIT-43), §5.5 (LOOK-33,
  LOOK-35), §7 (MOT-1, MOT-2, MOT-11), §12 (A11Y), §15 (TEST-1–TEST-20);
  `docs/ux-system/kit-v2.md` §8 (adaptive), §9 (kit-only).
- Contract problems (PROC-20): see §"Contract problems" below.
- New kit parts (KIT-3): none beyond the three this unit's spec names.
- Map items (EVID-11): n/a — no map pages owned by this unit.
- States per page (STATE-20): n/a (kit part, not a page). Declared kit-part
  states (KIT-12): `KitImage` — loading, error (its own doc comment; galleries
  `kit_image_loading_*`, `kit_image_error_narrow_*`, `kit_image_error_wide_*`).
  `KitAvatar` — loading, error, both falling back to the initials so the slot
  is never empty (gallery `kit_image_avatar_*` shows initials/icon/image
  together; a dedicated failing-image case is in
  `test/kit/kit_image_test.dart` "a failing image keeps showing the
  initials"). `KitZoom` — none (a viewer shows what its child gives it;
  galleries `kit_image_zoom_rest_*` / `kit_image_zoom_zoomed_*`).
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitImage`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`
  (`feat/phone-setup-v2`), code head `dbce0a98`.
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work at
the wave checkpoint.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `flutter pub get` | resolves | resolved (54 packages have newer versions, unrelated to this change) | PASS |
| 2 | `dart format --language-version=3.10` on the three new files | no diff after formatting | formatted, clean | PASS |
| 3 | `flutter analyze lib/ui/kit/kit_image.dart test/kit/kit_image_test.dart test/goldens/kit/kit_image_golden_test.dart` | no issues | "No issues found!" | PASS |
| 4 | `flutter analyze lib test` (whole tree) | no errors, no new warnings/infos | "No issues found!" (20.8s) | PASS |
| 5 | `flutter test -j 1 test/kit/kit_image_test.dart` | all pass | 23 passed | PASS |
| 6 | `flutter test -j 1 --update-goldens test/goldens/kit/kit_image_golden_test.dart` then again without `--update-goldens` | all pass, deterministic | 36 passed both times, byte-identical goldens on the repeat run | PASS |
| 7 | `flutter test -j 1 test/kit_ratchet_test.dart` | passes (kit_image.dart untouched by the outside-kit-only rules) | 32 passed | PASS |
| 8 | `flutter test -j 1 test/design_standard_test.dart test/l10n_coverage_test.dart test/ui_glossary_test.dart test/ui_ledger_coverage_test.dart` | pass, unaffected by this unit | 40 passed | PASS |
| 9 | `flutter test -j 1 test/kit/kit_manifest_test.dart` | n/a — see "Contract problems"; not part of this unit's gate | fails with 15 violations, all `exported`/`name`/`test`/`gallery`/`stateScenes`/`docRow`, all tied to kit.dart's export (integrator, R06) or to a scanner gap this unit cannot fix in its write set | SEE NOTE |

Run 9 is not a pass/fail against this unit: `kit.dart` exports and the
`kit_manifest_test.dart` harness are both explicitly outside this unit's
write set (STANDARDS.md "Shared files you never stage"; §0.5 step 3), and no
kit-part unit's own branch can satisfy the `exported`/`docRow` checks before
the coordinator adds the export. It is recorded here as evidence for the
"Contract problems" section, not hidden.

## 5. Evidence

- No fixes in this unit (new code only): no `failing-first.txt` (TEST-2 n/a).
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KitImage.md "Decode size" | `test/kit/kit_image_test.dart` "requests a decode width of 300" / "it requests 263" | 23 passed (§4 run 5) |
  | LOOK-35 (`FilterQuality.high`) | `test/kit/kit_image_test.dart` "filterQuality is high for memory, asset and provider" | 23 passed |
  | KitImage.md loading/failed states | `test/kit/kit_image_test.dart` "KitImage states" group (5 tests) + `kit_image_loading_*`, `kit_image_error_narrow_*`, `kit_image_error_wide_*` goldens | 23 passed; 36 goldens passed |
  | A11Y (semantics label null/given) | `test/kit/kit_image_test.dart` "KitImage semantics (A11Y)" group | 23 passed |
  | KitAvatar initials/Arabic/decorative/failure/clamp | `test/kit/kit_image_test.dart` "KitAvatar" group (5 tests) + `kit_image_avatar_*` goldens (incl. `_ar_`, `_text2_`) | 23 passed; 36 goldens passed |
  | KitZoom double-tap, keyboard, custom actions, disabled reasons, resetKey, canvas fit/reset, reduced motion, no haptics | `test/kit/kit_image_test.dart` "KitZoom" group (9 tests) + `kit_image_zoom_rest_*` / `kit_image_zoom_zoomed_*` goldens | 23 passed; 36 goldens passed |
  | MOT-11 (no haptics) | `test/kit/kit_image_test.dart` "no HapticFeedback call" | recorded 0 `HapticFeedback.*` platform-channel calls across a full zoom/reset cycle |

- Changed test expectations (TEST-19): none — no existing test was touched.
- Goldens changed (all new; each opened and looked at, TEST-6): 36 PNGs under
  `test/goldens/kit/kit_image_*.png`. `kit_image_loaded_dark.png` shows the
  four fit/shape combinations (contain/cover, square/panel/circle) filled with
  a deterministic red 1px source; `kit_image_error_wide_dark.png` shows the
  broken-image glyph and "Can't show this image"; `kit_image_avatar_dark.png`
  shows initials (tile, mark), an icon avatar and an image avatar (opaque,
  hiding its fallback initials); `kit_image_zoom_rest_dark.png` /
  `_zoom_zoomed_dark.png` show the controls pill with reset/zoom-out disabled
  at rest and all three enabled once zoomed. No approved VL canvas render
  exists for this part (EVID-12 n/a: none was supplied with the unit).
- Before and after (EVID-10): n/a — this is a new kit part with no
  predecessor screen or golden; "no before render" for every shot (there is
  no earlier `kit_image_*` golden in git history).
- Accessibility: every gallery shot runs G5 (`androidTapTargetGuideline`,
  `labeledTapTargetGuideline`, `textContrastGuideline`, reading-order) in both
  themes via `kitGalleryPart`, with no baseline entries added — all pass
  outright. `KitImage`: `semanticsLabel: null` gives zero `Semantics` widgets
  in its subtree; a label gives exactly one, `image: true`. `KitAvatar`:
  `decorative: true` gives zero; otherwise one `image: true` node labelled
  `name`, excluding the initials. `KitZoom`: one node with `label` and a
  spoken `value` ("100 %", "150 %", …, `intl`-formatted per locale), plus
  `Zoom in`/`Zoom out`/`Reset zoom` custom actions (only the enabled ones are
  offered), and it is a `Focus` target (a Tab stop). 200% text: initials clamp
  at `KitTokens.monogramMaxTextScale` (verified against an unclamped
  `TextScaler.linear(2)` paragraph). RTL: `KitAvatar`'s Arabic initials use
  each word's first grapheme with no case fold (verified: "محمد علي" → "مع");
  `KitZoom`'s controls pill uses `PositionedDirectional`/`EdgeInsetsDirectional`
  throughout (bottom-*start*-to-end reading order for out/reset/in).
- Privacy and security: n/a — no credentials, stored data, external links or
  notifications are touched. `KitImageSource` never accepts a raw URL string
  (SEC-1): a network image can only arrive as a caller-built `ImageProvider`.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_image_test.dart
$F test -j 1 test/goldens/kit/kit_image_golden_test.dart
$F analyze lib/ui/kit/kit_image.dart test/kit/kit_image_test.dart test/goldens/kit/kit_image_golden_test.dart
$F analyze lib test
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart test/l10n_coverage_test.dart test/ui_glossary_test.dart test/ui_ledger_coverage_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (coordinator work at the wave checkpoint,
  R19/R20).
- The G6 overflow matrix (no images) and the shared `test/kit_motion_test.dart`
  / `test/kit/kit_keyboard_test.dart` / `test/text_scale_overflow_test.dart`
  registrations are wired up from `kit.dart`'s export table
  (`test/kit/kit_manifest_test.dart` reads that table, not a per-unit list),
  so they cannot be exercised or registered from this branch; this unit's own
  `test/kit/kit_image_test.dart` covers reduced motion, keyboard shortcuts and
  200% text directly instead (§5 above).
- `test/kit/kit_manifest_test.dart` (G4) fails on this branch — see "Contract
  problems": both causes are structural (kit.dart export timing; a scanner
  gap for `kitGalleryPart`) and outside this unit's write set.
- The three `KitZoom` control icons (`AppIconography.expand` / `collapse` /
  `retry`) are a cosmetic stand-in pending a coordinator decision (see
  "Contract problems"); every test finds and asserts on the controls by their
  `label` field (the true accessible name), never by icon, so this does not
  affect proof of behaviour.

## Contract problems (PROC-20)

1. **kit_manifest_test.dart's NAME-1 assumption vs. the frozen one-file spec.**
   `docs/ux-system/kit-api/KitImage.md` ("File") explicitly puts `KitImage`,
   `KitAvatar` and `KitZoom` in one file, `lib/ui/kit/kit_image.dart`, with one
   test file and one golden file — exactly this unit's write set. `test/kit/
   kit_manifest_test.dart` (G4, NAME-1) instead expects each class in its own
   `lib/ui/kit/kit_<snake>.dart` with its own `test/kit/kit_<snake>_test.dart`
   and `test/goldens/kit/kit_<snake>_golden_test.dart`, and reports `name`,
   `test` and `gallery` violations for `KitAvatar` and `KitZoom` on that basis.
   Evidence: `$F test -j 1 test/kit/kit_manifest_test.dart` output, recorded
   verbatim in this unit's session log. Fix belongs to the coordinator: either
   grant `kit_image.dart`'s three classes a documented multi-class exception
   (the kind of reasoned entry `_forcedLtrFiles`/`_tokenFiles` already use in
   `test/kit_ratchet_test.dart`), or confirm the spec's placement and adjust
   the manifest's per-class assumption for multi-class units. Not worked
   around: the frozen spec's explicit file layout was followed exactly.
2. **`exported`/`docRow` violations are inherent to being pre-integration.**
   `KitImage`/`KitAvatar`/`KitZoom` are not yet in `lib/ui/kit/kit.dart`'s
   export table (R06: "the integrator adds exports") or its doc table
   (KIT-14), so the manifest's `exported` and `docRow` checks fail for all
   three by construction. This is the same situation every kit-part unit's
   own branch is in before merge; no action taken here beyond not touching
   `kit.dart` (R06/PROC-13).
3. **The manifest's gallery scanner does not see `kitGalleryPart(...)`.**
   `test/kit/kit_manifest_test.dart`'s shot collector matches only
   `\bkitGalleryShot\s*\(` (the modal-opener helper) and `matchesGoldenFile(`
   with a literal first argument; it has no rule for `kitGalleryPart(...)`,
   the plain-widget helper `test/goldens/kit/kit_gallery.dart` itself
   documents for "a part that is not a modal: rows, buttons, cards, type" —
   exactly what `KitImage`/`KitAvatar`/`KitZoom` are (none is a `showKit…`
   opener). Because of this, the manifest reports `stateScenes` and `gallery`
   violations ("lacks a …text2… golden", "lacks an …_ar_… golden") even
   though `test/goldens/kit/kit_image_golden_test.dart` genuinely has both
   (`textScale: 2`, `Locale('ar')`, `kitGallerySizes`, `kitGalleryScaledSizes`
   are all present and used, and every shot passes its own G5 accessibility
   check). `test/goldens/kit/kit_foundation_golden_test.dart` is the only
   other `kitGalleryPart` user in the tree and does not hit this because it
   predates the G4 gate and sits outside the manifest's scan entirely via its
   own history, not because its shots are recognised. This is a gap in the
   shared harness itself, not in this unit's galleries; fixing it means
   teaching `_Gallery` in `kit_manifest_test.dart` to also parse
   `kitGalleryPart(` calls, which is squarely the shared file no kit-part
   unit may stage (STANDARDS.md, "Shared files you never stage"). Reported,
   not worked around: this unit did not invent a `kitGalleryShot`-shaped
   wrapper around a non-modal part just to satisfy the scanner.
4. **No dedicated zoom-in/zoom-out/fit icon vocabulary exists yet.** KitZoom's
   frozen spec calls for "three KitIconButtons (zoom out, reset, zoom in; the
   existing v1 API)" but names no glyphs, and `lib/ui/app_iconography.dart`
   (where a new verb's `IconData` would be added) is outside this unit's
   write set. `AppIconography.collapse` (already the exact glyph the work
   graph's own Fit control uses, one of the InteractiveViewer call sites this
   unit replaces), `.expand` and `.retry` are used as reasonable, distinct
   stand-ins; every behaviour test and the controls' accessible name (the
   `KitIconButton.label`, which is also the tooltip and the semantic name)
   are correct regardless of icon choice. A coordinator follow-up to add
   dedicated glyphs is a same-shape, no-behaviour-change edit.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitImage` |
| Enabled | No: not exported from `kit.dart` yet (integrator, R06) | |
| Verified | Tests and goldens only (59 total: 23 behaviour + 36 golden) | this record |
| Committed | Yes | code head `dbce0a98` |
| Deployed | No | |
| Released | No | |
