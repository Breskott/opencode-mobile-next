# Runtime proof and native-parent attestation

Finish line: each new daemon generation obtains authority only after complete isolated native/proot proof, a Keystore signature bound to the current launch, and Rust verification; every future proot/service/PTY launch remains confined after app restart.

Non-goal: UI, APK signing/install/publication, changing Cargo/build/daemon ownership, bypassing a failed kernel/tool prerequisite, stopping a person's chat automatically, or claiming Android device evidence from compilation.

Owned files: `BuiltinLinux.kt`, `PhoneEngineNative.kt`, `LocalTerminal.kt`, new `PhoneEngineAttestation.kt`, additive Dart native-status fields and native bridge tests; new Rust `attestation.rs` and its tests. Root owns Cargo/lib/config/CLI/daemon integration and runs checks. This worktree begins at `ddf3a6fe`; no other checkout is edited.

## Native start and durable confinement

`startPhoneEngine` runs the existing exact-policy native attack and proot real-Git positive/negative controls before each new daemon process. It signs nothing when a control fails, a fixture changes, Ubuntu is absent, native bundle validation fails or the process census is uncertain. Existing unconfined proot/service/PTY or untracked app-UID processes cause `restart_required`; they are not killed. Durable store-only startup remains usable with execution unavailable and a safe failure reason. An already tracked same-profile daemon returns its existing generation without rerunning proof or rotating its credential.

Process inventory tracks confinement at creation for every native proot process and terminal session. It recognizes only current protected descendants and the tracked native daemon. A root-owned `/proc/<pid>` directory is not assumed to be a different UID, because a nondumpable app-UID process can appear root-owned; unknown UID or inventory denial fails closed. Android SELinux/proc policy may therefore prevent proof even on a Landlock-capable kernel. That is an unavailable prerequisite, never evidence of protection.

Only full successful controls cause an atomic/fsynced `filesDir/oc.teamEngine.protection-required` marker. Every future native proot `run`, service, recovery and PTY launch consults it and validates the shipped sandbox before spawning. It survives app restart/update/profile deletion. Missing, changed or unavailable sandbox code refuses launch; a corrupt/symlink marker still requires confinement. No feature path clears this marker or returns to legacy execution while canonical state might exist. A fresh proof is still required to authorize each new daemon generation; the marker alone grants no daemon authority.

The native bearer token rotates on every new daemon generation so a credential observed in an earlier unconfined generation cannot authorize the protected generation. Credentials never enter proof payloads, public pins, logs or status. Native status adds nullable `boundaryGeneration` and `protectionRequired`; `boundary` and `execution` reflect authenticated daemon health after Rust verification, with independent OC1 protocol readiness. A verified boundary does not alone advertise execution.

## Receipt format and trusted handoff

Native uses AndroidKeyStore EC secp256r1/P256, key alias `oc.phoneEngineBoundary.v1`, `SHA256withECDSA`. The private key is nonexportable through the Keystore API; hardware/StrongBox backing is not claimed. Confined tools lack Binder device access and AF_UNIX socket creation, so the signing service is outside their permitted authority.

Three private files are written atomically with directory fsync:

- `boundary-receipt.json`: the exact UTF-8 payload bytes signed.
- `boundary-receipt.json.sig`: detached ASN.1 DER ECDSA signature.
- `boundary-public-key.der`: ASN.1 SPKI DER public key.

Payload keys: `schemaVersion=1`, `profileId`, `parentPid`, UUID `generation`, UUID `bootId`, `kernelRelease`, `policySha256`, `engineSha256`, `sandboxSha256`, `probeSha256`, `issuedAtElapsedMs`, `protectedLaunchesRequired=true`, and `controls={nativeAttacksDenied:true,prootGitCompatible:true,fixtureUnchanged:true,complete:true}`. Kernel/boot metadata unavailable on Android prevents signing. Policy digest is SHA-256 of the exact ordered launcher/policy argv (excluding its final `--` separator and tool argv), encoded UTF-8 and joined with NUL. Packaged binary digests are revalidated against the APK asset manifest immediately before signing.

