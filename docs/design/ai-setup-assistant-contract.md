# AI setup assistant: backend and UI contract (2026-09-28)

Status: **inspection, review, guided planning, audit ownership and a conditional
transaction coordinator implemented; production Apply/Undo/MCP mutations and
actual AI sessions remain unavailable**. No UI entry point is wired. Tests with
an atomic fake verify the coordinator; they do not establish a deployed server
transaction capability.

Rechecked the exact OpenCode 1 **1.18.32** and OpenCode 2 **2.0.10** source tags,
including SV3's companion configuration APIs. OC2 now has a shell-only global
PATCH and per-session permission rules, correcting the older beta-based claims.
It still lacks the source-bound conditional mutation/restore needed here, and
its AI session loads ambient context. See [pinned evidence and exact missing
contracts](../qa/codex-ai-setup-2026-09-28/pinned-runtime-recheck.md).

The single entry page has **Set up by hand** and **Ask the setup assistant**.
The latter currently explains the server-AI gap and offers **Guided setup (on
this device)**. This structured planner ignores free-form questions and calls
no model. Do not present it as a running AI agent or an enabled Apply workflow.

## Capability and refusal contract

UI imports domain/state only, never protocol adapters, and gates on support
and the current proposal rather than flavor. The composition owner supplies
the existing authenticated adapter. No new credential or shell path is used.

| Support | OC1 1.18.32 | OC2 2.0.10 | Codex / Claude Code via Paseo |
| --- | --- | --- | --- |
| Config inspection | Effective merged config | Ordered sources; do not invent an effective merge | No verified setup adapter |
| MCP inventory | Available | Available; stable route/envelope covered by fake transport tests | Unavailable in this setup facet |
| Config Apply/Undo | Unavailable: no conditional source snapshot/restore | Unavailable: shell-only global patch, no conditional source snapshot/restore | Unavailable |
| Reviewed MCP config add/remove | Unavailable | Unavailable; experimental runtime controls are not durable config transactions | Unavailable |
| Actual assistant session | Unavailable pending restricted-session verification | Deny rules exist, but sanitized-only context/typed setup session is not verified | Unavailable |
| Structured local planner / opt-in registry | Existing guided planner and registry remain usable independently; their candidates use OC1 vocabulary | Same; no automatic conversion into V2 payloads | Same; no guessed adapter |

`SetupSupport` retains `readConfig`, `writeConfig`, `mcpInventory`, `assistant`
and safe `reason`. A write flag alone is insufficient: the controller requires
`SetupTransactionalConfigGateway`. Legacy `SetupConfigGateway.patchConfig`
is never used by the reviewed Apply/Undo executor. Both shipped adapters keep
writes and assistant sessions false; SV3's acknowledged one-field PATCH and
runtime disconnect helpers must not be injected as a transaction gateway.

Copy intents, to localize in `app_en.arb` when building the kit screens:

- OC1: the server can read setup but cannot restore the exact source safely;
  Apply and Undo are unavailable.
- OC2: the shell-only global update cannot apply these proposals or protect
  them against other edits. Its runtime MCP controls cannot restore prior state.
- Layered read: source inspection is available, effective-config diffs are not.
- Actual AI: a setup session restricted to approved sanitized context is not
  verified. Offer guided choices or manual setup; do not claim OC2 lacks all
  per-session permission controls.
- Credentials: use existing sign-in or secret-entry flows, never a proposal,
  model question, arbitrary header/environment field or audit value.
- Local MCP/package commands: their executable bodies need a separate complete
  review contract. A masked command is not a fully reviewed command.
- Codex/Paseo: no verified setup configuration adapter; keep these actions off.

## UI-facing controller and scope ownership

Import `lib/state/setup_controller.dart` and `lib/domain/setup_assistant.dart`.
Construct `SetupController(gateway: ..., prefs: ..., profileId: ...,
locationId: ..., isCurrent: ...)` outside the UI. `isCurrent` must compare the
captured profile, location generation and gateway identity, including an
away-and-back selection change. Its default exists for isolated callers/tests;
it does not replace application ownership checks. Subscribe to `changes`, then
read `snapshot` immediately (the broadcast stream does not replay).

The profile must already exist in `ProfileStore`. Recreate and await disposal
when changing profile/server/location. Both shipped adapters now capture their
location at construction; subsequent changes to the borrowed client's selected
directory/workspace do not retarget setup reads. They borrow credentials and
transport lifetime, and never close the shared client.

