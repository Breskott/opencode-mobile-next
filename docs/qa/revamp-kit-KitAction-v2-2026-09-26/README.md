# revamp-kit-KitAction-v2: KitAction, KitButton, KitActionBlock, KitActionStack (2026-09-26)

Updated 2026-09-27 after the review (11 findings). Section 8 maps each finding to its fix.

## 1. Scope

- **Unit:** `kit-KitAction-v2` (wave 1, tier 1a, kit-change).
- **Finish line:** `KitAction` carries `disabledReason`, `shortcut` and a `.copy` constructor. `KitActionBlock` stacks on every window when a tertiary action is destructive. A disabled action's reason shows as visible text and as its semantic hint, in the block, in the stack and in "More". Every existing call site keeps compiling and keeps passing its tests.
- **Non-goal:** no screen migration, no removal of `menu:`, no `KitAsserts` strict-mode seam (it does not exist yet), no shortcut binding.
- **Files changed:**
  - `lib/ui/kit/kit_buttons.dart` and `lib/ui/kit/kit_action_stack.dart`.
  - `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb`: one new key, `kitMore` ("More" / "المزيد"). PROC-13 lets a unit add ARB keys (en and ar together).
  - `test/kit/kit_action_test.dart`.
  - `test/goldens/kit/kit_action_golden_test.dart` and its 56 PNGs.
  - This record.
- **Generated l10n (PROC-13):** `lib/l10n/app_localizations*.dart` were regenerated locally so the code compiles, and were left uncommitted, as PROC-13 requires. **HEAD compiles only after `flutter gen-l10n`**, because `kit_buttons.dart` reads `l10n.kitMore`. The integrator regenerates after the merge.
- **Pages (map ids):** none. This is a kit-change unit.
- **Specs followed:**
  - `docs/ux-system/kit-api/KitAction.md` (the frozen API).
  - STANDARDS.md rules KIT-8, KIT-9, KIT-23, KIT-39, KIT-43, LAY-3, LAY-9, LAY-10, LAY-12, LAY-13, LAY-14, LOOK-5, LOOK-14, LOOK-21, MOT-7, STATE-7, STATE-8, COPY-8, PROC-13 and PROC-20.
  - kit-v2.md §2.7, §4.2, §4.9, §8.2 and §8.3; design-standard.md §2; visual-language §5.
- **New kit parts (KIT-3):** none.
- **Map items (EVID-11):** n/a, no pages.
- **States per page (STATE-20):** n/a, no pages. The part's states from the KitAction.md States table are default, disabled with reason, disabled without reason, working, destructive, copied and with shortcut. Section 5 lists the test and golden for each one.
- **Deferred states (STATE-21):** none.

### Contract problems (PROC-20)

1. **QA record path.**
   - **What it says:** the task text says `docs/qa/revamp-<unit id>/README.md`, with no date.
   - **Why wrong:** STANDARDS.md EVID-1 (the rulebook) requires the dated path.
   - **Resolution:** the dated path is used here. `blocks: false`.
2. **`KitAsserts` (KitAction.md, Open question 1).**
   - **What it says:** the structural asserts (a disabled action without a reason, a destructive primary in a block) fire only in strict mode.
   - **Why it is open:** `lib/ui/kit/kit_asserts.dart` is a coordinator seam that has not landed.
   - **Resolution:** the field and its rendering ship without the assert, as the spec itself directs. Test 9 waits for the seam. `blocks: false`.
3. **Disabled primary and secondary contrast (theme).**
   - **The problem:** `text3` on `surface3` measures 4.44:1 in the dark theme, below the WCAG AA 4.5:1 that G5 checks. The code is unchanged from the base.
   - **Resolution:** `theme_roles.dart` is outside this write set. The gallery's `disabled` scenes use a disabled tertiary action. `test/kit/kit_action_test.dart` "disabled look" covers the disabled primary and secondary look (text3 on surface3, full alpha).
   - **Proposed:** the visual-language token owner lifts `text3` or `surface3` in dark. `blocks: false`.
