# Setup server contract research — 2026-09-27

Finish line: expose truthful, project-scoped config inspection and MCP inventory
through the existing authenticated clients, with typed safe failures and an
explicit refusal of mutations that cannot satisfy review plus Undo.

Non-goal: general file writes, shell commands, credential discovery, SDK edits,
UI work, live server mutation, or pretending a runtime MCP addition is a durable
installation.

Read set: `AGENTS.md`; `STANDARDS.md` sections 2, 3, 13, 15; `contracts/`;
`lib/api/opencode_api.dart`, `lib/api/product_repository.dart`; `lib/api2/`;
`docs/opencode2-protocol-notes.md`; official upstream sources below.
Write set: the two new `setup_config_adapter.dart` files, their behaviour test,
this research record, and the two additive capability flags in
`lib/api2/gateway_mappers.dart`. Dependency: root-owned setup domain types.

## Confirmed repository contracts

| Topic | OC1 (`opencode-openapi-f12e14cf.json`) | OC2 beta (`opencode2-openapi-beta-18600.json`) |
|---|---|---|
| Configuration read | `GET /config` effective Config; `GET /global/config` global Config | `GET /api/config` ordered source entries, not an effective object |
| Configuration write | `PATCH /config`, `PATCH /global/config`; schema-shaped Config, not JSON Patch | No config write endpoint in the pinned beta contract |
| Project scope | `directory`, `workspace` query parameters | `location[directory]`, `location[workspace]` |
| MCP inventory | `GET /mcp`: map of names to status | `GET /api/mcp`: `{location,data:[{name,status:{status,...},integrationID?}]}` |
| Runtime MCP changes | `POST /mcp`; connect/disconnect routes per name | PUT/DELETE `/api/mcp/{server}`; connect/disconnect routes |
| MCP config flags | Named entries under `mcp`; `enabled` | Beta uses `disabled`; current public V2 docs have `mcp.servers`, so never copy OC1's shape blindly |
| Provider metadata | `/provider`, `/provider/auth`; `/config/providers` can include credentials and is deliberately never requested here | `/api/provider`, `/api/model`, `/api/model/default`; generic integrations manage credentials |
| Agents / commands | `agent`, `command` config maps; GET `/agent`, `/command` catalogs | `agents`, `commands` in beta Config.Info; `/api/agent`, `/api/command` catalogs |
| Permissions | `permission` config object; pending-request reply endpoints are separate from configuration | `permissions` ordered `{action,resource,effect}` rules; permission requests and saved decisions are distinct APIs |

OC1 local MCP entries require `type: local`, `command: string[]`; optional
`cwd`, `environment`, `enabled`, `timeout`. Remote entries require
`type: remote`, `url`; optional `headers`, `enabled`, `timeout`, and OAuth
configuration or `false`. OAuth fields include `clientId`, `clientSecret`,
`scope`, `callbackPort`, `redirectUri`. None of their credential values belong
in display snapshots or persisted audit records. The schema also permits
`{enabled: boolean}` overrides for inherited MCP entries.

OC2 beta local/remote runtime configs use similar command/environment and
URL/headers fields but use `disabled` and may include `codemode`. The existing
dialect-aware transport moves stable-generation MCP mutations under
experimental routes; this adapter only reads stable `/mcp` and `/config` routes.
OC2 source entries retain document/directory/agents/claude provenance and order
in `{'sources': [...]}`. The adapter does not claim to merge these correctly.

## Official-source checks and feasibility decision

