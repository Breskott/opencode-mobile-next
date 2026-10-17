# Astra — ideas from paperclip for OpenCode Mobile and FactsBook (2026-10-12)

**Borrow Paperclip’s execution controls; keep each product’s own purpose and trust model.** OpenCode Mobile benefits most from stronger coordination and recovery. FactsBook benefits most from bounded decisions, provenance, and review receipts.

Read-only review of Paperclip at `bfe7c63`; no files changed, dependencies installed, project code or tests run. Findings below are source-based. Effort: **S** = focused change, **M** = several components, **L** = substantial integration and qualification.

**1. What Paperclip is — five lines**

- An MIT-licensed control plane for companies staffed by AI agents.
- It connects company goals, projects, tasks, agents, and reporting relationships.
- It invokes agents through adapters and tracks runs, outputs, usage, and costs.
- It gives humans approvals, pause controls, budget enforcement, and an activity history.
- Its strongest transferable ideas are durable work ownership and governed execution—not the corporate metaphor.

Architecture:

- **Control plane:** TypeScript/Express services in `server/`; React board UI in `ui/`.
- **Persistence:** PostgreSQL/Drizzle in `packages/db/`; shared types and validation in `packages/shared/`; local or object storage for artifacts.
- **Execution:** adapters in `packages/adapters/`; shared transport utilities in `packages/adapter-utils/`; a Rust production runner and versioned protocol in `packages/paperclip-runner/`.
- **Coordination:** scheduling, run recovery, task checkout, approvals, budgets, and delivery queues live in server services. Evidence: [V1 specification](paperclip/doc/SPEC-implementation.md), [runner architecture](paperclip/packages/paperclip-runner/README.md).

**2. OpenCode Mobile — ADOPT / ADAPT / AVOID**

The existing [phone-engine contract](oc_app/docs/design/aiteam-inapp-engine-2026-09-30.md) already specifies request IDs, revision checks, role snapshots, isolated workers, merge receipts, and cautious recovery. Recommendations below extend or harden those controls.

- **ADOPT — Reserve budget before starting work.** Paperclip holds reservations across timeouts/restarts and reconciles durable usage receipts, including failed runs. Map to AI Team admission, project budgets, and Usage details. Show spent, reserved, estimated, and unknown separately. **Value:** parallel workers cannot each spend the same remaining allowance. **M.** Evidence: [budget-reservations.ts](paperclip/server/src/services/budget-reservations.ts), [run-cost-accounting.ts](paperclip/server/src/services/run-cost-accounting.ts). Reservations constrain admission; they cannot guarantee a provider’s final bill.

- **ADOPT — One authoritative approval record across screens.** Chat and Inbox should resolve the same request, bound to exact arguments or the exact diff/commit being approved. Keep human decision, execution, and outcome separate; dismissal must not mean rejection. **Value:** prevents stale approvals and double execution after reconnect. **M.** Map to permission cards, `KitNeedsYou`, diff review, and promotion confirmation. Evidence: [tool-action-review.ts](paperclip/server/src/services/tool-action-review.ts), [TASK-REVIEWS.md](paperclip/doc/connections/TASK-REVIEWS.md).

- **ADOPT — Fence ownership by task and run identity.** A worker’s name is insufficient: ownership needs the current run/generation, atomic claim, and guarded release. A stale worker must not finish or release its successor’s task. **Value:** safer parallel lanes and restart recovery. **M.** Map to the Rust phone engine, worker sessions, and merge queue; retain the app’s stronger checked-SHA merge/promotion rules. Evidence: [issues.ts](paperclip/server/src/services/issues.ts), V1 specification §10.4.1.

- **ADAPT — A small, explicit adapter contract.** Borrow capability negotiation, normalized events, cancellation, usage receipts, and resume compatibility. Keep these behind `ServerGateway`/`ServerCapabilities`; do not transplant Paperclip’s entire runtime. Preserve selected provider/model identity and reject incompatible resumes. **Value:** consistent Claude/Codex/Pi/OpenCode behavior without pretending they support identical features. **M.** Evidence: [runner README](paperclip/packages/paperclip-runner/README.md), [protocol fixtures](paperclip/packages/paperclip-runner/protocol/fixtures).

- **ADAPT — Durable recovery with visible uncertainty.** Borrow persisted continuation receipts, bounded retry budgets, and proof that previous execution stopped. For Android, checkpoint and explain “interrupted,” “waiting,” or “needs reconciliation”; do not blindly resend uncertain prompts or commands. **Value:** preserves user intent and avoids duplicate work. **L.** Map to `lib/background/`, `ConnectionController`, and AI Team recovery. Evidence: [runner recovery contract](paperclip/tests/runner-recovery/README.md), [durable-chat-wakeup.ts](paperclip/server/src/services/durable-chat-wakeup.ts).

