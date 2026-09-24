# OpenCode 2 went stable — what changed, 2026-09-20

The app's phone installer pins `@opencode-ai/cli@0.0.0-beta-18600`
(2026-08-28). That package name is dead: on 2026-09-07 the project moved to the
`@opencode` npm scope, and on 2026-09-11 it released **2.0.0**.

| | Package | Version | Date |
|---|---|---|---|
| App's pin | `@opencode-ai/cli` | `0.0.0-beta-18600` | 2026-08-28 |
| Last build under the old name | `@opencode-ai/cli` | `0.0.0-beta-19271` | 2026-09-07 |
| **Latest stable** | **`@opencode/cli`** | **`2.0.10`** | 2026-09-19 |
| Latest beta | `@opencode/cli` | `0.0.0-beta-19507` | 2026-09-12 |

Source: `github.com/anomalyco/opencode`, tags `v2.0.0` … `v2.0.10` (303 commits
between them). There are no written release notes; this is read from commit
subjects. The binary is now `opencode`, with `opencode2` kept as an alias.

## What matters to this app

**2.0.4 (2026-09-16) changed the server protocol the app speaks** (`lib/api2/`):
removed the current-project endpoint, removed the `v2` operation prefixes,
consolidated server status into one endpoint, removed the workspace API and the
preferences API, simplified response locations, session actions, session and
interactive resources, skill and reference contracts, the VCS and shell APIs,
and the permissions event. The project's own client needed a fix for "servers
missing status endpoint". Expect the app's OpenCode 2 client to break against
2.0.4+ until it is ported; the flavor probe (`lib/api/server_probe.dart`) is
the first thing to check.

Additions worth using later: a server-info endpoint and `fs.write` (2.0.6),
a turn-diff route (2.0.3), configuration reload (2.0.7), enforced permission
policies (2.0.7), streamed large attachments (2.0.8), MCP client reworked for
the 2026-07-28 revision with a reason on `needs_auth` (2.0.4), subagents can
pick a model (2.0.5), retry of provider failures for about 84 s (2.0.6),
repair of malformed tool arguments (2.0.9), ACP cancellation fixes (2.0.7).

## Before moving the pin

1. Install `@opencode/cli@2.0.10` on the PC, run `opencode serve`, and run the
   app's v2 suites plus a live connection against it.
2. Port `lib/api2/` to the 2.0.4 protocol; keep 18600 working only if both can
   be told apart cheaply (the new server-info endpoint may do that).
3. Change the installer's package name and pin, and the runtime's name in the
   UI ("OpenCode 2 beta" is no longer a beta).

## Done (2026-09-20)

The app now speaks both generations; see `lib/api2/dialect.dart`.

- **Client:** requests keep the beta vocabulary and are translated at the
  transport once the connect-time health check has settled the generation
  (`/api/health` answers → beta; 404 then `/api/info` → stable). 23 of the 88
  endpoints the app calls had moved or changed method; 14 more changed a
  field (`reply`→`decision`, `command`→`name`, fork `boundary`→`before`,
  interrupt `continue`→`resume`). Cloud environments and changing a running
  command's timeout no longer exist on the stable line and fail clearly.
- **Probes:** the server probe and the phone's running-server probe accept
  `/api/info`, but only in the stable line's own shape, so an OpenCode 1
  server still falls through to the v1 check.
- **Phone installer:** pins `@opencode/cli@2.0.10`. That package installs a
  command named `opencode`, which collides with OpenCode 1 in the shared npm
  prefix (`EEXIST`, reproduced on the PC), so OpenCode 2 installs into
  `/opt/oc2` and only `opencode2` is linked; the dead `@opencode-ai/cli`
  package is removed. Readiness accepts `/api/info` or `/api/health`, and the
  version parser accepts `opencode v2.0.10` as well as `opencode2 v…`.
- **Proof:** `tool/qa/oc2_live_proof_test.dart` passes 46 of 46 steps against
  2.0.10 on the PC (a real model turn included) and shows no regression
  against `0.0.0-beta-18600`. In the emulator with real Termux, the wizard
  switched OpenCode 1 → 2.0.10, the app connected ("This phone · OpenCode
  2"), and a turn ran a Write tool and replied; captures in
  `docs/qa/opencode2-2.0/`. Two bugs were found only by that live run: the
  manager's readiness probe still asked `/api/health`, and the version showed
  as `opencode v2.0.10`.
- **Not done:** the additions in 2.0.x (server-info fields, `fs.write`, turn
  diff, configuration reload, permission policies) are not used yet, and the
  free default model on a fresh server (`jev-1.13-free`) currently fails on
  OpenCode's side with a 500, so a new user must pick another model.

