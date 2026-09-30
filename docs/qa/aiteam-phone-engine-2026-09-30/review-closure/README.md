# Phone engine review closure

Finish line: close both critical and all seven major review paths with focused regressions, authenticated native startup and usable durable recovery, commit the independent report unchanged, and provide matched ARM64/x86_64 bundles for coordinator integration.

Non-goal: signing, installation, publication, changing UI ownership, the whole repository test suite, claiming device or paid-model acceptance from host checks.

The original [independent review](../../aiteam-engine-review-2026-09-30.md) describes integration candidate `f4786c8b`. It is retained unchanged; this ledger describes the updated engine branch. UI files were not edited and nothing was pushed.

## Critical and major evidence

[negative-controls.json](negative-controls.json) records ten executed controls. Every control restores one faulty behavior and gets the expected regression assertion failure, with no compilation failure counted. Final positive checks run with fixes restored. R4 has independent worker-ledger and sticky-unknown controls.

| Finding | Change and regression |
| --- | --- |
| C1 | App-owned stdin EOF replaces thread-scoped PDEATHSIG. `daemon_startup::actual_daemon_survives_launcher_thread_then_exits_on_app_pipe_eof` launches the real daemon, keeps its launcher alive through authenticated readiness, then ends the launcher and finally closes the app pipe. Restoring PDEATHSIG fails it. |
| C2, S3 | Native supplies canonical app paths; Config resolves the trusted system alias while refusing descendant symlinks. Real-daemon alias startup succeeds and descendant-link startup refuses. Skipping normalization fails the alias regression. Android mount namespace itself still needs device execution. |
| S1 | Bind port 0; child publishes profile/port/nonce with HMAC over the private launcher pipe. Native validates it before any HTTP/bearer. Real-daemon occupied-4098 host test fails under restored fixed binding. Actual Kotlin squatter and forged-pipe tests compile; device execution is pending. |
| R1 | Resume moves known durable dispatch checkpoints to `resuming`, refetching the existing session; pristine never-dispatched work requeues with a fresh clone. Unknown/unrecorded submissions remain reviewable rather than being resent. Original interrupted rejection fails the durable restart/resume regression. |
| R2 | First-turn unknown status stays pending for at most 30 seconds; bounded transient observe retries refetch the same session. No new prompt is submitted. Removing grace fails the accepted-async-turn regression. |
| R3 | Usage changes workspace/usage revision, leaving the command revision intact. The exact revision held before three usage updates still pauses. Restoring project-revision bumps fails the regression. |
| R4 | Worker namespace filtered before session-ID registration, bounded LRU person directories, busy scopes retained, unknown clears only with a fresh complete connected snapshot. Both faulty-behavior controls fail their regression. |
| D1 | Accepted command stays accepted if only refresh fails; a later poll can refresh the view. Restoring saveFailed after accepted POST fails the controller regression. |
| D2 | Ordinary metadata upsert preserves the separate secure engine token; explicit clear/deletion owns removal. Restoring empty-field token deletion fails the profile edit regression. |

## Minor findings

