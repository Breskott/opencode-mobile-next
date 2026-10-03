# revamp-kit-KitMenu: KitMenu (2026-09-26)

## 1. Scope

- Unit: `kit-KitMenu` (wave 1, tier 1a, kit-part). Finish line: `showKitMenu`/`KitMenuPanel`/`KitMenuItem` v2 exist in `lib/ui/kit/kit_menu.dart`, matching `docs/ux-system/kit-api/KitMenu.md`'s frozen API exactly, with every state, gallery and behaviour test it lists. Non-goal: no screen migrates off `PopupMenuButton`/`PopupMenuItem`/`CheckedPopupMenuItem`/`PopupMenuDivider` (wave 2); `kit.dart` is not exported into; `kit_row_parts.dart` is not touched.
- Files changed:
  - `lib/ui/kit/kit_menu.dart` (new).
  - `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` (one new key, `kitMenu`).
  - `test/kit/kit_menu_test.dart` (new, 12 required scenarios + 3 pure-function ordering checks; 27 test cases after the review round).
  - `test/goldens/kit/kit_menu_golden_test.dart` (new) and its 30 PNGs under `test/goldens/kit/kit_menu_*.png` (6 regenerated in the review round, see §5).
  - `docs/qa/revamp-kit-KitMenu-2026-09-26/README.md` (this record).
  - Not staged: `lib/l10n/app_localizations*.dart` (regenerated locally by `flutter pub get` so the new `kitMenu` getter compiles for `flutter analyze`/`flutter test`; PROC-13 says units never commit the generated output).
