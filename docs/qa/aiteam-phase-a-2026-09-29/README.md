# AI Team Phase A integration — 2026-09-29

Base: `94dd1021`, local candidate branch `build/aiteam-phase-a`.

Finish line: a person can create a fixture project, edit and approve its spec and plan, watch dependency-ordered lanes, answer questions, fix and re-check findings, review a dev merge queue, explicitly promote, and recover the same project after restart through a fully reachable adaptive UI.

Non-goal: no production engine, server mutation, publishing, or merge into the owner integration branch. Phase B evaluates engines; Phase C waits for the owner choice.

## Ownership and dependencies

- Engine slice (`build/aiteam-engine`): additive domain contract, neutral model, persistent fixture and controller; focused behavior tests.
- Kit slice (`build/aiteam-kit`): presentation components, severity tones, API documentation, manifest and galleries.
- Screens slice (`build/aiteam-screens`): project journeys and focused widget tests; depends on frozen engine and kit APIs.
- Integration (this branch): existing navigation and demo activation, Work/Inbox/notification linkage, lifecycle/deletion, localization, ledger and final verification.

Each worker has an isolated worktree. Heavy checks are serialized through `tool/qa/machine_lock.sh` with `OC_TEST_SLOTS=1`. No push, PR, signing, release or production-engine choice is authorized.

## Validation plan

Format affected Dart, run focused behavior checks, inspect Android gallery renders (phone 412×915 and wide 1280×800; dark/light), then analyzer and required design/architecture/redaction/ledger gates. At a stable candidate, run the complete serial manifest in bounded chunks and record failures/skips against that revision. Device-only behavior is reported separately.

## Status

Implementation in progress. This file is not evidence of passing tests.

## Integration notes

The normal AI Team route selects the project UI only through `projectLifecycle` capability. The demo can be opened before server setup from the app demo; an unconfigured profile can explicitly enable it. Leaving a profile demo retains its saved workspace for next time. Work, Inbox and notification destinations resolve project/task IDs. Cross-profile monitoring uses a read-only snapshot adapter, with no seeding, recovery writes or timer.

Shutdown shares one completion future, drains an in-flight startup and pending editor writes, and closes the fixture before profile preference discovery and deletion. Removing the plugin also removes workspace/editor data when it was already stopped. New editor drafts are redacted before persistence.

The standalone structural ledger checker reports 58 failures on both the original `94dd1021` checkout and this candidate, with no new failure lines. These are existing stale source locations and the unregistered `team_model_sheet.dart`; this does not establish a clean ledger gate. The Flutter coverage gate is still to be run.
