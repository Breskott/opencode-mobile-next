# KitSwipeAction: API freeze (wave 0, 2026-09-26)

Unit: `kit-KitRow-v2` (wave 1, tier 1e, kit-change), which writes `lib/ui/kit/kit_row.dart` and this new file (cut review C14). Spec: kit-v2.md §2.5 (`swipe: KitSwipeAction(...)`), §4.1 (undo, confirm or neither), §4.2, §8.3; kit-v2.json `changed` KitRow ("always Undo, always mirrored in the row menu"). Rules: KIT-29, DATA-11, KIT-34, A11Y-5, LOOK-5, MOT-5, MOT-11, and Appendix A #86.

## Purpose

This is a row's one swipe. It is an accelerator for an act whose treatment is "act, then Undo", such as archiving a conversation or deleting a local saved prompt. The act is always the same as the row's menu item for it, and it always ends in `showKitUndo`. A swipe never confirms and is never the only way to do the act.

## Replaces

- **Code:**
  - `Dismissible`, 1 use: `lib/ui/screens/workspace_screen.dart:1908`, the conversation swipe;
  - `SwipeDeleteBackground` (`lib/ui/widgets/confirm_sheet.dart:47-61`, error-container red);
  - `_SwipeArchiveBackground` (`workspace_screen.dart`).

  C37: in wave 2, shared-shell-1 turns `SwipeDeleteBackground` into a forwarding wrapper over this part's background, and screen-work-1 moves the conversation swipe onto `KitRow.swipe`.
