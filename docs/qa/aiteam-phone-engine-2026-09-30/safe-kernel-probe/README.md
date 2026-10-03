# Safe Landlock capability probe (P0-2)

Finish line: `oc-engine-sandbox --check-kernel` survives an inherited Android
seccomp policy that kills Landlock syscalls and returns exit 78 with
`boundary_unsupported`; an unsupported launcher never executes its requested
program.

Non-goal: this slice does not enable a proot-only boundary or claim that a
rootfs view protects app-private state.

The launcher now forks a disposable child before attempting any Landlock
syscall. The child queries ABI >= 6, creates a real ruleset, adds a read-only
root rule, and applies it. All three Landlock operations must succeed. It uses
only async-signal-safe operations after fork, disables core dumps, returns a
four-byte ABI result over a private pipe, and exits. Child policy state never
changes parent authority. A killed, unsupported, malformed or timed-out probe
returns `boundary_unsupported`. A stopped probe is killed by its exact PID and
reaped after a two-second deadline. No environment/config flag grants access.

`confine()` runs this preflight before its actual policy operations, retaining
all existing Landlock and seccomp restrictions. A syscall-number filter that
allows the version query but blocks add/restrict is detected in the child too.
The private pipe and child are closed/reaped on each attempt; no probe persists
across launches or changes of inherited seccomp policy.

Focused regressions:

- `boundary_kernel` installs real seccomp filters in the sandbox subprocess:
  SIGSYS on create; ENOSYS on create; SIGSYS on add/restrict; failed confinement
  never executes the requested program. The parent launcher must exit normally
  with the typed code rather than a signal.
- `kernel_probe_tests::stopped_probe_is_killed_and_reaped_at_the_deadline` proves
  bounded termination and that the owned child has already been reaped.

Run under the shared machine lock, serially:

```sh
cargo test --manifest-path engine/phone/Cargo.toml --test boundary_kernel -- --test-threads=1
cargo test --manifest-path engine/phone/Cargo.toml --lib kernel_probe_tests -- --test-threads=1
```

Verification at handoff: Rust formatting and `git diff --check` pass. Focused
Cargo runs and API 34/API 35 device evidence are owned by the coordinator's
serialized gate and are not claimed here.