| API | Behavior |
| --- | --- |
| `snapshot`, `changes`, `support` | Immutable redacted presentation and capability/reason data |
| `setOnline(bool)` | No queued mutations or automatic retry; offline never becomes a later false ready state |
| `refresh()` | Config/source and MCP inspection; invalidates displayed proposal; no mutation |
| `validate(edits)` | Bounded input/credential/path/shape validation, not server-schema or execution proof |
| `propose(edits)` | Copy edits, produce redacted review and metadata audit; writes nothing to the host |
| `apply(proposalId, confirmed: true)` | Exact current proposal and explicit review confirmation, conditional transaction only |
| `undo(confirmed: true)` | Last verified memory-only transaction, conditional exact restore through host handle |
| `audit`, `auditKey` | Bounded metadata-only history; `oc.setupAudit.<profileId>` |
| `dispose()` | Stop admission, drain in-flight work, clear raw snapshots/handles and close stream |

Never derive confirmation from a changed toggle. Show server/location, source
scope, concrete changes, availability reason and activation uncertainty before
calling Apply. A registry selection is a proposal, not installation/connection.
Leaving the page after a mutation starts does not cancel a remote mutation.

`SetupSnapshot` contains `phase`, redacted immutable `config`, normalized
`servers`, `proposal`, safe `reason`, and `canUndo`. `SetupMcpStatus` remains
name plus known status (connected/pending/disabled/failed/needs_auth/
needs_client_registration/unknown). Runtime status never proves durable install.

| Phase | UI meaning |
| --- | --- |
| `idle`, `loading` | Nothing fetched yet / inspection in progress |
| `ready`, `empty` | Read succeeded; empty means config and inventory are empty |
| `applying`, `undoing` | One confirmed operation pending; suppress duplicate admission |
| `verifying` | A receipt was received; independent snapshot verification is still pending |
| `uncertain` | Host outcome cannot be verified; no blind retry or automatic rollback; inspect/refetch |
| `offline`, `unsupported`, `needsSignIn`, `error` | Fixed safe reason, retained safe data where appropriate, no invented success |

`SetupFailureCode` remains `offline`, `unsupported`, `needsSignIn`, `invalid`,
`conflict`, `storage`, `transport`, `busy`, `uncertain`. `message` is authored
copy; `toString()` exposes only the code. UI maps codes to localized words and
shows only explicitly redacted technical context under Details. No raw exception,
configuration, URI, provider credential or restore handle belongs in the body,
notification, report or clipboard.

## Review data and exact transaction boundary

`SetupEdit(path: List<String>, value: ..., remove: bool)` is input only.
`SetupProposal` has `id`, immutable `changes`, `canApply`, optional `reason` and
`effect`. Show `SetupDiff`, never raw edits/snapshots. Proposal IDs are random
opaque per-attempt IDs, not counters reused across controller instances.
`SetupDiff.beforePresent` and `afterPresent` distinguish an absent setting from
a present JSON null; render removal as removal, never as the string "null".
Do not infer presence from the redacted `before`/`after` values alone.

Inputs remain bounded to 1–32 non-overlapping paths and non-secret JSON. Model
and default-agent choices must be nonempty; simple permissions use allow/ask/deny.
MCP additions start disabled. Provider/auth fields, general agent/command bodies
and arbitrary runtime MCP operations remain outside the executable subset.
Local MCP commands remain unavailable for Apply while their review is masked.
An atomic fake exercises disabled remote MCP definition add/remove and ordinary
config edits; that is coordinator coverage, not runtime installation support.

`setupRedact` structurally masks provider options, headers/environment, credentials
and executable/prompt bodies in addition to KitRedact. Redacted values must never
be sent back as replacement configuration. OC2's `sources` view remains
inspection-only: a guessed merge is not a source snapshot.

The optional **implemented domain facet** is a requirement on any future host
adapter, not a new HTTP endpoint the app calls today:

```dart
abstract interface class SetupTransactionalConfigGateway
    implements SetupConfigGateway {
  Future<SetupConfigRevision> readSnapshot();
  Future<SetupConfigCommit> commit({
    required SetupConfigRevision expected,
    required List<SetupEdit> edits,
    required String operationId,
  });
  Future<SetupConfigCommit> restore({
    required SetupConfigCommit commit,
    required String operationId,
  });
}
```