- Pages (map ids): none — `kit-KitMenu` is tier 1a with no map page (KitMenu.md "Depends on": none).
- Specs followed: KitMenu.md in full (API, States, Tokens, Adaptive, Accessibility, RTL, Motion and haptics, Data safety, Tests required, Galleries required); kit-v2.md §4.2 (destructive last), §8.2 (KitRow row), §8.3 (right-click and long-press open the same menu); visual language §1, §5 (no per-row ⋮); STANDARDS.md KIT-2, KIT-8, KIT-11, KIT-23, KIT-28, LAY-9, LAY-10, LAY-11, LOOK-5, LOOK-19, LOOK-20, MOT-2, A11Y-5.
- Contract problems (PROC-20): three, all from the same root cause — this unit's write set is `lib/ui/kit/kit_menu.dart` plus its own tests only, and it must not edit `lib/ui/kit/kit.dart` (Hard rules, R06: "the integrator adds exports"). KitMenu.md itself assumes more:
  1. **KitMenu.md "File" / Open question 1 (decision D6, "Adopted"):** the frozen spec says this unit's write set includes a two-line edit of `kit_row_parts.dart` (delete the old `KitMenuItem`, add `export 'kit_menu.dart' show KitMenuItem;`), reasoned as safe because kit-KitRowParts-v2 (tier 1d) never runs concurrently with tier 1a. But this task's own Acceptance list says plainly "does not edit kit_row_parts.dart", and the write set given to me lists exactly three files, none of them `kit_row_parts.dart`. I followed the narrower instruction and made no edit there — the old `KitMenuItem`/`KitRowMenu` in `kit_row_parts.dart` are untouched and still compile (verified: `flutter analyze` on the whole kit is unaffected, no ambiguous export today since `kit.dart` does not yet import `kit_menu.dart`). The two-line move (decision D6) is still open and needs the integrator's call before `kit.dart` can export `kit_menu.dart` (importing both would then be an ambiguous `KitMenuItem` export, exactly as KitMenu.md's Open question 1 describes).
  2. **`test/kit/kit_manifest_test.dart` (gate G4) fails for `KitMenuPanel` and `showKitMenu`,** and cannot be made to pass from inside this unit's write set. Full output (`run-manifest.txt`): 8 violations — `exported`/`docRow` for both `KitMenuPanel` and `showKitMenu` (needs a `kit.dart` edit, forbidden here); `name` (G4's NAME-1 heuristic expects a widget's file to be named after it — `lib/ui/kit/kit_menu_panel.dart` — but KitMenu.md's own "File" section puts `KitMenuItem`, `KitMenuPanel` and `showKitMenu` together in `kit_menu.dart`, which is what every reviewer approved); `gallery`/`test` (same mismatch — KitMenu.md names the files `kit_menu_golden_test.dart`/`kit_menu_test.dart`, which both exist and pass, not `kit_menu_panel_*`); `keyboard` (G14x's manifest-driven coverage list lives in the shared `test/kit/kit_keyboard_test.dart`, outside this unit's write set). None of these are gaps in the part's own behaviour — every one of KitMenu.md's own 12 required tests and 30 galleries passes (§4 below) — they are the export/doc-table/shared-test-registration steps R06 reserves for the integrator. Recorded so G4 is not mistaken for a regression when this branch is reviewed.
  3. **Gallery size list (KitMenu.md "Galleries required", second bullet):** the frozen text asks for `default` at "360×800, 915×412, 800×1280, 1280×800 and 1600×1000" — note `915×412`, the *landscape* census phone, not the usual portrait `412×915` in `kitGallerySizes`. Using the standard `kitGallerySizes` list here would collide with the "each state" bullet's own 412×915 `default` shot (same golden name twice). I built the five sizes literally as written (substituting the landscape phone for the portrait one), which also exercises `KitLayout.isShort` (height 412 < 480) that the Adaptive section calls for. Flagging this because it is easy to misread as a typo; `namedGallerySizes` in `test/golden_harness_test.dart` already allows `915x412` for exactly this reason.
  4. **Review finding 10 (integration blocker, coordinator step):** because of #1 there are two public `KitMenuItem` classes (the old one in `kit_row_parts.dart`, the v2 one here), so `kit.dart` cannot export `kit_menu.dart` without an ambiguous export, and the gallery imports `kit.dart hide KitMenuItem`. The integrator or coordinator makes the D6 two-line move in `kit_row_parts.dart` (delete the class, add `export 'kit_menu.dart' show KitMenuItem;`) before or when exporting `kit_menu.dart`, then drops the `hide KitMenuItem` from `test/goldens/kit/kit_menu_golden_test.dart`. Not done here: `kit_row_parts.dart` is outside this unit's write set.
  5. **Internal keys (TEST-5), now as frozen:** every divider carries `kit-menu-divider` (sibling uniqueness comes from a wrapping `KeyedSubtree` with the divider's index), and the panel's surface carries `kit-menu` whether it is shown by `showKitMenu` or used standalone. `menuKey` is now an extra key on the route's `KitMenuPanel` widget, no longer a replacement for `kit-menu`, so `find.byKey(ValueKey('kit-menu'))` finds exactly one widget per open menu. The first build used indexed `kit-menu-divider-<n>` keys and did not report it; that deviation is gone.
- New kit parts (KIT-3): `KitMenu` (`lib/ui/kit/kit_menu.dart`): `KitMenuItem`, `KitMenuPanel`, `showKitMenu`.
- Map items (EVID-11): n/a — no map page.
- States per page (STATE-20): n/a — not a screen; the part's own states (default, with icons, checked, groups, destructive, disabled) are covered per KitMenu.md "States" and its galleries (§4, §5 below).
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitMenu`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4` (`feat/phone-setup-v2`), first build `befeba0c9fbd91ada30b99921919bcf34f0c7c6d`; review-fix round on top of `2b552791` (see the commit log for its head).
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator/checkpoint work (R19, R20).

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Review round, failing first: the new and changed tests in `test/kit/kit_menu_test.dart` run against the first build's `kit_menu.dart` (`git show 2b552791:lib/ui/kit/kit_menu.dart`) | the tests for findings 1, 3, 4, 5 (ring), 7, 8 and 9 fail | 7 failed: 2 (no `kit-menu-divider`), 3b (disabled checked item: `CheckedState.none`), 5b (copy skipped after the invoker unmounted), 7a (no accent ring on the focused item), 7d (right-click focused the first item), 8d (panel bottom 536 > 440, under the keyboard), 9 (panel right edge 336 > 304) | FAIL as expected (`failing-first-review.txt`) |
| 2 | `test/kit/kit_menu_test.dart` | passes | 27 passed | PASS (`run-behavior.txt`) |
| 3 | `test/goldens/kit/kit_menu_golden_test.dart` | passes, 30 PNGs | 30 passed (6 regenerated after looking, §5) | PASS (`run-goldens.txt`) |
| 4 | `test/kit_ratchet_test.dart`, `test/l10n_coverage_test.dart`, `test/ui_glossary_test.dart` | pass | 55 passed (after two self-found G21 hits in the round: a border width through a local instead of `KitTokens.hairlineWidth(context)`, and `metaLeft` matching the "metal" pattern, fixed by collapsing key synonyms) | PASS (`run-ratchet.txt`) |
| 5 | `test/design_standard_test.dart`, `test/golden_harness_test.dart` (G23) | pass | 23 passed | PASS (`run-design-standard.txt`) |
| 6 | `test/kit/kit_manifest_test.dart` (G4) | fails, integrator-owned steps only (Contract problems #2 and #4) | the same 8 export/name/gallery/test/docRow/keyboard entries as the first build | FAIL (expected; not this unit's to fix) |
| 7 | `flutter analyze` on the three changed Dart files | no issues | No issues found | PASS (`run-analyze.txt`) |
| 8 | `dart format --language-version=3.10` on every changed `.dart` file | 0 changes | 0 changed | PASS |

### Review round (10 findings)

| # | Finding | Fix | Proof |
|---|---|---|---|
| 1 | Width not clamped to the window minus the gutter | `getConstraintsForChild` caps width and height at the window minus the system insets and 2 × 16 dp | test 9 (text 1.0 and 2.0 at 320 dp: left ≥ 16, right ≤ 304, rows ≥ 48, no ellipsis, no `maxLines`) |
| 2 | No visible focus ring | `_KitMenuFocusRing`: `accent`, `KitTokens.focusRingWidth(context)` (2 physical px), inset `space1` with corners concentric to the panel's (radius 14 − 4), drawn only while the item has focus; hover keeps the plain `surface3` fill. The panel's position is snapped to the physical pixel grid | test 7a (ring on the focused item only, follows focus), 7d and 7e (none after a pointer open); looked at a scratch render in dark and light (not committed; the spec's 30-shot gallery list has no focus shot) |
| 3 | Keyboard open detected from `highlightMode` | decided from the invoking gesture: a non-modifier key held when `showKitMenu` is called (Shift+F10, the context-menu key and Enter act on key down); modifiers are collapsed and ignored, so Shift+right-click is a pointer open. Passed to the route's panel through a private `KitMenuPanel._route` constructor; the public API is unchanged | 7a (Shift+F10), 7b (Enter), 7c (context-menu key) focus the first enabled item; 7d (right-click) and 7e (Shift+right-click) focus the panel, no item, no ring. The old `alwaysTraditional` override is gone |
| 4 | Divider key differs from TEST-5; standalone panel has no `kit-menu` key | see Contract problems #5 | test 2 finds exactly 2 `kit-menu-divider`s, placed between the groups and before the destructive block |
| 5 | Test 7 incomplete | four keyboard cases with a real focusable invoker: Down/Up skip and wrap, Home/End, Enter and Space select, Esc closes, focus returns to the invoker (asserted each time) | 7a–7e |
| 6 | Border under item highlights | the border is a foreground decoration above the clipped content; the surface fill stays underneath | regenerated `kit_menu_default_1280x800_*` and `_1600x1000_*` (hovered row, border intact at the edges); `groups_light` and `destructive_light` moved by 2 px where the border now covers the divider ends |
| 7 | Disabled checkable item loses `checked` | `checked: item.checked` on the disabled node too | test 3b |
| 8 | Placement ignores system insets | the layout area is the window deflated by `MediaQuery.paddingOf` + `viewInsetsOf` + the gutter before `fitsBelow`/`fitsAbove` and clamping; insets and DPR are in `shouldRelayout` | test 8d (status bar 24, keyboard 400: an anchored chip's menu opens above it, a point open at y 2 lands at ≥ 40) |
| 9 | Copy skipped when the invoker unmounted | falls back to the navigator's context (same view, localizations and direction) | test 5b |
| 10 | Two public `KitMenuItem`s | coordinator step (Contract problems #4) | — |

## 5. Evidence

- `run-manifest.txt`: full output of step 6 (the 8 G4 entries).
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | KIT-43 (retired ctor still compiles) | `test/kit/kit_menu_test.dart` "12. the retired KitMenuItem…" | all-tests run, test 12 passed |
  | KIT-23/SEC (copy redacts, no SnackBar) | `test/kit/kit_menu_test.dart` "5. KitMenuItem.copy…" | passed |
  | LOOK-5/§4.2 (destructive last, after a divider) | `test/kit/kit_menu_test.dart` "2. destructive items render last…" + `kitMenuLayout` group tests | passed |
  | LAY-10/A11Y-5 (keyboard open, Up/Down/Home/End, Enter/Space, Esc, focus return, pointer open focuses the panel) | `test/kit/kit_menu_test.dart` "7. keyboard, with desktop capabilities" (5 cases) | `run-behavior.txt`; failing first in `failing-first-review.txt` |
  | LAY-10/LOOK-21 (2 physical px accent focus ring) | "7. keyboard…" Shift+F10 case (`_focusRing`) | same |
  | LAY-11 (anchoring, RTL, window gutter, system insets) | `test/kit/kit_menu_test.dart` "8. anchoring…" (4 cases) and "9. at 320dp wide…" | same |
  | STATE/honest copy (copy survives an unmounted invoker) | "5. KitMenuItem.copy still copies when the invoker unmounted…" | same |
  | KIT-16 (no stacking on a confirm from a menu item) | `test/kit/kit_menu_test.dart` "10. onSelected that opens showKitConfirm…" | passed |
  | G8/MOT-2 (reduced motion, no ticker) | `test/kit/kit_menu_test.dart` "11. reduced motion…" | passed |
  | G21/LOOK-21 (kit stroke widths and spacing from KitTokens) | `test/kit_ratchet_test.dart` "G21 look and motion" | `failing-first-g21.txt` → fixed → `run-ratchet.txt` |

- Evidence files next to this README: `failing-first-g21.txt`, `run-ratchet.txt` (ratchet + l10n-coverage + glossary, 55 passed), `run-behavior.txt` (`kit_menu_test.dart`, 20 passed), `run-goldens.txt` (`kit_menu_golden_test.dart`, 30 passed), `run-design-standard.txt` (design-standard + G23 golden-harness, 23 passed), `run-analyze.txt` (`flutter analyze` on the three changed files, no issues), `run-manifest.txt` (G4, the 8 expected violations — Contract problems #2).

- Changed test expectations (TEST-19), review round: test 2 now finds the frozen `kit-menu-divider` key (was indexed `kit-menu-divider-<n>`, a spec deviation); test 7 no longer forces `FocusHighlightStrategy.alwaysTraditional` (that hid finding 3) and opens the menu from a real invoker by key and by right-click; test 9 asserts the gutters instead of `width <= 320` (which hid finding 1) and runs at text 1.0 as well as 2.0. Each change follows the spec's own wording; none weakens an assertion.
- Goldens changed (each opened and looked at): all 30 are new (no prior version). Looked at: `kit_menu_default_dark/light`, `kit_menu_icons_dark`, `kit_menu_checked_dark`, `kit_menu_groups_dark`, `kit_menu_destructive_dark`, `kit_menu_disabled_dark/light` (twice — regenerated once more after the G21 padding fix moved the disabled reason's gap from a literal `2` to `KitTokens.space1` (4); visually unchanged at this scale), `kit_menu_default_1280x800_dark` (hover + shortcut column). No approved VL canvas render exists for this new part yet (EVID-12: none).
- Review round goldens (each opened and looked at): `kit_menu_default_1280x800_{dark,light}`, `kit_menu_default_1600x1000_{dark,light}` (hovered row now under an intact hairline), `kit_menu_groups_light`, `kit_menu_destructive_light` (2 px at the divider ends). The other 24 are byte-identical.
- Before and after: n/a — new part, no prior golden or census page to diff against (EVID-10).
- Accessibility: 48 dp minimum row height enforced via `KitTokens.minTarget`; disabled items keep a real `Semantics(button:true, enabled:false, hint: reason)` node (fixed a self-found bug during this build: the disabled row's explicit `label:` was duplicating the title with the merged child text — "Restart\nRestart\nNo server connected" — removed so it now merges once, see the code comment); checked/unchecked exposed as `Semantics.checked`; keyboard Up/Down wrap and skip disabled items, Home/End jump, focus returns to the invoker on close; every gallery shot runs G5 (`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`, reading order) via `kitGalleryPart`/the custom hover shot, all passing with nothing added to `kitGalleryG5Ceiling`; 200 % text and Arabic RTL both covered by galleries and pass G6-style overflow checks (`tester.takeException()` is null at 320 dp, 2.0 text).
- Privacy and security: n/a — no credentials, stored data, external links or notifications touched. `KitMenuItem.copy` redacts through the existing `KitCopy.copy`/`KitRedact` seam (test 5 uses the same fake `sk-ant-…` fixture as `kit_copy_test.dart` and asserts the clipboard only ever sees the masked value).
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get   # also regenerates lib/l10n/app_localizations*.dart locally (uncommitted)
$F test -j 1 test/kit/kit_menu_test.dart
$F test -j 1 test/goldens/kit/kit_menu_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/l10n_coverage_test.dart test/ui_glossary_test.dart
$F test -j 1 test/design_standard_test.dart test/golden_harness_test.dart
$F test -j 1 test/kit/kit_manifest_test.dart   # expected to fail; see Contract problems #2
$F analyze lib/ui/kit/kit_menu.dart test/kit/kit_menu_test.dart test/goldens/kit/kit_menu_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator (R19/R20: coordinator work).
- Not exported from `kit.dart`, so no other unit or screen can reach `showKitMenu`/`KitMenuPanel` yet (Contract problems #1–2) — this is expected wave-1 sequencing, not a defect, but it means nothing downstream (kit-KitRowParts-v2, kit-KitTopBar, kit-KitTappable, kit-KitViewer, kit-KitComposerChips) can build on it until the integrator wires the export, the doc-table row and the `kit_row_parts.dart` two-line move.
- `test/kit/kit_manifest_test.dart` (G4) is not clean for this unit's new part (Contract problems #2); `flutter test --concurrency=1` on the *whole* repo has not been run (out of scope for a single kit-part unit; STANDARDS §1.1's whole-tree `flutter analyze`/serial-suite gate is the integration checkpoint's job).
- No committed gallery shows the focus ring: KitMenu.md's gallery list (30 PNGs) has no focus shot, so the ring is proven by test 7 and a scratch render only.
- Focus-first on a keyboard open relies on the key still being held when the invoker calls `showKitMenu` synchronously. An invoker that awaits something between the key press and the call opens with the panel focused (Down then reaches the first item); callers in wave 2 should call it synchronously.
- The `_hoverShot` helper in the gallery simulates a mouse hover with `debugPlatformCapabilities` forced to desktop; it does not prove real trackpad/mouse behaviour on a PC build.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitMenu` |
| Enabled | No: not reachable from `kit.dart` yet (integrator step, Contract problems #1–2) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | first build `befeba0c`; review round in the next commit on `revamp/kit-KitMenu` |
| Deployed | No | |
| Released | No | |
