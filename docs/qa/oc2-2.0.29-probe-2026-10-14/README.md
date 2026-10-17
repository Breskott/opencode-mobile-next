# OpenCode 2.0.29 capability probe (2026-10-14)

Phase 0 of `docs/design/oc1-decommission-plan-2026-10-14.md`. Question: what does a live
stable OpenCode 2 server support, compared with `api2ServerCapabilities` in
`lib/api2/gateway_mappers.dart` (set against beta-18600)?

## Method

- `@opencode/cli@2.0.29` installed with npm in a scratch folder on the build server (Ubuntu 24.04,
  Node 22), own `XDG_*` and `HOME` under that folder, `opencode serve --port 4190 --hostname 127.0.0.1`.
  The per-run password was read from the server log by a helper script and never printed.
- The server's own `/openapi.json` was diffed against the app's calls: **118 paths**
  (`/api/...`; the beta capture had 114). Where a call was safe and needed no model key it was made.
- History migration was proven against a second scratch server (port 4192) that started on a copy of a
  real OpenCode 1.19.0 data directory. OpenCode 1.19.0 created that data with one free-model turn.
- Listeners were found with `ss -ltnp` and stopped by exact PID. Nothing was run on the phone or PC.
- How `location` goes on the wire: query `location[directory]=/abs/path` (URL-encoded), or the server's
  working directory when omitted.

## Table

Verdicts: **available** (works now on 2.0.29), **partial**, **missing** (no endpoint).

### The specific items

| Feature | Verdict | Endpoint | Notes |
|---|---|---|---|
| Revert commit | **available** | `POST /api/session/{id}/revert/commit` | No body. 204. Staged revert (`POST .../revert/stage {messageID, files?}` returns `{data:{messageID, snapshot, files[]}}`) then commit deleted the messages from the boundary (message list went to `[]`); a second commit with nothing staged is also 204. 409 `SessionBusyError` while the session runs. Clear is `DELETE .../revert`. |
| Provider sign-in (OAuth, device code) | **available** | `POST /api/integration/{id}/connect/oauth {methodID, answer?, label?}` -> `{data:{attemptID,url,instructions,mode:"auto"\|"code",time}}`; `GET .../oauth/{attemptID}` -> `{status:"pending"\|"complete"...}`; `POST .../oauth/{attemptID}/complete {code?}`; `DELETE .../oauth/{attemptID}` | Proven live: `openai` method `chatgpt-headless` returned a real device-code URL (`auth.openai.com/codex/device`) and "Enter code: ..." instructions, mode `auto` (the server polls), status `pending`, cancel 204. Ten integrations list an `oauth` method (openai x3 methods, github-copilot device, xai device, opencode console device, gitlab pkce, poe, digitalocean, snowflake-cortex browser). `mode:"code"` means the user pastes a code to `/complete`. Also `connect/key`, `connect/command` (+ status/cancel), `connect/external` (AWS profile, gcloud). |
| `GET /api/experimental/migration/v1` | **available** (read-only status) | `GET /api/experimental/migration/v1` | See "Migration" below. |
| Session import | **available**, at a different path | `POST /api/experimental/session/import` (not `/api/session/import`) | Body `{info, messages}`; `info` is a v2 `Session.Info` and **`info.location.directory` is required** (a top-level `location` is not enough: 400 `Missing key ["info"]["location"]`); `parentID` must already exist. Returns `{data: Session.Info}`. Proven by exporting from one server (`GET /api/experimental/session/{id}/export?sanitize=`) and importing into another; the messages listed identically. It takes the **v2 transcript shape, not OpenCode 1 JSON**. `lib/api2/dialect.dart` already rewrites `/session/import` and `/session/stats` to `/experimental/...`. |
| Todo | **missing** | none | No route or event. `todowrite` appears only inside the migration code (v1 tool name). |
| Share | **missing** | none | Only the config enum `share: manual\|auto\|disabled`. No share route; sessions have no `share_url` on the wire. |
| Archive | **missing** | none | `Session.time.archived` is read-only; `PATCH /api/session/{id}` takes only `{metadata, permissions}`; the session list has no archived filter. (`GET /api/project?archived=true` exists for projects.) |
| Message delete | **missing** | none | Only revert (which truncates from a boundary) and `DELETE /api/session/{id}`. |
| Text search | **missing** | none (`GET /api/fs/find?query=&type=file\|directory&limit=` is **path-only**) | `fs/find` ranks file and directory names; `query=hi` did not match file contents. No grep route. |
| Symbol search | **missing** | none | No LSP route. |
| Worktree create | **available** | `POST /api/worktree {projectID, name?, from?, branch?, directory?}` -> `{directory}` | Proven: `{projectID, name:"probe-a"}` created a real git worktree under `<data>/opencode/worktree/<id6>/probe-a` and listed `strategy:"git"`. `strategy` is **not** a request field on stable (the beta note "`{strategy, directory}` required" no longer holds). Runs the project setup script. The project needs a commit (a repo without commits got project id `global`). |
| Worktree list / refresh / remove | **available** | `GET /api/worktree?projectID=`; `POST /api/worktree/refresh {projectID}` (204); `DELETE /api/worktree {projectID, directory, force}` (all three required, 204) | Remove proven (git showed the worktree gone). `WorktreeError.data.forceRequired` marks a dirty tree. |
| Worktree reset | **missing** | none | Only create / refresh / remove. |
| MCP OAuth | **missing** | none | `GET /api/mcp` can report `status: needs_auth`, but no authenticate/callback route exists. `PUT /api/experimental/mcp/{server}` accepts remote `oauth:{client_id, client_secret, scope, callback_port, redirect_uri, auth_server_metadata_url}\|false` config only. |
| MCP config writes | **missing** (runtime only) | `PUT/DELETE /api/experimental/mcp/{server}`, `POST .../connect`, `.../disconnect` | Runtime add/remove/connect/disconnect. Nothing persists MCP config. Unchanged from beta. |
| Shell settings | **available** | `GET /api/config/shell` -> `[{path,name,acceptable}]`; `PATCH /api/experimental/config {shell: string\|null}` (204) | Proven: PATCH wrote `"shell":"/bin/bash"` into `<config>/opencode/opencode.jsonc`; `null` removed it. **No validation**: a path that does not exist was accepted with 204, so the app must pick from the `acceptable` list. `GET /api/config` returns documents with the same `info.shell`. |

