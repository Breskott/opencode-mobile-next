# crit-chat-live — 2026-09-29

The owner's report (build 2076, in-app phone OpenCode 1, GLM-5.3): after
sending "Hi, what is this project?" nothing showed under the prompt for about
three minutes. The composer showed the mic, then later Stop, and the whole
reply (steps at 4:13 and 4:14, the answer at 4:15) appeared only at the end.
There was no sign that anything was happening, and once Stop replaced the mic
the owner could not use voice.

Not tested here. Per the brief there were no test runs. `flutter analyze` is
clean and the coordinator gates the rest.

## Root cause

**A. Nothing under a running prompt (UI, this slice).** Since chat-9
(592d7c50, 2026-09-27) the transcript has had no live row. Its comment reads
"The composer, not a transcript row, says when a run is active". Three things
add up to a blank turn:

- `_replyTurn` never sets `KitTurnPhase.starting`: the phase chain at
  `lib/ui/screens/chat/message_view.dart:1466` (base 8b34df86) ends in
  running or finished. KitTurn only draws a line for starting, stopped and
  interrupted (`lib/ui/kit/chat/kit_turn.dart:370-380`). So a running turn
  with no blocks draws nothing.
- An assistant message with no parts yet collapses to `SizedBox.shrink`
  (`message_view.dart:1385`, and `chat_screen.dart:7414` in `_transcriptRow`).
- Before the server reports busy, nothing counts as running. `_sending` clears
  as soon as `prompt_async` returns (`chat_screen.dart:2990`). After that the
  app waits for the server's `session.status busy`, so the composer shows the
  mic in the meantime and Stop only when busy arrives.

Today's merges did not cause this. The new interrupted and connectionLost
logic only applies to an assistant message that is still streaming, and it
would draw the "connection dropped" line, not nothing.

**B. A turn that ends with nothing.** `_unansweredTurn`
(`message_view.dart:83` and `:86`) returns null when no step came, or when
the last step has no error. A turn that went idle with no words, no steps and
no error therefore renders nothing.

**C. Live updates not reaching the chat during the turn (outside this
slice).** The owner saw every step only at the end, and busy arrived late.
That points to the location-scoped `/event` stream (`lib/api/opencode_api.dart:250`,
`?directory=`) not delivering this session's events on the in-app server. The
app then catches up through refreshes. Two such refreshes exist: the 5 s
`refreshSessions` poll, which runs only while the stream status is not
connected (`lib/state/connection.dart:6052`, `shouldPoll` at `:1057`), and
the session refresh on idle.

I found no change since 8b34df86 in `lib/api/`, the stream code in
`lib/state/connection.dart` (only AI Team progress lines were added), or the
chat's event handlers (`chat_screen.dart` `_onEvent`, unchanged since
August). The event schema the chat reads (a top-level `sessionID` on
`message.part.updated`) matches the pinned OpenCode v1.18.32 contract.

So the cause is not in the chat library, and I cannot confirm it without the
device. The owner's performance trace would settle it:

- `events.connected` and `events.first`: whether the stream was up.
- `prompt.accepted` versus `prompt.first_token`: a missing first token with
  `reply.done` present means the events never arrived.

Owner of the next step: the connection or stream owner (`lib/state/connection.dart`
is single-owner).

## Where the time goes on a first in-app reply

The app already times each phase:

