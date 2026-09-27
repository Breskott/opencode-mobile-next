# KitScreen v2 — frozen API (wave 0, 2026-09-26)

Group: screen. Unit `kit-KitScreen-v2` (wave 1, tier 1d; cut review C06 merges kit-KitScaffold into it). Write set: `lib/ui/kit/kit_screen.dart`, `lib/ui/kit/kit_layout.dart` (C23), `test/kit/kit_screen_test.dart`. Spec: kit-v2.md §2.12, §2.3 (KitStatusLineSlot), §2.7 (one primary), §8.1, §8.2 (KitScreen row), §9.2 (KitScaffold); design-standard §1, §4, §5; VL §4 (gutter), §5 (PC panes 296 · 700 · 340); STANDARDS KIT-35, KIT-36, KIT-43, LAY-2 to LAY-6, LAY-12, STATE-4, STATE-14, R23 (FloatingActionButton → bottom primary), Appendix A #43, #83.

## Purpose

The one screen frame. A page (a route) is `KitScreen(topBar: …)`: the ground, the top bar, the one status line, a pinned search, the one loading bar, the body, a pinned bottom primary lifted above the keyboard, and the bottom inset that floating parts use. A body inside the shell is `KitScreen` without a top bar. From expanded it can show two panes (list 296 · detail up to 700) and on large three (… · changes 340), with selection filling the detail instead of pushing a route.

## Replaces

- `KitScreen` v1 (`lib/ui/kit/kit_screen.dart`, 59 lines: `body`, `header`, `loading`, `loadingLabel`, `bottom`; 18 call sites) — kept source-compatible (R11, KIT-43).
- K2 §9.2 `KitScaffold` ("KitScreen with KitTopBar"): **no separate class**. `KitScreen(topBar:)` is the scaffold; `lib/ui/kit/kit_scaffold.dart` is not created, and R13 forbids any other unit from creating a `KitScaffold`.
- G16 (`test/kit_ratchet_baseline.json`): `Scaffold` 98 in 80 files, `AppBar` 95 in 77 files (with KitTopBar), `FloatingActionButton` 3 (`managed_workspaces_screen.dart`, `terminal_screen.dart`, `worktrees_screen.dart` → the `bottom` primary, R23), `PreferredSize` 5 (with KitTopBar). Top offenders: `termux_setup_screen.dart`, `terminal_screen.dart`, `external_agents_screen.dart` (4 Scaffold + 4 AppBar each).
- The hand-stacked banners and status rows above screen bodies (the "at most one status line" rule becomes the slot, K2 §2.3).
- `KitLayout.paneListWidth` 360 → 296 (LAY-5), and the missing twoPane that `build_units.py` marked P9.2 done without (cut review W3-29, C37).

## File

- `lib/ui/kit/kit_screen.dart` (v2: `KitScreen`, `KitScreenWidth`).
- `lib/ui/kit/kit_status_slot.dart` (new: `KitStatusScope`, `KitStatusLineSlot`, `KitStatusContribution`). Owner: kit-KitStatusLine-v2 (tier 1b), not this unit (README.md, decision D5), because kit-KitRowParts-v2 (tier 1d) contributes its risky-switch condition through `KitStatusContribution` and this unit is in the same tier. The API is frozen here; this unit only hosts the slot.
- `lib/ui/kit/kit_layout.dart` (in the write set for its own edits; the new names below are added before wave 1).
- `KitStatus`/`KitStatusKind`/`KitStatus.highest`/`KitStatusLine.of` live in `lib/ui/kit/kit_status_line.dart` (kit-KitStatusLine-v2).

## Public API

