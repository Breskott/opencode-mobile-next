# KitUndo — frozen API (wave 0, 2026-09-26)

Group: screen. Unit `kit-KitUndo` (wave 1, tier 1a leaf; C25). Spec: kit-v2.md §1.17, §4.1, §4.8, §8.2; STANDARDS KIT-11, KIT-34, DATA-11, MOT-1, MOT-11. STANDARDS wins where it differs from K2.

## Purpose

The only snackbar: "done, with Undo". One at a time, an 8 s window, never auto-dismissed under accessible navigation, floating above the dock, the composer and a pinned primary. Every other snackbar job moves to `KitIconButton.copy` (copy), `KitNotice` (a failure on one part) or `KitStatusLine` (a condition).

## Replaces

- Map: `workspace#workspace-archive-undo` (kit-v2.json `assignment`, 1 element).
- Code reach (K2 §1.17, gate G1): every `showSnackBar` that carries an undo. Today G1 counts `showSnackBar(` 127 and `SnackBar(` 127 in 68 files; G16 counts `SnackBar` 117 in 64 files, `SnackBarAction` 4 (`chat_screen.dart`, `workspace_screen.dart`, `widgets/file_preview.dart`, `widgets/markdown.dart`) and `ScaffoldMessenger` 1 (`widgets/file_preview.dart`). KitUndo is the destination only for the undo-carrying ones (the archive swipe at `workspace_screen.dart:1575-1612` is the reference call site); the rest leave through other parts, owned by the wave-2 units of their files.
- The shell's double-back "press back again to exit" snackbar (`home_screen.dart:~486`) is not an undo: it becomes a `KitStatusLine`-free transient handled by screen-shell-1, not KitUndo.

## File

`lib/ui/kit/kit_undo.dart` (new). The same unit owns `lib/ui/kit/kit_bottom_inset.dart` (see KitBottomInset.md).

## Public API

```dart
/// Shows the one Undo bar. Returns at once (the one modal-family entry point
/// that is not a Future: KIT-11, Appendix A #21).
///
/// Two ways to use it (DATA-11):
/// - act now, undo = inverse: do the act, then call with [onUndo] running
///   the inverse call (only where the gateway exposes one);
/// - deferred commit (local acts): hide the thing, pass [onCommit] to do the
///   act for real and [onUndo] to put it back. [onCommit] runs exactly once
///   unless Undo is taken.
void showKitUndo(
  BuildContext context, {
  required String message,              // names the thing: "Archived “Fix login”"
  required FutureOr<void> Function() onUndo,
  FutureOr<void> Function()? onCommit,
  void Function(Object error, VoidCallback tryAgain)? onUndoFailed,
  String? undoLabel,                    // default: kit ARB key kitUndoAction ("Undo")
  Key? key,                             // the bar
  Key? undoKey,                         // the Undo button
});

abstract final class KitUndo {
  /// How long the bar stays when nothing is pressed: KitMotion.undoWindow
  /// (8 s). Not a motion; a named kit wait (MOT-1).
  static const Duration window = KitMotion.undoWindow;

  /// Commits a pending bar now (runs its onCommit, closes it). Called by the
  /// kit on route pop and AppLifecycleState.paused; public for the app's
  /// lifecycle wiring and tests. No-op when nothing is pending.
  static void commitPending();

  /// Tests only.
  @visibleForTesting
  static bool get debugHasPending;
}
```

Behaviour (frozen):

