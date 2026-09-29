# AI Team project API

Finish line: a restart-safe simulated project journey from explicit settings to confirmed promotion, behind an optional domain gateway.
Non-goal: real engine, network, git, process or background service operations.

Import `lib/domain/team_project_gateway.dart` for models and commands. The optional gateway is independent of the older task gateway. `TeamProjectController(gateway)` exposes `snapshot`, `loading`, `busy`, `errorCode`, `load()`, `execute(command)`, and `newRequestId()`.

Use `TeamProjectCommand(requestId: controller.newRequestId(), action: ..., projectId: project.id, expectedRevision: project.revision, ...)`. Every mutation on an existing project requires its current revision. Result `accepted`, `code`, `projectId`, `revision`, `replayed` are safe UI state; localize codes. Never display caught errors.

`createProject` requires name, spec (goal), repos and settings. `createQuickTask` uses the same explicit inputs but bypasses spec approval. `settings.mode` is `single` or `parallel`; budget must have `chosen: true` and either `unlimited: true` or positive daily/total limits. `approvePlan` optionally carries the edited tasks/phases. `saveSpecDraft` carries spec. `answerRequest` uses targetId + text. Task actions use targetId. `moveTask` uses serverId and optional roleId. `promote` uses targetId (repo), confirmed, expectedDevCommit and expectedMainCommit. All values are simulated.

Construct `ProjectFixtureGateway(persistence: SharedPreferencesTeamProjectPersistence(prefs, profileId), now: optionalClock, tickInterval: optionalDuration, seedDemo: true)` in state integration only. The adapter implements both gateways; project mutations broadcast legacy work/gate dirty events. `TeamProjectController(gateway, profileId: profileId, ownsGateway: false)` shares a gateway owned by the existing orchestration controller. Default controller ownership is true.

`findingIds` scopes fix/ignore; an empty list means all open findings. `createQuickTask` requires exactly one repo, honors roleId/serverId, and `confirmed: true` starts immediately; false leaves a plan for approval. `isCharging` on the fixture adapter is simulated environment input. Task state strings: queued, running, review, findings, done, merged, paused, stopped, interrupted, stalled, failed. Project states: spec, plan, running, paused, stopped, done. Request kinds are question/permission plus targeted spec/plan/findings/recovery/phase/conflict/budget gates. Use the corresponding action for targeted gates.

Storage is versioned JSON at `oc.teamWorkspace.<profileId>`. No storage mutation is published until its write succeeds. Restart reconciles running tasks to interrupted. IDs and expected revisions survive restarts; repeating an identical accepted request returns its prior result without applying twice. Deletion closes/drains before removing its key. Snapshots and persisted user text are redacted with the shared KitRedact implementation.
