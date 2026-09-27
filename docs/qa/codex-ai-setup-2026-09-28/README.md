# AI setup backend follow-up — 2026-09-28

**Implemented backend safeguards; production mutations and AI sessions remain
blocked.** The exact pinned runtime contracts do not support atomic, lossless
configuration restoration. No server writes, runtime MCP mutations or model
sessions were enabled. The conditional Apply/Undo executor is verified with
fakes only. No UI composition exists in the current app.

## Scope and feasibility

Finish line: recheck the pinned runtime APIs and safely implement reviewed
configuration Apply/Undo with verified snapshots and audit wherever the actual
host contract permits it; document precise refusals and Claude's UI contract.
Non-goals: UI/native work, new credential entry, host file/shell workarounds,
general agent execution, live server mutation, release or push.

Base: `f83e1e30` on `codex/audit`, the supplied worktree fast-forwarded to the
integration tip. Initial tree clean. `connection.dart`, shared gateway files,
generated SDK, localization and all UI/native files remain untouched.

[Exact-tag research](pinned-runtime-recheck.md) covers OpenCode 1 1.18.32 and
OpenCode 2 2.0.10 plus the merged [SV3 APIs](../codex-sv3-2026-09-27/README.md).
This is source verification, not a live pinned-host test. Local runtime aliases
are older and were not treated as pinned-runtime evidence.

- OC1 effective config plus merge PATCH cannot preserve source inheritance or
  prevent concurrent writes. There is no conditional exact restore receipt.
- OC2 **does** have a shell-only global PATCH and per-session deny rules. These
  correct stale beta claims. Its PATCH cannot apply the proposal fields, and
  its MCP overrides lack durable source restoration and revision preconditions.
- Permission denial does not exclude ambient server context from an AI session.
  Actual AI setup remains unavailable; guided local choices are not an AI model.
- SV3's narrow acknowledged edits remain separate actions. They do not acquire
  an Undo guarantee through an adapter or a second GET.

## Backend changes

| Area | Delivered behavior |
| --- | --- |
| Domain transaction requirement | `SetupTransactionalConfigGateway` requires source identity/revision, atomic compare-and-commit, actual before/after snapshots and opaque host-owned conditional restore. No HTTP implementation is invented. Legacy write flags alone cannot enable Apply. |
| Review executor | Fresh preflight, exact receipt validation and independent readback for Apply and Undo; conflicts write nothing; missing/null values stay distinct; uncertain outcomes disable automatic replay and Undo. |
| Executable subset | Scalar model/default-agent/simple permission choices and disabled remote MCP definitions only on a conforming future host. Provider credentials, local commands, general agents/commands, active MCP connections and OAuth remain outside this executor. |
| Lifecycle | Captured adapter directory/workspace; optional selection-generation guard; scope/online checks across awaits; post-dispatch reconciliation stays on the original host without publishing ready to another selection. |
| Audit | Shared serialized per-profile metadata writer, random operation IDs, pending/accepted/verified distinctions, bounded immutable history, corrupt-history refusal and durable-cache reload after refused writes. |
| Deletion | Close audit/default owner admission before yielding, drain writes, then discover and sweep scoped keys. Absent profiles and closed handles reject new writes. |

Three independent implementation owners covered the domain/controller/tests,
audit persistence/deletion/tests, and protocol adapter binding/tests. Methods
and receipt types were frozen before editing. Workers did not launch Flutter;
the coordinator reviews and runs serialized checks through the machine lock.

Secrets remain on the existing authenticated transport paths. Raw source
snapshots and restore handles are memory-only, with trusted-ingress credential
registration and structural redaction for presentation. Undo must transmit an
opaque restore handle and revision, not replay credential-bearing snapshots.
No config, diff, prompt, server address, credential or restore handle enters
the audit. The existing `oc.setupAudit.<profileId>` key remains in use; old
bounded id/action/UTC-time metadata remains readable. Invalid history is not
silently overwritten. No credential/storage-format migration is required.

## Claude UI hook-up

