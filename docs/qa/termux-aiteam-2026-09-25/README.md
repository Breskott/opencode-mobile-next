# AI Team for OpenCode in Termux, from the upstream builds (2026-09-25)

Branch `fix/termux-aiteam-upstream`, from `feat/phone-setup-v2` @ `2730891b`.
Issue #87, "can't download AI Team", Termux path. **Tests only. Nothing here
ran on a phone** (the owner has not approved touching his phone, and the
emulators have no Termux).

## Scope

- `lib/termux/team_scripts.dart` (new): `aiteam.sh`, now built from the in-app
  team's scripts, and the pins file it reads.
- `lib/termux/bridge.dart`, AI Team part only: the dispatch writes `aiteam.sh`,
  `~/.oc/aiteam-pins` and, for `init`, `~/.oc/aiteam/rig.sh`. The manifest
  path is gone. The storage scan also counts `/opt/aiteam`. The pinned
  manager script is untouched.
- `lib/termux/team_runtime.dart`: `install()` takes no manifest. `manifest()`
  is the pinned upstream downloads for the phone's CPU (arm64, or x86_64 on
  the emulator). The verb table is updated.
- `lib/builtin/setup/aiteam_scripts.dart`: `unpackScript` and `ubuntuPackages`
  are exposed. The built-in install script is **byte-for-byte unchanged**
  (compared before and after, both default and mirror variants).
- Added at the coordinator's request (the owner's "Is it normal to take
  long?", build 2054):
  - `lib/builtin/team/builtin_team_job.dart` (new).
  - `BuiltinTeam.prepare()`, and the poll interval cut from 2 s to 1 s.
  - `lib/ui/widgets/builtin_team_section.dart`.
  - `lib/ui/widgets/team_phone_section.dart`: no disabled buttons while a
    verb runs.
- Copy (en + ar): `teamUiPhoneOfferSize`, `teamUiPhoneChooseProjectBody` and
  `teamUiPhoneFailedPackages` no longer describe the old Android builds or
  Termux packages. New strings: `aiteamComponentTurnOnExpectation`,
  `aiteamComponentStartExpectation`, `aiteamComponentStageSoFar` and
  `aiteamComponentStageTook`.

## Feasibility (timeboxed, from source and earlier records)

| Question | Finding |
|---|---|
| Where OpenCode runs in Termux | Inside proot-distro `opencode-ubuntu`, as root, with projects in `/root/projects/<name>`. The in-app Ubuntu uses the same paths. `/root/aiteam`, `/opt/aiteam` and `/usr/local/bin` are free there. Ubuntu's npm puts `opencode` in `/usr/local/bin`, which is what the agents' wrapper execs (`lib/termux/opencode_ubuntu_setup.dart` is shared by both paths). |
| Which proot | The same program: the in-app Linux ships Termux's own `proot` 5.1.107.94 (`tool/builtin_linux/fetch_proot.sh`), with `--link2symlink --sysvipc -L --kill-on-exit`, as proot-distro does. |
| How the app talks to the team | HTTP on loopback. proot does not isolate the network, so a supervisor inside Ubuntu listening on `127.0.0.1:8372` is reachable from the app, exactly like the Termux OpenCode server on 4096. The Termux team keeps **8372** (the Termux profile's `OrchestrationConfig` and discovery already use it). The in-app team keeps 8472, so `BuiltinTeam.isBuiltinConfig` never mistakes one for the other. The supervisor settings are now the in-app team's: `bind = "127.0.0.1"`, loopback Host headers only. The old Termux team ran with Gas City's defaults. |
| How the app starts, stops and watches the Termux team | Unchanged contract. The bridge runs `aiteam.sh <verb>` through the `oc/termux` channel, detached (`setsid`), and polls `aiteam.sh status` (JSON). The phases and failure tokens the onboarding and section read are kept. New tokens `no-ubuntu`, `pins`, `blocked-syscall`, `runs-here`, `unpack` and `rig-script` read as "Reason: <message>". |
| A long-lived process inside proot-distro | proot-distro's `--kill-on-exit` stops everything a login started when that login ends (spike §3d). The supervisor therefore gets its own `proot-distro login`, run by `aiteam.sh run-supervisor` under `nohup setsid`: the same pattern `claude.sh` already uses for the Paseo daemon. Stop asks `gc supervisor stop` inside Ubuntu, then signals the runner's process group, then anything whose working folder is under the team's home in the rootfs. Nothing is matched by program name. |
| Anything Termux's Ubuntu lacks | Nothing blocking found. `git` and `curl` come from the OpenCode setup. `tmux jq lsof procps` are installed by the install step (the in-app setup's own apt helper). Termux needs only `curl`, `sha256sum`, `setsid` and `timeout`, all used before. |
| **Risk (not a blocker, same as the in-app path)** | The only real-phone run of the upstream Linux builds under Termux's proot (spike §3c, 2026-09-10) crashed after about 11 minutes. The trace was `futexwakeup … returned -38` then SIGSEGV, attributed in §3f to Android's seccomp policy. It ran without the phone tuning, which came later. The in-app path runs the same binaries under the same proot. It was proven on the Android 15 emulator, never on an arm64 phone. So both paths carry this risk until a phone run. The install runs each program once and fails in plain words on an immediate SIGSYS ("Android stopped bd: this phone blocks a system call it needs (SIGSYS)."). A crash later under load would show as "Android stopped the team" or "the supervisor stopped". |

