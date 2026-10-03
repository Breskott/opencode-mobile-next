# slice-builtin-opencode-pin — 2026-09-28

**Finish line:** This phone setup installs OpenCode in the in-app Ubuntu from
the pinned native program (SHA-256 checked before unpacking), proves it runs
and serves before calling the step done, and a phone where the npm install
failed (owner's ARM64, build 2062) replaces only OpenCode on Continue.
**Non-goal:** the Termux manager's own install path (it keeps npm, now with
`--allow-scripts`), touching the owner's phone.

## What failed on the phone (build 2062)

Job log: Node.js 24.21.0 → `npm install -g opencode-ai@1.18.32` (postinstall
ran; npm 11.19 warned about `allowScripts`) → `opencode --version` printed
`1.18.32` from npm's JS wrapper → "Getting the model list" → the start step
failed. The report's tail was then filled with `timing · OCTRACE …
linux.setupStatus` events, hiding the reason. The root cause on the phone was
not observable from the log; the fix removes npm from the path entirely and
makes any remaining failure name itself.

## What changed

- `lib/builtin/setup/components.dart`
  - `OpenCodePins`: OpenCode 1 v1.18.32 from
    `github.com/anomalyco/opencode/releases` — arm64
    `568461b7…65840`, x64-baseline `763af386…6adce` (same as
    `scripts/host/ubuntu-opencode.sh`, re-read from the GitHub API
    `digest` today). OpenCode 2 (`@opencode/cli` 2.0.10) has **no GitHub
    release** (API 404 for `v2.0.10`); its official per-platform npm tarballs
    carry only `package/bin/opencode` + `package.json`, no install script.
    Downloaded both today; their SHA-512 equals the registry's published
    `integrity`, and the pins are those files' SHA-256: arm64
    `cf541667…80ebc`, x64-baseline `700c4d0f…1a76c`.
  - `SetupScripts.openCodeNativeInstall` (in-app host only): CPU → asset,
    `oc_download` (resumable, SHA-256 checked, mismatch deletes the file and
    stops before `tar`), unpack only the program next to the current install,
    `--version` from the native program, then a short `serve` in a throwaway
    HOME/XDG on a loopback port until `/global/health` (OC1) or
    `/api/info`/`/api/health` (OC2) answers (≤120 s). Only then swap into
    `/opt/opencode` or `/opt/opencode2`, link `/usr/local/bin/opencode[2]`,
    delete npm's old `opencode-ai`/`opencode-linux-*` (or `/opt/oc2`), and
    delete the archive. OC1's model refresh is bounded by `timeout 180`.
    Every failure ends with one plain `[oc] …` line after the program's own
    output (`OpenCodeInstallFailure`), so the log ends with the reason; the
    previous install stays until the new one is proven.
  - `SetupScripts.openCodeNativeCheck`: passes only when the command resolves
    (`readlink -f`) to the pinned native program at the pinned version. npm's
    wrapper printing `1.18.32` fails it → **Continue/Try again redoes only
    OpenCode**; Linux base, Git, Python and Node pass their own checks
    (engine resume rule unchanged).
  - Termux host keeps the shared text (`openCodeUbuntuSetupScript`).
- `lib/termux/opencode_ubuntu_setup.dart`: `--allow-scripts="$main_package"`
  (exactly `opencode-ai` or `@opencode/cli`). `lib/termux/bridge.dart`
  `npm_install` (Paseo, Claude Code on the Termux path): `--allow-scripts=`
  exactly the package being installed (`@scope/pkg@1.2.3` → `@scope/pkg`).
  AI Team (`aiteam_scripts.dart`) and built-in Claude (`claude_scripts.dart`)
  have no npm installs.
- Failure wording (`describeSetupFailure`, `app_en.arb`):
  - "OpenCode was downloaded, but its program was not in the download.
    Continue to fetch it again."
  - "OpenCode was downloaded, but its program does not run on this phone.
    Details show what it said."
  - "OpenCode was installed, but it did not start. Continue to try again;
    Details show what it said."
  - checksum mismatch keeps "The download of OpenCode was damaged…".
- OCTRACE never in the people-facing job log: `setupLogForPeople` strips it
  from the setup progress log tail and from `FailedJobReport`'s excerpt; a
  report with a failed job attached (`KitReport.log`) carries no timing events
  (they stay in the device log and the diagnostics page).

## Tests

New `test/opencode_native_install_test.dart` (real dash, local HTTP server,
fake archives): per-CPU asset + pin in the production script, download before
`tar`, no npm; ARM64 install replaces an npm wrapper and the check flips from
fail to pass; x86_64/OC2 unpacks `package/bin/opencode` as `opencode2`;
checksum mismatch aborts with nothing unpacked; missing program / non-running
program / program that does not start each end with their reason, keep the
previous install, and map to the plain words. Added: resume after the 2062
failure replaces only OpenCode (`setup_engine_test`), OCTRACE filtered from
progress log + failure wording (`setup_engine_test`), failed-job excerpt
(`failed_job_report_test`), report without timings when a job is attached
(`problem_report_test`). Updated: npm expectations → native
(`setup_engine_test`), Termux check test pinned to the Termux host
(`setup_scripts_test`), `--allow-scripts` in `termux_scripts_test`, Termux
manager hash (`builtin_linux_test`, deliberate change).

Ran (serial, via `tool/qa/machine_lock.sh`): opencode_native_install,
setup_engine, setup_scripts, problem_report, failed_job_report,
termux_scripts, builtin_linux, local_agent_runtime, aiteam_component,
failed_job_report_ui, setup_component_removal, setup_finish_host,
setup_persistence_failure, setup_termux_existing_install,
setup_voice_component, termux_setup_finish, phone_setup_progress_screen,
setup_termux_resume, setup_termux_host — all pass. `flutter analyze` clean.

## Real x86_64 smoke (this PC, temp root, never the phone)

`OC_SMOKE_REAL_OPENCODE=1 flutter test test/opencode_native_install_test.dart
--plain-name smoke` runs the **production** script (real GitHub / npm
registry URLs and pins) under dash with every path under a temp dir:

```
--- opencode1
::oc stage Downloading OpenCode 1.18.32
::oc stage Unpacking OpenCode
::oc stage Checking that OpenCode starts
::oc stage Getting the model list
::oc version 1.18.32

--- opencode2
::oc stage Downloading OpenCode 2.0.10
::oc stage Unpacking OpenCode
::oc stage Checking that OpenCode starts
::oc version 2.0.10
```

Both native checks pass afterwards. Manually also: `opencode --version` →
`1.18.32`, `opencode v2.0.10`; both `serve` on loopback answered
(`/global/health` 200; OC2 `/api/info` 401 without credentials).

## Still needs a device

- ARM64 run of the new step on a phone/emulator under proot (the arm64 pins
  are GitHub's/npm's published digests; not executed here).
- If the start step still fails after this install is proven, the failure
  screen now shows the start reason and the log ends with the real lines.
