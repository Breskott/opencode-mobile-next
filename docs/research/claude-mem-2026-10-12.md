# Astra — ideas from claude-mem (2026-10-12)

**FactsBook should borrow claude-mem’s economical retrieval and operational safeguards, while retaining its own evidence, consent, and signed-write model.** The main mismatch is that useful coding recollections can tolerate automatic summarization; personal facts need stronger provenance and review.

Static review of checkout `fa8ab09f0`. No files changed, dependencies installed, or project code/tests executed. FactsBook references below mean `docs/specs/NN-*.md` and `docs/02-contracts.md`. D36 takes precedence over older provider wording; D37 is treated as your queued proposal.

**1. What claude-mem is — five lines**

- An Apache-2.0 system that remembers coding sessions across agent restarts and context resets.
- Hooks capture prompts, tool activity and session endings; transcript watchers cover hosts without suitable hooks.
- A separate observer model converts activity into typed observations and structured session summaries.
- The local worker stores memory in SQLite, provides FTS5 and optional Chroma retrieval, and serves HTTP/MCP clients.
- New sessions receive a compact memory index; agents can retrieve selected details, with hosted providers and server/cloud paths also available.

Architecture:

```text
Host hooks / transcript watchers
  → normalization, exclusions → durable hook spool or direct ingest
  → local HTTP worker → per-session RAM buffer → tool-disabled observer
  → parsed observations + summaries → SQLite / FTS5 → optional Chroma
  → startup context / progressive MCP search / viewer
  → optional integrations: awareness logs, notifications, cloud sync
```

Evidence: [hook configuration](claude-mem/plugin/hooks/hooks.json), [transcript processor](claude-mem/src/services/transcripts/processor.ts), [worker architecture](claude-mem/src/services/worker/README.md), [database manager](claude-mem/src/services/worker/DatabaseManager.ts).

**2. ADOPT**

| Idea and claude-mem evidence | FactsBook mapping and value | Effort |
|---|---|---|
| **Progressive retrieval:** `mem_search` returns index → surrounding context → selected details. Its protocol bounds results, checks selected IDs, and expires scoped continuations. [Protocol](claude-mem/src/shared/progressive-search.ts) | Specs 11/24/33, F109/F110: expose small authorized result cards before evidence. Reduces unnecessary disclosure and context cost. | M |
| **Measure rendered context:** drops whole items to meet the host’s output limit, preserving structure. [ContextBudget.ts](claude-mem/src/services/context/ContextBudget.ts) | Specs 24/33, contracts §9: enforce both byte and token budgets on the final envelope, including citations and instructions. Prevents apparently successful but truncated context. | S |
| **Tool denial enforced below prompts:** empty tool set, denied callbacks, no inherited MCP/settings; explicitly blocks peer-agent messaging. [hardened-options.ts](claude-mem/src/sdk/hardened-options.ts) | D36, spec 33 Mode A: qualify actual adapter behavior, including child arguments. Prevents an extractor from borrowing another agent’s authority. CLI configuration still needs FactsBook’s host qualification. | M |
| **Bounded retry and backpressure:** one unanswered observer prompt at a time, capped stall/rate-limit resumes, distinct failure states. [response-pacer.ts](claude-mem/src/services/worker/session/response-pacer.ts) | Specs 20/32/33, contracts §9: shared retry budget, cancellation, explicit `abstain`/paused states. Prevents runaway spending and starvation. | M |
| **Suppress memory feedback loops:** recalled memory and explicit-save echoes do not generate another observation. [observation.ts](claude-mem/src/cli/handlers/observation.ts) | Specs 30/40, D25: preserve source lineage and exclude FactsBook-generated context from independent corroboration. Prevents repetition becoming “evidence.” | S |
| **Keep keyword retrieval independently useful:** SQLite FTS5 remains available without Chroma; empty semantic categories can receive keyword matches. [SearchOrchestrator.ts](claude-mem/src/services/worker/search/SearchOrchestrator.ts) | D21, spec 11: reinforces FactsBook’s existing FTS-first plan. Exact names, dates and amounts remain retrievable without a model. | S |

