# KitBottomInset — frozen API (wave 0, 2026-09-26)

Group: screen. Built by unit `kit-KitUndo` (cut review C23: `lib/ui/kit/kit_bottom_inset.dart` is in kit-KitUndo's write set). Rulebook: `docs/ux-system/revamp/STANDARDS.md` wins over every source below it (§0.2).

## Purpose

The one published answer to "how much of the bottom (and start) of this subtree is covered by something pinned or floating": the dock, a pinned primary, the composer, the keyboard, the system gesture inset, and the navigation rail at the start. Floating parts (`KitUndo`, `KitJumpPill`) and `KitScreen.endPadding` read it, so nothing floats under the dock or the pinned button and no screen measures these by hand (K2 §1.17, §2.12; LAY-6).

## Replaces

- No map element (kit-v2.json `assignment` has none; it is the seam K2 §2.12 asks for: "It publishes the bottom padding that `showKitUndo` and `KitJumpPill` use").
- The implicit contract in `lib/ui/screens/home_screen.dart:326-330` where `Scaffold(extendBody: true)` publishes the dock height as `MediaQuery.padding.bottom`, and `KitScreen.endPadding`'s `16 + MediaQuery.paddingOf(context).bottom` (`lib/ui/kit/kit_screen.dart:33`).
- The hand-placed floating offsets of the jump pills (`lib/ui/screens/chat/message_view.dart` `_JumpToLatestButton`, `lib/ui/screens/team/run_screen.dart:1911` `_JumpPill`) and the undo snackbar in `workspace_screen.dart:1587`, which today covers the dock.
- G16/G1 counts: none directly.

## File

`lib/ui/kit/kit_bottom_inset.dart` (new; owner kit-KitUndo).

## Public API

```dart
/// What a floating part must stay clear of, in logical dp measured from the
/// window's edges (not from the subtree's box).
@immutable
class KitClearance {
  const KitClearance({this.bottom = 0, this.start = 0});

  /// From the window's bottom edge: system gesture inset, keyboard, dock,
  /// pinned primary, composer — whatever is published below this point.
  final double bottom;

  /// From the window's start edge: the navigation rail or sidebar.
  final double start;

  KitClearance copyWith({double? bottom, double? start});

  @override
  bool operator ==(Object other);
  @override
  int get hashCode;
}

/// Publishes [insets] to its subtree. Publishers are kit parts only:
/// KitNav (dock height, rail/sidebar width), KitScreen (its pinned bottom
/// block and the keyboard), and the chat composer (kit/chat, KitComposer).
class KitBottomInset extends InheritedWidget {
  const KitBottomInset({
    super.key,
    required this.insets,
    required super.child,
  });

  /// Publishes the inherited insets plus [extraBottom] (a pinned block
  /// measured by the caller) and, when given, a new [start].
  static Widget add({
    Key? key,
    required double extraBottom,
    double? start,
    required Widget child,
  });

  final KitClearance insets;

  /// The nearest published insets; registers a dependency. With no
  /// publisher above: bottom = MediaQuery.paddingOf(context).bottom +
  /// MediaQuery.viewInsetsOf(context).bottom, start = 0.
  static KitClearance of(BuildContext context);

  /// The same without registering a dependency (for a one-time read at
  /// show time, e.g. showKitUndo).
  static KitClearance read(BuildContext context);

  /// Null when nothing above publishes (tests and assertions only).
  static KitBottomInset? maybeOf(BuildContext context);
}
```

Invariants:

- A publisher's `bottom` already includes everything below it (the system inset and any ancestor's published bottom). `add` never double-counts: `extraBottom` is only what the caller pins itself.
- While a publisher is in the tree, `MediaQuery.padding.bottom` seen by its subtree equals its published `bottom` minus the keyboard (so unmigrated scroll views that honour `MediaQuery` padding keep clearing the dock, as `extendBody` does today).
- Values are rounded to whole physical pixels (VL §7).

## States

None: it draws nothing (KIT-12 does not apply; it is exempt from the gallery manifest with the reason "draws nothing").

## Tokens

None read directly. Consumers add `KitTokens.space2` (8) of clearance above `bottom` and `KitTokens.gutter` (16) beside `start`.

## Adaptive

- compact: `bottom` = system inset + dock (KitNav) + pinned block (KitScreen) or composer; keyboard replaces the dock (the dock hides while the keyboard is open).
- medium: dock gone; `start` = rail width (`KitLayout.railWidth`, a pre-wave name listed in `_new-tokens.md`) plus `space2`.
- expanded / large: `start` = sidebar width (`KitLayout.paneListWidth`, 296).
- Pointer/keyboard: no effect.

## Accessibility

No semantics. Guarantees floating parts never cover a 48 dp target of the dock, the pinned primary or the composer (LAY-9).

## RTL

`start` is directional: in RTL it is measured from the right edge. Consumers position with `PositionedDirectional`/`EdgeInsetsDirectional` only (G7, LAY-8).

## Motion and haptics

None. A change of insets (keyboard opening) is not animated by this part; consumers follow it on the next frame.

## Data safety and honest state

Not applicable (no data). Honesty: a floating part never hides the control the person is about to press.

## Depends on

Nothing (tier-1 leaf, same unit as KitUndo).

## Tests required

In `test/kit/kit_undo_test.dart`, the unit's own test file (kit-KitUndo's derived write set has no separate `kit_bottom_inset_test.dart`), in a `KitBottomInset` group:

1. With no publisher, `of` returns `MediaQuery` padding bottom + view insets bottom, start 0.
2. `KitBottomInset(insets: KitClearance(bottom: 100))` → `of` = 100 in a descendant; `add(extraBottom: 58)` below it → 158.
3. `add(start: 296)` replaces start, keeps bottom.
4. A descendant that depends through `of` rebuilds when the published value changes; `read` does not register a dependency.
5. The subtree's `MediaQuery.padding.bottom` equals the published bottom (keyboard closed).
6. Values snap to whole physical pixels at DPR 3 (e.g. 57.9 → 58.0).

## Galleries required

None (draws nothing). The G4 manifest needs an exemption entry for `kit_bottom_inset.dart` with the reason "draws nothing" (kit-gates-manifest, listed in README.md). Its effect is shown in the KitUndo, KitJumpPill, KitScreen and KitNav galleries.

## Non-goals

- A top inset (content scrolling beneath the top controls is not in this freeze; see KitTopBar non-goals).
- Measuring arbitrary widgets for callers: publishers measure their own blocks.
- Any use outside `lib/ui/kit/` other than reading it (screens never publish).

## Open questions

None.
