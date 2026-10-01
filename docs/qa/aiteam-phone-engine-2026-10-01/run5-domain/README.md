# Run 5: interrupted session recovery presentation

Finish line: real phone checkpoints expose the existing project/task Resume controls only for native restart/pause reconciliation when the engine advertises the matching command, and unsafe interruptions show Review with a typed static diagnostic.

Non-goal: change UI screens, submit/replay prompts, start a replacement session, alter native admission, or fabricate a recovery/merge receipt.

## Contract

- Raw `interrupted` planner checkpoints with `restartNeedsReconciliation` or `pauseNeedsReconciliation` present project `paused` when `resumeProject` is advertised. The original `planningState` and command revision stay unchanged.
- Interrupted approved projects present `paused` only when every interrupted task is resumable and `resumeProject` is advertised. Mixed safe and review-only checkpoints present `failed`; a blanket Resume would not truthfully promise recovery for all jobs.
- Interrupted tasks with either reconciliation reason present `paused` only when `resumeTask` is advertised. Other interrupted tasks present `review`. Native `resuming` presents `running`, meaning the existing session is being refetched; this creates no new prompt or session.
- The existing UI selects Resume for `paused`, so no screen/kit changes are needed. `executeProject` still probes health, refuses unadvertised commands as `unsupportedCommand`, and refuses execution if boundary/protocol gates do not pass.
- Read-only checkpoint timeline summaries expose only application-authored codes: `restartNeedsReconciliation`, `pauseNeedsReconciliation`, `recoveryNeedsReview`, `sessionUnknown`, `sessionFailed`, `sessionUncertain`, `promptUncertain`, and `sessionCreateUncertain`. Unknown model/error/path text is omitted. A review checkpoint does not suggest safe resend.
- Project revisions, task reasons, planner metadata, durable timeline entries, criterion results, and receipts remain authoritative. Presentation summaries are not persisted events or recovery receipts.

## Regression coverage

`test/phone_engine_status_presentation_test.dart` adds six cases covering successful Resume predicates, missing command advertisements, unsafe review/redaction, mixed checkpoints, refetch presentation, and preservation of explicit Stop/Pause. It updates the old planner `stalled` expectation to the advertised `paused` Resume contract.

Formatting and `git diff --check` passed locally. This worker did not launch Flutter tests, analyzer, native builds or emulator processes; the coordinator owns serialized execution and will record the results in the run 5 backend QA README.

## Limited admission diagnostics

Interrupted planning/task summaries now retain the scheduler's exact static admission codes, including `totalUsageUnknown`, `dailyUsageUnknown`, `tokenUsageUnknown`, `budgetReached`, and `taskTokenBudgetReached`. The scheduler does not return `budgetExceeded`; that invented value remains omitted alongside unknown private/error text. Two regressions cover every current scheduler admission code in both planner and task checkpoints, plus unknown-budget/secret redaction. These summaries stay read-only and never authorize prompt resend. Root owns the focused test rerun.
