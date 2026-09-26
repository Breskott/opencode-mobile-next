# revamp-kit-KitQueuedMessage: KitQueuedMessage (2026-09-27)

## 1. Scope

- Unit: `kit-KitQueuedMessage` (wave 1, kit tier 3). Finish line: everything waiting to reach the agent renders as one end-aligned prompt-style bubble with each message's honest state, a per-item menu and one action line, to the frozen API in `docs/ux-system/kit-api/KitQueuedMessage.md`. Non-goal: rendering it in `message_view.dart` or the composer (chat-1 / chat-3, wave 2c), and any queue engine change.
- Files changed: `lib/ui/kit/chat/kit_queued_message.dart` (new), `lib/l10n/app_en.arb` (+10 `kitQueued*` keys) and the generated `lib/l10n/app_localizations*.dart`, `test/kit/kit_queued_message_test.dart` (new), `test/goldens/kit/kit_queued_message_golden_test.dart` (new) and its 20 PNGs, this record.
- Pages (map ids): `embedded-pending-sends-strip#pending-bubble` (kitGap KitQueuedMessage) — the part only; the page migrates in chat-1/chat-3.
- Specs followed: STANDARDS.md STATE-17, STATE-10, STATE-5, DATA-11, KIT-28, A11Y-3, A11Y-5, LOOK-5, LOOK-23, LOOK-26, MOT-5; kit-v2 §9.2, §5; KitQueuedMessage.md.
- Contract problems (PROC-20):
  1. **Action text colour.** KitQueuedMessage.md "Action line" says the action is "a tertiary KitButton in `accent` text (LOOK-23 tertiary)". LOOK-23 says "tertiary is text in text2", and KIT-8 says a caller never styles a button. The part uses `KitButton.fromAction(role: tertiary)` unstyled, so the words are `text2`. Proposed spec text: "`action` as a tertiary `KitButton` (LOOK-23: text2)". Blocks nothing.
  2. **`KitReceipt.span` carries a trailing " · ".** The span is built as a prefix for a row's supporting line ("Sent · 2 min ago"); the bubble's state line stands alone. The part keeps KitReceipt's words and colour and drops the trailing separator. Proposed: KitReceipt.md gains a `trailingSeparator` flag (default true), or KitQueuedMessage.md says the separator is dropped. Blocks nothing.
  3. **`reachedServer` as "a receipt `sent` with that label".** `KitReceipt.span` uses `label` only for a confirmed write (STATE-10), so a `sent` span with a label still reads "Sent". The part shows `kitQueuedReachedServer` ("Reached the server") in `text2` directly. Proposed: KitQueuedMessage.md says "the words `kitQueuedReachedServer`" and drops the receipt reference. Blocks nothing.
  4. **All-waiting head line casing.** The spec shows "Waiting to send · {count} · sends when you're back online" but the frozen key `kitQueuedOffline` is "Sends when you're back online"; the part joins the two keys, so the head reads "… · Sends when you're back online". Blocks nothing.
  5. **Tap on an item.** The spec names long-press, right-click, Shift+F10 and the Menu key; KitTappable needs an `onTap` for its menu to work. The part makes a tap (and Enter) open the item's menu anchored to the item. Proposed: KitQueuedMessage.md adds "a tap opens the same menu".
- New kit parts (KIT-3): `KitQueuedMessage` (with `KitQueuedItem`, `KitQueuedState`) in `lib/ui/kit/chat/kit_queued_message.dart`. Not exported from `kit.dart` (R06: integrator).
- Map items (EVID-11): `embedded-pending-sends-strip`: "more than 3 queued: the third bubble is cut by the composer" → done: test 4 (ten items, no cap, no internal scroll); "sending progress per item" → done: test 3 and `kit_queued_message_sending`/`_mixed` goldens; "outlined red box per message, right-aligned, overlaps the composer" → done: test 2 (no border, no danger, surface2) and every gallery shot.
- States per page (STATE-20): waiting → `kit_queued_message_offline`, test 3; sending → `_sending`, test 3; sending slow → test 3 (fake clock, 8 s); notConfirmed → `_not_confirmed`, test 3; reachedServer → `_mixed`, test 3; failed → `_failed`, test 3; afterThisReply / addToThisTurn → `_after_reply`, test 3; contextUpdate → `_mixed`, test 3; mixed → `_mixed`; empty → test 1.
- Deferred states (STATE-21): none.

