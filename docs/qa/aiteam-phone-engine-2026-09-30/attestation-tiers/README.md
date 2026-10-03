# Signed boundary tiers

Finish line: the native signer records the actual successful proof tier and
controls, the daemon validates those tier-specific signed controls, and health
reports the accepted tier accurately.

Non-goal: constructing either confinement tier or claiming that proot provides
Landlock's kernel enforcement. Proof execution and app launch policy are owned
by the parallel runtime slices.

## Receipt and health contract

New receipts use `schemaVersion: 2` with top-level `tier: "landlock" | "proot"`.
The native `issue` method obtains the tier from `controls["tier"]` and preserves
actual Boolean control values instead of signing hardcoded success values.
`nativeAttacksDenied` must be provided as a Boolean, including `false` when the
proot probe does not prove native syscall rejection.

Both tiers require `prootGitCompatible`, `fixtureUnchanged`, and `complete` to
be true. Landlock additionally requires `nativeAttacksDenied` to be true. Proot
instead requires `canonicalPathsDenied`, `daemonProcDenied`, `fdHygiene`, and
`parentInspectionDenied` to be true; native syscall rejection never substitutes
for those controls. Missing or false required controls fail closed.

Schema 1 receipts missing a tier retain the existing Landlock interpretation.
A schema 1 receipt cannot claim proot, and schema 2 cannot omit the tier. The
signed tier is bound to the accepted receipt bytes and revalidated alongside the
existing signer/generation/profile/parent/boot/kernel/policy/binary checks.

`GET /v1/health` exposes `boundaryTier` both at top level and under
`capabilities`. Its values are `none`, `landlock`, and `proot`. A missing or
invalid live receipt produces `none` and disables boundary/execution authority.
No config Boolean or probe output by itself supplies that health value.

## Regression coverage and validation

Rust tests cover legacy Landlock receipts, both valid schema 2 tiers, unknown or
missing tiers, missing and false tier controls, shared-control failures, signed
and unsigned tier changes, and health reporting both tiers with tamper closure.

This worker ran `cargo fmt` and `git diff --check` only. No test/build process was
started; the coordinator owns the machine lock and device evidence.

Focused commands from `engine/phone` under that lock:

```sh
cargo test --test attestation
cargo test --lib daemon::tests::health_reports_only_live_signed_boundary_tier_at_both_locations
cargo test --lib daemon::tests::exact_native_receipt_composes_driver_capability_and_replacement_closes_it
```

The changed Rust source requires rebuilding staged Android engine bundles before
phone acceptance. Native signer compilation and real device proof remain part
of the coordinator's final gate.
