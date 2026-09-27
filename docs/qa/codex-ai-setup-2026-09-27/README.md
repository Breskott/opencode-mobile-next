# AI setup backend — 2026-09-27

**Partial, blocked for full feature delivery.** Config/MCP inspection, proposal
review, a local structured planner, safe audit metadata and opt-in registry
browsing are implemented. Production Apply/Undo/install/connect/remove and an
actual server AI session are unavailable following feasibility checks. No UI is
wired. See the [frontend contract](../../design/ai-setup-assistant-contract.md).

## Scope and finish line

Finish line established before editing: expose a redacted config inspection →
proposal/review → explicitly confirmed reversible apply/undo backend with audit
and a small documented UI API; leave unsupported server actions unavailable.
Non-goals: UI, native code, generated SDK changes, signing/releases, unrestricted
agent execution, live config mutation, public internet by default.

Current branch/worktree: `codex/aiset`, existing supplied checkout.
Starting revision: `23bce72dc50883113a993cca4ec7556f4a924781`.
Initial working tree was clean. Repository AGENTS.md and only STANDARDS.md
sections 2, 3, 13, 15 were read. No HANDOFF.md exists in this checkout.

Read set: server schemas/client/gateway/state/preferences, KitRedact, protocol
notes and official web references. Write set: new setup domain/state/adapter
files, four behavior test files, contract/research/QA docs, COMMIT_MSG.txt;
additive ServerCapabilities fields in `server_gateway.dart` and the OC2 mapper.
The later explicit permission for additive changes to that shared file was
used; no rename or existing behavior change. `connection.dart`, `main.dart`,
`product_repository.dart`, Android Kotlin, SDK and every `lib/ui/**` file stayed
untouched. KitRedact is imported read-only.

Three independent execution slices had exclusive ownership after freezing the
four-method `SetupConfigGateway` and `SetupEdit` contracts:

| Owner | Writes | Dependency / acceptance |
|---|---|---|
| Coordinator | Domain contract, controller, capability declarations, controller tests, main docs | Review states, no secret persistence, refusal/conflict/uncertainty/Undo behavior |
| Adapter worker | Two adapters, OC2 capability mapping, adapter tests, server research | Frozen gateway/types; authenticated reads, no unsafe writes, typed safe errors |
| Registry worker | Registry domain/store/tests/research | Existing prefs/Dio/redactor; no network without consent, bounded safe cache, deletion/race checks |
| Planner worker | Local planner/tests/feasibility record | Frozen edits; structured proposal-only sessions, no network/execution/LLM claims |

Workers formatted their files; only the coordinator launched Flutter. The
planner worker also did a read-only controller review. Resulting offline-refresh
race and basic-shape validation findings were fixed and regression-tested.

## Feasibility decisions and missing work

See [server research](server-research.md) and
[assistant feasibility](assistant-feasibility.md) for pinned schema/source links.

- OC1 has GET/PATCH config, but a layered effective read plus deep-merge PATCH
  cannot prove source restoration, deletion or an atomic revision precondition.
  Therefore its setup adapter refuses writes. The reusable coordinator mutation
  path is tested only with a fake; it is not production-enabled or atomic CAS.
- OC2 beta returns ordered config sources and has no config-write route. Current
  upstream V2 has evolved; no new write contract was inferred from newer docs.
  Runtime MCP add/remove/connect are not reversible durable configuration.
- OC1 has system/tools/structured output and session permission fields, but
  deny-all-plus-StructuredOutput enforcement for a safe setup agent was not
  verified live. OC2 lacks the pinned equivalent per-session controls. No
  general chat or shell workaround was added.
- Codex and Claude Code via Paseo have no verified setup adapter. New flags
  default false. Provider secret entry, general agents/commands editing,
  package installation and reload/restart proof remain missing.
- The local planner's questions are ignored; it uses explicit intents and
  structured fields. It is **not an AI model**. Its typed edits use OC1 vocabulary
  and must never be sent blindly to another backend.

These feasibility failures stop those slices as requested. The frontend must
not turn flags on to make controls look usable. This branch is not a completed
AI setup assistant and is not recommended as an enabled end-user feature.

## UI hook-up

The exhaustive public API/state/copy/page inventory is in
[ai-setup-assistant-contract.md](../../design/ai-setup-assistant-contract.md).
The composition/integration owner, outside `lib/ui`, constructs:

- OC1: `OpenCode1SetupConfigGateway(api: existingOpenCodeApi)`.
- OC2: `OpenCode2SetupConfigGateway(client: existingApi2Client)`.
- `SetupController(gateway: adapter, prefs: prefs, profileId: id,
  locationId: selectedLocation)`; subscribe to `changes`, read `snapshot`, then
  `refresh()`. Preserve transport location for the controller lifetime.
- `SetupPlanner()` per profile; `start`/`continueSession` return proposed
  `SetupEdit`s. On OC1 pass them to `controller.propose`; render only the
  resulting redacted `SetupDiff`s. OC2 source-only config cannot produce a
  truthful effective before/after, so the controller refuses that diff.
