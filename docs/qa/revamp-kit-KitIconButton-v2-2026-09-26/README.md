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
  `test/goldens/kit/kit_icon_button_golden_test.dart` (new), 36 new PNGs under
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
  - **`/// States:` line vs KIT-12 (unresolved; spec to amend at the freeze).** The frozen API
    block writes `/// States: disabled, working, selected, copied (KIT-12).`, but KIT-12 (STANDARDS.md)
    limits declared states to {loading, empty, error, disabled, working, answered}, and gate G4
    (`test/kit/kit_manifest_test.dart`, `kitManifestStates`) fails any other word. The part keeps
    the KIT-12 line `/// States: disabled, working.` and says in its doc comment that selected,
    copied, destructive, hover and focused are looks covered by the gallery and contract test,
    not KIT-12 states. The spec's API block should drop `selected, copied` (or KIT-12 should
    gain them) at the freeze.
  - **915×412 is a real LAY-4 size, and the shared harness lacks it.** TEST-9, LAY-4 and this
    unit's spec list 360×800, 915×412 (a phone in landscape), 800×1280, 1280×800 and 1600×1000
    as the other gallery sizes. `kitGallerySizes` in `test/goldens/kit/kit_gallery.dart` has
    412×915 in place of 915×412 (gate G4 already notes it: `'harness': ['kitGallerySizes 915x412']`
    in `kit_manifest_test.dart`). An earlier revision of this record called 915×412 a typo; that
    was wrong. This gallery now renders `kit_icon_button_default_915x412_{dark,light}.png` itself
    (`[...kitGallerySizes, const Size(915, 412)]`) without editing the harness. The harness
    should gain the landscape entry (integrator/harness owner).
  - **"The tooltip wraps up to two lines" is a copy-length limit, not something the button can
    enforce.** At 2.0 text on a 412 dp phone, a label of about 40 characters ("Retry the
    connection to this server") takes two lines; a longer one takes three. The button never
    cuts the text (no `maxLines`), which is the half of the rule it controls; keeping labels
    short is the caller's (and COPY review's) job.
  - `docs/ux-system/revamp/STANDARDS.md` EVID-1 requires the QA folder
    `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/`, but the task list handed to this unit said
    `docs/qa/revamp-<unit id>/` (no date). Followed EVID-1 (the rulebook) since it is explicitly
    "the one rulebook" and is what gate G32 checks; this folder is named with the date.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a — no map pages assigned to this unit.
- States per page (STATE-20): n/a — not a screen unit. KitIconButton's own declared states
  (`States: disabled, working.`) are proven in `test/kit/kit_icon_button_test.dart` and
  `test/goldens/kit/kit_icon_button_golden_test.dart` (see Runs and Evidence below); its other
  looks (selected on/off, destructive, hover, focused, copied) are outside the KIT-12
  vocabulary (see the first contract problem) but are covered by the same two files.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitIconButton-v2`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`
  (`feat/phone-setup-v2`). First build `bdbec9f4`; review fixes in the `fix(kit): KitIconButton
  review fixes` commit on top of it (focus ring, disabled-reason tooltip, tests, gallery).
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator/checkpoint work.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: the review-fix tests on `bdbec9f4` (before the fix) | the new keyboard, ring-over-hover and disabled-tooltip tests fail | 4 failed: one Tab then one frame loses focus (line 716), two-Tab focus lost (767), focused+hovered focus lost (803), tooltip has no reason span (309) — `failing-first.txt` | PASS (fails first) |
| 2 | `test/kit/kit_icon_button_test.dart` | passes | 24 passed | PASS |
| 3 | `test/goldens/kit/kit_icon_button_golden_test.dart` (against the committed goldens, no `--update-goldens`) | passes | 38 passed (36 PNGs; the default 412×915 pair is compared twice) | PASS |
| 4 | `test/kit_ratchet_test.dart` + `test/design_standard_test.dart` (G1, G2, G3x, G7, G15, G15x, G16, G17, G21, G48) | passes | 47 passed | PASS |
| 5 | `test/golden_harness_test.dart` (G23) | passes | passed | PASS |
| 6 | `test/kit/kit_secret_field_test.dart`, `test/mcp_setup_screen_test.dart` (existing `label:` callers) | passes | 13 passed | PASS |
| 7 | `test/kit/kit_manifest_test.dart` (G4) | passes | 1 failed: the stale allowlist entries for KitIconButton (`states`, `gallery`, `test`) — see NOT proven and `sharedTestsBroken` | FAIL (shared, reported) |
| 8 | `flutter analyze` (whole tree) | no issues | No issues found! | PASS |

## 5. Evidence

