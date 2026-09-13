# OpenCode 2 setup feasibility

Read-only upstream check: 2026-09-09T18:24:21.598135+00:00. Initial discovery performed no software execution. The separately authorized provider-free host verification below subsequently executed only the official pinned binary in isolated temporary directories. No provider calls, existing server changes or user credential/config reads. Scope: current official upstream, with app-pinned beta18600 distinguished below.

**Conclusion:** A remote OC2 server can be connected through the app's existing OC2 HTTP/Basic-auth gateway. Official OC2 does not publish an Android/Bionic package; Linux ARM64 and ARM64-musl packages are not evidence of native Termux compatibility. For on-phone OC2, the existing Ubuntu/proot userland is the plausible Linux runtime, but actual phone execution remains unverified. Most importantly, a reversible OC1→OC2 switch must isolate OC2 storage: current upstream beta shares global paths and `opencode.db` by default and runs migrations.

## Version and platform evidence

- [Official current introduction](https://opencode.ai/v2/docs/) installs `npm install -g @opencode/cli@beta`, command `opencode2`; trusted npm postinstall selects a native executable. Both binaries can be installed side by side. Docs describe beta instability and do not offer a Termux recipe.
- Live registry `@opencode/cli` beta resolved **0.0.0-beta-19398**; [exact package metadata](https://registry.npmjs.org/@opencode%2fcli/0.0.0-beta-19398). Old namespace `@opencode-ai/cli` beta resolved **0.0.0-beta-19271**; app remains pinned **0.0.0-beta-18600**, not automatically upgraded by this research.
- Current wrapper metadata explicitly limits OS to `darwin,linux,win32`, CPU `arm64,x64`. Its optional dependencies include `@opencode/cli-linux-arm64` and `...-linux-arm64-musl`; no Android target. Published [wrapper artifact](https://registry.npmjs.org/@opencode/cli/-/cli-0.0.0-beta-19398.tgz), `postinstall.mjs:16–22`, resolves OS/arch and fails when no platform dependency exists. Lines65–100 detect musl through Alpine/ldd and select Linux variants. They do not implement Bionic compatibility. **Inference:** neither official installer nor musl fallback is a supported native Termux route; no native Android claim can be made from those binaries.
- [Termux's own proot-distro documentation](https://github.com/termux/proot-distro) supports rootless Ubuntu/Debian/Alpine userlands on Android. Its current basic commands are `pkg install proot-distro`, `proot-distro install ubuntu:24.04`, `proot-distro login ubuntu`. Existing app container is separately named `opencode-ubuntu`; do not reinstall/reset it as part of switching. proot provides a suitable Linux userspace in principle; it is not an upstream OC2-on-Android support guarantee.

## Existing remote OC2 versus managed on-phone OC2

| Mode | Supported contract | Remaining gate |
|---|---|---|
| Remote OC2 already running | Add a separate OC2 profile using reachable base URL, username `opencode`, server password. App uses `/api` paths. No phone runtime installation or OC1 conversion needed. | Verify the remote beta schema is compatible with app18600, then auth/health and actual user flow. |
| Existing phone Ubuntu/proot | Install a distinct `opencode2` binary alongside `opencode`; launch only with isolated OC2 directories and a preserved runtime-specific profile; a single managed port may be reused after stopping the prior runtime. | Provider-free pinned18600 host check passed below; actual Android/proot startup, persistence and app-managed switch/revert validation remain. |
| Native Termux/Bionic | No official Android binary or supported recipe found in current primary package/docs. | Do not advertise as supported or force Linux/musl selection. |

The source-confirmed ordinary server command on a compatible Linux runtime is `opencode2 serve --hostname 127.0.0.1 --port 4097`. This is a manual foreground server; shared-service startup is a separate mode. For a remote host, bind a deliberately reachable host/interface and use its actual reachable URL. Do not change an existing OC1 listener or claim loopback on another machine is reachable from the phone.

## Data safety: binary coexistence is not data isolation

Current official beta branch resolved **95503c177347a1a5e011bd0ed1c8fe830d7309b5**. Published artifacts do not expose a gitHead; this hash is current source identity, not a fabricated exact commit for npm19398/18600.

- [global-roots.ts](https://github.com/anomalyco/opencode/blob/95503c177347a1a5e011bd0ed1c8fe830d7309b5/packages/util/src/global-roots.ts): honors all four `XDG_DATA_HOME`, `XDG_CACHE_HOME`, `XDG_CONFIG_HOME`, `XDG_STATE_HOME`; defaults under the current user's home. [global.ts](https://github.com/anomalyco/opencode/blob/95503c177347a1a5e011bd0ed1c8fe830d7309b5/packages/util/src/global.ts) app suffix is `opencode`, and `OPENCODE_CONFIG_DIR` can override config.
- [server-process.ts:96–104](https://github.com/anomalyco/opencode/blob/95503c177347a1a5e011bd0ed1c8fe830d7309b5/packages/cli/src/server-process.ts#L96): `OPENCODE_DB` overrides database filename; beta/latest/dev/next/prod default to **opencode.db**. [database.ts](https://github.com/anomalyco/opencode/blob/95503c177347a1a5e011bd0ed1c8fe830d7309b5/packages/core/src/database/database.ts) resolves relative DB filename under global.data and applies schema migration.
- [v1-migration.bun.ts:516–565](https://github.com/anomalyco/opencode/blob/95503c177347a1a5e011bd0ed1c8fe830d7309b5/packages/core/src/database/v1-migration.bun.ts#L516) imports legacy sessions into session_v2 and clears existing event rows at migration start. It also imports old opencode-next.db through a read-only connection (:684–695). Do not confuse that read-only auxiliary import with the main database migration: the main selected DB is written. No tested reverse migration or safe concurrent old/new DB writers was established.
- [legacy credential migration](https://github.com/anomalyco/opencode/blob/95503c177347a1a5e011bd0ed1c8fe830d7309b5/packages/core/src/database/migration/20260805200742_import_legacy_credentials.ts) reads global.data/auth.json and imports credentials into the DB; no source auth.json deletion in this migration. With isolated empty data, credentials/history do not appear automatically: reconnect providers through supported UI rather than silently copying credentials.
- [Migration docs](https://opencode.ai/v2/docs/migrate-v1/) say supported V1 config is read from shared locations and normalized in memory, without rewriting the source. Project `.opencode` files remain visible even with separate XDG roots. Plugins have an incompatible API. Retain V1 config; do not convert shared project/global files merely to try OC2.

## Pinned beta18600 evidence and verification boundary

The exact published [@opencode-ai/util@18600 artifact](https://registry.npmjs.org/@opencode-ai/util/-/util-0.0.0-beta-18600.tgz) was downloaded and read, not installed. `dist/global-roots.js:4–17` confirms **all four XDG variables** and app-suffixed directories. `dist/global.js:11–30,58–60` confirms `opencode` suffix and **OPENCODE_CONFIG_DIR**. Thus separate XDG/config storage is supported at the actual app pin, not merely inferred from latest source. Exact CLI database default/OPENCODE_DB override was subsequently verified by the isolated pinned-binary check below: [cli18600 wrapper](https://registry.npmjs.org/@opencode-ai/cli/-/cli-0.0.0-beta-18600.tgz) contains postinstall/native launcher rather than CLI source. Pinned runtime evidence now confirms the same DB default/override behavior; current source remains separately identified.

## Recommended reversible switch contract

1. Keep OC1 binary, profile, server port, data and project config intact. Install/prepare OC2 separately; no replacement of the Ubuntu container.
2. Scope every OC2 launch (including upgrade, diagnostics and recovery) to a dedicated directory tree, e.g. `/root/.oc-mobile-oc2/{data,cache,config,state,tmp}` through XDG variables and TMPDIR. Set `OPENCODE_CONFIG_DIR` to that tree's config/opencode and an absolute isolated `OPENCODE_DB`; the pinned override is now confirmed. Clear conflicting inherited OpenCode overrides. Do not repurpose the caller's HOME; any test HOME override belongs only to its isolated child process.
3. Use preserved runtime-specific profiles and a managed server password; switch active profile only after authenticated health confirms readiness/version. The app intentionally manages one runtime at a time on port4096: bounded stopping of the exact old process, isolated storage and a durable switch journal make reuse of that port valid. A distinct port is optional for independent side-by-side servers, not a prerequisite. Preserve the previous OC1 runtime/profile state if OC2 launch or migration fails. Do not claim old sessions/providers migrated when isolated storage is empty.
4. Revert means return to OC1 profile/runtime; stop only the exact managed OC2 PID. Preserve OC2 data for retry. It must not restore a migrated shared DB over OC1 or perform a global uninstall: [CLI docs](https://opencode.ai/v2/docs/cli/) explicitly note uninstall can remove shared global directories.
5. Isolation covers application state, not work files or provider account effects. Both runtimes pointed at the same project can still edit the same files. A read-only first verification or separate working copy is needed to prove behavior without touching the user's project/config.

## Authentication and pairing

Current [server-process.ts:68–80,164–166](https://github.com/anomalyco/opencode/blob/95503c177347a1a5e011bd0ed1c8fe830d7309b5/packages/cli/src/server-process.ts#L68) uses `OPENCODE_PASSWORD`/legacy `OPENCODE_SERVER_PASSWORD` when supplied; otherwise generates a password and prints it for foreground startup. [server/auth.ts](https://github.com/anomalyco/opencode/blob/95503c177347a1a5e011bd0ed1c8fe830d7309b5/packages/server/src/auth.ts) fixes username `opencode`; [server/process.ts:184–209](https://github.com/anomalyco/opencode/blob/95503c177347a1a5e011bd0ed1c8fe830d7309b5/packages/server/src/process.ts#L184) requires Basic auth even for `/api/health`. Local app `docs/opencode2-protocol-notes.md` separately records these same beta18600 auth/health contracts from earlier live capture. No new phone proof is implied. Pairing here means URL+server password; no official Android QR pairing install flow was verified.

Saved primary source extracts/registry metadata: `/tmp/oc2-upstream-feasibility/`. No user configuration, provider auth or server secrets inspected. Follow-up isolated host execution completed under the coordinator's serialized slot; results below. Both owned processes and listeners are stopped.


## Pinned18600 isolated Linux host verification — PASS

Executed the official [@opencode-ai/cli-linux-x64@0.0.0-beta-18600 artifact](https://registry.npmjs.org/@opencode-ai/cli-linux-x64/-/cli-linux-x64-0.0.0-beta-18600.tgz), downloaded into `/tmp/oc2-pinned18600-check`, without npm/global installation. Verified registry SHA1 and SHA512 before execution. Full registry identity and executable SHA256: [pinned18600-artifact.json](pinned18600-artifact.json).

Each of two serial runs used a newly constructed environment (no caller env), child-only temporary HOME, empty temporary project, isolated XDG data/cache/config/state, TMPDIR and OPENCODE_CONFIG_DIR; a generated ephemeral password stayed in process memory only. No provider prompt or configuration/auth-data endpoint was requested. Only `/api/health` was queried. No existing server was touched.

| Check | Explicit DB override | Default DB under isolated XDG data |
|---|---|---|
| Binary version | opencode2 v0.0.0-beta-18600 | Same |
| Authenticated health | 200, healthy:true, exact18600 | Same |
| Unauthenticated health | 401 | 401 |
| Actual DB files | database/isolated.db only; no default DB | data/opencode/opencode.db only |
| Database validation | Read-only sqlite schema query succeeded | Same |
| Supplied password printed in stdout/stderr | No / No | No / No |
| Server-password log line | None | None |
| Cleanup | Exact owned PID stopped; port closed | Same |

This confirms `OPENCODE_DB` override and XDG_DATA_HOME database isolation at the **exact pinned version**. Exact published util18600 source confirms the other XDG/config overrides; startup created data/cache/state/tmp content and left the temporary HOME empty. Empty config trees contain no files to demonstrate config content precedence, so no extra runtime claim is made about provider config loading. Global/project configuration overrides still need consistent handling in every managed launch path.

The supplied `OPENCODE_PASSWORD` is **not printed by serve** in this verified pin. Do not generalize this to launches without a supplied password: upstream source prints a generated foreground password when no environment password is supplied. Manager diagnostics must continue to prevent generated auth from entering setup output; this test retained only allowlisted line categories, discarded raw stdout/stderr and never saved the generated value.

Results: [pinned18600-host-results.json](pinned18600-host-results.json). Reproducible isolated harness (download/verify official artifact first): [pinned18600-host-check.py](pinned18600-host-check.py). Runtime directories remain owned temporary test data; no real user data was copied. **Verified: Linux x64 host startup/auth/storage isolation. Unverified: Android ARM64/proot execution, actual phone switch/revert, provider use, OC1 history/provider migration.** Root's single-server4096 design remains valid with the bounded stop/profile/journal boundary above.
