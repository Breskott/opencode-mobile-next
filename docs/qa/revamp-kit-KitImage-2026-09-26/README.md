# revamp-kit-KitImage: KitImage, KitAvatar, KitZoom (2026-09-26)

## 1. Scope

- Unit: `kit-KitImage` (wave 1, tier 1a, `kit-part`). Finish line: `KitImage`,
  `KitAvatar` and `KitZoom` exist in `lib/ui/kit/kit_image.dart` with their
  full §4 API, every declared state, their galleries (TEST-9) and their
  contract tests (TEST-15). Non-goal: no call site outside the kit changes
  (no screen migration).
- Files changed: `lib/ui/kit/kit_image.dart` (new); `test/kit/kit_image_test.dart`
  (new); `test/goldens/kit/kit_image_golden_test.dart` (new, plus its 38 PNGs);
  `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb` (new `kit*` keys only).
  The generated `lib/l10n/app_localizations*.dart` are **not** in the diff
  (PROC-13, G30, COPY-4): they were restored to `feat/phone-setup-v2` in
  `a4346f51`; `flutter gen-l10n` was run locally only to compile and test,
  and the integrator regenerates them after the merge.
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
  (`feat/phone-setup-v2`). First build `dbce0a98`; review-fix round on top
  (see "Review fixes, round 1" below).
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

| 10 | Round 1: `dart format --language-version=3.10` + `flutter analyze --no-pub` on the three write-set files | no issues | "No issues found!" | PASS |
| 11 | Round 1: `flutter test -j 1 test/kit/kit_image_test.dart` against the reviewed `kit_image.dart` (`dbce0a98`) | the new tests fail by assertion | 15 failed, 22 passed (`failing-first.txt`) | PASS (failing-first) |
| 12 | Round 1: `flutter test -j 1 --update-goldens test/goldens/kit/kit_image_golden_test.dart`, each changed PNG opened | 38 shots; the pill at the bottom end; Arabic initials in `_ar` | 38 passed; images looked at (zoom_rest `_ar` pill bottom left, avatar `_ar` "مع", 915×412 default, text2 failure words on two lines) | PASS |
| 13 | Round 1: `flutter test -j 1 test/kit/kit_image_test.dart test/goldens/kit/kit_image_golden_test.dart` (no update) | all pass | 75 passed (37 behaviour + 38 golden) | PASS |
| 14 | Round 1: `flutter test -j 1 test/golden_harness_test.dart test/kit_ratchet_test.dart` then `test/design_standard_test.dart test/l10n_coverage_test.dart` | pass | 40 passed; 17 passed | PASS |

Runs 10–14 used locally generated l10n (`flutter gen-l10n`), then the
generated files were restored to the base before committing (finding 1).

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

