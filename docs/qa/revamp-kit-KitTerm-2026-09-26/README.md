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
- Contract problems (PROC-20): none. The first build's G5 suppression is
  withdrawn (review round, §4a): G5 now runs on all 26 shots in both themes.
- Write-set note for the coordinator (R04, R09): the first build commit
  (`b98b1933`) edits `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` and the
  generated `lib/l10n/app_localizations*.dart` to add the three spec-required
  keys `kitTermHint`, `kitTermShow`, `kitTermClose` (en + ar). The keys stay;
  merge or regenerate the l10n output once at integration, per the l10n
  process. The review round touches no l10n file.
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

- Branch `revamp/kit-KitTerm`, base `b67e3276`, first build `b98b1933`,
  code head after the review round `7844fbdd`.
- No APK (unit agents do not build; R19/R20 reserve device proof for the
  coordinator).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator work at
the wave checkpoint.

## 4. Runs

Runs 1–9: first build (`b98b1933`); runs 10–16: review round (§4a).

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `flutter test -j 1 test/kit/kit_term_test.dart` | passes | 27 passed | PASS |
| 2 | `flutter test -j 1 test/info_label_test.dart` | passes | 5 passed | PASS |
| 3 | `flutter test -j 1 --update-goldens test/goldens/kit/kit_term_golden_test.dart` | passes, 26 PNGs | 26 passed, but G5 was off for 24 shots and the 1280/1600 hover shots showed no bubble (review finding); superseded by run 12 | SUPERSEDED |
| 4 | `flutter test -j 1 test/kit_ratchet_test.dart` | passes (G1/G2/G7/G15/G15x/G16/G17/G21/G48) | 32 passed | PASS |
| 5 | `flutter test -j 1 test/design_standard_test.dart` | passes (G3x) | 15 passed | PASS |
| 6 | `flutter test -j 1 test/ui_glossary_test.dart test/l10n_coverage_test.dart test/ui_ledger_coverage_test.dart` | passes | 25 passed | PASS |
| 7 | `flutter analyze lib test` | no errors, no new warnings/infos in changed paths | "No issues found!" (19.2s) | PASS |
| 8 | `dart format --language-version=3.10` on every changed/new `.dart` file | no diff after | formatted, re-ran clean | PASS |
| 9 | `flutter gen-l10n` (once, after copy settled) | regenerates with `kitTermHint`/`kitTermShow`/`kitTermClose` | present in `app_localizations_en.dart`/`_ar.dart` | PASS |

### 4a. Review round (fix round, 2026-09-27, code head `7844fbdd`)

