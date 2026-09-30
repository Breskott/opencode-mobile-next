# Repository review slice

Finish line: untrusted authored trees are rejected before private checkout or dev integration, corrupted receipt bodies block only their durably scoped repository, and a fenced backend can collect unreferenced canonical repositories and worker clones without following agent symlinks.

Non-goals: changing daemon command sequencing, UI, attestation, checker trust, or deleting promotion audit receipts. Root integrates the collection API after authoritative store acceptance and cancellation/fencing of pipelines.

## Contract and behavior

- `RepositoryAuthority::collect_unreferenced_repositories(&[String]) -> Result<Value>` validates all retained IDs before mutation and holds the authority flock. It returns `removedRepoIds` and `receiptsRetained: true`. The list must include **every** currently committed repository ID, not only the current project's repositories.
- Collection deletes canonical repositories, import bindings, entire exported worker subtrees and worker records for unreferenced IDs. It handles mode-000 directories through descriptor-anchored chmod and unlinks symlinks without following their targets. Receipts, receipt scopes and durable retirement markers remain until profile deletion. Collected repository IDs cannot be reimported; a caller must allocate a new ID.
- `repository::erase_tree_no_links(&Path) -> Result<()>` is a trusted native cleanup helper. The native caller must constrain the absolute target to an app-owned root. It checks parent ancestors without following symlinks, anchors mode-000 directory access with O_PATH, bounds traversal to 128 levels/200000 entries, accepts a missing final child, and never follows descendant symlinks. Intermediate missing parents remain an error.
- Git object-tree validation runs before import installation, worker checkout, worker collection and dev integration. It rejects duplicate names, dot/dotdot/.git components (case insensitive for .git), unsafe modes, and empty/absolute/parent-traversing/oversized symlink targets. Ordinary relative symlinks and gitlink entries remain supported. Existing private canonical dev trees are checked before checkout too.
- New promotion receipt scopes (`receipt-scopes/<requestId>.json`) are durable before their intent body. Reconciliation filters by this scope before strictly reading a receipt. A legacy receipt with readable `repoId` also scopes errors correctly. A completely corrupted legacy receipt lacking a scope remains fail-closed as `legacy_receipt_scope_unknown`; it is preserved for operator review rather than guessed or discarded. A malformed scope itself also remains fail-closed.
- Arbitrary staging snapshots cannot safely be attributed to a repository ID and are not collected here; normal RAII snapshot cleanup still applies. An app process killed while importing can leave an unattributable staging directory until whole-profile deletion. Audit receipts/scopes/retirement markers are deliberately retained and small; they are not a promise of zero retained metadata after project deletion.

## Verification

Added repository regressions exercise crafted raw tree objects, safe relative-symlink positive controls, corrupted scoped and legacy receipt behavior, selective collection, mode-000 cleanup, symlink escape negatives, retirement and invalid retained-ID rejection. These tests would allow unsafe trees/unrelated receipt blocking or fail compilation/behavior without the new boundary/API.

Worker checks: `cargo fmt --manifest-path engine/phone/Cargo.toml` and `git diff --check`. No cargo tests/native builds were launched by this worker; root runs the serial machine-locked Rust gate and records the results. No device proof, deployment or UI behavior is asserted here.
