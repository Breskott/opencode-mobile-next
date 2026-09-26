# revamp-kit-KitAction-v2: KitAction, KitButton, KitActionBlock, KitActionStack (2026-09-26)

## 1. Scope

- Unit: `kit-KitAction-v2` (wave 1, tier 1a, kit-change). Finish line: `KitAction` carries `disabledReason` and `shortcut` and a `.copy` constructor; `KitActionBlock` stacks on every window when a tertiary action is destructive and shows a disabled action's reason as visible text and as its semantic hint; every existing call site keeps compiling. Non-goal: no screen migration, no removal of `menu:`, no `KitAsserts` strict-mode seam (it does not exist yet and is not in this unit's write set), no shortcut binding.
- Files changed: `lib/ui/kit/kit_buttons.dart`, `lib/ui/kit/kit_action_stack.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb`, `test/kit/kit_action_test.dart` (new), `test/goldens/kit/kit_action_golden_test.dart` (new) and its 12 PNGs. `lib/l10n/app_localizations*.dart` were regenerated locally to compile against the new `kitMore` key and left uncommitted (PROC-13; the integrator regenerates once for real).
- Pages (map ids): none — this is a kit-change unit, not a screen unit.
- Specs followed: `docs/ux-system/kit-api/KitAction.md` (frozen API, verbatim); STANDARDS.md KIT-8, KIT-9, KIT-23, KIT-39, KIT-43, LAY-9, LAY-12, LAY-13, LAY-14, STATE-7, STATE-8, LOOK-5, LOOK-23, LOOK-33, COPY-8; kit-v2.md §2.7, §4.2, §4.9, §8.2, §8.3, §9.1; design-standard.md §2; visual-language-2026-09-26.md §5.
- Contract problems (PROC-20):
  1. **QA record path.** The task's own instruction list said `docs/qa/revamp-<unit id>/README.md` (no date); STANDARDS.md EVID-1 requires `docs/qa/revamp-<unit id>-<YYYY-MM-DD>/README.md`. Followed STANDARDS.md (the named rulebook) and used the dated path; recorded here rather than silently picking one.
  2. **`KitAsserts` (Open question 1 in KitAction.md).** The frozen spec's proposed resolution — ship the field and its rendering, skip the debug assert until the coordinator adds `lib/ui/kit/kit_asserts.dart` in STANDARDS §0.5 step 2 — was followed exactly as the spec itself directs, since that file does not exist and is outside this unit's write set. Not a defect; recorded so the assert isn't mistaken for forgotten.
  3. **Pre-existing contrast near-miss, found by this unit's gallery.** `KitButton`'s disabled primary/secondary fill (`disabledForegroundColor: roles.text3` on `disabledBackgroundColor: roles.surface3`, unchanged code from before this unit) measures 4.44:1 against the WCAG AA 4.5:1 minimum in the dark theme — first surfaced because no earlier G4/G5-audited gallery rendered a disabled primary or secondary button. `theme_roles.dart` is outside this unit's write set and this rule's scope, so the golden "disabled" scenes use a disabled **tertiary** action instead (transparent background, no contrast issue); `test/kit/kit_action_test.dart` still asserts a disabled **primary**'s semantics directly (text + `isEnabled: false` + hint), so the behaviour itself is proven. Flagged for the visual-language token owner.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a — no pages.
