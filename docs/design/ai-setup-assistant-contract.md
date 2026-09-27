# AI setup assistant: frontend contract (2026-09-27)

Status: **backend inspection, proposal review, local guided planning and optional
registry browsing implemented; production mutations and server AI sessions blocked**.
This is not a completed AI configuration feature. No UI is wired in this slice.

The single entry page has two paths: **Set up by hand** and **Ask the setup
assistant**. Both lead to the same review model. In this revision the second
path must explain that server AI is unavailable and offer **Guided setup (on
this device)**. That mode uses structured choices, ignores free-form questions,
and does not call a model. Do not market it as an AI agent.

## Capability contract

Gate on `ServerCapabilities` plus the selected `SetupConfigGateway.support`,
never a UI flavor switch. New flags default false, including for Codex and
Claude Code via Paseo. An integration/composition owner creates the concrete
adapter; UI imports domain/state only. Flags describe availability, not current
connectivity. No server or provider credentials are required by UI adapters.

| Capability | OC1 | OC2 captured beta/current adapter | Codex | Claude Code via Paseo |
|---|---|---|---|---|
| `setupConfigRead` | true; effective config | true; ordered sources | false | false |
| `setupMcpInventory` | true | true | false | false |
| `setupConfigWrite` | false | false | false | false |
| `setupAssistantSession` | false | false | false | false |
| Local structured planner | available | available as OC1-format candidate only | available as OC1-format candidate only | available as OC1-format candidate only |
| Public registry | optional, independent of server, off by default | same | same | same |

`SetupSupport` fields are `readConfig`, `writeConfig`, `mcpInventory`,
`assistant`, `reason`. `writeConfig` requires verified reversible writes, not
merely PATCH support. All shipped adapters return false. The planner's OC1
candidates are **not portable wire payloads** for OC2/Codex/Claude Code.

Required gap copy (localize these strings when building UI):

- OC1 Apply/Undo: “This server cannot safely restore configuration changes.
  Apply and Undo are unavailable.”
- OC2 Apply/Undo: “This server has no verified reversible configuration endpoint.
  Apply and Undo are unavailable.”
- OC2 effective diff: “This server returns layered sources. Effective-config
  diffs are unavailable.” The controller refuses to invent a before value.
- Codex/Paseo: “This server does not expose setup configuration APIs.” Keep the
  inspection and mutation actions unavailable; do not construct an OC adapter.
- Server assistant: “A proposal-only AI session is not verified on this server.
  Use Guided setup (on this device) or Set up by hand.”
- Credentials: “Use the existing sign-in or secret entry flow for credentials.”
- Runtime MCP operations: “Runtime MCP controls do not provide reversible
  configuration changes. Use the existing MCP management page.”
- Package install: “Package installation needs a reviewed command on your
  server. Set it up by hand.” This is guidance, not an install action.

## UI-facing controller and values

Import `lib/state/setup_controller.dart` and `lib/domain/setup_assistant.dart`.

`SetupController({required SetupConfigGateway gateway, required SharedPreferences
prefs, required String profileId, required String locationId})` is bound to one
profile and one selected location. Subscribe to `changes` and immediately read
`snapshot` (broadcast streams do not replay). Read `support` for capability copy.
The composition owner must recreate and await disposal when changing profile,
server or location; borrowed transport location must remain unchanged throughout
an operation. Dispose before the existing profile deletion sweep.

| Public API | Behavior |
|---|---|
| `SetupSnapshot get snapshot` | Current safe immutable state |
| `Stream<SetupSnapshot> get changes` | Subsequent state updates |
| `SetupSupport get support` | Adapter capabilities and gap reason |
| `void setOnline(bool online)` | Disable writes/refresh while offline; never queues writes |
| `Future<void> refresh()` | Fetch config and installed MCP status; invalidates the displayed proposal |
| `List<String> validate(List<SetupEdit> edits)` | Local bounds, path, basic shape and credential checks; **not** full server schema or execution validation |
| `Future<SetupProposal> propose(List<SetupEdit> edits)` | Requires a successful effective-config read; records proposal metadata and produces redacted diffs; no mutation |
| `Future<void> apply(String proposalId, {required bool confirmed})` | Exact current proposal and explicit confirmation; current production adapters return unsupported without a write |
| `Future<void> undo({required bool confirmed})` | Current controller's last verified change only; production adapters return unsupported |
| `List<Map<String,Object?>> get audit` | Bounded metadata records with `id`, `action`, UTC `at`; no values/prompts/configs |
| `String get auditKey` | `oc.setupAudit.<profileId>`; integration/testing only |
| `Future<void> dispose()` | Stop use, drain active operation, clear in-memory config/Undo/snapshot and close stream |

`profileId`, `locationId`, `gateway`, and `prefs` are construction bindings,
not UI actions. Do not call the raw gateway from widgets.