### Every other flag that is false in `api2ServerCapabilities`

| Flag | Verdict | Endpoint / evidence |
|---|---|---|
| `gitInit` | **available** | `POST /api/vcs/init?provider=git\|hg&location[directory]=` -> 204 (409 already a repo, 501 provider without init, 503). Proven: a bare folder got a `.git`. Description: markerless project directories only. |
| `projectsAreGitRepositories` (stays false) | n/a | Every folder gets a project. The "reports no VCS" comment is stale: `GET /api/vcs`, `/api/vcs/status`, `/branch`, `/diff`, `/base` exist and `GET /api/project` rows carry `vcs:"git"`. |
| `managedWorkspaces`, `workspaceWarp` | **missing** | The workspace API was removed in 2.0.4. Nearest: `POST /api/session/{id}/move` (move a session to another project directory) and the worktree routes. |
| `sessionSteal` | **missing** | No route. |
| `consoleOrganizations` | **missing** | No organizations route. Only the `opencode` integration's console device sign-in (above). |
| `mcpOAuth`, `mcpChatOAuth` | **missing** | See MCP OAuth. |
| `mcpChatToolRefresh` | **missing** | Only `POST /api/location/reload`: rebuilds every loaded location, cancels pending permissions and forms, emits `location.shutdown`; far too heavy to be a per-chat refresh and still no readiness barrier for a running request. |
| `sessionShare`, `sessionArchive`, `sessionTodos`, `messageDelete` | **missing** | See above. |
| `workspaceSymbols`, `textSearch` | **missing** | See above. `fs/find` is a file-name finder (this is `fileBrowsing` territory, not `textSearch`). |
| `languageServiceStatus`, `formatterStatus` | **missing** | Only `Config.LSP.Server` and `Config.Formatter.Entry` config schemas; no status routes. |
| `toolInventory` | **missing** | No tool list. Related lists that do exist: `/api/agent`, `/api/command`, `/api/skill`, `/api/reference`, `/api/plugin`, `/api/mcp`, `/api/mcp/resource`. |
| `experimentalCapabilities` | **partial** | `GET /api/info` returns `capabilities:{persistentPty:true}`; `/api/experimental/persistent-pty/*` and `/api/experimental/session/{id}/terminal` exist. Unclear what the flag gates; leave. |
| `remoteUpgrade` | **missing** | `POST /api/plugin/check` and `/plugin/update` update plugin packages, not the server. |
| `clientDiagnostics` | **missing** | No route. |
| `providerRuntimeRefresh` | **partial** | Only `POST /api/location/reload` (heavy, see above). |
| `configuredProviderFallback` | n/a | v1 `/config/providers` fallback. v2 has `GET /api/provider` (active providers with `activation`, `integrationID`) and `GET /api/provider/{id}`. Models: `/api/model`, `/api/model/default`. |
| `worktreeReset` | **missing** | See worktree. |
| `legacyQuestionRequests` | **missing** (by design) | Replaced by forms, which are on. |