4. **Rule 1 / LAY-3, "a short window keeps the stacked layout", against KitRequestCard's large-text cap (G6).**
   - **What it says:** KitAction.md rule 1 and LAY-3 stack `KitActionBlock` on any window under 480 dp tall.
   - **Why it cannot hold today:** `KitRequestCard` caps itself at 45 % of the window at 2.0 text (`lib/ui/kit/kit_request_card.dart:103-107`), but keeps its `KitActionBlock` outside the part that scrolls (`kit_request_card.dart:197`). At 915×412 the cap is 185 dp, and the stacked Allow, Deny and tertiary buttons need about 236 dp. The first build of this unit overflowed there: `test/text_scale_overflow_test.dart`, `KitRequestCard/default` at 915×412, text 2.0, ltr and rtl, "RenderFlex overflowed by 51 pixels". G6 is absolute, and R11 keeps every current caller working. `KitRequestCard` is outside this write set.
   - **Resolution:** this one item stays at today's behaviour: the window's width decides, and a short wide window keeps the row. The destructive stacking (rule 3) and the compact stack are unchanged. `test/text_scale_overflow_test.dart` passes again (75 passed).
   - **Proposed text:** in KitRequestCard.md (kit-KitRequestCard-v2, which depends on this unit), "at large text the action block scrolls with the body, or the height cap applies to the body alone". Once that merges, KitActionBlock adds `|| KitLayout.isShort(context)` back to its stack condition.
   - `blocks: false`.
5. **Where the shortcut hint shows: the API against the gallery list.**
   - **What it says:** the API doc and the Adaptive table both say "on a fine pointer from expanded up". The gallery list asks for the `shortcut` scene "at 412 with desktop capabilities".
   - **Why wrong:** at 412 the hint does not show, so that scene would prove nothing.
   - **Resolution:** the hint is gated on `KitLayout.windowOf(context).isWide` and a fine pointer, following the two API statements. The gallery renders the scene at 1280×800 with desktop capabilities (`kit_action_block_shortcut_1280x800_*`), which keeps 14 state PNGs.
   - **Proposed gallery text:** "`shortcut` at 1280×800 with desktop capabilities".
   - **Coordinator:** please confirm which rule applies. `blocks: false`.
6. **The spinner's stroke has no token (KIT-9 against "New tokens: none").**
   - **What it says:** KIT-9 bans numeric literals in a part. The spec's Tokens section says "New tokens: none".
   - **Why wrong:** `KitTokens` has no stroke width for a spinner.
   - **Resolution:** `CircularProgressIndicator(strokeWidth: 2)` stays at today's value, which is also the stroke of the kit's other small spinner in `KitStatusMark`. The still arc under reduced motion uses `value: .75` (see MOT-7 below).
   - **Proposed:** a `KitTokens.spinnerStroke` (2) with the pre-wave seams, or on KitProgress.
   - `blocks: false`.
7. **Semantics of a working action (Accessibility: "`enabled` follows `enabled`").**
   - **What it says:** the button's `enabled` semantics follow `KitAction.enabled`.
   - **Why wrong:** `KitAction.enabled` is true for a working action with a callback, but test 7 requires its taps to be ignored. Semantics "enabled" would announce an enabled button that does nothing (review finding 5).
   - **Resolution:** an enabled action that is working is announced with `enabled: false` and keeps its accent fill. A caller that passes `onPressed: null` while working renders disabled, exactly as on the base.
   - **Proposed text:** "`enabled` follows `enabled && !working`". `blocks: false`.

A design decision for the coordinator to confirm, not a contract problem: the keyboard focus ring is `accent` on secondary and tertiary buttons, the same as KitTappable. On a filled primary it is the fill's own foreground (`onAccent`, or `onDangerFill` when destructive), because an `accent` ring inside an `accent` fill is invisible. KitAction.md names no ring colour.

## 2. Builds

- Branch `revamp/kit-KitAction-v2`, base `b67e3276b373c5bf5b6023d9ab5bcc61f5f23db4`.
- First build: code head `5490ff63`.
- Review fixes: code head `77cc154f`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is the wave 1 checkpoint's job (R19, R20).

## 4. Runs

