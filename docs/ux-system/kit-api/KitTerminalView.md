# KitTerminalView — API freeze (wave 0)

Unit: `kit-KitTerminalView` (wave 1, tier 1a, kind `kit-part`, model opus; provisional per R22). Spec: kit-v2.md §5 (one-off surfaces) and §9.2 (Surfaces), with cut review C23 (`terminal_key_bar.dart` joins this unit) and C24 (`lib/ui/widgets/terminal_view.dart` joins this unit; `shared-terminal-1` is removed). Programme: P9.9 (finish line: the part exists with its galleries; non-goal: no new behaviour in the terminal). Rules: KIT-1, KIT-3, KIT-9, KIT-22, KIT-23, KIT-32, KIT-43, LOOK-1, LOOK-5, LOOK-6, LOOK-16, LAY-8, LAY-9, LAY-10, MOT-11, COPY-30, SEC-2, SEC-4, A11Y-1, A11Y-2, A11Y-8.

## Purpose

The terminal as one kit surface in two forms:

- **live:** an xterm session painted in the theme's colours, with the key bar a phone keyboard lacks. The phone's terminal and a server's terminal become the same surface.
- **output:** a finished (or streaming) command and what it printed, drawn the way a terminal does: the program picked out, flags and strings apart, ANSI colours kept, and the end of a long output shown first.

## Replaces

- **Map elements, 2 on 1 page** (kit-v2.json `assignment` → `module:special surface`, moved into the kit by K2 §9.2):
  - `terminal-surface#terminal-surface-view` (the xterm `TerminalView`, `terminal_screen.dart:1286-1319`);
  - `terminal-surface#terminal-surface-keys` (the private `_TerminalKey` strip: 8 `OutlinedButton` keys, `terminal_screen.dart:1325-1395` and `:1426-1462`). The map note asks for the kit's `TerminalKeyBar`; this part is where it lands.
- **The phone terminal's view** (`local_terminal_screen.dart:381-405`), which paints on `xterm.TerminalThemes.defaultTheme.background` while the server terminal paints on the literal `Color(0xFF0A0C0F)`. Both move to one palette from `ThemeRoles`.
- **Files in this unit's write set:**
  - `lib/ui/widgets/terminal_view.dart` (`TerminalView`, 370 lines; G16: `Container` 1, `SelectableText` 1, `SingleChildScrollView` 1, `Text` 2, `TextButton` 2) becomes a thin forwarding wrapper over `KitTerminalView.output` with its signature unchanged. `stripAnsi` forwards to `KitTerminalText.strip`. Both are marked `/// Retired by kit-KitTerminalView: use KitTerminalView.output` (KIT-43, R12). There is no `@Deprecated`: STANDARDS KIT-43 overrides R11 and R12 on this point. The file's G16 count reaches zero. Its callers stay in their own units: `message_view.dart` (chat chain), `tool_card.dart`, `setup_progress_view.dart` and `phone_server_card.dart`.
  - `lib/ui/kit/terminal_key_bar.dart` (`TerminalKeyBar`, `TerminalKeyBarController`, `TerminalBarKey`, `sendTerminalBarKey`, `terminalModifiedText`) stays where it is and stays compatible. It gains the kit look, 48 dp keys, no raw haptics and the two keys the server strip has (below).
- **G16 that wave 2 can then bring to zero** (screen-terminal-1): `terminal_screen.dart` `ColoredBox` 1, `Directionality` 1, `OutlinedButton` 1; `local_terminal_screen.dart` `ColoredBox` 1, `Directionality` 1.

## File

