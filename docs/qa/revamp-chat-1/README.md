# revamp-chat-1: Chat parts: messages, markdown and the work line (2026-09-27)

## 1. Scope

- Unit: `chat-1` (wave 2c, tier 1, screen-revamp on the chat chain). Finish line: `lib/ui/screens/chat/message_view.dart` draws the transcript from kit parts only (KitTurn, KitMessage, KitWorkLine, KitQueuedMessage, KitNotice, KitJumpPill) with a G1/G16/G7/G2/G17/G21 count of zero, in the approved look, following the turn model. Non-goal: no gateway call, controller field or persistence added; `chat_screen.dart`'s list builder, the host's action sheet and `tool_card.dart` (chat-2) are not rebuilt here.
- Files changed:
  - `lib/ui/screens/chat/message_view.dart` (rebuilt)
  - `lib/ui/kit/chat/kit_turn.dart` (additive: `KitTurnSegment`, `KitTurn.segment`, `KitTurnFooter.onMore`, `KitTurnFooter.copyLabel`)
  - `lib/ui/kit/chat/kit_markdown.dart` (one numeric padding literal removed, G21 0)
  - `lib/ui/screens/chat_screen.dart`: **one line outside the write set**, the `info_label.dart` import that became unused when the reasoning block stopped using `InfoLabel` (without it `flutter analyze` warns). Flagged for the integrator.
  - `lib/l10n/app_en.arb` + generated `app_localizations*.dart` (2 new keys, en only per the owner's 2026-09-27 decision)
  - tests: `test/revamp/chat_1_test.dart` (new), `test/chat_transcript_lens_test.dart`, `test/chat_transcript_placement_test.dart`, `test/pending_sends_strip_test.dart`, `test/v2_transcript_rows_test.dart`, `test/goldens/chat_states_golden_test.dart` (+ its PNGs)
  - `kit_message.dart`, `kit_work_line.dart`: read and used as they are; no change needed (their G counts were already 0).
- Pages (map ids): `embedded-message-view` (proposal fix), `embedded-pending-sends-strip` (proposal redesign; P4.3 acceptance brings the one-bubble form now).
- Specs followed: STANDARDS STATE-16, KIT-41, KIT-23, KIT-28, KIT-33, LOOK-5, LOOK-24, LOOK-26, AUTO-15, MAP-1; kit-api KitTurn, KitMessage, KitWorkLine, KitQueuedMessage, KitMarkdown; visual-language §5 (Transcript), canvas `docs/design/visual-language-2026-09-26/Chat.png`.
- Contract problems (PROC-20):
  1. KitTurn.md assumes the host hands one KitTurn a whole turn, but the chat list is virtualised one server message per row and the list builder lives in `chat_screen.dart` (not chat-1's). Resolved additively in `kit_turn.dart`: `KitTurnSegment {whole, first, middle, last}` — each row draws its part of the turn, no section gap inside a turn, phase line and footer only on the part that ends it. Proposed text for KitTurn.md: add the `segment` parameter as written in the code.
  2. KitTurnFooter has no way to reach the host's existing reply-actions sheet (read aloud, revert, delete live there until chat-2/the host move them to KitMenu). Added `onMore` (More calls it; long-press still shows Copy + `menu`) and `copyLabel` (the host's honest words: "Copy reply so far", "Copy loaded reply"). Both optional, both default to today's behaviour.
  3. KitMessage.prompt/reply/thought take a `KitMarkdown`, but the chat library cannot build a KitMarkdown with the agent blocks (```choices```) and the code reader: `agent_blocks.dart` and `reader_preferences.dart` are not imported by `chat_screen.dart`, and the reader page is private to `markdown.dart`. The reply's prose therefore goes through `MarkdownText` (the app's KitMarkdown adapter, built only from kit parts) inside the turn, with KitMessage.reply's look (start edge, no frame, reading-width cap). Prompts, thoughts and notices use KitMarkdown directly. Proposal: a public `MarkdownText.kit(...)` factory returning the wired KitMarkdown, owned by the markdown file's unit.
