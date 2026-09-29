# AI Team project API

Finish line: a restart-safe simulated project journey from explicit settings to confirmed promotion, behind an optional domain gateway.
Non-goal: real engine, network, git, process or background service operations.

Import `lib/domain/team_project_gateway.dart` for models and commands. The optional gateway is independent of the older task gateway. `TeamProjectController(gateway)` exposes `snapshot`, `loading`, `busy`, `errorCode`, `load()`, `execute(command)`, and `newRequestId()`.

Use `TeamProjectCommand(requestId: controller.newRequestId(), action: ..., projectId: project.id, expectedRevision: project.revision, ...)`. Every mutation on an existing project requires its current revision. Result `accepted`, `code`, `projectId`, `revision`, `replayed` are safe UI state; localize codes. Never display caught errors.

`createProject` requires name, spec (goal), repos and settings. `createQuickTask` uses the same explicit inputs but bypasses spec approval. `settings.mode` is `single` or `parallel`; budget must have `chosen: true` and either `unlimited: true` or positive daily/total limits. `approvePlan` optionally carries the edited tasks/phases. `saveSpecDraft` carries spec. `answerRequest` uses targetId + text. Task actions use targetId. `moveTask` uses serverId and optional roleId. `promote` uses targetId (repo), confirmed, expectedDevCommit and expectedMainCommit. All values are simulated.
