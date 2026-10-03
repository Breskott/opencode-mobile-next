# AI Team start: real steps (2026-09-29)

Owner: "Can this show actual real time progress and steps?" (AI Team page while the in-app team starts, header said "Not answering", bar was not real.)

## Done
- `lib/builtin/team/builtin_team_start_progress.dart`: one progress model (`BuiltinTeamStartProgress.shared`, exposed as `BuiltinTeam.startProgress`, a ValueListenable). Per step: began/took/elapsed, slow bound, failed step, error; overall bar = finished steps / 4.
- Steps and the signal that ends each (polled every `pollInterval`, 1 s, never a timer):
  1. Starting the team's service: native `startService` returned and `BuiltinLinux.status` shows the process alive.
  2. Waiting for the team to answer: supervisor `GET /health` status ok (bound 90 s explicit, 3 min after restart; failure if the process dies or the bound passes).
  3. Opening the task store: team registered, then `GET /v0/city/phone/health` status ok (6 min bound).
  4. Getting the agents ready: `GET /v0/city/phone/status` `agents.total > 0` (45 s, then let go: an empty list is not a failure; a status without an agent count counts as nothing to wait for; a dead service fails).
  `/v0/readiness` was not used: it reports providers and tools, not the team.
- Same model for both paths: `BuiltinTeam._start` (explicit button, turnOn) and the automatic start after an app restart (`ensureRunning(observe: true)`, passed by `main.dart`'s `reviveTeam`; it starts the service, then watches in the background, bounded). Existing callers keep the old no-wait behaviour.
- Page (`team_states.dart`): `KitStateView` with `KitChecklist` (spinner on the current step, "0:12 so far", "Took 0:03", ticks), determinate bar, "Taking longer than usual, the phone is busy" past a per-step bound (step keeps going). Shown for the explicit start and for the connecting state of the in-app team while a start runs. Failure page shows the checklist with the failed step marked, the sentence, "Start again", and technical text under Details. When an automatic start finishes the page reads the team again.
- Header: `teamHostCondition/Phrase(teamStarting:)` says "Starting" instead of "Not answering" while the in-app team starts (AI Team home passes it).
- Copy: 7 new keys in app_en.arb / app_ar.arb (`teamStartStep*`, `teamStartSlow`, `teamStartAgain`, `teamUiHostPhraseStarting`); gen-l10n run.

## Not done / notes
- No tests run or added (brief). No existing test referenced the changed copy. Kit ratchet not run: `team_states.dart` adds one StatefulWidget (`_StartWatch`, draws nothing) and no hand-built visuals.
- The old job-driven stage page (`builtinTeamStageText` for the page) is no longer used on the team page; the Plugins section still uses it.

## Device check
- Force-stop the app with the team on, reopen: AI Team page shows the four steps advancing with seconds, header "On this phone . Starting", then the team loads by itself.
- Tap "Start AI Team on this phone" on the failed page: same steps. Kill the service mid-way: failed step marked, "Start again".
- Slow phone: a step past its bound reads "Taking longer than usual, the phone is busy".
