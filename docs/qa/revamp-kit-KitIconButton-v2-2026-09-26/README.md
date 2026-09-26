# revamp-kit-KitIconButton-v2: KitIconButton v2 (2026-09-26)

## 1. Scope

- Unit: `kit-KitIconButton-v2` (wave 1, tier 1a, kit-change). Finish line: `KitIconButton` matches
  docs/ux-system/kit-api/KitIconButton.md (look, API, states, adaptive, `.copy`), its gallery and
  contract tests exist, and every existing call site (`kit_secret_field.dart`,
  `mcp_setup_screen.dart`) still compiles with unchanged behaviour. Non-goal: no screen migration,
  no shortcut binding, no filled/outlined variant, no text label next to the icon, no badge — all
  explicitly out of scope per the spec's "Non-goals".
- Files changed: `lib/ui/kit/kit_icon_button.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`
  (two new keys, `kitCopy`/`kitWorking`), `test/kit/kit_icon_button_test.dart` (new),
  `test/goldens/kit/kit_icon_button_golden_test.dart` (new), 34 new PNGs under
  `test/goldens/kit/`. `lib/l10n/app_localizations*.dart` regenerated locally then restored
  (PROC-13; never committed by a unit).
- Pages (map ids): none — this unit is tier 1a with no map assignment of its own; kit-v2.json's
  22-element `assignment` for KitIconButton is wave-2 screen-migration work (KitIconButton.md
  "Replaces").
- Specs followed: docs/ux-system/kit-api/KitIconButton.md (frozen API); kit-v2.md §1.10, §8.2,
  §8.3, §4.8; STANDARDS.md §1, §4, §15, §18 (G4, G8x, G9, G12, G14x, G16, G17, G20, G21, G23, G37);
  KIT-22, KIT-23, KIT-39, KIT-43, LAY-9, LAY-11, STATE-7, STATE-8, A11Y-1, LOOK-5, LOOK-6, LOOK-33,
  R23.
- Contract problems (PROC-20):
  - STANDARDS.md TEST-9 and this unit's frozen spec both list the "other LAY-4 gallery sizes" as
    "360×800, 915×412, 800×1280, 1280×800 and 1600×1000" (5 sizes, "10 PNGs"), but the shared
    harness's actual `kitGallerySizes` (`test/goldens/kit/kit_gallery.dart`, which a kit unit may
    not edit) is `360×800, 412×915, 800×1280, 1280×800, 1600×1000` — i.e. the phone entry is
    written backwards in both prose documents (915×412 vs 412×915) and does not exist as a
    distinct size in code. Read literally, this makes the spec's own size list impossible to
    satisfy with the actual `kitGallerySizes` constant. Worked around the only way that does not
    edit the shared harness: the gallery iterates `kitGallerySizes` itself (all 5 real entries,
    dark+light = 10 test cases as the spec's own count implies), which reproduces the same
    `kit_icon_button_default_dark`/`_light` files the "each state" bullet already writes (harmless
    — same content, same name) rather than a 6th, nonexistent 915×412 size. Total distinct PNGs is
    therefore 34, not the spec's nominal "36" (36 counts that default@412×915 pair twice, once per
    bullet). Reported, not resolved unilaterally — the coordinator should correct the doc's digit
    order or confirm this reading.
  - `docs/ux-system/revamp/STANDARDS.md` EVID-1 requires the QA folder
    `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/`, but the task list handed to this unit said
    `docs/qa/revamp-<unit id>/` (no date). Followed EVID-1 (the rulebook) since it is explicitly
    "the one rulebook" and is what gate G32 checks; this folder is named with the date.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a — no map pages assigned to this unit.
- States per page (STATE-20): n/a — not a screen unit. KitIconButton's own declared states
  (`States: disabled, working.`) are proven in `test/kit/kit_icon_button_test.dart` and
  `test/goldens/kit/kit_icon_button_golden_test.dart` (see Runs and Evidence below); its other
  visual states (selected on/off, destructive, hover, focused, copied) are outside the KIT-12
  vocabulary but are covered by the same two files.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitIconButton-v2`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`
  (`feat/phone-setup-v2`), code head `bdbec9f4a8f4786429723984e993bfbd3cbca667`.
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator/checkpoint work.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: the fix's test on the base without the fix | fails with an assertion | n/a: this unit adds `KitIconButton` v2 behaviour, it does not fix a reported bug (no `fix(` commit) | n/a |
| 2 | `test/kit/kit_icon_button_test.dart` | passes | 19 passed | PASS |
| 3 | `test/goldens/kit/kit_icon_button_golden_test.dart` (against the committed goldens, no `--update-goldens`) | passes | 36 passed | PASS |
| 4 | `test/kit_ratchet_test.dart` (G1, G2, G7, G15, G15x, G16, G17, G21, G48) | passes | 32 passed | PASS |
| 5 | `test/design_standard_test.dart` (G3x) | passes | 15 passed | PASS |
| 6 | `test/l10n_coverage_test.dart` | passes | 2 passed | PASS |
| 7 | `test/kit/kit_secret_field_test.dart` (existing caller, `label:` via `KitIconButton`) | passes | 3 passed | PASS |
| 8 | `test/mcp_setup_screen_test.dart` (existing caller, `label:` via `KitIconButton`) | passes | 10 passed | PASS |
| 9 | `test/kit/kit_manifest_test.dart` (G4) | passes | 1 failed — see Evidence and `sharedTestsBroken` below | FAIL (shared, reported) |
| 10 | `flutter analyze` (whole tree) | no errors, no new issues | No issues found! | PASS |

## 5. Evidence