## 2. Builds

- Branch `revamp/kit-KitQueuedMessage`, base `024e97b0`, code head: see `git log -1 revamp/kit-KitQueuedMessage`.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 1 checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only | n/a: a new part | n/a | n/a |
| 2 | `test/kit/kit_queued_message_test.dart` | passes | 14 passed (`run-behaviour.txt`) | PASS |
| 3 | `test/goldens/kit/kit_queued_message_golden_test.dart --update-goldens` (G4 + G5 in both themes) | passes | 20 passed (`run-gallery.txt`) | PASS |
| 4 | `flutter analyze` on the part and both test files | no issues | no issues | PASS |
| 5 | Ratchet, design-standard, l10n, glossary, ledger tests | not run | owner decision 2026-09-27 (speed): only the unit's own files | NOT RUN |

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test (`file` + `--plain-name`) or golden | Output |
  |---|---|---|
  | STATE-17 | `test/kit/kit_queued_message_test.dart` "2. three items" and "5. per-item menu" | `run-behaviour.txt` |
  | STATE-5, STATE-10 | "3. each state shows its words" (sending escalates at 8 s; reachedServer has no Try again) | `run-behaviour.txt` |
  | LOOK-5 | "2. three items" (no border, no `danger`) | `run-behaviour.txt` |
  | KIT-28 | "5. per-item menu" (no KitIconButton / IconButton) | `run-behaviour.txt` |
  | A11Y-5 | "5. per-item menu" (menu items are custom actions) | `run-behaviour.txt` |
  | A11Y-3 | "9. semantics" (not a live region) | `run-behaviour.txt` |
  | DATA-11 | "8. the part never calls back on its own" | `run-behaviour.txt` |
  | MOT-5 | "7. arrivals and departures" | `run-behaviour.txt` |
  | G6 | "11. 200 % text at 320 dp" (ltr and rtl) | `run-behaviour.txt` |

- Changed test expectations (TEST-19): none.
- Goldens changed (each opened and looked at): 20 new PNGs, `test/goldens/kit/kit_queued_message_{offline,sending,not_confirmed,failed,after_reply,mixed}_{dark,light}.png`, `kit_queued_message_default{,_1280x800,_text2,_text2_1280x800}_{dark,light}.png`. The bubble sits at the end edge at 85 % of the pane, surface2, 6 dp bottom-end tail, hairlines between items, two-line preview with ellipsis, action line inside. No approved render exists for this new part.
- Before and after: n/a — the old `_PendingSendsStrip` is replaced at its call site in chat-1.
- Accessibility: bubble is one container labelled by its head line; each item is one node labelled `kitQueuedItemLabel` (with attachment count); item menus are custom actions and Tab stops; actions ≥ 48 dp, 8 dp apart (Android tap-target guideline passes); 200 % text at 320 dp does not overflow. Arabic dropped (owner decision 2026-09-27).
- Privacy and security: n/a — no credentials, stored data, links or notifications; the part never sends or deletes.
- Migration: n/a: no stored format changed.

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/kit/kit_queued_message_test.dart
$F test -j 1 test/goldens/kit/kit_queued_message_golden_test.dart
$F analyze lib/ui/kit/chat/kit_queued_message.dart test/kit/kit_queued_message_test.dart test/goldens/kit/kit_queued_message_golden_test.dart
```

## 7. NOT proven

- Not run on a device or emulator.
- Not rendered in the conversation (chat-1) or wired to the composer's withdraw-to-draft (chat-3).
- Shared gates (ratchet, design-standard, l10n coverage, manifest) not run by this unit (owner decision 2026-09-27). The Arabic ARB has no `kitQueued*` entries (Arabic dropped), so `app_localizations_ar.dart` falls back to English for them.
- Keyboard Tab order checked with Linux desktop capabilities in a test only.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes | `revamp/kit-KitQueuedMessage` |
| Enabled | No: no screen renders it until chat-1 | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