```dart
/// How wide a single-pane body may grow on medium and wider windows.
enum KitScreenWidth {
  /// Today's behaviour: the whole width (the default, KIT-43).
  full,

  /// Forms, settings, a page of prose: centred at KitLayout.readingWidth (720).
  reading,

  /// A list on its own: centred at KitLayout.listWidth (960).
  list,
}

class KitScreen extends StatelessWidget {
  /// v1 parameters unchanged; every v2 parameter is optional.
  const KitScreen({
    super.key,
    required this.body,               // the single scroll view
    this.header = const [],           // fixed rows above the loading bar (v1)
    this.loading = false,
    this.loadingLabel = '',
    this.bottom,                      // the pinned primary block (a KitActionBlock), v1
    // v2
    this.topBar,                      // a page: builds the frame (ground, bar, safe area)
    this.search,                      // pinned under the bar and the status line
    this.status,                      // this screen's condition, into the one slot
    this.jump,                        // a KitJumpPill floating over body, above bottom
    this.width = KitScreenWidth.full,
    this.bottomKey,                   // default ValueKey('kit-screen-bottom'), as v1
    this.page = false,                // a page with no bar: the frame without a KitTopBar (slice-R14)
  }) : detail = null,
       emptyDetail = null,
       side = null,
       listPaneKey = null,
       detailPaneKey = null,
       sidePaneKey = null;

  /// From expanded: [list] at KitLayout.paneListWidth (296) and [detail]
  /// in the rest, its content capped at KitLayout.paneDetailMaxWidth (700).
  /// Below expanded (or a short window): [list] only; opening a row pushes
  /// the detail as a page (see [openDetail]).
  const KitScreen.twoPane({
    super.key,
    required Widget list,
    required this.detail,             // the selected item's view; null → emptyDetail
    required Widget this.emptyDetail, // a KitStateView (page size): "Pick a conversation"
    this.topBar,                      // the list pane's bar
    this.search,                      // the list pane's search
    this.status,
    this.loading = false,             // the list's loading bar
    this.loadingLabel = '',
    this.bottom,                      // the list pane's pinned primary
    this.listPaneKey,
    this.detailPaneKey,
  }) : body = list,
       header = const [],
       jump = null,
       width = KitScreenWidth.full,
       bottomKey = null,
       side = null,
       sidePaneKey = null;

  /// twoPane plus, on large only, [side] at KitLayout.paneSideWidth (340)
  /// at the end (the changes pane). Below large, [side] is not shown; the
  /// screen offers it through a top bar action that opens it with
  /// showKitSheet(height: KitSheetHeight.full) (an end-side sheet from
  /// expanded, a bottom sheet below).
  const KitScreen.threePane({
    super.key,
    required Widget list,
    required this.detail,
    required Widget this.emptyDetail,
    required Widget this.side,
    this.topBar,
    this.search,
    this.status,
    this.loading = false,
    this.loadingLabel = '',
    this.bottom,
    this.listPaneKey,
    this.detailPaneKey,
    this.sidePaneKey,
  }) : body = list,
       header = const [],
       jump = null,
       width = KitScreenWidth.full,
       bottomKey = null;

  final Widget body;                  // for the pane constructors: the list
  final Widget? detail;
  final Widget? emptyDetail;          // non-null for the pane constructors
  final Widget? side;
  final List<Widget> header;
  final bool loading;
  final String loadingLabel;
  final Widget? bottom;
  final KitTopBar? topBar;
  final KitSearchField? search;
  final KitStatus? status;               // passed as an object, never words (ARCH-8)
  final KitJumpPill? jump;
  final KitScreenWidth width;
  final Key? bottomKey;
  final Key? listPaneKey;
  final Key? detailPaneKey;
  final Key? sidePaneKey;

  /// Space after the last row when nothing is pinned below the list (v1
  /// signature). Now: KitTokens.space4 + KitBottomInset.of(context).bottom.
  static double endPadding(BuildContext context);

  /// The body scroll view's padding: the gutter (16) on each side on
  /// compact, and endPadding at the bottom. Screens pass it to their scroll
  /// view instead of padding by hand (LAY-6).
  static EdgeInsetsDirectional padding(BuildContext context);

  /// True when this window shows the detail beside the list (expanded or
  /// large, not short).
  static bool showsDetail(BuildContext context);

  /// True when this window shows threePane's side pane (large, not short).
  static bool showsSide(BuildContext context);

  /// Opens a row's detail the adaptive way: where [showsDetail], calls
  /// [select] (the caller stores the selection and rebuilds with `detail`)
  /// and returns null; otherwise pushes [page] with pushKitPage and returns
  /// its result.
  static Future<T?> openDetail<T>(
    BuildContext context, {
    required VoidCallback select,
    required WidgetBuilder page,
    RouteSettings? settings,
  });
}
```

`kit_layout.dart` additions (LAY-2). The coordinator adds them in the §0.5 step 2 commit (`_new-tokens.md`), because kit-KitUndo (1a), kit-KitNav (1c) and the chat parts read them before this tier; this unit only uses them:

```dart
static const double paneListWidth = 296;        // was 360 (LAY-5, Appendix A #43)
static const double paneDetailMaxWidth = 700;   // new
static const double paneSideWidth = 340;        // new
static const double railWidth = 80;             // new (KitNav)
static const double undoMaxWidth = 480;         // new (KitUndo)
// No dialogWidth: KitDialog reads the existing confirmDialogWidth (480).
```

