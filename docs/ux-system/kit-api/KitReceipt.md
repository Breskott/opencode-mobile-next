# KitReceipt — API freeze (wave 0)

Unit: `kit-KitReceipt` (wave 1, tier 1b, kind `kit-part`). Spec: kit-v2.md §1.16, §4.8, §4.9, with cut review C12 and C25 (depends on KitSince) and C24 (`team_receipt.dart` moves into this unit). Rules: STATE-5, STATE-10, AUTO-4, DATA-11, COPY-7, A11Y-3. The STANDARDS §0.5 example `read` for this unit is STATE-5, STATE-10, AUTO-4.

## Purpose

What happened to a write the phone sent (an answer, a message, a move, a stop, a merge, or an automatic action), shown in place as a mark and a word:

- sending;
- sent;
- confirmed;
- not confirmed yet, with Try again;
- refused, with the reason;
- answered elsewhere.

It also carries the automatic-action line (`KitAutoLine`, AUTO-4) with Undo.

## Replaces

- **Map elements, 3 on 3 pages (kit-v2.json `new[KitReceipt]`):**
  - `chat` (chat-note-receipt-dismiss);
  - `embedded-team-receipt-chip` (receipt);
  - `team-home-needs-you-tab` (receipt).
- **Widgets it absorbs:**
  - `TeamReceiptChip` in `lib/ui/widgets/team_receipt.dart:101` (G16: ActionChip 1, Icon 1, Text 1; 9 call sites in `run_screen.dart`, `activity_screen.dart`, `agent_screen.dart` ×2, `team_needs_you.dart` ×2, `team_conversation_view.dart` ×2, `team_cycle_strip.dart`). The file joins this unit's write set (C24) and its chip becomes a thin forwarding wrapper that maps `MutationStatus` to `KitReceiptState`.
  - The second `TeamReceiptChip` in `team_controls.dart:52` stays with shared-team-2, which makes it a wrapper over `KitReceipt` (C37).
  - The gate sheet's `_Receipt` goes with slice-P4.1c (C45).
  - The team conversation's sent line and the chat answers that have no receipt go to the chat chain.
- **Merged gap name:** `KitReceipt`, plus the automation-first vertical's `KitAutoLine`.

## File

- `lib/ui/kit/kit_receipt.dart` (`KitReceipt`, `KitReceiptState`)
- `lib/ui/widgets/team_receipt.dart`, a wrapper (C24). The kit never imports `lib/state/mutation_store.dart`; the wrapper does the mapping.
- Tests: `test/kit/kit_receipt_test.dart`
- Gallery: `test/goldens/kit/kit_receipt_golden_test.dart`

## Public API

```dart
enum KitReceiptState {
  sending,            // in flight
  sent,               // left the phone; no echo yet
  confirmed,          // the server echoed it
  notConfirmed,       // no echo in time, or the echo was lost: Try again
  refused,            // the server said no: the reason, in words
  answeredElsewhere,  // NEW vs K2: someone answered it on another device first
}

class KitReceipt extends StatelessWidget {
  const KitReceipt({
    super.key,
    required this.state,
    this.label,           // NEW: the words for the act, replacing the state word:
                          //   "Allowed once" (confirmed), "Restarted the phone's server" (automatic)
    this.reason,          // refused: the server's reason in plain words
    this.where,           // NEW, answeredElsewhere: "the laptop"
    this.at,              // the time of the latest transition: "10:42"
    this.since,           // NEW: when it was sent; sending/sent escalate after KitMotion.escalateAfter (8 s)
    this.onRetry,         // notConfirmed (and escalated sent): "Try again"
    this.onUndo,          // shown until at + KitMotion.undoWindow, only where the server allows it
    this.onTap,           // NEW: the receipt opens where the write lives (the gate sheet)
    this.automatic = false, // KitAutoLine: "Restarted the phone's server at 10:42 · Undo"
    this.retryKey,
    this.undoKey,
  });

  final KitReceiptState state;
  final String? label;
  final String? reason;
  final String? where;
  final DateTime? at;
  final DateTime? since;
  final VoidCallback? onRetry;
  final VoidCallback? onUndo;
  final VoidCallback? onTap;
  final bool automatic;
  final Key? retryKey;
  final Key? undoKey;

  /// A row's supporting line (like kitCurrentSpan): "Sent · ",
  /// "Not confirmed yet · ", "Not accepted: {reason} · ",
  /// "Answered on {where} · ". No actions: a row's actions live in its
  /// KitRowMenu or its sheet.
  static InlineSpan span(
    BuildContext context,
    KitReceiptState state, {
    String? reason,
    String? label,     // NEW
    String? where,     // NEW
  });
}
```

