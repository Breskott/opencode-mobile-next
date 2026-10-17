# Protected OC2 start on APK 2316

Base: `8d959a41d`; branch: `codex/aiteam-oc2-protected-start`.
Input: the coordinator's `rerun-2316.md` / `r2-*` record (read from the batch
checkout; those files were not yet tracked in this base). Diagnosis used only
`adb -s emulator-5554`, version 1.3.0 / build 2316. The physical phone was not
accessed. No app data was cleared, no force-stop was performed in this
follow-up, and no replacement APK was installed.

Finish line: fix the ownership refusal that prevents protected OC2 from being
launched, preserve the boundary, and share the start failure with the shell.
Non-goals: changing OC1 protocol behavior, relaxing sandbox restrictions, or
claiming fixed-device qualification before a rebuilt APK is tested.

## Confirmed cause: the live engine deliberately hides its process metadata

The engine sets `PR_SET_DUMPABLE=0` in `startup_hygiene` before loading secrets.
On this Android emulator, its parent app cannot read `/proc/<engine-pid>/stat`.
The server launcher nevertheless tried to read that file while capturing
known native peers for its installer/ownership admission. The engine was
alive, so the fallback absence probe correctly refused to treat it as gone.
That produces `ownershipUnknown`, mapped by APK 2316 to `componentRecovery`.
The changed label did not mean the ownership problem was fully resolved.

A bounded file-open/signal trace of the app during an actual Restart reproduced
this sequence (only metadata calls are published):

```text
openat(AT_FDCWD, "/proc/19525/stat", O_RDONLY) = 143
openat(AT_FDCWD, "/proc/20175/stat", O_RDONLY) = -1 ENOENT (No such file or directory)
kill(20175, SIG_0) = 0
```

Both before and after the failed restart, `ps -A -o UID,PID,PPID,NAME` showed:

```text
10192 19525   359 io.github.eslamasabry.opencode_mobile
10192 20175 19525 libaiteam_engine.so
```

There was no OC2 server process. The same daemon PID survived the retry.
`ENOENT` here means hidden metadata, not an exited process. This corrects the
causal inference in [root-cause.md](root-cause.md): its APK 2315 trace alone
could not prove exit. The earlier confirmed-exit handling remains conservative
and useful, but cannot admit this live hidden peer.

See [r3-before-retry.png](r3-before-retry.png) and
[r3-after-retry.png](r3-after-retry.png). These are screenshots of **unmodified
APK 2316 failing**, not of the new implementation passing.

The trace used `strace -f -b execve -e trace=openat,kill` for 15 seconds against
the exact app PID, through emulator root; no app-private file contents,
credentials, argv or environments were captured for publication. The tracer
was detached, its device scratch file removed, and the emulator lock released.
Raw diagnostic output remains in ignored local build artifacts.

## OC1 versus OC2 protected launch

| Concern | OC1 | OC2 |
|---|---|---|
| Program | `opencode` via `/usr/local/bin`, installed under `/opt/opencode` | `opencode2` via `/usr/local/bin`, installed under `/opt/opencode2` |
| Guest user / HOME | root, `HOME=/root` | Same |
| Working directory / environment | `/root/projects`, clean `/usr/bin/env -i`, fixed PATH, `TMPDIR=/tmp` | Same |
| Data/config | Existing OC1 defaults | XDG data/cache/state/config under `/root/.oc-opencode2`; explicit config and DB paths; old config overrides unset |
| Password | `/root/.oc-builtin/server.password`, username `opencode` | Same password file and username; both `OPENCODE_SERVER_PASSWORD` and `OPENCODE_PASSWORD` exported |
| Bind | `127.0.0.1:4097` | Same |
| Dart readiness | Authenticated probe falls through to `/global/health` | Basic-auth `/api/health`, then `/api/info` on stable-route 404 |
| Wait budget | 90-second server readiness, two-second poll gap | Same; individual HTTP operations have eight-second timeouts |
| Protected wrapper | Shared native PRoot/Landlock selection and policy | Same; no OC2-only environment or permission downgrade |

The Rust phone engine does not execute the OpenCode server binary. Its native
launcher uses separate private-pipe authentication and `/v1/health` for the
engine itself. The retained `oc1*` configuration field names still feed the
protocol-selecting OC1/OC2 client; they do not force OC1 HTTP probes.

The observed failure occurs during native ownership capture before server
launch. This capture is used by password-writing guest commands and server-start
admission, before the protected server binary/HTTP readiness loop can run. Changing the OC2 health route, increasing timeouts, changing port,
or granting Bun more syscalls cannot fix this refusal. Logcat also contains a
SIGSYS from the sandbox **kernel capability probe**; this does not establish
that OC2/Bun was killed. Boundary selection already handles the unsupported
kernel result. Protected OC2 execution after admission is still a rebuilt-APK
qualification item.

