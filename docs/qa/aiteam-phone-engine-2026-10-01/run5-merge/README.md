# Run 5 automatic dev merge receipts

Finish line: a checked automatic dev merge records durable native intent before its Git ref update, and an interrupted caller can recover the exact scoped before/after receipt without re-merging or trusting worker metadata.

Non-goal: confirmation for dev merges, main promotion changes, UI changes, or broadening the phone boundary.

## Cause and change

`RepositoryAuthority.merge_dev` committed `refs/heads/dev` before returning its in-memory receipt. Death before the daemon published completion in SQLite lost the original before SHA. A retry could fail stale-dev, and merely reading current refs could not prove the earlier integration.

The daemon-facing `merge_dev_for_evidence` writes a prepared native journal in private `merges/` after syncing objects and before moving dev, then syncs the ref and writes applied. The journal binds repo, task, job ID, checked commit, before main/dev, after dev, and a SHA-256 fingerprint of the exact checker session/criteria/findings/results. A private 32-byte key authenticates its contents with HMAC-SHA-256. Neither key nor journals come from worker clones or app-editable config. Main remains untouched.

`recover_merge_dev` accepts only the matching authenticated checkpoint. Before-ref death applies its prepared transaction once; after-ref death returns its original before/after receipt and marks applied. Repeated retries are identical. A malformed/tampered journal, changed checker evidence/commit, or changed canonical main/dev refuses. A later dev integration cannot be overwritten with an older recovered receipt. Missing journals grant no recovered authority. Authentication key reads require an owner-matching regular file, one link, exact 32-byte length and mode 0600. Repository collection sweeps its journal directory; promotion receipts keep their existing retention policy. Legacy unbound `merge_dev` retains its strict stale-ref behavior for existing callers; the execution daemon uses the bound method.

The daemon owner serializes integration through SQLite completion publication and refetches the current persisted checker checkpoint for the fingerprint. That publication atomically completes the job/task and stores the scoped public receipt. Merge journaling closes the private Git-to-SQLite crash window; it does not accept model-supplied receipts.

## Regression checks

`engine/phone/tests/repository_merge_journal.rs` contains six focused regressions:

- Prepared before-ref crash recovers exact before/after, keeps main unchanged, and duplicate recovery does not merge twice.
- Prepared after-ref crash recovers original before, rather than current dev.
- Tampering, changed criterion fingerprint/checked commit, and wrong task scope grant no authority.
- Rewritten dev or changed main cannot publish an earlier receipt.
- Truncated journal returns an explicit refusal and leaves dev unchanged.
- Repository collection deletes its scoped journals without following descendants; profile deletion removes the entire private engine root.

The crash fixture reconstitutes the exact prepared journal using the native fixture's private key and canonical refs. This models trusted process death; it does not expose a runtime fault command to agents.

Formatting and diff checks pass. This worker did not run test/build processes; the coordinator records serialized host and device results in the run 5 backend QA README.
