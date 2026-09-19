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