**3. ADAPT**

- **Capture adapters and checkpoints — M.** [Transcript watcher](claude-mem/src/services/transcripts/watcher.ts) handles offsets, partial records, file replacement and bounded reading; [hook spool](claude-mem/src/shared/hook-spool.ts) namespaces dedupe keys and retains failed handoffs. Map these patterns to spec 40/D37 source-account/object/revision cursors. Capture only consented sources; minimize before any persistence; acknowledge against durable FactsBook state. Value: reliable ingestion without indiscriminate surveillance.

- **Typed observations — M.** [Code mode](claude-mem/plugin/modes/code.json) defines nine types: bugfix, feature, refactor, change, discovery, decision, security_alert, security_note and sensitive. For specs 10/30/32, separate **claim category, provenance, sensitivity, trust, review state and urgency**. A model’s “important” classification must never grant normal-data status or permission. Value: useful triage without conflating meaning and authority.

- **Compression — M.** [Prompts](claude-mem/src/sdk/prompts.ts) produce titles, facts, narratives and summaries of request/investigation/learning/completion/next steps; [history pruning](claude-mem/src/services/worker/history-pruning.ts) removes already-processed payloads from older conversation turns. For specs 10/30/33, summaries should be disposable views over supported facts. Preserve source spans, negation, subject and valid time; never promote a summary into independent evidence. Value: shorter prompts without erasing why a claim exists.

- **IDs and back-references — M.** [ResponseProcessor.ts](claude-mem/src/services/worker/agents/ResponseProcessor.ts:700) links tool-use batches to observations, explicitly acknowledging that the first observation pointer is not a one-to-one evidence mapping. FactsBook needs full `f_` IDs, revisions, support hashes/spans and operation references under D24/D25 and contracts §§2–3. Value: inspectable and correctable recall.

- **Awareness “needles” — M.** [GrokBotAwarenessPusher.ts](claude-mem/src/services/integrations/GrokBotAwarenessPusher.ts) selects types/concepts, limits lines to 500 characters, deduplicates and writes to allowlisted agents’ monthly logs. Adapt to **expiring, authorized pointers** in FactsBook’s brief/offers, with acknowledgements, per-item feedback and D28/D35 caps. Unreviewed items say “proposal awaiting review”; sensitive needles stay generic. Value: surface important changes without broadcasting personal content.

- **Multi-agent identity — M.** Platform/session/agent IDs and configurable subagent suppression prevent fan-out floods; startup context normally excludes subagents. [Agent filtering](claude-mem/src/shared/should-skip-agent-observation.ts) → D36/F109/F110: assign server-side role/run identities, separate capabilities and budgets, and preserve attribution. Identity labels alone are not an authorization boundary.

**4. AVOID**

- **Treating `<private>` as comprehensive protection.** The observation hook passes tool payloads to the spool, which writes JSON; stripping occurs later at worker ingest. Thus private text can reach a durable spool before filtering. Automatic secret redaction is also off by default. Evidence: [spool](claude-mem/src/shared/hook-spool.ts:237), [ingest](claude-mem/src/services/worker/http/shared.ts:225), [tag stripping](claude-mem/src/utils/tag-stripping.ts), [defaults](claude-mem/src/shared/SettingsDefaultsManager.ts:478). FactsBook’s F60 must apply before spool, quarantine plaintext, diagnostics or IPC retention.

- **Automatically committing model claims.** The observer stores generated observations directly; its parser even preserves unknown types, defaults missing types and salvages malformed prose. [Parser](claude-mem/src/sdk/parser.ts:137), [storage call](claude-mem/src/services/worker/agents/ResponseProcessor.ts:660). FactsBook requires closed-schema candidates, deterministic evidence validation and digest-bound review before signed operations.

