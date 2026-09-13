# Control-plane front (AI Team · Gas City)

`front.py` is the small host-side service that lets the phone reach a Gas
City supervisor over the tailnet with an identity attached to every request.
It runs on the same computer as the supervisor, listens on that computer's
Tailscale address in plain HTTP (WireGuard already encrypts and
authenticates the hop; no Tailscale Serve, no certificates, never Funnel)
and proxies to the loopback supervisor. Standard-library Python 3, one file.

What it adds on top of a raw TCP forwarder:

| Concern | Front |
|---|---|
| Who is calling | `tailscale whois --json <peer-ip>` per request (cached 10 min; a whois that times out reuses the peer's last identity for up to an hour): login name and node tags |
| Reads (`GET`/`HEAD`/`OPTIONS`) | allowlisted identities; or any identified tailnet peer with `--reads-any-peer` |
| Mutations (`POST`/`PUT`/`PATCH`/`DELETE`) | allowlisted identities only; forwarded with `X-GC-Request: opencode-mobile-front` and `Host` rewritten to the supervisor's `host:port` |
| Idempotency | `Idempotency-Key` → receipt stored on disk (fsync); a replay answers the stored receipt without touching the supervisor; the same key from another identity is a 409 |
| Streams | `/events/stream` and `/session/{id}/stream` are relayed chunk by chunk, `Last-Event-ID` forwarded, client disconnect closes the upstream stream |
| Discovery | `GET /.well-known/opencode-mobile-orchestration` for any identified tailnet peer |
| Merge roles | `merge-readiness`, `mr/{bead}/approve` and `merge/{run}` answered by the front itself over git on the host (Gas City v0 has no merge-request API); never a force push, never a branch or worktree deletion |
| Policy | `GET .../front/policy` answers the rig's supervision level and boundary texts from the per-rig config, read-only, so the phone shows the host's rules instead of inventing them |
| Hygiene | hop-by-hop headers stripped; the client's `Authorization` and `Cookie` never reach the supervisor; `Set-Cookie` never reaches the phone; one log line per request, never bodies, keys or whois output |

## Install

```sh
mkdir -p ~/.local/bin ~/.config/opencode-mobile-front
cp tool/host/cp_front/front.py ~/.local/bin/opencode-mobile-front
chmod +x ~/.local/bin/opencode-mobile-front

# find your tailnet login (or read it off the Tailscale admin console)
tailscale whois $(tailscale ip -4)      # "UserProfile: LoginName: you@example.com"

~/.local/bin/opencode-mobile-front \
  --supervisor http://127.0.0.1:8372 \
  --bind $(tailscale ip -4) --port 8373 \
  --allow you@example.com
```

Flags:

| Flag | Default | Meaning |
|---|---|---|
| `--supervisor` | `http://127.0.0.1:8372` | the loopback supervisor |
| `--bind` | required | the computer's Tailscale IPv4/IPv6 or loopback; anything else is refused |
| `--port` | `8373` | listen port (`0` = ephemeral) |
| `--allow LOGIN` | | tailnet login allowed to read and write; repeatable |
| `--allow-tags tag:x` | | node tag allowed to read and write (tagged devices have no login); repeatable |
| `--reads-any-peer` | off | every identified tailnet peer may read; writes stay allowlisted |
| `--city NAME` | first running city | the city advertised in the well-known document |
| `--whois-cmd` | `tailscale whois --json` | command that maps a peer IP to identity JSON |
| `--whois-ttl` | `600` | seconds to cache whois answers; a whois that times out reuses the peer's last identity for up to an hour |
| `--state-dir` | `~/.config/opencode-mobile-front` | where `receipts.json`, `rigs/<rig>.json` and `merge-checks.json` live |
| `--git` | `git` | git executable used by the merge roles |
| `--print-config` | | print the effective settings and exit |
| `--insecure-allow-any-peer` | | tests only: skip identity checks; prints a warning |

Startup refusals (exit 2 with the reason on stderr): `--bind` is neither
loopback nor a Tailscale address (100.64.0.0/10, fd7a:115c:a1e0::/48); the
allowlist is empty; the supervisor does not answer `GET /health`.

### systemd user unit

`~/.config/systemd/user/opencode-mobile-front.service`:

```ini
[Unit]
Description=OpenCode Mobile control-plane front (AI Team · Gas City)
After=network-online.target tailscaled.service

[Service]
ExecStart=%h/.local/bin/opencode-mobile-front --supervisor http://127.0.0.1:8372 --bind 100.x.y.z --port 8373 --allow you@example.com
Restart=on-failure
RestartSec=3
KillSignal=SIGTERM

[Install]
WantedBy=default.target
```

```sh
systemctl --user daemon-reload
systemctl --user enable --now opencode-mobile-front
journalctl --user -u opencode-mobile-front -f
loginctl enable-linger $USER      # keep it running after you log out
```

Use the literal Tailscale IP in the unit (`tailscale ip -4`); systemd does
not expand `$(...)`.

## Allowlist semantics

- `--allow you@example.com` matches the `UserProfile.LoginName` that
  `tailscale whois` reports for the peer, case-insensitively. Devices you
  log into with your own account (your phone) carry your login.
- `--allow-tags tag:phone` matches any of the peer node's `Node.Tags`.
  Tagged devices report the login `tagged-devices`, so tag them and allow the
  tag instead.
- Reads and writes use the same allowlist. `--reads-any-peer` opens reads
  to every device on the tailnet that whois can identify; writes never open.
- A peer whois cannot identify (not a tailnet address, whois failed) gets a
  403 `peer-not-on-tailnet` for everything, including the well-known route.
  A whois that times out (8 s) or cannot run does not count against a peer
  the front resolved within the last hour: its last identity is reused and
  the log says `whois timeout; using cached identity`.
- Refusals are problem+json (`application/problem+json`) with
  `type: urn:opencode-mobile:front:<code>`; codes: `peer-not-on-tailnet`,
  `identity-not-allowed`, `idempotency-mismatch`, `upstream-unavailable`,
  `length-required`, `payload-too-large`, `method-not-allowed`.

## Verify from the phone

Anything on your tailnet, e.g. Termux on the phone:

```sh
curl http://100.x.y.z:8373/.well-known/opencode-mobile-orchestration
```

```json
{"provider": "gascity", "supervisorUrl": "http://100.x.y.z:8373", "city": "myteam",
 "front": true, "version": "1.4.1",
 "capabilities": {"read": true, "control": true, "merge": true},
 "identity": {"login": "you@example.com", "allowed": true}}
```

`identity.allowed` tells you whether that device may write; `supervisorUrl`
is what the app uses as the base URL (the front keeps the supervisor's
paths, so `/v0/city/<city>/...` works unchanged). `capabilities.merge` is
true when git is available and at least one rig of the city has an `origin`
remote and a resolvable default branch (checked every 60 s). Then in the app: Settings
› Plugins › AI Team › Add manually, URL `http://100.x.y.z:8373`.

## Mutations and receipts

Send mutations exactly as you would to the supervisor, plus
`Idempotency-Key: <uuid>` (generate one per attempt the user makes, keep it
across retries). The front answers the supervisor's status code with a
receipt body (`application/json`) and `X-GC-Request-Id`:

```json
{"request_id": "95c2b27606552450", "status": "accepted", "upstream_status": 202,
 "body": {"status": "accepted", "id": "bl-48k"}, "idempotency_key": "…"}
```

- `request_id`: the supervisor's `X-GC-Request-Id` (every supervisor response
  carries one), else a front-minted `front-<hex>`.
