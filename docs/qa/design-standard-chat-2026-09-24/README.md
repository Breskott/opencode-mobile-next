# The chat's states and banners on the design kit (2026-09-24)

## Scope

Spec: [`docs/design/design-standard.md`](../../design/design-standard.md), migration
step 5 ("Chat states: empty, errors, permission"), after steps 1-2
([work-tab-cleanup-2026-09-24](../work-tab-cleanup-2026-09-24/README.md)). The owner's
complaint: "every screen looks different and adhoc".

In scope: the empty conversation, the loading of a conversation, errors (a conversation
that could not load, a message that was not sent, a prompt the server refused, the model
error a reply carries), the connection inside a chat, the permission, question, form and
retry cards above the composer, the permission sheet, the "notify me when a reply is
ready" question, and the chat-level banners (staged revert, subagent context, sharing).
Not in scope: the transcript's message rendering (turn model, `markdown.dart`,
`tool_card.dart`), which is unchanged.

### Kit additions (`lib/ui/kit/`, new files, exported from `kit.dart`)

| Part | Standard | What it is |
|---|---|---|
| `KitSkeletonTranscript` | §4 | placeholder turns (a prompt block and reply lines) at the bottom of a loading conversation; no words, no motion, excluded from semantics; in a short space it clips at the top instead of overflowing |
| `KitRequestCard` | §2, §3 | a request the person answers above the composer: icon (accent, or a tone), one-line title (announced), mono summary, muted detail, optional body (option rows), actions in the one hierarchy through `KitActionBlock`; keeps the raised shadow the design reserves for floating surfaces |
| `KitAskLine` | §2 | a one-time question on a working screen with both answers in view (decline muted, accept); the answers move under the question when both do not fit; the question is two lines at most |

Additive changes to existing kit files (no behaviour change for the Work tab or the
connection screen): `KitAction.working` (a button's own tap in flight, passed through
`KitButton.fromAction`); `KitStatusLine.supporting` (+ key and semantics label, one
muted sentence under the message) and `dismissTooltip`.

### What changed

| # | State | Before | After | Where |
|---|---|---|---|---|
| 1 | Loading a conversation | six list-row skeletons (`LoadingList`) under the app bar | the screen's one 2 dp loading bar under the top bar (labelled "Loading the conversation") and placeholder turns at the bottom, where the first message lands | `chat/chat_states.dart` `_ChatLoadingBody`; `chat_screen.dart` `KitLoadingBar` |
| 2 | Could not load | centred red icon, the raw error as the title, a tonal "Try again", "Report a bug" | `KitStateView` page: "Couldn't open this conversation", "Nothing is lost. Try again when OpenCode answers.", full-width Try again, Report a bug (tertiary), the raw error under Details | `_ChatLoadError` |
| 3 | A message was not sent | a red snackbar with the raw error, gone after a few seconds | the status line: "Your message wasn't sent" + the plain reason, Details when the reason was reworded, dismiss; it stays until dismissed or the next send; the text is back in the box (unchanged) | `_sendErrorStatus`; `_send` sets `_sendError` |
| 4 | A prompt the server refused | a red container (error-container fill) with its own buttons, below the connection banner | the status line, failure tone: the plain sentence, the hint, Choose model (model not found) or Details, Details under More when both, dismiss | `_promptErrorStatus` (replaces `_PromptErrorBanner`) |
| 5 | The model error a reply carries | text buttons right-aligned in their own row, Details before the fix | kit tertiary buttons, start-aligned under the words, the fix first; Details alone stays at the end of the sentence's line | `message_view.dart` `_ErrorActionCard` |
| 6 | Disconnected / reconnecting | a `MaterialBanner` at once for any state that was not connected, with a spinner while reconnecting, Try again + Details, two lines | the Work tab's rule and words: while reconnecting only the loading bar; after 8 s, or at once when nothing is reconnecting, "Laptop isn't answering" / "OpenCode on this phone isn't answering" with Try again (Restart, confirmed, for the phone's own server) and Details under More; queued drafts said under it; a rejected password or token says so at once with its fix | `_ChatStatusLine` |
| 7 | Banners | up to three strips stacked (connection, then prompt error or subagent or share, then staged revert), each drawn differently | one status line, most urgent first: connection, a message not sent, prompt error, staged revert, subagent context (Open parent conversation; the siblings under More), sharing (the link, Stop sharing; Copy under More) | `_ChatStatusLine.others` |
| 8 | Permission card | card with "Review" as a right-aligned filled chip | `KitRequestCard`, Review the full-width primary | `attention_card.dart` |
| 9 | Question card | Send and More right-aligned; "Sending" as a spinner row | Send the full-width primary (its own spinner while the answer is on its way), More a start-aligned tertiary | `attention_card.dart` |
| 10 | Form and retry cards | a separate hand-built card with a tonal Answer; the retry card on the old frame | both `KitRequestCard` (form: Answer primary; retry: attention tone, no buttons) | `attention_card.dart` (`_FormRequestCard` moved here from `chat_screen.dart`) |
| 11 | Permission sheet | Reject and Allow once side by side, Always allow centred; "Send rejection" a red tonal fill; the always-allow dialog's buttons right-aligned | Allow once (primary), Reject (secondary), Always allow (tertiary, start) stacked full width; Send rejection a destructive secondary with Back under it; the dialog's confirm full width with Keep asking under it; 16 dp rails | `chat/permission_sheet.dart` |
| 12 | Notify me | a hand-built row with two text buttons | `KitAskLine` (same words, same keys, same answers) | `widgets/first_reply_notify_card.dart` |
| 13 | Empty conversation | 20 dp side padding (12 for the starter row) | the standard's 16 dp rails; the design (project name, caret, facts, tip, starters) is kept | `chat/empty_chat.dart` |