| Finding | Disposition |
| --- | --- |
| S2 | Checker output remains advisory. It authorizes a dev merge, never main; confirmed expected-SHA promotion remains required. Coordinator UI must show the dev diff for review. OC1 replacement by a same-UID agent remains an honest residual limitation. |
| S4 | Validate imported/task/merged trees before private installation or checkout: duplicate/invalid names, `.git`, unsupported modes, absolute and parent-traversing symlinks refuse. Safe relative symlinks remain supported. |
| R5 | Whole admitted dispatch is capped at 5 seconds; no replacement prompt after uncertain acknowledgement. |
| R6 | Stop is rechecked after prompt dispatch; newly created unrecorded sessions are aborted if checkpoint persistence fails. Profile deletion fences dispatch and cancels pipelines. |
| R7 | Semantic preflight before import; attributable repo/worker cleanup after durable project deletion or failed import/create. Accepted deletion remains accepted with `cleanupPending` on cleanup failure; replay retries cleanup. Promotion audits remain private and retained. Retired repository IDs cannot be reused by stale sessions. Unattributable staging is not guessed or deleted. |
| R8 | Refuse unsupported `chargingOnly=true` with `chargingUnsupported`; no invented battery state. Existing true settings safely pause until edited false. |
| R9 | Bounded 64-entry descriptor-metadata hash cache; signature/receipt/pins/runtime authority remain live. Replacement, same-size writes, symlinks and receipt tamper still close authority. |
| R10 | Latest 10,000 metadata events retained; durable prune watermark. Expired cursor gives `cursorExpired`/`resetRequired`, never silent empty history. Workspace/spec/promotion history is retained. |
| R11 | Durable per-request repository scopes before promotion intent; damaged scoped receipts block only their repository. Parseable legacy scopes are filtered first. Completely corrupted legacy receipts with no trustworthy scope remain preserved and fail closed as `legacy_receipt_scope_unknown`; an operator quarantine path is still needed. |
| A1 | Exact PDF PID/UID/package from Android ActivityManager; forgeable cmdline is never authority. |
| A2 | Verified packaged engine descriptor-based cleanup helper removes mode-000/0555 directories and unlinks symlinks without traversing their targets. Failure retains deletion tombstone. |
| A3 | Sign successfully before committing protection marker under existing launch fence; existing markers remain protected. |
| A4 | Stop all attempts every service before reporting the first failure. |
| A5 | **Pending minor:** global monitor still spans the boundary probe/start. A safe follow-up needs shared admission/cancellation epochs and exact active-proof process tracking across service and PTY launches. Removing synchronization alone would introduce a confinement/late-launch race. Notification stop/status can still wait during proof. |
| A6 | Stop erases active credential copy; Ubuntu uninstall sweeps inactive copies after tracked processes stop. |
| D3 | Connection deletion fences managed builtin URLs and pending lifecycle ownership even before a token exists. |
| D4 | Both transport-hook and alias admission failures map to plain API wording before queued error persistence. |
| D5 | Monitor uses selected profile identity/token and projects capability, with bounded attention projection and unknown/partial coverage. |
| D6 | Older workspace revision cannot replace newer state. |
| D7 | Closed gateway clients remove themselves from the controller registry. |
| D8 | Keep deletion intent fail-closed; persisted tombstone survives restart, deletion can be retried without profile revival. The suggested unconditional removal from `_deleted` would weaken deletion fencing and is not adopted. |

The checks additionally found that a bare clone may place non-HEAD branches under remote refs. Import now reads the intended dev OID from its sanitized source snapshot, validates its object and establishes canonical dev while keeping main unchanged. A regression imports a source with a later dev commit and HEAD still on main, then seeds the worker from that dev.

## Verification

All heavy checks use `OC_TEST_SLOTS=1 tool/qa/machine_lock.sh`; native builds also hold the build lock.

- Rust: `cargo test --manifest-path engine/phone/Cargo.toml -- --test-threads=1 --include-ignored`: **123 passed, zero failed/ignored**, including actual daemon CLI and host-kernel Landlock negative/positive controls. Host kernel proof is not Android proof.
- Dart: eight focused files (controller, phone controller/gateway, builtin phone, profile store/secure store, connection review, monitor), **77 passed, zero failed**.
- Native: `:app:compileReleaseKotlin :app:compileReleaseAndroidTestKotlin -PocPreview=true`: **passed**. The new native instrumentation compiles; no APK is signed, installed or delivered by this gate.
- Ten major/critical faulty-behavior controls: **expected runtime failure in all ten**, followed by restored positive gates.
- Pinned Dart format, `cargo fmt`, shell syntax and `git diff --check`: passed.
- Pinned `flutter analyze`: clean.
- Acceptance wrapper unit tests: **12 passed**.
- Dual-ABI staging: source/bundle hashes recorded after the final build below.

`adb devices` returned no attached device. Native regression mode and the live acceptance script therefore remain unexecuted on Android. On a compatible phone, the runtime self-check must pass for this exact bundle and OC1 1.18.32 protocol verification must pass before imports/lanes/promotion become available. A Linux kernel without Landlock ABI 6 remains honestly unavailable.

Device-only no-model regression command after matching preview/test APKs are installed:

```sh
adb -s SERIAL shell am instrument -w -r \
  -e isolatedQa true -e nativeRegressions true \
  io.github.eslamasabry.opencode_mobile.preview.test/io.github.eslamasabry.opencode_mobile.PhoneEngineAcceptance
```

The full scratch task/promotion journey is documented in [x86-acceptance](../x86-acceptance/README.md) and uses `tool/qa/phone_engine_acceptance.sh`. It explicitly requires isolated QA and model-spend authorization; this change did not spend model credits.