**Additions to K2 §1.16:**

- `answeredElsewhere` is in the task's scope ("answered elsewhere"), and it is the receipt KitSheet and KitRequestCard leave behind ("Answered on the laptop", §1.1, §2.1).
- `label` is needed because an automatic line must say what was done.
- `where` names the other device.
- `since` gives §4.9 escalation for a part that waits.
- `onTap` preserves TeamReceiptChip's "tap to open the sheet".

All are optional. The K2 constructor call shape is unchanged.

**Default words** (kit ARB, COPY-3, COPY-7):

| State | Word | Key |
|---|---|---|
| sending | Sending… | `kitReceiptSending` |
| sent | Sent | `kitReceiptSent` |
| confirmed | Done | `kitReceiptConfirmed`; `label` overrides it with the act ("Allowed once") |
| notConfirmed | Not confirmed yet | `kitReceiptNotConfirmed` |
| refused | Not accepted | `kitReceiptRefused`; the existing team word, with ": {reason}" |
| answeredElsewhere | Answered on {where} | `kitReceiptAnsweredElsewhere` |
| time | at {time} | `kitReceiptAt` |
| actions | Try again, Undo | `kitTryAgain` (exists), `kitUndoAction` (KitUndo.md) |

## States

| State | Mark | Word | Actions |
|---|---|---|---|
| sending | a small working ring (still dot under reduced motion) | Sending… | none |
| sent | a check in `text2` | Sent | none; after 8 s since `since` it shows as not confirmed |
| sent, escalated (≥ 8 s) | the warning glyph in `text1` | Not confirmed yet | Try again (`onRetry`) |
| confirmed | a check in `success` | Done, or `label` | Undo while inside the window |
| notConfirmed | the warning glyph in `text1` | Not confirmed yet | Try again |
| refused | the neutral error glyph in `text1` | Not accepted: {reason} | none (the caller may offer an edit elsewhere) |
| answeredElsewhere | a check in `text2` | Answered on {where} | none |
| automatic | the check in `success`, or the state's mark | {label} at {time} | Undo while inside the window |

- It is interactive only through its actions and `onTap`. There is no disabled state (a receipt with no possible action shows none).
- It is not a data list, so loading, empty and error are the states above.
- KIT-12 doc comment: "States: sending, sent, confirmed, not confirmed, refused, answered elsewhere, automatic (working = sending; answered = confirmed / answeredElsewhere)".
- **"Sent" is never "Done"** (STATE-10). Confirmed needs the server's echo, which is the caller's state.

## Tokens

- **ThemeRoles:**
  - `accent` (sending ring);
  - `success` (confirmed check; LOOK-6);
  - `text2` (sent and answered-elsewhere check, the time);
  - `text1` (warning and error glyphs and their words; LOOK-4/5: no amber, no red);
  - words in `text2`, and in `text1` for notConfirmed and refused.
- **KitText:** `secondary` (word and time), `button` (actions, through `KitButton` tertiary).
- **KitTokens:** `smallIconSize` (20; LOOK-33 allows only 20/22/24), `space1`, `space2`, `minTarget`.
- **Tone map:** the shared pre-wave `KitTokens.toneFor` / `toneColor` (`_new-tokens.md`). No other new tokens: there is no chip, pill or border (K2: "no chip or card").

## Adaptive

- **All classes:** inline, as wide as its words, wrapping. The actions follow the words on the same line when they fit, and otherwise go under them, start-aligned. The span form sits in a row's supporting line in any class.
- **expanded / large:** no layout change. In twoPane it stays where the write was made.
- **Pointer and keyboard:**
  - Try again and Undo are Tab-reachable, and Enter and Space activate them;
  - `onTap` makes the receipt one button (focus ring, Enter);
  - hover only highlights.

## Accessibility

- **One live region:** each transition is announced exactly once ("Sent", "Done", "Not confirmed yet"). A rebuild with the same state never re-announces (A11Y-3).
- **Actions:** Try again and Undo are 48 dp tertiary actions (LAY-9), with 8 dp between them.
- **Semantics:** "{word}[, {reason}][, at {time}]". The mark is excluded, because the word already says it.
- **200 % text:** the words wrap and are never truncated. The actions drop under them.

