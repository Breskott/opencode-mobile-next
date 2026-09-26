# AI Team: from "Give the team a task" to first output (2026-09-26)

Branch `perf/team-hot` (from `feat/phone-setup-v2` at c799e2af). Owner's
question: "Why 4 minutes? Everything should be hot and in seconds." Targets
(docs/design/team-conversation-2026-09-26.md, Speed): the task reaches a
worker within 5 s; first output within ~20 s.

States: **implemented, unit-tested, committed locally. Not on a device, not
pushed, not released.**

## What the owner's phone showed (read-only, 2026-09-25 UTC)

Android 15, arm64, 16 GB; built-in Ubuntu; Gas City 1.4.1; OpenCode 1.18.29.
Read over adb: `ps`, `dumpsys activity exit-info`, and GETs to the
supervisor through `adb forward tcp:18472 tcp:8472` (`/v0/cities`,
`/v0/city/phone/{sessions,beads,status,config,events}`,
`/bead/<id>`, `/session/ph-yqt/transcript`). Nothing was written, started or
stopped. The event timeline (ids and times only, no task text) is in
[phone-events-2026-09-25.tsv](phone-events-2026-09-25.tsv).

| UTC | What | Source |
|---|---|---|
| 19:49:03.0 | task `da-r7d` created (`POST /beads`) | `bead.created` |
| 19:49:03.4 | routed to `demo-app/gastown.polecat` (`POST /sling`: convoy `sling-da-r7d`) | `bead.created` |
| 19:49:10.7 | reconciler tick (the sling's poke; `phone-upkeep` fired in the same tick) | `order.fired` |
| 19:49:11.3 | worker start 1, session `ph-3br` | `bead.created` |
| 19:49:27 | start 1 closed: `session create failed: aborted before creation_complete` (16 s) | `/bead/ph-3br` |
| 19:49:50.4 | start 2, `ph-n65` | |
| 19:50:22.1 | `session.cold_start_timeout`: "cold start timed out" (32 s = the 30 s ACP handshake) | event |
| 19:50:27.6 | start 3, `ph-6be`; closed 19:50:35 (8 s), same reason text | `/bead/ph-6be` |
| 19:51:05.1 | start 4, `ph-yqt` (the one the owner saw) | |
| 19:51:27.1 | `session.woke`: handshake done, **22 s** after start | event |
| 19:54:28 | the agent's first write to the task | `bead.updated` |
| ~19:55 | first output the owner saw | owner |

Also from the phone: `opencode acp` 563 MB RSS (15 min in), `opencode serve`
410 MB, `gc supervisor` 79 MB, `dolt sql-server` 96 MB, the gc Dolt
watchdog 28 MB. The worker's folder holds `.opencode/node_modules/`
(listed in its transcript): OpenCode installed a package there from npm.
At 20:06:33 UTC the app was force-stopped (`dumpsys activity exit-info`:
`reason=10 (USER REQUESTED) subreason=21 (FORCE STOP)`, from system pid
2285) while these reads were going on; nothing here stops apps, and the
reads stopped there.

**So the two minutes were not a patrol wait.** The task reached the worker
8 s after it was created. Gas City then cut off three OpenCode starts before
the fourth got through: one at the 30 s handshake limit, two earlier for a
reason only the supervisor's log holds (the app's service log, not readable
over adb on a release build). The remaining ~3.5 min were the one cold
OpenCode (22 s) and the time before the agent's first action (19:51:27 to
19:54:28), which includes OpenCode's per-folder npm install (below) and the
first model call; the phone gave no finer split.

## Feasibility

### 1. Instant dispatch: already happens (8 s measured)

- The app's "Give the team a task" is `POST /beads` then `POST /sling`
  (`OrchestrationController.giveTask`, `GasCityControl.assign`).
- Gas City 1.4.1's API sling pokes the controller: `internal/sling/sling_core.go`
  calls `deps.Notify.PokeController` after routing, and the API's notifier
  is `state.Poke()` (`internal/api/handler_sling.go:469`); the city loop
  runs `runTick("poke")` on it (`cmd/gc/city_runtime.go:735`,
  `tick_debounce` 0 by default). `gc session wake` and `gc sling` on the CLI
  use the same poke; there is nothing faster to call.
- Measured: task 19:49:03.0 → worker session 19:49:11.3. The tick also
  runs whatever is due (here `phone-upkeep`), and each store probe is one at
  a time under proot, so 5–8 s is what a tick costs on this phone.
