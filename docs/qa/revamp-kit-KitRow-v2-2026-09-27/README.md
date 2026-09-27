# revamp-kit-KitRow-v2: KitRow v2 and KitSwipeAction (2026-09-27)

## 1. Scope

- Unit: `kit-KitRow-v2` (wave 1, tier 4, kit-change). Finish line: `KitRow` has the frozen v2 API (unavailable, server label, menu via long-press/right-click/Shift+F10/semantic actions, disabled reason without `Opacity`, selected, one Undo-only swipe) and `KitRowGroup` puts destructive rows last behind a full-width divider, with every current caller compiling. Non-goal: no screen migration (the `ListTile` sites move in wave 2), no `ListTile` look-alike parameters.
- Files changed: `lib/ui/kit/kit_row.dart`, `lib/ui/kit/kit_swipe_action.dart` (new), `test/kit/kit_row_test.dart` (new), `test/goldens/kit/kit_row_golden_test.dart` (new) and its 26 PNGs, this record.
- Pages (map ids): none of its own (a kit part; its adopters are the 57 pages in KitRow.md "Replaces").
- Specs followed: `docs/ux-system/kit-api/KitRow.md`, `docs/ux-system/kit-api/KitSwipeAction.md`; kit-v2 §2.5, §4.1, §4.2, §8.2, §8.3; rules KIT-26..29, KIT-43, STATE-8/9/12/13, LOOK-5, LOOK-14, A11Y-5, A11Y-8, COPY-30, MOT-5, MOT-11, DATA-11.
- Contract problems (PROC-20):
  1. **KitTappable has no menu name.** KitRow.md gives `menuLabel` ("the opened menu's name"), but `KitTappable` (which opens the menu on long-press, right-click, Shift+F10 and the context key) has no parameter to pass `showKitMenu(semanticsLabel:)`. `menuLabel` is used only when a tap on a row with a menu and no `onTap` opens it (`KitRowMenu.show(menuLabel:)`). Proposed: `KitTappable.menuLabel` (kit-KitTappable owner). Blocks nothing.
  2. **`KitSwipeAction.menuItem` has no `BuildContext`.** The spec says selecting the twin "runs the same onAct → showKitUndo path", but `KitMenuItem.onSelected` is a bare `VoidCallback` and `showKitUndo` needs a context. `KitRow(swipe:)` therefore adds its own twin bound to `KitSwipeAction.run(context)` (one path from swipe, menu and semantic action); the bare `menuItem` getter asserts in debug if selected outside a KitRow. Proposed: document `run(BuildContext)` as the public path in KitSwipeAction.md. Blocks nothing.
  3. **Gallery name collision.** KitRow.md asks for a `menu_open` shot, whose TEST-20 name `kit_row_menu_open_<theme>` already belongs to kit-KitRowParts-v2's `KitRowMenu` gallery. This unit's shot is `kit_row_context_menu_<theme>`. Proposed: rename the state in KitRow.md.
  4. **Trailing width.** KitRow.md test 11 asks for no overflow at 320 dp and 2.0 text with a trailing value; `KitRowValue` inside a `Row` gets unbounded width and overflowed by 230 px. The row now caps its trailing slot at half the window width (`MediaQuery.sizeOf`, not a `LayoutBuilder`, so rows still answer intrinsic sizing). Proposed: note the cap in KitRow.md "Adaptive".
  5. **QA folder name.** The unit task names `docs/qa/revamp-<unit id>/README.md`; STANDARDS.md EVID-1 names the dated folder. This record follows EVID-1.
- New kit parts (KIT-3): `KitSwipeAction` (`lib/ui/kit/kit_swipe_action.dart`, frozen in KitSwipeAction.md). Not exported from `kit.dart` (R06: the integrator adds the export).
- Map items (EVID-11): n/a: a kit part with no pages of its own.
- States (STATE-20): default, two-line, disabled, unavailable, selected, hover, focused, destructive, server, menu open → goldens `kit_row_*`; swipe revealing and acted → goldens `kit_swipe_action_*`.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitRow-v2-r2` (the task's `revamp/kit-KitRow-v2` already existed at the base with no commits and is checked out in another worktree, `wf_1d49ead2-79b-1`, from an earlier interrupted run; this run started a fresh branch rather than touch that checkout). Base `8ce9389b`, code head: see the commit before this record's commit.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_row_test.dart` | passes | 17 passed | PASS |
| 2 | `test/goldens/kit/kit_row_golden_test.dart --update-goldens`, with G5 checks | renders and passes G5 | 26 shots written; every shot passed G5 (the two `acted` shots first failed on a pending undo timer; fixed and re-run) | PASS |
| 3 | `test/goldens/kit/kit_divider_golden_test.dart` (renders KitRow; integrator-owned) | unchanged | 22 passed, no golden diff | PASS |
| 4 | `flutter analyze` on the four changed Dart files | no issues | no issues | PASS |
| 5 | `flutter analyze lib` | no errors from this unit | 6 errors, all undefined `AppLocalizations` getters in `folder_browser`/`safety_confirms` (stale generated l10n on base `8ce9389b`; `feat/phone-setup-v2` `eebd79d4` regenerates it). None in KitRow callers | PASS (unrelated errors listed) |

