# Performance pass — 2026-09-28

Base: `c8e02abf`, supplied `codex/audit` worktree fast-forwarded to the
integration tip. Initial tree clean.

Finish line: measure startup, streamed transcripts, large team/Work projections
and bounded caches; fix the largest safe costs with before/after evidence and
give Claude exact changes for the chat files it owns. Non-goals: visual redesign,
changed migration/consent semantics, live server mutation, signing, release,
push, or edits to the other owners' chat library and `connection.dart`.

## Measurement contract

These are reproducible Flutter debug/widget-test measurements with synthetic
data and fake transports, not release-device cold-start, raster/GPU timing or
heap-profiler results. Frame pumps can prove scheduling, rebuilding and
coalescing; their scripted clock cannot estimate a real phone's frame duration.
Stopwatch values measure host CPU work in the test process and are secondary to
deterministic operation/allocation counters. No content or credentials are
printed in the probes. Source-only observations are labelled separately.

Pinned toolchain:
`~/.shorebird/bin/cache/flutter/91f8bd75076e9c740aa13cf67eb9ec1a093f68f5/bin`.
Root alone runs Flutter, serially through the existing machine lock. Queue and
tool startup waits are not included in workload times.

## Ownership and evidence

| Slice | Exclusive production write set | Evidence and hand-off |
| --- | --- | --- |
| Startup | `lib/main.dart` bootstrap scheduling and test seam | [Startup](startup.md) |
| Work | `lib/state/session_pins.dart` immutable derived lookup cache | [Team and Work](work-lists.md) |
| Chat | None; all chat production files remain Claude-owned | [Exact chat fixes](chat.md) |
| Memory/diagnostics | Non-chat kit log buffer and diagnostics history import | [Buffers and caches](memory.md) |

Each slice first wrote a baseline harness. Root captures the baseline before
the production optimization and reruns the same workload afterward. The test
seams do not select alternate production behavior.

## Results and verification

| Surface | Before | Implemented result |
| --- | --- | --- |
| Opening frame | Bootstrap loader starts with zero completed paints | One completed paint before bootstrap starts; persisted-report opening also deferred until after first frame |
| Connected sequence | Scripted first frame / health start / connected: 0 / 40 / 120 ms | Unchanged, with two existing health reads and one event channel; no network-latency speedup claimed |
| Historical diagnostics attach | 128 synchronous durable publications; 1,406.034 ms | One publication; 39.490 ms; live same-turn durability retained |
| 100,000-line log, 2,000-line capacity | 100,000 created line objects; median 24.085 ms | 2,000 created objects; median 11.201 ms; identical retained tail and drop count |
| 5,000 Work pin checks × 20 builds | 100,000 scope keys and 100,000 pin-set wrappers; 64.698 ms | One key and one immutable set reused; 21.451 ms in the first after run |
| Chat, one 5,000-fragment assistant reply | Ten spaced token pumps take 15,987.840 ms in the debug harness | Measured only; Claude-owned fixes ranked in [chat.md](chat.md) |
| Team board, 5,000 items × 20 notifications | 20 full projections | Measured only; immutable revision and expiry requirements in [work-lists.md](work-lists.md) |

These times are host observations, not release-device promises. For small
1,000-line logs the after sample was slower (0.755 vs 0.320 ms); the deterministic
benefit is bounded intermediate allocation for large inputs. Widget rebuild
counts remain unchanged for the implemented memory/pin fixes. Global controller
notifications already remain zero for the measured chat text events.

### Claude / owner hook-up contract

The implemented changes need no screen wiring, new copy or new states. Existing
pin queries and log append/replace APIs retain their contracts. Bootstrap still
awaits draft/photo/notification migrations before the shell; diagnostics keeps
in-memory early capture and imports it on durable-store attachment. No storage
format or per-profile key changes are introduced.

The chat hand-off gives exact current file/line locations, invalidation rules
and acceptance cases. Start with linear `_mergeTextParts`; then remeasure before
larger per-turn caching/virtualization. Team/Work screen projections and
`connection.dart` inventory sorting remain owner work: mutable model identity
alone is not a safe memoization key. Freshness, failure, consent and capability
indicators must continue to update. The extra startup health request from the
eager Settings tab is documented, not removed by changing tab lifecycle.