- `lib/ui/kit/kit_terminal_view.dart` (new): `KitTerminalView`, `KitTerminalText`.
- `lib/ui/kit/terminal_key_bar.dart` (existing, in this unit's write set).
- `lib/ui/widgets/terminal_view.dart` (becomes the forwarding wrapper).
- Tests: `test/kit/kit_terminal_view_test.dart` (new). The existing `test/terminal_key_bar_test.dart` and `test/terminal_view_test.dart` are this unit's own tests (PROC-10) and must keep passing unchanged.
- Gallery: `test/goldens/kit/kit_terminal_view_golden_test.dart`.
- `kit.dart`: one export row each for `kit_terminal_view.dart` and `terminal_key_bar.dart`. `TerminalKeyBar` is not exported today. The integrator adds the rows (R06, PROC-13).

## Public API

```dart
import 'package:xterm/xterm.dart' as xterm;

/// The terminal (kit v2 §9.2). States: live, read-only, keys latched,
/// output (tail shown, all shown, too long for inline), empty output.
class KitTerminalView extends StatelessWidget {
  /// A live session. The view fills its box. The key bar sits under it
  /// on touch and is left out with a fine pointer (a hardware keyboard).
  const KitTerminalView.live({
    super.key,
    required xterm.Terminal this.terminal,
    required String this.semanticsLabel,   // "Terminal · build-server" (the surface's name)
    this.controller,                      // xterm.TerminalController: the selection
    this.scrollController,
    this.focusNode,
    this.autofocus = true,
    this.readOnly = false,                // not connected, or the shell ended: the host says why (STATE-8)
    this.keys,                            // TerminalKeyBarController? null = no key bar; the part
                                          //   builds the bar and wires onKey to sendTerminalBarKey(terminal, …)
    this.interruptKeys = false,           // server terminals: lead the bar with Ctrl-C and Ctrl-D
    this.onKeyEvent,                      // FocusOnKeyEventCallback? hardware keys on a PC (copy/paste chords)
    this.viewKey,                         // e.g. ValueKey('local-terminal-view-1')
    this.keysKey,                         // e.g. ValueKey('local-terminal-keys')
  }) : output = null, command = null, tailLines = 0, framed = false,
       wrap = false, onOpenFull = null, showEarlierKey = null, openFullKey = null;

  /// A command and its output. UNCHANGED semantics of widgets/TerminalView:
  /// the last [tailLines] lines first, "Show {n} earlier lines" in place,
  /// and past [inlineLineCap] lines "Open all {n} lines" calls [onOpenFull].
  const KitTerminalView.output({
    super.key,
    required String this.output,
    this.command,
    this.tailLines = 40,
    this.framed = true,     // false where the host already frames it (one box, not a box in a box)
    this.wrap = true,       // false: each line stays one line and the block scrolls sideways
    this.onOpenFull,        // ValueChanged<String>? gets the full text with ANSI stripped and redacted
    this.viewKey,           // default ValueKey('terminal-view') (kept, TEST-5)
    this.showEarlierKey,    // default ValueKey('terminal-show-earlier') (kept)
    this.openFullKey,       // default ValueKey('terminal-open-full') (kept)
  }) : terminal = null, semanticsLabel = null, controller = null,
       scrollController = null, focusNode = null, autofocus = false,
       readOnly = true, keys = null, interruptKeys = false, onKeyEvent = null,
       keysKey = null;

  /// Past this many lines, the full output opens elsewhere instead of inline.
  static const inlineLineCap = 2000; // UNCHANGED (moved from TerminalView)

  /// The terminal colours for [roles]; both forms and every pack use it.
  static xterm.TerminalTheme themeOf(ThemeRoles roles);

  /// The live view's selected text ("" when nothing is selected), for a
  /// host's KitIconButton.copy / KitMenuItem.copy (KIT-23). The kit never
  /// writes the clipboard itself here.
  static String selectedText(xterm.Terminal terminal, xterm.TerminalController controller);
}

/// Terminal text as spans: pure functions, no widgets.
abstract final class KitTerminalText {
  /// ANSI escape sequences removed (the old top-level stripAnsi).
  static String strip(String text);

  /// "$ " then the program (folder dimmed), flags, strings and operators.
  static List<InlineSpan> command(String command, ThemeRoles roles);

  /// One output line: its own ANSI colours when it has them, otherwise a
  /// tint from what it says (errors, warnings, passes, test progress).
  static List<InlineSpan> line(String line, ThemeRoles roles);
}

// ── terminal_key_bar.dart (existing API kept; additions marked NEW) ──
enum TerminalBarKey {
  esc, slash, dash, pipe, home, up, end, pageUp,
  tab, ctrl, alt, tilde, left, down, right, pageDown,
  interrupt,   // NEW: Ctrl-C in one tap (the server strip has it today)
  endOfInput;  // NEW: Ctrl-D in one tap
  static const rows = [...];        // UNCHANGED two rows
  static const extraRow = [interrupt, endOfInput]; // NEW, shown only when the bar has `interruptKeys`
}

class TerminalKeyBar extends StatelessWidget {
  const TerminalKeyBar({
    super.key,
    required this.controller,
    required this.onKey,
    this.enabled = true,
    this.compact = false,       // kept; KitTerminalView.live decides it (height < KitLayout.shortHeight)
    this.interruptKeys = false, // NEW: lead the bar with Ctrl-C and Ctrl-D (server terminals)
    this.disabledReason,        // NEW: the semantic hint when !enabled ("Not connected")
  });

  static const keyHeight = 48.0;      // CHANGED from 44 (LAY-9); reads KitTokens.minTarget
  static const compactKeyWidth = 56.0; // UNCHANGED
}

/// NEW. The NAME-1 name for the bar. TerminalKeyBar stays and is marked
/// "Retired by kit-hygiene: use KitTerminalKeyBar"; kit-gates adds the G2
/// pattern (KIT-44), not this unit.
typedef KitTerminalKeyBar = TerminalKeyBar;

// UNCHANGED: TerminalKeyBarController, sendTerminalBarKey, terminalModifiedText.
```

Notes:

- **No styling parameters.** The palette, the mono face and size, padding and key look come from tokens. `framed` and `wrap` are kept because they are structure (KIT-43), not look.
- **`sendTerminalBarKey(terminal, TerminalBarKey.interrupt)`** writes `\x03` and `endOfInput` writes `\x04` through `terminal.textInput`, so a server terminal (whose `onOutput` goes to its socket) and a phone shell behave alike.
- **The existing exhaustive `switch`es on `TerminalBarKey`** are all inside `terminal_key_bar.dart` or have a default branch (checked: `_label`, `sendTerminalBarKey`), so adding two values is additive.
- **Internal keys (TEST-5):** `terminal-key-<name>` stays on each key (the new ones are `terminal-key-interrupt` and `terminal-key-endOfInput`). The output form keeps `terminal-view`, `terminal-show-earlier`, `terminal-open-full` and `terminal-view-sideways`.

## States

| State | Form | What shows |
|---|---|---|
| live | live | the session on `ground`; the key bar enabled |
| read-only | live | the last screen stays readable; input is ignored; keys are disabled with `disabledReason` as their hint. The host's status line or state view says why (not connected, ended). The part never says "Stopped" itself (COPY-17). |
| keys latched | live | Ctrl or Alt drawn as selected (toggled semantics) until the next key |
| keys compact | live | one sideways-scrolling row (modifiers and arrows first) when the window is shorter than `KitLayout.shortHeight` |
| tail | output | the last `tailLines` lines, with "Show {n} earlier lines" above them |
| all | output | every line up to `inlineLineCap` |
| too long | output | "Open all {n} lines" calls `onOpenFull`; without `onOpenFull` the part shows only the last `inlineLineCap` lines and says so ("Showing the last 2,000 lines"), with no dead button |
| empty | output | only the command line; with no command either, nothing is drawn (the host shows its own empty state) |

Loading and error are the host's (connecting, a failed socket, an exited shell use `KitStateView`/`KitStatusLine`); working and answered do not apply. KIT-12 doc comment: "States: live, read-only (disabled), empty; output: tail, all, too long".

## Tokens

- **ThemeRoles → `themeOf`:**
  - background `ground`, foreground `text1`, cursor `accent` (LOOK-6: the text cursor), selection the theme's selection colour (`AppTheme`'s `TextSelectionThemeData`, which is `accent`-based);
  - ANSI: black `surface3`, red `danger`, green `success`, yellow `codeString`, blue `codeType`, magenta `codeKeyword`, cyan `codeType`, white `text2`; bright black `text3`, bright white `text1`, bright colours the same as their normal ones;
  - a program's own 256-colour and true-colour output is shown as sent. It is the program's data, not a kit colour, so LOOK-1 does not apply to it.