All runs used the pinned Flutter through `tool/qa/machine_lock.sh`, with `-j 1`, on code head `77cc154f`.

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes: the new tests against the first build's code (`kit_buttons.dart` and `kit_action_stack.dart` stashed) | fails | 15 failed, listed in `failing-first.txt` | PASS |
| 2 | `test/kit/kit_action_test.dart` | passes | 45 passed (with the gallery: 101 passed together on the final code) | PASS |
| 3 | `test/goldens/kit/kit_action_golden_test.dart --update-goldens`, then the same without the flag | 56 shots, G5 clean in both themes | 56 passed; each PNG looked at (§5) | PASS |
| 4 | `test/text_scale_overflow_test.dart` (G6) | passes | 75 passed. This fixes the first build's `KitRequestCard` 915×412 failure. | PASS |
| 5 | `test/kit_ratchet_test.dart`, `test/golden_harness_test.dart`, `test/kit/kit_manifest_test.dart` | pass | 42 passed. G15x and G21 report counts falling to 0 for both files, which is informational: the integrator regenerates the baseline (R05). | PASS |
| 6 | `test/kit_motion_test.dart` (G8x) | passes | 8 failures, each "now settles, remove it from the baseline": the working spinner is now still under reduced motion (MOT-7). See sharedTestsBroken. | FAIL (shared baseline, improvement) |
| 7 | `test/goldens/kit/kit_confirm_sheet_golden_test.dart`, `test/goldens/kit/kit_foundation_golden_test.dart` (compared, not updated) | pass | 36 passed, 2 differ: `kit_confirm_stop_working_{dark,light}`, only in the spinner (before and after in §5). See sharedTestsBroken. | FAIL (shared golden, integrator regenerates) |
| 8 | Callers: `design_standard_setup`, `design_standard`, `first_run_welcome`, `oc2_server_discovery`, `phone_setup_notification_route`, `phone_setup_ready_screen`, `phone_setup_start_screen`, `phone_termux_discovery`, `team_controls`, `team_discover`, `team_gate_answer`, `team_motion`, `team_policy`, `work_tab_status_line`, `l10n_coverage` | pass | 37 + 35 + 67 + 65 + 28 passed | PASS |
| 9 | `test/kit/kit_keyboard_test.dart`, `test/accessibility_guidelines_test.dart` | pass | 33 passed | PASS |
| 10 | `flutter analyze lib test` | no issues | "No issues found!" | PASS |
| 11 | `dart format --language-version=3.10 --set-exit-if-changed` on the 4 changed Dart files | no change | 0 changed | PASS |

## 5. Evidence

- **`failing-first.txt`:** step 1. Each review fix has a test that failed on the first build.
- **Rule evidence (PROC-31):** every test below is in `test/kit/kit_action_test.dart` and passes on `77cc154f`. Rules are grouped by theme.

  **Disabled actions and their reasons**

  | Rule | Test (group, then name) |
  |---|---|
  | STATE-8, test 1 | "disabledReason" group: the block's disabled primary shows its reason as text and hint; the stack's disabled tertiary; the reasons under the row |
  | LOOK-14, test 2 | "disabled look": text3 on surface3 at full alpha, and no Opacity around a button |
  | STATE-8 in "More" (finding 1) | "overflow items (More)": a disabled action in More shows its reason as a line and as its hint |
  | TEST-5 key (finding 6) | "overflow items (More)": two tertiary actions with the same label and reasons build; `kit-action-reason` is counted |

  **Layout (stack, row, "More")**

  | Rule | Test (group, then name) |
  |---|---|
  | LAY-14, LAY-9, test 3 | "destructive stacking": a destructive tertiary forces the stack on compact, medium and large. The clearance is measured on the `ButtonStyleButton` areas (finding 10). |
  | LAY-13, test 4 | "destructive stacking": medium and up is one row with the primary at the end; compact stacks. A short wide window keeps today's row (PROC-20, problem 4). |
  | §2.7 ordering, test 5 | "overflow": a third tertiary action moves into More; a destructive overflow action renders last, after a divider |

  **Copy**

  | Rule | Test (group, then name) |
  |---|---|
  | KIT-23, test 6 | "KitAction.copy": copies the text read at tap time, announces once, shows the check, then reverts, with no SnackBar |
  | G12, test 6 | "KitAction.copy keys and redaction": a provider key is redacted before it reaches the clipboard |
  | Key on one widget (finding 2) | "KitAction.copy keys and redaction": the caller's key is on exactly one widget and a tap copies; a GlobalKey on a copy action builds |
  | Copy in "More" (finding 1) | "overflow items (More)": a copy action in More is enabled and copies |

  **Working, shortcut and keyboard**

  | Rule | Test (group, then name) |
  |---|---|
  | STATE-7, test 7 (finding 5) | "working": shows the spinner and ignores taps. "working semantics": `onPressed: null` renders disabled as before; with a callback the fill stays accent, taps are ignored and it is not announced as enabled. |
  | Test 8 (finding 7) | "shortcut window rule": absent at 412×915 on touch; absent at 412×915 with a mouse; shown at 1280×800 with a mouse. "shortcut": isolated left to right in Arabic. |
  | LOOK-21, LAY-10 (finding 8) | "keyboard focus ring": primary, secondary and tertiary each draw a `focusRingWidth` ring on keyboard focus |

  **Gates and compatibility**

  | Rule | Test (group, then name) |
  |---|---|
  | G6, test 11 | "G6: no overflow": block and stack with two long tertiary labels and two reasons, at every LAY-4 size and 915×412, text 1.0, 1.3 and 2.0, LTR and RTL |
  | MOT-7, G8, test 12 | "G8: settles after one pump under reduced motion": default, disabled, working, working with no icon, destructive, stack, shortcut and copied |
  | KIT-43, test 10 | "KIT-43 compatibility": the `menu:` slot; `fromAction` keeps the key; every constructor shape. `kit-actions-more` and `kit-button-working` are used above. |