- New kit parts (KIT-3): none (only additive members of KitTurn).
- Map items (EVID-11):
  - embedded-message-view · statesMissing "expanded work group repeats its own summary line" → done: KitWorkLine never repeats the chip as a first row; nested `_ToolCallGroup` folds removed (one indent level). `test/chat_transcript_placement_test.dart` "a one-line thought titles the tool run that follows it".
  - embedded-message-view · statesMissing "waiting-for-you turn still shows 'Running tools'" (P7.5) → done: `test/revamp/chat_1_test.dart` "P7.5: work blocked on a permission says "Waiting for you"…".
  - embedded-message-view · statesMissing "a turn interrupted by server loss has no end marker" → done: `test/revamp/chat_1_test.dart` "a reply the connection dropped says so at its end".
  - embedded-message-view · rationale "kit error icon" → done: KitNotice with the kit's one error glyph for every kind (golden `chat_model_error_*`).
  - embedded-message-view · rationale "quieter per-turn footer (latest reply only)" → done: the footer's model/time/usage words only on the newest turn (KitTurn.latest); older turns keep Copy and More only.
  - embedded-message-view · rationale "KitMotion/KitReveal instead of AnimatedSize" → done: no size animation left in the file (folds fade in, MOT-5).
  - embedded-message-view · P8.3 "chat error details can be copied" → done: "Error details" opens `showKitTechnicalDetails` with Copy all; `test/revamp/chat_1_test.dart` "P8.3…".
  - embedded-message-view · actionsMissing "Retry a failed turn", "Edit and resend a prompt" → deferred: both need a host action (resend/edit a prompt) that `chat_screen.dart` does not expose to this file; the prompt menu shows exactly the host's actions. Owner: chat chain unit that owns `chat_screen.dart` actions (no id in this unit's inputs).
  - embedded-message-view · rationale "project-derived starters" → deferred: lives in `empty_chat.dart`, not in this write set.
  - embedded-pending-sends-strip · P4.3 "Waiting to send · N" bubble → done: `test/pending_sends_strip_test.dart` "the strip shows offline drafts and server inbox items in one list".
  - embedded-pending-sends-strip · statesMissing "more than 3 queued: the third bubble is cut by the composer" → done: one bubble, scrolls inside a cap of 40 % of the window height (KitLayout.composerMaxShare).
  - embedded-pending-sends-strip · statesMissing "sending progress per item" → done: each item carries its KitReceipt state (sending → not confirmed after 8 s).
  - embedded-pending-sends-strip · actionsMissing "retry all" → partial: the bubble's action "Send this message again" when exactly one send is unconfirmed; with several, each item's menu has it. A true batch retry needs a host batch-resend with one confirmation (today each resend confirms). "discard all", "reorder" → deferred (reorder: the server has none; discard all needs a host batch with one confirmation). Owner: the redesign slice for this page.
  - embedded-pending-sends-strip · a11y "icon-only actions without labels" → done: actions are named menu items on each item (KitTappable + KitMenu, custom semantics actions).
- States per page (STATE-20):
  - embedded-message-view: loaded → golden `chat_transcript_*`; working → `test/revamp/chat_1_test.dart` P7.5 (running, then waiting for you); model-error → golden `chat_model_error_*`; interrupted → chat_1 test; stopped → `test/revamp/chat_1_test.dart` KitTurn segments; empty/loading/load error → goldens `chat_empty_*`, `chat_loading_*`, `chat_load_error_*` (host-drawn).
  - embedded-pending-sends-strip: waiting, sending, not confirmed, reached server, failed, after this reply, adds to this turn → `test/pending_sends_strip_test.dart` + the KitQueuedMessage galleries.
- Deferred states (STATE-21): none beyond the actions above.

### Moved or removed (owner rule 2026-09-27, rethink)

