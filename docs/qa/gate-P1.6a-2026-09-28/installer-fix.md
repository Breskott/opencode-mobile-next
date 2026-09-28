# P1.6a installer follow-up — off-phone, 2026-09-28

**Fix prepared; ARM64 cause not conclusively diagnosed. Gate remains NO-GO.**
Finish line: remove npm optional-package selection from the pinned Claude
installer and verify x64 execution plus ARM64 static selection. Non-goals:
phone access, sign-in, enabling P1.6b, or modifying the older Termux runtime.

## What the failure establishes

The awake phone installed the npm wrapper but its postinstall could not resolve
`@anthropic-ai/claude-code-linux-arm64`. The package requires `os: [linux]`,
`cpu: [arm64]`, `libc: [glibc]`; the musl variant requires `libc: [musl]`.
The wrapper pins both optional dependencies at **2.1.283**.
[Published ARM64 metadata](https://registry.npmjs.org/@anthropic-ai%2fclaude-code-linux-arm64/2.1.283).

The exact error interpolates the package selected by Claude's `getPlatformKey()`.
It therefore proves Claude selected **Linux ARM64 glibc**, not the musl package.
It does not prove the report's raw glibc field: Claude treats an absent/null
report as non-musl too. No npm debug log, npm config dump, `ldd` text or Node
report was retained from the phone before its required cleanup, so attributing
the omission specifically to libc detection would exceed the evidence.
[Inspected 2.1.283 wrapper, `install.cjs`](https://registry.npmjs.org/@anthropic-ai/claude-code/-/claude-code-2.1.283.tgz).

## Pinned selectors and configuration

- **npm 11.19.0 / npm-install-checks 8.0.0:** OS and CPU come from
  `process.platform` and `process.arch`. For Linux, npm reads `/usr/bin/ldd`
  **as text**, rather than executing it. `musl` selects musl; `GNU C Library`
  selects glibc. A readable unrecognized file returns null without fallback;
  only a read failure falls back to `process.report`. The fallback tests
  `header.glibcVersionRuntime`, then musl names in `sharedObjects`.
  [Exact detector](https://github.com/npm/cli/blob/v11.19.0/node_modules/npm-install-checks/lib/current-env.js).
- Unknown libc fails a package's libc constraint. Incompatible optional
  dependencies can be skipped; optional fetch/extraction/build failures can
  also be handled nonfatally and leave the wrapper installed. These remain
  distinct plausible explanations, not a proven phone root cause.
  [Platform check](https://github.com/npm/cli/blob/v11.19.0/node_modules/npm-install-checks/lib/index.js),
  [optional failure handling](https://github.com/npm/cli/blob/v11.19.0/workspaces/arborist/lib/arborist/reify.js).
- **Node 24.21.0** obtains `glibcVersionRuntime` by looking up and calling
  `gnu_get_libc_version` with `dlsym(RTLD_DEFAULT, ...)`. That field is not
  derived from `/proc`. The app binds Android `/proc` into the guest; its
  restricted files do not alone prove libc/architecture misdetection. Do not
  dump an entire report during a future probe: it may include environment data.
  [Pinned Node report implementation](https://github.com/nodejs/node/blob/v24.21.0/src/node_report.cc).
- **Claude's selector differs:** it uses the Node report rather than npm's
  ldd-first detector. A present report without `glibcVersionRuntime` selects
  musl. That particular outcome is inconsistent with the glibc package named
  in this phone error, though npm's own decision remains unknown.
- `omit` defaults to `[]` (or `['dev']` under `NODE_ENV=production`), not
  optional. `--include=optional` overrides omission but cannot repair platform
  rejection or make optional fetch failures fatal. npm's default
  `ignore-scripts=false`, empty `allow-scripts`, `strict-allow-scripts=false`
  allow unreviewed scripts to run with a notice. The phone output explicitly
  shows postinstall running, so its `allowScripts` warning is not evidence
  of blocked postinstall. Actual phone config remains unmeasured.
  [Pinned configuration definitions](https://github.com/npm/cli/blob/v11.19.0/workspaces/config/lib/definitions/definitions.js).

## Smallest prepared fix

There is no registered built-in Claude v2 component in this branch or the
inspected `feat/phone-setup-v2` snapshot. Added
[`ClaudeScripts.install`](../../../lib/builtin/setup/claude_scripts.dart)
as its reusable install script; it is deliberately not registered. The older
Termux installer is unchanged. The coordinator can use this script when the
runtime gate permits P1.6b; this is not the complete component manifest.

The script chooses only ARM64/x64 Ubuntu, confirms glibc, and downloads the
**official native 2.1.283 binary** using existing `oc_download` and fixed hashes
from the [official release manifest](https://downloads.claude.ai/claude-code-releases/2.1.283/manifest.json):

| Target | SHA-256 | Bytes |
| --- | --- | ---: |
| linux-arm64 | `346d294f0103d6fc0de11ac953579b5c62dfa90698a4cfc486b6f927c615e697` | 240,902,136 |
| linux-x64 | `1859583ce32920595c61ef868bee52e1b1594f7486db209935e01f1e5e804ae2` | 241,556,664 |

No remote install script, npm lifecycle policy override, musl fallback, downgrade
or unverified execution is used. Checksum verification precedes chmod and the
first `--version`. Exact version verification precedes replacing the binary in
`/opt/oc-claude`; `/usr/local/bin/claude` points there. Failed verification keeps
the previous binary. Signal traps exit nonzero and clean the staged file.
`DISABLE_AUTOUPDATER=1` applies during verification; future daemon launch must
retain that environment setting as already specified in the gate report.
Paseo/npm may still install their own SDK payloads; this fix only selects the
standalone Claude executable reliably and does not solve every optional package.

## Off-phone checks

An owned `OC_API35` x86_64 emulator used an isolated `/data/local/tmp` Ubuntu
24.04.5 rootfs, the repository's proot libraries/options, and verified official
Node 24.21.0/npm 11.19.0. **This regression ran as emulator adb root through
proot, not the app UID**; it does not replace the original app-UID proof or
establish ARM64 SELinux/seccomp behavior. No phone adb call or app-data read
was made, and no APK build/install or signing key was needed.

Observed: `process.platform=linux`, `process.arch=x64`, runtime glibc **2.39**,
compiler glibc **2.28**, npm libc **glibc**; `ldd --version` also reported
2.39 and its text contained `GNU C Library`. The process's own `/proc/self/maps`
was readable in this root context. Fresh npm config returned empty omit/include,
false ignore-scripts and empty allow-scripts. The actual pinned platform checker
accepted glibc and rejected musl for both CPU fixtures; the ARM64 CPU case is
only simulation, not ARM64 execution.

The exact emitted installer completed a fresh x64 download, verified the pinned
hash and ran **2.1.283 (Claude Code)**; the installed symlink/version/hash were
checked again. The final script also passed with a staged, checksum-verified
cached payload. The ARM64 official binary was independently downloaded and
checksum-verified on the host, then inspected as **ELF64 AArch64** without
execution. [Machine-readable evidence](installer-fix-measurements.json).

The three focused shell-behavior tests cover both ABI download selections,
checksum failure preserving the previous binary without executing the payload,
and rejection of an unsupported architecture. Dart formatting, emitted POSIX shell syntax, and the scoped Flutter analyzer
passed (no issues, 3.9 seconds). The isolated
emulator guest and host scratch were removed; the owned emulator exited.
No full product suite is claimed.
Reproduce the emitted script with:

```sh
dart tool/qa/p16a_claude_install.dart > /private/scratch/install.sh
# Run only in an explicitly authorized isolated Ubuntu/proot environment.
```

The next owner-authorized awake phone run should first capture only allowlisted
OS/arch/libc/report fields, ldd signature booleans and npm omit/include/script
policy values, with classified npm failure codes if reproducing the old path.
Then test this pinned installer and the remaining Paseo/gateway/PTY measurements.
No phone retry is authorized by this off-phone follow-up.