- `failing-first.txt`: n/a — see Runs row 1.
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-22 | `test/kit/kit_icon_button_test.dart` "an empty tooltip and no label asserts (KIT-22)" | throws `AssertionError` |
  | KIT-43 | `test/kit/kit_icon_button_test.dart` "label: alone still renders, and the semantic label equals it"; `test/kit/kit_secret_field_test.dart`, `test/mcp_setup_screen_test.dart` (unchanged, still pass) | PASS |
  | G9 (copy contract) | `test/kit/kit_icon_button_test.dart` "copies at tap time, announces Copied once, shows no SnackBar, and the check reverts after the hold" | PASS |
  | G12 (redaction) | `test/kit/kit_icon_button_test.dart` "a fake provider key is redacted before it reaches the clipboard" | clipboard text has no key |
  | G8x (reduced motion) | `test/kit/kit_icon_button_test.dart` group "reduced motion settles after one pump (G8x)" (6 states + copied) | `hasScheduledFrame` false after one pump in every case |
  | G14x (keyboard, tooltip = semantic label) | `test/kit/kit_icon_button_test.dart` "Tab reaches it, the focus ring shows, Enter and Space activate it"; "the semantic label equals the tooltip; a fine pointer adds the shortcut" | PASS |
  | TEST-9 (gallery) | `test/goldens/kit/kit_icon_button_golden_test.dart` | 34 PNGs, listed below |
  | LAY-9 / target | `test/kit/kit_icon_button_test.dart` "the target is 48x48 at text 1.0 and 2.0, compact and large" (+ `androidTapTargetGuideline`) | PASS |

- Changed test expectations (TEST-19): none — no existing test's expectations changed.
- Goldens changed (all new, each opened and looked at):
  - `kit_icon_button_default_{dark,light}.png`: the button on `ground` and on a `surface1` panel.
  - `kit_icon_button_disabled_{dark,light}.png`: `text3` glyph, no fill.
  - `kit_icon_button_working_{dark,light}.png`: the still `accent` dot (reduced motion in every
    gallery shot; no ticking spinner is rendered).
  - `kit_icon_button_selected_on_{dark,light}.png` / `_selected_off_…`: an `accent` glyph on a
    `surface3` circle when true; the plain glyph when false.
  - `kit_icon_button_destructive_{dark,light}.png`: `danger`-tinted glyph (regenerated once after
    an initial render that omitted `destructive: true` on the scene — caught by looking at the
    image before committing, TEST-6).
  - `kit_icon_button_hover_{dark,light}.png`: the `surface3` hover circle and the tooltip bubble.
  - `kit_icon_button_focused_{dark,light}.png`: the `accent` focus ring.
  - `kit_icon_button_copied_{dark,light}.png`: the ground copy shows the check, the untapped panel
    copy still shows the copy icon.
  - `kit_icon_button_default_{360x800,800x1280,1280x800,1600x1000}_{dark,light}.png`: the default
    state at the other gallery sizes.
  - `kit_icon_button_default_text2_…png` / `_ar_…png`: default at text 2.0 and in Arabic (RTL: the
    scene's decorative row mirrors, as a plain `Row` does under `Directionality.rtl`); the
    1280×800 pair additionally shows the hover tooltip with its `Ctrl+R` shortcut, isolated LTR.
  - No approved VL canvas render exists for this part (EVID-12): "none".
- Before and after: no before render exists for a new gallery (EVID-10 "no before render", page id
  `kit-icon-button`); after: the 34 PNGs above.
- Accessibility: semantic label equals the tooltip text (asserted); hint is `disabledReason` when
  disabled, `l10n.kitWorking` while working, otherwise the shortcut; `toggled` only when `selected`
  is non-null; 48×48 target checked at text 1.0/2.0 on a compact and a large window with
  `androidTapTargetGuideline`; the copy announcement fires once via `SemanticsService.announce`.
- Privacy and security: n/a — no credentials, stored data or external links changed. `.copy`
  copies only through `KitCopy.copy`, which redacts before it reaches the clipboard (tested).
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_icon_button_test.dart
$F test -j 1 test/goldens/kit/kit_icon_button_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart test/l10n_coverage_test.dart
$F test -j 1 test/kit/kit_secret_field_test.dart test/mcp_setup_screen_test.dart
$F analyze
```

## 7. NOT proven

- Not run on a device or emulator.
- The hover and focused galleries interact with only the `ground` copy of the pair (one mouse
  pointer / one focus at a time cannot hold both simultaneously); the `surface1` panel copy is
  shown at rest in those two shots. Selected, disabled, working, destructive and copied are shown
  on both copies since those are plain configuration, not live pointer/focus state.
- No golden or test proves the exact 48×48 tap target keeps 8 dp from a destructive neighbour's
  target (LAY-9 whole-screen composition) — that is a page-composition check, out of scope for a
  kit part in isolation.
- `test/kit/kit_manifest_test.dart` (gate G4) now fails for this part: KitIconButton was on
  `test/kit/kit_manifest_allowlist.json`'s shrinking allowlist for the `states`, `gallery` and
  `test` checks (it predates gate G4), and this unit's doc comment, contract test and gallery now
  satisfy all three — which the allowlist mechanism treats as a *failure* until the now-stale
  entries are removed (`KIT_MANIFEST_WRITE=1`). `kit_manifest_allowlist.json` is not in this
  unit's write set (not listed under PROC-13's baseline or registry files), so it was not edited;
  see `sharedTestsBroken` in the build record. `docRow` stays on the allowlist unchanged, since
  `kit.dart`'s doc table (owned by the integrator, R06) was not touched.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitIconButton-v2` |
| Enabled | Yes — no flag; existing call sites already use it | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `bdbec9f4a8f4786429723984e993bfbd3cbca667` |
| Deployed | No | |
| Released | No | |
