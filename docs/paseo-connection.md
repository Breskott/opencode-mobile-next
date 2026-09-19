# Connect the app to Claude Code and Pi through Paseo

Paseo support is experimental and available in the development source. See
[the spike notes](research/paseo-backend-spike-2026-09-19.md) for the protocol
and [the captures](qa/paseo/) for the verified flow.

Claude Code and Pi have no network API of their own. [Paseo](https://github.com/getpaseo/paseo)
(Apache-2.0) is a daemon that runs beside those CLIs on your computer and
drives them; this app talks to that daemon over one WebSocket. Paseo's own
relay and QR pairing are **never used**: the app connects on this device or
over your private network (Tailscale) only.

## Host setup

On the computer that has the project and the agent CLIs (`claude`, `pi`, …)
installed and logged in:

```sh
npm install -g @getpaseo/cli

# This device only (emulator, desktop, or a phone reaching it by port forward)
paseo start --no-relay

# A phone over Tailscale: listen on the Tailscale address and require a password
PASEO_PASSWORD='choose-a-long-secret' \
  paseo start --no-relay --listen "$(tailscale ip -4):6767"
```

- `--no-relay` keeps the daemon off `relay.paseo.sh`. Do not enable the relay.
- The password may contain no spaces or commas (it travels in a WebSocket
  subprotocol). `paseo daemon set-password` stores a hashed one in the daemon's
  `config.json` instead of the environment.
- The daemon checks the `Host` header. IP addresses pass by default; to connect
  by a MagicDNS name add `--hostnames .ts.net`.
- `paseo status` lists which runtimes the daemon found.

## In the app

Servers → add → **Paseo: Claude Code, Pi (experimental)**.

| Field | Value |
|---|---|
| Server address | `ws://<tailscale-ip>:6767`, `ws://127.0.0.1:6767`, or `wss://…` |
| Project folder on server | Absolute path of the project on the computer |
| Daemon password | The password above; empty if none was set |

Plain `ws://` is accepted only for this device and for Tailscale addresses
(`100.64.0.0/10`, `*.ts.net`), where the network already encrypts the hop.
Anything else needs `wss://`.

## How it maps

| App | Paseo |
|---|---|
| Session | Agent (one provider conversation) in the project folder |
| Model picker: provider | Runtime: Claude Code, Pi, Codex, Copilot, OpenCode |
| Model picker: model | That runtime's model |
| Agent selector in the composer | The runtime's permission mode (default, plan, accept edits, …) |
| Permission card | Daemon permission request; **Always allow** applies the rule the runtime suggested (for Claude: accept edits for this session) |
| Delete session | Archives the agent; the runtime's own session stays on the computer |

A new conversation is created on the daemon with its first prompt, because
the runtime is only known once a model is chosen. The model's provider at that
moment decides the runtime for the life of the conversation.

## Not available yet

Files, diffs, git, terminal, attachments, slash commands, session fork/revert,
todos and questions are off for this backend (the daemon has RPCs for several
of them; they are not mapped yet). Pi has not completed a live turn in
verification because the only Pi credential on the test machine was over quota.
On-device hosting of the daemon in Termux is unexplored.

## Verification

- `test/paseo_gateway_test.dart` — transport, mapping, permissions, reconnect.
- `tool/qa/paseo_live_proof_test.dart` — a real Claude turn through the gateway:
  `PASEO_LIVE_URL=ws://127.0.0.1:6767 PASEO_LIVE_DIR=/abs/project flutter test tool/qa/paseo_live_proof_test.dart`
- Emulator run on 2026-09-19 against daemon 0.8.0: add server, test, connect,
  new session, streamed Write tool call, permission review and allow, reply,
  follow-up turn, model picker, reopen from the session list.
