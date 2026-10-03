# Running OpenCode on an Ubuntu host for this app

The phone app talks to any reachable OpenCode server. This guide sets one up
on Ubuntu (or any systemd Linux) as a per-user service, so it keeps running
after you close the terminal and comes back after reboots — no root required.

The app cannot run commands on your computer. Settings → **Ubuntu host
management** shows these same commands with copy buttons, filled in with your
server's actual port.

## One-time setup (on the Ubuntu machine)

```sh
curl -fsSLo ubuntu-opencode.sh.part \
  https://raw.githubusercontent.com/Eslamasabry/opencode-mobile-next/c62f159ae3c1741cb4ec0ef92b4941c0ddfc0a18/scripts/host/ubuntu-opencode.sh &&
echo '1f42642fe92c9a8a46e26f27dfa200ffd2274e9cdf9dfafc08e6a9bc7511d721  ubuntu-opencode.sh.part' | sha256sum -c - &&
mv ubuntu-opencode.sh.part ubuntu-opencode.sh &&
OPENCODE_PORT=4096 bash ubuntu-opencode.sh install
```

The script comes from one published commit (release 1.0.44), not from a
branch that can change under you, and `sha256sum -c` checks it before it is
given its real name. If the check fails, nothing runs and no unchecked copy
is left behind. The app shows the same command, and the pin and checksum
live in one place: `HostScripts` in `lib/ui/setup_commands.dart`, which
`test/host_script_pin_test.dart` checks against the script in the
repository.

This installs OpenCode if it is missing, writes a `systemd --user` unit that
runs `opencode serve --hostname 127.0.0.1 --port 4096`, enables it, and
starts it. Re-running `install` is safe; it refreshes the unit in place.

How OpenCode itself is installed depends on the script the pin points at.
The release 1.0.44 script above still runs OpenCode's own installer
(`opencode.ai/install`). The script in the repository now installs one
pinned OpenCode release instead (1.18.32, the version the app pins): it
downloads the archive for your CPU from OpenCode's GitHub releases, checks
it against the SHA-256 recorded in the script, and installs it to
`~/.opencode/bin` only if it matches. The app and this guide move to that
script once a commit holding it is published; see
`docs/qa/slice-script-pins-2026-09-28/README.md`.

Want a different port or bind address?

```sh
OPENCODE_PORT=5000 OPENCODE_HOSTNAME=127.0.0.1 bash ubuntu-opencode.sh install
```

### Keep it running after logout

```sh
loginctl enable-linger "$USER"
```

Without linger, systemd stops user services when your last session ends.

### Firewall

Leave it closed. The service listens on `127.0.0.1` only, so opening a
port does nothing for you and everything for anyone else on the network:
an OpenCode server runs shell commands as your user.

## Day-to-day

```sh
bash ubuntu-opencode.sh status    # service state + listening check
bash ubuntu-opencode.sh restart   # restart the server process
bash ubuntu-opencode.sh logs      # follow the server log (Ctrl-C to stop)
bash ubuntu-opencode.sh update    # move OpenCode to the pinned release, refresh unit, restart
```

The app's Settings screen remains the primary upgrade path when the server
itself reports an available update; `update` here is the host-side
equivalent for servers that don't. With the pinned script it installs the
release the script pins (checked the same way as `install`) and never
downgrades an OpenCode that is already newer; the release 1.0.44 script
runs `opencode upgrade` instead.

## Connecting the phone

The server is loopback-only and the app refuses plain HTTP to anything but
the device's own loopback, so the phone reaches it through a tunnel that
ends at `127.0.0.1` on the phone.

### 1. Bring the server within reach

Do this first. Pairing hands the app an address and a password; it cannot
conjure a route to a server the phone cannot reach.

**USB (simplest).** With the phone plugged in and USB debugging on:

```sh
adb reverse tcp:4096 tcp:4096
```

The phone can then reach the server at `http://127.0.0.1:4096`.

**SSH.** Any SSH client on the phone that forwards a local port works;
forward phone-local `4096` to `127.0.0.1:4096` on this machine, which gives
the same `http://127.0.0.1:4096`.

**Tailscale Serve or another HTTPS reverse proxy.** Terminate TLS in front
of the server and use the `https://` address. A plain
`http://<tailscale-name>:4096` will be rejected by the app — it is
unencrypted, and the password would cross the network in clear text.

**Binding to the network directly is an advanced path.** It requires
`OPENCODE_ALLOW_REMOTE_BIND=1`, and you should only take it behind TLS.

### 2. Pair (OpenCode 2 servers)

Don't copy the password by hand:

```sh
opencode2 pair
```

It prints the server's addresses, the username (always `opencode`), and the
current serve password, plus a QR encoding all three. In the app's server
editor, either tap **Scan** and point the camera at that QR (Android), or
copy the printed code and tap **Paste pairing code** (anywhere). Either way
the app fills the address, username and password in one step, tries each
address the code carries, and names the one it connected to.

The code contains the serve password, so treat it like the password itself:
it is as good as shell access to this machine. It also goes stale — the
password rotates on every restart unless `OPENCODE_SERVER_PASSWORD` is set,
and a stale code produces "Password rejected" rather than a mystery failure.

`opencode2 pair` reports `http://127.0.0.1:4096` while the service is
loopback-only, which is exactly the address to use once the tunnel above is
up. If you have run `opencode service set hostname 0.0.0.0`, the code will
also carry a plain-HTTP LAN address; the app lists that one as skipped and
says why, because sending the serve password across a network in the clear
is not something it will do. Put TLS in front of it instead.

### Pairing by hand (OpenCode 1 servers)

OpenCode 1 has no `pair` command, so read the password and type the address:

```sh
bash ubuntu-opencode.sh password
```

Then enter `http://127.0.0.1:4096` and that password in the app.

## Uninstall

```sh
systemctl --user disable --now opencode-serve
rm ~/.config/systemd/user/opencode-serve.service
systemctl --user daemon-reload
```
