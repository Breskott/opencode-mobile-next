# P6.2 backend: While you were away (2026-09-27)

Finish line: expose durable, redacted automatic-action history, optional real Undo,
and all eligible finished work through a small Dart API for the rebuilt Inbox.
Non-goal: new automation triggers or edits to UI, native code, connection, main,
the gateway, or the product repository.

Base: `dcf05c5e`, existing worktree branch `codex/p62` (retained as instructed).
Implemented backend only; **not enabled in the app**. Full P6.2 acceptance remains
pending producer/owner integration and UI integration. Tests and analysis are
environment-blocked, not passing.

## Scope and feasibility

Read set: AGENTS.md; STANDARDS.md sections 2, 3, 13, 15; existing return-brief
domain/store; profile preference deletion; connection's reconnect and auto-approval
paths; thermal/recovery/update services; KitRedact. No other STANDARDS sections read.
Write set: `lib/domain/while_away.dart`, `lib/state/automatic_activity.dart`,
`test/while_away_test.dart`, `test/automatic_activity_test.dart`, this QA directory,
and `COMMIT_MSG.txt` only if git metadata is not writable.

Three bounded work sets: domain + its tests (domain worker), state behavior tests
(test worker), persistence/controller + integration documentation (coordinator).
The enum/model/controller signatures were fixed before parallel edits. Only the
coordinator attempted tests and analysis. No shared or restricted library edited.

The local record/undo contract is feasible without a new server endpoint,
authentication adapter, credentials, timer, or background process. Existing
`ReturnBrief.unreviewedRun` and `ReturnBriefAck` provide finished-work eligibility
and exact acknowledgement. ProfileStore discovers `oc.automaticActivity.<profileId>`
through its existing key-shape sweep.

There is no existing unified event log or KitAutoLine in this checkout. A generic
recorder does not prove every producer is wired: exact completion hooks need the
owners below. Do not infer an automatic act from an arbitrary rebuild, current
connection state, an update check, or a historical process exit. Native-only
events without a confirmed Dart outcome remain an integration gap; no fabricated
event/replay adapter was added.

## UI hook-up

Import `state/automatic_activity.dart` and `domain/while_away.dart`.

1. The profile owner creates exactly one `AutomaticActivityController` per profile
   with `preferences`, opaque `profileId`, and `isProfilePresent`. Keep it above
   screen lifetimes; bind `isProfilePresent` to actual profile membership. Observe
   it with a Listenable builder. Do not create competing writers for the same key.
2. Existing producers call `record(eventId:, location:, kind:, summary:,
   occurredAt:, sessionId:, undo:)` **after a confirmed act**. Use a stable ID for
   that occurrence, including its source namespace; retries use the same ID and
   later occurrences use new IDs. Capture profile/location/time at the act, before
   awaiting. The location string must use the same canonical identity as the
   owner's return-brief scope. Do not pass credentials, diagnostics, commands,
   permission patterns, or raw error text as summary copy.
3. `record` returns whether history was saved, not whether the original act
   succeeded. On false, show a localized history-save failure and retry only
   recording the same event. Never repeat the underlying act. Kinds include
   reconnect, restart, heatPause, heatResume, update, permissionApproval,
   queuedSend, other (e.g. a confirmed heat stop). There is no Needs-you kind.
4. Build `WhileAwaySnapshot.build` from `controller.forLocation(location)`, current
   sessions, the existing `isUnread`/`isBusy`/`blockerOf` callbacks,
   `readStateKnown`, `inventoryPartial`, and `connection.returnBriefAcknowledgement`.
   Use the active profile's controller only. The snapshot gives immutable,
   newest-first `automaticActs` and `finishedWork`; no three-row truncation. Keep
   unknown read state and incomplete inventories visible; `isEmpty` alone does
   not prove there is no finished work. Blocked, child, archived, busy, read,
   missing-idle, and exactly acknowledged runs are excluded.
5. Render each automatic act as one KitAutoLine with its safe `summary` (already
   one line), timestamp, and Undo only when `canUndo(act.id)`. The UI owner supplies
   localized copy for kinds/states/controls; persisted summaries retain the
   language supplied when recorded. Use `automaticActs` and `finishedWork` in
   the Inbox's “While you were away” section. These automatic acts never feed
   Needs-you, its badges, or its notifications. This API posts no notifications.
6. `undo(id)` returns `unavailable`, `undone`, `failed`, or `unconfirmed`. Supply an
   inverse only when the producer has a real, safe, scope-checked operation; the
   callback must verify current profile/server/session and current undo validity
   before executing. Reconnects, completed permission replies, restarts, applied
   updates, and protective heat actions generally have no valid inverse. Never
   offer “Undo” merely to dismiss a line. No inverse is reconstructed after app
   restart. Pending intent is committed first, and an invoked inverse is never
   retried; `undoAttempted && !undone` must not be described as confirmed success.
   `undone` is persisted only after confirmation and a successful history write.
