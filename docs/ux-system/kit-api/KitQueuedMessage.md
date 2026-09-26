# KitQueuedMessage — frozen API (wave 0, 2026-09-26)

Group: chat. Unit `kit-KitQueuedMessage` (wave 1, tier 1c; after kit-KitReceipt, C25, and kit-KitMenu instead of kit-KitIconButton-v2, README.md). In wave 2c `lib/ui/kit/chat/kit_queued_message.dart` joins chain link chat-3 (C03, C38); chain link chat-1 is the first to render it (in `message_view.dart`, carrying P4.3's "Waiting to send · N" bubble), and chat-3 carries P4.3's composer half (withdraw returns the text to the draft with Undo). Spec: kit-v2.md §9.2, §5 ("queued messages carry a KitReceipt"); owner verdict on `embedded-pending-sends-strip`: "All the queued messages should be merged in one bubble with a clear CTA inside and follow the theme"; STANDARDS STATE-17 (one queued bubble styled as the prompt bubble, one action line inside, per-message actions in its row menu) and Appendix A #76; programme P4.3. Rules: STATE-17, STATE-10, STATE-5, DATA-7, DATA-11, KIT-28, A11Y-5, LOOK-26, LOOK-5.

## Purpose

Everything that is waiting to reach the agent (prompts typed while offline, and on OpenCode 2 the sends the server has accepted but not yet delivered) shown as one bubble at the end of the conversation: "Waiting to send · 3", each message in order with its own honest state, and one clear action inside ("Send now", "Edit"). Nothing typed is ever silently lost or silently resent.

## Replaces

- **Map** (kit-v2.json, module:chat composer): `embedded-pending-sends-strip#pending-bubble` (kitGap KitQueuedMessage). The same page's `pending-actions` (assigned KitIconButton) become the bubble's per-message menu under STATE-17, which ranks above K2's assignment. Map `statesMissing` fixed here: "more than 3 queued: the third bubble is cut by the composer" (the bubble is a transcript item, not a capped strip), "sending progress per item" (each item has its receipt state). Map note fixed: "outlined red box per message, right-aligned, overlaps the composer".
- **Code** (`lib/ui/screens/chat/message_view.dart`, chat-1 renders it; chat-3 owns this part's file in 2c): `_PendingSendsStrip` (:2937), `_PendingSendBubble` (:3029), `_PendingSendAction` (:3119, 32 dp icon buttons), `_QueuedPromptBubble` (:3151), `_InboxSendBubble` (:3232). Their raw widgets (Container, Text, Icon, Row, IconButton, SingleChildScrollView) are part of `message_view.dart`'s G16 count of 111 that chat-1 brings to zero.

## File

`lib/ui/kit/chat/kit_queued_message.dart` (new).

## Public API

```dart
/// Where one waiting message stands. The host maps its queue entry or its
/// server inbox item; the bubble says it in words.
enum KitQueuedState {
  waiting,        // offline: it sends when the app is back online
  sending,        // on the wire now
  notConfirmed,   // it left, and no confirmation came back: Try again is offered (a resend)
  reachedServer,  // the server accepted it but this phone could not record that: never resend
  failed,         // the send failed; [KitQueuedItem.reason] says why
  afterThisReply, // OpenCode 2: accepted, delivered when the running reply finishes
  addToThisTurn,  // OpenCode 2: accepted, delivered at the agent's next step
  contextUpdate,  // OpenCode 2: an update the server itself queued (not typed by the person)
}

@immutable
class KitQueuedItem {
  const KitQueuedItem({
    required this.id,
    required this.text,                    // the message; may be empty for contextUpdate
    required this.state,
    this.attachmentCount = 0,              // "2 attachments"
    this.reason,                           // failed / notConfirmed: plain words (agentErrorWords), never raw
    this.since,                            // sending: when it left, for the 8 s escalation
    this.menu = const <KitMenuItem>[],     // Edit, Send now / Add to this turn / Send after, Try again, Remove
    this.key,                              // today's ValueKey('queued-send-<i>') / ValueKey('pending-send-<id>')
  });
  final Object id;
  final String text;
  final KitQueuedState state;
  final int attachmentCount;
  final String? reason;
  final DateTime? since;
  final List<KitMenuItem> menu;
  final Key? key;
}

/// Everything waiting to reach the agent, in one bubble at the end of the
/// conversation (STATE-17). Styled as the person's prompt bubble (surface2,
/// radii 20/20/6/20); lists each item oldest first; one action line inside.
///
/// States: waiting (offline), sending, not confirmed, reached server,
/// failed, queued behind the reply (OpenCode 2), steering (OpenCode 2),
/// mixed, empty (KIT-12).
class KitQueuedMessage extends StatelessWidget {
  const KitQueuedMessage({
    super.key,
    required this.items,        // oldest first; empty renders nothing
    this.action,                // the bubble's one call to action: "Send now", "Try again"
    this.secondaryAction,       // at most one more: "Edit"
    this.bubbleKey,
  });

  final List<KitQueuedItem> items;
  final KitAction? action;
  final KitAction? secondaryAction;
  final Key? bubbleKey;
}
```

**Frozen behaviour.**

- **Frame.** End-aligned like the prompt bubble (`KitLayout.bubbleMaxShare`), `surface2`, corners `bubbleRadius`/`bubbleTailRadius` (the tokens KitMessage.md flags), no border and no red (LOOK-5: a failed send is said in words). It is a transcript item: it scrolls with the conversation, has no height cap and no internal scroll, and is never overlaid on the composer.
- **Head line.** "Waiting to send · {count}" in `label`/`text2`. When every item is `waiting`: "Waiting to send · {count} · sends when you're back online".
- **Items.** One per item, oldest first, separated by `hairline` rules: the text in `body`/`text1`, at most two lines with an end ellipsis (the full text in semantics); "{n} attachments" in `secondary`; then the state line in `secondary`:
  - `sending`, `notConfirmed`, `failed` use `KitReceipt.span` (sending → "Sending…"; notConfirmed → "Not confirmed yet"; failed → refused with `reason`). `KitReceipt.span` is a static span with no timer, so a `sending` item with `since` is wrapped in `KitSince(since: item.since, builder: …)`, and once slow it renders the `notConfirmed` span ("Not confirmed yet"): one timer source for the kit (C12).
  - `reachedServer` → "Reached the server" (a receipt `sent` with that label; no Try again, a resend would duplicate it).
  - `waiting` → "Waiting to send"; `afterThisReply` → "Sends after this reply"; `addToThisTurn` → "Adds to this turn"; `contextUpdate` → "Update waiting".
- **Per-item actions.** No button per item (STATE-17, KIT-28). Long-press and right-click on an item open `showKitMenu(items: item.menu)` at the gesture point; Shift+F10 and the Menu key open it anchored; the items are the item's semantic custom actions (A11Y-5). An item with an empty menu is inert.
- **Action line.** Inside the bubble, after the items: `action` as a tertiary `KitButton` in `accent` text (LOOK-23 tertiary; the button words are the host's), then `secondaryAction`. Both ≥ 48 dp, 8 dp apart; they wrap to two lines at 200 % text. With neither, no action line.
- **Arrivals and departures.** Items enter and leave with `KitAnimatedRows` (paint only; an item that is sent folds away where it was). The bubble itself appears and leaves with a `KitMotion.quick` fade.

**Kit copy** (ARB, `kit` prefix, en + ar, ICU plurals with all Arabic forms): `kitQueuedTitle` "Waiting to send · {count}", `kitQueuedOffline` "Sends when you're back online", `kitQueuedWaiting` "Waiting to send", `kitQueuedReachedServer` "Reached the server", `kitQueuedAfterReply` "Sends after this reply", `kitQueuedAddToTurn` "Adds to this turn", `kitQueuedUpdate` "Update waiting", `kitQueuedAttachments` "{count, plural, =1{1 attachment} other{{count} attachments}}", `kitQueuedItemLabel` "Waiting message {index} of {count}: {text}. {state}" (semantics), `kitQueuedActions` "Message actions" (menu name). Receipt words are KitReceipt's.

## States

Declared (KIT-12): **waiting** (all offline), **sending**, **sending slow** (after 8 s: "Not confirmed yet"), **notConfirmed**, **reachedServer**, **failed**, **afterThisReply**, **addToThisTurn**, **contextUpdate**, **mixed** (several states in one bubble), **empty** (renders nothing, no semantics node). No loading (the host has the queue), no disabled (an action that cannot run is left out by the host, or carries its `disabledReason` through KitAction, STATE-8).

## Tokens

- ThemeRoles: `surface2` (the bubble), `text1` (message text), `text2` (head line, state words), `hairline` (between items), `accent` (the action line's text; focus ring). Receipt marks are KitReceipt's.
- KitText roles: `label` (head line), `body` (text), `secondary` (attachments, state), `button` (actions, via KitButton).
- KitTokens: `space2`, `space3`, `space4`, `minTarget` (48), `hairlineWidth(context)` (§0.5 step 2 seam).
- Shared pre-wave tokens (`_new-tokens.md`): `KitTokens.bubbleRadius`, `KitTokens.bubbleTailRadius`, `KitLayout.bubbleMaxShare`.

## Adaptive

- **compact / medium / expanded / large:** the same end-aligned bubble inside the conversation pane (≤ `KitLayout.paneDetailMaxWidth`); the action line is one row when it fits and stacks at 200 % text.
- **Fine pointer:** right-click on an item opens its menu at the pointer; hover shows the item's surface step; the action buttons show hover (KitButton).
- **Keyboard:** each item with a menu is a Tab stop (Shift+F10 or the Menu key opens it), then the actions; Enter activates an action.

## Accessibility

- The bubble is one container named by the head line; each item is a node labelled `kitQueuedItemLabel` with its menu as custom actions.
- State changes (sending → sent, or failed) are announced once by the host's status line; the bubble is not a live region (A11Y-3).
- Actions ≥ 48 dp and 8 dp apart; at 200 % text every item wraps (the two-line preview becomes more lines only in semantics), the action line stacks, nothing clips at 320 dp.

## RTL

- The bubble sits at the end edge (left under Arabic) with its small corner mirrored, like the prompt bubble.
- Each item's text follows its own first strong character; counts come from intl (COPY-30).
- Actions sit at the start of the action line, mirrored.

## Motion and haptics

- Items: `KitAnimatedRows` (paint fades, no size animation in the scrolling list, MOT-5). The bubble: a `KitMotion.quick` fade in and out.
- Reduced motion: nothing moves; one `pump()` settles (G8x).
- Haptics: none from the bubble. When the person's "Send now" makes words leave, the host fires `KitHaptics.send` (MOT-11).

## Data safety and honest state

- The bubble never sends, resends, edits or deletes anything; every act is the host's through `action`, `secondaryAction` and each item's menu. The host applies DATA-11: withdrawing a message returns its text to the draft with Undo (`showKitUndo`); "Remove" of text the app keeps a copy of is also Undo; a confirmation appears only when text would be lost for good (P4.3).
- `reachedServer` never offers Try again (a resend would be a certain duplicate); `notConfirmed` offers it only as an explicit act.
- "Sent" is never shown as done; a send with no confirmation escalates to "Not confirmed yet" after 8 s (STATE-5, STATE-10, via KitReceipt).
- Errors are plain words (the host passes `agentErrorWords` output, COPY-14); raw text stays behind Details.
- The Inbox never lists this queue (STATE-17); removing a server lists its queued prompts first (DATA-7; the host's confirmation).

## Depends on

- **kit-KitReceipt** (C25): `KitReceipt.span`, states and escalation.
- **kit-KitMenu** (tier 1a: `showKitMenu`, `KitMenuItem`): edge added, and the C25 edge to kit-KitIconButton-v2 dropped because STATE-17 has no per-item button (README.md). The unit stays in tier 1c.
- **kit-KitSince** (tier 1a, reached through kit-KitReceipt): the per-item escalation above.
- Existing `KitButton.tertiary`, `KitAction`, `KitAnimatedRows`, `KitText`, `KitMotion`.
- Pre-wave seams: `KitTokens.hairlineWidth`, and the bubble tokens `bubbleRadius`, `bubbleTailRadius`, `bubbleMaxShare`, which the coordinator adds before wave 1 (`_new-tokens.md`), so no unit races to add them.

## Tests required

`test/kit/kit_queued_message_test.dart`:

1. Empty `items` renders nothing and no semantics node.
2. Three items render in the given order inside one bubble with the head line "Waiting to send · 3"; the bubble is end-aligned, `surface2`, with the 20/20/6/20 corners, and has no border and no `danger` role.
3. Each state shows its words; `sending` with `since` 8 s ago (fake async) shows "Not confirmed yet"; `reachedServer` has no Try again anywhere.
4. Ten items: all are laid out (no internal scroll, no height cap) inside a scroll view without overflow.
5. Long-press on an item opens its menu items; right-click (desktop capabilities) opens the same; the items are semantic custom actions; no per-item icon button exists.
6. `action` and `secondaryAction` render as buttons in the bubble and call back once; with neither there is no action line.
7. An item removed from `items` animates out and leaves the tree after `KitMotion.standard`; under reduced motion one `pump()` settles.
8. The part never calls back on its own (no timers fire actions; only escalation words change).
9. Semantics: container label from the head line; item labels per `kitQueuedItemLabel`; not a live region; targets ≥ 48×48, 8 dp apart.
10. Desktop capabilities: Tab reaches each item with a menu, then the actions; Shift+F10 opens an item's menu.
11. 200 % text at 320 dp, LTR and RTL: no overflow (G6).

## Galleries required

`test/goldens/kit/kit_queued_message_golden_test.dart`, DPR 3, Android (TEST-9, TEST-20), placed at the end of a short transcript above a composer-height inset:

- States at 412×915, dark and light: `kit_queued_message_offline` (three waiting, "Send now" disabled with its reason via the host's KitAction), `kit_queued_message_sending`, `kit_queued_message_not_confirmed` (Try again), `kit_queued_message_failed`, `kit_queued_message_after_reply` (OpenCode 2), `kit_queued_message_mixed`.
- Default (three waiting, Send now + Edit) at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000, dark and light.
- Default at text 2.0 and Arabic RTL at 412×915 and 1280×800, dark.
- About 26 PNGs.

## Non-goals

- The offline queue, the OpenCode 2 inbox, flushing, reconciling with the server transcript and auto-retry (the host and `lib/state`; P4.3's non-goal "no offline queue engine changes").
- Deciding per-item actions and their confirm-or-Undo treatment (the host, DATA-11).
- The composer's withdraw-to-draft and Undo (KitComposer's host and KitUndo; chat-3).

## Open questions

None.
