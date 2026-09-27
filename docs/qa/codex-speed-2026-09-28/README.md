# Speed backend and Claude hook-up — 2026-09-28

Worktree `oc_app-codex-perf`, branch `codex/perf`, base `33ccb2ea`. Builds on
[the earlier performance pass](../codex-perf-2026-09-28/README.md); does not
repeat or change P4.4 chat rendering work.

Finish line: reduce independent startup/read waits, reuse session ordering,
and provide bounded, profile-safe last-known opening data with exact UI hooks.
Non-goals: chat rendering/merge ownership, changed consent/authentication,
full-suite runs, signing, phone access, publication, or device-speed claims.

## Measured results

All timings below are host harness evidence, **not Android cold-start/frame
latency**. Scripted delays are input fixtures. Socket counts use real loopback
HTTP on the host. No release/profile APK or emulator timing was collected.

| Workload | Before | After | Evidence |
| --- | --- | --- | --- |
| Inventory page + status, each scripted 60 ms | 120 ms | 60 ms | `perf_session_inventory_test.dart`; live SSE revisions and partial failure retained |
| 5,000 sessions, 20 unchanged ordering reads | 20 projections; 102,572 µs | 1 projection; 38,744 µs | Same host fixture, separate before/after runs; still scans membership O(n), no notification suppression |
| Eight independent 20 ms credential reads | 160 ms serial | 40 ms, max four reads in flight | `perf_profile_load_test.dart`; native secure storage may itself serialize |
| OpenCode 2 HTTP requests separated by 4 s | 2 TCP connections | 1 TCP connection | `perf_transport_decode_test.dart`; idle lifetime 3 → 15 s; no network-latency claim |
| Restarted session-label cache | No local inventory preview | Up to 100 labels synchronously, zero HTTP reads | `session_inventory_cache_test.dart`; not yet painted by UI |
| Restarted chat-tail cache | No local tail preview | Up to 12 text excerpts synchronously, zero HTTP reads | `session_tail_cache_test.dart`; not complete history, UI hook-up pending |
| Concurrent intentional prefetch + newest-page hydration | Separate gateway calls would make 2 reads | Shared controller call makes 1 read | `session_tail_cache_test.dart`; no elapsed-time claim |

The ordering baseline was captured before editing controller production code.
The profile/socket harnesses retain the previous serial/default-client behavior
as an explicit control. Cache absence is a source baseline, not a fabricated
cold-start stopwatch. Final test logs/verification are recorded below.

## Implemented backend behavior

- Profile secrets restore in bounded groups of four before returning bootstrap.
  First paint was already deferred correctly by the earlier pass. Draft/photo
  recovery and consent migrations keep their ordering; a one-profile boot does
  not gain secure-read parallelism. [Profile details](profiles.md).
- Session page/status reads overlap on startup, polling, and resume. Errors are
  attached immediately to the status future; page failure cannot leave an
  unhandled status error. Generation, refresh, and SSE revision guards remain.
- `sortedSessions()` returns an immutable memoized ordering. It compares the
  eligible immutable Session objects in host order and pin membership, so map
  replacement, archive, timestamp/title changes, inventory membership, equal-time
  input reordering, and pin changes invalidate. No controller listeners are
  suppressed; freshness, failure, permission and busy state still notify.
- Native v2 HTTP retains idle sockets 15 seconds; disconnect closes them.
  Browser imports remain native-free. Dio's existing large-JSON isolate decode
  remains in place; adding another compute boundary would duplicate it.
  [Transport details](transport.md).
- Successful inventory refresh persists one last-known location per profile,
  at most 100 redacted labels / 64 KiB. It never populates `sessionsById` with
  disk data. `cachedSessionInventory` is a synchronous, memoized read.
- Chat-tail reads can coalesce prefetch and live hydration. A separate persisted
  preview holds at most 12 redacted text excerpts (1,000 Unicode scalars each).
  Reasoning, tools, attachments, errors, credentials and cursors are omitted.
  Oversized individual parts are skipped, rather than redacted on the opening
  frame. It is an excerpt, never a complete cached transcript.

## Exact Claude contract, ranked by user-felt impact

### 1. Show useful cached Work/session labels while reconnecting

Read `ConnectionController.cachedSessionInventory` after normal bootstrap.
The result is `SessionInventoryPreview?` with `fetchedAt` and immutable
`sessions: List<SessionPreview>`; each row exposes `id`, `title`, `updated`.
No async load, new provider or initialization call is needed. Refresh writes
this cache automatically. Null means no valid cache for this exact owner/scope.