The chat already rebuilds on every connection change; the status line adds no listener
of its own (it is built in that same pass, with a `GraceTimer` that keeps the 8 s clock
across rebuilds), so the streaming path gets no new rebuilds. The phone-server lookup
for Restart runs only when the "isn't answering" line is about to show.

### Decisions where the standard left a choice

- **Disconnected at once when nothing is reconnecting.** The Work tab waits 8 s unless
  the last attempt failed with an error. In a chat a stream that is down with nothing in
  flight has no loading bar to say anything, so the line says it at once; while a
  reconnect is in flight the bar shows and the line waits 8 s.
- **The subagent context and sharing are status lines.** They were strips of their own;
  the standard allows one status line, so they are the lowest in its order and yield to a
  connection problem or an error. The share link stays visible (release-blocker test:
  the person sees what is shared) and Stop sharing stays one tap away.
- **A message that was not sent is a status line, not a snackbar.** The failure is a
  condition of the screen until the person acts; a snackbar left while they read it.
  The "notify me" question also waits while it shows.
- **Request cards keep a card.** §3 keeps cards for content the person works with; a
  permission or question is answered there. Their buttons follow §2.
- **The permission sheet's buttons stack.** The standard stacks buttons under 600 dp,
  so the sheet's action bar is taller (primary, secondary, tertiary).
- **Details for a prompt error goes under More when Choose model is shown** (one visible
  action per status line).

### Tests whose expectations changed with the standard