### Verification ledger

Candidate: base `c8e02abf` plus this commit's six production files and focused
tests. Final formatting uses `dart format --language-version=3.10` (12 files,
zero additional changes). Commands below use the pinned binaries above with
`OC_TEST_SLOTS=1 tool/qa/machine_lock.sh test --` and `flutter test --no-pub
--concurrency=1 … --reporter expanded`.

| Manifest | Result / local log |
| --- | --- |
| `perf_memory_test`, `kit/kit_log_panel_test`, `kit/kit_log_panel_r3_test`, `report_problem_test`, `report_problem_capture_test`, `app_diagnostics_test`, `perf_trace_test` | 79 passed; `/tmp/oc-perf-memory-after.log` |
| `perf_work_lists_test`, `session_pins_test` | 13 passed; `/tmp/oc-perf-work-after.log`; final deletion-cache assertion subsequently covered below |
| `perf_startup_test`, `perf_startup_connection_test`, `perf_work_lists_test`, `session_pins_test`, `saved_prompts_migration_test`, `saved_prompts_photo_recovery_test`, `capability_flows_test`, `report_problem_startup_test`, `kit_ratchet_test`, `redaction_test`, `ui_glossary_test`, `no_raw_error_text_test` | 112 passed; `/tmp/oc-perf-final-gates.log` |
| `app_diagnostics_test` after final bootstrap deferral | 4 passed; `/tmp/oc-perf-bootstrap-preservation.log` |

All manifest names are under `test/` with `.dart` suffixes. Results overlap;
they are not summed into an inflated distinct-test count. The startup ordering,
historical publication and log-allocation assertions failed before the fixes.
The Work probe recorded the allocation baseline before asserting final reuse.
The five chat baseline cases passed on unchanged chat production source.

After the host-session crash, the tree remained intact and the same candidate
was rechecked. The earlier `/tmp` logs were cleared by the restart; the tables
above preserve their observed results. All five performance files were rerun:
**19 passed**, `/tmp/oc-perf-final-probes-resumed.log`. Deterministic counts agree:
one paint before bootstrap, unchanged scripted connection timing, one scope
key/pin set, one history publication, and 2,000 materialized large-log lines.
Repeated after timings were 23.485 ms for 100,000 pin checks, 46.058 ms for
history attach, and 13.030 ms median for the large log; these are new samples,
not substitutes for the original before/after comparison. The small-log median
was 1.677 ms, reinforcing the absence of a small-input speedup claim.

The restarted preservation/gate run also passed **177 tests** in
`/tmp/oc-perf-final-preservation-resumed.log`. Its exact manifest is
`kit/kit_log_panel_test`, `kit/kit_log_panel_r3_test`, `report_problem_test`,
`report_problem_capture_test`, `app_diagnostics_test`, `perf_trace_test`,
`session_pins_test`, `saved_prompts_migration_test`,
`saved_prompts_photo_recovery_test`, `capability_flows_test`,
`report_problem_startup_test`, `kit_ratchet_test`, `redaction_test`,
`ui_glossary_test`, and `no_raw_error_text_test`, using the command flags above.

Pinned `flutter analyze --no-pub` passed with **no issues** after restart
(`/tmp/oc-perf-analyze-resumed.log`, 20.1 seconds), through
`OC_TEST_SLOTS=1 tool/qa/machine_lock.sh analyze --`. Final `git diff --check`
and all seven relative documentation links passed. The final candidate was
formatted without changes; production source stayed fixed during these runs.

Initial analysis found two redundant test imports, which were removed without
ignores. No full repository suite, release APK, device
cold-start/raster measurement or heap profile is claimed by this focused pass.
No signing, release, push or live-server mutation was performed. Local `/tmp`
logs are run artifacts; all measured values and rerunnable probes are committed.

### Remaining release checks

Measure actual `app.main` → `app.first_frame` / `app.first_connected` traces on
the target phone, separating remote and managed-local startup. Profile giant
chat replies after Claude's changes. Capture heap/live-image measurements before
changing image budgets; a line-count cap still cannot bound one giant log line.
See each slice for precise limitations and owner acceptance cases.
