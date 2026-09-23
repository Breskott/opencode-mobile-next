# Phone setup v2: one tap, real progress, reusable and resumable

Status: spec for implementation (2026-09-24). Builds on the built-in Linux work on
branch `feat/builtin-linux-spike` (see `built-in-linux-plan-2026-09-23.md`).

## Why

The owner watched the first-run video and judged both setup pages poor. The cause
was the same on both: they show how it works instead of what the person wants.

- **"On this phone"** offered three equal paths. One of them ("connect existing
  server") doesn't even belong there. Two green primary buttons competed, and a
  three-step Termux wizard showed rows of "Not yet". The copy used words like
  "server setup", "Ubuntu" and "Experimental".
- **"OpenCode inside the app"** was four implementation steps, each needing a tap
  (download Ubuntu → install OpenCode → start the server → connect).
  - It asked "OpenCode 1 or 2?" mid-flow.
  - It then gave four minutes with nothing but a spinner and "keep the app open".
  - "Remove Ubuntu" sat on screen during first setup.
  - When done, it landed on yet another "choose a project folder" screen.

## Goals

1. **One decision, one tap.** "Set up" runs everything to a working agent with no
   further taps.
2. **Real progress.** Every number on screen comes from a real signal: bytes
   downloaded, apt's own status stream, the stage an install script reports. No
   fake timers. When a stage has no measurable progress, say what is happening and
   show an indeterminate bar for that stage only.
3. **Reusable (an owner requirement).** First setup is just one use of a
   general install engine. The same parts are used, unchanged, by:
   - "Add tools" later (Python, AI Team, Git LFS, anything);
   - updating OpenCode and switching between OpenCode 1 and 2;
   - any future installer, such as AI Team's own setup tomorrow.

   Concretely:
   - **The component registry.** Adding a tool means adding one `SetupComponent`:
     a check script and an install script. No engine, Kotlin or screen code
     changes.
   - **The engine.** `SetupEngine.run(selection)` takes any set of component ids,
     not "the first setup".
   - **The progress UI.** The checklist + bar + details is one widget,
     `SetupProgressView`, fed by a `SetupProgress`. Screen B hosts it, and so does
     any later install screen or sheet.
   - **The protocol and helpers.** `::oc` lines, `oc_download` and
     `oc_apt_install` are the only way scripts report progress, so every
     component gets real progress for free.
4. **Resumable (an owner requirement).** Interrupting setup never throws work
   away, and continuing picks up exactly where it stopped. That covers killing the
   app, a reboot, a lost network, a cancel, or Android reclaiming the app.
   - **Across components:** every component has a check script, so running the
     engine again skips what is done.
   - **Within a component:** downloads resume from their partial file (HTTP Range /
     `curl -C -`); apt and npm reuse what they already fetched.
   - **The job itself:** it is persisted in `setup.json`. On app start an
     interrupted job is found and offered as "Continue setup" (screen A's hero,
     screen B, and the notification).
   - **Proof:** the end-to-end test force-stops the app mid-install and requires it
     to continue, not restart.

5. **Pleasant.** Calm, confident and fast-feeling:
   - one primary action per screen;
   - plain words;
   - motion that tells progress, never decoration;
   - the app's design language (lines not boxes, muted secondary text).

Non-goals for this round: AI Team itself, iOS/desktop, Play Store packaging.

---

## The install engine (shared by every screen)

### Components

A component is one installable piece. The registry lives in Dart:
`lib/builtin/setup/components.dart`.

```dart
class SetupComponent {
  final String id;               // 'linux', 'essentials', 'python', 'node', 'opencode', later 'aiteam'
  final String title;            // "Linux base", "Git and SSH", …
  final String shortTitle;       // for the progress checklist
  final List<String> dependsOn;  // ids that must be installed first
  final bool required;           // required for a working agent
  final bool defaultOn;          // installed by "Set up" when not required
  final int estimatedSeconds;    // measured on a mid-range phone; used for weights and ETA
  final int? downloadBytes;      // approximate, for the size shown before setup
  final String checkScript;      // exit 0 = installed and healthy; prints its version on the last line
  final String installScript;    // idempotent; reports progress (protocol below); exit 0 = done
  final String? removeScript;    // optional, for "Remove" of optional components
}
```

The initial set, in dependency order:

| id | title | required | notes |
|---|---|---|---|
| `linux` | Linux base | yes | Ubuntu Base 24.04.5. Downloaded and unpacked by Kotlin, not a script. Byte progress, HTTP Range resume, SHA-256 checked. |
| `essentials` | Git, SSH and certificates | yes | `apt-get install curl ca-certificates git openssh-client`, with apt status progress. |
| `python` | Python | no, on by default | `python3 python3-venv python3-pip` via apt. Agents expect Python; Ubuntu Base has none (seen in the recorded run). |
| `node` | Node.js | yes | Official pinned tarball (`TermuxBridge.localAgentsPins`). Byte progress, SHA-256. `npm config set prefix /usr/local`. |
| `opencode` | OpenCode | yes | Pinned `TermuxRuntime.openCode1.pinnedVersion` by default, via the shared `openCodeUbuntuSetupScript` path. Stage progress. |
| `aiteam` (tomorrow) | AI Team | no | Added later as a component. No engine change should be needed. |

Which OpenCode: the engine installs the recommended runtime (OpenCode 1 today) without
asking. Switching to OpenCode 2 is a setting on the "This phone" card (screen D). It is
re-running the `opencode` component with a different parameter, which the engine
supports: components take `Map<String, String> params`.

### Progress protocol (scripts → engine)

Install scripts report on stdout with lines that start `::oc ` and are otherwise
ignored. Everything else is log text.

```
::oc stage <label…>            what is happening now, in plain words ("Downloading Node.js 24")
::oc bytes <done> <total>      byte progress of the current stage (total may be 0 = unknown)
::oc percent <0-100>           percent of the current stage, when that is what the tool gives (apt)
::oc version <text>            the installed version, once known
```

Exit code 0 means installed. Any other code means failed, and the last `::oc stage` plus the
tail of the log is what the person sees.

Helpers the scripts use (a shell prelude the engine prepends):
- `oc_download URL FILE SHA256`: a curl download that emits `::oc bytes` about twice a
  second (a background size poll against Content-Length), resumes partial files with
  `-C -`, verifies SHA-256 and deletes the file on a mismatch.
- `oc_apt_install PKG…`: `apt-get install` with `-o APT::Status-Fd=3`. The status lines
  (`dlstatus:…:<pct>:…` and `pmstatus:…:<pct>:…`) become `::oc percent`, labelled
  "Downloading packages" or "Installing packages". `apt-get update` runs only if the
  package lists are older than a day.

### Running a setup job (Kotlin)

Setup must survive the app going to the background, so it runs in native code under a
foreground service, not from a Dart isolate.

New channel methods on `io.github.eslamasabry.opencode_mobile/builtin_linux`:
- `startSetup {components: [{id, script, weight}], jobId}`
  - Runs the components in order, inside Ubuntu, each script with the prelude.
  - `linux` is handled natively.
  - Holds a foreground service ("Setting up OpenCode on this phone · 42%") while it runs.
  - Returns immediately.
- `setupStatus` returns the persisted job state (below).
- `cancelSetup` stops the running script; the job becomes `cancelled`.

Job state is written to `files/linux/setup.json` on every change, so it survives the
process dying:

```json
{
  "jobId": "…",
  "state": "running|done|failed|cancelled|interrupted",
  "current": "node",
  "components": {
    "linux":  {"state": "done", "version": "24.04.5"},
    "node":   {"state": "running", "stage": "Downloading Node.js 24", "done": 18000000, "total": 30000000, "percent": null},
    "opencode": {"state": "pending"}
  },
  "startedAt": 0,
  "updatedAt": 0,
  "error": null,
  "logTail": "last 4 KB"
}
```

On app start, a `running` job whose process is gone becomes `interrupted`.

### The engine and its resume rule (Dart, `lib/builtin/setup/setup_engine.dart`)

`SetupEngine.run(selection)` does the following:
1. Build the component list: required components plus the selected optional ones,
   expanded by `dependsOn` and sorted by dependency order.
2. For each component, run its `checkScript`. Components that pass are marked done
   and skipped. This is what makes every run a resume.
3. `startSetup` with the rest.
4. Poll `setupStatus` about every 500 ms while a screen watches, and expose it as a
   `ValueListenable<SetupProgress>`.

`SetupProgress` gives the screens:
- `overall` (0..1): each component weighted by `estimatedSeconds`, using the current
  component's real fraction (bytes, percent, or half-way when it only reports stages);
- `etaSeconds`: remaining weights, scaled by the measured pace so far;
- per-component state, stage label and bytes;
- `state`: `idle`, `running`, `done`, `failed`, `interrupted` or `cancelled`;
- `error` in plain words.

An `interrupted` or `failed` job shows "Continue setup", which calls `run` again.
The check scripts make it pick up exactly where it stopped.

After `opencode` is done, the engine (not the screen) starts the server with the existing
`BuiltinServerStarter` and connects. That finishes the job.

---

## Screen A: "On this phone"

File: `lib/ui/screens/phone_setup_start_screen.dart` (replaces the top of today's
`termux_setup_screen.dart` as the entry point).

```
 ←  On this phone

        [ quiet illustration: a phone with a spark ]

    Run a coding agent right here
    No computer and no other apps. About 4 minutes
    and ~200 MB the first time.

    ┌───────────────────────────────┐
    │            Set up             │      ← the only filled button
    └───────────────────────────────┘
    Includes Git, Python and Node.js.  Customize

    Other ways  ⌄                          ← collapsed
       Use Termux instead            advanced ›
       Connect to a server by address      ›
```

- **Set up** calls `SetupEngine.run(default selection)` and pushes screen B.
- **Customize** opens a sheet listing the optional components with switches
  (Python on). Required ones are shown, checked and disabled, with a one-line
  reason. Size and time totals update as switches change.
- **Other ways**:
  - "Use Termux instead" opens the existing Termux flow (today's
    `TermuxSetupScreen`, untouched).
  - "Connect to a server by address" opens the existing add-server form.
- **State-aware:**
  - A setup already running, interrupted or failed: the hero becomes "Setup is
    X% done", with a **Continue** button that opens B.
  - Already set up: "OpenCode is ready on this phone", with **Open**.
  - If the Termux path is already set up (Termux-managed server found), the hero
    says so and offers Connect, with the in-app option under Other ways.
- **Words:** never "Ubuntu", "server", "proot" or "Experimental" on this screen.
  The size and time numbers come from the component registry.
- **Accessibility:** it works at 2.5× text scale on a 320 dp width, and every tap
  target is ≥ 48 dp.

## Screen B: Setting up

File: `lib/ui/screens/phone_setup_progress_screen.dart`.

```
    Setting up OpenCode on this phone

    ███████████████░░░░░░░░  ~2 min left

    ✓  Linux base
    ✓  Git, SSH and certificates
    ●  Node.js           Downloading · 18 of 30 MB
    ○  Python
    ○  OpenCode

    You can leave the app. We'll notify you when it's ready.

    Show details ⌄      (live log, TerminalView, auto-scroll)
                                         Cancel
```

- **Overall bar:** animated towards `overall` (it eases, never jumps backwards).
- **ETA:** only after 10 seconds of real progress; before that, "Getting started…".
- **Checklist rows:** state icon, title, and the current stage on the right. Bytes
  show as "18 of 30 MB"; percent as "62%"; a stage alone as its label. A finished
  row shows its version muted ("Node.js 24.21"). No row ever shows a fake number.
- **Show details:** expands the live log (the existing `TerminalView`), tail-first,
  and follows the output.
- **Leaving is safe:** the foreground-service notification mirrors the bar. Tapping
  it opens screen B again.
- **Failure:** the bar turns calm red; the failed row says what failed in plain
  words (the last stage + the reason). The buttons are **Continue setup** (resume)
  and **Show details**. A network failure says "No internet connection — Continue
  when you're back online".
- **Cancel:** confirms, stops, and keeps what's finished. Coming back later resumes.
- **Motion:** a check "lands" (a short scale + fade) as a row completes, and the next
  row's spinner starts. Reduce-motion turns both into instant changes.
- **When the job reaches done** (server started and connected): push screen C.

## Screen C: Ready

File: `lib/ui/screens/phone_setup_ready_screen.dart`.

```
    ✓  OpenCode is ready

    Name your first project
    ┌───────────────────────┐
    │ my-app                │   Create
    └───────────────────────┘
    Letters, numbers, - _ .

    or  Open an existing folder ›
```

- **Create** uses the existing `BuiltinProjectFolders.create`, then opens the
  project, then goes straight to a new conversation with the composer focused. No
  Work-screen hop.
- **Open an existing folder** is the existing in-app folder sheet.
- **A small success moment:** the check draws in once. No confetti.
- **Returning users:** screen C appears only once, at the end of first setup.

## Screen D: "This phone" management card

File: `lib/ui/widgets/phone_server_card.dart`. It is shown in the server switcher and
in Settings → Servers for the in-app server, replacing the old four-step screen as
the place to manage it.

```
    This phone                         ● Running
    OpenCode 1.18.29 · 1.1 GB

    Stop        Show log        ⋯
                                ├ Switch to OpenCode 2
                                ├ Add tools (Python, AI Team…)
                                ├ Update OpenCode
                                └ Remove from this phone…
```

- **Start/Stop** use the existing server starter.
- **Add tools** opens the Customize sheet from screen A in "add" mode. Installing
  goes through screen B with only the new components.
- **Update / Switch to OpenCode 2** re-run the `opencode` component with params, in
  screen B.
- **Remove** confirms (and says how much space comes back), then uninstalls.
- **Storage:** shown only once measured (never "0 B").

---

## Words

| Say | Don't say |
|---|---|
| "Set up", "Setting up OpenCode on this phone" | "Download Ubuntu", "server setup" |
| "Linux base" (in the checklist and details only) | "Ubuntu Base 24.04" (details log only) |
| "This phone" | "127.0.0.1:4097", "built-in (OpenCode 1)" |
| "Continue setup" | "Retry", "Resume setup" |

Arabic translations for every string. Keep sentences short.

## Testing

- **Engine:**
  - the resume rule (checks skip done components);
  - dependency order;
  - weights and ETA math;
  - protocol parsing (fed recorded script output);
  - state transitions (interrupted, failed, continue).
- **Kotlin:** the job runner with a fake script; the `setup.json` round trip; the
  process-death → interrupted rule.
- **Screens:**
  - A: states, customize totals, Other ways;
  - B: progress rendering from fake progress, failure and continue, cancel;
  - C: the create → conversation path;
  - D: menu actions.
- **End to end on the emulator:** a fresh install, then Set up, with the app
  force-stopped mid-install and reopened. It must continue, not restart. Then
  record the guide video again.
