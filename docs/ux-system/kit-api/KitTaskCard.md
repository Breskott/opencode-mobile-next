# KitTaskCard — API freeze (wave 0)

Unit: `kit-KitTaskCard` (wave 1, tier 1c, kind `kit-part`, model sonnet), after kit-KitNeedsYou, kit-KitReceipt and kit-KitStatusMark-v2 (C25). Spec: kit-v2.md §5 (team board: "task card") and §9.2 (Surfaces), with cut review C24 (`lib/ui/widgets/team_board_card.dart` moves from shared-team-1 into this unit). The board's design is `docs/design/team-board-2026-09-26.md` §2 "Card anatomy" (TB); STANDARDS overrides it where the two differ (§0.2). Rules: LOOK-4, LOOK-5, LOOK-14, LOOK-23, LOOK-24, KIT-8, KIT-27, KIT-28, KIT-43, STATE-9, STATE-10, COPY-13, A11Y-5, A11Y-8, LAY-9, MOT-11.

## Purpose

One AI Team task on the board. It shows, in order:

- the task's mark;
- its title in the person's words;
- one muted meta line (priority when not normal, type, who has it, how long ago);
- at most one flag line (needs you, blocked by, failed, stopped, in its epic), or a receipt while a move is in flight.

A tap opens the task's conversation.

## Replaces

- **Map element, 1 on 1 page:** `team-board#team-board-card` (kit-v2.json `assignment` → `module:team board`; kit "KitPanel+KitTaskMark+custom", `kitGap` `KitTaskCard`; note "meta + flag lines + ⋯").
- **File in this unit's write set:** `lib/ui/widgets/team_board_card.dart` (428 lines; G16: `CustomPaint` 1, `GestureDetector` 1, `Icon` 3, `IconButton` 1, `Text` 3). It becomes a mapping file whose G16 count reaches zero:
  - `TeamBoardCardView(card, now, onOpen, onMoves, onLongPress)` keeps its signature and builds a `KitTaskCard` from a `TeamBoardCard`;
  - `TeamBoardPriorityGlyph(priority)` forwards to `KitPriorityGlyph`;
  - the word functions (`teamBoardColumnWord`, `teamBoardAgeLabel`, `teamBoardPriorityWord`, `teamBoardTypeWord`, `teamBoardMark`, `teamBoardFlag`) stay there, because they read `state/team_board.dart` and the kit reads no app model;
  - `TeamBoardCardView` and `TeamBoardPriorityGlyph` are marked `/// Retired by kit-KitTaskCard: use KitTaskCard` (KIT-43; no `@Deprecated`).
- **Look retired:**
  - the whole card in `KitPanel(tone: attention)` when it needs you (LOOK-24: in team lists, needs-you is the mark and word on a row, never the attention card);
  - "Blocked by …" in the attention tone (LOOK-4);
  - "Failed" and the urgent priority in the failure red (LOOK-5, B2 interim);
  - the unlit priority bars at 35 % alpha (LOOK-1, LOOK-14);
  - the 40 dp drawn "⋯" (`IconButton` with `tapTargetSize.padded`), and the per-card ⋮ (KIT-28, below).

## File

- `lib/ui/kit/kit_task_card.dart` (new): `KitTaskCard`, `KitTaskMeta`, `KitTaskFlag`, `KitTaskFlagKind`, `KitPriority`, `KitPriorityGlyph`.
- `lib/ui/widgets/team_board_card.dart` (the mapping file).
- Tests: `test/kit/kit_task_card_test.dart`.
- Gallery: `test/goldens/kit/kit_task_card_golden_test.dart`.

## Public API

