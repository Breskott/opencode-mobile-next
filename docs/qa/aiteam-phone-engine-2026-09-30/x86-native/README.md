# Native ABI selection

Finish line: native startup verifies the installed ARM64 or x86_64 engine,
sandbox and boundary probe against their own ABI entry before any execution or
attestation.

Non-goal: weaken the device boundary proof, enable execution merely because a
binary builds, or change the UI activation flow.

## Contract

`PhoneEngineNative.verifyBundle` reads all three known packaged executables
using `O_NOFOLLOW` descriptors. Each must be a regular ELF64, little-endian PIE
with a complete 64-byte ELF header. Machine 183 selects `arm64-v8a`; machine 62
selects `x86_64`. Unknown machines, mixed architectures and an ABI absent from
`Build.SUPPORTED_ABIS` fail with `engine_bundle_invalid`. The app process must
also be 64-bit.

The installed ELF chooses the manifest entry. Device preference order does not
choose the hash map, including when Android advertises translated ABIs. The
header and SHA-256 are read through the same descriptor. All three hashes must
pass even when a caller requests only one executable.

Schema 2 selects `abis.<installed ABI>` and requires the matching Rust target,
API 26 and all three lowercase SHA-256 hashes. Legacy schema 1 remains accepted
only for actual ARM64 binaries with `target: aarch64-linux-android` and API 26.
Unsupported schemas and missing or mismatched entries fail closed. No stored
receipt is made portable across binaries: existing attestation still binds the
hashes of the binaries actually installed on this device.

## Prerequisites and checks

Source inspection confirms existing x86_64 proot, loader, talloc and
android-shmem libraries in `jniLibs/x86_64`, and a pinned amd64 Ubuntu Base in
`BuiltinLinux.imageForDevice`. ELF-header inspection confirms those four
libraries use machine 62. Existing ARM64 engine binaries have ELF64,
little-endian version-1 PIE headers, machine 183 and header size 64.

The pure helper `PhoneEngineNative.packagedAbi` supports focused assertions:
valid machine 183 and 62 headers succeed; truncated headers, invalid magic,
ELF32, big endian, invalid ELF version, non-PIE type, wrong header size and an
unknown machine fail. Integration compilation and focused execution checks
are run by the coordinator under the shared machine lock, not this slice.

A successful build or header inspection does not prove emulator execution.
The runtime proof still requires Landlock ABI 6, the unchanged seccomp policy,
real Git positive and negative controls, and an attested receipt for this
installed bundle. An emulator without those prerequisites must keep canonical
import, lanes and promotion unavailable. No emulator or phone proof was run in
this slice.