- **Equating a local worker with local inference.** Tool content, prompts and summaries can reach the selected model provider; recalled context also reaches the consuming agent’s provider. Grok Bot installation explicitly defaults to hosted CMEM, while general settings default to Claude. [Installer choice](claude-mem/src/npx-cli/installer-provider-choice.ts), [defaults](claude-mem/src/shared/SettingsDefaultsManager.ts:401). D36 must govern both extraction and recall egress; no silent provider fallback.

- **Writing recalled prose into instruction-bearing files.** The awareness integration recognizes this risk and sanitizes/fences text. [Sanitizer](claude-mem/src/services/integrations/grok-bot-untrusted-text.mjs). Fences help formatting; they cannot establish trust. FactsBook should return typed data through scoped tools, with authority enforced outside the model.

- **Using transcript replay as FactsBook’s durability model.** [SessionMessageBuffer.ts](claude-mem/src/services/worker/SessionMessageBuffer.ts) deliberately keeps pending observer work in RAM after earlier retry storms. A worker crash loses that buffer. FactsBook needs durable immutable captures, stage receipts and idempotent proposal creation; replaying a nondeterministic model is not replaying signed state.

- **Assuming bounded prompts mean bounded storage or measured savings.** Raw tool I/O has a durable side index; awareness logs accumulate; history pruning only reduces model history. [Ingest](claude-mem/src/services/worker/http/shared.ts:243). Apply separate retention rules to captures, evidence, caches and diagnostics. [TokenCalculator.ts](claude-mem/src/services/context/TokenCalculator.ts) estimates reading cost from characters and compares it with discovery tokens; that is not measured counterfactual savings.

- **Importing the vector stack now.** Chroma brings a Python/MCP subprocess, model/runtime dependencies and storage-version compatibility work. [ChromaMcpManager.ts](claude-mem/src/services/sync/ChromaMcpManager.ts). Preserve D21/spec 11’s multilingual and device gates.

**5. How FactsBook should give agents memory**

claude-mem’s startup context is primarily **recent project memory**, filtered by type/concept/platform, with summaries; defaults request 50 observations and 10 sessions before budget reduction. Query-based semantic injection is separately experimental and disabled. [ObservationCompiler.ts](claude-mem/src/services/context/ObservationCompiler.ts), [defaults](claude-mem/src/shared/SettingsDefaultsManager.ts:447). FactsBook should select by the current job and authorized areas, then consider relevance, validity, review state and recency.

Proposed contract extensions below are recommendations, not existing APIs or approved numerical defaults. Keep the agent context packet distinct from the user’s scheduled `get_brief`.

| Stage | What the agent receives | Initial evaluation budget |
|---|---|---|
| **Brief** | Task scope, freshness/index status, capability limits, and up to eight relevant fact cards. Each card includes full fact ID, revision, short claim, provenance, source/date and dispute/expiry flags. | 800 tokens |
| **Search** | Extend `search_things`/`job_search` with compact projection, budget and continuation; return up to ten authorized cards with estimated expansion cost. | 1,000 tokens/response |
| **Expand** | Selected facts through bounded `get_thing`/internal equivalents; optional timeline for changes or contradictions. | Three facts, 2,000 tokens/response |
| **Evidence** | Explicit authorized source spans, source revision/hash and support linkage; clearly distinguish source assertions from verified truth. | Within a 4,000-token cumulative retrieval budget/turn |

Use provider tokenizers where available, otherwise marked conservative estimates plus a hard byte limit. Drop whole cards; return truncation/status explicitly. Permit direct authorized expansion of an already-known fact ID; a mandatory three-call ceremony can cost more than it saves.

Bind continuations to caller, run, vault, policy and expiry. Recheck current permissions, lock state and fact revision on every expansion. F110 filtering applies **before** candidates, ranking, counts, snippets and graph hops. Titles, IDs and token-cost estimates can themselves disclose sensitive information.

For D36 roles:

- **Extractor:** one selected minimized item plus a closed candidate-thing list; Mode A, no retrieval tools or general profile.
- **Decider/Jev:** the specific closed question and smallest sufficient normal-data context; explicit abstention.
- **Gardener:** node-selected comparison sets with original support and conflicting versions; proposals only.
- **Scout:** only its approved watch projection and brokered sources; no incidental personal-memory expansion.
- **Brief:** authorized approved facts/findings, user cap and feedback; clearly separated pending proposals.
- **Conversation offers:** a minimized fenced summary and narrowly scoped read tools; actions remain approval cards.

For D37: **consented collection → on-phone minimization/classification → sender + subject + ~300 characters to selected Jev role → important normal items to the selected reader/extractor → validated proposals → owner review**. Sender and subject require minimization too; spoofable sender text establishes no authority. Sensitive or uncertain captures never reach Jev, and redaction alone does not make sensitive-derived text normal.

Include synthetic examples where the decisive detail appears after character 300. Jev must be able to return “insufficient context”; triage must not silently discard potentially important mail. Initially the node supplies bounded additional normal text to a tool-less reader; autonomous reading tools remain behind spec 33 Mode B qualification.

**6. What to borrow from their evals**

The inspected `evals/` suite tests a **file-read gate**, not general memory truth, extraction quality or privacy. Its reported results are repository evidence, not independently rerun results here. [Eval README](claude-mem/evals/read-gate/README.md), [runner](claude-mem/scripts/eval-read-gate.ts).

- **Paired experiments:** identical seeded inputs with progressive retrieval on/off; include small inputs where extra calls cost more. Their history documents precisely that regression.
- **Prove the tested path ran:** require evidence that the adapter, refusal or expansion was actually exercised. “No forbidden action occurred” is weak if none was attempted.
- **Prevent answer leakage:** their seed observations omit the exact requested values. FactsBook fixtures should require retrieving the right fact revision and support.
- **Reject incomplete campaigns:** missing runs, errors and missing cost data must not become passes. Retain exact versions, configuration, traces and machine-readable verdicts.
- **Use independent deterministic oracles:** fact IDs, support spans, expected proposals, forbidden byte sequences and state transitions; do not rely solely on a model judge.
- **Add FactsBook-specific cases:** EN/AR/code-switching, negation, namesakes, changing facts, assistant echoes, injected mail, misleading subjects, truncated previews, sensitive metadata, revoked permissions, lock changes, replay and stale review cards.
- **Apply spec 32 §6’s stronger qualification:** separate calibration and held-out sets; report per-class precision/recall with intervals, abstention, severity, latency and cost. Measure Jev false-negative triage and resulting review burden. Their two/three-run task checks cannot establish rare-error safety.
- **Include security and durability campaigns:** verify every retained plaintext representation, actual adapter tool denial, cross-role isolation and recovery—consistent with Astra B6 §6. Their [tool-enforcement tests](claude-mem/tests/security/observer-tool-enforcement.test.ts) and [progressive-search adversarial tests](claude-mem/tests/worker/progressive-search-adversarial.test.ts) provide useful patterns.

**7. Top eight recommendations, ranked**

1. **Transport:** after independent core acceptance, keep verified closure, rollback protection and authenticated readback as the first gate; copy no raw worker database/spool sync design.
2. **Roles/Jev:** qualify explicit per-role selection, actual tool denial, locality, cancellation and shared budgets before enabling providers.
3. **Roles/Jev:** build the synthetic held-out evaluation gate with per-class calibration, abstention and non-vacuous execution checks.
4. **Roles/Jev → client:** add budgeted fact cards, selective expansion and complete fact/source citations under F110.
5. **D37 Gmail pipeline:** minimize on-phone before retention/egress; add preview-insufficiency handling and durable source-revision dedupe.
6. **Gardening:** retain supported atomic claims through compression; model output creates validated review proposals, never direct facts.
7. **Gardening:** prevent generated-memory feedback, bound retries and storage, and resume from durable item-level receipts.
8. **Client:** show capped, expiring awareness pointers with “why shown,” provenance, review state and feedback; retain explicit source access.