```dart
/// A task's priority (TB §2; Linear's five levels).
enum KitPriority { urgent, high, normal, low, someday }

/// The one flag line a card may carry. In-flight writes are a receipt,
/// not a flag (see [KitTaskCard.receipt]).
enum KitTaskFlagKind {
  needsYou, // KitNeedsYou's word and mark tone (the only attention on a card)
  blocked,  // "Blocked by Sync engine": blocked glyph, text1 (never attention, LOOK-4)
  failed,   // "Stopped with an error": neutral error glyph, text1 (never red, LOOK-5)
  stopped,  // "Cancelled": stop glyph, text2
  info,     // "In epic: Onboarding": its own glyph, text2
}

@immutable
class KitTaskFlag {
  const KitTaskFlag({required this.kind, required this.label, this.icon});
  final KitTaskFlagKind kind;
  final String label;      // the whole line, from the host's ARB ("Blocked by {title}")
  final IconData? icon;    // info only; the other kinds have fixed glyphs
}

/// One piece of the meta line; pieces are joined with " · ".
@immutable
class KitTaskMeta {
  const KitTaskMeta(this.label, {this.icon, this.priority, this.strong = false});
  final String label;          // "High", "Bug", "fox", "12 min ago"
  final IconData? icon;        // a type glyph (bug, feature, epic)
  final KitPriority? priority; // draws KitPriorityGlyph before the label
  final bool strong;           // text1 semibold (urgent and high), otherwise text2
}

/// States: default, needs you, blocked, failed, stopped, done, moving
/// (receipt: sending / not confirmed / refused), read-only (no action).
class KitTaskCard extends StatelessWidget {
  const KitTaskCard({
    super.key,
    required this.title,           // the task's words as written (COPY-2); 2 lines, 3 from 1.3× text
    required this.mark,            // KitTaskState
    required this.onOpen,          // the task's conversation (scrolled to its request card when needsYou)
    this.paused = false,
    this.meta = const [],
    this.flag,
    this.receipt,                  // KitReceipt? a move in flight; replaces the flag line while present
    this.action,                   // KitAction? ONE trailing icon action (KIT-27), e.g. "Move or change";
                                   //   its icon and label are required; null = none (read-only)
    this.menu = const [],          // List<KitMenuItem>: long-press, right-click, Shift+F10, semantic actions
    this.onLongPress,              // compatibility hook for TeamBoardCardView only; asserts menu.isEmpty
    this.cardKey,                  // TeamBoardCardView passes ValueKey('team-board-card-$id')
    this.titleKey,                 // 'team-board-card-title-$id'
    this.metaKey,                  // 'team-board-card-meta-$id'
    this.flagKey,                  // 'team-board-card-flag-$id'
    this.actionKey,                // 'team-board-card-more-$id'
  });
}

/// Priority as signal bars: three bars filled to the level, a filled
/// square with a bang for urgent, a dashed line for someday. Decorative:
/// the word beside it says the priority.
class KitPriorityGlyph extends StatelessWidget {
  const KitPriorityGlyph({super.key, required this.priority});
}
```

Notes:

- **One trailing action, never a generic ⋮ (KIT-27, KIT-28).** TB §46 calls the card "a KitRow anatomy", so the row rules apply.
  - The card has no overflow ⋮. It may carry one icon action named by its verb.
  - `TeamBoardCardView` passes `onMoves` as `action: KitAction(label: l10n.teamBoardMoveMenuTooltip, icon: AppIconography.swap, onPressed: onMoves)` with `actionKey: team-board-card-more-$id`, and passes `onLongPress` through. The board's behaviour (a button and a long-press that open the move sheet) and its test keys are unchanged. Only the glyph changes, from ⋯ to the move verb's glyph.
- **Moves are a receipt.** "Moving to Review…" is `KitReceipt(state: sending, label: …, since: movedAt)`. After 8 s without the host's echo it reads "Not confirmed yet" with Try again (STATE-10). The board's refused move keeps its screen-level `KitNotice`.
- **Kit copy:** none. Every word is the host's (COPY-13 team words come from `team_vocabulary.dart` and the board's ARB keys). The card only joins meta pieces with the kit's `·` separator, spaced with `space1`.

## States

| State | Mark | Title | Flag or receipt line | Other |
|---|---|---|---|---|
| default (waiting, working) | `KitTaskMark` | `text1` | none, or `info` | |
| needs you | `KitNeedsYou.mark()` | `text1` | `KitNeedsYou.span` + the flag label ("Needs you · Approve the merge") | no attention surface (LOOK-24) |
| blocked | as its column | `text1` | blocked glyph + label, `text1` semibold | |
| failed | `failed` | `text1` | error glyph + label, `text1` semibold | |
| stopped | `stopped` | `text2` | stop glyph + label, `text2` | |
| done | `done` | `text2` (resting; opaque, LOOK-14) | none, or `info` | a done card that needs you keeps `text1` |
| moving | as before the move | unchanged | `KitReceipt` sending, then not confirmed after 8 s, or refused with the host's reason | the action is disabled while sending, with the reason "Moving…" as its hint; the receipt line is the visible reason (STATE-8) |
| read-only | as its state | as its state | as its state | no action, no menu; long-press shows the title's tooltip |

