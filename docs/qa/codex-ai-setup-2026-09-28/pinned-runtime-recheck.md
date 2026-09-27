# AI setup: pinned-runtime feasibility recheck

Reviewed 2026-09-28 from app integration `f83e1e30`. Authoritative runtime source:
OpenCode 1 `v1.18.32` (`545f51d26cc39a907d2867492d498d9607ea5fa4`) and OpenCode 2
`v2.0.10` (`b8cedc1a7a5e2916bbb65dc1d4b620729c261638`). This is exact-tag source
inspection, not a running-host test. The local command aliases resolve to older
1.18.23 and beta19242 installations; they were not used as pinned-runtime proof.
No live server was started or mutated, and no populated credential store read.

## What changed since the previous feasibility report

Two OC2 claims in the [earlier research](../codex-ai-setup-2026-09-27/server-research.md)
and [assistant report](../codex-ai-setup-2026-09-27/assistant-feasibility.md) are
outdated: stable 2.0.10 has a shell-only experimental config PATCH and accepts
per-session permission rules. Neither establishes the complete requested
reversible setup or restricted-context assistant contract.

| Operation | OC1 1.18.32 | OC2 2.0.10 | Safe setup-assistant availability |
| --- | --- | --- | --- |
| Config inspection | Effective merged config | Ordered source entries, with decoded document information | Available, with distinct view semantics |
| Persistent config update | Deep-merge project/global PATCH | Experimental global patch accepts only `shell: string or null` | Not an exact reversible transaction |
| Tool/MCP enablement | SV3 sends narrow acknowledged patches | No corresponding verified persistent general configuration route | Existing SV3 actions stay separate; no setup Undo promise |
| MCP add/remove | Runtime add can start/connect a server; disconnect retains config; no config-key deletion contract | Runtime name override/replacement; removal records an in-memory false override | No complete conditional before/after snapshot or exact restore |
| AI tool denial | Session permissions plus structured-output-related fields exist | Per-session permissions; deny-all filters direct/codemode tools | Necessary execution control, not proof of sanitized-only context |
| Typed, restricted setup agent | Not verified against exact runtime/plugin combination | Ambient configuration/discovery/MCP/skill/reference context still loads; no prompt output-schema field | Actual AI sessions remain unavailable |

## OC1: why existing-value patches still do not have exact Undo

