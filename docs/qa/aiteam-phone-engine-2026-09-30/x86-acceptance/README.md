# x86_64 bundle and live acceptance handoff

Finish line: the engine branch supplies matched ARM64/x86_64 native bundles and
one command that exercises real startup proof, a reviewed scratch task, checked
dev merge, confirmation refusal and durable confirmed promotion in an isolated
preview app.

Non-goal: UI activation, model authentication setup, weaker emulator protection,
APK signing/install, running a host daemon, release, or claiming every review
finding is closed.

## Implemented and verified locally

The build script defaults to both ABIs. Schema 2 records per-ABI ELF hashes and
one exact Rust source digest. Native uses the actual installed ELF architecture;
all three files must match the selected manifest entry. Existing x86_64 proot
and Ubuntu support are retained. Unsupported kernel/proot controls stay closed.

The test APK contains framework instrumentation in the preview app UID. It uses
the real native startup/proof, private credentials, pinned OC1 sessions, Git
refs, SQLite workspace and durable authority receipts. The host never receives
the token/password and cannot inject a proof or idle lease. Its six-step output
is strictly parsed and raw output is discarded.

Executed against the integrated source on this branch:

| Check | Result |
| --- | --- |
| `cargo test --locked -- --include-ignored --test-threads=1` | 97 passed, 0 failed, 0 ignored; includes actual host boundary controls, thread/pipe lifetime, delayed-turn/refetch/stop and seven fresh-clone recovery tests |
| Six focused Flutter files, pinned `--no-pub --concurrency=1` | 60 passed: team controller, phone controller/gateway, native bridge, profile store and secure storage |
| Pinned `flutter analyze --no-pub` | Clean |
| Host acceptance wrapper tests | 12 passed |
| `:app:compileReleaseKotlin :app:compileReleaseAndroidTestKotlin -PocPreview=true`, JDK 17 | Passed; existing toolchain warnings remain |
| Rust formatting, shell syntax and Git whitespace | Passed |
| Device, real provider task and separate UI journey | Pending; adb lists no attached device, including emulator-5554 |
| Full Flutter suite, APK signing/install, push/CI/release | Not performed |

All heavy checks used machine locks and pinned toolchains. An intermediate
compile found the SDK does not export `OsConstants.O_DIRECTORY`; opening with
supported flags plus same-descriptor directory/inode verification fixed it.
An authored stop test initially omitted the required confirmation; the corrected
confirmed stop proves unknown-turn grace does not defeat cancellation. Those
failed intermediate candidates are not claimed as passes.

## Review fixes included in this handoff

- C1: child stdin EOF follows whole app lifetime. A real child survives its
  launch thread exiting and terminates when the retained parent pipe closes.
- C2/S3: trusted Android app-data aliases normalize; descendants remain nofollow.
- S1: port 0 is bound before an authenticated child-pipe readiness message.
  Native verifies that message before sending any bearer token to TCP.
- R1: explicit recorded-session reconciliation is reachable. A completed worker
  proceeds to a new checker without worker resubmission. Proven undispatched
  abandoned clones reset safely; uncertain/missing dispatch evidence blocks.
- R2: the first absent turn after async acceptance waits within a bounded grace
  window. Transient observation failures refetch the same session, never prompt.
- R3: usage refreshes workspace/usage revisions without changing command revision.
- R4: worker namespace events never teach person directories. LRU and fresh
  connected snapshots permit safe recovery from unknown evidence.
- R5/R6: team dispatch has a five-second bound, checkpoints dispatch intent/ACK,
  rechecks cancellation after dispatch and aborts the exact recorded session.
  Deletion fences dispatch and cancels pipeline futures after durable tombstone.
- D1/D2/D6/D7: accepted POST results survive refresh failures; edits retain the
  Keystore token; older snapshots are discarded; closed clients are pruned.
- D8: retained tombstone fencing and deletion retry are tested across restart.

This is a partial review response. Remaining items include agent-authored-tree
hardening, canonical garbage collection, charging telemetry, hash/event-log
efficiency, damaged-receipt operator recovery, native PDF/inventory/probe-lock
ergonomics, inactive credential-copy uninstall sweep, first-attach deletion
integration, queued error wording and monitor attention credentials. Native
deletion now handles readable read-only directories via verified descriptors;
mode-zero worker trees can still require a separate native deletion repair.
Arbitrary interrupted merge/fix/permission checkpoints do not automatically
resume. The checker remains advisory model evidence; promotion must review the
actual dev diff and expected refs independently of its verdict.

The coordinator-supplied review file is retained unchanged; this follow-up does
not rewrite its findings or claim device verification from host tests.

## Run the real acceptance

Prepare the disposable preview Ubuntu, pinned OC1 and model authentication, then
install matching preview app and release instrumentation APKs signed with the
same certificate through the separately authorized delivery workflow. Android
instrumentation restarts its target process. No signing/install is automated by
the wrapper.

```bash
tool/qa/phone_engine_acceptance.sh \
  --serial emulator-5554 --server http://127.0.0.1:4097 \
  --model '<provider>/<model>' --isolated-qa --allow-model-spend
```

The server URL is device loopback. The selected model must already work inside
the preview. This requests actual planner/worker/checker usage; no dollar ceiling
is invented from unknown cost. A real on-device proof must pass before lanes or
canonical promotion enable. x86_64 packaging alone cannot establish that.

See [wrapper contract](../acceptance/README.md),
[runner lifecycle](../acceptance-runner/README.md),
[dual build](../x86-build/README.md) and
[additive UI handoff](../../../design/aiteam-inapp-engine-2026-09-30.md).
