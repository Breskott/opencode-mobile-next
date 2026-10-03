# SV3 — MCP, tools, provider key links and skill conversation actions

Date: 2026-09-27. Base: `643a5104b53defd5ea5b82c049c4c832f3d3798d`.
Branch: `codex/sv3`, the supplied worktree.

Finish line: expose supported backend actions through small domain/state APIs,
with focused behavior tests and exact unavailable-contract documentation.
Non-goals: UI/controller-owner integration, skill installation, credential
storage, guessed provider links, releases, and changes to generated SDK code.

Read set: `AGENTS.md`, STANDARDS sections **2, 3, 13, 15 only** (read with
`sed` ranges), checked-in contracts, domain/state and protocol implementations.
Write set: new `lib/{api,domain,state}/sv3_*.dart`, `test/sv3_*_test.dart`, this
record, and root `COMMIT_MSG.txt`. Dependencies: existing authenticated gateways,
SDK configuration PATCH, and the optional `SessionSkillGateway` facet.
Acceptance: exact narrow configuration writes; capability-gated actions;
create-before-activate; no duplicate uncertain dispatch; no raw errors or secrets
exposed. Three bounded workers owned tools, MCP, and provider feasibility; the
coordinator owned skills, documentation, and final integration review. Workers
did not run Flutter or edit protected files.

## Server truth and delivered hooks

| item | server has it? | what you built | capability flag | UI hook for the builder |
|---|---|---|---|---|
| Tool source MCP server | No authoritative provenance in either catalog | Unavailable hook; no name-prefix guessing | `codingToolSourceMcp == false` | Omit source attribution until a server source field exists |
| Turn one tool off | V1: yes, config PATCH; V2: no equivalent verified route | Optional V1 adapter writes only `tools[id]: false` | `canConfigureCodingTools(gateway: adapter)` | `ToolConfigurationGateway.setCodingToolEnabled(id, false, scope: ...)` |
| Effective tool enabled state | No catalog field after config/permission overrides | Explicit unknown capability; no fabricated toggle state | `codingToolEnabledState == false` | Offer an explicit Disable action; do not display accepted writes as authoritative effective state |
| Turn MCP server off | Both have runtime disconnect; V1 also persistent `enabled:false` patch | Safe runtime helper and V1 persistent enablement adapter | `mcpRuntimeDisconnect`; `canConfigureMcpEnablement(gateway: adapter)` | Runtime `disconnectMcpRuntime`; persistent `setMcpServerEnabled`; label scope distinctly |
| Delete MCP from configuration | No key-deletion contract; V2 runtime DELETE is not config deletion | Unavailable hook only | `mcpConfigDeletion == false` | Keep unavailable |
| Undo runtime Remove | V2 re-add exists, but no complete pre-removal config/restore receipt | Unavailable hook; no credential/config cache | `mcpRuntimeRemovalUndo == false` | Do not show an Undo action after Remove |
| OAuth expired state | No established-token expiry field/event; `needs_auth` is not expiry | Unavailable hook | `mcpOAuthTokenExpiry == false` | Retain existing needs-auth/unknown presentation |
| Automatic reconnect on token expiry | No expiry signal or documented unattended refresh guarantee | Unavailable hook; no timers or retries | `mcpExpiryAutoReconnect == false` | No expiry-driven reconnect switch |
| Provider Get a key | Neither provider/auth nor integration-key method defines a provisioning URL | Unavailable hook; no URL mappings | `providerKeyPageLinks == false` | Keep unavailable; future URLs must pass `openExternalLink` |
| Use skill in a new conversation | V2: create + explicit activation exist; V1: no activation route | One-action controller creates then activates exact skill ID with `resume:false` | `canStartSkillConversation(optionalSkillGateway)` / controller `canUseSkill` | `useInNewConversation(skill)`; open returned session after `ready` |
| Ask an agent to write a skill | Both: create + ordinary prompt exist; no dedicated authoring endpoint needed | Redacted request for a reviewable SKILL.md draft in a new conversation | `skillAuthoringRequests` / controller `canAskForSkill` | `askAgentToWriteSkill(requirements)`; acknowledgement means request sent, not skill installed |

## UI hook-up