Owner decision 2026-09-27: other suites (ratchet, design-standard, l10n) were not run.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | STATE-8, LOOK-14 | `test/kit/kit_row_test.dart` "2: disabled reason replaces supporting" | run 1 |
  | STATE-12 | `test/kit/kit_row_test.dart` "3: unavailable with enable" / "3: unavailable without enable" | run 1 |
  | KIT-28, A11Y-5 | `test/kit/kit_row_test.dart` "4: long-press, right-click and Shift+F10 open the menu" | run 1 |
  | KIT-43 | `test/kit/kit_row_test.dart` "5: onLongPress with a menu asserts" | run 1 |
  | COPY-30 | `test/kit/kit_row_test.dart` "7: server label leads the supporting line" | run 1 |
  | STATE-9 | `test/kit/kit_row_test.dart` "8: selected exposes selected semantics" | run 1 |
  | §4.2 destructive last | `test/kit/kit_row_test.dart` "9: KitRowGroup puts destructive rows last" | run 1 |
  | A11Y-8, G6 | `test/kit/kit_row_test.dart` "11: 48 dp target and no overflow" | run 1 |
  | KIT-29, DATA-11, MOT-11 | `test/kit/kit_row_test.dart` "1, 3, 10: a full swipe acts once" | run 1 |
  | LOOK-5 (swipe), G8 | `test/kit/kit_row_test.dart` "8, 9: the revealed panel is surface3/text1" | run 1 |

- Changed test expectations (TEST-19): none.
- Goldens (each opened and looked at): all new, `test/goldens/kit/kit_row_{default,disabled,unavailable,server,selected,destructive,hover,focused,context_menu}_{dark,light}.png`, `kit_row_default_1280x800_{dark,light}.png`, `kit_swipe_action_{revealing,acted}_{dark,light}.png`, `kit_swipe_action_revealing_1280x800_{dark,light}.png`. No approved VL canvas render for KitRow v2 states (EVID-12: none).
- Before and after: no before render (KitRow had no gallery of its own at the base); after: `after-kit-row-default.png`, `after-kit-row-unavailable.png`, `after-kit-row-destructive.png`, `after-kit-row-context_menu.png`, `after-kit-swipe-action-revealing.png` (dark, 412×915).
- Accessibility: one merged node per row (button when it has `onTap`, `selected` when selected, `enabled: false` with the reason as the hint when disabled or unavailable); menu items and the swipe twin are custom semantic actions; 48 dp minimum through KitTappable; titles take two lines from 1.3× text; no overflow at 320 dp and 2.0 text.
- Privacy and security: n/a: no credentials, stored data, links or notifications changed.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_row_test.dart
$F test -j 1 test/goldens/kit/kit_row_golden_test.dart
$F analyze lib/ui/kit/kit_row.dart lib/ui/kit/kit_swipe_action.dart test/kit/kit_row_test.dart test/goldens/kit/kit_row_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Arabic/RTL and 2.0-text galleries and the RTL swipe direction test (dropped by the owner decision of 2026-09-27).
- KitSwipeAction test 6's route-pop and `paused` commit paths (KitUndo's own tests cover them); only the window-close and Undo paths are tested here.
- The full suite, the ratchet, design-standard and l10n gates were not run (owner decision 2026-09-27); goldens of other parts that render KitRow were not re-rendered except KitDivider's.
- The strict disabled-without-reason assert waits on the `KitAsserts` seam (KitRow.md Open question 2).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitRow-v2-r2` |
| Enabled | Yes (additive API; existing callers unchanged) | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
