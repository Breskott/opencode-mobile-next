# Team model choice (2026-09-29)

Owner: "how to select models in AI Team?"

## Mechanism (verified in gascity-src 1.4.1 and the app)

Candidates checked:
- Provider `option_defaults` (`model`): the builtin opencode option has fixed
  choices and its `--model` flag args; the ACP transport uses `ACPArgs`
  (`["acp"]`), which replace `Args`, so an option flag is not applied and
  arbitrary models are not accepted. Rejected.
- Agent patch `env` / provider `env` (`PATCH /v0/city/{c}/provider/opencode`,
  `[providers.opencode] env`): env merges additively and would carry
  `OPENCODE_CONFIG_CONTENT`, but the provider PATCH is unproven on the phone
  and reloads config; a builtin-provider override needs a different route.
  Not needed.
- Chosen: the agents already start through the app's own `opencode` wrapper
  (`AiTeamScripts.agentWrapperScript`, first on the agents' PATH). It now
  reads `~/aiteam/model` (one `provider/model` line) and exports
  `OPENCODE_CONFIG_CONTENT={"model":"provider/model"}` (OpenCode's inline
  config; the app already strips that variable on its own isolated paths, so
  it is a real OpenCode input) before `exec opencode ...`, including
  `opencode acp`. No file: OpenCode's own default. A value that is not a plain
  `provider/model` is ignored.

Unverified here (no device): that `opencode acp` starts its session on the
inline config's `model`. Device check below.

## Built

- Team settings: one row "Workers use <model> · Change. Takes effect the next
  time a worker starts." (only for the team inside the app), opening a kit
  sheet of the models the phone's OpenCode lists (enabled models of its
  catalog through the connection) plus "Same as this phone's OpenCode".
- Stored per profile: `oc.teamModel.<profileId>` (`lib/state/team_model.dart`).
- Applied at once on change: `BuiltinTeam.applyModel` writes/removes
  `~/aiteam/model` and refreshes the wrapper (so an older wrapper gains the
  reader). The file lives on the phone with the team, so every later start and
  tune keeps using it. A running worker keeps its model; the next start uses
  the new one. A failed write shows a notice and keeps the old choice.
- One row, one value: the planner uses the same model (same mechanism, all
  agents); no separate planner choice.
- Agent screen unchanged: it shows the model an agent actually ran with.

## Device check

Pick a different model, start a task, open the worker's screen: its model
should be the chosen one; pick "Same as this phone's OpenCode" and the next
worker follows the phone again.