Current `_Root` in `lib/main.dart` only mounts `HomeScreen` after
`hasConnectedServer`. Add a kit-only read-only opening shell using these labels
before that condition succeeds. Claude owns the kit shell; coordinate the
`main.dart` hook after this job releases its single-owner file. Do **not** set `hasConnectedServer`, populate
`sessionsById`, or infer busy/idle/capabilities from the preview. Keep the
connection status/banner honest; display last-known/fetched-at copy and a
refresh state. Keep sending, archive, approval, and server commands behind their
existing transport/capability gates. Route/navigation may show cached preview
content while reconnecting; actual live actions must still await readiness.

Work's regular list should keep live rows on resume while `sessionsLoading` is
true instead of clearing them for a full-page spinner. The controller already
retains those rows. Servers metadata already comes from `ProfileStore.profiles`
after bootstrap; do not wait for monitor probes to render saved servers.

Acceptance: cached rows visible with health/page futures held indefinitely;
no green/live indicator; no live command enabled; failed refresh retains the
last-known display; fresh inventory replaces it (including fresh empty list).
Foreign profile, endpoint, protocol, directory and workspace never flash old
rows. Add English/Arabic kit copy as needed.

### 2. Open a chat with text already visible, then reconcile live history

Backend APIs (in `ConnectionController`):

```dart
SessionTailPreview? cachedSessionTail(String sessionID);
Future<void> prefetchSessionTail(String sessionID);
Future<ServerPage<MessageWithParts>> loadSessionTail(String sessionID);
```

`SessionTailPreview` exposes `fetchedAt` and immutable
`messages: List<SessionTailText>` (`id`, `role`, `text`). These are explicitly
incomplete, redacted text excerpts. Render them in a kit preview while initial
history is pending; **never** insert them into `_messages`, reconcile optimistic
IDs against them, derive cursors/actions from them, or copy/export them as full
history. A cache miss falls back to the existing opening state. The most recent
successfully loaded conversation is persisted per profile, not every chat.

On intentional navigation (tap/pointer-down), fire
`unawaited(conn.prefetchSessionTail(id))`. Do not prefetch every row, hidden tab,
or background profile. In the chat owner's newest-page hydration path replace
the `readHistoryAtStagedBoundary(api, scope.session, boundary: ..., isCurrent: ...)`
call with `conn.loadSessionTail(scope.session)` after its current scope/readiness
checks. The controller uses that same staged-boundary reader internally and
rejects changed history/boundaries; it does not cache staged-away text.
Keep the original `versionAtStart`, current-history guards, merge, pending-send
reconciliation, scroll anchor and pagination logic. Older pages continue through
`api.messagePage(scope.session, cursor: cursor)`. Never call this for the
special `limit: 1` prompt/revert probes.

The prefetch method absorbs speculative errors; `loadSessionTail` preserves
transport errors for existing `productErrorText` presentation. Neither invokes
controller-wide notifications. A profile/location change, deletion, disconnect
or local history revision retires a late response. When disconnected, a disk
preview can render but the live read refuses. A prefetch that finishes before
route hydration may be refreshed again; this is deliberately stale-while-
revalidate, not a timed freshness assertion.

Acceptance: prefetch + immediate route hydration makes one HTTP call; cached
text appears before that call completes; empty/failed/attachment-only tail
falls back gracefully; profile switch/deletion and history reset cannot mount
or re-persist a late page. Keep P4.4 tests for live deltas during hydration.

### 3. Keep optimistic send visible before optional work

The existing chat send path already adds its optimistic user bubble before
`waitForSessionSelection` and `promptAsync`. Keep that order and its existing
server-ID reconciliation. Do not add a second pending-send owner in the
controller. Measure pointer-up → bubble paint in the P4.4 owner harness,
including a held transport/selection future; no new send latency claim here.

### 4. Avoid hidden-tab startup and large projections

Follow the earlier [startup note](../codex-perf-2026-09-28/startup.md):
`KitTabSwitcher` eagerly mounts tabs, including Settings' second health request.
Lazy first-visit mounting belongs to Claude, with visited-state retention tests.
Reuse `sortedSessions()` rather than sorting it again; it is now **immutable**,
so copy before any UI-specific reorder. Team-board projection memoization still
needs the full revision/expiry contract in
[work-lists.md](../codex-perf-2026-09-28/work-lists.md). P4.4 owns transcript
merging, markdown, row notifications and virtualization; no chat files changed.

## Persistence, isolation and deletion

