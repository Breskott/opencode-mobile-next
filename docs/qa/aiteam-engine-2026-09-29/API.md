# AI Team project API

Finish line: a restart-safe simulated project journey from explicit settings to confirmed promotion, behind an optional domain gateway.
Non-goal: real engine, network, git, process or background service operations.

Import `lib/domain/team_project_gateway.dart` for models and commands. The optional gateway is independent of the older task gateway. `TeamProjectController(gateway)` exposes `snapshot`, `loading`, `busy`, `errorCode`, `load()`, `execute(command)`, and `newRequestId()`.

Use `TeamProjectCommand(requestId: controller.newRequestId(), action: ..., projectId: project.id, expectedRevision: project.revision, ...)`. Every mutation on an existing project requires its current revision. Result `accepted`, `code`, `projectId`, `revision`, `replayed` are safe UI state; localize codes. Never display caught errors.

`createProject` requires name, spec (goal), repos and settings. `createQuickTask` uses the same explicit inputs but bypasses spec approval. `settings.mode` is `single` or `parallel`; budget must have `chosen: true` and either `unlimited: true` or positive daily/total limits. `approvePlan` optionally carries the edited tasks/phases. `saveSpecDraft` carries spec. `answerRequest` uses targetId + text. Task actions use targetId. `moveTask` uses serverId and optional roleId. `promote` uses targetId (repo), confirmed, expectedDevCommit and expectedMainCommit. All values are simulated.

Construct `ProjectFixtureGateway(persistence: SharedPreferencesTeamProjectPersistence(prefs, profileId), now: optionalClock, tickInterval: optionalDuration, seedDemo: true)` in state integration only. The adapter implements both gateways; project mutations broadcast legacy work/gate dirty events. `TeamProjectController(gateway, profileId: profileId, ownsGateway: false)` shares a gateway owned by the existing orchestration controller. Default controller ownership is true.

`findingIds` scopes fix/ignore; an empty list means all open findings. `createQuickTask` requires exactly one repo, honors roleId/serverId, and `confirmed: true` starts immediately; false leaves a plan for approval. `isCharging` on the fixture adapter is simulated environment input. Task state strings: queued, running, review, findings, done, merged, paused, stopped, interrupted, stalled, failed. Project states: spec, plan, running, paused, stopped, done. Request kinds are question/permission plus targeted spec/plan/findings/recovery/phase/conflict/budget gates. Use the corresponding action for targeted gates.

Storage is versioned JSON at `oc.teamWorkspace.<profileId>`. No storage mutation is published until its write succeeds. Restart reconciles running tasks to interrupted. IDs and expected revisions survive restarts; repeating an identical accepted request returns its prior result without applying twice. Deletion closes/drains before removing its key. Snapshots and persisted user text are redacted with the shared KitRedact implementation.

Editor drafts: `readEditorDraft(target) -> Future<String?>`, `saveEditorDraft(target,text) -> Future<void>`, `clearEditorDraft(target) -> Future<void>`. Denied/failed writes throw a generic safe StateError. `drainEditorDrafts()` closes new writes and drains pending work; call after disposal and before the profile sweep. Optional `preferences` constructor input avoids a separate preferences lookup. Storage key: `oc.teamEditorDrafts.<profileId>`.

Review follow-up: `processMergeQueue` requires `confirmed:true` for `reviewLevel:everyStep`; targetId selects one repo (empty selects all). Promotion requires relevant risky phases accepted. `milestone` requests place the milestone ID in `phaseId` as the target, pending a separately typed request target in a real engine. Safe phase completion is automatic; risky phase requests use `acceptPhase`, milestone requests use `acceptMilestone`. Replan preserves active phases and running tasks. Spec drafts with pending changes create a fresh spec-review request.

Final fixture scenario commands (all existing-project commands require expected revision):
- `simulatePlanFailure`: unapproved planned project becomes `planFailed` with a `planFormat` request. `retryPlan` produces another structured plan; `usePlanAsTask` makes one editable task. Neither starts without approval.
- `simulateManualCommit`: targetId repo, optional text commit label; preserves an explicit before/after receipt on **dev only**. confirmed false simulates rebasing task branches; true plants conflicts. `simulateConflict` targets one merge item. Unaffected queue entries continue.
- `resolveConflict`: targetId queue item, text `agent` creates a checked task in that item's original branch; `manual` leaves conflict waiting for you; `recheck` clears it only after manual resolution was started. Manual waiting reason is `Waiting for your conflict resolution`.
- `moveTask`: no shared remote on started work fails with `sharedRemoteRequired`. Only confirmed true starts over on the destination with a new branch/context, zeroed execution/findings and an audit note retaining the old branch.
- `TeamTask.criterionResults` reports `TeamCriterionResult(criterion,status)` (`met`, `unmet`, `notApplicable`); an empty list means not checked. `TeamProject.budgetWarning` reflects 80% daily/total usage and a once-per-day timeline notice. These are simulated reports, never real costs/checks.
