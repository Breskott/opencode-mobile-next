# SV2 backend: workspaces, worktrees, terminals and environments

Date: 2026-09-27. Base: `643a5104`, branch `codex/sv2`.

Finish line: expose supported server operations through small domain APIs with
focused behaviour tests, and document exact contracts blocking the remaining
requests without enabling them.

Non-goals: UI changes, server implementation, inferred timestamps/deadlines,
credential persistence, connection composition, native code, release or push.

## Scope and ownership

Read: `AGENTS.md`; `docs/ux-system/revamp/STANDARDS.md` sections 2, 3, 13,
15 only; pinned contracts, generated SDK and current domain/protocol adapters.
Existing checkout preserved; no `HANDOFF.md` was present.

Write sets are independent: worktree domain service/test; terminal domain
facet, new protocol adapters/tests; environment/project domain service/test;
this QA record and root `COMMIT_MSG.txt`. The coordinator reviews all three.
No existing UI, gateway, repository, connection, main or native file is edited.
No dependency on another job's unpublished API.

The request also asks for additions to `server_gateway.dart`, but explicitly
forbids editing that single-owner file. The prohibition wins: additions use
separate domain files and extensions on `ServerCapabilities`. Terminal command
creation uses an optional domain gateway facet and explicit protocol adapters;
the connection owner must supply that facet before the UI can enable rerun.

Acceptance: preserve directory/workspace scope and pagination, never confuse a
failed request with a clean copy, preserve command arguments as separate values,
never reconstruct a missing deadline or restore an unreported environment, and
leave unsupported actions unavailable. No new persistence, logs or diagnostics
are introduced; no credentials are inspected or recorded. Any later persistence
must pass through `KitRedact` and the profile deletion contract.

## Server capability matrix

| Item | Server has it? | What you built | Capability flag | UI hook for the builder |
|---|---|---|---|---|
| Merge a copy back | No, neither pinned contract | No mutation; blocked contract below | `worktreeMerge == false` | Keep merge unavailable |
| Uncommitted changes per copy | Yes: v1 `vcsStatus` with directory/workspace; v2 `GET /api/vcs/status` with `location[directory]` | `WorktreeInspection.loadChanges` over existing per-directory gateway call | `worktreeUncommittedChanges` | Fetch a selected/expanded row; successful empty means clean; failures mean unknown |
| Which conversation uses a copy | Yes: global paged root sessions carry directory/project/workspace | `WorktreeInspection.conversationPage` with exact scope filtering and preserved continuation | `worktreeConversations` | Page through results; do not label a partial page as an exhaustive count or imply activity |
| Restart ended terminal command | Both create routes accept executable, argument array, cwd and title; no restoration of typed shell input or original env | Optional `TerminalCommandGateway` plus v1/v2 adapters | `supportsTerminalCommandRerun(facet)`; false when facet absent | Connection owner injects facet; user action reruns reported executable with server-default env in a new PTY |
| Terminal age | No start timestamp on either PTY schema | No fabricated age | `terminalAge == false` | Omit elapsed-time claim |
| Time left for command started elsewhere | No effective deadline/timeout on `Shell.Info` | No countdown based on local defaults | `externalCommandTimeLeft == false` | Omit countdown |
| Environment error reason | No identified, refetchable reason; v1 status has only workspaceID/status, v2 lacks workspace inventory | No guessed reason from unrelated failed event | `environmentErrorReason == false` | Generic status only until upstream provides reason |
| Stop environment without removal | No; existing DELETE destroys/removes | No delete-as-stop alias | `environmentStop == false` | Keep stop unavailable |
| Clone repository | No; git-init creates a repo in an existing directory, not a clone | No shell workaround | `repositoryClone == false` | Keep clone unavailable |
| Recent projects first | Both supply `Project.time.updated`; neither supplies last-opened time or guaranteed recent-use order | Stable client-side newest-update ordering, unknown dates last | `projectsByLatestUpdate`; `projectsByRecentUse == false` | Use “Recently updated”, not “Recently opened” |

Current-source evidence:

- [`server_gateway.dart`](../../../lib/domain/server_gateway.dart):
  `WorkspaceProject`, `WorkspaceInfo`, `TerminalProcess`, `HostGateway` and
  `TerminalGateway` describe the existing projection and calls.
- [`product_repository.dart`](../../../lib/api/product_repository.dart):
  `listProjects`/`_workspaceProject` preserve update time;
  `listWorktreeFileStatuses` performs the per-copy request;
  `listGlobalSessions` preserves session scope; workspace listing joins status.
- [`gateway_operations.dart`](../../../lib/api2/gateway_operations.dart):
  `listProjects` (676), `_project` (682), `listWorktreeFileStatuses` (812),
  workspace inventory limitation (836), PTY methods (1011 onward).
- [`v1 OpenAPI`](../../../contracts/opencode-openapi-f12e14cf.json):
  `/project`, `/experimental/worktree`, `/experimental/workspace`, `/pty`;
  schemas `ProjectTime`, `Workspace`, `WorkspaceEventConnectionStatus`,
  `EventWorkspaceFailed`, `Pty`, and the inline PTY create request body
  (generated as `PtyCreateRequest` in the SDK).