## Fix: authenticated identity tied to the exact live child

The engine's ready success frame is now schema 2. It adds only five numeric
identity fields (`pid`, `startTicks`, `parent`, `group`, `session`) read from
`/proc/self/stat` after inspection protection is active. The existing HMAC now
covers all five fields as well as profile, port and nonce. Static failure
frames remain schema 1. No credential or private path is added to the frame.

Native code verifies strict types/ranges, exact field sets and the HMAC, and
requires the reported PID to match the direct Java `Process` handle and the
reported parent to match the app PID. It completes the existing authenticated
engine health check before retaining that identity.

The cached proof is usable only for that exact live `Process`. Stop/replacement
clears it; observed exit or a different handle cannot use it. A readable kernel
identity that disagrees with it is refused. Native lookup and both ownership
inventories can therefore represent the hidden live daemon as an ordinary
known peer. This is necessary even when hidepid omits the directory entirely.

There is no bare-PID exemption, no widening of registered app PIDs, no synthetic
descendants, and no disk-restored authority. Unknown live processes still fail
closed. Existing receipt, identity, nonce, drain, quiescence and inventory
checks remain active. `PR_SET_DUMPABLE=0`, the syscall policy, PRoot proc masking
and private storage boundaries are unchanged.

## Banner: shared server owner, not suppression of a true failure

The global banner correctly remained visible while the server was stopped.
Its **Restart** action was wrong because AI Team could create a private
`BuiltinServerStarter` before the shell's starter was supplied:

1. Migration eligibility called `PhoneTeamSetup.of` merely to ask `hasServer`.
2. That cached a flow with a newly allocated starter.
3. Opening setup later returned the cached flow, ignoring the shell starter.
4. The protected-start failure was invisible to the shell banner. The private
   starter also lacked the shell's manual-start ownership coordination hook.

Eligibility is now a pure profile/capability lookup. Every production setup
entry uses the provider-owned starter; the factory refuses to manufacture a
hidden fallback. Setup, manual-start coordination and the banner share one
failure owner. The regression covers eligibility → off page → failed protected
start and verifies both the manual-start hook and shared `componentRecovery`.
The banner continues to report a real disconnected server; it is not hidden
just because the person is on Settings.

## Verification and delivery state

- **108 pure JVM tests passed**, covering the shared Rust/Kotlin HMAC vector,
  identity-field tampering, malformed/legacy frames, wrong child/parent,
  hidden live peers, unknown peers, exit/replacement, readable identity conflicts,
  and the existing ownership/installer admission regressions.
- `PhoneEngineNative`, its attestation dependency and the new identity bridge
  compiled against Android API 37.0 with a 256 MB Kotlin compiler heap. This
  focused compile is not a full application build.
- **242 Rust tests passed, one existing kernel-proof test ignored**, across
  the resumed default Cargo targets (all 20 integration files, unit targets and
  doc tests). All commands used `cargo test --locked -j 2`. The first invocation
  stopped because `boundary_proof` requires `OC_PHONE_PROOF_ROOT`; it was resumed
  with isolated fixture directories in this worktree. `startup_reporting`'s
  non-CLOEXEC descriptor test failed with `WouldBlock` in a parallel run and
  passed with `--test-threads=1`; later targets also ran serially. This is a
  completed set of default targets, not one clean uninterrupted invocation.
  The existing ignored raw-syscall proof explicitly requires Landlock ABI 6.
- `CARGO_BUILD_JOBS=2 tool/qa/machine_lock.sh build --
  engine/phone/tool/build-android.sh --stage-android` completed for arm64-v8a
  and x86_64. All six ELF hashes and the source digest were verified against
  the staged manifest. Source SHA-256:
  `0a3511ae3076e07ec312c854cc4abec78a335c88fceab2fe41f0677864e71e0d`.
  Dependency notices were regenerated by the staging script and unchanged.
- Standalone pinned Dart formatting parsed all six changed Dart files with no
  changes needed; diff and local documentation-link checks passed.
- Flutter tests, analyzer and Android instrumentation were not run here.
  The real-engine instrumentation regression now also checks identity replacement
  and clearing on stop.
- No signing, installation, release or push was performed. **A new native
  Shorebird release / APK is required** for the Kotlin and Rust change.

Dart files for the integration environment:

```text
test/phone_team_setup_test.dart
test/team_migration_test.dart
test/phone_team_stuck_resume_test.dart
test/connection_status_presentation_test.dart
```

After rebuilding, repeat protected OC2 turn-on from a working ordinary OC2
server, confirm authenticated readiness and team execution, then exercise a
small task and needs-you answer. Check that unknown ownership still blocks,
that the banner shares the failure/recovery action, and that it clears after a
successful reconnection. Repeat the OC1 protected-start regression as well.