## What now happens when a Termux user sets up the AI Team

The flow and screens are the same (the onboarding's five steps; Plugins ›
On this phone).

1. **Download & verify** (`install`). If Ubuntu is not set up, it fails as
   `no-ubuntu` with a sentence. If the programs are already installed at the
   pinned versions (the in-app check script passes), it downloads nothing.
   Otherwise Termux's curl fetches the three upstream archives from
   `github.com/gastownhall/gascity`, `…/beads` and `dolthub/dolt`: about
   112 MB on arm64, and the offer line now says about 115 MB, not 294. The
   download resumes after a cut, and a refused or unreachable server is
   named with its host. Every archive is checked against its size and the
   SHA-256 in `AiTeamPins`. On a mismatch everything is deleted and it stops
   with exit 65, **before anything reaches Ubuntu**.
2. **Install prerequisites.** `tmux jq lsof procps` are installed in Ubuntu,
   only if missing. The checked archives are then unpacked into
   `/opt/aiteam` by the in-app `unpackScript`: links in `/usr/local/bin`, the
   agents' `opencode` wrapper, the git/dolt identity, and each program run
   once. An unpack that fails keeps the checked archives, so Try again
   downloads nothing.
3. **Create the team** (`init /root/projects/<p>`). This runs the in-app
   `cityScript` (the store with the phone tuning, retried clean) and
   `rigScript` for that project. A project without an origin gets
   `/root/aiteam/origins/<p>.git` with the `post-receive` hook, which brings
   merged work into `/root/projects/<p>`. The script checks that the
   project's script was prepared by the app for that path. An origin the old
   native layout set by its Termux path is re-pointed at the Ubuntu path.
4. **Start** (`start`). This writes the in-app `serviceScript`: supervisor
   settings on 8372, the tuning brought up to date, the `phone-upkeep` order
   and its `flock`, the hooks, and `exec gc supervisor run`. It runs that in
   the long-lived login, waits for `/health`, registers (cut at 60 s), then
   waits for the team's health (up to 360 s). It holds the Termux wake lock.
5. **Connect**: unchanged. The Termux profile gets Gas City on
   `http://127.0.0.1:8372`, phone host, loopback controls.

**Remove** deletes `/opt/aiteam`, the links, `/root/.gc`, the store and the
settings, plus the old native layout's leftovers. It **keeps**
`/root/aiteam/origins`, because a project's `origin` points there and holds
the team's branches. (The in-app `removeScript` deletes them; that is not
changed here.) Every verb logs each stage with the seconds since it began,
for example `[aiteam] verifying: Verifying checksums (at 41s)`, so a phone
run shows where its minutes go.

`assets/aiteam/manifest*.json` and the `aiteam-assets-1` URL are **left in
place, unused**. `pubspec.yaml` still declares the assets (outside this
branch's write set), `test/shipped_download_urls_test.dart` checks them, and
`tool/release/upload_aiteam_assets.sh` refers to them. Nothing in the app
reads them any more; retiring them is a small follow-up for the pubspec
owner.

## "Is it normal to take long?" (owner, build 2054, built-in path)

The screenshots showed the old section: a greyed "Turn on AI Team for
demo-app" button above one stage line and a bar, with no time and no
expectation. On the emulator, a turn-on took 8–9 minutes: getting ready 2–3,
adding the project about 2.6, starting 1.2, waiting for health about 2.5
(`../aiteam-builtin-2026-09-24/README.md` rows 7, Run 2 step 4, Run 3
step 3).

What changed:

- **One job, not a widget's future.** `BuiltinTeamJob.shared` runs the
  turn-on or start. If the person leaves Plugins, the job goes on, the
  profile still gets the team's config when it finishes, and coming back
  shows the same job where it got to. A second turn-on cannot start beside
  it.
- **No disabled button** (design standard §2). While the job runs, the
  section shows only the job, with no Turn on, Start or Stop. The same
  applies to the Termux section: Start again, Stop and Delete are hidden
  while a verb runs, and its status line says what is running.
- **Expectation.** "This takes about 5 to 10 minutes the first time. You can
  leave this screen; it keeps going." A start says "This takes a few
  minutes…". There is **no "we'll notify you"**: no notification exists for
  the turn-on before the supervisor's service starts, and adding one needs
  the platform side.
- **Stages as a list.** Each stage is a `KitRow` with a `KitStatusMark`: done
  with "Took 2:05", the current one with "1:05 so far", the rest waiting, or
  failed. The stage list and the error stay after a failure.
- **Time cut, where safe.** The team's store ("Getting the team ready",
  2–3 minutes) is now made in the background as soon as the section sees AI
  Team installed without a store (`BuiltinTeam.prepare()`). Turn on waits
  for that one instead of making a second beside it; a test checks the two
  never run at once. If the person opens Plugins and taps Turn on later,
  that step is instant. If they tap at once, nothing is lost. Health and
  service polling went from every 2 s to every 1 s.