New optional v1 JSON blobs: `oc.sessionInventory.<profileId>` and
`oc.chatTail.<profileId>`. Scope is a SHA-256 digest of backend, flavor, endpoint,
username, directory and workspace, not credentials. Profile changes invalidate
scope. Only one scope/tail per profile is retained. Existing data needs no
migration; malformed/unknown-version blobs are cache misses. Refused writes
reload preferences rather than presenting an unpersisted local mutation.

The deletion controller closes profile admission, drains both cache writers,
forgets decoded snapshots, then uses its existing checked preference sweep.
Generation/deletion guards reject pending network results and queued cache
writes. No shared blob, provider response, prompt attachment or authentication
material is added. Text caching is redacted and bounded, but remains local user
content: its keys participate in the same profile erasure contract as drafts.

## Existing size/startup controls (source observations)

No package/asset-size reduction is claimed. Voice models are downloaded into
app storage on demand (`VoiceModelManager.shared/create`), not listed as bundle
assets. Scanner's `MobileScannerController` is lazy with `autoStart: false`.
Terminal backend creation is owned by the terminal screen's explicit lifecycle;
no new eager terminal process is added. The asset list includes small branding,
licenses, AI Team manifests and fonts. Fonts/native scanner binaries are bundle
costs, not evidence of eagerly decoded startup work. Measure APK sections before
removing a dependency or font.

V2 event reconnect already refetches after reconnect; volatile deltas are never
replayed. Its first failure backoff is 1 second, growing to 16 seconds. This pass
does not shorten outage retries or bypass automatic-reconnect policy. Resume
keeps existing data and now overlaps inventory/status revalidation.

## Verification ledger

Pinned Flutter 3.47.1; commands use `OC_TEST_SLOTS=1
 tool/qa/machine_lock.sh test -- <pinned-flutter> test --no-pub
 --concurrency=1 … --reporter expanded` (without the displayed wrapping spaces).
Analyzer uses the same lock's `analyze` mode and `flutter analyze --no-pub`.

- `/tmp/oc-speed-inventory-before.log`: 2 baseline tests passed on unchanged
  controller; 120 ms scripted, 20 sorts / 102,572 µs.
- `/tmp/oc-speed-core-after.log`: controller, profile preservation and transport
  checks passed; the new profile test initially hit a widget-test guard conflict.
  Replacing its asynchronous callback assertion with `expectSync` fixed the
  harness; no production workaround was made.
- `/tmp/oc-speed-cache.log`: 5 tests passed: corrected profile timing/failure
  harness and inventory cache restart, isolation, deletion and corruption.
- `/tmp/oc-speed-final.log`: **176 passed**, no skips, 17-file manifest below.
  Repeated ordering sample: one projection / 33,628 µs. This is another noisy
  host sample, not a replacement for the paired baseline/after observation.
- `/tmp/oc-speed-final-probes.log`: **11 passed**, no skips, after style cleanup,
  covering `perf_session_inventory_test`, `session_inventory_cache_test`,
  `session_tail_cache_test`, and `perf_transport_decode_test`. Includes the
  additional changed-staged-boundary rejection case. These overlap the 176-test
  manifest; do not sum them as distinct tests.
- `/tmp/oc-speed-analyze-final.log`: **No issues found**, 10.2 seconds, after
  177 seconds waiting for the shared slot (wait excluded from workload results).
  The first analyzer found style issues only (braces, unused imports, test print
  calls and doc markup); fixed without ignores. Production behavior stayed
  fixed through style cleanup.
- Final `dart format --language-version=3.10 --output=none
  --set-exit-if-changed` on all 12 changed/new Dart files, `git diff --check`,
  and README relative-link checks passed.

Exact 176-test manifest (all under `test/`, suffix `.dart`):
`perf_session_inventory_test`, `session_inventory_cache_test`,
`session_tail_cache_test`, `session_inventory_paging_test`, `session_pins_test`,
`profile_deletion_test`, `staged_revert_workflow_test`, `perf_profile_load_test`,
`profile_store_test`, `profile_secure_storage_test`, `perf_transport_decode_test`,
`api2_transport_test`, `kit_ratchet_test`, `redaction_test`, `ui_glossary_test`,
`no_raw_error_text_test`, `kit/kit_manifest_test`.

Only focused tests and requested gates ran; no full suite, signing, release,
push, owner-phone access or UI screenshots. Cache rendering/prefetch remains a
Claude integration task, not an enabled screen feature. Backend inventory,
credential overlap and native keepalive are enabled on existing call paths.

Local commits: `9244e566` (profile reads), `f6011f33` (native v2 reuse), and the
controller/cache/contract commit containing this README. All carry `[skip ci]`
and the requested Claude author/session trailers.
