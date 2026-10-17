# Astra — ideas from hindsight for OpenCode Mobile and FactsBook (2026-10-12)

**Recommendation: borrow Hindsight’s evidence, retrieval, and refresh patterns; keep each product’s existing authority and storage model.** OpenCode Mobile needs project memory that reduces repeated steering. FactsBook needs personal knowledge whose origin, uncertainty, and owner approval remain intact.

Read-only review of Hindsight commit `a9eeed77f9bc`. No files changed, dependencies installed, or project code/tests run. Product mappings use the current checkouts. FactsBook’s B7 review was absent; I read B6 and the B7 builder report, which still records independent acceptance as pending. Effort: **S** bounded addition, **M** integrated feature, **L** substantial subsystem and qualification.

**1. What Hindsight is — five lines**

- An MIT-licensed service for persistent agent memory; “learning” means updating stored knowledge, rather than training model weights.
- **Retain** extracts attributed facts, entities, relationships, and dates from supplied material.
- **Recall** combines semantic, keyword, graph, and temporal retrieval within a configurable budget.
- **Observations** consolidate facts into evolving beliefs; **mental models** answer standing questions; **knowledge pages** organize those answers into a wiki.
- **Reflect** runs an evidence-seeking model loop over those layers and returns a synthesized answer with citations.

Architecture:

- Python/FastAPI engine, REST/MCP interfaces, generated clients, Rust CLI, and Next.js control plane: [CLAUDE.md](hindsight/CLAUDE.md).
- PostgreSQL/pgvector, with Oracle support; documents/chunks underpin facts, entities, links, and derived knowledge.
- Configurable extraction, embedding, reranking, and reflection providers; local hosting does not itself guarantee local inference.
- Durable asynchronous operations and workers handle extraction/consolidation/refresh: [worker/poller.py](hindsight/hindsight-api-slim/hindsight_api/worker/poller.py).
- Coding-agent integrations collect project history and conversations across harnesses: [coding-agents/README.md](hindsight/hindsight-integrations/coding-agents/README.md).

**2. OpenCode Mobile — ADOPT / ADAPT / AVOID**

These map through `lib/domain/`, existing controllers, and kit components; memory must not bypass backend-specific capabilities.

**ADOPT**

- **Evidence-bearing project memory.** Remember owner corrections, architectural decisions, and verified outcomes with repository, session, harness, commit, and source references. Show them in AI Team task details and worker handoffs. Hindsight preserves source/harness attribution and distinguishes speakers ([integration README, “Recording where a memory came from”](hindsight/hindsight-integrations/coding-agents/README.md:1011)). **Value:** fewer repeated corrections across Claude/Codex/OpenCode/Pi. **M**.
- **Bounded, inspectable context retrieval.** Add “Suggested project context” beside planned Tidy/@files, opening source previews before attachment. Keep search effort separate from returned-context size, as in [retrieval.md](hindsight/hindsight-docs/docs/developer/retrieval.md:127). Map to chat composer, `active_context`, and `KitContextRing`; count the complete serialized payload. **Value:** useful context without silently consuming the conversation window. **M**.
- **Freshness and dependency tracking.** Attach source revisions and “checked through commit…” to project summaries; changes invalidate affected summaries. Hindsight tracks scoped freshness and retains prior mental-model versions ([mental-models.mdx](hindsight/hindsight-docs/docs/developer/mental-models.mdx)). Map to AI Team digest, task restart, and `KitLastKnown`. **Value:** agents stop treating yesterday’s constraints as current. **M**.

**ADAPT**

- **One project memory across agents, with stronger identity.** Hindsight shares a worktree-aware repository bank across harnesses ([bank resolution](hindsight/hindsight-integrations/coding-agents/README.md:990)). Use stable profile/repository IDs, plus branch/task/commit provenance; a repository basename is insufficient. Integrate through `AgentToolAdapter` and a capability-gated memory interface. **Value:** coherent handoffs without cross-project contamination. **M**.
- **Knowledge pages as project reference views.** Offer Architecture, Decisions, and Runbook pages in the project workspace, searchable and optionally attached to chat. Hindsight pages are derived, incrementally refreshed, and cannot read other pages ([knowledge-pages.mdx](hindsight/hindsight-docs/docs/developer/knowledge-pages.mdx)). Preserve the approved AI Team spec separately; generated pages cannot amend it. **Value:** fast orientation without another narrating lead agent. **M**.
- **Coalesced background refresh.** Borrow “one active refresh plus one pending follow-up” from [test_33_refresh_dedupe.py](hindsight/hindsight-system-tests/tests/test_33_refresh_dedupe.py). Implement through existing durable jobs, work leases, budgets, and Android lifecycle handling; defer when chat is busy or resource evidence is unavailable. **Value:** fewer redundant calls and recoverable interruptions. **M**.