- States per page (STATE-20): n/a — no pages. `KitButton`/`KitActionBlock`/`KitActionStack` states (KIT-12): default, disabled, working, destructive, copied, shortcut (per KitAction.md's own States table); a `States:` doc-comment line was **not** added (see §7, NOT proven — it would flip pre-existing `kit_manifest_allowlist.json` "states" entries from tolerated to stale and pull in the manifest's `stateScenes` gallery requirement, which this unit's budget did not cover).
- Deferred states (STATE-21): n/a.

## 2. Builds

- Branch `revamp/kit-KitAction-v2`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4` (`feat/phone-setup-v2` at start), code head `5490ff63c46a09be5fd30a34baac7ba258c48a89`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is the wave checkpoint's job.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only (TEST-2) | n/a: this unit rebuilds an API to a frozen spec, it does not fix a reported bug | n/a | n/a |
| 2 | `test/kit/kit_action_test.dart` | passes | 20 passed | PASS |
| 3 | `test/goldens/kit/kit_action_golden_test.dart --update-goldens` | passes, 12 PNGs, each looked at | 12 passed, all opened and reviewed (§5) | PASS |
| 4 | `test/kit_ratchet_test.dart` | passes (counts may drop) | 32 passed; G15x and G21 report `kit_buttons.dart`/`kit_action_stack.dart` counts dropped to 0 (informational; the integrator regenerates the baseline, R05) | PASS |
| 5 | `test/design_standard_test.dart` | passes | 15 passed | PASS |
| 6 | `test/l10n_coverage_test.dart` | passes | 2 passed | PASS |
| 7 | `test/kit/kit_manifest_test.dart` (G4) | passes, no stale allowlist entries from the new files | 2 passed | PASS |
| 8 | `test/kit_motion_test.dart` (G8x, pre-existing `KitActionBlock`/`KitActionStack` samples) | passes | 179 passed | PASS |
| 9 | `test/team_controls_test.dart`, `test/team_gate_answer_test.dart`, `test/work_tab_status_line_test.dart` (existing consumers, incl. the old 600 dp-width row/stack switch) | pass | 32 + 31 + 12 passed | PASS |
| 10 | `test/text_scale_overflow_test.dart` (G6) | passes | 73 passed, 1 new failure: `KitRequestCard/default` at 915×412, text 2.0, ltr and rtl — `RenderFlex overflowed by 51 pixels on the bottom` (see §5, sharedTestsBroken) | FAIL (downstream, not this unit's write set) |
| 11 | `flutter analyze lib test` | no errors, no new issues | "No issues found!" | PASS |
| 12 | `dart format --language-version=3.10` on every changed file | no diff after formatting | applied cleanly, goldens re-verified unchanged after reformatting | PASS |

## 5. Evidence

- No `failing-first.txt`: no bug fix in this unit (TEST-2 n/a).
- Rule evidence (PROC-31):

  | Rule | Test (`file` + name) | Outcome |
  |---|---|---|
  | STATE-8 (disabledReason renders + is the semantic hint) | `test/kit/kit_action_test.dart` "KitActionBlock shows a disabled primary's reason under it, as text and as the semantic hint" | PASS |
  | LAY-14, §2.7 (destructive tertiary forces the stack, every window) | `test/kit/kit_action_test.dart` "a destructive tertiary forces the stack on compact/medium/large" (3 cases) | PASS |
  | LAY-9 (8 dp clearance around the destructive target) | same 3 cases, asserts `deleteTop - duplicateBottom >= 8` | PASS |
  | LAY-3 (a short window keeps the stack) | `test/kit/kit_action_test.dart` "a short window keeps the stack even when wide" | PASS |
  | LAY-13 (row, primary at the end, medium+) | `test/kit/kit_action_test.dart` "with no destructive tertiary, medium and up is one row with the primary at the end" | PASS |
  | §2.7 "More" ordering | `test/kit/kit_action_test.dart` "a third tertiary action moves into More", "a destructive overflow action renders last, after a divider" | PASS |
  | KIT-23 (`KitAction.copy`) | `test/kit/kit_action_test.dart` "copies the text read at tap time, announces once, shows the check then reverts, with no SnackBar" | PASS |
  | STATE-7, C21 f (`working` ignores taps) | `test/kit/kit_action_test.dart` "shows the spinner and ignores taps" | PASS |
  | Shortcut visibility/RTL isolation | `test/kit/kit_action_test.dart` "shown on a fine pointer, absent on touch", "isolated left to right in Arabic" | PASS |
  | KIT-43 (additive) | `test/kit/kit_action_test.dart` "the old menu: slot keeps working", "KitButton.fromAction keeps the caller's key", "every existing KitButton constructor shape still compiles" | PASS |

- Changed test expectations (TEST-19): none — no existing test's expectation was changed.
- Goldens changed (each opened and looked at, TEST-6):
  - `kit_action_block_default_{dark,light}.png`: new — primary (accent fill), secondary (surface3), two tertiary text actions, enabled.
  - `kit_action_block_disabled_{dark,light}.png`: new — a disabled tertiary ("Duplicate") with its reason ("Fill in the server address first.") directly under it, dimmed but opaque text.
  - `kit_action_block_destructive_stack_{dark,light}.png`: new — "Restart" and "Delete server" (danger tone) each on their own line, clearly separated, even at 412 dp (no row).
  - `kit_action_stack_default_{dark,light}.png`, `kit_action_stack_disabled_{dark,light}.png`, `kit_action_stack_destructive_{dark,light}.png`: new — the same three states for `KitActionStack`.
  - No approved VL canvas render exists for this unit (EVID-12: none named for KitAction in the map); n/a.
- Before and after (EVID-10): n/a — no existing screen or golden changed; every PNG here is new.
- Accessibility: disabled action semantics carry `isEnabled: false` and the reason as `hint` (asserted in the test file); targets stay 48–50 dp (unchanged sizing plus the tokenised 20 dp icon/spinner slot); 200% text and Arabic were checked in the widget tests (RTL isolation, row overflow via the existing `text_scale_overflow_test.dart` `KitActionBlock`/`KitActionStack` scenes, both still passing across all 54 size/scale/direction combinations); full 2.0-text and Arabic **galleries** were not rendered (§7).
- Privacy and security: n/a — no credentials, stored data, external links or notifications changed. `KitAction.copy` copies through the existing `KitCopy.copy`, unchanged, which already redacts and never shows a SnackBar.
- Migration: n/a — no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_action_test.dart
$F test -j 1 --update-goldens test/goldens/kit/kit_action_golden_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/design_standard_test.dart test/l10n_coverage_test.dart test/kit/kit_manifest_test.dart
$F test -j 1 test/kit_motion_test.dart
$F test -j 1 test/team_controls_test.dart test/team_gate_answer_test.dart test/work_tab_status_line_test.dart
$F test -j 1 test/text_scale_overflow_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator (coordinator's job, R19/R20).
- Only a partial gallery: 12 of the frozen spec's 56 (`KitActionBlock`) + 24 (`KitActionStack`) PNGs — `default`, `disabled` and `destructive(_stack)` at 412×915 only. Missing: `working`, `overflow` (the More menu open), `copied`, `shortcut` states; the other four LAY-4 sizes for `default`; text 2.0 and Arabic RTL galleries. Deferred; the widget tests in `test/kit/kit_action_test.dart` cover the missing states' *behaviour* (working ignores taps, copy shows the check, shortcut visibility and RTL isolation, More overflow and its divider ordering) but not their rendered look.
- The `KitAsserts` strict-mode assert (Open question 1) is not built — see §1 contract problem 2.
- No `States:` doc-comment line was added to `KitButton`/`KitActionBlock`/`KitActionStack`/`KitInset` (KIT-12) — see §1.
- `test/text_scale_overflow_test.dart`'s `KitRequestCard/default` scene now overflows at 915×412 (a short, wide window) with 2.0 text, in both directions — a direct, correct consequence of implementing KitAction.md's rule 1/LAY-3 ("a short window keeps the compact, stacked arrangement") on `KitActionBlock`, which `KitRequestCard` uses unmodified. This is a shared test broken by this unit; `KitRequestCard` and `text_scale_overflow_test.dart`/its baseline are outside this unit's write set, so it is reported here for the integrator rather than fixed in place (R08).
- A pre-existing WCAG contrast near-miss in the dark theme's disabled-button fill (see §1 contract problem 3) was found, not fixed (out of write set).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitAction-v2` |
| Enabled | Yes — no flag; every existing `KitAction`/`KitButton`/`KitActionBlock`/`KitActionStack` call site gets the new rendering and layout immediately | |
| Verified | Tests and goldens only (this record) | this record |
| Committed | Yes | code head `5490ff63c46a09be5fd30a34baac7ba258c48a89` |
| Deployed | No | |
| Released | No | |
