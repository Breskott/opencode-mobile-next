# APK 2315 AI Team / OC2 failures: diagnosis and fix

**Correction, 2026-10-15:** the `ENOENT` trace below did not prove that the
engine exited. APK 2316 diagnosis found the same lookup failing while signal
zero and `ps` proved the daemon was still alive. Its inspection protection hides
metadata from the app. See [root-cause-2.md](root-cause-2.md) for the corrected
cause and authenticated live-child fix. The confirmed-exit guard below remains
fail-closed but does not resolve a hidden live process.

Candidate base: `e7f4fa231`, branch `codex/aiteam-oc2-emulator-fixes`.
Diagnosis used only `adb -s emulator-5554`, with the emulator lock held.
The installed app was version 1.3.0, build 2315. No APK was replaced, no
app data was cleared, and the app was not uninstalled or force-stopped during
this follow-up. The screenshots below show the **old APK failing**, not the
new code passing.

Finish line: preserve OC2 during Add tools, let confirmed process exits pass
ownership capture safely, and offer Android recovery for genuine ownership
uncertainty. Non-goals: changing lane permissions, OC1 protocol behavior,
engine binaries, or qualifying AI Team task execution without a rebuilt APK.

## P0-1: a process exits during the ownership snapshot

The component-recovery message was a wrapper, not proof that an OC2 archive
rollback failed. The APK's exact R8 mapping resolves the nested exception in
[s36.png](s36.png) as follows:

| APK frame | Source at the candidate base |
|---|---|
| `gh.o0:413` | `BuiltinLinux.knownOtherRuntime`, line 2136 |
| `gh.W1:54` | `knownOtherRuntime$default` / `startQualifiedInstaller`, line 499 |
| `gh.T1:19` | `startInstaller` wrapper, line 488 |

Mapping SHA-256:
`ea97d08de061a8019e86540e0f5fd3b2c5ca80c1a2c324202eb75c68da0e8ea8`.
The unrelated mapping in the main checkout's build directory was not used.

`knownOtherRuntime` first checks tracked processes' `isAlive`, enumerates their
PIDs and descendants, then reads each `/proc/<pid>/stat`. Previously any null
identity immediately threw `ownershipUnknown`. A process can exit between those
operations. Java's `FileNotFoundException` also covers access failures, so the
stack alone did not establish whether this was an exit or a permissions issue.

A bounded 20-second `strace -f -b execve -e trace=open,openat,kill` attached to the
app during the actual Restart confirmation resolved that ambiguity. The only
per-PID stat opens in that trace were:

```text
openat(AT_FDCWD, "/proc/12798/stat", O_RDONLY) = 200
openat(AT_FDCWD, "/proc/15867/stat", O_RDONLY) = -1 ENOENT (No such file or directory)
```

PID 15867 was present in the preceding same-UID process snapshot. It was gone
when the app read its identity. The restart again failed; see
[diagnosis-2315-restart.png](diagnosis-2315-restart.png). Earlier retries without
tracing also failed. The trace detached at child exec to avoid tracing the
PRoot workload. Raw trace, logcat and private preferences remain untracked;
only the two allowlisted syscall lines above are published. Device trace and
UI-dump scratch files were removed, and the emulator lock was released.

The installer preferences had a generation counter but no pending ticket at
the inspected failure. The failing snapshot runs before creation of the next
installer ticket. The installed opt tree contained OC2 and its `.oc-good`
backup, with no `.oc-pending` in that directory. This is evidence of failure at
admission, not evidence that a particular 2.0.28 → 2.0.29 archive is corrupt.
The original first-switch failure uses this shared start/recovery path, but a
fresh 2.0.28 upgrade was not replayed in this follow-up.

### Native correction and safety boundary

`NativeRuntimeOwnership.capturePeers` now handles the snapshot race. A missing
identity is omitted only when the existing native absence probe confirms the
old same-UID peer is gone. That probe uses signal zero and the existing
`NativeInstallerVisibility` errno policy. A still-live peer, an uncertain probe,
an invalid PID, or an over-limit inventory still blocks. A failed `/proc` read
alone never grants permission to proceed.

