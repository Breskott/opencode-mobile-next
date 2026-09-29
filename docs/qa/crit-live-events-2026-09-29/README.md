# crit-live-events — 2026-09-29

The owner's report (build 2076, built from 5cc22241; in-app phone OpenCode
1.18.32): a new conversation from Work in "Test", "Hi, what is this
project?" sent at 4:12. The server wrote steps at 4:13 and 4:14 and the
answer at 4:15. The chat showed none of it live, and the composer changed
from mic to Stop only after a delay.

## The leading hypothesis is wrong

The idea was that `/event` is scoped to a different folder than the
conversation. I checked the source and ran a local OpenCode 1.18.32. The
binary was copied from `/proc/<pid>/exe` of the 1.18.32 server already
running on :4123. My copy ran on :4131 with isolated XDG dirs, and I stopped
it by its exact PID afterwards.

- **Server semantics (proven on 1.18.32).** `/event?directory=X` only
  carries events from X's own instance. There is no fallback to the project
  and no fallback to a subfolder: a stream on `projA` does not see a session
  in `projA/sub`, and a stream with no directory sees neither. The server
  resolves paths before choosing the instance. A trailing slash and a
  symlinked path both reach the same instance as the plain path. A folder
  without git works the same way. `/global/event` carries every instance's
  events, wrapped as `{directory, project, payload}`.
- **App (read).** Work → New conversation calls `createSession`
  (`workspace_screen.dart:579`), and that goes through the same `api`
  object whose `_directory` scopes `/event`: `opencode_api.dart:353`
  (`sessionCreate(directory: _directory)`), `:253` (`/event` with
  `_query()`), and the prompt. The only code that changes that directory is
  `_selectLocation` and connect or resume (`connection.dart` ~9540,
  ~2595, ~8734), and each of them rebuilds the transport and restarts
  `/event` together. The chat reads the same controller (`connProvider`)
  that Work uses. The crit/connect change (2ef6d7f8) removed the automatic
  first conversation. It does not touch the location: Work still opens its
  pick through `selectInitialLocation`, which restarts the stream.

In this flow the conversation and the stream always share one folder. The
cause has to be that the stream was **not delivering** during the turn. The
symptom fits that. A stream scoped to the wrong folder but still "connected"
never shows Stop, because nothing else sets busy for that session. A stream
that is not connected turns on the 5 s `refreshSessions` poll
(`shouldPoll`, `connection.dart:1057`, `:6067`). That poll sets busy late,
which gives "Stop after a delay", and it sets idle at the end, which gives
"everything at once". The OpenCode 1 `EventStream` also had no way to notice
a connection that stays open while the server has stopped writing to it
(no watchdog; `lib/api/sse.dart`).

Other things I checked and ruled out on 1.18.32:

- An instance dispose (the provider heal) sends `server.instance.disposed`
  and closes `/event`, so the app reconnects. It also aborts a running reply
  (`MessageAbortedError`). The owner's reply finished, so no dispose
  happened during that turn.
- The SSE response is not compressed (checked with `Accept-Encoding: gzip`).

## What changed

1. **`lib/api/sse.dart`: stall watchdog.** OpenCode 1 writes
   `server.heartbeat` every 10 s on both streams. Once a connection has
   sent one heartbeat, 35 s with no bytes ends that connection quietly. The
   existing loop then reconnects, and on reconnect the controller runs
   `refreshSessions`. Servers that send no heartbeats are never timed out.
   The dead subscription is cancelled without waiting for it, so a socket
   that never answers the cancel cannot hold up its replacement.
2. **`lib/state/connection.dart` `_startGlobalEvents`: live backstop.**
   While the folder stream is not connected, OpenCode 1 events from
   `/global/event` whose `directory` matches the open folder go through
   `_onEvent`. The chat therefore keeps getting the parts, deltas, busy and
   idle of a running reply instead of waiting for the list poll. When the
   folder stream is connected nothing is forwarded, so no delta arrives
   twice. Events from other folders are never forwarded. OpenCode 2, Codex
   and Paseo are unchanged: the forward only applies when the gateway
   `is OpenCodeApi`.

Tests added to `test/connection_sse_test.dart`:

- "a stream that goes silent after a heartbeat is replaced"
- "while the folder stream is down, the server-wide stream carries that
  folder's events live"

Checks run here: `test/connection_sse_test.dart`, all 40 passed. With the
connection.dart change reverted, the new folder-stream test fails
(`[]` instead of `['live']`). `flutter analyze` is clean.

## Not done

- The exact device state behind build 2076 is still unproven. It was either
  a stream that stayed "connecting" or reconnecting, or one that stayed open
  and silent, and both are now covered. The owner's Performance report, or
  logcat `OCTRACE`, would say which.
- This slice changes no UI and no copy.

## Device check

Take the in-app phone server, open Work, pick "Test", tap New conversation
and send "Hi, what is this project?". The first step, and then the words,
should appear while the reply runs, and Stop should replace the mic within
about a second of sending. If it fails again, read logcat (`OCTRACE`) or the
Performance report for that turn:

- `events.connected` and `events.first` with `parent=location.select`
- whether `GET /event` repeats (reconnects)
- whether `events.first` is missing while `sessions.refresh` repeats every
  5 s, which means the folder stream never connected
