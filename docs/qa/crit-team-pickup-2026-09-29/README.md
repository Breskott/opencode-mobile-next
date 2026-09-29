# Team pickup: why so long, and exactly when (2026-09-29)

Owner: "Why so long, and I want to know exactly when it will be picked."
Branch `crit/team-pickup`. No tests or devices were run (coordinator gates);
analyze is clean.

## 1. Diagnosis

Between "Started a worker" and "begins the task" the phone does, in order
(Gas City 1.4.1 reading, `gascity-src`, and `docs/qa/team-hot-2026-09-26`):

1. The reconciler starts the worker session: a pool session is created
   (`creating` / `start-pending`), its git worktree is made, then
   `exec opencode acp` starts under proot. Cold start is about 22 s on the
   owner's phone, more when the phone is loaded. Timeouts allow up to 4 min
   (`startup_timeout`) and 3 min (ACP handshake).
2. `max_wakes_per_tick = 1` and `patrol_interval = 60s` (`phoneTuning`): every
   other wake (mayor, witness, refinery, a second worker) also needs a tick,
   so a start can queue behind another for 60 s per tick.
3. The session becomes `active`, the task is delivered to it as its first
   prompt (`last_nudge_delivered_at`), and the worker claims the bead
   (`active_bead`), which is "began the task".

"Not answering" at the same time: `teamHostCondition` says it when
`OrchestrationController.isStale` (live stream not `live`, which the SSE
client declares after a 90 s stall, or the last read older than 60 s) or
when a read failed (30 s receive timeout). Starting OpenCode under proot
saturates the phone, so the app's own reads and stream time out while the
supervisor is fine. The app cannot tell that apart from a dead supervisor
except by history: whether the team was read a moment ago.

What the app can observe: the session `state` (`creating`, `start-pending`,
`active`, `asleep`), the `running` flag, `last_nudge_delivered_at` (task
handed over) and `active_bead` (worker claimed it), plus session `created_at`.
It cannot see "ACP handshake done" or "OpenCode loaded" as such; `active` with
`running` is the closest.

## 2. Built: pickup shown honestly

- `lib/state/team_worker_start.dart`: `TeamWorkerStage` (preparing, running,
  taskDelivered) from the joined session; `teamWorkerStartMeasured`
  (session created to the worker claiming the task, plausible 1 s to 30 min);
  `TeamWorkerStartStore`, key `oc.teamWorkerStart.<profileId>` (ms), swept
  with the profile by the existing scoped-key deletion.
- The Now line while "Starting a worker · N min": the reason (after 8 s)
  names the real stage: "The worker is being set up...", "The worker's program
  is running...", "The task has reached the worker...". When the host names
  none, the older honest line stays.
- "Next: the worker begins the task" now carries "took 42 s last time" from this
  phone's own last measured start. With no measurement nothing is promised:
  the fixed "usually within 5 min" is gone for this stage (it stays for the
  earlier "waiting for a worker" stage).
- The measurement is recorded when the conversation sees the worker begin.
- Lead line when the worker claims: "The worker began the task · 10:09:47"
  (to the second; "{name} began the task" when named).
- The Why fold for a starting worker no longer says "1-5 minutes".

Limit: the elapsed time on the line updates with each team update, not every
second (a per-second ticker would keep pumpAndSettle from settling in tests).

## 3. Faster: findings, mostly blocked

- Immediate wake on dispatch: already there. The app dispatches with HTTP
  `POST .../sling`; the API's sling notifier calls `state.Poke()`
  (`internal/api/handler_sling.go`, `apiNotifier.PokeController`), the same
  as `gc sling`'s controller poke, so the reconciler ticks at once. Nothing
  to add. The remaining wait is cold start plus one wake per tick.
- `POST /session/{id}/wake` exists but only for an existing session.
- Keep the project's worker warm: Gas City has `min_active_sessions`,
  `idle_timeout` and `sleep_after_idle` per agent, but keeping an OpenCode
  process resident costs RAM the phone may not have (Android kills it), and
  overriding a pack agent in `city.toml` is not verified for 1.4.1 (the
  `[[patches.provider]]` form was already rejected). Not built. Needs an
  on-device proof and an owner decision on memory; recorded as a blocker.
- Raising `max_wakes_per_tick` was not changed (it was set to stop the
  phone being overrun; team-hot evidence).

## 4. "Not answering" while busy starting

`teamHostBusyStarting` (`lib/ui/widgets/team_vocabulary.dart`): while a worker
starts (step starting, a session in `creating`/`start-pending`, or a direct
task whose worker was just observed) and the team is otherwise ready and was
read within 5 minutes (`teamStartReadGrace`), a late stream or a timed-out read
shows "Busy starting a worker" in the header, and the Now line keeps its stage
instead of flipping to "unavailable". A team that failed its probe, or has not
been read for 5 minutes, still says "Not answering".

Limit: a supervisor that dies within 5 minutes of a good read reads as busy
until the grace ends.

## Files touched

New: `lib/state/team_worker_start.dart`, `test/team_worker_start_test.dart`.
Edited: `lib/state/team_now_line.dart`, `lib/state/team_conversation.dart`,
`lib/state/orchestration.dart` (store getter), `lib/ui/widgets/team_now_line_view.dart`,
`lib/ui/widgets/team_vocabulary.dart` (host condition),
`lib/ui/screens/chat/team_conversation_view.dart`,
`lib/ui/screens/chat_screen.dart` (one import), `lib/l10n/app_en.arb` (+ generated),
`test/team_conversation_screen_test.dart` (no "usually within 5 min" when
nothing is measured).

## Device check

Give a task on the phone: the Now line should show the stage change
(set up, running, task reached) and, from the second task on, "took N s last
time"; the header should say "Busy starting a worker", not "Not answering",
while OpenCode starts; the lead line shows "The worker began the task ·
HH:MM:SS". Kill the supervisor: after 5 minutes (or at once if the probe
fails) the header must say "Not answering".
