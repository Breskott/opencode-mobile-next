# KitAskLine and KitSkeletonTranscript (look only) — API freeze (wave 0, 2026-09-26)

Unit: `kit-KitAskLine-look` (wave 1, tier 1a, kind `kit-change`, model sonnet; cut review C18). Write set: `lib/ui/kit/kit_ask_line.dart` and `lib/ui/kit/kit_skeleton_transcript.dart`. Spec: VL §7 (look only); STANDARDS KIT-9, KIT-43, LOOK-1, LOOK-2, LOOK-6, LOOK-12, LOOK-19, LOOK-33, LAY-8, A11Y-8. Written in the cross-check because the unit had no frozen API block (R16). Both public APIs stay exactly as they are; only the look moves onto the visual language's roles, type and tokens.

## Purpose

Two existing parts that no other wave-1 unit owns:

- **`KitAskLine`:** a one-time question on a working screen with its two answers in view (the chat's "Tell me when the first reply arrives?").
- **`KitSkeletonTranscript`:** the placeholder turns while a conversation loads.

The unit moves them to `ThemeRoles`, `KitText` roles, `KitTokens` spacing and icon sizes 20/22/24, with no change of behaviour.

## Replaces

- **In the two files:** `theme.colorScheme.primary`, `scheme.surfaceContainer` and `surfaceContainerHigh` (LOOK-2), `theme.textTheme.bodyMedium`/`labelLarge` (LOOK-12), the 18 dp icon (LOOK-33), `BorderRadius.circular(4)` and `height / 2` (LOOK-19), the literal paddings `fromSTEB(16, 2, 8, 2)`, `top: 15`, `top: 12`, `SizedBox(width: 12)`, `minHeight: 52`, the transcript's `maxWidth: 860` and `fromLTRB(16, 16, 16, 24)` (KIT-9, LAY-2), and the raw `TextButton` answers (KIT-8).
- **Callers (unchanged):** `lib/ui/widgets/first_reply_notify_card.dart:122` (`KitAskLine(`) and `lib/ui/screens/chat/chat_states.dart:22` (`KitSkeletonTranscript(`).
- **Map:** no element is assigned; the two parts' pages are restyled through this unit's look.

## File

- `lib/ui/kit/kit_ask_line.dart`, `lib/ui/kit/kit_skeleton_transcript.dart` (existing files).
- Tests: `test/kit/kit_ask_line_test.dart` (both parts). Gallery: `test/goldens/kit/kit_ask_line_golden_test.dart`, with a group for each part.

## Public API

Unchanged (KIT-43):

```dart
class KitAskLine extends StatelessWidget {
  const KitAskLine({
    super.key,
    required this.icon,
    required this.question,
    required this.accept,           // KitAction
    required this.decline,          // KitAction
    this.semanticsLabel,
  });
}

class KitSkeletonTranscript extends StatelessWidget {
  const KitSkeletonTranscript({super.key, this.turns = 2});
}
```

- **The answers** are tertiary `KitButton`s built from the two `KitAction`s (`KitButton.fromAction`, the existing constructor): decline, then accept, both in the tertiary `accent` (R5); the same measurement decides when they move under the question, now measured with `KitText.styleOf(label/secondary)` and token widths instead of literals.
- **Internal keys (TEST-5):** `kit-skeleton-transcript` stays. The answers keep their callers' `KitAction.key`s.

## States

- **KitAskLine:** one line (question and answers side by side), or stacked (answers under the question, start-aligned) when they do not fit or the text scale passes 1.5, as today. Loading, empty, error and working do not apply: it asks once and the host removes it when answered.
- **KitSkeletonTranscript:** one state, no words and no motion, excluded from semantics (unchanged).

KIT-12 doc comments: KitAskLine "States: inline, stacked"; KitSkeletonTranscript "States: loading (decorative)".

## Tokens

- **ThemeRoles:** the ask line's glyph `text2` (a neutral glyph: the accent is for the primary, working and links, LOOK-6); the question `text1`; the skeleton's prompt block and reply bars `surface3` on the transcript's `ground` (opaque roles, no alpha).
- **KitText:** `secondary` for the question (14/20, two lines at most, the full text in `semanticsLabel`), `button` for the answers (through KitButton).
- **KitTokens:** `smallIconSize` (20, the glyph), `space1`–`space4`, `gutter` (16), `minTarget` (48); the ask line's minimum height becomes `statusLineMinHeight` (52, shared with KitStatusLine; pre-wave, `_new-tokens.md`); the skeleton's corners `KitShape.button` for the prompt block and `KitShape.pill` for the bars (pre-wave `KitShape`); its width cap `KitLayout.paneDetailMaxWidth` (700, pre-wave; replaces 860, LAY-5).
- **New tokens:** none of its own.

## Adaptive

- **All windows:** the ask line spans the width it is given (the conversation pane) and stacks by measurement, never by a width literal. The skeleton is capped at `paneDetailMaxWidth` and centred, like the transcript it stands in for.
- **Short windows:** unchanged (the skeleton shows the turns nearest the composer and clips at the top, as today).
- **Keyboard and pointer:** the answers are KitButtons (Tab order decline then accept, Enter and Space, hover from KitButton). The skeleton is not focusable.

## Accessibility

- The ask line is one container labelled `semanticsLabel` (or the question); each answer is a 48 dp button with its label. It is not a live region (the host announces a new question once).
- At 200 % text the question keeps two lines with the full text in semantics (the existing rule, A11Y-8 for a one-time question) and the answers stack under it.
- The skeleton stays excluded from semantics; the screen's loading bar says it is loading.

## RTL

The glyph at the start and the answers at the end (or under the question, start-aligned); all insets directional (`EdgeInsetsDirectional`; the existing `EdgeInsets.only(top:)` becomes directional, G7). The skeleton's bars grow from the start edge (unchanged).

## Motion and haptics

None (unchanged): the ask line appears with its host, and the skeleton never moves. No haptics.

## Data safety and honest state

Unchanged. The ask line never answers for the person; the skeleton never shows words, so it cannot be mistaken for content.

## Depends on

- **Existing:** `KitButton`/`KitAction`, `KitText`, `KitTokens`, `ThemeRoles`, `KitLayout`.
- **Pre-wave (`_new-tokens.md`):** `KitShape`, `statusLineMinHeight`, `KitLayout.paneDetailMaxWidth`.
- **No wave-1 dependency** (tier 1a).

## Tests required

In `test/kit/kit_ask_line_test.dart`:

1. The ask line's question, glyph and both answers render; each answer calls its action once.
2. At 412 dp and text 1.0 the answers sit beside the question; at text 2.0 (or a long question at 320 dp) they sit under it, start-aligned; no overflow at 320–1600 dp, LTR and RTL (G6).
3. Painted colours are opaque roles only: no `colorScheme` read and no accent on the glyph (a source scan plus a painted-colour scan); the glyph is 20 dp (LOOK-33).
4. The skeleton is excluded from semantics, keeps `kit-skeleton-transcript`, is at most 700 dp wide at 1280 dp, and clips instead of overflowing in a 200 dp tall box.
5. Reduced motion (G8): both settle after one `pump()`.
6. `first_reply_notify_card` and `chat_states` callers compile unchanged (flutter analyze).

## Galleries required

`test/goldens/kit/kit_ask_line_golden_test.dart`, DPR 3, Android (TEST-9, TEST-20):

- **States × dark and light at 412×915:** `ask_inline`, `ask_stacked` (a long question), `skeleton`. That is 6 PNGs.
- **Default (`ask_inline` above a composer-height inset, `skeleton` in its own shot) × dark and light** at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000: 20 PNGs.
- **Text 2.0 and Arabic** (`ask_inline`) at 412×915 and 1280×800, dark: 4 PNGs.
- **Names:** `kit_ask_line_<state>[_ar][_text2][_WxH]_<dark|light>.png`. That is 30 PNGs.

## Non-goals

- No API change and no behaviour change.
- No new ask or skeleton variants.
- No edits to the callers.

## Open questions

None.
