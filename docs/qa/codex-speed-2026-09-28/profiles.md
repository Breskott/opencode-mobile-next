# Bounded secure profile restoration

Finish line: restore profiles in saved order with at most four concurrent secure
reads, reducing multi-profile startup wait while retaining reentry flags and
redactor registration before `load()` returns. Non-goals: metadata-only shell
exposure, credential/storage format changes, or controller/UI changes.

`ProfileStore.load()` previously awaited one secure read per saved profile in
sequence. It now restores groups of at most four profiles with `Future.wait`.
The shell/bootstrap contract is unchanged: callers must still await `load()`;
every read has completed and every recovered secret is registered with
`KitRedact` before that future resolves. Metadata ordering is unchanged.

The focused host harness in `test/perf_profile_load_test.dart` compares the
previous serial secure-read ordering with actual `ProfileStore.load()`, using
the same mocked secure-storage channel and eight 20 ms scripted delays. Observed
scripted wait was 160 ms before and 40 ms after, with peak pending reads increasing
from one to four. These are virtual-clock scheduling measurements, not Android
Keystore or cold-start measurements. One saved profile has no latency reduction;
a native implementation serializing its reads may also show no reduction.

The mixed-backend test checks out-of-order completion and individual read
failures. An unreadable secret marks only its profile for reentry; a missing
mandatory Codex token requires reentry. Missing OpenCode passwords and Paseo
secrets retain their existing optional-authentication behavior. Storage keys,
profile deletion, and serialized metadata do not change. No secret/error text is
logged or included in assertion values.

Coordinator validation passed the two focused harness tests (see README ledger).
Preservation checks run under the machine lock:

```bash
tool/qa/machine_lock.sh test -- "$FLUTTER" test --concurrency=1 \
  test/perf_profile_load_test.dart test/profile_store_test.dart \
  test/profile_secure_storage_test.dart
```

No UI hookup is necessary. This optimization applies wherever bootstrap awaits
`ProfileStore.load()`.