Installer capture now includes the server through the same bounded helper,
instead of a second unguarded identity map. Receipt identity, nonce, inventory,
drain, and component-update rules remain in force. No receipt is erased and no
unknown process is killed by this fix. The helper is shared native lifecycle
code; the OC1 protocol, runtime selection and permission policy are unchanged.

## P0-2: Add tools lost the selected runtime

Both Add tools entry points supplied only `SetupJobParams.adding(ids)`.
A completed job intentionally does not lend its parameters to a new job.
Without an explicit runtime, the dependency-expanded OpenCode component and
start step defaulted to OC1. Adding AI Team therefore checked/installed OC1
and restarted it, even when the selected phone profile was OC2.

The phone card and AI Team onboarding now pass the selected profile's runtime
in `params['opencode']['runtime']`. Unknown profiles are refused rather than
defaulted. OC1 still selects OC1. Tests cover completed and stale failed OC1
jobs followed by OC2 Add tools, plus interrupted OC2 resume using the OC2 pin.

## P1: plain recovery instead of repeated restarts

Native ownership failures get the stable code `runtime_ownership_unknown`.
The method channel and native setup runner preserve that classification without
exposing a stack or private paths. Dart also recognizes legacy
`ownershipUnknown` details from older native errors. Setup progress carries
the classification through check, launch and start-step failures.

The starter treats this as non-retryable. Launch healing does not schedule an
extra start for it. AI Team setup, This phone, the phone card, saved-server
connection card, connection banner and setup progress offer **Open app
settings** with instructions to **Force stop**, then reopen OpenCode. The
existing bridge opens this app's Android settings. The copy explicitly says
not to clear storage or uninstall; saved chats and projects are retained.
Technical details stay in Details. English and Arabic copy and screen catalog
recovery cases are included.

This action is an escape route for ownership that genuinely cannot be proved;
it is not a substitute for fixing the confirmed-exit race. Reopening still
performs native ownership checks and does not bypass them.

## Verification and remaining qualification

- Pure JVM regression: baseline with the old null-identity behavior failed the
  two confirmed-exit tests (100 tests, 2 failures). Updated code passed **101
  tests** across `NativeRuntimeOwnershipTest`, `NativeInstallerOwnershipTest`,
  `NativeInstallerVisibilityTest` and `NativeInstallerAdmissionTest`.
- The harness used cached Kotlin/JUnit 4.13.2, a 256 MB Kotlin compiler heap,
  a 128 MB JUnit heap, and `tool/qa/machine_lock.sh` build/test slots. It compiles
  the pure ownership/admission classes, not the full Android application.
- Dart source formatting/parsing, ARB JSON consistency and `git diff --check`
  were checked. **Flutter tests and analyzer were not run**, per the job's
  tool restriction. No full Gradle/Android build was run.
- The standalone Dart Widgetbook coverage check could not resolve its
  `analyzer` dependency in this checkout; it remains for the Flutter-enabled
  integration environment.
- No Rust source changed; no engine restaging or Rust test run was needed.
- **A new APK / Shorebird native release is required.** A Dart patch cannot
  deliver the Kotlin fix. Nothing was pushed, signed, released or installed.

Run these focused files with the repository-pinned Flutter:

```text
test/builtin_server_test.dart
test/builtin_server_autostart_test.dart
test/setup_engine_test.dart
test/setup_finish_host_test.dart
test/team_phone_onboarding_test.dart
test/phone_server_card_test.dart
test/phone_team_setup_test.dart
test/phone_setup_progress_screen_test.dart
test/this_phone_screen_test.dart
test/this_phone_plain_failures_test.dart
test/saved_server_connection_card_test.dart
test/connection_status_presentation_test.dart
```

Also run `widgetbook/test/standard_check_test.dart` from the widgetbook package,
its `dart run tool/coverage_check.dart`, and the app's `test/kit_ratchet_test.dart`.
Run the analyzer at the integration checkpoint.

After rebuilding, rerun the original emulator journey: first OC2 switch from
2.0.28, Add tools → AI Team without changing OC2, protected restart, a small
team task, and a needs-you response. Confirm no retry loops on an injected
ownership failure, and that App settings opens the correct package. The
existing Python/AI Team Installed-line discrepancy, discoverability and extra
profile observations are not independently qualified by this fix.