**AVOID**

- **Automatically remembering and injecting everything.** The integration defaults to project-wide capture and offers automatic injection; its explicit opt-in mode is the better starting point ([integration README](hindsight/hindsight-integrations/coding-agents/README.md:598)). Keep capture owner-controlled. Phrase chips should remain the person’s own phrases; inferred memory belongs in a separately labelled suggestion. **Value:** predictable chat and privacy. **S**.
- **Turning agent claims into execution truth.** Hindsight’s observations reconcile conflicting claims, while reflect applies dispositions ([observations.mdx](hindsight/hindsight-docs/docs/developer/observations.mdx), [reflect.mdx](hindsight/hindsight-docs/docs/developer/reflect.mdx)). AI Team must continue deriving “checked,” “merged,” and “promoted” from its receipts and exact commits. Memory may explain a result, never authorize a merge or approval. **Value:** preserves trustworthy status. **S**.
- **Bundling the desktop daemon model into the phone runtime.** Hindsight’s integration starts a persistent daemon, downloads dependencies, and defaults `embedVersion` to `latest` ([daemon mode](hindsight/hindsight-integrations/coding-agents/README.md:507)). Start with lightweight local records or an explicitly configured host service. **Value:** avoids an unqualified database/model stack competing with coding agents. Full phone integration would be **L**.

**3. FactsBook — ADOPT / ADAPT / AVOID**

Several ideas reinforce existing contracts rather than requiring new product decisions.

**ADOPT**

- **Preserve attribution and two kinds of time.** Hindsight separates when something happened from when it was learned, and distinguishes the agent’s experience from somebody else’s statements ([retain.md](hindsight/hindsight-docs/docs/developer/retain.md)). Apply to specs **10/30/40**, D24–D25: retain speaker, source span, capture date, and valid time. **Value:** an email sender’s claim or an assistant’s suggestion cannot silently become something the owner said. **S–M**.
- **Make “not stated” a valid extraction result.** Hindsight documents fabricated dates/owners caused by required non-null fields ([test_fact_extraction_nullable_dimensions.py](hindsight/hindsight-api-slim/tests/test_fact_extraction_nullable_dimensions.py)). Apply to **D36/D37**, specs **30/32/33**: nullable fields, abstention, and deterministic subject/span checks. **Value:** fewer plausible but invented personal facts and reminders. **S**.
- **Test authorization through evidence expansion.** Hindsight’s [test_81_source_text_scope.py](hindsight/hindsight-system-tests/tests/test_81_source_text_scope.py) tests a shared fact whose source document contains private material. Extend specs **11/24/50**, D26, and `CallerContext` tests to snippets, source reads, links, summaries, exports, and counts. **Value:** sharing a work fact does not reveal its health-related source paragraph. **M**.

**ADAPT**

