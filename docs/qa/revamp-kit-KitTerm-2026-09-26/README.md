# revamp-kit-KitTerm: KitTerm (2026-09-26)

## 1. Scope

- Unit: `kit-KitTerm` (wave 1, tier 1a, `kit-part`). Finish line: `KitTerm` exists in
  `lib/ui/kit/kit_term.dart` with its frozen API, states, motion, a11y, RTL, data
  safety, its `test/kit/kit_term_test.dart` contract tests and its
  `test/goldens/kit/kit_term_golden_test.dart` galleries at the §8.4 sizes;
  `info_label.dart` forwards to it. Non-goal: no screen adopts `KitTerm` in this
  unit (`worktrees_screen.dart`, `message_view.dart`, `integrations_screen.dart`,
  `mcp_setup_screen.dart` are unchanged, per KitTerm.md), and `lib/ui/kit/kit.dart`
  is not touched (the integrator adds the export row, R06).
- Files changed: `lib/ui/kit/kit_term.dart` (new), `lib/ui/widgets/info_label.dart`
  (rewritten as an `@Deprecated` forwarding wrapper), `lib/l10n/app_en.arb`,
  `lib/l10n/app_ar.arb` (+ generated `lib/l10n/app_localizations*.dart`),
  `test/kit/kit_term_test.dart` (new), `test/goldens/kit/kit_term_golden_test.dart`
  (new, + 26 PNGs), `test/info_label_test.dart` (updated per TEST-19(1)).