The [project writer](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/opencode/src/config/config.ts#L589-L601)
loads one file, deep-merges and writes without an expected revision. The
[PATCH handler](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/opencode/src/server/routes/instance/httpapi/handlers/config.ts#L14-L22)
returns the submitted update; it is not a resulting effective-state receipt.
Global loading combines several files, while a global write selects one target.
See [global loading](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/opencode/src/config/config.ts#L240-L270),
[target selection](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/opencode/src/config/config.ts#L129-L160)
and [global update](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/opencode/src/config/config.ts#L606-L629).

If the old model came from a lower-priority source, writing that value back
creates an override instead of restoring inheritance. A GET/PATCH/GET sequence
also leaves a race with another client or file editor. Readback can detect some
wrong outcomes only after damage; it cannot turn a merge patch into a conditional
transaction. A local app lock does not protect server-side editors.

The [MCP config schema](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/core/src/v1/config/config.ts#L113-L115)
does not allow null deletion values. [MCP routes](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/opencode/src/server/routes/instance/httpapi/groups/mcp.ts#L32-L139)
do not expose source-level deletion/restore. [Runtime add/disconnect](https://github.com/anomalyco/opencode/blob/v1.18.32/packages/opencode/src/mcp/index.ts#L641-L659)
changes runtime configuration and connection activity; disconnect is not lossless
Undo of Add. No nontrivial supported mutation meets exact restoration today.

## OC2: the new PATCH is real, but too narrow and unconditional

The [protocol route](https://github.com/anomalyco/opencode/blob/v2.0.10/packages/protocol/src/groups/config.ts#L9-L42)
includes `PATCH /api/experimental/config`. Its
[request schema](https://github.com/anomalyco/opencode/blob/v2.0.10/packages/schema/src/config.ts#L112-L130)
allows only the shell setting. It is not a route for the assistant's model,
agent, permission or MCP proposals. Null deletes shell, but does not define
arbitrary JSON merge-patch deletion semantics.

The [implementation](https://github.com/anomalyco/opencode/blob/v2.0.10/packages/core/src/config.ts#L329-L348)
chooses the highest existing global config candidate at write time, modifies
JSONC, writes and reloads. An internal semaphore serializes that writer, but
there is no caller-selected source, expected revision, compare-and-swap or
exact restoration receipt. Do not add shell editing as a workaround or claim
that serializing phone requests closes the external-writer race.

[MCP operations](https://github.com/anomalyco/opencode/blob/v2.0.10/packages/protocol/src/groups/mcp.ts#L24-L54)
are runtime controls. [Inventory and overrides](https://github.com/anomalyco/opencode/blob/v2.0.10/packages/core/src/mcp/index.ts#L583-L615)
strip full configuration from inventory and implement removal as a false
override; overrides do not constitute durable config deletion. An added
`disabled:true` definition [avoids startup](https://github.com/anomalyco/opencode/blob/v2.0.10/packages/core/src/mcp/index.ts#L455-L471),
but there is no atomic create-if-absent or complete prior-state receipt. A
check-then-add can replace someone else's concurrent definition. Credentials
and OAuth state cannot be reconstructed safely from inventory.

## AI sessions: acknowledge new enforcement, keep the remaining gap precise

[Stable session creation](https://github.com/anomalyco/opencode/blob/v2.0.10/packages/protocol/src/groups/session.ts#L220-L229)
accepts `permissions`, using [action/resource/effect rules](https://github.com/anomalyco/opencode/blob/v2.0.10/packages/schema/src/permission.ts#L58-L65).
[Session denial precedes saved approvals](https://github.com/anomalyco/opencode/blob/v2.0.10/packages/core/src/permission.ts#L158-L188),
and [tool filtering/execution](https://github.com/anomalyco/opencode/blob/v2.0.10/packages/core/src/tool.ts#L225-L295)
provides a real deny-all boundary for direct tools and codemode. The earlier
blanket claim that OC2 has no per-session permission override must not be used
in new UI copy.

However, [session context construction](https://github.com/anomalyco/opencode/blob/v2.0.10/packages/core/src/session/context.ts#L130-L153)
loads ambient builtin, discovery, skill, reference, MCP and instruction context
independently of tool denial. Session creation provides no verified
sanitized-context-only switch. [Prompt input](https://github.com/anomalyco/opencode/blob/v2.0.10/packages/schema/src/prompt-input.ts#L29-L34)
also lacks a typed proposal-output contract. Parsing model text as JSON could
validate a proposal, but would not remove the ambient-context/privacy gap or
prove configured plugin behavior. No ordinary chat or shell fallback is enabled.

Future enablement needs an exact-runtime integration test demonstrating that
only approved sanitized input reaches the model, no execution/delegation escape
exists, and malformed/untrusted model output cannot bypass local validation and
explicit review. Provider credentials continue through existing sign-in/secret
entry, never assistant prompts, audit, diagnostics or notification copy.

## App implementation boundary

The [SV3 API](../codex-sv3-2026-09-27/README.md) remains useful for explicitly
named standalone actions. Its accepted PATCH response does not add reversible
source storage, conditional deletion or MCP restoration. Do not inject that
adapter into a reversible setup interface.

The follow-up hardens the existing coordinator with an explicit transaction
facet and adversarial fake coverage, rather than creating an HTTP adapter for
an imaginary route. Both production setup adapters retain false write/AI flags.
Required host implementation: source-bound revision, atomic commit of exactly
reviewed edits, authoritative before/after snapshots, opaque server-owned restore
handle, conditional restore against the exact after revision, and no execution
of newly added disabled MCP definitions. Unsupported operations report a reason
before transport. No fake passing test establishes a deployed host capability.
