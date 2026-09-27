# Work and Team hot-path measurements

Finish line: reduce repeated pin-query allocations in the existing Work list without changing pin ordering, persistence, or profile/location isolation; measure Team board derivation and give its UI owner an exact follow-up. Non-goals: screen redesign, changes to `connection.dart`, polling freshness semantics, and unsupported identity-based caches.

## Harness and limits

`test/perf_work_lists_test.dart` drives a real `SessionPinStore` and the real `buildTeamBoard` through `ListenableBuilder`, with 1,000/5,000 rows and 20 distinct pumped notifications. It counts consecutive scope-string/pin-set identity changes (retaining only the last value), and board projection identities. An initial identity-HashSet probe was discarded because equal strings can have colliding identity hashes and distort timing; only the corrected linear-overhead probe is comparison evidence. Stopwatches surround synchronous work only. Widget-test elapsed time is debug host workload evidence, **not** device cold-start or raster frame timing. Pump count remains 20; this change removes repeated derivation/allocation within a rebuild, not controller notifications.

The pin probe calls the same backend chain as `ConnectionController.isSessionPinned` (`connection.dart:8309–8312`), without constructing the large connection/controller dependency graph. The actual Work screen makes at least two membership checks per unblocked, non-running row while constructing pinned/recent groups (`workspace_screen.dart:595–610`). The probe uses one check per row, so it does not inflate that path's allocation count.

Corrected baseline (root serial run, `/tmp/oc-perf-baseline-corrected.log`):

| Workload | Rebuilds | Scope identities | Pin-set identities | Synchronous time |
|---|---:|---:|---:|---:|
| 1,000 pin checks/frame | 20 | 20,000 | 20,000 | 28,175 µs |
| 5,000 pin checks/frame | 20 | 100,000 | 100,000 | 64,698 µs |
| 1,000 board items | 20 | — | 20 board projections | 62,031 µs |
| 5,000 board items | 20 | — | 20 board projections | 168,781 µs |

The four corrected baseline probes passed. The first after run passed all 13
tests across this harness and `test/session_pins_test.dart`:

| Pin workload | Scope identities after | Pin-set identities after | Synchronous time after |
|---|---:|---:|---:|
| 1,000 checks × 20 builds | 1 | 1 | 8,876 µs |
| 5,000 checks × 20 builds | 1 | 1 | 21,451 µs |

Build count stays 20. The deterministic win is reuse of one key/set instead of
20,000/100,000 newly returned objects, not suppression of status notifications.
Board projections stay 20; there is **no implemented board speedup**. Its after
times (54,852/129,722 µs) are run-to-run noise on unchanged derivation code.
The earlier identity-HashSet timings are excluded from all comparisons.

## Safe backend change

`SessionPinStore.scope` now memoizes its most recent pair of immutable directory/workspace strings and the exact JSON key. The cache stays bounded to one pair and preserves null/empty/string escaping distinctions. `ids` now returns a cached immutable set for each persisted profile/location; a successful write replaces the profile map only after storage acknowledges it. Pending or failed writes keep the previous visible set. Previously returned sets remain immutable snapshots. `forget` clears the profile owner and the last-scope memo, so a deleted profile does not leave its location in that memo and a later load reads persisted state again. No credentials, session body, or diagnostics are introduced.

## Remaining Team/Work owner changes

These are measured/source-backed recommendations, not implemented improvements:

1. `lib/ui/screens/team/team_board_screen.dart:147–153` re-derives the complete board on every `AnimatedBuilder`/controller notification. `:182` repeats it for every project when choosing the initial project. `lib/state/team_board.dart:211–290` filters all work, builds lookup maps/cards, and sorts all five columns every call. The harness measures 20 projections for 20 unrelated notifications on the same snapshot. Memoize one projection per active project at the screen/domain projection owner, but first establish immutable snapshot revisions; today's `OrchestrationSnapshot` and model lists/maps are publicly mutable. Identity-only memoization could hide changes.
2. A correct board memo key must include ordered work/runs/agents/gates evidence revisions, project filter, a detached copy of pending moves, and time validity. Relevant work fields include every field consumed by bookkeeping/type/routing/column/priority/blocker/epic derivation and every field exposed through returned cards. Invalidate at the first completed-item expiry (`updatedAt ?? createdAt` plus seven days; strict cutoff preserves an item exactly at the boundary), on clock moving backward, and on pending-map mutation. Keep only current/bounded projections and clear on profile/host switch. Do not cache stale/error/status UI with the board: its freshness/capability line must still rebuild.
3. `lib/ui/screens/team/team_home_screen.dart:663–670` derives gates, visible/upkeep lists and sorts runs per rebuild; `team_needs_you.dart:59–70` linearly resolves a gate's run, called again for each gate around `team_home_screen.dart:680–683`. A projection owner should construct run/work/agent ID indexes once per immutable evidence revision, keep ordered gate/run lists, and invalidate for mutation receipts that mark gates answered. Preserve host order as the stable sort tie-break and keep status/thermal/staleness changes live independently.
4. `lib/state/connection.dart:8056–8078` filters and sorts sessions on every `sortedSessions()` call. `workspace_screen.dart:572–610` then filters pending archive and partitions the list four times. The cx-policy/Work owner should expose an immutable session-list revision and memoize sorted inventory on session ordering fields, inventory inclusion state, selected profile/location, and persisted pin revision. A single ordered pass can construct attention/active/pinned/recent groups, using one captured pin set. It must invalidate on blockers, busy state, archive/Undo, pin acknowledgments, error/staleness changes and locale changes if caching localized blocker strings. Do not use SSE token arrival as the inventory revision unless it changes these fields.

## Acceptance for deferred memoization

At 1,000/5,000 items, repeated unrelated updates should produce one projection while freshness/error indicators continue to rebuild. Reordered host input, changed nested metadata, changed pending moves, seven-day expiry, answered-gate receipts, profile/location switch, lost capabilities, and archive/Undo must each show the new result. Test mutable input explicitly until the domain guarantees immutable evidence. No recommendation permits suppressing the controller's freshness or error notifications simply because item IDs did not change.

## Behavior coverage

The final focused file adds assertions that repeated 1k/5k probes retain exactly one scope key and pin set, plus scope JSON/null/empty/escaping distinctions, immutable old sets across pin/unpin, persistence reload, profile/location isolation, deletion-style forget, pending writes, refused storage, and recovery after refusal. Existing `test/session_pins_test.dart` continues to cover real controller ordering and queued writes.
