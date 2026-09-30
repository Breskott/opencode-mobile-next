# Run 3 backend repair and live acceptance

Finish line: project creation gives its typed refusal or imports a committed scratch repo, then the real GLM-5.3 planner/worker/checker produce a dev merge and a confirmed, durable promotion. Non-goal: UI copy/screens and another device or physical-phone claim.

## Reproduction

Exact signed APK 2082 was installed with `adb -s emulator-5554 install -r` on OC_API35 under the shared emulator lock, with existing data preserved. Its certificate matches the known local release signer. Turn-on reached Ready; New project / Start planning reproduced the generic save-failed error. Metadata-only inspection showed `my-app/.git` had no objects/branch commits. The failed create left `retired/edit-1790793073442151-0.json` while the SQLite command table had no accepted create. No engine token or provider key was read onto the host.

Root cause on this preserved emulator: an unborn Git repository cannot seed canonical main/dev. The import wrote its binding before failing, and cleanup permanently retired the form's repo ID, poisoning corrected retries. HTTP errors additionally flattened the specific refusal into `engineUnavailable`/`saveFailed`. The reported committed-repo attempt is checked with the new live scratch journey below; no symlink cause is claimed from host inference.

## Verification

Initial focused Rust crate gate passed (141 tests). Dart focused gate passed (70 tests); QA release + androidTest compiled with packaged hashes verified. Counterfactual repository retry regression FAILS at retirement assertion on `1afc1ee3`.

First live committed scratch attempt: protection PASS, create/import FAIL. Device metadata positively shows proot `--link2symlink` wrote every loose Git object as an in-directory `.l2s.tmp_obj_*` chain. Native nofollow snapshot rejects it. This confirms the committed-repository cause separately from the unborn-repository/retry defect. Narrow dirfd object normalization and negative controls are now required; no symlink escape allowance is accepted.

## Returned static reason catalog

These are existing static Rust store/repository reasons, now preserved for authenticated command errors as well as durable refused receipts. Names use the existing casing. No raw OS/Git exception, config, path or credential is forwarded. Transport/protocol/native codes remain separately typed.

### Repository

`confirmation_required`, `divergent_import`, `import_binding_mismatch`, `invalid_commit`, `invalid_id`, `invalid_path`, `invalid_receipt`, `invalid_repository`, `invalid_request`, `legacy_receipt_scope_unknown`, `linked_repository`, `merge_conflict`, `overlapping_roots`, `promotion_not_fast_forward`, `promotion_recovery_required`, `promotion_superseded`, `receipt_encoding`, `repository_busy`, `repository_changed`, `repository_empty`, `repository_exists`, `repository_io`, `repository_retired`, `repository_too_large`, `repository_unavailable`, `request_id_conflict`, `shared_repository_objects`, `stale_dev`, `stale_main`, `stale_task`, `symbolic_ref_refused`, `symlink_refused`, `task_changed`, `task_not_descendant`, `task_rewritten`, `unsafe_repository_config`, `unsafe_repository_metadata`, `unsafe_repository_path`, `unsafe_source`, `unsafe_task_tree`, `worker_binding_mismatch`, `worker_exists`, `worker_reset_refused`.

### Store

`approveSpecFirst`, `chargingUnsupported`, `checkerMustBeReadOnly`, `chooseBudget`, `chooseExecutionMode`, `confirmationRequired`, `cursorExpired`, `dependencyCycle`, `invalidCommand`, `invalidCursor`, `invalidFixRounds`, `invalidJob`, `invalidJobPatch`, `invalidJobTransition`, `invalidPlacement`, `invalidPlan`, `invalidProfile`, `invalidRepositoryReceipt`, `invalidRequestId`, `invalidReviewLevel`, `invalidRole`, `invalidSpec`, `invalidTaskPatch`, `invalidUsage`, `jobNotFound`, `missingCriteria`, `missingDependency`, `missingProjectDetails`, `needsReconciliation`, `planAlreadyRunning`, `profileDeleted`, `projectBusy`, `projectNotFound`, `projectPaused`, `projectStopped`, `promptAlreadyDispatched`, `quickTaskNeedsOneRepo`, `repoNotFound`, `requestIdReuse`, `roleInUse`, `roleNotFound`, `sessionAlreadyRecorded`, `staleJobStage`, `staleRepositoryRefs`, `staleRevision`, `storageCorrupt`, `storageUnavailable`, `taskAlreadyDone`, `taskIdAlreadyUsed`, `taskNotFound`, `taskNotPaused`, `unsafeStoragePath`, `unsupportedAction`, `unsupportedServer`, `usageRegression`.