The board's loading and empty states are KitBoardLane's. An error on the card is its flag or its receipt. Disabled applies only to the action. KIT-12 doc comment: "States: default, needs you, blocked, failed, stopped, done, working (moving receipt), disabled (read-only)".

## Tokens

- **ThemeRoles:**
  - card `surface1` (a panel on the lane's `ground`);
  - title `text1` (`text2` when done or stopped);
  - meta `text2`, strong meta `text1`;
  - flag glyphs and words as in States;
  - the priority glyph lit in `text1` and unlit in `surface3`, urgent a `text1` square with a `ground` bang;
  - `attention` only through `KitNeedsYou`.
- **KitText:** `rowTitle` (title, 16/22 w500), `secondary` (meta and flag; flag semibold via `KitText.rich` span weight).
- **KitTokens:**
  - `panelCornerRadius` (18);
  - `space2` (8: card padding at the start, and the gap between mark and text) and `space3` (12: top, bottom and end padding);
  - `space1` (4: the meta separator's spacing);
  - `iconTileSize` (30: the mark's box);
  - `minTarget` (48: the action and the card's own target).
- **KitIcon** (`KitIconSize.small`, 20): the type glyph, flag glyphs and the priority glyph's box. Today's 14 and 16 are retired (LOOK-33).
- **New tokens:** none.

## Adaptive

- **All windows:** the card is as wide as its lane (KitBoardLane sets the lane width) and its content is identical.
- **Short windows:** unchanged.
- **Fine pointer:**
  - hover shows `KitTappable`'s fill on the whole card;
  - right-click opens `menu`;
  - the action's tooltip shows its label (and a shortcut if the host gives one).
- **Keyboard (LAY-10):**
  - the card is one Tab stop; Enter or Space calls `onOpen`;
  - Shift+F10 or the Menu key opens `menu`;
  - the trailing action is the next Tab stop.

## Accessibility

- **One button node for the card,** read as "{title}. {state word}. {meta}. {flag or receipt}". The state word comes from `KitTaskMark.wordFor` or `KitNeedsYou`, so it is never colour alone (STATE-9). The mark itself is excluded, so the word is read once.
- **Menu items** are custom semantic actions (KIT-28, A11Y-5). The long-press hint is the action's label.
- **The trailing action** is a 48 dp `KitIconButton` with its label, at least 8 dp from the card's edge.
- **200 % text (A11Y-2, A11Y-8):**
  - the title shows 2 lines below 1.3× and 3 lines from 1.3×, ending with "…". Its full text is in semantics and in the card's tooltip;
  - meta and flag lines wrap and never truncate;
  - the card grows, and nothing overflows at 320 dp.
- **Announcements:** the receipt announces its own changes once (KitReceipt). The card is not a live region.

## RTL

- The mark sits at the start and the action at the end; padding is directional.
- The priority glyph's bars fill from the start edge.
- Titles and names are the host's words, wrapped with `KitBidi.auto` by the host (COPY-30).
- The separator `·` needs no isolation.

## Motion and haptics

- **Nothing on the card moves.** A card leaving its column is animated by KitBoardLane (`KitAnimatedRows`), not by the card.
- **The receipt's word change** uses KitReceipt's own cross-fade (`KitMotion.quick`), instant under reduced motion.
- **No haptics:** a tap opens, and a move is the host's (MOT-11).
- **Reduced motion:** settles after one `pump()` (G8).

## Data safety and honest state

- **Nothing is changed by the card itself:** `onOpen`, the action and the menu belong to the host. A move is confirmed or refused by the host, and the card shows the receipt until then (STATE-10). "Moving" never becomes "Done" without the host's echo.
- **Needs you lands on the card:** `onOpen` for a needs-you card must open the conversation scrolled to its `KitRequestCard`. The card never answers (LOOK-24, AUTO-17). This is a contract for the host, repeated in the doc comment.
- **One flag line:** needs you, then failed, then blocked, then stopped, then info. The host's `teamBoardFlag` already orders them, and the card shows what it is given, so two conflicting flags cannot appear.

## Depends on

- **kit-KitStatusMark-v2** (tier 1a): `KitTaskMark`, `paused`, `wordFor` (C25).
- **kit-KitNeedsYou** (tier 1b): `mark()` and `span()` (C25).
- **kit-KitReceipt** (tier 1b): the moving line (C25).
- **kit-KitTappable** (tier 1b; edge added, README.md): the card's tap, hover, focus ring, menu and semantic actions. It keeps this unit in tier 1c.
- **Tier-1a parts it also uses** (edges added for the record, no tier change):
  - kit-KitMenu (`KitMenuItem`);
  - kit-KitSurface (`KitSurface.panel` look);
  - kit-KitIcon (20 dp glyphs).
- **Existing:** `KitIconButton` (the action, v1 API), `KitText`, `KitTokens`, `ThemeRoles`.

Depended on by: kit-KitBoardLane (C25), and the board screen through `TeamBoardCardView` (wave 2).

## Tests required

In `test/kit/kit_task_card_test.dart`:

1. **Open:** a tap anywhere on the card except the action calls `onOpen` once. Enter on the focused card does the same (G14).
2. **Action:** the trailing action is at least 48 × 48 dp and calls its callback. It is absent with `action: null`. With `receipt` sending it is disabled, with the reason as its semantic hint.
3. **Menu:** long-press and right-click open `showKitMenu` with `menu`. Each item is a semantic custom action. `onLongPress` with a non-empty `menu` asserts.
4. **Needs you:** `mark: needsYou` shows the "Needs you" word, paints `attention` only in the mark and word (a painted-colour scan), and draws no attention surface or border.
5. **No red, no amber:** `blocked` and `failed` flags and an urgent priority paint no `danger` and no `attention` colour.
6. **Receipt:** with `KitReceipt(state: sending, since: now)` and KitSince's fake clock, "Moving to Review" shows; at 8 s it reads "Not confirmed yet" with Try again. The receipt replaces the flag line while present.
7. **Semantics:** the card node reads "{title}. {word}. {meta}. {flag}". The mark is excluded, so there is no double word.
8. **Truncation:** a 300-character title shows 2 lines at 1.0 and 3 lines at 1.3; the full title is in the semantics label and the tooltip. Meta and flag lines are never ellipsised.
9. **Wrapper:** `TeamBoardCardView(card:, now:, onOpen:, onMoves:, onLongPress:)` renders a `KitTaskCard` with the keys `team-board-card-$id`, `-title-`, `-meta-`, `-flag-` and `-more-`. `test/team_board_test.dart` finds and taps them unchanged. That test belongs to the integrator (R08); if it breaks, it is reported under `sharedTestsBroken`, not edited.
10. **Priority glyph:** high lights 3 bars and low 1; someday is dashed; urgent is a filled square. It is excluded from semantics.
11. **Overflow and motion:** no overflow at 320 and 412 dp at text 1.0, 1.3 and 2.0, LTR and RTL (G6); settles after one `pump()` (G8).

## Galleries required

`test/goldens/kit/kit_task_card_golden_test.dart`, DPR 3, Android. The scene is a lane-width column (as KitBoardLane sizes it) on `ground` with one card per scene.

- **Declared states × dark and light at 412×915:**
  - `default` (working, high priority, bug, agent, 12 min);
  - `needs_you`;
  - `blocked`;
  - `failed`;
  - `stopped`;
  - `done`;
  - `moving`;
  - `not_confirmed`;
  - `read_only`.

  That is 9 × 2 = 18 PNGs.
- **Default × dark and light** at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000: 10 PNGs.
- **Text 2.0 and Arabic** (`default`, `needs_you`) at 412×915 and 1280×800, dark: 8 PNGs.
- **Names:** `kit_task_card_<state>[_ar][_text2][_WxH]_<dark|light>.png`. That is 36 PNGs.

## Non-goals

- **No drag and drop**, no inline editing of titles or priority (TB non-goals).
- **No move sheet:** that is the board screen's `team_board_move_sheet.dart`.
- **No mapping from `TeamBoardCard` inside the kit.**
- **No board layout:** that is KitBoardLane.

## Open questions

None. The ⋯-versus-row-rules conflict is settled by §0.2: STANDARDS KIT-27 and KIT-28 rank above TB. The board keeps its behaviour through one named trailing action instead of a ⋮. The coordinator should amend TB §2 "Card anatomy" to say so.
