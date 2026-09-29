# crit-team-revive — AI Team gone after an app update (2026-09-29)

Owner report: after installing 2071 over 2070 while the in-app AI Team ran a
task, AI Team showed "On this phone · Not answering" / "Can't reach the team
host … Tailscale …" with only Try again; Details:
`Unreachable: SocketException: Connection refused (OS Error: Connection refused, errno = 111), address = 127.0.0.1, port = 36580`.

## Root cause (source only, no device)

1. **Port 36580 is not a server port.** For a refused connect, Dart's
   `SocketException` text ends in the *local, ephemeral* port the socket was
   bound to (Android range 32768–60999), not the port asked for. The probe
   asked `BuiltinTeam.url` = `http://127.0.0.1:8472` (the profile's config
   passes `BuiltinTeam.isBuiltinConfig`, which requires port 8472; the probe
   only follows a front's `supervisorUrl`, which the in-app supervisor has
   none of). Nothing stale or advertised — the supervisor on 8472 was simply
   not running.
2. **Nothing restarted the team.** An APK update kills the process and every
   proot service. On the next launch `AppExitRecovery.runOnce` sees `aiteam`
   in the recorded services, but its only action is the server recovery
   (`PhoneServerHealing.check` → `BuiltinServerStarter.start(automatic: true,
   recoveryGeneration: …)`), and that start deliberately skips the team
   (`builtin_server.dart`: team follows only a manual or non-recovery start;
   heal slice 2026-09-27: "Server recovery deliberately does not start the
   team"). The launch start (`startForLaunch`, which would bring the team)
   is skipped once the recovery check already started the server. So
   OpenCode came back and the team never did.
3. The failed state had no fix to offer: it used the generic "team host"
   copy (Tailscale) and only Try again, which re-probes a dead port.

## Fixed

- **A. Team comes back after an update or any process death.**
  `AppExitRecovery.runOnce` takes `reviveTeam`; after the server recovery it
  starts the team when: `aiteam` ran when the process ended (a Stop the
  person gave clears that record, and a deliberate server Stop already
  suppresses it), the in-app profile still has the team's config (turning
  the team off clears it), and `AutomationBehavior.restartPhoneServer`
  allows it for that profile. `main.dart` wires it to
  `BuiltinTeam.ensureRunning`, which also refuses when the durable
  turned-off mark is set. This makes the existing notice "they're starting
  again" true for the team.
- **B. Failed state for the in-app team** (`team_states.dart`, failed branch
  only): title "AI Team stopped", body "AI Team on this phone isn't running.
  Start it to continue your tasks.", primary **Start AI Team on this phone**
  (runs `BuiltinTeam.start` through the app's one `BuiltinTeamJob`, so the
  page shows "Starting AI Team" / "Waiting for AI Team to answer" with a
  progress bar, then re-reads the team), secondary Try again. A failed start
  says what failed in words; its log tail goes under Details. Tailscale
  wording now shows only for teams not inside the app. Keys: `<prefix>-error`
  (unchanged), `<prefix>-start-team`, `<prefix>-team-starting`.
- **C. Details name the address asked.** `ProbeUnreachable` carries the URL
  (scheme://host:port only, never credentials) so Details read
  `Unreachable: http://127.0.0.1:8472 did not answer: SocketException …`
  instead of pointing at the misleading ephemeral port. No probe fallback
  was needed: the address was never stale.

## Files

- lib/builtin/app_exit_recovery.dart — `reviveTeam`, `_reviveTeam`
- lib/main.dart — wires `reviveTeam` (two imports, one argument)
- lib/ui/screens/team/team_states.dart — builtin failed state
- lib/orchestration/adapters/gascity/gascity_probe.dart — `ProbeUnreachable.url`
- lib/l10n/app_en.arb (+ generated) — `teamUiStatePhoneStoppedTitle`,
  `teamUiStatePhoneStoppedBody`, `teamUiStartOnPhone`

## Not done / notes

- No tests run (brief). No existing test asserts the old builtin
  unreachable copy; test fixtures use the `fixture` provider, which is not
  the in-app config, so they keep the generic state. New tests worth adding
  at the gate: runOnce with `aiteam` in previous services + builtin profile
  calls `reviveTeam` once; not with the policy off or without the config;
  team_states builtin unreachable shows `-start-team`.
- Arabic strings for the three new keys are not added (English fallback).
- A Termux-hosted phone team still gets the generic unreachable copy.
- Server healing still does not start the team on its own crash restarts
  (bounded budget, left as designed); the once-per-launch revival covers
  updates and Android kills.

## Device check

1. With the team running a task, install a new APK over the old one; open
   the app. Within ~1–2 min the team answers again without a tap
   (`app.recover.team started=true` in the perf trace).
2. Turn the team off, update again: it must stay off.
3. Stop the team's service another way (or set Automation → restart phone
   server off) and open AI Team: "AI Team stopped" with **Start AI Team on
   this phone**; tap it: stages show, then the team page loads.