- `status`: `accepted` for a 2xx upstream answer, `rejected` otherwise; the
  upstream body (problem+json on rejection) is in `body`.
- A replay with the same key returns the same receipt and the header
  `Idempotent-Replayed: true`; the supervisor is not called again. Receipts
  survive a front restart (`<state-dir>/receipts.json`, fsynced, last 5000).
- The same key from a different identity is a 409 `idempotency-mismatch`.
- A mutation without a key is forwarded once and answered with a receipt
  whose `idempotency_key` is `null`; nothing is stored.
- If the supervisor is unreachable the answer is 502 `upstream-unavailable`
  and nothing is stored, so the same key may be retried.

Supervisor facts the receipts rely on (pinned spec
`contracts/gascity-supervisor-openapi-v0-3648ca2d499a.json`): every mutation
needs `X-GC-Request` (any non-empty value; the front sets it) and answers
`X-GC-Request-Id`; `POST /session/{id}/respond` takes
`{action, request_id?, text?, metadata?}` (`action` is the option, e.g.
`allow`/`deny` or a choice; `request_id` is the pending interaction) and
answers 202 `{status, id}`; `POST /session/{id}/messages` takes `{message}`
and answers 202 `{status, request_id, event_cursor}` whose result arrives on
the event stream as `request.result.*` / `request.failed` with that
`request_id`.