Use the updated [complete contract](../../design/ai-setup-assistant-contract.md)
for APIs, phases, copy intents and error mapping. The composition owner outside
UI supplies the authenticated domain adapter and captures profile/location
generation in `isCurrent`. Recreate and dispose on selection changes; never
toggle write support based on flavor or SV3 availability.

Render only redacted `SetupSnapshot`/`SetupDiff`; presence flags distinguish
absence from null. The body uses localized plain words, with explicitly redacted
technical context in Details. Copy intents belong in `app_en.arb` when screens
are built. Show receipt acceptance as verification in progress, never completion.
Uncertain outcomes require inspection, not Retry/Undo buttons. Current production
adapters show the unavailable reason and leave Apply/Undo disabled.

## Verification

Toolchain: `~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin`.
The coordinator ran heavy checks serially through
`OC_TEST_SLOTS=1 tool/qa/machine_lock.sh test|analyze -- ...`; machine-slot and
Flutter startup-lock waits are excluded from test durations below.

- `dart format --language-version=3.10`: all ten changed handwritten Dart files
  formatted, no pending changes.
- `flutter analyze --no-pub`: **clean**. The first run found four style lints
  and one unnecessary test cast; corrected without ignores, then rerun clean.
- Initial focused run: **152 passed** across the manifest below. Final review
  then added ancestor-replacement, snapshot-immutability and post-dispatch
  audit-failure coverage; the final controller/transaction rerun supersedes
  those two files' earlier results.
- Final controller/transaction tests plus the four required gates: **114 passed**
  (38 controller/transaction cases and 76 gate cases). Kit ratchet, redaction,
  UI glossary and no-raw-error-text gates all pass on the final code.
- Local documentation links: 11 checked across three documents, no missing
  targets. `git diff --check`: clean.

Initial focused manifest (`flutter test --no-pub --concurrency=1 ... --reporter expanded`):

```text
test/setup_controller_test.dart
test/setup_transaction_test.dart
test/setup_audit_store_test.dart
test/setup_config_adapter_test.dart
test/setup_planner_test.dart
test/setup_registry_test.dart
test/profile_deletion_test.dart
test/profile_store_test.dart
test/profile_secure_storage_test.dart
test/default_notice_deletion_test.dart
test/interaction_defaults_test.dart
test/sv3_tool_test.dart
test/sv3_mcp_test.dart
```

Final affected rerun and gate manifest (same command options):

```text
test/setup_controller_test.dart
test/setup_transaction_test.dart
test/kit_ratchet_test.dart
test/redaction_test.dart
test/ui_glossary_test.dart
test/no_raw_error_text_test.dart
```

Coverage includes adapter location capture and both OC2 dialects, refusal without
transport, secret registration through real adapter reads, legacy write-flag
refusal, an external revision change between preflight and atomic commit,
revision-only Undo conflicts, exact disabled-MCP add/remove restoration without
credential replay, absent versus null preservation, bad receipts/readback/lost
responses, storage failure before and after dispatch, stale/offline owners,
shared writers and real `ProfileStore` deletion with a delayed audit write.

No live mutation, model call, native build, full-suite claim, deployment or
release is part of this unit. Check logs remain outside the repository in
`/tmp/oc-ai-setup-*.log`.

## Remaining limits

- Production Apply/Undo and MCP mutations need a real host implementation of
  the atomic source contract. Fake tests do not supply that capability.
- Undo is one level, memory-only, conditional on the exact after revision and
  available only after verified audit/readback. Process-restart recovery needs
  durable host operation lookup/idempotency before it can be offered.
- Configuration restoration does not undo runtime activation, external MCP
  effects, OAuth or package installation. Such operations remain unavailable.
- Local deletion cannot cancel an already-dispatched host operation. A deletion
  that reaches owner closure but later fails leaves admission closed until
  restart; no writer is reopened during the sweep.
- A screens/composition owner still needs to build and verify the end-user flow.
  This is backend groundwork and a precise hand-off, not a completed AI setup
  assistant.