## RTL

- The mark sits at the start. `reason`, `where` and `label` are wrapped with `KitBidi.auto` (COPY-30), and the time comes from `intl`.
- The Undo and forward glyphs, if any, mirror (LAY-8). The check does not.

## Motion and haptics

- The mark cross-fades on `KitMotion.quick`. The words change in place. The Undo action fades out when the window closes.
- **Reduced motion:** instant, and the sending ring is a still dot.
- **Haptics:** none. The send tick fired when the person sent (K2 §1.16, MOT-11).

## Data safety and honest state

- **Escalation:** a receipt that waits (sending or sent with `since`) turns into "Not confirmed yet" with Try again after 8 s (K2 §1.16, STATE-5, STATE-10). The timer is `KitSince`'s, so one fake clock drives the tests.
- **Undo:** shown only when `onUndo` is given, and only until `at + KitMotion.undoWindow` (8 s, pre-wave). It follows DATA-11: offered only where the server exposes an inverse. The caller decides that and passes null otherwise.
- **Undo failure:** if the Undo fails, the caller shows a `KitNotice` error where the thing was (K2 §1.17 rule, applied here). The receipt returns to its previous state.
- **The wrapper keeps meaning:** `TeamReceiptChip` today hides the chip for `confirmed` and for a gate never answered here. It keeps returning an empty box in those cases, so screens do not suddenly grow "Done" words before their own units adopt the receipt. It maps:
  - `sent` → sent;
  - `unconfirmed` → notConfirmed with `onRetry: onOpen`;
  - `rejected` → refused;
  - `onTap: onOpen`.

  Its semantics label `teamUiGateAnswerChipUnconfirmedSemantics` is kept.

## Depends on

- **kit-KitSince** (C25).
- **Existing:** `KitButton` (tertiary), `KitAction`.
- **Pre-wave:** `KitMotion.escalateAfter`, `KitMotion.undoWindow`, `KitBidi`.

Depended on by: KitChoiceList, KitRequestCard-v2, KitTaskCard, KitQueuedMessage (C25).

## Tests required

In `test/kit/kit_receipt_test.dart`, using KitSince's fake clock:

1. **Every state:** each state renders its word and mark. `sent` never renders "Done" (a finder for the confirmed word is absent).
2. **Escalation:** `sent` with `since` 7 s ago stays "Sent". At 8 s it shows "Not confirmed yet" and Try again, and one announcement fires. `confirmed` never escalates.
3. **Announcements:** the transitions sending → sent → confirmed produce exactly three announcements. Rebuilding with the same state produces none.
4. **Undo window:** Undo is visible at `at + 7 s` and gone at `at + 8 s`. Tapping it calls `onUndo` once.
5. **refused** with a reason renders "Not accepted: {reason}". **answeredElsewhere** with `where: 'the laptop'` renders "Answered on the laptop".
6. **Automatic:** `automatic: true` with `label`, `at` and `onUndo` renders "{label} at 10:42 · Undo".
7. **The span:** `KitReceipt.span` produces the same words, with no actions.
8. **The wrapper:** `TeamReceiptChip` keeps its behaviour. Confirmed and never-answered render nothing, unconfirmed shows Try again, and tapping calls `onOpen`. The existing team tests (`test/team_gate_answer_test.dart`) pass by behaviour, and any look-level finder changes are listed under TEST-19.
9. **Reduced motion:** `sending` shows the still dot and settles after one `pump()` (G8).

## Galleries required

`test/goldens/kit/kit_receipt_golden_test.dart`, DPR 3, Android platform. Receipts are shown under a card stub and in `KitRow` supporting lines.

- **Declared states × dark and light at 412×915:**
  - sending;
  - sent;
  - not-confirmed (escalated);
  - confirmed (with label and Undo);
  - refused;
  - answered-elsewhere;
  - automatic;
  - span-in-rows.
- **Default (confirmed)** × dark and light at 360×800, 915×412, 800×1280, 1280×800 and 1600×1000.
- **Text 2.0 and Arabic** (not-confirmed, answered-elsewhere) at 412×915 and 1280×800.
- **Names:** `kit_receipt_<state>…png`.

## Non-goals

- The write itself, the mutation store, and retry logic (the caller's `onRetry`).
- The request card's collapse to an answered row (KitRequestCard-v2 uses this part).
- No screen adoption beyond the forwarding wrapper in `team_receipt.dart`.

## Open questions

None.
