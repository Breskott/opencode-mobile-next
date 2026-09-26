# KitBoardLane — API freeze (wave 0)

Unit: `kit-KitBoardLane` (wave 1, tier 1d, kind `kit-part`, model sonnet), after kit-KitTaskCard and kit-KitTabSwitcher-v2 (C25). Spec: kit-v2.md §5 (team board: "paged lanes") and §9.2 (Surfaces), with cut review C36 (`team_board_screen.dart` → kit-KitBoardLane as the file→part edge for its wave-2 unit). Board design: `docs/design/team-board-2026-09-26.md` §2 (TB: "A board of five columns, paged one at a time with the next one peeking, under a strip of column tabs with counts"). Programme: P9.9 (non-goal: no new behaviour in the board). Rules: KIT-1, KIT-12, LAY-1, LAY-2, LAY-8, LAY-10, STATE-4, STATE-18, A11Y-4, A11Y-5, LOOK-14, MOT-1, MOT-5, MOT-7.

## Purpose

The board's columns:

- a strip of column tabs with counts over lanes of task cards;
- on a phone, one lane at a time with the next one peeking, swiped or chosen from the strip;
- on a tablet or PC, as many lanes side by side as fit.

Each lane scrolls its own cards and says so when it has none.

## Replaces

- **Map element, 1 on 1 page:** `team-board#team-board-pages` (kit-v2.json `assignment` → `module:team board`; `kitGap` `KitPagedColumns`; note "PageView of lanes, next one peeking").
- **Code the board's wave-2 unit replaces with this part** (`lib/ui/screens/team/team_board_screen.dart`, not in this unit's write set):
  - the `PageView.builder` with its peeking `viewportFraction` built from the width literals `(width − 40) / width` and `400 / width` (`:201-215`; G15 `width-literal` 1);
  - the private `_Lane` (`DecoratedBox` + `ClipRRect`, `surfaceContainerLowest`/`surfaceContainer`, radius `radiusCard + 4`; `:666-688`);
  - the stale `Opacity(.6)` over every card (`:541-546`; LOOK-14: no opacity on text);
  - the per-column `KitRefresh` + `ListView` + `KitAnimatedRows` + inline empty `KitStateView` (`:579-642`);
  - the loading lane of skeleton cards (`:496-518`).
  - Of the file's G16 baseline (`AppBar` 1, `CheckedPopupMenuItem` 1, `ClipRRect` 1, `DecoratedBox` 1, `Icon` 2, `IconButton` 1, `Opacity` 1, `PageView` 1, `PopupMenuButton` 1, `Scaffold` 1, `Text` 4), this part takes `PageView`, `DecoratedBox`, `ClipRRect` and `Opacity`.
- **`TeamBoardTabs`** (`lib/ui/widgets/team_board_tabs.dart`) moves to kit-KitTabSwitcher-v2 (C24). This part composes that strip; it does not redraw it.

## File

- `lib/ui/kit/kit_board_lane.dart` (new): `KitBoardLanes`, `KitBoardLane`, `KitBoardColumn`.
- Tests: `test/kit/kit_board_lane_test.dart`.
- Gallery: `test/goldens/kit/kit_board_lane_golden_test.dart`.

## Public API