All UI imports must stay in domain/state. No screen should construct a protocol
client or branch on `ServerFlavor`. The integration owner constructs the
protocol companion alongside the existing authenticated gateway and supplies
only the domain interface. Existing `server_gateway.dart`, `connection.dart`,
`product_repository.dart`, `main.dart`, all `lib/ui/**`, and Kotlin are untouched.
New hooks are opt-in; none is wired into the app by this unit.

### Configuration API

Import `lib/domain/sv3_tool_configuration.dart`.

- `CodingToolConfigScope.project` / `.global` selects persistent scope.
- `ToolConfigurationGateway.setCodingToolEnabled(String toolID, bool enabled,
  {required CodingToolConfigScope scope}) -> Future<void>` writes one tool entry.
- `McpConfigurationGateway.setMcpServerEnabled(String name, bool enabled,
  {required CodingToolConfigScope scope}) -> Future<void>` writes one MCP
  enabled-only entry. It does not delete configuration.
- `Sv3ToolCapabilities.canConfigureCodingTools({gateway})` requires
  `toolInventory`, `mcpConfigWrites`, and an injected adapter.
  `canConfigureMcpEnablement({gateway})` requires `serverCatalog`,
  `mcpConfigWrites`, and an adapter. Both are false without injection.
- `codingToolSourceMcp` and `codingToolEnabledState` are always false.
- `ToolConfigurationException.code` is one of `unavailable`, `invalidToolID`,
  `invalidMcpServer`, `projectRequired`, `requestFailed`. Map codes to localized
  UI copy. `requestFailed` may mean the server applied a write but the response
  was lost: never automatically retry or claim failure rolled the write back.

The owner constructs `V1ToolConfigurationGateway(client: authenticatedSdk,
capabilities: currentCapabilities, directory: capturedDirectory,
workspace: capturedWorkspace)` from `lib/api/sv3_tool_configuration.dart`.
The SDK is the existing authenticated `sdk.OpencodeSdk`; no new credential
source, storage or authentication scheme is introduced. The adapter neither
closes nor owns it. Project writes require a nonblank directory. Recreate the
adapter when the profile/location changes; global writes affect that server's
global configuration. Serialize each item's writes and invalidate stale UI
results using the owner's location revision. Disable SDK transport logging:
PATCH responses contain configuration and may include credentials. No response
configuration is retained or returned by the adapter.

Success acknowledges a config patch. It does not prove that a running turn
stopped, that an inherited rule is overridden, or that a tool is effectively
disabled. Refresh available inventory after the action, preserving unknown
effective tool state. V2 cannot safely reuse a whole MCP PUT configuration to
disable an arbitrary existing server: there is no complete config readback.

### Runtime MCP API

Import `lib/domain/sv3_mcp_capabilities.dart`.
`Sv3McpCapabilities` adds `mcpRuntimeDisconnect` (derived from `serverCatalog`)
and the four unavailable getters listed above. `Sv3McpRuntimeActions` on
`McpGateway` adds:

```dart
await operations.disconnectMcpRuntime(
  exactInventoryName,
  capabilities: currentCapabilities,
);
final inventory = await operations.listMcpServers();
```

Run through the owner's existing action preparation/location guard and refetch
after success or uncertain failure. The action stops a runtime connection; it
does not remove configuration or promise persistence across restart.
`Sv3McpRuntimeException.reason` is `unavailable`, `invalidName`, or
`requestFailed`; it retains no raw server error. Use exact server names and
never normalize them into another name. Existing connect remains the way to
connect a retained server; it is not restoration after runtime Remove.

### Skill conversation API

Import `lib/state/sv3_skill_conversation.dart` and
`lib/domain/sv3_skill_capabilities.dart`. Construct one
`SkillConversationController` per explicit user action with:

- `gateway`: captured `ServerGateway`;
- `operations`: captured `ServerOperationsGateway`;
- `isCurrent`: closure comparing captured profile/location revision and **both
  gateway identities**, false after removal/disposal/disconnection;
- `selection`: captured `SessionSelection(model: ..., agent: ..., variant: ...)`
  from the picker. `ModelRef` and `SessionSelection` are re-exported by the
  companion domain file so the UI does not import protocol code. Omitting this
  uses server defaults.

The service creates through the captured gateway directly, using
`SessionSelectionGateway.createSelectedSession` when available. It passes the
same selection to authoring prompts for V1's per-message selection contract.
Prepare the connection before construction, and refresh the owner's inventory
after completion. Do not substitute plain `ConnectionController.createSession`
as a callback: that public method can select another transport while awaiting
preparation. The service accepts no such callback. Invalidate `isCurrent` whenever
either captured gateway's location changes, including an away-and-back change.

