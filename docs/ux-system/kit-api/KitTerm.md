# KitTerm — API freeze (wave 0)

Unit: `kit-KitTerm` (wave 1, tier 1a, kind `kit-part`). Write set (work-units.json): `lib/ui/kit/kit_term.dart` (new), `lib/ui/widgets/info_label.dart` (becomes a wrapper, C24, R12; slice-P3.1 deletes it, C40), `test/kit/kit_term_test.dart`, `test/goldens/kit/kit_term_golden_test.dart`; its `tests` list: `test/info_label_test.dart`. Spec: kit-v2.md §1.20; map proposals for embedded-info-label (remove: "Kill if not needed or show tool tip?"; replace with a kit KitTerm, a 48 dp hit area, a tooltip on tap, a sheet only for long text) and info-label-sheet (fix: no button, drag or scrim closes it, kit rails); R23 (a tooltip is reached only through KitIconButton, KitTerm or KitTappable). Rules: COPY-19, A11Y-1, A11Y-2, LAY-9, LAY-10, LAY-11, KIT-43, R11, R12.

## Purpose

A word the person may not know ("Worktree", "MCP") that explains itself in place: tap, long-press or hover shows a short explanation anchored to the word, with an optional "Learn more" into the Guide. It replaces a separate page and a 24 dp hit area.

## Replaces

- **Map elements (kit-v2.json `assignment` → `KitTerm`): 2 elements on 2 pages.**
  - embedded-info-label (embedded-info-label-term: an `InkWell` with 2 dp padding, about 24 dp tall, critical X1);
  - info-label-sheet (info-label-sheet: a sheet with a raw right-aligned `FilledButton.tonal` "Got it" and 24 dp padding).
- **Merged proposal names:** `KitTerm`.
- **Moved by this unit (C24, R12):** `lib/ui/widgets/info_label.dart` (230 lines; G16 `FilledButton` 1, `Icon` 1, `InkWell` 1, `Text` 4; G1 `showModalBottomSheet(` 1). `InfoLabel`, `InfoLabel.glossary`, `InfoLabel.show` and `Glossary` keep compiling as forwarding wrappers over `KitTerm` and `showKitTerm` (KIT-43: `/// Retired by kit-KitTerm: use KitTerm`, and a G2 ratchet pattern `InfoLabel`). `InfoLabel`'s `style` and `iconSize` are accepted and ignored (display only; the term takes the look of its KitText role). The file drops to G16 zero and G1 zero once it forwards.
- **Callers of the wrapper (unchanged by this unit):** `screens/worktrees_screen.dart:614` (`InfoLabel(`), `screens/chat/message_view.dart:2872` (`InfoLabel.glossary(`, chat chain), `screens/library/integrations_screen.dart:911` (`InfoLabel.glossary(`), `screens/mcp_setup_screen.dart:281` (`InfoLabel.show(`).
- **Code reach:** `Tooltip` has 26 uses in 10 files (G16). Under R23 only the three named parts reach a tooltip; a tooltip that explains a term becomes a `KitTerm`, and one that labels an icon becomes a `KitIconButton`.

## File

- `lib/ui/kit/kit_term.dart`: `KitTerm`, `showKitTerm`.
- `lib/ui/widgets/info_label.dart`: forwarding wrapper (`Glossary` stays there, with its ARB lookups, until slice-P3.1).
- Tests: `test/kit/kit_term_test.dart`; `test/info_label_test.dart` is this unit's own and is updated per TEST-19(1) (see Tests required).
- Gallery: `test/goldens/kit/kit_term_golden_test.dart`.

## Public API

```dart
/// A term that explains itself (K2 §1.20). A standalone widget at least
/// 48×48 dp: use it as a label, a heading word or at the end of a line,
/// never in the middle of a paragraph (a paragraph says it in words).
///
/// States: default, open (the explanation shows), hovered, focused.
class KitTerm extends StatelessWidget {
  const KitTerm(
    this.term, {
    super.key,
    required this.explanation,  // ≤ 2 short sentences (a reviewer rule; the glossary test caps English at 260 characters)
    this.learnMore,             // opens the Guide at the right place: one tertiary action
    this.role,                  // the KitText role to match the text around it; null = the ambient style
    this.termKey,
  });

  final String term;
  final String explanation;
  final KitAction? learnMore;
  final KitTextRole? role;
  final Key? termKey;
}

/// Shows [explanation] for [term] without a KitTerm on screen (a toolbar
/// button that explains "MCP"; InfoLabel.show). The bubble anchors to
/// [context]'s render box; when it cannot fit, it opens as a sheet
/// (see Presentation). Completes when it closes.
Future<void> showKitTerm(
  BuildContext context, {
  required String term,
  required String explanation,
  KitAction? learnMore,
});
```