Config `boundary.verified` remains false and is never evidence. Config adds optional `receiptFile`, `publicKeyFile`, `generation`. The native parent separately passes public, ephemeral pins in actual daemon argv:

```text
--config <private-config-path>
--trusted-public-key-sha256 <SPKI-DER-SHA256>
--native-generation <new-UUID>
--policy-sha256 <policy-SHA256>
```

The root daemon must derive the actual native parent with `getppid()`, current executable with `current_exe()`, expected profile from its validated native config, and these pins from the native handoff. It must not read a trusted key pin, expected policy or expected generation from the receipt/config itself. The parent-death contract terminates the daemon when the app parent dies. This binds authority to the currently owned native process, rather than accepting an arbitrary signer supplied beside a JSON boolean.

## Rust verifier contract

Dependency requested from root: `p256 = { version = "0.13", features = ["ecdsa", "pkcs8"] }`; root exports `pub mod attestation`.

`AttestationExpectation` contains receipt_file, public_key_file, profile_id, generation, trusted_public_key_sha256, expected_parent_pid, executable_path and expected_policy_sha256. `verify(&expectation)` returns `VerifiedBoundary { generation, policy_sha256, receipt_sha256 }` only after exact-byte detached signature verification, pinned public-key digest, complete controls, schema/profile/generation/parent/policy/marker claims, current boot/kernel, sane nonfuture monotonic issuance and startup freshness <=120 seconds, and current engine plus adjacent sandbox/probe binary hashes. Symlink/nonregular/oversized input files are refused. Errors are stable symbolic codes only.

Root should use `verify_current(&expectation, &accepted)` before each authority mutation/step. It pins the exact initially verified receipt digest and repeats signature/current parent/boot/kernel/generation/policy/binary invariants. The initial 120-second age window is not reapplied to a long-lived legitimate task; future/zero issuance is still rejected. Receipt replacement, even another valid signed JSON for the same generation, fails the accepted digest check. This prevents an endlessly cached boolean from authorizing mutations after receipt or packaged code changes.

## Verification state

Meaningful Rust tests cover exact valid signatures/current receipt recheck, signed malformed JSON, tampered DER/payload, stale/future issuance, stale generation/boot, key-pin replacement, binary replacement, incomplete controls, profile/parent/policy/marker mismatches and nofollow receipt symlinks. Test fixtures use the supplied Storage artifact root or the repository target directory; no production key/state is touched. Flutter status tests cover independent protocol readiness and the new native generation/marker visibility.

Worker checks performed: Dart format, rustfmt and `git diff --check`. Dart formatter reported absent flutter_lints resolution in this isolated worktree; formatting succeeded and is not analysis. No tests, compiler, analyzer, device process, signing or release command is run by this worker. Root runs integration compilation/tests. No Android kernel/proot/device pass is claimed here. Failed real controls leave execution unavailable, even when the receipt verifier unit tests pass.

## Raw proof correction from coordinator diagnostics

The coordinator's first explicit Linux run reported two failures: protected hard-link attempt returned EXDEV, and a public parent mount-namespace handle could be opened. EXDEV is Landlock's documented REFER/link hierarchy denial; it is accepted only for link/rename controls, while protected data/read/write/process inspection remain strict permission-denial checks. A namespace handle is not a credential or an authority transfer. The probe now attempts `setns(handle, 0)` and `unshare(CLONE_NEWNS)` and requires permission denial. The policy additionally blocks the new mount APIs open_tree/move_mount/fsopen/fsconfig/fsmount/fspick/mount_setattr, alongside existing setns/unshare/mount/umount denial. Worker write and real rename positive controls remain required. No successful authority attack is waived. Diagnostics contain only static control IDs and numeric results/errno, never paths, argv, environment or raw error text. Subsequent runs belong to coordinator evidence; this worker launches no test/build processes.
