# Continue with… — backend / frontend contract

Owner request: 2026-10-14, corrected in the direct-Codex follow-up. The owner's
source is the **direct Codex integration**, app-server 0.153.4, running GPT-6.1
Sol; the main destination is Claude Code via Paseo. This slice implements domain/state/gateway behavior
and supplies tests. It does **not** implement the sheet, menu, banners or
localization. Flutter tests and phone qualification remain pending.

## What works and what is gated

A new conversation is a continuation of the work, with a portable record; it
is not the same provider session or hidden model context. Source conversations
can be direct Codex, OpenCode 1, OpenCode 2 or Paseo, using bounded domain
history interfaces. The implemented file-writing destination is Paseo advertising
`server_info.features.workspaceFileEditing: true`. OC1/OC2 destinations lack
an explicit project-file writer and remain unavailable for cross-agent handoff.
Codex does expose filesystem RPCs, but its safe handoff writer is not qualified
or enabled; it is a source, not a new-conversation destination in this slice.
Use `agentHandoffUnavailableReason(...).message` for a disabled row, including
**This destination cannot safely save a conversation record yet.** Do not infer
writer support from the existence of a generic filesystem method.
See [feasibility evidence](agent-handoff-feasibility.md) for exact pinned APIs.

For the owner's direct Codex → Claude Code case, select the ready Claude runtime
and a model returned by its current catalog. The runtime uses its own normal
Claude sign-in. Do not copy credentials, offer a hardcoded model identifier,
or mistake a Claude subscription for an Anthropic provider connected to
OpenCode. The app may offer Opus only when that runtime lists it as enabled.

When the choice is just another model in the **current** conversation's runtime,
`agentHandoffRoute` returns `switchModel`: offer **Use this model** and call
`ConnectionController.selectModelForSession(sourceSessionId, model, variant: …)`.
Use its normal availability/error/result handling. Keep the session ID and full
native history. Do not write a record, create a conversation, send a prompt or
persist continuation links. Set `HandoffTarget.startNewAgent: false` only for
these model rows; Claude Code is an agent row (`true`). Provider changes require
`sessionModelProviderSwitching`; same-provider model changes can remain native.

## Entry points and sheet

Add **Continue with…** to the conversation ⋯ menu, including read-only source
conversations when their history is available. After a provider failure, a quiet
secondary **Continue with another agent** action may open the same sheet. Do
not automatically open it or reinterpret a permission refusal as provider failure.

Use kit components only. Add real-screen catalog states when the UI is built.
The UI imports domain/state contracts, never Codex, OC1, OC2 or Paseo implementation
classes. Branch on `ServerCapabilities` and domain route results, never flavor.

Show, in order:

1. **Continue this work** with the source title and project folder.
2. Ready agents/models from their current catalog; show unavailable choices with
   their reason. A missing sign-in uses the existing sign-in flow.
3. For a native model row: **Your conversation stays here.** / **Use this model**.
4. For a new-agent row: **Start a new conversation with a record of this one.**
   Show target agent, model and project. Explain that the source stays available.
5. Once prepared, **Conversation record** with size, omitted-message count,
   redaction notice, expandable markdown preview and the generated file path.
   Say **Older turns were left out to keep the record small** when applicable.
6. **First message**, an editable multiline field initialized from `draft.prompt`.
   Keep the required record path in the message. The primary action is
   **Start and continue**. **Cancel** closes without sending.

All record/draft preparation is read-only. No file or conversation exists until
**Start and continue**. The preview and draft stay in memory. Before sending,
credential-looking text is masked again (the app-authored record path is kept); the editor should use
`draft.sanitizePrompt(editedText)` so the review matches the sent text. A blank message, missing record
path or message above 16 KiB is rejected without consuming the ready draft.

## Wiring and ownership

- `lib/domain/agent_handoff.dart`: `HandoffScope`, `HandoffTarget`, route/failure
  types and explicit target gateway contract.