- `failing-first.txt`: the review-fix tests against the part at `bdbec9f4` (Runs row 1).
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-22 | `test/kit/kit_icon_button_test.dart` "an empty tooltip and no label asserts (KIT-22)" | throws `AssertionError` |
  | KIT-43 | `test/kit/kit_icon_button_test.dart` "label: alone still renders, and the semantic label equals it"; `test/kit/kit_secret_field_test.dart`, `test/mcp_setup_screen_test.dart` (unchanged, still pass) | PASS |
  | G9 (copy contract) | `test/kit/kit_icon_button_test.dart` "copies at tap time, announces Copied once, shows no SnackBar, and the check reverts after the hold" | PASS |
  | G12 (redaction) | `test/kit/kit_icon_button_test.dart` "a fake provider key is redacted before it reaches the clipboard" | clipboard text has no key |
  | G8x (reduced motion) | `test/kit/kit_icon_button_test.dart` group "reduced motion settles after one pump (G8x)": each state reached from the default look in one host; after one pump only the new glyph is in the tree, no ticker runs, and the next frame is idle; "without reduced motion the same swap cross-fades" shows the check can fail; "copied, under reduced motion" shows the hold still runs | PASS |
  | G14 / LAY-10 (keyboard) | "one Tab reaches it and it keeps focus: the ring shows, Enter and Space activate it"; "after a focusable neighbour, exactly two Tabs reach it, and the ring goes when focus moves on" | PASS |
  | §8.3 (ring always visible) | "focused and hovered, the ring paints above the hover fill (§8.3)" | ring is a foreground decoration over the Material |
  | G14x (tooltip = semantic label) | "the semantic label equals the tooltip; a fine pointer adds the shortcut"; "a disabled button tooltip says why: the label span, then the reason" | PASS |
  | STATE-8 / spec `disabledReason` | "a disabled button tooltip says why…"; "an enabled or working button tooltip has no reason span"; "onPressed: null disables the button…" (the same button counts a tap while enabled, then not once disabled; InkWell `onTap` is null) | PASS |
  | 200 % text | "at 412x915 and text 2.0 the long-press tooltip wraps to at most two lines and is not cut"; golden `kit_icon_button_default_text2_{dark,light}.png` | PASS |
  | TEST-9 (gallery) | `test/goldens/kit/kit_icon_button_golden_test.dart` | 36 PNGs, listed below |
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
  - `kit_icon_button_default_{360x800,915x412,800x1280,1280x800,1600x1000}_{dark,light}.png`: the
    default state at the other LAY-4 sizes. The 915×412 pair was added by the review fix (the
    buttons sit at the top of the landscape phone because the scene is centred in the pushed
    route's body; nothing is clipped).
  - `kit_icon_button_default_text2_{dark,light}.png` (412×915): changed by the review fix. It now
    shows the compact-window path: a held touch long-press on the ground copy shows the tooltip
    "Retry the connection to this server" at 2.0 text, wrapped to two lines, not cut. Before, it
    was byte-identical to `kit_icon_button_default_*` (no text on screen at rest).
  - `kit_icon_button_default_ar_…png` and the 1280×800 text2/ar pairs: default in Arabic (RTL: the
    scene's decorative row mirrors, as a plain `Row` does under `Directionality.rtl`); the
    1280×800 pairs show the hover tooltip with its `Ctrl+R` shortcut, isolated LTR.
  - `kit_icon_button_focused_{dark,light}.png` and `_hover_…`: unchanged by the review fix (the
    ring moved to a foreground decoration and paints the same pixels when not hovered); the
    focused shot now takes exactly one Tab and asserts focus on the ground copy.
  - No approved VL canvas render exists for this part (EVID-12): "none".
- Before and after: no before render exists for a new gallery (EVID-10 "no before render", page id
  `kit-icon-button`); after: the 36 PNGs above.
- Accessibility: semantic label equals the tooltip text (asserted); a disabled button's tooltip
  adds `disabledReason` as a second line (the label span stays first, G14x); keyboard focus
  survives the ring appearing, and the ring is removed when focus leaves; hint is
  `disabledReason` when disabled, `l10n.kitWorking` while working, otherwise the shortcut; `toggled` only when `selected`
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
- On a 412 dp phone at 2.0 text the long-press tooltip spans the full width with no side margin
  (Material's default tooltip margin). The spec does not set a margin; flagged for the look
  review, not changed.
- The widget-test line count for the 2.0-text tooltip uses the test font (Ahem, 1 em per
  character), so "two lines" there is about Ahem widths; the golden shows the real font.
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
| Committed | Yes | `bdbec9f4` plus the review-fix commit on `revamp/kit-KitIconButton-v2` |
| Deployed | No | |
| Released | No | |