Keep the controller instance while the action is pending. Do not create another
instance on double taps, rebuilds, or uncertain responses. `canUseSkill` combines
`ServerCapabilities.serverCatalog` with the existing optional
`SessionSkillGateway.sessionSkillsSupported` runtime probe; `canAskForSkill`
uses `skillAuthoringRequests` (derived from `serverCatalog`). No flavor checks.

`useInNewConversation(SkillInfo) -> Future<SkillConversationResult>` requires a
nonempty, safe `SkillInfo.id`. It never substitutes the display name, slash
command, skill content, or location. It creates a session and then activates
with `resume:false`, leaving the composer idle. The owner should block editing
that pending session until preparation resolves, then open it and refresh
context on success. On V1 this action remains unavailable.

`askAgentToWriteSkill(String requirements) -> Future<SkillConversationResult>`
creates a session and prompts for a draft in chat. It applies `KitRedact` before
sending text that the server will persist. This requests reviewable output; no
skill-install API, file write, or automatic activation is performed by the app.
Normal agent permissions still apply. A prompt instruction is not a technical
guarantee that the agent cannot request tools.

`SkillConversationResult.status` values:

- `ready`: activation/prompt acknowledged; `session` is available. For authoring
  this does **not** prove generation completed or a skill was installed.
- `unsupported`, `invalidInput`, `changed`: unavailable/invalid input or stale
  connection. If `session` exists, keep it in its original location and let the
  person find it there; do not navigate in a newly selected profile.
- `alreadyStarted`: this controller has already started one action; no second
  session or request is made.
- `creationUncertain`: creation threw; a server session may nevertheless exist.
  Refresh the original inventory before offering another explicit action.
- `activationUncertain`, `promptUncertain`: retain `session`, reconcile its
  context/messages, and do not blindly resend. No automatic rollback/delete.

No exception text is exposed. No local storage, preferences, migration or
deletion hook is added. Existing server session deletion handles these normal
sessions. Process-death recovery uses existing inventory/messages/context;
this service does not claim a durable multi-step transaction. Connection-owner
integration and UI localization remain work for the later UI/controller unit.

## Exact missing-server requests (proposals, not implemented endpoints)

The upstream server checkout is not present. The following names describe the
required routes/fields and responsible upstream subsystems, not verified
implementation filenames. Do not call these proposed endpoints.

| missing item | request / response needed | upstream placement |
|---|---|---|
| Tool provenance | Add nullable `source: {kind: "builtin"\|"mcp", server?: string}` to each V1 `ToolListItem` (GET `/experimental/tool?...`) and equivalent V2 catalog; MCP `server` must be exact inventory identity, not inferred from ID prefix | Tool registry/catalog serializer where MCP tools are registered |
| V2 tool enablement + effective readback | Proposed PATCH `/api/config/tools/{toolID}` with `{enabled:boolean,scope:"project"\|"global",location:{directory,workspace?}}` -> `{id,enabled,effectiveEnabled,scope}`; inventory should also report `effectiveEnabled` (V1 needs this field too). Define config/permission precedence | Tool configuration writer, resolution layer and inventory serializer |
| Persistent MCP deletion | Proposed DELETE `/config/mcp/{name}?scope=project\|global&directory=...` (V1), DELETE `/api/config/mcp/{server}?scope=project\|global&location[directory]=...` (V2), no body -> 204; 404 absent entry. Define target file, inheritance and runtime reconciliation | Configuration mutation/merge layer and MCP config routes |
| Lossless runtime Remove undo | Proposed POST `/api/mcp/{server}/remove` `{allowUndo:true}` -> `{undoToken,expiresAt}`; POST `/api/mcp/{server}/restore` `{undoToken}` -> 204; 409 name collision, 410 expired. Keep exact configuration and credentials server-side, scoped to caller/location | MCP runtime registry and removal/restore routes |
| Established OAuth expiry | Add `auth:{state:"valid"\|"expired"\|"needs_auth"\|"unknown",expiresAt?:ISO8601,refreshable:boolean}` to MCP inventory; add `mcp.auth.changed {server,state,expiresAt?}`. Never expose tokens | MCP OAuth credential/refresh service, status serializer and event schema |
| Expiry reconnect | Alongside expiry signal, proposed POST `/api/mcp/{server}/auth/refresh` `{}` -> `{state:"connected"\|"needs_auth",expiresAt?:ISO8601}`; define noninteractive refresh/reconnect and bounded retry semantics | MCP OAuth refresh service and runtime reconnect lifecycle |
| Provider key page | Nullable HTTPS `keyPageUrl` on V1 API `ProviderAuthMethod`, returned by GET `/provider/auth`, and V2 `Integration.KeyMethod`, returned in existing GET `/api/integration[/{id}]` discovery; no request body | Authoritative provider/integration metadata registry, discovery schema and serializer |
| V1 session skill activation | Proposed POST `/session/{sessionID}/skill` `{skill:string,resume:boolean}` -> 204; stable skill ID in inventory and an activation event/context row; V2 already has these | Session skill resolver, activation route and context/event persistence |