- [`v2 OpenAPI`](../../../contracts/opencode2-openapi-beta-18600.json):
  `/api/project`, `/api/worktree/{projectID}`, `/api/workspace`, `/api/pty`,
  `/api/shell`; schemas `Project.Time`, `Shell.Info`, workspace destroy result.
- [`v2 wire notes`](../../opencode2-protocol-notes.md): workspace event shapes
  and PTY create/get/update routes. These pinned local contracts are the
  feasibility evidence; no live server was contacted.

## UI hook-up

Import the three new domain libraries, never their protocol adapters from a
screen. Pass capabilities and operations from the **same** connected profile.
No `ServerFlavor` branching is needed in presentation code.

### Worktree inspection

[`worktree_inspection.dart`](../../../lib/domain/worktree_inspection.dart):

- `WorktreeInspection(gateway: HostGateway, capabilities: ServerCapabilities)`
  binds the read service to a connected server. Recreate after profile/location
  changes, and discard pending results for the previous scope.
- `loadChanges(String directory)` returns an unmodifiable list of
  `VersionControlFile`. It uses the gateway's current workspace; the copy must
  belong to that workspace. The existing method cannot select a different
  workspace per row. No active directory is changed.
- `conversationPage({required directory, required projectID, workspaceID,
  cursor, limit = 50, includeArchived = true})` returns `ServerPage<Session>`.
  Matching is exact, including workspace (`null` means host-local); unknown
  metadata and child sessions are excluded. Archived roots are included by
  default. Pass `nextCursor` back unchanged with the same scope; an empty page
  with `hasMore` is not proof of no conversations. This is association, not a
  claim that the conversation is currently running.
- `WorktreeInspectionCapabilities` supplies the three worktree gates in the
  matrix. Unsupported calls fail before dispatch; invalid empty scope/limit
  fails before dispatch; request errors propagate instead of becoming empty.

Both server protocol adapters already implement the needed reads, so no new
client or gateway declaration is necessary. Fetch on demand rather than issuing
unbounded requests for every row. There is no bulk counts endpoint or new
cache; a bulk count badge is not part of this API.

### Project order and environments

[`environment_projects.dart`](../../../lib/domain/environment_projects.dart):

- `EnvironmentProjectOperations.loadProjectsByLatestUpdate({required
  ServerCapabilities capabilities})` is an extension on
  `ServerOperationsGateway`. It fetches once, sorts positive `updatedAt`
  descending, preserves input order on ties, and places non-positive/unknown
  values last. The returned list is unmodifiable; the source list is untouched.
  Request errors propagate. Gate with `projectsByLatestUpdate`.
- `EnvironmentProjectCapabilities` adds `projectsByLatestUpdate`,
  `projectsByRecentUse`, `environmentErrorReason`, `environmentStop` and
  `repositoryClone` as listed in the matrix. It does not provide pretend
  operations for absent endpoints.

### Terminal command rerun (composition required)

[`terminal_lifecycle.dart`](../../../lib/domain/terminal_lifecycle.dart):

- `TerminalCommandGateway.rerunTerminalCommand(TerminalProcess ended)` returns
  the newly created PTY. The original is retained. It sends the **reported
  executable and separate arguments**, cwd and title. It cannot restore commands
  typed into an interactive shell or the original environment. Describe this as
  rerunning the reported command with the server's default environment.
- `terminalRerunSnapshot(ended)` validates/snapshots input: rejects running
  processes, blank command/cwd and NUL in executable/cwd/arguments; copies the
  argument list without shell joining. Invalid input produces a generic
  `ProductException` without echoing the command.
- `TerminalLifecycleCapabilities.supportsTerminalCommandRerun(facet)` requires
  both `terminal` and a non-null injected facet. `terminalAge` and
  `externalCommandTimeLeft` stay false.

The composition owner must provide either
[`SdkTerminalCommandGateway`](../../../lib/api/terminal_command_gateway.dart)
with the existing authenticated `sdk.OpencodeSdk`, explicit source directory
and workspace, or
[`Api2TerminalCommandGateway`](../../../lib/api2/terminal_command_gateway.dart)
with the existing authenticated `Api2Client`. Both implement the domain facet;
neither creates/stores credentials or owns/disposes the shared client. The v2
adapter snapshots location and refuses a call after that client's location
changes. Recreate/discard facets on profile/location changes; the v1 owner must
bind the explicit source location. Do not expose protocol objects to UI code.

`lib/state/connection.dart` is the remaining composition dependency: its owner
must create the matching facet alongside each operations gateway, clear it on
disconnect/switch, and expose it typed as `TerminalCommandGateway?`. Until that
lands, pass null and keep the action unavailable. Existing
`createTerminal(title:)` remains unchanged.

The UI must initiate a rerun only on an explicit user action, prevent repeated
submission while pending, and refresh terminals after an uncertain response
before offering another attempt. Adapters issue no automatic retry and return
generic errors without attaching raw server/transport causes. A failed response
does not prove the command did not start. No command is persisted.