- **ADAPT — Context attached to work, with bounded handoffs.** Paperclip’s fresh-session handoff carries source identities, bounded excerpts, and omission markers; plan handoffs retain the accepted revision. Use this for planned Tidy, `@files`, context awareness, and worker delegation. Phrase chips should prepare editable intent, not silently expand permissions. **Value:** less repeated context and fewer accidental scope changes. **M.** Map to the chat composer, context sheet, plan card, and worker instructions. Evidence: [runner README](paperclip/packages/paperclip-runner/README.md), [handoff-plan-context.ts](paperclip/server/src/services/native-runtime/handoff-plan-context.ts).

- **ADOPT — Inspectable results with receipts.** Bind outputs to task, run, workspace, revision, and—where appropriate—file hash. Distinguish a workspace reference from a durable accessible artifact. **Value:** the phone user can open the actual diff, report, or screenshot behind “done.” **M.** Map to task conversation result cards, Files, review, and merge receipts. Evidence: [AGENT-ARTIFACTS.md](paperclip/doc/AGENT-ARTIFACTS.md), [work-products.ts](paperclip/server/src/services/work-products.ts).

- **AVOID — CEO/org-chart-first UX.** Paperclip’s company → employees → reporting tree suits its product. OpenCode Mobile should retain goal → conversation → plan → workers → checked result, with “Needs you” first. **Value:** avoids a second management application inside a phone app. **S** to preserve this design boundary. Evidence: [PRODUCT.md](paperclip/doc/PRODUCT.md); consistent with the app’s AI Team redesign.