- **Not done, and why:**
  - Making the store inside the setup job: review must-fix #1 ("install
    only") is pinned by `aiteam_component_test` (no `gc init` in the setup
    job).
  - Overlapping "starting" with "adding the project": it is unknown whether
    Gas City 1.4.1 accepts a `gc rig add` beside a starting supervisor, and
    getting it wrong corrupts the store.
  - Cutting the register wait: register already ends when the team is up,
    and the health wait follows it.
  - The ~2.6 min "adding" is `gc rig add` (a new Beads/Dolt database under
    proot) plus `gc import install`, which fetches the Gas Town pack over the
    network. Pre-fetching the pack during the store step is a candidate, but
    it was not measured (the stubs here cannot time real programs).
  - **No before/after timing was measured on a device.** The Termux stage
    log and the section's "Took m:ss" rows are there so the next phone run
    measures it.

## Tests

Pinned Flutter 3.47.1. All passed:

- `test/termux_aiteam_upstream_test.dart`, `test/termux_aiteam_script_test.dart`,
  `test/team_runtime_test.dart`, `test/builtin_team_section_test.dart`,
  `test/builtin_team_test.dart`, `test/builtin_team_bring_in_test.dart`,
  `test/aiteam_component_test.dart` and `test/shipped_download_urls_test.dart`.
  These 8 files ran together with `flutter test -j 2 …`: 80 tests passed.
- Neighbours, 12 files, 196 tests passed: `team_phone_onboarding` (it
  subclasses the runtime), `design_standard`, `l10n_coverage`,
  `phone_termux_discovery`, `plugins_screen`, `team_design_standard`,
  `team_plugins_layout`, `team_plugins_screen`, `termux_bridge_platform`,
  `termux_scripts`, `termux_storage` and `ui_glossary`.
- `flutter analyze lib test`: no issues.
- The full serial suite was **not** run.

**Failing first:** `test/termux_aiteam_upstream_test.dart` was written against
the old code. It fails there because the dispatched install carries the
`aiteam-assets-1` manifest ([failing-first.txt](failing-first.txt)). It
passes after the change.

`test/termux_aiteam_script_test.dart` runs the generated `aiteam.sh` for real:

- A fake `proot-distro login` runs each command in a private user and mount
  namespace (`unshare --user --map-root-user --mount`). The fixture rootfs's
  `/root`, `/opt`, `/usr/local`, `/var/cache` and `/var/lib` are bound over
  the real ones, so the scripts meant for Ubuntu run as written, as a mapped
  root like proot's.
- A local HTTP server serves stub gc/bd/dolt packed like the upstream
  archives, and plays the supervisor.
- `apt-get`, `dpkg` and `pkill` are stubbed inside the fake Ubuntu, so the
  store script's `pkill -f` never reaches this machine's processes.
- Test processes are stopped by exact pid.
- The group is skipped, saying why, where user namespaces are refused.

It covers:

- The pins are the upstream URLs and SHA-256 for both CPUs. Nothing names
  `aiteam-assets-1` or an Android build.
- The Ubuntu parts equal the in-app scripts except `port = 8372`, and carry
  the tuning, the `acp_command` and the upkeep `flock`.
- Every script and dispatch parses in bash, and the parts in sh.
- Install puts the programs in `/opt/aiteam` with links, the wrapper, the
  packages and the identity, and leaves nothing behind on either side.
- A second install downloads and installs nothing.
- A checksum mismatch stops before unpacking: no `/opt/aiteam`, no apt, no
  archive in Ubuntu.
- A 404 names the host, and Try again fetches only the missing file. A cut
  download resumes at its byte offset.
- A program killed with SIGSYS fails as `blocked-syscall` in plain words,
  and Try again downloads nothing.
- No Ubuntu and a 32-bit phone each fail with their own reason.
- Init writes the tuned store and the supervisor settings on 8372, adds the
  project with its phone-side origin and hook, and logs `up-to-date`.
- **A push to the origin inside the fake Ubuntu fast-forwards
  `/root/projects/calc`** (`brought-in`).
