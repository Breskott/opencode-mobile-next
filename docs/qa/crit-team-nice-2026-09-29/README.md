# crit/team-nice: the person's chat always wins over AI Team

Measured on the owner's phone: "Hello" took ~2 min on the in-app server while the in-app AI Team ran, 4 s on Termux, quick again with the team off.

## Done
1. Lowest CPU priority for every AI Team process.
   - `AiTeamScripts.lowPriorityExec` (new) is used by `BuiltinTeam.serviceScript`: the supervisor now ends with
     `exec nice -n 19 ionice -c 3 gc supervisor run` (`ionice` only if `ionice -c 3 true` works under proot; else `exec nice -n 19 gc supervisor run`; else plain `exec` if `nice` is missing). Nice is inherited, so dolt/bd, tmux and every agent inherit it.
   - `AiTeamScripts.agentWrapperScript` (each agent's `opencode`) now ends `exec nice -n 19 [ionice -c 3] /usr/local/bin/opencode "$@"` (same guards): explicit even if a child is started some other way.
   - The in-app chat OpenCode server (separate service) is untouched, normal priority.
   - Existing installs: `serviceScript` runs on every team start and already includes `refreshAgentWrapperScript`, so the next start rewrites the wrapper and starts the supervisor niced. `applyModel` refreshes the wrapper too. Running agents keep the old priority until the team restarts.
   - Ubuntu base has `nice` (coreutils) and `ionice` (util-linux, also provides `flock` the upkeep script already needs). Raising nice needs no privilege. Not verified on the device (no phone access here): a device check should run `ps -o pid,ni,comm` in the proot and see NI 19 on gc, dolt, opencode acp.
3. Honest hint words: `KitTurnLive.teamAlsoWorking` (bool, default false) + l10n `kitTurnLiveFirstWordSlowTeam` ("AI Team is also working on this phone, so replies may be slower"). When the turn is waitingForModel and past `slowAfter` (20 s) and the flag is set, the live line shows it instead of "Waiting for the model's first word". Chat screen not touched.
   - Wiring needed later (one line, in `lib/ui/screens/chat_screen.dart` near line 7569 where `KitTurnLive(` is built): `teamAlsoWorking: <reply is on the in-app server> && <in-app team has working tasks>,`
   - Arabic string not added (falls back to English via gen-l10n untranslated list).

## Skipped
- 2 (pause new worker starts while the person's reply runs): would need Gas City changes or a new app-side gate on the reconciler poke; the nice level already stops the team taking CPU from chat.

## Files
lib/builtin/setup/aiteam_scripts.dart, lib/builtin/team/builtin_team.dart, lib/ui/kit/chat/kit_turn.dart, lib/l10n/app_en.arb (+ generated l10n). Tests: existing `exec gc supervisor run` assertions still hold (the plain fallback line keeps that text); none edited.