- **Behaviour it removes:** today, where archive is unavailable, `workspace_screen.dart:1914-1920` swipes into the **delete confirmation**. KIT-29 forbids a confirm-first act on a swipe (Appendix A #86). With this part, such a row has no swipe, and delete stays in the menu.
- **Map:** no element carries a swipe proposal of its own. `workspace#workspace-archive-undo` goes to KitUndo, and the swipe is its accelerator.

## File

`lib/ui/kit/kit_swipe_action.dart` (new, in kit-KitRow-v2's write set). Tests go in a `KitSwipeAction` group of `test/kit/kit_row_test.dart`, and the gallery scenes in a group of `test/goldens/kit/kit_row_golden_test.dart`: the unit's derived files (README.md convention: one test file and one gallery file per unit).

## Public API

```dart
/// A row's swipe (kit-v2.md §2.5). Only for an act whose DATA-11
/// treatment is Undo: there is no confirm variant and no destructive tint.
/// The act itself runs in [onAct]; the kit then shows the one undo
/// snackbar. KitRow adds the same act to its menu (the gesture's twin).
///
/// States: idle, revealing, acted (undo showing), failed (KIT-12).
@immutable
class KitSwipeAction {
  const KitSwipeAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onAct,
    required this.undoMessage,
    required this.onUndo,
    this.onCommit,
    this.group,
  });

  /// Unique per row in its list: becomes the Dismissible key
  /// ("session-dismiss-<id>" today; keep existing test keys, TEST-5).
  final Key id;

  /// The verb, as on the menu item: "Archive". Also the revealed word
  /// behind the row and the semantic custom action's name.
  final String label;

  /// One glyph per verb (COPY-18), e.g. AppIconography.archive.
  final IconData icon;

  /// Does the act, or, for a deferred local act, hides the item and returns
  /// (the real write happens in [onCommit]). Completes true when done; false
  /// when it failed and the caller has already shown a KitNotice where the
  /// thing is (§4.8). Throwing counts as false.
  final Future<bool> Function() onAct;

  /// The undo line, naming the thing: "Archived 'Fix login'" (KitUndo).
  final String undoMessage;

  /// Runs the inverse, or cancels a deferred commit. Same type as
  /// showKitUndo's (KitUndo.md). A failing undo is handled by KitUndo: the
  /// bar turns into its "Couldn't undo · Try again" form, never silent.
  final FutureOr<void> Function() onUndo;

  /// Deferred commits (DATA-11 b): runs when the undo window closes unused,
  /// when a new undo arrives, when the route pops, or on
  /// AppLifecycleState.paused (KitUndo runs it exactly once or never).
  /// Null: [onAct] already did the write and [onUndo] is the server's
  /// inverse call (DATA-11 a).
  final FutureOr<void> Function()? onCommit;

  /// The menu group the twin item joins (KitMenuItem.group).
  final Object? group;

  /// The row menu's twin item: same label, icon and group; selecting it
  /// runs the same onAct → showKitUndo path (one treatment from every door).
  KitMenuItem get menuItem;
}
```

- **Wiring in `KitRow`** (see KitRow.md):
  - `KitRow(swipe: KitSwipeAction(...))` wraps the row in the kit's swipe. It is end-to-start only: the reading end, mirrored in RTL.
  - It adds `swipe.menuItem` to the row's `menu`, so the long-press, right-click and semantic custom action all run the same path.
  - In debug builds it asserts that the caller did not pass its own menu item with the same label. This is new API with no existing callers, so it is a plain assert, not a strict-mode one.
- **Flow on a completed swipe:**
  1. The row snaps back: the swipe's `confirmDismiss` always resolves `false`, as today, so the list owner removes or keeps the row.
  2. `onAct()` runs.
  3. If it returns true, the kit calls `showKitUndo(context, message: undoMessage, onUndo: onUndo, onCommit: onCommit)`.
  4. If it returns false or throws, nothing more happens: the caller's `KitNotice` is the failure.
- **Internal keys (TEST-5):** `kit-swipe-background` (the revealed panel). The row's key is `id`.

## States

| State | Look / behaviour |
|---|---|
| idle | the row as usual; no hint glyph (the gesture is an accelerator; its twin is in the menu) |
| revealing | behind the row, from the end edge: a `surface3` panel with `icon` (`text1`, 22 dp) and `label` (`rowTitle`, `text1`) at the end, following the finger |
| acted | the row returns (the list owner removes it); `showKitUndo` shows the undo line (KitUndo's own states) |
| failed | the row stays; nothing is announced by the swipe; the caller's `KitNotice` on the row reports the failure (§4.8) |

There is no disabled state: a row whose act is unavailable passes no `swipe`, and there is no loading, empty or error state of the part's own (KIT-12).

## Tokens

- **ThemeRoles:** `surface3` (the revealed panel) and `text1` (its glyph and word). **Never `danger` or `dangerFill`:** a swiped act is undoable by definition, and LOOK-5 keeps red for acts that lose data or end running work. This replaces the red `SwipeDeleteBackground`.
- **KitTokens:** `space4` (16, the end padding of the revealed content), `space2` (8, glyph to word), `rowTitle` (the word).
- **KitText:** `rowTitle`.
- **KitMotion:** `standard`, `enter` and `reduced(context)`, for the snap-back and the reveal settle.
- **Not yet on the VL branch:** `KitMotion.undoWindow` (read by KitUndo, not here; STANDARDS §0.5 step 2).
- **New tokens:** none.

## Adaptive

| Window | Behaviour |
|---|---|
| compact | touch swipe, end to start |
| medium | the same |
| expanded / large | The same, when touch is used. With a mouse, there is no swipe affordance to discover, and the act is reached through right-click, the row menu or the keyboard (§8.3: the gesture's twin). A trackpad horizontal drag is not bound. |

- **Keyboard:** no key does a swipe. The twin menu item is reachable with Shift+F10, the context-menu key, or the row's semantic action (LAY-10).
- **Short windows:** no change.

## Accessibility

- **The twin:** the act is exposed as a semantic custom action on the row, named `label`, through `KitRow.menu` (A11Y-5, KIT-28). TalkBack users never need the gesture. The swipe itself adds no semantics.
- **Announcements:** the undo line is announced politely by KitUndo, without taking focus (§1.17). The swipe announces nothing itself (A11Y-3: once, by the host).
- **Targets:** the swipe does not change the row's 48 dp target, and Undo is KitUndo's 48 dp action.
- **200 % text:** the revealed word wraps to two lines within the panel, and the glyph does not scale. The panel is as tall as the row.

## RTL

- "End to start" follows `Directionality`: in Arabic the row slides toward the right, and the panel is revealed at the left edge.
- The panel content is aligned to the end with `AlignmentDirectional.centerEnd` and directional padding (G7).
- The glyph mirrors only if it is directional (LAY-8). The archive and trash glyphs do not.

## Motion and haptics

- **Reveal:** follows the finger (gesture-driven, not timed).
- **Snap-back:** on `KitMotion.standard` with `enter`.
- **Removal:** the list's own change, with no size animation in the list (MOT-5).
- **Reduced motion:** the snap-back is instant, and the drag still follows the finger, because it is direct manipulation and not an animation (G8: it settles after one `pump()`).
- **Haptics:** none. MOT-11 names rows and archive-type acts as silent; `commit` is only for a *confirmed* stop, delete or discard.

## Data safety and honest state

- **Always Undo, never confirm (K2 §4.1, KIT-29):**
  - The API has no confirm hook.
  - An act that needs confirmation cannot be put on a swipe. The row passes no `swipe` for it, and the act lives in the menu with `showKitConfirm`.
  - G37's "KitRow with swipe has a matching menu item and its act's treatment is not confirm" holds by construction: the twin is generated, and the only continuation is `showKitUndo`.
- **Same from every door (DATA-11):** the menu twin runs the identical `onAct` → `showKitUndo` path, so the swipe and the menu can never diverge.
- **Server acts (DATA-11 a):** Undo is an inverse call only where the gateway exposes one (a capability flag). The caller passes `swipe` only when `onUndo` can really undo.
- **Local acts (DATA-11 b):** use `onCommit`, so nothing is pending across a kill (KitUndo commits on `paused`).
- **Honest failure:** a failed act leaves the row and says so through the caller's `KitNotice`. The undo line is never shown for an act that did not happen, and "Archived" is never shown on failure.

## Depends on

- **kit-KitUndo:** `showKitUndo`, its window, one-at-a-time and the paused commit.
- **kit-KitMenu:** `KitMenuItem` for the twin.
- **Delivered together with kit-KitRow-v2**, in the same unit, which depends on kit-KitUndo, kit-KitTappable, kit-KitDivider and kit-KitRowParts-v2 (C14, C25).

## Tests required

These go in the `KitSwipeAction` group of `test/kit/kit_row_test.dart` (G9, G37, G14x):

1. A full end-to-start swipe calls `onAct` once. When it returns true, `showKitUndo` shows `undoMessage`, and tapping Undo calls `onUndo` once.
2. When `onAct` returns false or throws, no undo line shows and the row stays.
3. A swipe never opens a confirmation: after the swipe, no `KitConfirmSheet` route is pushed, in any case.
4. The row's menu contains the twin (same label). Selecting it from long-press, right-click (desktop capabilities) or the semantic custom action runs the same `onAct` → undo path.
5. Passing both `swipe` and a menu item with the same label asserts in debug.
6. A deferred act: `onCommit` runs once when the undo window closes (fake async `KitUndo.window`, which is `KitMotion.undoWindow`), when a second swipe's undo replaces it, and on `AppLifecycleState.paused`. It never runs after Undo.
7. RTL: the swipe direction is start-to-end in screen terms (toward the right), and the panel is revealed at the left.
8. The revealed panel paints `surface3` and `text1`, never `danger` or `dangerFill`.
9. Reduced motion (G8): the snap-back settles after one `pump()`.
10. No haptic is fired (mock `HapticFeedback` and expect zero calls).
11. At text 2.0 and 320 dp, the revealed word wraps with no overflow (G6).

## Galleries required

These go in the `KitSwipeAction` group of `test/goldens/kit/kit_row_golden_test.dart` (names `kit_swipe_action_<state>…png`). The row is held mid-swipe at about 60 % by a test-only drag, rendered at DPR 3.0 (TEST-9, TEST-20):

- **Each state at 412×915, dark and light:** `revealing` and `acted` (the undo line over the list), which is 4 PNGs. `idle` is the KitRow gallery's default.
- **`revealing` at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000, dark and light:** 10 PNGs.
- **`revealing` at text 2.0 and Arabic RTL, at 412×915 and 1280×800, dark and light:** 8 PNGs.
- **Total:** 22 PNGs. Together with the KitRow gallery, kit-KitRow-v2 must stay at 60 or fewer (see KitRow.md).

## Non-goals

- No start-to-end swipe.
- No two-action swipe (leading and trailing).
- No full-swipe-to-delete with a confirmation.
- No destructive tint.
- No swipe on non-row surfaces (cards, chips).
- The screens' adoption is wave 2: screen-work-1 for the conversation list, and shared-shell-1 for the `SwipeDeleteBackground` wrapper.

## Open questions

None. The behaviour on rows whose archive is unavailable (no swipe) follows KIT-29 and Appendix A #86. The neutral colour follows LOOK-5.