- Init refuses an uninstalled team, a missing folder, a non-git folder and a
  project the app did not prepare. It fixes an origin set by a Termux path.
- Start runs `sh /root/.oc-aiteam/service.sh` in its own login (its own
  session), with the agents' `opencode` first on the supervisor's PATH. It
  writes the upkeep order, registers and reaches ready. A second start does
  nothing, and stop takes it all down.
- A killed supervisor reads as killed by Android, and Start brings it back.
- A supervisor that exits fails with its own output.
- Remove deletes everything listed above, keeps the project and its origin,
  and a set-up after it works again.
- A foreign `opencode` in `$PREFIX/bin` is never deleted.
- A verb that died reads as interrupted.
- Logs reach `install.log`.
- Each stage is logged with its time.
- The bridge dispatch writes the script, the pins and the project's script,
  queues, refuses while busy, and runs install → init → start → stop.
- **`TermuxTeamRuntime` over a mocked `oc/termux` channel** that runs every
  script with bash in the fixture: idle → installed → city ready → ready →
  stopped. The profile config is loopback phone host.

`test/builtin_team_section_test.dart` covers:

- While the turn-on runs, the section shows no Turn on, no button at all,
  and the expectation line.
- Stage marks: working, then done with "Took 1:05". The current stage shows
  "1:05 so far" on a fake clock.
- Leaving and coming back shows the same job. It finishes while away and the
  profile still gets the team.
- The store is prepared once in the background.
- A failed stage is marked failed, the reason is shown, and Turn on is back.
- The job's own timing.
- `BuiltinTeam.turnOn` waits for `prepare()`: over the real channel contract,
  never two store scripts at once.

## On the owner's phone, once he approves (coordinator)

Build an arm64 APK from this branch, signed with the installed signer
(AGENTS.md), and install it over the current one. Then:

1. Termux with OpenCode already set up: Settings › Plugins › On this phone
   (or the onboarding offer) › Set up AI team, with `demo-app`. Expect the
   offer to say about 115 MB. Download & verify should show the three
   github.com archives. Record the stage times: `tail -f
   ~/.oc/aiteam/aiteam.log` in Termux shows `… (at Ns)` per stage.
2. Check that the programs run under Termux's proot:
   `proot-distro login opencode-ubuntu -- gc version` should print `1.4.1`.
   Also check `bd --version` and `dolt version`. A SIGSYS shows in the app as
   "Android stopped …".
3. Check the team is up: `curl -s http://127.0.0.1:8372/v0/city/phone/health`
   from Termux, and Work › AI Team shows the team.
4. Give one task ("Create hello.txt containing the word hi") and let it
   merge. Then run `git -C /root/projects/demo-app log --oneline -2` inside
   Ubuntu: the merge should be in the project **with no pull**. Read
   `/root/aiteam/pull.log`.
5. Throughout steps 3–4, sample the processes of Termux's uid
   (`tool/qa/aiteam_builtin/procwatch.py` with the Termux package's uid) and
   check `adb logcat | grep -E 'Killing PhantomProcess|SIGSYS'`. The limit
   is 32 and **Termux's processes count too** (its OpenCode server). Record
   the peak. Watch in particular for the §3c crash (`futexwakeup … -38`) in
   `~/.oc/aiteam/supervisor.log` over at least 30 minutes.
6. Stop, Start, then Delete from this phone. After Delete, `/opt/aiteam` is
   gone and `/root/aiteam/origins` is kept. Then set up again.
7. On the in-app (built-in) path of the same phone: tap Turn on, leave
   Plugins, and come back. The same stage list should show with times, and
   no greyed button. Record each stage's "Took m:ss" against the emulator's
   8–9 minutes. Open Plugins a minute before tapping Turn on to see the
   background store ("Getting the team ready" should then be near 0:00).

## NOT proven

- Nothing ran on a phone or in real Termux or proot-distro. The fake
  proot-distro is a namespace, not proot. The programs are stubs, so no real
  Gas City, Beads or Dolt ran here.
- The arm64 upstream builds under Termux's proot on the owner's phone: the
  §3c futex/SIGSYS crash is still possible. The phone tuning and a fresh
  Gas City build are the differences since then.
- Process counts with Termux's own processes added.
- `proot-distro login` passing `gc supervisor run` a working environment. The
  service is `env PATH=… HOME=/root LANG=C.UTF-8 TMPDIR=/tmp sh
  /root/.oc-aiteam/service.sh`; proot-distro's own environment handling was
  not checked on a device.
- Any time saving. The background store and the 1 s polling are
  unmeasured, and so is the Termux stage timing.
- The re-pointing of an origin the old native layout set (tested with a
  fixture path only). The owner's phone may still hold an old native city in
  `~/.oc/aiteam/city`; stop and remove handle it, but that was not run.
- The Arabic copy was not viewed.
