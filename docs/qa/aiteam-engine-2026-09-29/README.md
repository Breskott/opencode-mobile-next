# AI Team project fixture engine — 2026-09-29

Finish line: persistent, deterministic simulated project work from explicit mode and budget selection through spec/plan approval, task checks, dev merges and confirmed promotion.
Non-goal: real agents, network, git, background services or signing.

Implemented: optional project gateway, immutable JSON snapshots, typed mutation commands, controller, profile storage, demo fixture, clock/manual advance and opt-in timer. Old adapters retain false project capability flags. The original disk recording fixture remains unchanged.

The fixture supports projects/quick tasks, context references, edited/versioned specs, affected-task replan, edited plans, lane/dependency/server caps, role/server selection, questions, messaging, task recovery, chat/charging holds, usage/budgets, ranked findings, selected fixes/ignore/recheck, bounded automatic checks, per-repo queue receipts, conflict resolution, exact-commit confirmed promotion and revert receipts. All data and money/costs are simulated; unreported usage is explicitly unknown. It cannot run while the process is dead or reconcile a real host. Screen-off preferences are persisted intent, not a claimed background execution service.

Storage: `oc.teamWorkspace.<profileId>`, schema 1. Writes serialize, persist before publishing, and redact all string values. Identical request IDs replay their durable result; changed commands reusing a request ID fail. Existing projects require expected revisions. Close/delete drain seed and mutation writes and prevent resurrection. Read-only monitor projections do not seed, reconcile, persist or mutate.

Verification (pinned Flutter 3.47.1; `OC_TEST_SLOTS=1`, machine_lock):
- `flutter pub get`: passed.
- Scoped `flutter analyze --no-pub` across the seven changed/new Dart surfaces: clean.
- `flutter test --no-pub --concurrency=1 test/team_project_fixture_test.dart`: 11 passed.
- `dart format --language-version=3.10` changed Dart files: passed.

Tests cover lifecycle, explicit choices, stale/reused/idempotent requests, failed-write rollback, restart interruption, lane/dependency caps, delete with pending writes, read-only monitor safety, budget with no live tasks, safe replan, plan-first quick tasks, and both live/disk credential redaction.

Images: not applicable to this domain/state slice. UI screenshots, integration gates/full suite and device checks belong to the coordinator's complete candidate. No engine/Android behavior is claimed verified.

Open integration checks: phase/milestone review UX, every-step merge confirmation and fixture edge-case coverage must be audited with the finished screens. The fixture has no public operation, provider credential, process or real branch API.

Follow-up candidate (coordinator runs integration checks):
- Review policy now gates every-step merges on confirmation, protects promotion behind risky-phase review, auto-accepts safe phases, and creates milestone review requests. Dependent phases wait for required review.
- Editor draft APIs serialize/redact whole-form JSON or plain text, reject writes after dispose/drain, and use the deletable `oc.teamEditorDrafts.<profileId>` shared map.
- Added controller draft tests and fixture tests for minor-only automatic checks, phase review, every-step merge confirmation, terminal work and started-task placement. Earlier 11-test result predates this follow-up; do not claim these added checks passed until coordinator runs them.

Mandatory fixture recovery follow-up:
- Added explicit malformed-plan fallback, conflicting/manual dev changes, checked agent/manual conflict resolution, criterion results, 80% budget notices and confirmed start-over placement. Original branch work and human dev commit receipts remain recorded; main remains untouched until confirmed reviewed promotion.
- Added focused tests for these scenarios and closed-gateway late reads. Coordinator owns final analyzer/test execution for the combined candidate; initial 11-test result is historical only.


## Integrated verification, September 30

The coordinator's final recovery checkpoint passed all 20 fixture tests and 3 controller/draft tests. Complete-source analyzer is clean. Lifecycle integration adds immediate-stop, late factory, concurrent deletion, read-only monitor and profile-scoped cleanup coverage. See [the integration record](../aiteam-phase-a-2026-09-29/README.md) for the frozen full-manifest run and its separate baseline failures. Earlier 11-test evidence above remains historical. No actual server, filesystem merge or background engine was exercised.
