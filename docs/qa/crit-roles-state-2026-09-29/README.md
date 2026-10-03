# AI Team roles: state slice (2026-09-29)

Implemented every body in `lib/state/team_roles.dart` (contract unchanged; additions only).

## Done
- Storage `oc.teamRoles.<profileId>` and `oc.teamTaskRoles.<profileId>`: both match `oc.<what>.<profileId>`, so `ProfileStore.profileScopedPreferenceKeys` (used by `deleteProfileAndLocalData`) sweeps them with no extra code. Corrupt JSON reads as empty; malformed entries are skipped.
- Built-ins stored only once edited (`update`); `reset` removes the stored copy. `TeamRoles.defaults` holds the shipped English instructions (each says to follow the repo's AGENTS.md/CLAUDE.md); general is empty.
- `suggest`: whole-word vocabulary score per built-in role plus words (3+ letters) of each role's name/purpose; top score wins; tie or none is general.
- `describeTaskForRole`: `Role: <name>\n<instructions>\n\n---\n\n<description>`; unchanged when instructions are empty. Unedited built-ins have an empty name, so the role id is used in the "Role:" line.
- `giveTaskAsRole`: awaits `applyModel(role.model ?? teamModel)` (errors swallowed, debugPrint of the type only), then `team.giveTask`, then remembers the role under `created.receipt.createdId` when accepted.
- `teamRolesFor(prefs, profileId)` caches one controller per profile.
- Added `roleOfRun(run, team)`: runs link to work by `WorkItem.runId`; roles are stored under the work id, so it looks through `team.snapshot.work`.
- Added `TeamRoles.defaults/defaultFor/vocabulary`.
- `TeamDispatchController.submit` got optional `role`, `roles`, `teamModel`, `applyModel`; with role+roles it goes through `giveTaskAsRole`, otherwise unchanged. This is how the UI should pass a role (the sheet already uses the dispatch controller).

## UI call sites of giveTask (for the UI agent)
- `lib/ui/screens/team/start_run_sheet.dart:430` `attempt.submit(...)` (through TeamDispatchController; the only UI path). `team_home_screen.dart:327 _startRun` opens that sheet.
- No other UI or workspace path calls `giveTask`. The only non-UI caller is `lib/state/team_dispatch.dart` (now branches).

## Interpreted
- `fromJson` forces `builtIn` from the id, and drops an invalid model string.
- `update` on an unknown id is ignored; `remove` of a built-in is ignored.
- Tasks given on a computer team pass `applyModel: null`.

## Device check
Give a task as Frontend, confirm the worker's first message starts with `Role: Frontend`-style text and the task page can look up the role via `roleOfTask(workId)` after restart.
Not run: tests, emulator (per brief). Analyze on lib/state: clean.