- The per-message ⋯ disc and copy disc → the turn's one footer (KitTurn): Copy ("Copy reply" / the host's "Copy reply so far") and More, only on the message that ends a turn.
- The model/time/usage line on every finished turn → only on the newest turn.
- Pending-send inline icon buttons (resend, edit, discard, steer/queue, cancel) → each item's menu, named for what they do ("Send this message again", "Edit draft", "Discard draft", "Send now and steer instead", "Wait for this run instead", "Cancel and return to the composer").
- The marker's hover-only detail (previous model, full path of a move) → removed: never reachable on touch; the marker says what it switched to.
- The streaming tint on the newest prose → removed (not in the visual language; the work line and composer say it is live).
- The per-kind error icons (brain, key, …) → the kit's one error glyph; "Continue" → "Continue this reply"; "Details" → "Error details".
- The reasoning block's inline short form and its "Reasoning ⓘ" glossary label → one fold titled by the thought's first line ("Thinking…" while it thinks).
- The copy-choice snackbar in isolated previews → KitCopy ("Copied", no snackbar).

## 2. Builds

- Branch `revamp/chat-1`, base `da6a2a2f` (feat/phone-setup-v2), code head: see the branch's last commit.
- No APK (unit agents do not build).

## 3. Devices

None: tests, goldens and renders only. Device proof is in the wave 2c checkpoint record.

## 4. Runs

| # | Step | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | Fixes only: the fix's test on the base | fails | not re-run on the base (owner decision 2026-09-27: no time on tests); the P7.5 and interrupted assertions name words the base never draws | NOT RUN |
| 2 | `test/revamp/chat_1_test.dart` | passes | 5 passed | PASS |
| 3 | `test/pending_sends_strip_test.dart` | passes | 16 passed | PASS |
| 4 | `test/v2_transcript_rows_test.dart` | passes | 20 passed | PASS |
| 5 | `test/chat_transcript_lens_test.dart` + `test/chat_transcript_placement_test.dart` | pass | 28 passed | PASS |
| 6 | `test/goldens/chat_states_golden_test.dart --update-goldens` | regenerated, looked at | 22 passed | PASS |
| 7 | `test/kit/kit_turn_test.dart` + `test/kit/kit_markdown_test.dart` (the parts this unit changed) | pass | 37 passed | PASS |
| 8 | `test/kit_ratchet_test.dart` with `KIT_RATCHET_WRITE=1` (baseline restored afterwards, not staged) | message_view.dart absent from every gate; kit chat files at 0 | message_view.dart 0 in G1/G2/G7/G16/G17/G21; kit_markdown.dart G21 0 after the fix | PASS |
| 9 | `flutter analyze` on chat_screen.dart, chat/, kit/chat/ and the changed tests | no issues in changed paths | no issues | PASS |

Other shared suites were not run (owner decision). Shared tests that reference changed keys are listed in the build record's `sharedTestsBroken`.

## 5. Evidence

- Rule evidence (PROC-31):

  | Rule | Test or golden | Output |
  |---|---|---|
  | AUTO-15 / P7.5 | `test/revamp/chat_1_test.dart` "P7.5: work blocked on a permission…" | run 2 |
  | KIT-33 / P8.3 | `test/revamp/chat_1_test.dart` "P8.3: a chat error opens its server words, and they copy" | run 2 |
  | STATE-16 (one footer, running turn has none) | `test/chat_transcript_placement_test.dart` "a running turn has no footer…" | run 5 |
  | STATE-17 / P4.3 | `test/pending_sends_strip_test.dart` "the strip shows offline drafts…" | run 3 |
  | LOOK-26 (prompt bubble) | `test/chat_transcript_placement_test.dart` "a prompt is an end-aligned bubble…"; golden `chat_transcript_*` | runs 5, 6 |