## Merge roles (TEAM-205)

Gas City v0 merges through its refinery agent (`merge_strategy: local`) and
has no merge-request API, so the front implements the three merge roles of
02-ux §8a itself, over git on the host, behind the same identity gate as
everything else (reads for readers, the two mutations for allowlisted
identities only) and the same receipt store. The routes sit under the city
path so the app's base URL works unchanged:

| Route | Role |
|---|---|
| `GET /v0/city/{city}/front/merge-readiness/{runId}` | the readiness checklist, diff summary, boundaries and the merge request |
| `POST /v0/city/{city}/front/mr/{beadId}/approve` | approve the merge request (idempotent by `Idempotency-Key`) |
| `POST /v0/city/{city}/front/merge/{runId}` | merge the run's branches into the rig's target branch (idempotent by `Idempotency-Key`) |

### What a run's merge is

- **Run → work.** A convoy (`GET /convoys`, `id == runId`) tracks its beads
  through `dependencies[].type == "tracks"`. A formula run (`GET /runs`)
  collects the beads whose `metadata.run_id` / `gc.run_id` equals the run
  id. Anything else is 404 `run-not-found`.
- **Rig and target.** The rig is the convoy's or a bead's `metadata.rig`,
  else the `rig/` prefix of a bead's assignee. Its path and default branch
  come from `GET /rig/{name}` (fallback: `/status` `rig_details`). The
  target branch is the first bead `metadata.target`, else the rig's
  `default_branch`, else `origin/HEAD`, else `main`/`master`. No origin
  remote, no path, no default branch or no git → 422 `merge-unavailable`.
- **Branches.** Each bead's `metadata.branch` (default `polecat/<bead>`).
  Branches on `origin` that are already ancestors of the target are skipped;
  an open bead without a branch fails the `conflicts` line; a closed one is
  taken as merged by the refinery.
- **Candidate.** The front makes its own temporary clone under
  `<state-dir>/tmp/` (`git clone --shared --no-checkout`, never `git
  worktree`), fetches `origin`, checks out `origin/<target>` detached and
  merges every branch: a single fast-forwardable branch fast-forwards,
  anything else is a `--no-ff` merge commit authored by the requesting
  login and committed by `opencode-mobile-front`. A conflict aborts the
  merge and names the branch and files. The diff against the target gives
  `files`, `additions`, `deletions` and the first 200 `changes`. The clone
  is removed as soon as it is no longer needed. The rig's own checkout is
  never touched: the front only runs `fetch`, `ls-remote`, `merge-base` and
  `remote get-url` inside it.
- **Merge.** `POST .../merge/{runId}` recomputes readiness, refuses with a
  rejected receipt when a line fails (409 `not-ready`, `line` names it) or a
  boundary is unsatisfied (403 `boundary`, `boundary` names it and `detail`
  carries its text), otherwise pushes the candidate with
  `git push origin HEAD:refs/heads/<target>` — never `--force`, never a
  deletion — and answers `{"status": "merged", "mergeCommit", "branch",
  "alreadyMerged", "branches", "fastForward"}` (200). A run with nothing
  left to merge answers `alreadyMerged: true` without pushing. The rig is
  fetched afterwards so its `origin/<target>` sees the new head.

