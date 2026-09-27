# Buffers and caches

## Measured workloads

`test/perf_memory_test.dart` uses real buffers/controllers. Historical timing
capture imports 128 synthetic spans into a temporary, private diagnostic file;
listeners count durable publications and a widget counts builds. Large log
replacement uses 1,000 and 100,000 lines with capacity 2,000, one warmup and five
Stopwatch samples. A debug-only counter counts actual internally created
`KitLogLine` objects; it does not record log content and does not increment in
release builds. Retained lines, eviction counts and tail content are asserted.

| Workload | Before | After |
| --- | --- | --- |
| Import 128 historical timings | 128 durable publications; 1,406.034 ms | 1 durable publication; 39.490 ms |
| Import widget builds | 2 (initial + final) | 2; intermediate synchronous notifications were already frame-coalesced |
| Replace 100,000-line log | 100,000 internally allocated line objects; median 24.085 ms | 2,000 line objects; median 11.201 ms |
| Retained/dropped large-log lines | 2,000 / 98,000 | 2,000 / 98,000 |
| Replace 1,000-line log | 1,000 line objects; median 0.320 ms | 1,000 line objects; median 0.755 ms |

The large-log object reduction is deterministic (98% fewer created lines).
The small-log sample is slower; no general small-log speedup is claimed.
Stopwatch samples are noisy debug-host observations from separate processes,
not device frame budgets. Replacement widget builds stay at seven (initial plus
six inputs), preserving synchronous publication behavior.

Historical attach now calls `ReportProblem.recordTimings` once. It preserves
capture order, redaction, byte/entry limits, atomic replacement and final
snapshot, with one synchronous durable publication. Each **live** timing still
calls `recordTiming` and is persisted before returning. Error capture and Clear
semantics are unchanged. Batch failure preserves the prior snapshot and sets
`storageFailed`; nothing is moved into a lossy background queue.

`KitLogBuffer.appendText` counts completed lines from the tail and creates only
the lines that can survive the capacity limit. It preserves CRLF, empty lines,
partial-line joining, level/time metadata, dropped counts and immutable old
snapshots. The incoming source string still exists; the improvement removes
unbounded intermediate split strings and line objects, not the caller's input.

The baseline failed the new one-publication and bounded-materialization
assertions. After the fixes, all **79** tests passed in the memory/diagnostics
focused manifest, including existing log UI tests, same-turn durability,
redaction, limits, capture, trace tests, a randomized chunk-boundary oracle and
batch-versus-sequential byte eviction/reopen/failure behavior. Logs:
`/tmp/oc-perf-baseline.log` and `/tmp/oc-perf-memory-after.log`.

## Source inventory and limits

- `KitLogBuffer`: default 2,000 lines, immutable published snapshots. Before
  optimization, a single chunk is split into every line and creates every line
  object before old content is dropped. A line-count cap does **not** cap the
  bytes of a single line or an unterminated partial line. That residual limit
  needs an explicit truncation/product contract; this pass preserves content.
- `AppDiagnosticsController`: default 20 entries, each source/message/stack
  sanitized then limited to 80/2,000/12,000 code units plus truncation marker.
  Adjacent repeated errors are combined within ten seconds. The list is small;
  no speculative replacement is made.
- `PerfTrace`: a `ListQueue` capped at 2,000 spans; recent/stats reads allocate
  derived lists. Live trace persistence is synchronous by design so returned
  error/timing calls survive process death. Moving those writes onto an async
  queue would change that guarantee and is outside this optimization.
- `ReportProblem`: 128 entries, a 262,144-byte UTF-8 snapshot by default; at
  most committed and pending files coexist. Historical attach previously writes
  each imported timing separately. Same-turn live durability must stay intact.
- `DraftAttachmentVault`: five attachments, 32 MiB per draft and 256 MiB on
  disk; bounded streaming reads verify size and hash. The weak-key `Expando`
  retains metadata, not a global strong payload cache.
- Chat composer decoded thumbnails use a weak-key `Expando` per immutable
  attachment, including a failed-decode marker. No global strong thumbnail
  cache was introduced; these Claude-owned files are read only.
- `KitImage` uses layout/device-pixel decode targets and a 4,096-pixel fallback
  when unbounded. The pinned Flutter image cache defaults to 1,000 entries and
  100 MiB (`packages/flutter/lib/src/painting/image_cache.dart:18–19`). The app
  does not override those defaults. Live decoded images and source attachment
  bytes are additional memory, so this is not a process-memory ceiling.

No heap/RSS improvement is inferred from reference counts. A release-phone run
with camera-sized images, GC/heap snapshots and live-image counts remains the
appropriate validation before changing image budgets or decode quality.