New in 2.0.29 and not yet used by the app (candidates, not asked): `POST /api/pair` + `GET /auth/connect/{code}`
(pairing link), `POST /api/experimental/generate` and `/session/{id}/generate`, `GET /api/reference`,
`POST /api/experimental/session/{id}/skill`, `/session/{id}/wait`, `GET /api/experimental/session/stats`,
`POST /api/experimental/fs/write`, `/api/experimental/session/{id}/instructions/entries`.

## Migration: `GET /api/experimental/migration/v1`

What it is: a **status read** of a migration the server runs **by itself, in the background, on every
`opencode serve` start**. It has no inputs (no query, no body) and no way to start, retry or cancel.

- Response (union): `{status:"required"}` | `{status:"completed"}` | `{status:"running", progress:{label, numerator?, denominator?}}` | `{status:"error", error}`.
  Labels seen in the binary: `Clearing old events`, `Migrating sessions` (numerator/denominator are session counts).
  `required` means V1 tables exist and the work has not run or started yet; a fresh data directory with no V1 tables reports `completed`.
- What it migrates: the server's **own SQLite file** `$XDG_DATA_HOME/opencode/opencode.db` (the same file OpenCode 1.x writes).
  V1 tables `session`, `message`, `part` are copied into `session_v2` plus the v2 event log (`INSERT OR IGNORE`),
  one transaction per session, with a per-row "Skipped V1 migration row" warning for rows it cannot convert.
  A recorded "phase completed" marker stops it from running again.
- **It cannot point at another data directory.** The only handle is the process environment (`XDG_DATA_HOME`),
  or placing the V1 database file where the V2 server looks.
- Proven: OpenCode 1.19.0 made one session with one free-model turn; a copy of its data directory was given to
  2.0.29. After start the status was `completed` within seconds, `GET /api/session` listed the session
  (`projectID`, `title`, model, cost, tokens, the V1 working directory as `location.directory`) and
  `GET /api/session/{id}/message` returned the user and assistant turns, with reasoning and text parts.
  Not tested: a large history (progress labels), a V1 database added after V2 already wrote a "completed" marker, a V1 database
  from before the SQLite era (JSON storage), and running V1 and V2 on the same file at once.

What the phone needs in order to bring OpenCode 1 history over:
1. Start the OpenCode 2 server with the **same XDG data directory** the OpenCode 1 server used (so it opens the same `opencode.db`),
   or copy `opencode.db` (plus `-wal` and `-shm`, after stopping OpenCode 1) into the OpenCode 2 data directory **before OpenCode 2's first start**.
   The current switch gives OpenCode 2 its own folder, which is why chats stay behind.
2. Poll `GET /api/experimental/migration/v1` after start until `completed`; show `progress.label` and numerator/denominator while `running`; show a plain-words recovery for `error`.
3. Keep a copy of the V1 database until the owner has seen the chats in OpenCode 2 (migration is additive, but a bad copy over a live V2 database loses V2 data).
4. The per-session alternative is export from a V2 server and `POST /api/experimental/session/import`; that moves V2 transcripts only, not V1 JSON.

## Flag changes I would make (not applied)

| Flag | From | To | Why / what to wire |
|---|---|---|---|
| `gitInit` | false | **true** | `POST /api/vcs/init` proven. |
| `worktreeCreate` | false | **true** | `{projectID, name}` proven (the dialect already adds `projectID`). Keep the project-has-a-commit guard in the UI. |
| `shellSettings` | false | **true** | List from `/api/config/shell`; write `PATCH /api/experimental/config {shell}`; pick only from `acceptable` entries (no server validation). |
| `providerRuntimeRefresh` | false | leave false | Only a whole-server reload exists. |
| everything else listed above | false | leave false | No endpoint. |

Not flags, but wiring that now has a target: revert **commit** (B3), provider **OAuth / device-code** sign-in (B4, `integration.connect.oauth`; the adapter lives with `integrationCredentials`),
and the migration status poll (B1).
Also fix the stale comments in `api2ServerCapabilities` (beta-18600, "reports no VCS", "{strategy, directory} required").
