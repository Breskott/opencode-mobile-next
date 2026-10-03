# Phone proot boundary tier

Finish line: API35 startup passes actual inside-proot path/process controls,
issues a signed `tier=proot` receipt, and reports enabled execution with the real
in-app OC1 1.18.32 server. Non-goal: UI edits, model spending, full task E2E,
production delivery, or representing proot as a kernel boundary.

## Owner decision and limits

The owner explicitly selected proot path isolation on Android images whose
inherited seccomp blocks Landlock. **PRoot is ptrace-based path translation, not
a kernel boundary.** This tier does not provide the Landlock tier's guarantees
against raw native-code attacks or detaching/killing the tracer. Previously
measured permission to signal the isolated tracer is not a criterion for this
owner-selected path tier. No claim of kernel enforcement is recorded or shown.

Canonical repositories, SQLite, engine authentication and promotion material,
AndroidKeystore signing keys, receipts and configs stay outside Ubuntu and are
never bound into agent paths. Workers receive isolated clones inside Ubuntu.
The daemon remains outside proot; only its authenticated confirmed promotion
with expected refs and a durable receipt changes canonical main. Existing Rust
negative/direct/tool-mediated and confirmed-promotion regressions remain gates.

## Startup and runtime contract

Landlock remains preferred when its kernel probe succeeds. Otherwise a native
self-check verifies open/stat/readlink/list denial for real private fixtures and
canonical directories, a functioning worker clone, proc root/cwd/fd aliases,
parent/daemon environment and cmdline inspection, and inherited FD/env hygiene.
A process using the exact engine ELF has a live private cwd and sentinel FD;
the initial proof inspects it. Before returning credentials, startup repeats the
controls against the actual ready daemon PID. Failed controls stop the daemon.

The proot command hides the app and daemon proc entries using an empty Linux
mask directory, clears inherited environment, and keeps kill-on-exit. A fresh
proof requires every old server/terminal/tool process to stop, even if it belonged
to an earlier approved proot generation: proc masks are fixed at process launch.
Setup retains its existing confirmation/wait/rollback flow.

Schema-2 AndroidKeystore-signed receipts explicitly identify the tier and preserve
observed controls. Proot signs `nativeAttacksDenied=false`; the daemon requires
its proot-specific controls, signature, binary hashes, native policy/generation,
parent and boot identity. Tier tampering removes boundary and execution authority.
Schema-1 receipts remain compatible as Landlock only, never implied proot.

Health reports `boundaryTier` at top level and in capabilities. Native status and
Dart health expose the same additive enum (`none`, `landlock`, `proot`). UI can
show “Protected by this phone Linux sandbox” for proot. Chat-first admission,
usage/budgets, OC1 driver verification and Android service limits remain intact.

## Verification

Locked host/device results and exact artifact hashes follow below. The no-model
instrumentation uses only disposable preview storage. Its fresh random OC1
server password is never printed; physical phones and stable app data are untouched.

### Verified candidate

- Rust crate: **139 passed, 0 failed, 0 ignored**, including signed tier
  rejection/tamper, executable startup hygiene, search-only Android ancestors,
  direct/indirect/tool writes, merge recovery and confirmed promotion receipts.
  Command: `cargo test --manifest-path engine/phone/Cargo.toml --locked --
  --test-threads=1 --include-ignored`, under `machine_lock.sh test`.
- **54 focused Dart tests passed**: phone project engine controller, connection
  review, project gateway and native bridge. Pinned Flutter analyzer is clean.
  This is focused backend coverage, not the full Flutter integration suite.
- **14 APK packaging regressions passed**. Both native ABIs rebuilt and staged;
  minified preview + release instrumentation assembly passed. Source freshness
  and actual six packaged executable hashes match the manifest.
- **OC_API35, API35 x86_64, PASS**, using only `emulator-5554` under the shared
  emulator lock. See [actual controls](api35-controls.log). Kernel probe returns
  normal 78; schema-2 signed tier is `proot`; every required individual canonical
  open/stat/readlink/list, worker alias, daemon proc, inherited FD/environment and
  parent inspection control passes; worker clone positives pass;
  `nativeAttacksDenied=false` is preserved. Actual in-app OC1 1.18.32 starts in
  the accepted tier and daemon health reports **executionEnabled=true**. Receipt
  tier tampering switches boundary/execution off and reports tier `none`.
- API34 uses the same implemented fallback, but **was not rerun with this
  candidate**. Physical-phone compatibility is not claimed. Full model task,
  checker, merge and promotion E2E remains the coordinator's next gate.
- No models were invoked or provider keys read. The test's OC1 password and
  disposable native project are erased, and tracked server/daemon are stopped.
  Emulator shutdown and lock release are recorded before the final commit.

The worker alias control follows the link to an actual private sentinel.
Ordinary `stat`/`ls` of the deliberately seeded symlink entry inside the worker
can report that entry's metadata without accessing its private target; the
meaningful denial is `cat`, `stat -L`, and `ls` of `private-alias/sentinel`. The
canonical fixture itself separately tests all four primitives. These controls
remain honest about the approved path view; no tracer-kill/kernel claim is made.

### Exact emulator artifacts

Preview APK SHA-256:
`eedff1a5289b6c111d3875291ec852543dca7af5d1bc9c2dc3aa10588103c4a7`.
AndroidTest APK SHA-256:
`390791b39783aea7da38e0145130c170a46878f77619c3282fe9210324da304a`.
ARM64 engine SHA-256:
`a7f1ef1acc025f695a0c9d0520c8d2730d5daab38fa1728b9acefa6056184180`.
x86_64 engine SHA-256:
`c4bd431ed42f676d11fc930924f5e7bdb59ab636c4af9b5560b5793673cbdc39`.
The preview uses the known debug/local certificate solely for emulator QA; no
production signing, release, push or publication was performed.

Reproduce with the minified preview and AndroidTest APK installed:
`adb -s emulator-5554 shell am instrument -w -e isolatedQa true
-e boundaryRegressions true -e bootstrap false
io.github.eslamasabry.opencode_mobile.preview.test/io.github.eslamasabry.opencode_mobile.PhoneEngineAcceptance`.
The initialized preview needs Ubuntu and Git; default bootstrap mode can install
the pinned OC1 archive after hash verification. No provider/model is required.