- **Observations become reviewable hypotheses.** Borrow grouped evidence and contradiction detection from [observations.mdx](hindsight/hindsight-docs/docs/developer/observations.mdx), but produce Memory care proposals under **D23, spec 30, contracts §3.9**. Preserve both conflicting claims until the owner decides. Deduplicate corroboration by source lineage; copied emails and assistant echoes are not independent support. **Value:** cleaner memory without automatic belief changes. **M**.
- **Mental models become derived person/area summaries.** Use approved facts to build “What should I know about this thing?” views, with source links, revision history, and visible staleness ([mental-models.mdx](hindsight/hindsight-docs/docs/developer/mental-models.mdx)). Touch specs **10/11/30/60**, D4/D25/D26. Summaries cannot support new facts; edits proposing factual changes enter review and signed history. **Value:** readable overviews without creating a competing source of truth. **M**, after basic memory.
- **Stage D37 ingestion with durable identities and bounded work.** Hindsight imports conversations by document ID, batches missing work, and reports whether extraction is queryable ([ingestion internals](hindsight/hindsight-integrations/coding-agents/README.md:1098)). Map to specs **20/21/33/40**, D36/D37: collect → local minimization → Jev header triage → selected normal-item extraction → review. Record each stage separately; retries preserve identity and spend reservations. **Value:** no duplicate proposals or hidden mailbox-processing costs. **M**.
- **Borrow hybrid retrieval only at the existing later gate.** Hindsight’s rank fusion and temporal retrieval are useful candidates ([retrieval.md](hindsight/hindsight-docs/docs/developer/retrieval.md)). Keep **spec 11/D21** FTS-first; compare FTS, Arabic-friendly alternatives, and local vectors before adopting reranking or graph expansion. **Value:** measurable search improvement with a working offline baseline. **L** for the qualified enhancement.

**AVOID**

- **Automatic fuzzy identity merges or “proof count” as confidence.** Hindsight resolves similar names and boosts observations with more supporting memories ([entity_resolver.py](hindsight/hindsight-api-slim/hindsight_api/engine/memories/pg/entity_resolver.py), [retrieval scoring](hindsight/hindsight-docs/docs/developer/retrieval.md:321)). Under **specs 10/30/32**, two Sams or two similar accounts require resolution proposals; repetition cannot establish truth. **Value:** prevents damaging personal-data merges. **S** to preserve the boundary.
- **Using Hindsight as the authoritative vault or its history as signed history.** Its database-backed memory and generated Markdown projections serve a different contract ([knowledge-pages.mdx](hindsight/hindsight-docs/docs/developer/knowledge-pages.mdx)). Preserve **D4/D8/D24/D34**, spec **10**, and contracts **§3–4**: Rust node, authoritative files, verified operations, and owner review. **Value:** keeps recovery, provenance, and client neutrality intact. Replacement would be **L** and contrary to current decisions.

**4. Security and privacy lessons for both**

- **Local server does not mean local data processing.** Hindsight defaults to OpenAI for its LLM and local embedding/reranking providers; all are configurable ([config.py](hindsight/hindsight-api-slim/hindsight_api/config.py)). Extraction sends source content to the selected model; reflection sends questions and retrieved evidence; remote embedding/reranking sends text too. Document each route in both products’ egress policy.
- **Minimize before crossing the first boundary.** Server-side redaction cannot undo upload to a remote memory server. For OpenCode Mobile, minimize before transcript/context export. For FactsBook, scan D37 sender, subject, and preview as well as the body; sensitive or uncertain items stay local, and only eligible important items reach the selected extraction role.
- **Borrow the scanner placement, not its assurance level.** Hindsight’s regex defense is disabled by default and is not retroactive ([memory-defense/index.md](hindsight/hindsight-docs/docs/developer/memory-defense/index.md)). Its retain implementation screens content before extraction ([orchestrator.py](hindsight/hindsight-api-slim/hindsight_api/engine/retain/orchestrator.py:1621)). Both products need coverage of metadata, queues, diagnostics, old copies, and exports too; a regex match set does not prove absence of secrets.
- **Prompts are not permission enforcement.** Hindsight calls directives “hard rules,” but they steer model reasoning ([reflect.mdx](hindsight/hindsight-docs/docs/developer/reflect.mdx)). Repository text, emails, retrieved facts, and summaries remain untrusted. Enforce tools, scope, egress, and writes outside the model. FactsBook extraction stays proposal-only; outward actions retain exact owner approval.
- **Authentication and scope must be mandatory.** Hindsight’s default tenant accepts requests without authentication ([tenant.py](hindsight/hindsight-api-slim/hindsight_api/extensions/builtin/tenant.py)). A bank name or tag is not caller authority. Preserve pairing and scoped capabilities; test import/export and direct-ID reads as well as search.
- **Keep the products’ memory separate.** The same owner does not authorize coding agents to browse personal memory. Any FactsBook context shared into chat needs an explicit, area-scoped projection; it must not subsequently enter a project memory bank by automatic capture.
- **Pin the complete supply chain.** Avoid floating daemon versions, inherited provider selection, and automatic plugin configuration. Pin binaries/models/dependencies and review their notices separately from Hindsight’s root MIT license. Keep keys in existing secure stores. Hindsight’s diagnostic events can contain queries ([logging documentation](hindsight/hindsight-integrations/coding-agents/README.md:1141)); adopt structural, redacted diagnostics rather than copying that payload.