| Phase | What measures it |
|---|---|
| Send → server has it | `prompt.accepted` (the `prompt_async` round trip). Usually well under a second on localhost. |
| Server has it → busy | The `session.status busy` event, which is not traced on its own. The trace would show the gap between `prompt.accepted` and the first event of the turn. |
| Busy → first token | `reply.first_token` (`ReplyWatch`). It records `server_ms` (user message created → first part started, by the server's own clock) next to the app-side wait. |
| End | `reply.done` / `prompt.turn`. This phone's **Reply speed** row (`oc.replySpeed.inApp`) shows the last first-words and total times. |

Two ways the owner's reading can go:

- **`server_ms` is large:** the model is slow to answer. OpenCode's free
  model often takes 40–120 s.
- **`server_ms` is small but the app-side first token equals the total:**
  the events did not reach the app live (C above).

## What changed

1. **The live line (kit: `KitTurnLive` on `KitTurn`).**
   - From the moment a send is accepted here, the running turn shows one line
     under what has come back so far, the prompt itself included. It shows
     "Sending…", "Waiting for the server…", "Thinking…", "Writing…",
     "Working…" or "Waiting for you…", then the time from 5 s on ("Thinking ·
     12 s", "1 min 5 s").
   - After 20 s with nothing back, it names where the wait is: "The server
     has not answered yet" before the server has confirmed the prompt, or
     "Waiting for the model's first word" after.
   - The chat keeps `_localTurnSince` (optimistic, set on send). The server's
     busy and idle take over when they arrive; it is also cleared on send
     failure, Stop, an idle or error event, or a finished last step.
   - A running reply is no longer marked "connection dropped" just because
     busy has not arrived yet.
   - `KitSince` gained `KitSinceTicks.seconds`.
2. **Never a silent turn.**
   - A turn that ended with no words, no steps and no error shows a notice on
     the prompt: "No reply came back", with **Send again**. Send again resends
     the words, or falls back to retry-last when the prompt had files.
   - When the server reported an error, the existing error notice and
     Details stay.
   - A turn the person stopped never says this.
3. **Stop versus the mic.**
   - Stop moved from the composer to the live line: **Stop reply**, a red
     tertiary kit action, keyed `chat-stop-button`. TalkBack reaches it as a
     button labelled "Stop reply", and the status words are the line's label
     (the seconds are not announced).
   - No Stop while the prompt is still on its way.
   - The composer passes no `onStop`, so while a reply runs KitComposer keeps
     the mic when empty and Send when there is text. A send made then queues
     as before: OpenCode 1 shows "Queued · runs after this turn", OpenCode 2
     shows the waiting bubble or delivery choice, and the composer says
     "Sends after this reply".
   - Dictation in the tools sheet is no longer blocked while a reply runs.
     Voice conversation still waits for the reply.
   - The composer had the only Stop. The status line is a keyboard-focusable
     button, so it is now the one Stop.
4. **Small fix.** On OpenCode 1, a new prompt sent right after a finished
   reply is no longer captioned "Queued · runs after this turn" before its
   own reply starts (`_queuedAfterIndex` ignores a finished reply). The live
   line sits under the running reply, above any prompt queued behind it.

## Files

- Kit:
  - `lib/ui/kit/chat/kit_turn.dart`: `KitTurnActivity`, `KitTurnLive`,
    `KitTurn.live`, and the live line.
  - `lib/ui/kit/kit_since.dart`: the seconds ticks.
  - `lib/ui/kit/chat/kit_composer.dart`: the mic while busy with no
    `onStop`.
- Chat:
  - `lib/ui/screens/chat_screen.dart`: `_localTurnSince`, `_stoppedPromptID`,
    `_liveTurn`, the transcript row carrying the live line, clearing on
    idle and error events, the queued index, no composer Stop.
  - `lib/ui/screens/chat/message_view.dart`: the silent unanswered turn,
    `live` and `onSendAgainNoReply` on `_MessageView`, and an empty
    streaming reply that keeps the live line.
  - `lib/ui/screens/chat/composer.dart`: no Stop; dictation allowed while
    busy.
- Copy: `lib/l10n/app_en.arb`, with 15 new keys (`kitTurnLive*`,
  `chatNoReplyCameBack`) and the generated l10n.
- Docs: `docs/ux-system/kit-api/KitTurn.md` (live line).

## Tests edited (not run)

- `test/composer_desktop_enter_test.dart`: the Stop tooltip test is now "a
  sent prompt runs at once" (live line, Stop reply, the composer keeps its
  mic or Send, and stopping leaves no "No reply came back").
- `test/chat_server_state_ui_test.dart`: the retry test gets a prompt, since
  Stop is on the turn. New test: "No reply came back" with Send again.
- `test/pending_sends_strip_test.dart`: the v2 and v1 busy tests expect no
  Stop in the composer and the mic or Send there.
- `test/chat_live_events_test.dart`: the three Stop tests seed a prompt
  (`_onePrompt`); tap by "Stop reply".
- `test/composer_layout_test.dart`:
  - The voice tool is enabled while busy.
  - The busy test expects "Thinking…" and Stop on the turn, not in the pill.
  - The reduced-motion test gets a prompt.
- `test/chat_transcript_placement_test.dart`: Stop sits inside the newest
  turn, under its words; its semantics label is "Stop reply".
- `test/stable_chat_layout_test.dart`: the keyboard test no longer expects
  Stop in the composer.
- `test/motion_states_test.dart`: wording only.
- `test/kit/kit_composer_test.dart`: new test, busy with no `onStop` keeps the
  mic.
- `test/kit/kit_turn_test.dart`: new group for the live line (timing, slow
  words, Stop, no Stop while sending).

## What a device check should look at

- **Timing and words.** On the in-app server with the free model, the line
  shows at once under the sent prompt, with no gap before busy. It counts
  seconds and changes to "Waiting for the model's first word" after 20 s.
  Tool steps show "Working", streaming text shows "Writing".
- **Stop reply.** It stops the run, and the line goes. TalkBack reaches it by
  swiping.
- **Mic during a reply.** The mic stays in the composer while the reply
  runs. Dictating, then Send, queues the message.
- **A silent turn.** Kill the model mid-turn or use a provider that returns
  nothing: the prompt gets "No reply came back" and Send again.
- **C above.** Capture the performance trace for one in-app reply. If the
  steps still appear only at the end, the event stream is the fault, and the
  live line will say "Waiting for the server" or "Thinking" until the
  catch-up.