### Readiness JSON

```json
{"ready": true, "runId": "oc-xru", "rig": "ocproof", "targetBranch": "main",
 "lines": [
   {"key": "work", "ok": true, "detail": "18/18 work items"},
   {"key": "tests", "ok": true, "detail": "passed"},
   {"key": "build", "ok": true, "detail": "not configured on the host"},
   {"key": "review", "ok": true, "detail": "approved by you@example.com"},
   {"key": "conflicts", "ok": true, "detail": "1 branch(es) merge cleanly into main"},
   {"key": "acceptance", "ok": true, "detail": "not reported by the host"}],
 "files": 14, "additions": 841, "deletions": 203,
 "changes": [{"path": "calc.py", "additions": 4, "deletions": 0}],
 "boundaries": [{"key": "require_approval", "satisfied": true, "text": "Never merge without approval"}],
 "mergeRequest": {"id": "oc-xru", "title": "sling-oc-1", "approvedBy": "you@example.com", "approvedAt": "2026-09-11T10:00:00Z"},
 "mergeCommit": "c02e375…", "branches": ["polecat/oc-loy"]}
```

Lines, in order: `work` (every tracked bead closed, `needs-review` or
approved), `tests`, `build` (from `merge_checks`; "not configured on the
host" when absent), any further configured check key, `review` (no tracked
bead still waits for review and the merge request is approved, closed or
was never labelled), `conflicts`, `acceptance` (bead `metadata.validation`
/ `validation_result` / `gc.validation`, string or JSON). A check that is
still running is `{"ok": false, "pending": true, "detail": "running on the
host"}` — refresh later. `ready` is true when every line is ok; the app
disables Merge and names the first failing line otherwise.

### Per-rig config: `<state-dir>/rigs/<rig>.json`

```json
{"supervision": "balanced",
 "merge_checks": [
   {"key": "tests", "command": "python3 -m pytest -q"},
   {"key": "build", "command": "make"},
   "scripts/lint.sh"],
 "boundaries": {"require_approval": true, "require_tests": true,
                "allowed_logins": ["you@example.com"],
                "extra": ["Never touch production"]},
 "check_timeout_sec": 600}
```

- `supervision`: `high`, `balanced` or `autonomous` (default `balanced`;
  anything else is logged and reported as the default). Shown on the
  phone's run overview and Start-a-run sheet; the front does not enforce
  it — it is the level the host's owner set for the rig's agents.
- `boundaries.extra` (optional): free-text rules shown beside the built-in
  boundaries (`extra-1`, `extra-2`, …); the front never applies them, it
  only reports them.

- `merge_checks`: shell commands run in the temporary clone at the merged
  tree, in order; an object names the readiness line (`key`), a bare string
  becomes `check-<n>`. Results are cached per merged tree in
  `<state-dir>/merge-checks.json`, so a check runs once per candidate and
  never again for the same content. The first readiness request that meets
  a new candidate starts the checks in the background and reports them as
  pending.
- `boundaries.require_approval` (default `true`): "Never merge without
  approval" — the merge request bead must carry `review.approved_by`.
- `boundaries.require_tests` (default `true` when `merge_checks` is
  non-empty): "Require tests before merge" — every configured check passed;
  with no checks configured it can never be satisfied.
- `boundaries.allowed_logins` (optional): "Only … may merge" — the
  requesting tailnet login must be listed.
- A missing file means the defaults; a malformed one is logged and treated
  as the defaults. Boundaries the app cannot satisfy are shown on the phone
  with their text, never applied silently.

### Policy: `GET /v0/city/{city}/front/policy[?rig=NAME]` (TEAM-207)

The read-only policy document the phone shows on the run overview
("Supervision · Balanced" plus the boundary chips) and in the Start-a-run
sheet's Boundaries row. Gated like every read. `rig` names the rig whose
config to read; without it the city's first rig (`/status` `rig_details`
order) is used, and a city with no rig answers the defaults with `rig: ""`.
An unknown rig name answers the defaults under that name; a name with `/`
or `..` is 422 `rig-unusable`.