- **Look.** The term's text in its role, `text1`, with a dotted underline in `text2` (1 physical px, `TextDecorationStyle.dotted`). There is no info glyph. The widget pads itself symmetrically to a 48 dp minimum height and width, so the words keep their role's line height and baseline while the hit area is 48 dp (K2's "without changing the text's line height").
- **Presentation.**
  - **Bubble (default):** a panel anchored under the term (above it when there is no room), `surface2` with a 1 physical px `hairline` border, no shadow (LOOK-20), max width `KitLayout.popoverMaxWidth` (320, shared with the KitMenu panel). Its corners are `popoverRadius`, the one popover radius the KitIconButton tooltip and the KitMenu panel share (`_new-tokens.md`). It holds the term (`label` role), the explanation (`secondary`, wraps, never cut), and `learnMore` as a tertiary action. It stays until the person taps outside, presses Esc or back, scrolls the content under it, or activates the term again. It is built on `OverlayPortal`, not `Tooltip`, so it never times out while being read.
  - **Sheet (long text):** when the laid-out bubble would be taller than `termBubbleMaxHeight` of the window (in practice a phone at 200 % text), the same content opens as `showKitSheet(height: content)` titled by the term, with no buttons: Close, drag and scrim close it (map info-label-sheet: no "Got it").
- **Compatibility (R11).** `InfoLabel(term, explanation:, style:, iconSize:)`, `InfoLabel.glossary(entry, …)` and `InfoLabel.show(context, term:, explanation:)` keep their signatures and forward (`show` → `showKitTerm`). `Glossary.localized` keeps resolving the app's glossary entries.
- **Internal keys (TEST-5):** `kit-term` (default `termKey`), `kit-term-bubble`, `kit-term-learn-more`, `kit-term-sheet`.
- **Kit copy (ARB, `kit` prefix, en + ar):** `kitTermHint` "Explanation available", `kitTermShow` "Show explanation", `kitTermClose` "Close explanation", plus `kitSheetClose` (exists). The terms and explanations themselves are the caller's keys (the glossary keeps `e7Glossary*` until slice-P3.1 moves them; COPY-3 forbids new `e7` keys, and none are added).

## States

| State | Look |
|---|---|
| default | the term with its dotted underline |
| hovered (fine pointer) | a highlight behind the 48 dp box, one surface step above the host's surface through `KitTokens.fillOf` (KitTappable's rule, README.md decision D11; `surface3` on the usual `surface1` panel in light, `surface2` in dark); after a short hover the bubble opens (and closes on exit unless it was opened by click or keyboard) |
| focused (keyboard) | the 2 physical px focus ring around the 48 dp box |
| open | the bubble (or sheet); the term keeps its focus ring while the bubble is open from the keyboard |

Loading, empty, error, disabled, working and answered do not apply: the part shows text it was given. KIT-12 doc comment: "States: default, hovered, focused, open".

## Tokens