- Changed test expectations (TEST-19):
  - lens "collapsing a running tool group": `tool-call-group-header` → `work-group-header` (KitWorkLine replaces the nested group fold; STATE-16).
  - lens "assistant prose is selectable": `SelectableText` → `KitSelectable` (KitMarkdown's selection).
  - lens "a prompt carries no control row": host sheet keys `message-action-*` → the bubble's KitMenu keys `message-menu-*` (KitMessage.prompt menu, KIT-28).
  - lens "an unfinished assistant reply…": long-press moved past the end of the prose line (the words are selectable).
  - lens "tool groups report skipped steps": "Read 1 file, 1 step was not run" → "Read 1 file · 1 not run" (KitWorkLine words); no status mark instead of the old semantics wording.
  - placement "a one-line thought titles the tool run": the heading shows once the work line is opened; the closed chip says what was done.
  - placement "a prompt is a ruled line, not a bubble" → "a prompt is an end-aligned bubble; the reply has no frame" (Appendix A #47, LOOK-26).
  - pending strip: status words → KitQueuedMessage's ("Waiting to send", "Sends after this reply", "Adds to this turn"), actions reached through the item's menu.
  - v2 rows: marker tooltips removed; location glyph `AppIconography.folderOpen`.
- Goldens changed (each opened and looked at):
  - `test/goldens/chat_transcript_{dark,light}.png`, `chat_transcript_1280x800_{dark,light}.png` (new): prompt bubble at the end edge, "Read 3 files · edited 1 file" chip, reply prose, footer. Matches `Chat.png` except the host's 6 dp list gutter (chat_screen.dart, not this unit).
  - `chat_model_error_*`: the error is a KitNotice with the kit error glyph and tertiary "Choose model" / "Error details"; the prompt is a bubble.
  - `chat_permission_*`, `chat_permission_sheet_*`, `chat_disconnected_*`, `chat_notify_*`, `chat_send_error_*`: prompt bubble and prose look.
  - `chat_empty_*`, `chat_loading_*`, `chat_load_error_*`: small pixel changes in regions this unit does not draw (the empty-state drawing); the goldens were stale against the base.
- Before and after: `before-message-view-turn-dark.png` → `after-message-view-turn-dark.png`; `before-message-view-model-error-dark.png` → `after-message-view-model-error-dark.png`; `after-message-view-transcript-dark.png`.
- Accessibility: the prompt is one semantics node "You said, …" with its menu as custom actions; the work line chip reads "Waiting for you, …" / "Working, …"; footer buttons are 48 dp KitIconButtons with tooltips; queued items are named menu buttons. 200 % text and Arabic not re-checked here (Arabic dropped by the owner; the parts' own galleries cover 200 %).
- Privacy and security: error details are redacted by the kit before they are shown or copied (KitReportHook.redact in showKitTechnicalDetails); no links, storage keys or notifications changed.
- Migration: n/a: no stored format changed (the expansion store keys `work:`, `tool:`, `reasoning:` are unchanged).

## 6. How to reproduce

```bash
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F test -j 1 test/revamp/chat_1_test.dart test/pending_sends_strip_test.dart
$F test -j 1 test/v2_transcript_rows_test.dart test/chat_transcript_lens_test.dart test/chat_transcript_placement_test.dart
$F test -j 1 test/goldens/chat_states_golden_test.dart
$F analyze lib/ui/screens/chat_screen.dart lib/ui/screens/chat/ lib/ui/kit/chat/
```

## 7. NOT proven

- Not run on a device or emulator.
- The full suite, the design-standard, l10n-coverage, glossary and ledger tests were not run (owner decision 2026-09-27).
- The "interrupted" end line relies on `busySessions` being cleared when a server stops working on a session; a server that never reports idle after a drop would keep the turn "running".
- The fix tests were not run against the base.

## State

| State | Yes/No | Where |
|---|---|---|
| Implemented | Yes (retry-a-turn, edit-and-resend, batch retry/discard deferred) | `revamp/chat-1` |
| Enabled | Yes | |
| Verified | tests and goldens only | this record |
| Committed | Yes | branch head |
| Deployed | No | |
| Released | No | |