- `lib/state/agent_handoff_controller.dart`: one controller per sheet/attempt;
  `prepare(lastState: …)` returns `AgentHandoffDraft`, then `send(editedPrompt)`
  returns the live navigation session ID. `createdSessionId` holds the durable
  ID. `onChanged` observes `phase`, `failure`,
  `draft`, `writtenPath` and `createdSessionId`.
- `lib/domain/agent_handoff_history.dart`: bounded complete-history reader.
- `lib/domain/agent_handoff_record.dart`: reusable builder for already-held
  transcript data, including an explicit `historyComplete: false` disclosure.
- `lib/state/agent_handoff_links.dart`: metadata persistence and navigation.

Retain independent source and destination gateway leases through the attempt.
Connect the target before inspecting its negotiated capability. Do not change
the source controller's location to reach the target. The `isCurrent` callback
must cover both profile lifetimes, deletion, both location generations, source
session selection and sheet disposal; generations must catch away-and-back
changes. The controller additionally checks gateway directory/workspace and
profile-store admission before and after awaits and at prompt dispatch.

For phone agents, `HandoffScope.profileId` is the saved **parent** server profile,
with `origin: HandoffOrigin.phoneAgent`; the saved profile's ordinary backend uses `origin: server`. The
connected phone-agent profile is a transient transport lease and is not a saved
profile: never use its suffixed ID for link ownership. Source and target can
share a parent profile while using different origins. Routing a link must select
its saved origin as well as its profile and project.

`HandoffScope.filesystemId` is **trusted app-owned evidence**, not a string copied
from the server. For managed phone routes, establish that both gateway leases
refer to the same managed Linux installation/agent owner and effective project
mount. `ProfileStore.phoneAgentOwnerId` identifies the shared agent home; use
that only together with managed-host provenance from the lease that opened the
runtime. A remotely configured server named “phone”, two localhost URLs, or
matching absolute paths do not establish that provenance. Leave identity null
and the route unavailable when it cannot be established. Source and target
must name the same canonical effective project directory. No cross-machine
file copy, project migration or credential reuse is performed by this feature.

Pass last state from the source's current attention/status model using plain
words: **Working**, **Waiting for you**, **Failed**, or **Unknown**. Do not infer
“waiting for you” solely from an idle transport. Preparation checks the source
session revision again after reads; sending checks it again after review. If it
changed, reopen preparation so the person reviews a current record.

Target availability is rechecked against the gateway's connected provider
inventory at prepare and send (including its normal provider-cache behavior). Provider and model must
be enabled; a requested thinking variant must exist and not be disabled. The
`agent` argument is the gateway's existing agent/mode selection, not the target
runtime ID; the model's provider selects the Paseo runtime. Preserve its normal
permission mode. Do not set auto-approve for handoffs.

## Direct Codex source

The regular Codex chat history method resumes a thread. Handoff deliberately
uses `AgentHandoffHistoryGateway.agentHandoffHistory` instead:
`thread/read {threadId, includeTurns: true}` reads the full persisted rollout
projection without `thread/resume`, subscriptions, approval responses or a new
turn. The gateway pins the connection epoch, location generation and requested
thread ID, and checks the returned cwd before exporting any text. The common
reader also fences profile/selection changes. No Codex account or transport
token goes into the record or the target prompt.

App-server 0.153.4 requires `historyMode: legacy|paginated` and each hydrated
turn's `itemsView: full`. Missing, summary-only or not-loaded history is an error,
not an empty transcript. Both history modes are accepted when fully hydrated.
The full response is bounded by the existing 4 MiB transport limit; extraction
also bounds 5,000 mapped messages, 10,000 source items/parts and 1,048,576 UTF-16
code units per text field. Over-bound or malformed input fails visibly. Although the pinned API
also offers turn/item pagination, this slice uses full hydration; it does not
silently substitute the UI's cached tail for an oversized response.