### The status slot (`kit_status_slot.dart`; KitStatus comes from KitStatusLine v2)

The KitStatusLine freeze (`KitStatusLine.md`) owns `KitStatus`, `KitStatusKind` (connection, appStopped, heat, riskySwitch, work, update, info — highest first), `KitStatus.highest` and `KitStatusLine.of`, and hands the slot to this unit. The slot and its plumbing are frozen here:

```dart
/// App-wide conditions (connection, Android stopped the app, heat, update
/// ready), provided once above the Navigator by main.dart (coord-main).
class KitStatusScope extends InheritedWidget {
  const KitStatusScope({
    super.key,
    required this.conditions,
    required super.child,
  });

  final ValueListenable<List<KitStatus>> conditions;

  /// Empty when no scope is above (tests, galleries).
  static ValueListenable<List<KitStatus>> of(BuildContext context);
}

/// Draws the one line: KitStatus.highest over the app-wide conditions, this
/// slot's own [status] and every status contributed from below (ties keep
/// the first: app-wide, then own, then contributions in registration order),
/// rendered with KitStatusLine.of. Nothing to show → nothing drawn. The line
/// folds in and out through KitReveal (it stays mounted with no child).
class KitStatusLineSlot extends StatefulWidget {
  const KitStatusLineSlot({super.key, this.status, this.slotKey});

  final KitStatus? status;
  final Key? slotKey;

  /// True when a slot is above [context] (a KitScreen then contributes
  /// instead of drawing).
  static bool existsAbove(BuildContext context);
}

/// Contributes [status] (null = nothing) to the nearest KitStatusLineSlot
/// above, for as long as it is mounted and its TickerMode is enabled (an
/// offstage tab stops contributing). Used by KitScreen; public for parts
/// that are not screens (a composer's risky-switch line).
class KitStatusContribution extends StatefulWidget {
  const KitStatusContribution({
    super.key,
    required this.status,
    required this.child,
  });

  final KitStatus? status;
  final Widget child;
}
```

### Behaviour (frozen)

