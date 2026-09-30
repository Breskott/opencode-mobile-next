# Phone engine status compatibility

Finish line: the real phone gateway presents a completed proposed plan as `plan` so the existing editor sends reviewed `approvePlan`, while incomplete or interrupted planning has honest existing-domain labels and its raw checkpoint remains available.

Non-goal: changing UI, daemon command admission, planner resend/recovery policy, command revisions, approval flags, native storage, or inventing merge receipts/queue items.

## Additive read contract

`PhoneEngineGateway.teamWorkspace` derives presentation after parsing the authenticated schema-1 snapshot. Public method names and command payloads are unchanged. Workspace/project revisions, `planApproved`, `planningState`, spec, tasks/phases content, server records, receipts and merge queue remain native truth.

| Native project status/checkpoint | Domain presentation status |
| --- | --- |
| `needsPlanApproval` (including an unconfirmed quick task without a planner job) | `plan` |
| Unapproved `planning`/`interrupted`, active planner `starting`, `planning`, `preparing`, `submitting`, `running` | `running` |
| Same project, queued/unknown checkpoint | `waiting` |
| Same project, failed or interrupted checkpoint | `failed` |
| Interrupted checkpoint requiring restart/pause reconciliation | `stalled` |
| Same project, paused/stopped checkpoint | `paused`/`stopped` |
| Explicit project pause/stop or approved project | Existing project status preserved |

The adapter never emits `planFailed`: that UI state exposes `retryPlan`/`usePlanAsTask`, which the native engine does not implement. No polling read executes or resends a command.

Native task `checked` means the daemon reached `mergeReady` after checker validation passed, so it presents as `verified`. `needsFix` presents as `findings`; `merging` presents as `running`. Native `review` and `merged` already match the domain. These mappings do not create or alter findings, criteria, queue items or receipts.

For an unapproved terminal planner checkpoint, one derived current-checkpoint timeline row supplies static copy. Only known safe reason codes (`sessionFailed`, `promptUncertain`, `modelUnavailable`, `modelInvalid`, restart/pause reconciliation) are included in this canned copy; an unrecognized reason receives generic review wording. The original typed `planningState` remains unchanged. This is a current observation, not a fabricated durable historical event, and repeated reads do not append to the daemon log.

## Evidence and gate

Six focused tests in `test/phone_engine_status_presentation_test.dart` cover completed planner -> visible plan -> unchanged reviewed approve command, quick task approval, active/terminal checkpoints, failed model/server reason presentation without writes, pause/stop preservation, and checker/merge vocabulary without invented receipt evidence.

Pinned Dart formatting and `git diff --check` passed. No Flutter tests/analyzer/native/device processes launched by this worker. Coordinator must run the new test and existing `phone_project_engine_gateway_test.dart` under the serialized gate.

Residual backend integration gap reported to the store owner: the real task promotion UI requires a nonempty native merged/checks-passed merge queue. This adapter does not synthesize those records from a task status alone.

Implemented and locally committed with `[skip ci]`; integration/verification/deployment remain separate coordinator gates. No push or UI changes.