- **ThemeRoles:** `text1` (term, bubble title), `text2` (underline, explanation), `surface2` (bubble), `surface2`/`surface3` (hover, one step above the host surface, D11), `hairline` (bubble border), `accent` (focus ring only).
- **KitText:** the given `role` (or the ambient style) for the term; `label` (bubble title), `secondary` (explanation), `button` via `KitButton` (Learn more).
- **KitTokens (VL branch):** `minTarget` (48), `space2`/`space3` (bubble padding), `gutter` (the bubble's minimum distance from the window edges); `popoverRadius` (14, bubble corners; pre-wave).
- **Pre-wave seams:** `KitTokens.hairlineWidth(context)`, `KitTokens.focusRingWidth(context)`.
- **New tokens (pre-wave, `_new-tokens.md`):**
  - `KitLayout.popoverMaxWidth` = 320: the bubble's maximum width, shared with KitMenu (one popover width, not a KitTerm token);
  - `KitTokens.termBubbleMaxHeight` = 0.4: the share of the window height above which the explanation opens as a sheet.

## Adaptive

| Window | Behaviour |
|---|---|
| compact | tap or long-press opens the bubble; the sheet when it does not fit |
| medium | the same |
| expanded / large | the same, plus hover opens the bubble after a short delay on a fine pointer (`KitLayout.finePointer`); the bubble stays within the window, the gutter from each edge |

- **Keyboard (LAY-10):** the term is focusable in reading order; Enter or Space opens the bubble and moves focus into it (to Learn more, if any); Esc closes it and returns focus to the term.
- **No hover-only information (LAY-11):** everything the bubble says is reachable by tap, keyboard and screen reader.

## Accessibility

- `Semantics(button: true, label: term, hint: kitTermHint, onTapHint: kitTermShow)`: it reads "Worktree, explanation available" (K2 §1.20). On activation the explanation is read (the bubble is announced as a polite live region once) and the bubble offers a semantic dismiss action (`kitTermClose`).
- The hit area is 48×48 dp at least, with no overlap with neighbouring targets (LAY-9); the old 24 dp area is gone.
- 200 % text: the term wraps if it must; the bubble's explanation wraps and is never cut; when it would pass `termBubbleMaxHeight`, it becomes a sheet that scrolls.

## RTL

- The bubble aligns to the term's start edge and mirrors its anchor in RTL (K2 §1.20). The underline follows the text.
- A technical term (for example "MCP") inside an Arabic label is isolated by the caller with `KitBidi.ltr` when it is part of a sentence; as a standalone `KitTerm` its own direction is resolved by the text.

## Motion and haptics

- The bubble fades in and out on `KitMotion.quick` (no scale, MOT-2); the sheet uses KitSheet's transition. Under `KitMotion.reduced(context)` both are instant (MOT-7).
- Haptics: none.

## Data safety and honest state

- Nothing is stored. The explanation is app-authored copy from the ARB files, never server text (the glossary's `localized` resolves only known entries).
- `learnMore` opens an in-app place (the Guide); an external URL would go through `openExternalLink` in the caller's action (SEC-1). The kit never launches a URL.
- COPY-19: a term that needs explaining is explained here, never by a separate page. Where a screen can say it in plain words, the unit that owns the screen drops the term instead (map verdict).

## Depends on

- **None in wave 1** (tier 1a; C25 lists no edges).
- **Pre-wave seams:** `KitTokens.hairlineWidth`, `KitTokens.focusRingWidth`, `KitBidi`.
- **Existing kit parts:** `showKitSheet` (long text), `KitButton` (Learn more), `KitText`, `KitTokens`, `KitMotion`, `KitLayout`, `KitAction` (v1 fields only: `label`, `onPressed`).
- **Depended on by:** slice-P3.1 (deletes `info_label.dart`), the chat chain (`message_view.dart`), screen-library-* (`integrations_screen.dart`, `mcp_setup_screen.dart`) and the worktrees screen unit.

## Tests required

In `test/kit/kit_term_test.dart`, and `test/info_label_test.dart` updated per TEST-19(1):

1. Tap opens the bubble with the explanation; tapping outside closes it; Esc and back close it; activating the term again closes it.
2. Long-press opens the bubble (touch).
3. Hit area: the term's semantics rect is at least 48×48 dp (`androidTapTargetGuideline` passes), and the term's text has its role's line height (the padding is outside the text).
4. Semantics: `button`, label "Worktree", hint "Explanation available"; the bubble is announced once. `test/info_label_test.dart`'s expectation `'Worktree. Tap for an explanation.'` changes to the K2 label and hint (TEST-19(1), rule A11Y-1 and K2 §1.20, listed in the QA record); its "Got it" step changes to tapping outside (map: no button).
5. Learn more: shown only with `learnMore`; tapping it closes the bubble, then calls the action once.
6. Long text: at text scale 2.0 on a 360×800 window, the glossary's longest entry opens as a sheet titled by the term with no buttons; Close closes it.
7. Wrapper compatibility: `InfoLabel.glossary(Glossary.mcp)` still shows "MCP" and opens its explanation; `InfoLabel.show(context, …)` opens it without a term on screen; the glossary length test (every entry < 260 characters) still passes.
8. Keyboard (G14): with desktop capabilities, Tab focuses the term, Enter opens the bubble and focuses Learn more, Esc closes and returns focus to the term.
9. Hover: on a fine pointer, hovering opens the bubble after the delay and leaving closes it; a click-opened bubble stays on exit.
10. RTL: in Arabic the bubble aligns to the term's right edge.
11. Reduced motion (G8): opening and closing settle after one `pump()`.
12. Overflow (G6): a 40-character term and a 260-character explanation at 320 and 412 dp × text 1.0/1.3/2.0 × LTR/RTL: no overflow; at 2.0 on 320 dp it becomes the sheet.

## Galleries required

`test/goldens/kit/kit_term_golden_test.dart`, DPR 3.0, Android, the term in a section label and at the end of a row's line, names per TEST-20.

- **Each state at 412×915, dark and light:** `default`, `focused`, `open` (bubble with Learn more), `open_sheet` (long text at 2.0). 4 × 2 = 8 PNGs.
- **`open` at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000, dark and light:** 10 PNGs (1280 and 1600 rendered with desktop capabilities, as a hover).
- **`open` at text 2.0 and in Arabic RTL, at 412×915 and 1280×800, dark and light:** 8 PNGs.
- **Total:** 26 PNGs.

## Non-goals

- No inline span inside a running paragraph (a 48 dp target cannot sit mid-line without changing line height).
- No glossary data in the kit: `Glossary` and its ARB keys stay in `info_label.dart` until slice-P3.1.
- No page, no "Got it" button, no info glyph.
- No screen adoption; the four call sites move in their own units.

## Open questions

None. The names `KitLayout.popoverMaxWidth`, `KitTokens.termBubbleMaxHeight` and `KitTokens.popoverRadius` are pre-wave (`_new-tokens.md`).