No dedicated skill-authoring endpoint is missing for requesting a draft through
normal prompting. Actual installation would require separately defined and
verified permission/file-write behavior; it is outside this action.

## Evidence

- V1 `contracts/opencode-openapi-f12e14cf.json`: Config tools at line 21475,
  enabled-only MCP union around 21345; ToolListItem at 21912 lacks source or
  enabled state; Provider at 21836 and ProviderAuthMethod at 22913 lack key URLs.
  MCP configuration values do not allow null, and no named configuration-delete
  endpoint exists. PATCH `/config` and `/global/config` already exist in the SDK.
- V2 `contracts/opencode2-openapi-beta-18600.json` (one-line snapshot): JSON
  pointers `#/components/schemas/Provider.Info`, `Integration.KeyMethod`,
  `Mcp.Status.*`; paths `/api/session`, `/api/session/{sessionID}/skill`,
  `/api/session/{sessionID}/prompt`, `/api/mcp/{server}`. MCP DELETE is runtime
  only; it returns no restoration handle. Untyped integration `metadata` does
  not establish provisioning-URL semantics.
- `docs/opencode2-protocol-notes.md:306` documents session skill activation;
  `:450–476` cover catalogs, no config-write endpoint, runtime MCP CRUD,
  integration key/OAuth methods. Authentication-attempt `expired` is not
  established MCP token expiry.
- `lib/api2/gateway_operations.dart:120` already implements skill activation
  and runtime unsupported detection; `:1275` implements runtime MCP add.
  `lib/api2/gateway.dart:241` already creates sessions; `:371` prompts.
- `lib/domain/server_gateway.dart:471` tool fields and `:490` MCP inventory lack
  source/config snapshots. The MCP draft at `:502` omits OAuth configuration and
  other runtime fields, so re-adding a reconstructed draft is not lossless undo.
  `:999`, `:1031`, `:1335–1358` expose creation, prompting, catalog, MCP add/remove.

## Verification and state

- Implemented: companion domain/API/state slice and focused tests; partial
  product integration by design. Missing-contract items remain disabled.
- Enabled: no new UI/controller wiring. Optional adapters must be installed by
  the integration owner before their capabilities become available.
- Verified: source/contract review and pinned Dart formatting only. The
  formatter warns that `package:flutter_lints/flutter.yaml` cannot resolve;
  `.dart_tool/package_config.json` is absent. No package files were generated.
- Flutter tests/analyzer/builds: **not run**, per the user's explicit instruction
  that this unit cannot run Flutter. No runtime/compilation pass is claimed.
- Deployed/released/pushed: no.

Verifier commands (pinned Flutter after resolving packages in the verifier's
environment; run files serially):

```bash
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter test --concurrency=1 test/sv3_tool_test.dart
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter test --concurrency=1 test/sv3_mcp_test.dart
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter test --concurrency=1 test/sv3_skill_conversation_test.dart
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter analyze
```

Tests cover narrow authenticated config request bodies/scope, unavailable
capabilities, rejected identifiers, safe errors, runtime disconnect, exact skill
activation without resume, unsupported/missing IDs, location changes, duplicate
suppression, uncertain create/activate/prompt results, and redaction.

Contract problems: the request asks for additive gateway/capability methods but
also explicitly excludes editing the shared gateway file. Companion interfaces
and extensions satisfy the backend handoff without changing protected files;
the owner must perform construction/wiring. The existing supplied branch is
retained. Full product enablement remains blocked on that later integration and
the stated server gaps; local checks cannot substitute for it.
