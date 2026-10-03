# revamp-kit-KitBoardLane: Build KitBoardLane (2026-09-27)

## 1. Scope

- Unit: `kit-KitBoardLane` (wave 1, tier 4 in the run's numbering, `kit-part`). Finish line: `KitBoardLanes`, `KitBoardLane` (+ `.loading`) and `KitBoardColumn` exist to the frozen API in `docs/ux-system/kit-api/KitBoardLane.md`, with behaviour tests and a gallery. Non-goal: moving `team_board_screen.dart` onto it (its wave-2 unit, C36).
- Files changed: `lib/ui/kit/kit_board_lane.dart` (new), `test/kit/kit_board_lane_test.dart` (new), `test/goldens/kit/kit_board_lane_golden_test.dart` (new) plus 12 PNGs, `lib/l10n/app_en.arb` (+2 `kit`-prefixed keys: `kitBoardLane`, `kitBoardLaneLoading`) and the regenerated `lib/l10n/app_localizations*.dart`.
- Pages (map ids): none adopted. The part covers `team-board#team-board-pages` (kitGap `KitPagedColumns`).
- Specs followed: KitBoardLane.md (frozen API); kit-v2 §5, §8.2, §9.2; KIT-1, KIT-12, LAY-1, LAY-2, LAY-8, LAY-10, STATE-4, STATE-18, A11Y-4, A11Y-5, LOOK-14, MOT-1, MOT-5, MOT-7.
- Composes: `KitTabStrip` / `KitTab` (kit-KitTabSwitcher-v2), `KitTaskCard` in tests (kit-KitTaskCard), `KitAnimatedRows`, `KitRefresh`, `KitSkeletonRows`, `KitStateView` (host's inline empty), `KitLayout.lane*`, `KitTokens`, `KitMotion`.
- Contract problems (PROC-20):
  1. **Lane 372 dp and 20 dp peeks cannot both hold with a space1 gap.** At 412 dp the page slot is 372 (412 − 2 × `lanePeek`) and the neighbours' slots show 20 dp, as specified. The `space1` gap between paged lanes sits inside the slot (2 dp each side), so the lane surface is 368 wide and each neighbour's surface shows 18 dp. Test 4 asserts those numbers. At 700 dp the slot is the 400 cap and the surface 396. Proposed text: "the page slot is `min(width − 2 × lanePeek, laneMaxWidth)`; the surface is the slot less `space1`".
  2. **Branch name.** `revamp/kit-KitBoardLane` already existed at the base, checked out in a stale worktree (`.claude/worktrees/wf_1d49ead2-79b-6`) that held an uncommitted earlier draft of this part and no commits. I did not touch that checkout. The unit is on `revamp/kit-KitBoardLane-v2` (the run's `-v2` convention for reruns); the earlier draft was read and finished here.
  3. **Gallery list.** The owner decision of 2026-09-27 (later, so it wins under R15) replaces the spec's 24 PNGs with 412x915 and 1280x800, light and dark: the five declared states at 412x915 and `loaded` at 1280x800 (four lanes side by side), 12 PNGs. The 360x800, 915x412, 800x1280, 1600x1000, text-2.0 and Arabic shots are covered by behaviour tests 4, 11 and 13 instead.
  4. **Skeleton colour.** The spec names `surface3` for the skeleton. `KitSkeletonRows` paints its own bars (from the colour scheme), and the part puts each one on a `surface1` card shape so the skeleton reads as the cards to come. The part does not repaint `KitSkeletonRows`.
  5. **Ctrl+→ inside the strip.** The strip's own arrow keys (KitTabSwitcher v2) handle Left and Right, with or without Ctrl, while a tab has focus. So Ctrl+→ moves between lanes from a card, not from the strip. From the strip, Tab enters the lane first (test 9).
  6. **Ctrl+→ onto an empty lane** pages to it and keeps focus where it was, because there is no card to focus. The next Ctrl+→ goes on from there (test 9).
  7. **`KitBoardLane.md` and the rest of `docs/ux-system/` are not on `feat/phone-setup-v2`.** They were read from the main checkout.
- New kit parts (KIT-3): none beyond the unit's own (not exported from `kit.dart`: the integrator adds it, R06).
- Map items (EVID-11): n/a: no screen adopted in this unit.
- States (STATE-20): loading, loaded, lane empty and lane loaded (plus needs-you and a long, scrolled lane) each have a golden and a behaviour test.
- Deferred states (STATE-21): none. Not answering, failed and an empty board belong to the host's page `KitStateView`, by spec.

## 2. Builds

- Branch `revamp/kit-KitBoardLane-v2`, base `8ce9389b` (feat/phone-setup-v2); code head: see `git log`.
- No APK (unit agents do not build).

## 3. Devices

None: only tests, goldens and renders. Device proof is part of the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | `test/kit/kit_board_lane_test.dart` | passes | 14 passed | PASS |
| 2 | `test/goldens/kit/kit_board_lane_golden_test.dart` (G4, G5 in both themes) | passes | 12 passed | PASS |
| 3 | `flutter analyze` on the three new Dart files | no issues | no issues | PASS |
| 4 | Ratchet, design-standard, l10n and other shared suites | not run (owner decision 2026-09-27: run only your own new files) | not run | n/a |

## 5. Evidence

- Rule evidence (PROC-31), all in `test/kit/kit_board_lane_test.dart`:

  | Rule | Test (`--plain-name`) |
  |---|---|
  | Lanes and strip agree | "1 opens on selected; the strip shows that tab selected" |
  | One `onSelected` per settle | "2 a swipe calls onSelected(selected + 1) once on settle" |
  | MOT-1, MOT-7 strip paging, reduced jump | "3 a strip tap animates to the lane; reduced motion jumps" |
  | §8.2 adaptive widths (LAY-1, LAY-2) | "4 lane width: …" (412: slot 372, peeks 20; 700: cap 400; 1024: 3 side by side, no PageView; 1600: all 5) |
  | STATE-4, honest counts | "5 loading: labels, no counts, 4 skeleton cards, no swipe" |
  | Never a blank lane | "6 an empty lane says so; no cards and no empty asserts" |
  | Counts never invented | "7 a count that differs from the lane asserts" |
  | LOOK-14, STATE-18 | "8 stale is not dimming: card text is never faded" |
  | LAY-10, G14 | "9 keyboard: Tab from the strip into the lane; Ctrl+→ pages" |
  | A11Y-4, A11Y-5 | "10 each lane is a labelled container; pages scroll" |
  | LAY-8 RTL | "11 RTL: the first column at the right edge; Ctrl+← forward" |
  | MOT-4 pull to refresh | "12 pull on the visible lane refreshes once" |
  | G6 | "13 no overflow at every size, scale and direction" (320x800, 412x915, 600x960, 840x1000, 1280x800, 1600x1000, 915x412 × 1.0/1.3/2.0 × LTR/RTL) |
  | G8 | "13b reduced motion settles after one pump" |

- Changed test expectations (TEST-19): none (new files only).
- Goldens (new; I opened each one and checked it): `kit_board_lane_{loading,loaded,lane_empty,needs_you,long_lane}_{dark,light}.png` and `kit_board_lane_loaded_1280x800_{dark,light}.png`. They show:
  - the strip with no numbers while loading, and 4 skeleton cards in the Working lane;
  - Working selected, with Ready and Review peeking at the edges;
  - Review's inline "Nothing waiting for review";
  - the strip's needs-you badge (2) and the needs-you cards;
  - Working with 12 cards, scrolled;
  - four lanes side by side at 1280, with Done off to the end.
- Accessibility:
  - Each lane is a semantics container labelled "Working, 3 tasks" or "Review, no tasks". While loading, the lane is "Loading Working".
  - The paged view exposes scroll-left and scroll-right.
  - A lane change is not a live region: the strip's selected tab changes instead.
  - On compact, the lanes that are not selected are left out of the focus order. Tab runs from the selected tab into that lane's cards. On wide windows every lane is in the order, each in its own traversal group.
  - Ctrl+→ and Ctrl+← follow the reading direction.
  - A mouse drag never pages; a horizontal wheel or Shift+wheel scrolls the wide list, and the scrollbar shows on a fine pointer.
- Privacy and security: none. The part shows only what the host gives it, and changes nothing.
- Migration: n/a: no stored format.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_board_lane_test.dart test/goldens/kit/kit_board_lane_golden_test.dart
$F analyze lib/ui/kit/kit_board_lane.dart test/kit/kit_board_lane_test.dart test/goldens/kit/kit_board_lane_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Shared suites (kit ratchet, design standard, l10n coverage, kit manifest, golden harness G23) were not run: owner decision 2026-09-27.
- Wide-window behaviour that has no test:
  - the strip tap that scrolls a lane into view;
  - `selected` following the lane nearest the start edge after a scroll;
  - Shift+wheel scrolling.
- The fine-pointer scrollbar was not rendered: the tests have no mouse.
- No Arabic copy (owner decision 2026-09-27: app_en.arb only).

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitBoardLane-v2` |
| Enabled | No: no screen uses it yet (the board's wave-2 unit) | |
| Verified | Own tests and gallery only | §4 |
| Committed | Yes (local) | `revamp/kit-KitBoardLane-v2` |
| Deployed / released | No | |