```dart
/// One column's tab in the strip.
@immutable
class KitBoardColumn {
  const KitBoardColumn({
    required this.label,        // "Working" (the host's word; COPY-13)
    this.count,                 // null while the first answer comes: no number, never "0"
    this.needsYou = 0,          // cards in it that need the person: KitNeedsYou.badge beside the count
    this.tabKey,                // e.g. ValueKey('team-board-tab-working')
  });
}

/// The board: the column strip and the lanes, kept in step.
/// States: loading, loaded, not answering (the host's), and per lane
/// empty / loaded.
class KitBoardLanes extends StatefulWidget {
  const KitBoardLanes({
    super.key,
    required this.columns,        // 2..8 (asserted)
    required this.selected,       // the column in view (compact) or scrolled to (wide)
    required this.onSelected,     // ValueChanged<int>: a swipe or a strip tap
    required this.laneBuilder,    // Widget Function(BuildContext, int): a KitBoardLane
    this.loading = false,         // the first answer: strip without counts, one KitBoardLane.loading
    this.pagesKey,                // ValueKey('team-board-pages') (kept by the host)
    this.stripKey,
  });
}

/// One column's cards: a vertical list on the lane surface.
class KitBoardLane extends StatelessWidget {
  const KitBoardLane({
    super.key,
    required this.cards,          // List<Widget>, normally KitTaskCards, each with its own key
    this.empty,                   // KitStateView (inline) shown when cards is empty; asserted non-null then
    this.onRefresh,               // Future<void> Function()? pull to refresh (KitRefresh)
    this.rowsKey,                 // restarts the arrival animation (a new filter, a new page of data)
    this.laneKey,                 // ValueKey('team-board-column-<name>')
    this.listKey,                 // ValueKey('team-board-list-<name>')
  }) : isLoading = false;

  /// Skeleton cards while the first answer comes (STATE-4).
  const KitBoardLane.loading({super.key, this.laneKey})
      : cards = const [], empty = null, onRefresh = null,
        rowsKey = null, listKey = null, isLoading = true;
}
```

Notes:

