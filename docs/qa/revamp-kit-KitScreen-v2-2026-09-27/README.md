# revamp-kit-KitScreen-v2: KitScreen v2 (2026-09-27)

## 1. Scope

- Unit: `kit-KitScreen-v2` (wave 1, kit tier 4). Finish line: KitScreen is the one screen frame (a page with a top bar, one status slot, a pinned search, the loading bar, the body, a bottom primary lifted above the keyboard, a published bottom inset, twoPane and threePane) and v1 callers are unchanged. Non-goal: moving any screen onto it (that is screen-unit work), and a separate `KitScaffold` class (KitScreen.md "Replaces": `KitScreen(topBar:)` is the scaffold, and `kit_scaffold.dart` is not created).
- Files changed: `lib/ui/kit/kit_screen.dart` (v2), `lib/ui/kit/kit_status_slot.dart` (optional `child`, per the coordinator ruling), `test/kit/kit_screen_test.dart` (new), `test/goldens/kit/kit_screen_golden_test.dart` and 18 PNGs (new). `kit_layout.dart` needed no edit because 296/700/340 were added before the wave. `test/kit/kit_pre_wave_tokens_test.dart` is unchanged.
- Pages (map ids): n/a (kit part).
- Specs followed: `docs/ux-system/kit-api/KitScreen.md`; kit-v2 §2.12, §2.3, §2.7, §8.2; STANDARDS KIT-35, KIT-36, KIT-43, LAY-5, LAY-6, LAY-12, STATE-4, STATE-14, R23.
- Contract problems (PROC-20):
  1. KitScreen.md test 9 says threePane's side pane is "absent at 1280×800". But 1280 is in the large class (§8.1, large ≥ 1200), and the same spec's Adaptive section shows the side pane on large ("between 1200 and 1336 dp the detail takes the rest"). I built it to the Adaptive section, so the side pane shows from 1200. The test checks 1600 (side is 340), 1280 (side shown, detail < 700) and 1100 (side absent). Proposed text for test 9: "absent at 1100×800 (expanded)".
  2. Pane scope vs KitTopBar: KitScreen.md §6 and KitTopBar.md test 2 both require `KitTopBar(exit: auto)` in a detail pane to show no Back. No seam for this is frozen, and `KitTopBar.resolveExit` (in `kit_top_bar.dart`, outside this write set) reads only the route. This unit adds the seam `KitScreen.inPane(context)` (a public static beyond the frozen API) and wraps detail and side panes in the scope. kit-KitTopBar's owner or the integrator still has to add `if (KitScreen.inPane(context)) return KitTopBarExit.none;` at the start of `resolveExit`. Until then a pane's bar needs `exit: none`, which the gallery uses.
  3. KitStatusLine-v2 slot reach (resolved by the coordinator ruling): `KitStatusLineSlot` gained an optional `Widget? child`. With it, the slot draws its line above `child` (which fills the rest), and contributions inside `child` reach the slot.
  4. G5's reading-order check compares consecutive leaves only, so the list → detail → side pane order (A11Y-4) reads as "goes back up". The pane galleries keep the detail and side content out of semantics, following KitNav's wide gallery. The list pane is still checked.
  5. In pane layout the status line spans the window above all panes, not between the list pane's bar and its search. The slot draws its line above the content it hosts, so it cannot sit inside one pane while its reach covers the others.
- New kit parts (KIT-3): none.
- Map items (EVID-11): n/a.
- States (STATE-20): default, loading, status, search and keyboard → goldens at 412x915; twoPane empty, twoPane selected and threePane → goldens at 1280x800; all in light and dark.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitScreen-v2-r2`. The name `revamp/kit-KitScreen-v2` already existed at the stale commit c228215b and is checked out in another worktree, so it could not be reused. Base `8ce9389b` (feat/phone-setup-v2).
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_screen_test.dart` | passes | 24 passed | PASS |
| 2 | `test/goldens/kit/kit_screen_golden_test.dart` (rendered with --update-goldens, then compared) | passes, G5 clean | 18 passed | PASS |
| 3 | `flutter analyze` on the four changed Dart files | no issues | no issues | PASS |

Per the owner decision of 2026-09-27, other suites (ratchet, design standard, screen tests) were not run.

## 5. Evidence

- Rule evidence:

  | Rule | Test (`test/kit/kit_screen_test.dart`) |
  |---|---|
  | KIT-43 | "v1 parameters build as before, bottom keeps its key" |
  | KIT-35 / STATE-14 | "status slot" group (own status, app-wide wins, priority order, tab contribution, offstage tab, one live region) |
  | LAY-6 | "bottom block" group (keyboard 300 → 308; published inset and endPadding) |
  | LAY-5 | "twoPane" and "threePane" groups (296 · ≤ 700 · 340; openDetail pushes or selects; short window) |
  | LAY-12 / K2 §2.7 | "one of each (debug)" group |
  | KIT-36 | "a page nested in a body asserts" |
  | G6 | "no overflow across sizes and text scales" |
  | G15 | "G15: kit_screen.dart compares no width to a literal" |

- Goldens (each opened and looked at): `test/goldens/kit/kit_screen_{default,loading,status,search,keyboard}_{dark,light}.png`, `kit_screen_default_1280x800_*`, `kit_screen_two_pane_empty_1280x800_*`, `kit_screen_two_pane_selected_1280x800_*`, `kit_screen_three_pane_1280x800_*`. The owner's gallery rule of 2026-09-27 (412x915 and 1280x800 only, no Arabic) replaces KitScreen.md's size list, so three_pane is rendered at 1280x800.
- Accessibility: each pane is a semantics container, read list → detail → side; the drawn status line is the one live region; no overflow at text 1.0/1.3/2.0 from 320 to 1600 dp.
- Privacy and security: n/a.
- Migration: n/a, no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_screen_test.dart test/goldens/kit/kit_screen_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Callers' own tests were not run. The new debug one-of-each check (a post-frame assert) may fail an existing screen test that shows two primaries, two status lines, two KitRefresh or two KitDetailsFold in one KitScreen. Any such failure is a real LAY-12 finding for the integrator.
- Only the count half of the "one KitDetailsFold, and it is the last content" check is implemented. The "last content" half is not.
- `KitTopBar(exit: auto)` in a pane still shows Back until KitTopBar reads `KitScreen.inPane` (contract problem 2).
- No RTL or Arabic galleries (owner decision); there is one RTL pane-order test only.
- Moving the FloatingActionButton to the bottom primary (R23) in `managed_workspaces_screen.dart`, `terminal_screen.dart` and `worktrees_screen.dart` belongs to those screens' units.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes (the inPane consumer in KitTopBar is pending) | `revamp/kit-KitScreen-v2-r2` |
| Enabled | Yes (existing callers get the slot and the debug check) | |
| Verified | Tests and goldens only | this record |
| Committed | Yes | |
| Deployed | No | |
| Released | No | |