- `[daemon] patrol_interval` (60 s on the phone, 30 s default) is not on
  this path. Shortening it buys nothing for dispatch and costs a full
  reconcile (store probes through Dolt, order checks) more often; it stays.

### 2. Warm workers through the phone's OpenCode server: not possible

- OpenCode 1.18.29 (the app's pin, `TermuxRuntime.openCode1`) `opencode acp`
  (`packages/opencode/src/cli/cmd/acp.ts`) always starts its own server
  (`Server.listen(opts)`) and talks to that; no `--attach`. Same on the
  newest release (v1.18.32). The upstream PR "feat(cli): add ACP attach
  support" (anomalyco/opencode#18272) was closed without merging.
- Even with attach it would be wrong for Gas City: each agent's identity is
  its process environment (`GC_ALIAS`, `GC_RIG_ROOT`, session ids, Gas City's
  `OPENCODE_PERMISSION`), read by the agent's `gascity.js` plugin and by
  every `gc`/`bd` command its shell runs. In an attached server, tools run
  in the server's process, with the person's server environment.
- What was measured instead: the handshake itself takes 22 s cold on this
  phone, and two avoidable costs sat on top of it (below). A pre-warmed
  worker (one `opencode acp` kept running) would cost ~550 MB and one
  process all the time; not built (see NOT done).

### 3. Making the cold start count once, and shorter: built

| Change | Where | Saves | Costs |
|---|---|---|---|
| `[session] startup_timeout = "4m"`, `[session.acp] handshake_timeout = "3m"` (Gas City defaults 60 s / 30 s) | `BuiltinTeam.phoneTuning` | the cut-off-and-restart cycles: ~2 min on the owner's phone | no process, no memory; a start that truly hangs is found after 3–4 min instead of 30–60 s. Gas City's tick waits for its start wave (`city_runtime.go`: "a session-start wave that waits for startup_timeout"), so other work of that tick (e.g. waking the merger) waits for a slow start, as it did before for each 30–60 s try |
| Older teams get it on their next start: `tuneScript` now rewrites when `handshake_timeout = "3m"` is missing too, and drops/re-adds `[session]` and `[session.acp]` like `[daemon]` | `BuiltinTeam.tuneScript` | — | one `awk` over `city.toml` once |
| New work folders skip OpenCode's npm install: the agents' `opencode` links `.opencode/node_modules` to the phone server's `~/.config/opencode/node_modules` and writes the `package.json`/`package-lock.json` that satisfy OpenCode's skip rule (`packages/core/src/npm.ts`: `node_modules` exists and every declared package is locked). Only for a `.opencode` with neither file; a project's own is untouched. OpenCode waits for that install before loading the folder's plugins (`plugin/index.ts`: `waitForDependencies` when there are plugins; Gas City's `gascity.js` is one and needs no package) | `AiTeamScripts.agentWrapperScript` | a network install under proot on every new worker folder (refinery, each polecat name, a pruned folder); not separately timed | none: `sed` + `ln` run once before `exec`; less disk (no copy) |
| `OPENCODE_DISABLE_MODELS_FETCH=1` for agents: they read the models cache the phone's server keeps fresh (`packages/core/src/models-dev.ts`: disk cache first, fetch only in the background) | same | a models.dev fetch at each agent start and hourly per agent | none |
| Every team start rewrites the agents' `opencode` (installed phones get the new one without reinstalling) | `AiTeamScripts.refreshAgentWrapperScript` in `BuiltinTeam.serviceScript` (also the Termux runtime, which runs the same service script) | — | none; running agents are unaffected (they `exec`ed already) |
| `BuiltinTeam.agentStarts()`: Gas City's own start lines from the supervisor log (`session lifecycle: op=start … outcome=… duration=… phases=[start_call=…] err=…`) as `BuiltinTeamAgentStart` (session, template, outcome, duration, startCall, error, succeeded, timedOut) | `lib/builtin/team/builtin_team.dart` | makes the next measurement (and the reason for any cut-off start) readable in the app | reads ≤64 KB of the log on demand |

Processes and memory: no new long-lived process; per agent unchanged
(one `opencode acp`, ~550 MB). Store (Dolt) untouched; nothing deletes
work: the tuning only replaces its own tables in `city.toml`, the wrapper
only adds files in a `.opencode` that has none of them (ignored by the
`.gitignore` OpenCode writes there, which the wrapper also writes if
missing), and a link removed by a folder cleanup removes only the link.

## What happens now, "Give the team a task" → first output (expected)

| Stage | Before (measured) | Now (expected, not yet measured) |
|---|---|---|
| App: create + route (`POST /beads`, `POST /sling`) | < 1 s | < 1 s |
| Poke → worker session made | 8 s | 5–8 s (unchanged) |
| Cut-off starts | 3 starts, ~115 s | none expected: one start |
| `opencode acp` cold start + handshake | 22 s (4th try) | ~20–30 s |
| OpenCode's npm install for a new worker folder | inside the 3 min below | skipped when the phone's server has the package |
| Handshake → agent's first action / output | ~3 min (install + first model call, not split) | first model call: ~10–30 s by model |
| **Total** | **~6 min (owner: "4 min")** | **~40–70 s** |

The ~20 s target needs a worker that is already running; see NOT done.

## Tests

- `test/builtin_team_hot_test.dart` (8 tests, pass): new team has the start
  times; a team tuned by the previous version gets them once, the rest kept,
  still TOML (Python `tomllib` reads `4m 3m`); the wrapper seeds a new
  folder so OpenCode's own skip rule holds, leaves a project's own
  `.opencode` alone, does nothing without the server's package, and sets
  the models flag; an older wrapper is replaced on start, nothing made when
  AI Team is not installed; start lines and Go durations parse.
- Without the change (tuning check and wrapper seeding reverted, API kept):
  [without-change.log](without-change.log) — the migration test and the
  wrapper test fail.
- Neighbours: `test/builtin_team_test.dart`, `test/aiteam_component_test.dart`,
  `test/termux_aiteam_script_test.dart`, `test/termux_aiteam_upstream_test.dart`,
  `test/builtin_team_bring_in_test.dart`, `test/builtin_team_section_test.dart`
  with the new file: `flutter test -j 2` → **74 passed** (pinned Flutter
  3.47.1). `flutter analyze lib/builtin test/builtin_team_hot_test.dart`:
  no issues. The full suite was not run.

## On-device measurement plan (owner's phone, after installing this build)

1. Open the app; the AI Team start migrates `city.toml` (tuneScript) and the
   wrapper (refresh). Nothing else to do.
2. Give the team a task. With `adb forward tcp:18472 tcp:8472`, read
   `GET /v0/city/phone/events` and note: `bead.created` of the task,
   `bead.created` of the session, `session.woke`. Pass: **one** session bead
   for the task (was four) and no `session.cold_start_timeout`.
3. In the app (or a debug hook on `BuiltinTeam.agentStarts()`): the start's
   `duration` and `start_call` (OpenCode's own start + handshake) and, for
   any failed start, its `err` (this also names the reason of the two 8 s /
   16 s failures if they recur).
4. First output: the first `session/<id>/stream` event after `session.woke`
   (or the owner's stopwatch from the button). Pass: under ~70 s.
5. In the built-in terminal: `ls -l /root/aiteam/city/.gc/worktrees/*/*/*/.opencode/`
   shows `node_modules -> /root/.config/opencode/node_modules` for a folder
   made after the update.
6. `adb shell ps -A -o PID,RSS,ETIME,ARGS`: one `opencode acp` per working
   agent, ~550 MB; the app's processes stay under 32.

## NOT done

- A worker kept warm between tasks (Gas City pool `min_active_sessions = 1`
  or `gc session pin`): ~550 MB and one process always; unknown whether an
  idle gastown polecat waits quietly or loops (model usage). Needs a device
  experiment before it can be offered, with its memory cost in the UI.
- Why two of the owner's three failed starts ended at 8 s and 16 s (not the
  30 s limit): the reason is only in the supervisor log; `agentStarts()`
  makes it readable next time.
- Trimming OpenCode for agents further (LSP servers, snapshots): would cut
  processes/memory while an agent edits TypeScript, but snapshots feed the
  per-message diffs a team conversation may show; not changed.
- UI: nothing in `lib/ui/` (another agent's). For them: "Starting a worker,
  about 30 s on a phone" can read the session's state, and "the last worker
  took N s to start" can read `BuiltinTeam.agentStarts()`.
- No emulator, no device run, no Gradle build, no push.
