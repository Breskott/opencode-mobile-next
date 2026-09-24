# A local terminal on the phone (2026-09-24)

## Why

Today the interactive terminal (`lib/ui/screens/terminal_screen.dart`, the `xterm` Dart package) draws a shell that the OpenCode server opens through its PTY API (`ptyCreate` in `lib/api/product_repository.dart`). So:
- it only works while the OpenCode server runs and answers, which is exactly when you need a shell least (the owner's phone server hung today and there was no way in);
- it was never tested on the built-in Ubuntu;
- its key bar is Ctrl-C, Ctrl-D and Esc only.

The owner asked for a terminal as good as Termux's, inside the app, reusing Termux's public code where the licence allows.

## Licence facts (checked 2026-09-24)

- `termux/termux-app` is **GPLv3**. We must not copy its app code, its extra-keys view, or `termux-shared` into this MIT app.
- The **`terminal-emulator`** and **`terminal-view`** modules are **Apache 2.0** (from Jack Palevich's Android Terminal Emulator), and may be used.
  - `terminal-emulator` holds the VT emulator and `src/main/jni/termux.c`, which starts a subprocess on a real PTY.
  - `terminal-view` is the Android `View`: IME, selection, scrollback, rendering.
  - Prefer the published artifacts (JitPack `com.github.termux.termux-app:terminal-emulator` / `terminal-view`, pinned to a release tag). Copy the sources only if the artifacts cannot build here, and then keep their licence headers.
  - Add the Apache 2.0 notice to the app's open-source notices (About › Open source) and a `NOTICE` entry.

## Goal

A terminal that runs a login shell inside the app's built-in Ubuntu **directly from the app, with no OpenCode server involved**, as good to use as Termux's.

## Scope

### 1. Local PTY session (Kotlin)

- Start `bash -l` inside the built-in Ubuntu on a real PTY.
  - Use the same proot command line as `BuiltinLinux.start()` (`android/.../BuiltinLinux.kt`): the rootfs, the binds, `PROOT_LOADER`, `PROOT_TMP_DIR`, `LD_LIBRARY_PATH`, `TERM=xterm-256color`, `HOME=/root`.
  - Start it through Termux's `termux.c` / `JNI.createSubprocess`, or the artifact's session class.
- Each session supports:
  - resize (rows and cols);
  - write;
  - output as a stream;
  - exit code;
  - kill of the whole process tree, as `BuiltinLinux.stopTree` does.
- Sessions survive leaving the screen; they are owned by a small Kotlin manager.
- **Count them against Android's 32-process phantom limit.** One idle shell is proot plus bash, 2 processes. Say in the UI what a session costs if the AI Team is on.
- Only when the built-in Ubuntu is installed. Termux users keep the Termux app for their own shell.

### 2. The display

Decide with evidence, and record the decision and the numbers.

- **Option A:** keep the `xterm` Dart display and feed it the local PTY over a MethodChannel plus EventChannel. It fits the app's look and the design standard (`docs/design/design-standard.md`).
- **Option B:** embed Termux's `terminal-view` as an Android platform view.
- Try A first. Test both on the device with the checks in the proof section below. Switch to B only if A fails on correctness or feel: IME, speed, redraw, selection. B must still sit inside the app's design-standard chrome (top bar, key bar, states).

### 3. Key bar

Our own, not Termux's GPL `ExtraKeysView`.
- Keys: Esc, Tab, Ctrl (sticky modifier), Alt, the four arrows, Home/End or PgUp/PgDn (a second row or a swipe), and `- / | ~`.
- It is a `lib/ui/kit/` component. The design standard's kit may be in progress on another branch; if it isn't on yours, put the bar in `lib/ui/kit/terminal_key_bar.dart` so it can merge.
- Ctrl plus a letter works from the soft keyboard after tapping the sticky Ctrl.

### 4. Entry and states

- The terminal screen gets a source choice: "This phone" (the local shell, the default when the built-in Ubuntu is installed) or "OpenCode server" (today's PTY).
- The screen follows the design standard:
  - one loading bar while the shell starts;
  - `KitStateView` when the Ubuntu isn't installed (with a "Set up" button to phone setup) or when the shell exited (Restart);
  - the session list in the top bar's overflow.
- Add "Terminal" to the phone server's card and the Settings › On this phone page, if one exists on your branch.
- **Also reachable when the OpenCode server is stopped or not answering.** That is the point of this work.

### 5. Out of scope

- Termux-side shells.
- SSH to other machines.
- Tabs beyond a simple session list.

## Proof (the owner's rule: modular, tested in real scenarios, documented)

- **Unit and widget tests:**
  - the key bar: sticky Ctrl, Ctrl plus a letter sends the right control byte;
  - the session manager's Dart side;
  - the states;
  - the source choice.
  - At least one test fails without the change.
- **A real run on an Android emulator.** Use **emulator-5554** (Android 14, AVD `Pixel_6`): emulator-5556 belongs to another agent.
  - Start it detached: `TMPDIR=/tmp/emu-tmp ~/Android/Sdk/emulator/emulator -avd Pixel_6 -no-window -no-snapshot-save -no-boot-anim -gpu swiftshader_indirect`.
  - Install the built-in Ubuntu through the app's own setup. That is a fresh install and takes about 6 minutes.
  - Then check, with screenshots or a short recording:
    1. `ls --color /`, `echo $TERM`, `tput cols`, and a rotate or resize changes `tput cols`;
    2. `vim` opens, you can type, `:wq` works;
    3. `htop` (or `top`) redraws smoothly, and `q` quits;
    4. `seq 1 200000` or a noisy build stays responsive, with a frame measurement from `adb shell dumpsys gfxinfo <pkg>` before and after;
    5. Tab completion, the arrow keys, Ctrl-C to stop `sleep 100`, Ctrl-R history search;
    6. a long line and CJK/emoji wrap correctly;
    7. select and copy text;
    8. stop the OpenCode server (or never start it), and the local terminal still works;
    9. leave the screen and come back: the session and its scrollback are still there;
    10. process count of the app's uid with one shell open.
- **Record it** in `docs/qa/local-terminal-2026-09-24/README.md` in the `docs/qa/README.md` format, including the A-vs-B decision with numbers, and add a row to the `docs/qa/README.md` index.