- **AVOID — Server-shaped execution defaults on phones.** Do not copy a permanently running scheduler, desktop database stack, or Paperclip’s documented default of 20 concurrent runs per agent. **Value:** protects memory, battery, and foreground-service time. **M** for explicit mobile admission limits. Evidence: V1 specification §§6, 11.6. Android’s applicable `dataSync` background limit is six hours per 24-hour period; hosting must tolerate suspension. [Android documentation](https://developer.android.com/develop/background-work/services/fgs/timeout)

**3. FactsBook — ADOPT / ADAPT / AVOID**

D36/D37 take precedence over older spec tables still deferring Jev/Gmail. No requested B7 independent review was present; I read B6 and the B7 builder report. B7 reports local repairs, with independent acceptance pending and roles/Jev still disabled.

- **ADOPT — Per-job execution snapshots.** For each role invocation, record the selected adapter, exact model, template/schema versions, locality decision, budget handle, and input references. Changing the Roles screen must not silently alter an admitted job. **Value:** reproducibility and enforceable sensitive routing. **M.** Touches **D36, specs 32/33, contract capability registry**. Evidence: [runner compatibility and identity rules](paperclip/packages/paperclip-runner/README.md). Keep “none” valid; never auto-select a replacement.

- **ADAPT — Paperclip’s actual Jev integration as an adapter reference.** This checkout uses `typesafe/jev-1.13` through OpenRouter and separates typed answers from accounting receipts; malformed answers and refusals can still incur charges. Borrow those failure semantics, bounded error handling, and tests. **Value:** avoids treating invalid output as either a decision or a free request. **M.** Touches **D36, spec 32 interface/evals, spec 33 Mode A**. Evidence: [decision-model-provider.ts](paperclip/server/src/services/decision-model-provider.ts), [model declarations](paperclip/packages/shared/src/decision-models.ts). This does not qualify FactsBook’s provider route or require adopting OpenRouter.

- **ADOPT — Reservations and unresolved-cost accounting within the existing hierarchy.** Use one ledger for triage, extraction, gardening, retries, and conversation offers; retain reservations when a request’s charge is unknown. **Value:** daily source caps cannot be bypassed by nested jobs. **M.** Touches **D28/D29/D37, contract §9, specs 21/32/33/44**. Evidence: [budget-reservations.ts](paperclip/server/src/services/budget-reservations.ts). Preserve FactsBook’s **$0 means no spending**: Paperclip’s [budgets.ts](paperclip/server/src/services/budgets.ts) disables enforcement for non-positive policy amounts.

- **ADAPT — Durable pipeline stages with source-based identity.** Carry one source identity through collect → minimize → triage → read → propose → review, with separate stage receipts and policy/model versions. Resume from the last proven stage; do not reprocess every email after restart. **Value:** deduplication, explainable omissions, and traceable proposals. **M.** Touches **D37, specs 40/30/21, contract §3.5**. Evidence: Paperclip’s [triage provenance design](paperclip/doc/DATABASE.md:327) and [durable delivery service](paperclip/server/src/services/durable-chat-wakeup.ts). Its queue sidecars reference sources without copying their bodies.

- **ADOPT — One review identity, multiple presentations.** A proposal shown in Memory care, a thing’s detail, or Inbox must resolve the same signed review operation. Revalidate source/target revisions; keep “approved” distinct from “applied.” **Value:** no stale-card commits or contradictory review states. **M.** Touches **D23/D25, contract §3.9, specs 30/60**; outward actions remain separately governed by **§6/spec 42**. Evidence: [tool-action-review.ts](paperclip/server/src/services/tool-action-review.ts). Retain FactsBook’s existing owner signature and digest requirements.

- **ADAPT — A unified attention queue without duplicating private content.** Borrow stable attention identities, snooze state, and authorization rechecks when reading a source. Display review proposals, failed captures, blocked jobs, and reminders through their own existing contracts. **Value:** one useful Memory inbox without conflating “review this fact” with “answer this question.” **M.** Touches **D25/D27/D32, specs 24/43/60**. Evidence: [decision-queues.ts](paperclip/server/src/services/decision-queues.ts), database documentation §“Decision queues and triage provenance.”

- **AVOID — An autonomous company inside a personal memory.** Areas are privacy scopes; roles are bounded jobs. They should not become departments, self-hiring agents, or managers permitted to rewrite personal history. **Value:** keeps FactsBook understandable and review-first. **S.** Touches **D17/D23/D26/D36, specs 30/33**. Evidence: Paperclip’s deliberately different [company and employee model](paperclip/doc/PRODUCT.md).

- **AVOID — Broad remembered permissions and open skill mutation.** Paperclip’s “Always allow” can permit future argument values for an action; ordinary company skill editing is open by default unless restricted. Neither belongs in FactsBook v1. **Value:** an email cannot expand future authority through agent-generated instructions. **S** for the policy boundary. Touches **D13/D23/D37, specs 33/42/50**. Evidence: [TASK-REVIEWS.md](paperclip/doc/connections/TASK-REVIEWS.md), [PRODUCT.md](paperclip/doc/PRODUCT.md). Gmail remains read-only, labels local, facts proposed only.

- **AVOID — Treating an activity table as signed history.** Paperclip’s activity rows are useful attribution records, but that schema is not FactsBook’s signed, hash-linked operation protocol. **Value:** preserves replay validation, owner attestations, and verified Move checkpoints. **S** to preserve the boundary. Touches **D22 and contract §§3–4**. Evidence: [activity_log.ts](paperclip/packages/db/src/schema/activity_log.ts). Keep SQLite projections subordinate to the relevant signed authority.

**4. Security and privacy lessons for both**

- **Local hosting does not mean local-only processing.** Paperclip can send prompts to model providers, workspaces to remote execution, artifacts to configured storage, and actions to connectors. Its first-party Telemetry is enabled by default outside suppression conditions and targets Paperclip endpoints. OpenTelemetry is separate and requires an operator endpoint; run-log rows remain in the instance database. Evidence: [telemetry config](paperclip/packages/shared/src/telemetry/config.ts), [client](paperclip/packages/shared/src/telemetry/client.ts), [instrumentation](paperclip/server/src/instrumentation.ts). Neither product should inherit opt-out analytics incidentally.

- **Do not let hostile output become trusted instructions.** Paperclip’s low-trust mode intersects scopes and quarantines output before higher-trust continuation. Apply this to repository content and worker reports in OpenCode Mobile, and email/body/subject content in FactsBook. Delimiters help; enforced tool and data restrictions provide the boundary. Evidence: [LOW-TRUST-PRESETS.md](paperclip/doc/LOW-TRUST-PRESETS.md). FactsBook v1 should retain tool-less extraction; proot alone does not provide isolation.

- **Minimize before any hosted call, including triage.** Sender, subject, and 300 characters can disclose health, money, identity, or credentials. Under D37, unknown/sensitive material stays local; removing a number does not automatically make the remaining message normal. Recheck before full-item reading. Paperclip’s bounded provider-error handling is useful, but its home-path masking is not a personal-data classifier. Evidence: [decision-model-provider.ts](paperclip/server/src/services/decision-model-provider.ts), [log-redaction.ts](paperclip/packages/adapter-utils/src/log-redaction.ts).

- **Keep secrets outside instructions and configuration snapshots.** Borrow secret references, narrow credential bindings, and redaction across failure paths. Retain Android Keystore and FactsBook’s prohibition on putting the Jev key in environment variables. Paperclip supports environment-based credentials and a local master-key file; those are deployment choices, not phone defaults. Evidence: [DEVELOPING.md, Secrets in Dev](paperclip/doc/DEVELOPING.md:1864).

- **Treat remote addresses and installed capabilities as security boundaries.** Paperclip documents DNS-pinned HTTP requests, redirect refusal, exact private-endpoint allowances, and immutable skill snapshots. Apply equivalent checks to connectors, agent packages, and prompt packs; never install or activate capabilities because imported content requests them. Evidence: [HTTP adapter rules](paperclip/doc/DEVELOPING.md:1918), [skill snapshot tests](paperclip/server/src/__tests__/skill-source-git-snapshot.test.ts). Preserve MIT notices for copied portions and audit dependencies separately.

**5. Tests and benchmarks worth borrowing**

- **Approval race matrix:** duplicate taps, two screens, dismissal/reopen, changed arguments/schema, revoke-before-dispatch, restart while waiting, and unknown outcome. Assert actual provider invocation counts—especially zero after rejection. Borrow [connection-review workflows](paperclip/doc/connections/TASK-REVIEWS.md); adapt to mobile permission cards and FactsBook signed reviews.

- **Accounting fault matrix:** concurrent reservations, late receipts after cancellation, charged refusals, malformed output with usage, unknown price, and repeated settlement. Borrow [heartbeat-cost-accounting.test.ts](paperclip/server/src/__tests__/heartbeat-cost-accounting.test.ts), [decision-model-provider.test.ts](paperclip/server/src/__tests__/decision-model-provider.test.ts). Add FactsBook’s explicit $0 prohibition.

- **Controlled recovery tests:** establish old-process ownership, pending effects, saved work, and retry allowance before deciding whether a successor is safe. Borrow [tests/runner-recovery](paperclip/tests/runner-recovery/README.md). Extend with Android service timeout and app-death cases; arbitrary process killing is not proof of safe recovery.

- **Adapter conformance:** duplicates, event gaps, unsupported required versions, oversized output, permission waits, cancellation, and identity changes. Borrow [protocol fixtures](paperclip/packages/paperclip-runner/protocol/fixtures) and [acceptance catalog boundaries](paperclip/tests/runner-acceptance/README.md). A registered adapter is not a qualified adapter.

- **Prompt-injection and decision-quality evals:** borrow [low-trust red-team tests](paperclip/server/src/__tests__/low-trust-red-team-routes.test.ts) and [eval case structure](paperclip/evals/README.md). FactsBook needs synthetic English/Arabic emails, quoted instructions, negation, similar people, sensitive headers, and secret-bearing identifiers. Measure precision/recall, abstention, sensitive egress, latency, and total cost; model confidence must never authorize a fact commit.

- **Long-chat performance:** borrow the fixture shape of 200 long replies, 4,000 tool entries, and a live tail updating ten times per second from [task-chat benchmark](paperclip/tests/perf/task-chat/README.md). Measure Flutter frame time, memory, typing, reading-position stability, and lazy expansion on representative phones; do not reuse Chromium thresholds as mobile acceptance.

**6. Ranked recommendations**

Slice names below are proposed groupings, not newly approved milestones.

**OpenCode Mobile**

1. **AI Team budget hardening — M:** reserve before dispatch; reconcile failures and unknown usage across restarts.
2. **Approval/Inbox consistency — M:** one exact-action receipt across chat, review, and promotion surfaces.
3. **Phone recovery qualification — L:** prove stop ownership and reconcile pending effects before continuation.
4. **Parallel-lane correctness — M:** test task/run ownership fencing and checked-commit merge authority together.
5. **Adapter parity — M:** qualify normalized capabilities, cancellation, resume identity, and accounting per runtime.
6. **Composer and result continuity — M:** bounded Tidy/`@files` handoffs plus directly inspectable task artifacts.

**FactsBook**

1. **B7 independent acceptance — M:** close the minimization/replay acceptance gate before hosted roles or source execution.
2. **D36 Roles/Jev slice — M:** reconcile stale specs; explicit selection, immutable role snapshots, tool-less calls, synthetic qualification.
3. **Shared budget slice — M:** enforce $0 default, pre-call reservations, nested-retry accounting, and unresolved charges.
4. **D37 email-first slice — L:** on-phone minimization, bounded triage, gated full reading, durable source checkpoints, local labels only.
5. **Review integrity slice — M:** preserve provenance and signed revision-bound decisions across every Memory surface; no automatic fact commits.
6. **Phone scheduling/Move slice — L:** checkpoint bounded jobs, preserve source cursors, and retain one explicitly chosen executor.