Capability integration note: current Paseo/Codex disable project management and
global search, so the derived read gates stay false there. DemoGateway currently
defaults those flags to true despite lacking these operations; its owner must
provide demo implementations or correct its flags before wiring these services
to demo mode. This slice's hooks target connected server gateways.

## Missing server contracts

These will be proposals, not claims that the routes exist. Upstream server
source is not checked out here; module ownership is identified by the existing
route families and schema names, not guessed source filenames.

| Missing item | Proposed upstream request/response contract | Upstream owner |
|---|---|---|
| Merge copy back | Proposed `POST /experimental/worktree/merge` (v1 directory/workspace query) / `POST /api/worktree/{projectID}/merge` (v2), body `{sourceDirectory,targetDirectory,expectedSourceHead,expectedTargetHead}`, response `{merged,head,conflicts:[{path,kind}]}`. Dirty trees, stale heads and conflicts must fail without deleting the copy or partially applying changes | Worktree routes/service and VCS integration transaction |
| PTY age | Add `time.started` (UTC epoch milliseconds) to PTY create/list/get and created/updated events; retain it for exited PTYs | PTY process registry and route/event serialization |
| External command deadline | Add `time.deadline: epochMs \| null` to `Shell.Info` on list/get/create and timeout update responses; null means no deadline, absence means unknown; return authoritative effective deadline after adjustments | Shell execution scheduler and shell routes/events |
| Environment error reason | v1 `GET /experimental/workspace/status` rows need `{workspaceID,status,reason?:{code,message},updatedAt}`. v2 needs refetchable `GET /api/workspace` inventory carrying those fields. Failed/status events also need identified `workspaceID` plus reason. Refetch after reconnect | Workspace lifecycle/status storage and HTTP/event serialization |
| Non-destructive stop | Proposed `POST /experimental/workspace/{id}/stop` and `POST /api/workspace/{workspaceID}/stop`, body `{}`, response `{workspaceID,status:"stopped",stoppedAt}` (v2 envelope as appropriate). Preserve files/identity; define idempotence and restart/resume semantics | Workspace provider/lifecycle manager and routes |
| Repository clone | Proposed `POST /project/clone` / `POST /api/project/clone`, body `{url,directory,branch?}`, response `Project` / `{data:Project}`, typed destination/auth/clone errors. Use server-managed auth; forbid credential-bearing URLs and unsafe destinations | Project HTTP routes and project/VCS service, including project registration |
| True recent-use order | Add `Project.time.lastOpened` epoch-ms and `GET /project` / `GET /api/project` ordering parameter `order=lastOpened.desc`; update timestamp on a project/location open, not metadata edits | Project lifecycle persistence and project-list routes |

No merge, stop, clone, reason, age or deadline implementation is attempted after
the corresponding feasibility failure. Stop must never call DELETE. Clone must
never shell out through a terminal workaround. Project update times must never
be relabelled as last-opened times.

## Verification and state

Flutter tests and Flutter analyzer are **not run**, per the owner's instruction
that this builder cannot run Flutter. This checkout has no
`.dart_tool/package_config.json`. A verifier must resolve packages with the
pinned toolchain and run the focused files listed here before integration.
No full-suite, live-server, UI, device, signing or release claim is made.

Focused verifier commands, run serially after pinned `flutter pub get`:

```sh
FLUTTER_SV2="$HOME/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter"
"$FLUTTER_SV2" test --concurrency=1 test/worktree_inspection_test.dart
"$FLUTTER_SV2" test --concurrency=1 test/environment_projects_test.dart
"$FLUTTER_SV2" test --concurrency=1 test/terminal_lifecycle_test.dart
"$FLUTTER_SV2" analyze
```

The focused tests cover exact copy scope, clean versus failed reads, paged root
conversation association, unsupported/invalid no-dispatch, stable project
ordering, both PTY request shapes, literal argument preservation, failed
response sanitization/no retry and stale v2 location rejection. These are
authored coverage, **not passing test evidence**.

Pinned Dart formatting with `--language-version=3.10` succeeded on all added
Dart files. It warned that `package:flutter_lints/flutter.yaml` could not be
resolved without this checkout's package configuration. Static API/type review
used the checked-in generated SDK and existing gateway declarations; it cannot
replace analyzer/test execution.

QA relative-link check: 11 links resolved. The final scope check confirms only
eight new Dart files, this QA record and `COMMIT_MSG.txt`; no existing source,
generated SDK, forbidden single-owner file or UI file changed.

| State | Result |
|---|---|
| Implemented | Supported backend APIs/adapters and focused tests; missing-contract records complete |
| Enabled | Read hooks callable through existing gateways; no UI connected; terminal rerun unavailable until composition owner supplies facet; missing actions false |
| Verified | Pinned formatting and static review only; Flutter/analyzer/runtime unverified |
| Committed | Local commit attempted after final scope/diff checks; see final task report and root `COMMIT_MSG.txt` |
| Deployed / released | No |