Review findings fixed: hover-open closed itself under the opaque barrier;
the bubble was not clamped to the window (Arabic bubble cut off at the left
edge); the focus ring showed after a touch tap; `showKitTerm`'s raw
`OverlayEntry` let back pop the screen underneath; the bubble announced
"Close explanation" instead of its content; Learn more ran before the sheet
closed; G5 was off for 24 of 26 shots; tests asserted anchor enums instead
of placement.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 10 | Failing first (TEST-2): the new `test/kit/kit_term_test.dart` against the first build's `kit_term.dart` (`b98b1933`) | the new cases fail | 11 failed: announcement, dismiss action, no ring on tap, sheet Learn more order, hover survives the fade, end-edge placement ×4 (ltr/rtl × 320/412), `showKitTerm` back, `showKitTerm` 320 dp | PASS (fails as expected) |
| 11 | `flutter test -j 1 test/kit/kit_term_test.dart test/info_label_test.dart` at `7844fbdd` | passes | 45 passed (39 + 6) | PASS |
| 12 | `flutter test -j 1 --update-goldens test/goldens/kit/kit_term_golden_test.dart` (run in `--plain-name` chunks), each image looked at, then a compare run | passes with G5 on every shot | 26 passed, compare run 26 passed | PASS |
| 13 | `flutter test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart` | passes | 47 passed | PASS |
| 14 | `flutter test -j 1 test/l10n_coverage_test.dart test/ui_glossary_test.dart` | passes | 23 passed | PASS |
| 15 | `flutter analyze` on the five changed Dart files | clean | "No issues found!" | PASS |
| 16 | `dart format --language-version=3.10` on the changed Dart files | no diff | 0 changed | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-12 states | `test/kit/kit_term_test.dart` (39 cases cover default/hovered/focused/open) | run 11 |
  | LAY-9 hit area | `test/kit/kit_term_test.dart` "the hit area is at least 48x48 dp" | runs 1, 11 |
  | A11Y-1/A11Y-6 semantics | `test/kit/kit_term_test.dart` "semantics: button, label, hint"; `test/info_label_test.dart` "term is announced as a button with the K2 hint" | runs 1–2, 11 |
  | LAY-10/LAY-11/A11Y-5 keyboard (G14) | `test/kit/kit_term_test.dart` "keyboard (G14) Tab focuses the term; Enter opens and focuses Learn more" | runs 1, 11 |
  | MOT-7 reduced motion (G8) | `test/kit/kit_term_test.dart` "reduced motion: opening and closing settle after one pump" | runs 1, 11 |
  | A11Y-2/LAY-4 overflow (G6) | `test/kit/kit_term_test.dart` "overflow (G6) ..." (12 cases: 320/412 dp × 1.0/1.3/2.0 × ltr/rtl) | runs 1, 11 |
  | K2 §1.20 RTL anchor | `test/kit/kit_term_test.dart` "RTL: the bubble aligns to the term's start (right) edge" (the bubble's global right edge equals the term's right edge, inside the window) | run 11 |
  | Adaptive: inside the window, gutter from each edge; explanation never cut | `test/kit/kit_term_test.dart` "the bubble stays inside the window, the gutter from each edge a term at the end edge, …" (ltr/rtl × 320/412) and "showKitTerm on a 320 dp window the popover fits inside the gutter" | run 11 |
  | Hover (test 9) | `test/kit/kit_term_test.dart` "hover (fine pointer) hovering opens the bubble after the delay" (still open well past `KitMotion.quick` and over the bubble; closes after leaving both) | run 11 |
  | Focus ring for the keyboard only | `test/kit/kit_term_test.dart` "a tap opens the bubble without drawing the focus ring" | run 11 |
  | Back and Esc close (test 1) | `test/kit/kit_term_test.dart` "the system back gesture closes the bubble, not the route", "showKitTerm back closes the popover and the screen stays", "showKitTerm Esc and a tap outside close the popover"; `test/info_label_test.dart` "back closes the InfoLabel.show explanation, not the screen" | run 11 |
  | Announced once; dismiss action (test 4) | `test/kit/kit_term_test.dart` "opening announces the term and explanation once, politely", "the bubble offers a dismiss action labelled Close explanation" | run 11 |
  | Hit area guideline and line height (test 3) | `test/kit/kit_term_test.dart` "the hit area is at least 48x48 dp" (`androidTapTargetGuideline`), "the term keeps its role's line height (padding is outside)" | run 11 |
  | Long text (test 6) | `test/kit/kit_term_test.dart` "the glossary's longest entry at text 2.0 on 360x800 opens as a sheet…" | run 11 |
  | Learn more order (test 5) | `test/kit/kit_term_test.dart` "learn more is shown only when given, and fires once", "in the sheet, Learn more closes the sheet, then runs once" | run 11 |
  | G5 accessibility | every `_interactiveScene` shot in `test/goldens/kit/kit_term_golden_test.dart` runs `expectKitGalleryAccessible` in both themes, in the state the shot shows | run 12 |
  | R11/R12 wrapper compatibility | `test/info_label_test.dart` "tapping a glossary term...", "InfoLabel.show opens the explanation without a term on screen", "style and iconSize are accepted and ignored" | runs 2, 11 |
  | R23 directional layout | `test/kit_ratchet_test.dart` "G7: layout is directional..." | runs 4, 13 (the review round places both bubbles with one directional `SingleChildLayoutDelegate`; no `Positioned` remains) |
  | KIT-43 wrapper drops to zero | `test/kit_ratchet_test.dart` (G1/G17/G21 for `lib/ui/widgets/info_label.dart` all now count 0; printed as "baseline entries dropped", not committed — R05, the integrator regenerates the baseline) | runs 4, 13 |
  | Design standard | `test/design_standard_test.dart` (info_label.dart is not in `_migrated`/`_grandfathered`, unaffected) | runs 5, 13 |
  | COPY-1/COPY-3 | `test/l10n_coverage_test.dart` (`info_label.dart`: 0 hardcoded strings, baseline 1) | runs 6, 14 |

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
- Goldens (26 PNGs, regenerated in the review round, each opened and looked
  at). Every scene shows the term twice, per KitTerm.md "Galleries
  required": as a section label ("Worktrees", label role) and at the end of
  a row's line ("Runs each task in a separate … Worktree"); the scene opens
  the row's term, which sits at the window's end edge.
  - `kit_term_default_{dark,light}.png`: both terms with their dotted
    underline, no chrome.
  - `kit_term_focused_{dark,light}.png`: keyboard focus (traditional
    highlight mode): the 2 px accent ring around the row term's 48 dp box.
  - `kit_term_open_{dark,light}.png` (412×915, tapped): the bubble below the
    term, right edge a gutter (16 dp) from the window edge, title in text1,
    explanation, "Learn more"; no focus ring (touch).
  - `kit_term_open_sheet_{dark,light}.png`: the long-explanation fallback at
    text 2.0: a bottom sheet titled "Worktree", drag handle, Close, no
    buttons.
  - `kit_term_open_{360x800,915x412,800x1280}_{dark,light}.png`: tapped, the
    bubble open and clamped a gutter from the end edge.
  - `kit_term_open_{1280x800,1600x1000}_{dark,light}.png`: opened by a real
    mouse hover (desktop capabilities); the hover fill is behind the term
    and the bubble is open, clamped a gutter from the right edge. The scene
    asserts the bubble is still open 1 s after the hover opened it.
  - `kit_term_open_text2_{dark,light}[_1280x800].png`: text 2.0, tapped;
    the bubble wraps its explanation inside the window. On 412×915 the
    two-line row text runs under the bubble (the bubble floats over the
    content, as a popover does).
  - `kit_term_open_ar_{dark,light}[_1280x800].png`: Arabic, right to left,
    text 1.3; the row term sits at the left (end) edge, so the bubble,
    which would align to the term's right edge, is clamped a gutter from
    the left edge; the whole explanation is visible.
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
| Verified | Tests and goldens only (G5 on every shot) | this record |
| Committed | Yes | code head (see §2) |
| Deployed | No | |
| Released | No | |
