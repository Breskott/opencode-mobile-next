# revamp-kit-KitRowParts-v2: KitRowParts v2 (2026-09-27)

## 1. Scope

- Unit: `kit-KitRowParts-v2` (wave 1, kit-change). Finish line: KitRowMenu opens `showKitMenu`, KitSwitchRow has `risk` (scope, until, status-line condition) and `locked`, and KitExpandRow can be controlled. Non-goal: moving any screen onto the new parameters (wave 2), and KitRow.menu.
- Files changed: `lib/ui/kit/kit_row_parts.dart`; `lib/l10n/app_en.arb` (6 new `kit*` keys) and the gen-l10n output; `test/kit/kit_row_parts_test.dart` (new); `test/goldens/kit/kit_row_parts_golden_test.dart` (new) and its PNGs; this record.
- Pages (map ids): none migrated (kit unit).
- Specs followed: `docs/ux-system/kit-api/KitRowParts.md`; kit-v2 §2.5, §2.6, §2.11; KIT-28, KIT-30, KIT-35, KIT-43, SEC-9, STATE-8, MOT-5.
- Contract problems (PROC-20):
  1. **KitChoiceList not merged.** KitRowParts.md (decision D7) makes the risk step's 2–3 `until` options a `KitChoiceList.single(actsOnTap: true)`. `kit-KitChoiceList` is not on `feat/phone-setup-v2`; the unit's computed dependencies still name kit-KitSegmented (the pre-D7 edge), and KitSegmented cannot act on its already-selected segment, so it cannot carry a one-tap choice. No local substitute part was built: the step uses full-width `KitButton.secondary` per duration (each acts on tap, KIT-25). Proposed: swap to KitChoiceList when it merges (one call site in `_riskStep`). Blocks: nothing else.
  2. **The status slot cannot receive contributions from a screen body.** `KitStatusLineSlot` (kit_status_slot.dart, kit-KitStatusLine-v2) takes no `child`; its private `_KitStatusSlotScope` wraps only the drawn line, so no row below a screen can reach it through `KitStatusContribution`, and `KitScreen` (another file) cannot build the private scope. The row contributes exactly as frozen (`KitStatus(kind: riskySwitch, id: 'risk:<switchKey or title>', icon, message: onLabel, action: Turn off)`), and the test checks the contributed status and its action; "the screen's status line says so" is **not proven** until kit-KitScreen-v2 (or the slot's owner) gives the slot a way to wrap the body. Proposed: `KitStatusLineSlot` gains a `child`, or KitScreen.md names a public scope constructor. Blocks: the Tests-required item 4 "inside a KitScreen with its slot".
  3. **KitRow dims disabled rows with `Opacity(.5)`.** KitRowParts.md says the disabled switch uses no Opacity. KitSwitchRow no longer passes `enabled: false` to KitRow (it passes `onTap: null`), so nothing dims; the title stays `text1` rather than `text3` because KitRow has no title-colour hook (kit-KitRow-v2's file).
  4. **Gallery budget.** The spec's 74 PNGs (Open question 2) are superseded by the owner decision of 2026-09-27: 412x915 + 1280x800, light and dark, no Arabic. This gallery renders every state at 412x915 and each widget's default at 1280x800: 26 PNGs.
- New kit parts (KIT-3): none. `KitUntil` and `KitRisk` are part of the frozen API in this file.
- Map items (EVID-11): n/a (kit unit).
- States per page (STATE-20): KitRowMenu default/open → goldens; hidden → test. KitSwitchRow off, on, disabled, risk_step, risk_on, locked → goldens and tests. KitExpandRow folded, open → goldens; controlled → test.
- Deferred states (STATE-21): KitSwitchRow "risk on" on the screen status line → needs the slot fix (contract problem 2).

## 2. Builds

- Branch `revamp/kit-KitRowParts-v2`, base `024e97b0`, code head: see `git log` on the branch.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_row_parts_test.dart` | passes | 17 passed | PASS |
| 2 | `test/goldens/kit/kit_row_parts_golden_test.dart --update-goldens` | renders, G5 clean | 26 passed; PNGs opened and looked at | PASS |
| 3 | Other suites | not run (owner decision 2026-09-27, speed) | — | n/a |
| 4 | `dart analyze` on the changed files and the 15 caller files (KIT-43) | no issues | no issues | PASS |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`test/kit/kit_row_parts_test.dart` + `--plain-name`) or golden |
  |---|---|
  | STATE-8 (no dead ⋮) | "disabled or empty renders no button" |
  | KitMenu ordering | "a tap opens the menu, destructive items last" |
  | KIT-30 / SEC-9 | "off to on unfolds the step without calling onChanged", "Not now folds back and calls neither", "one option offers Turn on", "while on: status condition with Turn off; on to off acts at once" |
  | STATE-8 (disabled says why) | "disabled shows its reason as text and hint, undimmed" |
  | locked | "locked: no switch, the word, no toggle", "locked with value false asserts" |
  | controlled fold | "controlled: a tap reports without unfolding", "uncontrolled toggles and reports; Enter and Space fold", "maintainState keeps a folded child's State" |
  | G6 | "the step lays out at text 2.0 and 320 dp" (LTR only; Arabic dropped) |
  | G14 | "a tap toggles; Space toggles when focused", "Enter on the focused button opens the menu" |

- Changed behaviour (TEST-19): `KitRowMenu(enabled: false)` and `KitRowMenu(items: [])` now render nothing instead of a dimmed ⋮; the menu is `showKitMenu`'s panel, not a `PopupMenuButton`, and the default tooltip is `kitMore` ("More", same words as `chatUiMore`). Any shared test that found a `PopupMenuButton` or a disabled ⋮ changes expectation (listed as sharedTestsBroken candidates, not run).
- Goldens: new `kit_row_menu_*`, `kit_switch_row_*`, `kit_expand_row_*` (first render; each opened and looked at).
- Accessibility: locked is toggled-on + disabled with the locked word as hint; disabled carries its reason as visible text and hint; the risk step moves focus to the scope sentence; KitExpandRow keeps `button` + `expanded`, and adds Right/Left (mirrored in RTL) to open/close.
- Privacy and security: risky switches now state scope and duration before taking effect (KIT-30); no credentials, stored data or links touched.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_row_parts_test.dart
$F test -j 1 test/goldens/kit/kit_row_parts_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- The risky switch's condition on a real screen's status line (contract problem 2).
- The `until` choice as KitChoiceList (contract problem 1).
- Shared suites, ratchet and l10n-coverage gates were not run (owner decision 2026-09-27).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | partial (status-line hosting and KitChoiceList blocked) | `revamp/kit-KitRowParts-v2` |
| Enabled | Yes for existing callers; new parameters unused until wave 2 | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