- **The lanes and the strip always agree.** `selected` drives both; a swipe that settles on a new lane calls `onSelected` once, and the host rebuilds with the new `selected`.
- **Opening column.** TB's "opens on Working, or the first column with something" is the host's choice of the first `selected`. The part never picks.
- **Stale is not dimming.** Last-known cards stay at full strength. The screen's status line says "Last updated 5 min ago" (STATE-18, LOOK-14). `KitDim` is for images and drawings only.
- **Kit copy** (ARB, `kit` prefix):
  - `kitBoardLane` "{column}, {count, plural, =0{no tasks} =1{1 task} other{{count} tasks}}" (the lane's semantic label);
  - `kitBoardLaneLoading` "Loading {column}".

  Everything else is the host's.

## States

| State | What shows |
|---|---|
| loading | the strip with labels and no counts; one `KitBoardLane.loading` (4 skeleton cards, `KitSkeletonRows`) in the selected column; nothing is swipeable yet |
| loaded | the strip with counts and needs-you badges; the lanes |
| lane empty | that lane shows its inline `empty` state (TB: "a column with nothing says so in one line") |
| lane loaded | the cards, `space2` apart, arriving and leaving with `KitAnimatedRows` |
| not answering, failed, board empty | the host's page `KitStateView`, instead of this part |

Error, disabled, working and answered are the host's or the card's. KIT-12 doc comment: "States: loading, loaded, empty (per lane)".

## Tokens

- **ThemeRoles:**
  - lane `ground`, with a 1-physical-px `hairline` outline (`KitTokens.hairlineWidth(context)`), so the peeking neighbour reads as another column (depth from surface steps: `ground` lane, `surface1` cards; LOOK-20);
  - skeleton `surface3`;
  - the strip's colours are KitTabSwitcher v2's.
- **KitText:** none of its own (cards and the strip carry the words).
- **KitTokens:**
  - `panelCornerRadius` (18, lane corners);
  - `space1` (4, the gap between paged lanes);
  - `space2` (8, lane padding and the gap between cards);
  - `space3` (12, the gap between lanes side by side);
  - `gutter` (16);
  - `labelGap` (8, strip to lanes).
- **KitLayout (new names; pre-wave seam, LAY-2; listed in `_new-tokens.md`):**
  - `KitLayout.laneMaxWidth` = 400: a lane on a phone or medium window never grows past a phone's column;
  - `KitLayout.lanePeek` = 20: how much of each neighbour shows on compact (today's `width − 40`);
  - `KitLayout.laneMinWidth` = 296: the narrowest lane side by side, equal to VL's list pane (LAY-5).

## Adaptive

| Window | Lanes |
|---|---|
| compact | one lane at a time in a `PageView`: lane width `min(width − 2 × lanePeek, laneMaxWidth)`, the neighbours peeking, swiped or chosen from the strip |
| short (< 480 dp tall) | the same, with the strip kept pinned (the lane scrolls under it) |
| medium | paged as on compact, lanes at `laneMaxWidth` (about one and a half lanes show) |
| expanded | as many lanes side by side as fit at ≥ `laneMinWidth` (3 at 1024 dp), in a horizontal list with a visible scrollbar on a fine pointer. A strip tap scrolls that lane into view (`Scrollable.ensureVisible`), and `selected` follows the lane nearest the start edge. |
| large | the same, with all five columns visible from about 1560 dp (5 × 296 + gaps); at 1600 × 1000 the whole board shows |

- **Pointer:** a horizontal wheel or Shift+wheel scrolls the lanes on wide windows. A drag with the mouse never pages; the strip does.
- **Keyboard (LAY-10):**
  - the strip's own arrow-key behaviour (KitTabSwitcher v2);
  - Tab moves from the strip into the selected lane's cards, top to bottom, then to the next lane on wide windows;
  - Ctrl+→ and Ctrl+← (reversed under RTL) move focus to the first card of the next or previous lane, paging on compact.

## Accessibility

- **Each lane** is a semantics container labelled `kitBoardLane` ("Working, 3 tasks"). Its cards are the lane's children, in order (A11Y-4).
- **The swipe has a visible twin:** the strip (A11Y-5). On compact, the `PageView` also exposes scroll-left and scroll-right semantic actions that page.
- **A lane change is not announced as a live region:** the strip's selected tab changes its selected semantics, which TalkBack reads on focus (A11Y-3: no double announcement).
- **200 % text:**
  - lanes keep their width and the cards grow taller;
  - the strip follows KitTabSwitcher v2 (it scrolls);
  - nothing overflows at 320 dp;
  - a lane never shrinks below the card's minimum, and on compact the peek shrinks first (to 0 at 320 dp).
- **Targets:** no target of its own. The cards and the strip provide 48 dp targets.

## RTL

- **Columns run from the start edge:** Backlog is at the right in Arabic and the next column peeks on the left. `PageView` and the horizontal list take their axis direction from `Directionality`.
- **Keyboard:** Ctrl+→ and Ctrl+← follow the reading direction (LAY-8).
- **The lane outline and padding** are symmetric or directional; there are no left or right literals (G7).

## Motion and haptics

- **Paging from a strip tap** uses `KitMotion.standard` with `KitMotion.emphasized` (TB); under reduced motion it jumps (`jumpToPage`). A swipe follows the finger.
- **Cards arriving and leaving** use the existing `KitAnimatedRows`, with paint only (MOT-5). `rowsKey` restarts it, so a filter change shows at once.
- **Pull to refresh** is always `KitRefresh` (MOT-4).
- **No haptics** (MOT-11).
- **No ambient motion:** the board is a resting screen (TB).
- **Reduced motion:** settles after one `pump()` (G8).

## Data safety and honest state

- **Counts are the host's, and never invented.** While the first answer comes, the strip shows no number. After it, `count` must equal the lane's card count; a debug assert in `KitBoardLanes` checks it when both are known, so the strip cannot say 3 while the lane shows 2.
- **A lane with no cards always says so** (the `empty` assert), never a blank lane.
- **The part changes nothing:** moves and refreshes are the host's, and the card shows the move's receipt.
- **Pull to refresh** runs only on the visible lane (PERF-4). Lanes off screen do not poll.

## Depends on

- **kit-KitTaskCard** (tier 1c): the cards (C25).
- **kit-KitTabSwitcher-v2** (tier 1c): `KitTabStrip`, the strip of tabs with counts and the needs-you badge, as frozen in KitTabSwitcher.md (K2 §2.10, C24, C25).
- **Existing parts:** `KitStateView` (inline empty), `KitRefresh`, `KitAnimatedRows`, `KitSkeletonRows`, `KitLayout`, `KitTokens`, `KitMotion`, `ThemeRoles`.
- **Through the strip:** kit-KitNeedsYou (the badge).

Depended on by: the board's wave-2 unit (C36: `team_board_screen.dart` → kit-KitBoardLane).

## Tests required

In `test/kit/kit_board_lane_test.dart`, using a five-column fixture of `KitTaskCard`s:

1. **Opening:** the lanes open on `selected`, and the strip shows that tab selected.
2. **Swipe:** a swipe to the next lane calls `onSelected(selected + 1)` once when the page settles.
3. **Strip:** a strip tap animates to that lane; under reduced motion it jumps (one `pump()`).
4. **Lane width:** at 412 dp the lane is 372 dp and both neighbours show 20 dp. At 700 dp the lane is 400 dp (the cap). At 1024 dp 3 lanes show side by side with no `PageView`. At 1600 dp all 5 show.
5. **Loading:** `loading: true` shows every label, no count text (no "0"), and 4 skeleton cards; swiping does nothing.
6. **Empty:** an empty lane shows its inline `empty` state. `cards: []` with `empty: null` asserts.
7. **Counts agree:** a column whose `count` differs from its lane's card count asserts in debug.
8. **Stale:** no `Opacity` or alpha is applied to any card text in any state (a painted-colour scan: text alpha is 255).
9. **Keyboard (G14):** Tab goes from the strip into the selected lane's first card. Ctrl+→ moves to the next lane's first card and pages on compact.
10. **Semantics:** each lane is a container labelled "Working, 3 tasks"; on compact the page view has scroll actions.
11. **RTL:** in Arabic the first column is at the right edge; a swipe to the right shows the next column; Ctrl+← moves forward.
12. **Refresh:** pull on the visible lane calls `onRefresh` once.
13. **Overflow and motion:** no overflow at 320, 412, 600, 840, 1280, 1600 and 915×412 at text 1.0, 1.3 and 2.0, LTR and RTL (G6); settles after one `pump()` (G8).

## Galleries required

`test/goldens/kit/kit_board_lane_golden_test.dart`, DPR 3, Android. The fixture is five columns (Backlog 2, Ready 1, Working 3 with one needing you, Review 0, Done 4), with fixed times (TEST-11).

- **Declared states × dark and light at 412×915:**
  - `loading`;
  - `loaded` (Working selected, neighbours peeking);
  - `lane_empty` (Review selected);
  - `needs_you` (the strip badge and the card);
  - `long_lane` (a column of 12, scrolled).

  That is 10 PNGs.
- **Default (`loaded`) × dark and light** at 360×800, 915×412, 800×1280 (paged), 1280×800 (4 side by side) and 1600×1000 (all 5): 10 PNGs.
- **Text 2.0 and Arabic** (`loaded`) at 412×915 and 1280×800, dark: 4 PNGs.
- **Names:** `kit_board_lane_<state>[_ar][_text2][_WxH]_<dark|light>.png`. That is 24 PNGs.

## Non-goals

- **No drag between lanes** (TB non-goal), no swimlanes, no custom columns and no filters.
- **No move sheet, no project switcher, no add button:** those belong to the board screen.
- **No change to the strip's look or behaviour:** that is KitTabSwitcher v2.
- **No edits to `team_board_screen.dart`:** that is its wave-2 unit.

## Open questions

None. The strip is `KitTabStrip({required List<KitTab> tabs, required int selected, required ValueChanged<int> onSelected})`, with `KitTab` carrying `label`, `count` and `needsYou`, exactly as KitTabSwitcher.md freezes it. `KitBoardColumn` maps one to one onto `KitTab`.