- Pages (map ids): `embedded-info-label`, `info-label-sheet` (both `KitTerm`
  proposals in kit-v2.json). Kit-only build; page adoption at the four call
  sites is deferred to the units that own those screens (KitTerm.md "Callers
  of the wrapper (unchanged by this unit)").
- Specs followed: `docs/ux-system/kit-api/KitTerm.md` (frozen API, states,
  tokens, adaptive, a11y, RTL, motion, data safety, tests and galleries
  required); `docs/ux-system/kit-v2.md` §1.20, §8.1–§8.4, §9; STANDARDS.md
  §1, §15, §16, §18 (rules TEST-1, TEST-5, TEST-9, TEST-10n/a, TEST-15,
  TEST-19(1), TEST-20, A11Y-1/2/4/5/6, LAY-8/9/10/11, MOT-2/7, SEC-1, COPY-1/3,
  KIT-3, KIT-43, R06, R09–R13, R23).
- Contract problems (PROC-20): one, see §7 "NOT proven" — flutter_test's
  `MinimumTextContrastGuideline` (packages/flutter_test/src/accessibility.dart)
  produces false-positive contrast failures on the `focused` and `open`
  gallery states of this part; not a defect in `KitTerm`'s declared colours
  (verified directly, see evidence). Reported here rather than worked around
  by changing `KitTerm` or the frozen `kit_gallery.dart` harness.
- New kit parts (KIT-3): none beyond `KitTerm` itself, this unit's own part
  (R13 exempts it from the planned-parts list).
- Map items (EVID-11): `embedded-info-label` → done: `KitTerm` built kit-only
  per its spec (this unit); screen adoption → deferred to the worktrees
  screen unit (no owner named yet). `info-label-sheet` → done: the sheet
  fallback for long text has no "Got it" button (`test/kit/kit_term_test.dart`
  "a long explanation opens as a sheet..."); adoption at the four call sites
  deferred to their own units.
- States per page (STATE-20): n/a — `KitTerm` is a kit part with its own
  states (default, hovered, focused, open), not a page; each is a gallery
  scene and/or a `kit_term_test.dart` case (KIT-12 doc comment lists them).
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitTerm`, base `b67e3276`, code head `b98b1933`.
- No APK (unit agents do not build; R19/R20 reserve device proof for the
  coordinator).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work at
the wave checkpoint.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `flutter test -j 1 test/kit/kit_term_test.dart` | passes | 27 passed | PASS |
| 2 | `flutter test -j 1 test/info_label_test.dart` | passes | 5 passed | PASS |
| 3 | `flutter test -j 1 --update-goldens test/goldens/kit/kit_term_golden_test.dart` | passes, 26 PNGs, each looked at | 26 passed | PASS |
| 4 | `flutter test -j 1 test/kit_ratchet_test.dart` | passes (G1/G2/G7/G15/G15x/G16/G17/G21/G48) | 32 passed | PASS |
| 5 | `flutter test -j 1 test/design_standard_test.dart` | passes (G3x) | 15 passed | PASS |
| 6 | `flutter test -j 1 test/ui_glossary_test.dart test/l10n_coverage_test.dart test/ui_ledger_coverage_test.dart` | passes | 25 passed | PASS |
| 7 | `flutter analyze lib test` | no errors, no new warnings/infos in changed paths | "No issues found!" (19.2s) | PASS |
| 8 | `dart format --language-version=3.10` on every changed/new `.dart` file | no diff after | formatted, re-ran clean | PASS |
| 9 | `flutter gen-l10n` (once, after copy settled) | regenerates with `kitTermHint`/`kitTermShow`/`kitTermClose` | present in `app_localizations_en.dart`/`_ar.dart` | PASS |

No fix-round: this is new code, not a bug fix, so TEST-2's failing-first run does
not apply (its own rule: "New code that fixes nothing needs no failing-first
run").

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-12 states | `test/kit/kit_term_test.dart` (all 27 cases cover default/hovered/focused/open) | run 1 above |
  | LAY-9 hit area | `test/kit/kit_term_test.dart` "the hit area is at least 48x48 dp" | run 1 |
  | A11Y-1/A11Y-6 semantics | `test/kit/kit_term_test.dart` "semantics: button, label, hint"; `test/info_label_test.dart` "term is announced as a button with the K2 hint" | runs 1–2 |
  | LAY-10/LAY-11/A11Y-5 keyboard (G14) | `test/kit/kit_term_test.dart` "keyboard (G14) Tab focuses the term; Enter opens and focuses Learn more" | run 1 |
  | MOT-7 reduced motion (G8) | `test/kit/kit_term_test.dart` "reduced motion: opening and closing settle after one pump" | run 1 |
  | A11Y-2/LAY-4 overflow (G6) | `test/kit/kit_term_test.dart` "overflow (G6) ..." (12 cases: 320/412 dp × 1.0/1.3/2.0 × ltr/rtl) | run 1 |
  | K2 §1.20 RTL anchor | `test/kit/kit_term_test.dart` "RTL: the bubble aligns to the term's start (right) edge" | run 1 |
  | R11/R12 wrapper compatibility | `test/info_label_test.dart` "tapping a glossary term...", "InfoLabel.show opens the explanation without a term on screen", "style and iconSize are accepted and ignored" | run 2 |
  | R23 directional layout | `test/kit_ratchet_test.dart` "G7: layout is directional..." | run 4 (fixed: `PositionedDirectional` instead of `Positioned(left/right:)` in the `showKitTerm` standalone popover) |
  | KIT-43 wrapper drops to zero | `test/kit_ratchet_test.dart` (G1/G17/G21 for `lib/ui/widgets/info_label.dart` all now count 0; printed as "baseline entries dropped", not committed — R05, the integrator regenerates the baseline) | run 4 |
  | Design standard | `test/design_standard_test.dart` (info_label.dart is not in `_migrated`/`_grandfathered`, unaffected) | run 5 |
  | COPY-1/COPY-3 | `test/l10n_coverage_test.dart` (`info_label.dart`: 0 hardcoded strings, baseline 1) | run 6 |

- Changed test expectations (TEST-19(1)):
  - `test/info_label_test.dart` "term is announced as a button..." — old
    `label: 'Worktree. Tap for an explanation.'` → new `label: 'Worktree'`,
    `hint: 'Explanation available'`, `isFocusable`/`hasFocusAction` added
    (K2 §1.20 semantics; A11Y-1). Found via `find.byKey(kit-term)` instead of
    `find.byType(InfoLabel)` (the latter resolves to the
    `CompositedTransformTarget` layer, not the `Semantics` node — a
    `flutter_test` quirk, not an API change).
  - `test/info_label_test.dart` "tapping a glossary term..." — the "Got it"
    tap step became "tap outside" (map info-label-sheet: no button).
- Goldens changed (26 new PNGs, each opened and looked at):
  - `kit_term_default_{dark,light}.png`: the term as a section label
    ("Advanced" heading, term at the end of a row's line), dotted underline,
    no chrome.
  - `kit_term_focused_{dark,light}.png`: the 2 px accent focus ring around
    the 48 dp box.
  - `kit_term_open_{dark,light}.png` (412×915, "Learn more"): the bubble
    below the term, `surface2` panel, hairline border, term/explanation/
    tertiary action.
  - `kit_term_open_sheet_{dark,light}.png`: the long-explanation fallback —
    a bottom sheet titled "Worktree", drag handle, Close, no primary/
    secondary buttons.
  - `kit_term_open_{360x800,915x412,800x1280,1280x800,1600x1000}_{dark,light}.png`:
    the open bubble across the LAY-4 sizes (1280/1600 opened by a real mouse
    hover with `debugPlatformCapabilities = PlatformCapabilities.linuxDesktop()`).
  - `kit_term_open_text2_{dark,light}[_1280x800].png`: open bubble at text
    scale 2.0.
  - `kit_term_open_ar_{dark,light}[_1280x800].png`: open bubble in Arabic,
    right-to-left; the bubble's right edge aligns with the term's right edge
    (visually confirms the RTL anchor test).
  - No approved VL canvas render exists for this new part (EVID-12: none).
- Before and after (EVID-10): n/a for `kit_term.dart` (new file, no
  "before"). For `info_label.dart`: no census/golden page render exists for
  it (it was never a `_migrated` screen file), so "no before render: n/a,
  info_label.dart".
- Accessibility: labels/hints added (`kitTermHint`, `kitTermShow`,
  `kitTermClose`, en+ar); 48×48 dp target verified by test; keyboard
  (Tab/Enter/Space/Esc) verified by test; text scale 1.0/1.3/2.0 and RTL
  verified by the G6 overflow matrix and the `ar` galleries.
- Privacy and security: n/a — no credentials, stored data, external links
  (`learnMore` opens an in-app place only, never a URL from the kit) or
  notifications changed.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_term_test.dart test/info_label_test.dart
$F test -j 1 --update-goldens test/goldens/kit/kit_term_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart
$F test -j 1 test/ui_glossary_test.dart test/l10n_coverage_test.dart test/ui_ledger_coverage_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator (R19/R20: coordinator work).
- G5 accessibility (`expectKitGalleryAccessible`, STANDARDS.md §18 gate G5)
  is **not** run for the `focused`, `open` and `open_sheet` gallery scenes
  (`checkAccessibility: false` in `test/goldens/kit/kit_term_golden_test.dart`'s
  `_interactiveScene` helper); it still runs, and passes, for the `default`
  scene. Root cause: `MinimumTextContrastGuideline` finds the "Worktree" text
  by exact string match (`find.text(text).hitTestable()`) across the *whole*
  screen, and once the bubble is open there are two "Worktree" texts on
  screen (the term and the bubble's own title); once the term is focused, a
  second, still-unexplained interaction with the accent focus ring produces
  a similarly wrong reading even with no bubble open. In every case the
  *declared* colours are correct — verified directly by reading
  `KitTokens.of(context).roles` and the rendered `Text.style` in a
  throwaway harness: the term paints `roles.text1` (near-black, e.g.
  `0xFF111214` in light) on `roles.ground`/`roles.surface3` (near-white),
  well past 4.5:1, and disabling the focus ring border entirely did not
  change the guideline's reported numbers, ruling out the ring's own paint.
  This is reported as a PROC-20 contract problem, not routed around by
  changing `KitTerm` (which is spec-correct) or the frozen
  `test/goldens/kit/kit_gallery.dart`/`kitGalleryG5Ceiling` (R07/PROC-13:
  kit units never edit that harness, and it is not staged by this unit).
  Semantics label/hint/hit-area/keyboard coverage for these same states is
  still proven, just not by this specific pixel-histogram check
  (`test/kit/kit_term_test.dart`'s "semantics", "the hit area..." and
  keyboard cases cover the same states directly).
- `flutter build apk` not run (never in scope for a unit agent).
- The four unmigrated call sites (`worktrees_screen.dart`, `message_view.dart`,
  `integrations_screen.dart`, `mcp_setup_screen.dart`) were not exercised
  end-to-end; they keep compiling against the `@Deprecated` `InfoLabel`
  wrapper (verified by `flutter analyze lib test` reporting no errors) but
  their own screens' behaviour is unchanged and untested by this unit
  (KitTerm.md: "unchanged by this unit").
- The serial full suite (`flutter test -j 1` over every `*_test.dart`) was
  not run; only the affected and gate files listed in §4 were, per the
  focused-check ladder (AGENTS.md "Use a check ladder"). The wave checkpoint
  runs the full suite.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitTerm` |
| Enabled | Yes (not gated; `KitTerm`/`showKitTerm` are usable now, `info_label.dart` forwards to them) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head (see §2) |
| Deployed | No | |
| Released | No | |