```json
{"rig": "ocproof", "supervision": "balanced",
 "boundaries": [
   {"key": "require_approval", "text": "Never merge without approval"},
   {"key": "require_tests", "text": "Require tests before merge"},
   {"key": "allowed_logins", "text": "Only you@example.com may merge"},
   {"key": "extra-1", "text": "Never touch production"}]}
```

`boundaries` lists exactly the rules `merge-readiness` would evaluate for
that rig (same keys and texts, without the `satisfied` flag, which needs a
run) plus the `extra` strings. `supervision` is the config's value or
`balanced`.

### How approval is persisted

`POST .../mr/{beadId}/approve` reads the bead (a missing one is a rejected
receipt with `upstream_status: 404`) and then sends the supervisor's
`PATCH /v0/city/{city}/bead/{id}` (pinned spec `BeadUpdateBody`) with

```json
{"metadata": {"review.approved_by": "you@example.com", "review.approved_at": "2026-09-11T10:00:00Z"},
 "remove_labels": ["needs-review"]}
```

so the approval is a bead metadata pair and the `needs-review` label is
cleared in the same call. The bead is the one the readiness document names
in `mergeRequest.id`: a `merge-request` bead referencing the run when the
pack made one, else the convoy bead itself. The receipt's `body` is the
updated bead.

### What never happens on the phone path

No `--force`, `-f` or `+refspec` push, no `reset --hard`, no `branch -d/-D`,
no `push :branch`, no `git worktree` verb at all: the tests assert none of
these ever appears in the recorded git invocations. The only thing the
front deletes is its own temporary clone under `<state-dir>/tmp/`.

## Security model

- Identity comes from the tailnet, not from a password: only devices
  admitted to your tailnet can reach the address at all, and the front asks
  `tailscaled` who each peer is. There is nothing to type on the phone and
  nothing to leak.
- Writes are gated by identity (login or tag allowlist). Reads are gated the
  same way unless you opt into `--reads-any-peer`.
- Nothing is public. The front refuses to bind non-tailnet addresses, `tailscale
  funnel` is never used, and plain HTTP keeps the hostname out of public
  Certificate Transparency logs (owner decision 5 in
  `docs/plans/gas-city-plugin-2026-09-10/06-decisions-and-readiness.md`).
- The supervisor keeps its own loopback-only listener and anti-rebinding
  `allowed_hosts`; the front always presents `Host: 127.0.0.1:8372`.
- Logs carry method, path, login, status and request id only.

## Replaces the raw forwarder in docs/ai-team-host.md §5

The read-only phase used a TCP forwarder (`socat` or
`tool/host/tailnet_proxy.py`) plus `allowed_hosts` entries for the tailnet
address in `~/.gc/supervisor.toml`. The front replaces the forwarder: it
speaks HTTP, identifies the caller, gates writes and rewrites `Host`, so the
extra `allowed_hosts` entries become optional (harmless to keep). Stop the
forwarder before starting the front on the same port, or run the front on
8373 as documented.

## Tests

```sh
python3 -m unittest discover -s tool/host/cp_front/tests -p 'test_*.py'
```

59 tests, under fifteen seconds: startup refusals, well-known shape, read/write
gating by login and tag, header hygiene, receipts (replay, restart, 409,
502), SSE pass-through with `Last-Event-ID` and disconnect propagation, log
hygiene, three runs against the recorded fixture in
`tool/qa/gascity_fixture`, the merge roles against a temporary bare
origin plus rig clone (readiness pass/fail lines, checks and their cache,
approve, fast-forward and `--no-ff` merges, boundary refusals, replays,
and the no-force / no-deletion / no-worktree assertions), and the policy
route (defaults, config values, fallbacks, rig selection, read gating). Peers are simulated by connecting from different
loopback source addresses that `tests/fake_whois.py` maps to identities.
