# Built-in Linux: running agents on the phone without Termux

Status: plan, not started (2026-09-23). Go/no-go is slice 1.

## Why

Today a phone server needs Termux from F-Droid or GitHub. The user then has to set
`allow-external-apps`, grant `RUN_COMMAND` and keep Termux alive in the background.
Every step is a place where people drop off. With a built-in runtime there is one
app to install, and uninstalling it removes everything.

## What Termux does for us now

The coupling is narrow. All of it goes through one bridge in
`android/app/src/main/kotlin/.../MainActivity.kt`: a `com.termux.RUN_COMMAND`
intent runs our bash scripts in Termux. `openTermuxSession` is used for sign-ins.

Those scripts use `proot-distro login opencode-ubuntu` (37 call sites in
`lib/termux/bridge.dart`) to reach Ubuntu, where OpenCode, Node, Paseo and
Claude Code live.

Everything above that is ours: 7 embedded scripts (~3,900 shell lines) plus the
Dart bridge, processes, storage and recovery code. They need only "a Linux shell
with Ubuntu inside". Termux is just the launcher and host.

## Options considered

1. **Built-in Linux (chosen).**
   - Ship `proot` and its loader in the APK as native libraries (`jniLibs`).
     Android lets those run despite its block on running programs from app
     storage (Android 10+). proot then runs the Ubuntu files. Termux's Play build
     and other Linux-on-Android apps work this way.
   - Download a pinned Ubuntu base image into app storage and verify it with
     SHA-256.
   - The app starts processes itself and keeps them alive with the existing
     foreground service.
2. **No phone server.** Run the agents on a computer and connect over
   Tailscale. This works today, but the phone can't work on its own.
3. **OpenCode built natively for Android.** Not viable: OpenCode 2 is a Bun
   program that relies on Bun-only features, and Bun does not run on Android.

## Constraints

- **Security rule:** nothing over the open internet. Downloads come from pinned
  URLs with checksums. Servers stay on loopback or Tailscale, and Paseo runs with
  `--no-relay`.
- **Distribution:** sideloaded APK plus Shorebird. Downloading and running programs
  is fine here; Google Play policy would object.
- **Android 12+ background-process limit:** it can kill background child
  processes. Termux has the same problem, so nothing gets worse, but nothing gets
  better either. Document the developer-options switch.
- **Android 15 16 KB pages:** bundled binaries must be built 16 KB-aligned, or they
  won't load on newer phones.
- **Storage:** about 1–1.5 GB in app storage (Ubuntu, Node, OpenCode, Claude Code).
- **No automatic move of existing installs:** the app can't read Termux's
  private storage.

## Slices

1. **Spike (go/no-go), ~600–900 lines.**
   - Put proot, the loader and a static tar in `jniLibs` for arm64 and x86_64.
   - Unpack Ubuntu into app storage.
   - Run `uname -a`, `git --version` and `apt update` from the app.
   - Verify on the emulator and on the user's phone.
2. **OpenCode server on the built-in runtime.**
   - Replace `proot-distro login` with our own launch command (binds, fake
     `/proc` entries, environment).
   - Point the existing manager script at it.
   - The app starts and stops the server.
3. **Claude Code / Paseo on the same base.** Sign-in without a Termux window:
   capture the login link and open the browser, or a small built-in terminal
   (check the licence of Termux's terminal-view library first).
4. **Setup UI and fallback.**
   - Delete the Termux install and permission steps; add install progress,
     storage use and Remove.
   - Keep Termux behind one "local runtime" interface for a release or two.
   - Moving projects out of an existing Termux install is git push/pull, or an
     optional one-time copy-out helper.

## Effort estimate (lines)

About 15,000 lines exist today. Most are reused and rewired, not rewritten.

| Piece | New or changed lines |
|---|---|
| Kotlin process runner (start, stream output to Dart, stdin, stop, exit code, foreground service) | 600–900 |
| Build step: fetch pinned proot/loader/tar per ABI, verify, package as native libs | 150–300 |
| `proot-distro login` replacement | 200–350 shell |
| First-run installer (download, verify, unpack, DNS, user `oc`) | 300–500 |
| Rewire existing scripts and Dart bridge | 800–1,500 changed |
| Sign-in without Termux (link capture; +400–600 for a built-in terminal) | 250–400 |
| Setup UI | +300–500, −1,000 to −1,500 |
| Termux fallback behind a runtime interface | 250–400 |
| Optional copy-out helper for existing Termux installs | 200–400 |
| Tests, at the repo's usual density | 1,500–2,500 |

**Total:** about 4,500–7,500 lines written or changed (3,000–5,000 production plus
tests), with 1,000–1,500 deleted.

The risk is on-device debugging, not line count: proot quirks, the background-process
limit, OEM security quirks and 16 KB pages. Each can cost a day while changing ten
lines, so plan for device testing to take longer than writing the code.