- **Output form tints** (`KitTerminalText`): `$` and dimmed folders `text3`; the program `accent`; flags `codeType`; strings `codeString`; errors `text1` in semibold, never `danger` (LOOK-5, B2 interim); warnings `text2` in semibold (LOOK-4: never `attention`); passes `success`; test counts `+n` `success`, `~n` `text2`, `-n` `text1` semibold.
- **Key bar:** key face `surface3` with `text1` label; latched `accent` with `onAccent` (LOOK-6: a toggle's on mark); disabled `surface3` with `text3`. The container is `surface2`, with a 1-physical-px `hairline` on top (`KitTokens.hairlineWidth(context)`).
- **KitText:** `mono` (13/19) for the terminal face, the output block and key caps; `secondary` for "Show earlier" and "Open all" (through `KitButton` tertiary).
- **KitTokens:** `minTarget` (48, key height and width floor), `space1` (4, the gap between keys), `space2` (8, block padding), `codeRadius` (14, the framed output block), `detailsSurface` (the framed block's fill: `surface1` in dark, `ground` in light, one step off a sheet), `buttonRadius` (key corners).
- **New tokens (pre-wave, `_new-tokens.md`):**
  - `KitTokens.terminalMaxTextScale` = 2.0: the terminal face grows with the person's text size up to this. Beyond it, 40 columns no longer fit a 412 dp phone. This is a named clamp with a reason (A11Y-8).
  - `KitTokens.terminalKeyMaxTextScale` = 1.3: key caps stop growing here so "PgDn" fits a 48 dp key. The full name is in semantics (A11Y-8).
  - No new colour role. If a theme pack ever wants its own ANSI set, `ThemeRoles.ansi` would be a coordinator decision (§0.5), not this unit's.

## Adaptive

| Window | live | output |
|---|---|---|
| compact | the view fills the body; the key bar (2 rows × 48 dp) sits under it, above the keyboard, full width; one row when the window is shorter than 480 dp (landscape with the keyboard up) | full width of the host's rails; wraps by default |
| medium | the same; the key bar is capped at `KitLayout.readingWidth` and centred, so keys stay thumb-sized | the same |
| expanded / large | with a fine pointer (`KitLayout.finePointer`) the key bar is left out and the view takes hardware keys only (`hardwareKeyboardOnly`, so no keystroke arrives twice through key event and IME). A touch-only tablet keeps the bar. | the same, plus mouse text selection across lines |

- **Pointer:** the mouse selects in the live view (xterm's own selection), with a text cursor over it; keys show the hover fill (`KitTappable`-style, no ripple).
- **Keyboard (LAY-10):**
  - While the live view has focus, Tab, Esc and the arrows go to the shell, because a terminal needs them.
  - Ctrl+Tab and Ctrl+Shift+Tab move focus to the next and previous control, so the terminal is never a focus trap. The shortcuts help sheet lists both.
  - In the output form, "Show earlier" and "Open all" are Tab stops, activated with Enter or Space.
  - Each key in the bar is a focusable button with a visible 2-physical-px `accent` focus ring (`focusRingWidth`).

## Accessibility

- **Live view:** one container node labelled `semanticsLabel`. The xterm canvas is excluded, because a screen reader cannot read a character grid. The accessible transcript mode is the screen's, composed from `KitLogPanel` and `KitField` in wave 2 (see Non-goals).
- **Keys:**
  - each is a button with its spoken name (Escape key, Control, Interrupt, Control C…), not its cap;
  - Ctrl and Alt carry toggled semantics;
  - when disabled, the hint is `disabledReason` (default `e7SetupKeyUnavailable`, "Unavailable while the terminal is disconnected");
  - the bar is one container labelled `localTerminalKeysLabel`;
  - every key is at least 48 × 48 dp, with no overlap (LAY-9; today's 44 dp fails).
- **Output:** the block is selectable. "Show {n} earlier lines" is a button whose label includes the count.
- **200 % text:**
  - the terminal face grows up to `terminalMaxTextScale`;
  - key caps grow to 1.3×, and the keys keep 48 dp and do not overflow at 320 dp wide (G6);
  - the output block wraps (or scrolls sideways when `wrap: false`);
  - the output's buttons wrap to two lines.
- **Announcements:** none from this part. Connection changes are the host status line's (A11Y-3).

## RTL

- **The live view and the key bar are always LTR:** keys sit where a keyboard has them in every language (the existing rule). The bar's container label and each key's spoken name are localised.
- **The output block is an LTR region aligned left in both directions** (COPY-30, KIT-32; `KitLtr` once kit-KitText lands, `Directionality` inside the kit until then). "Show earlier" and "Open all" sit outside that region, at the start edge of the reading direction.
- **Counts** in the button labels come from `intl` (COPY-30, B17).

## Motion and haptics

- **Nothing animates.** A latched modifier changes at once. "Show earlier" expands in place with no `KitReveal`, because tens of lines in a scrolling list must not animate layout (MOT-5).
- **No haptics:** the raw `HapticFeedback.selectionClick()` on every key is removed. A key tap is a local choice (MOT-11), and the G2 `HapticFeedback.` pattern would flag it.
- **Reduced motion:** nothing to reduce; the part settles after one `pump()` (G8).

## Data safety and honest state

- **Output lines pass through `KitRedact.text`** before they are shown and before `onOpenFull` gets them, the same as KitLogPanel (SEC-2, SEC-4). A tool's printed bearer token never reaches the screen or the file viewer.
- **The live session is not redacted:** it is the person's own shell. The kit never logs or copies it by itself. `selectedText` returns only what the person selected; the host copies it through `KitCopy.copy`.
- **Read-only is honest:** input is dropped, not queued, while `readOnly`. The keys are visibly disabled with a reason, so nothing looks typed that was not sent.
- **"Too long" never hides silently:** the part says how many lines it shows. The old `TerminalView` offered a button only when `showFilePreviewSheet` was reachable. Now the host passes `onOpenFull`, because the kit may not import `widgets/file_preview.dart`. The forwarding wrapper passes `showFilePreviewSheet`, so behaviour is unchanged.

## Depends on

- **Existing kit parts:** `KitButton` (tertiary "Show earlier" and "Open all"), `KitTokens`, `KitText`, `ThemeRoles`, `KitLayout`.
- **Pre-wave seams:** `KitRedact`, `KitTokens.hairlineWidth`/`focusRingWidth`, `KitCopy` (the host's copy), `KitBidi`.
- **Package:** `xterm` (already a dependency).
- **No wave-1 dependency**, so it stays in tier 1a.

Depended on by: screen-terminal-1 (both terminals). In wave 2 it is also depended on by the units owning `tool_card.dart`, `setup_progress_view.dart` and `phone_server_card.dart`, and by the chat chain (`message_view.dart`), through the wrapper.

## Tests required

In `test/kit/kit_terminal_view_test.dart`, with `debugDefaultTargetPlatformOverride = TargetPlatform.android`:

1. **Key size:** every key of `TerminalKeyBar` (two-row, compact and `interruptKeys`) is at least 48 × 48 dp and hit-testable at 320 dp wide (LAY-9).
2. **Latch:** tap `terminal-key-ctrl`, then `apply('c')` returns `\x03`; the key reports toggled semantics while latched and releases after one key. The existing `terminal_key_bar_test.dart` passes unchanged.
3. **New keys:** `interrupt` sends `\x03` and `endOfInput` sends `\x04` to a fake `xterm.Terminal`'s `onOutput`.
4. **No haptics:** with a `SystemChannels.platform` mock, tapping any key records no `HapticFeedback.vibrate` call.
5. **Disabled:** `enabled: false` ignores taps; semantics say `enabled: false` with `disabledReason` as the hint.
6. **Application cursor mode:** with DECCKM set, ↑ sends `ESC O A` (existing behaviour kept).
7. **Live focus:** Tab typed into the live view reaches the terminal. Ctrl+Tab moves focus to the next focusable (G14, desktop `debugPlatformCapabilities`).
8. **Read-only:** `readOnly: true` drops typed text (`onOutput` not called).
9. **Palette:** `themeOf(graphiteDark)` has background `ground`, cursor `accent`, red `danger`, green `success`; `themeOf(graphiteLight)` likewise. The key bar and view paint no colour outside `ThemeRoles` (a painted-colour scan of the gallery scene).
10. **Output tail:** 50 lines with `tailLines: 40` shows "Show 10 earlier lines" (`terminal-show-earlier`). A tap shows all 50. With 2,500 lines and `onOpenFull`, "Open all 2,500 lines" calls it once with ANSI-stripped text. Without `onOpenFull`, the "Showing the last 2,000 lines" line appears and no button does.
11. **Redaction:** output containing a fake `sk-ant-api03-…` key and `Authorization: Bearer …` renders and hands to `onOpenFull` only the masked form.
12. **Tints:** a line with `error:` is `text1` semibold (not `danger`); `warning` is not `attention`; ANSI `\x1b[31m` maps to `danger`.
13. **RTL:** in Arabic the output block's text direction is LTR and left-aligned, and "Show earlier" sits at the start (right) edge.
14. **Wrapper:** `TerminalView(command:, output:, tailLines:, framed:, wrap:)` from `widgets/terminal_view.dart` renders through `KitTerminalView.output`, and `test/terminal_view_test.dart` passes unchanged.
15. **Reduced motion and overflow:** settles after one `pump()` (G8); no overflow at 320, 412 and 915×412 at text 1.0, 1.3 and 2.0, LTR and RTL (G6).

## Galleries required

`test/goldens/kit/kit_terminal_view_golden_test.dart`, DPR 3, Android, Geist and Noto Sans Arabic loaded (TEST-8). The live scenes use a fake `xterm.Terminal` fed a fixed ANSI sample (prompt, `ls --color`, a red error line, a green pass line), with no clock and no process (TEST-11).

- **Declared states × dark and light at 412×915:** `live`, `live_readonly`, `keys_latched`, `keys_compact` (412×915 with a 300 dp keyboard inset, and 915×412), `output_tail`, `output_all`, `output_too_long`. That is 7 × 2 = 14 PNGs.
- **Default (`live`) × dark and light** at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000; at 1280 and 1600 with desktop capabilities, so the key bar is absent. That is 10 PNGs.
- **Text 2.0 and Arabic** (`live` and `output_tail`) at 412×915 and 1280×800, dark: 8 PNGs.
- **Names:** `kit_terminal_view_<state>[_ar][_text2][_WxH]_<dark|light>.png`. That is 32 PNGs, under the 60 cap (TEST-20).

## Non-goals

- **No new terminal behaviour (P9.9):**
  - no font-size control, paste, rename or stop;
  - no process-exited state (the map's `statesMissing` for `terminal-surface` belongs to screen-terminal-1);
  - no reconnect logic.
- **No accessible-transcript part.** The screen composes it from `KitLogPanel` and `KitField`.
- **No edits to** `terminal_screen.dart`, `local_terminal_screen.dart` or any caller of `TerminalView`.
- **No ANSI in `KitLogPanel` or `KitCodeBlock`.** They may later call `KitTerminalText`; that is kit-hygiene's decision.

## Open questions

None that block. Two decisions are recorded for the coordinator:

- **`KitTerminalView.output` coexists with `KitCodeBlock(kind: output)` and `KitLogPanel`.** C24 moved `terminal_view.dart` here, and KitLogPanel.md excludes ANSI ("that is KitTerminalView"). Each wave-2 caller picks the part for its job: a tool's finished output with colours → `.output`; a process log → `KitLogPanel`; a copyable block → `KitCodeBlock`. kit-hygiene deletes the `TerminalView` wrapper once its count is zero.
- **"No `@Deprecated`" follows STANDARDS KIT-43, which ranks above R11 and R12.**
