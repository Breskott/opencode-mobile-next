# Run 4: worker/checker evidence contract

Finish line: authored worker/checker requests distinguish actual acceptance evidence from unresolved findings, preserving read-only checking and fail-closed merge validation.

Non-goal: waive findings, loosen `validate_check`, change tools or UI, or claim an unexecuted check passed.

## Trigger and behavior

The real GLM worker/checker journey returned four `met` criteria with explanatory successful observations in `findings`. Any finding intentionally blocks merge, so that answer was correctly refused. The previous request ambiguously applied `met/unmet/notApplicable` to both criteria and findings.

`checker_request(job)` now separates the two arrays with explicit JSON examples. `criterionResults` must copy every original criterion exactly and use `met/unmet/notApplicable`; findings are only actual unresolved defects with status `open`. All passing criteria with no defects require `findings: []`. The request forbids successful observations in findings, waivers, fabricated evidence, and claims about unexecuted checks. Missing required execution evidence is `unmet`.

`worker_request(job, branch)` requires a committed `.aiteam-verification.md` recording actual acceptance commands, working directory, exit codes and observed results, or inspected committed files for static criteria. Failed/skipped/not-run checks remain explicit. Evidence must contain no credentials. The checker can inspect that committed report with read/glob/grep; it cannot run shell commands or tests itself. Existing native tool policy and `validate_check` are unchanged.

A worker-authored report is evidence to inspect, not independent proof of command execution. This change clarifies the model contract; it does not introduce attestation of worker checks.

## Checks

Added unit regressions:

- `checker_prompt_separates_criterion_status_from_defects_and_requires_evidence`: checks status semantics, original criteria, read-only/nonfabrication rules, and parses both JSON examples through unchanged validation.
- `worker_prompt_requires_committed_actual_acceptance_check_evidence`: checks the committed actual-check evidence requirement, skipped/not-run distinction, branch limits and secret exclusion.
- `successful_observation_mislabeled_as_a_finding_still_blocks_merge`: successful-looking findings and `notApplicable` still block merge.

Rust formatter and `git diff --check` completed. No build or test process was launched for this slice; coordinator runs focused native checks and packages the resulting binary. No new device pass is claimed here.