1. **One at a time.** A new `showKitUndo` first commits the pending one (its `onCommit` runs before the new bar shows), then shows the new bar.
2. **Commit triggers** for a pending bar: the window runs out; a new `showKitUndo`; the route that owns `context` pops; `AppLifecycleState.paused` (nothing stays pending across a kill, DATA-11 b); the Dismiss button (below).
3. **Undo taken:** the bar closes, `onUndo` runs once, `onCommit` never runs.
4. **Undo fails** (`onUndo` throws or its Future errors): if `onUndoFailed` is given, it is called with the error and a `tryAgain` callback that re-runs `onUndo`; the host shows a `KitNotice` failure with "Try again" where the thing was (K2 §1.17). Without `onUndoFailed`, the bar stays in place in its failure form: the message becomes kit copy `kitUndoFailed` ("Couldn't undo. {message}"), the action becomes "Try again" (`kitTryAgain`), it does not time out, and it has Dismiss. A failure is never silent.
5. **Commit fails:** `onCommit` owns its errors (the host shows its `KitNotice`); an error escaping `onCommit` is reported through `FlutterError.reportError` (never swallowed) and the bar is already gone.
6. **Accessible navigation** (`MediaQuery.accessibleNavigationOf`): no timeout; the bar shows a Dismiss `KitIconButton` (label `kitSheetDismiss`, the existing "Dismiss" key), which commits.
7. **Keyboard (PC):** while a bar shows and no text field has focus, Ctrl+Z takes Undo. Esc does not touch it (Esc belongs to modals, LAY-10). The visible hint is `KitAction.shortcut` ("Ctrl Z", shown on a fine pointer; KitAction v2 freeze). KitAction v2 builds in the same tier (1a), so if it has not merged when kit-KitUndo builds, the unit binds Ctrl+Z without the hint and lists the hint under NOT proven; kit-hygiene adds it.
8. The bar is solid, never glass (LOOK-27, Appendix A #24).

## States

Declared (KIT-12): default (message + Undo), working (Undo tapped and an async `onUndo` in flight: the Undo action shows `working`, message unchanged, no second tap), error (failure form, item 4), and the accessible-navigation variant (default + Dismiss). No loading or empty. Disabled does not exist (an Undo that cannot run is not offered).

## Tokens

- ThemeRoles: `surface3` (bar), `hairline` (1 physical px border), `text1` (message), the action's colours come from `KitButton` tertiary.
- KitText: `body` for the message (max 2 lines, then wraps; never truncated: A11Y-8), `button` via `KitButton`.
- KitTokens: `gutter` (16, compact side margins), `space2` (8, clearance above `KitClearance.bottom`), `space3`/`space4` (inner padding), `panelCornerRadius` (18), `minTarget` (48), `hairlineWidth(context)` (§0.5 step 2 seam, `_new-tokens.md`).
- KitLayout: `undoMaxWidth` = 480 (§0.5 step 2 named layout widths, `_new-tokens.md`).
- KitMotion: `undoWindow` (§0.5 step 2 seam, `_new-tokens.md`), `standard`, `quick`, `enter`, `exit`.
- No shadow (LOOK-20: it is not floating glass).

## Adaptive

(K2 §8.2 row KitUndo.)

- compact: full width minus `gutter` on each side; its bottom edge sits `space2` above `KitBottomInset.read(context).bottom` (above the dock, the composer or the pinned primary; above the keyboard when open).
- medium: at most 480 dp, at the bottom-start, `gutter` from `KitClearance.start` (clear of the rail).
- expanded / large: 480 dp, bottom-start, clear of the rail or sidebar (`KitClearance.start`).
- Short window (< 480 dp tall): compact placement.
- Fine pointer: hover and focus ring on Undo and Dismiss come with `KitButton`/`KitIconButton`; Ctrl+Z as above. Targets stay 48 dp.
- Insets are read at show time; if the keyboard opens while the bar shows, the bar rises with it.

## Accessibility

- The bar is one polite live region: the message is announced once when it shows, without moving focus (A11Y-3). The failure form is announced once.
- Undo and Dismiss are 48 dp targets with labels; Undo's semantic label is "{undoLabel}, {message}" so it makes sense on its own.
- Never auto-dismissed under accessible navigation (item 6).
- At 200 % text the message wraps (up to the bar's height), the action moves under the message when message + action do not fit on one line (same stacking rule as `KitStatusLine`), nothing clips.

## RTL

Placed bottom-start (right in RTL) from medium up; the message is start-aligned; the action sits at the end. The quoted thing inside `message` is the host's words (use `KitBidi.auto` for a user title, §0.5 seam COPY-30).

## Motion and haptics

- In: slides up `space2` and fades in over `KitMotion.standard` on `KitMotion.enter`. Out: fades over `KitMotion.quick` on `KitMotion.exit`. No scale, no blur (MOT-2). If built on the framework's floating `SnackBar`, the kit supplies this animation instead of the framework's.
- Under `KitMotion.reduced(context)`: appears and disappears at once; settles in one `pump()` (G8x).
- Haptics: none (MOT-11: no vibration for undo, copy or failures).

## Data safety and honest state

- DATA-11: never both confirmed and undoable; the host decides the treatment; the kit guarantees `onCommit` runs exactly once or never, and never leaves a commit pending across a pause or kill.
- The message names the thing ("Archived “Fix login”"), never "Done".
- A failed undo always surfaces (item 4). A deferred commit's failure is the host's `KitNotice`.
- Nothing is announced as undone until `onUndo` completes.

## Depends on

- KitBottomInset (same unit).
- Existing kit: `KitButton`/`KitAction` (`kit_buttons.dart`), `KitIconButton` (the current `label` parameter, which KitIconButton v2 keeps as a forwarding alias of `tooltip`), `KitMotion`, `KitText` and `KitTokens` from the VL branch.
- No unit dependency (C25: leaf).

## Tests required

`test/kit/kit_undo_test.dart` (G9, G9x), fake async throughout:

1. Shows the message and Undo; no other snackbar is in the tree afterwards.
2. After `KitUndo.window` with no tap: `onCommit` ran once, bar gone.
3. Undo tap: `onUndo` once, `onCommit` never, bar gone.
4. One at a time: a second `showKitUndo` commits the first (first `onCommit` once) before the second shows; only one bar visible.
5. Route pop of the caller's route commits; `AppLifecycleState.paused` commits; `commitPending()` commits.
6. `accessibleNavigation: true`: still visible after 60 s; Dismiss commits.
7. `onUndo` throws + `onUndoFailed` given: callback receives the error; `tryAgain` re-runs `onUndo`.
8. `onUndo` throws, no `onUndoFailed`: failure words and Try again shown; no timeout; Try again re-runs.
9. Async `onUndo` in flight: Undo shows working and ignores a second tap.
10. Placement: with `KitBottomInset(bottom: 120)` the bar's bottom is ≥ 128 dp above the window bottom; at 1280×800 it is ≤ 480 wide and starts at `start + 16`; in RTL it hugs the right.
11. Semantics: one live region; message announced once; Undo is ≥ 48×48 with a label.
12. Desktop capabilities: Ctrl+Z takes Undo; not when a text field has focus.
13. Reduced motion and Effects Animations Off: one `pump()` shows it fully; no ticker left (G8x).
14. No `HapticFeedback` call and no `KitHaptics` call in any path.

## Galleries required

`test/goldens/kit/kit_undo_golden_test.dart`, DPR 3, Android platform (TEST-9, TEST-20, G23):

- Every state at 412×915, dark and light: `kit_undo_default`, `kit_undo_working`, `kit_undo_error`, `kit_undo_accessible` — each shown over a KitNav dock scene so the clearance is visible.
- Default state at 360×800, 915×412, 800×1280, 1280×800 (with a rail/sidebar at start) and 1600×1000, dark and light.
- Default at text 2.0 and in Arabic RTL at 412×915 and 1280×800 (`_text2_`, `_ar_`).
- G5 guidelines and G6 overflow (no images) for every other state × size.

## Non-goals

- Copy feedback, failure messages, updates and releases (they go to `KitIconButton.copy`, `KitNotice`, `KitStatusLine`).
- A queue of bars, stacked bars, or an Undo history.
- Undo for acts the gateway cannot reverse without a deferred commit (those are confirmed, DATA-11 a).
- Swipe-to-dismiss of the bar (it would be an unlabelled commit gesture).

## Open questions

None.