- **Changed test expectations (TEST-19):**
  - These changes are only in this unit's own `test/kit/kit_action_test.dart`.
  - "a short window keeps the stack even when wide (LAY-3)" became "a short wide window keeps today's row (PROC-20)". The reason is contract problem 4 (PROC-20).
  - The LAY-9 clearance is now measured between the button areas instead of the text glyphs (LAY-9, finding 10).
  - No other file's test expectation was changed.
- **Goldens (TEST-6).** Each one was opened and looked at.
  - **Unchanged:** the first build's 12 PNGs (the default, disabled and destructive states at 412×915 for both parts) are byte-identical.
  - **New `kit_action_block_*` states:**
    - `working_{dark,light}`: "Connect" with its still arc in `onAccent` (no track) and "Cancel". Before this fix, the arc was `accent` on a `surface3` track, almost invisible on the accent fill.
    - `overflow_{dark,light}`: "Save", then Duplicate and Rename each on their own line (the destructive "Delete" is in overflow, so the block stacks, rule 3). The More menu is open with Copy link and Archive, a divider, then Delete in `danger`.
    - `copied_{dark,light}`: "Done" and a check with "Copied".
    - `shortcut_1280x800_{dark,light}`: the end-aligned row "Save draft Ctrl+S · Cancel Esc · Send Ctrl+Enter", with the hints in mono.
  - **New `kit_action_block_default` sizes:**
    - At 360×800: stacked.
    - At 800×1280, 1280×800, 1600×1000 and at 915×412 (contract problem 4): the end-aligned row, primary last.
    - At `text2` 412: stacked, words at 2×.
    - At `text2` 1280: the row, at 2×.
    - At `ar` 412: stacked, tertiary actions start-aligned on the right.
    - At `ar` 1280: the row mirrored, primary at the left.
  - **New `kit_action_stack_default` sizes:** stacked and full width at every size. At 1280 and 1600 it is inside the gallery's 720 dp column. Text 2.0 and Arabic follow the block, mirrored in RTL.
  - **VL canvas (EVID-12):** no approved VL canvas render is named for KitAction. n/a.
- **Before and after (EVID-10):**
  - `before-kit_confirm-stop_working_light.png` (base golden `test/goldens/kit/kit_confirm_stop_working_light.png`) and `after-kit_confirm-stop_working_light.png`. The spinner in the working confirm button changes from an `accent` arc on a `surface3` track to a still `onDangerFill` arc. Nothing else changes.
  - **Behaviour change for current callers, `working` with a callback:**
    - Before: taps reached the callback.
    - After: taps are ignored, the fill stays accent, and the button is announced as not enabled.
    - Callers that pass `working: busy, onPressed: busy ? null : f` look and behave exactly as on the base: disabled, with the spinner. These are `team_intro_screen.dart:245-258`, `start_run_sheet.dart:428`, `phone_setup_ready_screen.dart:259` and `phone_setup_start_screen.dart:551`. Their tests pass (step 8).
