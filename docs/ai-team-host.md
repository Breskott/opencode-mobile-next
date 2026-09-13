# Run an AI team on your computer (AI Team · Gas City)

This guide sets up a [Gas City](https://github.com/gastownhall/gascity)
supervisor on a computer so OpenCode Mobile can show and steer the team from
your phone. Everything stays on your Tailscale network; nothing is published
to the internet.

What you get: several coding agents (OpenCode, running as `opencode acp`)
working on your project under a supervisor, each on its own branch, with a
merge agent landing finished work on your main branch. The phone shows
Runs, Work, Agents and the things that need you.

Verified on Ubuntu 24.04 (x86_64) with Gas City 1.4.1 on 2026-09-10. The
macOS and Windows (WSL) steps use the same commands with the platform
differences noted; they are marked "(not verified here)" wherever we have
not run them ourselves. Read the disclaimer for your kind of computer in
§7 before you start, and pick the same kind in the app when you add the
host: it decides which reminder the app shows.

## 1. Prerequisites

| Tool | Why | Version used |
|---|---|---|
| `gc` (Gas City) | the supervisor | 1.4.1 |
| `bd` (beads) | the task store CLI the agents use | ≥ 1.0.4 (1.2.2 used) |
| `dolt` | the database behind `bd`; Gas City starts it for you | 2.3.3 |
| `tmux`, `git`, `jq` | used by the agent pack | distro packages |
| `opencode` | the agent harness | 1.18.x, logged in to a model provider |
| `tailscale` | the phone reaches the computer through it | any current |

Install the three binaries into a directory on your `PATH` **before** you
start anything. `gc start` installs a user service that inherits your
`PATH`; if `gc` is not on it, the service fails with `gc: command not found`
in the pack's scheduled orders.

Identity that `gc init` insists on, on every OS:

```sh
dolt config --global --add user.name "Your Name"
dolt config --global --add user.email "you@example.com"
git config --global beads.role maintainer
```

### 1a. Ubuntu / Debian (verified)

```sh
mkdir -p ~/.local/bin
# Gas City — pick the tarball for your OS/arch and verify it
curl -LO https://github.com/gastownhall/gascity/releases/download/v1.4.1/gascity_1.4.1_linux_amd64.tar.gz
curl -LO https://github.com/gastownhall/gascity/releases/download/v1.4.1/gascity_1.4.1_checksums.txt
sha256sum -c --ignore-missing gascity_1.4.1_checksums.txt
tar xzf gascity_1.4.1_linux_amd64.tar.gz && mv gc ~/.local/bin/
# beads
curl -LO https://github.com/gastownhall/beads/releases/download/v1.2.2/beads_1.2.2_linux_amd64.tar.gz
curl -LO https://github.com/gastownhall/beads/releases/download/v1.2.2/checksums.txt
sha256sum -c --ignore-missing checksums.txt
tar xzf beads_1.2.2_linux_amd64.tar.gz && mv bd ~/.local/bin/
# Dolt (no checksum file is published; the 2.3.3 linux-amd64 archive was sha256 850a880a…aed3 on 2026-09-10)
curl -LO https://github.com/dolthub/dolt/releases/download/v2.3.3/dolt-linux-amd64.tar.gz
tar xzf dolt-linux-amd64.tar.gz && mv dolt-linux-amd64/bin/dolt ~/.local/bin/
sudo apt install tmux git jq
```

`~/.local/bin` is on `PATH` by default on Ubuntu once it exists; log out
and in (or `source ~/.profile`) if `which gc` finds nothing. Tailscale:
`curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up`.

### 1b. Fedora / Arch (not verified here)

Same binaries and the same `~/.local/bin` as Ubuntu; only the package
manager line differs:

```sh
sudo dnf install tmux git jq          # Fedora
sudo pacman -S tmux git jq            # Arch
```

Arch has `tailscale` in `extra`; Fedora uses Tailscale's own repository
(`dnf config-manager --add-repo https://pkgs.tailscale.com/stable/fedora/tailscale.repo`).
On aarch64 machines use the `linux_arm64` tarballs of `gc` and `bd` and
`dolt-linux-arm64.tar.gz`.

### 1c. macOS (not verified here)

Homebrew supplies the pack's tools; `gc`, `bd` and `dolt` ship `darwin`
tarballs on the same release pages:

```sh
brew install tmux jq git
mkdir -p ~/.local/bin
# Apple silicon: darwin_arm64 / darwin-arm64. Intel Macs: darwin_amd64 / darwin-amd64.
curl -LO https://github.com/gastownhall/gascity/releases/download/v1.4.1/gascity_1.4.1_darwin_arm64.tar.gz
curl -LO https://github.com/gastownhall/gascity/releases/download/v1.4.1/gascity_1.4.1_checksums.txt
shasum -a 256 -c --ignore-missing gascity_1.4.1_checksums.txt
tar xzf gascity_1.4.1_darwin_arm64.tar.gz && mv gc ~/.local/bin/
curl -LO https://github.com/gastownhall/beads/releases/download/v1.2.2/beads_1.2.2_darwin_arm64.tar.gz
curl -LO https://github.com/gastownhall/beads/releases/download/v1.2.2/checksums.txt
shasum -a 256 -c --ignore-missing checksums.txt
tar xzf beads_1.2.2_darwin_arm64.tar.gz && mv bd ~/.local/bin/
curl -LO https://github.com/dolthub/dolt/releases/download/v2.3.3/dolt-darwin-arm64.tar.gz
tar xzf dolt-darwin-arm64.tar.gz && mv dolt-darwin-arm64/bin/dolt ~/.local/bin/
```

`~/.local/bin` is not on the macOS `PATH` by default: add
`export PATH="$HOME/.local/bin:$PATH"` to `~/.zprofile`. Gatekeeper may
quarantine the downloaded binaries; `xattr -d com.apple.quarantine
~/.local/bin/{gc,bd,dolt}` clears it. Install Tailscale from the Mac App
Store or `brew install --cask tailscale`. `brew install dolt` is an
alternative to the Dolt tarball; its version may be newer than 2.3.3,
which we have not tested with `bd` 1.2.2.

### 1d. Windows via WSL2 Ubuntu (not verified here)

The team runs **inside WSL**, not on Windows itself: `gc`, `bd`, `dolt`,
`tmux` and the OpenCode agents are all Linux processes in the Ubuntu
distribution, and your project should live on the Linux side
(`~/code/...`, not `/mnt/c/...`, which is slow for `git` and Dolt).

1. `wsl --install -d Ubuntu` in an administrator PowerShell, reboot, open
   Ubuntu once to create your user.
2. Inside Ubuntu, follow §1a exactly (same tarballs, same `apt` line).
   `opencode` must be installed and logged in inside WSL too.
3. Tailscale has to be **one** of these, not both:
   - the Windows client (Microsoft Store or tailscale.com). WSL2 shares
     the Windows network, so the Ubuntu side reaches the tailnet through
     it; `tailscale ip -4` inside WSL will not work then, so read the
     address from the Windows tray icon or `tailscale ip -4` in
     PowerShell and use that address in §5; or
   - the WSL client (`curl -fsSL https://tailscale.com/install.sh | sh`
     inside Ubuntu, then `sudo tailscaled &` and `sudo tailscale up`).
     WSL has no systemd unless `systemd=true` is set in `/etc/wsl.conf`,
     so `tailscaled` has to be started by hand or by the keep-alive below.
4. WSL stops the whole distribution a few seconds after its last terminal
   closes, and the supervisor with it. Keep one process running from the
   Windows side so the distribution never counts as idle, for example
   from a shortcut or a Task Scheduler "at logon" task:
   `wsl --exec bash -lc 'cd ~/aiteam/city && TMPDIR=/tmp gc supervisor run'`.
   Alternatively enable systemd (`[boot]` / `systemd=true` in
   `/etc/wsl.conf`, then `wsl --shutdown` once) so `gc start`'s user
   service works and the distribution stays up while the service runs.

## 2. Your project needs an `origin`

Agents fetch `origin/<main branch>` and push `origin/polecat/<work-id>`; the
merge agent merges from `origin`. A project without a remote makes the first
agent quit silently. If you don't push anywhere, a local bare repository is
enough:

```sh
git init --bare ~/repos/myproject.git
cd ~/code/myproject && git remote add origin ~/repos/myproject.git && git push -u origin main
```

## 3. Create the city

A "city" is the supervisor's workspace. Put it next to your projects, not
inside one.

```sh
mkdir -p ~/aiteam && cd ~/aiteam
cat > city.toml <<'EOF'
[workspace]
provider = "opencode"
install_agent_hooks = ["opencode"]

[providers]
[providers.opencode]
base = "builtin:opencode"
ready_delay_ms = 0

[defaults]
[defaults.rig]
[defaults.rig.imports]
[defaults.rig.imports.gastown]
source = "https://github.com/gastownhall/gascity-packs/tree/main/gastown"
version = "sha:33d3a430a67d1782ad364556cb566bdb01d0afe3"

[daemon]
patrol_interval = "30s"
max_restarts = 5
restart_window = "1h"
shutdown_timeout = "5s"

EOF
gc init --file ./city.toml --name myteam --no-start city
cd city
gc rig add ~/code/myproject --name myproject     # path first, then --name
gc import install
# Lean profile: keep only the worker pool and the merge agent awake. The
# stock pack keeps mayor, deacon and boot polling your model all day. This
# must come AFTER rig add + import install (the pack agents do not exist in
# the merged config before that, and the patch is rejected).
cat >> city.toml <<'EOF'

[[patches.agent]]
name = "gastown.mayor"
suspended = true
[[patches.agent]]
name = "gastown.deacon"
suspended = true
[[patches.agent]]
name = "gastown.boot"
suspended = true
EOF
gc doctor
```

`gc rig add <name> <path>` is wrong: it creates an empty repository named
`<name>` inside the city and ignores the path. The agents will then "work"
on an empty project.

## 4. Start it

```sh
gc start            # installs and starts the user service, registers the city
gc status
curl -s http://127.0.0.1:8372/v0/city/myteam/health
```

If you would rather not have a service (or `gc start` fails on your
system), run the supervisor in a terminal or under `nohup`:

```sh
TMPDIR=/tmp gc supervisor run    # then, in another shell: gc register --name myteam
```

Expect `no tmux server running` lines in the log with the OpenCode harness;
they are harmless because the agents run over ACP, not tmux.

To give the team something to do:

```sh
cd ~/code/myproject
gc bd create "Add input validation to the signup form" -p 1
gc sling myproject/gastown.polecat <bead-id>
```

**macOS (not verified here).** `gc start` installs a launchd user agent
instead of a systemd unit (a `plist` under `~/Library/LaunchAgents/`);
check it with `launchctl list | grep -i gascity`. launchd agents do not
inherit your shell `PATH`: if the log shows `gc: command not found`, the
agent's plist needs an `EnvironmentVariables` › `PATH` entry that includes
`~/.local/bin` and Homebrew's `bin`, or run the supervisor from a terminal
as above. A closed lid puts the Mac to sleep and pauses everything; leave
it plugged in and turn on "Prevent automatic sleeping when the display is
off" in System Settings › Battery › Options (or run `caffeinate -s`) if the
team should keep going.

**Windows / WSL (not verified here).** Without systemd in WSL there is no
user service: run `TMPDIR=/tmp gc supervisor run` under the `wsl --exec`
keep-alive from §1d, and register the city once from another WSL shell.
The `--exec` process is what keeps the distribution alive; closing that
window stops the team. Windows sleep and hibernation stop WSL entirely;
runs resume when the machine wakes and the supervisor restarts its agents.

## 5. Reach it from the phone

The supervisor listens on `127.0.0.1:8372` only. The phone reaches it
through the **front** this project ships (`tool/host/cp_front/front.py`,
[README](../tool/host/cp_front/README.md)): a one-file Python service that
listens on the computer's Tailscale address, asks `tailscale whois` who each
caller is, lets allowlisted identities read and write, and proxies to the
supervisor with the `X-GC-Request` header and a loopback `Host`.

```sh
# 1. find your tailnet login
tailscale whois $(tailscale ip -4)          # UserProfile › LoginName
# 2. run the front (or install the systemd user unit from the README)
python3 tool/host/cp_front/front.py \
  --supervisor http://127.0.0.1:8372 \
  --bind $(tailscale ip -4) --port 8373 \
  --allow you@example.com
# 3. check from any tailnet device
curl http://$(tailscale ip -4):8373/.well-known/opencode-mobile-orchestration
```

The front presents `Host: 127.0.0.1:8372` to the supervisor, so the
`allowed_hosts` entries for the tailnet address in `~/.gc/supervisor.toml`
(the supervisor's anti-rebinding check) are no longer needed; keeping them
is harmless. Without the front a raw TCP forwarder (`socat` or
`tool/host/tailnet_proxy.py`) still works for a read-only look, but it
passes writes through to anyone on the tailnet and needs those
`allowed_hosts` entries; the front replaces it.

Then in the app: Settings › Plugins › AI Team › Add manually, URL
`http://<tailscale-ip>:8373` (the front), city `myteam`.

Plain HTTP is fine here: Tailscale (WireGuard) already encrypts and
authenticates the hop, and only devices on your tailnet can reach the
address. The app refuses `http://` to anything that is not loopback or a
tailnet address; the front refuses to bind anything else. Do not use
`tailscale funnel`; it publishes the port to the internet.

### 5a. Merging from the phone (TEAM-205)

Gas City's refinery agent merges each `polecat/<work-id>` branch itself
(`merge_strategy: local`, §2) and v0 has no merge-request API, so the three
merge roles the app offers on a finished run — the readiness checklist,
**Approve request** and the two-step **Merge** button — are the front's
own routes over git on this computer ([README › Merge
roles](../tool/host/cp_front/README.md#merge-roles-team-205)). Nothing to
install beyond the front; the well-known document advertises
`capabilities.merge: true` once a rig has an `origin` remote and a default
branch.

- **Readiness** (`GET …/front/merge-readiness/<run>`) is derived here, not
  on the phone: every tracked work item closed or review-ready, the run's
  branches present on `origin` and merging cleanly into the rig's target
  branch (checked in a temporary clone under
  `~/.config/opencode-mobile-front/tmp/`, never in your checkout), optional
  test/build commands, review state and each item's validation result. The
  phone shows the lines and disables Merge naming the first missing one.
- **Optional checks and boundaries** live in
  `~/.config/opencode-mobile-front/rigs/<rig>.json`:

  ```json
  {"supervision": "balanced",
   "merge_checks": [{"key": "tests", "command": "python3 -m pytest -q"},
                    {"key": "build", "command": "make"}],
   "boundaries": {"require_approval": true, "require_tests": true,
                  "allowed_logins": ["you@example.com"],
                  "extra": ["Never touch production"]}}
  ```

  Checks run once per candidate merge in the temporary clone and are cached
  by merged tree. `require_approval` ("Never merge without approval") is on
  by default; `require_tests` ("Require tests before merge") is on whenever
  checks are configured. A boundary that blocks the merge is shown on the
  phone with its text; it is never applied silently.
- **Supervision and the boundaries list** on the phone (the run overview's
  "Supervision · Balanced" line and the Start-a-run sheet's Boundaries row)
  come from the same file through `GET …/front/policy`: `supervision` is
  `high`, `balanced` or `autonomous` (default `balanced`), and
  `boundaries.extra` adds free-text rules to the list. Both are shown
  read-only; the front reports them and does not enforce `supervision`.
- **Approve** records `review.approved_by` / `review.approved_at` in the
  merge request bead's metadata through the supervisor's `PATCH /bead/{id}`
  and clears its `needs-review` label in the same call (the bead is the
  pack's `merge-request` bead when one references the run, else the convoy
  bead itself). The approver is the tailnet login `tailscale whois`
  reported for the phone.
- **Merge** re-checks readiness and the boundaries, then fast-forwards (one
  branch, no divergence) or makes a `--no-ff` merge commit authored by the
  approver and pushes `HEAD:refs/heads/<target>` to `origin` — never
  `--force`. Branches and worktrees are left for the refinery and for you;
  the front deletes nothing but its own temporary clone. The phone shows the
  commit id and "Merged into <branch>"; the bead closure stays Gas City's
  (see §8 for why a merged bead can stay open).
- Both mutations carry the app's `Idempotency-Key`, so a retried tap never
  pushes twice: the stored receipt is replayed.

## 6. Stopping, cost and cleanup

- Stop the team: `gc supervisor stop` (or `systemctl --user stop
  gascity-supervisor`; on macOS unload the launchd agent, on WSL close the
  keep-alive window). Then check for leftover agent helpers:
  `pgrep -fa "opencode acp|mcp"` and kill what belongs to stopped agents. On
  2026-09-10 two orphaned MCP servers kept two CPU cores busy for an hour
  after their agents had exited.
- Idle cost: with the lean profile above, nothing polls your model while no
  work is slung. With the stock pack, four patrol agents stay awake and
  consume model quota continuously.
- Remove: `gc unregister myteam`, delete `~/aiteam`, and remove
  `~/.local/share/systemd/user/gascity-supervisor.service` (macOS: the
  launchd plist) if it was installed.

## 7. Disclaimers by kind of computer

The app asks for the kind of computer when you add a host (Settings ›
Plugins › AI Team › Add manually › "Kind of computer": Desktop computer,
Laptop or Windows (WSL); "This phone" is set by the phone path itself).
The choice changes nothing but the one-line reminder shown on the
Workspace card and in the plugin sheet, so pick the honest one.

| Host | What to expect | The line the app shows |
|---|---|---|
| Desktop computer (Linux, macOS, Windows/WSL on a desktop) | Runs as fast as the computer; keep it awake. A five-line change took about 14 minutes end to end with a small model. | "Runs as fast as your computer; keep it awake" |
| Laptop | Sleep and lid-close pause the team; runs resume on wake. What an agent that was mid-step does after a long sleep is not verified here; expect that step to start over. | "Sleep and lid-close pause the team; runs resume on wake" |
| Windows (WSL) | As a laptop, plus WSL stops when the last terminal closes unless a `wsl --exec` process or systemd keeps the distribution running (§1d, §4). | "Sleep and lid-close pause the team; runs resume on wake. WSL also stops when its last terminal closes." |
| This phone | Experimental. Android stops the team when the screen is off unless Termux holds a wake lock and has unrestricted battery; slower than any computer. See §9 and the app's setup step. | "Android may stop it when the screen is off; slower than a computer" |

## 8. Known rough edges (Gas City 1.4.1)

- `merge_strategy: local` (the default the app slings with) merges finished
  work into the rig checkout's main branch, not into `origin`. Push it
  yourself, or set the strategy to `direct` on the host if you want
  `origin` updated.
- Agents run unattended: OpenCode's own permission prompts (for example
  "ask before git push") are auto-allowed by the harness under Gas City, so
  they never reach the phone. Decisions on the phone come from gate beads,
  review-ready work and failed runs.

- A re-registered rig keeps old task rows; the merge agent may pick up a
  stale task. Prefer a fresh city over `gc rig remove` + `gc rig add`.
- Completed agent sessions vanish from the API, transcript included. The
  app keeps what it streamed.
- Formula "runs" appear only for `gc sling --formula`; plain task slings are
  shown as Work plus a Batch.
- A merged bead is not always closed: on 2026-09-10 the refinery
  fast-forwarded `master` to the right commit and then closed a stale bead
  instead (docs/qa/ai-team/spike-pc-2026-09.md). The front's readiness
  therefore treats a branch that is already an ancestor of the target as
  merged whatever the bead says; close the bead by hand if it lingers.

## 9. On this phone (experimental)

The phone can host the team itself, with no computer, in the hybrid layout
worked out in
[docs/qa/ai-team/spike-phone-2026-09.md §3f](qa/ai-team/spike-phone-2026-09.md):
`gc`, `bd` and `dolt` built for Android run natively in Termux (Android's
seccomp policy kills the stock Linux builds), and only the OpenCode agent
runs inside the proot Ubuntu through a small `opencode` wrapper. The
scripts under [`scripts/termux/`](../scripts/termux/) build the binaries
(`aiteam-build-android.sh`), create the city (`aiteam-native-city.sh`) and
write the wrapper (`aiteam-opencode-wrapper.sh`); the app's on-device setup
step (Sprint C) installs them with pinned checksums, asks for
`termux-wake-lock` and the battery "Unrestricted" setting, and runs
`gc supervisor run` as its own long-lived process. Expect it to be slower
than any computer, and expect Android to stop it when the screen is off.