**5. Evals and tests worth borrowing**

- **Blackbox composition tests:** [hindsight-system-tests/README.md](hindsight/hindsight-system-tests/README.md) uses the published client against a real service with strict provider stubs; unexpected calls fail. Borrow for capture → proposal → review → restart → recall, and AI Team handoff → correction → fresh context.
- **Deterministic concurrency:** use held provider responses to test in-flight work. Borrow refresh deduplication, [read-only preview](hindsight/hindsight-system-tests/tests/test_32_refresh_safety.py), [concurrent deletion](hindsight/hindsight-system-tests/tests/test_75_delete_concurrency.py), and [bank-scoped import](hindsight/hindsight-system-tests/tests/test_83_bank_scoped_import.py). Add revocation and Android interruption cases.
- **Longitudinal truth tests:** [system-evals/README.md](hindsight/hindsight-system-evals/README.md) covers facts arriving in waves, lost older knowledge, incorrect accumulated counts, absent information, language drift, subject confusion, and authoritative sources versus recent chatter. These directly strengthen FactsBook specs 30/32 and AI Team decision memory.
- **Separate retrieval failure from reasoning failure:** record whether the correct evidence reached the model; grade correctness and specific false claims separately. Use an independent judge for language quality, deterministic checks for authorization/signatures/commits, and human-labelled synthetic cases for consequential errors.
- **Measure complete cost:** Hindsight’s refresh-cost suite found that text-only budgets missed substantial JSON overhead. Compare actual input/output tokens, serialized bytes, latency, calls, and refresh frequency; add phone RAM, battery, and restart costs.
- **Borrow benchmark methods, not headline scores:** LoComo, LongMemEval, BEAM, PersonaMem, and coding tasks are delegated to AMB; its default ref floats, so pin the resolved commit and dataset/model/prompt versions. For OpenCode Mobile, prioritize corrections per task and total cost. For FactsBook, prioritize false facts/merges, abstention, source/date coverage, stale-answer rate, and English/Arabic retrieval. Public benchmark success cannot qualify either product’s privacy or approval boundaries.

**6. Ranked recommendations and fitting slices**

The slice names below are proposed work packages, not new milestone approvals.

**OpenCode Mobile**

1. **Project evidence ledger — AI Team handoff slice:** retain owner decisions and receipt-backed outcomes with stable source IDs. **M**
2. **Visible context suggestions — smart-input Tidy/@files slice:** preview, attach, remove, and budget recalled context before Send. **M**
3. **Scoped cross-agent memory — agent-adapter slice:** explicit project opt-in, stable repository identity, qualified per-agent access. **M**
4. **Fresh project summaries — AI Team digest slice:** versioned Decisions/Runbook views with stale-source detection. **M**
5. **Bounded refresh jobs — phone-runtime slice:** coalescing, durable checkpoints, cancellation, and measured resource admission. **M**
6. **Memory-on/off acceptance — pilot QA slice:** compare corrections, correctness, cost, leakage, and interruption recovery before wider enablement. **M**

**FactsBook**

1. **Complete admission acceptance — B7 core gate:** carry scanner counterexamples through every retained copy and future D37 outbound projection. **M**
2. **Evidence-safe extraction — D36 Roles/Jev slice:** nullable output, explicit role selection, subject/span validation, staged proposals only. **M**
3. **End-to-end scope tests — v1 API/MCP acceptance:** include source expansion, derived views, counts, imports, and revocation. **M**
4. **Qualify Jev on longitudinal synthetic cases — D36/spec 32 gate:** measure false acceptance, abstention, language fidelity, and actual cost. **M**
5. **Durable email stages — D37 email-first slice:** minimize locally, triage headers, extract selected normal items, review; no Gmail write-back. **M**
6. **Sourced thing/area summaries — post-v1 memory-care slice:** derive from approved facts, expose freshness, prevent recursive evidence, preserve signed history. **M**

