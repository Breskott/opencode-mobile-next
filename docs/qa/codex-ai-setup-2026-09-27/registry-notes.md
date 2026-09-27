# Optional registry backend

Finish line: after explicit per-profile consent, a manual refresh yields a bounded, redacted catalog that survives restart, remains browsable offline, and is deleted with the profile.

Non-goals: installing packages, running registry-provided commands, contacting listed MCP endpoints, automatic background fetches, arbitrary catalog hosts, registry-derived trust or OAuth claims.

Ownership: `lib/domain/setup_registry.dart`, `lib/state/setup_registry_store.dart`, `test/setup_registry_test.dart`, this record. Dependencies: existing Dio, SharedPreferences, KitRedact and ProfileStore preference sweep. Acceptance: zero default internet requests; explicit consent and refresh; cache isolation/deletion; no secrets or executable arguments retained; reviewed disabled remote candidate only. The coordinator owns all integration and test execution.

## Research and feasibility

The [official aggregator guide](https://github.com/modelcontextprotocol/registry/blob/main/docs/modelcontextprotocol-io/registry-aggregators.mdx) documents unauthenticated GET `/v0.1/servers`, cursor pagination, and the possibility of registry outages/data changes. The API is metadata discovery rather than a package executor. The [official OpenAPI](https://raw.githubusercontent.com/modelcontextprotocol/registry/main/docs/reference/api/openapi.yaml) defines `limit`, `version=latest`, `servers[].server`, remote transports, and package identifiers. We retain only a small allowlisted projection and discard arguments, environment values, headers, custom metadata and package download links. No registry authentication or API key is needed.

On 2026-09-27 a researcher GET to `https://registry.modelcontextprotocol.io/v0.1/servers?limit=1&version=latest` returned HTTP 200, 654 bytes, top-level `servers`/`metadata`, one record containing `server`/`_meta`. No entry payload, header or credential was printed. The web reader could not open this endpoint; a bounded Python HTTPS request verified the callable shape instead. This verifies registry availability at research time, not application runtime or MCP endpoint compatibility.

Only the official public registry is implemented. Other registries/aggregators may use the [same open specification](https://github.com/modelcontextprotocol/registry/blob/main/docs/modelcontextprotocol-io/registry-aggregators.mdx), but arbitrary hosts and their independent authentication/trust policies are outside this client. The main research record covers alternative providers.

## UI hook-up

Use `SetupRegistryStore(prefs, profileId: id)` as the only UI-facing registry entry point. Constructing it, `load()`, and `setOptIn(true)` do not fetch anything. Read `snapshot`, subscribe to `changes`, and call `load()` once. `snapshot` has `status`, `optedIn`, immutable `entries`, `cachedAt`, and optional fixed safe `reason`. Status values are `disabled`, `loading`, `ready`, `empty`, `offline`, and `error`.

Explain that enabling browsing contacts `registry.modelcontextprotocol.io` from the phone; a saved catalog is optional and is not evidence a listed server is installed or connected. Call `setOptIn(bool)` only after the user changes that preference. Call `refresh(online: connectivityKnownOnline)` only after an explicit refresh action; the default argument is true, so pass known offline state. Errors retain any cached entries. Do not present `ready` or the presence of an endpoint as an installed status. Show `cachedAt` and label cached listings when offline.

`RegistryEntry` exposes `id`, `name`, `version`, `description`, `remotes`, `packages`, `connectableRemote`, and `unsupportedReason`. `RegistryRemote` exposes `type`, `url`, and `requiresConfiguration`. After explicit selection, `toMcpConfig()` returns `{type: remote, url: ..., enabled: false}` for the separate setup controller to validate/propose; it does not apply or connect. Remote declarations with required/custom headers or variable declarations are not automatically connectable. The metadata does not reliably establish OAuth readiness. Show “This server needs connection details. Set it up by hand.”

Only `https` endpoints with no user-info, query, fragment, template variable, recognized secret or whitespace are accepted. Registry text is passed through KitRedact. No returned URL is opened or fetched here. If the frontend offers opening a URL, it must use `openExternalLink`.

Package fields are `registryType`, `identifier`, and `version`; these are informational only. Package-only entries expose “Package installation needs a reviewed command on your server. Set it up by hand.” Entries without a supported endpoint expose “This listing has no supported HTTPS endpoint. Set it up by hand.” Nothing synthesizes shell commands or performs a package download.

`clear()` removes consent and cache, returning to disabled. `Future<void> dispose()` cancels work, drains already-started preference writes, and closes the stream; await it before switching/deleting a profile. Preference writes are serialized, so opt-out and clear follow any write already in flight. `oc.setupRegistry.<profileId>` stores versioned JSON with only consent, safe metadata, and cache time. Existing `ProfileStore.profileScopedPreferenceKeys` and `removeScopedPreferences` already include this suffix, so no shared blob or connection edit is needed. An in-flight refresh checks the preference still exists before writing, preventing ordinary delete-during-request resurrection.

## Boundaries and limitations

- The client has a dedicated unauthenticated Dio; it cannot inherit server Basic/Bearer headers. Redirect following is disabled. Requests target exactly the official list endpoint.
- Each user-requested refresh loads the first 100 latest-version rows, limited to 512 KiB. There is no pagination or remote search in this slice. The UI must describe this as a limited catalog, not all available MCPs. Lists within an entry are capped at 10 and text at 1000 characters.
- Connection/send/read timeouts and a bounded response deadline prevent indefinite normal requests. A refresh does not follow package, documentation or MCP endpoint URLs.
- Deleted/deprecated records are filtered. Other publication metadata is not a security endorsement.
- Configuration proposals/apply/undo and installed/connection status belong to the setup controller, never the registry store. A toggle must call that controller and show its confirmation/result; it must not mutate `entries` or imply installation based on a listing.
- Local/Tailscale server setup remains usable without this client or public internet consent.

## Verification

Pinned `dart format --language-version=3.10` completed for all three Dart files. `git diff --check` reported no whitespace issues. Focused behavior tests (including delayed persistence races for opt-out, clear, and disposal before deletion) were written in `test/setup_registry_test.dart`; this worker did not run Flutter, per coordinator serialization. The coordinator records actual test/analyzer results. Implemented: backend only. Enabled: opt-in only; no UI hook-up. Committed/deployed/released: no worker action.