The official [server API documentation](https://opencode.ai/docs/server/)
confirms Basic authentication, config GET/PATCH, catalog endpoints and session
creation/prompt endpoints. Existing clients already own credentials. Adapters
reuse those clients and send no credential-bearing query string.

The [configuration documentation](https://opencode.ai/docs/config/) describes
multiple config sources and precedence. A read of the effective configuration
does not expose a reversible, writable snapshot of each underlying source.

At the contract revision, upstream
[config.ts](https://raw.githubusercontent.com/anomalyco/opencode/f12e14cf/packages/opencode/src/config/config.ts)
implements project updates by deep-merging into project `config.json`, and
global updates through merging/JSONC modifications. Reapplying the old effective
object cannot remove a newly introduced property or restore whether a value
was originally inherited. No revision precondition or documented reversible
transaction was found in the pinned config endpoints. This is an inference
from source plus schema, not a live mutation test.

Therefore **both production adapters advertise `writeConfig: false`** and
`patchConfig` always fails before making a request. OC1 has writes, but not the
verified reversible semantics required by this feature. OC2 beta lacks config
writes altogether. Runtime MCP connect/add/remove is not a substitute: it does
not supply a durable config transaction or restoration of previous auth state.
Install/remove/Apply/Undo remain unavailable through these production adapters.
No shell/file-write workaround was built.

The current [V2 MCP documentation](https://opencode.ai/v2/docs/mcp-servers)
shows a newer `mcp.servers` schema and project/global CLI persistence.
Consequently the beta's missing-endpoint statement is scoped to the captured
contract, not every current or future OC2 release. A newer server needs a
separate verified reversible-write contract before enabling writes here.

## Live application versus restart

Runtime MCP endpoints act on the current server location; the app's existing
OC2 capability mapper explicitly describes runtime additions as lasting until
restart. Durable configuration is distinct. Pinned schema documents PATCH
success responses but does not guarantee that every model, provider, agent,
permission, command or listener setting applies immediately to existing
sessions. Repository research for OC2 stable records configuration reload
introduced in 2.0.7; the current adapter does not invoke it. No blanket
“applies live” or “restart needed” success promise is made. A future write
adapter must report the setting-specific reload outcome and verify by refetch;
server listener/auth changes require separate connection-management design.

## Assistant session feasibility

OC1 supports session creation and prompt fields including `system`, `agent`,
`tools` and model selection. OC2 has session and agent APIs. These existing
surfaces alone do not prove a sandbox that can inspect configuration while
preventing an agent from writing files or invoking MCP tools before the user's
review. A system prompt is not enforcement. Both adapters consequently expose
`assistant: false`; no unrestricted agent session is started by them. The
application's separate assistant provider/controller contract can accept only
typed proposals once a restricted execution mechanism is verified.

Codex and Claude Code through Paseo have no verified configuration transaction
adapter in this slice. Existing session/chat capability must not imply config
inspection, reversible write, or MCP management capability.

## Adapter API and failure contract

- `OpenCode1SetupConfigGateway({required OpenCodeApi api})`
- `OpenCode2SetupConfigGateway({required Api2Client client})`
- Both implement `SetupConfigGateway`: `support`, `readConfig()`,
  `patchConfig(patch)`, `listMcpServers()`.
- `readConfig()` is the **raw in-memory adapter/controller boundary**. UI must
  use the controller's redacted snapshot, never this method directly.
- Inventories return safe names and whitelisted status strings. Unknown
  statuses become `unknown`; raw diagnostic/error fields are discarded.
- `SetupFailureCode.needsSignIn` maps 401/403, `offline` maps transport
  connection failures, `transport` maps other failures, `invalid` rejects
  malformed payloads, and `unsupported` rejects writes before network access.
  Error objects never retain or stringify server response bodies.
- These adapters persist nothing and introduce no transport or credential
  logger. They borrow, and do not close, the profile-owned clients.

## Focused checks

`test/setup_config_adapter_test.dart` covers both protocols: selected-location
queries and existing authentication, ordered OC2 sources, no network on refused
write, inventory status normalization, 401/403/500 safe failures, offline
failures, and malformed response rejection. Tests use synthetic values only.
No Flutter tests were launched by this worker; the coordinator owns serialized
verification and the user requested written tests for an external verifier.

Pinned `dart format --language-version=3.10` completed on the two adapters,
capability mapper and test. It reported the checkout's missing package
resolution for `flutter_lints/flutter.yaml`; formatting itself succeeded.
No live servers, signing, releases, push, or SDK changes were performed.