The handoff mapper preserves user text, final answers, commands/cwd/exit status,
file paths and tool outcomes before common redaction and size reduction. MCP,
dynamic, function-output and collaboration steps retain names/status; only
allowlisted command/path arguments and explicit text results are exported. It
excludes reasoning and explicit commentary. Legacy answers with no phase retain
their visible text with an unknown-phase disclosure. Successful file-change
paths are observations, not proof of current disk state; patch bodies are
excluded. Persisted plan text is retained, but an event-only plan/todo update
cannot be reconstructed from thread history. Failed, interrupted and active
turns carry explicit notices, and compaction is disclosed without inventing
removed context. Unknown item contents are excluded with a notice.

A saved direct-Codex profile uses `origin: HandoffOrigin.server`; its thread ID
is already durable. Do not relabel it as a transient Paseo phone-agent profile.
The existing shared-filesystem proof is still required: direct Codex and Paseo
having equal cwd strings does not prove they operate on the same files.

Direct Codex remains unavailable as a new-conversation destination because no
exclusive, project-contained, no-follow handoff writer has been established for
its generic absolute-path write RPC. The pinned schema confirms `fs/writeFile`,
`fs/createDirectory`, `fs/getMetadata` and `fs/readFile`; it does not establish
those safety semantics. Do not claim that Codex lacks all file APIs, and do not
work around the missing adapter by asking the model to write its own record.

## Record and project files

The builder keeps user text and visible assistant text verbatim except secret
masking. It never includes reasoning, credentials/config payloads, attachment
contents or arbitrary tool metadata. Tool summaries allowlist command/path
fields, execution status, numeric exit codes and a redacted compact outcome.
Pruned outputs and attachment omissions are explicit. Todo and changed-file
sections use available source data; missing endpoint data is not a claim that
there was no work. OC2 working-tree diffs are not session attribution.

The UTF-8 limit is 96 KiB. Omit whole oldest user-led turns until the record fits,
retaining the newest complete turn. If that turn or metadata alone cannot fit,
fail visibly; never truncate the newest prompt silently. Tool summaries may be
shortened after redaction. The read path consumes at most 100 pages of 50 items
and refuses incomplete/malformed/cycling pagination rather than claiming full
coverage. Provider compaction may already have removed old information.

A random per-attempt ID produces `.handoff/<id>/record.md`. The target file API
exclusively creates the subdirectory, writes its own `.gitignore` containing
`*` (also ignoring the ignore file), then writes and reads back the record.
This avoids changing project-wide ignore files or overwriting an earlier
handoff. It uses version-checked writes, no shell command and no agent prompt
as a file-writing workaround. An existing symlink in place of `.handoff` is
refused. A failure may leave an empty or ignored folder; do not delete an
uncertain remote result automatically. Users may remove old handoff folders
through their normal project tools. Profile deletion removes app links, not
files the user has placed in the project.

The record itself tells the receiving agent that conversation and tool output
are historical data, and to inspect the current project before continuing.
Pattern-based redaction cannot certify arbitrary private prose; show the preview
and never describe the record as guaranteed free of sensitive information.

## States, errors and retry behavior

| State | Sheet copy / action |
| --- | --- |
| `loading` | **Preparing the conversation record…**; cancel available |
| `ready` | Editable first message and record preview; **Start and continue** |
| `writingFile` | **Saving the conversation record…**; disable duplicate submit |
| `creating` / `sending` | **Starting the conversation…**; disable duplicate submit |
| `linking` | **Linking the conversations…** |
| `complete` | Open the returned session through normal profile/project routing |
| unsupported writer | **This agent can't save a conversation record here yet.** |
| unverified project identity | **These conversations aren't connected to the same project.** |
| unavailable target | **This model isn't available. Choose another one.** |
| source changed | **This conversation changed. Prepare the record again.** |
| scope/deletion changed | **The server or project changed. Start again.** |
| history read/coverage failure | **Couldn't read the conversation. Try preparing it again.** |
| record too large | **The latest turn is too large to carry over.** |
| file failure | **Couldn't save the record. No message was sent.** |
| `creationUnknown` / `deliveryUnknown` | **The result isn't confirmed. Check the target conversations before trying again.** |
| `linkFailed` | **The conversation started, but its link couldn't be saved.** / **Save link again** |