- `SetupRegistryStore(prefs, profileId: id)`; `load()` reads cache only.
  `setOptIn(true)` does not fetch. An explicit `refresh(online: knownOnline)`
  fetches a limited official catalog. A selected remote can produce a disabled
  candidate; toggles are proposal selections, never installation status.

Await both controller/store `dispose()` and clear planner sessions before
profile/location changes or profile deletion. Persistence uses only
`oc.setupAudit.<profileId>` and `oc.setupRegistry.<profileId>`; the existing
`ProfileStore.profileScopedPreferenceKeys`/`removeScopedPreferences` sweep
already covers both, verified in behavior tests. No shared blob was added, so
`ConnectionController.deleteProfileAndLocalData` needs no extension. Do not
retain these objects after deletion; there is no composition hook in this slice.

Audit records contain bounded metadata only; config, prompts, diffs, secrets
and inverse snapshots are never persisted. Undo exists only for the current
in-memory verified fake-capable transaction. On restart show no Undo action.

## Registry research and offline behavior

The [official registry API](https://github.com/modelcontextprotocol/registry/blob/main/docs/reference/api/official-registry-api.md)
provides public server metadata. The implemented client uses a fixed
unauthenticated `/v0.1/servers` origin with redirects disabled, 100-row/512-KiB
bounds, safe metadata only and no execution/download/follow-up endpoint calls.
Detailed feasibility, cache races and a research-time HTTP 200 shape check are
recorded in [registry notes](registry-notes.md). No app credentials/config are
sent to the registry. Offline/manual server use never depends on it.

Alternatives were researched but not integrated:
[Glama's own directory page](https://glama.ai/mcp/servers/AgentModule/mcp)
provides a per-server directory API example under `/api/mcp/v1/servers/...`;
that is not evidence of a compatible complete-list API, SLA or trust contract.
[GitHub's registry documentation](https://docs.github.com/en/copilot/how-tos/administer-copilot/manage-mcp-usage/configure-mcp-registry)
describes organization/enterprise registry configuration. It is not evidence
that authenticated enterprise discovery should be enabled on a phone by
default. Alternate hosts would need separate opt-in, schema/authentication and
privacy checks. No alternate adapter or automatic fallback was built.

## Checks and evidence

Pinned Flutter was available despite the expected environment limitation:
Flutter 3.47.1, framework `91f8bd7507`, Dart 3.13.1. `flutter pub get` succeeded;
no dependency or generated-localization file changes are included.

Commands (binary prefix throughout:
`~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/`):

```text
dart format --language-version=3.10 <13 changed Dart files>
flutter test --no-pub --concurrency=1 test/setup_controller_test.dart test/setup_config_adapter_test.dart test/setup_planner_test.dart test/setup_registry_test.dart
flutter analyze --no-pub lib test
git diff --check
```

Results are recorded in the final evidence files below (terminal trailing
whitespace removed for repository hygiene). Earlier attempts are
retained separately and never combined into a final pass:

- `focused-tests.txt`: initial 39 passes; registry compile failed on an undefined
  deadline and incorrect static ProfileStore.load call. Both corrected.
- `controller-tests.txt`: 14 controller tests passed after offline/source/shape
  review fixes.
- `final-focused-tests.txt`: pre-final attempt; 57 passed and one registry race
  test failed because cancellation happened before the fake transport started.
  Replaced timing assumptions with an explicit request-entry completer.
- `analyze.txt`: first whole-lib/test analysis, zero errors/warnings but 29 infos
  in new files; corrected rather than suppressed.
- Final checks: **60 focused tests passed** on the Dart-file hashes in
  `verification-candidate.json`; final whole-lib/test analysis reported **no issues**.
  See `verification-tests.txt`, `verification-analyze.txt`,
  `format.txt`, and `verification-diff.txt` (populated before commit).

Behavior evidence covers config/status redaction, authenticated request scopes,
401/403/offline/malformed errors, typed review without writes, explicit
confirmation, stale-config rejection, Undo conflicts, unknown outcomes, profile
isolation/deletion, offline/reconnect behavior, capability defaults, planner
input validation/unsupported intents, registry consent/cache/bounds/redaction,
and cancellation/persistence races. No full suite, emulator, screenshot,
Android build, live setup writes or live restricted assistant test was run.

## Shipping state

| State | Result |
|---|---|
| Implemented | Partial backend: inspection/review/guided planner/registry; production mutation and AI session slices blocked |
| Enabled | No UI entry point; registry internet off by default; all production config-write/AI-session flags false |
| Verified | Focused behavior and whole-lib/test analyzer evidence only; see final logs |
| Committed | Local commit requested; final response reports resulting hash |
| Deployed / released | No; no push, PR, CI, signing, APK, tag or release |

Privacy: KitRedact plus structural masking, fixed safe errors and metadata-only
audit; no populated credential files or raw server config artifacts. Migration:
new profile-scoped registry JSON is version 1, invalid cache is ignored/refused;
new audit is a bounded metadata list. Accessibility/localization: no UI changed;
frontend requirements are documented, not runtime-verified.
