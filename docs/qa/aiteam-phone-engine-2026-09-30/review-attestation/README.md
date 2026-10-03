# R9: bounded binary digest cache

Finish line: repeated live boundary checks avoid reading unchanged packaged ELF
bytes while binary mutations and changed attestation authority still fail closed.
Non-goal: caching receipt validity, signatures, runtime identity, or enabling
execution on an unverified device.

Only SHA-256 digests enter a process-local 64-entry LRU cache. Every lookup opens
the requested regular file with `O_NOFOLLOW|O_NONBLOCK|O_CLOEXEC`; its key includes
device, inode, length, and nanosecond mtime **and ctime**. Before returning either
a fresh or cached digest, the code rechecks metadata on that same descriptor and
on a fresh no-follow open of the current path. Removed, unreadable, symlinked,
nonregular, concurrently modified, or replaced files never receive a fallback
cached digest. A poisoned cache lock also fails closed.

Receipt bytes, detached signature, signer pin, generation, parent process,
policy, kernel, boot identity, elapsed-time conditions, and complete boundary
controls remain checked on every `verify` / `verify_current` call.

Regression coverage:

- Twenty unchanged checks perform exactly one byte-hash; eviction is bounded and
  forces a new hash when a binary is no longer retained.
- Replacing an inode and writing the same length while restoring mtime both
  force new hashes (ctime distinguishes the latter).
- Same-descriptor mutation and path replacement are rejected by the identity
  guards even when the old descriptor remains open.
- Removed, symlinked, and nonregular paths cannot borrow a cached digest.
- Repeated accepted attestation checks still reject a tampered detached
  signature, a changed parent pin, and a replaced binary.

Validation in this worker: `cargo fmt` and `git diff --check`. Heavy checks are
reserved for the coordinator's machine-locked gate; these tests have not been
executed in this worker, and no Android runtime evidence is claimed.

Suggested focused commands from `engine/phone` under the machine lock:

```sh
cargo test --lib attestation::cache_tests
cargo test --test attestation
```
