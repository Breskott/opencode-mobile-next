# Keep a worker warm for 15 minutes (2026-09-29): blocked, nothing built

Owner: keep a worker warm 15 min after a task ends, then let it stop (an idle
`opencode acp` is 563 MB, so never always-on).

## What gc 1.4.1 and the pinned gastown pack do (read, not run)

Pack `sha:33d3a430...` (cache `d0e8066c...`), `agents/polecat/agent.toml`:
`wake_mode = "fresh"`, `idle_timeout = "2h"`, `min_active_sessions = 0`,
`max_active_sessions = 5`.

- The polecat's own prompt ends every task with the done sequence
  (`gc runtime drain-ack`, then `exit`) and calls sitting idle after finishing
  the "Idle Polecat heresy" (`prompt.template.md`, lines ~185-306). So the worker
  process leaves by itself when the task ends; there is no idle process for a
  timeout to keep or stop.
- `wake_mode = "fresh"` starts a new provider session on every wake, so even a
  session kept alive would not carry a loaded conversation to the next task.
- `sleep_after_idle` (`cmd/gc/compute_awake_set.go`) only puts a session to
  sleep while it is still in the desired set (demand or `min_active_sessions`);
  it cannot extend a session past its demand. `idle_timeout` kills and
  restarts an inactive session (2h already, from the pack).
- The only setting that keeps a pool session alive with no demand is
  `min_active_sessions >= 1`, which is permanent (the 563 MB the owner rejects),
  not "15 minutes then stop".
- Whether an idle polecat calls the model: it has no periodic self-prompt in
  the pack (its `nudge` is delivered at start); a running session at an empty
  prompt makes no calls unless nudged or mailed. That is source-reading only.

## Decision

No supported setting gives "warm for 15 minutes, then stop". Making it work
would mean overriding the pack's polecat prompt (remove drain-ack) plus a custom
`scale_check` that reports demand for 15 minutes after the last task, which
changes the pack's lifecycle and is a workaround, not the contract. Not built.
The team's tuning is unchanged.

## What still makes the next start faster (already shipped)

Immediate reconciler poke on dispatch (API sling), the agents' `opencode`
wrapper (no npm install per worktree, no model-list fetch), and this phone's
measured start time on the Now line.

## If the owner still wants it (needs a decision)

Options to prototype on a device, each costing memory or a pack fork:
1. Fork the polecat prompt without drain-ack plus a `scale_check` marker with a
   15-minute lease (check idle worker makes no model calls; measure RAM).
2. `min_active_sessions = 1` only while a task ran in the last 15 minutes,
   toggled by an app-side timer through the provider/agent patch API (proof
   needed that a patch applies without a supervisor restart on 1.4.1).

Device check for either: an idle worker makes no model calls (watch provider
usage over 10 minutes) and its memory returns after the 15 minutes.