| Test | Change |
|---|---|
| `test/permission_sheet_test.dart` "ordinary permission decisions precede persistent access" | Allow once is above Reject and as wide, instead of beside it (§2 stacking) |
| `test/permission_sheet_test.dart` "a pending permission keeps its action label…" | reads the `FilledButton` inside the kit button |
| `test/chat_question_card_test.dart` "multi-select collects choices behind Send" | reads the `FilledButton` inside the kit button |
| `test/chat_live_events_test.dart` "child chat exposes parent and sibling navigation" | opens the status line's More before the sibling list |
| `test/chat_live_events_test.dart` "offline chat keeps its transcript…" | "OpenCode isn't answering" (the Work tab's words) instead of "Connection lost"; Details under More |
| `test/chat_live_events_test.dart` "a model-not-found session error…" | Details under More (Choose model is the visible action) |

## Builds

- Branch `ds/chat` from `feat/phone-setup-v2` @ `dca366f1`: kit `7a625a0d`, chat
  `39226d37` (code, tests, goldens), this record after them. The session was killed by
  the machine running out of memory at 21:27; the work saved as WIP commit `3799960c`
  was split into these commits unchanged (the tested content is identical). No APK
  built.

## Devices

None. Widget tests and rendered images only (`flutter test`, pinned Shorebird Flutter
`91f8bd75076e9c740aa13cf67eb9ec1a093f68f5`, on the PC).

## Runs

| # | Step | Expected | Actual |
|---|---|---|---|
| 1 | Open a conversation whose history is held back | one `LinearProgressIndicator` (the 2 dp bar), placeholder turns, no `LoadingList`, no spinner; both gone when it arrives | PASS |
| 2 | History fails, then Try again | "Couldn't open this conversation"; the address only under Details; Try again loads the transcript | PASS |
| 3 | Send fails (503), wait 10 s, dismiss, send again failing, then succeeding | "Your message wasn't sent" + reason, no snackbar, text back in the box; still there after 10 s; gone on dismiss; back on the next failure; gone when a send goes through | PASS |
| 4 | Stream reconnecting: 0 s, 7 s, 9 s, connected | bar only / bar only / "Laptop isn't answering" + Try again / both gone | PASS |
| 5 | Prompt error, then the connection is lost, then back | one `KitStatusLine`: the error / the connection / the error again | PASS |
| 6 | Permission pending | `KitRequestCard`, Review full width inside it, one `FilledButton` | PASS |
| 7 | Permission sheet at 320x740, 1x and 2.5x text; pending reply; v1 and v2 reject; always-allow confirm | stacked, 48 dp targets, label kept while pending, confirm flow unchanged | PASS (`permission_sheet_test`, `chat_permission_test`) |
| 8 | Question card: single answer on tap, multi-select behind Send, custom answer, More, sending | as before, with kit buttons | PASS (`chat_question_card_test`) |
| 9 | Notify me: absent/present, Not now, Notify me, refusal, 320 dp at 2.5x (en, ar), compact | as before | PASS (`first_reply_notify_card_test`) |
| 10 | Empty conversation: facts, starters, caret, short windows (640x320 at 2x), keyboard | as before; no overflow | PASS (`chat_empty_start_test`) |
| 11 | Share, stop sharing (confirmed), link visible with its label | as before | PASS (`release_blockers_test`) |
| 12 | Drafts queued while offline | "1 draft queued to send on reconnect. 1 draft waiting for other servers." under the connection line | PASS (`offline_queue_test`) |
| 13 | `design_standard_test`: migrated files and classes use no raw progress, `Card(` or `FilledButton`; retired parts (`LoadingList(`, `ProductErrorState(`, `ConnectionStatusBanner(` in `chat_screen.dart`; the three old banner classes) do not come back; every golden exists | clean | PASS |
| 14 | Goldens: 9 chat states x dark/light at 412x915 | match | PASS (18) |
| 15 | Rows 1-6, the scan and the goldens against `dca366f1` (same test files) | fail | FAIL as expected: 6 of 6 behaviour tests, 2 of 6 scan tests, 18 of 18 goldens ([tests-without-fix.txt](tests-without-fix.txt)) |
| 16 | Every test file that imports a changed file (95 files, incl. the Work tab, connection card, goldens, glossary, l10n coverage) | pass | PASS: 1204 passed, 6 skipped ([tests-with-fix.txt](tests-with-fix.txt)) |

## Evidence

- `before-N-*.png` / `after-N-*.png`: the same state rendered by
  `tool/capture/chat_states_test.dart` on `dca366f1` and on this branch, 412x915, dark,
  real fonts: 1 empty, 2 loading, 3 could not load, 4 send error, 5 prompt error,
  6 model error in a reply, 7 permission card, 8 permission sheet, 9 question,
  10 reconnecting (2 s), 11 not answering (9 s), 12 lost, 13 notify me.
  `before-4` shows the red snackbar over the composer; `before-10` the spinner banner
  at once; `before-5` the error-filled block; `before-8` the side-by-side buttons.
- `test/goldens/chat_{empty,loading,load_error,send_error,model_error,permission,permission_sheet,disconnected,notify}_{dark,light}.png`:
  the reviewed renders the suite now holds the chat to.
- [tests-with-fix.txt](tests-with-fix.txt), [tests-without-fix.txt](tests-without-fix.txt).

## How to reproduce

```sh
F=~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter
$F pub get
$F test -j 3 test/chat_states_standard_test.dart test/design_standard_test.dart \
  test/goldens/chat_states_golden_test.dart test/permission_sheet_test.dart \
  test/chat_permission_test.dart test/chat_question_card_test.dart \
  test/first_reply_notify_card_test.dart test/chat_empty_start_test.dart \
  test/chat_live_events_test.dart test/offline_queue_test.dart test/release_blockers_test.dart
# Renders (after):
$F test --concurrency=1 tool/capture/chat_states_test.dart
# The old code: export it, add the new test files and goldens, run them.
git archive --format=tar -o /tmp/old.tar dca366f1 && mkdir /tmp/old && tar -xf /tmp/old.tar -C /tmp/old
cp test/chat_states_standard_test.dart test/design_standard_test.dart /tmp/old/test/
cp test/goldens/chat_* /tmp/old/test/goldens/
cp tool/capture/chat_states_test.dart /tmp/old/tool/capture/
(cd /tmp/old && $F pub get &&
  $F test --concurrency=1 --dart-define=CHAT_STATES_CAPTURE=before \
    tool/capture/chat_states_test.dart &&
  $F test test/chat_states_standard_test.dart test/design_standard_test.dart \
    test/goldens/chat_states_golden_test.dart)   # fail
# Goldens, deliberately:
$F test --update-goldens test/goldens/chat_states_golden_test.dart
```

## NOT proven

- Not viewed on a device: no emulator or phone run, no APK.
- Restart from the chat's "isn't answering" line runs the Work tab's existing restart
  paths (`phoneServerRestartFor`); it was not exercised here (the fixtures use a remote
  server, which offers Try again).
- The 8 s rule was tested with the test clock only.
- The Arabic strings for the five new keys are the agent's translation, not reviewed by
  a native speaker.
- The light-theme permission sheet shows a hard shadow line above its action bar in the
  test renderer (elevation 6, unchanged by this work); not checked on a device.

## Not migrated yet

- Above the composer: the draft-save error row, the pending photo row, the saved-note
  receipt, the composer note, the pending-sends strip and the composer's chip strip
  (they are composer parts, not screen states).
- In the transcript: "Load older" with its spinner, the jump-to-latest and earlier-
  messages pills, tool cards, background result cards (message rendering, out of scope).
- Sheets opened from the chat: the full question sheet (`activity_screen.dart`), the
  form renderer, the approvals sheet, the conversation menu sheet, and the run-shell
  and rename dialogs (their `FilledButton`s remain; `chat_screen.dart` is listed by
  retired parts, not whole).
- The shell's `ConnectionStatusBanner` on the other tabs (still used by
  `home_screen.dart`).
- Standard §9 steps 3, 4 and 6 (other agents).
