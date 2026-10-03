# KitScrollbar — API freeze (wave 0, 2026-09-26)

Unit: `kit-KitScrollbar` (wave 1, tier 1a, kind `kit-part`, model sonnet). **This unit is not in the cut yet:** STANDARDS §0.5 step 4 and KIT-6 tell the coordinator to add it to wave 1; README.md lists the `build_units.py` change. Proposed write set: `lib/ui/kit/kit_scrollbar.dart` (new), `lib/ui/desktop/desktop_interaction.dart` (its scroll classes become forwarders; the input seam stays), `test/kit/kit_scrollbar_test.dart`, `test/goldens/kit/kit_scrollbar_golden_test.dart`. Spec: kit-v2.md §8.3 ("Scrollbars follow desktop_interaction.dart"), §9 (kit only); STANDARDS KIT-6, KIT-44 (the allowlist removal), LAY-10, A11Y-5, MOT-5. Written in the cross-check because KitAgentStrip, KitMarkdown, KitBoardLane, KitCodeBlock, KitLogPanel, KitViewer and KitDiffView refer to it.

## Purpose

The one scrollbar: always visible and draggable on a desktop where the scrollable owns a controller, the platform's fading thumb elsewhere, never on a horizontal strip of chips or tabs, and never a second thumb over one the behaviour already draws. It moves today's working rule from `desktop_interaction.dart` into the kit unchanged, so screens stop constructing `Scrollbar`.

## Replaces

- **G16 `Scrollbar`:** 8 uses in 6 files (`review_workspace.dart` 3, `shortcuts.dart`, `chat/voice_conversation.dart`, `delimited_file_preview.dart`, `file_preview.dart`, `setup_terminal.dart`), adopted by their units in wave 2.
- **Moved from `lib/ui/desktop/desktop_interaction.dart`** (R12, KIT-43): `AppScrollBehavior`, `DesktopScrollbarArea` and `OwnScrollbar` become `KitScrollBehavior`, `KitScrollArea` and `KitOwnScrollbar`. The old names stay as forwarders marked `/// Retired by kit-KitScrollbar: use Kit…` (no `@Deprecated`), with G2 patterns; their 15 importers (among them `main.dart`, `files_screen.dart`, `workspace_screen.dart`, `settings_screen.dart`) keep compiling. `desktopInteractions`, `shortcutModifierLabel`, `DesktopSelectionArea` and `ClickCursor` stay in `desktop_interaction.dart` (the input seam; KitText.md and KitTappable.md retire the last two).
- **Ratchet:** the G16 exception that allows `Scrollbar` in `desktop_interaction.dart` (`test/kit_ratchet_test.dart:82`, `:196`) is removed in this unit's commit (KIT-6), with `ratchet-tighten: G16 Scrollbar` in the commit body (KIT-44).

## File

- `lib/ui/kit/kit_scrollbar.dart` (new): `KitScrollbar`, `KitScrollBehavior`, `KitScrollArea`, `KitOwnScrollbar`.
- Tests: `test/kit/kit_scrollbar_test.dart`. Gallery: `test/goldens/kit/kit_scrollbar_golden_test.dart`.

## Public API

```dart
/// App-wide scroll behaviour (moved from AppScrollBehavior, unchanged rule):
/// on a desktop, a vertical scrollable that owns a controller gets an
/// always-visible, draggable thumb; everything else keeps the platform's
/// fading one; horizontal strips get none. The mouse is not a drag device
/// (drag selects text).
class KitScrollBehavior extends MaterialScrollBehavior {
  const KitScrollBehavior();
}

/// Gives a long scrollable its controller on a desktop, so the behaviour
/// can pin a draggable thumb (moved from DesktopScrollbarArea). [builder]
/// gets null off desktop, so touch scrolling is unchanged.
class KitScrollArea extends StatefulWidget {
  const KitScrollArea({super.key, required this.builder}); // Widget Function(ScrollController? controller)
}

/// An explicit scrollbar for a box that scrolls inside a page (a code
/// block's sideways scroller, a table): visible and draggable on a fine
/// pointer, the platform's thumb on touch. Wraps its child in
/// KitOwnScrollbar so the behaviour does not add a second thumb.
class KitScrollbar extends StatelessWidget {
  const KitScrollbar({
    super.key,
    required this.controller,     // ScrollController: the box's own
    required this.child,
    this.axis = Axis.vertical,    // horizontal: the sideways scroller of a code block, log or table
  });
}

/// Stops KitScrollBehavior adding a second thumb inside a subtree that
/// builds its own KitScrollbar (moved from OwnScrollbar).
class KitOwnScrollbar extends StatelessWidget {
  const KitOwnScrollbar({super.key, required this.child});
}
```