`SetupSnapshot` contains `phase`, `config`, `servers`, `proposal`, `reason`,
`canUndo`. `config` is redacted recursively with KitRedact and structural masking
of environment, headers, credential/options, prompt/system/command/template
bodies. OC2 returns `{'sources': [...]}` preserving source order; show source
inspection, not a guessed merged config. No raw config is persisted.

`SetupPhase` is `idle`, `loading`, `ready`, `empty`, `offline`, `unsupported`,
`needsSignIn`, or `error`. `empty` means config and inventory both empty, not a
failed fetch. Offline may retain previously fetched safe data. On reconnection,
call `refresh()` explicitly; do not replay lost OC2 events or retry writes.
401/403 yields “Sign in to this server to inspect setup.” `error` carries fixed
safe copy. Never render raw transport exceptions or response bodies.

`SetupMcpStatus` has `name` and normalized `status`: `connected`, `pending`,
`disabled`, `failed`, `needs_auth`, `needs_client_registration`, or `unknown`
where supported. A status does not prove durable installation. Show
“Needs sign-in” for `needs_auth`, “Client registration needed” for
`needs_client_registration`, and “Status unavailable” for `unknown`.

`SetupFailure` is typed by `SetupFailureCode`: `offline`, `unsupported`,
`needsSignIn`, `invalid`, `conflict`, `storage`, `transport`, `busy`, `uncertain`.
Its `message` is application-owned safe copy; `toString()` gives only a code.
`busy` also covers use after disposal. Avoid concurrent controller calls.

## Review, Apply, Undo and confirmations

`SetupEdit({required List<String> path, Object? value, bool remove=false})` is an
input object; do not render it directly. Segment paths avoid JSON-pointer
escaping ambiguity. Edits are copied before use. Proposals allow 1–32 distinct,
non-overlapping paths and bounded non-secret JSON. Models/default agents require
nonempty strings; simple permission rules require allow/ask/deny; new MCP
objects must specify local/remote and start disabled. Credential-bearing fields
must go through existing secret entry/sign-in, never assistant chat.

`SetupProposal` has `id`, immutable `changes`, `canApply`, optional `reason`,
and `effect`. Each `SetupDiff` has immutable `path`, redacted `before`, redacted
`after`, `remove`. Null before means absent only for effective config; OC2
layered-source diff creation is refused. Masked command bodies cannot be treated
as fully reviewed executable commands. No production write is enabled here.

Display the selected server/location, proposed changes, scope, capability reason
and activation uncertainty. `effect` says “Runtime activation is not verified.
Recheck server status after a change.” A registry toggle selects a **proposal**;
it must not change the installed/connected visual state. Confirm Apply only
when `canApply` is true; pass the current proposal ID. Cancel closes review and
sends no mutation. Do not pass `confirmed:true` merely because a toggle changed.

The coordinator's reusable mutation path is tested against an in-memory fake
only: fresh whole-config comparison, pending audit before write, single patch,
read-back verification, then verified audit and memory-only inverse. It supports
only replacing existing non-null non-map values; addition/removal/object edits
remain proposal-only. Changed config prevents Apply/Undo; ambiguous outcomes
become `uncertain` and invalidate retry/Undo until refresh. Audit failure before
write prevents mutation; audit failure after write reports uncertainty. **The
read/compare/write sequence is not an atomic compare-and-swap. Do not enable a
production adapter until the server provides concurrency/reversibility guarantees
and those are implemented in the gateway contract.** Undo does not survive an
app restart, and restoring an effective value is not restoring source-file
provenance. There is no claim of persistent Undo or atomic rollback.

## Guided assistant API

Import `lib/domain/setup_planner.dart`. Create a profile-scoped `SetupPlanner()`.

- `start({required SetupIntent intent, String? question,
  Map<String,Object?> inputs=const {}})` starts a memory-only session.
- `continueSession({required String sessionId, String? question,
  Map<String,Object?> inputs=const {}})` accepts additional structured fields.
- `closeSession(String sessionId)` forgets one; `dispose()` forgets all.

Returns `SetupPlannerReply`: `sessionId`, `state`, safe `guidance`,
`requiredInputs`, immutable `edits`. States: `needsInput`, `proposed`,
`unsupported`. Eight sessions maximum, oldest discarded on ninth. Questions are
ignored and never retained. Inputs are credential-checked; no tool or request
executes. Pass proposed edits to `controller.propose` only when effective config
is available. On unsupported servers show the guidance and capability gap.

| Intent | Input keys | Result |
|---|---|---|
| `chooseModel` | `model` as provider/model | OC1 model candidate |
| `defaultAgent` | `agent` | Existing-agent name candidate |
| `permission` | `tool`, `effect` | Simple OC1 permission candidate |
| `connectRemoteMcp` | `name`, `url` | Disabled OC1 remote MCP candidate |
| `addLocalMcp` | `name`, `command` string list | Disabled OC1 local MCP candidate; no execution |
| `removeMcp` | `name` | Removal candidate; never applicable in this revision |
| `configureProvider` | none | Unsupported; use secure sign-in |
| `configureAgent` / `configureCommand` | none | Unsupported; server tools required |