Never show raw exceptions, server error payloads or tool output as error copy.
Display typed errors from `prepare` (including `HandoffRecordTooLarge` and
`AgentHandoffHistoryFailure`) and the controller's `failure` for sending.

One controller consumes at most one send attempt after side effects begin.
Unknown delivery never retries or creates another conversation. Keep
`createdSessionId`/`writtenPath` visible for recovery when known. After an
acknowledged prompt, `retryLink()` only persists navigation metadata; it does
not write the file, create a conversation or resend. Cancel before send has
no side effects; after dispatch, closing the sheet does not cancel work already
accepted by the target. App/process loss during a mutation has no durable
reconciliation journal in this slice: inspect target history before starting
another attempt. Do not label that case “not sent”.

## Links and deletion

After acknowledged delivery, source shows **Continued in <agent> →** and target
shows **Continued from <title>**. `forSession(profileId, durableSessionId, origin: origin)` returns
both directions within that runtime. Resolve Paseo IDs through the domain target gateway's
`handoffSessionId`, including source lookup, so links survive a reconnect.
Use saved profile/origin/project routing when opening a link; never manufacture
URLs. Resolve the saved durable ID through `handoffNavigationSessionId` on the
selected target gateway before opening it: an already-live Paseo gateway may
still use a local draft alias, whereas a fresh gateway uses the durable ID.
`send` already returns this navigation ID; `createdSessionId` remains durable.
If a conversation was deleted, say **This conversation is no longer available.**

Each link has one canonical record under `oc.agentHandoffs.<sourceProfileId>`.
Incoming lookup discovers that same record; there is no half-written pair.
Only navigation metadata is persisted, never record text or first prompts.
Writes serialize and read back. Profile deletion closes admission synchronously,
drains outstanding writes, removes outgoing records and removes incoming
references from surviving profiles. Failed deletion only reopens admission once
the profile is known to remain. Link-storage failures are reported separately
from remote conversation success.

## Verification handoff

Supplied focused files (Flutter execution explicitly not performed):

- `test/agent_handoff_record_test.dart`
- `test/agent_handoff_history_test.dart`
- `test/agent_handoff_controller_test.dart`
- `test/agent_handoff_links_test.dart`
- `test/paseo_agent_handoff_test.dart`
- `test/codex_agent_handoff_test.dart`
- `test/codex_handoff_record_test.dart`

Also run affected existing `test/profile_deletion_test.dart`,
`test/profile_store_test.dart`, `test/paseo_gateway_test.dart`,
`test/session_selection_sync_test.dart`, `test/gen_ui_history_test.dart`,
`test/codex_gateway_test.dart` and `test/codex_transport_test.dart`. Use pinned
Flutter and the repository machine lock. Local Dart analysis and standalone
Dart smoke results are recorded at commit handoff; they are not Flutter tests,
a full-suite pass, UI acceptance or a phone/subscription qualification.


Local checks for this candidate: pinned Dart formatting and focused Dart analysis
of changed libraries plus the handoff test files completed cleanly. Analysis
used a worktree-local package map pointing to the existing pinned SDK and cached
dependencies; no Dart package install or Flutter command ran. Three standalone
Dart smokes passed for record UTF-8 bounds/redaction, history paging/order/failures,
and complete-snapshot bounds, identity, immutable parts and scope fencing.
These do not execute the Codex gateway or mapper; their Flutter tests were
analyzed but remain pending execution.
The Flutter-based tests above remain unexecuted. No owner's server, sign-in,
phone, APK or real agent was used for validation.