## States

Idle (fading or pinned by the rule above), dragged, hovered (fine pointer). No data states. KIT-12 doc comment: "States: idle, hovered, dragged (decorative control; not a data part)".

## Tokens

- **ThemeRoles:** the thumb in `text3`, the track none; the scrollbar theme in `app_theme.dart` (the one place theme data lives, C21 g) reads the same role.
- **KitTokens:** `space1` (4, the thumb's thickness at rest), `space2` (8, on hover or drag), `minTarget` (48, the draggable hit width on a fine pointer). No new tokens.

## Adaptive

- **compact / medium (touch):** the platform's fading thumb; nothing pinned.
- **expanded / large, fine pointer (`KitLayout.finePointer` or `desktopInteractions`):** a pinned, draggable thumb on vertical scrollables that own a controller, and on every box wrapped in `KitScrollbar` (either axis).
- **Keyboard:** the scrollbar is not a Tab stop; the scrollable takes the arrow and page keys (LAY-10).

## Accessibility

The scrollable, not the thumb, carries the scroll semantics and actions (A11Y-5: the thumb is the pointer twin of those actions). Nothing is announced. The thumb does not scale with text.

## RTL

A vertical thumb sits at the end edge (the left in Arabic); a horizontal thumb follows the box's own direction (LTR for code, logs and diffs).

## Motion and haptics

The platform's fade on touch; no animation on the pinned thumb (MOT-5). Reduced motion: nothing to reduce. No haptics.

## Data safety and honest state

Not applicable (no data). Honesty: a box that scrolls always shows that it can on a fine pointer.

## Depends on

Nothing in wave 1 (tier 1a). Existing: `desktopInteractions` (the input seam), `KitLayout.finePointer`, `ThemeRoles`, `KitTokens`.

## Tests required

In `test/kit/kit_scrollbar_test.dart`:

1. With desktop capabilities, a vertical `ListView` inside `KitScrollArea` shows a pinned thumb that can be dragged; without desktop capabilities the builder gets null and no thumb is pinned.
2. A horizontal list gets no pinned thumb from the behaviour.
3. `KitScrollbar(axis: horizontal)` around a sideways scroller shows one thumb, and `KitOwnScrollbar` prevents a second (count the `RawScrollbar`s).
4. The forwarders `AppScrollBehavior`, `DesktopScrollbarArea` and `OwnScrollbar` build the same trees as the kit classes.
5. The ratchet: `test/kit_ratchet_test.dart` no longer allows `Scrollbar` outside the kit; a new `Scrollbar(` in a file with no baseline entry fails.
6. RTL: the vertical thumb is at the left under Arabic.
7. Reduced motion (G8): nothing ticks after one `pump()`.

## Galleries required

`test/goldens/kit/kit_scrollbar_golden_test.dart`, DPR 3, Android: a long list with a pinned thumb (desktop capabilities) and a code-like sideways box with its horizontal thumb, dark and light at 1280×800 and 1600×1000; the touch look at 412×915; Arabic at 1280×800. About 10 PNGs.

## Non-goals

- New scroll physics, overscroll or pull-to-refresh (`KitRefresh`).
- Scroll-to-top buttons (KitJumpPill).
- Migrating the six `Scrollbar` call sites (wave 2).

## Open questions

None for the API. Adding the unit to the cut is a coordinator action (README.md).