The dedicated future system prompt, narrow tools and enforced-permission
prerequisites are in [assistant feasibility](../qa/codex-ai-setup-2026-09-27/assistant-feasibility.md).
No ordinary chat session is started as a workaround.

## Optional registry API and privacy

Import `lib/state/setup_registry_store.dart`; value types are in
`lib/domain/setup_registry.dart`. `SetupRegistryStore(prefs,
{required String profileId, SetupRegistryClient? client})` is profile scoped.
Read `snapshot`, subscribe to `changes`, call `load()` once (cache only).
`setOptIn(bool)` changes consent without fetching; `refresh({bool online=true})`
fetches only with consent and online state; pass known offline state explicitly.
`clear()` removes consent/cache. Await `dispose()` before profile deletion.
`storageKey` is `oc.setupRegistry.<profileId>`.

`SetupRegistrySnapshot` has `status` (`disabled`, `loading`, `ready`, `empty`,
`offline`, `error`), `optedIn`, immutable `entries`, `cachedAt`, and safe `reason`.
Errors retain cache. `ready` may be cached; show its timestamp. Consent copy:
“Browse the public MCP registry from this phone. This contacts
registry.modelcontextprotocol.io. Your server configuration and credentials are
not sent.” Default is off, with no public internet request on construction,
load, opt-in, local guidance, or config inspection. Opt-out prevents future
fetches; cached safe listings can remain until Clear/profile deletion.

`RegistryEntry` exposes `id`, `name`, `version`, `description`, immutable
`remotes`/`packages`, `connectableRemote`, `unsupportedReason`.
`RegistryRemote` exposes `type`, `url`, `requiresConfiguration`, and
`toMcpConfig()` returning a disabled OC1 candidate. Never auto-select/execute a
listing. `RegistryPackage` exposes only `registryType`, `identifier`, `version`;
no command/download is generated. `fromJson`/`toJson` on these types are
serialization helpers, not needed by widgets. A URL is untrusted; any UI open
must use `openExternalLink`. This backend never follows listing URLs.

`SetupRegistryClient({HttpClientAdapter? adapter})` is an integration/testing
API using a dedicated unauthenticated transport. `fetch({CancelToken? cancelToken})`
is **not** the UI consent boundary: widgets use the store. `dispose()` closes
the owned transport. `SetupRegistryException.message` is fixed safe copy.
The first page is bounded to 100 latest-version rows and 512 KiB; no pagination
or remote search yet. Label “Limited public catalog”; do not imply completeness.
Listings are discovery metadata, not a trust/security endorsement. Headers and
variable requirements are dropped and disable automatic candidate conversion.

## Pages for the UI builder

1. Setup landing page: selected server/location, two paths, capability/offline
   explanation, installed MCP statuses and existing sign-in entry points.
2. Manual setup page: model/default-agent/simple-permission forms, local/remote
   MCP details; unsupported provider/agent/command editing explanations.
3. Assistant page: server AI gap, explicit guided-mode choice, structured intent
   and fields, safe reply states; never pretend free-form questions are answered.
4. Registry browse page: consent, refresh, saved timestamp, limited-catalog
   label, discovery rows and proposal toggles. Empty/error/offline states retain
   manual setup. A listing is not an installed server.
5. Review page: typed diff, masked values, selected scope, effect uncertainty,
   capability reason, cancel/confirm and clear outcome/unknown states.
6. Setup history page: proposal/pending/verified/uncertain audit metadata and
   current-session Undo availability; no credential values or historical configs.

All parts belong to the kit; localize presentation copy in English/Arabic and
keep config identifiers/paths/URLs LTR. No UI implementation is included here.

## Missing-server-feature list and research

- OC1: PATCH exists but no verified source-level snapshot restoration, deletion
  semantics or atomic revision precondition; no full reversible config workflow.
- OC2 pinned beta: no config-write endpoint; config reads are layered entries;
  runtime MCP mutations do not persist or provide reversible credential state.
- OC1 assistant: session permission/system/tool/structured-output fields exist,
  but a live deny-all-plus-StructuredOutput enforcement test is missing.
- OC2 assistant: pinned session contract lacks per-session deny/system/structured
  output controls needed for a safe proposal-only agent.
- Codex and Claude Code/Paseo: no verified setup config inspection/transaction
  adapters. Session/chat support is not setup capability.
- Provider secrets, OAuth lifecycle restoration, general agent/command editing,
  package execution and setting-specific restart/reload verification are not
  implemented. Existing sign-in and runtime MCP surfaces remain separate.

Read [server research](../qa/codex-ai-setup-2026-09-27/server-research.md),
[registry research](../qa/codex-ai-setup-2026-09-27/registry-notes.md) and
[QA evidence](../qa/codex-ai-setup-2026-09-27/README.md). Official sources and
version-drift qualifications are linked there. No writes to a live server were
performed during this slice.