`SetupConfigRevision` holds immutable raw `targetId`, `revision`, and exact
source `config`. `SetupConfigCommit` holds `before`, `after`, and an opaque
`undoHandle`. These are controller/adapter-only, memory-only values; widgets
must never import them for display or persist them. Raw snapshot credential
fields are registered with KitRedact at trusted ingress before capture.

A conforming adapter must have a real source identity/revision and **atomic**
server-side expected-revision check. It commits all reviewed edits together,
preserves unrelated values, and returns the actual before/after source snapshots.
A conflict means no mutation. It must not implement this interface with
GET/PATCH/GET, a phone mutex, file access via an AI agent or reconstructed MCP
inventory. Sources include presence/absence and provenance; restoring an
effective old value is insufficient. New disabled definitions must not launch
processes, contact MCP endpoints or start OAuth. The host must retain all restore
material, including any credentials, behind the opaque handle.

The coordinator audits pending **before** dispatch; verifies the receipt's
before snapshot against its fresh read, target identity, new revision and exact
expected after contents; independently rereads; and only then records verified
and makes Undo eligible. Accepted/response-received is not verified. A revision
change conflicts even when values happen to compare equal.

Undo passes the original receipt/handle to the adapter, which must transmit the
opaque handle and after precondition, never resubmit credential-bearing snapshots.
It restores exactly the original source (including absent keys and nulls), then
the coordinator independently verifies the new receipt and readback. A changed
target/revision prevents restoration. Undo is one level and does not survive
restart. Runtime activation, OAuth, process state, external MCP effects and
package installation are not included or promised by this configuration contract.

Unknown transport outcome, bad receipt, mismatched readback or post-write audit
failure invalidates local retry/Undo eligibility. There is no automatic rollback.
Once sent, reconciliation remains bound to the original host even if the page
closes, but a stale/offline owner must not publish ready for the new selection.
A host must provide idempotent operation lookup before durable process-restart
retry can be added; this unit does not provide that capability.

## Audit ownership and deletion

`SetupAuditStore.forProfile(prefs, profileId)` supplies a shared serialized owner.
Its `records` are immutable, `isAvailable` checks profile/history admission, and
`append(id, action, operation: ...)` accepts only metadata. Actions are proposed,
pending, accepted, verified, rejected and uncertain; operation is review/apply/
undo when recorded. Historical id/action/UTC-at rows remain readable. No raw
location, server address, config, diff, prompt, snapshot or undo handle is stored.
History is capped at 100; corrupt/untrusted history refuses overwrite instead
of silently resetting it. A refused preference write reloads durable state.

`ProfileStore.removeScopedPreferences` now stops audit and default-owner admission
synchronously, drains pending writes, then discovers and removes scoped keys.
Absent/deleted profiles reject new writers; a new controller cannot reopen a
closed owner during the sweep. Compose/dispose the controller on selection and
delete as above. A deletion that reaches the sweep and then fails leaves this
owner closed until restart; do not reopen it inside a deletion transaction.
Local deletion does not cancel an already-sent server operation. No shared blob,
raw snapshot persistence or credential migration is introduced.

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
| `removeMcp` | `name` | Removal candidate; production unavailable; disabled definitions are covered only through the transaction fake |
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

## Remaining host features and current evidence

- OC1 exact source snapshots, revision preconditions, deletion semantics and
  conditional restore remain missing. SV3 narrow PATCH success is not Undo.
- OC2 stable supports only shell-setting global PATCH; it does not support the
  setup proposal fields or conditional exact restoration. Runtime MCP overrides
  do not supply durable config deletion, full readback or restore receipts.
- OC2 per-session deny rules are real. Restricted ambient context and the
  dedicated setup-session/output contract remain unverified; actual AI is off.
  OC1 likewise needs exact-runtime restricted-session verification.
- Codex/Paseo configuration, general executable/agent editing, OAuth lifecycle
  restore and package execution remain unsupported. Existing credential flows
  and MCP management actions stay separate.

See [2026-09-28 pinned-runtime recheck](../qa/codex-ai-setup-2026-09-28/pinned-runtime-recheck.md)
and [implementation/check results](../qa/codex-ai-setup-2026-09-28/README.md).
The [2026-09-27 record](../qa/codex-ai-setup-2026-09-27/README.md) remains historical;
its old beta claims are superseded where this recheck identifies changes.
