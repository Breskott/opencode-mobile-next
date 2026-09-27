# P4.4 connection status and bootstrap recovery

Finish line: one controller-owned connection status feeds the shared KitScreen status slot; bootstrap can clear saved sign-ins safely; Add server accepts backend preselection.

Non-goals: reconnect-engine redesign, deleting local work, native/release changes.

## UI hook-up contract for Claude

### One connection status

Read `ConnectionController.connectionStatus` (`lib/domain/connection_status.dart`) while listening to the controller. The immutable snapshot contains `phase`, `profileId`, `serverName`, `since`, `usesToken`, `retrying` and `attemptRevision`. `visible` excludes hidden/connected; `waiting` means connecting/reconnecting; `reachable` means connected. Isolated work and no selected/retained server produce hidden status. Credentials take priority over transport waiting/failure. A completed failure is immediately `notAnswering`.

`AppConnectionStatusScope` in `main.dart` publishes connection, app-exit and thermal conditions above the Navigator. `connectionKitStatus` localizes the snapshot and resolves global actions through the Navigator overlay context. Chat contributes its local errors/Undo/share actions through `KitScreen.status`; Work contributes its local status to the same slot. The priority is connection, app stopped, heat, local work, update. Home’s server status word reads the same snapshot. Standalone screen test/capture hosts should mount the shared scope rather than reconstructing connection rules.

The controller owns the eight-second wait deadline. Stream reconnect churn and route rebuilds preserve it; a new connection attempt or owner starts a new period. Success and disposal cancel it. Do not add a `GraceTimer` or pass this snapshot's `since` to `KitStatus.since`: that would create a second status clock. Localize the snapshot through the shared presentation adapter and contribute to the screen status slot. Keep raw technical details behind the existing sanitized Details sheet.

### Bootstrap Start fresh

`await AppBootstrap.resetSavedSignIns()` obtains a fresh `ProfileStore` and calls `resetSavedSignIns()` without loading profile metadata. Use only at the bootstrap gate while there is no live connection. Serialize/drain outstanding loader attempts before resetting, and block retry/duplicate reset while the operation runs. Confirmation must explicitly say that saved passwords and connection tokens and the active server selection are removed, while saved servers, queued prompts and drafts are kept.

The gate exposes a confirmed **Start fresh** secondary action, drains stale loaders, and retries a partial reset directly when the person chooses **Try again**. The user confirmed the sign-in-only scope during this task.

The store enumerates only its `pw.*` and `oc.codexToken.*` secure keys (including orphaned entries), deletes individually, and verifies both secure storage and the cleared active selection. Other secure keys, `oc.profiles`, local work and settings remain untouched. Cached profile objects lose credentials even on partial failure. The redaction registry remains intact. A partial/refused/unverifiable removal throws `SavedSignInResetException` with fixed safe copy; retry is idempotent. Never use a broad secure-storage `deleteAll` or preferences clear here.

This is a sign-in reset, not a metadata repair or app-data wipe. Unreadable profile metadata remains preserved and can still require recovery. It does not revoke remote credentials or tear down live controllers; its bootstrap-only exclusion is part of the API contract.

### Add server backend preselection

Navigate to `/servers` with `ServersRouteRequest.add(backend: ServerBackend.codex)` (or `paseo` / `openCode`). `ServersRouteRequest.add()` keeps the generic first question. Preselection opens the connection-fields step but retains Back to change the server kind. It grants no permission to probe, save or connect. Existing-profile edits always retain the saved backend. Capability enable flows for Codex/Paseo now supply their selected backend through this same typed route.

## Verification

All commands use the pinned Shorebird SDK and `OC_TEST_SLOTS=1 tool/qa/machine_lock.sh` for machine-heavy work. The focused manifest is [focused-tests.txt](focused-tests.txt); it includes the original policy/deletion/credential regressions and requested gates. Final candidate results:

- All **388 tests** in the focused manifest passed (128 seconds). This includes F2/F3 controller behavior, F4 credential ingress, sign-in reset, backend preselection, status timing/priority, chat error controls, bootstrap exclusion, and `kit_ratchet`, `redaction`, `kit_redact`, `ui_glossary`, `no_raw_error_text`.
- **16 focused integration checks** passed (41 seconds): three Home recovery/layout cases, Work phone recovery, offline chat recovery, all seven Servers removal behaviors, and four golden comparisons.
- `flutter analyze --no-pub`: **No issues found** (20.6 seconds).
- Pinned `dart format --language-version=3.10`, localization regeneration, duplicate English-key validation, and `git diff --check` passed. No authored Arabic copy or guard allowlist additions.

Reproduce the primary batch with `flutter test --no-pub --concurrency=1 $(cat docs/qa/codex-status-2026-09-28/focused-tests.txt) --reporter expanded`. The integration command uses `test/home_navigation_test.dart test/work_tab_cleanup_test.dart test/chat_live_events_test.dart test/revamp/queued_prompt_removal_test.dart test/revamp/coord_main_golden_test.dart` with `--name 'failed reconnect keeps|recovery banner fits|automatic SSE reconnect|the Work tab says so after|offline chat keeps|behaviour|bootstrap gate|share waiting'`.

The source/test fingerprint is [verified-files.sha256](verified-files.sha256).

Four deliberate capture updates passed and were visually reviewed: [phone bootstrap](../../../test/revamp/goldens/coord_main_bootstrap_failed_dark.png), [wide bootstrap](../../../test/revamp/goldens/coord_main_bootstrap_failed_1280x800_light.png), [phone connection priority](../../../test/revamp/goldens/coord_main_share_waiting_dark.png), [wide connection priority](../../../test/revamp/goldens/coord_main_share_waiting_1280x800_light.png). These are Flutter golden renders, not device screenshots. No APK, emulator or release check was performed.

The broader legacy chat/home/Work suites were also examined, but are not represented as passing. A detached checkout of the merge prerequisite reproduced the same 33 chat and 21 Home failing cases, plus six older Work cleanup failures; see [baseline-comparison.txt](baseline-comparison.txt). The additional Work connection-harness failure from the first integration run was corrected and its focused check passes. One affected Home navigation assertion now uses the kit component. The unrelated legacy cases were not rewritten, and no full-suite pass is claimed. The chat load-error Details fold was also corrected to retain technical details through the kit redactor, while authored failure copy stays plain.

Merge prerequisite: `c5d2a8ce3f2ae06496647230291d63b4acafa478` (335 focused tests and clean analysis; see policy QA README).

## Delivery boundary

Implemented and wired in this worktree; local checks above verified. No push, PR, device deployment, signing or release. The reset retains unreadable profile metadata by design; it clears sign-ins without silently deleting work.