7. Capture only IDs actually shown, then `acknowledge(ids)` to dismiss automatic
   rows. Future arrivals stay unacknowledged. Acknowledgements are stored on the
   exact occurrence, not a time cutoff. For finished work retain the existing
   `dismissReturnBrief(ReturnBrief.single(run), expectedScope: capturedScope)`
   path per shown row, or the existing navigation/read operation when opening
   the result. Never dismiss `ReturnBrief.requests` through this feed.
8. Before `ConnectionController.deleteProfileAndLocalData` sweeps preferences,
   await `deleteProfileData()` on this profile's activity owner. It stops new
   writes immediately, drains in-flight writes and inverses, removes the key, and
   remains closed. Abort/report a deletion failure if it returns false; retry is
   allowed. Dispose the owner after completion. A normal shutdown uses `dispose`
   without deleting history. This integration is mandatory before enabling the
   recorder; a key sweep alone cannot drain an outstanding write.

### Producer and owner integration requests

| Owner/source | Hook needed; no new trigger |
|---|---|
| `lib/state/connection.dart`, `_startEvents.handleStatus` | Record an actual automatic recovery transition to connected; distinguish manual connect/reconnect and initial connect. Keep its existing refetch reconciliation. |
| `lib/state/connection.dart`, `_autoApprove` | Record after the resolved permission is appended to the successful auto-approval history; use request/session identity, omit patterns. |
| `lib/state/connection.dart`, offline queue completion | Record only a confirmed automatically flushed send, not a queued item or a user send. |
| `lib/builtin/app_exit_recovery.dart`, `lib/termux/managed_server_recovery.dart` | Record a confirmed automatic restart/recovery, with a stable episode ID; do not equate historical exit evidence with completed recovery. |
| `lib/builtin/thermal_guard.dart` | Record confirmed pause/stop/resume effects per affected team/profile, at the existing completion points; no override of heat protection. |
| `lib/update/shorebird_update_notice.dart` | Record the confirmed automatic download outcome as downloaded/restart required; a check or available update is not an installation. Applied-update claims need actual applied evidence. |
| Profile owner in connection/main | Create/manage the recorder and await its deletion barrier before the existing profile-key sweep. |
| Inbox/kit owner | Build KitAutoLine, route this snapshot into “While you were away”, keep system acts out of Needs-you, and complete removal of the old embedded panel/dialog if present on the integration branch. |

Current `lib/ui` search finds no `ReturnBriefPanel`, `showReturnBrief`, or
`return-brief` references. Workspace still uses return-brief domain acknowledgements
for finished rows. They are intentionally preserved; this unit neither deletes UI
nor certifies the rebuilt Inbox. KitAutoLine is a later UI dependency.

## Persistence, privacy, and limits

Version 1 JSON under `oc.automaticActivity.<profileId>`; no shared blob or migration
of existing return-brief acknowledgements. Stores the newest 200 observations per
profile across locations, including acknowledged ones; history and deduplication
are bounded by that retention window. It is not a permanent audit log or absence
interval detector. Late records older than the retained window can be discarded.

KitRedact processes summary/session metadata before writing; registered secrets
must already be registered by the credential owner. Raw event IDs and location
paths/URLs are hashed, not stored. Sensitive session IDs are omitted to avoid
turning masked text into a navigation target. Summary copy is limited to 400
Unicode code points after redaction and whitespace normalization. No exception
payload is published or logged. Inverse callbacks exist only in memory. Corrupt or
unsupported history sets `corruptHistory`; failed writes set `persistenceFailed`
without publishing a successful observation/acknowledgement. These flags require
honest UI error states. No security or notification policy was relaxed.

## Verification

Behavior tests added in `test/while_away_test.dart` and
`test/automatic_activity_test.dart`: eligibility, complete finished lists, exact
acks, ordering/immutability, profile/location isolation, redaction, storage
refusal/retry, restart behavior, bounded retention, at-most-once Undo and deletion
races. All fixture secrets are synthetic. No tests were executed successfully.

Pinned commands attempted:

```sh
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/dart format --language-version=3.10 lib/state/automatic_activity.dart lib/domain/while_away.dart test/while_away_test.dart test/automatic_activity_test.dart
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter test --concurrency=1 test/while_away_test.dart
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter test --concurrency=1 test/automatic_activity_test.dart
~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin/flutter analyze lib test
```

Flutter/bin-dart stop before execution because their launcher tries writing
`bin/cache/engine.stamp.tmp.*` and `bin/cache/engine.realm` in the read-only SDK.
See `while-away-test.txt`, `automatic-activity-test.txt`, and `analyze.txt`.
Formatting succeeded through the **same pinned SDK's cached Dart executable**
with `--suppress-analytics format --language-version=3.10`; see `format.txt`.
The dependency config is absent, so format reports unresolved flutter_lints;
that output is not analyzer validation. The verifier must prepare dependencies
and run both files plus whole-tree analysis with the pinned SDK in a writable
environment. No full suite, build, screenshots, native verification, or release
was attempted. New API work, not a claimed fix: no failing-first run applies.

Implemented: backend API and tests. Enabled: no. Verified: formatting and static
scope/diff checks only; behavior/analyzer blocked. Committed: see `commit.txt` and
root `COMMIT_MSG.txt` if metadata is read-only. Deployed/released: no.
