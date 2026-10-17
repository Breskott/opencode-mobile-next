# OC2 checker interruption on APK 2318

Base: `547173dca`; branch: `codex/aiteam-oc2-interrupted`.
Input: [run4-2318.md](run4-2318.md) and its `r4-*` screenshots.
Run 4 established the first complete plan → worker → checker → dev merge on
OpenCode 2.0.29. The second project's checker completed on the server, but the
engine could not parse its final answer and retained an interrupted checkpoint.

Finish line: identify the second project's interruption, accept its unambiguous
OC2 answer format without weakening checker or merge authority, and document
the existing recovery API for the UI builder. Non-goals: UI changes, new retry
or acceptance overrides, automatic recovery, promotion to main, or changing
the OpenCode 1 path.

## Confirmed cause: a successful checker answer failed structured parsing

Diagnosis used only `adb -s emulator-5554`, read-only engine/OC2 HTTP requests,
read-only engine database inspection, and process/logcat evidence. The installed
app remained APK 2318. App PID `31200`, engine PID `32124`, and OC2 PID `32285`
were alive. The observed interruption was not an app, engine, or server crash.

The persisted job was interrupted with reason `structuredOutputInvalid` and
`resumeStage: checking`. Both worker and checker prompts were recorded as
`dispatched`. The OC2 checker session had completed successfully: idle outcome
`succeeded`, final assistant `finish: stop`, no error, absent from the active
session list, zero pending permissions, and zero pending forms. These
observations exclude a provider failure, outstanding permission/form, and a
still-running turn as the cause of this checkpoint.

The final assistant answer contained an explanatory inspection summary,
followed by a standalone, **unfenced** JSON object. That object contained
`criterionResults` for the exact three original criterion strings, all `met`,
and `findings: []`. The existing parser accepted a whole JSON response or one
explicit JSON code fence; prose followed by an unfenced object matched neither.
It returned `structuredOutputInvalid`. The pipeline's error handler then
persisted an interrupted job while preserving the checker session and commit.
This is a completed-turn parsing failure, not an observation race or timeout.

The allowlisted proof is [checker-interruption-proof.json](checker-interruption-proof.json).
Raw HTTP responses and the private read-only job snapshot remain under ignored
`build/qa/aiteam-oc2-interrupted/`; credentials are not copied into this record.

| Checkpoint | Observed value |
|---|---|
| Project | `project-0de98887-54a1-44b0-9086-0b7664f8e7e9` |
| Task | `task-1` |
| Job | `job-6bba332e-4a78-4e36-b549-1cf2fe1dca48` |
| Native project state | `running` |
| Native task/job state | `interrupted` / `structuredOutputInvalid` |
| Resume stage | `checking` |
| Checker session | `ses_ec30c6f89ffeZzJmkalVtFOtmZ` |
| Checked task commit | `b6b59f37deb34f72135241d2bd1460b703261b17` |
| Expected dev commit | `c6111974a3a5b62ba7c308eeee6e9666f90054a3` |

The temporary ADB forwards were removed and the emulator lock released. No
credentials were printed or committed. No resume, prompt, interrupt, stop, role change, or other state-changing command
was sent during this diagnosis. The original interrupted project is left for
recovery after the rebuilt engine and recovery controls are available. Repeating
Resume against the unchanged APK 2318 would re-read the same answer and fail
the same parser again.

## Engine change and preserved authority

The OC2 parsing path additionally accepts one unique trailing JSON object after
plain explanatory prose. It requires an unambiguous standalone object and
rejects multiple candidates, ambiguous structural text, malformed or duplicate
JSON keys, and trailing commentary. This compatibility is selected through
`e.server.is_oc2()`; the existing OC1 parser behavior remains unchanged.

Parsing only extracts a proposed result. The existing checker schema, exact
original-criterion matching, finding validation, protected boundary, recorded
session identity, and checked-commit comparison still decide whether it can
merge. Prose claiming success is not evidence, an unrelated JSON object is not
a checker verdict, and any open finding still blocks merge. Read-only checker
permissions remain unchanged. No prompt replay or automatic recovery is added.

## Why the UI says “Needs you” but offers no recovery

The native project was still `running`, with its only task `interrupted`.
`lib/orchestration/adapters/inapp/phone_engine_gateway.dart` projects generic
interrupted tasks to `review`, and a running project whose interrupted tasks
have no active peer to `failed`. Only `restartNeedsReconciliation` and
`pauseNeedsReconciliation` are recognized by `_resumableInterruption` and
projected to a resumable paused presentation.

The task page renders Resume for `paused` / `interrupted` status, or for an
explicit interrupted `TeamRequest`. The native checkpoint produces neither
after this projection: its status is `review` and no request is synthesized.
No checker result was published because parsing failed, so there are no
criterion results or findings to review. Lane transcripts are not copied into
the task's message list; the work log is the remaining evidence shown there.
The project menu sees `failed` rather than `interrupted`, explaining Pause/Stop
without Resume. This is a presentation gap, not the absence of a native resume
operation. This branch does not change Dart or UI controls.

## Recovery contract for the UI builder

Use `OrchestrationProjectGateway.executeProject` with a `TeamProjectCommand`.
Gate recovery on the engine's advertised actions and `projectResume`
capability, not the server flavor or the existence of a Dart enum member.
Refetch the project first and use the revision the person reviewed. Display the
interrupted checkpoint independently from the `review` board-column label.

### Check the existing checker run

The recommended label is **Check existing run** (or **Resume checker** with
equivalent explanatory copy). Send `TeamProjectAction.resumeTask`, target the
task ID, and disclose that a successful completed check can merge into dev.
The authenticated engine request is:

```http
POST /v1/commands
Authorization: Bearer <engine credential obtained privately by the adapter>
Content-Type: application/json

{
  "requestId": "<fresh unique request id, at most 128 characters>",
  "action": "resumeTask",
  "projectId": "project-0de98887-54a1-44b0-9086-0b7664f8e7e9",
  "targetId": "task-1",
  "expectedRevision": 123
}
```

`123` is illustrative; use the current project revision, never a hard-coded
value. Keep the same request ID and body when resolving an uncertain transport
result; the engine journals command results. A stale revision requires a
refetch and a newly reviewed command, not an automatic retry loop.

The engine admits a paused/interrupted checkpoint only with sufficient saved
authority. For this checker it requires its recorded session ID and directory,
a recognized resume stage, `dispatching` or `dispatched` prompt checkpoint,
and the checked task commit. Missing authority returns `needsReconciliation`;
a non-paused/non-interrupted task returns `taskNotPaused`. The command sets
the job to `resuming` and clears its interruption reason. It does not create a
session, send another checker prompt, change its model, or answer a permission.

The daemon then observes the exact recorded checker session:

- If still busy, it continues observing that turn.
- If complete, it parses and validates the verdict. A passing verdict must
  still match the original criteria and unchanged task commit before dev merge.
- Findings or unmet criteria produce `needsFix`, with no merge.
- A failed, blocked, unknown, malformed, or changed-commit result returns to
  interrupted review; Resume does not override those conditions.

In this observed project, successful recovery can finish the already-completed
checker without another model call. This has not yet been exercised on a
rebuilt APK. An accepted command is admission to reconciliation, not a promise
that the check or merge succeeded; refresh/watch the resulting workspace.

`resumeTask` changes an interrupted project back to running. Other queued tasks
may consequently become eligible, which recovery copy must disclose. It does
not unpause an explicitly paused project. For a paused project use
`TeamProjectAction.resumeProject` with project ID and current expected revision;
that command resumes **all** paused/interrupted checkpoints atomically, and
rejects if any checkpoint lacks safe recovery authority.

### Re-run, accept, stop, and discard

| Proposed control | Implemented contract / safe meaning |
|---|---|
| Re-run check / retry checker | **Not implemented.** `recheckTask`, `verifyTask`, and `restartTask` exist in the Dart enum but are not native command actions. Do not route to them or alias them to Resume. |
| Accept interrupted work | **Not implemented.** There is no `acceptTask` or checker-bypass API. `acceptPhase` and `acceptMilestone` only accept completed groups whose relevant tasks are already merged. |
| Stop task | `stopTask`, project ID, target task ID, current revision, `confirmed: true`. Permanently stops that checkpoint and makes a best-effort interrupt of its recorded sessions. It retains work/evidence and does not revert commits or delete the task branch. A stopped checkpoint cannot be resumed. |
| Discard task | **Not implemented.** There is no task-discard action. Do not describe Stop as deleting work. |
| Delete entire project | `deleteProject`, project ID, current revision, `confirmed: true`. Removes the whole project and jobs, interrupts known sessions, and cleans unreferenced repository storage. This is broader than discarding one task and requires that explicit destructive choice. |

Future checker re-run support would need a separate native action: prove the
previous turn is terminal (or positively interrupted), retain its evidence,
bind the replacement checker to the same reviewed task commit and original
criteria, validate current model/boundary/permissions and budget admission,
persist a fresh checker session and dispatch checkpoint, and retain idempotent
command behavior. It must never silently retry an uncertain prompt, rerun the
worker, change the checked commit, or bypass findings. This branch implements
none of those new actions. Native action advertising remains authoritative.

## Validation and delivery status

- Failing-first parser checks reproduced `structuredOutputInvalid` in the two
  new success cases; the ambiguity-rejection case already passed. After the
  fix all three parser tests passed, including the reviewed exact final checker
  answer in `engine/phone/tests/fixtures/oc2_checker_summary_verdict.txt`.
- The new `resumeTask` checkpoint regression passed: an interrupted checker
  with this parse reason survives storage reopen, resumes the same job/session,
  preserves model/dispatch/commit authority, and replays the command idempotently.
  Its first fixture incorrectly bound the model alongside session creation;
  the engine correctly refused `modelResolutionTooLate`. The fixture now binds
  the model before the session, matching production ordering.
- The final full Rust invocation passed **251 tests, 0 failed, 1 existing
  ignored** across all 25 default test targets (including doc tests):
  `cargo test --manifest-path engine/phone/Cargo.toml --locked -j 2 -- --test-threads=1`,
  under `tool/qa/machine_lock.sh test`. Fixture roots were isolated below
  ignored `build/qa/aiteam-oc2-interrupted`; the existing ignored raw-syscall
  proof requires Landlock ABI 6. No new skip was added.
- Both Android ABI bundles were rebuilt and staged with
  `CARGO_BUILD_JOBS=2 tool/qa/machine_lock.sh build -- engine/phone/tool/build-android.sh --stage-android`.
  All six ELF hashes and the current source digest match the staged manifest.
  Source SHA-256: `6e30ee989390385cc23a59adaadcefc639285e540a3a9b006d24edc0020e17fa`.
- Rust formatting, diff whitespace and evidence/link checks passed. No Dart
  files changed; Flutter, analyzer and Android instrumentation were not run.

APK 2318 provides diagnosis evidence only;
the source fix and recovery of this project still require rebuilt-APK emulator
verification. Engine native binaries require a new Shorebird release, not a
Dart-only patch. Nothing is pushed, signed, or released by this work.
