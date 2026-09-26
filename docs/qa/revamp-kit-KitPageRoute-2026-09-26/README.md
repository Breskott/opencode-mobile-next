# revamp-kit-KitPageRoute: KitPageRoute (2026-09-26)

## 1. Scope

- Unit: `kit-KitPageRoute` (wave 1, tier 1a leaf kit part). Finish line: `KitPageRoute` exists in its own file and is the one way to push a page with the kit's shared-axis transition (`KitPageTransitionsBuilder`, API unchanged). It has `pushKitPage`/`replaceWithKitPage`, all ten spec "Tests required" contracts (1–9 in `test/kit/kit_page_route_test.dart`, the KIT-7 guard 10 in `test/kit_ratchet_test.dart`), a G16 baseline for every current route use per file (KIT-7), and its galleries (spec "Galleries required"). Non-goal: no call site migrates (`lib/main.dart`, screens and `chat/permission_sheet.dart` etc. keep `MaterialPageRoute`/`PageRouteBuilder` until their own units migrate); no export in `kit.dart` (integrator, R06); no Android predictive-back, hero choreography or a second transition style.
- Files changed: `lib/ui/kit/kit_page_route.dart` (new), `lib/ui/kit/motion/kit_page_transitions.dart` (one token fix), `test/kit/kit_page_route_test.dart` (new), `test/goldens/kit/kit_page_route_golden_test.dart` (new, plus its 5 PNGs), `test/kit_ratchet_test.dart` and `test/kit_ratchet_baseline.json` (KIT-7, see below), `docs/qa/revamp-kit-KitPageRoute-2026-09-26/README.md` and `failing-first.txt`.
- Pages (map ids): none (a kit part, not a screen).
- Specs followed: `docs/ux-system/kit-api/KitPageRoute.md` (frozen API, R16); STANDARDS.md KIT-1, KIT-3, KIT-7, KIT-44, MOT-2, MOT-3, MOT-7, PROC-9, PROC-10, PROC-13, TEST-2, TEST-6, TEST-7; kit-v2 §9.1 (Routes row), §9.2; design standard §10.
- Contract problems (PROC-20): **one, non-blocking. The task's generic write set conflicts with the KIT-7 exception in the frozen spec. It is resolved in favour of the more specific source; see below.** No other contract problem. One behaviour gap that test 4 exposed is fixed in the route (see "Review fixes").
- New kit parts (KIT-3): none (this unit's own part, not an incidental new one).
- Map items (EVID-11): n/a — no page.
- States per page (STATE-20): n/a — `KitPageRoute` is not a KIT-12 stateful part (spec "States": none). Declared gallery frames instead: mid-forward, mid-reverse, mid-forward-ar.
- Deferred states (STATE-21): none.

### Contract problem (PROC-20): write-set scope for KIT-7

- **Rule or doc §**: The task's "Write set" line and its "Shared files you never stage" line ("`test/kit_ratchet_baseline.json` … never stage", R05; tests only in your own files, R08). Against them: `docs/ux-system/kit-api/KitPageRoute.md` "Replaces" says the KIT-7 commit baselines "every current use per file in the same commit … This unit is the one KIT-7 names, so it may stage those baseline entries (the single exception to R05 for this pattern)". Its "Tests required" 10 puts the guard in `test/kit_ratchet_test.dart`. STANDARDS.md agrees: KIT-7 ("the commit that adds KitPageRoute removes `MaterialPageRoute` and `PageRouteBuilder` from the G16 allowlist"), KIT-44 ("only the coordinator or the unit the rule names") and PROC-13 (baselines: "KIT-44 and G31's split rule are the only exceptions").
- **What it says / why it looked wrong**: The task's write set names four files. It never names `test/kit_ratchet_test.dart` or `test/kit_ratchet_baseline.json`. Read alone, it forbids the KIT-7 action that the frozen spec and STANDARDS.md both give to this unit.
- **Resolution**: The frozen spec and STANDARDS.md agree with each other, and both name this unit, so I followed them. `test/kit_ratchet_test.dart`: `MaterialPageRoute`/`PageRouteBuilder` left `_g16Allowlist`, G16 counts them (`_g16Routes`), and spec test 10 was added. `test/kit_ratchet_baseline.json`: only the `G16` entries for these two patterns were added. Both commits carry `ratchet-tighten: G16 MaterialPageRoute` and `ratchet-tighten: G16 PageRouteBuilder` in the body (KIT-44). The first build commit (`f68e26fd`) removed the names from the allowlist but counted nothing and added no baseline. Review finding 1 correctly called that "met only on paper". Commit `3ba83c42` makes the gate count routes and commits the baseline.
- **Evidence**: See "Review fixes" below. The baseline diff against `f68e26fd` adds only `"MaterialPageRoute": n` keys under `G16` (49 files, 120 constructions). No other gate or G16 entry changed. `PageRouteBuilder` has no use under `lib/` today, so it has no entry, and any first use fails.
- **Proposed replacement text**: The task template's "Write set" line could add: "…plus, when your frozen spec names a KIT-44 exception for your unit, the gate file and baseline entries it names". A future unit would then not have to settle this itself.
- **blocks**: false.

## Review fixes (2026-09-27, commit `3ba83c42`)

1. **KIT-7 now counts (finding 1).** `_countG16` looks up `_g16Routes` (`MaterialPageRoute`, `PageRouteBuilder`, default constructor only) when a name is not in the widget catalogue. G16 now scans `lib/ui` (minus the kit) as before. It also scans the Flutter UI files elsewhere under `lib/` (`_uiElsewhere`, which includes `lib/main.dart` and `lib/voice/notices.dart`), for the two routes only (`_g16CountsFor`). The baseline was written with `KIT_RATCHET_WRITE=1 KIT_RATCHET_GATES=G16`, and a script confirmed that only the new route keys differ from the committed file.
   - Counts: 120 `MaterialPageRoute` constructions in 49 files, including `lib/main.dart` (9) and `lib/voice/notices.dart` (1). The spec's grep count of "122 uses in 49 files" also counts a doc comment (`widgets/diff_view.dart:21`) and a type annotation (`servers_screen.dart:480`), which construct nothing. `PageRouteBuilder`: 0.
   - Spec test 10: `test/kit_ratchet_test.dart` "KIT-7: a new MaterialPageRoute( in a file with no baseline entry fails G16, in lib/ui and in UI code elsewhere under lib/". It checks a synthetic source for a `lib/ui` path and a `lib/voice` path that have no baseline entry. Each gets one `MaterialPageRoute` and one `PageRouteBuilder`, the ratchet reports both as "new — baseline has none", and `KitPageRoute(`, `pushKitPage(`, `is MaterialPageRoute` and a comment do not count. The test also shows that a rise in `lib/main.dart`'s baselined count fails. Failing first: with the `_g16Routes` lookup removed, it fails with `Actual: {}` (`failing-first.txt` §C).
2. **Test 8 can fail now (finding 2).** The draft lives only in widget state: a `TextField` with no controller on a page pushed with `pushKitPage`. After typing, a second page is pushed over it. The text is still in the tree (offstage). Reduced motion is toggled on and off while the second page is open, then it is popped. The test checks that `'draft text'` is shown and that the `EditableTextState` is the same instance, then checks again after a toggle with the draft page on top. Failing first: with `KitPageRoute.maintainState` defaulting to `false`, it fails (`Found 0 widgets with text "draft text"`, `failing-first.txt` §B). A variant that skips the offstage check fails at the final "draft shown after pop" assertion.
3. **One pump, as frozen (finding 3), and a real behaviour gap fixed.** With a single `pump()` after `pushKitPage` under `disableAnimations`, test 4 failed: the new page was not found (`failing-first.txt` §A). The cause is the framework, not the transition. `MaterialApp`'s `HeroController` sets `offstage = true` on every newly pushed `PageRoute` for one frame, to measure where heroes land, and brings it back onstage in a post-frame callback. So any pushed page, `MaterialPageRoute` included, appears on the second frame. `KitPageRoute` now overrides the `offstage` setter: when `KitMotion.reduced(navigator.context)` is true, it ignores `offstage = true`. The kit transition already draws the arriving page whole and in place from t = 0 under reduced motion, so that frame has nothing to measure. With motion on, the measuring frame is unchanged. A new test guards that ("with motion on, a pushed page keeps the hero measuring frame the framework gives it"). The public API is unchanged: this overrides an inherited member and adds no parameter.
   - Side effect, recorded: the check runs `KitMotion.reduced` on the Navigator's context. That subscribes the Navigator to the reduced-motion aspect of `MediaQuery` and to `KitEffectsScope`, which change rarely. Under reduced motion, a hero flight (the app has only the default FAB hero) measures from the onstage page at t = 0, which is already its final place.
4. **Dead scaffolding (finding 4).** `_pumpApp`'s `toggleAnimations` is now what test 8 uses, so the helper has no unused parameter.

## 2. Builds

- Branch `revamp/kit-KitPageRoute`, base `b67e3276` (tip of `feat/phone-setup-v2` at branch time), first build `f68e26fd`, code head `3ba83c42` (review fixes).
- No APK (unit agents do not build; R19/R20).

## 3. Devices

None: tests, goldens and renders only. Device proof is coordinator/wave-checkpoint work.

## 4. Runs

Runs 1–4 and 9 are from code head `3ba83c42`. Runs 5–8 are from `f68e26fd`. The review commit changes none of the code or tests they cover: `kit_page_transitions.dart` is untouched, and the one `lib/` change is `KitPageRoute`, which no shared test uses yet because it is not exported from `kit.dart`.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: each review fix undone in turn, its test run (`failing-first.txt`) | fails with an assertion | §A test 4 failed (page not found after one pump); §B test 8 failed (draft gone); §C test 10 failed (`Actual: {}`) | PASS |
| 2 | `test/kit/kit_page_route_test.dart` (`-j 1`) | 10 pass (spec tests 1–9, plus the hero-frame guard) | 10 passed | PASS |
| 3 | `test/goldens/kit/kit_page_route_golden_test.dart` (`-j 1`, committed goldens) | 5 shots pass | 5 passed | PASS |
| 4 | `test/kit_ratchet_test.dart` (`-j 1`, full file) | passes; no drops printed | 33 passed (includes spec test 10), no drops | PASS |
| 5 | `test/kit_motion_test.dart`, `test/kit_motion_app_test.dart` (shared tests that already exercise `KitPageTransitionsBuilder`) | unaffected by the `ground`-role edit | 199 passed | PASS |
| 6 | `test/text_scale_overflow_test.dart` (shared G6 overflow matrix) | unaffected | 75 passed | PASS |
| 7 | `test/l10n_coverage_test.dart`, `test/design_standard_test.dart` | pass (no new copy, no migrated screen) | 2 + 15 passed | PASS |
| 8 | `test/kit/kit_manifest_test.dart` | unaffected (`KitPageRoute` is not in `kit.dart` yet by design; the integrator exports it) | 2 passed | PASS |
| 9 | `flutter analyze` (whole tree) | no issues | "No issues found!" | PASS |

## 5. Evidence

- `failing-first.txt`: step 1 for the three review fixes. The first build was new code, which needs no failing-first run (TEST-2).
- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | API shape (constructor, `pushKitPage`, `replaceWithKitPage`) | `test/kit/kit_page_route_test.dart` all | run 2 |
  | MOT-2 (no scale/blur mid-transition) | `test/kit/kit_page_route_test.dart` "mid-transition there is no scale or blur (MOT-2)" | run 2 |
  | MOT-3 (kit transition regardless of ambient theme) | `test/kit/kit_page_route_test.dart` "under a bare ThemeData…" | run 2 |
  | MOT-7 / G8x (reduced motion: the page is whole and in place after one `pump()`) | `test/kit/kit_page_route_test.dart` "under disableAnimations the new page is opaque and in place after one pump (G8x)" | runs 1 §A, 2 |
  | Hero measuring frame kept with motion on | `test/kit/kit_page_route_test.dart` "with motion on, a pushed page keeps the hero measuring frame…" | run 2 |
  | RTL slide direction | `test/kit/kit_page_route_test.dart` "RTL: the arriving page slides in from the left…" | run 2 |
  | `settings.name` kept, pop value returned | `test/kit/kit_page_route_test.dart` "pushKitPage resolves…" | run 2 |
  | `fullscreenDialog` visible to the page | `test/kit/kit_page_route_test.dart` "fullscreenDialog is visible…" | run 2 |
  | DATA: a draft in widget state survives push/pop and a motion toggle | `test/kit/kit_page_route_test.dart` "a draft in a page underneath survives push, pop and a reduced-motion toggle…" | runs 1 §B, 2 |
  | `replaceWithKitPage` removes the old route | `test/kit/kit_page_route_test.dart` "replaceWithKitPage removes the route it replaces" | run 2 |
  | KIT-7 (routes leave the G16 allowlist and are counted; spec test 10) | `test/kit_ratchet_test.dart` "KIT-7: a new MaterialPageRoute( in a file with no baseline entry fails G16…" and "G16: every UI component comes from the kit" | runs 1 §C, 4 |
  | KIT-44 (baseline rise only for the named patterns) | `test/kit_ratchet_baseline.json` diff: only `G16` → `MaterialPageRoute` keys added; `ratchet-tighten:` trailers in `3ba83c42` | this record |
  | Galleries (mid-forward/-reverse, dark/light, ar) | `test/goldens/kit/kit_page_route_golden_test.dart` | run 3 |

- Changed test expectations (TEST-19): test 4 now pumps once instead of twice, as the spec freezes it (MOT-7, G8x). Test 8 keeps its draft in widget state instead of a test-owned controller, and checks State identity (DATA). Both are stricter than before. No expectation was loosened.
- Goldens changed (each opened and looked at):
  - `test/goldens/kit/kit_page_route_mid_forward_dark.png` / `_light.png`: new — "B" mid-fade-in, centred, no scale/blur; correct ground colour behind.
  - `test/goldens/kit/kit_page_route_mid_reverse_dark.png` / `_light.png`: new — "A" reappearing mid-fade after a pop.
  - `test/goldens/kit/kit_page_route_mid_forward_ar_dark.png`: new — "ب" renders with the Noto Sans Arabic fallback (no tofu), sits left of centre (RTL "from the left").
  - No approved VL canvas render exists for this part (EVID-12: none — a route has no visual "look" beyond motion, which a still PNG only partly shows; the motion assertions in `kit_page_route_test.dart` carry the rest).
- Before and after: n/a — no existing page or golden changes shape or copy; `kit_page_transitions.dart`'s one edit is pixel-identical for the real `AppTheme` (`scaffoldBackgroundColor` is already set to `ThemeRoles.ground`, see contract note below), confirmed by the two shared tests in run 4 passing unchanged.
- Accessibility: the route scopes semantics via `Semantics(scopesRoute: true, explicitChildNodes: true)` (matches the framework's own `MaterialPageRoute` pattern); a page's own name comes from its `KitTopBar` (not built here); the leaving page ignores pointers mid-transition (existing `_KitSharedAxisPage` behaviour, unchanged). No G5 gallery accessibility pass on the two moving mid-transition frames (they are a transient animation state, not a settled shot the G5 harness is built to judge — `kit_gallery.dart`'s `kitGalleryShot` disables animations and settles before checking, which would hide the very thing these frames exist to show); this is the frozen spec's own "Galleries required" list, which does not ask for G5 here.
- Privacy and security: n/a — no credentials, stored data, links or notifications.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_page_route_test.dart
$F test -j 1 test/goldens/kit/kit_page_route_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart
# the G16 baseline was written with (then rerun without the env vars):
#   KIT_RATCHET_WRITE=1 KIT_RATCHET_GATES=G16 $F test -j 1 test/kit_ratchet_test.dart
$F test -j 1 test/kit_motion_test.dart test/kit_motion_app_test.dart test/text_scale_overflow_test.dart
$F test -j 1 test/l10n_coverage_test.dart test/design_standard_test.dart test/kit/kit_manifest_test.dart
$F analyze
```

## 7. NOT proven

- Not run on a device or emulator (R19/R20: coordinator work).
- No call site migrated to `KitPageRoute` (non-goal). The 120 `MaterialPageRoute` constructions in 49 files are unchanged. They are now baselined under G16 and can only shrink.
- `onGenerateRoute`/`routes` in `lib/main.dart` still return `MaterialPageRoute`s (coord-main's work, per the spec). Until they migrate, the one-pump reduced-motion push holds only for pages pushed as `KitPageRoute`. A stock `MaterialPageRoute` still appears one frame later because of the HeroController measuring frame.
- A hero flight between two `KitPageRoute` pages under reduced motion is not tested (the app has only the default FAB hero, and hero choreography is a spec non-goal).
- No G5 accessibility pass on the two moving (mid-transition) gallery frames; see the Accessibility note above for why the shared harness does not apply here.
- Android predictive-back gesture animation: out of scope (spec Non-goals).
- `flutter build apk --release` not run (not part of this unit's checks; AGENTS.md's Android compile check is a coordinator/integration-checkpoint step).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitPageRoute` |
| Enabled | Yes (a new kit API; nothing calls it yet — additive, no screen changed) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | code head `3ba83c42` |
| Deployed | No | |
| Released | No | |