- Changed test expectations (TEST-19): no shared test was touched; this
  unit's own changed expectations are listed under "Review fixes, round 1".
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
  `Zoom in`/`Zoom out`/`Reset zoom` custom actions (only the ones that do
  something are offered: no reset at the start view, no zoom out at the
  smallest scale, no zoom in at the largest), and it is a `Focus` target (a
  Tab stop). A labelled `KitImage` that failed reads its label and "Can't
  show this image" in one image node. 200% text: initials clamp
  at `KitTokens.monogramMaxTextScale` (verified against an unclamped
  `TextScaler.linear(2)` paragraph). RTL: `KitAvatar`'s Arabic initials use
  each word's first grapheme with no case fold (verified: "محمد علي" → "مع");
  `KitZoom`'s controls pill sits at the bottom *end* (`PositionedDirectional(end:,
  bottom:)`: the bottom left under Arabic, see `kit_image_zoom_rest_ar_dark.png`),
  with zoom out, reset, zoom in in reading order.
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

## Review fixes, round 1 (2026-09-27)

Each finding, what changed, and the test that now proves it. Every fix below
is proven failing-first (TEST-2): `failing-first.txt` in this folder is
`test/kit/kit_image_test.dart` run against the reviewed `kit_image.dart`
(`dbce0a98`) — 15 assertion failures, no compile errors.

| # | Finding | Fix | Proof (`test/kit/kit_image_test.dart --plain-name`, or golden) |
|---|---|---|---|
| 1 | Generated l10n in the diff (PROC-13, G30, COPY-4) | restored the three `app_localizations*.dart` to the base (`a4346f51`); ARB additions kept | `git diff feat/phone-setup-v2 --stat -- lib/l10n` lists only the two ARBs |
| 2 | Pill centred, not at the bottom end (RTL) | `PositionedDirectional(end: space4, bottom: space4)`, no `Center` | `kit_image_zoom_rest_ar_dark.png` / `_ar_1280x800_dark.png`: pill at the bottom left, zoom out rightmost (first in reading order); `kit_image_zoom_rest_dark.png`: bottom right |
| 3 | Decode ignored the binding axis | both axes bounded: `contain` → `ResizeImage(policy: fit)`; `cover` (and every `KitAvatar`) → private `_KitCoverResizeImage` (shorter side covers the box, aspect kept, never upscales) | "contain in a height-bound box decodes to the box height" (25×100, was 400×1600); "cover decodes so the shorter side still covers the box" (1600×400, was 200×50); "a wide avatar image covers the circle without upscaling" (360×90, was 90×22) — real decodes of non-square PNGs, asserting the engine's decoded size |
| 4 | Failure indistinguishable from success for a screen reader | labelled `KitImage` is a container image node that no longer excludes its subtree; the failure state merges `kitImageUnavailable` into it (also when the words are not drawn) | "a failing labelled image (80dp) reads its failure words", "(200dp)", and "a loaded labelled image does not read the failure words" |
| 5 | No shortcut in tooltips | on `KitLayout.finePointer`, enabled controls are labelled `kitZoomShortcut` ("{action} · Ctrl+{key}", new ARB key, en + ar) | "with a fine pointer each tooltip carries its shortcut" |
| 6 | Ctrl+wheel handled twice; plain wheel zoomed | KitZoom no longer wraps `InteractiveViewer` (its `Listener` zooms on every wheel and cannot be told to require Ctrl); its own transform takes Ctrl/Cmd+wheel through `GestureBinding.pointerSignalResolver`, one step per notch, and ignores a plain wheel so the host can scroll | "one Ctrl+wheel notch zooms exactly one step at the pointer; a plain wheel does not zoom" (150 %, and 100 % for the plain wheel) |
| 7 | Canvas could be dragged off screen | one clamp for gestures, keys and zoom: a child larger than the view cannot leave a gap; a smaller one stays inside (room to centre) | "canvas mode fits a 2000x2000 child on open, pans within its bounds, …" (a ±5000 drag stops exactly at the edge) |
| 8 | Arrows unclamped, swallowed at rest, dead in canvas | `Shortcuts` + `Actions` with `isEnabled` per direction; clamped pan | "arrows pan only while zoomed, clamped to the image; at rest they reach the host"; "a canvas smaller than the view on one axis keeps panning room at the fitted start" |
| 9 | `_ar` avatar shots used English names; no 915×412 | `_avatarGallery(arabic: true)` ("محمد علي" → "مع"); default shot also at 915×412 | `kit_image_avatar_ar_dark.png`, `kit_image_default_915x412_{dark,light}.png` |
| 10 | Raw size literals (KIT-9) | glyph and avatar icon use `tokens.smallIconSize`; controller fallback clamps at `KitZoom.minScale`; `_panStep` stays a documented behaviour constant (like `maxScale`) | analyzer + existing glyph tests |
| 11 | Failure words ellipsized at 200 % | measured with a `TextPainter` in the secondary role at the ambient scale; words that need more than two lines are dropped, the glyph alone shows | "at 2.0 text the words that need more than two lines are dropped, never ellipsized; the glyph alone shows" |
| 12 | Reset action always offered; Fit never disabled | reset custom action only away from the start view; in canvas mode Fit is disabled at the fitted start with `kitZoomAtStart` | "the custom actions zoom in, zoom out and reset" (only "Zoom in" at rest); canvas test asserts the disabled Fit and its reason |
| 13 | Double-tap multiplied by 2 | absolute 2× at the tap point | "in canvas mode double-tap goes to an absolute 2x" (0.2 → 2.0); fit mode now asserts exactly "200 %" |
| 14 | Missing/weak tests | added: reduced-motion first frame, the cross-fade itself, the zoom-out action, canvas bounds; decode tests assert decoded sizes, not a null `height` field | "under reduced motion the first frame shows at once", "the first frame cross-fades in" |
| 15 | Unfrozen public `transformation` field | now private `_transformation`; the frozen constructor parameter is unchanged | analyzer (no outside reference) |

Changed test expectations in this unit's own tests (TEST-19): the double-tap
and Ctrl+= tests now assert the exact level ("200 %", "150 %") instead of
`isNot('100 %')` (stronger, finding 13/14); the reduced-motion and haptics
tests find the reset control as "Reset zoom · Ctrl+0" because they run under
desktop capabilities (finding 5, KitImage.md Adaptive); the decode-width
tests no longer assert `height` is null (finding 14).

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

5. **KitIconButton v1 has one string for tooltip and accessible name.**
   KitImage.md Adaptive asks for the shortcut in each control's *tooltip*
   ("Zoom in · Ctrl+="). The v1 `KitIconButton` this unit must use
   ("Depends on": the existing v1 API only) takes a single `label` that is
   both the tooltip and the semantic label, so on fine-pointer windows the
   shortcut is also spoken. Evidence: `lib/ui/kit/kit_icon_button.dart:24-30`.
   Proposed: kit-KitIconButton-v2 adds an optional `shortcut`/`tooltip`
   parameter and KitZoom passes the key there. blocks: false.
6. **"applied through `ResizeImage.resizeIfNeeded`" cannot express cover.**
   KitImage.md "Decode size" names `ResizeImage.resizeIfNeeded`, which only
   has the `exact` policy; a box bounded on both axes needs the binding axis
   from the source's own aspect ratio (review finding 3). `contain` uses
   `ResizeImage(policy: ResizeImagePolicy.fit)`; `cover` uses a private
   provider with the same decode hook and a cover target. Proposed text:
   "decoded at the laid-out size × devicePixelRatio on the axis that binds
   for the fit (contain: fits inside; cover: the shorter side covers), never
   upscaled". Evidence: `lib/ui/kit/kit_image.dart` `_decodeProvider`.
   blocks: false.
7. **The harness size list lacks 915×412.** KitImage.md "Galleries" lists
   915×412 for the default state; `kitGallerySizes`
   (`test/goldens/kit/kit_gallery.dart:105`) does not carry it. This gallery
   adds it locally (`[...kitGallerySizes, const Size(915, 412)]`); the shared
   list is the coordinator's to change. blocks: false.
8. **KitZoom no longer contains an `InteractiveViewer`.** Not a spec
   conflict (the spec says KitZoom *replaces* it), but a note for the
   migrating units: `zoomKey` now keys KitZoom's own transform, and a test
   that looked for `find.byType(InteractiveViewer)` under a migrated screen
   must look for `KitZoom` instead. Reason: `InteractiveViewer` zooms on
   every mouse wheel from its own `Listener` (not through the pointer-signal
   resolver), so "Ctrl+wheel zooms" could not be honoured with it inside.
   blocks: false.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitImage` |
| Enabled | No: not exported from `kit.dart` yet (integrator, R06) | |
| Verified | Tests and goldens only (75 total: 37 behaviour + 38 golden) | this record, runs 10–14 |
| Committed | Yes | first build `dbce0a98`; review round 1 on `revamp/kit-KitImage` |
| Deployed | No | |
| Released | No | |