- **Accessibility:**
  - A disabled action's reason is its semantic hint, in the block, the stack and "More".
  - A working action is not announced as an enabled button.
  - The keyboard focus ring is 2 physical px.
  - Targets are at least 48 dp, with 8 dp between a destructive button's area and every other target (measured).
  - G5 (tap targets, labels, text contrast, reading order) passes in both themes for all 56 shots.
  - 2.0 text and Arabic are rendered in the gallery and checked by the G6 matrix.
- **Privacy and security:** `KitAction.copy` and the copy item in "More" copy only through `KitCopy.copy`, which redacts (G12, tested with a fake provider key). Nothing else touches credentials, stored data, external links or notifications.
- **Migration:** n/a. No stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F gen-l10n   # HEAD needs the generated kitMore getter (PROC-13)
$F test -j 1 test/kit/kit_action_test.dart
$F test -j 1 test/goldens/kit/kit_action_golden_test.dart
$F test -j 1 test/text_scale_overflow_test.dart
$F test -j 1 test/kit_ratchet_test.dart test/golden_harness_test.dart test/kit/kit_manifest_test.dart
$F test -j 1 test/kit_motion_test.dart
$F test -j 1 test/goldens/kit/kit_confirm_sheet_golden_test.dart
$F analyze lib test
```

## 7. NOT proven

- Not run on a device or emulator (coordinator, R19 and R20).
- The `KitAsserts` strict-mode asserts (test 9) are not built (contract problem 2).
- The short-window stack (rule 1, LAY-3) is deferred to kit-KitRequestCard-v2 (contract problem 4).
- No `States:` doc-comment line was added to the four classes (KIT-12). It would turn the pre-existing `kit_manifest_allowlist.json` "states" entries stale, which is integrator-owned.
- Shared tests this unit breaks, all in the improving direction (the integrator fixes them after the merge, R08):
  - `test/kit_motion_test.dart`: 8 baseline entries now settle. Remove these from `test/kit_motion_baseline.json` and `_frozenBaseline`:
    - `KitActionBlock / working / {system,effectsOff}`;
    - `KitButton / {primary,secondary} working / {system,effectsOff}`;
    - `KitConfirmSheet / working / {system,effectsOff}`.
  - `test/goldens/kit/kit_confirm_stop_working_{dark,light}.png`: regenerate (spinner only).
- The disabled primary and secondary contrast in dark is not fixed (contract problem 3).

## 8. Review findings → fixes

| # | Finding | Fix |
|---|---|---|
| 1 | A copy or disabled action in "More" was broken, and its reason was dropped | `enabled: action.enabled`; a copy runs `KitCopy.copy`; the reason shows as a second muted line and as the hint; tests added |
| 2 | A copy action's key was on two widgets | The key is on the outer `KitButton` only; tests with `find.byKey` and a GlobalKey |
| 3 | The gallery had 12 of 56 PNGs | All 56 rendered and looked at (the shortcut scene at 1280, contract problem 5) |
| 4 | G6 failure in KitRequestCard at 915×412, text 2.0 | PROC-20: the short-window item stays at today's behaviour, raised as contract problem 4; G6 passes |
| 5 | `working` turned a null `onPressed` into an enabled button | Null stays disabled; an enabled working button is announced as not enabled; the look change is recorded in §5 |
| 6 | Reason keys were derived from labels | One key, `kit-action-reason`, on the inner Text; the copies are identical in both files; a test with duplicate labels |
| 7 | The shortcut hint showed at any window size | Gated from expanded up; the gallery contradiction is raised as contract problem 5 |
| 8 | No keyboard focus ring | `side` on focus, `KitTokens.focusRingWidth`; tests for all three roles |
| 9 | Literals were not tokenised | Tertiary padding and KitInset use `space2`; the More labels use `KitText.styleOf` (danger, tertiary); the spinner stroke is contract problem 6 |
| 10 | Spec tests were missing or weak | Tests 2, 6 (redaction), 8 (412), 11 and 12 added; LAY-9 measured on the button areas |
| 11 | ARB edits outside the write set; HEAD needs gen-l10n | PROC-13 allows adding ARB keys (en and ar); the generated files stay uncommitted; HEAD needs `flutter gen-l10n` (§1) |

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitAction-v2` |
| Enabled | Yes, with no flag: every existing `KitAction`, `KitButton`, `KitActionBlock` and `KitActionStack` call site gets it | |
| Verified | Tests and goldens only (this record) | this record |
| Committed | Yes | code head `77cc154f` |
| Deployed | No | |
| Released | No | |