1. **Frame.** With `topBar`, KitScreen is a page: `ground` background, the bar in the top safe area, the body resizing above the keyboard. Without `topBar`, it is a body inside a host (a tab, a pane) and builds no frame. `page: true` builds the same frame with no bar: the PC shell's content pane, where the sidebar beside it already names the destination (slice-R14), so the pane starts with its own header instead of repeating the sidebar's highlighted name. A `KitScreen(topBar:)` inside another KitScreen's body asserts (one bar per window area, KIT-36), except inside a twoPane/threePane `detail` or `side`, which are panes.
2. **Order, top to bottom:** top bar → status slot → search → `header` rows → the one loading bar (`KitLoadingBar`, STATE-4) → body (with `jump` floating over it) → `bottom`.
3. **One status line per window (KIT-35, STATE-14, Appendix A #83).** A KitScreen owns a `KitStatusLineSlot` only when no slot is above it (the shell's screen; a pushed page); it then shows the highest of the app-wide conditions, its own `status` and its descendants' contributions. A KitScreen with a slot above it (a tab body, a pane) forwards its `status` through `KitStatusContribution` and draws none.
4. **Bottom block and keyboard.** `bottom` sits `space2` above max(published inset from ancestors, the keyboard): with `viewInsets.bottom` 300 its bottom edge is 308 dp above the window bottom. KitScreen then publishes `KitBottomInset.add(extraBottom: <measured bottom block height>)` to its body, so `KitUndo` and `jump` float above the primary.
5. **Width.** On medium and wider, `KitScreenWidth.reading`/`list` centre the body, search, header and bottom at 720/960; `full` keeps today's full width. On compact every width is full with the 16 dp gutter from `padding(context)`.
6. **Panes.** twoPane from expanded (not short): list pane 296 on the start side, a 1 physical px `hairline` between panes, the detail pane centred at ≤ 700; `detail == null` shows `emptyDetail`. threePane on large adds `side` (340) at the end. Inside a `KitNav` whose sidebar hosts this destination's pane (`KitNav.hostsPane`), the list pane is left out and the detail fills the content. Detail and side panes are wrapped in a pane scope so a `KitTopBar(exit: auto)` inside them shows no Back.
7. **Search on the rails.** The pinned `search` sits on the 16 dp gutter (`KitTokens.gutter`) on both sides, like the rows below it (KitSearchField.md "Where it sits").
8. **Snack bars (transition).** A page (`topBar` set, or `page: true`) with no `Scaffold` above it hosts a transparent one, so screens that still call `ScaffoldMessenger.showSnackBar` until they move to `KitUndo` show their snack bar. It floats above the `KitBottomInset` clearance (dock, pinned primary, gesture inset, keyboard); the page's own `MediaQuery` is unchanged.
9. **One of each (debug only, G37).** After each frame in debug builds, KitScreen walks its subtree (skipping offstage and `TickerMode`-disabled parts, and nested panes, which check themselves) and asserts: at most one visible primary `KitButton`; at most one drawn `KitStatusLine`; at most one `KitRefresh`; at most one `KitDetailsFold`, and it is the last content. (LAY-12, K2 §2.7.)

## States

Declared (KIT-12): default, loading (the one bar under the header), status (a line in the slot), search (pinned field), keyboard (bottom lifted), twoPane empty detail, twoPane selected, threePane (large). Empty and error are the body's `KitStateView` (STATE-1), not KitScreen's. No disabled.

## Tokens

- ThemeRoles: `ground` (frame and panes), `hairline` (pane separators).
- KitText: none directly (its slots bring their own).
- KitTokens: `gutter` (16), `space2` (8), `space4` (16), `hairlineWidth(context)` (§0.5 step 2 seam, `_new-tokens.md`).
- KitLayout: `readingWidth` 720, `listWidth` 960, `shortHeight` 480, `paneListWidth` 296 (**changed**), `paneDetailMaxWidth` 700, `paneSideWidth` 340 (pre-wave, §0.5 step 2 named widths, `_new-tokens.md`).
- No motion token of its own.

## Adaptive

(K2 §8.2 row KitScreen; LAY-4, LAY-5; Appendix A #43.)

- compact: full width, 16 dp gutter via `padding(context)`; panes collapse to the list; `openDetail` pushes a page.
- medium: single pane centred at `reading`/`list` (when chosen); panes still collapse to the list.
- expanded: twoPane shows list 296 + detail (≤ 700, centred in the rest); threePane shows two panes and offers `side` as an end-side sheet.
- large: threePane shows list 296 · detail ≤ 700 · side 340. Between 1200 and 1336 dp the detail takes the rest (under 700).
- Short windows (< 480 dp tall, e.g. 915×412): compact behaviour for panes (LAY-3).
- Fine pointer: nothing extra (its slots handle hover). Keyboard: Tab order follows the visual order above; in panes, list → detail → side.

## Accessibility

- Semantics traversal: bar, status line, search, header, loading bar, body, bottom; panes in list → detail → side order (A11Y-4).
- The drawn `KitStatusLine` is the one live region: the slot announces a condition once when it becomes the shown one (keyed by `KitStatus.id`); a lower-priority one arriving under a higher one is not announced until it shows; re-renders of the same `id` are not re-announced.
- Each pane is a semantics container; selecting a row in the list does not move focus into the detail on PC, and the detail's title (its `KitTopBar`, header) is the next stop in traversal.
- 200 % text: the bottom block may grow; the body keeps at least `KitLayout.shortHeight`-free space by scrolling; nothing pinned covers the last row (endPadding includes the bottom block).

## RTL

Panes are laid out in reading order: list at the start (right in Arabic), side at the end. All insets directional (`EdgeInsetsDirectional`, G7).

## Motion and haptics

- None of its own: the status line unfolds through `KitReveal` (KitStatusLine v2), the loading bar and jump pill animate themselves, pane changes swap at once (no layout animation, MOT-5), and a pushed detail uses `KitPageRoute`.
- Reduced motion: nothing to add; one `pump()` settles.
- Haptics: none.

## Data safety and honest state

- Switching a twoPane selection never discards a detail's draft without that detail's own `KitDraft`/dirty rules (the detail is a normal widget; the caller keys it by item).
- The slot never shows two conditions or a contradiction; the highest-priority condition wins (connection > app stopped > heat > risk > screen > update).
- `endPadding`/`padding` guarantee the last row scrolls clear of the dock, the primary and the keyboard (DS §1, LAY-6).

## Depends on

kit-KitTopBar, kit-KitSearchField, kit-KitStatusLine-v2 (`KitStatus`, `KitStatus.highest`, `KitStatusLine.of`, and `kit_status_slot.dart`), kit-KitUndo (KitBottomInset), kit-KitJumpPill (C25), plus three edges added (README.md) that keep tier 1d: kit-KitPageRoute (`openDetail`, tier 1a), kit-KitNav (`hostsPane`, tier 1c), kit-KitDetailsFold (the debug "last fold" check, tier 1b). Existing: `KitLoadingBar`, `KitButton`, `KitRefresh`, `KitLayout`, VL `KitTokens`/`ThemeRoles`.

## Tests required

`test/kit/kit_screen_test.dart` (G9, G37, G6, G15):

1. v1 compatibility: `KitScreen(body:, header:, loading:, loadingLabel:, bottom:)` builds as before; the bottom block keeps `ValueKey('kit-screen-bottom')`.
2. Order: bar above status line above search above header above loading bar above body above bottom (by rect).
3. Slot: a pushed page shows its own `status`; with a `KitStatusKind.connection` status in `KitStatusScope`, the connection line shows instead; with both gone, nothing is drawn; order follows `KitStatusKind` (connection > appStopped > heat > riskySwitch > work > update > info).
4. Contribution: a tab `KitScreen(status:)` inside the shell's KitScreen draws no line; the shell's slot shows it; two contributions → only the higher one visible; exactly one `KitStatusLine` in the tree; an offstage tab (TickerMode off) stops contributing.
4a. Announcement: a new shown condition is announced once; the same `id` re-rendered is not re-announced.
5. Keyboard: `viewInsets.bottom` 300 → bottom block's bottom edge at window height − 308.
6. Inset: `KitBottomInset.of` inside body = ancestor bottom + measured bottom block; `endPadding` = 16 + that.
7. Width: at 1280×800 `reading` centres the body at 720, `list` at 960, default `full` is full width; at 412 all are full width with 16 dp gutters from `padding`.
8. twoPane at 412: list only; `openDetail` pushes a `KitPageRoute` and returns its result. At 1280×800: list pane 296 wide, detail ≤ 700, `openDetail` calls `select` and pushes nothing; `detail: null` shows `emptyDetail`. At 915×412: list only.
9. threePane: side visible at 1600×1000 (340 wide), absent at 1280×800; `showsSide` agrees.
10. Inside a `KitNav` whose sidebar hosts the pane: the list pane is not built; the detail fills the content.
11. A `KitTopBar(exit: auto)` in a detail pane shows no Back.
12. Debug asserts (G37): two visible primaries → `AssertionError`; two drawn status lines → `AssertionError`; a `KitScreen(topBar:)` nested in a body (not a pane) → `AssertionError`; a primary inside an offstage tab does not count.
13. RTL: list pane on the right at 1280×800.
14. Overflow: loaded default at 320, 360, 412, 600, 800, 840, 1280, 1600 and 915×412, text 1.0/1.3/2.0, LTR/RTL: no exception (G6).
15. G15: `kit_screen.dart` compares no width to a literal (only `kit_layout.dart` does).

## Galleries required

`test/goldens/kit/kit_screen_golden_test.dart`, DPR 3, Android (TEST-9, TEST-20):

- States at 412×915, dark and light: `kit_screen_default` (top bar, body of rows, bottom primary), `kit_screen_loading`, `kit_screen_status` (a connection line), `kit_screen_search`, `kit_screen_keyboard` (viewInsets 300, primary lifted).
- Pane states at their meaningful size, dark and light: `kit_screen_two_pane_empty_1280x800`, `kit_screen_two_pane_selected_1280x800`, `kit_screen_three_pane_1600x1000`.
- Default at 360×800, 915×412, 800×1280 (`reading` centred), 1280×800 and 1600×1000, dark and light.
- Default at text 2.0 and Arabic RTL at 412×915 and 1280×800 (the Arabic 1280 render uses twoPane selected, list on the right).
- G5/G6 for the rest.

## Non-goals

- The shell's own composition (home_screen: screen-shell-1) and which pages use panes (screen-work-1 Work, screen-shell-1 Inbox, screen-settings-1 Settings: cut review C37).
- Content scrolling beneath the top bar or the PC toolbar; collapsing large titles.
- Pull-to-refresh (`KitRefresh`, used inside the body), sheets, dialogs.
- Draggable pane widths or remembering them.
- A `KitScaffold` class (see Replaces).

## Open questions

None. `lib/ui/kit/kit_status_slot.dart` (scope, slot, contribution; about 150 lines, depending only on `KitStatus`) belongs to kit-KitStatusLine-v2 (README.md, decision D5; a build_units write-set change). `lib/ui/kit/kit_scaffold.dart` is not created (see Replaces), so it leaves this unit's write set (README.md).
