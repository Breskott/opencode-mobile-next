# Codex tests-c — 2026-09-28

Finish line: repair the assigned non-golden tests against the intentional September 27 UI changes; preserve meaningful failures for product-owner handoff. Non-goals: production edits, golden refresh, gate or baseline changes, publication.

## Prerequisite integration

Merged `feat/phone-setup-v2` at `dbac9c48` into `codex/tests-b` (previous head `93aab671`). The two conflicts were test-only resolutions:

- `team_controls_test.dart`: P3.6's worker conversation composer replaces the removed message sheet; the agent page offers one Open conversation action. Kept tests-b receipt, capability, manual-reassignment removal, and 320dp/2.5x layout checks. Dismiss the overflow menu before replacing its screen in the layout fixture.
- `builtin_server_autostart_test.dart`: kept both fake setup engines and the voice-device probe mock alongside incoming autostart checks.

Serial pinned-Flutter merge verification (`flutter test --no-pub --concurrency=1 <file>`): team_controls **31/31**, builtin_server_autostart **6/6**, kit_ratchet **34/34**, redaction **16/16**, ui_glossary **21/21**, no_raw_error_text **5/5**. Initial team-controls run was 29/31 because the fixture retained its open menu across screen replacement; corrected fixture rerun is 31/31. Logs: `/tmp/codex-tests-c/merge-*.jsonl`, `merge-final-team_controls.jsonl`.

The merge includes upstream product, baseline and image changes. This lane did not author those changes or regenerate images; subsequent tests-c edits are restricted to tests and this evidence record.

## Chat batch

Pending baseline and repairs. Four disjoint test groups; the lead owns serial execution and integration. Workers do not run Flutter or edit production files.
