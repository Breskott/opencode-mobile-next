# P5.5 backend/state — 2026-09-27

Finish line: provide one observable, localized status source for chat and team rows, their header word and notification copy, with static last-observed status while disconnected.

Non-goal: UI/layout changes, notification delivery changes, new endpoints, storage, or edits to single-owner files.

## Scope and feasibility

Read: AGENTS.md; STANDARDS.md sections 2, 3, 13, 15 only; current chat/run/todo models, orchestration work models, row/header/notification presentation, connection/orchestration state, localization and KitRedact.

Write: `lib/domain/work_row_status.dart`, `lib/state/work_row_status_controller.dart`, `test/work_row_status_test.dart`, this QA directory, and the requested fallback commit message.

Dependencies: existing `RunResult`, `Todo`, `WorkItem`/`WorkState` and generated English/Arabic localization. These contracts are present. This is a local derivation API; it needs no new network/authentication contract or credentials. Existing gateways/controllers remain responsible for authenticated reads. No prerequisite failed for the backend API.

Evidence: `lib/domain/run_result.dart` records evidence-based terminal outcomes and run timestamps; `lib/api/models.dart` exposes todo completion; `lib/orchestration/models/work.dart` exposes normalized team state. Team task `createdAt`/`updatedAt` are not run start/end evidence, so durations are omitted unless the caller has explicit timestamps. Idleness never means Done. Needs you outranks busy and completion.

This is one small, coupled slice with one owner. No UI, Kotlin, main, connection, server_gateway or product_repository edits. No third-party dependencies or new localization keys.

## UI hook-up

Import `package:opencode_mobile/state/work_row_status_controller.dart` (it re-exports the domain API).

1. Own a `WorkRowStatusController` per profile/location and transport. Chat and team use separate controllers if their transports differ. Listen to it with the UI owner's normal Listenable binding. Call `clear()` immediately on scope switch/profile deletion, and `dispose()` when the owner leaves. There is no disk state or preference-key deletion sweep to extend.
2. Call `setConnected(true)` only for a connected transport; connecting, reconnecting, disconnected, authentication failure and lost host all use `false`. A reconnect does not make existing rows fresh.
3. Capture `generation` BEFORE starting a gateway fetch. Following a successful response, call `observe('chat:<id>' or 'team:<id>', facts, observedAt: receiptTime, generation: capturedGeneration)`. Old generations and older observation timestamps are rejected. Capture the receipt time when evidence arrives, not when a delayed callback runs. After reconnect, refetch; never relabel cached controller collections or rebuilds as fresh evidence. Event observations must carry their subscription's generation. On request failure, retain stale data; do not manufacture new evidence.
4. Chat: `WorkRowFacts.chat(busy: ..., needsYou: ..., result: ..., todos: ...)`. `busy` comes from current session status, including retry/compaction. `needsYou` means any permission, question or form pending for that session. Supply `RunResult.fromMessages` for that session's current turn and only its current todo list. Unknown/unloaded results and totals stay null. Do not fetch all chat histories just to fill rows; omit unavailable details. A previous completed result is not a newly busy turn's start time.
5. Team: `WorkRowFacts.team(item: item, needsYou: pendingGateForThisTask, steps: measuredSteps, startedAt: explicitRunStart, finishedAt: explicitRunEnd)`. Pass measured plan counts only when the total is known. Do not use dependency count, loaded assistant message count or created/updated timestamps as a plan total or run duration. Review and waiting are distinct from Needs you unless there really is a pending request.
6. Read `statusFor(key)`. Null means no observation yet. Use `status.word(l10n)` for the header and notification status word; `status.line(l10n, now: now)` for both Work and Inbox supporting lines. Mapping happens in the domain file once. Examples using existing localized vocabulary: `Working · 2 of 5 done · 3 min`, `Needs you`, `Done 4 min ago`. The completed/total pair counts steps; the existing translation says “done” rather than adding a new “steps” key.
7. Only `showLiveMark == true` permits the working/live/animated mark. For `!isFresh`, use a static neutral mark (including cached Done); `line` includes an absolute localized `as of <date/time>` and freezes durations/completion ages at `observedAt`, even when rebuilt hours later. Do not attach a live timer, pulse, green connection dot or live-region announcement to a stale row. Connected rows can use an existing shared minute tick; this service starts no timers.
8. On entity removal call `remove(key)` and cancel/ignore outstanding reads for that entity. `clear()` invalidates all in-flight reads on scope deletion; `remove()` only removes that row.

Minimal feed, inside the existing owner's successful gateway read path:

```dart
final token = rowStatuses.generation; // before await
// final response = await existingGatewayRead();
// Build facts from that response, not cached collections.
rowStatuses.observe(
  'chat:$sessionId',
  WorkRowFacts.chat(busy: busy, needsYou: needsYou, result: result, todos: todos),
  observedAt: receivedAt,
  generation: token,
);
final status = rowStatuses.statusFor('chat:$sessionId');
// Row: status?.line(l10n, now: now)
// Header / notification word: status?.word(l10n)
// Live mark: status?.showLiveMark == true
```

Integration still required by other owners: Work/Inbox rows and chat/team headers must consume this source; the notification owner must use the same word. Current `ConnectionController.liveStatus()` and native notifications are unchanged. Full end-user acceptance (including absence of a green disconnected dot) is not claimed until those consumers are wired and verified.

## Security / persistence

No disk writes, serialized state, diagnostic logging, new network calls, or credential access. Facts retain enums, counts and timestamps only; factories discard todo text, task titles, raw errors and raw provider payloads. No persisted payload exists to redact with KitRedact. Any later persistence must use KitRedact and profile-scoped deletion; this API deliberately adds none.

## Verification

Five focused flutter_test cases in `test/work_row_status_test.dart` cover: evidence-based completion and request precedence; common chat/team vocabulary and measured counts, including Arabic; offline freezing and per-row reconnect freshness; deletion/scope invalidation and stale reply rejection; unknown measurements and clock skew.

- Requested pinned wrapper formatting: blocked before Dart by read-only `bin/cache/engine.stamp.tmp` / `engine.realm`.
- Formatting fallback: used the SAME pinned SDK's `bin/cache/dart-sdk/bin/dart format --language-version=3.10`. Files were formatted. Initial invocation then failed updating read-only analytics state. Final `dart --suppress-analytics format --language-version=3.10 --output=none --set-exit-if-changed ...` passed: 3 files, 0 changes, exit 0. Package-resolution warnings remain because this worktree has no resolved Flutter lint package. Saved: [format-output.txt](format-output.txt).
- `.../bin/flutter test --concurrency=1 test/work_row_status_test.dart`: blocked at wrapper startup by the same read-only cache. No tests executed. Saved: [test-output.txt](test-output.txt).
- `.../bin/flutter analyze lib test`: blocked at wrapper startup, exit 1. No analyzer result. Saved: [analyze-output.txt](analyze-output.txt).
- `git diff --check`: passed; new files additionally checked for trailing whitespace.
- No full suite, build, emulator, phone, signing, push, or release attempted.

Verifier: resolve dependencies with the pinned Flutter in a writable-cache environment, run the focused test serially, then analyze `lib test`. UI screenshots/accessibility verification belong to the later UI unit.

## State

Implemented: backend API and focused tests. Enabled: no, awaiting intentional consumer wiring. Verified: formatting only; behaviour tests and analysis blocked by sandbox. Committed: no; `git add` failed creating the worktree `index.lock` on a read-only filesystem. Changes remain in the working tree; the exact requested message and trailers are in `COMMIT_MSG.txt` at the repo root. Deployed/released: no.
